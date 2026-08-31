import Foundation
import Testing
@testable import Trove

/// T001's guards over the canonical schema: serializers by exact output, the
/// money round trip `012` depends on, and the pinned header lists.
struct ExportSchemaTests {
    // MARK: - Headers

    /// Deliberate double-entry bookkeeping, not a copy-paste tautology: these
    /// arrays are a wire format `012` matches byte-for-byte, so changing them
    /// must be a conscious two-place edit that also updates plan.md's schema
    /// section — this test is what makes an accidental reorder or rename fail
    /// loudly instead of silently changing the contract.
    @Test func headerListsMatchThePinnedSchema() {
        #expect(ExportSchema.itemHeaders == [
            "Name", "Category", "Purchase Price", "Currency", "Purchase Date",
            "Purchase Location", "Current Value", "Desire to Keep", "Condition",
            "Condition Notes", "Serial Number", "Notes",
        ])
        #expect(ExportSchema.wishlistHeaders == [
            "Name", "Category", "Estimated Cost", "Currency", "Desire to Own",
            "Added", "Notes",
        ])
    }

    // MARK: - Money

    @Test func moneySerializesExactValues() {
        #expect(ExportSchema.money(cents: 0) == "0.00")
        #expect(ExportSchema.money(cents: 1) == "0.01")
        #expect(ExportSchema.money(cents: 99) == "0.99")
        #expect(ExportSchema.money(cents: 105) == "1.05")
        #expect(ExportSchema.money(cents: 125_000) == "1250.00")
        #expect(ExportSchema.money(cents: 999_999_999) == "9999999.99")
    }

    /// The invariant `012` actually depends on (plan.md's test plan): the
    /// serialized field, parsed back through the app's own parse-side helper,
    /// lands on the same cents — not merely "the string looks right".
    @Test func moneyRoundTripsThroughTheParseSide() throws {
        for cents in [0, 1, 5, 99, 100, 105, 125_000, 999_999_999] {
            let field = ExportSchema.money(cents: cents)
            let parsed = try #require(Decimal(string: field))
            #expect(Money.cents(from: parsed) == cents, "\(cents) → \(field)")
        }
    }

    // MARK: - Dates

    private func calendar(in identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    @Test func daySerializesZeroPaddedISO() throws {
        let newYork = calendar(in: "America/New_York")
        let date = try #require(newYork.date(from: DateComponents(year: 2026, month: 1, day: 5)))
        #expect(ExportSchema.day(from: date, calendar: newYork) == "2026-01-05")
    }

    /// Documents the local-day semantics the spec's amended date rule chose:
    /// one instant, two calendars, two days. This is the recorded caveat, not
    /// a bug — the CSV shows the day the screen shows.
    @Test func dayIsTheLocalCalendarDay() throws {
        let newYork = calendar(in: "America/New_York")
        let tokyo = calendar(in: "Asia/Tokyo")
        let lateEvening = try #require(newYork.date(
            from: DateComponents(year: 2026, month: 8, day: 30, hour: 23, minute: 45)
        ))
        #expect(ExportSchema.day(from: lateEvening, calendar: newYork) == "2026-08-30")
        #expect(ExportSchema.day(from: lateEvening, calendar: tokyo) == "2026-08-31")
    }

    // MARK: - Rows

    private func cell(_ row: [String], _ header: String, of headers: [String]) throws -> String {
        row[try #require(headers.firstIndex(of: header))]
    }

    @Test func itemRowCarriesEveryColumnInHeaderOrder() throws {
        let newYork = calendar(in: "America/New_York")
        let bought = try #require(newYork.date(from: DateComponents(year: 2026, month: 3, day: 9)))
        let record = ItemExportRecord(
            name: "Leica M6",
            categoryPath: "Photography/Cameras",
            purchasePriceCents: 290_000,
            currencyCode: "USD",
            purchaseDate: bought,
            purchaseLocation: "KEH",
            currentValueCents: 345_050,
            desireToKeep: 5,
            conditionRawValue: "excellent",
            conditionNotes: "New seals",
            serialNumber: "2244668",
            notes: "Body only",
            firstPhotoID: nil
        )

        let row = ExportSchema.row(from: record, calendar: newYork)
        #expect(row == [
            "Leica M6", "Photography/Cameras", "2900.00", "USD", "2026-03-09",
            "KEH", "3450.50", "5", "excellent", "New seals", "2244668", "Body only",
        ])
        #expect(row.count == ExportSchema.itemHeaders.count)
    }

    @Test func nilItemFieldsBecomeEmptyCellsNotZeroes() throws {
        let record = ItemExportRecord(
            name: "Squier CV 50s",
            categoryPath: "Music/Guitars",
            purchasePriceCents: 38_000,
            currencyCode: "USD",
            purchaseDate: .now,
            purchaseLocation: nil,
            currentValueCents: nil,
            desireToKeep: 1,
            conditionRawValue: "good",
            conditionNotes: nil,
            serialNumber: nil,
            notes: nil,
            firstPhotoID: nil
        )

        let row = ExportSchema.row(from: record)
        let headers = ExportSchema.itemHeaders
        // Unvalued is not worthless: the cell must be empty, never "0.00".
        #expect(try cell(row, "Current Value", of: headers) == "")
        #expect(try cell(row, "Purchase Location", of: headers) == "")
        #expect(try cell(row, "Condition Notes", of: headers) == "")
        #expect(try cell(row, "Serial Number", of: headers) == "")
        #expect(try cell(row, "Notes", of: headers) == "")
    }

    @Test func wishlistRowCarriesEveryColumnInHeaderOrder() throws {
        let newYork = calendar(in: "America/New_York")
        let added = try #require(newYork.date(from: DateComponents(year: 2026, month: 8, day: 30)))
        let record = WishlistExportRecord(
            name: "Vox AC15",
            categoryPath: "Music/Amps",
            estimatedCostCents: 105_000,
            currencyCode: "USD",
            desireToOwn: 3,
            createdAt: added,
            notes: nil,
            firstPhotoID: nil
        )

        let row = ExportSchema.row(from: record, calendar: newYork)
        #expect(row == ["Vox AC15", "Music/Amps", "1050.00", "USD", "3", "2026-08-30", ""])
        #expect(row.count == ExportSchema.wishlistHeaders.count)
    }

    @Test func tablesPairThePinnedHeadersWithSerializedRows() {
        let table = ExportSchema.itemsTable([])
        #expect(table.headers == ExportSchema.itemHeaders)
        #expect(table.rows.isEmpty)

        let wishlist = ExportSchema.wishlistTable([])
        #expect(wishlist.headers == ExportSchema.wishlistHeaders)
        #expect(wishlist.rows.isEmpty)
    }
}

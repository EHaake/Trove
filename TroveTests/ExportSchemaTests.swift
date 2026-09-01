import Foundation
import SwiftData
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

    private func zone(_ identifier: String) -> TimeZone {
        TimeZone(identifier: identifier)!
    }

    /// Builds fixture dates; the serializer itself never takes a calendar —
    /// only a time zone — which is what makes identifier-independence
    /// structural (T019/B1).
    private func gregorian(in identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone(identifier)
        return calendar
    }

    @Test func daySerializesZeroPaddedISO() throws {
        let newYork = gregorian(in: "America/New_York")
        let date = try #require(newYork.date(from: DateComponents(year: 2026, month: 1, day: 5)))
        #expect(ExportSchema.day(from: date, timeZone: zone("America/New_York")) == "2026-01-05")
    }

    /// T019/B1's pin: the serializer's calendar is Gregorian by
    /// construction — the API takes only a `TimeZone`, so the user's
    /// preferred-calendar setting (Buddhist year 2569, Japanese eras) has no
    /// way in. The epoch is the least ambiguous instant there is.
    @Test func dayIsAlwaysGregorianRegardlessOfDeviceCalendar() {
        #expect(ExportSchema.day(from: Date(timeIntervalSince1970: 0), timeZone: zone("UTC")) == "1970-01-01")
    }

    /// Documents the local-day semantics the spec's amended date rule chose:
    /// one instant, two calendars, two days. This is the recorded caveat, not
    /// a bug — the CSV shows the day the screen shows.
    @Test func dayIsTheLocalCalendarDay() throws {
        let newYork = gregorian(in: "America/New_York")
        let lateEvening = try #require(newYork.date(
            from: DateComponents(year: 2026, month: 8, day: 30, hour: 23, minute: 45)
        ))
        #expect(ExportSchema.day(from: lateEvening, timeZone: zone("America/New_York")) == "2026-08-30")
        #expect(ExportSchema.day(from: lateEvening, timeZone: zone("Asia/Tokyo")) == "2026-08-31")
    }

    // MARK: - Rows

    private func cell(_ row: [String], _ header: String, of headers: [String]) throws -> String {
        row[try #require(headers.firstIndex(of: header))]
    }

    @Test func itemRowCarriesEveryColumnInHeaderOrder() throws {
        let newYork = gregorian(in: "America/New_York")
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

        let row = ExportSchema.row(from: record, timeZone: zone("America/New_York"))
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
        let newYork = gregorian(in: "America/New_York")
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

        let row = ExportSchema.row(from: record, timeZone: zone("America/New_York"))
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

    // MARK: - PDF entry builders (T007)

    /// The entry grid speaks the detail screen's language ("Worth now",
    /// "Not yet valued") and skips empty optionals the way the screen
    /// filters its empty rows — presentation, where the CSV is data.
    @Test func itemEntrySkipsEmptyRowsAndSpeaksScreenLanguage() {
        let record = ItemExportRecord(
            name: "Squier",
            categoryPath: "Music/Guitars/Electric",
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

        let entry = PDFEntry(record: record)
        #expect(entry.eyebrow == "Music · Guitars · Electric")
        #expect(entry.name == "Squier")
        #expect(entry.notes == nil)

        let labels = entry.fields.map(\.label)
        #expect(labels == ["Paid", "Worth now", "Currency", "Bought", "Desire to keep", "Condition"])

        let worthNow = entry.fields[1]
        #expect(worthNow.value == "Not yet valued")
        // Prose, not a figure — it draws in the sans face like the screen.
        #expect(!worthNow.isMono)
        #expect(entry.fields[0].value == "$380")
        #expect(entry.fields[0].isMono)
        #expect(entry.fields[5].value == "Good")
    }

    @Test func wishlistEntryCarriesItsFourFieldsAndNotes() {
        let record = WishlistExportRecord(
            name: "Vox AC15",
            categoryPath: "Music/Amps",
            estimatedCostCents: 105_000,
            currencyCode: "USD",
            desireToOwn: 3,
            createdAt: .now,
            notes: "Custom, not C2",
            firstPhotoID: nil
        )

        let entry = PDFEntry(record: record)
        #expect(entry.fields.map(\.label) == ["Estimated cost", "Currency", "Desire to own", "Added"])
        #expect(entry.fields[0].value == "$1,050")
        #expect(entry.fields[2].value == "3 / 3")
        #expect(entry.notes == "Custom, not C2")
    }

    // MARK: - Model → record mapping (T002)

    @Test func itemRecordCarriesEveryFieldFromTheModel() throws {
        let context = try makeInMemoryContext()
        let bought = Date(timeIntervalSince1970: 1_700_000_000)
        let item = Item(
            name: "Leica M6",
            categoryPath: "Photography/Cameras",
            purchasePriceCents: 290_000,
            purchaseDate: bought,
            currencyCode: "USD",
            serialNumber: "2244668",
            purchaseLocation: "KEH",
            currentValueCents: 345_000,
            desireToKeep: 5,
            condition: .fair,
            conditionNotes: "New seals",
            notes: "Body only"
        )
        context.insert(item)
        try context.save()

        let record = ItemExportRecord(item: item)
        #expect(record.name == "Leica M6")
        #expect(record.categoryPath == "Photography/Cameras")
        #expect(record.purchasePriceCents == 290_000)
        #expect(record.currencyCode == "USD")
        #expect(record.purchaseDate == bought)
        #expect(record.purchaseLocation == "KEH")
        #expect(record.currentValueCents == 345_000)
        #expect(record.desireToKeep == 5)
        #expect(record.conditionRawValue == "fair")
        #expect(record.conditionNotes == "New seals")
        #expect(record.serialNumber == "2244668")
        #expect(record.notes == "Body only")
        #expect(record.firstPhotoID == nil)
    }

    @Test func itemRecordKeepsNilsNil() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Squier", categoryPath: "Music/Guitars", purchasePriceCents: 38_000)
        context.insert(item)
        try context.save()

        let record = ItemExportRecord(item: item)
        // Unvalued must survive as nil — the row builder turns it into an
        // empty cell, and a 0 sneaking in here would read as "worthless".
        #expect(record.currentValueCents == nil)
        #expect(record.purchaseLocation == nil)
        #expect(record.conditionNotes == nil)
        #expect(record.serialNumber == nil)
        #expect(record.notes == nil)
    }

    /// The chosen photo is the *display-order* first, not whatever the
    /// relationship hands back — `sortOrder` runs opposite to insertion order
    /// here so relationship order can't accidentally satisfy the test.
    @Test func firstPhotoFollowsDisplayOrderNotInsertionOrder() throws {
        let context = try makeInMemoryContext()
        let second = Photo(imageData: Data([0x01]), sortOrder: 1)
        let first = Photo(imageData: Data([0x02]), sortOrder: 0)
        let item = Item(name: "M6", categoryPath: "Photography", photos: [second, first])
        context.insert(item)
        try context.save()

        let record = ItemExportRecord(item: item)
        #expect(record.firstPhotoID == first.persistentModelID)
        #expect(record.firstPhotoID != second.persistentModelID)
    }

    @Test func wishlistRecordCarriesEveryFieldFromTheModel() throws {
        let context = try makeInMemoryContext()
        let second = Photo(imageData: Data([0x01]), sortOrder: 1)
        let first = Photo(imageData: Data([0x02]), sortOrder: 0)
        let wanted = WishlistItem(
            name: "Vox AC15",
            categoryPath: "Music/Amps",
            estimatedCostCents: 105_000,
            currencyCode: "USD",
            notes: "Custom, not C2",
            desireToOwn: 3,
            photos: [second, first]
        )
        context.insert(wanted)
        try context.save()

        let record = WishlistExportRecord(item: wanted)
        #expect(record.name == "Vox AC15")
        #expect(record.categoryPath == "Music/Amps")
        #expect(record.estimatedCostCents == 105_000)
        #expect(record.currencyCode == "USD")
        #expect(record.desireToOwn == 3)
        #expect(record.createdAt == wanted.createdAt)
        #expect(record.notes == "Custom, not C2")
        #expect(record.firstPhotoID == first.persistentModelID)
    }
}

import Foundation
import SwiftData
import Testing
@testable import Trove

/// 021 T006, guard G9 and the summary half of G21 on the wishlist: the add
/// path through `WishlistImportStore` (plan §8, Q11). Callers save, so every
/// persisted assertion saves and refetches on a **second** `ModelContext`.
/// Every row is invented.
@Suite("Wishlist import store")
struct WishlistImportStoreTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    /// After every stored position — a bought entry's included (015 plan
    /// §4) — in file order.
    @Test func rowsLandAfterTheExistingWishlistInFileOrder() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(WishlistItem(name: "Vox AC15", sortOrder: 3))
        let bought = WishlistItem(name: "Rickenbacker 330", sortOrder: 7)
        context.insert(bought)
        try WishlistPurchaseStore.markBought(
            bought, purchase: Purchase(date: now, priceCents: 250_000, location: nil, condition: .good),
            at: now, in: context
        )
        try context.save()

        let sheet = try wishSheet([
            cells(["Name": "Leica Q2"]),
            cells(["Name": "Fuji X100V"]),
            cells(["Name": "Ricoh GR III"]),
        ])
        try commit(sheet, in: context)

        let stored = try ModelContext(container).fetch(FetchDescriptor<WishlistItem>())
        let order = Dictionary(uniqueKeysWithValues: stored.map { ($0.name, $0.sortOrder) })
        #expect(order["Vox AC15"] == 3)
        #expect(order["Rickenbacker 330"] == 7)
        #expect(order["Leica Q2"] == 8)
        #expect(order["Fuji X100V"] == 9)
        #expect(order["Ricoh GR III"] == 10)
    }

    /// `Added` restores `createdAt` — a date far from `now` and from the
    /// moment the test runs.
    @Test func addedIsTheRowsDate() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let sheet = try wishSheet([cells(["Name": "Leica Q2", "Added": "2019-11-04"])])
        try commit(sheet, in: context)

        let wish = try #require(try ModelContext(container).fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(wish.createdAt == day(2019, 11, 4))
    }

    @Test func aCasingVariantTakesTheExistingPathsCasing() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(WishlistItem(name: "Vox AC15", categoryPath: "Music/Amps"))
        try context.save()

        let sheet = try wishSheet([
            cells(["Name": "Fender Princeton", "Category": "music/AMPS"]),
            cells(["Name": "Leica Q2", "Category": "Photo/Compacts"]),
            cells(["Name": "Ricoh GR III", "Category": "photo/compacts"]),
        ])
        try commit(sheet, in: context)

        let stored = try ModelContext(container).fetch(FetchDescriptor<WishlistItem>())
        let paths = Dictionary(uniqueKeysWithValues: stored.map { ($0.name, $0.categoryPath) })
        #expect(paths["Fender Princeton"] == "Music/Amps")
        #expect(paths["Leica Q2"] == "Photo/Compacts")
        #expect(paths["Ricoh GR III"] == "Photo/Compacts")
    }

    @Test func theSummaryCarriesTheSheetsCounts() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        // No `Desire to Own` column; `Mount` is not one of Trove's.
        let header = ["Trove ID", "Name", "Estimated Cost", "Added", "Mount"]
        let sheet = try ImportSchema.wishlistSheet(from: file(header, [
            ["", "Leica Q2", "4250.00", "03/04/2025", "L"],
            ["", "Fuji X100V", "abc", "05/06/2025", ""],
            [UUID().uuidString, "", "", "", ""],
            ["", "Total", "4250.00", "", ""],
            ["", "Ricoh GR III", "900", "07/08/2025", "", "extra"],
            ["", "", "100", "07/08/2025", ""],
            ["", "Pentax 17", "", "", ""],
        ]), timeZone: utc(), locale: Locale(identifier: "en_US"))

        let plan = try WishlistImportStore.plan(for: sheet, in: context, timeZone: utc(), now: now)
        #expect(!context.hasChanges)

        let summary = plan.summary
        #expect(plan.adds.map(\.record.name) == ["Leica Q2", "Fuji X100V", "Pentax 17"])
        #expect(summary.added == 3)
        #expect(summary.skipped == [
            SkippedRow(rowNumber: 4, reason: "no name"),
            SkippedRow(rowNumber: 6, reason: "more columns than the header"),
            SkippedRow(rowNumber: 7, reason: "no name"),
        ])
        // One unreadable cost; then an empty cost and an empty `Added`. The
        // missing `Desire to Own` column counts nothing.
        #expect(summary.defaultedOnNew == 3)
        #expect(summary.unusedColumns == ["Mount"])
        #expect(summary.unusedColumns == sheet.unusedColumns)
        #expect(summary.totalsRows == [5])
        #expect(summary.regionDateOrder == .monthFirst)
        #expect(summary.regionDateOrder == sheet.regionDateOrder)
        #expect(summary.missingDefaultColumns == ["Desire to Own"])
        #expect(summary.updated == 0)
        #expect(summary.unchanged == 0)
        #expect(summary.keptCodeAdds == 0)
    }

    // MARK: - Helpers

    /// Plan, apply, then the caller's save.
    private func commit(_ sheet: WishlistImportSheet, in context: ModelContext) throws {
        let plan = try WishlistImportStore.plan(for: sheet, in: context, timeZone: utc(), now: now)
        try WishlistImportStore.apply(plan, in: context, now: now)
        try context.save()
    }

    private func utc() -> TimeZone { TimeZone(identifier: "UTC")! }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc()
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func file(_ header: [String], _ dataRows: [[String]]) -> [CSVRow] {
        [CSVRow(number: 1, cells: header)]
            + dataRows.enumerated().map { CSVRow(number: $0.offset + 2, cells: $0.element) }
    }

    private func wishSheet(_ dataRows: [[String]]) throws -> WishlistImportSheet {
        try ImportSchema.wishlistSheet(
            from: file(ExportSchema.wishlistHeaders, dataRows), timeZone: utc(), locale: Locale(identifier: "en_US")
        )
    }

    /// One valid row in `ExportSchema.wishlistHeaders` order, keyed by header.
    private func cells(_ changes: [String: String]) -> [String] {
        var byHeader = [
            "Name": "Leica Q2",
            "Category": "",
            "Estimated Cost": "4250.00",
            "Currency": "USD",
            "Desire to Own": "3",
            "Added": "2025-11-04",
            "Notes": "",
            "Reverb Product ID": "",
            "Year": "",
            "Looking For": "",
        ]
        byHeader.merge(changes) { _, new in new }
        return ExportSchema.wishlistHeaders.map { byHeader[$0]! }
    }
}

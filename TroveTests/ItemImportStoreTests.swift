import Foundation
import SwiftData
import Testing
@testable import Trove

/// 021 T006, guard G9 and the summary half of G21: the items import's add
/// path through `ItemImportStore` (plan §8, Q11). The store doesn't save —
/// callers do — so every persisted assertion saves and refetches on a
/// **second** `ModelContext` (`makeInMemoryContainer`'s doc). Every row is
/// invented.
@Suite("Item import store")
struct ItemImportStoreTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    /// Placement after every stored position — the max, not the count — in
    /// file order.
    @Test func rowsLandAfterTheExistingCollectionInFileOrder() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(Item(name: "Telecaster", purchasePriceCents: 100_000, sortOrder: 3))
        context.insert(Item(name: "Blues Junior", purchasePriceCents: 60_000, sortOrder: 7))
        try context.save()

        let sheet = try itemsSheet([
            cells(["Name": "Leica M6"]),
            cells(["Name": "Rolleiflex"]),
            cells(["Name": "Hasselblad 500C"]),
        ])
        try commit(sheet, in: context)

        let stored = try ModelContext(container).fetch(FetchDescriptor<Item>())
        let order = Dictionary(uniqueKeysWithValues: stored.map { ($0.name, $0.sortOrder) })
        #expect(order["Telecaster"] == 3)
        #expect(order["Blues Junior"] == 7)
        #expect(order["Leica M6"] == 8)
        #expect(order["Rolleiflex"] == 9)
        #expect(order["Hasselblad 500C"] == 10)
    }

    @Test func aSalePairArrivesSoldWithAllFourFieldsAndNoPlan() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let sheet = try itemsSheet([
            cells([
                "Name": "Blues Junior", "Sold Date": "2026-07-04", "Sale Price": "550.00",
                "Sold At": "Reverb", "Sale Note": "Shipped Tuesday",
            ]),
        ])
        try commit(sheet, in: context)

        let item = try #require(try ModelContext(container).fetch(FetchDescriptor<Item>()).first)
        #expect(item.soldDate == day(2026, 7, 4))
        #expect(item.salePriceCents == 55_000)
        #expect(item.saleLocation == "Reverb")
        #expect(item.saleNote == "Shipped Tuesday")
        #expect(item.soldTowardWishlistItem == nil)
    }

    /// A stored path's casing wins, and within the file the first
    /// occurrence's casing does.
    @Test func aCasingVariantTakesTheExistingPathsCasing() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(Item(name: "Telecaster", categoryPath: "Music/Guitars", purchasePriceCents: 100_000))
        try context.save()

        let sheet = try itemsSheet([
            cells(["Name": "Stratocaster", "Category": "music/GUITARS"]),
            cells(["Name": "Leica M6", "Category": "Photo/Film Bodies"]),
            cells(["Name": "Rolleiflex", "Category": "photo/film bodies"]),
        ])
        try commit(sheet, in: context)

        let stored = try ModelContext(container).fetch(FetchDescriptor<Item>())
        let paths = Dictionary(uniqueKeysWithValues: stored.map { ($0.name, $0.categoryPath) })
        #expect(paths["Stratocaster"] == "Music/Guitars")
        #expect(paths["Leica M6"] == "Photo/Film Bodies")
        #expect(paths["Rolleiflex"] == "Photo/Film Bodies")
    }

    /// The summary of the add path is the sheet's, plus the store's own
    /// "no name" skip for a nameless row the sheet kept for its code — and
    /// planning writes nothing.
    @Test func theSummaryCarriesTheSheetsCounts() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        // No `Desire to Keep` column; `Mount` is not one of Trove's.
        let header = ["Trove ID", "Name", "Purchase Price", "Purchase Date", "Condition", "Mount"]
        let sheet = try ImportSchema.itemsSheet(from: file(header, [
            ["", "Leica M6", "2900.00", "03/04/2026", "excellent", "M"],
            ["", "Blues Junior", "abc", "05/06/2026", "good", ""],
            [UUID().uuidString, "", "", "", "", ""],
            ["", "Total", "2900.00", "", "", ""],
            ["", "Strat", "1200", "07/08/2026", "good", "", "extra"],
            ["", "", "100", "07/08/2026", "good", ""],
            ["", "Vox AC15", "", "", "", ""],
        ]), timeZone: utc(), locale: Locale(identifier: "en_US"))

        let plan = try ItemImportStore.plan(for: sheet, in: context, timeZone: utc(), now: now)
        #expect(!context.hasChanges)

        let summary = plan.summary
        #expect(plan.adds.map(\.record.name) == ["Leica M6", "Blues Junior", "Vox AC15"])
        #expect(summary.added == 3)
        #expect(summary.skipped == [
            SkippedRow(rowNumber: 4, reason: "no name"),
            SkippedRow(rowNumber: 6, reason: "more columns than the header"),
            SkippedRow(rowNumber: 7, reason: "no name"),
        ])
        // One unreadable price; then an empty price, date and condition. The
        // missing `Desire to Keep` column counts nothing.
        #expect(summary.defaultedOnNew == 4)
        #expect(summary.unusedColumns == ["Mount"])
        #expect(summary.unusedColumns == sheet.unusedColumns)
        #expect(summary.totalsRows == [5])
        #expect(summary.regionDateOrder == .monthFirst)
        #expect(summary.regionDateOrder == sheet.regionDateOrder)
        #expect(summary.missingDefaultColumns == ["Desire to Keep"])
        #expect(summary.updated == 0)
        #expect(summary.unchanged == 0)
        #expect(summary.keptCodeAdds == 0)
    }

    // MARK: - Helpers

    /// Plan, apply, then the caller's save.
    private func commit(_ sheet: ItemsImportSheet, in context: ModelContext) throws {
        let plan = try ItemImportStore.plan(for: sheet, in: context, timeZone: utc(), now: now)
        try ItemImportStore.apply(plan, in: context, now: now)
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

    private func itemsSheet(_ dataRows: [[String]]) throws -> ItemsImportSheet {
        try ImportSchema.itemsSheet(
            from: file(ExportSchema.itemHeaders, dataRows), timeZone: utc(), locale: Locale(identifier: "en_US")
        )
    }

    /// One valid row in `ExportSchema.itemHeaders` order, keyed by header.
    private func cells(_ changes: [String: String]) -> [String] {
        var byHeader = [
            "Name": "Leica M6",
            "Category": "",
            "Purchase Price": "2900.00",
            "Currency": "USD",
            "Purchase Date": "2026-03-09",
            "Purchase Location": "",
            "Current Value": "",
            "Desire to Keep": "4",
            "Condition": "good",
            "Condition Notes": "",
            "Serial Number": "",
            "Notes": "",
            "Reverb Product ID": "",
            "Year": "",
            "Sold Date": "",
            "Sale Price": "",
            "Sold At": "",
            "Sale Note": "",
            "Bought": "",
        ]
        byHeader.merge(changes) { _, new in new }
        return ExportSchema.itemHeaders.map { byHeader[$0]! }
    }
}

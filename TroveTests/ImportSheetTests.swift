import Foundation
import Testing
@testable import Trove

/// 021 T004, guards G6 and G21: the items file read to cells and made into
/// new rows (plan §4; spec criteria 1, 3, 6, 11, 14, 15 and 41; Decisions 17
/// and 23). Every row here, and in `docs/samples/items-hand-kept.csv`, is
/// invented.
struct ImportSheetTests {
    /// The person's header, exact names and order (plan §4).
    private let handKeptHeader =
        "Name,Category,Purchase Price,Currency,Purchase Date,Purchase Location,Current Value,Desire to Keep,Condition,Serial Number"

    // MARK: - Criterion 1: the hand-kept fixture

    @Test func theHandKeptFixtureReadsWholeWithNoSkipsAndNoDefaults() throws {
        let text = try fixtureText()
        #expect(text.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) == handKeptHeader)
        #expect(!text.hasSuffix("\n"))
        #expect(!text.contains("\r"))
        #expect(!text.hasPrefix("\u{FEFF}"))

        // A day-first region: the file's own dates must decide month-first.
        let sheet = try ImportSchema.itemsSheet(
            from: try CSVParser.parse(text), timeZone: utc(), locale: Locale(identifier: "en_GB")
        )
        #expect(sheet.rows.count == 24)
        #expect(sheet.skipped.isEmpty)
        #expect(sheet.totalsRowNumbers == [32])
        #expect(sheet.regionDateOrder == nil)
        #expect(sheet.missingDefaultColumns.isEmpty)
        #expect(sheet.unusedColumns.isEmpty)

        let new = sheet.rows.compactMap { $0.asNew(now: instant(), missingColumns: sheet.missingDefaultColumns) }
        #expect(new.count == 24)
        #expect(new.reduce(0) { $0 + $1.defaultedFieldCount } == 0)
        // The totals row's two amounts are the columns' true sums.
        #expect(new.reduce(0) { $0 + $1.record.purchasePriceCents } == 2_708_886)
        #expect(new.reduce(0) { $0 + ($1.record.currentValueCents ?? 0) } == 2_660_500)
    }

    @Test func theFixturesCellsReadAsTheyShould() throws {
        let sheet = try fixtureSheet()
        func row(_ name: String) throws -> ItemImportRow {
            let found = sheet.rows.first { $0.name == .value(name) }
            return try #require(found, "\(name)")
        }

        let free = try row("Lens cap set")
        #expect(free.purchasePrice == .value(0))
        let freeNew = try #require(free.asNew(now: instant(), missingColumns: []))
        #expect(freeNew.record.purchasePriceCents == 0)
        #expect(freeNew.defaultedFieldCount == 0)

        #expect(try row("Klon-style overdrive").currentValue == .value(50_000))
        #expect(try row("Klon-style overdrive").serialNumber == .value("SN+4471"))
        #expect(try row("Hasselblad 500C/M").serialNumber == .value("0451288"))
        let notApplicable = try row("Summicron 50mm f/2")
        #expect(notApplicable.serialNumber == .empty)
        #expect(notApplicable.asNew(now: instant(), missingColumns: [])?.record.serialNumber == nil)

        // Trimmed, and the untrimmed spelling is nowhere.
        _ = try row("Fender Twin Reverb")
        #expect(!sheet.rows.contains { $0.name == .value("Fender Twin Reverb ") })
        _ = try row("Sony Bravia 42\" TV")

        // 3/14/2019 — a day above 12 lands on that day.
        #expect(try row("Leica M6 Classic").purchaseDate == .value(day(2019, 3, 14)))
        #expect(try row("Nikon FM2").purchaseDate == .value(day(2018, 11, 23)))
        #expect(try row("Gitzo tripod").condition == .value(.veryGood))
    }

    // MARK: - Criterion 3: columns by name, in any order

    @Test func shuffledColumnsGiveEqualRows() throws {
        let text = try fixtureText()
        let parsed = try CSVParser.parse(text)
        let width = handKeptHeader.split(separator: ",").count
        let permutation = [9, 3, 0, 7, 5, 1, 8, 2, 6, 4]
        let shuffled = parsed.map { row in
            let padded = row.cells + Array(repeating: "", count: width - row.cells.count)
            return CSVRow(number: row.number, cells: permutation.map { padded[$0] })
        }
        #expect(shuffled[0].cells.first == "Serial Number")

        let original = try ImportSchema.itemsSheet(from: parsed, timeZone: utc(), locale: usLocale())
        let reordered = try ImportSchema.itemsSheet(from: shuffled, timeZone: utc(), locale: usLocale())
        #expect(reordered.rows.count == 24)
        #expect(reordered.rows == original.rows)
        #expect(reordered.totalsRowNumbers == original.totalsRowNumbers)
        #expect(reordered.skipped.isEmpty)
    }

    // MARK: - Criteria 6 and 41: the required-only file

    @Test func aRequiredOnlyFileTakesTheBlankDefaultsAndCountsNoneForMissingColumns() throws {
        let sheet = try sheet(header: ["Name", "Purchase Price", "Purchase Date"], [
            ["Rega Planar 2", "$450.00", "3/14/2024"],
            ["Nikon F3", "300", "2024-01-02"],
        ])
        #expect(sheet.missingDefaultColumns == ["Desire to Keep", "Condition"])
        #expect(sheet.skipped.isEmpty)

        let new = sheet.rows.compactMap { $0.asNew(now: instant(), missingColumns: sheet.missingDefaultColumns) }
        #expect(new.count == 2)
        for row in new {
            #expect(row.defaultedFieldCount == 0)
            #expect(row.record.desireToKeep == 3)
            #expect(row.record.conditionRawValue == "excellent")
            #expect(row.record.currencyCode == "USD")
            #expect(row.record.categoryPath == "")
            #expect(row.record.currentValueCents == nil)
            #expect(row.record.purchaseLocation == nil)
            #expect(row.record.conditionNotes == nil)
            #expect(row.record.serialNumber == nil)
            #expect(row.record.notes == nil)
            #expect(row.record.reverbProductID == nil)
            #expect(row.record.year == nil)
            #expect(row.record.soldDate == nil)
            #expect(row.record.salePriceCents == nil)
            #expect(row.record.bought == nil)
        }
        #expect(new[0].record.purchasePriceCents == 45_000)
        #expect(new[0].record.purchaseDate == day(2024, 3, 14))
        #expect(new[1].record.purchasePriceCents == 30_000)
    }

    @Test func aPresentColumnWithBlankCellsStillCountsItsDefault() throws {
        let sheet = try sheet(header: ["Name", "Purchase Price", "Purchase Date", "Condition"], [
            ["Rega Planar 2", "$450.00", "3/14/2024", ""],
            ["Nikon F3", "300", "2024-01-02", "N/A"],
        ])
        #expect(sheet.missingDefaultColumns == ["Desire to Keep"])
        let new = sheet.rows.compactMap { $0.asNew(now: instant(), missingColumns: sheet.missingDefaultColumns) }
        #expect(new.count == 2)
        #expect(new.map(\.defaultedFieldCount) == [1, 1])
        #expect(new.map(\.record.conditionRawValue) == ["excellent", "excellent"])
        #expect(new.map(\.record.desireToKeep) == [3, 3])
    }

    // MARK: - Criterion 11: the symbol does not change the currency

    @Test func aPriceSymbolNeverSetsTheCurrency() throws {
        let sheet = try sheet(header: ["Name", "Purchase Price", "Currency", "Purchase Date"], [
            ["Leica M3", "€1,250", "", "2024-01-02"],
            ["Leica M4", "€1,250", "GBP", "2024-01-02"],
        ])
        #expect(sheet.rows.map(\.purchasePrice) == [.value(125_000), .value(125_000)])
        #expect(sheet.rows.map(\.currency) == [.empty, .value("GBP")])
        let new = sheet.rows.compactMap { $0.asNew(now: instant(), missingColumns: sheet.missingDefaultColumns) }
        #expect(new.map(\.record.currencyCode) == ["USD", "GBP"])
        #expect(new.map(\.defaultedFieldCount) == [0, 0])
    }

    // MARK: - Criterion 14: N/A is an empty cell in every column

    @Test func notApplicableReadsAsAnEmptyCellInEveryColumn() throws {
        for spelling in ["N/A", "n/a", "#N/A"] {
            let serial = try fullRow(["Serial Number": spelling])
            #expect(serial.serialNumber == .empty, "\(spelling)")
            #expect(serial.asNew(now: instant(), missingColumns: [])?.record.serialNumber == nil)

            let value = try fullRow(["Current Value": spelling])
            #expect(value.currentValue == .empty, "\(spelling)")
            let valueNew = try #require(value.asNew(now: instant(), missingColumns: []))
            #expect(valueNew.record.currentValueCents == nil)
            #expect(valueNew.defaultedFieldCount == 0, "\(spelling)")

            let year = try fullRow(["Year": spelling])
            #expect(year.year == .empty, "\(spelling)")
            let yearNew = try #require(year.asNew(now: instant(), missingColumns: []))
            #expect(yearNew.record.year == nil)
            #expect(yearNew.defaultedFieldCount == 0, "\(spelling)")

            // A required cell of a new row: the blank default, counted once.
            let price = try fullRow(["Purchase Price": spelling])
            #expect(price.purchasePrice == .empty, "\(spelling)")
            let priceNew = try #require(price.asNew(now: instant(), missingColumns: []))
            #expect(priceNew.record.purchasePriceCents == 0)
            #expect(priceNew.defaultedFieldCount == 1, "\(spelling)")

            let nameless = try fullSheet([fullCells(["Name": spelling])])
            #expect(nameless.rows.isEmpty, "\(spelling)")
            #expect(nameless.skipped == [SkippedRow(rowNumber: 2, reason: "no name")], "\(spelling)")
        }
    }

    // MARK: - Criterion 15: totals rows, nameless rows, blank rows

    @Test func totalsRowsAreLeftOutAnywhereLabelledOrNotAndNeverSkipped() throws {
        let header = ["Name", "Category", "Purchase Price", "Purchase Date", "Current Value"]
        let sheet = try sheet(header: header, [
            ["Nikon F3", "Cameras", "$300.00", "2024-01-02", "$350.00"],   // 2
            ["", "", "$300.00", "", "$350.00"],                             // 3
            ["Total", "", "$300.00", "", ""],                               // 4
            ["Leica M3", "Cameras", "$1,250.00", "2024-01-02", ""],         // 5
            ["totals", "", "$1,550.00", "", "$350.00"],                     // 6
            [" Subtotal ", "", "$1,550.00"],                                // 7
            ["SUM", "", "", "", "1550"],                                    // 8
            ["Rega Planar 2", "Turntables", "$450.00", "2024-01-02", ""],  // 9
            ["", "", "$2,000.00", "", "$350.00"],                           // 10
        ])
        #expect(sheet.rows.map(\.rowNumber) == [2, 5, 9])
        #expect(sheet.totalsRowNumbers == [3, 4, 6, 7, 8, 10])
        #expect(sheet.skipped.isEmpty)
    }

    @Test func aSumUnderAnUnknownColumnIsStillATotalsRow() throws {
        let sheet = try sheet(header: ["Name", "Purchase Price", "Purchase Date", "Running Total", "Checked"], [
            ["Nikon F3", "$300.00", "2024-01-02", "$300.00", "yes"],
            ["", "$300.00", "", "$300.00", "yes"],
        ])
        #expect(sheet.rows.map(\.rowNumber) == [2])
        #expect(sheet.totalsRowNumbers == [3])
        #expect(sheet.skipped.isEmpty)
        #expect(sheet.unusedColumns == ["Running Total", "Checked"])
    }

    @Test func aTotalsShapedRowWithAnythingElseFilledIsNotATotalsRow() throws {
        let sheet = try sheet(header: ["Name", "Category", "Purchase Price", "Purchase Date", "Current Value"], [
            ["", "Cameras", "$300.00", "", ""],       // 2: a filled Category
            ["", "", "$300.00", "2024-01-02", ""],    // 3: a nameless row with a date
            ["", "", "$300.00", "", "lots"],          // 4: a money cell that is no amount
            ["Total", "", "$5.00", "2024-01-02", ""], // 5: named Total, with a date
        ])
        #expect(sheet.totalsRowNumbers.isEmpty)
        #expect(sheet.skipped == [2, 3, 4].map { SkippedRow(rowNumber: $0, reason: "no name") })
        #expect(sheet.rows.map(\.rowNumber) == [5])
        #expect(sheet.rows.first?.name == .value("Total"))
    }

    @Test func aTotalsShapedRowWithATroveIDIsANamelessRowThatIsKept() throws {
        let id = UUID()
        let sheet = try sheet(header: ["Name", "Purchase Price", "Purchase Date", "Trove ID"], [
            ["", "$300.00", "", id.uuidString.lowercased()],
            ["", "$300.00", "", "not-a-code"],
        ])
        #expect(sheet.totalsRowNumbers.isEmpty)
        #expect(sheet.rows.map(\.rowNumber) == [2])
        #expect(sheet.rows.first?.troveID == .value(id))
        #expect(sheet.rows.first?.name == .empty)
        #expect(sheet.rows.first?.asNew(now: instant(), missingColumns: []) == nil)
        #expect(sheet.skipped == [SkippedRow(rowNumber: 3, reason: "no name")])
    }

    @Test func aRowOfNotApplicablesOrOfUnknownColumnsOnlyDropsSilently() throws {
        let sheet = try sheet(header: ["Name", "Purchase Price", "Purchase Date", "Remarks"], [
            ["N/A", "n/a", "#N/A"],
            ["", "", "", "see the binder"],
            ["  ", "N/A", "", "N/A"],
        ])
        #expect(sheet.rows.isEmpty)
        #expect(sheet.skipped.isEmpty)
        #expect(sheet.totalsRowNumbers.isEmpty)
    }

    // MARK: - The header's width

    @Test func extraCellsAgainstTheHeaderSkipAndShortRowsPad() throws {
        let sheet = try sheet(header: ["Name", "Purchase Price", "Purchase Date", "Remarks"], [
            ["Nikon F3", "$300.00", "2024-01-02", "mint box"],          // 2: the header's width
            ["Leica M3", "$300.00", "2024-01-02", "mint box", "stray"], // 3: one more
            ["Rega Planar 2", "$450.00"],                               // 4: short
        ])
        #expect(sheet.skipped == [SkippedRow(rowNumber: 3, reason: "more columns than the header")])
        #expect(sheet.rows.map(\.rowNumber) == [2, 4])
        let short = try #require(sheet.rows.last)
        #expect(short.purchaseDate == .empty)
        let new = try #require(short.asNew(now: instant(), missingColumns: sheet.missingDefaultColumns))
        #expect(new.record.purchaseDate == instant())
        #expect(new.defaultedFieldCount == 1)
    }

    // MARK: - The slash order is the whole file's

    @Test func theSlashOrderComesFromEveryDateNotTheFirst() throws {
        let sheet = try sheet(header: ["Name", "Purchase Price", "Purchase Date", "Sold Date"], [
            ["Nikon F3", "$300.00", "3/4/2024"],
            ["Leica M3", "$300.00", "1/2/2024", "25/12/2024"],
        ])
        #expect(sheet.regionDateOrder == nil)
        #expect(sheet.rows.map(\.purchaseDate) == [.value(day(2024, 4, 3)), .value(day(2024, 2, 1))])
        #expect(sheet.rows.last?.soldDate == .value(day(2024, 12, 25)))
    }

    @Test func theRegionDecidesOnlyWhenTheFileCannot() throws {
        let sheet = try sheet(header: ["Name", "Purchase Price", "Purchase Date"], [
            ["Nikon F3", "$300.00", "3/4/2024"],
        ], locale: Locale(identifier: "en_GB"))
        #expect(sheet.regionDateOrder == .dayFirst)
        #expect(sheet.rows.first?.purchaseDate == .value(day(2024, 4, 3)))
    }

    // MARK: - asNew: today's field policy, exactly

    @Test func asNewCountsAndDefaultsExactlyAsTodaysPreview() throws {
        // Rows without N/A and without a defaulted purchase date — the two
        // places the sheet means to differ from `itemsPreview` — read the
        // same through both paths, cell for cell and count for count.
        let rows = [
            fullCells(),
            fullCells(["Purchase Price": "", "Desire to Keep": "9", "Condition": "mint",
                       "Currency": "dollars", "Current Value": "abc"]),
            fullCells(["Reverb Product ID": "abc", "Year": "75", "Bought": "maybe"]),
            fullCells(["Sold Date": "2025-06-01", "Sale Price": "1,200.00", "Sold At": "Reverb",
                       "Sale Note": "local pickup"]),
            fullCells(["Sold Date": "2025-06-01", "Sold At": "Reverb", "Sale Note": "half"]),
            fullCells(["Currency": "", "Purchase Location": " ", "Bought": "Used", "Desire to Keep": ""]),
        ]
        let preview = try ImportSchema.itemsPreview(from: itemsFile(rows), timeZone: utc())
        let sheet = try ImportSchema.itemsSheet(from: itemsFile(rows), timeZone: utc(), locale: usLocale())
        let new = sheet.rows.compactMap { $0.asNew(now: instant(), missingColumns: sheet.missingDefaultColumns) }

        #expect(new.count == preview.validated.count)
        #expect(new.map(\.defaultedFieldCount) == preview.validated.map(\.defaultedFieldCount))
        #expect(new.map(\.defaultedFieldCount) == [0, 5, 3, 0, 1, 1])
        #expect(new.map(\.rowNumber) == preview.validated.map(\.rowNumber))
        #expect(
            new.map { ExportSchema.row(from: $0.record, timeZone: utc()) }
                == preview.validated.map { ExportSchema.row(from: $0.record, timeZone: utc()) }
        )
    }

    @Test func anUnreadableTroveIDCountsOnce() throws {
        let sheet = try sheet(header: ExportSchema.itemHeaders + [ExportSchema.troveIDHeader], [
            fullCells() + [""],
            fullCells() + ["not-a-code"],
        ])
        #expect(sheet.rows.map(\.troveID) == [.empty, .unreadable])
        let new = sheet.rows.compactMap { $0.asNew(now: instant(), missingColumns: []) }
        #expect(new.map(\.defaultedFieldCount) == [0, 1])
    }

    // MARK: - Helpers

    private func utc() -> TimeZone { TimeZone(identifier: "UTC")! }

    private func usLocale() -> Locale { Locale(identifier: "en_US") }

    /// A fixed past instant, the default date `asNew` is handed.
    private func instant() -> Date { day(2020, 7, 1) }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc()
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func sheet(
        header: [String], _ dataRows: [[String]], locale: Locale? = nil
    ) throws -> ImportSheet<ItemImportRow> {
        let rows = [CSVRow(number: 1, cells: header)]
            + dataRows.enumerated().map { CSVRow(number: $0.offset + 2, cells: $0.element) }
        return try ImportSchema.itemsSheet(from: rows, timeZone: utc(), locale: locale ?? usLocale())
    }

    private func itemsFile(_ dataRows: [[String]]) -> [CSVRow] {
        [CSVRow(number: 1, cells: ExportSchema.itemHeaders)]
            + dataRows.enumerated().map { CSVRow(number: $0.offset + 2, cells: $0.element) }
    }

    private func fullSheet(_ dataRows: [[String]]) throws -> ImportSheet<ItemImportRow> {
        try sheet(header: ExportSchema.itemHeaders, dataRows)
    }

    /// One row of the full items layout, read.
    private func fullRow(_ changes: [String: String]) throws -> ItemImportRow {
        let sheet = try fullSheet([fullCells(changes)])
        return try #require(sheet.rows.first)
    }

    /// One fully valid row in `ExportSchema.itemHeaders` order, keyed by
    /// header so a test reads as the change it makes.
    private func fullCells(_ changes: [String: String] = [:]) -> [String] {
        var byHeader = [
            "Name": "Leica M6",
            "Category": "Photography/Cameras",
            "Purchase Price": "2900.00",
            "Currency": "USD",
            "Purchase Date": "2026-03-09",
            "Purchase Location": "KEH",
            "Current Value": "3450.00",
            "Desire to Keep": "5",
            "Condition": "excellent",
            "Condition Notes": "",
            "Serial Number": "1234567",
            "Notes": "",
            "Reverb Product ID": "160322",
            "Year": "1984",
            "Sold Date": "",
            "Sale Price": "",
            "Sold At": "",
            "Sale Note": "",
            "Bought": "new",
        ]
        byHeader.merge(changes) { _, new in new }
        return ExportSchema.itemHeaders.map { byHeader[$0]! }
    }

    private func fixtureSheet() throws -> ImportSheet<ItemImportRow> {
        try ImportSchema.itemsSheet(from: try CSVParser.parse(fixtureText()), timeZone: utc(), locale: usLocale())
    }

    private func fixtureText(file: StaticString = #filePath) throws -> String {
        let url = URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "docs/samples/items-hand-kept.csv")
        return try String(contentsOf: url, encoding: .utf8)
    }
}

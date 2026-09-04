import Foundation
import Testing
@testable import Trove

/// T002's guards: row shaping — trailing-empty stripping and silent
/// blank-row dropping (plan §Row pipeline, steps 1–2; spec's amended
/// transport tolerance). The header gate and field policy get their own
/// suites as the pipeline grows.
struct ImportSchemaTests {
    // MARK: - Trailing-empty stripping

    @Test func trailingEmptyCellsAreStripped() {
        let shaped = ImportSchema.shaped([CSVRow(number: 2, cells: ["a", "b", "", ""])])
        #expect(shaped == [CSVRow(number: 2, cells: ["a", "b"])])
    }

    @Test func interiorEmptyCellsAreKept() {
        // Interior emptiness means something (an empty Current Value is
        // "unvalued"); only the trailing run is transport damage.
        let shaped = ImportSchema.shaped([CSVRow(number: 2, cells: ["a", "", "b", ""])])
        #expect(shaped == [CSVRow(number: 2, cells: ["a", "", "b"])])
    }

    @Test func whitespaceOnlyCellsAreNotStripped() {
        // Whitespace is the field policy's question (blank means
        // empty-after-trim there); stripping removes only truly empty
        // cells, so a trailing " " survives to be judged later.
        let shaped = ImportSchema.shaped([CSVRow(number: 2, cells: ["a", " "])])
        #expect(shaped == [CSVRow(number: 2, cells: ["a", " "])])
    }

    // MARK: - Blank rows

    @Test func blankAndAllEmptyRowsDropSilently() {
        // A blank line parses as one empty cell; an all-commas line as
        // several. Both shape to nothing — no row, no report.
        let shaped = ImportSchema.shaped([
            CSVRow(number: 1, cells: ["A"]),
            CSVRow(number: 2, cells: [""]),
            CSVRow(number: 3, cells: ["", "", ""]),
            CSVRow(number: 4, cells: ["B"]),
        ])
        #expect(shaped == [
            CSVRow(number: 1, cells: ["A"]),
            CSVRow(number: 4, cells: ["B"]),
        ])
    }

    @Test func survivorsKeepTheirSpreadsheetNumbers() {
        // Dropping must never renumber: a skip reported for the row after
        // a blank line has to point where Numbers points.
        let shaped = ImportSchema.shaped([
            CSVRow(number: 1, cells: ["header"]),
            CSVRow(number: 2, cells: [""]),
            CSVRow(number: 3, cells: ["data"]),
        ])
        #expect(shaped.map(\.number) == [1, 3])
    }

    // MARK: - The amended criterion-3 transport fixture

    /// A canonical items file, then the same file with four trailing
    /// commas on every line (header included) and a blank line after each
    /// row — the shape a spreadsheet re-save leaves behind. Shaping must
    /// make the damaged file's rows exactly the clean file's rows.
    @Test func aResavedFileWithTrailingColumnsAndBlankLinesShapesClean() throws {
        let table = ExportSchema.itemsTable([
            record(name: "Leica M6", notes: "body, cap"),
            record(name: "Blues Junior", notes: ""),
        ])
        let clean = CSVWriter.write(table)
        // Every row boundary gains trailing commas and a following blank
        // line. Fixture data deliberately has no embedded CRLF, so the
        // transform touches only real row endings (the embedded comma in
        // the notes field is quoted and untouched).
        let damaged = clean.replacingOccurrences(of: "\r\n", with: ",,,,\r\n\r\n")

        let cleanRows = ImportSchema.shaped(try CSVParser.parse(clean))
        let damagedRows = ImportSchema.shaped(try CSVParser.parse(damaged))

        #expect(damagedRows.map(\.cells) == cleanRows.map(\.cells))
        // Guard against two-wrongs-equal: the clean side is also pinned to
        // an explicit expectation, not just to whatever both pipelines
        // happen to agree on. The empty trailing Notes cell strips here —
        // the field policy pads it back (strip-then-pad identity).
        #expect(cleanRows.count == 3)
        #expect(cleanRows[0].cells == ExportSchema.itemHeaders)
        #expect(cleanRows[1].cells[0] == "Leica M6")
        #expect(cleanRows[1].cells.last == "body, cap")
        // Row 2's trailing empty run is three cells — Condition Notes,
        // Serial Number, and Notes are all nil — so shaping keeps the nine
        // columns through Condition. Interior empties (Purchase Location,
        // Current Value) survive, pinned by the exact count.
        #expect(cleanRows[2].cells.count == 9)
        #expect(cleanRows[2].cells[5].isEmpty && cleanRows[2].cells[6].isEmpty)
        // Blank lines shifted the damaged file's numbering; survivors keep
        // the numbers the damaged file actually shows in a spreadsheet.
        #expect(damagedRows.map(\.number) == [1, 3, 5])
    }

    // MARK: - Header gate (T003)

    @Test func exactHeadersPassBothGates() throws {
        try ImportSchema.requireItemsHeader(CSVRow(number: 1, cells: ExportSchema.itemHeaders))
        try ImportSchema.requireWishlistHeader(CSVRow(number: 1, cells: ExportSchema.wishlistHeaders))
    }

    @Test func whitespacePaddedHeaderCellsPass() throws {
        try ImportSchema.requireItemsHeader(
            CSVRow(number: 1, cells: ExportSchema.itemHeaders.map { " \($0)\t" })
        )
    }

    /// The T002 tie: a re-saved header line with trailing empty columns,
    /// run through the real parse-then-shape pipeline, still gates clean.
    @Test func aStrippedResavedHeaderRowPassesTheGate() throws {
        let line = ExportSchema.itemHeaders.joined(separator: ",") + ",,,,\r\n"
        let shaped = ImportSchema.shaped(try CSVParser.parse(line))
        try ImportSchema.requireItemsHeader(try #require(shaped.first))
    }

    @Test func missingExtraRenamedAndReorderedColumnsAllMismatch() {
        var missing = ExportSchema.itemHeaders
        missing.removeLast()
        var extra = ExportSchema.itemHeaders
        extra.append("Photos")
        var renamed = ExportSchema.itemHeaders
        renamed[0] = "Item Name"
        var reordered = ExportSchema.itemHeaders
        reordered.swapAt(0, 1)

        for cells in [missing, extra, renamed, reordered] {
            #expect(throws: ImportSchema.HeaderError.mismatch) {
                try ImportSchema.requireItemsHeader(CSVRow(number: 1, cells: cells))
            }
        }
    }

    /// Criterion 4's mechanism: the other list's exact headers are
    /// recognized as such, not lumped into "wrong columns".
    @Test func theOtherListsHeadersAreRecognizedAsWrongList() {
        #expect(throws: ImportSchema.HeaderError.wrongList) {
            try ImportSchema.requireItemsHeader(CSVRow(number: 1, cells: ExportSchema.wishlistHeaders))
        }
        #expect(throws: ImportSchema.HeaderError.wrongList) {
            try ImportSchema.requireWishlistHeader(CSVRow(number: 1, cells: ExportSchema.itemHeaders))
        }
    }

    // MARK: - Money (T004)

    @Test func canonicalMoneyFormsParseCentExact() {
        #expect(ImportSchema.cents(from: "0.00") == 0)
        #expect(ImportSchema.cents(from: "0.01") == 1)
        #expect(ImportSchema.cents(from: "9.99") == 999)
        #expect(ImportSchema.cents(from: "1250.00") == 125_000)
        #expect(ImportSchema.cents(from: "9999999999.99") == 999_999_999_999)
    }

    @Test func bareIntegersAreWholeAmountsAndLeadingZerosAreJustDigits() {
        #expect(ImportSchema.cents(from: "1250") == 125_000)
        #expect(ImportSchema.cents(from: "007") == 700)
        #expect(ImportSchema.cents(from: "5.5") == 550)
    }

    /// The reader is deliberately stricter than `Decimal(string:)`, which
    /// stops silently at a thousands separator — the exact leniency the
    /// spec forbids.
    @Test(arguments: ["1250.", ".50", "1250.000", "+5.00", "-5.00", "$5",
                      "1,250.00", "1 250,00", "5..0", "", " 5.00", "5.00 ", "5.0a"])
    func nonCanonicalMoneyIsRejected(field: String) {
        #expect(ImportSchema.cents(from: field) == nil)
    }

    @Test func moneyOverflowRejectsWithoutTrapping() {
        #expect(ImportSchema.cents(from: String(repeating: "9", count: 25)) == nil)
        // The *100 scaling can overflow even when the digit scan doesn't.
        #expect(ImportSchema.cents(from: "9223372036854775807") == nil)
    }

    /// The two preserved invariants: writer→parser identity across a cent
    /// spread, and equivalence with `Money.cents(from: Decimal(string:))`
    /// on canonical forms — 011's recorded parse-side invariant, corrected
    /// in place to name this parser as the path.
    @Test(arguments: [0, 1, 999, 10_000, 123_456_789, 999_999_999_99])
    func writerMoneyRoundTripsThroughTheParser(cents: Int) throws {
        let written = ExportSchema.money(cents: cents)
        #expect(ImportSchema.cents(from: written) == cents)
        let decimal = try #require(Decimal(string: written))
        #expect(Money.cents(from: decimal) == cents)
    }

    // MARK: - Dates (T004)

    @Test func canonicalDaysParseAndRoundTripThroughTheWriter() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let parsed = try #require(ImportSchema.day(from: "2026-03-09", timeZone: utc))
        #expect(ExportSchema.day(from: parsed, timeZone: utc) == "2026-03-09")
    }

    /// T019/B1's pin, from the parse direction: the parser's calendar is
    /// Gregorian by construction. The epoch is the least ambiguous instant
    /// — a Buddhist-calendar leak would land ~543 years away.
    @Test func dayIsAlwaysGregorianRegardlessOfDeviceCalendar() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        #expect(ImportSchema.day(from: "1970-01-01", timeZone: utc) == Date(timeIntervalSince1970: 0))
    }

    @Test(arguments: ["2026-1-5", "26-01-05", "2026/01/05", "2026-01-05 ",
                      "01-05-2026", "2026-01", "", "yyyy-MM-dd"])
    func nonCanonicalDateShapesAreRejected(field: String) {
        #expect(ImportSchema.day(from: field) == nil)
    }

    /// Gregorian `date(from:)` normalizes Feb 30 into March rather than
    /// failing; the components round-trip is what actually rejects it.
    @Test(arguments: ["2026-02-30", "2026-13-01", "2026-00-10", "2025-02-29", "2026-04-31"])
    func impossibleDatesAreRejected(field: String) {
        #expect(ImportSchema.day(from: field) == nil)
    }

    /// The day local midnight doesn't exist: Chile's 2026 spring-forward
    /// (first Sunday of September, per current tzdata) jumps 00:00→01:00.
    /// `date(from:)` answers the first valid instant and the day still
    /// round-trips — the claim is the round trip, not the hour.
    @Test func aDayWhoseMidnightDoesNotExistStillResolves() throws {
        let santiago = try #require(TimeZone(identifier: "America/Santiago"))
        let parsed = try #require(ImportSchema.day(from: "2026-09-06", timeZone: santiago))
        #expect(ExportSchema.day(from: parsed, timeZone: santiago) == "2026-09-06")
    }

    // MARK: - Desire, condition, currency (T004)

    @Test func desireParsesIntegersInsideTheGivenScale() {
        #expect(ImportSchema.desire(from: "1", in: 1...5) == 1)
        #expect(ImportSchema.desire(from: "5", in: 1...5) == 5)
        #expect(ImportSchema.desire(from: "3", in: 1...3) == 3)
        #expect(ImportSchema.desire(from: "0", in: 1...5) == nil)
        #expect(ImportSchema.desire(from: "6", in: 1...5) == nil)
        #expect(ImportSchema.desire(from: "4", in: 1...3) == nil)
        #expect(ImportSchema.desire(from: "3.0", in: 1...5) == nil)
        #expect(ImportSchema.desire(from: "three", in: 1...5) == nil)
        #expect(ImportSchema.desire(from: "", in: 1...5) == nil)
    }

    @Test func conditionMatchesCaseInsensitively() {
        #expect(ImportSchema.condition(from: "excellent") == .excellent)
        #expect(ImportSchema.condition(from: "Excellent") == .excellent)
        #expect(ImportSchema.condition(from: "BROKEN") == .broken)
        #expect(ImportSchema.condition(from: "mint") == nil)
        #expect(ImportSchema.condition(from: "") == nil)
    }

    @Test func currencyIsThreeLettersUppercased() {
        #expect(ImportSchema.currencyCode(from: "USD") == "USD")
        #expect(ImportSchema.currencyCode(from: "eur") == "EUR")
        #expect(ImportSchema.currencyCode(from: "Usd") == "USD")
        #expect(ImportSchema.currencyCode(from: "US") == nil)
        #expect(ImportSchema.currencyCode(from: "USDD") == nil)
        #expect(ImportSchema.currencyCode(from: "U5D") == nil)
        #expect(ImportSchema.currencyCode(from: "") == nil)
    }

    // MARK: - Items row validation (T005)

    @Test func aFullyValidRowValidatesWithNoDefaults() throws {
        let preview = try ImportSchema.itemsPreview(from: itemsFile([cells()]), timeZone: utc())
        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        let row = try #require(preview.validated.first)
        #expect(row.rowNumber == 2)
        #expect(row.record.name == "Leica M6")
        #expect(row.record.purchasePriceCents == 290_000)
        #expect(row.record.currentValueCents == 345_000)
        #expect(row.record.conditionRawValue == "excellent")
        #expect(row.record.purchaseLocation == "KEH")
        #expect(row.record.firstPhotoID == nil)
    }

    @Test func blankAndWhitespaceOnlyNamesSkipTheRow() throws {
        for name in ["", "   ", "\t"] {
            let preview = try ImportSchema.itemsPreview(
                from: itemsFile([cells(["Name": name])]), timeZone: utc()
            )
            #expect(preview.validated.isEmpty)
            #expect(preview.skipped == [SkippedRow(rowNumber: 2, reason: "no name")])
        }
    }

    @Test func extraContentCellsSkipTheRow() throws {
        let preview = try ImportSchema.itemsPreview(
            from: itemsFile([cells() + ["stray"]]), timeZone: utc()
        )
        #expect(preview.validated.isEmpty)
        #expect(preview.skipped == [
            SkippedRow(rowNumber: 2, reason: "more columns than the template"),
        ])
    }

    @Test func underLengthRowsPadAndFollowTheBlankPolicy() throws {
        // Only the first five columns survive transport: Name, Category,
        // Purchase Price, Currency, Purchase Date. The padded tail is
        // blank-silent for optionals, defaulted-and-counted for Desire to
        // Keep and Condition.
        let short = Array(cells().prefix(5))
        let preview = try ImportSchema.itemsPreview(from: itemsFile([short]), timeZone: utc())
        let row = try #require(preview.validated.first)
        #expect(row.record.currentValueCents == nil)
        #expect(row.record.purchaseLocation == nil)
        #expect(row.record.notes == nil)
        #expect(row.record.desireToKeep == 3)
        #expect(row.record.conditionRawValue == "excellent")
        #expect(row.defaultedFieldCount == 2)
    }

    @Test func blankOptionalFieldsAndBlankCurrencyAreSilent() throws {
        let preview = try ImportSchema.itemsPreview(from: itemsFile([cells([
            "Purchase Location": "", "Current Value": "", "Currency": "",
            "Condition Notes": "", "Serial Number": "", "Notes": " ",
        ])]), timeZone: utc())
        let row = try #require(preview.validated.first)
        #expect(preview.defaultedFieldCount == 0)
        #expect(row.record.currencyCode == "USD")
        #expect(row.record.currentValueCents == nil)
        #expect(row.record.purchaseLocation == nil)
        #expect(row.record.notes == nil)
    }

    @Test func requiredBlanksAndUnparseablesDefaultAndCount() throws {
        let preview = try ImportSchema.itemsPreview(from: itemsFile([cells([
            "Purchase Price": "", "Purchase Date": "someday", "Desire to Keep": "9",
            "Condition": "mint", "Currency": "dollars", "Current Value": "n/a",
        ])]), timeZone: utc())
        let row = try #require(preview.validated.first)
        #expect(row.defaultedFieldCount == 6)
        #expect(preview.defaultedFieldCount == 6)
        #expect(row.record.purchasePriceCents == 0)
        #expect(row.record.desireToKeep == 3)
        #expect(row.record.conditionRawValue == "excellent")
        #expect(row.record.currencyCode == "USD")
        #expect(row.record.currentValueCents == nil)
        #expect(abs(row.record.purchaseDate.timeIntervalSinceNow) < 60)
    }

    @Test func currentValueZeroAndBlankStayDistinct() throws {
        let preview = try ImportSchema.itemsPreview(
            from: itemsFile([cells(["Current Value": "0.00"]), cells(["Current Value": ""])]),
            timeZone: utc()
        )
        #expect(preview.validated[0].record.currentValueCents == 0)
        #expect(preview.validated[1].record.currentValueCents == nil)
        #expect(preview.defaultedFieldCount == 0)
    }

    @Test func textFieldsNormalizeExactlyAsTheFormWould() throws {
        let preview = try ImportSchema.itemsPreview(from: itemsFile([cells([
            "Name": "  Leica M6  ", "Category": " Photography/Cameras ",
            "Serial Number": " 1234567 ",
        ])]), timeZone: utc())
        let row = try #require(preview.validated.first)
        #expect(row.record.name == "Leica M6")
        #expect(row.record.categoryPath == "Photography/Cameras")
        #expect(row.record.serialNumber == "1234567")
    }

    /// The criterion-5 numbering fixture: an embedded-newline row (two
    /// physical lines, one spreadsheet row) followed by a nameless row —
    /// the skip must be reported as row 3, the number Numbers shows.
    @Test func skipReportsUseSpreadsheetNumbersPastEmbeddedNewlines() throws {
        let file = ExportSchema.itemHeaders.joined(separator: ",") + "\r\n"
            + "\"Two\nLines\",Cat,1.00,USD,2026-01-01,,,3,good,,,\r\n"
            + ",Cat,1.00,USD,2026-01-01,,,3,good,,,\r\n"
        let preview = try ImportSchema.itemsPreview(from: try CSVParser.parse(file), timeZone: utc())
        #expect(preview.validated.map(\.rowNumber) == [2])
        #expect(preview.skipped == [SkippedRow(rowNumber: 3, reason: "no name")])
    }

    @Test func anEmptyFileFailsTheGateNotTheRowPolicy() {
        #expect(throws: ImportSchema.HeaderError.mismatch) {
            try ImportSchema.itemsPreview(from: [], timeZone: utc())
        }
    }

    @Test func aWishlistFileFailsTheItemsPreviewAsWrongList() {
        #expect(throws: ImportSchema.HeaderError.wrongList) {
            try ImportSchema.itemsPreview(
                from: [CSVRow(number: 1, cells: ExportSchema.wishlistHeaders)],
                timeZone: utc()
            )
        }
    }

    /// Criterion 2's unit half: export → write → parse → validate → the
    /// same rows the writer would serialize for the originals, zero skips,
    /// zero defaults. Serialization equality, not record equality —
    /// `firstPhotoID` can't round-trip through CSV (plan §Records).
    @Test func aTroveExportRoundTripsLosslessly() throws {
        let zone = utc()
        let originals = [
            record(name: "Leica M6", notes: "body, cap — \"user grade\"\nno box"),
            record(name: "Blues Junior", notes: ""),
            ItemExportRecord(
                name: "SM7B", categoryPath: "Audio/Mics", purchasePriceCents: 39_900,
                currencyCode: "USD", purchaseDate: Date(timeIntervalSince1970: 1_600_000_000),
                purchaseLocation: "Sweetwater", currentValueCents: 35_000, desireToKeep: 5,
                conditionRawValue: "new", conditionNotes: "still sealed",
                serialNumber: "SN=1+2", notes: nil, reverbProductID: nil, year: nil, firstPhotoID: nil
            ),
        ]
        let text = CSVWriter.write(ExportSchema.itemsTable(originals, timeZone: zone))
        let preview = try ImportSchema.itemsPreview(from: try CSVParser.parse(text), timeZone: zone)

        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        #expect(preview.validated.count == originals.count)
        for (validated, original) in zip(preview.validated, originals) {
            #expect(
                ExportSchema.row(from: validated.record, timeZone: zone)
                    == ExportSchema.row(from: original, timeZone: zone)
            )
        }
    }

    /// The closed loop plan.md calls the highest-value test: the blank
    /// template's own bytes plus one hand-appended canonical row, through
    /// the production pipeline, yields exactly that row — writer and
    /// parser tied together with neither as the other's oracle.
    @Test func theBlankTemplatePlusOneHandRowImportsCleanly() throws {
        let template = CSVWriter.write(CSVTable(headers: ExportSchema.itemHeaders, rows: []))
        let file = template + "Strat,Music/Guitars,1200.00,USD,2025-06-01,,,4,good,,,\r\n"
        let preview = try ImportSchema.itemsPreview(from: try CSVParser.parse(file), timeZone: utc())

        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        let row = try #require(preview.validated.first)
        #expect(preview.validated.count == 1)
        #expect(row.record.name == "Strat")
        #expect(row.record.purchasePriceCents == 120_000)
        #expect(row.record.desireToKeep == 4)
        #expect(row.record.conditionRawValue == "good")
        #expect(row.record.currentValueCents == nil)
    }

    // MARK: - Wishlist row validation (T006)

    @Test func aFullyValidWishlistRowValidatesWithNoDefaults() throws {
        let preview = try ImportSchema.wishlistPreview(
            from: wishlistFile([wishlistCells()]), timeZone: utc()
        )
        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        let row = try #require(preview.validated.first)
        #expect(row.record.name == "OM-1")
        #expect(row.record.estimatedCostCents == 45_000)
        #expect(row.record.desireToOwn == 3)
        // Added restores the wish's creation date, not the import moment.
        #expect(row.record.createdAt == ImportSchema.day(from: "2024-05-10", timeZone: utc()))
    }

    @Test func wishlistRowFatalsMatchTheItemsRules() throws {
        let preview = try ImportSchema.wishlistPreview(
            from: wishlistFile([
                wishlistCells(["Name": "  "]),
                wishlistCells() + ["stray"],
            ]),
            timeZone: utc()
        )
        #expect(preview.validated.isEmpty)
        #expect(preview.skipped == [
            SkippedRow(rowNumber: 2, reason: "no name"),
            SkippedRow(rowNumber: 3, reason: "more columns than the template"),
        ])
    }

    @Test func wishlistRequiredBlanksDefaultAndCountAndBlankCurrencyIsSilent() throws {
        let preview = try ImportSchema.wishlistPreview(
            from: wishlistFile([wishlistCells([
                "Estimated Cost": "", "Desire to Own": "5", "Added": "", "Currency": "",
            ])]),
            timeZone: utc()
        )
        let row = try #require(preview.validated.first)
        // Cost, out-of-scale desire (5 on a 1–3 scale), and Added count;
        // blank currency is silent — same rule as items.
        #expect(row.defaultedFieldCount == 3)
        #expect(row.record.estimatedCostCents == 0)
        #expect(row.record.desireToOwn == 2)
        #expect(row.record.currencyCode == "USD")
        #expect(abs(row.record.createdAt.timeIntervalSinceNow) < 60)
    }

    @Test func anItemsFileFailsTheWishlistPreviewAsWrongList() {
        #expect(throws: ImportSchema.HeaderError.wrongList) {
            try ImportSchema.wishlistPreview(
                from: [CSVRow(number: 1, cells: ExportSchema.itemHeaders)],
                timeZone: utc()
            )
        }
    }

    /// The wishlist round trip — serialization equality, zero skips, zero
    /// defaults, `Added` preserved across the loop.
    @Test func aWishlistExportRoundTripsLosslessly() throws {
        let zone = utc()
        let originals = [
            WishlistExportRecord(
                name: "OM-1", categoryPath: "Photography/Cameras",
                estimatedCostCents: 45_000, currencyCode: "USD", desireToOwn: 3,
                createdAt: Date(timeIntervalSince1970: 1_500_000_000),
                notes: "wants: \"clean glass\", meter\nworking", reverbProductID: nil, year: nil, firstPhotoID: nil
            ),
            WishlistExportRecord(
                name: "Big Muff", categoryPath: "Music/Pedals",
                estimatedCostCents: 9_900, currencyCode: "USD", desireToOwn: 1,
                createdAt: Date(timeIntervalSince1970: 1_650_000_000),
                notes: nil, reverbProductID: nil, year: nil, firstPhotoID: nil
            ),
        ]
        let text = CSVWriter.write(ExportSchema.wishlistTable(originals, timeZone: zone))
        let preview = try ImportSchema.wishlistPreview(from: try CSVParser.parse(text), timeZone: zone)

        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        #expect(preview.validated.count == originals.count)
        for (validated, original) in zip(preview.validated, originals) {
            #expect(
                ExportSchema.row(from: validated.record, timeZone: zone)
                    == ExportSchema.row(from: original, timeZone: zone)
            )
        }
    }

    @Test func theBlankWishlistTemplatePlusOneHandRowImportsCleanly() throws {
        let template = CSVWriter.write(CSVTable(headers: ExportSchema.wishlistHeaders, rows: []))
        let file = template + "Jazzmaster,Music/Guitars,1800.00,USD,2,2026-01-15,someday fund\r\n"
        let preview = try ImportSchema.wishlistPreview(from: try CSVParser.parse(file), timeZone: utc())

        #expect(preview.skipped.isEmpty)
        #expect(preview.defaultedFieldCount == 0)
        let row = try #require(preview.validated.first)
        #expect(preview.validated.count == 1)
        #expect(row.record.name == "Jazzmaster")
        #expect(row.record.estimatedCostCents == 180_000)
        #expect(row.record.desireToOwn == 2)
        #expect(row.record.notes == "someday fund")
        #expect(row.record.createdAt == ImportSchema.day(from: "2026-01-15", timeZone: utc()))
    }

    // MARK: - Fixtures

    private func utc() -> TimeZone { TimeZone(identifier: "UTC")! }

    private func wishlistFile(_ dataRows: [[String]]) -> [CSVRow] {
        [CSVRow(number: 1, cells: ExportSchema.wishlistHeaders)]
            + dataRows.enumerated().map { CSVRow(number: $0.offset + 2, cells: $0.element) }
    }

    private func wishlistCells(_ changes: [String: String] = [:]) -> [String] {
        var byHeader = [
            "Name": "OM-1",
            "Category": "Photography/Cameras",
            "Estimated Cost": "450.00",
            "Currency": "USD",
            "Desire to Own": "3",
            "Added": "2024-05-10",
            "Notes": "meter working",
        ]
        for (header, value) in changes { byHeader[header] = value }
        return ExportSchema.wishlistHeaders.map { byHeader[$0]! }
    }

    /// A canonical items file as parsed rows: header from the pinned array,
    /// data rows numbered the way a spreadsheet numbers them.
    private func itemsFile(_ dataRows: [[String]]) -> [CSVRow] {
        [CSVRow(number: 1, cells: ExportSchema.itemHeaders)]
            + dataRows.enumerated().map { CSVRow(number: $0.offset + 2, cells: $0.element) }
    }

    /// One fully valid row, keyed by header so tests read as the change
    /// they make — and ordered by the pinned array, so a schema growth
    /// breaks this fixture by compile-adjacent failure, not silently.
    private func cells(_ changes: [String: String] = [:]) -> [String] {
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
            "Notes": "body only",
        ]
        for (header, value) in changes { byHeader[header] = value }
        return ExportSchema.itemHeaders.map { byHeader[$0]! }
    }

    private func record(name: String, notes: String) -> ItemExportRecord {
        ItemExportRecord(
            name: name,
            categoryPath: "Music/Amps",
            purchasePriceCents: 69_000,
            currencyCode: "USD",
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            purchaseLocation: nil,
            currentValueCents: nil,
            desireToKeep: 3,
            conditionRawValue: "good",
            conditionNotes: nil,
            serialNumber: nil,
            notes: notes.isEmpty ? nil : notes,
            reverbProductID: nil,
            year: nil,
            firstPhotoID: nil
        )
    }
}

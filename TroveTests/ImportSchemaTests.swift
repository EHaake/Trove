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
            firstPhotoID: nil
        )
    }
}

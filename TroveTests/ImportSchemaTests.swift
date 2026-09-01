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

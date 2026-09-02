import Foundation
import Testing
@testable import Trove

/// T001's guards: the production parser against hand-written golden
/// fixtures — the standard plan.md sets. The test-only `RFC4180` in
/// `CSVWriterTests` may cross-check writer-produced files (one test below
/// does) but is never the oracle for the parser's own rules; it lacks the
/// strictness this parser is required to have.
struct CSVParserTests {
    // MARK: - Quoting

    @Test func minimalAndMaximalQuotingParseIdentically() throws {
        let minimal = try CSVParser.parse("A,B\r\n1,2\r\n")
        let maximal = try CSVParser.parse("\"A\",\"B\"\r\n\"1\",\"2\"\r\n")
        let expected = [
            CSVRow(number: 1, cells: ["A", "B"]),
            CSVRow(number: 2, cells: ["1", "2"]),
        ]
        #expect(minimal == expected)
        #expect(maximal == expected)
    }

    @Test func embeddedCommasAndDoubledQuotesSurvive() throws {
        let rows = try CSVParser.parse("\"has,comma\",\"say \"\"hi\"\"\"\r\n")
        #expect(rows == [CSVRow(number: 1, cells: ["has,comma", "say \"hi\""])])
    }

    @Test func embeddedNewlineStaysOneField() throws {
        let rows = try CSVParser.parse("\"multi\nline\",x\r\n")
        #expect(rows == [CSVRow(number: 1, cells: ["multi\nline", "x"])])
    }

    @Test func embeddedCRLFIsPreservedInsideAQuotedField() throws {
        let rows = try CSVParser.parse("\"crlf\r\ninside\",x\r\n")
        #expect(rows.count == 1)
        // Unicode-scalar comparison, deliberately: `String ==` is
        // canonical-equivalence and would call "\r\n" equal to itself
        // regardless; the scalar count pins that both scalars survived.
        #expect(rows[0].cells[0] == "crlf\r\ninside")
        #expect(rows[0].cells[0].unicodeScalars.count == "crlf\r\ninside".unicodeScalars.count)
    }

    @Test func unclosedQuoteThrowsWholeFile() {
        #expect(throws: CSVParseError.unclosedQuote) {
            try CSVParser.parse("A,B\r\n\"oops,truncated\r\nmore,rows\r\n")
        }
    }

    // MARK: - Row endings

    @Test(arguments: [
        "A,B\r\n1,2\r\n",   // CRLF
        "A,B\n1,2\n",       // lone LF
        "A,B\r1,2\r",       // lone CR, including as the file's final byte
        "A,B\r\n1,2",       // trailing newline absent
    ])
    func allRowEndingsYieldTheSameRows(text: String) throws {
        let rows = try CSVParser.parse(text)
        #expect(rows == [
            CSVRow(number: 1, cells: ["A", "B"]),
            CSVRow(number: 2, cells: ["1", "2"]),
        ])
    }

    @Test func crlfSplitAcrossTheCRCaseCountsOneRowBoundary() throws {
        // The scalar machine's own trap: CR must consume its LF or every
        // CRLF boundary yields a phantom empty row between real rows.
        let rows = try CSVParser.parse("A\r\nB\r\n")
        #expect(rows == [
            CSVRow(number: 1, cells: ["A"]),
            CSVRow(number: 2, cells: ["B"]),
        ])
    }

    // MARK: - BOM

    @Test func leadingBOMIsStrippedAndAbsenceIsFine() throws {
        let with = try CSVParser.parse("\u{FEFF}A,B\r\n")
        let without = try CSVParser.parse("A,B\r\n")
        #expect(with == without)
        #expect(with == [CSVRow(number: 1, cells: ["A", "B"])])
    }

    // MARK: - Cells and blank rows

    @Test func emptyCellsArePreservedInPlace() throws {
        let rows = try CSVParser.parse("a,,b\r\n,\r\n")
        #expect(rows == [
            CSVRow(number: 1, cells: ["a", "", "b"]),
            CSVRow(number: 2, cells: ["", ""]),
        ])
    }

    @Test func blankLinesAreRowsWithNumbers() throws {
        // The parser reports what the file contains; dropping blank rows is
        // `ImportSchema.shaped`'s job (T002), and numbering must already
        // account for them here or every skip report after a blank line
        // would point one row early.
        let rows = try CSVParser.parse("A\r\n\r\nB\r\n")
        #expect(rows == [
            CSVRow(number: 1, cells: ["A"]),
            CSVRow(number: 2, cells: [""]),
            CSVRow(number: 3, cells: ["B"]),
        ])
    }

    // MARK: - Spreadsheet row numbering

    @Test func embeddedNewlinesDoNotAdvanceTheRowNumber() throws {
        // Two physical lines, one spreadsheet row: the row after the
        // multi-line field must be numbered 2, the way Numbers shows it —
        // this is what makes skip reports findable (plan §The parser).
        let rows = try CSVParser.parse("\"line1\nline2\",x\r\nnext,y\r\n")
        #expect(rows == [
            CSVRow(number: 1, cells: ["line1\nline2", "x"]),
            CSVRow(number: 2, cells: ["next", "y"]),
        ])
    }

    // MARK: - Writer cross-check

    /// The writer's own hard cases parse back exactly — a writer-produced
    /// file, which is the one context the test-only `RFC4180` also covers;
    /// here the production parser takes the same bar.
    @Test func writerOutputRoundTripsThroughTheProductionParser() throws {
        let table = CSVTable(
            headers: ["Name", "Notes"],
            rows: [
                ["plain", ""],
                ["has,comma", "say \"hi\""],
                ["multi\nline", "crlf\r\ninside"],
                ["café 🎸", "=SUM(A1)"],
            ]
        )
        let rows = try CSVParser.parse(CSVWriter.write(table))
        #expect(rows.map(\.cells) == [table.headers] + table.rows)
        #expect(rows.map(\.number) == [1, 2, 3, 4, 5])
    }
}

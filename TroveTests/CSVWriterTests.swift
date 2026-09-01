import Foundation
import Testing
@testable import Trove

/// T003's guards: the writer's output survives a real RFC 4180 parse — not
/// just "the string looks right" — across criterion 5's hard cases (commas,
/// quotes, embedded newlines), plus the exact framing facts (BOM, CRLF,
/// minimal quoting) that are part of the canonical schema.
struct CSVWriterTests {
    private let hardTable = CSVTable(
        headers: ["Name", "Notes"],
        rows: [
            ["plain", ""],
            ["has,comma", "say \"hi\""],
            ["multi\nline", "crlf\r\ninside"],
            ["café 🎸", "=SUM(A1)"],
        ]
    )

    @Test func roundTripsThroughAnRFC4180Parser() {
        let parsed = RFC4180.parse(CSVWriter.write(hardTable))
        #expect(parsed == [hardTable.headers] + hardTable.rows)
    }

    @Test func startsWithExactlyOneByteOrderMark() {
        let text = CSVWriter.write(hardTable)
        #expect(text.hasPrefix("\u{FEFF}"))
        #expect(!text.dropFirst().contains("\u{FEFF}"))
    }

    @Test func usesCRLFRowEndingsIncludingATrailingOne() {
        let text = CSVWriter.write(CSVTable(headers: ["A"], rows: [["1"], ["2"]]))
        #expect(text == "\u{FEFF}A\r\n1\r\n2\r\n")
    }

    @Test func quotesOnlyFieldsThatNeedIt() {
        let text = CSVWriter.write(CSVTable(headers: ["A", "B"], rows: [["plain", "with,comma"]]))
        #expect(text.contains("plain,\"with,comma\""))
        #expect(!text.contains("\"plain\""))
    }

    @Test func doublesEmbeddedQuotes() {
        let text = CSVWriter.write(CSVTable(headers: ["A"], rows: [["say \"hi\""]]))
        #expect(text.contains("\"say \"\"hi\"\"\""))
    }

    /// A field carrying a newline must stay one field in one row — this is
    /// the case that breaks naive line-split parsers, and the reason notes
    /// fields get quoted at all.
    @Test func fieldWithNewlineStaysOneParsedRow() {
        let text = CSVWriter.write(CSVTable(headers: ["A"], rows: [["line1\nline2"]]))
        let parsed = RFC4180.parse(text)
        #expect(parsed.count == 2)
        #expect(parsed[1] == ["line1\nline2"])
    }

    /// The CRLF-inside-a-field case specifically: Swift fuses "\r\n" into a
    /// single grapheme that a Character-level quoting check would miss — this
    /// pins the unicode-scalar scan.
    @Test func fieldWithCRLFStaysOneParsedRow() {
        let text = CSVWriter.write(CSVTable(headers: ["A"], rows: [["crlf\r\ninside"]]))
        let parsed = RFC4180.parse(text)
        #expect(parsed.count == 2)
        #expect(parsed[1] == ["crlf\r\ninside"])
    }
}

/// A small, real RFC 4180 parser — **test-only**. It exists so the round-trip
/// tests parse the writer's output the way a spreadsheet would, rather than
/// asserting on substrings; `012` will build its own production parser
/// against the schema, not this.
enum RFC4180 {
    static func parse(_ text: String) -> [[String]] {
        var content = Substring(text)
        if content.hasPrefix("\u{FEFF}") { content.removeFirst() }

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false

        var index = content.startIndex
        while index < content.endIndex {
            let character = content[index]
            if inQuotes {
                if character == "\"" {
                    let next = content.index(after: index)
                    if next < content.endIndex, content[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"" where field.isEmpty:
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                // Bare LF and bare CR split rows too, matching how real
                // readers (Excel splits on LF) treat unquoted line breaks —
                // a parser lenient about them couldn't catch missing quoting,
                // which the T003 mutation check proved the hard way: the
                // newline round-trip test stayed green with quoting stripped
                // until these cases existed.
                case "\r\n", "\n", "\r":
                    row.append(field)
                    field = ""
                    rows.append(row)
                    row = []
                default:
                    field.append(character)
                }
            }
            index = content.index(after: index)
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}

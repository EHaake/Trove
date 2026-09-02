import Foundation

/// The transport half of `012`'s import pipeline: text in, rows of cells
/// out. RFC 4180 with exactly the tolerance plan.md pins (§The parser):
/// optional BOM, CRLF/LF/CR row endings, any valid quoting, optional
/// trailing newline. Meaning — the header gate, the field policy — lives in
/// `ImportSchema`, never here.
///
/// This is not the test-only `RFC4180` parser in `CSVWriterTests` promoted;
/// that one is deliberately confined there as a weak cross-check oracle
/// (no unclosed-quote detection, one hard-coded trailing-newline answer).
/// This parser is validated against golden fixtures and the writer→parser
/// closed loop instead.
///
/// Everything here is explicitly `nonisolated`: the project-wide MainActor
/// default would otherwise capture these types, and parsing runs off the
/// main actor inside the import service.

/// One parsed row: its cells, and the row number a spreadsheet would show
/// for it (header = row 1). Numbered per parsed *record*, not per physical
/// line — a quoted field carrying a newline spans two lines but one
/// spreadsheet row, and skip reports must name the row the user can find in
/// Numbers or Excel. Blank lines keep their numbers too (a blank line is
/// still a row in a spreadsheet), so dropping them later never renumbers
/// what follows.
nonisolated struct CSVRow: Sendable, Equatable {
    let number: Int
    let cells: [String]
}

nonisolated enum CSVParseError: Error, Equatable {
    /// End of input arrived inside a quoted field. Whole-file by design
    /// (spec criterion 14 as amended): a runaway quote swallows the
    /// remainder of the file into this one field, so any per-row recovery
    /// would silently import garbage.
    case unclosedQuote
}

nonisolated enum CSVParser {
    static func parse(_ text: String) throws -> [CSVRow] {
        let scalars = text.unicodeScalars
        var index = scalars.startIndex

        // The writer's Excel accommodation is a single leading BOM; not
        // every editor preserves it, so absence is equally fine.
        if index < scalars.endIndex, scalars[index] == "\u{FEFF}" {
            index = scalars.index(after: index)
        }

        var rows: [CSVRow] = []
        var cells: [String] = []
        var field = ""
        var inQuotes = false
        var rowNumber = 1

        func endField() {
            cells.append(field)
            field = ""
        }

        func endRow() {
            endField()
            rows.append(CSVRow(number: rowNumber, cells: cells))
            cells = []
            rowNumber += 1
        }

        // Scalars, not Characters, deliberately — and this is the opposite
        // trap from the writer's: `Character`s fuse "\r\n" into a single
        // grapheme (which the test-only parser relies on), scalars see two.
        // The CR case below must consume an immediately following LF itself
        // or every CRLF row boundary would count twice.
        while index < scalars.endIndex {
            let scalar = scalars[index]
            if inQuotes {
                if scalar == "\"" {
                    let next = scalars.index(after: index)
                    if next < scalars.endIndex, scalars[next] == "\"" {
                        field.unicodeScalars.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    // Row endings inside quotes are field content, preserved
                    // byte-for-byte — the writer quotes CR/LF-bearing fields
                    // for exactly this round trip.
                    field.unicodeScalars.append(scalar)
                }
            } else {
                switch scalar {
                case "\"" where field.isEmpty:
                    inQuotes = true
                case ",":
                    endField()
                case "\r":
                    let next = scalars.index(after: index)
                    if next < scalars.endIndex, scalars[next] == "\n" {
                        index = next
                    }
                    endRow()
                case "\n":
                    endRow()
                default:
                    field.unicodeScalars.append(scalar)
                }
            }
            index = scalars.index(after: index)
        }

        if inQuotes { throw CSVParseError.unclosedQuote }

        // A file without the trailing newline still ends its last row.
        if !field.isEmpty || !cells.isEmpty {
            endRow()
        }
        return rows
    }
}

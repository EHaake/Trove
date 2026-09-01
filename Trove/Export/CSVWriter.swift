import Foundation

/// The RFC 4180 serializer for `CSVTable` — hand-rolled per plan.md's CSV
/// section (no third-party packages, and the format is small enough that a
/// dependency would be all liability).
///
/// Format facts that are part of the canonical schema, not incidentals:
/// UTF-8 with a single leading BOM (Excel on Windows misreads BOM-less
/// UTF-8; `012`'s parser must skip it), CRLF row endings including a
/// trailing one, minimal quoting — a field is quoted iff it contains a
/// comma, quote, CR, or LF, with embedded quotes doubled.
nonisolated enum CSVWriter {
    static let byteOrderMark = "\u{FEFF}"

    static func write(_ table: CSVTable) -> String {
        let lines = ([table.headers] + table.rows).map { row in
            row.map { escaped($0) }.joined(separator: ",")
        }
        return byteOrderMark + lines.map { $0 + "\r\n" }.joined()
    }

    private static func escaped(_ field: String) -> String {
        // Unicode scalars, not Characters: Swift graphemes fuse "\r\n" into
        // one Character that equals neither "\r" nor "\n", so a Character
        // scan would pass a CRLF-bearing field through unquoted — and split
        // it into two rows in every reader.
        let needsQuoting = field.unicodeScalars.contains {
            $0 == "," || $0 == "\"" || $0 == "\r" || $0 == "\n"
        }
        guard needsQuoting else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

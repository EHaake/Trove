import Foundation

/// One cell, read. `empty` covers a blank cell, an N/A, and a column the file
/// does not have — the spec's three ways of saying nothing (021, plan §2).
nonisolated enum Cell<Value: Sendable & Equatable>: Sendable, Equatable {
    case empty, unreadable, value(Value)
}

/// The order a slash date's first two numbers are read in (021, plan §2;
/// spec Decision 6). One order per file: `ImportSchema.slashDateOrder(in:region:)`
/// decides it from the file's own dates, and the phone's region only when
/// the file can't.
nonisolated enum SlashDateOrder: Sendable, Equatable {
    case monthFirst, dayFirst

    /// The phone's region: day-first iff "d" comes before "M" in the locale's
    /// own "yMd" pattern (en_US M/d/y, en_GB dd/MM/y, ja_JP y/M/d → month-first).
    static func regional(for locale: Locale) -> SlashDateOrder {
        let pattern = DateFormatter.dateFormat(fromTemplate: "yMd", options: 0, locale: locale) ?? ""
        guard
            let day = pattern.firstIndex(of: "d"),
            let month = pattern.firstIndex(of: "M")
        else { return .monthFirst }
        return day < month ? .dayFirst : .monthFirst
    }
}

/// Where each known column sits in a file's header (021, plan §3; P1–P3).
/// Columns are found by name, in any order: a header cell is canonicalised —
/// trimmed, one trailing `*` dropped, trimmed again, lowercased — and
/// compared with the lowercased `known` names, which the caller reads from
/// `ExportSchema.itemHeaders` / `wishlistHeaders` and never copies. Trove's
/// own names only: there is no synonym table.
nonisolated struct ImportColumns: Sendable {
    /// Header cells, after shaping.
    let width: Int
    /// Unrecognised names as written (trimmed), in file order — no blanks and
    /// no repeats, a repeat being the same name after canonicalising.
    let unused: [String]
    /// Canonical known name → its cell's index in the header.
    private let positions: [String: Int]
    /// Every known name, canonicalised — what `position(of:)` checks against.
    private let knownKeys: Set<String>

    nonisolated enum HeaderError: Error, Equatable {
        /// This list's required names are missing and every one of the other
        /// list's is present — the file is the other list's export.
        case wrongList
        /// The required names the header lacks, in schema order.
        case missing([String])
        /// A recognised name appears twice; carries the schema's spelling.
        case duplicate(String)
    }

    /// The cell holding `name`, or nil when the file has no such column.
    /// `name` must be one of the `known` names the columns were matched
    /// against — a typo traps in any test that parses.
    func position(of name: String) -> Int? {
        let key = Self.canonical(name)
        precondition(knownKeys.contains(key), "\(name) is not a known column")
        return positions[key]
    }

    /// In order: `.wrongList`, then `.missing` (every missing required name),
    /// then `.duplicate`. An empty header is a header of no cells, so it is
    /// missing every required name. An unrecognised column never refuses the
    /// file; it is listed in `unused`.
    static func match(
        header: [String],
        known: [String],
        required: [String],
        otherRequired: [String]
    ) throws(HeaderError) -> ImportColumns {
        let spellings = Dictionary(known.map { (canonical($0), $0) }, uniquingKeysWith: { first, _ in first })
        var positions: [String: Int] = [:]
        var duplicate: String?
        var unused: [String] = []
        var unusedKeys: Set<String> = []
        var present: Set<String> = []

        for (index, cell) in header.enumerated() {
            let key = canonical(cell)
            present.insert(key)
            if let spelling = spellings[key] {
                if positions[key] == nil {
                    positions[key] = index
                } else if duplicate == nil {
                    duplicate = spelling
                }
            } else if !key.isEmpty, unusedKeys.insert(key).inserted {
                unused.append(FieldNormalization.trimmed(cell))
            }
        }

        let missing = required.filter { positions[canonical($0)] == nil }
        if !missing.isEmpty, otherRequired.allSatisfy({ present.contains(canonical($0)) }) {
            throw .wrongList
        }
        if !missing.isEmpty { throw .missing(missing) }
        if let duplicate { throw .duplicate(duplicate) }

        return ImportColumns(
            width: header.count,
            unused: unused,
            positions: positions,
            knownKeys: Set(spellings.keys)
        )
    }

    /// Trimmed, one trailing `*` dropped, trimmed again, lowercased.
    private static func canonical(_ cell: String) -> String {
        var name = FieldNormalization.trimmed(cell)
        if name.hasSuffix("*") { name.removeLast() }
        return FieldNormalization.trimmed(name).lowercased()
    }
}

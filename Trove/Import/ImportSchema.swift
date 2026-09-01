import Foundation

/// The meaning half of `012`'s import pipeline: what parsed rows *are*.
/// This file grows in slices along the task list — this slice is row
/// shaping (plan §Row pipeline, steps 1–2); the header gate and field
/// policy land next.
///
/// Explicitly `nonisolated` for the same reason as `CSVParser`: validation
/// runs off the main actor inside the import service.
nonisolated enum ImportSchema {
    /// Plan §Row pipeline, steps 1–2, in one pass — the order matters and
    /// is the point:
    ///
    /// 1. **Trailing empty cells are stripped** from every row, the header
    ///    included (the caller shapes before gating). Spreadsheet apps
    ///    emit `...,Notes,,,` whenever the sheet's used range outgrew the
    ///    data, and the rigid header gate must not reject a re-saved file
    ///    for it (amended criterion 3). Only *empty* cells strip —
    ///    whitespace-only cells survive to the field policy, whose
    ///    trimming rules own that question.
    /// 2. **Wholly blank rows drop silently** — after stripping, a blank
    ///    line (one empty cell) or an all-commas line (several) has no
    ///    cells left, and reporting it would put a phantom "no name" skip
    ///    on an otherwise clean file. Dropped rows keep their absence
    ///    invisible; surviving rows keep the spreadsheet numbers the
    ///    parser gave them, so a skip reported after a blank line still
    ///    points where Numbers points.
    ///
    /// A row that legitimately *ends* in empty optional columns (an empty
    /// Notes cell) loses them here too; the field policy pads under-length
    /// rows back and treats the padded cells as blank — strip-then-pad is
    /// identity for legitimate trailing blanks.
    static func shaped(_ rows: [CSVRow]) -> [CSVRow] {
        rows.compactMap { row in
            var cells = row.cells
            while cells.last?.isEmpty == true {
                cells.removeLast()
            }
            guard !cells.isEmpty else { return nil }
            return CSVRow(number: row.number, cells: cells)
        }
    }

    // MARK: - Header gate (plan §Row pipeline, step 3)

    /// Thrown by the header gate. `wrongList` is checked first and exists
    /// for criterion 4: offering a wishlist export to the items list (or
    /// vice versa) is the most likely wrong-file mistake, and the alert
    /// should name it rather than say "wrong columns".
    nonisolated enum HeaderError: Error, Equatable {
        case wrongList
        case mismatch
    }

    /// The items gate: trimmed header cells must equal
    /// `ExportSchema.itemHeaders` exactly. The pinned arrays are read right
    /// here, never copied — a schema change reshapes the gate by
    /// construction, which is the append-only growth rule's enforcement
    /// point. Callers shape the rows first (`shaped(_:)`), so a re-saved
    /// header's trailing empty columns are already gone.
    static func requireItemsHeader(_ row: CSVRow) throws {
        try requireHeader(row, expected: ExportSchema.itemHeaders, other: ExportSchema.wishlistHeaders)
    }

    /// See `requireItemsHeader(_:)` — the wishlist twin.
    static func requireWishlistHeader(_ row: CSVRow) throws {
        try requireHeader(row, expected: ExportSchema.wishlistHeaders, other: ExportSchema.itemHeaders)
    }

    private static func requireHeader(_ row: CSVRow, expected: [String], other: [String]) throws {
        let cells = row.cells.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard cells != expected else { return }
        throw cells == other ? HeaderError.wrongList : HeaderError.mismatch
    }
}

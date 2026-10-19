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
    /// `ExportSchema.itemHeaders` — or a *shipped* prefix of it
    /// (`ExportSchema.itemSchemaBoundaries`), so a file written before 002
    /// appended `Reverb Product ID` and `Year` still imports (Q16). Returns
    /// the width that matched; the caller judges "more columns than the
    /// template" against *that*, not against the current header count, or a
    /// legacy file's overlong row would slip through as content.
    ///
    /// The pinned arrays are read right here, never copied — a schema change
    /// reshapes the gate by construction, which is the append-only growth
    /// rule's enforcement point. Callers shape the rows first (`shaped(_:)`),
    /// so a re-saved header's trailing empty columns are already gone.
    @discardableResult
    static func requireItemsHeader(_ row: CSVRow) throws -> Int {
        try requireHeader(
            row,
            expected: ExportSchema.itemHeaders,
            boundaries: ExportSchema.itemSchemaBoundaries,
            other: ExportSchema.wishlistHeaders,
            otherBoundaries: ExportSchema.wishlistSchemaBoundaries
        )
    }

    /// See `requireItemsHeader(_:)` — the wishlist twin.
    @discardableResult
    static func requireWishlistHeader(_ row: CSVRow) throws -> Int {
        try requireHeader(
            row,
            expected: ExportSchema.wishlistHeaders,
            boundaries: ExportSchema.wishlistSchemaBoundaries,
            other: ExportSchema.itemHeaders,
            otherBoundaries: ExportSchema.itemSchemaBoundaries
        )
    }

    /// Accepted widths: the full width, then each shipped boundary. Only
    /// those exact widths — one column short of a boundary is still a
    /// mismatch, because "any prefix" would accept a truncated file and
    /// silently blank whatever it lost.
    private static func requireHeader(
        _ row: CSVRow,
        expected: [String],
        boundaries: [Int],
        other: [String],
        otherBoundaries: [Int]
    ) throws -> Int {
        let cells = row.cells.map { FieldNormalization.trimmed($0) }
        for width in [expected.count] + boundaries where cells == Array(expected.prefix(width)) {
            return width
        }
        // Criterion 4 holds at every shipped width too: an old wishlist
        // export offered to the items screen is still "wrong list", not
        // "wrong columns".
        for width in [other.count] + otherBoundaries where cells == Array(other.prefix(width)) {
            throw HeaderError.wrongList
        }
        throw HeaderError.mismatch
    }

    // MARK: - Field parsers (plan §Money and date parsing)

    /// The one test of a cell that says nothing (021, P6; spec Decision 7):
    /// after trimming, empty, or `N/A` / `#N/A` in any letter case — the
    /// spreadsheet's own "not applicable" and its lookup-failure error.
    /// `NA`, `none` and `-` are not blank: they are text, and a column that
    /// can't read them counts them.
    static func isBlank(_ field: String) -> Bool {
        let folded = FieldNormalization.trimmed(field).lowercased()
        return folded.isEmpty || folded == "n/a" || folded == "#n/a"
    }

    /// Money as the schema reads it. Pure overflow-checked integer
    /// arithmetic; no `Locale`, no `Decimal`, deliberately.
    /// `Decimal(string:)` stops parsing silently at the first character it
    /// doesn't understand — `"1,250.00"` comes back as 1 — which is exactly
    /// the locale-shaped leniency the spec forbids (011's plan.md carries
    /// the correction note).
    ///
    /// **Widened in place by `021`** (plan §2, Q7; spec Decisions 16 and
    /// 22): an optional single leading `$`, `€`, `£` or `¥`, then any
    /// number of spaces (`$ 3,179.95`); then either digits with no commas,
    /// or thousands groups — one to three digits, then one or more `,ddd`;
    /// then optionally a dot and one or two fraction digits. Nothing else:
    /// a sign, brackets, trailing text, a space with no symbol before it,
    /// a trailing dot, a missing integer digit, sub-cent precision, and any
    /// other grouping (`1,25`, `12,34,567`, `1.250,00`) all return nil; the
    /// field policy turns nil into a counted default. The function returns
    /// cents and nothing else, so the symbol has no way to set the currency.
    static func cents(from field: String) -> Int? {
        let scalars = Array(field.unicodeScalars)
        var index = 0
        if index < scalars.count, moneySymbols.contains(scalars[index]) {
            index += 1
            while index < scalars.count, scalars[index] == " " { index += 1 }
        }

        // `run` counts the digits since the start or the last comma; once a
        // comma has been seen, every run after it must be exactly three.
        var whole = 0
        var run = 0
        var grouped = false
        while index < scalars.count {
            if let digit = digit(scalars[index]) {
                if grouped, run == 3 { return nil }
                let (shifted, overflow1) = whole.multipliedReportingOverflow(by: 10)
                guard !overflow1 else { return nil }
                let (added, overflow2) = shifted.addingReportingOverflow(digit)
                guard !overflow2 else { return nil }
                whole = added
                run += 1
                index += 1
            } else if scalars[index] == "," {
                guard grouped ? run == 3 : (1...3).contains(run) else { return nil }
                grouped = true
                run = 0
                index += 1
            } else {
                break
            }
        }
        guard run > 0, !grouped || run == 3 else { return nil }

        var fraction = 0
        if index < scalars.count, scalars[index] == "." {
            index += 1
            var fractionDigits = 0
            while index < scalars.count, fractionDigits < 3, let digit = digit(scalars[index]) {
                fraction = fraction * 10 + digit
                fractionDigits += 1
                index += 1
            }
            guard fractionDigits == 1 || fractionDigits == 2 else { return nil }
            if fractionDigits == 1 { fraction *= 10 }
        }
        guard index == scalars.count else { return nil }

        let (scaled, overflow3) = whole.multipliedReportingOverflow(by: 100)
        guard !overflow3 else { return nil }
        let (total, overflow4) = scaled.addingReportingOverflow(fraction)
        guard !overflow4 else { return nil }
        return total
    }

    /// The four symbols a price may open with (021, Q7). Dropped, never read.
    private static let moneySymbols: Set<Unicode.Scalar> = ["$", "€", "£", "¥"]

    /// A date as the schema reads it: `yyyy-MM-dd` (4-2-2 digits —
    /// `2026-1-5` is rejected, matching the writer's zero-padded output),
    /// resolved in a **Gregorian calendar built here over the injected
    /// `TimeZone`** — the same T019/B1 doctrine as `ExportSchema.day`: the
    /// API takes only a `TimeZone`, so the user's preferred-calendar
    /// setting has no way in from this direction either.
    ///
    /// **Widened by `021`** (plan §2, P4; spec Decision 6): given an
    /// `order`, `d{1,2}/d{1,2}/d{4}` also reads, month or day first as the
    /// order says — the file's order, from `slashDateOrder(in:region:)`. A
    /// two-digit year, another separator, or a slash date with no order
    /// given is nil, so every caller that passes no order reads exactly
    /// what it read before.
    ///
    /// Gregorian `date(from:)` *normalizes* impossible dates (Feb 30 →
    /// Mar 2) rather than failing, so the resolved date is round-tripped
    /// back to components and compared — that's the impossible-date check,
    /// for both shapes. On a day whose local midnight doesn't exist (a
    /// spring-forward transition), `date(from:)` answers the first valid
    /// instant instead and the components still round-trip — pinned by the
    /// DST fixture.
    static func day(
        from field: String, timeZone: TimeZone = .current, order: SlashDateOrder? = nil
    ) -> Date? {
        let scalars = Array(field.unicodeScalars)
        let year: Int
        let month: Int
        let dayOfMonth: Int
        if scalars.count == 10, scalars[4] == "-", scalars[7] == "-" {
            guard
                let isoYear = number(scalars[0...3]),
                let isoMonth = number(scalars[5...6]),
                let isoDay = number(scalars[8...9])
            else { return nil }
            (year, month, dayOfMonth) = (isoYear, isoMonth, isoDay)
        } else if let order, let parts = slashParts(scalars) {
            year = parts.year
            (month, dayOfMonth) = order == .monthFirst
                ? (parts.first, parts.second)
                : (parts.second, parts.first)
        } else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: year, month: month, day: dayOfMonth)
        guard let date = calendar.date(from: components) else { return nil }

        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == dayOfMonth else {
            return nil
        }
        return date
    }

    /// The file's slash-date order (021, plan §2, P4; spec Decision 6),
    /// over every cell in its date columns. A slash date whose first number
    /// is above 12 and second is not is evidence for day-first; the other
    /// way round, for month-first; anything else, for nothing. One kind of
    /// evidence decides. None, or both, and the region decides — and
    /// `regionDecided` is true only when the file holds at least one
    /// slash-shaped date, so a file of ISO dates says nothing about order.
    /// Under a contradiction, the dates that don't fit the region's order
    /// are unreadable by `day(from:timeZone:order:)`'s own check.
    static func slashDateOrder(
        in cells: [String], region: Locale
    ) -> (order: SlashDateOrder, regionDecided: Bool) {
        var monthFirstEvidence = false
        var dayFirstEvidence = false
        var anySlashDate = false
        for cell in cells {
            guard let parts = slashParts(Array(FieldNormalization.trimmed(cell).unicodeScalars)) else {
                continue
            }
            anySlashDate = true
            if parts.first > 12, parts.second <= 12 { dayFirstEvidence = true }
            if parts.second > 12, parts.first <= 12 { monthFirstEvidence = true }
        }
        switch (monthFirstEvidence, dayFirstEvidence) {
        case (true, false): return (.monthFirst, false)
        case (false, true): return (.dayFirst, false)
        default: return (.regional(for: region), anySlashDate)
        }
    }

    /// `d{1,2}/d{1,2}/d{4}`, as its three numbers in the order written, or
    /// nil for any other shape.
    private static func slashParts(
        _ scalars: [Unicode.Scalar]
    ) -> (first: Int, second: Int, year: Int)? {
        let parts = scalars.split(separator: "/", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            (1...2).contains(parts[0].count),
            (1...2).contains(parts[1].count),
            parts[2].count == 4,
            let first = number(parts[0]),
            let second = number(parts[1]),
            let year = number(parts[2])
        else { return nil }
        return (first, second, year)
    }

    /// The Trove ID as the schema reads it (021, plan §2): blank (by
    /// `isBlank`) is `empty`; the trimmed text that `UUID(uuidString:)`
    /// parses — in any letter case — is the value; anything else is
    /// `unreadable`. Parsed, never compared as text.
    static func troveID(from field: String) -> Cell<UUID> {
        if isBlank(field) { return .empty }
        guard let id = UUID(uuidString: FieldNormalization.trimmed(field)) else { return .unreadable }
        return .value(id)
    }

    /// Desire as the schema reads it: an integer inside the given scale —
    /// 1...5 for items, 1...3 for the wishlist (the `DesireLevel` /
    /// `DesireToOwnLevel` scales; the spec's policy is default-and-count,
    /// deliberately not those enums' clamping).
    static func desire(from field: String, in range: ClosedRange<Int>) -> Int? {
        guard let value = Int(field), range.contains(value) else { return nil }
        return value
    }

    /// Condition matched case-insensitively against the six known raw
    /// values (criterion 8) — a hand-typed "Excellent" works, and so does
    /// "Very Good", whose raw value carries its space (020, P5).
    static func condition(from field: String) -> Condition? {
        Condition(rawValue: field.lowercased())
    }

    /// Bought new or used, and looking for new or used (020, Q6): `new` or
    /// `used` in any letter case. Anything else is nil, which the field
    /// policy turns into a counted default — or, for a blank cell, a silent
    /// "not recorded".
    static func newOrUsed(from field: String) -> NewOrUsed? {
        NewOrUsed(rawValue: field.lowercased())
    }

    /// Currency: exactly three ASCII letters, stored uppercased. The model
    /// field is ISO 4217-shaped; v1 doesn't validate against the real code
    /// list (it writes only USD), and neither does the parser.
    static func currencyCode(from field: String) -> String? {
        let scalars = field.unicodeScalars
        guard scalars.count == 3, scalars.allSatisfy({
            ("A"..."Z").contains($0) || ("a"..."z").contains($0)
        }) else { return nil }
        return field.uppercased()
    }

    /// The Reverb match as the schema reads it (002, plan §7): ASCII digits
    /// only, overflow-checked, and positive — a product id is a positive
    /// whole number, so `0`, `-1`, `12.5` and `abc` are all unreadable. The
    /// field policy makes blank silent and unreadable counted, the same
    /// split `Current Value` uses.
    ///
    /// Trims first, as `year(from:)` does: callers may pass untrimmed input
    /// — a hand-edited cell with a stray space around the number is the
    /// number, on both columns alike.
    static func reverbProductID(from field: String) -> Int? {
        let scalars = Array(FieldNormalization.trimmed(field).unicodeScalars)
        guard !scalars.isEmpty else { return nil }
        var value = 0
        for scalar in scalars {
            guard let digit = digit(scalar) else { return nil }
            let (shifted, overflow1) = value.multipliedReportingOverflow(by: 10)
            guard !overflow1 else { return nil }
            let (added, overflow2) = shifted.addingReportingOverflow(digit)
            guard !overflow2 else { return nil }
            value = added
        }
        guard value > 0 else { return nil }
        return value
    }

    /// The year as the schema reads it (002, Decision 29 / P18): exactly
    /// four ASCII digits after trimming, `1900` through next calendar year.
    /// What it shares with the rule `ItemFormViewModel.parsedYear` applies
    /// to a typed field is the lower bound (`FieldNormalization.earliestYear`)
    /// and the four-digit shape; the upper bound is each caller's own clock
    /// and calendar, and under a non-Gregorian preferred calendar the two
    /// need not land on the same number. `"01975"` is the case that
    /// falsifies the four-digit check (`"75"` is rejected by the lower bound
    /// whatever the digit rule says — the note in plan Amendment A).
    ///
    /// Callers may pass untrimmed input — the field is trimmed here, as on
    /// `reverbProductID(from:)`.
    ///
    /// A separate function from the forms' `parsedYear` rather than shared
    /// machinery, for the T019/B1 reason `day(from:)` records: this path
    /// takes its time zone as a parameter and builds a Gregorian calendar
    /// from it, where the forms read `Calendar.current` — the user's
    /// preferred-calendar setting has no way in from here, and import must
    /// read a date the same way whatever locale the file arrives in. The
    /// instant is a parameter for the same reason, so "next year" is a
    /// thing a test can pin. What the two do share is the lower bound:
    /// `FieldNormalization.earliestYear`, one constant, three call sites.
    /// If a fourth appears, `FieldNormalization` is the home plan
    /// Amendment A names for a shared `year(from:)`.
    static func year(from field: String, timeZone: TimeZone = .current, now: Date = .now) -> Int? {
        let scalars = Array(FieldNormalization.trimmed(field).unicodeScalars)
        guard scalars.count == 4, let value = number(scalars[0...3]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let latest = calendar.component(.year, from: now) + 1
        guard (FieldNormalization.earliestYear...latest).contains(value) else { return nil }
        return value
    }

    private static func digit(_ scalar: Unicode.Scalar) -> Int? {
        guard ("0"..."9").contains(scalar) else { return nil }
        return Int(scalar.value - UnicodeScalar("0").value)
    }

    private static func number(_ scalars: ArraySlice<Unicode.Scalar>) -> Int? {
        var value = 0
        for scalar in scalars {
            guard let digit = digit(scalar) else { return nil }
            value = value * 10 + digit
        }
        return value
    }

    // MARK: - Row validation (plan §Row pipeline; the spec's field-policy tables)

    /// The two row-fatal reasons, as the strings the confirmation alert
    /// composes with ("Row 7 — no name"). Pinned here so the validator and
    /// `ImportCopy` can't drift.
    nonisolated enum SkipReason {
        static let noName = "no name"
        static let extraColumns = "more columns than the template"
        /// 021 (R7): the sheet readers judge a row against the file's own
        /// header, not a template. `extraColumns` goes with `itemsPreview`.
        static let extraHeaderColumns = "more columns than the header"
    }

    // MARK: - Sheets (021, plan §4)

    /// The items file read to cells (021, plan §4, Q2): shape, match the
    /// columns by name, record which of `Desire to Keep` and `Condition` the
    /// file lacks, settle the slash order over `Purchase Date` and `Sold
    /// Date`, then per data row, in this order:
    ///
    /// 1. More cells than the header → skipped (R7). Fewer → padded.
    /// 2. Every recognised cell blank by `isBlank` → dropped silently.
    /// 3. A totals row → its number joins `totalsRowNumbers`; neither a row
    ///    nor a skip.
    /// 4. No name and no readable Trove ID → skipped, "no name" (P8).
    /// 5. Otherwise a row.
    ///
    /// **Cells under a column the app does not know are never looked at**
    /// (spec Decision 23) — not by the blank test, not by the totals test.
    static func itemsSheet(
        from rows: [CSVRow],
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) throws(ImportColumns.HeaderError) -> ImportSheet<ItemImportRow> {
        let shaped = shaped(rows)
        // Plan §6's temporary seam: the known names are the array plus
        // `troveIDHeader` until T008 appends it to `itemHeaders`.
        let known = ExportSchema.itemHeaders + [ExportSchema.troveIDHeader]
        // An empty file is a header of no cells — missing every required name.
        let columns = try ImportColumns.match(
            header: shaped.first?.cells ?? [],
            known: known,
            required: ExportSchema.itemRequiredHeaders,
            otherRequired: ExportSchema.wishlistRequiredHeaders
        )
        let dataRows = shaped.dropFirst()

        let missing = ["Desire to Keep", "Condition"].filter { columns.position(of: $0) == nil }

        // One order per file, from every cell in its date columns — of the
        // rows step 1 keeps: an over-wide row is skipped, and its shifted
        // cells don't vote.
        let datePositions = ["Purchase Date", "Sold Date"].compactMap { columns.position(of: $0) }
        let dateCells = dataRows.filter { $0.cells.count <= columns.width }.flatMap { row in
            datePositions.compactMap { $0 < row.cells.count ? row.cells[$0] : nil }
        }
        let (order, regionDecided) = slashDateOrder(in: dateCells, region: locale)

        let recognised = known.compactMap { columns.position(of: $0) }
        let namePosition = columns.position(of: "Name")
        let troveIDPosition = columns.position(of: ExportSchema.troveIDHeader)
        let moneyPositions = Set(
            ["Purchase Price", "Current Value", "Sale Price"].compactMap { columns.position(of: $0) }
        )

        var sheetRows: [ItemImportRow] = []
        var skipped: [SkippedRow] = []
        var totals: [Int] = []

        for row in dataRows {
            guard row.cells.count <= columns.width else {
                skipped.append(SkippedRow(rowNumber: row.number, reason: SkipReason.extraHeaderColumns))
                continue
            }
            var cells = row.cells
            cells.append(contentsOf: Array(repeating: "", count: columns.width - cells.count))

            guard recognised.contains(where: { !isBlank(cells[$0]) }) else { continue }

            if isTotalsRow(
                cells,
                recognised: recognised,
                name: namePosition,
                troveID: troveIDPosition,
                money: moneyPositions
            ) {
                totals.append(row.number)
                continue
            }

            /// The cell under `name`, or nil when the file has no such column.
            func field(_ name: String) -> String? {
                columns.position(of: name).map { cells[$0] }
            }

            let troveID = field(ExportSchema.troveIDHeader).map(Self.troveID(from:)) ?? .empty
            let name = text(field("Name"))
            // A nameless row with a readable code is kept: only the store
            // knows whether it matches (P8).
            var readableID = false
            if case .value = troveID { readableID = true }
            if name == .empty, !readableID {
                skipped.append(SkippedRow(rowNumber: row.number, reason: SkipReason.noName))
                continue
            }

            sheetRows.append(ItemImportRow(
                rowNumber: row.number,
                troveID: troveID,
                name: name,
                category: text(field("Category")),
                purchaseLocation: text(field("Purchase Location")),
                conditionNotes: text(field("Condition Notes")),
                serialNumber: text(field("Serial Number")),
                notes: text(field("Notes")),
                saleLocation: text(field("Sold At")),
                saleNote: text(field("Sale Note")),
                purchasePrice: read(field("Purchase Price"), cents(from:)),
                currentValue: read(field("Current Value"), cents(from:)),
                salePrice: read(field("Sale Price"), cents(from:)),
                currency: read(field("Currency"), currencyCode(from:)),
                purchaseDate: read(field("Purchase Date")) { day(from: $0, timeZone: timeZone, order: order) },
                soldDate: read(field("Sold Date")) { day(from: $0, timeZone: timeZone, order: order) },
                desireToKeep: read(field("Desire to Keep")) { desire(from: $0, in: 1...5) },
                reverbProductID: read(field("Reverb Product ID"), reverbProductID(from:)),
                year: read(field("Year")) { year(from: $0, timeZone: timeZone) },
                condition: read(field("Condition"), condition(from:)),
                bought: read(field("Bought"), newOrUsed(from:))
            ))
        }

        return ImportSheet(
            rows: sheetRows,
            skipped: skipped,
            unusedColumns: columns.unused,
            totalsRowNumbers: totals,
            regionDateOrder: regionDecided ? order : nil,
            missingDefaultColumns: missing
        )
    }

    /// Plan §4, step 3: the name blank or, lowercased, one of `total`,
    /// `totals`, `subtotal`, `sum`; the Trove ID blank; at least one other
    /// recognised cell filled; and every other filled recognised cell in a
    /// money column and reading as an amount.
    private static func isTotalsRow(
        _ cells: [String],
        recognised: [Int],
        name: Int?,
        troveID: Int?,
        money: Set<Int>
    ) -> Bool {
        if let name, !isBlank(cells[name]),
           !totalsLabels.contains(FieldNormalization.trimmed(cells[name]).lowercased()) {
            return false
        }
        if let troveID, !isBlank(cells[troveID]) { return false }
        let filled = recognised.filter { $0 != name && $0 != troveID && !isBlank(cells[$0]) }
        return !filled.isEmpty && filled.allSatisfy {
            money.contains($0) && cents(from: FieldNormalization.trimmed(cells[$0])) != nil
        }
    }

    private static let totalsLabels: Set<String> = ["total", "totals", "subtotal", "sum"]

    /// A text cell: blank (by `isBlank`) or absent is `empty`; otherwise the
    /// trimmed text. Text is never unreadable.
    private static func text(_ field: String?) -> Cell<String> {
        guard let field, !isBlank(field) else { return .empty }
        return .value(FieldNormalization.trimmed(field))
    }

    /// A typed cell: blank or absent is `empty`; the trimmed text `parse`
    /// reads is the value; anything else is `unreadable`.
    private static func read<Value: Sendable & Equatable>(
        _ field: String?, _ parse: (String) -> Value?
    ) -> Cell<Value> {
        guard let field, !isBlank(field) else { return .empty }
        guard let value = parse(FieldNormalization.trimmed(field)) else { return .unreadable }
        return .value(value)
    }

    /// The items pipeline end-to-end: shape (T002), gate (T003), then the
    /// field policy per the spec's items table. Throws `HeaderError` for
    /// whole-file problems; everything row-level lands in the preview as a
    /// skip or a counted default, never an error — the amended
    /// skip-and-report decision.
    static func itemsPreview(
        from rows: [CSVRow],
        timeZone: TimeZone = .current
    ) throws -> ItemsImportPreview {
        let shaped = shaped(rows)
        // No rows at all — an empty or all-blank file — has no header, and
        // "not a Trove items file" is the honest description.
        guard let header = shaped.first else { throw HeaderError.mismatch }
        // The width the gate matched — the current layout's, or a shipped
        // legacy one. It bounds a row's cells; padding still runs out to the
        // full header count, so a legacy file's missing columns arrive blank.
        let width = try requireItemsHeader(header)

        // Column positions derive from the pinned array, never hand-numbered
        // — the arrays are the schema, and a growth lands here by compile
        // error, not convention. Force-unwrap is deliberate: a name absent
        // from its own schema array is a typo in this file, and any test
        // that touches the pipeline catches it.
        let headers = ExportSchema.itemHeaders
        func column(_ name: String) -> Int { headers.firstIndex(of: name)! }
        let nameColumn = column("Name")
        let categoryColumn = column("Category")
        let priceColumn = column("Purchase Price")
        let currencyColumn = column("Currency")
        let dateColumn = column("Purchase Date")
        let locationColumn = column("Purchase Location")
        let valueColumn = column("Current Value")
        let desireColumn = column("Desire to Keep")
        let conditionColumn = column("Condition")
        let conditionNotesColumn = column("Condition Notes")
        let serialColumn = column("Serial Number")
        let notesColumn = column("Notes")
        let reverbColumn = column("Reverb Product ID")
        let yearColumn = column("Year")
        let soldDateColumn = column("Sold Date")
        let salePriceColumn = column("Sale Price")
        let soldAtColumn = column("Sold At")
        let saleNoteColumn = column("Sale Note")
        let boughtColumn = column("Bought")

        var validated: [ValidatedRow<ItemExportRecord>] = []
        var skipped: [SkippedRow] = []

        for row in shaped.dropFirst() {
            guard row.cells.count <= width else {
                // Row-fatal by decision: after trailing-empty stripping,
                // extra cells are extra *content*, and a stray comma has
                // shifted every later column — no guess is safe. Judged
                // against the *matched* width: a 13-cell row in a 12-column
                // legacy file is a stray comma, not a Reverb id.
                skipped.append(SkippedRow(rowNumber: row.number, reason: SkipReason.extraColumns))
                continue
            }
            // Under-length is transport damage (apps trim trailing
            // delimiters); padded cells follow the ordinary blank policy,
            // so strip-then-pad is identity for legitimate trailing blanks.
            var cells = row.cells
            cells.append(contentsOf: Array(repeating: "", count: headers.count - cells.count))

            let name = FieldNormalization.trimmed(cells[nameColumn])
            guard !name.isEmpty else {
                skipped.append(SkippedRow(rowNumber: row.number, reason: SkipReason.noName))
                continue
            }

            var defaulted = 0

            let price: Int
            if let parsed = cents(from: FieldNormalization.trimmed(cells[priceColumn])) {
                price = parsed
            } else {
                price = 0
                defaulted += 1
            }

            // Blank currency is the app's own single-currency reality, not
            // a defect worth reporting; a malformed code is.
            let currencyCell = FieldNormalization.trimmed(cells[currencyColumn])
            let currency: String
            if currencyCell.isEmpty {
                currency = "USD"
            } else if let code = currencyCode(from: currencyCell) {
                currency = code
            } else {
                currency = "USD"
                defaulted += 1
            }

            let purchaseDate: Date
            if let parsed = day(from: FieldNormalization.trimmed(cells[dateColumn]), timeZone: timeZone) {
                purchaseDate = parsed
            } else {
                purchaseDate = .now
                defaulted += 1
            }

            // The empty-cell-≠-zero rule in reverse: blank is "unvalued",
            // a legitimate value, silent. Only an unparseable cell counts.
            let valueCell = FieldNormalization.trimmed(cells[valueColumn])
            let currentValue: Int?
            if valueCell.isEmpty {
                currentValue = nil
            } else if let parsed = cents(from: valueCell) {
                currentValue = parsed
            } else {
                currentValue = nil
                defaulted += 1
            }

            let desireToKeep: Int
            if let parsed = desire(from: FieldNormalization.trimmed(cells[desireColumn]), in: 1...5) {
                desireToKeep = parsed
            } else {
                desireToKeep = 3
                defaulted += 1
            }

            let conditionValue: Condition
            if let parsed = condition(from: FieldNormalization.trimmed(cells[conditionColumn])) {
                conditionValue = parsed
            } else {
                conditionValue = .excellent
                defaulted += 1
            }

            // The match and the year: blank is the ordinary "no match" /
            // "no year" answer and stays silent; anything unreadable is a
            // counted default, the `Current Value` policy exactly.
            let matchCell = FieldNormalization.trimmed(cells[reverbColumn])
            let productID: Int?
            if matchCell.isEmpty {
                productID = nil
            } else if let parsed = reverbProductID(from: matchCell) {
                productID = parsed
            } else {
                productID = nil
                defaulted += 1
            }

            let yearCell = FieldNormalization.trimmed(cells[yearColumn])
            let itemYear: Int?
            if yearCell.isEmpty {
                itemYear = nil
            } else if let parsed = year(from: yearCell, timeZone: timeZone) {
                itemYear = parsed
            } else {
                itemYear = nil
                defaulted += 1
            }

            // 006, the pair rule (Q6/R3): a row is a sold item iff **both**
            // `Sold Date` and `Sale Price` parse, through the schema's own
            // date and money parsers. Otherwise the item imports unsold and
            // the whole sale is dropped — counted **once** if any of the four
            // sale cells carried anything, however many did, because one
            // dropped sale is one thing lost, not four.
            //
            // Two rules the sheet enforces and this deliberately does not
            // (Q6): a **negative** `Sale Price` is unreadable to
            // `cents(from:)` already — it rejects any sign — so it lands here
            // as the price-unreadable case; a **future** `Sold Date` imports
            // as written, because `day(from:)` has no clock and
            // `Purchase Date` is accepted unbounded the same way.
            let saleCells = [soldDateColumn, salePriceColumn, soldAtColumn, saleNoteColumn]
                .map { FieldNormalization.trimmed(cells[$0]) }
            let soldDate: Date?
            let salePriceCents: Int?
            let saleLocation: String?
            let saleNote: String?
            if let parsedDate = day(from: saleCells[0], timeZone: timeZone),
               let parsedPrice = cents(from: saleCells[1]) {
                soldDate = parsedDate
                salePriceCents = parsedPrice
                saleLocation = FieldNormalization.nilIfBlank(cells[soldAtColumn])
                saleNote = FieldNormalization.nilIfBlank(cells[saleNoteColumn])
            } else {
                soldDate = nil
                salePriceCents = nil
                saleLocation = nil
                saleNote = nil
                if saleCells.contains(where: { !$0.isEmpty }) {
                    defaulted += 1
                }
            }

            // 020 (Q6): the `Reverb Product ID` split — blank is "not
            // recorded" and silent, an unreadable cell is counted.
            let boughtCell = FieldNormalization.trimmed(cells[boughtColumn])
            let bought: NewOrUsed?
            if boughtCell.isEmpty {
                bought = nil
            } else if let parsed = newOrUsed(from: boughtCell) {
                bought = parsed
            } else {
                bought = nil
                defaulted += 1
            }

            let record = ItemExportRecord(
                name: name,
                categoryPath: FieldNormalization.trimmed(cells[categoryColumn]),
                purchasePriceCents: price,
                currencyCode: currency,
                purchaseDate: purchaseDate,
                purchaseLocation: FieldNormalization.nilIfBlank(cells[locationColumn]),
                currentValueCents: currentValue,
                desireToKeep: desireToKeep,
                conditionRawValue: conditionValue.rawValue,
                conditionNotes: FieldNormalization.nilIfBlank(cells[conditionNotesColumn]),
                serialNumber: FieldNormalization.nilIfBlank(cells[serialColumn]),
                notes: FieldNormalization.nilIfBlank(cells[notesColumn]),
                reverbProductID: productID,
                year: itemYear,
                soldDate: soldDate,
                salePriceCents: salePriceCents,
                saleLocation: saleLocation,
                saleNote: saleNote,
                bought: bought,
                firstPhotoID: nil,
                firstPhotoAttribution: nil
            )
            validated.append(
                ValidatedRow(record: record, rowNumber: row.number, defaultedFieldCount: defaulted)
            )
        }

        return ImportPreview(
            validated: validated,
            skipped: skipped,
            defaultedFieldCount: validated.reduce(0) { $0 + $1.defaultedFieldCount }
        )
    }

    /// The wishlist pipeline — `itemsPreview`'s twin over the ten-column
    /// table. Deliberately a parallel implementation, not shared machinery:
    /// each function reads as its spec table, and the tables genuinely
    /// differ (`Added` restores `createdAt`; desire runs 1–3 defaulting
    /// to 2, the `DesireToOwnLevel` midpoint).
    static func wishlistPreview(
        from rows: [CSVRow],
        timeZone: TimeZone = .current
    ) throws -> WishlistImportPreview {
        let shaped = shaped(rows)
        guard let header = shaped.first else { throw HeaderError.mismatch }
        // See `itemsPreview` — the matched width bounds a row's cells.
        let width = try requireWishlistHeader(header)

        let headers = ExportSchema.wishlistHeaders
        func column(_ name: String) -> Int { headers.firstIndex(of: name)! }
        let nameColumn = column("Name")
        let categoryColumn = column("Category")
        let costColumn = column("Estimated Cost")
        let currencyColumn = column("Currency")
        let desireColumn = column("Desire to Own")
        let addedColumn = column("Added")
        let notesColumn = column("Notes")
        let reverbColumn = column("Reverb Product ID")
        let yearColumn = column("Year")
        let lookingForColumn = column("Looking For")

        var validated: [ValidatedRow<WishlistExportRecord>] = []
        var skipped: [SkippedRow] = []

        for row in shaped.dropFirst() {
            guard row.cells.count <= width else {
                skipped.append(SkippedRow(rowNumber: row.number, reason: SkipReason.extraColumns))
                continue
            }
            var cells = row.cells
            cells.append(contentsOf: Array(repeating: "", count: headers.count - cells.count))

            let name = FieldNormalization.trimmed(cells[nameColumn])
            guard !name.isEmpty else {
                skipped.append(SkippedRow(rowNumber: row.number, reason: SkipReason.noName))
                continue
            }

            var defaulted = 0

            let cost: Int
            if let parsed = cents(from: FieldNormalization.trimmed(cells[costColumn])) {
                cost = parsed
            } else {
                cost = 0
                defaulted += 1
            }

            let currencyCell = FieldNormalization.trimmed(cells[currencyColumn])
            let currency: String
            if currencyCell.isEmpty {
                currency = "USD"
            } else if let code = currencyCode(from: currencyCell) {
                currency = code
            } else {
                currency = "USD"
                defaulted += 1
            }

            let desireToOwn: Int
            if let parsed = desire(from: FieldNormalization.trimmed(cells[desireColumn]), in: 1...3) {
                desireToOwn = parsed
            } else {
                desireToOwn = 2
                defaulted += 1
            }

            // `Added` restores the wish's creation date — the round trip
            // preserves when a want was recorded (spec's field table). The
            // commit assigns it onto `createdAt` after construction, since
            // `WishlistItem.init` hard-sets `.now`.
            let createdAt: Date
            if let parsed = day(from: FieldNormalization.trimmed(cells[addedColumn]), timeZone: timeZone) {
                createdAt = parsed
            } else {
                createdAt = .now
                defaulted += 1
            }

            // As in `itemsPreview`: blank silent, unreadable counted.
            let matchCell = FieldNormalization.trimmed(cells[reverbColumn])
            let productID: Int?
            if matchCell.isEmpty {
                productID = nil
            } else if let parsed = reverbProductID(from: matchCell) {
                productID = parsed
            } else {
                productID = nil
                defaulted += 1
            }

            let yearCell = FieldNormalization.trimmed(cells[yearColumn])
            let wantedYear: Int?
            if yearCell.isEmpty {
                wantedYear = nil
            } else if let parsed = year(from: yearCell, timeZone: timeZone) {
                wantedYear = parsed
            } else {
                wantedYear = nil
                defaulted += 1
            }

            // 020 (Q6): as `Bought` in `itemsPreview`.
            let lookingForCell = FieldNormalization.trimmed(cells[lookingForColumn])
            let lookingFor: NewOrUsed?
            if lookingForCell.isEmpty {
                lookingFor = nil
            } else if let parsed = newOrUsed(from: lookingForCell) {
                lookingFor = parsed
            } else {
                lookingFor = nil
                defaulted += 1
            }

            let record = WishlistExportRecord(
                name: name,
                categoryPath: FieldNormalization.trimmed(cells[categoryColumn]),
                estimatedCostCents: cost,
                currencyCode: currency,
                desireToOwn: desireToOwn,
                createdAt: createdAt,
                notes: FieldNormalization.nilIfBlank(cells[notesColumn]),
                reverbProductID: productID,
                year: wantedYear,
                lookingFor: lookingFor,
                firstPhotoID: nil,
                firstPhotoAttribution: nil
            )
            validated.append(
                ValidatedRow(record: record, rowNumber: row.number, defaultedFieldCount: defaulted)
            )
        }

        return ImportPreview(
            validated: validated,
            skipped: skipped,
            defaultedFieldCount: validated.reduce(0) { $0 + $1.defaultedFieldCount }
        )
    }
}

// MARK: - Preview types (plan §Records)

/// One row the import will not create, and why — composed into the
/// confirmation as "Row 7 — no name", numbered as the spreadsheet shows it.
nonisolated struct SkippedRow: Sendable, Equatable {
    let rowNumber: Int
    let reason: String
}

/// One accepted row: the schema record it parsed to (the *export* snapshot
/// type, reused deliberately — plan §Records: schema growth becomes a
/// compile error here), its spreadsheet row number, and how many of its
/// required fields took a counted default.
nonisolated struct ValidatedRow<Record: Sendable>: Sendable {
    let record: Record
    let rowNumber: Int
    let defaultedFieldCount: Int
}

/// What parsing a file produces and the confirmation alert describes —
/// everything the commit needs, nothing store-bound.
nonisolated struct ImportPreview<Record: Sendable>: Sendable {
    let validated: [ValidatedRow<Record>]
    let skipped: [SkippedRow]
    /// Sum across `validated` — counted defaults only; silent blanks
    /// (model-optional fields, blank currency) never appear here.
    let defaultedFieldCount: Int
}

typealias ItemsImportPreview = ImportPreview<ItemExportRecord>
typealias WishlistImportPreview = ImportPreview<WishlistExportRecord>

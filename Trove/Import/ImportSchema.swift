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

    /// Money as the schema reads it: one or more digits, optionally a dot
    /// and one or two fraction digits — nothing else. Pure overflow-checked
    /// integer arithmetic; no `Locale`, no `Decimal`, deliberately.
    /// `Decimal(string:)` stops parsing silently at the first character it
    /// doesn't understand — `"1,250.00"` comes back as 1 — which is exactly
    /// the locale-shaped leniency the spec forbids (011's plan.md carries
    /// the correction note). Signs, symbols, grouping, a trailing dot, a
    /// missing integer digit, and sub-cent precision all return nil; the
    /// field policy turns nil into a counted default.
    static func cents(from field: String) -> Int? {
        let scalars = Array(field.unicodeScalars)
        var index = 0
        var whole = 0
        var wholeDigits = 0
        while index < scalars.count, let digit = digit(scalars[index]) {
            let (shifted, overflow1) = whole.multipliedReportingOverflow(by: 10)
            guard !overflow1 else { return nil }
            let (added, overflow2) = shifted.addingReportingOverflow(digit)
            guard !overflow2 else { return nil }
            whole = added
            wholeDigits += 1
            index += 1
        }
        guard wholeDigits > 0 else { return nil }

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

    /// A date as the schema reads it: exactly `yyyy-MM-dd` (4-2-2 digits —
    /// `2026-1-5` is rejected, matching the writer's zero-padded output),
    /// resolved in a **Gregorian calendar built here over the injected
    /// `TimeZone`** — the same T019/B1 doctrine as `ExportSchema.day`: the
    /// API takes only a `TimeZone`, so the user's preferred-calendar
    /// setting has no way in from this direction either.
    ///
    /// Gregorian `date(from:)` *normalizes* impossible dates (Feb 30 →
    /// Mar 2) rather than failing, so the resolved date is round-tripped
    /// back to components and compared — that's the impossible-date check.
    /// On a day whose local midnight doesn't exist (a spring-forward
    /// transition), `date(from:)` answers the first valid instant instead
    /// and the components still round-trip — pinned by the DST fixture.
    static func day(from field: String, timeZone: TimeZone = .current) -> Date? {
        let scalars = Array(field.unicodeScalars)
        guard scalars.count == 10, scalars[4] == "-", scalars[7] == "-" else { return nil }
        guard
            let year = number(scalars[0...3]),
            let month = number(scalars[5...6]),
            let dayOfMonth = number(scalars[8...9])
        else { return nil }

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

    /// Desire as the schema reads it: an integer inside the given scale —
    /// 1...5 for items, 1...3 for the wishlist (the `DesireLevel` /
    /// `DesireToOwnLevel` scales; the spec's policy is default-and-count,
    /// deliberately not those enums' clamping).
    static func desire(from field: String, in range: ClosedRange<Int>) -> Int? {
        guard let value = Int(field), range.contains(value) else { return nil }
        return value
    }

    /// Condition matched case-insensitively against the five known raw
    /// values (criterion 8) — a hand-typed "Excellent" works.
    static func condition(from field: String) -> Condition? {
        Condition(rawValue: field.lowercased())
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
                firstPhotoID: nil
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

    /// The wishlist pipeline — `itemsPreview`'s twin over the nine-column
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
                firstPhotoID: nil
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

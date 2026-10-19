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


/// One items row, read once into cells and decided later (021, plan §4, Q2):
/// `asNew(now:missingColumns:)` applies `012`'s defaults to it; an update
/// reads the same cells and applies none. A column the file does not have
/// reads `empty`, like a blank cell.
nonisolated struct ItemImportRow: Sendable, Equatable {
    let rowNumber: Int
    let troveID: Cell<UUID>
    // Text is never unreadable: blank (by `ImportSchema.isBlank`) or the
    // trimmed text.
    let name, category, purchaseLocation, conditionNotes, serialNumber, notes,
        saleLocation, saleNote: Cell<String>
    let purchasePrice, currentValue, salePrice: Cell<Int>
    let currency: Cell<String>
    let purchaseDate, soldDate: Cell<Date>
    let desireToKeep, reverbProductID, year: Cell<Int>
    let condition: Cell<Condition>
    let bought: Cell<NewOrUsed>

    /// The row as a new item — nil only when the name is empty. Exactly
    /// `012`'s field policy and counts, as its import shipped (the spec's "the
    /// defaults of `012` are for new rows only"): price, date, desire and
    /// condition default and count when empty or unreadable; currency,
    /// current value, Reverb product, year and Bought count only when
    /// unreadable; the sale is the pair rule, counted once; an unreadable
    /// Trove ID counts once (P7). **One difference (spec Decision 17)**: a
    /// default taken because its column is in `missingColumns` is still
    /// taken and is not counted — only `ExportSchema.itemDefaultedColumns`
    /// can appear in `missingColumns`, the required columns having gated the
    /// file. The currency comes from the `Currency` cell and nowhere else.
    func asNew(now: Date, missingColumns: [String]) -> ValidatedRow<ItemExportRecord>? {
        guard case .value(let name) = name else { return nil }

        var defaulted = 0
        if troveID == .unreadable { defaulted += 1 }

        let price: Int
        if case .value(let parsed) = purchasePrice {
            price = parsed
        } else {
            price = 0
            defaulted += 1
        }

        // Blank currency is the app's own single-currency reality, not a
        // defect worth reporting; a malformed code is.
        let currencyCode: String
        switch currency {
        case .empty: currencyCode = "USD"
        case .value(let code): currencyCode = code
        case .unreadable:
            currencyCode = "USD"
            defaulted += 1
        }

        let date: Date
        if case .value(let parsed) = purchaseDate {
            date = parsed
        } else {
            date = now
            defaulted += 1
        }

        // The empty-cell-≠-zero rule in reverse: blank is "unvalued", a
        // legitimate value, silent. Only an unreadable cell counts.
        let value: Int?
        switch currentValue {
        case .empty: value = nil
        case .value(let parsed): value = parsed
        case .unreadable:
            value = nil
            defaulted += 1
        }

        let desire: Int
        if case .value(let parsed) = desireToKeep {
            desire = parsed
        } else {
            desire = 3
            if !missingColumns.contains(ExportSchema.DefaultedColumn.desireToKeep.rawValue) { defaulted += 1 }
        }

        let grade: Condition
        if case .value(let parsed) = condition {
            grade = parsed
        } else {
            grade = .excellent
            if !missingColumns.contains(ExportSchema.DefaultedColumn.condition.rawValue) { defaulted += 1 }
        }

        // The match and the year: blank is the ordinary "no match" / "no
        // year" answer and stays silent; unreadable is a counted default.
        let productID: Int?
        switch reverbProductID {
        case .empty: productID = nil
        case .value(let parsed): productID = parsed
        case .unreadable:
            productID = nil
            defaulted += 1
        }

        let itemYear: Int?
        switch year {
        case .empty: itemYear = nil
        case .value(let parsed): itemYear = parsed
        case .unreadable:
            itemYear = nil
            defaulted += 1
        }

        // 006, the pair rule (Q6/R3): a sold item iff **both** `Sold Date`
        // and `Sale Price` read. Otherwise the item imports unsold and the
        // whole sale is dropped — counted **once** if any of the four sale
        // cells carried anything, because one dropped sale is one thing lost.
        let sold: (date: Date, cents: Int)?
        if case .value(let parsedDate) = soldDate, case .value(let parsedPrice) = salePrice {
            sold = (parsedDate, parsedPrice)
        } else {
            sold = nil
            let saleEmpty = soldDate == .empty && salePrice == .empty
                && saleLocation == .empty && saleNote == .empty
            if !saleEmpty { defaulted += 1 }
        }

        // 020 (Q6): blank is "not recorded" and silent; unreadable counts.
        let newOrUsed: NewOrUsed?
        switch bought {
        case .empty: newOrUsed = nil
        case .value(let parsed): newOrUsed = parsed
        case .unreadable:
            newOrUsed = nil
            defaulted += 1
        }

        let record = ItemExportRecord(
            name: name,
            categoryPath: category.text ?? "",
            purchasePriceCents: price,
            currencyCode: currencyCode,
            purchaseDate: date,
            purchaseLocation: purchaseLocation.text,
            currentValueCents: value,
            desireToKeep: desire,
            conditionRawValue: grade.rawValue,
            conditionNotes: conditionNotes.text,
            serialNumber: serialNumber.text,
            notes: notes.text,
            reverbProductID: productID,
            year: itemYear,
            soldDate: sold?.date,
            salePriceCents: sold?.cents,
            saleLocation: sold == nil ? nil : saleLocation.text,
            saleNote: sold == nil ? nil : saleNote.text,
            bought: newOrUsed,
            firstPhotoID: nil,
            firstPhotoAttribution: nil
        )
        return ValidatedRow(record: record, rowNumber: rowNumber, defaultedFieldCount: defaulted)
    }
}

/// One wishlist row, read once into cells and decided later (021, plan §4,
/// Q4) — `ItemImportRow`'s twin over the wishlist's columns. A column the
/// file does not have reads `empty`, like a blank cell.
nonisolated struct WishlistImportRow: Sendable, Equatable {
    let rowNumber: Int
    let troveID: Cell<UUID>
    // Text is never unreadable: blank (by `ImportSchema.isBlank`) or the
    // trimmed text.
    let name, category, notes: Cell<String>
    let estimatedCost: Cell<Int>
    let currency: Cell<String>
    /// 1...3, the `DesireToOwnLevel` range.
    let desireToOwn, reverbProductID, year: Cell<Int>
    let added: Cell<Date>
    let lookingFor: Cell<NewOrUsed>

    /// The row as a new wish — nil only when the name is empty. Exactly
    /// `012`'s field policy and counts, as its import shipped: cost, desire
    /// and `Added` default and count when empty or unreadable; currency,
    /// Reverb product, year and `Looking For` count only when unreadable; an
    /// unreadable Trove ID counts once (P7). **One difference (spec Decision
    /// 17)**: a default taken because its column is in `missingColumns` is
    /// still taken and is not counted — only
    /// `ExportSchema.wishlistDefaultedColumns` can appear in
    /// `missingColumns`, the required columns having gated the file. The currency comes from the `Currency` cell and nowhere else.
    func asNew(now: Date, missingColumns: [String]) -> ValidatedRow<WishlistExportRecord>? {
        guard case .value(let name) = name else { return nil }

        var defaulted = 0
        if troveID == .unreadable { defaulted += 1 }

        let cost: Int
        if case .value(let parsed) = estimatedCost {
            cost = parsed
        } else {
            cost = 0
            defaulted += 1
        }

        // As on the items row: blank currency is silent, a malformed code
        // counts.
        let currencyCode: String
        switch currency {
        case .empty: currencyCode = "USD"
        case .value(let code): currencyCode = code
        case .unreadable:
            currencyCode = "USD"
            defaulted += 1
        }

        let desire: Int
        if case .value(let parsed) = desireToOwn {
            desire = parsed
        } else {
            desire = 2
            if !missingColumns.contains(ExportSchema.DefaultedColumn.desireToOwn.rawValue) { defaulted += 1 }
        }

        // `Added` restores the wish's creation date (the spec's field table);
        // the commit assigns it onto `createdAt` after construction.
        let createdAt: Date
        if case .value(let parsed) = added {
            createdAt = parsed
        } else {
            createdAt = now
            if !missingColumns.contains(ExportSchema.DefaultedColumn.added.rawValue) { defaulted += 1 }
        }

        // Blank silent, unreadable counted — as on the items row.
        let productID: Int?
        switch reverbProductID {
        case .empty: productID = nil
        case .value(let parsed): productID = parsed
        case .unreadable:
            productID = nil
            defaulted += 1
        }

        let wantedYear: Int?
        switch year {
        case .empty: wantedYear = nil
        case .value(let parsed): wantedYear = parsed
        case .unreadable:
            wantedYear = nil
            defaulted += 1
        }

        // 020 (Q6): as `Bought` on the items row.
        let newOrUsed: NewOrUsed?
        switch lookingFor {
        case .empty: newOrUsed = nil
        case .value(let parsed): newOrUsed = parsed
        case .unreadable:
            newOrUsed = nil
            defaulted += 1
        }

        let record = WishlistExportRecord(
            name: name,
            categoryPath: category.text ?? "",
            estimatedCostCents: cost,
            currencyCode: currencyCode,
            desireToOwn: desire,
            createdAt: createdAt,
            notes: notes.text,
            reverbProductID: productID,
            year: wantedYear,
            lookingFor: newOrUsed,
            firstPhotoID: nil,
            firstPhotoAttribution: nil
        )
        return ValidatedRow(record: record, rowNumber: rowNumber, defaultedFieldCount: defaulted)
    }
}

private extension Cell<String> {
    /// A text cell as the model's optional field: the text, or nil.
    nonisolated var text: String? {
        if case .value(let text) = self { return text }
        return nil
    }
}

/// What reading a file produces (021, plan §4) — rows in file order, the
/// skips, and what the confirmation reports beside them.
nonisolated struct ImportSheet<Row: Sendable>: Sendable {
    let rows: [Row]
    let skipped: [SkippedRow]
    /// Unrecognised header names as written, in file order.
    let unusedColumns: [String]
    /// The spreadsheet numbers of the rows left out as totals rows — neither
    /// rows nor skips.
    let totalsRowNumbers: [Int]
    /// The slash order the phone's region decided, when the file's own
    /// dates could not; nil when they did, or when it holds no slash date.
    let regionDateOrder: SlashDateOrder?
    /// Decision 17: optional columns the file does not have at all whose blank
    /// is a counted default for a new row — `ExportSchema.itemDefaultedColumns`
    /// or `wishlistDefaultedColumns`. Schema names, schema order.
    let missingDefaultColumns: [String]
}

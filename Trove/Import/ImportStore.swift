import Foundation
import SwiftData

/// What an import will do, counted before anything is written — the
/// confirmation's every line reads from here (021, plan §5). Pure data; the
/// stores below fill it in `plan(for:in:timeZone:now:)`, and `ImportCopy`
/// words it.
nonisolated struct ImportSummary: Sendable, Equatable {
    var added = 0, updated = 0, unchanged = 0
    /// Every row left out, the sheet's and the store's, in row order.
    var skipped: [SkippedRow] = []
    /// Counted defaults on the rows that will be added.
    var defaultedOnNew = 0
    /// Unreadable cells on every row that matched an item — updated or unchanged.
    var unreadableOnUpdates = 0
    var unusedColumns: [String] = []
    var totalsRows: [Int] = []
    var unusedSaleRows = 0
    var regionDateOrder: SlashDateOrder? = nil
    var missingDefaultColumns: [String] = []
    /// Decision 19: rows that will be added **keeping a code from the file** —
    /// a subset of `added`. Never includes a matched row, a row with no code,
    /// or a kept-code row that was skipped.
    var keptCodeAdds = 0
    var writesAnything: Bool { added + updated > 0 }
}

typealias ItemsImportSheet = ImportSheet<ItemImportRow>
typealias WishlistImportSheet = ImportSheet<WishlistImportRow>

/// The one writer of an items import (021, plan §8, Q11) — `ItemSaleStore`'s
/// shape. `plan` reads the store and writes nothing; `apply` writes the plan
/// into the caller's context, and **callers save**, rolling back on a throw.
///
/// MainActor by the project default: it writes through the caller's
/// `ModelContext`.
///
/// This slice is the add path only: every row goes through `asNew` with the
/// sheet's `missingDefaultColumns`, and the Trove ID cell is not read here.
enum ItemImportStore {
    struct Plan {
        let adds: [ValidatedRow<ItemExportRecord>]
        let summary: ImportSummary
    }

    static func plan(
        for sheet: ItemsImportSheet, in context: ModelContext, timeZone: TimeZone, now: Date
    ) throws -> Plan {
        var adds: [ValidatedRow<ItemExportRecord>] = []
        var skipped = sheet.skipped
        for row in sheet.rows {
            // The sheet keeps a nameless row with a readable code, since only
            // the store knows whether it matches (P8); as a new row it has no
            // name, so it is skipped here.
            guard let new = row.asNew(now: now, missingColumns: sheet.missingDefaultColumns) else {
                skipped.append(SkippedRow(rowNumber: row.rowNumber, reason: ImportSchema.SkipReason.noName))
                continue
            }
            adds.append(new)
        }

        var summary = ImportSummary()
        summary.added = adds.count
        summary.skipped = skipped.sorted { $0.rowNumber < $1.rowNumber }
        summary.defaultedOnNew = adds.reduce(0) { $0 + $1.defaultedFieldCount }
        summary.unusedColumns = sheet.unusedColumns
        summary.totalsRows = sheet.totalsRowNumbers
        summary.regionDateOrder = sheet.regionDateOrder
        summary.missingDefaultColumns = sheet.missingDefaultColumns
        return Plan(adds: adds, summary: summary)
    }

    /// Inserts the adds at the end of custom order, in file order — the
    /// commit `ItemListViewModel.confirmImport` carried, moved here.
    /// Callers save, and roll back on a throw.
    static func apply(_ plan: Plan, in context: ModelContext, now: Date) throws {
        // Placement is computed HERE, never at parse time: a CloudKit
        // arrival — or a hand-add — between the alert and the confirm must
        // not stale the base.
        let existing = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        let base = ManualOrderHelper.nextPosition(after: existing)

        // The canonical path set is fetched once; the per-row instance
        // method is a full two-entity fetch per call (T009's reason for
        // the static). Batch-internal casing resolves by file row order,
        // first occurrence wins, each resolved path joining the set.
        // Load-bearing beyond tidiness: chip casing follows the earliest
        // `createdAt` across both entities, so an import restoring old
        // dates could otherwise steal an existing path's casing.
        var knownPaths = (try? CategoryPathHelper(modelContext: context).allCategoryPaths()) ?? []

        for (offset, validated) in plan.adds.enumerated() {
            let record = validated.record
            let path = CategoryPathHelper.canonicalize(record.categoryPath, against: knownPaths)
            if !path.isEmpty,
               !knownPaths.contains(where: { $0.caseInsensitiveCompare(path) == .orderedSame }) {
                knownPaths.append(path)
            }
            let item = Item(
                name: record.name,
                categoryPath: path,
                purchasePriceCents: record.purchasePriceCents,
                purchaseDate: record.purchaseDate,
                currencyCode: record.currencyCode,
                serialNumber: record.serialNumber,
                purchaseLocation: record.purchaseLocation,
                currentValueCents: record.currentValueCents,
                desireToKeep: record.desireToKeep,
                condition: Condition(rawValue: record.conditionRawValue) ?? .excellent,
                conditionNotes: record.conditionNotes,
                notes: record.notes,
                sortOrder: base + offset,
                // 002/T016a: the CSV's two appended columns restore the
                // Reverb match and the year, so a re-imported item asks
                // the same question of the market as before it left.
                reverbProductID: record.reverbProductID,
                year: record.year,
                // 020: the `Bought` column comes back with the row.
                bought: record.bought
            )
            context.insert(item)
            // 006 (plan §7, Q6): a row carrying both halves of the pair
            // arrives sold. It points at no plan — an imported sale has
            // no wishlist item on this device it could have funded
            // (P11) — and `Item.sale` writes the four fields, so the
            // date-without-price shape never reaches the store.
            if let soldDate = record.soldDate, let salePriceCents = record.salePriceCents {
                item.sale = Sale(
                    date: soldDate,
                    priceCents: salePriceCents,
                    location: record.saleLocation,
                    note: record.saleNote
                )
            }
        }
    }
}

/// `ItemImportStore`'s twin over the wishlist — the same two functions, with
/// the wishlist's one extra move: `Added` restores `createdAt`.
enum WishlistImportStore {
    struct Plan {
        let adds: [ValidatedRow<WishlistExportRecord>]
        let summary: ImportSummary
    }

    static func plan(
        for sheet: WishlistImportSheet, in context: ModelContext, timeZone: TimeZone, now: Date
    ) throws -> Plan {
        var adds: [ValidatedRow<WishlistExportRecord>] = []
        var skipped = sheet.skipped
        for row in sheet.rows {
            // As on the items side: a nameless row the sheet kept for its
            // code is skipped as a new row.
            guard let new = row.asNew(now: now, missingColumns: sheet.missingDefaultColumns) else {
                skipped.append(SkippedRow(rowNumber: row.rowNumber, reason: ImportSchema.SkipReason.noName))
                continue
            }
            adds.append(new)
        }

        var summary = ImportSummary()
        summary.added = adds.count
        summary.skipped = skipped.sorted { $0.rowNumber < $1.rowNumber }
        summary.defaultedOnNew = adds.reduce(0) { $0 + $1.defaultedFieldCount }
        summary.unusedColumns = sheet.unusedColumns
        summary.totalsRows = sheet.totalsRowNumbers
        summary.regionDateOrder = sheet.regionDateOrder
        summary.missingDefaultColumns = sheet.missingDefaultColumns
        return Plan(adds: adds, summary: summary)
    }

    /// The commit `WishlistViewModel.confirmImport` carried, moved here.
    /// Callers save, and roll back on a throw.
    static func apply(_ plan: Plan, in context: ModelContext, now: Date) throws {
        // Bought entries included, deliberately (015 plan §4): the import
        // appends past every stored position, not past the visible ones.
        let existing = (try? context.fetch(FetchDescriptor<WishlistItem>())) ?? []
        let base = ManualOrderHelper.nextPosition(after: existing)
        var knownPaths = (try? CategoryPathHelper(modelContext: context).allCategoryPaths()) ?? []

        for (offset, validated) in plan.adds.enumerated() {
            let record = validated.record
            let path = CategoryPathHelper.canonicalize(record.categoryPath, against: knownPaths)
            if !path.isEmpty,
               !knownPaths.contains(where: { $0.caseInsensitiveCompare(path) == .orderedSame }) {
                knownPaths.append(path)
            }
            let wish = WishlistItem(
                name: record.name,
                categoryPath: path,
                estimatedCostCents: record.estimatedCostCents,
                currencyCode: record.currencyCode,
                notes: record.notes,
                desireToOwn: record.desireToOwn,
                sortOrder: base + offset,
                // As on the items side (002/T016a): the match and the
                // year come back with the row.
                reverbProductID: record.reverbProductID,
                year: record.year,
                // 020: and so does `Looking For`.
                lookingFor: record.lookingFor
            )
            // Assigned after construction deliberately: the init hard-sets
            // `.now` and has no parameter — `Added` restores when the want
            // was actually recorded (plan §The commit path; don't "fix"
            // the init).
            wish.createdAt = record.createdAt
            context.insert(wish)
        }
    }
}

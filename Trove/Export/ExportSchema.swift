import Foundation
import SwiftData

/// The canonical export schema — the single source `012-data-import` will
/// parse against. Headers, column order, and serialization rules are pinned
/// in `specs/011-data-export/plan.md`'s "The canonical CSV schema" section
/// and implemented here, nowhere else.
///
/// Everything in this file is explicitly `nonisolated`: the project-wide
/// MainActor default would otherwise capture these types, and export
/// generation must run off the main actor (plan.md's Concurrency section).

/// One owned item, snapshotted into plain `Sendable` values at export time.
/// `@Model` objects are non-`Sendable` and never cross the isolation
/// boundary; this does.
nonisolated struct ItemExportRecord: Sendable {
    let name: String
    let categoryPath: String
    let purchasePriceCents: Int
    let currencyCode: String
    let purchaseDate: Date
    let purchaseLocation: String?
    let currentValueCents: Int?
    let desireToKeep: Int
    let conditionRawValue: String
    let conditionNotes: String?
    let serialNumber: String?
    let notes: String?

    /// The display-order first photo, chosen at snapshot time on the main
    /// actor (plan.md: `PhotoSelection.inDisplayOrder` is the one definition
    /// of photo order). Only the identifier crosses to the background.
    let firstPhotoID: PersistentIdentifier?
}

/// One wanted item, same snapshot rules as `ItemExportRecord`.
nonisolated struct WishlistExportRecord: Sendable {
    let name: String
    let categoryPath: String
    let estimatedCostCents: Int
    let currencyCode: String
    let desireToOwn: Int
    let createdAt: Date
    let notes: String?
    let firstPhotoID: PersistentIdentifier?
}

/// The PDF cover page's figures, computed by the view model with its own
/// arithmetic — which is how criterion 8 ("cover figures match the app's")
/// holds by construction rather than by re-derivation.
nonisolated struct CoverSummary: Sendable {
    let title: String
    /// The active filter, in the same words the chips use — "All items",
    /// "Category: Guitars".
    let coverageLabel: String
    let generatedAt: Date
    let itemCount: Int
    let totals: Totals

    nonisolated enum Totals: Sendable {
        /// The unvalued count keeps the value figure an honest floor, the
        /// same rule the list header and dashboard follow.
        case items(currentValueCents: Int, paidCents: Int, unvaluedCount: Int)
        case wishlist(estimatedCostCents: Int)
    }
}

/// What `CSVWriter` writes: a header row and data rows, already serialized.
nonisolated struct CSVTable: Sendable {
    let headers: [String]
    let rows: [[String]]
}

/// One label/value pair in a PDF entry's field grid.
nonisolated struct PDFField: Sendable {
    let label: String
    let value: String
}

/// One item's entry in the PDF collection document.
nonisolated struct PDFEntry: Sendable {
    let eyebrow: String
    let name: String
    let fields: [PDFField]
    let notes: String?
    let photoID: PersistentIdentifier?
}

/// Everything `PDFComposer` needs to render one document.
nonisolated struct PDFDocumentModel: Sendable {
    let cover: CoverSummary
    let entries: [PDFEntry]
}

extension ItemExportRecord {
    /// Snapshots a live item into the `Sendable` record that crosses to
    /// generation. `@MainActor` explicitly: the record type is `nonisolated`,
    /// but this initializer reads MainActor-isolated model properties — it
    /// runs at snapshot time on the main actor (plan.md's Architecture
    /// section), which is also where the first photo must be chosen, via the
    /// one definition of photo display order.
    @MainActor
    init(item: Item) {
        self.init(
            name: item.name,
            categoryPath: item.categoryPath,
            purchasePriceCents: item.purchasePriceCents,
            currencyCode: item.currencyCode,
            purchaseDate: item.purchaseDate,
            purchaseLocation: item.purchaseLocation,
            currentValueCents: item.currentValueCents,
            desireToKeep: item.desireToKeep,
            conditionRawValue: item.conditionRawValue,
            conditionNotes: item.conditionNotes,
            serialNumber: item.serialNumber,
            notes: item.notes,
            firstPhotoID: PhotoSelection.inDisplayOrder(item.photos ?? []).first?.persistentModelID
        )
    }
}

extension WishlistExportRecord {
    /// See `ItemExportRecord.init(item:)` — same snapshot rules, wishlist
    /// fields.
    @MainActor
    init(item: WishlistItem) {
        self.init(
            name: item.name,
            categoryPath: item.categoryPath,
            estimatedCostCents: item.estimatedCostCents,
            currencyCode: item.currencyCode,
            desireToOwn: item.desireToOwn,
            createdAt: item.createdAt,
            notes: item.notes,
            firstPhotoID: PhotoSelection.inDisplayOrder(item.photos ?? []).first?.persistentModelID
        )
    }
}

nonisolated enum ExportSchema {
    /// The items CSV's column order — the contract `012` matches
    /// byte-for-byte. Reordering or renaming is a schema change, made here
    /// and in plan.md together or not at all.
    static let itemHeaders = [
        "Name", "Category", "Purchase Price", "Currency", "Purchase Date",
        "Purchase Location", "Current Value", "Desire to Keep", "Condition",
        "Condition Notes", "Serial Number", "Notes",
    ]

    static let wishlistHeaders = [
        "Name", "Category", "Estimated Cost", "Currency", "Desire to Own",
        "Added", "Notes",
    ]

    /// Money as the schema writes it: plain decimal, always two places, dot
    /// separator, no symbol, no grouping. Pure integer arithmetic — no locale
    /// API exists anywhere in this path, which is what carries criterion 7.
    /// Display formatting lives in `Int+Currency.swift` and is a deliberately
    /// separate concern; the two must be allowed to diverge (plan.md's
    /// "Money and date serialization").
    static func money(cents: Int) -> String {
        let sign = cents < 0 ? "-" : ""
        let magnitude = abs(cents)
        return "\(sign)\(magnitude / 100).\(String(format: "%02d", magnitude % 100))"
    }

    /// A date as the schema writes it: the calendar day, `yyyy-MM-dd`, in the
    /// given calendar — the device's by default, which is the day the detail
    /// screen shows (spec.md's amended CSV date rule; the timezone caveat
    /// lives with the schema section in plan.md).
    static func day(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        // The three requested components are always present for a valid Date.
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// One CSV row, columns exactly per `itemHeaders`. Nil fields are empty
    /// cells — and for `Current Value` the emptiness means something: unvalued
    /// is not worthless, the same distinction the model and dashboard draw.
    static func row(from record: ItemExportRecord, calendar: Calendar = .current) -> [String] {
        [
            record.name,
            record.categoryPath,
            money(cents: record.purchasePriceCents),
            record.currencyCode,
            day(from: record.purchaseDate, calendar: calendar),
            record.purchaseLocation ?? "",
            record.currentValueCents.map { money(cents: $0) } ?? "",
            String(record.desireToKeep),
            record.conditionRawValue,
            record.conditionNotes ?? "",
            record.serialNumber ?? "",
            record.notes ?? "",
        ]
    }

    /// One CSV row, columns exactly per `wishlistHeaders`.
    static func row(from record: WishlistExportRecord, calendar: Calendar = .current) -> [String] {
        [
            record.name,
            record.categoryPath,
            money(cents: record.estimatedCostCents),
            record.currencyCode,
            String(record.desireToOwn),
            day(from: record.createdAt, calendar: calendar),
            record.notes ?? "",
        ]
    }

    static func itemsTable(
        _ records: [ItemExportRecord],
        calendar: Calendar = .current
    ) -> CSVTable {
        CSVTable(headers: itemHeaders, rows: records.map { row(from: $0, calendar: calendar) })
    }

    static func wishlistTable(
        _ records: [WishlistExportRecord],
        calendar: Calendar = .current
    ) -> CSVTable {
        CSVTable(headers: wishlistHeaders, rows: records.map { row(from: $0, calendar: calendar) })
    }
}

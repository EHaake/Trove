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
    /// 002: the match and the year — carried by the CSV (P17, Decision
    /// 29) so a re-import restores them; `nil` on an unmatched or
    /// year-less item, and always `nil` from a file written before the
    /// columns existed. Not presented by the PDF.
    let reverbProductID: Int?
    let year: Int?

    /// The display-order first photo, chosen at snapshot time on the main
    /// actor (plan.md: `PhotoSelection.inDisplayOrder` is the one definition
    /// of photo order). Only the identifier crosses to the background.
    ///
    /// Always `nil` on a record built by `012`'s import pipeline — CSV
    /// carries no photo representation, so a record is not proof of a live
    /// snapshot. Export-side code may rely on the *shape*, never on the
    /// field being populated.
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
    /// As on `ItemExportRecord` (002).
    let reverbProductID: Int?
    let year: Int?
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
    /// Money, dates, and serials draw in the mono face — the same per-row
    /// distinction the detail screens make.
    let isMono: Bool

    init(label: String, value: String, isMono: Bool = false) {
        self.label = label
        self.value = value
        self.isMono = isMono
    }
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
            reverbProductID: item.reverbProductID,
            year: item.year,
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
            reverbProductID: item.reverbProductID,
            year: item.year,
            firstPhotoID: PhotoSelection.inDisplayOrder(item.photos ?? []).first?.persistentModelID
        )
    }
}

extension PDFEntry {
    /// The item entry's field grid. Same field *set* as the CSV (plan.md's
    /// rule) — less the Reverb product identifier and the year, keys the CSV
    /// carries so a re-import restores the match and the narrowing, not
    /// fields the person reads (002, plan §7; the fetched market figures are
    /// in neither document) — presented in the detail screen's own
    /// vocabulary and formats — "Worth now", "Bought from", whole-dollar
    /// money, "Not yet valued" for the unvalued case — because the PDF is
    /// presentation where the CSV is data. Empty optionals are skipped,
    /// exactly as the detail screen filters its empty rows.
    nonisolated init(record: ItemExportRecord, timeZone: TimeZone = .current) {
        var fields: [PDFField] = [
            PDFField(
                label: "Paid",
                value: record.purchasePriceCents.formattedAsWholeCurrency(currencyCode: record.currencyCode),
                isMono: true
            ),
            PDFField(
                label: "Worth now",
                value: record.currentValueCents
                    .map { $0.formattedAsWholeCurrency(currencyCode: record.currencyCode) }
                    ?? "Not yet valued",
                isMono: record.currentValueCents != nil
            ),
            PDFField(label: "Currency", value: record.currencyCode, isMono: true),
            PDFField(
                label: "Bought",
                value: ExportSchema.day(from: record.purchaseDate, timeZone: timeZone),
                isMono: true
            ),
        ]
        if let location = record.purchaseLocation, !location.isEmpty {
            fields.append(PDFField(label: "Bought from", value: location))
        }
        fields.append(PDFField(label: "Desire to keep", value: "\(record.desireToKeep) / 5", isMono: true))
        fields.append(PDFField(label: "Condition", value: record.conditionRawValue.capitalized))
        if let conditionNotes = record.conditionNotes, !conditionNotes.isEmpty {
            fields.append(PDFField(label: "Condition notes", value: conditionNotes))
        }
        if let serial = record.serialNumber, !serial.isEmpty {
            fields.append(PDFField(label: "Serial number", value: serial, isMono: true))
        }

        self.init(
            eyebrow: record.categoryPath.split(separator: "/").joined(separator: " · "),
            name: record.name,
            fields: fields,
            notes: (record.notes?.isEmpty == false) ? record.notes : nil,
            photoID: record.firstPhotoID
        )
    }

    /// See `init(record: ItemExportRecord, ...)` — wishlist vocabulary, and
    /// the same carve-out: no Reverb identifier, no year, no market figure.
    nonisolated init(record: WishlistExportRecord, timeZone: TimeZone = .current) {
        self.init(
            eyebrow: record.categoryPath.split(separator: "/").joined(separator: " · "),
            name: record.name,
            fields: [
                PDFField(
                    label: "Estimated cost",
                    value: record.estimatedCostCents.formattedAsWholeCurrency(currencyCode: record.currencyCode),
                    isMono: true
                ),
                PDFField(label: "Currency", value: record.currencyCode, isMono: true),
                PDFField(label: "Desire to own", value: "\(record.desireToOwn) / 3", isMono: true),
                PDFField(
                    label: "Added",
                    value: ExportSchema.day(from: record.createdAt, timeZone: timeZone),
                    isMono: true
                ),
            ],
            notes: (record.notes?.isEmpty == false) ? record.notes : nil,
            photoID: record.firstPhotoID
        )
    }
}

nonisolated enum ExportSchema {
    /// The items CSV's column order — the contract `012` matches
    /// byte-for-byte. Reordering or renaming is a schema change, made here
    /// and in plan.md together or not at all.
    ///
    /// **Append-only** (002, Q16): a column may be added at the end and
    /// never renamed, reordered or removed, which is what lets the import
    /// gate accept a file written by an older Trove. `Reverb Product ID`
    /// and `Year` are 002's two appended columns.
    static let itemHeaders = [
        "Name", "Category", "Purchase Price", "Currency", "Purchase Date",
        "Purchase Location", "Current Value", "Desire to Keep", "Condition",
        "Condition Notes", "Serial Number", "Notes", "Reverb Product ID",
        "Year",
    ]

    static let wishlistHeaders = [
        "Name", "Category", "Estimated Cost", "Currency", "Desire to Own",
        "Added", "Notes", "Reverb Product ID", "Year",
    ]

    /// Every column count at which a shipped layout ended, oldest first —
    /// the widths `ImportSchema`'s gate accepts as a prefix of the current
    /// headers (002, plan §7). 12 is the layout `011`/`012` shipped, before
    /// `Reverb Product ID` and `Year` were appended. A width is added here
    /// only when a *released* layout ends, never speculatively: an entry
    /// that never shipped would accept a file Trove never wrote.
    static let itemSchemaBoundaries = [12]

    /// See `itemSchemaBoundaries` — 7 is the shipped wishlist layout.
    static let wishlistSchemaBoundaries = [7]

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

    /// A date as the schema writes it: the calendar day, `yyyy-MM-dd`, in
    /// the given time zone — the device's by default, which is the day the
    /// detail screen shows (spec.md's amended CSV date rule; the timezone
    /// caveat lives with the schema section in plan.md).
    ///
    /// The calendar is **always proleptic Gregorian, built here** — the API
    /// deliberately takes only a `TimeZone`, so the user's preferred-calendar
    /// setting cannot leak in (T019/B1: the first implementation defaulted
    /// to `Calendar.current`, which follows that setting — a device set to
    /// the Buddhist calendar would have written year 2569 into a canonical
    /// file and its filenames). Identifier-independence is structural, the
    /// same way integer math makes the money path locale-free.
    static func day(from date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        // The three requested components are always present for a valid Date.
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// One CSV row, columns exactly per `itemHeaders`. Nil fields are empty
    /// cells — and for `Current Value` the emptiness means something: unvalued
    /// is not worthless, the same distinction the model and dashboard draw.
    static func row(from record: ItemExportRecord, timeZone: TimeZone = .current) -> [String] {
        [
            record.name,
            record.categoryPath,
            money(cents: record.purchasePriceCents),
            record.currencyCode,
            day(from: record.purchaseDate, timeZone: timeZone),
            record.purchaseLocation ?? "",
            record.currentValueCents.map { money(cents: $0) } ?? "",
            String(record.desireToKeep),
            record.conditionRawValue,
            record.conditionNotes ?? "",
            record.serialNumber ?? "",
            record.notes ?? "",
            record.reverbProductID.map(String.init) ?? "",
            record.year.map(String.init) ?? "",
        ]
    }

    /// One CSV row, columns exactly per `wishlistHeaders`.
    static func row(from record: WishlistExportRecord, timeZone: TimeZone = .current) -> [String] {
        [
            record.name,
            record.categoryPath,
            money(cents: record.estimatedCostCents),
            record.currencyCode,
            String(record.desireToOwn),
            day(from: record.createdAt, timeZone: timeZone),
            record.notes ?? "",
            record.reverbProductID.map(String.init) ?? "",
            record.year.map(String.init) ?? "",
        ]
    }

    static func itemsTable(
        _ records: [ItemExportRecord],
        timeZone: TimeZone = .current
    ) -> CSVTable {
        CSVTable(headers: itemHeaders, rows: records.map { row(from: $0, timeZone: timeZone) })
    }

    static func wishlistTable(
        _ records: [WishlistExportRecord],
        timeZone: TimeZone = .current
    ) -> CSVTable {
        CSVTable(headers: wishlistHeaders, rows: records.map { row(from: $0, timeZone: timeZone) })
    }
}

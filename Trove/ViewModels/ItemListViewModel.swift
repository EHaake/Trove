import Foundation
import Observation
import SwiftData

/// Browse, filter, search and sort owned items.
///
/// `categoryFilter`, `searchText` and `sortOrder` are plain properties so the
/// view can bind controls straight to them; nothing recomputes until `load()`
/// is called.
/// That keeps the reload point explicit and the type trivially testable,
/// rather than hiding fetches inside property observers.
@Observable
final class ItemListViewModel {
    /// Most orders have one sensible direction — keepers and most recent
    /// lead, full stop — but Value carries both, as a labeled pair rather
    /// than a toggle: a direction switch hidden behind re-selecting the
    /// active option is exactly the kind of control that gets lost.
    /// (The pair reverses this enum's original "one direction each" rule —
    /// requested by the person steering the project during Phase 6 review;
    /// `tasks.md`'s T033a records it.)
    ///
    /// "Custom" leads the menu the way the wishlist's manual option does —
    /// same convention on both lists (010) — but the *default* stays Date:
    /// unlike the wishlist, whose manual order has been its single ordering
    /// since 001, an item collection's most recent purchase leading is the
    /// shipped behavior this spec doesn't change.
    enum SortOrder: String, CaseIterable, Identifiable {
        case custom
        case purchaseDate
        case currentValue
        case currentValueAscending
        case marketFigure
        case marketFigureAscending
        case desireToKeep

        var id: String { rawValue }

        /// What the sort control calls this. Here rather than in the view so
        /// the list and any future control can't disagree.
        var label: String {
            switch self {
            case .custom: "Custom"
            case .purchaseDate: "Date"
            case .currentValue: "Value ↓"
            case .currentValueAscending: "Value ↑"
            // The Market pair sits straight after the Value pair, same
            // order (002 Q11), and reads its labels from `MarketCopy` —
            // "Market", never "value", is what the figure is called.
            case .marketFigure: MarketCopy.sortDescending
            case .marketFigureAscending: MarketCopy.sortAscending
            case .desireToKeep: "Desire"
            }
        }
    }

    var categoryFilter: String = ""

    /// Free text over name and serial number. Narrows the same set the
    /// category filter narrows rather than replacing it — spec.md is explicit
    /// that the two combine, so a category chip stays in force while typing.
    var searchText: String = ""

    /// Narrows to items with no value entered — the destination of the
    /// dashboard's "Value →" callout.
    ///
    /// Combines with the category filter and search the same way they combine
    /// with each other: every active narrowing applies to the same set. Set
    /// from outside via `AppRouter`, and the only filter with no control of its
    /// own in the header, so the chip row grows a dismissible chip while it's on
    /// — a filter the user can't see or clear is worse than one they can't set.
    var showsOnlyUnvalued: Bool = false

    var sortOrder: SortOrder = .purchaseDate

    private(set) var items: [Item] = []
    private(set) var loadFailureMessage: String?

    /// This device's market figures for the items on screen, rebuilt on
    /// every `load()` from one fetch of the figure rows (plan §5) — never
    /// the history. What the rows' arrows and the Market sort read, and the
    /// only place either of them gets a figure, so the two can't disagree.
    private(set) var marketSummaries: [UUID: MarketSummary] = [:]

    /// Every category path in use, for the filter chips. Includes paths whose
    /// items the current filter or search excludes — otherwise choosing one
    /// filter would hide the means of choosing another, and typing a query
    /// would dissolve the chip row underneath the field.
    private(set) var categoryOptions: [String] = []

    /// Short chip labels keyed by path — leaf-only where unambiguous. Computed
    /// once per load rather than per render.
    private(set) var categoryLabels: [String: String] = [:]

    /// Owned items before any narrowing. Held so an empty list can tell an
    /// empty collection apart from a filter that excluded everything — the two
    /// need opposite invitations.
    private(set) var totalCount = 0

    var isEmpty: Bool { items.isEmpty }

    /// Which empty state applies, or `nil` when there's something to show.
    var emptyReason: ListEmptyReason? {
        ListEmptyReason.reason(
            totalCount: totalCount,
            visibleCount: items.count,
            searchText: searchText,
            categoryFilter: categoryFilter,
            showsOnlyUnvalued: showsOnlyUnvalued,
            mayStillBeImporting: syncMonitor.mayStillBeImporting
        )
    }

    /// Combined current value of the items on screen, so the header total
    /// tracks the filter. Un-valued items contribute nothing rather than
    /// counting as zero — the same floor-not-total rule as the dashboard.
    var totalCurrentValueCents: Int {
        items.compactMap(\.currentValueCents).reduce(0, +)
    }

    /// How many of the items on screen have no value entered, so the header
    /// can be honest that the total above is a floor.
    var unvaluedCount: Int {
        items.count { $0.currentValueCents == nil }
    }

    private let modelContext: ModelContext

    private let syncMonitor: SyncMonitor

    private let exportService: any ExportService

    private let importService: any ImportService

    private let now: () -> Date

    /// - Parameters:
    ///   - syncMonitor: defaults to a store with no mirror, so tests and
    ///     previews get the settled behaviour unless they ask otherwise.
    ///   - exportService: defaults to the live file-staging service over this
    ///     context's container; tests inject a fake and assert on what the
    ///     intents hand over (plan.md's Architecture section).
    ///   - importService: same injection rule, 012's side of the boundary.
    ///   - now: the clock the market figures' freshness is measured
    ///     against (002/T012), injected so a test can age a figure past the
    ///     thirty-day window without waiting a month.
    init(
        modelContext: ModelContext,
        syncMonitor: SyncMonitor = .notSyncing,
        exportService: (any ExportService)? = nil,
        importService: (any ImportService)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.syncMonitor = syncMonitor
        self.exportService = exportService ?? FileExportService(container: modelContext.container)
        self.importService = importService ?? FileImportService()
        self.now = now
    }

    /// Dragging only makes sense against the real, whole list in its own
    /// order — same rule as `WishlistViewModel.canReorder`, with this
    /// screen's third narrowing included: the un-valued filter hides rows
    /// exactly the way a category or query does, so it blocks reordering
    /// for the same reason.
    var canReorder: Bool {
        sortOrder == .custom
            && categoryFilter.isEmpty
            && SearchMatching.normalized(searchText).isEmpty
            && !showsOnlyUnvalued
    }

    /// Whether this device might still be receiving the collection. Read by
    /// the empty states, and by the note appended to the ones that survive
    /// mid-import.
    var mayStillBeImporting: Bool { syncMonitor.mayStillBeImporting }

    /// Bumped each time an import lands, so the screen can refetch — see
    /// `SyncMonitor.completedImports`.
    var completedImports: Int { syncMonitor.completedImports }

    func load() {
        loadFailureMessage = nil
        do {
            let all = try modelContext.fetch(FetchDescriptor<Item>())
            totalCount = all.count
            // Before the sort, not after: the Market orders read these.
            marketSummaries = Self.summaries(for: all, in: modelContext, now: now())
            items = all
                // `isWithin`, not `matchesPrefix`: a chip is a category that
                // exists, so "Music/Amps" must not also match
                // "Music/Amplifiers". The typing rule stays in the picker.
                .filter { CategoryPathHelper.path($0.categoryPath, isWithin: categoryFilter) }
                // Design's field says "name, brand, serial"; there is no brand
                // in the schema, same gap `ItemRow`'s meta line works around.
                .filter { SearchMatching.matches(query: searchText, in: [$0.name, $0.serialNumber]) }
                .filter { !showsOnlyUnvalued || $0.currentValueCents == nil }
                .sorted(by: isOrderedBefore)
            // Built from the unfiltered fetch, so the chips stay put as the
            // filter changes — and from owned items only, so the row doesn't
            // offer categories that only wishlist entries sit in.
            categoryOptions = CategoryPathHelper.sortedDistinctPaths(
                all.map { (path: $0.categoryPath, createdAt: $0.createdAt) }
            )
            categoryLabels = CategoryPathHelper.displayLabels(for: categoryOptions)
        } catch {
            loadFailureMessage = error.localizedDescription
            totalCount = 0
            items = []
            categoryOptions = []
            categoryLabels = [:]
            marketSummaries = [:]
        }
    }

    /// One fetch of the figure rows, narrowed to the items just fetched.
    ///
    /// A read that throws reads as "nothing stored" — the same direction
    /// `MarketSectionState.resolve(subjectID:…)` takes, and for the same
    /// reason: the device's own market rows are an addition to the
    /// collection, so a local-store problem must not empty the list.
    private static func summaries(for items: [Item], in context: ModelContext, now: Date) -> [UUID: MarketSummary] {
        let figures = ((try? MarketIndex.load(from: context)) ?? .empty).figures
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            figures[item.id].map { (item.id, MarketSummary(snapshot: $0, now: now)) }
        })
    }

    /// The trend the row's arrow draws, or nil for an unmatched item, one
    /// with no figure fetched here, or one whose history can't say yet.
    func trend(for id: UUID) -> MarketTrend? {
        marketSummaries[id]?.trend
    }

    /// Deletes an owned item by id, on the same shape as
    /// `WishlistViewModel.delete(id:)` — the list's swipe (T015) routes here
    /// rather than touching the store itself, per `DeletionGuardTests`'
    /// structural rule, and this new path is inside that rule from day one.
    ///
    /// Photos cascade with it; any sell plan that selected it drops it, the
    /// wishlist entries themselves untouched — the same consequences
    /// `ItemDeleteCopy.message` promises before this runs.
    func delete(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }

        modelContext.delete(item)
        do {
            // 002: the device's market rows for this item go with it.
            try MarketLocalStore.clear(subjectID: id, in: modelContext)
            try modelContext.save()
        } catch {
            loadFailureMessage = error.localizedDescription
        }
        load()
    }

    /// Applies a drag through `ManualOrderHelper`, exactly as
    /// `WishlistViewModel.move` does — one renumbering rule, both lists.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard canReorder else { return }

        items = ManualOrderHelper.reorder(items, fromOffsets: source, toOffset: destination)

        do {
            try modelContext.save()
        } catch {
            loadFailureMessage = error.localizedDescription
        }
    }

    /// Whether a row can move one step toward the top. False at the top of
    /// the list, and false whenever the drag itself wouldn't be offered, so
    /// the two reorder mechanisms can't disagree about when reordering is
    /// available. Since T029b the views no longer read this to gate the
    /// VoiceOver actions (position-conditional AX content breaks a settling
    /// drag) — it survives as the boundary guard inside `moveUp`/`moveDown`,
    /// which is what makes the always-offered actions safe to call anywhere.
    func canMoveUp(id: UUID) -> Bool {
        guard canReorder, let index = items.firstIndex(where: { $0.id == id }) else { return false }
        return index > 0
    }

    /// See `canMoveUp(id:)`. False at the bottom of the list.
    func canMoveDown(id: UUID) -> Bool {
        guard canReorder, let index = items.firstIndex(where: { $0.id == id }) else { return false }
        return index < items.count - 1
    }

    /// One step toward the top: VoiceOver's equivalent of a short drag,
    /// routed through the same `move(fromOffsets:toOffset:)` as the gesture
    /// so there is one reorder path to keep correct, not two.
    func moveUp(id: UUID) {
        guard canMoveUp(id: id), let index = items.firstIndex(where: { $0.id == id }) else { return }
        move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
    }

    /// See `moveUp(id:)`. The `+ 2` is `onMove`'s convention: the destination
    /// indexes the array *before* removal, so one step down from `index`
    /// means inserting ahead of the element two positions along.
    func moveDown(id: UUID) {
        guard canMoveDown(id: id), let index = items.firstIndex(where: { $0.id == id }) else { return }
        move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
    }

    /// Creates a copy per spec.md's duplicate flow, immediately and without
    /// confirmation: every field as-is except the serial number, which is
    /// cleared — it identifies one physical unit, and carrying it over would
    /// have two rows claiming the same one. Photos become genuinely new
    /// `Photo` rows with duplicated `.externalStorage` data; the
    /// one-photo-one-parent rule (`PhotoOwnershipTests`) allows no sharing,
    /// so the storage cost is real and spec.md accepts it explicitly. Sell
    /// Plan membership is not inherited. The copy lands immediately after
    /// the original in manual order.
    func duplicate(id: UUID) {
        guard let original = items.first(where: { $0.id == id }) else { return }

        let copy = Item(
            name: original.name,
            categoryPath: original.categoryPath,
            purchasePriceCents: original.purchasePriceCents,
            purchaseDate: original.purchaseDate,
            currencyCode: original.currencyCode,
            serialNumber: nil,
            purchaseLocation: original.purchaseLocation,
            currentValueCents: original.currentValueCents,
            desireToKeep: original.desireToKeep,
            condition: original.condition,
            conditionNotes: original.conditionNotes,
            notes: original.notes,
            photos: (original.photos ?? []).map {
                Photo(imageData: $0.imageData, source: $0.source, sortOrder: $0.sortOrder)
            }
        )
        modelContext.insert(copy)

        // Placement runs against the whole collection in manual order, not
        // this screen's filtered slice — see ManualOrderHelper.insert.
        let ordered = (try? modelContext.fetch(
            FetchDescriptor<Item>(sortBy: [SortDescriptor(\.sortOrder)])
        )) ?? []
        ManualOrderHelper.insert(copy, after: original, in: ordered)

        do {
            try modelContext.save()
        } catch {
            loadFailureMessage = error.localizedDescription
        }
        load()
    }

    // MARK: - Export (011)

    /// The staged file the view offers through the share sheet, or nil.
    /// Settable by the view deliberately: `.sheet(item:)` writes nil back on
    /// dismissal — view mechanics, not business logic.
    var stagedExport: StagedExport?

    /// Set when generation fails (spec criterion 2a); the view presents it
    /// as a plain alert and writes nil back on dismissal.
    var exportFailureMessage: String?

    /// True while a file is generating — the export badge swaps to a spinner
    /// and disables (criterion 11's progress affordance).
    private(set) var isExporting = false

    /// Whether the current view has anything to export (criterion 2): an
    /// empty file is never produced.
    var canExport: Bool { !items.isEmpty }

    /// Combined purchase price of the items on screen — the cover's "total
    /// paid", tracking the filter like `totalCurrentValueCents` does.
    var totalPaidCents: Int {
        items.reduce(0) { $0 + $1.purchasePriceCents }
    }

    /// What the export covers, in the chips' own words — "All items",
    /// "Category: Guitars", with the un-valued filter and any search query
    /// named too, so the document never claims more than the screen showed.
    var exportCoverageLabel: String {
        var parts: [String] = []
        if !categoryFilter.isEmpty {
            parts.append("Category: \(categoryLabels[categoryFilter] ?? categoryFilter)")
        }
        if showsOnlyUnvalued { parts.append("Not yet valued") }
        let query = SearchMatching.normalized(searchText)
        if !query.isEmpty { parts.append("Search: \u{201C}\(query)\u{201D}") }
        return parts.isEmpty ? Self.wholeCoverageLabel : parts.joined(separator: " · ")
    }

    /// The document title and the unfiltered coverage label, named once so
    /// export-everything (`SettingsViewModel`, 013) and this list's own
    /// export can't drift — criterion 5's byte-identity rests on it.
    static let documentTitle = "Owned Items"
    static let wholeCoverageLabel = "All items"

    /// Exports the visible items, in visible order, as the canonical CSV.
    /// Records are built from `items` as-is — never a refetch: visible order
    /// comes from `isOrderedBefore` over live filter/sort state and is not
    /// reproducible from any `FetchDescriptor` (criteria 3–4).
    /// `!isBusy` since 012: one operation at a time across export *and*
    /// import, so their presentations can't race.
    func exportCSV() async {
        guard canExport, !isBusy else { return }
        isExporting = true
        defer { isExporting = false }

        let table = ExportSchema.itemsTable(items.map { ItemExportRecord(item: $0) })
        let filename = ExportFilename.items(fileExtension: "csv")
        do {
            let url = try await exportService.exportCSV(table, filename: filename)
            stagedExport = StagedExport(url: url, filename: filename)
        } catch {
            exportFailureMessage = ExportCopy.failureMessage
        }
    }

    /// Exports the visible items as the PDF collection document. Same
    /// snapshot rule as `exportCSV`; the cover's figures are this view
    /// model's own arithmetic, which is what criterion 8 measures.
    func exportPDF() async {
        guard canExport, !isBusy else { return }
        isExporting = true
        defer { isExporting = false }

        let records = items.map { ItemExportRecord(item: $0) }
        let document = PDFDocumentModel(
            cover: CoverSummary(
                title: Self.documentTitle,
                coverageLabel: exportCoverageLabel,
                generatedAt: .now,
                itemCount: items.count,
                totals: .items(
                    currentValueCents: totalCurrentValueCents,
                    paidCents: totalPaidCents,
                    unvaluedCount: unvaluedCount
                )
            ),
            entries: records.map { PDFEntry(record: $0) }
        )
        let filename = ExportFilename.items(fileExtension: "pdf")
        do {
            let url = try await exportService.exportPDF(document, filename: filename)
            stagedExport = StagedExport(url: url, filename: filename)
        } catch {
            exportFailureMessage = ExportCopy.failureMessage
        }
    }

    // MARK: - Import (012)

    /// What the import flow is showing, or nil — one optional drives the one
    /// import alert (plan §View-model surface: this view already carries
    /// three presentations, and independent booleans that can go true
    /// together are how SwiftUI silently drops one). View-settable so
    /// dismissal writes nil back, the `stagedExport` convention.
    var importPresentation: ImportPresentation<ItemExportRecord>?

    /// True while a picked file parses or a confirmed batch commits. Not
    /// `isImporting`, deliberately: "import" already means *CloudKit sync*
    /// in this file (`mayStillBeImporting`, `completedImports`), and an
    /// empty collection mid-sync is exactly where both meanings are live
    /// at once.
    private(set) var isImportingFile = false

    /// The one busy flag the overflow badge reads. Every export and import
    /// intent guards on it, which serializes the operations.
    var isBusy: Bool { isExporting || isImportingFile }

    /// The import alert's title — composed here, not in the view, so the
    /// copy path stays testable without UI (the `ImportCopy` pattern).
    var importAlertTitle: String {
        switch importPresentation {
        case .confirmation(let preview):
            ImportCopy.confirmationTitle(importCount: preview.validated.count, target: .items)
        case .failure(let title, _):
            title
        case nil:
            ""
        }
    }

    var importAlertMessage: String {
        switch importPresentation {
        case .confirmation(let preview):
            ImportCopy.confirmationMessage(preview: preview)
        case .failure(_, let message):
            message
        case nil:
            ""
        }
    }

    /// Whether the alert offers an Import action: a confirmation with
    /// something to import. Zero importable rows is informational only
    /// (criterion 5).
    var importOffersConfirmation: Bool {
        guard case .confirmation(let preview) = importPresentation else { return false }
        return !preview.validated.isEmpty
    }

    /// Parses the picked file into a staged preview — nothing is written
    /// until `confirmImport()` (criterion 5's parse-first gate).
    func importCSV(from url: URL) async {
        guard !isBusy else { return }
        isImportingFile = true
        defer { isImportingFile = false }

        do {
            let preview = try await importService.parseItems(at: url, timeZone: .current)
            importPresentation = .confirmation(preview)
        } catch let error as ImportError {
            importPresentation = .failure(
                title: ImportCopy.failureTitle,
                message: ImportCopy.failureMessage(for: error, target: .items)
            )
        } catch {
            importPresentation = .failure(
                title: ImportCopy.failureTitle,
                message: ImportCopy.unexpectedFailureMessage
            )
        }
    }

    /// Cancel at the confirmation: nothing was written, so there is nothing
    /// to undo — the store-untouched half of criterion 5.
    func cancelImport() {
        importPresentation = nil
    }

    // 012's `exportBlankTemplate()` lived here until 013 moved the template
    // into Settings (`SettingsViewModel.exportItemsTemplate`); its tests
    // moved with it.

    /// Commits the staged preview: real items built from the validated
    /// records, appended to the end of custom order. On the main actor, on
    /// this context, deliberately (plan §The commit path): parsing was the
    /// expensive part and ran off-main; a bulk insert `load()` can see for
    /// free beats background-context refetch plumbing.
    /// **Synchronous capture, async commit** — reshaped by a T017 device
    /// finding: an alert button's dismissal writes nil through the
    /// presentation binding, and the original `Task`-wrapped async intent
    /// read `importPresentation` only after that write — the guard failed
    /// and Import silently did nothing. The unit tests couldn't see it
    /// (they call with the presentation still staged); only the manual
    /// pass could. The preview is now captured in the button action's
    /// synchronous window, so dismissal ordering can't matter; the
    /// returned task is the commit itself, for tests to await.
    @discardableResult
    func confirmImport() -> Task<Void, Never>? {
        guard !isBusy, case .confirmation(let preview) = importPresentation else { return nil }
        importPresentation = nil
        guard !preview.validated.isEmpty else { return nil }
        isImportingFile = true
        return Task {
            defer { isImportingFile = false }
            // A real suspension before the work, so the badge's spinner renders
            // a frame — setting the flag alone never draws (criterion 15; the
            // T056 lesson in reverse).
            await Task.yield()

            // Placement is computed HERE, never at parse time: a CloudKit
            // arrival — or a hand-add — between the alert and the confirm must
            // not stale the base.
            let existing = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
            let base = ManualOrderHelper.nextPosition(after: existing)

            // The canonical path set is fetched once; the per-row instance
            // method is a full two-entity fetch per call (T009's reason for
            // the static). Batch-internal casing resolves by file row order,
            // first occurrence wins, each resolved path joining the set.
            // Load-bearing beyond tidiness: chip casing follows the earliest
            // `createdAt` across both entities, so an import restoring old
            // dates could otherwise steal an existing path's casing.
            var knownPaths = (try? CategoryPathHelper(modelContext: modelContext).allCategoryPaths()) ?? []

            for (offset, validated) in preview.validated.enumerated() {
                let record = validated.record
                let path = CategoryPathHelper.canonicalize(record.categoryPath, against: knownPaths)
                if !path.isEmpty,
                   !knownPaths.contains(where: { $0.caseInsensitiveCompare(path) == .orderedSame }) {
                    knownPaths.append(path)
                }
                modelContext.insert(Item(
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
                    sortOrder: base + offset
                ))
            }

            do {
                try modelContext.save()
            } catch {
                // Without the rollback, `load()` on this same context would
                // show the phantom batch — unsaved objects the context happily
                // returns — which would vanish on relaunch (criterion 14's
                // "never a partial batch").
                modelContext.rollback()
                importPresentation = .failure(
                    title: ImportCopy.failureTitle,
                    message: ImportCopy.saveFailureMessage
                )
            }
            load()
        }
    }

    private func isOrderedBefore(_ lhs: Item, _ rhs: Item) -> Bool {
        // Attribute first, the user's own order on any tie — spec.md's
        // confirmed rule for every non-"Custom" sort (plan.md's Resolved
        // decision 5 left this open; the first implementation fell back to
        // name, T039's review caught the divergence, and the 2026-08-30
        // close-out decided it: manual order, both lists). The order itself
        // — position, then the creation-then-id tie-break a pre-`010` store
        // needs — lives in `ManualOrderHelper` since 013, so "Custom" here
        // and Settings' export-everything sort with one function rather
        // than two that agree.
        attributeOrder(lhs, rhs) ?? ManualOrderHelper.areInCustomOrder(lhs, rhs)
    }

    /// The active sort's own comparison, `nil` on a tie — the shape
    /// `ManualOrderHelper.areInOrder` wants, mirroring the wishlist's
    /// `attributeOrder` so manual order steps in exactly where the attribute
    /// can't decide.
    private func attributeOrder(_ lhs: Item, _ rhs: Item) -> Bool? {
        switch sortOrder {
        case .custom:
            return nil
        case .purchaseDate:
            guard lhs.purchaseDate != rhs.purchaseDate else { return nil }
            return lhs.purchaseDate > rhs.purchaseDate
        case .currentValue, .currentValueAscending:
            guard lhs.currentValueCents != rhs.currentValueCents else { return nil }
            // Un-valued items sort last in *either* direction — they're not
            // worth zero, they're unknown, same as on the dashboard;
            // ascending must not promote them above the cheapest valued
            // item.
            guard let left = lhs.currentValueCents else { return false }
            guard let right = rhs.currentValueCents else { return true }
            return sortOrder == .currentValue ? left > right : left < right
        case .marketFigure, .marketFigureAscending:
            // The same nil-last block, over the device's own figure: an item
            // with no current median — unmatched, never refreshed here,
            // withheld, or stale past thirty days (Decision 21) — is unknown
            // rather than cheap, so it sorts last in either direction.
            let leftMedian = marketSummaries[lhs.id]?.medianCents
            let rightMedian = marketSummaries[rhs.id]?.medianCents
            guard leftMedian != rightMedian else { return nil }
            guard let left = leftMedian else { return false }
            guard let right = rightMedian else { return true }
            return sortOrder == .marketFigure ? left > right : left < right
        case .desireToKeep:
            guard lhs.desireToKeep != rhs.desireToKeep else { return nil }
            return lhs.desireToKeep > rhs.desireToKeep
        }
    }
}

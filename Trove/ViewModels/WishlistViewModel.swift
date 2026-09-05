import Foundation
import Observation
import SwiftData

/// Browse, filter, search and reorder the wishlist.
///
/// Same shape as `ItemListViewModel` — plain properties for the controls,
/// nothing recomputes until `load()` — and the same shared rules for category
/// matching and search, so the two list screens can't disagree about what a
/// filter or a query means.
@Observable
final class WishlistViewModel {
    /// "Custom" is the default because `WishlistItem.sortOrder` exists
    /// precisely so the user can rank what they want most, which no derived
    /// order can express. It shipped in `001` as "Yours" and was renamed by
    /// `010` after real use found that name unclear even to the person who
    /// chose it — spec.md's Resolved decisions record the reversal.
    ///
    /// "Desire" and "Alphabetical" arrived with `010` too, and "Desire"
    /// reverses another `001` decision — the rating used to order nothing,
    /// by design. spec.md's Resolved decisions record why that concern no
    /// longer applies (every sort is an explicit picker choice now); T030's
    /// commit records the removal of the test that pinned it.
    /// Cost carries both directions as a labeled pair — the same reversal of
    /// the one-direction-each rule as `ItemListViewModel`'s Value pair, made
    /// on the same request (T033a). Cheapest-first stays the lead option,
    /// per plan.md's direction call.
    enum SortOrder: String, CaseIterable, Identifiable {
        case custom
        case cost
        case costDescending
        case marketFigure
        case marketFigureAscending
        case desire
        case alphabetical

        var id: String { rawValue }

        var label: String {
            switch self {
            case .custom: "Custom"
            case .cost: "Cost ↑"
            case .costDescending: "Cost ↓"
            // The Market pair sits straight after the Cost pair, same order
            // on both lists (002 Q11), labelled from `MarketCopy`.
            case .marketFigure: MarketCopy.sortDescending
            case .marketFigureAscending: MarketCopy.sortAscending
            case .desire: "Desire"
            case .alphabetical: "Alphabetical"
            }
        }
    }

    var categoryFilter: String = ""
    var searchText: String = ""
    var sortOrder: SortOrder = .custom

    private(set) var items: [WishlistItem] = []

    /// See `ItemListViewModel.marketSummaries` — one rule, both lists.
    private(set) var marketSummaries: [UUID: MarketSummary] = [:]

    private(set) var categoryOptions: [String] = []
    private(set) var categoryLabels: [String: String] = [:]
    private(set) var loadFailureMessage: String?

    private let modelContext: ModelContext

    private let syncMonitor: SyncMonitor

    private let exportService: any ExportService

    private let importService: any ImportService

    private let now: () -> Date

    /// - Parameter exportService: defaults to the live file-staging service,
    ///   injected as a protocol so tests fake it — see
    ///   `ItemListViewModel.init`, one pattern on both lists; 012's
    ///   `importService` follows the same rule.
    /// - Parameter now: the clock the market figures' freshness is measured
    ///   against — see `ItemListViewModel.init`.
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

    /// See `ItemListViewModel.mayStillBeImporting`.
    var mayStillBeImporting: Bool { syncMonitor.mayStillBeImporting }

    /// Bumped each time an import lands, so the screen can refetch — see
    /// `SyncMonitor.completedImports`.
    var completedImports: Int { syncMonitor.completedImports }

    /// Wanted items before any narrowing — see `ItemListViewModel.totalCount`.
    private(set) var totalCount = 0

    var isEmpty: Bool { items.isEmpty }

    /// Which empty state applies, or `nil` when there's something to show.
    ///
    /// Never `.everythingIsValued`: the wishlist has no un-valued filter, since
    /// nothing on it is owned yet. The shared rule is still what decides, so
    /// the two lists can't drift apart on the cases they do share.
    var emptyReason: ListEmptyReason? {
        ListEmptyReason.reason(
            totalCount: totalCount,
            visibleCount: items.count,
            searchText: searchText,
            categoryFilter: categoryFilter,
            mayStillBeImporting: syncMonitor.mayStillBeImporting
        )
    }

    /// Design's "4 WANTED · $4,740" — everything currently on screen, so the
    /// figure tracks the filter the same way the item list's total does.
    var totalEstimatedCostCents: Int {
        items.reduce(0) { $0 + $1.estimatedCostCents }
    }

    /// Dragging only makes sense against the real, whole list in its own
    /// order. Reordering a filtered subset would have to invent positions for
    /// the rows that aren't showing, and sorting by cost already fixes the
    /// order — a drag there would be undone by the next `load()`.
    var canReorder: Bool {
        sortOrder == .custom
            && categoryFilter.isEmpty
            && SearchMatching.normalized(searchText).isEmpty
    }

    func load() {
        loadFailureMessage = nil
        do {
            let all = try modelContext.fetch(FetchDescriptor<WishlistItem>())
            totalCount = all.count
            // Before the sort, not after: the Market orders read these.
            marketSummaries = Self.summaries(for: all, in: modelContext, now: now())
            items = all
                .filter { CategoryPathHelper.path($0.categoryPath, isWithin: categoryFilter) }
                // Name only. A wishlist item has no serial number — it isn't
                // owned yet — so there's nothing else to match on.
                .filter { SearchMatching.matches(query: searchText, in: [$0.name]) }
                .sorted(by: isOrderedBefore)

            // Wishlist categories only. Offering every path the owned-items
            // list uses would fill most of this row with chips that lead
            // nowhere, since a wishlist is short and a collection isn't.
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

    /// One fetch of the figure rows, narrowed to the wanted items just
    /// fetched.
    ///
    /// The derivation itself lives on `MarketSummary` (002/T013), the same
    /// as `ItemListViewModel.summaries(for:in:now:)`, so no surface that
    /// reads a figure per row carries its own copy of the step — including
    /// its rule that a read which throws reads as "nothing stored".
    private static func summaries(for items: [WishlistItem], in context: ModelContext, now: Date) -> [UUID: MarketSummary] {
        MarketSummary.summaries(forSubjects: items.map(\.id), in: context, now: now)
    }

    /// See `ItemListViewModel.trend(for:)`.
    func trend(for id: UUID) -> MarketTrend? {
        marketSummaries[id]?.trend
    }

    /// Applies a drag through `ManualOrderHelper`, which renumbers every row
    /// densely so the stored order matches what the user just saw — see the
    /// helper for the invariant's rationale, and
    /// `positionsStayDenseAndUniqueAcrossManyMoves` for its guard.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard canReorder else { return }

        items = ManualOrderHelper.reorder(items, fromOffsets: source, toOffset: destination)

        do {
            try modelContext.save()
        } catch {
            loadFailureMessage = error.localizedDescription
        }
    }

    /// See `ItemListViewModel.canMoveUp(id:)` — the same boundary guard,
    /// mirrored per entity the way `duplicate(id:)` is.
    func canMoveUp(id: UUID) -> Bool {
        guard canReorder, let index = items.firstIndex(where: { $0.id == id }) else { return false }
        return index > 0
    }

    /// See `canMoveUp(id:)`. False at the bottom of the list.
    func canMoveDown(id: UUID) -> Bool {
        guard canReorder, let index = items.firstIndex(where: { $0.id == id }) else { return false }
        return index < items.count - 1
    }

    /// See `ItemListViewModel.moveUp(id:)` — one step toward the top, through
    /// the same `move(fromOffsets:toOffset:)` as the drag.
    func moveUp(id: UUID) {
        guard canMoveUp(id: id), let index = items.firstIndex(where: { $0.id == id }) else { return }
        move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
    }

    /// See `ItemListViewModel.moveDown(id:)` for the `+ 2`.
    func moveDown(id: UUID) {
        guard canMoveDown(id: id), let index = items.firstIndex(where: { $0.id == id }) else { return }
        move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
    }

    /// Deletes a wanted item by id. The list's swipe used to call
    /// `modelContext.delete` straight from the view — business logic in a
    /// view, and the one deletion in the app with no tests behind it. Routed
    /// through here so both routes to the same deletion share one tested path.
    ///
    /// Photos cascade with it; sell-plan items are unlinked, not deleted —
    /// the same asymmetry `WishlistDeleteCopy.message` states to the user.
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

    /// Creates a copy per spec.md's wishlist duplicate flow — the same shape
    /// as `ItemListViewModel.duplicate(id:)` adjusted for the entity: no
    /// serial number exists to clear, photos become genuinely new `Photo`
    /// rows (same one-photo-one-parent reasoning), and the copy's own Sell
    /// Plan selection starts empty rather than inheriting
    /// `plannedSaleItems`. Lands immediately after the original in manual
    /// order.
    func duplicate(id: UUID) {
        guard let original = items.first(where: { $0.id == id }) else { return }

        let copy = WishlistItem(
            name: original.name,
            categoryPath: original.categoryPath,
            estimatedCostCents: original.estimatedCostCents,
            currencyCode: original.currencyCode,
            notes: original.notes,
            desireToOwn: original.desireToOwn,
            photos: (original.photos ?? []).map {
                Photo(imageData: $0.imageData, source: $0.source, sortOrder: $0.sortOrder)
            },
            plannedSaleItems: []
        )
        modelContext.insert(copy)

        // Whole collection in manual order, never the filtered slice.
        let ordered = (try? modelContext.fetch(
            FetchDescriptor<WishlistItem>(sortBy: [SortDescriptor(\.sortOrder)])
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

    /// See `ItemListViewModel`'s export section — one pattern, both lists.
    /// Settable by the view: `.sheet(item:)` writes nil back on dismissal.
    var stagedExport: StagedExport?

    /// Set when generation fails (spec criterion 2a); presented as a plain
    /// alert, cleared by the view on dismissal.
    var exportFailureMessage: String?

    /// True while a file is generating (criterion 11's progress affordance).
    private(set) var isExporting = false

    /// Whether the current view has anything to export (criterion 2).
    var canExport: Bool { !items.isEmpty }

    /// What the export covers — the category chip's own label and any search
    /// query; the wishlist has no un-valued filter to name.
    var exportCoverageLabel: String {
        var parts: [String] = []
        if !categoryFilter.isEmpty {
            parts.append("Category: \(categoryLabels[categoryFilter] ?? categoryFilter)")
        }
        let query = SearchMatching.normalized(searchText)
        if !query.isEmpty { parts.append("Search: \u{201C}\(query)\u{201D}") }
        return parts.isEmpty ? Self.wholeCoverageLabel : parts.joined(separator: " · ")
    }

    /// See `ItemListViewModel.documentTitle` — one definition for this list
    /// and for export-everything.
    static let documentTitle = "Wishlist"
    static let wholeCoverageLabel = "Whole wishlist"

    /// Exports the visible wanted items, in visible order, as the canonical
    /// CSV. Records come from `items` as-is — never a refetch — for the same
    /// criteria-3/4 reason as the item list.
    func exportCSV() async {
        // `!isBusy` since 012 — see `ItemListViewModel.exportCSV`.
        guard canExport, !isBusy else { return }
        isExporting = true
        defer { isExporting = false }

        let table = ExportSchema.wishlistTable(items.map { WishlistExportRecord(item: $0) })
        let filename = ExportFilename.wishlist(fileExtension: "csv")
        do {
            let url = try await exportService.exportCSV(table, filename: filename)
            stagedExport = StagedExport(url: url, filename: filename)
        } catch {
            exportFailureMessage = ExportCopy.failureMessage
        }
    }

    /// Exports the visible wanted items as the PDF collection document; the
    /// cover totals this view model's own `totalEstimatedCostCents`
    /// (criterion 8).
    func exportPDF() async {
        guard canExport, !isBusy else { return }
        isExporting = true
        defer { isExporting = false }

        let records = items.map { WishlistExportRecord(item: $0) }
        let document = PDFDocumentModel(
            cover: CoverSummary(
                title: Self.documentTitle,
                coverageLabel: exportCoverageLabel,
                generatedAt: .now,
                itemCount: items.count,
                totals: .wishlist(estimatedCostCents: totalEstimatedCostCents)
            ),
            entries: records.map { PDFEntry(record: $0) }
        )
        let filename = ExportFilename.wishlist(fileExtension: "pdf")
        do {
            let url = try await exportService.exportPDF(document, filename: filename)
            stagedExport = StagedExport(url: url, filename: filename)
        } catch {
            exportFailureMessage = ExportCopy.failureMessage
        }
    }

    // MARK: - Import (012)

    /// See `ItemListViewModel`'s import section — one pattern, both lists.
    var importPresentation: ImportPresentation<WishlistExportRecord>?

    /// Named against the CloudKit-sync collision, same as the item list's.
    private(set) var isImportingFile = false

    var isBusy: Bool { isExporting || isImportingFile }

    var importAlertTitle: String {
        switch importPresentation {
        case .confirmation(let preview):
            ImportCopy.confirmationTitle(importCount: preview.validated.count, target: .wishlist)
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

    var importOffersConfirmation: Bool {
        guard case .confirmation(let preview) = importPresentation else { return false }
        return !preview.validated.isEmpty
    }

    func importCSV(from url: URL) async {
        guard !isBusy else { return }
        isImportingFile = true
        defer { isImportingFile = false }

        do {
            let preview = try await importService.parseWishlist(at: url, timeZone: .current)
            importPresentation = .confirmation(preview)
        } catch let error as ImportError {
            importPresentation = .failure(
                title: ImportCopy.failureTitle,
                message: ImportCopy.failureMessage(for: error, target: .wishlist)
            )
        } catch {
            importPresentation = .failure(
                title: ImportCopy.failureTitle,
                message: ImportCopy.unexpectedFailureMessage
            )
        }
    }

    func cancelImport() {
        importPresentation = nil
    }

    // The wishlist template intent moved to `SettingsViewModel` with 013,
    // alongside the items one.

    /// See `ItemListViewModel.confirmImport` — one commit path, both lists,
    /// with the wishlist's one extra move: `Added` restores `createdAt`.
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
            await Task.yield()

            let existing = (try? modelContext.fetch(FetchDescriptor<WishlistItem>())) ?? []
            let base = ManualOrderHelper.nextPosition(after: existing)
            var knownPaths = (try? CategoryPathHelper(modelContext: modelContext).allCategoryPaths()) ?? []

            for (offset, validated) in preview.validated.enumerated() {
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
                    year: record.year
                )
                // Assigned after construction deliberately: the init hard-sets
                // `.now` and has no parameter — `Added` restores when the want
                // was actually recorded (plan §The commit path; don't "fix"
                // the init).
                wish.createdAt = record.createdAt
                modelContext.insert(wish)
            }

            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                importPresentation = .failure(
                    title: ImportCopy.failureTitle,
                    message: ImportCopy.saveFailureMessage
                )
            }
            load()
        }
    }

    private func isOrderedBefore(_ lhs: WishlistItem, _ rhs: WishlistItem) -> Bool {
        // Attribute first, the user's own order on any tie — spec.md's
        // confirmed rule for every non-"Custom" sort; for "Custom" the
        // attribute abstains entirely, so the manual order *is* the sort.
        // The order itself — position, then name and id where positions
        // collide — lives in `ManualOrderHelper` since 013, shared with the
        // item list and with export-everything.
        attributeOrder(lhs, rhs) ?? ManualOrderHelper.areInCustomOrder(lhs, rhs)
    }

    /// The active sort's own comparison, `nil` on a tie — the shape
    /// `ManualOrderHelper.areInOrder` wants, so manual order steps in
    /// exactly where the attribute can't decide.
    ///
    /// Directions are plan.md's recorded calls ("Sort direction" section):
    /// Cost ascending — cheapest first reads as "what could I realistically
    /// buy soon," and `010` deliberately flips `001`'s dearest-first here —
    /// Desire descending (most wanted first), Alphabetical A→Z,
    /// case-insensitively like every other name comparison in the app.
    private func attributeOrder(_ lhs: WishlistItem, _ rhs: WishlistItem) -> Bool? {
        switch sortOrder {
        case .custom:
            return nil
        case .cost, .costDescending:
            guard lhs.estimatedCostCents != rhs.estimatedCostCents else { return nil }
            return sortOrder == .cost
                ? lhs.estimatedCostCents < rhs.estimatedCostCents
                : lhs.estimatedCostCents > rhs.estimatedCostCents
        case .marketFigure, .marketFigureAscending:
            // The nil-last block, mirrored from `ItemListViewModel`: a wanted
            // item with no current median — unmatched, never refreshed here,
            // withheld, or stale (Decision 21) — sorts last either way.
            let leftMedian = marketSummaries[lhs.id]?.medianCents
            let rightMedian = marketSummaries[rhs.id]?.medianCents
            guard leftMedian != rightMedian else { return nil }
            guard let left = leftMedian else { return false }
            guard let right = rightMedian else { return true }
            return sortOrder == .marketFigure ? left > right : left < right
        case .desire:
            guard lhs.desireToOwn != rhs.desireToOwn else { return nil }
            return lhs.desireToOwn > rhs.desireToOwn
        case .alphabetical:
            let byName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            guard byName != .orderedSame else { return nil }
            return byName == .orderedAscending
        }
    }
}

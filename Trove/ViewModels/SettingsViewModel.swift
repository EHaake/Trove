import Foundation
import Observation
import SwiftData

/// The Settings sheet's state and intents (013): export-everything, the
/// blank templates, the iCloud row, Delete All for each list and — from
/// 009 Amendment A — for every sell plan, and About.
///
/// Owns everything the screen shows — including the iCloud row's copy and
/// the alerts' words — so nothing on the view is more than layout, and the
/// copy paths stay testable without UI (012's `importAlertTitle`
/// precedent). `SyncMonitor`, the storage mode, and the fallback reason are
/// constructor-injected by the presenting list view, exactly as
/// `ContentView` threads them into every other screen: one delivery
/// mechanism, not a second one that reads the environment from inside a
/// sheet.
@Observable
final class SettingsViewModel {
    /// Which action is in flight, if any — one optional rather than eight
    /// booleans, so the acting row can show the spinner and everything
    /// else can disable off `isBusy` (spec §Busy and failure states).
    enum Activity: Equatable {
        case exportCSV
        case exportPDF
        case itemsTemplate
        case wishlistTemplate
        case deleteItems
        case deleteWishlist
        /// 009 Amendment A (Decision 18): every sell plan, active and completed.
        case deleteSellPlans
        /// 002: the walk over every matched item (spec criterion 10).
        case refreshMarket
    }

    /// The one alert the screen presents, in its three shapes. One optional
    /// for the same reason 012 gave: independent booleans that can go true
    /// together are how SwiftUI silently drops an alert.
    enum SettingsAlert: Equatable {
        case confirmDelete(DeleteTarget, count: Int)
        case deleteFailed
        case exportFailed
    }

    private let modelContext: ModelContext
    private let syncMonitor: SyncMonitor
    private let storageMode: StorageMode
    private let storageFallbackReason: String?
    private let exportService: any ExportService
    private let marketService: any MarketService
    private let now: () -> Date
    private let appVersion: AppVersion

    /// Whole-store counts — `fetchCount`, never a loaded array: the rows
    /// only need to know whether there's anything to act on, and how many.
    private(set) var itemCount = 0
    private(set) var wishlistCount = 0

    /// 009 Amendment A (plan QA4, RA2(b)): stored plans, active and completed,
    /// plus rows still awaiting the carry-over — the alert's number. The one
    /// count here taken from **loaded rows** rather than `fetchCount`:
    /// `awaitsCarryOver` reads relationships, which no `#Predicate` can, so
    /// the count is `plannedRows()`'s filtered fetch — the very rows the
    /// delete then clears.
    private(set) var planCount = 0

    /// 009 T021a: set with each Delete All request — whether a list of one
    /// item is the item a completed plan was bought as, so the alert can say
    /// the plan loses its picture. False for every other request.
    private var onlyItemPicturesACompletedPlan = false

    /// 002: how many items — owned and wanted together — carry a Reverb
    /// match, counted through `MarketRefresher.targets(in:)` so Settings
    /// and the walk share the one definition of "matched".
    private(set) var matchedCount = 0

    /// The walk's position while it runs: `nil` when nothing is walking.
    /// Written after each item, and every `await` in the walk is a real
    /// suspension, so the row re-renders as it advances (the T056 lesson).
    private(set) var marketRefreshProgress: (done: Int, total: Int)?

    /// The one line under the row when a walk stops early (spec criterion
    /// 10, Decision 27) — the rate limit's words, or "Couldn't reach
    /// Reverb. 3 of 12 refreshed.". A completed walk says nothing.
    private(set) var marketRefreshStatus: String?

    /// The one quiet line under the row when a walk found nothing due
    /// (spec Decision 38): every matched item was refreshed within the
    /// hour, so the row did nothing — and says so, in the quiet colour, not
    /// the failure one. Cleared when the next walk starts.
    private(set) var marketRefreshNote: String?

    private(set) var activity: Activity?

    /// The staged file set the view offers through the share sheet.
    /// Settable by the view: `.sheet(item:)` writes nil back on dismissal.
    var stagedExport: StagedExport?

    /// Settable by the view for the same reason — the alert's binding
    /// writes nil back on any button tap.
    var alert: SettingsAlert?

    init(
        modelContext: ModelContext,
        syncMonitor: SyncMonitor = .notSyncing,
        storageMode: StorageMode = .cloudKit,
        storageFallbackReason: String? = nil,
        exportService: (any ExportService)? = nil,
        marketService: (any MarketService)? = nil,
        now: @escaping () -> Date = Date.init,
        appVersion: AppVersion = .current
    ) {
        self.modelContext = modelContext
        self.syncMonitor = syncMonitor
        self.storageMode = storageMode
        self.storageFallbackReason = storageFallbackReason
        self.exportService = exportService ?? FileExportService(container: modelContext.container)
        self.marketService = marketService ?? ReverbMarketService()
        self.now = now
        self.appVersion = appVersion
    }

    // MARK: - Loading

    /// Refreshes both counts. Called on appear and after every action, so
    /// a row whose list just emptied disables itself.
    func load() {
        itemCount = (try? modelContext.fetchCount(FetchDescriptor<Item>())) ?? 0
        // 015/R1: a bought entry is not on the wishlist, so it is not in this
        // number — which is the delete alert's count, `canDeleteWishlist` and
        // half of `canExportEverything`.
        wishlistCount = (try? modelContext.fetchCount(
            FetchDescriptor<WishlistItem>(predicate: #Predicate<WishlistItem> { $0.boughtDate == nil })
        )) ?? 0
        matchedCount = ((try? MarketRefresher.targets(in: modelContext)) ?? []).count
        planCount = ((try? plannedRows()) ?? []).count
    }

    /// Every row "Delete all sell plans" clears (plan RA2(b)): a stored plan,
    /// or a row the carry-over would make one — so after the delete no plan
    /// comes back on its own. The fetch narrows to rows that could be either;
    /// the filter decides, in memory, since `awaitsCarryOver` reads
    /// relationships. One definition for the count and the delete, so the
    /// gesture clears exactly what the alert's number promised.
    private func plannedRows() throws -> [WishlistItem] {
        try modelContext.fetch(FetchDescriptor<WishlistItem>(
            predicate: #Predicate<WishlistItem> { $0.sellPlanCreatedAt != nil || $0.sellPlanCheckedAt == nil }
        ))
        .filter { $0.hasSellPlan || $0.awaitsCarryOver }
    }

    // MARK: - Derived state

    var isBusy: Bool { activity != nil }

    /// Either collection having anything is enough: the gesture promises
    /// everything, and an empty list's file is an answer, not a gap
    /// (spec P2).
    var canExportEverything: Bool { itemCount + wishlistCount > 0 }

    var canDeleteItems: Bool { itemCount > 0 }
    var canDeleteWishlist: Bool { wishlistCount > 0 }
    var canDeleteSellPlans: Bool { planCount > 0 }

    /// Nothing matched, nothing to refresh — and never while another action
    /// runs (spec §Busy and failure states).
    var canRefreshMarketValues: Bool { matchedCount > 0 && !isBusy }

    /// Live: `SyncMonitor` is `@Observable`, so reading its phase here is
    /// what makes the row update while the sheet is open.
    var syncStatus: SyncStatus {
        SyncStatusCopy.status(
            mode: storageMode,
            phase: syncMonitor.phase,
            fallbackReason: storageFallbackReason
        )
    }

    var versionLine: String { appVersion.display }

    var alertTitle: String {
        switch alert {
        case .confirmDelete(let target, let count):
            DeleteAllCopy.title(count: count, target: target)
        case .deleteFailed:
            DeleteAllCopy.failureTitle
        case .exportFailed:
            ExportCopy.failureTitle
        case nil:
            ""
        }
    }

    /// Composed here rather than in the view so the storage-mode branch
    /// (spec Decision 13) is a view-model fact a unit test can pin.
    var alertMessage: String {
        switch alert {
        case .confirmDelete(let target, let count):
            DeleteAllCopy.message(
                for: target,
                count: count,
                mode: storageMode,
                picturesACompletedPlan: onlyItemPicturesACompletedPlan
            )
        case .deleteFailed:
            DeleteAllCopy.failureMessage
        case .exportFailed:
            ExportCopy.failureMessage
        case nil:
            ""
        }
    }

    // MARK: - Export everything

    /// Both collections, whole, in Custom order — the user-authored order
    /// and the one import appends to (spec P3) — through the very function
    /// the lists sort "Custom" with, so the files are what the lists would
    /// export unfiltered (criterion 5).
    ///
    /// 006 (plan Q5): the owned and the sold arrive apart, because they are
    /// ordered by different rules — owned in Custom order, sold in the Sold
    /// side's own order — and the two documents use them differently: the
    /// CSV writes owned then sold, the PDF owned only.
    private func everythingInCustomOrder() throws -> (owned: [Item], sold: [Item], wanted: [WishlistItem]) {
        let items = try modelContext.fetch(FetchDescriptor<Item>())
        let owned = items
            .filter { !$0.isSold }
            .sorted(by: ManualOrderHelper.areInCustomOrder)
        let sold = items
            .filter(\.isSold)
            .sorted(by: ItemListViewModel.areInSoldOrder)
        // 015 criterion 13: a bought entry exports in neither format. Its new
        // item is in the owned fetch above, as an ordinary item.
        let wanted = try modelContext.fetch(
            FetchDescriptor<WishlistItem>(predicate: #Predicate<WishlistItem> { $0.boughtDate == nil })
        )
            .sorted(by: ManualOrderHelper.areInCustomOrder)
        return (owned, sold, wanted)
    }

    func exportEverythingAsCSV() async {
        guard canExportEverything, !isBusy else { return }
        activity = .exportCSV
        defer { activity = nil }

        do {
            let (owned, sold, wanted) = try everythingInCustomOrder()
            // Owned first, in Custom order, then the sold in Sold-side order
            // — the same two comparators the list itself sorts with, so
            // 013's byte-identity survives a sale being present (Q5).
            try await stage([
                .csv(
                    ExportSchema.itemsTable((owned + sold).map { ItemExportRecord(item: $0) }),
                    filename: ExportFilename.items(fileExtension: "csv")
                ),
                .csv(
                    ExportSchema.wishlistTable(wanted.map { WishlistExportRecord(item: $0) }),
                    filename: ExportFilename.wishlist(fileExtension: "csv")
                ),
            ])
        } catch {
            alert = .exportFailed
        }
    }

    /// The covers use the lists' own titles, unfiltered labels, and the
    /// same total reductions, so each document is the one its list would
    /// produce with no filter (criterion 6).
    ///
    /// 006: the items document is the **owned** collection only, on this
    /// path as on the list's (Q5), so its cover figures are the Dashboard's
    /// collection figures rather than a mix of what is owned and what was
    /// sold.
    func exportEverythingAsPDF() async {
        guard canExportEverything, !isBusy else { return }
        activity = .exportPDF
        defer { activity = nil }

        do {
            let (items, _, wanted) = try everythingInCustomOrder()
            let itemsDocument = PDFDocumentModel(
                cover: CoverSummary(
                    title: ItemListViewModel.documentTitle,
                    coverageLabel: ItemListViewModel.wholeCoverageLabel,
                    generatedAt: .now,
                    itemCount: items.count,
                    totals: .items(
                        currentValueCents: items.compactMap(\.currentValueCents).reduce(0, +),
                        paidCents: items.reduce(0) { $0 + $1.purchasePriceCents },
                        unvaluedCount: items.count { $0.currentValueCents == nil }
                    )
                ),
                entries: items.map { PDFEntry(record: ItemExportRecord(item: $0)) }
            )
            let wishlistDocument = PDFDocumentModel(
                cover: CoverSummary(
                    title: WishlistViewModel.documentTitle,
                    coverageLabel: WishlistViewModel.wholeCoverageLabel,
                    generatedAt: .now,
                    itemCount: wanted.count,
                    totals: .wishlist(estimatedCostCents: wanted.reduce(0) { $0 + $1.estimatedCostCents })
                ),
                entries: wanted.map { PDFEntry(record: WishlistExportRecord(item: $0)) }
            )
            try await stage([
                .pdf(itemsDocument, filename: ExportFilename.items(fileExtension: "pdf")),
                .pdf(wishlistDocument, filename: ExportFilename.wishlist(fileExtension: "pdf")),
            ])
        } catch {
            alert = .exportFailed
        }
    }

    // MARK: - Templates

    /// The blank templates, moved here from the lists' "…" menu (spec
    /// Decision 2). Gated on `isBusy` only — never the counts: an empty
    /// collection is the template's whole audience. Same bytes and names
    /// as 012 shipped; only the row that hands them out moved.
    func exportItemsTemplate() async {
        await stageTemplate(
            .itemsTemplate,
            headers: ExportSchema.itemHeaders,
            filename: ExportFilename.itemsTemplate
        )
    }

    func exportWishlistTemplate() async {
        await stageTemplate(
            .wishlistTemplate,
            headers: ExportSchema.wishlistHeaders,
            filename: ExportFilename.wishlistTemplate
        )
    }

    private func stageTemplate(_ activity: Activity, headers: [String], filename: String) async {
        guard !isBusy else { return }
        self.activity = activity
        defer { self.activity = nil }

        do {
            try await stage([.csv(CSVTable(headers: headers, rows: []), filename: filename)])
        } catch {
            alert = .exportFailed
        }
    }

    /// One `exportFiles` call for the whole set — never one per file, which
    /// would purge each other on the live service — then the share sheet.
    private func stage(_ files: [ExportFile]) async throws {
        let urls = try await exportService.exportFiles(files)
        stagedExport = StagedExport(urls: urls, filenames: files.map(\.filename))
    }

    // MARK: - Refresh market values (002)

    /// Every matched item, one at a time, in the lists' own order (spec
    /// criterion 10): owned in Custom order, then wanted — the order
    /// `MarketRefresher.targets(in:)` defines, so this walk and the
    /// section's own Refresh agree on what "matched" means.
    ///
    /// Only the *due* ones are walked — an item refreshed within the hour
    /// is skipped rather than sent (spec criterion 9, P7), so "3 of 12"
    /// counts the ones this walk will actually ask about. The walk stops at
    /// the first failure and says which: Reverb's rate limit gets its own
    /// words, anything else the count it reached (Decision 27). Items
    /// already refreshed keep what they got.
    func refreshMarketValues() async {
        guard canRefreshMarketValues else { return }
        activity = .refreshMarket
        marketRefreshStatus = nil
        marketRefreshNote = nil
        defer {
            activity = nil
            marketRefreshProgress = nil
            load()
        }

        let due = (try? dueTargets()) ?? []
        let total = due.count
        // Nothing due is not a failure and not silence either (Decision 38).
        if total == 0 {
            marketRefreshNote = MarketCopy.nothingDue
            return
        }
        marketRefreshProgress = (done: 0, total: total)

        let refresher = MarketRefresher(modelContext: modelContext, service: marketService, now: now)
        var done = 0
        for target in due {
            switch await refresher.refresh(target) {
            case .failed(.rateLimited):
                marketRefreshStatus = MarketCopy.rateLimited
                return
            case .failed, .saveFailed:
                marketRefreshStatus = MarketCopy.refreshStoppedUnreachable(done: done, total: total)
                return
            case .refreshed, .superseded, .stillFresh:
                // `.stillFresh` can only arrive from a race with another
                // refresh; the item is current either way, so it counts.
                done += 1
                marketRefreshProgress = (done: done, total: total)
            }
        }
    }

    /// The matched items whose figure is older than the hour, or that have
    /// no figure on this device at all — read through the same stored
    /// `fetchedAt` and window the refresher itself budgets against.
    private func dueTargets() throws -> [MarketRefreshTarget] {
        let moment = now()
        return try MarketRefresher.targets(in: modelContext).filter { target in
            guard let stored = try? MarketLocalStore.figure(for: target.key.subjectID, in: modelContext) else {
                return true
            }
            return moment.timeIntervalSince(stored.fetchedAt) >= MarketRefresher.freshnessWindow
        }
    }

    // MARK: - Delete All

    /// Re-counts at request time, so the alert's title carries the count
    /// the store has *now*, not the one this screen loaded with — a
    /// CloudKit arrival between appear and tap would otherwise put a stale
    /// number on a destructive confirmation.
    func requestDeleteAll(_ target: DeleteTarget) {
        guard !isBusy else { return }
        load()
        let count = switch target {
        case .items: itemCount
        case .wishlist: wishlistCount
        case .sellPlans: planCount
        }
        guard count > 0 else { return }
        onlyItemPicturesACompletedPlan = target == .items && count == 1
            && ((try? modelContext.fetch(FetchDescriptor<Item>()))?.first?.boughtFromWishlistItem != nil)
        alert = .confirmDelete(target, count: count)
    }

    /// The commit path: **synchronous capture, async commit** — T017's
    /// shape. The alert's `isPresented` binding writes `alert` nil on any
    /// button tap, before a spawned task's body runs, so nothing in here
    /// may depend on `alert`; the target arrives as a parameter from the
    /// alert's `presenting` closure for the same reason.
    ///
    /// Per-object `delete` in this context and **one** `save`: the
    /// save/rollback envelope is what makes the deletion all-or-nothing
    /// (criterion 13), and `ModelContext.delete(model:)` commits outside
    /// it. Photos cascade and sell plans nullify by the schema's rules —
    /// nothing is unlinked by hand, exactly as the single deletes work.
    ///
    /// The third target, sell plans (009 Amendment A), deletes no model at
    /// all: each plan goes through `SellPlanStore.delete`, the one writer a
    /// single plan's delete uses, inside the same one-save envelope.
    @discardableResult
    func confirmDeleteAll(_ target: DeleteTarget) -> Task<Void, Never>? {
        guard !isBusy else { return nil }
        alert = nil
        activity = switch target {
        case .items: .deleteItems
        case .wishlist: .deleteWishlist
        case .sellPlans: .deleteSellPlans
        }

        return Task { @MainActor in
            defer {
                activity = nil
                load()
            }
            // Lets the presentation write land before the work — ordering
            // hygiene, not a promise of a rendered frame. plan.md's commit
            // path section carries the measured cost and the branch taken.
            await Task.yield()
            do {
                switch target {
                // 002 (spec Decision 30): each deleted item's device-local
                // market rows — figure, history, snapshot — go with it, and
                // nothing else does: the other list's rows and the one-time
                // notice's acknowledgement stay. Delete All removes these
                // items; it does not reset the device.
                case .items:
                    for item in try modelContext.fetch(FetchDescriptor<Item>()) {
                        try MarketLocalStore.clear(subjectID: item.id, in: modelContext)
                        modelContext.delete(item)
                    }
                // 015/R1: the same predicate `wishlistCount` uses, so the
                // gesture deletes exactly what the alert's number promised —
                // and a bought entry's completed sell plan (Decision 3)
                // survives a wishlist wipe it was never counted in.
                case .wishlist:
                    for wanted in try modelContext.fetch(
                        FetchDescriptor<WishlistItem>(predicate: #Predicate<WishlistItem> { $0.boughtDate == nil })
                    ) {
                        try MarketLocalStore.clear(subjectID: wanted.id, in: modelContext)
                        modelContext.delete(wanted)
                    }
                // 009 Amendment A (plan QA4, RA2(b)): every plan removed
                // exactly as a single delete removes it — plan and selection
                // gone, the entry, every item, the sold-toward record and the
                // purchase record untouched, the row stamped checked so no
                // carry-over brings it back. Nothing is deleted, so no market
                // rows are cleared.
                case .sellPlans:
                    let moment = now()
                    for wanted in try plannedRows() {
                        SellPlanStore.delete(planOf: wanted, at: moment)
                    }
                }
                try modelContext.save()
            } catch {
                // Without this, load() on the same context would show the
                // phantom deletion — the import commit's finding, reversed.
                modelContext.rollback()
                alert = .deleteFailed
            }
        }
    }

    func cancelDeleteAll() {
        alert = nil
    }
}

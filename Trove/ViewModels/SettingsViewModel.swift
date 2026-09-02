import Foundation
import Observation
import SwiftData

/// The Settings sheet's state and intents (013): export-everything, the
/// blank templates, the iCloud row, Delete All for each list, and About.
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
    /// Which action is in flight, if any — one optional rather than six
    /// booleans, so the acting row can show the spinner and everything
    /// else can disable off `isBusy` (spec §Busy and failure states).
    enum Activity: Equatable {
        case exportCSV
        case exportPDF
        case itemsTemplate
        case wishlistTemplate
        case deleteItems
        case deleteWishlist
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
    private let appVersion: AppVersion

    /// Whole-store counts — `fetchCount`, never a loaded array: the rows
    /// only need to know whether there's anything to act on, and how many.
    private(set) var itemCount = 0
    private(set) var wishlistCount = 0

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
        appVersion: AppVersion = .current
    ) {
        self.modelContext = modelContext
        self.syncMonitor = syncMonitor
        self.storageMode = storageMode
        self.storageFallbackReason = storageFallbackReason
        self.exportService = exportService ?? FileExportService(container: modelContext.container)
        self.appVersion = appVersion
    }

    // MARK: - Loading

    /// Refreshes both counts. Called on appear and after every action, so
    /// a row whose list just emptied disables itself.
    func load() {
        itemCount = (try? modelContext.fetchCount(FetchDescriptor<Item>())) ?? 0
        wishlistCount = (try? modelContext.fetchCount(FetchDescriptor<WishlistItem>())) ?? 0
    }

    // MARK: - Derived state

    var isBusy: Bool { activity != nil }

    /// Either collection having anything is enough: the gesture promises
    /// everything, and an empty list's file is an answer, not a gap
    /// (spec P2).
    var canExportEverything: Bool { itemCount + wishlistCount > 0 }

    var canDeleteItems: Bool { itemCount > 0 }
    var canDeleteWishlist: Bool { wishlistCount > 0 }

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
            DeleteAllCopy.message(for: target, count: count, mode: storageMode)
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
    private func everythingInCustomOrder() throws -> (items: [Item], wanted: [WishlistItem]) {
        let items = try modelContext.fetch(FetchDescriptor<Item>())
            .sorted(by: ManualOrderHelper.areInCustomOrder)
        let wanted = try modelContext.fetch(FetchDescriptor<WishlistItem>())
            .sorted(by: ManualOrderHelper.areInCustomOrder)
        return (items, wanted)
    }

    func exportEverythingAsCSV() async {
        guard canExportEverything, !isBusy else { return }
        activity = .exportCSV
        defer { activity = nil }

        do {
            let (items, wanted) = try everythingInCustomOrder()
            try await stage([
                .csv(
                    ExportSchema.itemsTable(items.map { ItemExportRecord(item: $0) }),
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
    func exportEverythingAsPDF() async {
        guard canExportEverything, !isBusy else { return }
        activity = .exportPDF
        defer { activity = nil }

        do {
            let (items, wanted) = try everythingInCustomOrder()
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

    // MARK: - Delete All

    /// Re-counts at request time, so the alert's title carries the count
    /// the store has *now*, not the one this screen loaded with — a
    /// CloudKit arrival between appear and tap would otherwise put a stale
    /// number on a destructive confirmation.
    func requestDeleteAll(_ target: DeleteTarget) {
        guard !isBusy else { return }
        load()
        let count = target == .items ? itemCount : wishlistCount
        guard count > 0 else { return }
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
    @discardableResult
    func confirmDeleteAll(_ target: DeleteTarget) -> Task<Void, Never>? {
        guard !isBusy else { return nil }
        alert = nil
        activity = target == .items ? .deleteItems : .deleteWishlist

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
                case .items:
                    for item in try modelContext.fetch(FetchDescriptor<Item>()) {
                        modelContext.delete(item)
                    }
                case .wishlist:
                    for wanted in try modelContext.fetch(FetchDescriptor<WishlistItem>()) {
                        modelContext.delete(wanted)
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

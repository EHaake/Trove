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

    // MARK: - Delete All

    func cancelDeleteAll() {
        alert = nil
    }
}

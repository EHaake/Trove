import Foundation
import SwiftData
import Testing
@testable import Trove

// MARK: - Fixtures

private func insertItem(
    _ name: String,
    category: String = "Music/Guitars",
    priceCents: Int = 0,
    valueCents: Int? = nil,
    order: Int = 0,
    createdAt: TimeInterval? = nil,
    photo: Bool = false,
    into context: ModelContext
) -> Item {
    let item = Item(
        name: name,
        categoryPath: category,
        purchasePriceCents: priceCents,
        currentValueCents: valueCents,
        sortOrder: order
    )
    if let createdAt {
        item.createdAt = Date(timeIntervalSince1970: createdAt)
    }
    if photo {
        item.photos = [Photo(imageData: Data([0xFF, 0xD8, 0xFF]))]
    }
    context.insert(item)
    return item
}

@discardableResult
private func insertWanted(
    _ name: String,
    category: String = "Music/Guitars",
    costCents: Int = 0,
    order: Int = 0,
    photo: Bool = false,
    plannedSaleItems: [Item] = [],
    into context: ModelContext
) -> WishlistItem {
    let wanted = WishlistItem(
        name: name,
        categoryPath: category,
        estimatedCostCents: costCents,
        sortOrder: order,
        plannedSaleItems: plannedSaleItems
    )
    if photo {
        wanted.photos = [Photo(imageData: Data([0xFF, 0xD8, 0xFF]))]
    }
    context.insert(wanted)
    return wanted
}

// MARK: - T008: the surface

/// 013/T008: counts, the `can…` flags, the live iCloud row, and the alert
/// copy — everything the screen shows, owned by the view model.
@Suite("SettingsViewModel — surface")
struct SettingsViewModelSurfaceTests {
    @Test func countsFollowTheWholeStore() throws {
        let context = try makeInMemoryContext()
        _ = insertItem("Guitar", into: context)
        _ = insertItem("Amp", into: context)
        insertWanted("Pedal", into: context)
        try context.save()

        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.itemCount == 2)
        #expect(viewModel.wishlistCount == 1)
    }

    /// Every combination of empty and non-empty, because the three flags
    /// are three different questions: export needs *either*, each delete
    /// needs *its own*.
    @Test func theFlagsAskThreeDifferentQuestions() throws {
        let empty = try makeInMemoryContext()
        let bare = SettingsViewModel(modelContext: empty)
        bare.load()
        #expect(!bare.canExportEverything)
        #expect(!bare.canDeleteItems)
        #expect(!bare.canDeleteWishlist)

        let itemsOnly = try makeInMemoryContext()
        _ = insertItem("Guitar", into: itemsOnly)
        try itemsOnly.save()
        let items = SettingsViewModel(modelContext: itemsOnly)
        items.load()
        #expect(items.canExportEverything)
        #expect(items.canDeleteItems)
        #expect(!items.canDeleteWishlist)

        let wishlistOnly = try makeInMemoryContext()
        insertWanted("Pedal", into: wishlistOnly)
        try wishlistOnly.save()
        let wanted = SettingsViewModel(modelContext: wishlistOnly)
        wanted.load()
        #expect(wanted.canExportEverything)
        #expect(!wanted.canDeleteItems)
        #expect(wanted.canDeleteWishlist)
    }

    /// The row is live: a finished, successful import recorded on the
    /// injected monitor changes what the view model says without a reload.
    @Test func theICloudRowFollowsTheMonitorLive() throws {
        let monitor = SyncMonitor(mode: .cloudKit)
        let viewModel = SettingsViewModel(
            modelContext: try makeInMemoryContext(),
            syncMonitor: monitor,
            storageMode: .cloudKit
        )
        #expect(viewModel.syncStatus.headline == "Catching up with iCloud")

        monitor.record(SyncEvent(kind: .importChanges, isFinished: true, succeeded: true))

        #expect(viewModel.syncStatus.headline == "Syncing with iCloud")
        #expect(viewModel.syncStatus == SyncStatusCopy.status(mode: .cloudKit, phase: .caughtUp, fallbackReason: nil))
    }

    @Test func theICloudRowCarriesTheFallbackReason() throws {
        let viewModel = SettingsViewModel(
            modelContext: try makeInMemoryContext(),
            syncMonitor: .notSyncing,
            storageMode: .localOnly,
            storageFallbackReason: "The container isn't reachable."
        )
        #expect(viewModel.syncStatus.headline == "On this device only")
        #expect(viewModel.syncStatus.detail.hasSuffix("The container isn't reachable."))
    }

    @Test func theDeleteConfirmationComposesTheSharedCopy() throws {
        let viewModel = SettingsViewModel(modelContext: try makeInMemoryContext(), storageMode: .cloudKit)
        viewModel.alert = .confirmDelete(.items, count: 3)

        #expect(viewModel.alertTitle == "Delete all 3 items?")
        #expect(viewModel.alertMessage == DeleteAllCopy.message(for: .items, count: 3, mode: .cloudKit))
        #expect(viewModel.alertMessage.contains("If you're signed in to iCloud"))
    }

    /// Decision 13 as a view-model fact: the same alert on a local-only
    /// store carries no iCloud sentence.
    @Test func theDeleteConfirmationFollowsTheStorageMode() throws {
        let viewModel = SettingsViewModel(modelContext: try makeInMemoryContext(), storageMode: .localOnly)
        viewModel.alert = .confirmDelete(.wishlist, count: 1)

        #expect(viewModel.alertTitle == "Delete your only wishlist item?")
        #expect(!viewModel.alertMessage.contains("iCloud"))
        #expect(viewModel.alertMessage == DeleteAllCopy.message(for: .wishlist, count: 1, mode: .localOnly))
    }

    /// Criterion 16: a failed export-everything shows 011's copy, not new
    /// words; a failed delete shows the mirror-image delete copy.
    @Test func theFailureAlertsReadTheSharedCopy() throws {
        let viewModel = SettingsViewModel(modelContext: try makeInMemoryContext())

        viewModel.alert = .exportFailed
        #expect(viewModel.alertTitle == ExportCopy.failureTitle)
        #expect(viewModel.alertMessage == ExportCopy.failureMessage)

        viewModel.alert = .deleteFailed
        #expect(viewModel.alertTitle == DeleteAllCopy.failureTitle)
        #expect(viewModel.alertMessage == DeleteAllCopy.failureMessage)

        viewModel.alert = nil
        #expect(viewModel.alertTitle.isEmpty)
        #expect(viewModel.alertMessage.isEmpty)
    }

    @Test func theVersionLineComesFromTheInjectedVersion() throws {
        let viewModel = SettingsViewModel(
            modelContext: try makeInMemoryContext(),
            appVersion: AppVersion(version: "3.1", build: "42")
        )
        #expect(viewModel.versionLine == "Version 3.1 (42)")
    }

    @Test func cancelClearsTheAlertAndTouchesNothing() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        _ = insertItem("Guitar", into: context)
        try context.save()

        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()
        viewModel.alert = .confirmDelete(.items, count: 1)
        viewModel.cancelDeleteAll()

        #expect(viewModel.alert == nil)
        #expect(!viewModel.isBusy)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Item>()) == 1)
    }
}

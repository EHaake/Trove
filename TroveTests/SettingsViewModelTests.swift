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

    @Test func cancelClearsTheAlertAndTouchesNothingElse() throws {
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

    /// 002/T006c: the device's market rows for the item — figure, history,
    /// snapshot — go with it, in the same save, read back on a second context.
    private func seedMarketRows(for id: UUID, in context: ModelContext) throws {
        let product = MarketProduct(id: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster", usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!)
        let figure = MarketFigure(medianCents: 140_000, lowCents: 130_000, highCents: 150_000, count: 12, fetchedAt: .now, isTruncated: false, yearScope: .any)
        try MarketLocalStore.record(.figure(figure), product: product, for: MarketSubjectKey(subjectID: id, kind: .owned), in: context)
    }

    private func marketRowsRemain(for id: UUID, in container: ModelContainer) throws -> Bool {
        let fresh = ModelContext(container)
        let figure = try MarketLocalStore.figure(for: id, in: fresh)
        let snapshot = try MarketLocalStore.snapshot(for: id, in: fresh)
        let history = try MarketLocalStore.history(for: id, in: fresh)
        return figure != nil || snapshot != nil || !history.isEmpty
    }

    /// 002/T006c, narrowed by spec Decision 30 (2026-09-04): Delete All
    /// clears the market rows of the items it deletes and nothing else —
    /// the other list's rows and the notice's acknowledgement survive it.
    /// Both directions are asserted, so "cleared everything" and "cleared
    /// nothing" are each red.
    @Test(arguments: [DeleteTarget.items, .wishlist])
    func confirmDeleteAllClearsOnlyTheDeletedItemsMarketRows(target: DeleteTarget) async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster", reverbProductID: 126_161)
        let wanted = WishlistItem(name: "D-18", reverbProductID: 182_769)
        context.insert(item); context.insert(wanted)
        let itemID = item.id, wantedID = wanted.id
        try seedMarketRows(for: itemID, in: context)
        try seedMarketRows(for: wantedID, in: context)
        try MarketLocalStore.acknowledgeNotice(at: .now, in: context)
        try context.save()
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()
        viewModel.requestDeleteAll(target)

        await viewModel.confirmDeleteAll(target)?.value

        let deleted = target == .items ? itemID : wantedID
        let survivor = target == .items ? wantedID : itemID
        let deletedRowsRemain = try marketRowsRemain(for: deleted, in: container)
        let survivorRowsRemain = try marketRowsRemain(for: survivor, in: container)
        #expect(!deletedRowsRemain, "the deleted list's market rows survived Delete All")
        #expect(survivorRowsRemain, "the other list's market rows were cleared too")
        #expect(MarketLocalStore.hasAcknowledgedNotice(in: ModelContext(container)), "Delete All reset the notice flag")
        #expect(viewModel.alert == nil)
    }

}

// MARK: - T009: export everything

/// 013/T009: both collections, whole, in Custom order, as one file set.
/// The order guard is an **independently written expectation** over a tie
/// fixture — after T003 the list and Settings share one comparator, so
/// equality with the list's table is a second assertion, not the guard
/// (the review's B1).
@Suite("SettingsViewModel — export everything")
struct SettingsViewModelExportTests {
    /// Equal positions with creation order running against the names, and
    /// one row placed after them — so a position-only sort, a name sort,
    /// and a fetch-order sort all fail this.
    private func seedTieFixture(into context: ModelContext) throws {
        _ = insertItem("Charlie", order: 0, createdAt: 100, into: context)
        _ = insertItem("Bravo", order: 0, createdAt: 200, into: context)
        _ = insertItem("alpha", order: 0, createdAt: 300, into: context)
        _ = insertItem("Zulu", order: 1, createdAt: 50, into: context)
        insertWanted("Charlie", order: 0, into: context)
        insertWanted("alpha", order: 0, into: context)
        insertWanted("Bravo", order: 0, into: context)
        insertWanted("Zed", order: 1, into: context)
        try context.save()
    }

    @Test func theCSVPairIsBothListsWholeInCustomOrderInOneCall() async throws {
        let context = try makeInMemoryContext()
        try seedTieFixture(into: context)
        let spy = ExportServiceSpy()
        let viewModel = SettingsViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        await viewModel.exportEverythingAsCSV()

        // One call carrying two files — two calls would purge each other.
        #expect(spy.fileSets.count == 1)
        #expect(spy.fileSets.first?.count == 2)
        let names = spy.tables.map { $0.rows.map { $0[0] } }
        #expect(names == [["Charlie", "Bravo", "alpha", "Zulu"], ["alpha", "Bravo", "Charlie", "Zed"]])
        #expect(spy.tables.map(\.headers) == [ExportSchema.itemHeaders, ExportSchema.wishlistHeaders])
        #expect(spy.filenames == [
            ExportFilename.items(fileExtension: "csv"),
            ExportFilename.wishlist(fileExtension: "csv"),
        ])
        #expect(viewModel.stagedExport?.filenames == spy.filenames)
        #expect(viewModel.stagedExport?.urls.count == 2)
        #expect(viewModel.activity == nil)
    }

    /// Criterion 5's byte-identity: the items file is what the Items list
    /// exports with no filter, no search, and Custom sort — and the
    /// wishlist file what the Wishlist exports likewise.
    @Test func eachFileIsByteIdenticalToTheListsOwnUnfilteredCustomExport() async throws {
        let context = try makeInMemoryContext()
        try seedTieFixture(into: context)

        let settingsSpy = ExportServiceSpy()
        let settings = SettingsViewModel(modelContext: context, exportService: settingsSpy)
        settings.load()
        await settings.exportEverythingAsCSV()

        let itemsSpy = ExportServiceSpy()
        let itemsList = ItemListViewModel(modelContext: context, exportService: itemsSpy)
        itemsList.sortOrder = .custom
        itemsList.load()
        await itemsList.exportCSV()

        let wishlistSpy = ExportServiceSpy()
        let wishlist = WishlistViewModel(modelContext: context, exportService: wishlistSpy)
        wishlist.sortOrder = .custom
        wishlist.load()
        await wishlist.exportCSV()

        let itemsTable = try #require(itemsSpy.tables.first)
        let wishlistTable = try #require(wishlistSpy.tables.first)
        #expect(CSVWriter.write(settingsSpy.tables[0]) == CSVWriter.write(itemsTable))
        #expect(CSVWriter.write(settingsSpy.tables[1]) == CSVWriter.write(wishlistTable))
    }

    /// Criterion 6: the covers are the lists' unfiltered covers in
    /// everything but the generation instant, and the entries match.
    @Test func thePDFPairMatchesTheListsUnfilteredDocuments() async throws {
        let context = try makeInMemoryContext()
        _ = insertItem("Valued", priceCents: 100_00, valueCents: 150_00, order: 0, into: context)
        _ = insertItem("Unvalued", priceCents: 50_00, valueCents: nil, order: 1, into: context)
        insertWanted("Pedal", costCents: 20_00, order: 0, into: context)
        insertWanted("Amp", costCents: 30_00, order: 1, into: context)
        try context.save()

        let settingsSpy = ExportServiceSpy()
        let settings = SettingsViewModel(modelContext: context, exportService: settingsSpy)
        settings.load()
        await settings.exportEverythingAsPDF()

        let itemsSpy = ExportServiceSpy()
        let itemsList = ItemListViewModel(modelContext: context, exportService: itemsSpy)
        itemsList.sortOrder = .custom
        itemsList.load()
        await itemsList.exportPDF()

        let wishlistSpy = ExportServiceSpy()
        let wishlist = WishlistViewModel(modelContext: context, exportService: wishlistSpy)
        wishlist.load()
        await wishlist.exportPDF()

        #expect(settingsSpy.fileSets.count == 1)
        #expect(settingsSpy.documents.count == 2)
        let expected = [try #require(itemsSpy.documents.first), try #require(wishlistSpy.documents.first)]
        for (produced, list) in zip(settingsSpy.documents, expected) {
            #expect(produced.cover.title == list.cover.title)
            #expect(produced.cover.coverageLabel == list.cover.coverageLabel)
            #expect(produced.cover.itemCount == list.cover.itemCount)
            #expect(produced.entries.map(\.name) == list.entries.map(\.name))
            switch (produced.cover.totals, list.cover.totals) {
            case let (.items(value, paid, unvalued), .items(listValue, listPaid, listUnvalued)):
                #expect((value, paid, unvalued) == (listValue, listPaid, listUnvalued))
                #expect((value, paid, unvalued) == (150_00, 150_00, 1))
            case let (.wishlist(cost), .wishlist(listCost)):
                #expect(cost == listCost)
                #expect(cost == 50_00)
            default:
                Issue.record("cover totals are for different lists")
            }
        }
        #expect(settingsSpy.documents.map(\.cover.coverageLabel) == ["All items", "Whole wishlist"])
        #expect(settingsSpy.filenames == [
            ExportFilename.items(fileExtension: "pdf"),
            ExportFilename.wishlist(fileExtension: "pdf"),
        ])
    }

    @Test func nothingIsExportedWhenBothCollectionsAreEmpty() async throws {
        let spy = ExportServiceSpy()
        let viewModel = SettingsViewModel(modelContext: try makeInMemoryContext(), exportService: spy)
        viewModel.load()
        try #require(viewModel.canExportEverything == false)

        await viewModel.exportEverythingAsCSV()
        await viewModel.exportEverythingAsPDF()

        #expect(spy.fileSets.isEmpty)
        #expect(viewModel.stagedExport == nil)
        #expect(viewModel.alert == nil)
    }

    /// Spec P2: one empty collection still means two files — the empty
    /// one's CSV is header-only (the template's bytes) and its PDF a
    /// cover-only document saying so.
    @Test func oneEmptyCollectionStillDeliversTwoFiles() async throws {
        let context = try makeInMemoryContext()
        _ = insertItem("Guitar", into: context)
        try context.save()
        let spy = ExportServiceSpy()
        let viewModel = SettingsViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        await viewModel.exportEverythingAsCSV()
        await viewModel.exportEverythingAsPDF()

        #expect(spy.fileSets.map(\.count) == [2, 2])
        let wishlistTable = try #require(spy.tables.last)
        #expect(wishlistTable.headers == ExportSchema.wishlistHeaders)
        #expect(wishlistTable.rows.isEmpty)
        #expect(CSVWriter.write(wishlistTable)
            == "\u{FEFF}" + ExportSchema.wishlistHeaders.joined(separator: ",") + "\r\n")
        let wishlistDocument = try #require(spy.documents.last)
        #expect(wishlistDocument.entries.isEmpty)
        #expect(wishlistDocument.cover.itemCount == 0)
    }

    @Test func aThrowingServiceSurfacesTheSharedExportCopy() async throws {
        let context = try makeInMemoryContext()
        _ = insertItem("Guitar", into: context)
        try context.save()
        let viewModel = SettingsViewModel(
            modelContext: context,
            exportService: ExportServiceSpy(failsEveryCall: true)
        )
        viewModel.load()

        await viewModel.exportEverythingAsCSV()

        #expect(viewModel.alert == .exportFailed)
        #expect(viewModel.alertTitle == ExportCopy.failureTitle)
        #expect(viewModel.alertMessage == ExportCopy.failureMessage)
        #expect(viewModel.stagedExport == nil)
        #expect(viewModel.activity == nil)
    }

    /// The gated-spy pattern: `activity` is observable while the set is
    /// generating, and a second action started mid-flight is refused —
    /// the spy gates only its first call, so a leaked reentrant call
    /// fails the count rather than hanging the test.
    @Test func activityIsObservableMidFlightAndBlocksReentry() async throws {
        let context = try makeInMemoryContext()
        _ = insertItem("Guitar", into: context)
        try context.save()
        let spy = GatedExportServiceSpy()
        let viewModel = SettingsViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        let inFlight = Task { await viewModel.exportEverythingAsCSV() }
        for _ in 0..<10_000 where spy.fileSetCalls == 0 { await Task.yield() }
        try #require(spy.fileSetCalls == 1, "gated export never started")

        #expect(viewModel.activity == .exportCSV)
        #expect(viewModel.isBusy)
        await viewModel.exportEverythingAsPDF()
        #expect(spy.fileSetCalls == 1, "a reentrant action reached the service")
        #expect(viewModel.activity == .exportCSV)

        spy.release()
        await inFlight.value
        #expect(viewModel.activity == nil)
        #expect(viewModel.stagedExport?.urls.count == 2)
    }
}

// MARK: - T010: the templates, relocated

/// 013/T010: 012's template tests, re-pointed at the Settings view model
/// with their assertions intact — the same bytes, the same names, ungated
/// by the counts, from an empty collection.
@Suite("SettingsViewModel — templates")
struct SettingsViewModelTemplateTests {
    @Test func theItemsTemplateStagesHeaderOnlyBytesFromAnEmptyCollection() async throws {
        let spy = ExportServiceSpy()
        let viewModel = SettingsViewModel(modelContext: try makeInMemoryContext(), exportService: spy)
        viewModel.load()
        try #require(viewModel.canExportEverything == false, "the empty collection is the point")

        await viewModel.exportItemsTemplate()

        let table = try #require(spy.tables.first)
        #expect(table.headers == ExportSchema.itemHeaders)
        #expect(table.rows.isEmpty)
        // The exact bytes: BOM + the header row + one CRLF — the canonical
        // blank template (verified against CSVWriter, the real serializer).
        #expect(
            CSVWriter.write(table)
                == "\u{FEFF}" + ExportSchema.itemHeaders.joined(separator: ",") + "\r\n"
        )
        #expect(spy.filenames == ["Trove-Items-Template.csv"])
        #expect(spy.fileSets.count == 1)
        #expect(viewModel.stagedExport?.filenames == [ExportFilename.itemsTemplate])
        #expect(viewModel.activity == nil)
    }

    @Test func theWishlistTemplateStagesHeaderOnlyBytesFromAnEmptyCollection() async throws {
        let spy = ExportServiceSpy()
        let viewModel = SettingsViewModel(modelContext: try makeInMemoryContext(), exportService: spy)
        viewModel.load()
        try #require(viewModel.canExportEverything == false)

        await viewModel.exportWishlistTemplate()

        let table = try #require(spy.tables.first)
        #expect(table.headers == ExportSchema.wishlistHeaders)
        #expect(table.rows.isEmpty)
        #expect(
            CSVWriter.write(table)
                == "\u{FEFF}" + ExportSchema.wishlistHeaders.joined(separator: ",") + "\r\n"
        )
        #expect(spy.filenames == ["Trove-Wishlist-Template.csv"])
        #expect(viewModel.stagedExport?.filenames == [ExportFilename.wishlistTemplate])
    }

    @Test func aThrowingServiceSurfacesTheSharedCopyForATemplateToo() async throws {
        let viewModel = SettingsViewModel(
            modelContext: try makeInMemoryContext(),
            exportService: ExportServiceSpy(failsEveryCall: true)
        )
        viewModel.load()

        await viewModel.exportItemsTemplate()

        #expect(viewModel.alert == .exportFailed)
        #expect(viewModel.stagedExport == nil)
    }
}

// MARK: - T011: Delete All

/// 013/T011: request, confirm, cancel — and every persistence claim
/// verified through a **second `ModelContext`** over the same container,
/// the T018 shape: a same-context refetch returns unsaved deletions and
/// would pass with `save()` deleted.
@Suite("SettingsViewModel — Delete All")
struct SettingsViewModelDeleteTests {
    private func counts(in container: ModelContainer) throws -> (items: Int, wanted: Int, photos: Int) {
        let fresh = ModelContext(container)
        return (
            try fresh.fetchCount(FetchDescriptor<Item>()),
            try fresh.fetchCount(FetchDescriptor<WishlistItem>()),
            try fresh.fetchCount(FetchDescriptor<Photo>())
        )
    }

    /// The title's count is the store's count *now*: a row arriving after
    /// the screen loaded (here, through a second context) is counted.
    @Test func requestCarriesTheLiveCount() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        _ = insertItem("Guitar", into: context)
        try context.save()
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()
        try #require(viewModel.itemCount == 1)

        let elsewhere = ModelContext(container)
        elsewhere.insert(Item(name: "Arrived from iCloud"))
        try elsewhere.save()

        viewModel.requestDeleteAll(.items)

        #expect(viewModel.alert == .confirmDelete(.items, count: 2))
        #expect(viewModel.alertTitle == "Delete all 2 items?")
    }

    @Test func requestOnAnEmptyListStagesNothing() throws {
        let viewModel = SettingsViewModel(modelContext: try makeInMemoryContext())
        viewModel.load()

        viewModel.requestDeleteAll(.items)
        viewModel.requestDeleteAll(.wishlist)

        #expect(viewModel.alert == nil)
    }

    @Test func cancelAfterRequestLeavesTheStoreIntact() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        _ = insertItem("Guitar", photo: true, into: context)
        insertWanted("Pedal", into: context)
        try context.save()
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()

        viewModel.requestDeleteAll(.items)
        viewModel.cancelDeleteAll()

        #expect(viewModel.alert == nil)
        let after = try counts(in: container)
        #expect(after.items == 1 && after.wanted == 1 && after.photos == 1)
    }

    /// Criterion 11: every item goes, its photos with it, every sell plan
    /// empties (the nullify direction), and no wishlist item is touched.
    @Test func confirmDeletesEveryItemAndOnlyItems() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let guitar = insertItem("Guitar", photo: true, into: context)
        _ = insertItem("Amp", into: context)
        insertWanted("Pedal", plannedSaleItems: [guitar], into: context)
        try context.save()
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()
        viewModel.requestDeleteAll(.items)

        await viewModel.confirmDeleteAll(.items)?.value

        let after = try counts(in: container)
        #expect(after.items == 0)
        #expect(after.wanted == 1)
        #expect(after.photos == 0)
        let survivor = try #require(ModelContext(container).fetch(FetchDescriptor<WishlistItem>()).first)
        #expect((survivor.plannedSaleItems ?? []).isEmpty, "the sell plan should have emptied, not vanished")
        #expect(viewModel.alert == nil)
        #expect(viewModel.activity == nil)
        #expect(viewModel.itemCount == 0)
        #expect(viewModel.wishlistCount == 1)
    }

    /// Criterion 12: the symmetric case — wanted items and their photos go,
    /// their sell plans go with them, and the gear on those plans stays.
    @Test func confirmDeletesEveryWishlistItemAndOnlyThose() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let guitar = insertItem("Guitar", into: context)
        insertWanted("Pedal", photo: true, plannedSaleItems: [guitar], into: context)
        insertWanted("Amp", into: context)
        try context.save()
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()
        viewModel.requestDeleteAll(.wishlist)

        await viewModel.confirmDeleteAll(.wishlist)?.value

        let after = try counts(in: container)
        #expect(after.wanted == 0)
        #expect(after.items == 1)
        #expect(after.photos == 0)
        let gear = try #require(ModelContext(container).fetch(FetchDescriptor<Item>()).first)
        #expect(gear.name == "Guitar")
        #expect((gear.plannedForWishlistItems ?? []).isEmpty)
        #expect(viewModel.wishlistCount == 0)
        #expect(viewModel.itemCount == 1)
    }

    /// The T017 race, pinned from the other direction: the alert's binding
    /// writes `alert` nil *before* the confirm intent runs. The intent
    /// takes its target as a parameter and never reads `alert`, so the
    /// deletion cannot be lost.
    @Test func aDismissalWriteBeforeTheCallCannotLoseTheDeletion() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        _ = insertItem("Guitar", into: context)
        try context.save()
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()
        viewModel.requestDeleteAll(.items)
        try #require(viewModel.alert != nil)

        viewModel.alert = nil
        await viewModel.confirmDeleteAll(.items)?.value

        #expect(try counts(in: container).items == 0)
    }

    @Test func activityIsSetSynchronouslyAndClearsWhenDone() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        _ = insertItem("Guitar", into: context)
        insertWanted("Pedal", into: context)
        try context.save()
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()

        let first = viewModel.confirmDeleteAll(.items)
        #expect(viewModel.activity == .deleteItems)
        #expect(viewModel.isBusy)
        // A second action while one is in flight is refused outright.
        #expect(viewModel.confirmDeleteAll(.wishlist) == nil)

        await first?.value

        #expect(viewModel.activity == nil)
        let after = try counts(in: container)
        #expect(after.items == 0)
        #expect(after.wanted == 1, "the refused second action must not have run")
    }

    /// The plan's measurement (§The delete-all commit path): ~300 items,
    /// each carrying a photo blob, deleted in one save. The figure prints
    /// to the test log and is recorded in plan.md; the assertions are the
    /// correctness ones — timing never gates a test.
    @Test func deletingThreeHundredItemsWithPhotosIsAllOrNothingAndTimed() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        for index in 0..<300 {
            let item = Item(name: "Item \(index)", sortOrder: index)
            item.photos = [Photo(imageData: Data(repeating: UInt8(index % 251), count: 50_000))]
            context.insert(item)
        }
        try context.save()
        try #require(try counts(in: container).photos == 300)
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()

        let elapsed = await ContinuousClock().measure {
            await viewModel.confirmDeleteAll(.items)?.value
        }
        print("T011 measurement: deleted 300 items with photos in \(elapsed)")

        let after = try counts(in: container)
        #expect(after.items == 0)
        #expect(after.photos == 0)
        #expect(viewModel.alert == nil)
    }
}

// MARK: - T014: Refresh market values (002)

/// 002/T014, plan §6: Settings' one walk over every matched item — owned in
/// Custom order then wanted, the within-the-hour ones skipped (criterion 9),
/// the progress observable while it runs, and a stop at the first failure
/// with the words Decision 27 gives it. The scripted spy answers in call
/// order and **throws when its script runs out**, so a walk that visits one
/// item more than the test expects fails on that call.
@Suite("SettingsViewModel — market refresh")
struct SettingsViewModelMarketRefreshTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let minute: TimeInterval = 60

    private func product(_ id: Int) -> MarketProduct {
        MarketProduct(
            id: id,
            slug: "product-\(id)",
            title: "Product \(id)",
            usedLowCents: 100_000,
            usedTotal: 12,
            listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=\(id)")!
        )
    }

    /// Three USD listings in one condition — enough for a figure, so a
    /// refreshed item is visible as a median rather than a withheld row.
    private func listings(median: Int) -> MarketListings {
        let prices = [median - 40_000, median, median + 40_000]
        return MarketListings(
            listings: prices.map { MarketListing(priceCents: $0, currency: "USD", conditionSlug: "excellent", year: nil) },
            reportedTotal: prices.count,
            isTruncated: false
        )
    }

    private func viewModel(_ context: ModelContext, service: any MarketService, now: Date? = nil) -> SettingsViewModel {
        let clock = now ?? t0
        let viewModel = SettingsViewModel(modelContext: context, marketService: service, now: { clock })
        viewModel.load()
        return viewModel
    }

    /// A stored figure at `fetchedAt`, written through the store's own
    /// writer — the same row the hour budget reads.
    private func seedFigure(for id: UUID, kind: MarketSubjectKind, productID: Int, at fetchedAt: Date, in context: ModelContext) throws {
        let figure = MarketFigure(medianCents: 111_000, lowCents: 100_000, highCents: 120_000, count: 12, fetchedAt: fetchedAt, isTruncated: false, yearScope: .any)
        try MarketLocalStore.record(.figure(figure), product: product(productID), for: MarketSubjectKey(subjectID: id, kind: kind), in: context)
        try context.save()
    }

    private func storedMedian(for id: UUID, in container: ModelContainer) throws -> Int? {
        try MarketLocalStore.figure(for: id, in: ModelContext(container))?.medianCents
    }

    // MARK: - The walk

    /// Both kinds, in the lists' own order, with the unmatched ones absent
    /// and the within-the-hour one skipped: the spy's call log is the
    /// assertion, so an extra visit and a missing one are each red.
    @Test func theWalkVisitsEveryDueMatchInOrderAcrossBothLists() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let second = Item(name: "Amp", sortOrder: 1, reverbProductID: 111)
        let first = Item(name: "Telecaster", sortOrder: 0, reverbProductID: 222)
        let unmatched = Item(name: "Pedal", sortOrder: 2)
        let fresh = Item(name: "Bass", sortOrder: 3, reverbProductID: 555)
        let wanted = WishlistItem(name: "D-18", sortOrder: 0, reverbProductID: 444)
        let unmatchedWanted = WishlistItem(name: "Pedal Steel", sortOrder: 1)
        for model in [second, first, unmatched, fresh] { context.insert(model) }
        context.insert(wanted); context.insert(unmatchedWanted)
        try context.save()
        // Refreshed half an hour ago: skipped, not sent (criterion 9, P7).
        try seedFigure(for: fresh.id, kind: .owned, productID: 555, at: t0.addingTimeInterval(-30 * minute), in: context)

        let spy = MarketServiceSpy(
            products: [.success(product(222)), .success(product(111)), .success(product(444))],
            listings: [.success(listings(median: 140_000)), .success(listings(median: 90_000)), .success(listings(median: 200_000))]
        )
        let viewModel = viewModel(context, service: spy)
        #expect(viewModel.matchedCount == 4, "the fresh item is still matched — only the walk skips it")

        await viewModel.refreshMarketValues()

        #expect(spy.calls == [
            .product(222), .listings(productID: 222),
            .product(111), .listings(productID: 111),
            .product(444), .listings(productID: 444),
        ], "the walk visited the wrong items, or in the wrong order")
        #expect(viewModel.marketRefreshStatus == nil, "a walk that finished said something")
        #expect(viewModel.marketRefreshNote == nil, "a walk that visited items showed the nothing-due note")
        #expect(viewModel.marketRefreshProgress == nil, "the progress outlived the walk")
        #expect(!viewModel.isBusy)
        #expect(try storedMedian(for: first.id, in: container) == 140_000)
        #expect(try storedMedian(for: second.id, in: container) == 90_000)
        #expect(try storedMedian(for: wanted.id, in: container) == 200_000)
        #expect(try storedMedian(for: fresh.id, in: container) == 111_000, "the skipped item was refreshed anyway")
    }

    /// Decision 38: every matched item refreshed within the hour → the row
    /// is enabled, the walk sends nothing, and one quiet line says why. The
    /// note is not the failure status, and it clears when a later walk has
    /// something to visit.
    @Test func aWalkWithNothingDueSaysSoAndSendsNothing() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let owned = Item(name: "Telecaster", sortOrder: 0, reverbProductID: 222)
        let wanted = WishlistItem(name: "D-18", sortOrder: 0, reverbProductID: 444)
        context.insert(owned); context.insert(wanted)
        try context.save()
        try seedFigure(for: owned.id, kind: .owned, productID: 222, at: t0.addingTimeInterval(-30 * minute), in: context)
        try seedFigure(for: wanted.id, kind: .wanted, productID: 444, at: t0.addingTimeInterval(-59 * minute), in: context)

        let spy = MarketServiceSpy(products: [], listings: [])
        let settings = viewModel(context, service: spy)
        #expect(settings.canRefreshMarketValues, "two matched items leave the row enabled")
        #expect(settings.marketRefreshNote == nil, "the note showed before any walk")

        await settings.refreshMarketValues()

        #expect(spy.calls.isEmpty, "a walk with nothing due sent a request")
        #expect(settings.marketRefreshNote == MarketCopy.nothingDue)
        #expect(settings.marketRefreshStatus == nil, "nothing due was reported as a failure")
        #expect(settings.marketRefreshProgress == nil)
        #expect(!settings.isBusy)

        // An hour and a minute later the owned item is due: the note clears
        // as the walk starts, and the walk itself runs.
        let later = viewModel(context, service: MarketServiceSpy(
            products: [.success(product(222)), .success(product(444))],
            listings: [.success(listings(median: 140_000)), .success(listings(median: 200_000))]
        ), now: t0.addingTimeInterval(61 * minute))
        await later.refreshMarketValues()
        #expect(later.marketRefreshNote == nil, "the note outlived a walk that visited items")
        #expect(later.marketRefreshStatus == nil)
    }

    /// The row's "3 of 12" while it runs, and no second walk behind it: the
    /// gated spy holds the first `listings` call open, and only that one, so
    /// a reentrant walk shows up as a second call rather than a deadlock.
    @Test func theProgressIsObservableMidFlightAndASecondWalkIsRefused() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(Item(name: "Telecaster", sortOrder: 0, reverbProductID: 111))
        context.insert(Item(name: "Amp", sortOrder: 1, reverbProductID: 222))
        try context.save()

        let gated = GatedMarketServiceSpy(product: .success(product(111)), listings: .success(listings(median: 140_000)))
        let viewModel = viewModel(context, service: gated)
        #expect(viewModel.canRefreshMarketValues)

        let task = Task { await viewModel.refreshMarketValues() }
        // Bounded: a walk that never reaches the spy turns the require
        // below red instead of spinning the suite forever.
        var yields = 0
        while gated.listingsCalls == 0 && yields < 10_000 {
            await Task.yield()
            yields += 1
        }
        try #require(gated.listingsCalls == 1)

        #expect(viewModel.activity == .refreshMarket)
        #expect(viewModel.isBusy)
        #expect(!viewModel.canRefreshMarketValues, "a walk in flight offered another")
        let midFlight = viewModel.marketRefreshProgress
        #expect(midFlight?.done == 0)
        #expect(midFlight?.total == 2)
        await viewModel.refreshMarketValues()
        #expect(gated.listingsCalls == 1, "the reentrant walk reached Reverb")

        gated.release()
        await task.value

        #expect(gated.listingsCalls == 2, "the walk didn't reach the second item")
        #expect(viewModel.marketRefreshProgress == nil)
        #expect(viewModel.marketRefreshStatus == nil)
        #expect(viewModel.activity == nil)
    }

    // MARK: - Stopping (criterion 10, Decision 27)

    /// Reverb's limit stops the walk where it stands, in its own words, and
    /// what was already refreshed stays refreshed (P8).
    @Test func theRateLimitStopsTheWalkAndKeepsTheEarlierFigures() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let first = Item(name: "Telecaster", sortOrder: 0, reverbProductID: 111)
        let second = Item(name: "Amp", sortOrder: 1, reverbProductID: 222)
        let third = Item(name: "Bass", sortOrder: 2, reverbProductID: 333)
        for model in [first, second, third] { context.insert(model) }
        try context.save()

        let spy = MarketServiceSpy(
            products: [.success(product(111)), .success(product(222)), .success(product(333))],
            listings: [.success(listings(median: 140_000)), .failure(.rateLimited), .success(listings(median: 200_000))]
        )
        let viewModel = viewModel(context, service: spy)

        await viewModel.refreshMarketValues()

        #expect(viewModel.marketRefreshStatus == MarketCopy.rateLimited)
        #expect(spy.calls == [
            .product(111), .listings(productID: 111),
            .product(222), .listings(productID: 222),
        ], "the walk carried on past the rate limit")
        #expect(try storedMedian(for: first.id, in: container) == 140_000, "the figure fetched before the limit was lost")
        #expect(try storedMedian(for: third.id, in: container) == nil)
        #expect(viewModel.marketRefreshProgress == nil)
        #expect(!viewModel.isBusy)
    }

    /// Any other failure stops it too, and says how far it got — Decision
    /// 27's line, with the count over the due ones.
    @Test func anUnreachableFailureStopsTheWalkAndSaysHowFarItGot() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let first = Item(name: "Telecaster", sortOrder: 0, reverbProductID: 111)
        let second = Item(name: "Amp", sortOrder: 1, reverbProductID: 222)
        let third = Item(name: "Bass", sortOrder: 2, reverbProductID: 333)
        for model in [first, second, third] { context.insert(model) }
        try context.save()

        let spy = MarketServiceSpy(
            products: [.success(product(111)), .failure(.unreachable), .success(product(333))],
            listings: [.success(listings(median: 140_000)), .success(listings(median: 200_000))]
        )
        let viewModel = viewModel(context, service: spy)

        await viewModel.refreshMarketValues()

        #expect(viewModel.marketRefreshStatus == MarketCopy.refreshStoppedUnreachable(done: 1, total: 3))
        #expect(spy.calls == [.product(111), .listings(productID: 111), .product(222)], "the walk carried on past the failure")
        #expect(try storedMedian(for: first.id, in: container) == 140_000)
        #expect(try storedMedian(for: third.id, in: container) == nil)
    }

    // MARK: - The count

    /// One definition of "matched", `MarketRefresher.targets(in:)`, so the
    /// row's count and the walk can't disagree — and both lists count.
    @Test func matchedCountCountsBothKindsAndGatesTheRow() throws {
        let context = try makeInMemoryContext()
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()
        #expect(viewModel.matchedCount == 0)
        #expect(!viewModel.canRefreshMarketValues, "the row offered a walk with nothing matched")

        context.insert(Item(name: "Telecaster", sortOrder: 0, reverbProductID: 111))
        context.insert(Item(name: "Amp", sortOrder: 1, reverbProductID: 222))
        context.insert(Item(name: "Pedal", sortOrder: 2))
        // 006/G8: matched but sold — no market value to track, so the count
        // and the walk both pass it by, through the one definition.
        let sold = Item(name: "Jazzmaster", sortOrder: 3, reverbProductID: 333)
        sold.sale = Sale(date: Date(timeIntervalSince1970: 1_770_000_000), priceCents: 130_000, location: nil, note: nil)
        context.insert(sold)
        context.insert(WishlistItem(name: "D-18", sortOrder: 0, reverbProductID: 444))
        context.insert(WishlistItem(name: "Pedal Steel", sortOrder: 1))
        try context.save()
        viewModel.load()

        #expect(viewModel.matchedCount == 3, "the count misses one of the two lists, or counts a sold item")
        #expect(viewModel.canRefreshMarketValues)
    }
}

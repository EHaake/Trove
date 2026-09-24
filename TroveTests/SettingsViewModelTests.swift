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
        #expect(viewModel.alertMessage == DeleteAllCopy.message(for: .items, count: 3, mode: .cloudKit, picturesACompletedPlan: false))
        #expect(viewModel.alertMessage.contains("If you're signed in to iCloud"))
    }

    /// Decision 13 as a view-model fact: the same alert on a local-only
    /// store carries no iCloud sentence.
    @Test func theDeleteConfirmationFollowsTheStorageMode() throws {
        let viewModel = SettingsViewModel(modelContext: try makeInMemoryContext(), storageMode: .localOnly)
        viewModel.alert = .confirmDelete(.wishlist, count: 1)

        #expect(viewModel.alertTitle == "Delete your only wishlist item?")
        #expect(!viewModel.alertMessage.contains("iCloud"))
        #expect(viewModel.alertMessage == DeleteAllCopy.message(for: .wishlist, count: 1, mode: .localOnly, picturesACompletedPlan: false))
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
        await itemsList.exportCSV(scope: .both)

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
        await itemsList.exportPDF(scope: .owned)

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

    /// A day in UTC, for the sale fixtures below — built here rather than
    /// read from a clock so the expected order is a fact about the data.
    private func day(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    /// 006/G28, the Settings half: with a sale present the items CSV is the
    /// owned rows in Custom order, then the sold rows in Sold-side order —
    /// most recent sale first, name case-insensitively on a tie. The sold
    /// rows' own `sortOrder` runs against that order on purpose, so a single
    /// Custom sort over everything, or a fetch-order pass-through, fails
    /// this. (The other half — byte-identity with the list's own unfiltered
    /// CSV — completes at T009, when the list gains its sides.)
    @Test func theItemsCSVIsOwnedInCustomOrderThenSoldInSoldSideOrder() async throws {
        let context = try makeInMemoryContext()
        try seedTieFixture(into: context)
        // Sale dates and manual positions deliberately disagree.
        let zebra = insertItem("Zebra", order: 9, into: context)
        zebra.sale = Sale(date: try day(2026, 6, 1), priceCents: 90_000, location: "Reverb", note: nil)
        let beta = insertItem("beta", order: 1, into: context)
        beta.sale = Sale(date: try day(2026, 3, 1), priceCents: 20_000, location: nil, note: nil)
        let alpha = insertItem("Alpha", order: 2, into: context)
        alpha.sale = Sale(date: try day(2026, 3, 1), priceCents: 30_000, location: nil, note: nil)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = SettingsViewModel(modelContext: context, exportService: spy)
        viewModel.load()
        await viewModel.exportEverythingAsCSV()

        let items = try #require(spy.tables.first)
        #expect(items.rows.map { $0[0] } == [
            "Charlie", "Bravo", "alpha", "Zulu", "Zebra", "Alpha", "beta",
        ])
        // And the sold rows carry the sale the owned ones leave blank.
        let priceColumn = try #require(ExportSchema.itemHeaders.firstIndex(of: "Sale Price"))
        #expect(items.rows.map { $0[priceColumn] } == [
            "", "", "", "", "900.00", "300.00", "200.00",
        ])
        // The wishlist file is untouched by any of this (criterion 12).
        #expect(spy.tables[1].rows.map { $0[0] } == ["alpha", "Bravo", "Charlie", "Zed"])
    }

    /// 006/G28's other half, completed now the list has two sides: with a
    /// sale present, Settings' items CSV is byte-identical to what the Items
    /// list exports unfiltered in Custom order — owned rows in Custom order,
    /// then sold rows in Sold-side order, on both paths. 013's criterion 5
    /// survives a sale being in the collection.
    ///
    /// Mutation: drop the sold half from `ItemListViewModel.exportCSV`, or
    /// sort it by anything but `areInSoldOrder`, and the two files diverge →
    /// red. The sold rows' `sortOrder` disagrees with their sale dates on
    /// purpose, so a single Custom sort over everything fails it too.
    @Test func theListsUnfilteredCSVStillMatchesSettingsByteForByteWithASalePresent() async throws {
        let context = try makeInMemoryContext()
        try seedTieFixture(into: context)
        let zebra = insertItem("Zebra", order: 9, into: context)
        zebra.sale = Sale(date: try day(2026, 6, 1), priceCents: 90_000, location: "Reverb", note: "clean")
        let beta = insertItem("beta", order: 1, into: context)
        beta.sale = Sale(date: try day(2026, 3, 1), priceCents: 20_000, location: nil, note: nil)
        let alpha = insertItem("Alpha", order: 2, into: context)
        alpha.sale = Sale(date: try day(2026, 3, 1), priceCents: 30_000, location: nil, note: nil)
        try context.save()

        let settingsSpy = ExportServiceSpy()
        let settings = SettingsViewModel(modelContext: context, exportService: settingsSpy)
        settings.load()
        await settings.exportEverythingAsCSV()

        let listSpy = ExportServiceSpy()
        let list = ItemListViewModel(modelContext: context, exportService: listSpy)
        list.sortOrder = .custom
        list.load()
        await list.exportCSV(scope: .both)

        let listTable = try #require(listSpy.tables.first)
        try #require(
            listTable.rows.map { $0[0] } == ["Charlie", "Bravo", "alpha", "Zulu", "Zebra", "Alpha", "beta"],
            "the list's own order changed — the equality below would be two wrongs agreeing"
        )
        #expect(CSVWriter.write(settingsSpy.tables[0]) == CSVWriter.write(listTable))
    }

    /// 014/G14: `013`'s byte-identity holds from **either** side of the Items
    /// list, whatever sort either side is showing (criterion 10). The list's
    /// sorts are reading aids; the file is the record — owned rows in Custom
    /// order when no owned row is on screen (014 plan R1), sold rows always in
    /// Date-sold order (P10).
    ///
    /// Mutation: order the owned half by `isOrderedBefore` from the Sold side
    /// → the `Date` sort puts Zulu first and the files diverge → red; write
    /// the sold half in the view's order → `Price ↑` and `Gain ↓` each
    /// diverge → red.
    @Test func theListsCSVMatchesSettingsFromEitherSideWhateverSortsShow() async throws {
        let context = try makeInMemoryContext()
        // Manual positions, names and purchase dates all disagree, so Custom
        // order and the Owned side's `Date` sort are genuinely two orders.
        let charlie = insertItem("Charlie", order: 0, createdAt: 100, into: context)
        charlie.purchaseDate = try day(2020, 1, 1)
        let bravo = insertItem("Bravo", order: 0, createdAt: 200, into: context)
        bravo.purchaseDate = try day(2024, 5, 1)
        let lowerAlpha = insertItem("alpha", order: 0, createdAt: 300, into: context)
        lowerAlpha.purchaseDate = try day(2022, 9, 1)
        let zulu = insertItem("Zulu", order: 1, createdAt: 50, into: context)
        zulu.purchaseDate = try day(2026, 1, 1)
        insertWanted("Pedal", order: 0, into: context)
        // Three sales whose prices and gains each order them differently from
        // Date sold — so `Price ↑` and `Gain ↓` are both real alternatives.
        let zebra = insertItem("Zebra", priceCents: 89_000, order: 9, into: context)
        zebra.sale = Sale(date: try day(2026, 6, 1), priceCents: 90_000, location: "Reverb", note: nil)
        let beta = insertItem("beta", order: 1, into: context)
        beta.sale = Sale(date: try day(2026, 3, 1), priceCents: 20_000, location: nil, note: nil)
        let alpha = insertItem("Alpha", order: 2, into: context)
        alpha.sale = Sale(date: try day(2026, 3, 1), priceCents: 30_000, location: nil, note: nil)
        try context.save()

        let settingsSpy = ExportServiceSpy()
        let settings = SettingsViewModel(modelContext: context, exportService: settingsSpy)
        settings.load()
        await settings.exportEverythingAsCSV()
        let expected = CSVWriter.write(settingsSpy.tables[0])

        // From the Sold side, with the Owned side left on `Date` and the Sold
        // side on `Price ↑`.
        let soldSpy = ExportServiceSpy()
        let fromSold = ItemListViewModel(modelContext: context, exportService: soldSpy)
        fromSold.sortOrder = .purchaseDate
        fromSold.show(.sold)
        fromSold.soldSortOrder = .salePriceAscending
        fromSold.load()
        try #require(
            fromSold.items.map(\.name) == ["Zulu", "Bravo", "alpha", "Charlie"],
            "the Owned side is showing an order the file must not use"
        )
        try #require(
            fromSold.soldItems.map(\.name) == ["beta", "Alpha", "Zebra"],
            "the Sold side is showing an order the file must not use"
        )
        await fromSold.exportCSV(scope: .both)
        let fromSoldTable = try #require(soldSpy.tables.first)
        try #require(
            fromSoldTable.rows.map { $0[0] } == ["Charlie", "Bravo", "alpha", "Zulu", "Zebra", "Alpha", "beta"],
            "the list's own order changed — the equality below would be two wrongs agreeing"
        )
        #expect(CSVWriter.write(fromSoldTable) == expected)

        // And from the Owned side under Custom, with the Sold side holding
        // `Gain ↓` — a third order again, and equally not the file's.
        let ownedSpy = ExportServiceSpy()
        let fromOwned = ItemListViewModel(modelContext: context, exportService: ownedSpy)
        fromOwned.show(.sold)
        fromOwned.soldSortOrder = .gainDescending
        fromOwned.show(.owned)
        fromOwned.sortOrder = .custom
        fromOwned.load()
        try #require(
            fromOwned.soldItems.map(\.name) == ["Alpha", "beta", "Zebra"],
            "the hidden Sold side is holding an order the file must not use"
        )
        await fromOwned.exportCSV(scope: .both)
        let fromOwnedTable = try #require(ownedSpy.tables.first)
        #expect(CSVWriter.write(fromOwnedTable) == expected)
    }

    /// 006/G16: the everything-PDF is the owned collection only — its
    /// entries, its `itemCount` and its cover totals — so the figures on the
    /// cover are the Dashboard's collection figures rather than a mix of
    /// what is owned and what was sold (criterion 14). Mutation: hand the
    /// document all the items and the count reads 2 → red.
    @Test func theEverythingPDFLeavesSoldItemsOut() async throws {
        let context = try makeInMemoryContext()
        _ = insertItem("Kept", priceCents: 100_00, valueCents: 150_00, order: 0, into: context)
        let gone = insertItem("Gone", priceCents: 50_00, valueCents: 200_00, order: 1, into: context)
        gone.sale = Sale(date: try day(2026, 6, 1), priceCents: 75_00, location: nil, note: nil)
        insertWanted("Pedal", costCents: 20_00, order: 0, into: context)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = SettingsViewModel(modelContext: context, exportService: spy)
        viewModel.load()
        await viewModel.exportEverythingAsPDF()

        let document = try #require(spy.documents.first)
        #expect(document.entries.map(\.name) == ["Kept"])
        #expect(document.cover.itemCount == 1)
        switch document.cover.totals {
        case let .items(value, paid, unvalued):
            #expect((value, paid, unvalued) == (150_00, 100_00, 0))
        case .wishlist, .sold:
            Issue.record("the items document carries another document's totals")
        }
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

    /// 009 T021a: a list of one item that a completed plan was bought as
    /// says the plan loses its picture; an ordinary only item doesn't.
    @Test func theOnlyItemsAlertSaysWhenItPicturesACompletedPlan() throws {
        let context = try makeInMemoryContext()
        let wanted = insertWanted("Vox AC15", category: "Music/Amps", into: context)
        let boughtAt = Date(timeIntervalSince1970: 1_760_000_000)
        let bought = try WishlistPurchaseStore.markBought(
            wanted,
            purchase: Purchase(date: boughtAt, priceCents: 70_000, location: "Reverb", condition: .excellent),
            at: boughtAt,
            in: context
        )
        try context.save()
        let viewModel = SettingsViewModel(modelContext: context, storageMode: .localOnly)

        viewModel.requestDeleteAll(.items)
        #expect(viewModel.alert == .confirmDelete(.items, count: 1))
        #expect(
            viewModel.alertMessage
                == "Its photos go too. Any sell plan it's on drops it, "
                + "and the completed plan it was bought for loses its picture. This can't be undone."
        )

        viewModel.cancelDeleteAll()
        context.delete(bought)
        _ = insertItem("Blues Junior", into: context)
        try context.save()

        viewModel.requestDeleteAll(.items)
        #expect(viewModel.alert == .confirmDelete(.items, count: 1))
        #expect(
            viewModel.alertMessage
                == "Its photos go too. Any sell plan it's on drops it. This can't be undone."
        )
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

// MARK: - 015/G10: Settings treats a bought entry as off the wishlist

/// G10 (015, plan §4 and R1, criterion 13). Settings reads `WishlistItem` in
/// three places, and all three take the bought entry as gone: the count that
/// feeds `canDeleteWishlist` and the delete alert, the export-everything
/// fetch, and the Delete-all walk. The matched count follows too (G11's
/// Settings half).
///
/// Each fixture's bought entry differs from the live ones by name, category
/// and estimated cost, and its purchase price differs from its estimate — so
/// a leg that counts it, exports it, deletes it or refreshes it fails on a
/// value no correct implementation produces.
@Suite("Settings treats a bought entry as off the wishlist")
struct SettingsBoughtExclusionTests {
    private let boughtAt = Date(timeIntervalSince1970: 1_780_000_000)

    /// Through `WishlistPurchaseStore` — the app's only writer of the marker.
    @discardableResult
    private func buy(_ wanted: WishlistItem, priceCents: Int, in context: ModelContext) throws -> Item {
        let item = try WishlistPurchaseStore.markBought(
            wanted,
            purchase: Purchase(date: boughtAt, priceCents: priceCents, location: "Reverb", condition: .excellent),
            at: boughtAt,
            in: context
        )
        try context.save()
        return item
    }

    // MARK: - The count (R1)

    @Test func theWishlistCountAndItsFlagsIgnoreABoughtEntry() throws {
        let context = try makeInMemoryContext()
        insertWanted("Vox AC15", category: "Music/Amps", costCents: 10_000, order: 0, into: context)
        let gibson = insertWanted("Gibson ES-335", category: "Music/Guitars", costCents: 250_000, order: 1, into: context)
        try context.save()
        try buy(gibson, priceCents: 300_000, in: context)

        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.wishlistCount == 1, "the bought entry is still counted as wanted")
        #expect(viewModel.canDeleteWishlist)
        #expect(viewModel.itemCount == 1, "the purchase's item is an ordinary item")

        viewModel.requestDeleteAll(.wishlist)
        #expect(viewModel.alert == .confirmDelete(.wishlist, count: 1))
    }

    /// The other end: buy the last wanted entry and the row disables itself.
    /// `canExportEverything` stays true on the item the purchase created,
    /// which is what R1 means by "not on the wishlist" rather than "gone".
    @Test func buyingTheLastWantedEntryDisablesDeleteAllWanted() throws {
        let context = try makeInMemoryContext()
        let amp = insertWanted("Vox AC15", category: "Music/Amps", costCents: 10_000, order: 0, into: context)
        try context.save()
        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()
        try #require(viewModel.canDeleteWishlist)

        try buy(amp, priceCents: 120_000, in: context)
        viewModel.load()

        #expect(viewModel.wishlistCount == 0)
        #expect(!viewModel.canDeleteWishlist)
        #expect(viewModel.canExportEverything, "the purchased item is still exportable")

        viewModel.requestDeleteAll(.wishlist)
        #expect(viewModel.alert == nil, "a wishlist with nothing wanted on it still offered the deletion")
    }

    // MARK: - The export (criterion 13)

    @Test func theWishlistCSVCarriesOnlyLiveRowsWhileTheItemsCSVCarriesThePurchase() async throws {
        let context = try makeInMemoryContext()
        insertWanted("Vox AC15", category: "Music/Amps", costCents: 10_000, order: 0, into: context)
        let gibson = insertWanted("Gibson ES-335", category: "Music/Guitars", costCents: 250_000, order: 1, into: context)
        try context.save()
        try buy(gibson, priceCents: 300_000, in: context)

        let spy = ExportServiceSpy()
        let viewModel = SettingsViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        await viewModel.exportEverythingAsCSV()

        #expect(spy.tables.count == 2)
        #expect(spy.tables[1].rows.map { $0[0] } == ["Vox AC15"], "the bought entry is in the wishlist CSV")
        #expect(spy.tables[0].rows.map { $0[0] } == ["Gibson ES-335"], "the purchase's item is missing from the items CSV")
        // Table count and order only. This compares the emitted headers
        // against the very constants the producer emits, so a new wishlist
        // column would move both sides together and leave this green — the
        // no-new-column half of criterion 13 is held by `ExportSchemaTests`'
        // `wishlistHeaders` literal, not here.
        #expect(spy.tables.map(\.headers) == [ExportSchema.itemHeaders, ExportSchema.wishlistHeaders],
                "the two files are in the wrong order, or one of them is missing")
    }

    @Test func theWishlistPDFCarriesOnlyLiveRowsAndItsCoverTotal() async throws {
        let context = try makeInMemoryContext()
        insertWanted("Vox AC15", category: "Music/Amps", costCents: 10_000, order: 0, into: context)
        let gibson = insertWanted("Gibson ES-335", category: "Music/Guitars", costCents: 250_000, order: 1, into: context)
        try context.save()
        try buy(gibson, priceCents: 300_000, in: context)

        let spy = ExportServiceSpy()
        let viewModel = SettingsViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        await viewModel.exportEverythingAsPDF()

        #expect(spy.documents.count == 2)
        #expect(spy.documents[1].entries.map(\.name) == ["Vox AC15"])
        #expect(spy.documents[1].cover.itemCount == 1)
        #expect(spy.documents[0].entries.map(\.name) == ["Gibson ES-335"])
        guard case .wishlist(let cost) = spy.documents[1].cover.totals else {
            Issue.record("the wishlist document's cover carries the wrong totals")
            return
        }
        #expect(cost == 10_000, "the bought entry's estimate is in the wishlist cover total")
    }

    // MARK: - Delete all wanted items (R1)

    @Test func deleteAllWantedLeavesTheBoughtEntryInTheStore() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        insertWanted("Vox AC15", category: "Music/Amps", costCents: 10_000, order: 0, into: context)
        insertWanted("Fender Twin", category: "Music/Amps", costCents: 180_000, order: 1, into: context)
        let gibson = insertWanted("Gibson ES-335", category: "Music/Guitars", costCents: 250_000, order: 2, into: context)
        try context.save()
        try buy(gibson, priceCents: 300_000, in: context)

        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()
        viewModel.requestDeleteAll(.wishlist)
        try #require(viewModel.alert == .confirmDelete(.wishlist, count: 2))

        await viewModel.confirmDeleteAll(.wishlist)?.value

        let elsewhere = ModelContext(container)
        let survivors = try elsewhere.fetch(FetchDescriptor<WishlistItem>())
        #expect(survivors.map(\.name) == ["Gibson ES-335"], "the gesture deleted more, or less, than the count promised")
        #expect(try #require(survivors.first).isBought)
        #expect(try elsewhere.fetchCount(FetchDescriptor<Item>()) == 1, "the purchase's item went with the wipe")
        #expect(viewModel.wishlistCount == 0)
    }

    // MARK: - The matched count (G11's Settings half)

    /// The arithmetic is the point: before the purchase two wanted entries
    /// are matched; after it the count is still 2, but it is a *different* 2
    /// — the new item takes the entry's place as an owned target. Leave the
    /// bought entry in the walk and it is 3.
    @Test func theMatchedCountDropsTheBoughtEntryAndPicksUpItsItem() throws {
        let context = try makeInMemoryContext()
        let amp = WishlistItem(name: "Vox AC15", categoryPath: "Music/Amps", sortOrder: 0, reverbProductID: 7)
        let gibson = WishlistItem(name: "Gibson ES-335", categoryPath: "Music/Guitars", sortOrder: 1, reverbProductID: 42)
        context.insert(amp)
        context.insert(gibson)
        try context.save()

        let viewModel = SettingsViewModel(modelContext: context)
        viewModel.load()
        try #require(viewModel.matchedCount == 2)

        try buy(gibson, priceCents: 300_000, in: context)
        viewModel.load()

        #expect(viewModel.matchedCount == 2, "the bought entry is still a refresh target — that would be 3")
        let targets = try MarketRefresher.targets(in: context)
        #expect(!targets.contains { $0.key.subjectID == gibson.id })
        #expect(targets.map(\.productID) == [42, 7], "the purchase's item carries the match, as an owned target")
    }
}

// MARK: - 009 Amendment A: G35, Delete all sell plans

/// G35 (009 Amendment A, plan QA4 and RA2(b); criteria 22 and 10–12). One
/// store holding every kind of row the gesture must tell apart: an active
/// plan, a completed plan, a stored plan whose row the carry-over has not
/// reached (the defence path `SellPlanStore.delete` documents), a row still
/// awaiting the carry-over, and two planless entries — one wanted, one bought.
///
/// Every persisted read is on a **second** `ModelContext`: a same-context
/// refetch hands back unsaved changes and would pass with the save removed.
/// The injected instant is in the past and distinct from every stamp in the
/// fixture, so a stamp written from anything but the view model's clock is
/// caught; every sale price differs from its item's current value.
@Suite("SettingsViewModel — Delete all sell plans")
struct SettingsDeleteAllSellPlansTests {
    private let earlier = Date(timeIntervalSince1970: 1_760_000_000)
    private let soldOn = Date(timeIntervalSince1970: 1_770_000_000)
    private let now = Date(timeIntervalSince1970: 1_780_000_000)
    private let later = Date(timeIntervalSince1970: 1_790_000_000)

    /// The four rows the delete clears — three stored plans and the row
    /// awaiting the carry-over (RA2(b)).
    private static let removed = ["Rickenbacker 330", "Gretsch White Falcon", "Danelectro 59", "Gibson ES-335"]
    private static let planless = ["Vox AC15", "Fender Twin"]

    private func sale(_ priceCents: Int) -> Sale {
        Sale(date: soldOn, priceCents: priceCents, location: "Reverb", note: nil)
    }

    private func viewModel(_ context: ModelContext) -> SettingsViewModel {
        SettingsViewModel(modelContext: context, now: { now })
    }

    private func entry(_ name: String, in context: ModelContext) throws -> WishlistItem {
        try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first { $0.name == name }, "no entry \(name)")
    }

    /// Every sale and value field criterion 10 names, per item — G6's shape.
    private struct ItemState: Equatable {
        let id: UUID
        let soldDate: Date?
        let salePriceCents: Int?
        let currentValueCents: Int?
        let desireToKeep: Int
    }

    private func itemStates(in context: ModelContext) throws -> [ItemState] {
        try context.fetch(FetchDescriptor<Item>())
            .map { ItemState(id: $0.id, soldDate: $0.soldDate, salePriceCents: $0.salePriceCents,
                             currentValueCents: $0.currentValueCents, desireToKeep: $0.desireToKeep) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// What of an entry the delete must leave alone.
    private struct EntryState: Equatable {
        let id: UUID
        let checkedAt: Date?
        let soldToward: [UUID]
        let boughtDate: Date?
        let boughtItemID: UUID?
    }

    private func entryStates(in context: ModelContext) throws -> [String: EntryState] {
        Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<WishlistItem>()).map {
            ($0.name, EntryState(
                id: $0.id,
                checkedAt: $0.sellPlanCheckedAt,
                soldToward: ($0.itemsSoldToward ?? []).map(\.id).sorted { $0.uuidString < $1.uuidString },
                boughtDate: $0.boughtDate,
                boughtItemID: $0.boughtItem?.id
            ))
        })
    }

    /// A plan made the way the app makes one, checked at `earlier` first so
    /// `create` leaves that stamp (it stamps only when nil).
    private func planned(_ name: String, in context: ModelContext) -> WishlistItem {
        let row = WishlistItem(name: name)
        context.insert(row)
        row.sellPlanCheckedAt = earlier
        SellPlanStore.create(for: row, at: earlier)
        return row
    }

    private func planlessOnly(in context: ModelContext) throws {
        let wanted = WishlistItem(name: "Vox AC15", estimatedCostCents: 80_000)
        let boughtPlanless = WishlistItem(name: "Fender Twin", estimatedCostCents: 180_000)
        context.insert(wanted)
        context.insert(boughtPlanless)
        try WishlistPurchaseStore.markBought(
            boughtPlanless, purchase: Purchase(date: soldOn, priceCents: 175_000, location: "Reverb", condition: .good),
            at: soldOn, in: context)
        try context.save()
    }

    private func seed(in context: ModelContext) throws {
        let telecaster = Item(name: "Telecaster", purchasePriceCents: 100_000, currentValueCents: 120_000, desireToKeep: 2)
        let jazzmaster = Item(name: "Jazzmaster", purchasePriceCents: 90_000, currentValueCents: 95_000, desireToKeep: 5)
        let bluesJunior = Item(name: "Blues Junior", purchasePriceCents: 60_000, currentValueCents: 55_000, desireToKeep: 1)
        let rat = Item(name: "ProCo RAT", purchasePriceCents: 8_000, currentValueCents: 7_000, desireToKeep: 3)
        let bigMuff = Item(name: "Big Muff", purchasePriceCents: 9_000, currentValueCents: 6_500, desireToKeep: 4)
        for item in [telecaster, jazzmaster, bluesJunior, rat, bigMuff] { context.insert(item) }

        // Active: a selection and a sale toward it.
        let active = planned("Rickenbacker 330", in: context)
        active.plannedSaleItems = [telecaster]
        try ItemSaleStore.markSold(bluesJunior, sale: sale(70_000), toward: active, at: soldOn, in: context)

        // Completed: a sale toward it, then bought — the purchase records its item.
        let completed = planned("Gretsch White Falcon", in: context)
        try ItemSaleStore.markSold(rat, sale: sale(11_000), toward: completed, at: soldOn, in: context)
        try WishlistPurchaseStore.markBought(
            completed, purchase: Purchase(date: soldOn, priceCents: 340_000, location: "Reverb", condition: .excellent),
            at: soldOn, in: context)

        // A stored plan the carry-over has not reached, with a sale toward it:
        // only `delete`'s nil-stamp keeps the carry-over from re-planning it.
        let unchecked = planned("Danelectro 59", in: context)
        try ItemSaleStore.markSold(bigMuff, sale: sale(12_000), toward: unchecked, at: soldOn, in: context)
        unchecked.sellPlanCheckedAt = nil

        // Awaiting the carry-over: no stored plan, a selection, unchecked.
        let awaiting = WishlistItem(name: "Gibson ES-335", plannedSaleItems: [jazzmaster])
        context.insert(awaiting)
        awaiting.sellPlanCheckedAt = nil

        try context.save()
        try planlessOnly(in: context)
    }

    // MARK: - The count (RA2(b))

    @Test func theCountIsTheStoredPlansAndTheRowAwaitingTheCarryOver() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try seed(in: context)
        let fixture = ModelContext(container)
        #expect(try entry("Gibson ES-335", in: fixture).awaitsCarryOver, "fixture: the Gibson awaits the carry-over")
        #expect(try entry("Danelectro 59", in: fixture).sellPlanCheckedAt == nil, "fixture: the Danelectro is unchecked")
        #expect(try entry("Gretsch White Falcon", in: fixture).isBought, "fixture: the Gretsch is completed")

        let viewModel = viewModel(context)
        viewModel.load()

        #expect(viewModel.planCount == 4, "three stored plans and the row awaiting the carry-over")
        #expect(viewModel.canDeleteSellPlans)
        viewModel.requestDeleteAll(.sellPlans)
        #expect(viewModel.alert == .confirmDelete(.sellPlans, count: 4))
        #expect(viewModel.alertTitle == "Delete all 4 sell plans?")
    }

    @Test func withNoPlansTheRowIsDimmedAndTheRequestStagesNothing() throws {
        let context = try makeInMemoryContext()
        try planlessOnly(in: context)
        let viewModel = viewModel(context)
        viewModel.load()

        #expect(viewModel.planCount == 0, "a planless entry, wanted or bought, is not a plan")
        #expect(!viewModel.canDeleteSellPlans)
        viewModel.requestDeleteAll(.sellPlans)
        #expect(viewModel.alert == nil)
    }

    /// The alert's number is the store's now: a plan arriving after the
    /// screen loaded, through a second context, is counted.
    @Test func theRequestReCountsAPlanThatArrivedAfterLoad() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try seed(in: context)
        let viewModel = viewModel(context)
        viewModel.load()
        try #require(viewModel.planCount == 4)

        let elsewhere = ModelContext(container)
        _ = planned("Arrived from iCloud", in: elsewhere)
        try elsewhere.save()

        viewModel.requestDeleteAll(.sellPlans)

        #expect(viewModel.alert == .confirmDelete(.sellPlans, count: 5))
    }

    // MARK: - The delete (criteria 10–12, 22)

    @Test func confirmRemovesEveryPlanAndNothingElse() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try seed(in: context)
        let before = ModelContext(container)
        let itemsBefore = try itemStates(in: before)
        let entriesBefore = try entryStates(in: before)
        try #require(itemsBefore.count == 7, "five owned items and the two purchases")
        try #require(entriesBefore.count == 6)
        try #require(entriesBefore["Gretsch White Falcon"]?.boughtItemID != nil, "fixture: the purchase recorded its item")
        let viewModel = viewModel(context)
        viewModel.load()
        viewModel.requestDeleteAll(.sellPlans)

        await viewModel.confirmDeleteAll(.sellPlans)?.value

        let after = ModelContext(container)
        #expect(try after.fetchCount(FetchDescriptor<WishlistItem>()) == 6, "every entry stays")
        #expect(try itemStates(in: after) == itemsBefore, "no item is created, removed, unsold, repriced or re-rated")
        let entriesAfter = try entryStates(in: after)
        for name in Self.removed {
            let stored = try entry(name, in: after)
            let was = try #require(entriesBefore[name])
            let current = try #require(entriesAfter[name])
            #expect(stored.sellPlanCreatedAt == nil, "\(name): the plan is gone")
            #expect((stored.plannedSaleItems ?? []).isEmpty, "\(name): the selection is gone")
            #expect(current.soldToward == was.soldToward, "\(name): the sold-toward record changed")
            #expect(current.boughtDate == was.boughtDate && current.boughtItemID == was.boughtItemID,
                    "\(name): the purchase record changed")
            #expect(current.checkedAt == (was.checkedAt ?? now), "\(name): the row does not end checked by the delete")
        }
        #expect(entriesBefore["Rickenbacker 330"]?.soldToward.isEmpty == false, "fixture: sales toward the plans")
        for name in Self.planless {
            #expect(entriesAfter[name] == entriesBefore[name], "\(name) was touched")
            #expect(try entry(name, in: after).sellPlanCreatedAt == nil)
        }
        #expect(viewModel.planCount == 0)
        #expect(viewModel.alert == nil)

        // Criterion 12: a deleted plan does not come back on its own.
        let carrying = ModelContext(container)
        _ = try SellPlanStore.carryOver(in: carrying, at: later)
        try carrying.save()
        let settled = ModelContext(container)
        for name in Self.removed {
            #expect(try entry(name, in: settled).sellPlanCreatedAt == nil, "\(name): the carry-over brought the plan back")
        }
    }

    @Test func activityIsSetSynchronouslyAndASecondActionIsRefused() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try seed(in: context)
        let viewModel = viewModel(context)
        viewModel.load()

        let first = viewModel.confirmDeleteAll(.sellPlans)
        #expect(viewModel.activity == .deleteSellPlans)
        #expect(viewModel.isBusy)
        #expect(viewModel.confirmDeleteAll(.items) == nil)

        await first?.value

        #expect(viewModel.activity == nil)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Item>()) == 7, "the refused second action must not have run")
    }
}

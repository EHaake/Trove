import Foundation
import SwiftData
import Testing
@testable import Trove

@Suite("ItemDetailViewModel")
struct ItemDetailViewModelTests {
    @Test func hasNothingLoadedBeforeLoadIsCalled() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(item)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)

        #expect(viewModel.item == nil)
        #expect(viewModel.hasLoaded == false)
    }

    @Test func loadsTheItemMatchingItsID() throws {
        let context = try makeInMemoryContext()
        let wanted = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        let other = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        context.insert(wanted)
        context.insert(other)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.item?.name == "Fender Telecaster")
    }

    /// The item may have been deleted on another device once sync is on, so
    /// "gone" has to be an ordinary outcome rather than a crash.
    @Test func loadsNothingForAnUnknownID() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Fender Telecaster", categoryPath: "Music/Guitars"))
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: UUID())
        viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.item == nil)
    }

    /// 009 T021a: the delete alert's completed-plan clause follows the item —
    /// true for the item a purchase created (through `markBought`, the only
    /// writer of the link), false for gear added by hand.
    @Test func onlyABoughtItemPicturesACompletedPlan() throws {
        let context = try makeInMemoryContext()
        let ordinary = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        let wanted = WishlistItem(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(ordinary)
        context.insert(wanted)
        let boughtAt = Date(timeIntervalSince1970: 1_760_000_000)
        let bought = try WishlistPurchaseStore.markBought(
            wanted,
            purchase: Purchase(date: boughtAt, priceCents: 150_000, location: "Reverb", condition: .excellent),
            at: boughtAt,
            in: context
        )
        try context.save()

        let boughtPage = ItemDetailViewModel(modelContext: context, itemID: bought.id)
        boughtPage.load()
        let ordinaryPage = ItemDetailViewModel(modelContext: context, itemID: ordinary.id)
        ordinaryPage.load()

        #expect(boughtPage.picturesACompletedPlan)
        #expect(!ordinaryPage.picturesACompletedPlan)
    }

    @Test func deleteRemovesTheItemFromTheStore() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(item)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        viewModel.load()

        #expect(viewModel.delete())
        #expect(viewModel.item == nil)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    @Test func deleteLeavesOtherItemsAlone() throws {
        let context = try makeInMemoryContext()
        let doomed = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        let survivor = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        context.insert(doomed)
        context.insert(survivor)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: doomed.id)
        viewModel.load()
        #expect(viewModel.delete())

        let remaining = try context.fetch(FetchDescriptor<Item>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "Leica M6")
    }

    @Test func deleteDoesNothingWhenNothingIsLoaded() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(item)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)

        #expect(viewModel.delete() == false)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
    }

    @Test func deletingAnItemTakesItsPhotosWithIt() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        let photo = Photo(imageData: Data([0x01]))
        context.insert(item)
        context.insert(photo)
        item.photos = [photo]
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        viewModel.load()
        #expect(viewModel.delete())

        #expect(try context.fetch(FetchDescriptor<Photo>()).isEmpty)
    }

    /// Deleting gear that's on a Sell Plan drops it from the plan; the
    /// wishlist item itself is untouched.
    @Test func deletingAnItemLeavesWishlistItemsIntact() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        let wishlistItem = WishlistItem(name: "Rickenbacker 330")
        context.insert(item)
        context.insert(wishlistItem)
        wishlistItem.plannedSaleItems = [item]
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        viewModel.load()
        #expect(viewModel.delete())

        let wishlist = try context.fetch(FetchDescriptor<WishlistItem>())
        #expect(wishlist.count == 1)
        #expect(wishlist.first?.plannedSaleItems?.isEmpty == true)
    }

    @Test func loadAfterDeleteFindsNothing() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(item)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        viewModel.load()
        #expect(viewModel.delete())

        viewModel.load()
        #expect(viewModel.item == nil)
    }

    // MARK: - Display

    /// `ItemDetailView` sorted its photos inline until this moved here, which
    /// left the same rule in two places — the shape of bug that already bit
    /// this build twice (`matchesPrefix` serving filtering, `allCategoryPaths`
    /// serving filter chips). The relationship comes back unordered from
    /// SwiftData, so an unsorted carousel shows a different lead photo between
    /// launches.
    @Test func photosComeBackInTheUsersOwnOrder() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        context.insert(item)
        let first = Photo(imageData: Data([0x01]), sortOrder: 0)
        let second = Photo(imageData: Data([0x02]), sortOrder: 1)
        let third = Photo(imageData: Data([0x03]), sortOrder: 2)
        context.insert(first)
        context.insert(second)
        context.insert(third)
        // Deliberately attached out of order.
        item.photos = [third, first, second]
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        viewModel.load()

        #expect(viewModel.photos.map(\.sortOrder) == [0, 1, 2])
        #expect(viewModel.photos.map(\.imageData) == [Data([0x01]), Data([0x02]), Data([0x03])])
    }

    @Test func photosAreEmptyWhenNothingIsLoaded() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemDetailViewModel(modelContext: context, itemID: UUID())

        #expect(viewModel.photos.isEmpty)
        viewModel.load()
        #expect(viewModel.photos.isEmpty)
    }

    /// Both detail screens have to answer this the same way, since they're the
    /// same rule — which is the point of it living in a view model at all.
    @Test func bothDetailScreensOrderPhotosAlike() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        let wanted = WishlistItem(name: "Summicron 35mm f/2", categoryPath: "Photography/Lenses")
        context.insert(item)
        context.insert(wanted)

        for parent in 0..<2 {
            let photos = (0..<3).map { Photo(imageData: Data([UInt8($0)]), sortOrder: 2 - $0) }
            photos.forEach(context.insert)
            if parent == 0 { item.photos = photos } else { wanted.photos = photos }
        }
        try context.save()

        let itemModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        let wishlistModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        itemModel.load()
        wishlistModel.load()

        #expect(itemModel.photos.map(\.sortOrder) == [0, 1, 2])
        #expect(wishlistModel.photos.map(\.sortOrder) == [0, 1, 2])
        #expect(itemModel.photos.map(\.imageData) == wishlistModel.photos.map(\.imageData))
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

    @Test func deleteClearsTheItemsMarketRowsInTheSameSave() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let doomed = Item(name: "Telecaster", reverbProductID: 126_161)
        let kept = Item(name: "Stratocaster", reverbProductID: 160_322)
        context.insert(doomed); context.insert(kept)
        try seedMarketRows(for: doomed.id, in: context)
        try seedMarketRows(for: kept.id, in: context)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: doomed.id)
        viewModel.load()
        #expect(viewModel.delete())

        #expect(!(try marketRowsRemain(for: doomed.id, in: container)), "the deleted item's market rows survived it")
        #expect(try marketRowsRemain(for: kept.id, in: container), "another item's rows went too")
    }

}

// MARK: - 002/T009: the Market section

/// The owned detail view model's market state and intents (plan §6).
/// Every fetch goes through a spy — nothing here opens a connection — and
/// every persistence claim is read on a **second context**, since a
/// same-context refetch hands back unsaved changes and would pass whether
/// or not the intent saved.
@Suite("ItemDetailViewModel — market")
struct ItemDetailViewModelMarketTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let minute: TimeInterval = 60
    private let day: TimeInterval = 24 * 60 * 60

    private let catalogProduct = MarketProduct(
        id: 126_161,
        slug: "fender-american-professional-ii-telecaster",
        title: "Fender American Professional II Telecaster",
        usedLowCents: 100_000,
        usedTotal: 108,
        listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
    )

    private func candidate(
        id: Int = 126_161,
        slug: String = "fender-american-professional-ii-telecaster",
        title: String = "Fender American Professional II Telecaster"
    ) -> MarketCandidate {
        MarketCandidate(id: id, slug: slug, title: title, brand: "Fender", imageURL: nil, usedLowCents: 100_000, usedTotal: 108)
    }

    private struct World {
        let container: ModelContainer
        let context: ModelContext
        let item: Item
    }

    private func world(productID: Int? = 126_161, condition: Condition = .excellent, year: Int? = nil) throws -> World {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster", condition: condition, reverbProductID: productID, year: year)
        context.insert(item)
        try context.save()
        return World(container: container, context: context, item: item)
    }

    /// One stored figure, through the store's own writer — a median makes a
    /// history point, `nil` is a withheld reading and makes none.
    private func seed(median: Int?, at fetchedAt: Date, in world: World, product: MarketProduct? = nil) throws {
        let reading: MarketReading = median.map {
            .figure(MarketFigure(medianCents: $0, lowCents: $0 - 10_000, highCents: $0 + 10_000, count: 12, fetchedAt: fetchedAt, isTruncated: false, yearScope: .any))
        } ?? .withheld(count: 1, usedLowCents: 100_000, fetchedAt: fetchedAt, yearScope: .any)
        try MarketLocalStore.record(reading, product: product ?? catalogProduct, for: MarketSubjectKey(subjectID: world.item.id, kind: .owned), in: world.context)
        try world.context.save()
    }

    private func viewModel(_ world: World, now: Date? = nil, service: (any MarketService)? = nil) -> ItemDetailViewModel {
        let clock = now ?? t0
        return ItemDetailViewModel(modelContext: world.context, itemID: world.item.id, marketService: service ?? MarketServiceSpy(), now: { clock })
    }

    private func loaded(_ world: World, now: Date? = nil, service: (any MarketService)? = nil) -> ItemDetailViewModel {
        let viewModel = viewModel(world, now: now, service: service)
        viewModel.load()
        return viewModel
    }

    private func display(of world: World, now: Date? = nil) throws -> MarketMatchDisplay {
        let state = loaded(world, now: now).marketState
        guard case .matched(let display) = state else { throw TestFailure("expected a match, got \(state)") }
        return display
    }

    private func storedItem(_ id: UUID, in container: ModelContainer) throws -> Item {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let item = try context.fetch(descriptor).first else { throw TestFailure("the item is gone") }
        return item
    }

    private func fixtureProduct() throws -> MarketProduct {
        try ReverbDecoding.product(from: try reverbFixture("csp-126161.json"))
    }

    private func fixtureListings() throws -> MarketListings {
        var all: [MarketListing] = []
        for page in 1...7 { all += try ReverbDecoding.page(from: try reverbFixture("listings-126161-p\(page).json")).listings }
        return MarketListings(listings: all, reportedTotal: 337, isTruncated: false)
    }

    // MARK: - The state table

    /// The eight rows the section draws, each read through the view model
    /// rather than the pure function, so the store→reading mapping is
    /// covered too.
    @Test func marketStateResolvesEveryRowOfTheTable() throws {
        // 1 — unmatched: rows a previous match left behind are not a state.
        let unmatched = try world(productID: nil)
        try seed(median: 140_000, at: t0, in: unmatched)
        #expect(loaded(unmatched).marketState == .unmatched)

        // 2 — matched, nothing fetched here, no snapshot: no title, no link.
        let bare = try world()
        let bareDisplay = try display(of: bare)
        #expect(bareDisplay.reading == .none)
        #expect(bareDisplay.title == nil)
        #expect(bareDisplay.webURL == nil)

        // 3 — the pick, before any refresh (Decision 20): the snapshot's
        // title and the link back, with no figure.
        let picked = try world()
        try MarketLocalStore.recordMatch(candidate(), for: picked.item.id, at: t0, in: picked.context)
        try picked.context.save()
        let pickedDisplay = try display(of: picked)
        #expect(pickedDisplay.reading == .none)
        #expect(pickedDisplay.title == "Fender American Professional II Telecaster")
        #expect(pickedDisplay.webURL == URL(string: "https://reverb.com/p/fender-american-professional-ii-telecaster"))

        // 4 — a fresh median reads current.
        let matched = try world()
        try seed(median: 140_000, at: t0, in: matched)
        let currentDisplay = try display(of: matched, now: t0.addingTimeInterval(2 * 60 * minute))
        guard case .current(let figure) = currentDisplay.reading else { throw TestFailure("\(currentDisplay.reading)") }
        #expect(figure.medianCents == 140_000)

        // 5 — a second short of thirty days is still current (the boundary).
        let boundary = try display(of: matched, now: t0.addingTimeInterval(30 * day - 1))
        guard case .current = boundary.reading else { throw TestFailure("\(boundary.reading)") }

        // 6 — thirty days on, the figure is not carried (Decision 21).
        let stale = try display(of: matched, now: t0.addingTimeInterval(30 * day))
        #expect(stale.reading == .stale(fetchedAt: t0))

        // 7 — a fresh withheld reading keeps its row (no median to show).
        let withheldWorld = try world()
        try seed(median: nil, at: t0, in: withheldWorld)
        let withheld = try display(of: withheldWorld, now: t0.addingTimeInterval(minute))
        guard case .withheld(let value) = withheld.reading else { throw TestFailure("\(withheld.reading)") }
        #expect(value.medianCents == nil)

        // 8 — an old withheld reading is stale, not withheld: staleness is
        // checked first, because its catalog price is thirty days old too.
        let staleWithheld = try display(of: withheldWorld, now: t0.addingTimeInterval(31 * day))
        #expect(staleWithheld.reading == .stale(fetchedAt: t0))
    }

    // MARK: - Nothing fetches itself (criterion 9)

    @Test func loadNeverFetches() async throws {
        let world = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-3 * day), in: world)
        let spy = MarketServiceSpy()
        let viewModel = viewModel(world, service: spy)

        viewModel.load()
        // A refresh spawned from `load()` would reach the spy across a
        // suspension, so give it every chance to: the assertion below is
        // about the mechanism, not about what a single frame shows.
        for _ in 0..<200 { await Task.yield() }

        #expect(spy.calls.isEmpty, "load() reached Reverb")
        #expect(viewModel.marketNotice == nil, "load() ran a refresh and mapped its outcome")
        #expect(viewModel.canRefresh, "a three-day-old figure is due — otherwise the guard, not load(), is what kept it quiet")
    }

    @Test func refreshWithinTheHourIsSkipped() async throws {
        let world = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-59 * minute), in: world)
        let spy = MarketServiceSpy()
        let viewModel = loaded(world, service: spy)

        #expect(!viewModel.canRefresh, "Refresh is offered within the hour (Q8)")
        await viewModel.refresh()

        #expect(spy.calls.isEmpty)
        #expect(viewModel.marketNotice == nil)

        // At the hour it is offered again — and the refresher agrees, since
        // both read `MarketRefresher.freshnessWindow`. Asserting `canRefresh`
        // alone would pass just as well if the two compared it differently
        // and the fetch were skipped behind an enabled button.
        let atTheHour = loaded(world, now: t0.addingTimeInterval(minute), service: spy)
        #expect(atTheHour.canRefresh)
        await atTheHour.refresh()
        #expect(spy.calls == [.product(126_161)], "the refresher skipped the fetch the button offered")
    }

    // MARK: - Every outcome's notice (plan §6)

    /// The whole of `MarketNotice.notice(for:lastFetchedAt:)`, not the four
    /// arms the refresh tests happen to walk: a re-pointed arm turns a row
    /// red here. It does *not* catch a new `Outcome` case — this table is a
    /// hand-written array, so a new case plus a new production arm passes
    /// with no coverage at all. What guards that is the production `switch`
    /// having no `default:`: a case added there fails to compile until every
    /// mapping is written, and a case deleted breaks its arm the same way —
    /// but neither of those adds a row to this table.
    @Test(arguments: OutcomeNoticeCase.all)
    func everyRefreshOutcomeMapsToItsNotice(outcomeCase: OutcomeNoticeCase) {
        let notice = MarketNotice.notice(for: outcomeCase.outcome, lastFetchedAt: OutcomeNoticeCase.lastFetchedAt)
        #expect(notice == outcomeCase.expected)
    }

    /// The unreachable line dates itself by whatever was last fetched, and
    /// says nothing when nothing was.
    @Test func theUnreachableNoticeCarriesWhateverDateItIsGiven() {
        #expect(MarketNotice.notice(for: .failed(.unreachable), lastFetchedAt: nil) == .unreachable(lastFetchedAt: nil))
    }

    // MARK: - Refreshing

    @Test func aRefreshIsObservableMidFlightAndASecondTapIsRefused() async throws {
        let world = try world()
        let gated = GatedMarketServiceSpy(product: .success(try fixtureProduct()), listings: .success(try fixtureListings()))
        let viewModel = loaded(world, service: gated)
        #expect(viewModel.canRefresh)

        let task = Task { await viewModel.refresh() }
        // Bounded: a refresh that never reaches the spy turns the require
        // below red instead of spinning the suite forever.
        var yields = 0
        while gated.listingsCalls == 0 && yields < 10_000 {
            await Task.yield()
            yields += 1
        }
        try #require(gated.listingsCalls == 1)

        #expect(viewModel.marketActivity == .refreshing)
        #expect(!viewModel.canRefresh, "a refresh in flight offered another")
        #expect(!viewModel.canAdopt, "a figure was adoptable mid-refresh")
        await viewModel.refresh()
        gated.release()
        await task.value

        #expect(gated.listingsCalls == 1, "the reentrant refresh reached Reverb")
        #expect(viewModel.marketActivity == nil)
        #expect(viewModel.marketNotice == nil)
        guard case .matched(let display) = viewModel.marketState, case .current(let figure) = display.reading else {
            throw TestFailure("\(viewModel.marketState)")
        }
        #expect(figure.medianCents == 139_999)
    }

    @Test func unreachableKeepsTheFigureAndSaysWhy() async throws {
        let world = try world()
        let fetchedAt = t0.addingTimeInterval(-2 * 60 * minute)
        try seed(median: 140_000, at: fetchedAt, in: world)
        let viewModel = loaded(world, service: MarketServiceSpy(products: [.failure(.unreachable)]))

        await viewModel.refresh()

        #expect(viewModel.marketNotice == .unreachable(lastFetchedAt: fetchedAt))
        #expect(viewModel.marketActivity == nil)
        guard case .matched(let display) = viewModel.marketState, case .current(let figure) = display.reading else {
            throw TestFailure("\(viewModel.marketState)")
        }
        #expect(figure.medianCents == 140_000, "the last figure was cleared by a failure (P8)")
        #expect(figure.fetchedAt == fetchedAt)
    }

    /// The other half of the same rule: a stale reading shows no figure, so
    /// the line has nothing to stand over and carries no date (plan §6) —
    /// it reads "Couldn't reach Reverb." rather than dating a figure the
    /// person cannot see. Passing `marketState.lastFetchedAt` here instead
    /// would hand over the stale row's date and turn this red.
    @Test func unreachableOverAStaleReadingCarriesNoDate() async throws {
        let world = try world()
        try seed(median: 140_000, at: t0, in: world)
        let viewModel = loaded(world, now: t0.addingTimeInterval(31 * day), service: MarketServiceSpy(products: [.failure(.unreachable)]))
        guard case .matched(let before) = viewModel.marketState, case .stale = before.reading else {
            throw TestFailure("expected a stale reading before the refresh, got \(viewModel.marketState)")
        }

        await viewModel.refresh()

        #expect(viewModel.marketNotice == .unreachable(lastFetchedAt: nil))
        guard case .matched(let after) = viewModel.marketState else { throw TestFailure("\(viewModel.marketState)") }
        #expect(after.reading == .stale(fetchedAt: t0), "the failure disturbed the reading (P8)")
    }

    @Test func theRateLimitSaysSoAndKeepsTheFigure() async throws {
        let world = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-2 * 60 * minute), in: world)
        let viewModel = loaded(world, service: MarketServiceSpy(products: [.failure(.rateLimited)]))

        await viewModel.refresh()

        #expect(viewModel.marketNotice == .rateLimited)
        guard case .matched(let display) = viewModel.marketState, case .current(let figure) = display.reading else {
            throw TestFailure("\(viewModel.marketState)")
        }
        #expect(figure.medianCents == 140_000)
    }

    /// Q3: the product is gone from Reverb, the match is not.
    @Test func productGoneKeepsTheMatch() async throws {
        let world = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-2 * 60 * minute), in: world)
        let viewModel = loaded(world, service: MarketServiceSpy(products: [.failure(.productNotFound)]))

        await viewModel.refresh()

        #expect(viewModel.marketNotice == .productGone)
        guard case .matched(let display) = viewModel.marketState, case .current(let figure) = display.reading else {
            throw TestFailure("\(viewModel.marketState)")
        }
        #expect(figure.medianCents == 140_000)
        #expect(try storedItem(world.item.id, in: world.container).reverbProductID == 126_161)
    }

    // MARK: - Use as my value (criterion 8, Q15)

    /// The amount reaches the store whole, whatever it is handed: the value
    /// step rounds its default and every move already (T021), and this is
    /// the same rule one level out, for any caller of the intent.
    @Test func adoptWritesAWholeAmount() throws {
        let world = try world()
        try seed(median: 139_950, at: t0.addingTimeInterval(-minute), in: world)
        let before = world.item.updatedAt
        let adoptedAt = t0.addingTimeInterval(day)
        let viewModel = loaded(world, now: adoptedAt)

        #expect(viewModel.canAdopt)
        #expect(viewModel.adopt(cents: 139_950))
        #expect(viewModel.adoptFailureMessage == nil)
        #expect(!world.context.hasChanges, "adopt left unsaved changes behind")

        let stored = try storedItem(world.item.id, in: world.container)
        let written = try #require(stored.currentValueCents)
        // The cents themselves, not the formatted line: two amounts a
        // display formatter rounds alike are not the same amount, and the
        // rounding this test is about is the one the store keeps.
        #expect(written == 140_000, "adopt wrote unrounded cents to the item's value")
        #expect(stored.updatedAt == adoptedAt, "P6: adopting marks the item edited")
        #expect(stored.updatedAt != before)
    }

    /// Decision 35, and criterion 8's second half: the market's record of
    /// itself is untouched by what anyone adopts, and adopting reaches
    /// nothing.
    @Test func adoptStillWritesNoHistoryAndFetchesNothing() throws {
        let world = try world()
        try seed(median: 139_950, at: t0.addingTimeInterval(-minute), in: world)
        let spy = MarketServiceSpy()
        let viewModel = loaded(world, now: t0.addingTimeInterval(day), service: spy)

        #expect(viewModel.adopt(cents: 139_950))

        let elsewhere = ModelContext(world.container)
        #expect(try MarketLocalStore.history(for: world.item.id, in: elsewhere).count == 1, "adopt wrote to the history")
        let figure = try #require(try MarketLocalStore.figure(for: world.item.id, in: elsewhere))
        #expect(figure.medianCents == 139_950, "adopt changed the stored figure")
        #expect(spy.calls.isEmpty, "adopt reached Reverb")
    }

    @Test func adoptRefusesAWithheldOrStaleReading() throws {
        let withheld = try world()
        try seed(median: nil, at: t0, in: withheld)
        let a = loaded(withheld, now: t0.addingTimeInterval(minute))
        #expect(!a.canAdopt)
        #expect(!a.adopt(cents: 140_000))
        #expect(try storedItem(withheld.item.id, in: withheld.container).currentValueCents == nil)

        let stale = try world()
        try seed(median: 140_000, at: t0, in: stale)
        let b = loaded(stale, now: t0.addingTimeInterval(31 * day))
        #expect(!b.canAdopt)
        #expect(!b.adopt(cents: 140_000))
        #expect(try storedItem(stale.item.id, in: stale.container).currentValueCents == nil)
    }

    // MARK: - Matching, changing, unmatching

    @Test func removeMatchClearsTheItemAndTheStoreInOneSave() throws {
        let world = try world()
        try seed(median: 140_000, at: t0, in: world)
        let removedAt = t0.addingTimeInterval(day)
        let viewModel = loaded(world, now: removedAt)

        viewModel.removeMatch()

        #expect(!world.context.hasChanges, "removeMatch left unsaved changes behind")
        #expect(viewModel.marketState == .unmatched)
        let stored = try storedItem(world.item.id, in: world.container)
        #expect(stored.reverbProductID == nil)
        #expect(stored.updatedAt == removedAt)

        let elsewhere = ModelContext(world.container)
        let figure = try MarketLocalStore.figure(for: world.item.id, in: elsewhere)
        let snapshot = try MarketLocalStore.snapshot(for: world.item.id, in: elsewhere)
        let history = try MarketLocalStore.history(for: world.item.id, in: elsewhere)
        #expect(figure == nil)
        #expect(snapshot == nil)
        #expect(history.isEmpty)
    }

    /// Decision 26: a different product's figure describes something else.
    ///
    /// The figure is seeded five minutes old, so the re-pick's own refresh
    /// (Decision 33) is skipped as still fresh and the pick under test is
    /// the only thing moving.
    @Test func setMatchToADifferentProductClearsHistoryButTheSameProductDoesNot() async throws {
        let world = try world()
        let matchedAt = t0.addingTimeInterval(day)
        try seed(median: 140_000, at: matchedAt.addingTimeInterval(-5 * minute), in: world)
        let viewModel = loaded(world, now: matchedAt)
        openThePicker(viewModel)

        await viewModel.setMatch(candidate())

        let same = ModelContext(world.container)
        let keptFigure = try MarketLocalStore.figure(for: world.item.id, in: same)
        let keptHistory = try MarketLocalStore.history(for: world.item.id, in: same)
        #expect(keptFigure?.medianCents == 140_000, "re-picking the same product cleared its figure")
        #expect(keptHistory.count == 1, "re-picking the same product cleared its history")
        // Amendment B's landing rule, not the old "a pick always closes the
        // sheet": a figure still in hand hands the sheet to the value step.
        #expect(viewModel.isFindingMatch, "the pick closed the sheet over a figure it could adopt")
        guard case .value = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }

        openThePicker(viewModel)
        await viewModel.setMatch(candidate(id: 182_769, slug: "martin-d-18", title: "Martin D-18"))

        #expect(!world.context.hasChanges, "setMatch left unsaved changes behind")
        let elsewhere = ModelContext(world.container)
        let figure = try MarketLocalStore.figure(for: world.item.id, in: elsewhere)
        let history = try MarketLocalStore.history(for: world.item.id, in: elsewhere)
        #expect(figure == nil, "the old product's figure survived a change of match")
        #expect(history.isEmpty, "the old product's history survived a change of match")
        let snapshot = try #require(try MarketLocalStore.snapshot(for: world.item.id, in: elsewhere))
        #expect(snapshot.productID == 182_769)
        #expect(snapshot.title == "Martin D-18")
        let stored = try storedItem(world.item.id, in: world.container)
        #expect(stored.reverbProductID == 182_769)
        #expect(stored.updatedAt == matchedAt)

        guard case .matched(let display) = viewModel.marketState else { throw TestFailure("\(viewModel.marketState)") }
        #expect(display.reading == .none)
        #expect(display.title == "Martin D-18")
    }

    /// The deviation recorded in plan §6: an unreachable or product-gone
    /// line describes a match that a change or an unmatch has just ended,
    /// so it goes with it.
    ///
    /// The change is watched **mid-fetch**, which is the only place the rule
    /// is visible since Amendment B: the pick's own refresh maps its outcome
    /// onto the notice when it lands, so an end-state assertion would pass
    /// just as well with the clearing deleted. The gate on every listings
    /// call is what lets the second fetch be the one held open.
    @Test func changingOrRemovingTheMatchClearsTheNotice() async throws {
        let changing = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-2 * 60 * minute), in: changing)
        let gated = GatedMarketServiceSpy(
            product: .success(try fixtureProduct()),
            listings: .failure(.rateLimited),
            gatesEveryListingsCall: true
        )
        let afterChange = loaded(changing, service: gated)

        let refreshing = Task { await afterChange.refresh() }
        // Named, not plain `release()`: this spy gates every listings call,
        // and a keyed release banks a credit if it gets there first, so it
        // can't depend on how far the fetch has run (T022's fourth review).
        gated.release(listingsCall: 1)
        await refreshing.value
        #expect(afterChange.marketNotice == .rateLimited, "the failing refresh left no notice to clear")

        openThePicker(afterChange)
        let picking = Task { await afterChange.setMatch(candidate(id: 182_769, slug: "martin-d-18", title: "Martin D-18")) }
        try await waitForListingsCall(2, on: gated)
        #expect(afterChange.marketNotice == nil, "a change of match kept the old match's notice")
        gated.release(listingsCall: 2)
        await picking.value

        let removing = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-2 * 60 * minute), in: removing)
        let afterRemove = loaded(removing, service: MarketServiceSpy(products: [.failure(.unreachable)]))
        await afterRemove.refresh()
        #expect(afterRemove.marketNotice != nil, "the failing refresh left no notice to clear")

        afterRemove.removeMatch()
        #expect(afterRemove.marketNotice == nil, "an unmatch kept the notice for a match that is gone")
    }

    // MARK: - The one-time notice (Decision 14, Q5)

    @Test func theNoticeShowsOnceAndOnlyContinuePutsItAway() throws {
        let world = try world(productID: nil)
        let spy = MarketServiceSpy()
        let viewModel = loaded(world, service: spy)

        viewModel.findMatch()
        #expect(viewModel.sheetStep == .notice)
        #expect(viewModel.isFindingMatch)
        #expect(spy.calls.isEmpty, "opening the sheet reached Reverb")

        viewModel.declineNotice()
        #expect(!viewModel.isFindingMatch)
        #expect(viewModel.sheetStep == .pick)
        #expect(!MarketLocalStore.hasAcknowledgedNotice(in: ModelContext(world.container)), "Not now acknowledged the notice (Q5)")
        #expect(spy.calls.isEmpty, "Not now searched Reverb")

        viewModel.findMatch()
        #expect(viewModel.sheetStep == .notice, "Not now should leave the notice to come back")

        viewModel.continueFromNotice()
        #expect(viewModel.sheetStep == .pick, "Continue didn't hand the sheet to the picker")
        #expect(viewModel.isFindingMatch, "Continue closed the sheet instead of handing it to the picker")
        #expect(MarketLocalStore.hasAcknowledgedNotice(in: ModelContext(world.container)), "Continue didn't reach the store")

        // The flag is the device's, not the screen's: a fresh view model over
        // the same container never shows the notice again.
        let next = ItemDetailViewModel(modelContext: ModelContext(world.container), itemID: world.item.id, marketService: spy, now: { self.t0 })
        next.load()
        next.findMatch()
        #expect(next.sheetStep == .pick, "the notice came back on a new view model")
    }


    // MARK: - The pick's refresh and the value step (Decisions 33–35, B3)

    /// Criterion 23's first half: the pick fetches that product at once, in
    /// the same sheet, and hands the sheet to the value step at the
    /// whole-currency median.
    @Test func setMatchRefreshesAndOpensTheValueStep() async throws {
        let world = try world()
        let gated = GatedMarketServiceSpy(product: .success(try fixtureProduct()), listings: .success(try fixtureListings()))
        let viewModel = loaded(world, service: gated)
        openThePicker(viewModel)

        let task = Task { await viewModel.setMatch(candidate()) }
        try await waitForListingsCall(1, on: gated)

        #expect(viewModel.marketActivity == .refreshing, "the pick's fetch doesn't read as activity")
        #expect(
            viewModel.sheetStep == .fetching(candidate(), token: 1),
            "the sheet doesn't hold the candidate and token it is fetching"
        )
        #expect(!viewModel.canRefresh, "a second refresh could start under the sheet")
        #expect(!viewModel.canAdopt, "a figure was adoptable mid-fetch")
        gated.release()
        await task.value

        #expect(
            gated.calls == [.product(126_161), .listings(productID: 126_161)],
            "the pick's fetch was \(gated.calls)"
        )
        #expect(viewModel.marketActivity == nil)
        #expect(viewModel.marketNotice == nil)
        #expect(viewModel.isFindingMatch, "the sheet closed instead of showing the value step")
        guard case .value(let step) = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }
        #expect(step.medianCents == 139_999)
        #expect(step.chosenCents == 140_000, "the step didn't default to the whole-currency median")
        #expect(step.chosenCents == MarketAdoption.wholeCurrencyCents(from: 139_999))
        #expect(step.lowerCents == 120_000, "the slider's ends aren't the trimmed bounds")
        #expect(step.upperCents == 169_900)

        // The refresh a pick runs is a refresh: read on a second context.
        let elsewhere = ModelContext(world.container)
        let figure = try #require(try MarketLocalStore.figure(for: world.item.id, in: elsewhere))
        #expect(figure.medianCents == 139_999)
        #expect(try MarketLocalStore.history(for: world.item.id, in: elsewhere).count == 1)
        let snapshot = try #require(try MarketLocalStore.snapshot(for: world.item.id, in: elsewhere))
        #expect(snapshot.productID == 126_161)
    }

    /// Decision 33 and P7: a re-pick of a product refreshed within the hour
    /// sends nothing and goes straight to the value step.
    @Test func aFreshRePickSkipsTheFetch() async throws {
        let world = try world()
        let pickedAt = t0.addingTimeInterval(day)
        try seed(median: 140_000, at: pickedAt.addingTimeInterval(-5 * minute), in: world)
        let spy = MarketServiceSpy()
        let viewModel = loaded(world, now: pickedAt, service: spy)
        openThePicker(viewModel)

        await viewModel.setMatch(candidate())

        #expect(spy.calls.isEmpty, "a figure five minutes old was fetched again (P7)")
        #expect(viewModel.marketNotice == nil, "a skipped fetch read as a failure")
        #expect(viewModel.isFindingMatch)
        guard case .value(let step) = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }
        #expect(step.chosenCents == 140_000)
    }

    /// Decision 34: a withheld reading offers no value step, so the sheet
    /// closes to the section — which says what it says today.
    @Test func aWithheldPickClosesToTheSection() async throws {
        let world = try world()
        let spy = MarketServiceSpy(
            products: [.success(try fixtureProduct())],
            listings: [.success(MarketListings(listings: [], reportedTotal: 0, isTruncated: false))]
        )
        let viewModel = loaded(world, service: spy)
        openThePicker(viewModel)

        await viewModel.setMatch(candidate())

        #expect(!viewModel.isFindingMatch, "a withheld reading opened the value step")
        #expect(viewModel.sheetStep == .pick)
        #expect(viewModel.marketNotice == nil, "a refresh that landed reported a failure")
        #expect(!viewModel.canAdopt)
        guard case .matched(let display) = viewModel.marketState, case .withheld = display.reading else {
            throw TestFailure("\(viewModel.marketState)")
        }
    }

    /// Decision 33's last sentence: the refresh failed, the sheet closes to
    /// the section, the match stands. The line carries no date — the state
    /// it reads is the one the save left behind, and a changed product's
    /// figure went with the product.
    @Test func aFailedPickClosesWithTheNotice() async throws {
        let world = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-2 * 60 * minute), in: world)
        let viewModel = loaded(world, service: MarketServiceSpy(products: [.failure(.unreachable)]))
        openThePicker(viewModel)

        await viewModel.setMatch(candidate(id: 182_769, slug: "martin-d-18", title: "Martin D-18"))

        #expect(!viewModel.isFindingMatch, "the sheet stayed open over a failed pick")
        #expect(viewModel.sheetStep == .pick)
        #expect(viewModel.marketNotice == .unreachable(lastFetchedAt: nil), "the failure was dated by a figure that is gone")
        #expect(try storedItem(world.item.id, in: world.container).reverbProductID == 182_769, "the failure took the match with it")
        guard case .matched(let display) = viewModel.marketState else { throw TestFailure("\(viewModel.marketState)") }
        #expect(display.title == "Martin D-18")
        #expect(display.reading == .none)
    }

    /// The landing rule's other half: an outcome that arrives after the
    /// person swiped the fetching sheet away updates the section and the
    /// notice and never re-presents the sheet.
    @Test func aDismissedFetchLandsQuietly() async throws {
        let world = try world()
        let gated = GatedMarketServiceSpy(product: .success(try fixtureProduct()), listings: .success(try fixtureListings()))
        let viewModel = loaded(world, service: gated)
        openThePicker(viewModel)

        let task = Task { await viewModel.setMatch(candidate()) }
        try await waitForListingsCall(1, on: gated)
        // The swipe-down: the sheet's `isPresented` binding writes the flag
        // back itself, exactly as the view does.
        viewModel.isFindingMatch = false
        gated.release()
        await task.value

        #expect(!viewModel.isFindingMatch, "the outcome re-presented a sheet the person had dismissed")
        if case .value = viewModel.sheetStep { Issue.record("the sheet landed on the value step after a dismissal") }
        #expect(viewModel.marketNotice == nil)
        #expect(viewModel.canAdopt, "the figure that landed isn't offered by the section")
        guard case .matched(let display) = viewModel.marketState, case .current(let figure) = display.reading else {
            throw TestFailure("\(viewModel.marketState)")
        }
        #expect(figure.medianCents == 139_999, "the section didn't take the outcome that landed")
    }

    /// Two quick taps on candidate cards are one save and one request: the
    /// second pick is dropped while the first is fetching.
    @Test func aSecondPickDuringTheFetchIsIgnored() async throws {
        let world = try world()
        let gated = GatedMarketServiceSpy(product: .success(try fixtureProduct()), listings: .success(try fixtureListings()))
        let viewModel = loaded(world, service: gated)
        openThePicker(viewModel)

        let first = Task { await viewModel.setMatch(candidate()) }
        try await waitForListingsCall(1, on: gated)
        await viewModel.setMatch(candidate(id: 182_769, slug: "martin-d-18", title: "Martin D-18"))
        gated.release()
        await first.value

        #expect(gated.listingsCalls == 1, "the second pick reached Reverb")
        #expect(
            gated.calls == [.product(126_161), .listings(productID: 126_161)],
            "the second pick fetched something of its own: \(gated.calls)"
        )
        #expect(try storedItem(world.item.id, in: world.container).reverbProductID == 126_161, "the second pick was saved")
        let elsewhere = ModelContext(world.container)
        let snapshot = try #require(try MarketLocalStore.snapshot(for: world.item.id, in: elsewhere))
        #expect(snapshot.productID == 126_161, "the second pick wrote its own snapshot")
        guard case .value = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }
    }

    /// The landing rule names *this fetch's* presentation, not merely "a
    /// sheet is up". A person who swipes the fetching sheet away and then
    /// re-opens Change match… is standing in a picker the earlier fetch has
    /// no claim on: it may neither replace it with a value step for the
    /// candidate they walked away from, nor close it under them.
    @Test func aReopenedPickerIsNotHijackedByAnEarlierFetch() async throws {
        let world = try world()
        let gated = GatedMarketServiceSpy(product: .success(try fixtureProduct()), listings: .success(try fixtureListings()))
        let viewModel = loaded(world, service: gated)
        openThePicker(viewModel)

        let task = Task { await viewModel.setMatch(candidate()) }
        try await waitForListingsCall(1, on: gated)
        // The swipe-down, then Change match… again while the first fetch is
        // still in flight — a sheet is presented, and it is the picker's.
        viewModel.isFindingMatch = false
        viewModel.findMatch()
        #expect(viewModel.sheetStep == .pick, "the re-opened sheet isn't the picker")
        #expect(viewModel.isFindingMatch)

        gated.release()
        await task.value

        #expect(viewModel.sheetStep == .pick, "the earlier fetch took over the picker the person re-opened")
        #expect(viewModel.isFindingMatch, "the earlier fetch closed the picker the person re-opened")
        // The outcome still landed, in the section behind the sheet.
        #expect(viewModel.canAdopt, "the figure that landed isn't offered by the section")
    }

    /// The token, not the candidate (T022's second review). A person who
    /// swipes the fetching sheet away, re-opens Change match… and picks
    /// something else is standing in the *second* pick's fetch; the first,
    /// landing late, has no claim on it and must leave it exactly as it is.
    @Test func aSecondPickAfterAReopenIsNotDisturbedByTheFirstFetch() async throws {
        let world = try world()
        let gated = GatedMarketServiceSpy(
            product: .success(try fixtureProduct()),
            listings: .success(try fixtureListings()),
            gatesEveryListingsCall: true
        )
        let viewModel = loaded(world, service: gated)
        openThePicker(viewModel)

        let a = candidate()
        let b = candidate(id: 182_769, slug: "martin-d-18", title: "Martin D-18")
        let first = Task { await viewModel.setMatch(a) }
        try await waitForListingsCall(1, on: gated)

        // The swipe-down, Change match… again, and a second pick — all while
        // the first fetch is still gated.
        viewModel.isFindingMatch = false
        viewModel.findMatch()
        let second = Task { await viewModel.setMatch(b) }
        try await waitForListingsCall(2, on: gated)
        #expect(viewModel.sheetStep == .fetching(b, token: 2), "the second pick isn't the sheet's own fetch")

        gated.release(listingsCall: 1)
        await first.value

        #expect(viewModel.sheetStep == .fetching(b, token: 2), "the first fetch moved the second's sheet")
        #expect(viewModel.isFindingMatch, "the first fetch closed the second's sheet")

        gated.release(listingsCall: 2)
        await second.value
        #expect(viewModel.isFindingMatch, "the second fetch closed its own sheet")
        guard case .value = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }
    }

    /// The same question with the candidates equal, which is where candidate
    /// equality and fetch identity part company: re-picking the *same*
    /// product after a swipe-down is a second fetch, and the first landing
    /// must not hand the second's sheet to the value step behind its back.
    @Test func aRePickOfTheSameProductIsASecondFetch() async throws {
        let world = try world()
        // The older fetch fails, so its landing has something to write:
        // the generation rule is what stops it (T022's third review).
        let gated = GatedMarketServiceSpy(
            product: .success(try fixtureProduct()),
            listingsScript: [.failure(.unreachable), .success(try fixtureListings())],
            gatesEveryListingsCall: true
        )
        let viewModel = loaded(world, service: gated)
        openThePicker(viewModel)

        let first = Task { await viewModel.setMatch(candidate()) }
        try await waitForListingsCall(1, on: gated)

        viewModel.isFindingMatch = false
        viewModel.findMatch()
        let second = Task { await viewModel.setMatch(candidate()) }
        try await waitForListingsCall(2, on: gated)
        #expect(viewModel.sheetStep == .fetching(candidate(), token: 2), "the re-pick isn't a fetch of its own")

        gated.release(listingsCall: 1)
        await first.value

        #expect(
            viewModel.sheetStep == .fetching(candidate(), token: 2),
            "the first fetch took over the second's sheet because the candidate matched"
        )
        #expect(viewModel.isFindingMatch)
        // The older landing speaks for nothing: the second fetch is still
        // running, so the section stays busy and its failure goes unwritten.
        #expect(viewModel.marketActivity == .refreshing, "the older fetch cleared the flag the newer one still holds")
        #expect(!viewModel.canRefresh, "the older fetch re-enabled Refresh under the running one")
        #expect(!viewModel.canAdopt, "the older fetch re-enabled the adopt button under the running one")
        #expect(viewModel.marketNotice == nil, "the older fetch painted its failure over the newer one's sheet")

        gated.release(listingsCall: 2)
        await second.value
        guard case .value = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }
    }

    /// **The generation rule** (plan Amendment B): the section's own Refresh
    /// is in flight when a pick starts a newer fetch. The pick lands first
    /// and speaks for the section; the older refresh then fails, and may
    /// neither paint its failure line over the match that replaced it nor
    /// clear the activity flag the newer fetch had already cleared.
    @Test func anOlderRefreshLandingAfterAPickWritesNoNotice() async throws {
        let world = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-2 * 60 * minute), in: world)
        let gated = GatedMarketServiceSpy(
            product: .success(try fixtureProduct()),
            listingsScript: [.failure(.unreachable), .success(try fixtureListings())],
            gatesEveryListingsCall: true
        )
        let viewModel = loaded(world, service: gated)
        #expect(viewModel.canRefresh)

        let refreshing = Task { await viewModel.refresh() }
        try await waitForListingsCall(1, on: gated)

        // The pick, made while the section's own refresh is still running —
        // the path the pick guard deliberately leaves open.
        openThePicker(viewModel)
        let picking = Task { await viewModel.setMatch(candidate()) }
        try await waitForListingsCall(2, on: gated)

        // The newer fetch lands first, and it is the one that speaks.
        gated.release(listingsCall: 2)
        await picking.value

        guard case .value = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }
        #expect(viewModel.marketNotice == nil)
        #expect(viewModel.marketActivity == nil, "the pick's landing left the section busy")
        #expect(viewModel.canAdopt, "the pick's landing left the adopt button disabled")

        // The older refresh, failing, lands last and changes neither.
        gated.release(listingsCall: 1)
        await refreshing.value

        #expect(viewModel.marketNotice == nil, "the older refresh painted its failure over the pick")
        #expect(viewModel.marketActivity == nil)
        #expect(viewModel.canAdopt, "the older refresh disturbed what the pick left standing")
        guard case .value = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }
    }

    /// The same two fetches in the other order, which is where `refresh()`'s
    /// own guard does its work (T022's third review): the older refresh
    /// lands while the pick's fetch is still out. It re-derives the section
    /// and nothing else — it may neither clear the flag the pick is still
    /// holding, re-enabling Refresh and the adopt button under a running
    /// fetch, nor paint its own failure line before the newer fetch has
    /// said anything.
    @Test func anOlderRefreshLandingWhileAPickRunsClearsNothing() async throws {
        let world = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-2 * 60 * minute), in: world)
        let gated = GatedMarketServiceSpy(
            product: .success(try fixtureProduct()),
            listingsScript: [.failure(.unreachable), .success(try fixtureListings())],
            gatesEveryListingsCall: true
        )
        let viewModel = loaded(world, service: gated)
        #expect(viewModel.canRefresh)

        let refreshing = Task { await viewModel.refresh() }
        try await waitForListingsCall(1, on: gated)

        openThePicker(viewModel)
        let picking = Task { await viewModel.setMatch(candidate()) }
        try await waitForListingsCall(2, on: gated)

        // The older refresh lands first, failing, with the pick's fetch
        // still gated behind it.
        gated.release(listingsCall: 1)
        await refreshing.value

        #expect(viewModel.marketActivity == .refreshing, "the older refresh cleared the flag the pick still holds")
        #expect(!viewModel.canRefresh, "the older refresh re-enabled Refresh under the pick's fetch")
        #expect(!viewModel.canAdopt, "the older refresh re-enabled the adopt button under the pick's fetch")
        #expect(viewModel.marketNotice == nil, "the older refresh painted its failure while the pick was still running")
        #expect(viewModel.sheetStep == .fetching(candidate(), token: 2), "the older refresh moved the pick's sheet")

        // The pick lands second, and it is the one that speaks.
        gated.release(listingsCall: 2)
        await picking.value

        guard case .value = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }
        #expect(viewModel.marketNotice == nil, "the pick's own landing wrote a notice")
        #expect(viewModel.marketActivity == nil, "the pick's landing left the section busy")
    }

    /// The other refused save, structurally, and for the same reason an
    /// in-memory `save()` can't be made to throw on demand. `setMatch`'s
    /// catch block ends in `return`, and that `return` is the whole of "a
    /// fetch never runs over a match that wasn't written" (the T009 rule):
    /// one save, the rollback and the close on the failure path, and both
    /// lines that start the fetch reachable only past it.
    @Test func aRefusedSetMatchSaveNeverFetches() throws {
        let code = try SourceScan.production("Trove/ViewModels/ItemDetailViewModel.swift")
        let bodies = SourceScan.closureBodies(after: "func setMatch(_ candidate: MarketCandidate) async", in: code)
        try #require(bodies.count == 1, "expected exactly one setMatch(_:)")
        let body = bodies[0]
        #expect(body.ranges(of: "modelContext.save()").count == 1, "setMatch must save exactly once")

        let catches = SourceScan.closureBodies(after: "} catch", in: body)
        try #require(catches.count == 1, "expected exactly one catch block")
        #expect(catches[0].contains("modelContext.rollback()"), "the refused save must roll back the context")
        #expect(catches[0].contains("closeSheet()"), "the refused save must close the sheet")
        // A line that *is* `return`, not the word anywhere in the block —
        // `return false` or a `returned` in prose would satisfy `contains`.
        // Comments are already gone: `SourceScan.production` strips them.
        let returnsOnItsOwnLine = catches[0]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .contains { $0.trimmingCharacters(in: .whitespaces) == "return" }
        #expect(returnsOnItsOwnLine, "the refused save must return before anything is fetched")

        let catchEnd = try #require(body.range(of: catches[0])).upperBound
        let fetching = try #require(body.range(of: "sheetStep = .fetching(candidate, token: token)"), "setMatch no longer enters the fetching phase")
        let activity = try #require(body.range(of: "marketActivity = .refreshing"), "setMatch no longer marks its fetch as activity")
        #expect(fetching.lowerBound > catchEnd, "the fetching phase is entered where a refused save can reach it")
        #expect(activity.lowerBound > catchEnd, "the fetch starts where a refused save can reach it")
        // The token is taken on the far side of the catch too (T022's
        // third review). Above the `do`, a refused save would consume a
        // generation and return, and any fetch already in flight would land
        // with a stale token — leaving `marketActivity` set with no landing
        // left to clear it, and the section busy for good.
        let token = try #require(body.range(of: "let token = nextGeneration()"), "setMatch no longer takes a generation of its own")
        #expect(token.lowerBound > catchEnd, "the generation is taken where a refused save can burn it")
    }

    // MARK: - The value step and what it writes (criterion 8, Decisions 34–35)

    /// Criterion 8: the button writes the amount on the slider, not the
    /// median under it.
    @Test func adoptWritesTheChosenAmountNotTheMedian() throws {
        let world = try world()
        try seedTrimmed(median: 139_999, low: 115_200, high: 325_000, p10: 120_000, p90: 169_900, at: t0.addingTimeInterval(-minute), in: world)
        let viewModel = loaded(world, service: MarketServiceSpy())

        viewModel.openValueStep()
        #expect(viewModel.isFindingMatch, "the section's adopt action opened nothing")
        guard case .value(let opened) = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }
        #expect(opened.chosenCents == 140_000, "the step didn't open on the whole-currency median")

        viewModel.setChosen(opened.upperCents)
        guard case .value(let moved) = viewModel.sheetStep else { throw TestFailure("\(viewModel.sheetStep)") }
        #expect(moved.chosenCents == 169_900, "the view model didn't carry the slider's move")
        #expect(viewModel.adopt(cents: moved.chosenCents))

        let stored = try storedItem(world.item.id, in: world.container)
        #expect(stored.currentValueCents == 169_900, "the median was written instead of the amount chosen")
        #expect(stored.currentValueCents != 140_000)
        #expect(!viewModel.isFindingMatch, "the sheet stayed open after the write")
        #expect(viewModel.sheetStep == .pick)
    }

    /// Not now: the sheet closes and nothing is written (Decision 34).
    @Test func dismissingTheValueStepWritesNothing() throws {
        let world = try world()
        try seedTrimmed(median: 139_999, low: 115_200, high: 325_000, p10: 120_000, p90: 169_900, at: t0.addingTimeInterval(-minute), in: world)
        let viewModel = loaded(world, service: MarketServiceSpy())

        viewModel.openValueStep()
        viewModel.setChosen(150_000)
        viewModel.dismissValueStep()

        #expect(!viewModel.isFindingMatch)
        #expect(viewModel.sheetStep == .pick)
        #expect(!world.context.hasChanges, "Not now left changes waiting to be saved")
        #expect(try storedItem(world.item.id, in: world.container).currentValueCents == nil)
    }

    /// Decision 34: a withheld or stale reading offers no value step, and
    /// neither does a figure with a refresh already running over it.
    @Test func openValueStepNeedsACurrentReading() async throws {
        let withheld = try world()
        try seed(median: nil, at: t0, in: withheld)
        let a = loaded(withheld, now: t0.addingTimeInterval(minute))
        a.openValueStep()
        #expect(!a.isFindingMatch, "a withheld reading opened the value step")
        #expect(a.sheetStep == .pick)

        let stale = try world()
        try seed(median: 140_000, at: t0, in: stale)
        let b = loaded(stale, now: t0.addingTimeInterval(31 * day))
        b.openValueStep()
        #expect(!b.isFindingMatch, "a stale reading opened the value step")
        #expect(b.sheetStep == .pick)

        let refreshing = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-2 * 60 * minute), in: refreshing)
        let gated = GatedMarketServiceSpy(product: .success(try fixtureProduct()), listings: .success(try fixtureListings()))
        let c = loaded(refreshing, service: gated)
        let task = Task { await c.refresh() }
        try await waitForListingsCall(1, on: gated)
        c.openValueStep()
        #expect(!c.isFindingMatch, "the value step opened over a figure a refresh was replacing")
        #expect(c.sheetStep == .pick)
        gated.release()
        await task.value
    }

    /// B3's refused save, structurally — the shape
    /// `SettingsWiringTests.confirmDeleteAllRollsBackOnSaveFailure` uses,
    /// and for its reason: an in-memory `save()` can't be made to throw on
    /// demand. One save; the rollback and the message on the failure path
    /// and nowhere else; and the sheet closed whichever way it goes.
    @Test func aRefusedAdoptSaveReportsAndCloses() throws {
        let code = try SourceScan.production("Trove/ViewModels/ItemDetailViewModel.swift")
        let bodies = SourceScan.closureBodies(after: "func adopt(cents: Int) -> Bool", in: code)
        try #require(bodies.count == 1, "expected exactly one adopt(cents:)")
        let body = bodies[0]
        #expect(body.ranges(of: "modelContext.save()").count == 1, "adopt must save exactly once")
        #expect(body.contains("defer { closeSheet() }"), "the sheet must close whether or not the save lands")

        let catches = SourceScan.closureBodies(after: "} catch", in: body)
        try #require(catches.count == 1, "expected exactly one catch block")
        #expect(catches[0].contains("modelContext.rollback()"), "the failure path must roll back the context")
        #expect(catches[0].contains("adoptFailureMessage = error.localizedDescription"), "the failure path must report itself")
        #expect(catches[0].contains("return false"), "the failure path must answer false")
        let outsideCatch = body.replacingOccurrences(of: catches[0], with: "")
        #expect(!outsideCatch.contains("rollback()"), "rollback belongs to the failure path only")
        #expect(!outsideCatch.contains("adoptFailureMessage = error"), "the message belongs to the failure path only")
    }

    // MARK: - Driving the sheet the way the screen does

    /// Find on Reverb…, and past the one-time notice where this device
    /// hasn't seen it (Decision 14): the picker is the only phase a pick
    /// can come from.
    private func openThePicker(_ viewModel: ItemDetailViewModel) {
        viewModel.findMatch()
        if viewModel.sheetStep == .notice { viewModel.continueFromNotice() }
    }

    /// Bounded, like the refresh tests' own spin: a fetch that never reaches
    /// the spy fails the `#require` instead of hanging the suite.
    private func waitForListingsCall(_ call: Int, on gated: GatedMarketServiceSpy) async throws {
        var yields = 0
        while gated.listingsCalls < call && yields < 10_000 {
            await Task.yield()
            yields += 1
        }
        try #require(gated.listingsCalls == call, "listings call \(call) never arrived")
    }

    /// A stored figure carrying trimmed bounds of its own — the memberwise
    /// init rather than `seed`'s shim, whose percentiles sit exactly on the
    /// ends (TestSupport's note), which a test about the slider's ends could
    /// not tell apart from the real thing.
    private func seedTrimmed(
        median: Int, low: Int, high: Int, p10: Int, p90: Int, at fetchedAt: Date, in world: World
    ) throws {
        let figure = MarketFigure(
            medianCents: median, lowCents: low, highCents: high,
            p10Cents: p10, p90Cents: p90,
            count: 34, fetchedAt: fetchedAt, isTruncated: false, yearScope: .any
        )
        try MarketLocalStore.record(.figure(figure), product: catalogProduct, for: MarketSubjectKey(subjectID: world.item.id, kind: .owned), in: world.context)
        try world.context.save()
    }

    // MARK: - The two screens agree

    /// The owned and the wanted screens read one derivation (plan §6): the
    /// same stored rows must resolve to the same reading on both.
    @Test func bothDetailViewModelsResolveTheSameState() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let owned = Item(name: "Telecaster", condition: .excellent, reverbProductID: 126_161)
        let wanted = WishlistItem(name: "Telecaster", estimatedCostCents: 240_000, reverbProductID: 126_161)
        context.insert(owned)
        context.insert(wanted)
        try context.save()

        let figure = MarketFigure(medianCents: 140_000, lowCents: 130_000, highCents: 150_000, count: 12, fetchedAt: t0, isTruncated: false, yearScope: .any)
        try MarketLocalStore.record(.figure(figure), product: catalogProduct, for: MarketSubjectKey(subjectID: owned.id, kind: .owned), in: context)
        try MarketLocalStore.record(.figure(figure), product: catalogProduct, for: MarketSubjectKey(subjectID: wanted.id, kind: .wanted), in: context)
        try context.save()

        let now = t0.addingTimeInterval(2 * 60 * minute)
        let ownedViewModel = ItemDetailViewModel(modelContext: context, itemID: owned.id, marketService: MarketServiceSpy(), now: { now })
        let wantedViewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id, marketService: MarketServiceSpy(), now: { now })
        ownedViewModel.load()
        wantedViewModel.load()

        guard case .matched(let a) = ownedViewModel.marketState, case .matched(let b) = wantedViewModel.marketState else {
            throw TestFailure("\(ownedViewModel.marketState) / \(wantedViewModel.marketState)")
        }
        #expect(a.reading == b.reading)
        #expect(a.title == b.title)
        #expect(a.webURL == b.webURL)
        #expect(ownedViewModel.canRefresh == wantedViewModel.canRefresh)
        #expect(ownedViewModel.canAdopt == wantedViewModel.canAdopt)
    }
}

/// One row of `MarketNotice.notice(for:lastFetchedAt:)`'s table (plan §6),
/// covering every `MarketRefresher.Outcome` case and every `MarketError`
/// under `.failed`.
/// `nonisolated` because `@Test(arguments:)` evaluates its arguments outside
/// the main actor, and this target's default isolation is `MainActor` — the
/// same reason `YearCase` is declared that way.
nonisolated struct OutcomeNoticeCase: CustomStringConvertible, Sendable {
    /// The date every row passes in: an arm that drops it reads as
    /// `.unreachable(lastFetchedAt: nil)` and fails against the expectation.
    static let lastFetchedAt = Date(timeIntervalSince1970: 1_799_000_000)

    let label: String
    let outcome: MarketRefresher.Outcome
    let expected: MarketNotice?

    static var all: [OutcomeNoticeCase] {
        let figure = MarketFigure(medianCents: 140_000, lowCents: 130_000, highCents: 150_000, count: 12, fetchedAt: lastFetchedAt, isTruncated: false, yearScope: .any)
        return [
            OutcomeNoticeCase(label: "refreshed(figure)", outcome: .refreshed(.figure(figure)), expected: nil),
            OutcomeNoticeCase(label: "refreshed(withheld)", outcome: .refreshed(.withheld(count: 1, usedLowCents: 100_000, fetchedAt: lastFetchedAt, yearScope: .any)), expected: nil),
            OutcomeNoticeCase(label: "stillFresh", outcome: .stillFresh(fetchedAt: lastFetchedAt), expected: nil),
            OutcomeNoticeCase(label: "superseded", outcome: .superseded, expected: nil),
            OutcomeNoticeCase(label: "failed(rateLimited)", outcome: .failed(.rateLimited), expected: .rateLimited),
            OutcomeNoticeCase(label: "failed(productNotFound)", outcome: .failed(.productNotFound), expected: .productGone),
            OutcomeNoticeCase(label: "failed(unreachable)", outcome: .failed(.unreachable), expected: .unreachable(lastFetchedAt: lastFetchedAt)),
            OutcomeNoticeCase(label: "failed(serverError)", outcome: .failed(.serverError(status: 500)), expected: .unreachable(lastFetchedAt: lastFetchedAt)),
            OutcomeNoticeCase(label: "failed(malformedResponse)", outcome: .failed(.malformedResponse), expected: .unreachable(lastFetchedAt: lastFetchedAt)),
            OutcomeNoticeCase(label: "saveFailed", outcome: .saveFailed("the store refused"), expected: .unreachable(lastFetchedAt: lastFetchedAt)),
        ]
    }

    var description: String { label }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

// MARK: - 006/T012: mark, edit, return

/// The item's own page as the second host of a sale (006 plan §5): Mark as
/// sold…, Edit sale… and Return to collection…, each through `ItemSaleStore`
/// with one save.
///
/// Every persistence claim refetches on a **second `ModelContext`** (the T003
/// rule): a same-context refetch hands back objects carrying unsaved changes
/// and would pass whether or not the intent saved.
@Suite("ItemDetailViewModel — sold")
struct ItemDetailSoldTests {
    private let soldOn = Date(timeIntervalSince1970: 1_770_000_000)
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func sale(_ priceCents: Int = 130_000, on date: Date? = nil) -> Sale {
        Sale(date: date ?? soldOn, priceCents: priceCents, location: "Reverb", note: "Shipped Tuesday")
    }

    private let product = MarketProduct(
        id: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster",
        usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
    )

    /// One refresh's worth of local rows — figure, history point and match
    /// snapshot — recorded exactly as a real refresh records them
    /// (`ItemSaleStoreTests`' helper).
    private func seedMarketRows(for subjectID: UUID, in context: ModelContext) throws {
        let reading = MarketReading.figure(MarketFigure(
            medianCents: 140_000, lowCents: 130_000, highCents: 150_000,
            p10Cents: 132_000, p90Cents: 148_000,
            count: 12, fetchedAt: soldOn, isTruncated: false, yearScope: .any
        ))
        try MarketLocalStore.record(reading, product: product, for: MarketSubjectKey(subjectID: subjectID, kind: .owned), in: context)
    }

    private func loaded(_ item: Item, in context: ModelContext) -> ItemDetailViewModel {
        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id, now: { self.now })
        viewModel.load()
        return viewModel
    }

    // MARK: - Mark as sold

    /// G20, G5 and G6's detail half, together, because they are one action:
    /// marking sold from the item's own page records the four fields and
    /// nothing else — the item's own fields, its photos and its Reverb match
    /// are as they were (Decision 1), the device's rows for *this* item are
    /// gone and another item's are not (Decision 7), and the sale points at
    /// no plan even though one exists to point at (criterion 11).
    @Test func markSoldRecordsTheSaleOnNoPlanAndLeavesTheItemItselfAlone() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let purchasedOn = Date(timeIntervalSince1970: 1_000_000)
        let item = Item(
            name: "Telecaster",
            categoryPath: "Music/Guitars",
            purchasePriceCents: 100_000,
            purchaseDate: purchasedOn,
            serialNumber: "TL-1138",
            purchaseLocation: "Guitar Center",
            currentValueCents: 120_000,
            desireToKeep: 2,
            condition: .good,
            conditionNotes: "Buckle rash",
            notes: "Ash body",
            sortOrder: 4,
            photos: [Photo(imageData: Data([0xAB, 0xCD]), source: .device)],
            reverbProductID: 126_161,
            year: 1975
        )
        let other = Item(name: "Blues Junior", purchasePriceCents: 60_000, reverbProductID: 222)
        // Present precisely so a detail-screen sale that reached for a plan
        // would find one: with no wishlist item in the store, `toward:`
        // could be anything at all and this test would still pass (G6).
        let plan = WishlistItem(name: "Rickenbacker 330")
        for model in [item, other] { context.insert(model) }
        context.insert(plan)
        try seedMarketRows(for: item.id, in: context)
        try seedMarketRows(for: other.id, in: context)
        try context.save()

        let viewModel = loaded(item, in: context)
        #expect(!viewModel.isSold)
        #expect(viewModel.sale == nil)
        #expect(viewModel.saleOutcome == nil)

        #expect(viewModel.markSold(sale()))

        #expect(viewModel.isSold)
        #expect(viewModel.sale == sale())
        #expect(viewModel.saleOutcome?.deltaCents == 30_000, "$1,300 against $1,000 paid is a $300 gain")

        let elsewhere = ModelContext(container)
        let stored = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first { $0.name == "Telecaster" })
        #expect(stored.sale == sale())
        #expect(stored.soldTowardWishlistItem == nil, "a sale from the item's own page is toward no plan (G6)")
        #expect(stored.plannedForWishlistItems?.isEmpty == true)
        #expect(stored.updatedAt == now, "the mark is an edit to the row (Q13)")

        // G20: the sale is a state change, not an edit.
        #expect(stored.categoryPath == "Music/Guitars")
        #expect(stored.purchasePriceCents == 100_000)
        #expect(stored.purchaseDate == purchasedOn)
        #expect(stored.serialNumber == "TL-1138")
        #expect(stored.purchaseLocation == "Guitar Center")
        #expect(stored.currentValueCents == 120_000)
        #expect(stored.desireToKeep == 2)
        #expect(stored.condition == .good)
        #expect(stored.conditionNotes == "Buckle rash")
        #expect(stored.notes == "Ash body")
        #expect(stored.sortOrder == 4, "the sale never touches the manual position")
        #expect(stored.year == 1975)
        #expect(stored.photos?.count == 1)
        #expect(stored.photos?.first?.imageData == Data([0xAB, 0xCD]))
        #expect(stored.reverbProductID == 126_161, "the match is kept (Decision 1) — only the local rows go")

        // G5: this item's device rows, and only this item's.
        #expect(try MarketLocalStore.figure(for: item.id, in: elsewhere) == nil, "the sold item's figure must be gone")
        #expect(try MarketLocalStore.history(for: item.id, in: elsewhere).isEmpty, "its history must be gone")
        #expect(try MarketLocalStore.snapshot(for: item.id, in: elsewhere) == nil, "its snapshot must be gone")
        #expect(try MarketLocalStore.figure(for: other.id, in: elsewhere) != nil, "another item's figure must be untouched")
        #expect(try MarketLocalStore.history(for: other.id, in: elsewhere).count == 1)
        #expect(try MarketLocalStore.snapshot(for: other.id, in: elsewhere) != nil)
    }

    /// The sale drops every plan *selection* the item was on, through the
    /// detail path as much as the plan's own (spec P6): the item survives its
    /// sale, so nothing else drops them for it.
    @Test func markSoldFromTheDetailLeavesTheItemOnNoSellPlan() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let plan = WishlistItem(name: "Rickenbacker 330")
        context.insert(item)
        context.insert(plan)
        plan.plannedSaleItems = [item]
        try context.save()

        #expect(loaded(item, in: context).markSold(sale()))

        let elsewhere = ModelContext(container)
        let storedPlan = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(storedPlan.plannedSaleItems?.isEmpty == true, "the sold item leaves every selection it was on")
        #expect(storedPlan.itemsSoldToward?.isEmpty == true, "and it funds nothing, having been sold from its own page")
    }

    // MARK: - Edit sale

    /// G21 through the detail path: an item sold *from a plan* and then
    /// corrected on its own page keeps the funding link. Red if `editSale`
    /// routes through `markSold(toward: nil)`, which would silently unfund
    /// the plan the money was raised for.
    @Test func editSaleKeepsAnEarlierPlanLink() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let plan = WishlistItem(name: "Rickenbacker 330")
        context.insert(item)
        context.insert(plan)
        try ItemSaleStore.markSold(item, sale: sale(), toward: plan, at: now, in: context)
        try context.save()

        let viewModel = loaded(item, in: context)
        let corrected = Sale(date: soldOn.addingTimeInterval(3_600), priceCents: 125_000, location: "eBay", note: nil)
        #expect(viewModel.editSale(corrected))
        #expect(viewModel.sale == corrected)
        #expect(viewModel.saleOutcome?.deltaCents == 25_000)

        let elsewhere = ModelContext(container)
        let stored = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first)
        #expect(stored.sale == corrected, "the four fields are the edit's")
        #expect(stored.soldTowardWishlistItem?.name == "Rickenbacker 330", "the edit must leave the funding link alone (G21)")
        #expect(stored.updatedAt == now, "the edit bumps the row (Q13)")
    }

    // MARK: - Return to collection

    /// G7 through the detail path: Return clears all five — the four sale
    /// fields and the funding link (P12) — and the item is back in
    /// `ItemListViewModel.items` **at its slot**, not appended, because
    /// `sortOrder` was never touched. The list is built on a second context,
    /// so it reads what was actually saved.
    @Test func returnToCollectionClearsAllFiveAndRestoresTheItemsSlot() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        var created = Date(timeIntervalSince1970: 900_000)
        var items: [Item] = []
        for (position, name) in ["Alpha", "Bravo", "Charlie", "Delta"].enumerated() {
            let item = Item(name: name, purchasePriceCents: 10_000, sortOrder: position)
            item.createdAt = created
            created = created.addingTimeInterval(60)
            context.insert(item)
            items.append(item)
        }
        let plan = WishlistItem(name: "Rickenbacker 330")
        context.insert(plan)
        let charlie = items[2]
        try ItemSaleStore.markSold(charlie, sale: sale(), toward: plan, at: now, in: context)
        try context.save()

        let viewModel = loaded(charlie, in: context)
        #expect(viewModel.isSold)
        #expect(viewModel.returnToCollection())
        #expect(!viewModel.isSold)
        #expect(viewModel.sale == nil)
        #expect(viewModel.saleOutcome == nil)

        let elsewhere = ModelContext(container)
        let returned = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first { $0.name == "Charlie" })
        #expect(returned.soldDate == nil)
        #expect(returned.salePriceCents == nil)
        #expect(returned.saleLocation == nil)
        #expect(returned.saleNote == nil)
        #expect(returned.soldTowardWishlistItem == nil, "the returned item funds nothing (P12)")
        #expect(returned.plannedForWishlistItems?.isEmpty == true, "it rejoins no plan")
        #expect(returned.sortOrder == 2, "the return must not renumber the item")
        #expect(returned.updatedAt == now, "the return bumps the row (Q13)")

        let list = ItemListViewModel(modelContext: elsewhere)
        list.sortOrder = .custom
        list.load()
        #expect(list.items.map(\.name) == ["Alpha", "Bravo", "Charlie", "Delta"], "the returned item is back in its own Custom-order slot")
        #expect(list.soldItems.isEmpty, "and it is gone from the Sold side")
    }

    // MARK: - A refused save

    /// The three intents' failure path, structurally — the shape
    /// `aRefusedAdoptSaveReportsAndCloses` uses, and for the same reason: an
    /// in-memory `save()` can't be made to throw on demand, and no
    /// `SaveFailingContext` exists in this tree.
    ///
    /// What it guards is that a refused save leaves the item exactly as it is
    /// stored — still owned after a refused mark, still sold after a refused
    /// return: one save per intent, the rollback that discards the
    /// half-written change, the `load()` that re-reads what is actually
    /// there, and `false` as the answer, all of them inside the catch and the
    /// rollback nowhere else.
    ///
    /// The Sell Plan's own `markSold(_:sale:)` is the fourth intent on the
    /// same path and is scanned here beside the three, so one host can't drift
    /// from the other. It carries one extra anchor: 006 plan §3 has it report
    /// the refusal in `saveFailureMessage`, which the detail screen surfaces
    /// its own way. The Items list's swipe (014 §5) is the fifth, reporting in
    /// the message *it* has, `loadFailureMessage`.
    @Test func aRefusedSaveRollsBackAndReReadsWhatIsStored() throws {
        // (file, signature, the failure message the host must also set)
        let intents: [(String, String, String?)] = [
            ("Trove/ViewModels/ItemDetailViewModel.swift", "func markSold(_ sale: Sale) -> Bool", nil),
            ("Trove/ViewModels/ItemDetailViewModel.swift", "func editSale(_ sale: Sale) -> Bool", nil),
            ("Trove/ViewModels/ItemDetailViewModel.swift", "func returnToCollection() -> Bool", nil),
            ("Trove/ViewModels/SellPlanViewModel.swift", "func markSold(_ item: Item, sale: Sale) -> Bool", "saveFailureMessage ="),
            ("Trove/ViewModels/ItemListViewModel.swift", "func markSold(_ item: Item, sale: Sale) -> Bool", "loadFailureMessage ="),
        ]
        var sources: [String: String] = [:]
        for path in Set(intents.map(\.0)) {
            sources[path] = try SourceScan.production(path)
        }
        for (path, signature, failureMessage) in intents {
            let code = try #require(sources[path])
            let bodies = SourceScan.closureBodies(after: signature, in: code)
            try #require(bodies.count == 1, "expected exactly one \(signature) in \(path)")
            let body = bodies[0]
            #expect(body.ranges(of: "modelContext.save()").count == 1, "\(signature) must save exactly once")

            let catches = SourceScan.closureBodies(after: "} catch", in: body)
            try #require(catches.count == 1, "expected exactly one catch block in \(signature)")
            #expect(catches[0].contains("modelContext.rollback()"), "\(signature): the refused save must roll the context back")
            #expect(catches[0].contains("load()"), "\(signature): the refused save must re-read what is stored")
            #expect(catches[0].contains("return false"), "\(signature): the refused save must answer false")
            if let failureMessage {
                #expect(catches[0].contains(failureMessage), "\(signature): the refused save must report itself (plan §3)")
            }

            let outsideCatch = body.replacingOccurrences(of: catches[0], with: "")
            #expect(!outsideCatch.contains("rollback()"), "\(signature): rollback belongs to the failure path only")
        }
    }

    // MARK: - Seeding the sheet (P1, G19)

    /// The sheet is `.sheet(item:)` state the view writes both ways, the way
    /// the plan row's `saleCandidate` is.
    @Test func theSaleSheetIsViewSettableBothWays() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000)
        context.insert(item)
        try context.save()

        let viewModel = loaded(item, in: context)
        #expect(viewModel.saleSheet == nil)
        viewModel.saleSheet = .mark
        #expect(viewModel.saleSheet == .mark)
        viewModel.saleSheet = nil
        #expect(viewModel.saleSheet == nil)
    }

    /// G19, `.mark`: the price comes from the item's own current value and the
    /// date from this screen's injected clock, with nothing else pre-filled.
    @Test func theMarkSheetIsSeededFromTheCurrentValueAndTodaysDate() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000, currentValueCents: 130_000)
        context.insert(item)
        try context.save()

        let viewModel = loaded(item, in: context)
        viewModel.saleSheet = .mark
        let form = viewModel.makeSaleFormViewModel()

        #expect(form.title == SaleCopy.sheetTitleMark)
        #expect(form.confirmLabel == SaleCopy.confirmMark)
        #expect(form.price == Decimal(string: "1300"))
        #expect(form.date == now)
        #expect(form.location.isEmpty)
        #expect(form.note.isEmpty)
    }

    /// G19, `.mark` with nothing to go on: a blank price, not a zero — the
    /// distinction P1 rests on.
    @Test func theMarkSheetIsBlankWhenTheItemHasNoValue() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000, currentValueCents: nil)
        context.insert(item)
        try context.save()

        let viewModel = loaded(item, in: context)
        viewModel.saleSheet = .mark
        let form = viewModel.makeSaleFormViewModel()

        #expect(form.price == nil, "no value entered means a blank field, never $0")
        #expect(form.date == now)
    }

    /// G19, `.edit`: the sale that is recorded, not the item's current value
    /// and not today — all four fields.
    @Test func theEditSheetIsSeededFromTheRecordedSale() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000, currentValueCents: 130_000)
        context.insert(item)
        try ItemSaleStore.markSold(item, sale: sale(95_000), toward: nil, at: now, in: context)
        try context.save()

        let viewModel = loaded(item, in: context)
        viewModel.saleSheet = .edit
        let form = viewModel.makeSaleFormViewModel()

        #expect(form.title == SaleCopy.sheetTitleEdit)
        #expect(form.confirmLabel == SaleCopy.confirmEdit)
        #expect(form.price == Decimal(string: "950"), "the sale's price, not the item's current value")
        #expect(form.date == soldOn, "the sale's date, not today")
        #expect(form.location == "Reverb")
        #expect(form.note == "Shipped Tuesday")
    }

    /// One seeding rule, every host (P1): for the same item and the same
    /// clock, the detail page's Mark as sold… sheet, a Sell Plan row's, and —
    /// since 014 G17 — the Items list swipe's seed the same sheet. Deferred
    /// here from T011, which had only one half of the comparison to make.
    ///
    /// Both an item that has a current value and one that hasn't: agreeing on
    /// the valued item alone would leave another host free to seed a $0 price
    /// where the detail host leaves the field blank — the one distinction P1
    /// rests on, and the one a `?? 0` slipped into any host would break.
    @Test func everyHostSeedsTheMarkSheetIdentically() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000, currentValueCents: 130_000, desireToKeep: 1)
        context.insert(item)
        let unvalued = Item(name: "Blues Junior", purchasePriceCents: 60_000, currentValueCents: nil, desireToKeep: 1)
        context.insert(unvalued)
        let plan = WishlistItem(name: "Rickenbacker 330", estimatedCostCents: 240_000)
        context.insert(plan)
        try context.save()

        let sellPlan = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id, now: { self.now })
        sellPlan.load()
        // An un-valued item isn't a candidate on its own (`qualifies` wants a
        // value), but a selected one stays on the plan after its value is
        // cleared — which is how a row with no price to seed from gets here.
        sellPlan.toggle(unvalued)
        sellPlan.load()

        // The third host: the Owned side's swipe, over the same context and
        // the same clock (014 §5).
        let list = ItemListViewModel(modelContext: context, now: { self.now })
        list.load()

        for subject in [item, unvalued] {
            let detail = loaded(subject, in: context)
            detail.saleSheet = .mark
            let fromDetail = detail.makeSaleFormViewModel()

            let candidate = try #require(
                sellPlan.candidates.first { $0.id == subject.id },
                "\(subject.name) must be a candidate for the comparison to mean anything"
            )
            let fromPlan = sellPlan.makeSaleFormViewModel(for: candidate)

            let row = try #require(
                list.items.first { $0.id == subject.id },
                "\(subject.name) must be an Owned row for the comparison to mean anything"
            )
            let fromList = list.makeSaleFormViewModel(for: row)

            for (host, form) in [("the plan", fromPlan), ("the list", fromList)] {
                #expect(fromDetail.title == form.title)
                #expect(fromDetail.confirmLabel == form.confirmLabel)
                #expect(fromDetail.price == form.price, "\(subject.name): the detail and \(host) seed the same price")
                #expect(fromDetail.date == form.date, "\(subject.name): the detail and \(host) seed the same date")
                #expect(fromDetail.location == form.location)
                #expect(fromDetail.note == form.note)
            }
        }

        // Pinned, so hosts agreeing on the wrong thing still fails.
        let unvaluedCandidate = try #require(sellPlan.candidates.first { $0.id == unvalued.id })
        #expect(sellPlan.makeSaleFormViewModel(for: unvaluedCandidate).price == nil, "no value entered means a blank field, never $0")
        #expect(sellPlan.makeSaleFormViewModel(for: unvaluedCandidate).date == now)
        let unvaluedRow = try #require(list.items.first { $0.id == unvalued.id })
        #expect(list.makeSaleFormViewModel(for: unvaluedRow).price == nil, "no value entered means a blank field, never $0")
        #expect(list.makeSaleFormViewModel(for: unvaluedRow).date == now)
    }

    // MARK: - Delete

    /// Criterion 9's third row: Delete on a sold item is the same permanent
    /// delete as on an owned one — the item and its photos go, and the sale
    /// goes with the item.
    @Test func deletingASoldItemRemovesItAndItsPhotos() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(
            name: "Telecaster",
            purchasePriceCents: 100_000,
            photos: [Photo(imageData: Data([0xAB]), source: .device), Photo(imageData: Data([0xCD]), source: .device, sortOrder: 1)]
        )
        let kept = Item(name: "Blues Junior", purchasePriceCents: 60_000, photos: [Photo(imageData: Data([0xEF]), source: .device)])
        for model in [item, kept] { context.insert(model) }
        try ItemSaleStore.markSold(item, sale: sale(), toward: nil, at: now, in: context)
        try context.save()

        let viewModel = loaded(item, in: context)
        #expect(viewModel.isSold)
        #expect(viewModel.delete())
        #expect(viewModel.item == nil)

        let elsewhere = ModelContext(container)
        #expect(try elsewhere.fetch(FetchDescriptor<Item>()).map(\.name) == ["Blues Junior"], "the sold item is gone")
        #expect(try elsewhere.fetch(FetchDescriptor<Photo>()).map(\.imageData) == [Data([0xEF])], "its photos go with it, and only its own")
    }
}

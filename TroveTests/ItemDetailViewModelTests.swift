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

    @Test func adoptWritesTheRoundedMedianAndChangesNothingElse() throws {
        let world = try world()
        try seed(median: 139_950, at: t0.addingTimeInterval(-minute), in: world)
        let before = world.item.updatedAt
        let spy = MarketServiceSpy()
        let adoptedAt = t0.addingTimeInterval(day)
        let viewModel = loaded(world, now: adoptedAt, service: spy)

        #expect(viewModel.canAdopt)
        #expect(viewModel.adopt())
        #expect(viewModel.adoptFailureMessage == nil)
        #expect(!world.context.hasChanges, "adopt left unsaved changes behind")

        let stored = try storedItem(world.item.id, in: world.container)
        let written = try #require(stored.currentValueCents)
        #expect(written == 140_000)
        // The number written is the number the section showed — the display
        // formatter rounds half to even, and so does the adoption.
        #expect(MarketCopy.median(cents: written) == MarketCopy.median(cents: 139_950))
        #expect(stored.updatedAt == adoptedAt)
        #expect(stored.updatedAt != before)

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
        #expect(!a.adopt())
        #expect(try storedItem(withheld.item.id, in: withheld.container).currentValueCents == nil)

        let stale = try world()
        try seed(median: 140_000, at: t0, in: stale)
        let b = loaded(stale, now: t0.addingTimeInterval(31 * day))
        #expect(!b.canAdopt)
        #expect(!b.adopt())
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
    @Test func setMatchToADifferentProductClearsHistoryButTheSameProductDoesNot() throws {
        let world = try world()
        try seed(median: 140_000, at: t0, in: world)
        let matchedAt = t0.addingTimeInterval(day)
        let viewModel = loaded(world, now: matchedAt)
        viewModel.findMatch()

        viewModel.setMatch(candidate())

        let same = ModelContext(world.container)
        let keptFigure = try MarketLocalStore.figure(for: world.item.id, in: same)
        let keptHistory = try MarketLocalStore.history(for: world.item.id, in: same)
        #expect(keptFigure?.medianCents == 140_000, "re-picking the same product cleared its figure")
        #expect(keptHistory.count == 1, "re-picking the same product cleared its history")
        #expect(!viewModel.isFindingMatch, "the sheet stayed open after the pick")

        viewModel.setMatch(candidate(id: 182_769, slug: "martin-d-18", title: "Martin D-18"))

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
    @Test func changingOrRemovingTheMatchClearsTheNotice() async throws {
        let changing = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-2 * 60 * minute), in: changing)
        let afterChange = loaded(changing, service: MarketServiceSpy(products: [.failure(.unreachable)]))
        await afterChange.refresh()
        #expect(afterChange.marketNotice != nil, "the failing refresh left no notice to clear")

        afterChange.setMatch(candidate(id: 182_769, slug: "martin-d-18", title: "Martin D-18"))
        #expect(afterChange.marketNotice == nil, "a change of match kept the old match's notice")

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
        #expect(viewModel.noticeIsPending)
        #expect(viewModel.isFindingMatch)
        #expect(spy.calls.isEmpty, "opening the sheet reached Reverb")

        viewModel.declineNotice()
        #expect(!viewModel.isFindingMatch)
        #expect(!viewModel.noticeIsPending)
        #expect(!MarketLocalStore.hasAcknowledgedNotice(in: ModelContext(world.container)), "Not now acknowledged the notice (Q5)")
        #expect(spy.calls.isEmpty, "Not now searched Reverb")

        viewModel.findMatch()
        #expect(viewModel.noticeIsPending, "Not now should leave the notice to come back")

        viewModel.continueFromNotice()
        #expect(!viewModel.noticeIsPending)
        #expect(viewModel.isFindingMatch, "Continue closed the sheet instead of handing it to the picker")
        #expect(MarketLocalStore.hasAcknowledgedNotice(in: ModelContext(world.container)), "Continue didn't reach the store")

        // The flag is the device's, not the screen's: a fresh view model over
        // the same container never shows the notice again.
        let next = ItemDetailViewModel(modelContext: ModelContext(world.container), itemID: world.item.id, marketService: spy, now: { self.t0 })
        next.load()
        next.findMatch()
        #expect(!next.noticeIsPending, "the notice came back on a new view model")
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

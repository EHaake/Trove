import Foundation
import SwiftData
import Testing
@testable import Trove

@Suite("WishlistDetailViewModel")
struct WishlistDetailViewModelTests {
    private func insert(
        _ name: String = "Summicron 35mm f/2",
        category: String = "Photography/Lenses",
        into context: ModelContext
    ) -> WishlistItem {
        let wanted = WishlistItem(name: name, categoryPath: category, estimatedCostCents: 240_000)
        context.insert(wanted)
        return wanted
    }

    @Test func hasNothingLoadedBeforeLoadIsCalled() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)

        #expect(viewModel.item == nil)
        #expect(viewModel.hasLoaded == false)
    }

    @Test func loadsTheItemMatchingItsID() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        _ = insert("Vox AC15 Custom", category: "Music/Amps", into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.item?.id == wanted.id)
        #expect(viewModel.item?.name == "Summicron 35mm f/2")
    }

    /// "Loaded, and it's gone" has to be distinguishable from "not loaded" —
    /// the view shows different things for each.
    @Test func loadsNothingForAnUnknownID() throws {
        let context = try makeInMemoryContext()
        _ = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: UUID())
        viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.item == nil)
    }

    /// The reason this holds an id instead of the object: an entry deleted
    /// elsewhere reads as absent on the next load rather than as a stale
    /// reference.
    @Test func loadAfterADeletionElsewhereFindsNothing() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.item != nil)

        context.delete(wanted)
        try context.save()
        viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.item == nil)
    }

    @Test func reloadingPicksUpAnEditMadeElsewhere() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        let form = WishlistFormViewModel(modelContext: context, editing: wanted)
        form.name = "Summicron 35mm f/2 (v4)"
        form.desireToOwn = 3
        #expect(form.save())

        viewModel.load()

        #expect(viewModel.item?.name == "Summicron 35mm f/2 (v4)")
        #expect(viewModel.desireLevel == .next)
    }

    // MARK: - Display

    /// Same rule the list rows follow: the relationship comes back unordered,
    /// so display order is `sortOrder`, not whatever SwiftData hands over.
    @Test func photosComeBackInTheUsersOwnOrder() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let first = Photo(imageData: Data([0x01]), sortOrder: 0)
        let second = Photo(imageData: Data([0x02]), sortOrder: 1)
        let third = Photo(imageData: Data([0x03]), sortOrder: 2)
        context.insert(first)
        context.insert(second)
        context.insert(third)
        // Deliberately attached out of order.
        wanted.photos = [third, first, second]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.photos.map(\.sortOrder) == [0, 1, 2])
        #expect(viewModel.photos.map(\.imageData) == [Data([0x01]), Data([0x02]), Data([0x03])])
    }

    @Test func photosAreEmptyWhenNothingIsLoaded() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: UUID())

        #expect(viewModel.photos.isEmpty)
        viewModel.load()
        #expect(viewModel.photos.isEmpty)
    }

    /// The detail screen shows the whole path, unlike rows, which show the
    /// trailing two segments.
    @Test func categorySegmentsCoverTheWholePath() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(category: "Music/Guitars/Electric", into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.categorySegments == ["Music", "Guitars", "Electric"])
    }

    @Test func categorySegmentsAreEmptyWithoutAnItem() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: UUID())
        viewModel.load()

        #expect(viewModel.categorySegments.isEmpty)
    }

    @Test(arguments: [(-5, DesireToOwnLevel.someday), (1, .someday), (2, .soon), (3, .next), (9, .next)])
    func theDesireLevelIsClampedOnTheWayOut(stored: Int, expected: DesireToOwnLevel) throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        wanted.desireToOwn = stored
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.desireLevel == expected)
    }

    @Test func thereIsNoDesireLevelWithoutAnItem() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: UUID())
        viewModel.load()

        #expect(viewModel.desireLevel == nil)
    }

    /// Blank notes save as `nil`, but an empty string could still reach here
    /// from an older build — both mean "no notes", so the heading goes.
    @Test(arguments: [nil, "", "   "])
    func hasNoNotesForBlankOrMissingText(notes: String?) throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        wanted.notes = notes
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.hasNotes == (notes == "   "))
    }

    @Test func hasNotesWhenThereIsSomethingToShow() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        wanted.notes = "v4 only, no haze"
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.hasNotes)
    }

    // MARK: - Delete

    @Test func deleteRemovesTheItemFromTheStore() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.delete())
        #expect(viewModel.item == nil)
        #expect(try context.fetch(FetchDescriptor<WishlistItem>()).isEmpty)
    }

    @Test func deleteLeavesOtherWishlistItemsAlone() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        _ = insert("Vox AC15 Custom", category: "Music/Amps", into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.delete())

        let survivors = try context.fetch(FetchDescriptor<WishlistItem>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.name == "Vox AC15 Custom")
    }

    @Test func deleteDoesNothingWhenNothingIsLoaded() throws {
        let context = try makeInMemoryContext()
        _ = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: UUID())
        viewModel.load()

        #expect(viewModel.delete() == false)
        #expect(try context.fetch(FetchDescriptor<WishlistItem>()).count == 1)
    }

    @Test func deletingTakesItsPhotosWithIt() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let photo = Photo(imageData: Data([0x01]))
        context.insert(photo)
        wanted.photos = [photo]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.delete())

        #expect(try context.fetch(FetchDescriptor<Photo>()).isEmpty)
    }

    /// The distinction the two delete rules exist for, exercised through the
    /// screen that actually offers the action: abandoning something you wanted
    /// must never delete gear you own. The alert says as much, so it had
    /// better be true.
    @Test func deletingLeavesTheSellPlanGearAlone() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let owned = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(owned)
        wanted.plannedSaleItems = [owned]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.delete())

        let survivors = try context.fetch(FetchDescriptor<Item>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.name == "Fender Telecaster")
    }

    @Test func loadAfterDeleteFindsNothing() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.delete())

        viewModel.load()
        #expect(viewModel.item == nil)
        #expect(viewModel.hasLoaded)
    }

    // MARK: - Scope

    /// plan.md keeps the Sell Plan a deliberate tap away rather than something
    /// this screen could render alongside the item. A detail model that
    /// computed candidates would quietly make that possible, so the boundary
    /// is worth pinning: this type reads the relationship's existence, never
    /// its ranking, and never writes it.
    @Test func loadingDoesNotTouchTheSellPlan() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let owned = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(owned)
        wanted.plannedSaleItems = [owned]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.item?.plannedSaleItems?.count == 1)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
    }

    /// 002/T006c: the device's market rows for the item — figure, history,
    /// snapshot — go with it, in the same save, read back on a second context.
    private func seedMarketRows(for id: UUID, in context: ModelContext) throws {
        let product = MarketProduct(id: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster", usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!)
        let figure = MarketFigure(medianCents: 140_000, lowCents: 130_000, highCents: 150_000, count: 12, fetchedAt: .now, isTruncated: false, yearScope: .any)
        try MarketLocalStore.record(.figure(figure), product: product, for: MarketSubjectKey(subjectID: id, kind: .wanted), in: context)
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
        let doomed = WishlistItem(name: "D-18", reverbProductID: 182_769)
        let kept = WishlistItem(name: "Timeline", reverbProductID: 17)
        context.insert(doomed); context.insert(kept)
        try seedMarketRows(for: doomed.id, in: context)
        try seedMarketRows(for: kept.id, in: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: doomed.id)
        viewModel.load()
        #expect(viewModel.delete())

        #expect(!(try marketRowsRemain(for: doomed.id, in: container)), "the deleted item's market rows survived it")
        #expect(try marketRowsRemain(for: kept.id, in: container), "another item's rows went too")
    }

}

// MARK: - 002/T009: the Market section

/// The wanted detail view model's market state and intents (plan §6) —
/// the mirror of `ItemDetailViewModelMarketTests`, differing only where the
/// two items differ: `.wanted` listings, "Use as estimated cost", and no
/// `updatedAt` to bump (002 Decision 24). Every fetch goes through a spy,
/// and every persistence claim is read on a **second context**.
@Suite("WishlistDetailViewModel — market")
struct WishlistDetailViewModelMarketTests {
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
        let item: WishlistItem
    }

    private func world(productID: Int? = 126_161, costCents: Int = 240_000, year: Int? = nil) throws -> World {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = WishlistItem(name: "Telecaster", estimatedCostCents: costCents, reverbProductID: productID, year: year)
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
        try MarketLocalStore.record(reading, product: product ?? catalogProduct, for: MarketSubjectKey(subjectID: world.item.id, kind: .wanted), in: world.context)
        try world.context.save()
    }

    private func viewModel(_ world: World, now: Date? = nil, service: (any MarketService)? = nil) -> WishlistDetailViewModel {
        let clock = now ?? t0
        return WishlistDetailViewModel(modelContext: world.context, itemID: world.item.id, marketService: service ?? MarketServiceSpy(), now: { clock })
    }

    private func loaded(_ world: World, now: Date? = nil, service: (any MarketService)? = nil) -> WishlistDetailViewModel {
        let viewModel = viewModel(world, now: now, service: service)
        viewModel.load()
        return viewModel
    }

    private func display(of world: World, now: Date? = nil) throws -> MarketMatchDisplay {
        let state = loaded(world, now: now).marketState
        guard case .matched(let display) = state else { throw MarketTestFailure("expected a match, got \(state)") }
        return display
    }

    private func storedItem(_ id: UUID, in container: ModelContainer) throws -> WishlistItem {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let item = try context.fetch(descriptor).first else { throw MarketTestFailure("the item is gone") }
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
        guard case .current(let figure) = currentDisplay.reading else { throw MarketTestFailure("\(currentDisplay.reading)") }
        #expect(figure.medianCents == 140_000)

        // 5 — a second short of thirty days is still current (the boundary).
        let boundary = try display(of: matched, now: t0.addingTimeInterval(30 * day - 1))
        guard case .current = boundary.reading else { throw MarketTestFailure("\(boundary.reading)") }

        // 6 — thirty days on, the figure is not carried (Decision 21).
        let stale = try display(of: matched, now: t0.addingTimeInterval(30 * day))
        #expect(stale.reading == .stale(fetchedAt: t0))

        // 7 — a fresh withheld reading keeps its row (no median to show).
        let withheldWorld = try world()
        try seed(median: nil, at: t0, in: withheldWorld)
        let withheld = try display(of: withheldWorld, now: t0.addingTimeInterval(minute))
        guard case .withheld(let value) = withheld.reading else { throw MarketTestFailure("\(withheld.reading)") }
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
            throw MarketTestFailure("\(viewModel.marketState)")
        }
        // Every used listing counts for a wanted item (P16), so the figure
        // is the wanted one, pinned to the recorded oracle in
        // `TroveTests/Fixtures/Reverb/README.md` (wanted n=72 median=149999)
        // that `MarketFigureComputationTests` asserts too — distinct from the
        // owned excellent bucket the same fixture yields (n=34 median=139999),
        // so this is the wanted reading and not merely "some number".
        // These numbers pin the bucket, nothing more: the two mechanisms that
        // could put the wanted subject in front of the computation — the
        // `subject` this view model hands in, and the refresher's re-read of
        // the row's `kind: .wanted` after its awaits — both yield 72 / 149_999,
        // so this test cannot tell them apart. That the re-read is what
        // decides it is recorded in plan §5, not proven here.
        #expect(figure.count == 72)
        #expect(figure.medianCents == 149_999)
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
            throw MarketTestFailure("\(viewModel.marketState)")
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
            throw MarketTestFailure("expected a stale reading before the refresh, got \(viewModel.marketState)")
        }

        await viewModel.refresh()

        #expect(viewModel.marketNotice == .unreachable(lastFetchedAt: nil))
        guard case .matched(let after) = viewModel.marketState else { throw MarketTestFailure("\(viewModel.marketState)") }
        #expect(after.reading == .stale(fetchedAt: t0), "the failure disturbed the reading (P8)")
    }

    @Test func theRateLimitSaysSoAndKeepsTheFigure() async throws {
        let world = try world()
        try seed(median: 140_000, at: t0.addingTimeInterval(-2 * 60 * minute), in: world)
        let viewModel = loaded(world, service: MarketServiceSpy(products: [.failure(.rateLimited)]))

        await viewModel.refresh()

        #expect(viewModel.marketNotice == .rateLimited)
        guard case .matched(let display) = viewModel.marketState, case .current(let figure) = display.reading else {
            throw MarketTestFailure("\(viewModel.marketState)")
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
            throw MarketTestFailure("\(viewModel.marketState)")
        }
        #expect(figure.medianCents == 140_000)
        #expect(try storedItem(world.item.id, in: world.container).reverbProductID == 126_161)
    }

    // MARK: - Use as estimated cost (criterion 8, Q15)

    /// The amount reaches the store whole, whatever it is handed: the value
    /// step rounds its default and every move already (T021), and this is
    /// the same rule one level out, for any caller of the intent.
    @Test func adoptWritesAWholeAmount() throws {
        let world = try world(costCents: 0)
        try seed(median: 139_950, at: t0.addingTimeInterval(-minute), in: world)
        let viewModel = loaded(world, now: t0.addingTimeInterval(day))

        #expect(viewModel.canAdopt)
        #expect(viewModel.adopt(cents: 139_950))
        #expect(viewModel.adoptFailureMessage == nil)
        #expect(!world.context.hasChanges, "adopt left unsaved changes behind")

        let stored = try storedItem(world.item.id, in: world.container)
        // The cents themselves, not the formatted line: two amounts a
        // display formatter rounds alike are not the same amount, and the
        // rounding this test is about is the one the store keeps.
        #expect(stored.estimatedCostCents == 140_000, "adopt wrote unrounded cents to the estimated cost")
    }

    /// Decision 35, and criterion 8's second half: the market's record of
    /// itself is untouched by what anyone adopts, and adopting reaches
    /// nothing.
    @Test func adoptStillWritesNoHistoryAndFetchesNothing() throws {
        let world = try world(costCents: 0)
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
        #expect(try storedItem(withheld.item.id, in: withheld.container).estimatedCostCents == 240_000)

        let stale = try world()
        try seed(median: 140_000, at: t0, in: stale)
        let b = loaded(stale, now: t0.addingTimeInterval(31 * day))
        #expect(!b.canAdopt)
        #expect(!b.adopt(cents: 140_000))
        #expect(try storedItem(stale.item.id, in: stale.container).estimatedCostCents == 240_000)
    }

    // MARK: - Matching, changing, unmatching

    @Test func removeMatchClearsTheItemAndTheStoreInOneSave() throws {
        let world = try world()
        try seed(median: 140_000, at: t0, in: world)
        let viewModel = loaded(world, now: t0.addingTimeInterval(day))

        viewModel.removeMatch()

        #expect(!world.context.hasChanges, "removeMatch left unsaved changes behind")
        #expect(viewModel.marketState == .unmatched)
        #expect(try storedItem(world.item.id, in: world.container).reverbProductID == nil)

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
        guard case .value = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }

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
        #expect(try storedItem(world.item.id, in: world.container).reverbProductID == 182_769)

        guard case .matched(let display) = viewModel.marketState else { throw MarketTestFailure("\(viewModel.marketState)") }
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
        let next = WishlistDetailViewModel(modelContext: ModelContext(world.container), itemID: world.item.id, marketService: spy, now: { self.t0 })
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
        guard case .value(let step) = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }
        #expect(step.medianCents == 149_999)
        #expect(step.chosenCents == 150_000, "the step didn't default to the whole-currency median")
        #expect(step.chosenCents == MarketAdoption.wholeCurrencyCents(from: 149_999))
        #expect(step.lowerCents == 120_000, "the slider's ends aren't the trimmed bounds")
        #expect(step.upperCents == 165_000)

        // The refresh a pick runs is a refresh: read on a second context.
        let elsewhere = ModelContext(world.container)
        let figure = try #require(try MarketLocalStore.figure(for: world.item.id, in: elsewhere))
        #expect(figure.medianCents == 149_999)
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
        guard case .value(let step) = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }
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
            throw MarketTestFailure("\(viewModel.marketState)")
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
        guard case .matched(let display) = viewModel.marketState else { throw MarketTestFailure("\(viewModel.marketState)") }
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
            throw MarketTestFailure("\(viewModel.marketState)")
        }
        #expect(figure.medianCents == 149_999, "the section didn't take the outcome that landed")
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
        guard case .value = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }
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
        guard case .value = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }
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
        guard case .value = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }
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

        guard case .value = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }
        #expect(viewModel.marketNotice == nil)
        #expect(viewModel.marketActivity == nil, "the pick's landing left the section busy")
        #expect(viewModel.canAdopt, "the pick's landing left the adopt button disabled")

        // The older refresh, failing, lands last and changes neither.
        gated.release(listingsCall: 1)
        await refreshing.value

        #expect(viewModel.marketNotice == nil, "the older refresh painted its failure over the pick")
        #expect(viewModel.marketActivity == nil)
        #expect(viewModel.canAdopt, "the older refresh disturbed what the pick left standing")
        guard case .value = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }
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

        guard case .value = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }
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
        let code = try SourceScan.production("Trove/ViewModels/WishlistDetailViewModel.swift")
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
        let world = try world(costCents: 0)
        try seedTrimmed(median: 139_999, low: 115_200, high: 325_000, p10: 120_000, p90: 169_900, at: t0.addingTimeInterval(-minute), in: world)
        let viewModel = loaded(world, service: MarketServiceSpy())

        viewModel.openValueStep()
        #expect(viewModel.isFindingMatch, "the section's adopt action opened nothing")
        guard case .value(let opened) = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }
        #expect(opened.chosenCents == 140_000, "the step didn't open on the whole-currency median")

        viewModel.setChosen(opened.upperCents)
        guard case .value(let moved) = viewModel.sheetStep else { throw MarketTestFailure("\(viewModel.sheetStep)") }
        #expect(moved.chosenCents == 169_900, "the view model didn't carry the slider's move")
        #expect(viewModel.adopt(cents: moved.chosenCents))

        let stored = try storedItem(world.item.id, in: world.container)
        #expect(stored.estimatedCostCents == 169_900, "the median was written instead of the amount chosen")
        #expect(stored.estimatedCostCents != 140_000)
        #expect(!viewModel.isFindingMatch, "the sheet stayed open after the write")
        #expect(viewModel.sheetStep == .pick)
    }

    /// Not now: the sheet closes and nothing is written (Decision 34).
    @Test func dismissingTheValueStepWritesNothing() throws {
        let world = try world(costCents: 0)
        try seedTrimmed(median: 139_999, low: 115_200, high: 325_000, p10: 120_000, p90: 169_900, at: t0.addingTimeInterval(-minute), in: world)
        let viewModel = loaded(world, service: MarketServiceSpy())

        viewModel.openValueStep()
        viewModel.setChosen(150_000)
        viewModel.dismissValueStep()

        #expect(!viewModel.isFindingMatch)
        #expect(viewModel.sheetStep == .pick)
        #expect(!world.context.hasChanges, "Not now left changes waiting to be saved")
        #expect(try storedItem(world.item.id, in: world.container).estimatedCostCents == 0)
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
        let code = try SourceScan.production("Trove/ViewModels/WishlistDetailViewModel.swift")
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
    private func openThePicker(_ viewModel: WishlistDetailViewModel) {
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
        try MarketLocalStore.record(.figure(figure), product: catalogProduct, for: MarketSubjectKey(subjectID: world.item.id, kind: .wanted), in: world.context)
        try world.context.save()
    }
}

private struct MarketTestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

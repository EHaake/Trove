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
/// `updatedAt` to bump (spec Decision 24). Every fetch goes through a spy,
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

    @Test func adoptWritesTheRoundedMedianAndChangesNothingElse() throws {
        let world = try world(costCents: 0)
        try seed(median: 139_950, at: t0.addingTimeInterval(-minute), in: world)
        let spy = MarketServiceSpy()
        let viewModel = loaded(world, now: t0.addingTimeInterval(day), service: spy)

        #expect(viewModel.canAdopt)
        #expect(viewModel.adopt())
        #expect(viewModel.adoptFailureMessage == nil)
        #expect(!world.context.hasChanges, "adopt left unsaved changes behind")

        let stored = try storedItem(world.item.id, in: world.container)
        #expect(stored.estimatedCostCents == 140_000)
        // The number written is the number the section showed — the display
        // formatter rounds half to even, and so does the adoption.
        #expect(MarketCopy.median(cents: stored.estimatedCostCents) == MarketCopy.median(cents: 139_950))

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
        #expect(try storedItem(withheld.item.id, in: withheld.container).estimatedCostCents == 240_000)

        let stale = try world()
        try seed(median: 140_000, at: t0, in: stale)
        let b = loaded(stale, now: t0.addingTimeInterval(31 * day))
        #expect(!b.canAdopt)
        #expect(!b.adopt())
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
    @Test func setMatchToADifferentProductClearsHistoryButTheSameProductDoesNot() throws {
        let world = try world()
        try seed(median: 140_000, at: t0, in: world)
        let viewModel = loaded(world, now: t0.addingTimeInterval(day))
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
        #expect(try storedItem(world.item.id, in: world.container).reverbProductID == 182_769)

        guard case .matched(let display) = viewModel.marketState else { throw MarketTestFailure("\(viewModel.marketState)") }
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
        let next = WishlistDetailViewModel(modelContext: ModelContext(world.container), itemID: world.item.id, marketService: spy, now: { self.t0 })
        next.load()
        next.findMatch()
        #expect(!next.noticeIsPending, "the notice came back on a new view model")
    }
}

private struct MarketTestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

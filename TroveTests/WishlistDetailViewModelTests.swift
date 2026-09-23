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

    // MARK: - The Sell Plan entry point (015 T012c)

    /// Nothing set aside: the button still names the task, in design's own
    /// words. The control for the three tests below it.
    @Test func theSellPlanEntryOffersTheSearchWhenNothingIsSetAside() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.hasSellPlan == false)
        #expect(viewModel.plannedSaleCount == 0)
        #expect(viewModel.sellPlanEntryTitle == "Find items to sell")
        #expect(viewModel.sellPlanEntrySubtitle == "Browse your lowest desire-to-keep items")
    }

    /// The person's decision at 015's walkthrough: a saved plan has to leave
    /// a trace on the page it was made from, which before this said "Find
    /// items to sell" whether or not anything had been chosen.
    ///
    /// The subtitle is a **count and nothing else**, deliberately — the
    /// entry point's rule (003, and the button's own doc comment) is that it
    /// names the task, not a target. Both items here carry a value, so a
    /// subtitle that had grown a money figure or a "$840 of $3,900" progress
    /// line would have one to show, and this equality refuses it.
    @Test func theSellPlanEntryNamesTheSavedPlanAndCountsWhatIsSetAside() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let first = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars", currentValueCents: 84_000)
        let second = Item(name: "Vox AC15", categoryPath: "Music/Amps", currentValueCents: 60_000)
        context.insert(first)
        context.insert(second)
        wanted.plannedSaleItems = [first, second]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.hasSellPlan)
        #expect(viewModel.plannedSaleCount == 2)
        #expect(viewModel.sellPlanEntryTitle == "View your sell plan")
        #expect(viewModel.sellPlanEntrySubtitle == "2 items set aside")
    }

    /// One item is "1 item", not "1 items" — pluralised inline, the shape
    /// `SaleCopy.sellPlanSoldCaption` uses, since the app has no
    /// pluralisation helper.
    @Test func theSellPlanEntryReadsSingularForOneItemSetAside() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let owned = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(owned)
        wanted.plannedSaleItems = [owned]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.plannedSaleCount == 1)
        #expect(viewModel.sellPlanEntrySubtitle == "1 item set aside")
    }

    /// Derived on every `load()`, not once: a plan emptied elsewhere — the
    /// Sell Plan itself, or a purchase releasing it — puts the search copy
    /// back the next time this screen loads, rather than leaving the page
    /// pointing at a plan that no longer holds anything.
    @Test func theSellPlanEntryGoesBackToTheSearchWhenThePlanIsReleased() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let owned = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(owned)
        wanted.plannedSaleItems = [owned]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.sellPlanEntryTitle == "View your sell plan")

        wanted.plannedSaleItems = []
        try context.save()
        viewModel.load()

        #expect(viewModel.hasSellPlan == false)
        #expect(viewModel.plannedSaleCount == 0)
        #expect(viewModel.sellPlanEntryTitle == "Find items to sell")
        #expect(viewModel.sellPlanEntrySubtitle == "Browse your lowest desire-to-keep items")
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

// MARK: - 015/T006: the three hosts' purchase intents

/// G12, G13, G19 (015 plan §6, Q10, R2; criterion 4). Three screens can open
/// the purchase sheet — a Wishlist row, this page, and the Sell Plan — and
/// criterion 4 says all three open *one* sheet, seeded identically. These
/// guards sit together in one suite rather than one per host file, because
/// every claim here is a claim about the three agreeing: split across three
/// files, each half would pass on its own while the pair disagreed.
///
/// 009 (plan §5, G13) adds a fourth host, the Plans tab's active rows. It
/// takes its subject from its rows, so every fixture entry below that it
/// buys carries a plan.
@Suite("Marking a wanted entry bought — the four hosts")
struct WishlistPurchaseHostTests {
    private let now = Date(timeIntervalSince1970: 1_783_000_000)
    private let boughtOn = Date(timeIntervalSince1970: 1_781_234_567)
    /// The fixture plans' date — distinct from `now` and `boughtOn`, so a host
    /// that re-stamped the plan at purchase would show.
    private let plannedOn = Date(timeIntervalSince1970: 1_779_876_543)

    /// A wanted entry carrying something in every field the purchase moves
    /// across, so the landing comparison below can tell a host that dropped
    /// one from a host that carried it.
    @discardableResult
    private func insertWanted(
        _ name: String,
        category: String = "Photography/Lenses",
        costCents: Int,
        into context: ModelContext
    ) -> WishlistItem {
        let wanted = WishlistItem(
            name: name,
            categoryPath: category,
            estimatedCostCents: costCents,
            currencyCode: "CAD",
            notes: "Chrome, not black",
            // 1, never 3: `Item.init` defaults `desireToKeep` to 3, so a
            // fixture rated 3 could not tell P5's "left at the default" from
            // a store that carried the wanting scale across.
            desireToOwn: 1,
            sortOrder: 7,
            reverbProductID: 9_112,
            year: 1971
        )
        context.insert(wanted)
        return wanted
    }

    /// The purchase every landing test records. None of its four values is a
    /// default, and none coincides with a neighbouring field a broken host
    /// might grab instead: the price is not the estimate, the date is not
    /// `now`, the place is a real string rather than nil, and the condition
    /// is not `Item.init`'s `.excellent`.
    private var purchase: Purchase {
        Purchase(date: boughtOn, priceCents: 219_500, location: "Kerrisdale Cameras", condition: .good)
    }

    // MARK: G12 — one seed, three hosts

    /// G12 (criterion 4): for the same entry and the same clock, the Wishlist
    /// row's sheet, this page's, and the Sell Plan's are seeded identically.
    ///
    /// Both an entry that carries an estimate and one that doesn't: agreeing
    /// on the estimated entry alone would leave a host free to seed a $0
    /// price where the others leave the field blank — the one distinction the
    /// `006` P1 rule rests on, and the one a `?? 0` slipped into any host
    /// would break.
    @Test func everyHostSeedsThePurchaseSheetIdentically() throws {
        let context = try makeInMemoryContext()
        let estimated = insertWanted("Summicron 35mm f/2", costCents: 240_000, into: context)
        let unestimated = insertWanted("Vox AC15 Custom", category: "Music/Amps", costCents: 0, into: context)
        // The Plans tab's subject is a row, and only a planned entry is one.
        SellPlanStore.create(for: estimated, at: plannedOn)
        SellPlanStore.create(for: unestimated, at: plannedOn)
        try context.save()

        let list = WishlistViewModel(modelContext: context, now: { self.now })
        list.load()
        let plans = PlansViewModel(modelContext: context, now: { self.now })
        plans.load()

        for subject in [estimated, unestimated] {
            let page = WishlistDetailViewModel(modelContext: context, itemID: subject.id, now: { self.now })
            page.load()
            let fromPage = page.makePurchaseFormViewModel()

            let row = try #require(
                list.items.first { $0.id == subject.id },
                "\(subject.name) must be a Wishlist row for the comparison to mean anything"
            )
            let fromList = list.makePurchaseFormViewModel(for: row)

            let plan = SellPlanViewModel(modelContext: context, wishlistItemID: subject.id, now: { self.now })
            plan.load()
            let fromPlan = plan.makePurchaseFormViewModel()

            let planRow = try #require(
                plans.activeRows.first { $0.id == subject.id },
                "\(subject.name) must be an active Plans row for the comparison to mean anything"
            )
            let fromPlans = plans.makePurchaseFormViewModel(for: planRow)

            // The comparison is over what a host can actually influence. All
            // three return the one `PurchaseFormViewModel`, whose `title` and
            // `confirmLabel` are get-only constants — comparing those across
            // hosts cannot fail for any reason, so it isn't done here; the
            // copy is `PurchaseCopyTests`' and `PurchaseFormViewModelTests`'
            // to pin. `location` and `condition` are `var`s a host could set
            // after construction, which is a divergence criterion 4 forbids,
            // so they stay.
            for (host, form) in [("the list", fromList), ("the plan", fromPlan), ("the Plans tab", fromPlans)] {
                #expect(fromPage.price == form.price, "\(subject.name): the page and \(host) seed the same price")
                #expect(fromPage.date == form.date, "\(subject.name): the page and \(host) seed the same date")
                #expect(fromPage.location == form.location)
                #expect(fromPage.condition == form.condition)
                #expect(
                    fromPage.comparisonLine == form.comparisonLine,
                    "\(subject.name): the page and \(host) compare against the same estimate"
                )
            }
        }

        // Pinned, so three hosts agreeing on the wrong thing still fails.
        // $2,400 rather than the cents, today rather than the entry's own
        // dates, and — the P1 distinction — nil rather than 0.
        let estimatedRow = try #require(list.items.first { $0.id == estimated.id })
        #expect(list.makePurchaseFormViewModel(for: estimatedRow).price == Decimal(string: "2400"))
        #expect(list.makePurchaseFormViewModel(for: estimatedRow).date == now)
        let unestimatedRow = try #require(list.items.first { $0.id == unestimated.id })
        #expect(
            list.makePurchaseFormViewModel(for: unestimatedRow).price == nil,
            "no estimate means a blank field, never $0"
        )
        #expect(unestimated.estimatedCostCents == 0, "the fixture must actually have no estimate")
    }

    // MARK: G12 — one landing, three hosts

    /// Everything a purchase leaves behind, read off a **second** context so
    /// only what reached the store is counted.
    private struct Landing: Equatable, CustomStringConvertible {
        var itemCount: Int
        var name: String
        var categoryPath: String
        var purchasePriceCents: Int
        var purchaseDate: Date
        var purchaseLocation: String?
        var currentValueCents: Int?
        var condition: Condition
        var currencyCode: String
        var notes: String?
        var reverbProductID: Int?
        var year: Int?
        var desireToKeep: Int
        /// The photos' `sortOrder`s, in display order — a count and a
        /// numbering, not an identity. Which photos landed is G6's, in
        /// `WishlistPurchaseStoreTests`; this field only has to diverge when
        /// one host moves a different number of them or numbers them
        /// differently.
        var itemPhotoSortOrders: [Int]
        var boughtDate: Date?
        var wishlistPhotoCount: Int
        var plannedSaleCount: Int
        /// 009, criterion 3: the plan survives the purchase whichever host
        /// made it — that is what puts it on the Completed side.
        var sellPlanCreatedAt: Date?

        var description: String { "\(name) @ \(purchasePriceCents), bought \(String(describing: boughtDate))" }
    }

    private func landing(in container: ModelContainer) throws -> Landing {
        // A second context: `ModelContext.fetch` hands back objects carrying
        // unsaved changes, so a same-context refetch would pass whether or
        // not the host saved.
        let elsewhere = ModelContext(container)
        let items = try elsewhere.fetch(FetchDescriptor<Item>())
        // By name, never `first`: `FetchDescriptor` promises no order, and the
        // plan's candidate is an `Item` in this store too.
        let item = try #require(
            items.first { $0.name == "Summicron 35mm f/2" },
            "the purchase must have reached the store"
        )
        let wanted = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        return Landing(
            itemCount: items.count,
            name: item.name,
            categoryPath: item.categoryPath,
            purchasePriceCents: item.purchasePriceCents,
            purchaseDate: item.purchaseDate,
            purchaseLocation: item.purchaseLocation,
            currentValueCents: item.currentValueCents,
            condition: item.condition,
            currencyCode: item.currencyCode,
            notes: item.notes,
            reverbProductID: item.reverbProductID,
            year: item.year,
            desireToKeep: item.desireToKeep,
            itemPhotoSortOrders: PhotoSelection.inDisplayOrder(item.photos ?? []).map(\.sortOrder),
            boughtDate: wanted.boughtDate,
            wishlistPhotoCount: (wanted.photos ?? []).count,
            plannedSaleCount: (wanted.plannedSaleItems ?? []).count,
            sellPlanCreatedAt: wanted.sellPlanCreatedAt
        )
    }

    /// The fixture each host buys: one wanted entry with two photos and a
    /// candidate already on its plan, plus the owned item that candidate is.
    private func seedWorld() throws -> (container: ModelContainer, context: ModelContext, wanted: WishlistItem) {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let wanted = insertWanted("Summicron 35mm f/2", costCents: 240_000, into: context)
        let photos = [
            Photo(imageData: Data([0x01]), source: .device, sortOrder: 0),
            Photo(imageData: Data([0x02]), source: .device, sortOrder: 1),
        ]
        for photo in photos { context.insert(photo) }
        wanted.photos = photos
        let candidate = Item(
            name: "Nikon F3",
            categoryPath: "Photography/Cameras",
            purchasePriceCents: 40_000,
            currentValueCents: 55_000,
            desireToKeep: 1
        )
        context.insert(candidate)
        wanted.plannedSaleItems = [candidate]
        // 009: a plan on every host's fixture, since the fourth host can only
        // buy a planned entry and the comparison needs one fixture for all.
        SellPlanStore.create(for: wanted, at: plannedOn)
        try context.save()
        return (container, context, wanted)
    }

    /// G12's second half: a purchase made through any of the three hosts
    /// leaves the *same* item and the *same* marker in the store. The
    /// comparison is what matters — a host on a different clock, or one that
    /// never saved, diverges here even though its own screen looked right.
    @Test func aPurchaseThroughAnyHostLandsIdentically() throws {
        let viaList = try seedWorld()
        let list = WishlistViewModel(modelContext: viaList.context, now: { self.now })
        list.load()
        let row = try #require(list.items.first)
        #expect(list.markBought(row, purchase: purchase))

        let viaPage = try seedWorld()
        let page = WishlistDetailViewModel(modelContext: viaPage.context, itemID: viaPage.wanted.id, now: { self.now })
        page.load()
        #expect(page.markBought(purchase: purchase))

        let viaPlan = try seedWorld()
        let plan = SellPlanViewModel(modelContext: viaPlan.context, wishlistItemID: viaPlan.wanted.id, now: { self.now })
        plan.load()
        #expect(plan.markBought(purchase: purchase))

        // 009, criterion 14: confirming moves the row from Active to Completed.
        let viaPlans = try seedWorld()
        let plans = PlansViewModel(modelContext: viaPlans.context, now: { self.now })
        plans.load()
        let planRow = try #require(plans.activeRows.first)
        #expect(plans.markBought(planRow, purchase: purchase))
        #expect(plans.activeRows.isEmpty, "the bought plan leaves Active")
        #expect(plans.completedRows.map(\.id) == [viaPlans.wanted.id], "and lands on Completed")

        let fromList = try landing(in: viaList.container)
        let fromPage = try landing(in: viaPage.container)
        let fromPlan = try landing(in: viaPlan.container)
        let fromPlans = try landing(in: viaPlans.container)
        #expect(fromList == fromPage, "the Wishlist row and the page must leave the same thing")
        #expect(fromList == fromPlan, "the Wishlist row and the Sell Plan must leave the same thing")
        #expect(fromList == fromPlans, "the Wishlist row and the Plans tab must leave the same thing")

        // Pinned, so three hosts landing the same wrong thing still fails.
        // Each value differs from the default and from the neighbouring field
        // a broken store would reach for.
        #expect(fromList.itemCount == 2, "the purchase adds one item beside the plan's candidate")
        #expect(fromList.name == "Summicron 35mm f/2")
        #expect(fromList.purchasePriceCents == 219_500, "what was paid, not the 240,000 estimate")
        #expect(fromList.currentValueCents == 219_500, "P4: worth what it cost, on the day it arrived")
        #expect(fromList.purchaseDate == boughtOn, "the date entered, not the marker's clock")
        #expect(fromList.boughtDate == now, "the marker's clock, not the date entered")
        #expect(fromList.condition == .good, "the condition entered, not Item.init's .excellent")
        #expect(fromList.purchaseLocation == "Kerrisdale Cameras")
        #expect(fromList.currencyCode == "CAD", "the entry's currency, not the USD default")
        #expect(fromList.notes == "Chrome, not black")
        #expect(fromList.reverbProductID == 9_112)
        #expect(fromList.year == 1971)
        #expect(fromList.desireToKeep == 3, "P5: left at Item.init's own default, never carried across")
        #expect(fromList.itemPhotoSortOrders == [0, 1], "both photos moved across, renumbered from zero")
        #expect(fromList.wishlistPhotoCount == 0, "moved, never copied")
        #expect(fromList.plannedSaleCount == 0, "P6: nothing is earmarked toward a purchase that has happened")
        #expect(fromList.sellPlanCreatedAt == plannedOn, "the plan survives the purchase, on its own date")
    }

    /// 009, criterion 3: a purchase through any host leaves a planless entry
    /// planless — no host makes a plan by buying — so it shows on neither
    /// side of the Plans tab. The Plans tab cannot reach a planless entry at
    /// all: handed a row for one, it refuses, says so, and writes nothing.
    @Test func aPurchaseThroughAnyHostLeavesAPlanlessEntryPlanless() throws {
        func planlessWorld() throws -> (container: ModelContainer, context: ModelContext, wanted: WishlistItem) {
            let container = try makeInMemoryContainer()
            let context = ModelContext(container)
            let wanted = insertWanted("Summicron 35mm f/2", costCents: 240_000, into: context)
            try context.save()
            return (container, context, wanted)
        }

        let viaList = try planlessWorld()
        let list = WishlistViewModel(modelContext: viaList.context, now: { self.now })
        list.load()
        #expect(list.markBought(try #require(list.items.first), purchase: purchase))

        let viaPage = try planlessWorld()
        let page = WishlistDetailViewModel(modelContext: viaPage.context, itemID: viaPage.wanted.id, now: { self.now })
        page.load()
        #expect(page.markBought(purchase: purchase))

        let viaPlan = try planlessWorld()
        let plan = SellPlanViewModel(modelContext: viaPlan.context, wishlistItemID: viaPlan.wanted.id, now: { self.now })
        plan.load()
        #expect(plan.markBought(purchase: purchase))

        for (host, world) in [("the list", viaList), ("the page", viaPage), ("the plan", viaPlan)] {
            let elsewhere = ModelContext(world.container)
            let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
            #expect(entry.boughtDate == now, "\(host): the purchase reached the store")
            #expect(entry.sellPlanCreatedAt == nil, "\(host): buying made no plan")
            let tab = PlansViewModel(modelContext: elsewhere, now: { self.now })
            tab.load()
            #expect(tab.activeRows.isEmpty && tab.completedRows.isEmpty, "\(host): on neither side")
        }

        let viaPlans = try planlessWorld()
        let plans = PlansViewModel(modelContext: viaPlans.context, now: { self.now })
        plans.load()
        #expect(plans.activeRows.isEmpty, "a planless entry is no Plans row")
        let stray = PlansViewModel.PlanRow(
            id: viaPlans.wanted.id,
            name: viaPlans.wanted.name,
            categoryPath: viaPlans.wanted.categoryPath,
            photos: [],
            lines: [],
            boughtDate: nil,
            showsThumbnail: true
        )
        #expect(plans.markBought(stray, purchase: purchase) == false)
        #expect(plans.purchaseFailureMessage == PurchaseCopy.failureMessage, "a refusal is never silent")
        let elsewhere = ModelContext(viaPlans.container)
        #expect(try elsewhere.fetch(FetchDescriptor<Item>()).isEmpty, "the Plans tab wrote no item")
        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(entry.boughtDate == nil)
        #expect(entry.sellPlanCreatedAt == nil)
    }

    // MARK: G13 — the refused save

    /// G13, rewritten at T012b: the three hosts' failure path, structurally.
    /// The shape `ItemDetailViewModelTests.aRefusedSaveRollsBackAndReReadsWhatIsStored`
    /// uses, and for the same reason — an in-memory `save()` can't be made to
    /// throw on demand and no `SaveFailingContext` exists in this tree, so the
    /// rollback, the single save and the ordering are things no view-model
    /// test in this suite can observe.
    ///
    /// **What it no longer scans is the message**: which property a host
    /// reports in, and which of the two sentences it picks, is now reachable
    /// by calling `markBought` twice, and
    /// `everyHostRefusesToBuyAnEntryTwice` below asserts it behaviourally.
    /// `CLAUDE.md`'s rule is that a scan never pins a behaviour a view-model
    /// test could reach instead.
    ///
    /// **The rule the ordering pins changed too.** It used to be per-host:
    /// the Wishlist reported into `loadFailureMessage`, which its own
    /// `load()` clears, so its message had to be set *after* the reload while
    /// the other two set theirs before it. T012b gave all three a
    /// `purchaseFailureMessage` of their own, which no host's `load()`
    /// touches — so the rule is now that there is no per-host rule: one
    /// ordering everywhere, and the property is cleared on entry so a
    /// previous refusal can't be shown again. That last half is behavioural
    /// too (`aSecondPurchaseAfterARefusedOneClearsTheMessage`); what is
    /// scanned here is that no `load()` and no neighbouring intent writes the
    /// property, which is the invariant making the single ordering safe and
    /// which no test can see from outside.
    ///
    /// Mutations: drop the `rollback()` → red; set the message after the
    /// reload → red; clear `purchaseFailureMessage` in any host's `load()`
    /// → red; report into the property beside it → red (here and, for the
    /// message itself, behaviourally below).
    @Test func aRefusedPurchaseRollsBackAndReportsInItsHostsOwnProperty() throws {
        // (file, signature, the properties this host must leave alone)
        let intents: [(String, String, [String])] = [
            (
                "Trove/ViewModels/WishlistViewModel.swift",
                "func markBought(_ wanted: WishlistItem, purchase: Purchase) -> Bool",
                ["loadFailureMessage"]
            ),
            (
                "Trove/ViewModels/WishlistDetailViewModel.swift",
                "func markBought(purchase: Purchase) -> Bool",
                ["deleteFailureMessage"]
            ),
            (
                "Trove/ViewModels/SellPlanViewModel.swift",
                "func markBought(purchase: Purchase) -> Bool",
                ["loadFailureMessage", "saveFailureMessage"]
            ),
        ]
        for (path, signature, foreignProperties) in intents {
            let code = try SourceScan.production(path)
            let bodies = SourceScan.closureBodies(after: signature, in: code)
            try #require(bodies.count == 1, "expected exactly one \(signature) in \(path)")
            let body = bodies[0]
            #expect(body.ranges(of: "modelContext.save()").count == 1, "\(signature) must save exactly once")
            #expect(
                body.contains("WishlistPurchaseStore.markBought("),
                "\(signature) must go through the one writer (plan Q4)"
            )

            let catches = SourceScan.closureBodies(after: "} catch", in: body)
            try #require(catches.count == 1, "expected exactly one catch block in \(signature)")
            let recovery = catches[0]
            #expect(recovery.contains("modelContext.rollback()"), "\(signature): the refused save must roll the context back")
            #expect(recovery.contains("load()"), "\(signature): the refused save must re-read what is stored")
            #expect(recovery.contains("return false"), "\(signature): the refused save must answer false")

            let rollback = try #require(recovery.range(of: "modelContext.rollback()"), "\(signature)")
            let reload = try #require(recovery.range(of: "load()"), "\(signature)")
            let message = try #require(
                recovery.range(of: "purchaseFailureMessage ="),
                "\(signature): the refused save must report itself in purchaseFailureMessage"
            )
            #expect(rollback.lowerBound < message.lowerBound, "\(signature): the rollback comes first")
            #expect(
                message.lowerBound < reload.lowerBound,
                "\(signature): the message is set straight after the rollback, one ordering for all three hosts since T012b"
            )

            // T012b: the purchase intent touches no other host's failure
            // property. The Sell Plan's `saveFailureMessage` is the one that
            // matters most — sharing it would show a refused *sale* in the
            // purchase alert, which this spec's non-goals rule out.
            for property in foreignProperties {
                #expect(
                    !body.contains(property),
                    "\(signature): a refused purchase writes \(property), which belongs to the intent beside it"
                )
            }

            // And the other way round: nothing else *in this view model*
            // clears the purchase's own property, which is what lets every
            // host set the message before its reload rather than after it.
            // Scoped to the view-model file on purpose — the three views'
            // alert bindings legitimately write `purchaseFailureMessage =
            // nil` on OK, and this scan says nothing about them.
            let outsideMarkBought = code.replacingOccurrences(of: body, with: "")
            #expect(
                !outsideMarkBought.contains("purchaseFailureMessage ="),
                "\(path): something other than markBought in this view model writes purchaseFailureMessage — if it is load(), the message is wiped before the alert can read it"
            )

            let outsideCatch = recovery.isEmpty ? body : body.replacingOccurrences(of: recovery, with: "")
            #expect(!outsideCatch.contains("rollback()"), "\(signature): rollback belongs to the failure path only")
        }
    }

    // MARK: B1 — an entry is bought once

    /// **T006a/B1.** A second purchase of the same entry is refused by the
    /// one writer, so no host can produce one.
    ///
    /// Two windows make this reachable rather than theoretical. R2's
    /// mechanism is `WishlistDetailView`'s `.onAppear`, which fires on push
    /// and on return from a pushed screen — not when the marker arrives from
    /// another device while the page sits in the foreground (criterion 12).
    /// And `SellPlanViewModel.markBought` deliberately does not reload on
    /// success (§6), so its subject and its button stay live while the screen
    /// dismisses. Neither is a view bug a view can fix, which is why the
    /// guard is in the store.
    ///
    /// What a missing guard costs is both halves of this test: a **second
    /// `Item`** built from the name, category, notes, match and year still
    /// sitting on the entry, and a **re-stamped `boughtDate`** that destroys
    /// the first purchase's date. Decision 5 leaves no undo for either.
    ///
    /// Thrown, never `precondition`ed, so this can be a behavioural test at
    /// all — see `PurchaseError`.
    @Test func anEntryCanOnlyBeBoughtOnce() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let wanted = insertWanted("Summicron 35mm f/2", costCents: 240_000, into: context)
        try context.save()

        try WishlistPurchaseStore.markBought(wanted, purchase: purchase, at: now, in: context)
        try context.save()

        // A second purchase, a day later and at a different price, so a
        // re-stamped marker or a second item would be unmistakable.
        let later = now.addingTimeInterval(86_400)
        let second = Purchase(date: later, priceCents: 111_100, location: "Craigslist", condition: .fair)
        #expect(throws: WishlistPurchaseStore.PurchaseError.alreadyBought) {
            try WishlistPurchaseStore.markBought(wanted, purchase: second, at: later, in: context)
        }
        try context.save()

        let elsewhere = ModelContext(container)
        let items = try elsewhere.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1, "a second purchase must not insert a second item")
        #expect(items.first?.purchasePriceCents == 219_500, "and the first purchase's price stands")
        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(entry.boughtDate == now, "the original marker survives — Decision 5 leaves no undo to restore it with")
    }

    /// The same refusal reaching each of the three hosts, which is where a
    /// person actually taps. None of them writes anything, each rolls the
    /// context back, each answers false — so a view wired to the outcome
    /// cannot dismiss on a refusal — and, since T012b, each leaves
    /// `PurchaseCopy.alreadyBought` in its own `purchaseFailureMessage`,
    /// which is the sentence the alert on that screen reads.
    ///
    /// **The message is checked here rather than by a source scan on
    /// purpose**: what a host reports, and which of the two refusals it
    /// picks, is a behaviour this suite reaches by calling `markBought`
    /// twice, and `CLAUDE.md` keeps scans for the things it can't reach.
    /// The properties beside it are asserted still nil, so a host reporting
    /// into the list's `loadFailureMessage`, the page's
    /// `deleteFailureMessage` or the plan's `saveFailureMessage` — the last
    /// of which would surface a refused *sale* through a purchase alert —
    /// fails here.
    ///
    /// Mutations: map `.alreadyBought` to `PurchaseCopy.failureMessage` in
    /// any host → red; report into the property beside it → red.
    @Test func everyHostRefusesToBuyAnEntryTwice() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let wanted = insertWanted("Summicron 35mm f/2", costCents: 240_000, into: context)
        SellPlanStore.create(for: wanted, at: plannedOn)
        try context.save()

        // A day on from the first purchase, so a host that re-stamped the
        // marker would be stamping a *different* instant — with all four
        // clocks equal, the surviving-marker assertion below could not fail.
        let later = now.addingTimeInterval(86_400)

        // The hosts are built *before* the purchase, the way they are on a
        // device when the marker arrives from elsewhere: each is holding the
        // entry as still-wanted.
        let list = WishlistViewModel(modelContext: context, now: { later })
        list.load()
        let row = try #require(list.items.first)
        let page = WishlistDetailViewModel(modelContext: context, itemID: wanted.id, now: { later })
        page.load()
        let plan = SellPlanViewModel(modelContext: context, wishlistItemID: wanted.id, now: { later })
        plan.load()
        let plans = PlansViewModel(modelContext: context, now: { later })
        plans.load()
        let planRow = try #require(plans.activeRows.first)

        try WishlistPurchaseStore.markBought(wanted, purchase: purchase, at: now, in: context)
        try context.save()

        let second = Purchase(date: later, priceCents: 111_100, location: "Craigslist", condition: .fair)
        #expect(list.markBought(row, purchase: second) == false)
        #expect(
            list.purchaseFailureMessage == PurchaseCopy.alreadyBought,
            "the Wishlist tells the person the entry was already bought, in its own property — the one its load() does not clear, since the sheet's dismissal reloads"
        )
        #expect(list.loadFailureMessage == nil, "and not in the property load() clears, where it could never be read")

        #expect(page.markBought(purchase: second) == false)
        #expect(page.purchaseFailureMessage == PurchaseCopy.alreadyBought, "the page says the same thing in its own purchase property")
        #expect(page.deleteFailureMessage == nil, "and not in the one delete() clears")

        #expect(plan.markBought(purchase: second) == false)
        #expect(plan.purchaseFailureMessage == PurchaseCopy.alreadyBought, "the Sell Plan says it too, in a property of its own")
        #expect(
            plan.saveFailureMessage == nil,
            "and never in markSold's, which its purchase alert would then read — a refused sale surfacing as a refused purchase"
        )

        #expect(plans.markBought(planRow, purchase: second) == false)
        #expect(plans.purchaseFailureMessage == PurchaseCopy.alreadyBought, "the Plans tab says it too, in its own property")

        let elsewhere = ModelContext(container)
        let items = try elsewhere.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1, "four refused taps leave the one item the first purchase made")
        #expect(items.map(\.purchasePriceCents) == [219_500], "at the first purchase's price, not the second's")
        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(entry.boughtDate == now, "and the original marker, four times over")
    }

    /// The other half of T012b's message rule, and the reason every host
    /// clears `purchaseFailureMessage` on entry: a refusal the person has
    /// already read must not be waiting on the *next* purchase. The Wishlist
    /// is the host that can show it — it stays on screen after a refusal and
    /// its next row is a different entry — and its sheet reloads on dismiss,
    /// so the property has to survive the reload without surviving the
    /// intent.
    ///
    /// Mutation: drop `purchaseFailureMessage = nil` from the top of
    /// `WishlistViewModel.markBought` → the second purchase succeeds with
    /// the first one's alert still pending, and this goes red.
    @Test func aSecondPurchaseAfterARefusedOneClearsTheMessage() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let boughtElsewhere = insertWanted("Summicron 35mm f/2", costCents: 240_000, into: context)
        insertWanted("Vox AC15 Custom", category: "Music/Amps", costCents: 90_000, into: context)
        try context.save()

        let list = WishlistViewModel(modelContext: context, now: { self.now })
        list.load()
        let refused = try #require(list.items.first { $0.name == "Summicron 35mm f/2" })

        // The marker lands from another device while the list sits open.
        try WishlistPurchaseStore.markBought(boughtElsewhere, purchase: purchase, at: boughtOn, in: context)
        try context.save()

        #expect(list.markBought(refused, purchase: purchase) == false)
        #expect(list.purchaseFailureMessage == PurchaseCopy.alreadyBought, "the refusal the person reads")

        let stillWanted = try #require(list.items.first { $0.name == "Vox AC15 Custom" })
        #expect(list.markBought(stillWanted, purchase: purchase))
        #expect(
            list.purchaseFailureMessage == nil,
            "a purchase that took leaves no alert pending — the second sheet would open onto the first one's refusal"
        )

        let elsewhere = ModelContext(container)
        let items = try elsewhere.fetch(FetchDescriptor<Item>())
        #expect(items.map(\.name).sorted() == ["Summicron 35mm f/2", "Vox AC15 Custom"], "the refusal wrote nothing; the purchase after it did")
    }

    // MARK: G19 — the page gets out of the way

    /// **T006a/S6.** The page's subject is the entry it loaded, so a page
    /// whose entry was deleted on another device while it sat open writes
    /// nothing rather than buying whatever it can find. The sibling of
    /// `SellPlanPurchaseTests.aPurchaseWithNoEntryLoadedWritesNothing`, and
    /// the host whose guard can actually fire in practice.
    ///
    /// **And says so (T012e).** This path used to return false with
    /// `purchaseFailureMessage` just cleared, so confirming closed the sheet
    /// and reported nothing — the silent refusal T012b existed to remove,
    /// surviving on the one path T012b didn't reach.
    /// `PurchaseCopy.failureMessage` rather than `alreadyBought`: the entry
    /// is gone, not bought, and "Nothing was changed" is true because the
    /// guard returns ahead of every write — which the two store assertions
    /// below check for real.
    ///
    /// Mutation: restore `guard let item else { return false }` → the
    /// message is nil and this goes red.
    @Test func aPurchaseFromAPageHoldingNothingWritesNothing() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        insertWanted("Summicron 35mm f/2", costCents: 240_000, into: context)
        try context.save()

        let page = WishlistDetailViewModel(modelContext: context, itemID: UUID(), now: { self.now })
        page.load()
        #expect(page.item == nil, "the fixture must actually leave the page holding nothing")
        #expect(page.markBought(purchase: purchase) == false)
        #expect(
            page.purchaseFailureMessage == PurchaseCopy.failureMessage,
            "a confirm that can't find its entry must say so — closing the sheet in silence is the state T012b removed everywhere else"
        )

        let elsewhere = ModelContext(container)
        #expect(try elsewhere.fetch(FetchDescriptor<Item>()).isEmpty, "no item is created")
        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(entry.boughtDate == nil, "and the entry on screen elsewhere is untouched")
    }

    /// G19 (R2): the page knows its entry has been bought, so `.onAppear` can
    /// take it off the stack rather than offer to buy it again.
    @Test func hasBeenBoughtIsTrueOnlyForABoughtEntry() throws {
        let context = try makeInMemoryContext()
        let bought = insertWanted("Summicron 35mm f/2", costCents: 240_000, into: context)
        let stillWanted = insertWanted("Vox AC15 Custom", category: "Music/Amps", costCents: 90_000, into: context)
        try context.save()

        let untouched = WishlistDetailViewModel(modelContext: context, itemID: bought.id, now: { self.now })
        #expect(untouched.hasBeenBought == false, "nothing is known before load()")
        untouched.load()
        #expect(untouched.hasBeenBought == false, "a wanted entry is not bought")

        try WishlistPurchaseStore.markBought(bought, purchase: purchase, at: now, in: context)
        try context.save()

        let onTheBought = WishlistDetailViewModel(modelContext: context, itemID: bought.id, now: { self.now })
        onTheBought.load()
        #expect(onTheBought.hasBeenBought, "R2: this page must take itself off the stack")

        // The other entry is untouched, so the flag reads its *own* entry
        // rather than "something somewhere was bought".
        let onTheOther = WishlistDetailViewModel(modelContext: context, itemID: stillWanted.id, now: { self.now })
        onTheOther.load()
        #expect(onTheOther.hasBeenBought == false, "a second entry is not bought by the first entry's purchase")

        // And a page that did the buying itself learns it from its own reload.
        let buyer = WishlistDetailViewModel(modelContext: context, itemID: stillWanted.id, now: { self.now })
        buyer.load()
        #expect(buyer.markBought(purchase: purchase))
        #expect(buyer.hasBeenBought, "the successful purchase's reload sets the flag R2 reads")
    }
}

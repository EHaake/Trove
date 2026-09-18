import Foundation
import SwiftData
import Testing
@testable import Trove

private func insertItem(
    _ name: String,
    category: String = "Music/Guitars",
    desire: Int = 3,
    priceCents: Int = 0,
    valueCents: Int? = nil,
    serial: String? = nil,
    purchasedAt seconds: TimeInterval = 0,
    order: Int = 0,
    createdAt: TimeInterval? = nil,
    into context: ModelContext
) {
    let item = Item(
        name: name,
        categoryPath: category,
        purchasePriceCents: priceCents,
        purchaseDate: Date(timeIntervalSince1970: seconds),
        serialNumber: serial,
        currentValueCents: valueCents,
        desireToKeep: desire,
        sortOrder: order
    )
    if let createdAt {
        item.createdAt = Date(timeIntervalSince1970: createdAt)
    }
    context.insert(item)
}

@Suite("ItemListViewModel — loading and filtering")
struct ItemListViewModelFilterTests {
    @Test func startsEmptyBeforeLoading() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemListViewModel(modelContext: context)

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.isEmpty)
    }

    @Test func staysEmptyWhenThereAreNoItems() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemListViewModel(modelContext: context)

        viewModel.load()

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.isEmpty)
    }

    @Test func loadsEveryItemWhenNoFilterIsSet() throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", into: context)
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.items.count == 2)
        #expect(viewModel.isEmpty == false)
    }

    /// Prefix matching, per plan.md: filtering by a parent shows its children.
    @Test func filtersByCategoryPrefix() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        insertItem("Summicron 35", category: "Photography/Lenses", into: context)
        insertItem("Telecaster", category: "Music/Guitars", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.load()

        #expect(viewModel.items.count == 2)
        #expect(viewModel.items.allSatisfy { $0.categoryPath.hasPrefix("Photography") })
    }

    @Test(arguments: ["PHOTOGRAPHY", "photography", "PHOTOGRAPHY/CAMERAS", "photography/cameras"])
    func filtersCaseInsensitively(filter: String) throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = filter
        viewModel.load()

        #expect(viewModel.items.count == 1, "filter \(filter) matched nothing")
    }

    /// A chip's filter is always a category that exists, never something
    /// half-typed, so a partial segment shouldn't match. This used to: the
    /// filter shared the autocomplete rule, which meant selecting "Music/Amps"
    /// also pulled in "Music/Amplifiers".
    @Test func doesNotMatchAPartialSegment() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        insertItem("Blues Junior", category: "Music/Amplifiers", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography/Cam"
        viewModel.load()
        #expect(viewModel.items.isEmpty)

        viewModel.categoryFilter = "Music/Amps"
        viewModel.load()
        #expect(viewModel.items.isEmpty)
    }

    /// Prefix, not substring — a filter has to match from the start of the path.
    @Test func doesNotMatchMidPathSubstrings() throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", category: "Music/Guitars/Electric", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Guitars"
        viewModel.load()

        #expect(viewModel.items.isEmpty)
    }

    @Test func aFilterMatchingNothingYieldsAnEmptyList() throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", category: "Music/Guitars", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Audio"
        viewModel.load()

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.isEmpty)
    }

    @Test func clearingTheFilterRestoresEverything() throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", category: "Music/Guitars", into: context)
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Music"
        viewModel.load()
        #expect(viewModel.items.count == 1)

        viewModel.categoryFilter = ""
        viewModel.load()
        #expect(viewModel.items.count == 2)
    }

    @Test func reloadingPicksUpNewlyInsertedItems() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        #expect(viewModel.items.isEmpty)

        insertItem("Telecaster", into: context)
        try context.save()
        viewModel.load()

        #expect(viewModel.items.count == 1)
    }
}

@Suite("ItemListViewModel — search")
struct ItemListViewModelSearchTests {
    @Test func matchesOnName() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", into: context)
        insertItem("Telecaster", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = "leica"
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Leica M6"])
    }

    /// The other field Design's placeholder promises. A serial is the one
    /// thing you'd search for that isn't in the name.
    @Test func matchesOnSerialNumber() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", serial: "2842156", into: context)
        insertItem("Telecaster", serial: "US20114477", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = "201144"
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Telecaster"])
    }

    @Test func ignoresCase() throws {
        let context = try makeInMemoryContext()
        insertItem("Hasselblad 500C/M", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        for query in ["HASSELBLAD", "hasselblad", "HaSsElBlAd"] {
            viewModel.searchText = query
            viewModel.load()
            #expect(viewModel.items.count == 1, "query \(query) found nothing")
        }
    }

    @Test(arguments: ["", " ", "   "])
    func aBlankQueryLeavesTheListWhole(query: String) throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", into: context)
        insertItem("Telecaster", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = query
        viewModel.load()

        #expect(viewModel.items.count == 2)
    }

    /// The load-bearing one. spec.md says search and the category filter
    /// combine rather than replace, so this fails in both directions: the
    /// off-category match catches an accidental `||`, and the in-category
    /// non-match catches the search filter being dropped altogether.
    @Test func combinesWithTheCategoryFilterRatherThanReplacingIt() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        insertItem("Leicaphone", category: "Audio/Headphones", into: context)
        insertItem("Nikon FM2", category: "Photography/Cameras", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.searchText = "Leica"
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Leica M6"])
    }

    @Test func searchAndSortApplyTogether() throws {
        let context = try makeInMemoryContext()
        insertItem("Nikon 105mm", desire: 2, into: context)
        insertItem("Nikon FM2", desire: 5, into: context)
        insertItem("Telecaster", desire: 4, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = "nikon"
        viewModel.sortOrder = .desireToKeep
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Nikon FM2", "Nikon 105mm"])
    }

    /// Both controls narrow the same set, so the header figure has to follow
    /// the query too — a total counting rows that aren't on screen is worse
    /// than no total.
    @Test func theHeaderTotalFollowsTheQuery() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", valueCents: 345_000, into: context)
        insertItem("Telecaster", valueCents: 129_900, into: context)
        insertItem("Leica Q3", valueCents: nil, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = "leica"
        viewModel.load()

        #expect(viewModel.totalCurrentValueCents == 345_000)
        #expect(viewModel.unvaluedCount == 1)
    }

    /// The chips sit directly under the field. Typing a query that excludes a
    /// whole category must not make its chip vanish mid-keystroke.
    @Test func keepsEveryCategoryChipWhileSearching() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        insertItem("Telecaster", category: "Music/Guitars", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = "leica"
        viewModel.load()

        #expect(viewModel.items.count == 1)
        #expect(viewModel.categoryOptions == ["Music/Guitars", "Photography/Cameras"])
    }

    @Test func clearingTheQueryRestoresEverything() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", into: context)
        insertItem("Telecaster", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = "leica"
        viewModel.load()
        #expect(viewModel.items.count == 1)

        viewModel.searchText = ""
        viewModel.load()
        #expect(viewModel.items.count == 2)
    }

    @Test func aQueryMatchingNothingYieldsAnEmptyList() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = "hasselblad"
        viewModel.load()

        #expect(viewModel.items.isEmpty)
        #expect(viewModel.isEmpty)
    }

    /// Most items have no serial recorded. Searching must skip them rather
    /// than treating the absent field as a match for anything.
    @Test func itemsWithoutASerialAreSimplyNotMatchedByIt() throws {
        let context = try makeInMemoryContext()
        insertItem("No serial", serial: nil, into: context)
        insertItem("Has serial", serial: "ABC123", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = "ABC123"
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Has serial"])
    }
}

@Suite("ItemListViewModel — header figures")
struct ItemListViewModelSummaryTests {
    @Test func totalsOnlyTheItemsOnScreen() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica", category: "Photography/Cameras", valueCents: 345_000, into: context)
        insertItem("Telecaster", category: "Music/Guitars", valueCents: 129_900, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.load()

        #expect(viewModel.totalCurrentValueCents == 345_000)
    }

    /// Un-valued items aren't worth zero, they're unknown — the same rule the
    /// dashboard uses, so the two screens can't contradict each other.
    @Test func excludesUnvaluedItemsFromTheTotalAndCountsThemInstead() throws {
        let context = try makeInMemoryContext()
        insertItem("Valued", valueCents: 50_000, into: context)
        insertItem("Unvalued", valueCents: nil, into: context)
        insertItem("Also unvalued", valueCents: nil, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.totalCurrentValueCents == 50_000)
        #expect(viewModel.unvaluedCount == 2)
    }

    @Test func totalsNothingWhenTheListIsEmpty() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.totalCurrentValueCents == 0)
        #expect(viewModel.unvaluedCount == 0)
    }

    /// The chips have to keep offering every category, including ones the
    /// current filter excludes — otherwise picking one filter removes the
    /// means of picking another.
    @Test func offersEveryCategoryEvenWhileFiltered() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica", category: "Photography/Cameras", into: context)
        insertItem("Telecaster", category: "Music/Guitars", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.load()

        #expect(viewModel.items.count == 1)
        #expect(viewModel.categoryOptions == ["Music/Guitars", "Photography/Cameras"])
    }

    @Test func everySortOrderHasADistinctLabel() {
        let labels = ItemListViewModel.SortOrder.allCases.map(\.label)
        #expect(Set(labels).count == labels.count)
        #expect(labels.allSatisfy { !$0.isEmpty })
    }
}

@Suite("Item value delta")
struct ItemValueDeltaTests {
    @Test func isTheGainOverWhatWasPaid() {
        let item = Item(purchasePriceCents: 290_000, currentValueCents: 345_000)
        #expect(item.valueDeltaCents == 55_000)
    }

    @Test func isNegativeWhenWorthLessThanPaid() {
        let item = Item(purchasePriceCents: 69_000, currentValueCents: 54_000)
        #expect(item.valueDeltaCents == -15_000)
    }

    /// Unvalued is not break-even. A zero here would render as "±$0 vs paid",
    /// which claims something the user never said.
    @Test func isUnknownWhileTheItemIsUnvalued() {
        let item = Item(purchasePriceCents: 69_000, currentValueCents: nil)
        #expect(item.valueDeltaCents == nil)
    }

    @Test func splitsTheCategoryPathIntoSegments() {
        #expect(Item(categoryPath: "Music/Guitars/Electric").categorySegments == ["Music", "Guitars", "Electric"])
        #expect(Item(categoryPath: "Accessories").categorySegments == ["Accessories"])
        #expect(Item(categoryPath: "").categorySegments.isEmpty)
    }
}

@Suite("ItemListViewModel — sorting")
struct ItemListViewModelSortTests {
    @Test func defaultsToNewestPurchaseFirst() throws {
        let context = try makeInMemoryContext()
        insertItem("Older", purchasedAt: 1_000, into: context)
        insertItem("Newer", purchasedAt: 2_000, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.sortOrder == .purchaseDate)
        #expect(viewModel.items.map(\.name) == ["Newer", "Older"])
    }

    @Test func sortsByDesireToKeepWithKeepersFirst() throws {
        let context = try makeInMemoryContext()
        insertItem("Ready to sell", desire: 1, into: context)
        insertItem("Treasured", desire: 5, into: context)
        insertItem("Neutral", desire: 3, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .desireToKeep
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Treasured", "Neutral", "Ready to sell"])
    }

    @Test func sortsByCurrentValueWithMostValuableFirst() throws {
        let context = try makeInMemoryContext()
        insertItem("Cheap", valueCents: 5_000, into: context)
        insertItem("Dear", valueCents: 500_000, into: context)
        insertItem("Middling", valueCents: 50_000, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .currentValue
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Dear", "Middling", "Cheap"])
    }

    /// The ascending half of the Value pair (T033a) — and un-valued items
    /// stay last here too, rather than leading as the "cheapest": unknown
    /// isn't a low value any more than it was a zero.
    @Test func valueAscendingLeadsWithTheCheapestAndStillSinksUnvalued() throws {
        let context = try makeInMemoryContext()
        insertItem("Dear", valueCents: 500_000, into: context)
        insertItem("Unvalued", valueCents: nil, into: context)
        insertItem("Cheap", valueCents: 5_000, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .currentValueAscending
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Cheap", "Dear", "Unvalued"])
    }

    /// Un-valued isn't worth zero, it's unknown — so those items go last
    /// rather than sinking below the cheapest valued one.
    @Test func sortsUnvaluedItemsLast() throws {
        let context = try makeInMemoryContext()
        insertItem("Unvalued", valueCents: nil, into: context)
        insertItem("Cheap", valueCents: 1, into: context)
        insertItem("Dear", valueCents: 500_000, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .currentValue
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Dear", "Cheap", "Unvalued"])
    }

    /// Beneath a tied attribute *and* a shared manual position — the real
    /// state of a pre-`010` store, where every legacy item sits at 0 — the
    /// order is the order things were added. This floor is what replaced the
    /// launch-time backfill (close-out decision 1b): the same `createdAt`
    /// order the backfill used to write, read at sort time instead, with no
    /// migration write to race CloudKit sync on a second device. Names
    /// oppose creation order so a name-based floor fails here.
    @Test func unvaluedItemsAtASharedPositionFollowCreationOrder() throws {
        let context = try makeInMemoryContext()
        insertItem("Zither", valueCents: nil, order: 0, createdAt: 100, into: context)
        insertItem("Accordion", valueCents: nil, order: 0, createdAt: 200, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .currentValue
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Zither", "Accordion"])
    }

    /// The legacy store under "Custom" itself: all positions tied at 0, so
    /// the whole list rides the `createdAt` floor until the first drag
    /// renumbers it. Names oppose creation order here too.
    @Test func customSortOnAnUnbackfilledStoreFollowsCreationOrder() throws {
        let context = try makeInMemoryContext()
        insertItem("Charlie", order: 0, createdAt: 100, into: context)
        insertItem("Bravo", order: 0, createdAt: 200, into: context)
        insertItem("alpha", order: 0, createdAt: 300, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .custom
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Charlie", "Bravo", "alpha"])
    }

    /// Equal sort keys resolve by the user's own manual order — spec.md's
    /// confirmed tie-break, shared with the wishlist (2026-08-30 close-out;
    /// this replaced a name fallback and the test that pinned it). Names run
    /// *against* the manual order on purpose, so a name-based fallback fails
    /// here rather than passing by coincidence.
    @Test func desireTiesResolveByManualOrder() throws {
        let context = try makeInMemoryContext()
        insertItem("Charlie", desire: 3, order: 0, into: context)
        insertItem("alpha", desire: 3, order: 2, into: context)
        insertItem("Bravo", desire: 3, order: 1, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .desireToKeep
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Charlie", "Bravo", "alpha"])
    }

    /// The same rule where the tied attribute is *absence* — two un-valued
    /// items are a value tie, and their relative order is the user's
    /// arrangement, not the alphabet. Names oppose the manual order here too.
    @Test func valueTiesAmongUnvaluedItemsResolveByManualOrder() throws {
        let context = try makeInMemoryContext()
        insertItem("Accordion", valueCents: nil, order: 1, into: context)
        insertItem("Zither", valueCents: nil, order: 0, into: context)
        insertItem("Valued", valueCents: 100_00, order: 2, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .currentValue
        viewModel.load()

        // The valued item leads regardless of its manual position; the
        // un-valued pair follows in manual order.
        #expect(viewModel.items.map(\.name) == ["Valued", "Zither", "Accordion"])
    }

    @Test func repeatedLoadsProduceTheSameOrder() throws {
        let context = try makeInMemoryContext()
        for index in 0..<8 {
            insertItem("Item \(index)", desire: 3, purchasedAt: 1_000, into: context)
        }
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        let first = viewModel.items.map(\.name)
        viewModel.load()
        let second = viewModel.items.map(\.name)

        #expect(first == second)
    }

    @Test func changingSortOrderReordersOnTheNextLoad() throws {
        let context = try makeInMemoryContext()
        insertItem("Old favourite", desire: 5, purchasedAt: 1_000, into: context)
        insertItem("New castoff", desire: 1, purchasedAt: 9_000, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        #expect(viewModel.items.map(\.name) == ["New castoff", "Old favourite"])

        viewModel.sortOrder = .desireToKeep
        viewModel.load()
        #expect(viewModel.items.map(\.name) == ["Old favourite", "New castoff"])
    }

    @Test func filteringAndSortingApplyTogether() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", desire: 5, into: context)
        insertItem("Nikon FM2", category: "Photography/Cameras", desire: 1, into: context)
        insertItem("Telecaster", category: "Music/Guitars", desire: 4, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.sortOrder = .desireToKeep
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Leica M6", "Nikon FM2"])
    }
}

/// The Market sort and the row's trend (002/T012, spec criteria 13–14,
/// Decision 21) — the mirror of `WishlistMarketSortTests`, which holds the
/// same rules for the other list.
///
/// Every figure here is written through `MarketLocalStore.record`, the app's
/// own writer, rather than by assembling rows by hand: the stale and
/// withheld cases only mean anything if they are the rows a real refresh
/// would have left.
@Suite("ItemListViewModel — the Market sort")
struct ItemListViewModelMarketSortTests {
    /// A fixed clock, so "thirty days old" is a fact about the fixture
    /// rather than about the day the suite runs.
    private let clock = Date(timeIntervalSince1970: 1_800_000_000)

    private func product(_ id: Int) -> MarketProduct {
        MarketProduct(
            id: id,
            slug: "fender-american-professional-ii-telecaster",
            title: "Fender American Professional II Telecaster",
            usedLowCents: 100_000,
            usedTotal: 108,
            listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
        )
    }

    /// One recorded refresh for an owned item: a figure, or — with no
    /// median — the withheld reading a thin catalog produces.
    private func record(
        _ medianCents: Int?,
        for id: UUID,
        fetchedAt: Date,
        productID: Int = 126_161,
        in context: ModelContext
    ) throws {
        let reading: MarketReading
        if let medianCents {
            reading = .figure(MarketFigure(
                medianCents: medianCents,
                lowCents: medianCents - 10_000,
                highCents: medianCents + 10_000,
                count: 12,
                fetchedAt: fetchedAt,
                isTruncated: false,
                yearScope: .any
            ))
        } else {
            reading = .withheld(count: 2, usedLowCents: 100_000, fetchedAt: fetchedAt, yearScope: .any)
        }
        try MarketLocalStore.record(
            reading,
            product: product(productID),
            for: MarketSubjectKey(subjectID: id, kind: .owned),
            in: context
        )
    }

    private func viewModel(over context: ModelContext) -> ItemListViewModel {
        ItemListViewModel(modelContext: context, now: { self.clock })
    }

    private func id(of name: String, in context: ModelContext) throws -> UUID {
        let items = try context.fetch(FetchDescriptor<Item>())
        return try #require(items.first(where: { $0.name == name })?.id, "\(name) wasn't inserted")
    }

    /// The four kinds of row, one sort: a current median leads, and
    /// everything without one — withheld, stale past thirty days
    /// (Decision 21), or never matched at all — falls to the bottom in the
    /// person's own order rather than sorting as if it were worth nothing.
    /// The stale figure is the *largest* number in the fixture, so a sort
    /// that ignored freshness would lead with it.
    @Test func theMarketSortLeadsWithTheDearestCurrentMedianAndSinksTheRest() throws {
        let context = try makeInMemoryContext()
        insertItem("Cheap", order: 5, into: context)
        insertItem("Dear", order: 6, into: context)
        insertItem("Stale", order: 0, into: context)
        insertItem("Withheld", order: 1, into: context)
        insertItem("Unmatched", order: 2, into: context)
        try record(50_000, for: try id(of: "Cheap", in: context), fetchedAt: clock, in: context)
        try record(200_000, for: try id(of: "Dear", in: context), fetchedAt: clock, in: context)
        try record(900_000, for: try id(of: "Stale", in: context), fetchedAt: clock.addingTimeInterval(-31 * 24 * 60 * 60), in: context)
        try record(nil, for: try id(of: "Withheld", in: context), fetchedAt: clock, in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.sortOrder = .marketFigure
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Dear", "Cheap", "Stale", "Withheld", "Unmatched"])
    }

    /// The ascending half: the cheapest current median leads, and the three
    /// figure-less rows stay last — they are unknown, not cheap, so
    /// ascending must not promote them above the cheapest matched item.
    @Test func theAscendingMarketSortLeadsWithTheCheapestAndStillSinksTheRest() throws {
        let context = try makeInMemoryContext()
        insertItem("Cheap", order: 5, into: context)
        insertItem("Dear", order: 6, into: context)
        insertItem("Stale", order: 0, into: context)
        insertItem("Withheld", order: 1, into: context)
        insertItem("Unmatched", order: 2, into: context)
        try record(50_000, for: try id(of: "Cheap", in: context), fetchedAt: clock, in: context)
        try record(200_000, for: try id(of: "Dear", in: context), fetchedAt: clock, in: context)
        try record(900_000, for: try id(of: "Stale", in: context), fetchedAt: clock.addingTimeInterval(-31 * 24 * 60 * 60), in: context)
        try record(nil, for: try id(of: "Withheld", in: context), fetchedAt: clock, in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.sortOrder = .marketFigureAscending
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Cheap", "Dear", "Stale", "Withheld", "Unmatched"])
    }

    /// Equal medians resolve by the user's own order — the tie-break every
    /// non-Custom sort takes. Insertion order, name order and manual order
    /// are three different orders here, so neither a stable sort over the
    /// fetch nor a name fallback passes this by coincidence.
    @Test func marketFigureTiesResolveByManualOrder() throws {
        let context = try makeInMemoryContext()
        insertItem("alpha", order: 2, into: context)
        insertItem("Charlie", order: 0, into: context)
        insertItem("Bravo", order: 1, into: context)
        for name in ["alpha", "Charlie", "Bravo"] {
            try record(140_000, for: try id(of: name, in: context), fetchedAt: clock, in: context)
        }
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.sortOrder = .marketFigure
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Charlie", "Bravo", "alpha"])
    }

    /// The row's arrow, not the sort: an item with no figure row of its own
    /// has no trend to draw, whatever its neighbours have.
    @Test func unmatchedItemsShowNoTrend() throws {
        let context = try makeInMemoryContext()
        insertItem("Unmatched", into: context)
        insertItem("Matched", into: context)
        try record(140_000, for: try id(of: "Matched", in: context), fetchedAt: clock, in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(viewModel.trend(for: try id(of: "Unmatched", in: context)) == nil)
        #expect(viewModel.marketSummaries[try id(of: "Unmatched", in: context)] == nil)
    }

    /// 003 Decision 12, the list's half: the figure is older than thirty days,
    /// so the row draws no arrow — the same silence the Sell Plan and the
    /// Market section already keep. The stored classification is still `.up`,
    /// which is exactly what makes this falsifiable: read the stored trend
    /// here instead of the current one and the row asserts a rise beside a
    /// figure the same load withheld.
    @Test func aFigureOlderThanThirtyDaysDrawsNoTrend() throws {
        let context = try makeInMemoryContext()
        insertItem("Stale", into: context)
        let id = try id(of: "Stale", in: context)
        try record(100_000, for: id, fetchedAt: clock.addingTimeInterval(-40 * 24 * 60 * 60), in: context)
        try record(112_000, for: id, fetchedAt: clock.addingTimeInterval(-31 * 24 * 60 * 60), in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(viewModel.marketSummaries[id]?.trend == .up, "the classification is still stored")
        #expect(viewModel.marketSummaries[id]?.medianCents == nil, "and the figure itself is already withheld for age")
        #expect(viewModel.trend(for: id) == nil)
    }

    /// The withheld half of the same rule: fetched today, but too thin a
    /// catalog to publish a median, so there is no figure for an arrow to
    /// sit beside and none is drawn.
    @Test func aWithheldFigureDrawsNoTrend() throws {
        let context = try makeInMemoryContext()
        insertItem("Withheld", into: context)
        let id = try id(of: "Withheld", in: context)
        try record(100_000, for: id, fetchedAt: clock.addingTimeInterval(-8 * 24 * 60 * 60), in: context)
        try record(112_000, for: id, fetchedAt: clock.addingTimeInterval(-1 * 24 * 60 * 60), in: context)
        try record(nil, for: id, fetchedAt: clock, in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(viewModel.marketSummaries[id]?.trend == .up, "the classification is still stored")
        #expect(viewModel.trend(for: id) == nil)
    }

    /// The positive half, through the property the row actually reads: two
    /// refreshes a fortnight apart, the second ten per cent higher, and the
    /// row's arrow points up (spec criterion 13). The trend is the figure
    /// row's own stored one, recomputed by `record` over the whole history.
    @Test func aMatchedItemWithARisingHistoryReadsUp() throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", into: context)
        let id = try id(of: "Telecaster", in: context)
        try record(100_000, for: id, fetchedAt: clock.addingTimeInterval(-14 * 24 * 60 * 60), in: context)
        try record(110_000, for: id, fetchedAt: clock, in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(viewModel.trend(for: id) == .up)
    }

    /// Q11's labels, on both lists: read from `MarketCopy`, never retyped —
    /// the source scan is the half that catches a second copy of the string
    /// being typed in beside the first.
    @Test func theMarketSortLabelsComeFromMarketCopyOnBothLists() throws {
        #expect(ItemListViewModel.SortOrder.marketFigure.label == MarketCopy.sortDescending)
        #expect(ItemListViewModel.SortOrder.marketFigureAscending.label == MarketCopy.sortAscending)
        #expect(WishlistViewModel.SortOrder.marketFigure.label == MarketCopy.sortDescending)
        #expect(WishlistViewModel.SortOrder.marketFigureAscending.label == MarketCopy.sortAscending)

        for file in ["Trove/ViewModels/ItemListViewModel.swift", "Trove/ViewModels/WishlistViewModel.swift"] {
            let code = try SourceScan.production(file)
            #expect(code.contains("MarketCopy.sortDescending"), "\(file): the descending label isn't read from MarketCopy")
            #expect(code.contains("MarketCopy.sortAscending"), "\(file): the ascending label isn't read from MarketCopy")
            let retyped = SourceScan.stringLiterals(in: code).filter { $0.contains("Market") }
            #expect(retyped.isEmpty, "\(file): the sort label is typed inline: \(retyped)")
        }
    }

    /// Q11's positions: the Market pair sits straight after the Value pair,
    /// descending before ascending — the order the menu shows, which is
    /// `allCases`.
    @Test func theMarketPairFollowsTheValuePairInTheMenu() {
        #expect(ItemListViewModel.SortOrder.allCases == [
            .custom, .purchaseDate, .currentValue, .currentValueAscending, .marketFigure, .marketFigureAscending, .desireToKeep,
        ])
    }
}

/// The un-valued filter, which arrives from the dashboard rather than from a
/// control on the list itself.
@Suite("ItemListViewModel — the un-valued filter")
struct ItemListUnvaluedFilterTests {
    private func insert(_ name: String, value: Int?, category: String = "Music/Amps", into context: ModelContext) {
        context.insert(Item(name: name, categoryPath: category, currentValueCents: value))
    }

    @Test func offIsTheDefaultAndShowsEverything() throws {
        let context = try makeInMemoryContext()
        insert("Valued", value: 20_000, into: context)
        insert("Not valued", value: nil, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.showsOnlyUnvalued == false)
        #expect(viewModel.items.count == 2)
    }

    @Test func onNarrowsToItemsWithNoValue() throws {
        let context = try makeInMemoryContext()
        insert("Valued", value: 20_000, into: context)
        insert("Not valued", value: nil, into: context)
        insert("Also not valued", value: nil, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.showsOnlyUnvalued = true
        viewModel.load()

        #expect(viewModel.items.map(\.name).sorted() == ["Also not valued", "Not valued"])
    }

    /// A deliberate zero is a value. Only "never entered" is un-valued — the
    /// same distinction the dashboard total draws.
    @Test func aZeroValueIsValued() throws {
        let context = try makeInMemoryContext()
        insert("Free but valued", value: 0, into: context)
        insert("Not valued", value: nil, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.showsOnlyUnvalued = true
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Not valued"])
    }

    /// Every narrowing applies to the same set — the rule search and the
    /// category filter already follow.
    @Test func combinesWithTheCategoryFilterRatherThanReplacingIt() throws {
        let context = try makeInMemoryContext()
        insert("Un-valued amp", value: nil, category: "Music/Amps", into: context)
        insert("Un-valued lens", value: nil, category: "Photography/Lenses", into: context)
        insert("Valued amp", value: 20_000, category: "Music/Amps", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.showsOnlyUnvalued = true
        viewModel.categoryFilter = "Music/Amps"
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Un-valued amp"])
    }

    @Test func combinesWithSearchToo() throws {
        let context = try makeInMemoryContext()
        insert("Un-valued amp", value: nil, into: context)
        insert("Un-valued lens", value: nil, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.showsOnlyUnvalued = true
        viewModel.searchText = "lens"
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Un-valued lens"])
    }

    /// The header total is a floor over what's on screen. Filtered to
    /// un-valued items there is nothing to total, and every row is counted as
    /// missing — the figure has to stay honest rather than read as $0 of value.
    @Test func theHeaderTotalStaysHonestWhileFiltered() throws {
        let context = try makeInMemoryContext()
        insert("Valued", value: 20_000, into: context)
        insert("Not valued", value: nil, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.showsOnlyUnvalued = true
        viewModel.load()

        #expect(viewModel.totalCurrentValueCents == 0)
        #expect(viewModel.unvaluedCount == 1)
        #expect(viewModel.items.count == 1)
    }

    /// The chips are built from the unfiltered fetch, so turning this on can't
    /// dissolve the row the user needs to get back out of it.
    @Test func theCategoryChipsSurviveTheFilter() throws {
        let context = try makeInMemoryContext()
        insert("Valued amp", value: 20_000, category: "Music/Amps", into: context)
        insert("Un-valued lens", value: nil, category: "Photography/Lenses", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.showsOnlyUnvalued = true
        viewModel.load()

        #expect(viewModel.categoryOptions == ["Music/Amps", "Photography/Lenses"])
    }
}

@Suite("ItemListViewModel — export")
struct ItemListViewModelExportTests {
    /// Criteria 3: exactly the visible items, in the visible order. The
    /// fixture makes a refetch detectably wrong twice over — the Telecaster
    /// is filtered out, and storage order can't produce ascending-value
    /// order within the filter.
    @Test func exportedRowsAreTheVisibleItemsInVisibleOrder() async throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", valueCents: 120_000, into: context)
        insertItem("Leica M6", category: "Photography/Cameras", valueCents: 345_000, into: context)
        insertItem("Summicron 35", category: "Photography/Lenses", valueCents: 240_000, into: context)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, exportService: spy)
        viewModel.categoryFilter = "Photography"
        viewModel.sortOrder = .currentValueAscending
        viewModel.load()

        await viewModel.exportCSV()

        let table = try #require(spy.tables.first)
        #expect(table.headers == ExportSchema.itemHeaders)
        #expect(table.rows.map { $0[0] } == ["Summicron 35", "Leica M6"])
    }

    @Test func exportStagesTheFileForTheShareSheet() async throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context, exportService: ExportServiceSpy())
        viewModel.load()

        await viewModel.exportCSV()

        let staged = try #require(viewModel.stagedExport)
        #expect(staged.filenames == [ExportFilename.items(fileExtension: "csv")])
        #expect(viewModel.isExporting == false)
        #expect(viewModel.exportFailureMessage == nil)
    }

    /// Criterion 2's actual subject: the *view*, not the store — a filter
    /// matching nothing disables export even though the collection has items.
    @Test func canExportTracksTheVisibleListNotTheStore() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemListViewModel(modelContext: context, exportService: ExportServiceSpy())
        viewModel.load()
        #expect(!viewModel.canExportCSV)
        #expect(!viewModel.canExportPDF)

        insertItem("Telecaster", into: context)
        try context.save()
        viewModel.load()
        #expect(viewModel.canExportCSV)
        #expect(viewModel.canExportPDF)

        viewModel.categoryFilter = "Photography"
        viewModel.load()
        #expect(!viewModel.canExportCSV)
        #expect(!viewModel.canExportPDF)
    }

    /// The intents' own guard, backing up the disabled menu: an empty view
    /// never reaches the service, so an empty file can't exist.
    @Test func nothingIsExportedWhenTheViewIsEmpty() async throws {
        let context = try makeInMemoryContext()
        let spy = ExportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        await viewModel.exportCSV()
        await viewModel.exportPDF()

        #expect(spy.tables.isEmpty)
        #expect(spy.documents.isEmpty)
        #expect(viewModel.stagedExport == nil)
    }

    /// Criterion 2a: a throw becomes the shared failure copy, nothing is
    /// staged, and the progress state doesn't stick.
    @Test func aThrowingServiceSurfacesTheSharedFailureCopy() async throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", into: context)
        try context.save()

        let viewModel = ItemListViewModel(
            modelContext: context,
            exportService: ExportServiceSpy(failsEveryCall: true)
        )
        viewModel.load()

        await viewModel.exportCSV()

        #expect(viewModel.exportFailureMessage == ExportCopy.failureMessage)
        #expect(viewModel.stagedExport == nil)
        #expect(viewModel.isExporting == false)
    }

    /// Criterion 8 by construction: the cover the service receives carries
    /// this view model's own arithmetic — checked against both the live
    /// properties and concrete figures, so a broken property can't vouch
    /// for itself.
    @Test func pdfCoverFiguresAreTheViewModelsOwnArithmetic() async throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", priceCents: 50_000, valueCents: 120_000, into: context)
        insertItem("Leica M6", priceCents: 60_000, valueCents: 345_000, into: context)
        insertItem("Blues Junior", priceCents: 70_000, into: context)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        await viewModel.exportPDF()

        let document = try #require(spy.documents.first)
        #expect(document.entries.count == 3)
        #expect(document.cover.title == "Owned Items")
        #expect(document.cover.coverageLabel == "All items")
        #expect(document.cover.itemCount == viewModel.items.count)

        guard case .items(let value, let paid, let unvalued) = document.cover.totals else {
            Issue.record("items export produced non-items cover totals")
            return
        }
        #expect(value == viewModel.totalCurrentValueCents)
        #expect(paid == viewModel.totalPaidCents)
        #expect(unvalued == viewModel.unvaluedCount)
        #expect(value == 465_000)
        #expect(paid == 180_000)
        #expect(unvalued == 1)
        // Entry order mirrors the visible order, same as the CSV rows
        // (T019 record-only: previously only entry *count* was asserted).
        #expect(document.entries.map(\.name) == viewModel.items.map(\.name))
    }

    /// T019/S1: the progress state observed *mid-flight* — previously no
    /// test could fail if `isExporting = true` were deleted — and the
    /// reentrancy guard, which protects the staged file from a concurrent
    /// export's purge-before-write.
    @Test func isExportingIsObservableMidFlightAndBlocksReentry() async throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", into: context)
        try context.save()

        let spy = GatedExportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        let inFlight = Task { await viewModel.exportCSV() }
        for _ in 0..<10_000 where spy.csvCalls == 0 { await Task.yield() }
        try #require(spy.csvCalls == 1, "gated export never started")

        #expect(viewModel.isExporting, "progress state must be visible while generating")

        // Reentrant attempts — same format and the other — bounce off the
        // guard without reaching the service.
        await viewModel.exportCSV()
        await viewModel.exportPDF()
        #expect(spy.csvCalls == 1)
        #expect(spy.pdfCalls == 0)

        spy.release()
        await inFlight.value
        #expect(viewModel.isExporting == false)
        #expect(viewModel.stagedExport != nil)
    }

    @Test func coverageLabelNamesEveryActiveNarrowing() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context, exportService: ExportServiceSpy())
        viewModel.load()
        #expect(viewModel.exportCoverageLabel == "All items")

        viewModel.categoryFilter = "Photography/Cameras"
        viewModel.showsOnlyUnvalued = true
        viewModel.searchText = "M6"
        viewModel.load()

        let categoryLabel = viewModel.categoryLabels["Photography/Cameras"] ?? "Photography/Cameras"
        #expect(viewModel.exportCoverageLabel
            == "Category: \(categoryLabel) · Not yet valued · Search: \u{201C}M6\u{201D}")
    }
}

/// T010's guards: the import surface — mid-flight state and reentry, busy
/// serialization across export and import, failure mapping onto the shared
/// copy, cancel leaving the store untouched, and the alert accessors.
struct ItemListViewModelImportTests {
    private let dummyURL = URL(filePath: "/dev/null/import.csv")

    @Test func isImportingFileIsObservableMidFlightAndBlocksReentry() async throws {
        let context = try makeInMemoryContext()
        let spy = GatedImportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, importService: spy)

        let inFlight = Task { await viewModel.importCSV(from: dummyURL) }
        for _ in 0..<10_000 where spy.itemCalls == 0 { await Task.yield() }
        try #require(spy.itemCalls == 1, "gated import never started")

        #expect(viewModel.isImportingFile, "progress state must be visible while parsing")
        #expect(viewModel.isBusy)

        // The reentrant attempt bounces off the guard without reaching the
        // service — the spy gates only the first call, so a wrongly-leaked
        // call would fail this count fast rather than deadlock (T019/S1).
        await viewModel.importCSV(from: dummyURL)
        #expect(spy.itemCalls == 1)

        spy.release()
        await inFlight.value
        #expect(viewModel.isImportingFile == false)
        guard case .confirmation = viewModel.importPresentation else {
            Issue.record("expected a staged confirmation")
            return
        }
    }

    @Test func aBusyImportRefusesExportAndViceVersa() async throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Telecaster"))
        try context.save()

        // Import in flight → export refused.
        let importSpy = GatedImportServiceSpy()
        let exportSpy = ExportServiceSpy()
        let viewModel = ItemListViewModel(
            modelContext: context, exportService: exportSpy, importService: importSpy
        )
        viewModel.load()

        let importing = Task { await viewModel.importCSV(from: dummyURL) }
        for _ in 0..<10_000 where importSpy.itemCalls == 0 { await Task.yield() }
        await viewModel.exportCSV()
        #expect(exportSpy.tables.isEmpty, "export must refuse while an import is in flight")
        importSpy.release()
        await importing.value

        // Export in flight → import refused.
        let gatedExport = GatedExportServiceSpy()
        let secondImportSpy = ImportServiceSpy()
        let second = ItemListViewModel(
            modelContext: context, exportService: gatedExport, importService: secondImportSpy
        )
        second.load()
        let exporting = Task { await second.exportCSV() }
        for _ in 0..<10_000 where gatedExport.csvCalls == 0 { await Task.yield() }
        await second.importCSV(from: dummyURL)
        #expect(secondImportSpy.itemURLs.isEmpty, "import must refuse while an export is in flight")
        gatedExport.release()
        await exporting.value
    }

    @Test func aFailureMapsToTheSharedCopy() async throws {
        let context = try makeInMemoryContext()
        let spy = ImportServiceSpy(items: .failure(.undecodable))
        let viewModel = ItemListViewModel(modelContext: context, importService: spy)

        await viewModel.importCSV(from: dummyURL)

        guard case .failure(let title, let message) = viewModel.importPresentation else {
            Issue.record("expected a failure presentation")
            return
        }
        #expect(title == ImportCopy.failureTitle)
        #expect(message == ImportCopy.failureMessage(for: .undecodable, target: .items))
        #expect(viewModel.importAlertTitle == ImportCopy.failureTitle)
        #expect(viewModel.importOffersConfirmation == false)
    }

    @Test func cancelClearsThePresentationWithoutStoreWrites() async throws {
        let context = try makeInMemoryContext()
        let spy = ImportServiceSpy(items: .success(itemsPreview(names: ["Strat"])))
        let viewModel = ItemListViewModel(modelContext: context, importService: spy)

        await viewModel.importCSV(from: dummyURL)
        #expect(viewModel.importPresentation != nil)

        viewModel.cancelImport()
        #expect(viewModel.importPresentation == nil)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    @Test func alertAccessorsComposeThroughImportCopy() async throws {
        let context = try makeInMemoryContext()
        let staged = ImportPreview<ItemExportRecord>(
            validated: itemsPreview(names: ["Strat"]).validated,
            skipped: [SkippedRow(rowNumber: 7, reason: "no name")],
            defaultedFieldCount: 2
        )
        let viewModel = ItemListViewModel(
            modelContext: context, importService: ImportServiceSpy(items: .success(staged))
        )
        await viewModel.importCSV(from: dummyURL)

        #expect(viewModel.importAlertTitle == "Import 1 item?")
        #expect(viewModel.importAlertMessage.contains("Row 7 \u{2014} no name"))
        #expect(viewModel.importAlertMessage.contains("2 missing or unreadable fields"))
        #expect(viewModel.importOffersConfirmation)

        // The zero-importable case is informational only (criterion 5).
        viewModel.importPresentation = .confirmation(
            ImportPreview(validated: [], skipped: staged.skipped, defaultedFieldCount: 0)
        )
        #expect(viewModel.importAlertTitle == "Nothing to import")
        #expect(viewModel.importOffersConfirmation == false)
    }
}

/// A validated items preview for staging tests — plain records, no store.
func itemsPreview(names: [String]) -> ItemsImportPreview {
    ImportPreview(
        validated: names.enumerated().map { offset, name in
            ValidatedRow(
                record: ItemExportRecord(
                    name: name, categoryPath: "Music/Guitars", purchasePriceCents: 100_000,
                    currencyCode: "USD", purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
                    purchaseLocation: nil, currentValueCents: nil, desireToKeep: 3,
                    conditionRawValue: "good", conditionNotes: nil, serialNumber: nil,
                    notes: nil, reverbProductID: nil, year: nil,
                    soldDate: nil, salePriceCents: nil, saleLocation: nil, saleNote: nil,
                    firstPhotoID: nil,
                    firstPhotoAttribution: nil
                ),
                rowNumber: offset + 2,
                defaultedFieldCount: 0
            )
        },
        skipped: [],
        defaultedFieldCount: 0
    )
}

/// T011's guards: the commit path — placement, canonicalization, rollback,
/// view-independence, and criterion 11's stated duplicate behavior.
struct ItemListViewModelCommitTests {
    private let dummyURL = URL(filePath: "/dev/null/import.csv")

    @Test func commitAppendsAtTheEndPreservingFileOrder() async throws {
        // A container, not just a context: the verification fetch below
        // runs on a SECOND context over the same store, because a
        // same-context refetch returns unsaved inserts and passes with
        // `save()` deleted — the recorded false-passing persistence shape,
        // which this suite exhibited until T018's audit ran that exact
        // mutation and stayed green.
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(Item(name: "Existing A", sortOrder: 0))
        context.insert(Item(name: "Existing B", sortOrder: 1))
        try context.save()

        let viewModel = ItemListViewModel(
            modelContext: context,
            importService: ImportServiceSpy(items: .success(itemsPreview(names: ["One", "Two", "Three"])))
        )
        await viewModel.importCSV(from: dummyURL)
        await viewModel.confirmImport()?.value

        let ordered = try ModelContext(container).fetch(
            FetchDescriptor<Item>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        #expect(ordered.map(\.name) == ["Existing A", "Existing B", "One", "Two", "Three"])
        #expect(ordered.map(\.sortOrder) == [0, 1, 2, 3, 4])
        #expect(viewModel.importPresentation == nil)
    }

    /// 002/T016a: the commit carries the CSV's two appended columns onto
    /// the model, so a re-imported item asks the market the same question it
    /// asked before it left (criterion 19). Verified on a second context
    /// over the same store — a same-context refetch would pass with
    /// `save()` deleted.
    @Test func commitRestoresTheReverbMatchAndTheYear() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        var preview = itemsPreview(names: ["Matched", "Unmatched"])
        preview = ImportPreview(
            validated: [
                ValidatedRow(
                    record: ItemExportRecord(
                        name: "Matched", categoryPath: "Music/Guitars",
                        purchasePriceCents: 100_000, currencyCode: "USD",
                        purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
                        purchaseLocation: nil, currentValueCents: nil, desireToKeep: 3,
                        conditionRawValue: "good", conditionNotes: nil, serialNumber: nil,
                        notes: nil, reverbProductID: 182_769, year: 1984,
                        soldDate: nil, salePriceCents: nil, saleLocation: nil, saleNote: nil,
                        firstPhotoID: nil,
                        firstPhotoAttribution: nil
                    ),
                    rowNumber: 2,
                    defaultedFieldCount: 0
                ),
                preview.validated[1],
            ],
            skipped: [],
            defaultedFieldCount: 0
        )

        let viewModel = ItemListViewModel(
            modelContext: context,
            importService: ImportServiceSpy(items: .success(preview))
        )
        await viewModel.importCSV(from: dummyURL)
        await viewModel.confirmImport()?.value

        let saved = try ModelContext(container).fetch(
            FetchDescriptor<Item>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        #expect(saved.map(\.name) == ["Matched", "Unmatched"])
        #expect(saved[0].reverbProductID == 182_769)
        #expect(saved[0].year == 1984)
        // An unmatched row stays unmatched — no id invented, no year.
        #expect(saved[1].reverbProductID == nil)
        #expect(saved[1].year == nil)
    }

    /// 006/T006: a sold row commits as a sold item, and an owned row beside
    /// it stays owned. The whole loop runs through production code — a live
    /// sale → its export record → CSV bytes → the real parse pipeline → the
    /// commit — so the four columns, the pair rule and the commit are tied
    /// together with none of them as the other's oracle. Verified on a
    /// SECOND context over the same store, the shape a same-context refetch
    /// would fake.
    ///
    /// The link is asserted absent deliberately (P11): an imported sale
    /// funded nothing on this device, and the commit must not invent a plan
    /// for it. Mutation: set `soldTowardWishlistItem` in the commit → red.
    @Test func commitRestoresTheSaleAndPointsAtNoPlan() async throws {
        let zone = TimeZone(identifier: "UTC")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let soldOn = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 4)))

        // The source lives in its own store, so nothing but the CSV bytes
        // crosses into the store the commit writes to.
        let sourceContext = try makeInMemoryContext()
        let sold = Item(name: "Blues Junior", categoryPath: "Music/Amps", purchasePriceCents: 69_000)
        sold.sale = Sale(date: soldOn, priceCents: 55_000, location: "Reverb", note: "Shipped")
        let owned = Item(name: "Strat", categoryPath: "Music/Guitars", purchasePriceCents: 120_000)
        sourceContext.insert(sold)
        sourceContext.insert(owned)
        try sourceContext.save()

        let table = ExportSchema.itemsTable(
            [sold, owned].map { ItemExportRecord(item: $0) }, timeZone: zone
        )
        let preview = try ImportSchema.itemsPreview(
            from: try CSVParser.parse(CSVWriter.write(table)), timeZone: zone
        )
        try #require(preview.defaultedFieldCount == 0)

        let container = try makeInMemoryContainer()
        let viewModel = ItemListViewModel(
            modelContext: ModelContext(container),
            importService: ImportServiceSpy(items: .success(preview))
        )
        await viewModel.importCSV(from: dummyURL)
        await viewModel.confirmImport()?.value

        let saved = try ModelContext(container).fetch(
            FetchDescriptor<Item>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        #expect(saved.map(\.name) == ["Blues Junior", "Strat"])
        #expect(saved[0].sale == Sale(
            date: soldOn, priceCents: 55_000, location: "Reverb", note: "Shipped"
        ))
        // An imported sale funded nothing on this device (P11).
        #expect(saved[0].soldTowardWishlistItem == nil)
        // And the owned row stays owned — no phantom sale from a blank pair.
        #expect(saved[1].sale == nil)
    }

    @Test func thePlacementBaseIsComputedAtCommitTimeNotParseTime() async throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemListViewModel(
            modelContext: context,
            importService: ImportServiceSpy(items: .success(itemsPreview(names: ["Imported"])))
        )
        await viewModel.importCSV(from: dummyURL)

        // Something lands between the alert and the confirm — a CloudKit
        // arrival, a hand-add. The batch must still append after it.
        context.insert(Item(name: "Latecomer", sortOrder: 10))
        try context.save()

        await viewModel.confirmImport()?.value
        let imported = try #require(
            try context.fetch(FetchDescriptor<Item>()).first { $0.name == "Imported" }
        )
        #expect(imported.sortOrder == 11)
    }

    @Test func aLegacyAllZeroStoreStillLandsTheBatchAfterTheLegacyBlock() async throws {
        // The real state of a pre-010 store: every item at sortOrder 0,
        // ties falling back to createdAt at sort time.
        let context = try makeInMemoryContext()
        for name in ["Legacy A", "Legacy B", "Legacy C"] {
            context.insert(Item(name: name, sortOrder: 0))
        }
        try context.save()

        let viewModel = ItemListViewModel(
            modelContext: context,
            importService: ImportServiceSpy(items: .success(itemsPreview(names: ["New One", "New Two"])))
        )
        viewModel.sortOrder = .custom
        await viewModel.importCSV(from: dummyURL)
        await viewModel.confirmImport()?.value

        #expect(viewModel.items.count == 5)
        #expect(viewModel.items.suffix(2).map(\.name) == ["New One", "New Two"])
    }

    @Test func importIsViewIndependentOfTheActiveFilter() async throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Mixer", categoryPath: "Audio/Desks"))
        try context.save()

        let viewModel = ItemListViewModel(
            modelContext: context,
            importService: ImportServiceSpy(items: .success(itemsPreview(names: ["Strat", "Tele"])))
        )
        viewModel.categoryFilter = "Audio/Desks"
        viewModel.load()
        try #require(viewModel.totalCount == 1)

        await viewModel.importCSV(from: dummyURL)
        await viewModel.confirmImport()?.value

        // The batch (Music/Guitars) is outside the filter: not visible,
        // but fully imported — criterion 10.
        #expect(viewModel.totalCount == 3)
        #expect(viewModel.items.map(\.name) == ["Mixer"])
    }

    @Test func committingTheSameFileTwiceDuplicatesEveryRow() async throws {
        let context = try makeInMemoryContext()
        let preview = itemsPreview(names: ["Strat"])
        let viewModel = ItemListViewModel(
            modelContext: context,
            importService: ImportServiceSpy(items: .success(preview))
        )
        await viewModel.importCSV(from: dummyURL)
        await viewModel.confirmImport()?.value
        viewModel.importPresentation = .confirmation(preview)
        await viewModel.confirmImport()?.value

        // Stated no-dedupe behavior (criterion 11) — two copies, each with
        // its own place in the order.
        let all = try context.fetch(FetchDescriptor<Item>())
        #expect(all.count == 2)
        #expect(Set(all.map(\.sortOrder)).count == 2)
    }

    @Test func canonicalizationPreservesExistingCasingAndBatchFirstWins() async throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "M6", categoryPath: "Photography/Cameras"))
        try context.save()

        var preview = itemsPreview(names: ["A", "B", "C"])
        preview = ImportPreview(
            validated: zip(preview.validated, ["photography/cameras", "guitars", "Guitars"])
                .map { row, path in
                    ValidatedRow(
                        record: ItemExportRecord(
                            name: row.record.name, categoryPath: path,
                            purchasePriceCents: 0, currencyCode: "USD",
                            purchaseDate: row.record.purchaseDate, purchaseLocation: nil,
                            currentValueCents: nil, desireToKeep: 3,
                            conditionRawValue: "good", conditionNotes: nil,
                            serialNumber: nil, notes: nil, reverbProductID: nil, year: nil,
                            soldDate: nil, salePriceCents: nil, saleLocation: nil,
                            saleNote: nil, firstPhotoID: nil,
                            firstPhotoAttribution: nil
                        ),
                        rowNumber: row.rowNumber,
                        defaultedFieldCount: 0
                    )
                },
            skipped: [], defaultedFieldCount: 0
        )
        let viewModel = ItemListViewModel(
            modelContext: context, importService: ImportServiceSpy(items: .success(preview))
        )
        await viewModel.importCSV(from: dummyURL)
        await viewModel.confirmImport()?.value

        let byName = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Item>()).map { ($0.name, $0.categoryPath) }
        )
        #expect(byName["A"] == "Photography/Cameras")
        #expect(byName["B"] == "guitars")
        #expect(byName["C"] == "guitars")
    }

    @Test func aZeroImportableConfirmationClearsWithoutWrites() async throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemListViewModel(
            modelContext: context,
            importService: ImportServiceSpy(
                items: .success(ImportPreview(
                    validated: [],
                    skipped: [SkippedRow(rowNumber: 2, reason: "no name")],
                    defaultedFieldCount: 0
                ))
            )
        )
        await viewModel.importCSV(from: dummyURL)
        await viewModel.confirmImport()?.value

        #expect(viewModel.importPresentation == nil)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    /// The T017 device finding, pinned at the view-model level: the
    /// alert's isPresented binding writes the presentation nil the moment
    /// any button is tapped, and that write can land before an async
    /// intent's body runs. `confirmImport` must capture the preview in its
    /// synchronous prefix, so a dismissal racing the commit cannot lose it.
    @Test func aDismissalWriteRacingTheConfirmCannotLoseTheCommit() async throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemListViewModel(
            modelContext: context,
            importService: ImportServiceSpy(items: .success(itemsPreview(names: ["Strat"])))
        )
        await viewModel.importCSV(from: dummyURL)

        let task = viewModel.confirmImport()
        // The dismissal write, as SwiftUI performs it — immediately after
        // the button action returns, before the commit task's body runs.
        viewModel.importPresentation = nil
        await task?.value

        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
    }

    /// The mechanism `confirmImport`'s catch relies on: rollback clears
    /// unsaved inserts from this context — paired with the wiring scan in
    /// `ImportWiringTests`, since a real SwiftData save failure can't be
    /// forced deterministically (plan §The commit path, stated honestly).
    @Test func rollbackClearsUnsavedInsertsFromTheContext() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Phantom"))
        try #require(try context.fetch(FetchDescriptor<Item>()).count == 1)

        context.rollback()
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
    }
}

// 012's `ItemListViewModelTemplateTests` moved to
// `SettingsViewModelTemplateTests` with the intent (013/T010, T013).

// MARK: - 006: the Items tab's two sides

/// A sold item, built here rather than through `insertItem` so the four sale
/// fields land through `Item.sale` — the one writer that keeps a date and a
/// price together.
@discardableResult
private func insertSold(
    _ name: String,
    category: String = "Music/Guitars",
    priceCents: Int = 0,
    valueCents: Int? = nil,
    order: Int = 0,
    soldAt seconds: TimeInterval,
    forCents salePriceCents: Int,
    into context: ModelContext
) -> Item {
    let item = Item(
        name: name,
        categoryPath: category,
        purchasePriceCents: priceCents,
        purchaseDate: Date(timeIntervalSince1970: 0),
        currentValueCents: valueCents,
        sortOrder: order
    )
    item.sale = Sale(
        date: Date(timeIntervalSince1970: seconds),
        priceCents: salePriceCents,
        location: nil,
        note: nil
    )
    context.insert(item)
    return item
}

/// A monitor mid-first-import, the `StillSyncingTests` shape.
private func importingMonitor() -> SyncMonitor {
    let monitor = SyncMonitor(mode: .cloudKit)
    monitor.record(SyncEvent(kind: .importChanges, isFinished: false, succeeded: false))
    return monitor
}

@Suite("ItemListViewModel — the Sold side")
struct ItemListViewModelSoldSideTests {
    /// G13: one fetch, split once. A sold item is absent from *every* Owned
    /// figure — the rows, the count behind the empty states, the header's two
    /// totals, and the chips — and present in `soldItems`.
    ///
    /// Mutation: drop the split in `load()` (`let owned = all`) → the names,
    /// the count, both totals and the chips all read the sold pair → red.
    @Test func aSoldItemLeavesEveryOwnedFigureAndAppearsOnTheSoldSide() throws {
        let context = try makeInMemoryContext()
        insertItem("Kept", valueCents: 150_00, purchasedAt: 200, into: context)
        insertItem("Unpriced", valueCents: nil, purchasedAt: 100, into: context)
        insertSold(
            "Gone", category: "Photography/Cameras", valueCents: 900_00,
            soldAt: 1_000, forCents: 800_00, into: context
        )
        insertSold(
            "Also gone", category: "Photography/Lenses", valueCents: nil,
            soldAt: 2_000, forCents: 100_00, into: context
        )
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Kept", "Unpriced"])
        #expect(viewModel.totalCount == 2)
        #expect(viewModel.totalCurrentValueCents == 150_00)
        #expect(viewModel.unvaluedCount == 1)
        #expect(viewModel.categoryOptions == ["Music/Guitars"])
        #expect(viewModel.soldItems.map(\.name) == ["Also gone", "Gone"])
    }

    /// G14: most recent sale first, then name case-insensitively, then id —
    /// fully determined by the data, so two sales on one day can't reshuffle
    /// between visits.
    ///
    /// Mutation: reverse the date comparison in `areInSoldOrder`
    /// (`left < right`) → the newest sinks to the bottom → red. Reverse the
    /// name comparison → `beta` leads `Alpha` → red.
    @Test func theSoldSideLeadsWithTheMostRecentSaleThenNameThenID() throws {
        let context = try makeInMemoryContext()
        insertSold("Newest", soldAt: 9_000, forCents: 100, into: context)
        insertSold("beta", soldAt: 1_000, forCents: 100, into: context)
        insertSold("Alpha", soldAt: 1_000, forCents: 100, into: context)
        let twinA = insertSold("Twin", soldAt: 500, forCents: 100, into: context)
        let twinB = insertSold("Twin", soldAt: 500, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.soldItems.map(\.name) == ["Newest", "Alpha", "beta", "Twin", "Twin"])
        // The id tie-break, read off the pair that shares a date and a name.
        let twins = viewModel.soldItems.suffix(2).map(\.id)
        let expected = [twinA.id, twinB.id].sorted { $0.uuidString < $1.uuidString }
        #expect(Array(twins) == expected)
    }

    /// The summary line is `SaleCopy`'s, over the totals `SaleOutcome` summed
    /// — including at zero sales, which is spec Decision 13 replacing
    /// Decision 11: the line is always there, reading `SaleCopy`'s zero form,
    /// so the Sold side's header keeps the slot the Owned side's stats
    /// occupy and the switch above it never jumps.
    ///
    /// Mutation: hide it again (`soldItems.isEmpty ? "" : …`, the nearest
    /// compiling form of the old `isEmpty ? nil`) → the first expectation
    /// fails. Restoring the optional itself no longer compiles, which is the
    /// stronger half of the guarantee.
    @Test func theSummaryLineIsTheSharedCopyOverTheSharedTotals() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        #expect(viewModel.soldSummaryLine == SaleCopy.soldSideSummary(viewModel.soldTotals))
        #expect(viewModel.soldSummaryLine == "0 sold · $0")
        #expect(viewModel.soldTotals == SaleTotals(count: 0, proceedsCents: 0, realisedDeltaCents: 0))

        insertSold("Gone", priceCents: 500_00, soldAt: 1_000, forCents: 800_00, into: context)
        insertSold("Also gone", priceCents: 300_00, soldAt: 2_000, forCents: 150_00, into: context)
        try context.save()
        viewModel.load()

        #expect(viewModel.soldTotals == SaleTotals(
            count: 2,
            proceedsCents: 950_00,
            realisedDeltaCents: 150_00
        ))
        #expect(viewModel.soldSummaryLine == SaleCopy.soldSideSummary(viewModel.soldTotals))
    }

    /// G32's scan half, this file: the sold totals come from
    /// `SaleOutcome.totals` and this view model does no sale arithmetic of
    /// its own, so the Sold side's summary and the Dashboard's card can't
    /// drift into two sums that agree today. `DashboardViewModel` joins this
    /// scan at T010, which is what wires it to the same function.
    @Test func theSoldTotalsComeFromSaleOutcomeAndNotFromArithmeticHere() throws {
        // Both readers of the sum, not just this one: AC7's "the summary
        // matches the card" holds because the Sold side and the Dashboard
        // card run the same arithmetic, and a hand-rolled sum in either of
        // them is the way that stops being true (G32).
        for path in [
            "Trove/ViewModels/ItemListViewModel.swift",
            "Trove/ViewModels/DashboardViewModel.swift",
        ] {
            let code = try SourceScan.production(path)
            try #require(
                code.contains("private(set) var soldTotals"),
                "the scan didn't find the sold totals it guards in \(path) — wrong file?"
            )
            #expect(code.contains("SaleOutcome.totals("), "\(path): the sold totals must come from SaleOutcome")
            #expect(!code.contains("salePriceCents -"), "\(path) must not compute a gain or loss itself")
        }
    }

    /// G7, plan Q5: the Sold side's chips are the categories of *sold* items
    /// only — it never offers one nothing sold sits in — the Owned side's are
    /// unchanged, and `categoryOptions` follows the side on screen under the
    /// one name the chip row reads.
    ///
    /// Mutation: build both pairs from `all` → each side offers all four paths
    /// → red. Make the getter ignore the side (always Owned's) → the Sold
    /// expectation reads the owned pair → red.
    @Test func theSoldSidesChipsAreTheSoldCategoriesOnly() throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", category: "Music/Guitars", into: context)
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        insertSold("Jazzmaster", category: "Music/Amps", soldAt: 1_000, forCents: 100, into: context)
        insertSold("Summicron 35", category: "Photography/Lenses", soldAt: 2_000, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        #expect(viewModel.categoryOptions == ["Music/Guitars", "Photography/Cameras"])
        #expect(viewModel.categoryLabels["Music/Guitars"] == "Guitars")

        viewModel.show(.sold)
        #expect(viewModel.categoryOptions == ["Music/Amps", "Photography/Lenses"])
        #expect(viewModel.categoryLabels["Music/Amps"] == "Amps")
        #expect(viewModel.categoryLabels["Music/Guitars"] == nil, "an owned-only category has no chip here")

        viewModel.show(.owned)
        #expect(viewModel.categoryOptions == ["Music/Guitars", "Photography/Cameras"], "Owned's row is unchanged")
    }

    /// G8, plan Q6: one gate, both sides — "controls need a list to narrow."
    /// The side on screen's own count decides, so an all-sold collection
    /// offers the controls on Sold and not on Owned, and a never-sold one the
    /// other way round.
    ///
    /// Mutation: have the gate read the other side's count → both pairs
    /// invert → red.
    @Test func theNarrowingControlsGateFollowsTheSideOnScreen() throws {
        let allSold = try makeInMemoryContext()
        insertSold("Gone", soldAt: 1_000, forCents: 100, into: allSold)
        try allSold.save()

        let seller = ItemListViewModel(modelContext: allSold)
        seller.load()
        #expect(!seller.offersNarrowingControls, "nothing owned is left to narrow")
        seller.show(.sold)
        #expect(seller.offersNarrowingControls, "one sale is a list to narrow")

        let neverSold = try makeInMemoryContext()
        insertItem("Kept", into: neverSold)
        try neverSold.save()

        let keeper = ItemListViewModel(modelContext: neverSold)
        keeper.load()
        #expect(keeper.offersNarrowingControls)
        keeper.show(.sold)
        #expect(!keeper.offersNarrowingControls, "nothing sold: no controls, the Owned side's rule at zero")
    }

    /// G10, plan Q6/P4: the Sold side's summary follows its narrowing the way
    /// the Owned side's header total follows its filter — "1 sold · …" over a
    /// query matching one sale, and `SaleCopy`'s zero form over one matching
    /// none. The line is still always present, so the switch above it cannot
    /// move.
    ///
    /// Mutation: sum the totals over the unnarrowed `sold` half → both
    /// narrowed readings stay at the whole side's two sales → red.
    @Test func theSoldSummaryFollowsTheSoldSidesNarrowing() throws {
        let context = try makeInMemoryContext()
        insertSold("Gone", priceCents: 500_00, soldAt: 1_000, forCents: 800_00, into: context)
        insertSold("Also gone", priceCents: 300_00, soldAt: 2_000, forCents: 150_00, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.show(.sold)
        try #require(viewModel.soldTotals == SaleTotals(count: 2, proceedsCents: 950_00, realisedDeltaCents: 150_00))

        viewModel.searchText = "also"
        viewModel.load()
        #expect(viewModel.soldItems.map(\.name) == ["Also gone"])
        #expect(viewModel.soldTotals == SaleTotals(count: 1, proceedsCents: 150_00, realisedDeltaCents: -150_00))
        #expect(viewModel.soldSummaryLine == SaleCopy.soldSideSummary(viewModel.soldTotals))
        #expect(viewModel.soldSummaryLine.hasPrefix("1 sold · "))

        viewModel.searchText = "zzz"
        viewModel.load()
        #expect(viewModel.soldItems.isEmpty)
        #expect(viewModel.soldTotals == SaleTotals(count: 0, proceedsCents: 0, realisedDeltaCents: 0))
        #expect(viewModel.soldSummaryLine == "0 sold · $0")
    }

    /// G9, plan Q7: the Sold side goes through `ListEmptyReason.reason` now
    /// that it carries a narrowing of its own — the same five cases and the
    /// same precedence the Owned side has always had, with the `.nothingAdded`
    /// the shared rule hands back mapped to `.nothingSold` afterwards. A Sold
    /// side narrowed to nothing says so rather than claiming nothing was ever
    /// sold (P5).
    ///
    /// Mutation: pick the case directly again (the 006 shape —
    /// `soldItems.isEmpty ? … : .nothingSold`, no `reason(...)`) → the query
    /// and chip cases read `.nothingSold` → red.
    @Test func theSoldSidesEmptyStateIsNothingSoldOrStillSyncing() throws {
        let context = try makeInMemoryContext()
        insertItem("Kept", into: context)
        try context.save()

        let settled = ItemListViewModel(modelContext: context)
        settled.show(.sold)
        #expect(settled.emptyReason == .nothingSold)

        let syncing = ItemListViewModel(modelContext: context, syncMonitor: importingMonitor())
        syncing.show(.sold)
        #expect(syncing.emptyReason == .stillSyncing)

        // A stale query over a side with nothing sold at all is still
        // `.nothingSold`: `reason(...)`'s `totalCount` guard outranks it, so
        // "no matches for that" is never said of an empty side.
        let stale = ItemListViewModel(modelContext: context)
        stale.show(.sold)
        stale.searchText = "zzz"
        stale.load()
        #expect(stale.emptyReason == .nothingSold)

        insertSold("Gone", category: "Music/Guitars", soldAt: 1_000, forCents: 100, into: context)
        try context.save()
        settled.load()
        syncing.load()
        #expect(settled.emptyReason == nil)
        #expect(syncing.emptyReason == nil, "a side with rows on it is not an empty state")

        settled.searchText = "zzz"
        settled.load()
        #expect(settled.emptyReason == .searchMatchedNothing(query: "zzz"))

        settled.searchText = ""
        settled.categoryFilter = "Photography"
        settled.load()
        #expect(settled.emptyReason == .categoryMatchedNothing)

        // The query the person typed a second ago keeps its answer mid-import,
        // exactly as it does on the Owned side.
        syncing.searchText = "zzz"
        syncing.load()
        #expect(syncing.emptyReason == .searchMatchedNothing(query: "zzz"))
    }

    /// Spec Decision 12, and the Owned side's own precedence around it: an
    /// Owned side emptied by *selling* says so, an app that has never held
    /// anything still gets the first-launch case, and mid-import neither
    /// claim is made at all.
    ///
    /// Mutations: drop the `!soldItems.isEmpty` check in `ownedEmptyReason`
    /// → the first expectation reads `.nothingAdded` → red; map to
    /// `.everythingSold` before `reason(...)` weighs `stillSyncing` → the
    /// third reads `.everythingSold` → red.
    @Test func theEmptiedOwnedSideSaysEverythingSold() throws {
        let context = try makeInMemoryContext()
        insertSold("Gone", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        #expect(
            viewModel.emptyReason == .everythingSold,
            "an Owned side emptied by selling still reads as a first launch"
        )
        #expect(viewModel.emptyReason != .nothingSold, "the Sold side's case leaked across")

        let empty = ItemListViewModel(modelContext: try makeInMemoryContext())
        empty.load()
        #expect(
            empty.emptyReason == .nothingAdded,
            "a collection that has never held anything is still a first launch"
        )

        let syncing = ItemListViewModel(modelContext: context, syncMonitor: importingMonitor())
        syncing.load()
        #expect(
            syncing.emptyReason == .stillSyncing,
            "the sold half is here but the owned half may still be arriving — `stillSyncing` still wins"
        )
    }

    /// G25: the Everything-sold guard weighs `soldTotalCount`, not
    /// `soldItems.count` — which since 014 is the *narrowed* sold half. A
    /// no-match query left behind on the Sold side must not turn an emptied
    /// Owned side back into a first launch; that is the hidden side leaking
    /// into the visible one that Decision 4 forbids.
    ///
    /// Mutation: have the guard read `!soldItems.isEmpty` again → the first
    /// expectation reads `.nothingAdded` → red.
    @Test func theEmptiedOwnedSideStillSaysEverythingSoldWithANoMatchQueryLeftOnSold() throws {
        let context = try makeInMemoryContext()
        insertSold("Gone", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.show(.sold)
        viewModel.searchText = "zzz"
        viewModel.load()
        try #require(viewModel.soldItems.isEmpty, "the Sold side is narrowed to nothing")

        viewModel.show(.owned)
        #expect(
            viewModel.emptyReason == .everythingSold,
            "a query left on the hidden side changed what the visible one says"
        )

        let neverSold = ItemListViewModel(modelContext: try makeInMemoryContext())
        neverSold.load()
        #expect(neverSold.emptyReason == .nothingAdded, "and nothing ever sold is still a first launch")
    }

    /// The mapping is the `.nothingAdded` case's alone: a narrowed-to-nothing
    /// Owned side keeps its filter copy even with sales on the other side
    /// (plan §4).
    @Test func aNarrowedOwnedSideKeepsItsFilterCopyWithSalesPresent() throws {
        let context = try makeInMemoryContext()
        insertItem("Kept", category: "Music/Guitars", into: context)
        insertSold("Gone", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.searchText = "hasselblad"
        viewModel.load()

        #expect(viewModel.emptyReason == .searchMatchedNothing(query: "hasselblad"))
    }

    /// Dragging is the Owned side's alone: the Sold side is ordered by the
    /// data (plan Q9) and has no manual order to rearrange.
    @Test func reorderingIsRefusedOnTheSoldSide() throws {
        let context = try makeInMemoryContext()
        insertItem("Kept", into: context)
        insertSold("Gone", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .custom
        viewModel.load()
        try #require(viewModel.canReorder)

        viewModel.show(.sold)
        #expect(!viewModel.canReorder)

        viewModel.show(.owned)
        #expect(viewModel.canReorder, "coming back restores it — the sort survives the trip")
    }

    /// The Sold side's swipe deletes through the same one path (P16), which
    /// is what keeps `DeletionGuardTests`' structural rule true of it.
    /// Refetched on a second context, so an unsaved delete can't pass.
    @Test func deletingWorksOnASoldItemToo() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        insertItem("Kept", into: context)
        let gone = insertSold("Gone", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.show(.sold)
        try #require(viewModel.soldItems.map(\.name) == ["Gone"])

        viewModel.delete(id: gone.id)

        #expect(viewModel.soldItems.isEmpty)
        #expect(viewModel.items.map(\.name) == ["Kept"], "the Owned side reloaded with it")
        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<Item>()).map(\.name) == ["Kept"])
    }
}

@Suite("ItemListViewModel — changing side")
struct ItemListViewModelShowSideTests {
    /// G4, Owned → Sold → Owned: the Owned side's four values — chip, query,
    /// un-valued and a non-default sort — survive a visit to the Sold side and
    /// are still in force on the rows when it comes back (014 Decision 4,
    /// replacing 006 Q15's clearing). While Sold is up, none of them is
    /// readable through the controls' own property names: the hidden side
    /// never leaks into the visible one.
    ///
    /// Mutations, both run: restore the three clears in `show(_:)` → the four
    /// values read back empty → red; give both sides one shared `Narrowing`
    /// → the Sold side opens under "Leica"/"Photography" and `soldItems`
    /// empties → red.
    @Test func theOwnedSideKeepsItsNarrowingWhileTheSoldSideIsVisited() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", valueCents: nil, purchasedAt: 200, into: context)
        insertItem("Telecaster", category: "Music/Guitars", valueCents: 120_00, purchasedAt: 100, into: context)
        insertSold("Summicron 35", category: "Photography/Lenses", soldAt: 2_000, forCents: 100, into: context)
        insertSold("Jazzmaster", category: "Music/Guitars", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.searchText = "Leica"
        viewModel.showsOnlyUnvalued = true
        viewModel.sortOrder = .currentValueAscending
        viewModel.load()
        try #require(viewModel.items.map(\.name) == ["Leica M6"])

        viewModel.show(.sold)

        #expect(viewModel.side == .sold)
        #expect(viewModel.categoryFilter.isEmpty, "Owned's chip is visible on the Sold side")
        #expect(viewModel.searchText.isEmpty, "Owned's query is visible on the Sold side")
        #expect(!viewModel.showsOnlyUnvalued)
        #expect(viewModel.soldSortOrder == .soldDate, "the Sold side opens on its own default")
        #expect(
            viewModel.soldItems.map(\.name) == ["Summicron 35", "Jazzmaster"],
            "the Sold side is narrowed by its own (clean) narrowing, not by Owned's"
        )

        viewModel.show(.owned)

        #expect(viewModel.categoryFilter == "Photography")
        #expect(viewModel.searchText == "Leica")
        #expect(viewModel.showsOnlyUnvalued)
        #expect(viewModel.sortOrder == .currentValueAscending)
        #expect(viewModel.items.map(\.name) == ["Leica M6"], "and the rows are narrowed by them again")
    }

    /// G4, the other direction: the Sold side's three values — chip, query and
    /// its own sort — survive a visit to the Owned side, and while Owned is up
    /// none of them narrows anything there.
    ///
    /// Mutations, both run: restore the three clears in `show(_:)` → the Sold
    /// values read back empty → red; one shared `Narrowing` → the Owned side
    /// opens under "Music"/"jazz" and `items` empties → red.
    @Test func theSoldSideKeepsItsNarrowingWhileTheOwnedSideIsVisited() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", purchasedAt: 200, into: context)
        insertItem("Telecaster", category: "Music/Guitars", purchasedAt: 100, into: context)
        insertSold("Summicron 35", category: "Photography/Lenses", soldAt: 2_000, forCents: 100, into: context)
        insertSold("Jazzmaster", category: "Music/Guitars", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.show(.sold)
        viewModel.categoryFilter = "Music"
        viewModel.searchText = "jazz"
        viewModel.soldSortOrder = .salePriceAscending
        viewModel.load()
        try #require(viewModel.soldItems.map(\.name) == ["Jazzmaster"])

        viewModel.show(.owned)

        #expect(viewModel.categoryFilter.isEmpty, "the Sold side's chip is visible on Owned")
        #expect(viewModel.searchText.isEmpty, "the Sold side's query is visible on Owned")
        #expect(viewModel.sortOrder == .purchaseDate, "Owned's own Sort By is untouched")
        #expect(
            viewModel.items.map(\.name) == ["Leica M6", "Telecaster"],
            "the Owned rows are narrowed by Owned's (clean) narrowing"
        )

        viewModel.show(.sold)

        #expect(viewModel.categoryFilter == "Music")
        #expect(viewModel.searchText == "jazz")
        #expect(viewModel.soldSortOrder == .salePriceAscending)
        #expect(viewModel.soldItems.map(\.name) == ["Jazzmaster"], "and the sold rows are narrowed by them again")
    }

    /// G6, plan Q2: un-valued is Owned-only *structurally*. A write while the
    /// Sold side is on screen is refused — the Sold copy can never hold
    /// `true`, so the shared chip row never renders the chip there — and
    /// Owned's own copy is untouched by the attempt.
    ///
    /// Mutations, both run: drop the guard so the setter writes through
    /// `narrowing` → the read after the write on Sold is `true` → red; drop
    /// the guard leaving the write on `ownedNarrowing` → the `false` written
    /// on Sold lands on Owned and the last expectation → red.
    @Test func theUnvaluedFilterIsRefusedWhileTheSoldSideIsOnScreen() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", valueCents: nil, into: context)
        insertItem("Telecaster", valueCents: 120_00, into: context)
        insertSold("Jazzmaster", valueCents: nil, soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.showsOnlyUnvalued = true
        viewModel.load()
        try #require(viewModel.items.map(\.name) == ["Leica M6"])

        viewModel.show(.sold)
        viewModel.showsOnlyUnvalued = true
        #expect(!viewModel.showsOnlyUnvalued, "the Sold side has no un-valued filter to turn on")

        viewModel.showsOnlyUnvalued = false
        viewModel.load()
        #expect(viewModel.soldItems.map(\.name) == ["Jazzmaster"], "neither write narrowed the sold rows")

        viewModel.show(.owned)
        #expect(viewModel.showsOnlyUnvalued, "Owned's own copy survived both attempts")
        #expect(viewModel.items.map(\.name) == ["Leica M6"])
    }

    /// G33's third case: asking for the side already on screen is not a
    /// change, so it leaves the narrowing alone — which is what lets the
    /// router's `.category` request call `show(.owned)` first and then write
    /// the filter it came to set.
    @Test func askingForTheSideAlreadyOnScreenLeavesTheFilterAlone() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        insertItem("Telecaster", category: "Music/Guitars", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.searchText = "Leica"
        viewModel.showsOnlyUnvalued = false

        viewModel.show(.owned)

        #expect(viewModel.categoryFilter == "Photography")
        #expect(viewModel.searchText == "Leica")
        #expect(viewModel.items.map(\.name) == ["Leica M6"], "and it reloaded under that filter")
    }

    /// The side is a plain launch-time default (006 plan Q4): the tab opens on
    /// Owned however the last visit ended, because nothing stores it.
    ///
    /// G5 extends that to the per-side state 014 adds: nothing about either
    /// side's narrowing or sort is stored either, so a fresh view model starts
    /// clean on *both* sides — Owned on "Date", Sold on "Date sold" (P8).
    @Test func aFreshViewModelOpensOnOwned() throws {
        let context = try makeInMemoryContext()
        insertSold("Gone", category: "Music/Guitars", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.show(.sold)
        viewModel.categoryFilter = "Music"
        viewModel.searchText = "gone"
        viewModel.soldSortOrder = .name
        viewModel.sortOrder = .currentValue
        try #require(viewModel.side == .sold)

        let fresh = ItemListViewModel(modelContext: context)
        #expect(fresh.side == .owned)
        #expect(fresh.categoryFilter.isEmpty)
        #expect(fresh.searchText.isEmpty)
        #expect(!fresh.showsOnlyUnvalued)
        #expect(fresh.sortOrder == .purchaseDate)
        #expect(fresh.visibleSortLabel == "Date")

        fresh.show(.sold)
        #expect(fresh.categoryFilter.isEmpty, "the Sold side starts clean too")
        #expect(fresh.searchText.isEmpty)
        #expect(!fresh.showsOnlyUnvalued)
        #expect(fresh.soldSortOrder == .soldDate)
        #expect(fresh.visibleSortLabel == "Date sold")
    }
}

@Suite("ItemListViewModel — the CSV's two halves")
struct ItemListViewModelSoldExportTests {
    /// G15: the CSV is the Owned side's visible rows, in visible order, then
    /// the sold rows that pass the *same* narrowing, in Sold-side order — so
    /// a visible chip narrows both halves and the coverage label stays true.
    ///
    /// Mutation: skip the narrowing on the sold half (`soldItems` in place of
    /// `exportableSoldItems`) → the filtered CSV grows the Jazzmaster → red.
    @Test func aVisibleFilterNarrowsTheSoldHalfOfTheCSVToo() async throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", purchasedAt: 200, into: context)
        insertItem("Telecaster", category: "Music/Guitars", purchasedAt: 100, into: context)
        insertSold("Summicron 35", category: "Photography/Lenses", soldAt: 2_000, forCents: 100, into: context)
        insertSold("Jazzmaster", category: "Music/Guitars", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, exportService: spy)
        viewModel.categoryFilter = "Photography"
        viewModel.load()
        await viewModel.exportCSV()

        let filtered = try #require(spy.tables.first)
        #expect(filtered.headers == ExportSchema.itemHeaders)
        #expect(filtered.rows.map { $0[0] } == ["Leica M6", "Summicron 35"])
        #expect(viewModel.exportCoverageLabel == "Category: Photography")

        // Unfiltered: every owned row in visible order, then every sold row.
        viewModel.categoryFilter = ""
        viewModel.load()
        await viewModel.exportCSV()
        let whole = try #require(spy.tables.last)
        #expect(whole.rows.map { $0[0] } == ["Leica M6", "Telecaster", "Summicron 35", "Jazzmaster"])
    }

    /// A search narrows both halves the same way a chip does — the second of
    /// the three filters `narrowed(_:)` shares between the sides.
    @Test func aQueryNarrowsBothHalvesToo() async throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", into: context)
        insertItem("Telecaster", into: context)
        insertSold("Leica Summicron", soldAt: 2_000, forCents: 100, into: context)
        insertSold("Jazzmaster", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, exportService: spy)
        viewModel.searchText = "leica"
        viewModel.load()
        await viewModel.exportCSV()

        let table = try #require(spy.tables.first)
        #expect(table.rows.map { $0[0] } == ["Leica M6", "Leica Summicron"])
    }

    /// G16's list half: the PDF is the owned collection only, entries and
    /// cover alike, so its figures are the Dashboard's collection figures
    /// (criterion 14) rather than a mix of what is owned and what was sold.
    ///
    /// Mutations, both run: build the entries from `items +
    /// exportableSoldItems` → the entries read the sold item → red; count the
    /// sold half into the cover → `itemCount` reads 2 and paid grows → red.
    @Test func thePDFLeavesSoldItemsOutOfItsEntriesAndItsCover() async throws {
        let context = try makeInMemoryContext()
        insertItem("Kept", priceCents: 100_00, valueCents: 150_00, into: context)
        insertSold("Gone", priceCents: 50_00, valueCents: nil, soldAt: 1_000, forCents: 75_00, into: context)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, exportService: spy)
        viewModel.load()
        await viewModel.exportPDF()

        let document = try #require(spy.documents.first)
        #expect(document.entries.map(\.name) == ["Kept"])
        #expect(document.cover.itemCount == 1)
        switch document.cover.totals {
        case let .items(value, paid, unvalued):
            #expect((value, paid, unvalued) == (150_00, 100_00, 0))
        case .wishlist:
            Issue.record("the items document carries wishlist totals")
        }
    }

    /// Plan Q5's split gate: an all-sold collection has a CSV worth writing
    /// and nothing at all to put in a PDF. One `canExport` would have to be
    /// wrong about one of them.
    @Test func anAllSoldCollectionCanExportACSVButNotAPDF() async throws {
        let context = try makeInMemoryContext()
        insertSold("Gone", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        #expect(viewModel.canExportCSV)
        #expect(!viewModel.canExportPDF)

        await viewModel.exportCSV()
        await viewModel.exportPDF()

        #expect(spy.tables.map { $0.rows.map { $0[0] } } == [["Gone"]])
        #expect(spy.documents.isEmpty, "the PDF intent's own guard backs up the disabled row")
    }

    /// The other end of the gate: a narrowing that excludes both halves
    /// disables the CSV row, so an empty file is still never produced
    /// (criterion 2).
    @Test func aFilterThatExcludesBothHalvesDisablesTheCSVToo() async throws {
        let context = try makeInMemoryContext()
        insertItem("Telecaster", category: "Music/Guitars", into: context)
        insertSold("Jazzmaster", category: "Music/Guitars", soldAt: 1_000, forCents: 100, into: context)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, exportService: spy)
        viewModel.categoryFilter = "Photography"
        viewModel.load()

        #expect(!viewModel.canExportCSV)
        #expect(!viewModel.canExportPDF)

        await viewModel.exportCSV()
        #expect(spy.tables.isEmpty)
    }
}

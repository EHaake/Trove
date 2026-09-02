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
        #expect(!viewModel.canExport)

        insertItem("Telecaster", into: context)
        try context.save()
        viewModel.load()
        #expect(viewModel.canExport)

        viewModel.categoryFilter = "Photography"
        viewModel.load()
        #expect(!viewModel.canExport)
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
                    notes: nil, firstPhotoID: nil
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
                            serialNumber: nil, notes: nil, firstPhotoID: nil
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


/// T012's guards: the blank template stages through the existing export
/// path, ungated by `canExport` — an empty collection is its audience.
struct ItemListViewModelTemplateTests {
    @Test func theTemplateStagesHeaderOnlyBytesFromAnEmptyCollection() async throws {
        let context = try makeInMemoryContext()
        let spy = ExportServiceSpy()
        let viewModel = ItemListViewModel(modelContext: context, exportService: spy)
        viewModel.load()
        try #require(viewModel.canExport == false, "the empty collection is the point")

        await viewModel.exportBlankTemplate()

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
        #expect(viewModel.stagedExport?.filenames == [ExportFilename.itemsTemplate])
    }
}

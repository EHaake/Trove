import Foundation
import SwiftData
import Testing
@testable import Trove

private func insertItem(
    _ name: String,
    category: String = "Music/Guitars",
    desire: Int = 3,
    valueCents: Int? = nil,
    serial: String? = nil,
    purchasedAt seconds: TimeInterval = 0,
    into context: ModelContext
) {
    context.insert(
        Item(
            name: name,
            categoryPath: category,
            purchaseDate: Date(timeIntervalSince1970: seconds),
            serialNumber: serial,
            currentValueCents: valueCents,
            desireToKeep: desire
        )
    )
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

    @Test func ordersSeveralUnvaluedItemsAmongThemselvesByName() throws {
        let context = try makeInMemoryContext()
        insertItem("Zither", valueCents: nil, into: context)
        insertItem("Accordion", valueCents: nil, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .currentValue
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Accordion", "Zither"])
    }

    /// Equal sort keys must not leave the order up to the fetch, which
    /// guarantees nothing — rows reshuffling between launches reads as a bug.
    @Test func breaksTiesByNameSoOrderIsDeterministic() throws {
        let context = try makeInMemoryContext()
        insertItem("Charlie", desire: 3, into: context)
        insertItem("alpha", desire: 3, into: context)
        insertItem("Bravo", desire: 3, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .desireToKeep
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["alpha", "Bravo", "Charlie"])
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

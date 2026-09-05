import Foundation
import SwiftData
import Testing
@testable import Trove

private func insertWanted(
    _ name: String,
    category: String = "Music/Amps",
    costCents: Int = 10_000,
    order: Int = 0,
    desire: Int = 1,
    into context: ModelContext
) {
    let wanted = WishlistItem(
        name: name,
        categoryPath: category,
        estimatedCostCents: costCents,
        sortOrder: order
    )
    wanted.desireToOwn = desire
    context.insert(wanted)
}

@Suite("WishlistViewModel — loading and filtering")
struct WishlistFilterTests {
    @Test func startsEmptyBeforeLoading() throws {
        let viewModel = WishlistViewModel(modelContext: try makeInMemoryContext())
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.isEmpty)
    }

    @Test func loadsEverythingWhenNoFilterIsSet() throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron", category: "Photography/Lenses", into: context)
        insertWanted("Vox AC15", category: "Music/Amps", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.items.count == 2)
    }

    @Test func filtersByCategoryPrefix() throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron", category: "Photography/Lenses", into: context)
        insertWanted("Hasselblad 80mm", category: "Photography/Lenses", into: context)
        insertWanted("Vox AC15", category: "Music/Amps", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.load()

        #expect(viewModel.items.count == 2)
    }

    /// The stricter of the two shared rules, same as the item list.
    @Test func aFilterStopsAtASegmentBoundary() throws {
        let context = try makeInMemoryContext()
        insertWanted("Headphones", category: "Audio/Headphones", into: context)
        insertWanted("Magazine", category: "Audiophile/Magazines", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.categoryFilter = "Audio"
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Headphones"])
    }

    @Test func offersEveryCategoryEvenWhileFiltered() throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron", category: "Photography/Lenses", into: context)
        insertWanted("Vox AC15", category: "Music/Amps", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.load()

        #expect(viewModel.categoryOptions == ["Music/Amps", "Photography/Lenses"])
    }

    @Test func totalsOnlyWhatIsOnScreen() throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron", category: "Photography/Lenses", costCents: 240_000, into: context)
        insertWanted("Vox AC15", category: "Music/Amps", costCents: 105_000, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        #expect(viewModel.totalEstimatedCostCents == 345_000)

        viewModel.categoryFilter = "Music"
        viewModel.load()
        #expect(viewModel.totalEstimatedCostCents == 105_000)
    }
}

@Suite("WishlistViewModel — search")
struct WishlistSearchTests {
    @Test func matchesOnName() throws {
        let context = try makeInMemoryContext()
        insertWanted("Leica Summicron 35mm", into: context)
        insertWanted("Vox AC15", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.searchText = "summicron"
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Leica Summicron 35mm"])
    }

    @Test(arguments: ["", "  "])
    func aBlankQueryLeavesTheListWhole(query: String) throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron", into: context)
        insertWanted("Vox AC15", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.searchText = query
        viewModel.load()

        #expect(viewModel.items.count == 2)
    }

    /// Same contract as the item list: the two controls narrow one set.
    @Test func combinesWithTheCategoryFilterRatherThanReplacingIt() throws {
        let context = try makeInMemoryContext()
        insertWanted("Leica Summicron", category: "Photography/Lenses", into: context)
        insertWanted("Leica-branded strap", category: "Accessories", into: context)
        insertWanted("Voigtlander 40mm", category: "Photography/Lenses", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.searchText = "Leica"
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Leica Summicron"])
    }

    @Test func keepsEveryCategoryChipWhileSearching() throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron", category: "Photography/Lenses", into: context)
        insertWanted("Vox AC15", category: "Music/Amps", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.searchText = "summicron"
        viewModel.load()

        #expect(viewModel.items.count == 1)
        #expect(viewModel.categoryOptions == ["Music/Amps", "Photography/Lenses"])
    }
}

@Suite("WishlistViewModel — ordering")
struct WishlistOrderingTests {
    @Test func defaultsToTheUsersOwnOrder() throws {
        let context = try makeInMemoryContext()
        insertWanted("Third", order: 2, into: context)
        insertWanted("First", order: 0, into: context)
        insertWanted("Second", order: 1, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.sortOrder == .custom)
        #expect(viewModel.items.map(\.name) == ["First", "Second", "Third"])
    }

    /// T025a's rename, pinned on both lists — and pinned because the rename
    /// itself found nothing guarding the old string: every test stayed green
    /// while "Yours" became "Custom", the same under-pinning T010a found on
    /// the delete copy. A silent revert would now fail here.
    @Test func theManualOptionReadsCustomOnBothLists() {
        #expect(WishlistViewModel.SortOrder.custom.label == "Custom")
        #expect(ItemListViewModel.SortOrder.custom.label == "Custom")
    }

    /// Cheapest first as of `010` — plan.md's recorded direction call
    /// ("what could I realistically buy soon"), deliberately flipping
    /// `001`'s dearest-first. This test flipped with it, in T031's commit.
    @Test func sortsByCostWithTheCheapestFirst() throws {
        let context = try makeInMemoryContext()
        insertWanted("Cheap", costCents: 5_000, order: 0, into: context)
        insertWanted("Dear", costCents: 240_000, order: 1, into: context)
        insertWanted("Middling", costCents: 105_000, order: 2, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.sortOrder = .cost
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Cheap", "Middling", "Dear"])
    }

    // MARK: - The 010 sorts (T031/T032)

    /// The descending half of the Cost pair (T033a) — 001's dearest-first,
    /// back as an explicit option rather than the default.
    @Test func costDescendingLeadsWithTheDearest() throws {
        let context = try makeInMemoryContext()
        insertWanted("Cheap", costCents: 5_000, order: 0, into: context)
        insertWanted("Dear", costCents: 240_000, order: 1, into: context)
        insertWanted("Middling", costCents: 105_000, order: 2, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.sortOrder = .costDescending
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Dear", "Middling", "Cheap"])
    }

    /// Manual order runs opposite the ratings on purpose, so a sort that
    /// consulted the wrong field — or the right one backwards — shows.
    @Test func sortsByDesireWithTheMostWantedFirst() throws {
        let context = try makeInMemoryContext()
        insertWanted("Someday", order: 0, desire: 1, into: context)
        insertWanted("Next", order: 1, desire: 3, into: context)
        insertWanted("Soon", order: 2, desire: 2, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.sortOrder = .desire
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Next", "Soon", "Someday"])
    }

    /// Case runs against the alphabet on purpose — a case-sensitive compare
    /// would put "Bravo" before "alpha".
    @Test func sortsAlphabeticallyIgnoringCase() throws {
        let context = try makeInMemoryContext()
        insertWanted("charlie", order: 0, into: context)
        insertWanted("Bravo", order: 1, into: context)
        insertWanted("alpha", order: 2, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.sortOrder = .alphabetical
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["alpha", "Bravo", "charlie"])
    }

    /// spec.md's confirmed tie-break, on the sort where ties are the common
    /// case (three tiers). The names run opposite the manual order, so the
    /// old name-first fallback would order this list backwards — the tie
    /// must be the user's own arrangement, not the alphabet.
    @Test func desireTiesResolveByManualOrder() throws {
        let context = try makeInMemoryContext()
        insertWanted("Charlie", order: 0, desire: 2, into: context)
        insertWanted("Bravo", order: 1, desire: 2, into: context)
        insertWanted("Alpha", order: 2, desire: 2, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.sortOrder = .desire
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Charlie", "Bravo", "Alpha"])
    }

    /// The same confirmed rule now applies to Cost, which `001` shipped with
    /// a name-first fallback — same opposing construction as above.
    @Test func costTiesResolveByManualOrder() throws {
        let context = try makeInMemoryContext()
        insertWanted("Bravo", costCents: 105_000, order: 0, into: context)
        insertWanted("Alpha", costCents: 105_000, order: 1, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.sortOrder = .cost
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Bravo", "Alpha"])
    }

    /// Two identically-named items — spec.md's own example for the
    /// Alphabetical tie — keep the user's relative order. Read back by
    /// position, since the names can't tell the rows apart.
    @Test func identicalNamesUnderAlphabeticalKeepTheManualOrder() throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron", costCents: 240_000, order: 1, into: context)
        insertWanted("Summicron", costCents: 105_000, order: 0, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.sortOrder = .alphabetical
        viewModel.load()

        #expect(viewModel.items.map(\.sortOrder) == [0, 1])
    }

    /// Mirrors `ItemListViewModelTests.filteringAndSortingApplyTogether`:
    /// a category filter and either new sort stay active together.
    @Test func filteringAndTheNewSortsApplyTogether() throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron", category: "Photography/Lenses", order: 0, desire: 1, into: context)
        insertWanted("Xpan", category: "Photography/Cameras", order: 1, desire: 3, into: context)
        insertWanted("Vox AC15", category: "Music/Amps", order: 2, desire: 2, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.categoryFilter = "Photography"
        viewModel.sortOrder = .desire
        viewModel.load()
        #expect(viewModel.items.map(\.name) == ["Xpan", "Summicron"])

        viewModel.sortOrder = .alphabetical
        viewModel.load()
        #expect(viewModel.items.map(\.name) == ["Summicron", "Xpan"])
    }

    /// Items created before manual ordering existed all sit at 0, so the
    /// fallback has to be deterministic or the list reshuffles per launch.
    @Test func breaksTiesByNameSoOrderIsDeterministic() throws {
        let context = try makeInMemoryContext()
        insertWanted("Charlie", order: 0, into: context)
        insertWanted("alpha", order: 0, into: context)
        insertWanted("Bravo", order: 0, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["alpha", "Bravo", "Charlie"])
    }

    @Test func repeatedLoadsProduceTheSameOrder() throws {
        let context = try makeInMemoryContext()
        for index in 0..<6 {
            insertWanted("Item \(index)", order: 0, into: context)
        }
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        let first = viewModel.items.map(\.name)
        viewModel.load()

        #expect(first == viewModel.items.map(\.name))
    }

    // MARK: - Dragging

    @Test func movingARowRenumbersEveryPositionAndPersists() throws {
        let context = try makeInMemoryContext()
        insertWanted("First", order: 0, into: context)
        insertWanted("Second", order: 1, into: context)
        insertWanted("Third", order: 2, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(viewModel.items.map(\.name) == ["Third", "First", "Second"])
        #expect(viewModel.items.map(\.sortOrder) == [0, 1, 2])

        // A fresh *context* over the same container — the same context
        // reloaded hands back its own unsaved changes, so the original form
        // of this check passed even with the save deleted. Found at T026,
        // when the item-list mirror inherited the shape and its mutation
        // survived; fixed in both places.
        let reloaded = WishlistViewModel(modelContext: ModelContext(context.container))
        reloaded.load()
        #expect(reloaded.items.map(\.name) == ["Third", "First", "Second"])
    }

    /// The invariant, stated the way `PhotoSelection` states its own: a row's
    /// position in the list is its `sortOrder`, with no gaps or collisions.
    @Test func positionsStayDenseAndUniqueAcrossManyMoves() throws {
        let context = try makeInMemoryContext()
        for index in 0..<6 {
            insertWanted("Item \(index)", order: index, into: context)
        }
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()

        for (from, to) in [(5, 0), (0, 3), (2, 5), (4, 1), (1, 4)] {
            viewModel.move(fromOffsets: IndexSet(integer: from), toOffset: to)
            #expect(viewModel.items.map(\.sortOrder) == Array(0..<viewModel.items.count))
        }
    }

    @Test func reorderingIsOnlyOfferedAgainstTheWholeListInItsOwnOrder() throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron", category: "Photography/Lenses", order: 0, into: context)
        insertWanted("Vox AC15", category: "Music/Amps", order: 1, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        #expect(viewModel.canReorder)

        viewModel.sortOrder = .cost
        #expect(viewModel.canReorder == false)

        viewModel.sortOrder = .custom
        viewModel.categoryFilter = "Photography"
        #expect(viewModel.canReorder == false)

        viewModel.categoryFilter = ""
        viewModel.searchText = "vox"
        #expect(viewModel.canReorder == false)

        viewModel.searchText = "   "
        #expect(viewModel.canReorder)
    }

    /// A drag that slipped through while filtered would renumber the visible
    /// rows only, silently reshuffling the ones off screen.
    @Test func aMoveIsIgnoredWhenReorderingIsNotAvailable() throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron", category: "Photography/Lenses", costCents: 240_000, order: 0, into: context)
        insertWanted("Vox AC15", category: "Music/Amps", costCents: 105_000, order: 1, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.sortOrder = .cost
        viewModel.load()
        viewModel.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        // Cheapest first, so Vox leads on screen — while the sortOrders,
        // read in that screen order, stay the untouched manual positions.
        #expect(viewModel.items.map(\.name) == ["Vox AC15", "Summicron"])
        #expect(viewModel.items.map(\.sortOrder) == [1, 0])
    }

    // MARK: - VoiceOver moves (T028b)

    /// The wishlist's mirror of `ItemReorderTests`' accessible-move suite —
    /// spot checks per the T020/T022 precedent, since the methods are
    /// duplicated per entity while only the renumbering helper is shared.
    @Test func aVoiceOverMoveStepsOneRowAndPersists() throws {
        let context = try makeInMemoryContext()
        insertWanted("First", order: 0, into: context)
        insertWanted("Second", order: 1, into: context)
        insertWanted("Third", order: 2, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        let first = try #require(viewModel.items.first)
        viewModel.moveDown(id: first.id)

        #expect(viewModel.items.map(\.name) == ["Second", "First", "Third"])
        #expect(viewModel.items.map(\.sortOrder) == [0, 1, 2])

        let reloaded = WishlistViewModel(modelContext: ModelContext(context.container))
        reloaded.load()
        #expect(reloaded.items.map(\.name) == ["Second", "First", "Third"])
    }

    /// Ends and gate in one pass: no move offered off the top or bottom, and
    /// none at all while the sort isn't Custom.
    @Test func accessibleMovesStopAtTheEndsAndBehindTheGate() throws {
        let context = try makeInMemoryContext()
        insertWanted("First", order: 0, into: context)
        insertWanted("Second", order: 1, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        let first = try #require(viewModel.items.first)
        let last = try #require(viewModel.items.last)

        #expect(viewModel.canMoveUp(id: first.id) == false)
        #expect(viewModel.canMoveDown(id: last.id) == false)
        viewModel.moveUp(id: first.id)
        #expect(viewModel.items.map(\.name) == ["First", "Second"])

        viewModel.sortOrder = .cost
        #expect(viewModel.canMoveDown(id: first.id) == false)
        viewModel.moveDown(id: first.id)
        #expect(viewModel.items.map(\.sortOrder) == [0, 1])
    }
}

/// Filter chips come from the screen's own rows, while autocomplete spans both
/// entities. Same distinction as prefix-versus-scope matching: one rule was
/// serving two jobs that want opposite answers.
/// The Market sort and the row's trend on the wanted list (002/T012, spec
/// criteria 13–14, Decision 21) — the mirror of
/// `ItemListViewModelMarketSortTests`. Written out rather than shared: the
/// two lists have one rule, and the way that rule stays true is that both
/// suites can fail independently.
@Suite("WishlistViewModel — the Market sort")
struct WishlistMarketSortTests {
    private let clock = Date(timeIntervalSince1970: 1_800_000_000)

    private func product(_ id: Int) -> MarketProduct {
        MarketProduct(
            id: id,
            slug: "martin-d-18",
            title: "Martin D-18",
            usedLowCents: 100_000,
            usedTotal: 108,
            listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
        )
    }

    /// One recorded refresh for a wanted item — the `.wanted` half of the
    /// same writer the owned suite uses.
    private func record(
        _ medianCents: Int?,
        for id: UUID,
        fetchedAt: Date,
        productID: Int = 182_769,
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
            for: MarketSubjectKey(subjectID: id, kind: .wanted),
            in: context
        )
    }

    private func viewModel(over context: ModelContext) -> WishlistViewModel {
        WishlistViewModel(modelContext: context, now: { self.clock })
    }

    private func id(of name: String, in context: ModelContext) throws -> UUID {
        let items = try context.fetch(FetchDescriptor<WishlistItem>())
        return try #require(items.first(where: { $0.name == name })?.id, "\(name) wasn't inserted")
    }

    /// See the owned list's twin: a current median leads; withheld, stale
    /// and unmatched fall to the bottom in the person's own order. The stale
    /// figure is the largest number here too.
    @Test func theMarketSortLeadsWithTheDearestCurrentMedianAndSinksTheRest() throws {
        let context = try makeInMemoryContext()
        insertWanted("Cheap", order: 5, into: context)
        insertWanted("Dear", order: 6, into: context)
        insertWanted("Stale", order: 0, into: context)
        insertWanted("Withheld", order: 1, into: context)
        insertWanted("Unmatched", order: 2, into: context)
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

    @Test func theAscendingMarketSortLeadsWithTheCheapestAndStillSinksTheRest() throws {
        let context = try makeInMemoryContext()
        insertWanted("Cheap", order: 5, into: context)
        insertWanted("Dear", order: 6, into: context)
        insertWanted("Stale", order: 0, into: context)
        insertWanted("Withheld", order: 1, into: context)
        insertWanted("Unmatched", order: 2, into: context)
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

    /// Insertion order, name order and manual order all differ here, so the
    /// tie-break is the only rule that produces this answer.
    @Test func marketFigureTiesResolveByManualOrder() throws {
        let context = try makeInMemoryContext()
        insertWanted("alpha", order: 2, into: context)
        insertWanted("Charlie", order: 0, into: context)
        insertWanted("Bravo", order: 1, into: context)
        for name in ["alpha", "Charlie", "Bravo"] {
            try record(140_000, for: try id(of: name, in: context), fetchedAt: clock, in: context)
        }
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.sortOrder = .marketFigure
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Charlie", "Bravo", "alpha"])
    }

    @Test func unmatchedItemsShowNoTrend() throws {
        let context = try makeInMemoryContext()
        insertWanted("Unmatched", into: context)
        insertWanted("Matched", into: context)
        try record(140_000, for: try id(of: "Matched", in: context), fetchedAt: clock, in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(viewModel.trend(for: try id(of: "Unmatched", in: context)) == nil)
        #expect(viewModel.marketSummaries[try id(of: "Unmatched", in: context)] == nil)
    }

    @Test func aMatchedItemWithARisingHistoryReadsUp() throws {
        let context = try makeInMemoryContext()
        insertWanted("D-18", into: context)
        let id = try id(of: "D-18", in: context)
        try record(100_000, for: id, fetchedAt: clock.addingTimeInterval(-14 * 24 * 60 * 60), in: context)
        try record(110_000, for: id, fetchedAt: clock, in: context)
        try context.save()

        let viewModel = viewModel(over: context)
        viewModel.load()

        #expect(viewModel.trend(for: id) == .up)
    }

    /// Q11's positions on this list: the Market pair straight after the Cost
    /// pair, descending first — the labels themselves are pinned once, in
    /// `theMarketSortLabelsComeFromMarketCopyOnBothLists`.
    @Test func theMarketPairFollowsTheCostPairInTheMenu() {
        #expect(WishlistViewModel.SortOrder.allCases == [
            .custom, .cost, .costDescending, .marketFigure, .marketFigureAscending, .desire, .alphabetical,
        ])
    }
}

@Suite("Category chips are per-screen")
struct CategoryChipScopeTests {
    @Test func theWishlistOffersOnlyCategoriesItsOwnEntriesUse() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Peak Design bag", categoryPath: "Accessories"))
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras"))
        insertWanted("Summicron", category: "Photography/Lenses", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.categoryOptions == ["Photography/Lenses"])
    }

    @Test func theItemListOffersOnlyCategoriesItsOwnItemsUse() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras"))
        insertWanted("Vox AC15", category: "Music/Amps", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.categoryOptions == ["Photography/Cameras"])
    }

    /// The half that has to keep working: a path established on either side is
    /// still suggested while typing, per spec.md's acceptance criteria.
    @Test func autocompleteStillSpansBothEntities() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras"))
        insertWanted("Vox AC15", category: "Music/Amps", into: context)
        try context.save()

        let form = WishlistFormViewModel(modelContext: context)
        form.loadCategorySuggestions()

        #expect(form.categorySuggestions == ["Music/Amps", "Photography/Cameras"])
    }
}

/// `001` shipped desire-to-own as display-only — no sort consulted it — and
/// this suite pinned that rule. `010` deliberately reverses half of it: the
/// rating now orders the list through its own explicit "Desire" option (see
/// spec.md's Resolved decisions for why the original "competing orderings"
/// concern no longer applies — every sort is an explicit picker choice now).
/// What survives, and what this suite still pins: the rating reorders
/// *nothing else*. Manual order stays the default and ignores it; Cost
/// ignores it; changing a rating never moves a row in any sort that isn't
/// "Desire".
@Suite("Desire to own reorders nothing but its own sort")
struct DesireToOwnOrderingTests {
    private func insertRated(
        _ name: String,
        desire: Int,
        order: Int,
        into context: ModelContext
    ) {
        let wanted = WishlistItem(name: name, categoryPath: "Music/Amps", sortOrder: order)
        wanted.desireToOwn = desire
        context.insert(wanted)
    }

    /// The rating runs opposite the manual order here, so anything sorting by
    /// it — ascending or descending — reverses the list.
    @Test func theManualOrderWinsOverTheRating() throws {
        let context = try makeInMemoryContext()
        insertRated("First", desire: 1, order: 0, into: context)
        insertRated("Second", desire: 2, order: 1, into: context)
        insertRated("Third", desire: 3, order: 2, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["First", "Second", "Third"])
    }

    /// The ratings run opposite the cost order — the dear item is the wanted
    /// one — so a cost sort that consulted desire would flip this list.
    /// (The fixture inverted when `010` flipped cost to cheapest-first: the
    /// old wanted-and-cheap pairing would have *agreed* with a desire sort,
    /// leaving the test unable to detect the very leak it pins.)
    @Test func theCostOrderIsUnaffectedByTheRatingToo() throws {
        let context = try makeInMemoryContext()
        let cheapButNot = WishlistItem(
            name: "Cheap", categoryPath: "Music/Amps", estimatedCostCents: 5_000, sortOrder: 0
        )
        cheapButNot.desireToOwn = 1
        let dearButWanted = WishlistItem(
            name: "Dear", categoryPath: "Music/Amps", estimatedCostCents: 240_000, sortOrder: 1
        )
        dearButWanted.desireToOwn = 3
        context.insert(cheapButNot)
        context.insert(dearButWanted)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.sortOrder = .cost
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["Cheap", "Dear"])
    }

    /// Changing a rating must not move a row. Same list, same items, ratings
    /// rewritten between two loads.
    @Test func rewritingEveryRatingLeavesTheOrderWhereItWas() throws {
        let context = try makeInMemoryContext()
        insertRated("Alpha", desire: 2, order: 0, into: context)
        insertRated("Bravo", desire: 2, order: 1, into: context)
        insertRated("Charlie", desire: 2, order: 2, into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        let before = viewModel.items.map(\.name)

        for (item, desire) in zip(viewModel.items, [3, 1, 2]) {
            item.desireToOwn = desire
        }
        try context.save()
        viewModel.load()

        #expect(viewModel.items.map(\.name) == before)
    }
}

@Suite("WishlistViewModel — export")
struct WishlistViewModelExportTests {
    /// Criterion 4: exactly the visible wanted items, in visible order. The
    /// fixture makes a refetch detectably wrong twice over — the Vox is
    /// filtered out, and cheapest-first order isn't storage order.
    @Test func exportedRowsAreTheVisibleItemsInVisibleOrder() async throws {
        let context = try makeInMemoryContext()
        insertWanted("Vox AC15", costCents: 105_000, into: context)
        insertWanted("Summicron 35", category: "Photography/Lenses", costCents: 240_000, into: context)
        insertWanted("Hasselblad 80mm", category: "Photography/Lenses", costCents: 95_000, into: context)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = WishlistViewModel(modelContext: context, exportService: spy)
        viewModel.categoryFilter = "Photography"
        viewModel.sortOrder = .cost
        viewModel.load()

        await viewModel.exportCSV()

        let table = try #require(spy.tables.first)
        #expect(table.headers == ExportSchema.wishlistHeaders)
        #expect(table.rows.map { $0[0] } == ["Hasselblad 80mm", "Summicron 35"])
    }

    @Test func exportStagesTheWishlistFilename() async throws {
        let context = try makeInMemoryContext()
        insertWanted("Vox AC15", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context, exportService: ExportServiceSpy())
        viewModel.load()

        await viewModel.exportCSV()

        let staged = try #require(viewModel.stagedExport)
        #expect(staged.filenames == [ExportFilename.wishlist(fileExtension: "csv")])
        #expect(viewModel.isExporting == false)
    }

    @Test func canExportTracksTheVisibleListNotTheStore() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistViewModel(modelContext: context, exportService: ExportServiceSpy())
        viewModel.load()
        #expect(!viewModel.canExport)

        insertWanted("Vox AC15", into: context)
        try context.save()
        viewModel.load()
        #expect(viewModel.canExport)

        viewModel.categoryFilter = "Photography"
        viewModel.load()
        #expect(!viewModel.canExport)
    }

    @Test func nothingIsExportedWhenTheViewIsEmpty() async throws {
        let context = try makeInMemoryContext()
        let spy = ExportServiceSpy()
        let viewModel = WishlistViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        await viewModel.exportCSV()
        await viewModel.exportPDF()

        #expect(spy.tables.isEmpty)
        #expect(spy.documents.isEmpty)
        #expect(viewModel.stagedExport == nil)
    }

    @Test func aThrowingServiceSurfacesTheSharedFailureCopy() async throws {
        let context = try makeInMemoryContext()
        insertWanted("Vox AC15", into: context)
        try context.save()

        let viewModel = WishlistViewModel(
            modelContext: context,
            exportService: ExportServiceSpy(failsEveryCall: true)
        )
        viewModel.load()

        await viewModel.exportPDF()

        #expect(viewModel.exportFailureMessage == ExportCopy.failureMessage)
        #expect(viewModel.stagedExport == nil)
        #expect(viewModel.isExporting == false)
    }

    /// Criterion 8, wishlist side: the cover totals this view model's own
    /// estimated-cost arithmetic — live property and concrete figure both.
    @Test func pdfCoverTotalsTheViewModelsOwnEstimatedCost() async throws {
        let context = try makeInMemoryContext()
        insertWanted("Vox AC15", costCents: 105_000, into: context)
        insertWanted("Summicron 35", category: "Photography/Lenses", costCents: 240_000, into: context)
        try context.save()

        let spy = ExportServiceSpy()
        let viewModel = WishlistViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        await viewModel.exportPDF()

        let document = try #require(spy.documents.first)
        #expect(document.entries.count == 2)
        #expect(document.cover.title == "Wishlist")
        #expect(document.cover.coverageLabel == "Whole wishlist")
        #expect(document.cover.itemCount == viewModel.items.count)

        guard case .wishlist(let estimated) = document.cover.totals else {
            Issue.record("wishlist export produced non-wishlist cover totals")
            return
        }
        #expect(estimated == viewModel.totalEstimatedCostCents)
        #expect(estimated == 345_000)
        // Entry order mirrors the visible order, same as the CSV rows.
        #expect(document.entries.map(\.name) == viewModel.items.map(\.name))
    }

    /// T019/S1 — see the items twin.
    @Test func isExportingIsObservableMidFlightAndBlocksReentry() async throws {
        let context = try makeInMemoryContext()
        insertWanted("Vox AC15", into: context)
        try context.save()

        let spy = GatedExportServiceSpy()
        let viewModel = WishlistViewModel(modelContext: context, exportService: spy)
        viewModel.load()

        let inFlight = Task { await viewModel.exportCSV() }
        for _ in 0..<10_000 where spy.csvCalls == 0 { await Task.yield() }
        try #require(spy.csvCalls == 1, "gated export never started")

        #expect(viewModel.isExporting, "progress state must be visible while generating")

        await viewModel.exportCSV()
        await viewModel.exportPDF()
        #expect(spy.csvCalls == 1)
        #expect(spy.pdfCalls == 0)

        spy.release()
        await inFlight.value
        #expect(viewModel.isExporting == false)
        #expect(viewModel.stagedExport != nil)
    }

    @Test func coverageLabelNamesTheActiveNarrowing() throws {
        let context = try makeInMemoryContext()
        insertWanted("Summicron 35", category: "Photography/Lenses", into: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context, exportService: ExportServiceSpy())
        viewModel.load()
        #expect(viewModel.exportCoverageLabel == "Whole wishlist")

        viewModel.categoryFilter = "Photography/Lenses"
        viewModel.searchText = "Summicron"
        viewModel.load()

        let categoryLabel = viewModel.categoryLabels["Photography/Lenses"] ?? "Photography/Lenses"
        #expect(viewModel.exportCoverageLabel
            == "Category: \(categoryLabel) · Search: \u{201C}Summicron\u{201D}")
    }
}

/// T010's wishlist twin — see `ItemListViewModelImportTests`; one pattern,
/// both lists, with the wishlist's own target copy.
struct WishlistViewModelImportTests {
    private let dummyURL = URL(filePath: "/dev/null/import.csv")

    @Test func isImportingFileIsObservableMidFlightAndBlocksReentry() async throws {
        let context = try makeInMemoryContext()
        let spy = GatedImportServiceSpy()
        let viewModel = WishlistViewModel(modelContext: context, importService: spy)

        let inFlight = Task { await viewModel.importCSV(from: dummyURL) }
        for _ in 0..<10_000 where spy.wishlistCalls == 0 { await Task.yield() }
        try #require(spy.wishlistCalls == 1, "gated import never started")

        #expect(viewModel.isImportingFile, "progress state must be visible while parsing")

        await viewModel.importCSV(from: dummyURL)
        #expect(spy.wishlistCalls == 1)

        spy.release()
        await inFlight.value
        #expect(viewModel.isImportingFile == false)
        guard case .confirmation = viewModel.importPresentation else {
            Issue.record("expected a staged confirmation")
            return
        }
    }

    @Test func aFailureMapsToTheSharedCopyWithTheWishlistTarget() async throws {
        let context = try makeInMemoryContext()
        let spy = ImportServiceSpy(wishlist: .failure(.headerMismatch(wrongList: true)))
        let viewModel = WishlistViewModel(modelContext: context, importService: spy)

        await viewModel.importCSV(from: dummyURL)

        guard case .failure(let title, let message) = viewModel.importPresentation else {
            Issue.record("expected a failure presentation")
            return
        }
        #expect(title == ImportCopy.failureTitle)
        #expect(
            message
                == ImportCopy.failureMessage(for: .headerMismatch(wrongList: true), target: .wishlist)
        )
        #expect(message.contains("Items export"))
    }

    @Test func cancelClearsThePresentationWithoutStoreWrites() async throws {
        let context = try makeInMemoryContext()
        let spy = ImportServiceSpy(wishlist: .success(wishlistPreview(names: ["OM-1"])))
        let viewModel = WishlistViewModel(modelContext: context, importService: spy)

        await viewModel.importCSV(from: dummyURL)
        #expect(viewModel.importPresentation != nil)

        viewModel.cancelImport()
        #expect(viewModel.importPresentation == nil)
        #expect(try context.fetch(FetchDescriptor<WishlistItem>()).isEmpty)
    }

    @Test func alertAccessorsUseTheWishlistNouns() async throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistViewModel(
            modelContext: context,
            importService: ImportServiceSpy(wishlist: .success(wishlistPreview(names: ["OM-1"])))
        )
        await viewModel.importCSV(from: dummyURL)

        #expect(viewModel.importAlertTitle == "Import 1 wishlist item?")
        #expect(viewModel.importOffersConfirmation)
    }
}

/// A validated wishlist preview for staging tests.
func wishlistPreview(
    names: [String],
    categoryPath: String = "Photography/Cameras"
) -> WishlistImportPreview {
    ImportPreview(
        validated: names.enumerated().map { offset, name in
            ValidatedRow(
                record: WishlistExportRecord(
                    name: name, categoryPath: categoryPath,
                    estimatedCostCents: 45_000, currencyCode: "USD", desireToOwn: 2,
                    createdAt: Date(timeIntervalSince1970: 1_500_000_000),
                    notes: nil, reverbProductID: nil, year: nil, firstPhotoID: nil
                ),
                rowNumber: offset + 2,
                defaultedFieldCount: 0
            )
        },
        skipped: [],
        defaultedFieldCount: 0
    )
}

/// T011's wishlist twin: the commit path with the wishlist's one extra
/// move — `Added` restoring `createdAt` — and the casing-priority theft
/// that canonicalization prevents.
struct WishlistViewModelCommitTests {
    private let dummyURL = URL(filePath: "/dev/null/import.csv")

    @Test func commitAppendsAndRestoresCreatedAtFromAdded() async throws {
        // Second-context verification — see the items twin's note (T018's
        // audit: a same-context refetch passes with `save()` deleted).
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(WishlistItem(name: "Existing", sortOrder: 0))
        try context.save()

        let added = Date(timeIntervalSince1970: 1_500_000_000)
        let viewModel = WishlistViewModel(
            modelContext: context,
            importService: ImportServiceSpy(wishlist: .success(wishlistPreview(names: ["OM-1"])))
        )
        await viewModel.importCSV(from: dummyURL)
        await viewModel.confirmImport()?.value

        let imported = try #require(
            try ModelContext(container).fetch(FetchDescriptor<WishlistItem>()).first { $0.name == "OM-1" }
        )
        #expect(imported.sortOrder == 1)
        // The fixture's record carries this instant; the init hard-sets
        // `.now`, so equality here proves the post-construction restore.
        #expect(imported.createdAt == added)
        #expect(viewModel.importPresentation == nil)
    }

    @Test func oldAddedDatesCannotStealAnExistingPathsCasing() async throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "M6", categoryPath: "Photography/Cameras"))
        try context.save()

        // A 2015-dated wish in lowercase: without canonicalization its old
        // createdAt would outrank the existing item in the chips' earliest-
        // casing rule across both entities.
        let viewModel = WishlistViewModel(
            modelContext: context,
            importService: ImportServiceSpy(wishlist: .success(wishlistPreview(
                names: ["Old Wish"], categoryPath: "photography/cameras"
            )))
        )
        await viewModel.importCSV(from: dummyURL)
        await viewModel.confirmImport()?.value

        let imported = try #require(
            try context.fetch(FetchDescriptor<WishlistItem>()).first { $0.name == "Old Wish" }
        )
        #expect(imported.categoryPath == "Photography/Cameras")
        // The chips agree: earliest casing across both entities is still
        // the existing one, because no lowercase copy ever landed.
        let helper = CategoryPathHelper(modelContext: context)
        #expect(try helper.allCategoryPaths() == ["Photography/Cameras"])
    }
}

// 012's `WishlistViewModelTemplateTests` moved to
// `SettingsViewModelTemplateTests` with the intent (013/T010, T013).

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

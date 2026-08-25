import Foundation
import SwiftData
import Testing
@testable import Trove

/// T026. The item list's manual order, tested in the same shape
/// `WishlistViewModelTests` established — deliberately, since both route
/// through `ManualOrderHelper` and the point of sharing was one guarded
/// implementation, not two drifting ones.
@Suite("ItemListViewModel — manual order")
struct ItemReorderTests {
    private func insertItem(
        _ name: String,
        category: String = "Test/Gear",
        order: Int,
        valueCents: Int? = 10_000,
        into context: ModelContext
    ) {
        let item = Item(name: name, categoryPath: category, sortOrder: order)
        item.currentValueCents = valueCents
        context.insert(item)
    }

    @Test func customShowsTheUsersOwnOrder() throws {
        let context = try makeInMemoryContext()
        insertItem("Third", order: 2, into: context)
        insertItem("First", order: 0, into: context)
        insertItem("Second", order: 1, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .custom
        viewModel.load()

        #expect(viewModel.items.map(\.name) == ["First", "Second", "Third"])
    }

    @Test func aMoveRenumbersAndReachesTheStore() throws {
        let context = try makeInMemoryContext()
        insertItem("First", order: 0, into: context)
        insertItem("Second", order: 1, into: context)
        insertItem("Third", order: 2, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .custom
        viewModel.load()
        viewModel.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(viewModel.items.map(\.name) == ["Third", "First", "Second"])
        #expect(viewModel.items.map(\.sortOrder) == [0, 1, 2])

        // A fresh *context* over the same container, not the same context
        // reloaded — the same context hands back its own unsaved changes and
        // would pass with the save deleted (the 001 lesson; the mutation run
        // proved it on this very test's first draft).
        let reloaded = ItemListViewModel(modelContext: ModelContext(context.container))
        reloaded.sortOrder = .custom
        reloaded.load()
        #expect(reloaded.items.map(\.name) == ["Third", "First", "Second"])
    }

    /// The invariant, stated the way the wishlist's suite states it: a row's
    /// position in the list is its `sortOrder`, no gaps, no collisions.
    @Test func positionsStayDenseAndUniqueAcrossManyMoves() throws {
        let context = try makeInMemoryContext()
        for index in 0..<6 {
            insertItem("Item \(index)", order: index, into: context)
        }
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .custom
        viewModel.load()

        for (from, to) in [(5, 0), (0, 3), (2, 5), (4, 1), (1, 4)] {
            viewModel.move(fromOffsets: IndexSet(integer: from), toOffset: to)
            #expect(viewModel.items.map(\.sortOrder) == Array(0..<viewModel.items.count))
        }
    }

    /// This screen has one more narrowing than the wishlist: the un-valued
    /// filter hides rows exactly the way a query does, so it blocks
    /// reordering for the same reason.
    @Test func reorderingIsOnlyOfferedAgainstTheWholeListInItsOwnOrder() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", order: 0, into: context)
        insertItem("Vox AC15", category: "Music/Amps", order: 1, valueCents: nil, into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .custom
        viewModel.load()
        #expect(viewModel.canReorder)

        viewModel.sortOrder = .purchaseDate
        #expect(viewModel.canReorder == false)

        viewModel.sortOrder = .custom
        viewModel.categoryFilter = "Photography"
        #expect(viewModel.canReorder == false)

        viewModel.categoryFilter = ""
        viewModel.searchText = "vox"
        #expect(viewModel.canReorder == false)

        viewModel.searchText = "   "
        #expect(viewModel.canReorder)

        viewModel.showsOnlyUnvalued = true
        #expect(viewModel.canReorder == false)
    }

    /// A drag that slipped through while narrowed would renumber the visible
    /// subset over the whole collection's order.
    ///
    /// The purchase dates are pinned so Date order *agrees* with manual
    /// order: with the two disagreeing, this test's first draft passed even
    /// with the guard deleted, because renumbering the date-sorted rows
    /// happened to land back on the original values.
    @Test func aDragWhileNarrowedDoesNothing() throws {
        let context = try makeInMemoryContext()
        insertItem("First", order: 0, into: context)
        insertItem("Second", order: 1, into: context)
        let byName = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Item>()).map { ($0.name, $0) }
        )
        byName["First"]?.purchaseDate = Date(timeIntervalSince1970: 2_000)
        byName["Second"]?.purchaseDate = Date(timeIntervalSince1970: 1_000)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.sortOrder = .purchaseDate
        viewModel.load()
        viewModel.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        // By name, unsorted — a `.sorted()` here only checks the values
        // exist, which a renumbered wrong order also satisfies (this test's
        // first draft did exactly that and its mutation survived).
        let orderByName = Dictionary(uniqueKeysWithValues: viewModel.items.map { ($0.name, $0.sortOrder) })
        #expect(orderByName["First"] == 0)
        #expect(orderByName["Second"] == 1)
    }
}

/// The append half of T025's scope note: `ItemFormViewModel` assigned no
/// position at all before `010`, so every new item tied at zero — these
/// mirror the wishlist form's suite, through the same helper.
@Suite("ItemFormViewModel — manual order")
struct ItemFormManualOrderTests {
    private func savedItem(named name: String, in context: ModelContext) -> Bool {
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = name
        viewModel.categoryPath = "Music/Guitars"
        viewModel.purchasePrice = 100
        return viewModel.save()
    }

    @Test func newItemsJoinTheEndOfTheManualOrder() throws {
        let context = try makeInMemoryContext()
        for name in ["First", "Second", "Third"] {
            #expect(savedItem(named: name, in: context))
        }

        let saved = try context.fetch(FetchDescriptor<Item>()).sorted { $0.sortOrder < $1.sortOrder }
        #expect(saved.map(\.name) == ["First", "Second", "Third"])
        #expect(saved.map(\.sortOrder) == [0, 1, 2])
    }

    /// Counting rows would reuse a position after a deletion and put two
    /// items on the same rung; taking the highest in use can't.
    @Test func appendingAfterADeletionDoesNotReuseAPosition() throws {
        let context = try makeInMemoryContext()
        let first = Item(name: "First", categoryPath: "A", sortOrder: 0)
        let second = Item(name: "Second", categoryPath: "A", sortOrder: 1)
        context.insert(first)
        context.insert(second)
        try context.save()

        context.delete(first)
        try context.save()

        #expect(savedItem(named: "Third", in: context))

        let orders = try context.fetch(FetchDescriptor<Item>()).map(\.sortOrder).sorted()
        #expect(orders == [1, 2])
    }

    @Test func editingDoesNotDisturbTheManualOrder() throws {
        let context = try makeInMemoryContext()
        let existing = Item(name: "Leica M6", categoryPath: "Photography/Cameras", sortOrder: 7)
        context.insert(existing)
        try context.save()

        let viewModel = ItemFormViewModel(modelContext: context, editing: existing)
        viewModel.name = "Leica M6 (0.72x)"
        #expect(viewModel.save())

        #expect(existing.sortOrder == 7)
    }
}

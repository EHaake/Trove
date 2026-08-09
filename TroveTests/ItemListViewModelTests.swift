import Foundation
import SwiftData
import Testing
@testable import Trove

private func insertItem(
    _ name: String,
    category: String = "Music/Guitars",
    desire: Int = 3,
    valueCents: Int? = nil,
    purchasedAt seconds: TimeInterval = 0,
    into context: ModelContext
) {
    context.insert(
        Item(
            name: name,
            categoryPath: category,
            purchaseDate: Date(timeIntervalSince1970: seconds),
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

    @Test func filtersCaseInsensitively() throws {
        let context = try makeInMemoryContext()
        insertItem("Leica M6", category: "Photography/Cameras", into: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.categoryFilter = "PHOTOGRAPHY/cam"
        viewModel.load()

        #expect(viewModel.items.count == 1)
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

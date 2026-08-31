import Foundation
import SwiftData
import Testing
@testable import Trove

/// T014. The item list's delete path, tested the way `WishlistDeletionTests`
/// tests the wishlist's — same suite shape on purpose, because the two paths
/// make the same promises. Persisted-state assertions go through a second
/// `ModelContext` over the same container: the first context hands back its
/// own unsaved changes, so only a fresh one can prove a delete reached the
/// store (`SellPlanViewModelTests` established the pattern in `001`).
@Suite("Item deletion")
struct ItemDeletionTests {
    private func makeItem(
        in context: ModelContext,
        name: String,
        valueCents: Int? = 54_000
    ) -> Item {
        let item = Item(name: name, categoryPath: "Music/Amps", purchasePriceCents: 69_000)
        item.currentValueCents = valueCents
        context.insert(item)
        return item
    }

    @Test func deleteRemovesTheItemFromTheStore() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let doomed = makeItem(in: context, name: "Blues Junior")
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        viewModel.delete(id: doomed.id)

        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(viewModel.items.isEmpty, "The list should reload itself after a delete")
    }

    @Test func deleteLeavesOtherItemsAlone() throws {
        let context = try makeInMemoryContext()
        let doomed = makeItem(in: context, name: "Blues Junior")
        makeItem(in: context, name: "Leica M6")
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        viewModel.delete(id: doomed.id)

        #expect(viewModel.items.map(\.name) == ["Leica M6"])
    }

    @Test func deleteWithAnUnknownIDDoesNothing() throws {
        let context = try makeInMemoryContext()
        makeItem(in: context, name: "Blues Junior")
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        viewModel.delete(id: UUID())

        #expect(viewModel.items.count == 1)
    }

    /// Both halves of what `ItemDeleteCopy.message` promises, measured:
    /// photos cascade, and the sell plan *drops the item* — the wishlist entry
    /// that planned it survives untouched, its selection just shrinks. The
    /// mirror of `WishlistDeletionTests`' cascade test, pointing the nullify
    /// the other way, which is exactly the direction T011 pins in the copy.
    @Test func deleteCascadesPhotosAndDropsOutOfSellPlans() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let doomed = makeItem(in: context, name: "Blues Junior")
        doomed.photos = [Photo(imageData: Data([0x01]), source: .device)]
        let wanted = WishlistItem(name: "Vox AC15", categoryPath: "Music/Amps")
        context.insert(wanted)
        wanted.plannedSaleItems = [doomed]
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        viewModel.delete(id: doomed.id)

        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<Photo>()).isEmpty, "Photos should cascade")
        let survivors = try fresh.fetch(FetchDescriptor<WishlistItem>())
        #expect(survivors.map(\.name) == ["Vox AC15"], "The wishlist entry must survive")
        #expect(
            survivors.first?.plannedSaleItems?.isEmpty == true,
            "The plan should have dropped the deleted item"
        )
    }
}

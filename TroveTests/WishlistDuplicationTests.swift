import Foundation
import SwiftData
import Testing
@testable import Trove

/// T022, mirroring `ItemDuplicationTests` for the wishlist's entity shape:
/// no serial exists to clear, and the plan non-inheritance points the other
/// way — the *copy's own* selection must start empty, while the original
/// keeps whatever gear it had selected.
@Suite("Wishlist duplication")
struct WishlistDuplicationTests {
    private func makeOriginal(in context: ModelContext) -> WishlistItem {
        let wanted = WishlistItem(
            name: "Summicron 35mm f/2",
            categoryPath: "Photography/Lenses",
            estimatedCostCents: 240_000,
            currencyCode: "USD",
            notes: "v4 only",
            desireToOwn: 3,
            photos: [Photo(imageData: Data([0x5A]), source: .device)]
        )
        context.insert(wanted)
        return wanted
    }

    @Test func theCopyMatchesFieldForField() throws {
        let context = try makeInMemoryContext()
        let original = makeOriginal(in: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.duplicate(id: original.id)

        let copy = try #require(viewModel.items.first { $0.id != original.id })
        #expect(copy.name == original.name)
        #expect(copy.categoryPath == original.categoryPath)
        #expect(copy.estimatedCostCents == original.estimatedCostCents)
        #expect(copy.currencyCode == original.currencyCode)
        #expect(copy.notes == original.notes)
        #expect(copy.desireToOwn == original.desireToOwn)
    }

    @Test func photosAreNewRowsWithDuplicatedData() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let original = makeOriginal(in: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.duplicate(id: original.id)

        let fresh = ModelContext(container)
        let photos = try fresh.fetch(FetchDescriptor<Photo>())
        #expect(photos.count == 2)
        #expect(Set(photos.map(\.id)).count == 2)
        #expect(photos.allSatisfy { $0.imageData == Data([0x5A]) })

        let wanted = try fresh.fetch(FetchDescriptor<WishlistItem>())
        for entry in wanted {
            #expect(entry.photos?.count == 1, "\(entry.name) should own exactly one photo")
        }
    }

    /// The copy's own Sell Plan selection starts empty — duplicating a
    /// wishlist item must not double-count the gear its original planned to
    /// sell — and the original's selection survives untouched.
    @Test func theCopysSellPlanSelectionStartsEmpty() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let original = makeOriginal(in: context)
        let gear = Item(name: "Blues Junior", categoryPath: "Music/Amps")
        gear.currentValueCents = 54_000
        context.insert(gear)
        original.plannedSaleItems = [gear]
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.duplicate(id: original.id)

        let fresh = ModelContext(container)
        let all = try fresh.fetch(FetchDescriptor<WishlistItem>())
        let freshOriginal = try #require(all.first { $0.id == original.id })
        let freshCopy = try #require(all.first { $0.id != original.id })
        #expect(freshCopy.plannedSaleItems?.isEmpty == true, "The copy inherited a plan selection")
        #expect(freshOriginal.plannedSaleItems?.map(\.id) == [gear.id], "The original's selection must survive")
    }

    @Test func theCopyLandsImmediatelyAfterTheOriginal() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        var seeded: [String: WishlistItem] = [:]
        for (index, name) in ["Alpha", "Bravo", "Charlie"].enumerated() {
            let wanted = WishlistItem(name: name, categoryPath: "Test/Gear", sortOrder: index)
            context.insert(wanted)
            seeded[name] = wanted
        }
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.duplicate(id: seeded["Bravo"]!.id)

        let fresh = ModelContext(container)
        let ordered = try fresh.fetch(
            FetchDescriptor<WishlistItem>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        #expect(ordered.map(\.name) == ["Alpha", "Bravo", "Bravo", "Charlie"])
        #expect(ordered.map(\.sortOrder) == [0, 1, 2, 3])
        #expect(ordered[2].id != seeded["Bravo"]!.id)
    }

    @Test func duplicateWithAnUnknownIDDoesNothing() throws {
        let context = try makeInMemoryContext()
        _ = makeOriginal(in: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.duplicate(id: UUID())

        #expect(viewModel.items.count == 1)
    }
}

import Foundation
import SwiftData
import Testing
@testable import Trove

/// T020. Each of spec.md's duplicate rules measured separately, because each
/// fails differently: a carried-over serial has two rows claiming one
/// physical unit, a *shared* photo reference silently reparents the
/// original's photo onto the copy (the one-photo-one-parent rule means
/// sharing isn't aliasing, it's theft), an inherited Sell Plan membership
/// changes a plan's math without the user selecting anything, and an
/// append-at-end placement loses the adjacency the flow promises.
/// Persisted-state assertions read through a second `ModelContext`, per the
/// house pattern.
@Suite("Item duplication")
struct ItemDuplicationTests {
    private func makeOriginal(in context: ModelContext) -> Item {
        let item = Item(
            name: "Blues Junior",
            categoryPath: "Music/Amps",
            purchasePriceCents: 69_000,
            purchaseDate: Date(timeIntervalSince1970: 1_000_000),
            currencyCode: "USD",
            serialNumber: "BJ-1138",
            purchaseLocation: "Reverb",
            currentValueCents: 54_000,
            desireToKeep: 2,
            condition: .good,
            conditionNotes: "Scratchy pot",
            notes: "Tolex wear",
            photos: [Photo(imageData: Data([0xAB, 0xCD]), source: .device)]
        )
        context.insert(item)
        return item
    }

    @Test func theCopyMatchesFieldForFieldExceptSerial() throws {
        let context = try makeInMemoryContext()
        let original = makeOriginal(in: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        viewModel.duplicate(id: original.id)

        let copy = try #require(viewModel.items.first { $0.id != original.id })
        #expect(copy.name == original.name)
        #expect(copy.categoryPath == original.categoryPath)
        #expect(copy.purchasePriceCents == original.purchasePriceCents)
        #expect(copy.purchaseDate == original.purchaseDate)
        #expect(copy.currencyCode == original.currencyCode)
        #expect(copy.purchaseLocation == original.purchaseLocation)
        #expect(copy.currentValueCents == original.currentValueCents)
        #expect(copy.desireToKeep == original.desireToKeep)
        #expect(copy.condition == original.condition)
        #expect(copy.conditionNotes == original.conditionNotes)
        #expect(copy.notes == original.notes)
        #expect(copy.serialNumber == nil, "The serial names one physical unit; the copy must not claim it")
        #expect(original.serialNumber == "BJ-1138", "The original keeps its own serial")
    }

    /// The storage-duplication behavior plan.md flagged, confirmed rather
    /// than assumed: two `Photo` rows exist afterward, with equal data but
    /// distinct identities, each parented to its own item. A shared
    /// reference would leave one row — reparented onto the copy, stealing
    /// the original's photo — and this is the test that catches it.
    @Test func photosAreNewRowsWithDuplicatedData() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let original = makeOriginal(in: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        viewModel.duplicate(id: original.id)

        let fresh = ModelContext(container)
        let photos = try fresh.fetch(FetchDescriptor<Photo>())
        #expect(photos.count == 2, "Expected the original's photo and a genuinely new row")
        #expect(Set(photos.map(\.id)).count == 2, "The rows must be distinct photos, not one shared")
        #expect(photos.allSatisfy { $0.imageData == Data([0xAB, 0xCD]) })

        let items = try fresh.fetch(FetchDescriptor<Item>())
        for item in items {
            #expect(item.photos?.count == 1, "\(item.name) should own exactly one photo")
        }
    }

    @Test func sellPlanMembershipIsNotInherited() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let original = makeOriginal(in: context)
        let wanted = WishlistItem(name: "Vox AC15", categoryPath: "Music/Amps")
        context.insert(wanted)
        wanted.plannedSaleItems = [original]
        // 009 Amendment A (G39): the original is also the item a second,
        // bought entry became — that entry has no selection, as a bought
        // entry never does. The two fields are set directly for brevity;
        // `WishlistPurchaseStoreTests` (G25) proves `markBought` writes the
        // same two.
        let bought = WishlistItem(name: "Rickenbacker 330", categoryPath: "Music/Guitars")
        context.insert(bought)
        bought.boughtDate = Date(timeIntervalSince1970: 1_770_000_000)
        bought.boughtItem = original
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        viewModel.duplicate(id: original.id)

        let fresh = ModelContext(container)
        let entries = try fresh.fetch(FetchDescriptor<WishlistItem>())
        let plan = try #require(entries.first { $0.name == "Vox AC15" })
        #expect(
            plan.plannedSaleItems?.map(\.id) == [original.id],
            "The plan's selection must still be exactly the original — the user selected nothing else"
        )
        let purchase = try #require(entries.first { $0.name == "Rickenbacker 330" })
        let copy = try #require(try fresh.fetch(FetchDescriptor<Item>()).first { $0.id != original.id })
        #expect(purchase.boughtItem?.id == original.id, "The purchase's record stays on the original")
        #expect(copy.boughtFromWishlistItem == nil, "The copy was bought from nothing")
    }

    @Test func theCopyLandsImmediatelyAfterTheOriginal() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let names = ["Alpha", "Bravo", "Charlie"]
        var seeded: [String: Item] = [:]
        for (index, name) in names.enumerated() {
            let item = Item(name: name, categoryPath: "Test/Gear", sortOrder: index)
            context.insert(item)
            seeded[name] = item
        }
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        viewModel.duplicate(id: seeded["Bravo"]!.id)

        let fresh = ModelContext(container)
        let ordered = try fresh.fetch(
            FetchDescriptor<Item>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        #expect(ordered.map(\.name) == ["Alpha", "Bravo", "Bravo", "Charlie"])
        #expect(ordered.map(\.sortOrder) == [0, 1, 2, 3], "Dense and unique, no gaps for later drags to trip on")
        #expect(ordered[2].id != seeded["Bravo"]!.id, "The row after the original is the copy, not the original moved")
    }

    @Test func duplicateWithAnUnknownIDDoesNothing() throws {
        let context = try makeInMemoryContext()
        _ = makeOriginal(in: context)
        try context.save()

        let viewModel = ItemListViewModel(modelContext: context)
        viewModel.load()
        viewModel.duplicate(id: UUID())

        #expect(viewModel.items.count == 1)
    }
}

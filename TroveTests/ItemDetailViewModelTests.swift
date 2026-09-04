import Foundation
import SwiftData
import Testing
@testable import Trove

@Suite("ItemDetailViewModel")
struct ItemDetailViewModelTests {
    @Test func hasNothingLoadedBeforeLoadIsCalled() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(item)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)

        #expect(viewModel.item == nil)
        #expect(viewModel.hasLoaded == false)
    }

    @Test func loadsTheItemMatchingItsID() throws {
        let context = try makeInMemoryContext()
        let wanted = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        let other = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        context.insert(wanted)
        context.insert(other)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.item?.name == "Fender Telecaster")
    }

    /// The item may have been deleted on another device once sync is on, so
    /// "gone" has to be an ordinary outcome rather than a crash.
    @Test func loadsNothingForAnUnknownID() throws {
        let context = try makeInMemoryContext()
        context.insert(Item(name: "Fender Telecaster", categoryPath: "Music/Guitars"))
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: UUID())
        viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.item == nil)
    }

    @Test func deleteRemovesTheItemFromTheStore() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(item)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        viewModel.load()

        #expect(viewModel.delete())
        #expect(viewModel.item == nil)
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    @Test func deleteLeavesOtherItemsAlone() throws {
        let context = try makeInMemoryContext()
        let doomed = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        let survivor = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        context.insert(doomed)
        context.insert(survivor)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: doomed.id)
        viewModel.load()
        #expect(viewModel.delete())

        let remaining = try context.fetch(FetchDescriptor<Item>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "Leica M6")
    }

    @Test func deleteDoesNothingWhenNothingIsLoaded() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(item)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)

        #expect(viewModel.delete() == false)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
    }

    @Test func deletingAnItemTakesItsPhotosWithIt() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        let photo = Photo(imageData: Data([0x01]))
        context.insert(item)
        context.insert(photo)
        item.photos = [photo]
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        viewModel.load()
        #expect(viewModel.delete())

        #expect(try context.fetch(FetchDescriptor<Photo>()).isEmpty)
    }

    /// Deleting gear that's on a Sell Plan drops it from the plan; the
    /// wishlist item itself is untouched.
    @Test func deletingAnItemLeavesWishlistItemsIntact() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        let wishlistItem = WishlistItem(name: "Rickenbacker 330")
        context.insert(item)
        context.insert(wishlistItem)
        wishlistItem.plannedSaleItems = [item]
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        viewModel.load()
        #expect(viewModel.delete())

        let wishlist = try context.fetch(FetchDescriptor<WishlistItem>())
        #expect(wishlist.count == 1)
        #expect(wishlist.first?.plannedSaleItems?.isEmpty == true)
    }

    @Test func loadAfterDeleteFindsNothing() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(item)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        viewModel.load()
        #expect(viewModel.delete())

        viewModel.load()
        #expect(viewModel.item == nil)
    }

    // MARK: - Display

    /// `ItemDetailView` sorted its photos inline until this moved here, which
    /// left the same rule in two places — the shape of bug that already bit
    /// this build twice (`matchesPrefix` serving filtering, `allCategoryPaths`
    /// serving filter chips). The relationship comes back unordered from
    /// SwiftData, so an unsorted carousel shows a different lead photo between
    /// launches.
    @Test func photosComeBackInTheUsersOwnOrder() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        context.insert(item)
        let first = Photo(imageData: Data([0x01]), sortOrder: 0)
        let second = Photo(imageData: Data([0x02]), sortOrder: 1)
        let third = Photo(imageData: Data([0x03]), sortOrder: 2)
        context.insert(first)
        context.insert(second)
        context.insert(third)
        // Deliberately attached out of order.
        item.photos = [third, first, second]
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        viewModel.load()

        #expect(viewModel.photos.map(\.sortOrder) == [0, 1, 2])
        #expect(viewModel.photos.map(\.imageData) == [Data([0x01]), Data([0x02]), Data([0x03])])
    }

    @Test func photosAreEmptyWhenNothingIsLoaded() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemDetailViewModel(modelContext: context, itemID: UUID())

        #expect(viewModel.photos.isEmpty)
        viewModel.load()
        #expect(viewModel.photos.isEmpty)
    }

    /// Both detail screens have to answer this the same way, since they're the
    /// same rule — which is the point of it living in a view model at all.
    @Test func bothDetailScreensOrderPhotosAlike() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Leica M6", categoryPath: "Photography/Cameras")
        let wanted = WishlistItem(name: "Summicron 35mm f/2", categoryPath: "Photography/Lenses")
        context.insert(item)
        context.insert(wanted)

        for parent in 0..<2 {
            let photos = (0..<3).map { Photo(imageData: Data([UInt8($0)]), sortOrder: 2 - $0) }
            photos.forEach(context.insert)
            if parent == 0 { item.photos = photos } else { wanted.photos = photos }
        }
        try context.save()

        let itemModel = ItemDetailViewModel(modelContext: context, itemID: item.id)
        let wishlistModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        itemModel.load()
        wishlistModel.load()

        #expect(itemModel.photos.map(\.sortOrder) == [0, 1, 2])
        #expect(wishlistModel.photos.map(\.sortOrder) == [0, 1, 2])
        #expect(itemModel.photos.map(\.imageData) == wishlistModel.photos.map(\.imageData))
    }

    /// 002/T006c: the device's market rows for the item — figure, history,
    /// snapshot — go with it, in the same save, read back on a second context.
    private func seedMarketRows(for id: UUID, in context: ModelContext) throws {
        let product = MarketProduct(id: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster", usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!)
        let figure = MarketFigure(medianCents: 140_000, lowCents: 130_000, highCents: 150_000, count: 12, fetchedAt: .now, isTruncated: false, yearScope: .any)
        try MarketLocalStore.record(.figure(figure), product: product, for: MarketSubjectKey(subjectID: id, kind: .owned), in: context)
    }

    private func marketRowsRemain(for id: UUID, in container: ModelContainer) throws -> Bool {
        let fresh = ModelContext(container)
        let figure = try MarketLocalStore.figure(for: id, in: fresh)
        let snapshot = try MarketLocalStore.snapshot(for: id, in: fresh)
        let history = try MarketLocalStore.history(for: id, in: fresh)
        return figure != nil || snapshot != nil || !history.isEmpty
    }

    @Test func deleteClearsTheItemsMarketRowsInTheSameSave() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let doomed = Item(name: "Telecaster", reverbProductID: 126_161)
        let kept = Item(name: "Stratocaster", reverbProductID: 160_322)
        context.insert(doomed); context.insert(kept)
        try seedMarketRows(for: doomed.id, in: context)
        try seedMarketRows(for: kept.id, in: context)
        try context.save()

        let viewModel = ItemDetailViewModel(modelContext: context, itemID: doomed.id)
        viewModel.load()
        #expect(viewModel.delete())

        #expect(!(try marketRowsRemain(for: doomed.id, in: container)), "the deleted item's market rows survived it")
        #expect(try marketRowsRemain(for: kept.id, in: container), "another item's rows went too")
    }

}

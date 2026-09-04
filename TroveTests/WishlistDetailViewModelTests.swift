import Foundation
import SwiftData
import Testing
@testable import Trove

@Suite("WishlistDetailViewModel")
struct WishlistDetailViewModelTests {
    private func insert(
        _ name: String = "Summicron 35mm f/2",
        category: String = "Photography/Lenses",
        into context: ModelContext
    ) -> WishlistItem {
        let wanted = WishlistItem(name: name, categoryPath: category, estimatedCostCents: 240_000)
        context.insert(wanted)
        return wanted
    }

    @Test func hasNothingLoadedBeforeLoadIsCalled() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)

        #expect(viewModel.item == nil)
        #expect(viewModel.hasLoaded == false)
    }

    @Test func loadsTheItemMatchingItsID() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        _ = insert("Vox AC15 Custom", category: "Music/Amps", into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.item?.id == wanted.id)
        #expect(viewModel.item?.name == "Summicron 35mm f/2")
    }

    /// "Loaded, and it's gone" has to be distinguishable from "not loaded" —
    /// the view shows different things for each.
    @Test func loadsNothingForAnUnknownID() throws {
        let context = try makeInMemoryContext()
        _ = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: UUID())
        viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.item == nil)
    }

    /// The reason this holds an id instead of the object: an entry deleted
    /// elsewhere reads as absent on the next load rather than as a stale
    /// reference.
    @Test func loadAfterADeletionElsewhereFindsNothing() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.item != nil)

        context.delete(wanted)
        try context.save()
        viewModel.load()

        #expect(viewModel.hasLoaded)
        #expect(viewModel.item == nil)
    }

    @Test func reloadingPicksUpAnEditMadeElsewhere() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        let form = WishlistFormViewModel(modelContext: context, editing: wanted)
        form.name = "Summicron 35mm f/2 (v4)"
        form.desireToOwn = 3
        #expect(form.save())

        viewModel.load()

        #expect(viewModel.item?.name == "Summicron 35mm f/2 (v4)")
        #expect(viewModel.desireLevel == .next)
    }

    // MARK: - Display

    /// Same rule the list rows follow: the relationship comes back unordered,
    /// so display order is `sortOrder`, not whatever SwiftData hands over.
    @Test func photosComeBackInTheUsersOwnOrder() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let first = Photo(imageData: Data([0x01]), sortOrder: 0)
        let second = Photo(imageData: Data([0x02]), sortOrder: 1)
        let third = Photo(imageData: Data([0x03]), sortOrder: 2)
        context.insert(first)
        context.insert(second)
        context.insert(third)
        // Deliberately attached out of order.
        wanted.photos = [third, first, second]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.photos.map(\.sortOrder) == [0, 1, 2])
        #expect(viewModel.photos.map(\.imageData) == [Data([0x01]), Data([0x02]), Data([0x03])])
    }

    @Test func photosAreEmptyWhenNothingIsLoaded() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: UUID())

        #expect(viewModel.photos.isEmpty)
        viewModel.load()
        #expect(viewModel.photos.isEmpty)
    }

    /// The detail screen shows the whole path, unlike rows, which show the
    /// trailing two segments.
    @Test func categorySegmentsCoverTheWholePath() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(category: "Music/Guitars/Electric", into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.categorySegments == ["Music", "Guitars", "Electric"])
    }

    @Test func categorySegmentsAreEmptyWithoutAnItem() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: UUID())
        viewModel.load()

        #expect(viewModel.categorySegments.isEmpty)
    }

    @Test(arguments: [(-5, DesireToOwnLevel.someday), (1, .someday), (2, .soon), (3, .next), (9, .next)])
    func theDesireLevelIsClampedOnTheWayOut(stored: Int, expected: DesireToOwnLevel) throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        wanted.desireToOwn = stored
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.desireLevel == expected)
    }

    @Test func thereIsNoDesireLevelWithoutAnItem() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: UUID())
        viewModel.load()

        #expect(viewModel.desireLevel == nil)
    }

    /// Blank notes save as `nil`, but an empty string could still reach here
    /// from an older build — both mean "no notes", so the heading goes.
    @Test(arguments: [nil, "", "   "])
    func hasNoNotesForBlankOrMissingText(notes: String?) throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        wanted.notes = notes
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.hasNotes == (notes == "   "))
    }

    @Test func hasNotesWhenThereIsSomethingToShow() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        wanted.notes = "v4 only, no haze"
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.hasNotes)
    }

    // MARK: - Delete

    @Test func deleteRemovesTheItemFromTheStore() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.delete())
        #expect(viewModel.item == nil)
        #expect(try context.fetch(FetchDescriptor<WishlistItem>()).isEmpty)
    }

    @Test func deleteLeavesOtherWishlistItemsAlone() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        _ = insert("Vox AC15 Custom", category: "Music/Amps", into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.delete())

        let survivors = try context.fetch(FetchDescriptor<WishlistItem>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.name == "Vox AC15 Custom")
    }

    @Test func deleteDoesNothingWhenNothingIsLoaded() throws {
        let context = try makeInMemoryContext()
        _ = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: UUID())
        viewModel.load()

        #expect(viewModel.delete() == false)
        #expect(try context.fetch(FetchDescriptor<WishlistItem>()).count == 1)
    }

    @Test func deletingTakesItsPhotosWithIt() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let photo = Photo(imageData: Data([0x01]))
        context.insert(photo)
        wanted.photos = [photo]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.delete())

        #expect(try context.fetch(FetchDescriptor<Photo>()).isEmpty)
    }

    /// The distinction the two delete rules exist for, exercised through the
    /// screen that actually offers the action: abandoning something you wanted
    /// must never delete gear you own. The alert says as much, so it had
    /// better be true.
    @Test func deletingLeavesTheSellPlanGearAlone() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let owned = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(owned)
        wanted.plannedSaleItems = [owned]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.delete())

        let survivors = try context.fetch(FetchDescriptor<Item>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.name == "Fender Telecaster")
    }

    @Test func loadAfterDeleteFindsNothing() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()
        #expect(viewModel.delete())

        viewModel.load()
        #expect(viewModel.item == nil)
        #expect(viewModel.hasLoaded)
    }

    // MARK: - Scope

    /// plan.md keeps the Sell Plan a deliberate tap away rather than something
    /// this screen could render alongside the item. A detail model that
    /// computed candidates would quietly make that possible, so the boundary
    /// is worth pinning: this type reads the relationship's existence, never
    /// its ranking, and never writes it.
    @Test func loadingDoesNotTouchTheSellPlan() throws {
        let context = try makeInMemoryContext()
        let wanted = insert(into: context)
        let owned = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(owned)
        wanted.plannedSaleItems = [owned]
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: wanted.id)
        viewModel.load()

        #expect(viewModel.item?.plannedSaleItems?.count == 1)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
    }

    /// 002/T006c: the device's market rows for the item — figure, history,
    /// snapshot — go with it, in the same save, read back on a second context.
    private func seedMarketRows(for id: UUID, in context: ModelContext) throws {
        let product = MarketProduct(id: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster", usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!)
        let figure = MarketFigure(medianCents: 140_000, lowCents: 130_000, highCents: 150_000, count: 12, fetchedAt: .now, isTruncated: false, yearScope: .any)
        try MarketLocalStore.record(.figure(figure), product: product, for: MarketSubjectKey(subjectID: id, kind: .wanted), in: context)
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
        let doomed = WishlistItem(name: "D-18", reverbProductID: 182_769)
        let kept = WishlistItem(name: "Timeline", reverbProductID: 17)
        context.insert(doomed); context.insert(kept)
        try seedMarketRows(for: doomed.id, in: context)
        try seedMarketRows(for: kept.id, in: context)
        try context.save()

        let viewModel = WishlistDetailViewModel(modelContext: context, itemID: doomed.id)
        viewModel.load()
        #expect(viewModel.delete())

        #expect(!(try marketRowsRemain(for: doomed.id, in: container)), "the deleted item's market rows survived it")
        #expect(try marketRowsRemain(for: kept.id, in: container), "another item's rows went too")
    }

}

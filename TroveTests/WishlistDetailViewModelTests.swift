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
}

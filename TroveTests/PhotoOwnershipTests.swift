import Foundation
import SwiftData
import Testing
@testable import Trove

/// Guards plan.md's claim about the dual-inverse `Photo`: it belongs to at
/// most one of `item` or `wishlistItem`, never both.
///
/// That claim is unusual in that nothing in the schema enforces it — SwiftData
/// has no "exactly one of these two relationships" constraint, so what makes it
/// true is that each form only ever writes its own side. Which is precisely the
/// kind of claim worth a test rather than a sentence: it holds today because of
/// how two view models happen to be written, and a third writer would break it
/// silently.
@Suite("Photo ownership — one parent, never both")
struct PhotoOwnershipTests {
    @Test func photosSavedFromTheWishlistFormBelongToTheWishlistItemAlone() throws {
        let context = try makeInMemoryContext()
        let viewModel = WishlistFormViewModel(modelContext: context)
        viewModel.name = "Summicron 35mm f/2"
        viewModel.categoryPath = "Photography/Lenses"
        viewModel.estimatedCost = 2_400
        viewModel.photos = PhotoSelection.appending([Data([0x01]), Data([0x02])], to: [])

        #expect(viewModel.save())

        let saved = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(saved.photos?.count == 2)

        let photos = try context.fetch(FetchDescriptor<Photo>())
        #expect(photos.count == 2)
        #expect(photos.allSatisfy { $0.wishlistItem === saved })
        #expect(photos.allSatisfy { $0.item == nil })
    }

    @Test func photosSavedFromTheItemFormBelongToTheItemAlone() throws {
        let context = try makeInMemoryContext()
        let viewModel = ItemFormViewModel(modelContext: context)
        viewModel.name = "Leica M6"
        viewModel.categoryPath = "Photography/Cameras"
        viewModel.purchasePrice = 2_900
        viewModel.photos = PhotoSelection.appending([Data([0x01])], to: [])

        #expect(viewModel.save())

        let saved = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        let photo = try #require(try context.fetch(FetchDescriptor<Photo>()).first)
        #expect(photo.item === saved)
        #expect(photo.wishlistItem == nil)
    }

    /// The two entities' photo sets stay separate even with both populated —
    /// this is what would fail if the relationships were wired to a single
    /// shared inverse.
    @Test func anItemAndAWishlistItemDoNotShareTheirPhotos() throws {
        let context = try makeInMemoryContext()

        let itemForm = ItemFormViewModel(modelContext: context)
        itemForm.name = "Leica M6"
        itemForm.categoryPath = "Photography/Cameras"
        itemForm.purchasePrice = 2_900
        itemForm.photos = PhotoSelection.appending([Data([0x01])], to: [])
        #expect(itemForm.save())

        let wishlistForm = WishlistFormViewModel(modelContext: context)
        wishlistForm.name = "Summicron 35mm f/2"
        wishlistForm.categoryPath = "Photography/Lenses"
        wishlistForm.estimatedCost = 2_400
        wishlistForm.photos = PhotoSelection.appending([Data([0x02]), Data([0x03])], to: [])
        #expect(wishlistForm.save())

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        let wanted = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)

        #expect(item.photos?.count == 1)
        #expect(wanted.photos?.count == 2)
        #expect(item.photos?.first?.imageData == Data([0x01]))
        let wantedData: [Data] = (wanted.photos ?? []).map(\.imageData).sorted { $0.first! < $1.first! }
        #expect(wantedData == [Data([0x02]), Data([0x03])])
    }
}

/// The wishlist half of the delete-rule contrast `ModelRelationshipTests`
/// already covers for `Item`. Worth its own tests rather than assumed by
/// symmetry: `WishlistItem` now carries a `.cascade` relationship immediately
/// above a `.nullify` one, which is exactly where getting them the wrong way
/// round would be easy and expensive.
@Suite("Wishlist photo delete rules")
struct WishlistPhotoDeleteRuleTests {
    @Test func deletingAWishlistItemCascadesToItsPhotos() throws {
        let context = try makeInMemoryContext()
        let wanted = WishlistItem(name: "Summicron 35mm f/2")
        let photo = Photo(imageData: Data([0x01]))
        context.insert(wanted)
        context.insert(photo)
        wanted.photos = [photo]
        try context.save()

        context.delete(wanted)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Photo>()).isEmpty)
    }

    /// The pairing that matters: one delete, two rules, opposite outcomes.
    @Test func deletingAWishlistItemTakesItsPhotosButNotItsSellPlanGear() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster")
        let wanted = WishlistItem(name: "Rickenbacker 330")
        let photo = Photo(imageData: Data([0x01]))
        context.insert(item)
        context.insert(wanted)
        context.insert(photo)
        wanted.photos = [photo]
        wanted.plannedSaleItems = [item]
        try context.save()

        context.delete(wanted)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Photo>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
    }

    /// Deleting owned gear must not take a wishlist item's photos with it —
    /// they're unrelated sets that merely share a type.
    @Test func deletingAnItemLeavesWishlistPhotosAlone() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster")
        let wanted = WishlistItem(name: "Rickenbacker 330")
        let itemPhoto = Photo(imageData: Data([0x01]))
        let wantedPhoto = Photo(imageData: Data([0x02]))
        context.insert(item)
        context.insert(wanted)
        context.insert(itemPhoto)
        context.insert(wantedPhoto)
        item.photos = [itemPhoto]
        wanted.photos = [wantedPhoto]
        try context.save()

        context.delete(item)
        try context.save()

        let survivors = try context.fetch(FetchDescriptor<Photo>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.imageData == Data([0x02]))
    }
}

/// Removing a photo while editing has to delete the row, not just drop it from
/// the array.
///
/// SwiftData's `.cascade` fires when the *parent* is deleted; there is no
/// orphan-removal rule for a child dropped from a to-many relationship. So
/// reassigning `item.photos` leaves the removed `Photo` in the store with both
/// inverses nil — and, because `imageData` is `@Attribute(.externalStorage)`,
/// still holding a blob that CloudKit uploads as a `CKAsset` and nothing ever
/// collects.
///
/// Invisible in the UI, cumulative, and it syncs to every device. Found by the
/// pre-merge review; the create path was covered and the edit path wasn't.
@Suite("Photo removal")
struct PhotoRemovalTests {
    @Test func removingAPhotoWhileEditingAnItemDeletesIt() throws {
        let context = try makeInMemoryContext()

        let form = ItemFormViewModel(modelContext: context)
        form.name = "Leica M6"
        form.categoryPath = "Photography/Cameras"
        form.purchasePrice = 2_900
        form.photos = PhotoSelection.appending([Data([0x01]), Data([0x02])], to: [])
        #expect(form.save())

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first)
        #expect(try context.fetch(FetchDescriptor<Photo>()).count == 2)

        let edit = ItemFormViewModel(modelContext: context, editing: item)
        let dropped = try #require(edit.photos.first)
        edit.photos = PhotoSelection.removing(dropped, from: edit.photos)
        #expect(edit.save())

        let remaining = try context.fetch(FetchDescriptor<Photo>())
        #expect(remaining.count == 1, "\(remaining.count - 1) orphaned Photo row(s) left in the store")
        #expect(remaining.allSatisfy { $0.item != nil }, "A Photo survived with no owner")
    }

    @Test func removingAPhotoWhileEditingAWishlistItemDeletesIt() throws {
        let context = try makeInMemoryContext()

        let form = WishlistFormViewModel(modelContext: context)
        form.name = "Summicron 35mm f/2"
        form.categoryPath = "Photography/Lenses"
        form.estimatedCost = 2_400
        form.photos = PhotoSelection.appending([Data([0x01]), Data([0x02])], to: [])
        #expect(form.save())

        let wanted = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)

        let edit = WishlistFormViewModel(modelContext: context, editing: wanted)
        let dropped = try #require(edit.photos.first)
        edit.photos = PhotoSelection.removing(dropped, from: edit.photos)
        #expect(edit.save())

        let remaining = try context.fetch(FetchDescriptor<Photo>())
        #expect(remaining.count == 1, "\(remaining.count - 1) orphaned Photo row(s) left in the store")
        #expect(remaining.allSatisfy { $0.wishlistItem != nil }, "A Photo survived with no owner")
    }
}

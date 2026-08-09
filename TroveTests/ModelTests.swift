import Foundation
import SwiftData
import Testing
@testable import Trove

@Suite("Model defaults")
struct ModelDefaultsTests {
    @Test func itemAppliesDefaults() throws {
        let context = try makeInMemoryContext()
        let item = Item()
        context.insert(item)

        #expect(item.name == "")
        #expect(item.categoryPath == "")
        #expect(item.purchasePriceCents == 0)
        #expect(item.currencyCode == "USD")
        #expect(item.desireToKeep == 3)
        #expect(item.condition == .excellent)
        #expect(item.conditionRawValue == "excellent")
        #expect(item.serialNumber == nil)
        #expect(item.purchaseLocation == nil)
        #expect(item.conditionNotes == nil)
        #expect(item.notes == nil)
        #expect(item.photos?.isEmpty == true)
        #expect(item.plannedForWishlistItems?.isEmpty == true)
    }

    /// `nil` is not zero: the dashboard excludes un-valued items from its total
    /// and counts them separately, and the Sell Plan drops them from the
    /// candidate pool. A zero default would silently break both.
    @Test func itemCurrentValueStartsUnset() throws {
        let context = try makeInMemoryContext()
        let item = Item()
        context.insert(item)

        #expect(item.currentValueCents == nil)
    }

    @Test func wishlistItemAppliesDefaults() throws {
        let context = try makeInMemoryContext()
        let wishlistItem = WishlistItem()
        context.insert(wishlistItem)

        #expect(wishlistItem.name == "")
        #expect(wishlistItem.categoryPath == "")
        #expect(wishlistItem.estimatedCostCents == 0)
        #expect(wishlistItem.currencyCode == "USD")
        #expect(wishlistItem.notes == nil)
        #expect(wishlistItem.sortOrder == 0)
    }

    /// The Sell Plan starts empty and stays that way until the user picks
    /// something — spec.md is explicit that nothing is ever auto-selected.
    @Test func wishlistItemSellPlanStartsEmpty() throws {
        let context = try makeInMemoryContext()
        let wishlistItem = WishlistItem()
        context.insert(wishlistItem)

        #expect(wishlistItem.plannedSaleItems?.isEmpty == true)
    }

    @Test func photoAppliesDefaults() throws {
        let context = try makeInMemoryContext()
        let photo = Photo()
        context.insert(photo)

        #expect(photo.imageData.isEmpty)
        #expect(photo.source == .device)
        #expect(photo.sourceRawValue == "device")
        #expect(photo.sortOrder == 0)
        #expect(photo.item == nil)
    }

    @Test func timestampsAreSetOnCreation() throws {
        let before = Date.now
        let context = try makeInMemoryContext()
        let item = Item()
        context.insert(item)
        let after = Date.now

        #expect(item.createdAt >= before && item.createdAt <= after)
        #expect(item.updatedAt >= before && item.updatedAt <= after)
    }
}

@Suite("Enum-backed properties")
struct EnumBackedPropertyTests {
    @Test(arguments: Condition.allCases)
    func conditionRoundTripsThroughItsRawValue(condition: Condition) throws {
        let context = try makeInMemoryContext()
        let item = Item()
        context.insert(item)

        item.condition = condition

        #expect(item.conditionRawValue == condition.rawValue)
        #expect(item.condition == condition)
    }

    @Test(arguments: PhotoSource.allCases)
    func photoSourceRoundTripsThroughItsRawValue(source: PhotoSource) throws {
        let context = try makeInMemoryContext()
        let photo = Photo()
        context.insert(photo)

        photo.source = source

        #expect(photo.sourceRawValue == source.rawValue)
        #expect(photo.source == source)
    }

    /// The raw column is what actually persists, so an unrecognized string —
    /// a case removed in a later version, say — must degrade rather than trap.
    @Test func unrecognizedRawValuesFallBackToADefault() throws {
        let context = try makeInMemoryContext()
        let item = Item()
        let photo = Photo()
        context.insert(item)
        context.insert(photo)

        item.conditionRawValue = "immaculate"
        photo.sourceRawValue = "telepathy"

        #expect(item.condition == .excellent)
        #expect(photo.source == .device)
    }
}

@Suite("Model relationships")
struct ModelRelationshipTests {
    @Test func attachingAPhotoSetsItsInverse() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster")
        let photo = Photo(imageData: Data([0x01]))
        context.insert(item)
        context.insert(photo)

        item.photos = [photo]

        #expect(photo.item === item)
        #expect(item.photos?.count == 1)
    }

    @Test func addingAnItemToASellPlanSetsItsInverse() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster")
        let wishlistItem = WishlistItem(name: "Rickenbacker 330")
        context.insert(item)
        context.insert(wishlistItem)

        wishlistItem.plannedSaleItems = [item]

        #expect(item.plannedForWishlistItems?.count == 1)
        #expect(item.plannedForWishlistItems?.first === wishlistItem)
    }

    /// An item can be under consideration for more than one purchase at once —
    /// the relationship is many-to-many, not one-to-many.
    @Test func anItemCanAppearOnSeveralSellPlans() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster")
        let first = WishlistItem(name: "Rickenbacker 330")
        let second = WishlistItem(name: "Vox AC30")
        context.insert(item)
        context.insert(first)
        context.insert(second)

        first.plannedSaleItems = [item]
        second.plannedSaleItems = [item]

        #expect(item.plannedForWishlistItems?.count == 2)
    }

    /// Deleting a wishlist item must never destroy the gear on its Sell Plan —
    /// the plan is a decision aid, not ownership.
    @Test func deletingAWishlistItemLeavesItsPlannedItemsAlone() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster")
        let wishlistItem = WishlistItem(name: "Rickenbacker 330")
        context.insert(item)
        context.insert(wishlistItem)
        wishlistItem.plannedSaleItems = [item]

        context.delete(wishlistItem)
        try context.save()

        let survivors = try context.fetch(FetchDescriptor<Item>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.name == "Fender Telecaster")
        #expect(survivors.first?.plannedForWishlistItems?.isEmpty == true)
    }

    /// Photos, by contrast, belong to their item and go with it.
    @Test func deletingAnItemCascadesToItsPhotos() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster")
        let photo = Photo(imageData: Data([0x01]))
        context.insert(item)
        context.insert(photo)
        item.photos = [photo]
        try context.save()

        context.delete(item)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Photo>()).isEmpty)
    }
}

@Suite("Persistence")
struct PersistenceTests {
    @Test func itemsSurviveASaveAndRefetch() throws {
        let context = try makeInMemoryContext()
        let item = Item(
            name: "Fender Telecaster",
            categoryPath: "Music/Guitars/Electric",
            purchasePriceCents: 129_900,
            currentValueCents: 145_000,
            desireToKeep: 2,
            condition: .good
        )
        context.insert(item)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Item>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Fender Telecaster")
        #expect(fetched.first?.categoryPath == "Music/Guitars/Electric")
        #expect(fetched.first?.purchasePriceCents == 129_900)
        #expect(fetched.first?.currentValueCents == 145_000)
        #expect(fetched.first?.desireToKeep == 2)
        #expect(fetched.first?.condition == .good)
    }
}

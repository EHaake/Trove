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
    /// Refetched through a second context, so "survives a save" is what's
    /// actually being tested. On the same context this passed with the `save()`
    /// removed — `fetch` returns objects carrying unsaved changes — which the
    /// Sell Plan's mutation run surfaced as a general pattern, not a one-off.
    @Test func itemsSurviveASaveAndRefetch() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
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

        let fetched = try ModelContext(container).fetch(FetchDescriptor<Item>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Fender Telecaster")
        #expect(fetched.first?.categoryPath == "Music/Guitars/Electric")
        #expect(fetched.first?.purchasePriceCents == 129_900)
        #expect(fetched.first?.currentValueCents == 145_000)
        #expect(fetched.first?.desireToKeep == 2)
        #expect(fetched.first?.condition == .good)
    }
}

/// 002/T003: the two synced market fields. Optional integers with no
/// uniqueness — additive for CloudKit, which `CloudKitSchemaTests` covers
/// the moment they exist (its red run for this task: declare either as a
/// non-optional `Int` with no default and the validator throws).
@Suite("Market fields on the models")
struct MarketFieldsTests {
    @Test func bothKindsStartUnmatchedAndYearless() {
        let item = Item(name: "Telecaster")
        let wanted = WishlistItem(name: "D-18")

        #expect(item.reverbProductID == nil)
        #expect(item.year == nil)
        #expect(wanted.reverbProductID == nil)
        #expect(wanted.year == nil)
    }

    @Test func theInitParametersSetBoth() {
        let item = Item(name: "Telecaster", reverbProductID: 126_161, year: 2021)
        let wanted = WishlistItem(name: "D-18", reverbProductID: 182_769, year: 1975)

        #expect(item.reverbProductID == 126_161)
        #expect(item.year == 2021)
        #expect(wanted.reverbProductID == 182_769)
        #expect(wanted.year == 1975)
    }

    /// A second context, so the assertion is about what reached the store
    /// (see `makeInMemoryContainer`'s doc).
    @Test func bothFieldsSurviveASaveAndRefetch() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(Item(name: "Telecaster", reverbProductID: 126_161, year: 2021))
        context.insert(WishlistItem(name: "D-18", reverbProductID: 182_769, year: 1975))
        try context.save()

        let elsewhere = ModelContext(container)
        let item = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first)
        let wanted = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(item.reverbProductID == 126_161)
        #expect(item.year == 2021)
        #expect(wanted.reverbProductID == 182_769)
        #expect(wanted.year == 1975)
    }

    @Test func theExportRecordsSnapshotBoth() {
        let item = Item(name: "Telecaster", reverbProductID: 126_161, year: 2021)
        let wanted = WishlistItem(name: "D-18", reverbProductID: 182_769, year: 1975)

        let itemRecord = ItemExportRecord(item: item)
        let wantedRecord = WishlistExportRecord(item: wanted)
        #expect(itemRecord.reverbProductID == 126_161)
        #expect(itemRecord.year == 2021)
        #expect(wantedRecord.reverbProductID == 182_769)
        #expect(wantedRecord.year == 1975)
    }
}

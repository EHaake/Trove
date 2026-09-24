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

    /// What a fetch sees while the context still holds unsaved changes — the
    /// platform fact the list view models' refusal paths rest on, measured
    /// rather than assumed (CLAUDE.md: a claim about how the system behaves
    /// gets the test that would catch it being false).
    ///
    /// All four answers, on iOS 27: a pending insert is *already* in the
    /// fetch, a pending delete is *already* gone from it, and `rollback()`
    /// undoes each. So a refused `save()` in `duplicate(id:)` or
    /// `delete(id:)` cannot just re-`load()` — the fetch would hand back the
    /// copy that was never stored, or hide the row that still is, under a
    /// message saying the save failed. `rollback()` first is what makes the
    /// reload read the store. If a future OS changes any of this, this test
    /// goes red before the four catch blocks quietly become wrong.
    @Test func aFetchSeesTheContextsPendingInsertsAndDeletesUntilRollback() throws {
        let names = { (context: ModelContext) in
            try context.fetch(FetchDescriptor<Item>()).map(\.name).sorted()
        }

        // A pending insert, unsaved: visible.
        let inserting = ModelContext(try makeInMemoryContainer())
        inserting.insert(Item(name: "Stored", purchasePriceCents: 1))
        try inserting.save()
        inserting.insert(Item(name: "Unsaved", purchasePriceCents: 2))
        #expect(try names(inserting) == ["Stored", "Unsaved"], "an unsaved insert is already in the fetch")
        inserting.rollback()
        #expect(try names(inserting) == ["Stored"], "rollback() discards the pending insert")

        // A pending delete, unsaved: already gone.
        let deleting = ModelContext(try makeInMemoryContainer())
        let doomed = Item(name: "Doomed", purchasePriceCents: 1)
        deleting.insert(doomed)
        try deleting.save()
        deleting.delete(doomed)
        #expect(try names(deleting) == [], "an unsaved delete is already out of the fetch")
        deleting.rollback()
        #expect(try names(deleting) == ["Doomed"], "rollback() restores the pending delete")
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

/// 006/T001: the sale on `Item` — four optional fields and the link, read and
/// written as one `Sale` (plan Q1/§1). Optional-with-no-default keeps the
/// schema CloudKit-additive, which `CloudKitSchemaTests` covers (its red run
/// for this task: declare `soldDate` as a non-optional `Date` with no default
/// and the validator names it).
@Suite("The sale on Item")
struct ItemSaleFieldsTests {
    @Test func anOwnedItemHasNoSale() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Telecaster")
        context.insert(item)

        #expect(item.sale == nil)
        #expect(item.saleOutcome == nil)
        #expect(!item.isSold)
        #expect(item.soldDate == nil)
        #expect(item.salePriceCents == nil)
        #expect(item.saleLocation == nil)
        #expect(item.saleNote == nil)
        #expect(item.soldTowardWishlistItem == nil)
    }

    /// A second context, so this is about what reached the store rather than
    /// what the writing context still holds unsaved.
    @Test func aSaleRoundTripsAllFourFields() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let soldOn = Date(timeIntervalSince1970: 1_770_000_000)
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000)
        context.insert(item)
        item.sale = Sale(date: soldOn, priceCents: 130_000, location: "Reverb", note: "Shipped Tuesday")
        try context.save()

        let elsewhere = ModelContext(container)
        let fetched = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first)
        #expect(fetched.isSold)
        #expect(fetched.sale == Sale(date: soldOn, priceCents: 130_000, location: "Reverb", note: "Shipped Tuesday"))
        #expect(fetched.soldDate == soldOn)
        #expect(fetched.salePriceCents == 130_000)
        #expect(fetched.saleLocation == "Reverb")
        #expect(fetched.saleNote == "Shipped Tuesday")
        #expect(fetched.saleOutcome?.deltaCents == 30_000)
    }

    /// G2 — Return to collection (P12): clearing the sale clears all four
    /// fields *and* the plan link, checked on a second context so a setter
    /// that only looked right in memory would still fail here.
    @Test func clearingTheSaleClearsTheFourFieldsAndTheLink() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let wanted = WishlistItem(name: "Rickenbacker 330")
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000)
        context.insert(wanted)
        context.insert(item)
        item.sale = Sale(date: .now, priceCents: 130_000, location: "Reverb", note: "Shipped Tuesday")
        item.soldTowardWishlistItem = wanted
        try context.save()

        item.sale = nil
        try context.save()

        let elsewhere = ModelContext(container)
        let fetched = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first)
        #expect(fetched.sale == nil)
        #expect(!fetched.isSold)
        #expect(fetched.soldDate == nil)
        #expect(fetched.salePriceCents == nil)
        #expect(fetched.saleLocation == nil)
        #expect(fetched.saleNote == nil)
        #expect(fetched.soldTowardWishlistItem == nil, "clearing the sale must drop the plan link too")

        let stillWanted = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(stillWanted.itemsSoldToward?.isEmpty == true)
    }

    /// The defensive branch, recorded rather than relied on: no writer in this
    /// app sets a date without a price (they always go together), so a row
    /// like this can only come from a future version or a bug. It reads as a
    /// sale priced 0 rather than disappearing from the Sold side entirely.
    @Test func aDateWithoutAPriceReadsAsZero() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000)
        context.insert(item)

        item.soldDate = Date(timeIntervalSince1970: 1_770_000_000)

        #expect(item.isSold)
        #expect(item.sale?.priceCents == 0)
        #expect(item.saleOutcome?.deltaCents == -100_000)
    }
}

/// 015/T001 (G1): the bought marker on `WishlistItem` — one optional `Date`
/// and the predicate that reads it (plan §1/Q1). Optional with no default and
/// no uniqueness keeps the schema CloudKit-additive, which
/// `CloudKitSchemaTests` covers (its red run for this task: declare the field
/// `@Attribute(.unique) var boughtDate: Date?` and the validator throws).
/// Persistence across a second `ModelContext` is G2's.
@Suite("The bought marker on WishlistItem")
struct WishlistBoughtFieldTests {
    @Test func aFreshEntryIsStillWanted() throws {
        let context = try makeInMemoryContext()
        let wanted = WishlistItem(name: "Rickenbacker 330")
        context.insert(wanted)

        #expect(wanted.boughtDate == nil)
        #expect(!wanted.isBought)
    }

    @Test func aDateMakesItBought() throws {
        let context = try makeInMemoryContext()
        let boughtOn = Date(timeIntervalSince1970: 1_770_000_000)
        let wanted = WishlistItem(name: "Rickenbacker 330")
        context.insert(wanted)

        wanted.boughtDate = boughtOn

        #expect(wanted.boughtDate == boughtOn)
        #expect(wanted.isBought)
    }
}

/// 009/T001 (G2): the plan on `WishlistItem` — one optional `Date` and the
/// predicate that reads it, plus the "checked" stamp `init` writes so a new
/// entry is never taken for an older one awaiting the carry-over (plan §1,
/// Q1, Q2). The CloudKit side (G1) is `CloudKitSchemaTests`' — its red run
/// for this task: declare `@Attribute(.unique) var sellPlanCreatedAt: Date?`.
@Suite("The sell plan fields on WishlistItem")
struct WishlistSellPlanFieldTests {
    @Test func aFreshEntryIsPlanlessAndChecked() throws {
        let context = try makeInMemoryContext()
        let before = Date.now
        let wanted = WishlistItem(name: "Rickenbacker 330")
        context.insert(wanted)

        #expect(wanted.sellPlanCreatedAt == nil)
        #expect(!wanted.hasSellPlan)
        let checkedAt = try #require(wanted.sellPlanCheckedAt)
        #expect(checkedAt >= before)
    }

    @Test func aDateMakesItAPlan() throws {
        let context = try makeInMemoryContext()
        let createdOn = Date(timeIntervalSince1970: 1_770_000_000)
        let wanted = WishlistItem(name: "Rickenbacker 330")
        context.insert(wanted)

        wanted.sellPlanCreatedAt = createdOn

        #expect(wanted.sellPlanCreatedAt == createdOn)
        #expect(wanted.hasSellPlan)
    }
}

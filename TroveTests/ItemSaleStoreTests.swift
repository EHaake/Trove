import Foundation
import SwiftData
import Testing
@testable import Trove

/// 006/T003. The one writer of a sale (plan Q3, §2). Each rule is measured
/// separately because each fails differently: a kept plan selection changes a
/// Sell Plan's math without the user selecting anything, a kept market row
/// leaves a sold item claiming a live figure, a reset `sortOrder` loses the
/// slot a returned item is supposed to reappear in, and a cleared match would
/// make Return to collection a re-matching chore.
///
/// `ItemSaleStore` doesn't save — callers do, the `MarketLocalStore` shape —
/// so every persistence assertion here saves and refetches on a **second**
/// `ModelContext`: a same-context refetch hands back objects carrying unsaved
/// changes and would pass whether or not the save happened
/// (`makeInMemoryContainer`'s doc).
@Suite("Item sale store")
struct ItemSaleStoreTests {
    private let soldOn = Date(timeIntervalSince1970: 1_770_000_000)
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func sale(_ priceCents: Int = 130_000) -> Sale {
        Sale(date: soldOn, priceCents: priceCents, location: "Reverb", note: "Shipped Tuesday")
    }

    private let product = MarketProduct(
        id: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster",
        usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
    )

    /// One refresh's worth of local rows for `subjectID`: the figure, a
    /// history point and the match snapshot, recorded exactly as a real
    /// refresh records them.
    private func seedMarketRows(for subjectID: UUID, in context: ModelContext) throws {
        let reading = MarketReading.figure(MarketFigure(
            medianCents: 140_000, lowCents: 130_000, highCents: 150_000,
            p10Cents: 132_000, p90Cents: 148_000,
            count: 12, fetchedAt: soldOn, isTruncated: false, yearScope: .any
        ))
        try MarketLocalStore.record(reading, product: product, for: MarketSubjectKey(subjectID: subjectID, kind: .owned), in: context)
    }

    // MARK: - markSold

    /// G4 (spec P6, criterion 4). The item survives its own sale, so the
    /// selections have to be dropped explicitly — deletion's `.nullify` isn't
    /// doing it here. The wishlist entries themselves must be untouched.
    @Test func aSaleEmptiesEveryPlanSelectionAndLeavesTheWishlistEntriesStanding() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let other = Item(name: "Blues Junior", purchasePriceCents: 60_000)
        let firstPlan = WishlistItem(name: "Rickenbacker 330")
        let secondPlan = WishlistItem(name: "Vox AC15")
        for model in [item, other] { context.insert(model) }
        for model in [firstPlan, secondPlan] { context.insert(model) }
        firstPlan.plannedSaleItems = [item, other]
        secondPlan.plannedSaleItems = [item]
        try context.save()

        try ItemSaleStore.markSold(item, sale: sale(), toward: nil, at: now, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        let sold = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first { $0.name == "Telecaster" })
        #expect(sold.plannedForWishlistItems?.isEmpty == true, "a sold item must be on no Sell Plan")

        let plans = try elsewhere.fetch(FetchDescriptor<WishlistItem>())
        #expect(plans.count == 2, "the wishlist entries survive the sale")
        let byName = Dictionary(uniqueKeysWithValues: plans.map { ($0.name, $0) })
        #expect(try #require(byName["Rickenbacker 330"]).plannedSaleItems?.map(\.name) == ["Blues Junior"], "only the sold item leaves the plan")
        #expect(try #require(byName["Vox AC15"]).plannedSaleItems?.isEmpty == true)
    }

    /// G5 (Decision 7, criterion 5). The device's rows for this item go; every
    /// other item's stay, so the clear is scoped by subject and not a wipe.
    @Test func theSaleClearsThisItemsMarketRowsAndLeavesAnothersStanding() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000, reverbProductID: 126_161)
        let other = Item(name: "Blues Junior", purchasePriceCents: 60_000, reverbProductID: 222)
        for model in [item, other] { context.insert(model) }
        try seedMarketRows(for: item.id, in: context)
        try seedMarketRows(for: other.id, in: context)
        try context.save()

        try ItemSaleStore.markSold(item, sale: sale(), toward: nil, at: now, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        #expect(try MarketLocalStore.figure(for: item.id, in: elsewhere) == nil, "the sold item's figure must be gone")
        #expect(try MarketLocalStore.history(for: item.id, in: elsewhere).isEmpty, "its history must be gone")
        #expect(try MarketLocalStore.snapshot(for: item.id, in: elsewhere) == nil, "its snapshot must be gone")
        #expect(try MarketLocalStore.figure(for: other.id, in: elsewhere) != nil, "another item's figure must be untouched")
        #expect(try MarketLocalStore.history(for: other.id, in: elsewhere).count == 1)
        #expect(try MarketLocalStore.snapshot(for: other.id, in: elsewhere) != nil)
    }

    /// G6 (spec P5, criterion 11). Sold from a Sell Plan, the sale points at
    /// that plan; sold from the detail screen, it points at nothing.
    @Test func theSaleLinksToAPlanOnlyWhenOneIsPassed() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let fromPlan = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let fromDetail = Item(name: "Blues Junior", purchasePriceCents: 60_000)
        let plan = WishlistItem(name: "Rickenbacker 330")
        for model in [fromPlan, fromDetail] { context.insert(model) }
        context.insert(plan)
        try context.save()

        try ItemSaleStore.markSold(fromPlan, sale: sale(), toward: plan, at: now, in: context)
        try ItemSaleStore.markSold(fromDetail, sale: sale(70_000), toward: nil, at: now, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        let items = Dictionary(uniqueKeysWithValues: try elsewhere.fetch(FetchDescriptor<Item>()).map { ($0.name, $0) })
        #expect(try #require(items["Telecaster"]).soldTowardWishlistItem?.name == "Rickenbacker 330")
        #expect(try #require(items["Blues Junior"]).soldTowardWishlistItem == nil, "a detail-screen sale is toward no plan")

        let stored = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(stored.itemsSoldToward?.map(\.name) == ["Telecaster"])
    }

    /// G20 (criterion 3, Decision 1). The sale is a state change, not an edit:
    /// the item's own fields and photos are as they were, and the Reverb match
    /// is *kept* — only the device-local rows go, so a return resumes
    /// refreshing without re-matching.
    @Test func markingSoldLeavesTheItemsOwnFieldsPhotosAndMatchUntouched() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let purchasedOn = Date(timeIntervalSince1970: 1_000_000)
        let item = Item(
            name: "Telecaster",
            categoryPath: "Music/Guitars",
            purchasePriceCents: 100_000,
            purchaseDate: purchasedOn,
            serialNumber: "TL-1138",
            purchaseLocation: "Guitar Center",
            currentValueCents: 120_000,
            desireToKeep: 2,
            condition: .good,
            conditionNotes: "Buckle rash",
            notes: "Ash body",
            sortOrder: 4,
            photos: [Photo(imageData: Data([0xAB, 0xCD]), source: .device)],
            reverbProductID: 126_161,
            year: 1975
        )
        context.insert(item)
        try context.save()

        try ItemSaleStore.markSold(item, sale: sale(), toward: nil, at: now, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        let sold = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first)
        #expect(sold.name == "Telecaster")
        #expect(sold.categoryPath == "Music/Guitars")
        #expect(sold.purchasePriceCents == 100_000)
        #expect(sold.purchaseDate == purchasedOn)
        #expect(sold.serialNumber == "TL-1138")
        #expect(sold.purchaseLocation == "Guitar Center")
        #expect(sold.currentValueCents == 120_000)
        #expect(sold.desireToKeep == 2)
        #expect(sold.condition == .good)
        #expect(sold.conditionNotes == "Buckle rash")
        #expect(sold.notes == "Ash body")
        #expect(sold.sortOrder == 4, "the sale never touches the manual position")
        #expect(sold.year == 1975)
        #expect(sold.photos?.count == 1, "the photos are the item's, not the listing's")
        #expect(sold.photos?.first?.imageData == Data([0xAB, 0xCD]))
        #expect(sold.reverbProductID == 126_161, "the match is left as it was (Decision 1) — only the local rows are cleared")
        #expect(sold.sale == sale())
    }

    // MARK: - The pair

    /// G9. No writer here may store half a sale: `Item.sale`'s getter treats a
    /// date without a price as a sale priced 0, which is a defensive read, not
    /// a state this app is allowed to write.
    @Test func everyStoredSaleHasBothADateAndAPrice() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let marked = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let edited = Item(name: "Blues Junior", purchasePriceCents: 60_000)
        for model in [marked, edited] { context.insert(model) }
        try context.save()

        try ItemSaleStore.markSold(marked, sale: sale(), toward: nil, at: now, in: context)
        try ItemSaleStore.markSold(edited, sale: sale(70_000), toward: nil, at: now, in: context)
        ItemSaleStore.editSale(edited, sale: Sale(date: soldOn, priceCents: 75_000, location: nil, note: nil), at: now)
        try context.save()

        let elsewhere = ModelContext(container)
        let stored = try elsewhere.fetch(FetchDescriptor<Item>())
        #expect(stored.count == 2)
        for item in stored {
            #expect(item.soldDate != nil, "\(item.name) stored a sale with no date")
            #expect(item.salePriceCents != nil, "\(item.name) stored a sale with no price")
        }
        #expect(try #require(stored.first { $0.name == "Blues Junior" }).salePriceCents == 75_000)
    }

    // MARK: - editSale

    /// G21 (spec P5). Editing the four fields must not quietly unfund the plan
    /// the sale was recorded toward — the edit is not a re-mark.
    @Test func editSaleKeepsThePlanLink() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let plan = WishlistItem(name: "Rickenbacker 330")
        context.insert(item)
        context.insert(plan)
        try ItemSaleStore.markSold(item, sale: sale(), toward: plan, at: now, in: context)
        try context.save()

        let corrected = Sale(date: soldOn.addingTimeInterval(3_600), priceCents: 125_000, location: "eBay", note: nil)
        ItemSaleStore.editSale(item, sale: corrected, at: now.addingTimeInterval(60))
        try context.save()

        let elsewhere = ModelContext(container)
        let stored = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first)
        #expect(stored.sale == corrected, "the four fields are the edit's")
        #expect(stored.soldTowardWishlistItem?.name == "Rickenbacker 330", "the edit must leave the funding link alone")
    }

    /// What G21 rests on, asserted on the setter itself (asked for at T001's
    /// review): setting a sale on an item that already carries a plan link
    /// leaves the link where it is. Only setting `nil` clears it.
    @Test func settingASaleLeavesAnExistingPlanLinkAlone() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let plan = WishlistItem(name: "Rickenbacker 330")
        context.insert(item)
        context.insert(plan)
        item.soldTowardWishlistItem = plan
        try context.save()

        item.sale = sale()
        try context.save()

        let elsewhere = ModelContext(container)
        let stored = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first)
        #expect(stored.sale == sale())
        #expect(stored.soldTowardWishlistItem?.name == "Rickenbacker 330")
    }

    // MARK: - returnToCollection

    /// G7 (spec P12). `sortOrder` is never touched by either direction, so the
    /// returned item is back in its own Custom-order slot among the others —
    /// not appended at the end — and it rejoins no plan.
    @Test func markThenReturnLeavesSortOrderAndTheCustomSlotUnchanged() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        var created = Date(timeIntervalSince1970: 900_000)
        var items: [Item] = []
        for (position, name) in ["Alpha", "Bravo", "Charlie", "Delta"].enumerated() {
            let item = Item(name: name, purchasePriceCents: 10_000, sortOrder: position)
            item.createdAt = created
            created = created.addingTimeInterval(60)
            context.insert(item)
            items.append(item)
        }
        let plan = WishlistItem(name: "Rickenbacker 330")
        context.insert(plan)
        let charlie = items[2]
        plan.plannedSaleItems = [charlie]
        try context.save()

        try ItemSaleStore.markSold(charlie, sale: sale(), toward: plan, at: now, in: context)
        try context.save()
        ItemSaleStore.returnToCollection(charlie, at: now.addingTimeInterval(120))
        try context.save()

        let elsewhere = ModelContext(container)
        let stored = try elsewhere.fetch(FetchDescriptor<Item>())
        let returned = try #require(stored.first { $0.name == "Charlie" })
        #expect(returned.sortOrder == 2, "the return must not renumber the item")
        #expect(returned.sale == nil)
        #expect(!returned.isSold)
        #expect(returned.soldTowardWishlistItem == nil, "the returned item funds nothing")
        #expect(returned.plannedForWishlistItems?.isEmpty == true, "it rejoins no plan (P12)")
        #expect(
            stored.sorted(by: ManualOrderHelper.areInCustomOrder).map(\.name) == ["Alpha", "Bravo", "Charlie", "Delta"],
            "the returned item is back in its former Custom-order slot"
        )
    }

    /// Plan Q13: each of the three is a change to the item row, so each bumps
    /// `updatedAt`.
    @Test func allThreeWritersBumpUpdatedAt() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster", purchasePriceCents: 100_000)
        context.insert(item)
        try context.save()

        try ItemSaleStore.markSold(item, sale: sale(), toward: nil, at: now, in: context)
        #expect(item.updatedAt == now)

        let edited = now.addingTimeInterval(60)
        ItemSaleStore.editSale(item, sale: sale(125_000), at: edited)
        #expect(item.updatedAt == edited)

        let returned = now.addingTimeInterval(120)
        ItemSaleStore.returnToCollection(item, at: returned)
        #expect(item.updatedAt == returned)

        try context.save()
        let elsewhere = ModelContext(container)
        #expect(try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first).updatedAt == returned)
    }
}

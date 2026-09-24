import Foundation
import SwiftData
import Testing
@testable import Trove

/// 015/T003. The one writer of a purchase (plan Q4, §3). Each rule is measured
/// separately because each fails differently: a wrong `currentValueCents`
/// makes a just-bought item look like a gain or a loss on day one, a rebuilt
/// photo drops the stock credit `005` requires to survive, a kept plan
/// selection leaves gear earmarked toward a purchase that already happened,
/// and a kept market row leaves a bought entry claiming a live wanted figure.
///
/// `WishlistPurchaseStore` doesn't save — callers do, the `MarketLocalStore`
/// shape — so every persistence assertion here saves and refetches on a
/// **second** `ModelContext`: a same-context refetch hands back objects
/// carrying unsaved changes and would pass whether or not the save happened
/// (`makeInMemoryContainer`'s doc).
@Suite("Wishlist purchase store")
struct WishlistPurchaseStoreTests {
    private let boughtOn = Date(timeIntervalSince1970: 1_770_000_000)
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func purchase(_ priceCents: Int = 240_000) -> Purchase {
        Purchase(date: boughtOn, priceCents: priceCents, location: "Reverb", condition: .good)
    }

    private let product = MarketProduct(
        id: 126_161, slug: "rickenbacker-330", title: "Rickenbacker 330",
        usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
    )

    /// One refresh's worth of local rows for a *wanted* subject: the figure,
    /// a history point and the match snapshot, recorded as a real refresh
    /// records them.
    private func seedMarketRows(for subjectID: UUID, in context: ModelContext) throws {
        let reading = MarketReading.figure(MarketFigure(
            medianCents: 250_000, lowCents: 230_000, highCents: 270_000,
            p10Cents: 235_000, p90Cents: 265_000,
            count: 12, fetchedAt: boughtOn, isTruncated: false, yearScope: .any
        ))
        try MarketLocalStore.record(reading, product: product, for: MarketSubjectKey(subjectID: subjectID, kind: .wanted), in: context)
    }

    // MARK: - G5: the item the purchase creates

    /// G5 (spec P3–P5, criterion 7). The thirteen fields the new item settles:
    /// the eleven `Item.init` is passed, plus `desireToKeep` left at the
    /// initializer's default (P5 — the wanting scale is not the keeping scale)
    /// and `sortOrder`.
    ///
    /// The existing items' positions carry a deliberate gap (0, 3, 7): a
    /// `nextPosition` written as a *count* would put the new item on rung 3,
    /// on top of one that is already there.
    @Test func theBoughtItemCarriesTheEntrysFieldsThePurchasesAndTheEndOfTheOrder() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        for (name, position) in [("Telecaster", 0), ("Blues Junior", 3), ("Jazzmaster", 7)] {
            context.insert(Item(name: name, purchasePriceCents: 50_000, sortOrder: position))
        }
        let wanted = WishlistItem(
            name: "Rickenbacker 330",
            categoryPath: "Music/Guitars",
            estimatedCostCents: 200_000,
            // Not "USD": both initializers default to it, so a carried-across
            // currency and a dropped one would read the same (criterion 7).
            currencyCode: "CAD",
            notes: "Fireglo, no checking",
            desireToOwn: 1,
            sortOrder: 2,
            reverbProductID: 126_161,
            year: 1967
        )
        context.insert(wanted)
        try context.save()

        try WishlistPurchaseStore.markBought(wanted, purchase: purchase(), at: now, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        // The name leg is this `#require`: no item is named for the wanted
        // entry unless the purchase carried its name across.
        let bought = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first { $0.name == "Rickenbacker 330" })
        #expect(bought.categoryPath == "Music/Guitars")
        #expect(bought.purchasePriceCents == 240_000)
        #expect(bought.purchaseDate == boughtOn)
        #expect(bought.currencyCode == "CAD", "the entry's currency is carried, not the initializer's default")
        #expect(bought.purchaseLocation == "Reverb")
        #expect(bought.currentValueCents == 240_000, "a just-bought item is worth what it cost (P4)")
        #expect(bought.condition == .good, "the condition is the purchase's, not the default")
        #expect(bought.notes == "Fireglo, no checking")
        #expect(bought.reverbProductID == 126_161)
        #expect(bought.year == 1967)
        // The entry wants this at 1 ("Someday"); the item's keeping default is 3,
        // so a carried-across `desireToOwn` reads differently from the default.
        #expect(bought.desireToKeep == 3, "the wanting scale is not the keeping scale (P5): the initializer's default stands")
        #expect(bought.sortOrder == 8, "the new item goes past the highest position, never at a count of them")
    }

    // MARK: - G6: the photos

    /// G6 (Q6, criterion 7). The photos **move**: the same rows change parent,
    /// so the store's `Photo` count is unchanged (copying doubles it, losing
    /// one lowers it) and a stock photo's three credit strings survive because
    /// nothing was rebuilt. Display order is preserved and renumbered from
    /// zero.
    @Test func thePhotosMoveToTheItemWithTheirIdsCreditAndOrderIntact() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let attribution = StockPhotoAttribution(
            author: "Jane Commons",
            licenseName: "CC BY-SA 4.0",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Rickenbacker_330.jpg")!
        )
        // Positions 5 and 2, so display order is the stock photo first and a
        // move that ignored `inDisplayOrder` would renumber them the other way.
        let device = Photo(imageData: Data([0xAB, 0xCD]), source: .device, sortOrder: 5)
        let stock = Photo.fetched(imageData: Data([0x01, 0x02]), attribution: attribution, sortOrder: 2)
        let wanted = WishlistItem(name: "Rickenbacker 330")
        context.insert(wanted)
        for photo in [device, stock] { context.insert(photo) }
        wanted.photos = [device, stock]
        try context.save()
        let deviceID = device.id
        let stockID = stock.id

        try WishlistPurchaseStore.markBought(wanted, purchase: purchase(), at: now, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        let bought = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first)
        let moved = PhotoSelection.inDisplayOrder(bought.photos ?? [])
        #expect(moved.map(\.id) == [stockID, deviceID], "the same rows, in the display order they had")
        #expect(moved.map(\.sortOrder) == [0, 1], "renumbered from zero")
        #expect(try elsewhere.fetch(FetchDescriptor<Photo>()).count == 2, "a moved photo is neither copied nor dropped")
        #expect(moved.allSatisfy { $0.wishlistItem == nil }, "a moved photo has one parent, never both")
        #expect(moved.allSatisfy { $0.item?.id == bought.id })

        let credit = try #require(moved.first { $0.id == stockID }?.attribution)
        #expect(credit == attribution, "a rebuilt row would drop the three stored credit strings")
        #expect(moved.first { $0.id == deviceID }?.imageData == Data([0xAB, 0xCD]))

        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(entry.photos?.isEmpty == true, "the wanted entry keeps no photo of what it no longer wants")
    }

    // MARK: - G7: the plan

    /// G7 (spec P6, Decision 3, criterion 9). The entry survives the purchase:
    /// the unsold candidates are released from the plan, the sales already
    /// recorded toward it stay, and the released gear is still in the
    /// collection and still unsold.
    @Test func thePurchaseReleasesTheUnsoldCandidatesAndKeepsWhatWasSoldTowardIt() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let candidate = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let otherCandidate = Item(name: "Blues Junior", purchasePriceCents: 60_000)
        let alreadySold = Item(name: "Jazzmaster", purchasePriceCents: 80_000)
        let wanted = WishlistItem(name: "Rickenbacker 330")
        for model in [candidate, otherCandidate, alreadySold] { context.insert(model) }
        context.insert(wanted)
        wanted.plannedSaleItems = [candidate, otherCandidate]
        try ItemSaleStore.markSold(
            alreadySold,
            sale: Sale(date: boughtOn, priceCents: 90_000, location: "Reverb", note: nil),
            toward: wanted, at: now, in: context
        )
        try context.save()

        try WishlistPurchaseStore.markBought(wanted, purchase: purchase(), at: now, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(entry.plannedSaleItems?.isEmpty == true, "nothing is earmarked toward a purchase that has happened (P6)")
        #expect(entry.itemsSoldToward?.map(\.name) == ["Jazzmaster"], "what was sold toward it stays recorded (Decision 3)")
        #expect(entry.itemsSoldToward?.count == 1)

        let stored = try elsewhere.fetch(FetchDescriptor<Item>())
        let released = stored.filter { ["Telecaster", "Blues Junior"].contains($0.name) }
        #expect(released.count == 2, "the released candidates are still in the collection")
        #expect(released.allSatisfy { !$0.isSold }, "releasing a candidate must not sell it")
        #expect(released.allSatisfy { $0.plannedForWishlistItems?.isEmpty == true }, "they are on no plan afterwards")
    }

    // MARK: - G2: the marker

    /// G2 (criterion 9). The entry is marked, not deleted — and the marker,
    /// the new item and the emptied plan all reach the store on the caller's
    /// own `save()`. Refetched on a second context, so dropping that `save()`
    /// turns this red.
    @Test func theEntryIsMarkedBoughtAndEverythingSurvivesTheCallersSave() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let candidate = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let wanted = WishlistItem(name: "Rickenbacker 330")
        context.insert(candidate)
        context.insert(wanted)
        wanted.plannedSaleItems = [candidate]
        wanted.photos = [Photo(imageData: Data([0xAB]), source: .device)]
        try context.save()

        try WishlistPurchaseStore.markBought(wanted, purchase: purchase(), at: now, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(entry.boughtDate == now, "the marker is the `at:` stamp the caller passed")
        #expect(entry.isBought)
        #expect(entry.name == "Rickenbacker 330", "the entry is marked, never deleted")
        #expect(entry.plannedSaleItems?.isEmpty == true)
        #expect(entry.photos?.isEmpty == true)
        #expect(try elsewhere.fetch(FetchDescriptor<Item>()).contains { $0.name == "Rickenbacker 330" },
                "the created item reached the store")
        #expect(try elsewhere.fetch(FetchDescriptor<Photo>()).count == 1)
    }

    // MARK: - G8: the device's market rows

    /// G8 (plan Q12). The bought entry's device-local rows go — a bought entry
    /// is nothing's refresh target, so a stale wanted figure would have no
    /// screen to be corrected on. Another subject's rows are untouched, so the
    /// clear is scoped by subject and not a wipe; the new item starts
    /// unmatched-for-figures, as a hand-added matched item does.
    @Test func thePurchaseClearsTheEntrysMarketRowsAndLeavesAnothersStanding() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let wanted = WishlistItem(name: "Rickenbacker 330", reverbProductID: 126_161)
        let otherWanted = WishlistItem(name: "Vox AC15", reverbProductID: 222)
        for model in [wanted, otherWanted] { context.insert(model) }
        try seedMarketRows(for: wanted.id, in: context)
        try seedMarketRows(for: otherWanted.id, in: context)
        try context.save()

        let item = try WishlistPurchaseStore.markBought(wanted, purchase: purchase(), at: now, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        #expect(try MarketLocalStore.figure(for: wanted.id, in: elsewhere) == nil, "the bought entry's figure must be gone")
        #expect(try MarketLocalStore.history(for: wanted.id, in: elsewhere).isEmpty, "its history must be gone")
        #expect(try MarketLocalStore.snapshot(for: wanted.id, in: elsewhere) == nil, "its snapshot must be gone")
        #expect(try MarketLocalStore.figure(for: item.id, in: elsewhere) == nil, "the new item is unmatched-for-figures until its first refresh")
        #expect(try MarketLocalStore.figure(for: otherWanted.id, in: elsewhere) != nil, "another entry's figure must be untouched")
        #expect(try MarketLocalStore.history(for: otherWanted.id, in: elsewhere).count == 1)
        #expect(try MarketLocalStore.snapshot(for: otherWanted.id, in: elsewhere) != nil)
    }

    // MARK: - G25: the record of the item the purchase became

    /// G25 (009 Amendment A, QA1, criterion 20). The purchase records the item
    /// it became, and **both ends** read back on a second context. `Item` has
    /// two to-one relationships into `WishlistItem`, so the bought item's
    /// `soldTowardWishlistItem` is read too: a purchase that wrote the record
    /// onto the sold-toward link turns that leg red (T017, mutation-checked).
    /// With `inverse:` removed from `Item`'s declaration, what T017 observed
    /// was not a mis-pairing: SwiftData made two one-way links, the item's
    /// `boughtFromWishlistItem` read back nil here, and the CloudKit schema
    /// check went red.
    @Test func thePurchaseRecordsTheItemItBecameOnBothEnds() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        // An owned bystander, so "the item it became" is picked out of more
        // than one `Item`.
        context.insert(Item(name: "Telecaster", purchasePriceCents: 100_000))
        let wanted = WishlistItem(name: "Rickenbacker 330")
        context.insert(wanted)
        try context.save()
        let wantedID = wanted.id

        let item = try WishlistPurchaseStore.markBought(wanted, purchase: purchase(), at: now, in: context)
        try context.save()
        let itemID = item.id

        let elsewhere = ModelContext(container)
        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first { $0.id == wantedID })
        let bought = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first { $0.id == itemID })
        #expect(entry.boughtItem?.id == itemID, "the entry records the item its purchase created")
        #expect(bought.boughtFromWishlistItem?.id == wantedID, "and the item records the entry it came from")
        #expect(bought.soldTowardWishlistItem == nil, "the record is not the sold-toward link")
        #expect((entry.itemsSoldToward ?? []).isEmpty, "nothing was sold toward the entry")
    }

    /// G25. A refused second purchase moves nothing: the record stays on the
    /// first purchase's item and no second item is created.
    @Test func aRefusedSecondPurchaseLeavesTheRecordOnTheFirstItem() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let wanted = WishlistItem(name: "Rickenbacker 330")
        context.insert(wanted)
        try context.save()

        let first = try WishlistPurchaseStore.markBought(wanted, purchase: purchase(), at: now, in: context)
        try context.save()
        let firstID = first.id

        #expect(throws: WishlistPurchaseStore.PurchaseError.alreadyBought) {
            try WishlistPurchaseStore.markBought(wanted, purchase: purchase(310_000), at: now, in: context)
        }
        try context.save()

        let elsewhere = ModelContext(container)
        let items = try elsewhere.fetch(FetchDescriptor<Item>())
        #expect(items.map(\.id) == [firstID], "a refused purchase creates no second item")
        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(entry.boughtItem?.id == firstID, "the record stays on the first purchase's item")
    }

    // MARK: - G26: the record's delete rules

    /// A planned entry bought, one photo moved onto the item, saved.
    private func boughtWithAPlan(
        in context: ModelContext
    ) throws -> (wantedID: UUID, itemID: UUID, photoID: UUID) {
        let wanted = WishlistItem(name: "Rickenbacker 330")
        context.insert(wanted)
        let photo = Photo(imageData: Data([0xAB]), source: .device)
        context.insert(photo)
        wanted.photos = [photo]
        SellPlanStore.create(for: wanted, at: boughtOn)
        try context.save()
        let item = try WishlistPurchaseStore.markBought(wanted, purchase: purchase(), at: now, in: context)
        try context.save()
        return (wanted.id, item.id, photo.id)
    }

    /// G26 (QA1, criteria 13 and 20). Deleting the bought item nils the
    /// record and nothing more: the entry is still there, still bought, still
    /// planned — a completed plan with the placeholder.
    @Test func deletingTheBoughtItemLeavesTheEntryBoughtAndPlannedWithNoRecord() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let ids = try boughtWithAPlan(in: context)

        let deleting = ModelContext(container)
        let item = try #require(try deleting.fetch(FetchDescriptor<Item>()).first { $0.id == ids.itemID })
        deleting.delete(item)
        try deleting.save()

        let elsewhere = ModelContext(container)
        #expect(try elsewhere.fetch(FetchDescriptor<Item>()).isEmpty, "the fixture: the bought item is gone")
        let entry = try #require(
            try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first { $0.id == ids.wantedID },
            "deleting the bought item must never delete the entry"
        )
        #expect(entry.boughtDate == now, "the entry is still bought")
        #expect(entry.sellPlanCreatedAt == boughtOn, "and still planned, so it stays on Completed")
        #expect(entry.boughtItem == nil, "the record nils with the item")
    }

    /// G26 (QA1). Selling the bought item leaves the record where it was —
    /// sold toward *another* entry's plan, so the sale writes `Item`'s other
    /// to-one into `WishlistItem` beside the record.
    @Test func sellingTheBoughtItemLeavesTheRecordIntact() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let ids = try boughtWithAPlan(in: context)
        let nextWant = WishlistItem(name: "Vox AC15")
        context.insert(nextWant)
        try context.save()
        let nextWantID = nextWant.id

        let item = try #require(try context.fetch(FetchDescriptor<Item>()).first { $0.id == ids.itemID })
        try ItemSaleStore.markSold(
            item, sale: Sale(date: now, priceCents: 260_000, location: "Reverb", note: nil),
            toward: nextWant, at: now, in: context
        )
        try context.save()

        let elsewhere = ModelContext(container)
        let entries = try elsewhere.fetch(FetchDescriptor<WishlistItem>())
        let entry = try #require(entries.first { $0.id == ids.wantedID })
        let sold = try #require(try elsewhere.fetch(FetchDescriptor<Item>()).first { $0.id == ids.itemID })
        #expect(sold.isSold, "the fixture: the bought item sold")
        #expect(entry.boughtItem?.id == ids.itemID, "the entry still records the item it became")
        #expect(sold.boughtFromWishlistItem?.id == ids.wantedID)
        #expect(sold.soldTowardWishlistItem?.id == nextWantID, "the sale's own link is the other entry")
        #expect(entries.first { $0.id == nextWantID }?.boughtItem == nil, "the sale records no purchase")
    }

    /// G26 (QA1). No path deletes a bought entry today (`015` R1); if one ever
    /// does, the owned item and its photos stay.
    @Test func deletingTheBoughtEntryLeavesTheItemAndItsPhotos() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let ids = try boughtWithAPlan(in: context)

        let deleting = ModelContext(container)
        let entry = try #require(try deleting.fetch(FetchDescriptor<WishlistItem>()).first { $0.id == ids.wantedID })
        deleting.delete(entry)
        try deleting.save()

        let elsewhere = ModelContext(container)
        #expect(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).isEmpty, "the fixture: the entry is gone")
        let item = try #require(
            try elsewhere.fetch(FetchDescriptor<Item>()).first { $0.id == ids.itemID },
            "deleting the entry must never delete the owned item"
        )
        #expect(item.boughtFromWishlistItem == nil, "the record nils with the entry")
        #expect((item.photos ?? []).map(\.id) == [ids.photoID], "the item keeps its photos")
        #expect(try elsewhere.fetch(FetchDescriptor<Photo>()).count == 1)
    }
}

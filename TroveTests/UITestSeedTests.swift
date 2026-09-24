import Foundation
import SwiftData
import Testing
@testable import Trove

/// Spec 003, Decision 9 and criterion 12: the seeded Sell Plan the UI test
/// and the device pass are verified against, and the two conditions the
/// constitution puts on a test-only branch that *adds* rows — the in-memory
/// bound is structural, and the seed takes its own second argument.
///
/// Each test is named for the mutation that turns it red (plan §7, G8–G11).
@Suite("UITestSeed")
struct UITestSeedTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private struct Seeded {
        let context: ModelContext
        let items: [String: Item]
        let wishlistItem: WishlistItem
    }

    // MARK: - G8, the gate

    /// The flag alone seeds nothing, and — the structural half — neither
    /// does every flag set against a store that is on disk. Mutation: gate on
    /// the arguments alone, and the two persistent modes go red.
    @Test func seedsOnlyTheInMemoryStoreAndOnlyWithItsOwnArgument() {
        let both = ["-uiTesting", UITestSeed.argument]

        #expect(UITestSeed.shouldSeed(mode: .ephemeral, arguments: both))

        #expect(
            !UITestSeed.shouldSeed(mode: .ephemeral, arguments: []),
            "an in-memory store with no arguments at all still needs the seed's own flag"
        )
        #expect(
            !UITestSeed.shouldSeed(mode: .ephemeral, arguments: ["-uiTesting"]),
            "-uiTesting alone must keep starting from an empty collection"
        )
        #expect(
            !UITestSeed.shouldSeed(mode: .cloudKit, arguments: both),
            "a synced store would be seeded with test data"
        )
        #expect(
            !UITestSeed.shouldSeed(mode: .localOnly, arguments: both),
            "an on-disk store would be seeded with test data"
        )
    }

    /// The app calls the seed once, under the guard, and still reads
    /// `-uiTesting` in exactly one place. Mutations: a second call outside the
    /// block; a second `-uiTesting` literal.
    @Test func theAppCallsTheSeedOnceUnderTheGuardAndReadsTheFlagOnce() throws {
        let code = try SourceScan.production("Trove/App/TroveApp.swift")

        #expect(code.ranges(of: "UITestSeed.sellPlan(").count == 1, "the seed is called more than once, or not at all")

        let guarded = SourceScan.closureBodies(after: "if UITestSeed.shouldSeed(mode: store.mode", in: code)
        try #require(guarded.count == 1, "TroveApp should gate the seed on shouldSeed(mode: store.mode …) exactly once")
        #expect(guarded[0].contains("UITestSeed.sellPlan("), "the seed call sits outside its guard")

        let literals = SourceScan.stringLiterals(in: code)
        #expect(literals.filter { $0 == "-uiTesting" }.count == 1, "-uiTesting is read in more than one place")
        #expect(!literals.contains(UITestSeed.argument), "the seed's argument is spelled in TroveApp — it lives in UITestSeed.argument alone")
    }

    // MARK: - G9, what the seed writes

    /// Through the production container pairing, so the local rows are proven
    /// to insert beside the collection's under the real configurations.
    @Test func theSeedFillsBothStoresThroughTheProductionContainer() throws {
        let seeded = try seed()

        #expect(try seeded.context.fetch(FetchDescriptor<Item>()).count == 4)
        #expect(try seeded.context.fetch(FetchDescriptor<WishlistItem>()).count == 1)
        #expect(seeded.wishlistItem.estimatedCostCents == 240_000)
        #expect(try seeded.context.fetch(FetchDescriptor<Item>()).filter { $0.reverbProductID != nil }.count == 3)
        #expect(seeded.items["Telecaster"]?.reverbProductID == 126_161)
        #expect(seeded.items["Squier Classic Vibe"]?.reverbProductID == nil, "the neutral candidate is unmatched")
        #expect(try seeded.context.fetch(FetchDescriptor<MarketMatchSnapshot>()).count == 3)
        #expect(try seeded.context.fetch(FetchDescriptor<MarketHistoryPoint>()).count == 6, "two readings per matched item")

        let figures = try seeded.context.fetch(FetchDescriptor<MarketFigureRecord>())
        #expect(figures.count == 3)
        #expect(figures.allSatisfy { $0.fetchedAt == now }, "the current reading is the one the row carries")
    }

    /// The stored trend is the one two refreshes would have left behind —
    /// equal to `compute` over the same history, and equal to what the seed
    /// set out to produce. Mutation: replace the Telecaster's second `record`
    /// call with a direct `MarketFigureRecord` insert carrying `"flat"`.
    @Test func everyStoredTrendIsTheComputedOneAndTheThreeAreUpFlatDown() throws {
        let seeded = try seed()
        let expected: [String: MarketTrend] = ["Telecaster": .up, "Blues Junior": .flat, "NT1-A": .down]

        for (name, trend) in expected {
            let item = try #require(seeded.items[name])
            let record = try #require(try MarketLocalStore.figure(for: item.id, in: seeded.context), "\(name) has no figure row")
            let history = try MarketLocalStore.historyEntries(for: item.id, in: seeded.context)
            #expect(history.count == 2, "\(name) should carry two readings")
            #expect(record.trendRawValue == MarketTrend.compute(history: history)?.rawValue, "\(name)'s stored trend disagrees with its history")
            #expect(record.trendRawValue == trend.rawValue, "\(name) was seeded as \(trend.rawValue)")
        }

        let squier = try #require(seeded.items["Squier Classic Vibe"])
        #expect(try MarketLocalStore.figure(for: squier.id, in: seeded.context) == nil, "the unmatched candidate has no market line")
    }

    /// The seed writes market rows only through the writer, so the figure,
    /// the history and the snapshot can't drift out of the shape a refresh
    /// leaves behind.
    @Test func theSeedConstructsNoLocalRowItself() throws {
        let code = try SourceScan.production("Trove/App/UITestSeed.swift")

        #expect(code.contains("MarketLocalStore.record("), "the seed writes no market rows at all")
        for constructor in ["MarketFigureRecord(", "MarketHistoryPoint(", "MarketMatchSnapshot("] {
            #expect(!code.contains(constructor), "the seed builds a \(constructor.dropLast()) directly instead of writing through MarketLocalStore.record")
        }
    }

    // MARK: - G11, the order the UI test reads

    /// The whole point of the values: the trend key disagrees with the value
    /// order at both ends. Mutation: drop the group key from `rank`, and this
    /// becomes Blues Junior, Telecaster, NT1-A, Squier.
    @Test func theSeededPlanRanksTheRisingCandidateFirstAndTheFallingOneLast() throws {
        let seeded = try seed()
        let viewModel = SellPlanViewModel(modelContext: seeded.context, wishlistItemID: seeded.wishlistItem.id, now: { self.now })

        viewModel.load()

        #expect(viewModel.candidates.map(\.name) == ["Telecaster", "Blues Junior", "Squier Classic Vibe", "NT1-A"])
        #expect(
            viewModel.candidates.map(\.currentValueCents) == [60_000, 64_000, 38_000, 40_000],
            "value alone would order these Blues Junior, Telecaster, NT1-A, Squier — the seed proves nothing if it doesn't"
        )

        let telecaster = try #require(seeded.items["Telecaster"])
        let rise = try #require(viewModel.rise(for: telecaster.id))
        #expect(rise.percent == 12)
        #expect(rise.since == now - 14 * day)
        for candidate in viewModel.candidates where candidate.id != telecaster.id {
            #expect(viewModel.rise(for: candidate.id) == nil, "\(candidate.name) draws a reason line it has no rise for")
        }
    }

    // MARK: - 006, the sold seed

    /// The sold seed's own gate, mirrored from the Sell Plan's: its own
    /// argument alone isn't enough against a store on disk, and neither
    /// `-uiTesting` nor the *other* seed's argument fires it. Mutation: gate
    /// on the arguments alone, and the two persistent modes go red; gate on
    /// `argument` instead of `soldArgument`, and the last two go red.
    @Test func theSoldSeedTakesTheInMemoryStoreAndItsOwnArgumentToo() {
        let both = ["-uiTesting", UITestSeed.soldArgument]

        #expect(UITestSeed.shouldSeedSold(mode: .ephemeral, arguments: both))

        #expect(
            !UITestSeed.shouldSeedSold(mode: .ephemeral, arguments: []),
            "an in-memory store with no arguments at all still needs the seed's own flag"
        )
        #expect(
            !UITestSeed.shouldSeedSold(mode: .ephemeral, arguments: ["-uiTesting"]),
            "-uiTesting alone must keep starting from an empty collection"
        )
        #expect(
            !UITestSeed.shouldSeedSold(mode: .cloudKit, arguments: both),
            "a synced store would be seeded with test data"
        )
        #expect(
            !UITestSeed.shouldSeedSold(mode: .localOnly, arguments: both),
            "an on-disk store would be seeded with test data"
        )

        // The two seeds are deaf to each other's flag, which is what lets
        // `testTheSeededSellPlanRanksRisingFirstAndSaysWhy` keep the
        // collection it was written against (plan Q10).
        #expect(
            !UITestSeed.shouldSeedSold(mode: .ephemeral, arguments: ["-uiTesting", UITestSeed.argument]),
            "the Sell Plan's argument must not also seed the sold collection"
        )
        #expect(
            !UITestSeed.shouldSeed(mode: .ephemeral, arguments: both),
            "the sold argument must not also seed the Sell Plan"
        )
    }

    /// The app calls the sold seed once, under its *own* guard, and still
    /// names neither argument itself. Mutations: a second call outside the
    /// block; folding it under `shouldSeed`'s guard; spelling `-seedSold` in
    /// `TroveApp`.
    @Test func theAppCallsTheSoldSeedOnceUnderItsOwnGuard() throws {
        let code = try SourceScan.production("Trove/App/TroveApp.swift")

        #expect(code.ranges(of: "UITestSeed.sold(").count == 1, "the sold seed is called more than once, or not at all")

        let guarded = SourceScan.closureBodies(after: "if UITestSeed.shouldSeedSold(mode: store.mode", in: code)
        try #require(guarded.count == 1, "TroveApp should gate the sold seed on shouldSeedSold(mode: store.mode …) exactly once")
        #expect(guarded[0].contains("UITestSeed.sold("), "the sold seed's call sits outside its guard")

        let literals = SourceScan.stringLiterals(in: code)
        #expect(
            !literals.contains(UITestSeed.soldArgument),
            "the sold seed's argument is spelled in TroveApp — it lives in UITestSeed.soldArgument alone"
        )
    }

    /// What the sold seed actually leaves in the store, read back on a second
    /// context: two sales, the third item still owned, the Telecaster's sale
    /// pointing at the plan and the Blues Junior's at nothing.
    ///
    /// The figures the UI test reads off the screen are taken from
    /// `SaleOutcome.totals` — the same sum the card and the Sold side's
    /// summary read — rather than hand-written a third time here, so a seed
    /// whose numbers drifted would move this line and the screen's together.
    @Test func theSoldSeedLeavesTwoSalesWorthEighteenHundredAndTwoHundredAhead() throws {
        let seeded = try seedSold()

        #expect(seeded.items.count == 3)
        let sold = seeded.items.values.filter(\.isSold).sorted(by: ItemListViewModel.areInSoldOrder)
        #expect(sold.map(\.name) == ["Telecaster", "Blues Junior"], "the Sold side's order is most recent first")
        #expect(seeded.items["Leica M6"]?.sale == nil, "the owned item must not be sold")

        let totals = SaleOutcome.totals(over: Array(seeded.items.values))
        #expect(totals == SaleTotals(count: 2, proceedsCents: 180_000, realisedDeltaCents: 20_000))
        #expect(
            SaleCopy.soldSideSummary(totals) == "2 sold \u{00B7} $1,800 \u{00B7} +$200 vs paid",
            "the summary line the UI test reads is this seed's own arithmetic"
        )

        // The two outcomes the rows say out loud, each the seed's own
        // subtraction rather than a figure written twice.
        #expect(seeded.items["Telecaster"]?.saleOutcome?.deltaCents == 35_000)
        #expect(seeded.items["Blues Junior"]?.saleOutcome?.deltaCents == -15_000)
        #expect(SaleCopy.rowOutcome(deltaCents: 35_000) == "Gain $350 vs paid")
        #expect(SaleCopy.rowOutcome(deltaCents: -15_000) == "Loss $150 vs paid")

        // Sold toward the plan, and sold toward nothing — the Sell Plan's
        // Sold figure is one sale, not two (plan §8).
        #expect(seeded.items["Telecaster"]?.soldTowardWishlistItem?.id == seeded.wishlistItem.id)
        #expect(seeded.items["Blues Junior"]?.soldTowardWishlistItem == nil)
        #expect(seeded.wishlistItem.itemsSoldToward?.count == 1)
    }

    // MARK: - 009, the carry-over at a seeded launch

    /// An in-memory launch now runs the sell plan's carry-over the moment its
    /// monitor is built, after the seeds. Every row the existing seeds write
    /// goes through `WishlistItem.init`, which stamps it checked, so the
    /// carry-over must find nothing to do — the starting states every earlier
    /// UI test was written against stay as they were. The sold seed's wanted
    /// item has a sold-toward history, so an unchecked one would be carried.
    @Test func theExistingSeedsLeaveTheCarryOverNothingToDo() throws {
        let store = try TroveStore.make(isUITesting: true)
        try #require(store.mode == .ephemeral)

        let seeding = ModelContext(store.container)
        try UITestSeed.sellPlan(into: seeding, now: now)
        try UITestSeed.sold(into: seeding, now: now)

        let context = ModelContext(store.container)
        let wanted = try context.fetch(FetchDescriptor<WishlistItem>())
        try #require(wanted.count == 2)
        try #require(wanted.contains { !($0.itemsSoldToward ?? []).isEmpty }, "a row the carry-over would take if it were unchecked")

        #expect(try SellPlanStore.carryOver(in: context, at: now) == 0)
    }

    // MARK: - 009, the Plans seed (G9)

    /// The Plans seed's own gate, mirrored from the other two: its argument
    /// alone isn't enough against a store on disk, and neither `-uiTesting`
    /// nor either other seed's argument fires it. Mutation: gate on the
    /// arguments alone, and the two persistent modes go red.
    @Test func thePlansSeedTakesTheInMemoryStoreAndItsOwnArgument() {
        let every = ["-uiTesting", UITestSeed.argument, UITestSeed.soldArgument, UITestSeed.plansArgument]

        #expect(UITestSeed.shouldSeedPlans(mode: .ephemeral, arguments: ["-uiTesting", UITestSeed.plansArgument]))

        #expect(
            !UITestSeed.shouldSeedPlans(mode: .cloudKit, arguments: every),
            "a synced store would be seeded with test data"
        )
        #expect(
            !UITestSeed.shouldSeedPlans(mode: .localOnly, arguments: every),
            "an on-disk store would be seeded with test data"
        )
        #expect(
            !UITestSeed.shouldSeedPlans(mode: .ephemeral, arguments: ["-uiTesting"]),
            "-uiTesting alone must keep starting from an empty collection"
        )
        #expect(
            !UITestSeed.shouldSeedPlans(mode: .ephemeral, arguments: ["-uiTesting", UITestSeed.argument, UITestSeed.soldArgument]),
            "the other seeds' arguments must not also seed the Plans collection"
        )
        #expect(
            !UITestSeed.shouldSeed(mode: .ephemeral, arguments: ["-uiTesting", UITestSeed.plansArgument]),
            "the Plans argument must not also seed the Sell Plan collection"
        )
        #expect(
            !UITestSeed.shouldSeedSold(mode: .ephemeral, arguments: ["-uiTesting", UITestSeed.plansArgument]),
            "the Plans argument must not also seed the sold collection"
        )
    }

    /// What the Plans seed leaves in the store, read back on a second
    /// context: the six wanted items in the shapes plan §13 names, and the
    /// Fuji row the one left unchecked. Mutation: drop any row, or the Fuji
    /// row's cleared stamp, and this goes red.
    @Test func thePlansSeedWritesSixWantedItemsInTheirShapes() throws {
        let context = try seedPlans()
        let wanted = try context.fetch(FetchDescriptor<WishlistItem>())
        let byName = Dictionary(uniqueKeysWithValues: wanted.map { ($0.name, $0) })
        try #require(
            Set(byName.keys) == ["Summicron 35mm f/2", "Vox AC15", "Hasselblad 80mm", "Rode NT5", "Nikon FM2", "Fuji X100V"],
            "the seed's wanted items are \(byName.keys.sorted())"
        )
        let summicron = try #require(byName["Summicron 35mm f/2"])
        let vox = try #require(byName["Vox AC15"])
        let hasselblad = try #require(byName["Hasselblad 80mm"])
        let rode = try #require(byName["Rode NT5"])
        let nikon = try #require(byName["Nikon FM2"])
        let fuji = try #require(byName["Fuji X100V"])

        // Summicron: planned three days back, the Telecaster set aside.
        #expect(summicron.sellPlanCreatedAt == now - 3 * day)
        #expect((summicron.plannedSaleItems ?? []).map(\.name) == ["Telecaster"])
        #expect(!summicron.isBought)

        // Vox: planned two days back, its one candidate sold toward it for
        // more than the estimate — so the selection is empty and it is
        // covered.
        #expect(vox.sellPlanCreatedAt == now - 2 * day)
        #expect((vox.plannedSaleItems ?? []).isEmpty, "the sale must have emptied the Vox's selection")
        #expect((vox.itemsSoldToward ?? []).map(\.name) == ["Blues Junior"])
        #expect(vox.itemsSoldToward?.first?.sale?.priceCents == 110_000)
        #expect(SellPlanSummary.isCovered(soldCents: 110_000, estimatedCostCents: vox.estimatedCostCents))

        // Hasselblad: planned, sold toward, bought — and not covered.
        #expect(hasselblad.sellPlanCreatedAt == now - 5 * day)
        #expect(hasselblad.boughtDate == now - 1 * day)
        #expect((hasselblad.itemsSoldToward ?? []).map(\.name) == ["NT1-A"])
        #expect(!SellPlanSummary.isCovered(soldCents: 30_000, estimatedCostCents: hasselblad.estimatedCostCents))

        // Rode and Nikon: no plan, one wanted and one bought.
        #expect(!rode.hasSellPlan && !rode.isBought)
        #expect(!nikon.hasSellPlan && nikon.isBought)

        // Fuji: the legacy shape — a selection, no plan, never checked.
        #expect(fuji.sellPlanCheckedAt == nil, "the Fuji row must be the one no 009 writer checked")
        #expect(!fuji.hasSellPlan)
        #expect(fuji.awaitsCarryOver)
        #expect(
            wanted.filter { $0.sellPlanCheckedAt == nil }.map(\.name) == ["Fuji X100V"],
            "every other row went through a writer, which checks it"
        )

        // What is owned: the Telecaster at $600 and desire 2, the Leica at
        // desire 5, and the two purchases.
        let owned = try context.fetch(FetchDescriptor<Item>()).filter { !$0.isSold }
        #expect(Set(owned.map(\.name)) == ["Telecaster", "Leica M6", "Hasselblad 80mm", "Nikon FM2"])
        // 009 Amendment A (G29): the Hasselblad's purchase records the item it
        // became, so its completed row has a picture source.
        let hasselbladItem = try #require(owned.first { $0.name == "Hasselblad 80mm" })
        #expect(hasselblad.boughtItem?.id == hasselbladItem.id, "the seeded purchase records the seeded Hasselblad 80mm item")
        let telecaster = try #require(owned.first { $0.name == "Telecaster" })
        #expect(telecaster.currentValueCents == 60_000)
        #expect(telecaster.desireToKeep == 2)
        #expect(owned.first { $0.name == "Leica M6" }?.desireToKeep == 5)
    }

    /// One carry-over over the seed — what the launch runs — leaves three
    /// plans Active, one Completed and two wanted items on neither side,
    /// read back on a third context after the save. Mutations: the gate
    /// reading the flag alone is the test above's; a seed row missing, or
    /// the Fuji row left checked, moves these counts.
    @Test func oneCarryOverOverThePlansSeedLeavesThreeActiveOneCompletedTwoPlanless() throws {
        let store = try TroveStore.make(isUITesting: true)
        try #require(store.mode == .ephemeral)
        try UITestSeed.plans(into: ModelContext(store.container), now: now)

        let carrying = ModelContext(store.container)
        #expect(try SellPlanStore.carryOver(in: carrying, at: now) == 1, "the Fuji row is the one the carry-over plans")
        try carrying.save()

        let wanted = try ModelContext(store.container).fetch(FetchDescriptor<WishlistItem>())
        let active = wanted.filter { $0.hasSellPlan && !$0.isBought }.map(\.name).sorted()
        let completed = wanted.filter { $0.hasSellPlan && $0.isBought }.map(\.name)
        let planless = wanted.filter { !$0.hasSellPlan }.map(\.name).sorted()
        #expect(active == ["Fuji X100V", "Summicron 35mm f/2", "Vox AC15"])
        #expect(completed == ["Hasselblad 80mm"])
        #expect(planless == ["Nikon FM2", "Rode NT5"])
        #expect(wanted.first { $0.name == "Fuji X100V" }?.sellPlanCreatedAt == now, "the carried plan is dated at the carry-over")
    }

    // MARK: - Private

    /// The Plans seed through the container the app builds for a UI test
    /// launch, handed back as a *second* context for the reason `seed()`
    /// gives.
    private func seedPlans() throws -> ModelContext {
        let store = try TroveStore.make(isUITesting: true)
        try #require(store.mode == .ephemeral)
        try UITestSeed.plans(into: ModelContext(store.container), now: now)
        return ModelContext(store.container)
    }

    /// The seed run into a context over the container the app itself builds
    /// for a UI test launch — `TroveStore.make`, not a hand-rolled pair.
    private func seed() throws -> Seeded {
        let store = try TroveStore.make(isUITesting: true)
        try #require(store.mode == .ephemeral)

        try UITestSeed.sellPlan(into: ModelContext(store.container), now: now)

        // Read back through a *second* context over the same store, per
        // `makeInMemoryContainer`'s note: a same-context refetch hands back
        // objects carrying unsaved changes, so every assertion below would
        // hold with the seed's `save()` deleted. This one sees only what
        // actually reached the store.
        let context = ModelContext(store.container)
        let items = try context.fetch(FetchDescriptor<Item>())
        let wishlistItem = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)
        return Seeded(
            context: context,
            items: Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) }),
            wishlistItem: wishlistItem
        )
    }

    /// The sold seed, through the same container the app builds for a UI test
    /// launch, read back on a second context for the reason `seed()` gives:
    /// a same-context refetch would hold the assertions up even with the
    /// seed's `save()` deleted.
    private func seedSold() throws -> Seeded {
        let store = try TroveStore.make(isUITesting: true)
        try #require(store.mode == .ephemeral)

        try UITestSeed.sold(into: ModelContext(store.container), now: now)

        let context = ModelContext(store.container)
        let items = try context.fetch(FetchDescriptor<Item>())
        let wishlistItem = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)
        return Seeded(
            context: context,
            items: Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) }),
            wishlistItem: wishlistItem
        )
    }
}

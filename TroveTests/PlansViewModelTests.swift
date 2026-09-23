import Foundation
import SwiftData
import Testing
@testable import Trove

/// G10–G12 (plan §5, Q9, Q10): the Plans tab's view model — which entries sit
/// on which side, the seven sorts and their tie-break, each side keeping its
/// own sort, and the four empty reasons with `stillSyncing` first. G13, the
/// fourth purchase host, lives beside the other three in
/// `WishlistPurchaseHostTests`.
///
/// Every date here is distinct from every other a broken implementation could
/// read instead: plan dates never coincide with bought dates or the view
/// model's clock. `createdAt` is the real clock at insert, which the pinned
/// dates cannot equal — so each sort fixture inserts its rows in an order that
/// matches none of the orders it checks, and a sort reading `createdAt` goes
/// red rather than landing on the expected order by insertion.
@Suite("PlansViewModel")
struct PlansViewModelTests {
    private let base = Date(timeIntervalSince1970: 1_750_000_000)
    private let now = Date(timeIntervalSince1970: 1_760_000_000)

    private func day(_ n: Int) -> Date { base.addingTimeInterval(Double(n) * 86_400) }

    // MARK: - Fixtures

    /// A wanted entry at a wishlist position, with a plan created on
    /// `planned` when one is given.
    @discardableResult
    private func wanted(
        _ name: String,
        position: Int = 0,
        planned: Date? = nil,
        estimateCents: Int = 240_000,
        into context: ModelContext
    ) -> WishlistItem {
        let entry = WishlistItem(
            name: name,
            categoryPath: "Photography/Lenses",
            estimatedCostCents: estimateCents,
            sortOrder: position
        )
        context.insert(entry)
        if let planned { SellPlanStore.create(for: entry, at: planned) }
        return entry
    }

    private func owned(_ name: String, into context: ModelContext) -> Item {
        let item = Item(
            name: name,
            categoryPath: "Music/Guitars",
            purchasePriceCents: 100_000,
            currentValueCents: 120_000,
            desireToKeep: 1
        )
        context.insert(item)
        return item
    }

    private func sell(_ item: Item, toward plan: WishlistItem, in context: ModelContext) throws {
        try ItemSaleStore.markSold(
            item,
            sale: Sale(date: day(20), priceCents: 90_000, location: "Reverb", note: nil),
            toward: plan,
            at: day(20),
            in: context
        )
    }

    @discardableResult
    private func buy(_ entry: WishlistItem, on date: Date, in context: ModelContext) throws -> Item {
        try WishlistPurchaseStore.markBought(
            entry,
            purchase: Purchase(date: date, priceCents: 219_500, location: "Kerrisdale Cameras", condition: .good),
            at: date,
            in: context
        )
    }

    // MARK: - G10 membership

    /// Criterion 2: a plan stays on Active whatever happens to its selection,
    /// including every item on it being sold — the case that read as no plan
    /// at all before this spec.
    ///
    /// Mutation: read `active` from the selection → red.
    @Test func aPlanWhoseEveryItemWasSoldStaysActive() throws {
        let context = try makeInMemoryContext()
        let plan = wanted("Summicron 35mm f/2", planned: day(1), into: context)
        let first = owned("Nikon F3", into: context)
        let second = owned("Fender Deluxe", into: context)
        plan.plannedSaleItems = [first, second]
        try sell(first, toward: plan, in: context)
        try sell(second, toward: plan, in: context)
        try context.save()
        #expect((plan.plannedSaleItems ?? []).isEmpty, "the fixture must leave nothing selected")

        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.load()

        #expect(viewModel.activeRows.map(\.id) == [plan.id])
        #expect(viewModel.completedRows.isEmpty)
    }

    /// Criterion 3: buying the wanted item moves its plan to Completed.
    @Test func buyingMovesAPlanToCompleted() throws {
        let context = try makeInMemoryContext()
        let plan = wanted("Summicron 35mm f/2", planned: day(1), into: context)
        try context.save()

        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.load()
        #expect(viewModel.activeRows.map(\.id) == [plan.id])

        try buy(plan, on: day(5), in: context)
        try context.save()
        viewModel.load()

        #expect(viewModel.activeRows.isEmpty)
        #expect(viewModel.completedRows.map(\.id) == [plan.id])
        #expect(viewModel.completedRows.first?.isCompleted == true)
    }

    /// Criterion 3's second half: an entry with no plan is on neither side,
    /// wanted or bought.
    ///
    /// Mutation: completed read as `isBought` alone → red.
    @Test func anEntryWithNoPlanIsOnNeitherSide() throws {
        let context = try makeInMemoryContext()
        wanted("Vox AC15 Custom", into: context)
        let bought = wanted("Summicron 35mm f/2", into: context)
        try buy(bought, on: day(5), in: context)
        try context.save()

        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.load()

        #expect(viewModel.activeRows.isEmpty)
        #expect(viewModel.completedRows.isEmpty)
    }

    /// Criterion 13, P4: an orphan — a bought entry with a plan whose created
    /// item has since been deleted — is on Completed, and deleting its plan
    /// takes it off while the entry stays in the store.
    @Test func anOrphanIsOnCompletedAndDeletingItsPlanTakesItOff() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let plan = wanted("Summicron 35mm f/2", planned: day(1), into: context)
        let item = try buy(plan, on: day(5), in: context)
        try context.save()
        context.delete(item)
        try context.save()

        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.show(.completed)
        #expect(viewModel.completedRows.map(\.id) == [plan.id], "the orphan is visible")

        #expect(viewModel.deletePlan(id: plan.id))
        #expect(viewModel.completedRows.isEmpty)
        #expect(viewModel.emptyReason == .nothingCompleted)

        let elsewhere = ModelContext(container)
        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first, "the entry stays")
        #expect(entry.sellPlanCreatedAt == nil, "the plan reached the store as deleted")
        #expect(entry.boughtDate == day(5), "the purchase marker is untouched")
    }

    /// Decision 9: deleting an active plan leaves the entry wanted and the
    /// sold-toward record standing.
    @Test func deletingAnActivePlanLeavesTheEntryAndItsSales() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let plan = wanted("Summicron 35mm f/2", planned: day(1), into: context)
        let sold = owned("Nikon F3", into: context)
        try sell(sold, toward: plan, in: context)
        try context.save()

        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.load()
        #expect(viewModel.deletePlan(id: plan.id))
        #expect(viewModel.activeRows.isEmpty)
        #expect(viewModel.deletePlan(id: UUID()) == false, "an id with no row deletes nothing")

        let elsewhere = ModelContext(container)
        let entry = try #require(try elsewhere.fetch(FetchDescriptor<WishlistItem>()).first)
        #expect(entry.sellPlanCreatedAt == nil)
        #expect(entry.boughtDate == nil, "still on the wishlist")
        #expect((entry.itemsSoldToward ?? []).map(\.name) == ["Nikon F3"], "what sold toward it stays on the record")
    }

    /// Criterion 7, Decision 11, R2: an active row shows its thumbnail, a
    /// completed row has no picture slot.
    ///
    /// Mutation: `showsThumbnail` true throughout → red.
    @Test func showsThumbnailIsTrueOnActiveRowsAndFalseOnCompletedOnes() throws {
        let context = try makeInMemoryContext()
        wanted("Summicron 35mm f/2", planned: day(1), into: context)
        wanted("Vox AC15 Custom", planned: day(2), into: context)
        let bought = wanted("Fender Deluxe", planned: day(3), into: context)
        try buy(bought, on: day(5), in: context)
        try context.save()

        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.load()

        #expect(viewModel.activeRows.count == 2)
        #expect(viewModel.activeRows.allSatisfy { $0.showsThumbnail })
        #expect(viewModel.completedRows.count == 1)
        #expect(viewModel.completedRows.allSatisfy { !$0.showsThumbnail })
    }

    /// Criterion 7: each row's lines are `SellPlanSummary.rowLines` for its
    /// entry, with no line for a zero count on either side. The active
    /// fixture has sales but nothing set aside, and the completed one nothing
    /// sold toward it, so a zero count drawn would show.
    ///
    /// The Phase 1 review's leg: a completed row's lines begin with its
    /// `Bought …` line — a caller passing a nil bought date to `rowLines`
    /// would draw the active side's lines on a completed row.
    ///
    /// Mutation: pass `nil` for the bought date → red.
    @Test func eachRowsLinesAreItsSummarysRowLines() throws {
        let context = try makeInMemoryContext()
        let active = wanted("Summicron 35mm f/2", planned: day(1), into: context)
        let sold = owned("Nikon F3", into: context)
        try sell(sold, toward: active, in: context)
        let completed = wanted("Vox AC15 Custom", planned: day(2), into: context)
        completed.plannedSaleItems = [owned("Fender Deluxe", into: context)]
        try buy(completed, on: day(5), in: context)
        try context.save()

        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.load()

        let activeRow = try #require(viewModel.activeRows.first)
        #expect(activeRow.lines == SellPlanSummary(active).rowLines(boughtDate: nil))
        #expect(activeRow.lines == [SellPlanCopy.soldToward(1)], "one sale, nothing set aside, not covered")

        let completedRow = try #require(viewModel.completedRows.first)
        #expect(completedRow.lines == SellPlanSummary(completed).rowLines(boughtDate: day(5)))
        #expect(completedRow.lines.first == SellPlanCopy.bought(on: day(5)), "a completed row leads with its bought date")

        let zeroLines = [SellPlanCopy.setAside(0), SellPlanCopy.soldToward(0), SellPlanCopy.soldTowardPast(0)]
        for line in activeRow.lines + completedRow.lines {
            #expect(!zeroLines.contains(line), "no line for a zero count: \(line)")
        }
    }

    // MARK: - G11 sorts

    /// Plan §5's Active fixture, chosen so every order differs from the others.
    /// Inserted Alpha, Charlie, Bravo — an order none of the four sorts
    /// produces — so `createdAt` read in place of the plan date goes red.
    private func activeFixture(into context: ModelContext) throws {
        wanted("Alpha", position: 2, planned: day(2), into: context)
        wanted("Charlie", position: 1, planned: day(3), into: context)
        wanted("Bravo", position: 0, planned: day(1), into: context)
        try context.save()
    }

    /// Plan §5's Completed fixture: bought dates and plan dates in different
    /// orders, so sorting by the plan date reads E, F, D and goes red. The
    /// wishlist positions read D, F, E — none of the side's three orders — so
    /// an order that abstained and left the tie-break to decide goes red too.
    private func completedFixture(into context: ModelContext) throws {
        let delta = wanted("Delta", position: 0, planned: day(1), into: context)
        let echo = wanted("Echo", position: 2, planned: day(3), into: context)
        let foxtrot = wanted("Foxtrot", position: 1, planned: day(2), into: context)
        try buy(delta, on: day(5), in: context)
        try buy(echo, on: day(4), in: context)
        try buy(foxtrot, on: day(6), in: context)
        try context.save()
    }

    /// Criterion 6: the Active side's four orders.
    ///
    /// Mutation: a comparator reversed → red.
    @Test func theActiveSortsOrderTheActiveRows() throws {
        let context = try makeInMemoryContext()
        try activeFixture(into: context)
        let viewModel = PlansViewModel(modelContext: context, now: { self.now })

        let expected: [(PlansViewModel.ActiveSortOrder, [String])] = [
            (.newest, ["Charlie", "Alpha", "Bravo"]),
            (.oldest, ["Bravo", "Alpha", "Charlie"]),
            (.name, ["Alpha", "Bravo", "Charlie"]),
            (.wishlistOrder, ["Bravo", "Charlie", "Alpha"]),
        ]
        for (order, names) in expected {
            viewModel.activeSortOrder = order
            viewModel.load()
            #expect(viewModel.activeRows.map(\.name) == names, "\(order)")
        }
    }

    /// Criterion 6: the Completed side's three orders, Newest and Oldest by
    /// the date bought.
    ///
    /// Mutations: the bought date read as the plan date → red; one shared sort
    /// for both sides → red.
    @Test func theCompletedSortsReadTheDateBought() throws {
        let context = try makeInMemoryContext()
        try completedFixture(into: context)
        let viewModel = PlansViewModel(modelContext: context, now: { self.now })

        let expected: [(PlansViewModel.CompletedSortOrder, [String])] = [
            (.newest, ["Foxtrot", "Delta", "Echo"]),
            (.oldest, ["Echo", "Delta", "Foxtrot"]),
            (.name, ["Delta", "Echo", "Foxtrot"]),
        ]
        for (order, names) in expected {
            viewModel.completedSortOrder = order
            viewModel.load()
            #expect(viewModel.completedRows.map(\.name) == names, "\(order)")
        }
    }

    /// Q9: two plans sharing a date — R3's carried-over plans above all — fall
    /// the wishlist-order way, not the name way, asked of the static
    /// comparator in both argument orders.
    ///
    /// Mutation: the tie broken by name → red.
    @Test func aTieFallsTheWishlistOrderWayNotTheNameWay() throws {
        let context = try makeInMemoryContext()
        // Name order puts Alpha first; wishlist order puts Zulu first.
        let zulu = wanted("Zulu", position: 0, planned: day(1), into: context)
        let alpha = wanted("Alpha", position: 1, planned: day(1), into: context)
        try context.save()

        for order in [PlansViewModel.ActiveSortOrder.newest, .oldest] {
            #expect(PlansViewModel.areInActiveOrder(zulu, alpha, under: order), "\(order)")
            #expect(PlansViewModel.areInActiveOrder(alpha, zulu, under: order) == false, "\(order)")
        }

        try buy(zulu, on: day(5), in: context)
        try buy(alpha, on: day(5), in: context)
        try context.save()
        for order in [PlansViewModel.CompletedSortOrder.newest, .oldest] {
            #expect(PlansViewModel.areInCompletedOrder(zulu, alpha, under: order), "\(order)")
            #expect(PlansViewModel.areInCompletedOrder(alpha, zulu, under: order) == false, "\(order)")
        }
    }

    /// Criterion 5: each side keeps its own sort across visits, and the rows
    /// follow the side on screen's.
    ///
    /// Mutation: one shared sort for both sides → red.
    @Test func eachSideKeepsItsOwnSortAcrossShow() throws {
        let context = try makeInMemoryContext()
        try activeFixture(into: context)
        try completedFixture(into: context)
        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.load()

        viewModel.activeSortOrder = .name
        viewModel.show(.completed)
        viewModel.completedSortOrder = .oldest
        viewModel.show(.active)

        #expect(viewModel.activeSortOrder == .name)
        #expect(viewModel.visibleSortLabel == "Name")
        #expect(viewModel.rows.map(\.name) == ["Alpha", "Bravo", "Charlie"])

        viewModel.show(.completed)
        #expect(viewModel.completedSortOrder == .oldest)
        #expect(viewModel.visibleSortLabel == "Oldest")
        #expect(viewModel.rows.map(\.name) == ["Echo", "Delta", "Foxtrot"])
    }

    /// Criteria 5, 6: a fresh view model opens on Active with both sorts at
    /// Newest.
    @Test func aFreshViewModelOpensOnActiveWithBothSortsNewest() throws {
        let context = try makeInMemoryContext()
        let viewModel = PlansViewModel(modelContext: context, now: { self.now })

        #expect(viewModel.side == .active)
        #expect(viewModel.activeSortOrder == .newest)
        #expect(viewModel.completedSortOrder == .newest)
        #expect(viewModel.visibleSortLabel == "Newest")
    }

    // MARK: - G12 empty reasons

    /// An empty wishlist: nothing wanted on Active, nothing completed on
    /// Completed.
    @Test func anEmptyWishlistReadsNothingWantedAndNothingCompleted() throws {
        let context = try makeInMemoryContext()
        let viewModel = PlansViewModel(modelContext: context, now: { self.now })

        viewModel.load()
        #expect(viewModel.emptyReason == .nothingWanted)
        viewModel.show(.completed)
        #expect(viewModel.emptyReason == .nothingCompleted)
    }

    /// Wanted entries with no plan: "No sell plans yet", not "Nothing on your
    /// wishlist" — and a bought entry is not wanted, so everything bought
    /// reads nothing wanted again.
    ///
    /// Mutation: `nothingWanted` for a planless wishlist → red.
    @Test func aPlanlessWishlistReadsNoPlans() throws {
        let context = try makeInMemoryContext()
        let entry = wanted("Vox AC15 Custom", into: context)
        try context.save()

        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.load()
        #expect(viewModel.emptyReason == .noPlans)

        try buy(entry, on: day(5), in: context)
        try context.save()
        viewModel.load()
        #expect(viewModel.emptyReason == .nothingWanted, "a bought entry is not something wanted")
    }

    /// A side with rows has no empty reason; the other side still has its own.
    @Test func aSideWithRowsHasNoEmptyReason() throws {
        let context = try makeInMemoryContext()
        wanted("Summicron 35mm f/2", planned: day(1), into: context)
        try context.save()

        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.load()
        #expect(viewModel.emptyReason == nil)
        viewModel.show(.completed)
        #expect(viewModel.emptyReason == .nothingCompleted)
    }

    /// Criterion 16, Q10: while the monitor may still be importing,
    /// `stillSyncing` outranks every other reason on both sides.
    ///
    /// Mutation: `stillSyncing` below `noPlans` → red.
    @Test func stillSyncingOutranksEveryOtherReasonWhileImporting() throws {
        let context = try makeInMemoryContext()
        let importing = SyncMonitor(mode: .cloudKit)
        #expect(importing.mayStillBeImporting, "the fixture monitor must be importing")

        let viewModel = PlansViewModel(modelContext: context, syncMonitor: importing, now: { self.now })
        viewModel.load()
        #expect(viewModel.emptyReason == .stillSyncing, "not nothingWanted")

        wanted("Vox AC15 Custom", into: context)
        try context.save()
        viewModel.load()
        #expect(viewModel.emptyReason == .stillSyncing, "not noPlans")

        viewModel.show(.completed)
        #expect(viewModel.emptyReason == .stillSyncing, "not nothingCompleted")
    }

    /// Criterion 16, Q10, R7: a not-importing monitor over a store holding one
    /// entry the carry-over has yet to reach still reads `stillSyncing` — an
    /// offline signed-in device has plans still to carry, and "No sell plans
    /// yet" would be the wrong diagnosis.
    ///
    /// Mutation: the awaiting check dropped → red.
    @Test func anEntryAwaitingTheCarryOverReadsStillSyncingWhenNotImporting() throws {
        let context = try makeInMemoryContext()
        let older = wanted("Summicron 35mm f/2", into: context)
        older.plannedSaleItems = [owned("Nikon F3", into: context)]
        older.sellPlanCheckedAt = nil
        try context.save()
        #expect(older.awaitsCarryOver, "the fixture must await the carry-over")
        #expect(SyncMonitor.notSyncing.mayStillBeImporting == false)

        let viewModel = PlansViewModel(modelContext: context, now: { self.now })
        viewModel.load()

        #expect(viewModel.activeRows.isEmpty, "it is not a plan yet")
        #expect(viewModel.emptyReason == .stillSyncing, "not noPlans")
    }

    /// Q3: the two counts the screen reloads on come straight from the
    /// monitor, and follow it as it moves.
    ///
    /// Mutation: either pass-through hardcoded to 0 → red.
    @Test func settledCountAndCompletedImportsFollowTheMonitor() throws {
        let context = try makeInMemoryContext()
        let monitor = SyncMonitor(mode: .cloudKit)
        let viewModel = PlansViewModel(modelContext: context, syncMonitor: monitor, now: { self.now })
        #expect(viewModel.settledCount == 0)
        #expect(viewModel.completedImports == 0)

        monitor.record(SyncEvent(kind: .importChanges, isFinished: false, succeeded: false))
        monitor.record(SyncEvent(kind: .importChanges, isFinished: true, succeeded: true))

        #expect(viewModel.settledCount == 1, "a successful import settles")
        #expect(viewModel.completedImports == 1, "and moves the import count")
    }
}

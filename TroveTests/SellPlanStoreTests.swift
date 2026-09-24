import Foundation
import SwiftData
import Testing
@testable import Trove

/// 009/T003. The one writer of plan state (plan Q4, §4). Each rule is
/// measured separately because each fails differently: a rewritten date moves
/// a plan's "created" instant every time the button is pressed again, a plan
/// on a bought entry makes a completed plan nobody asked for, a delete that
/// reaches past the plan unsells or reprices gear (criterion 10) or erases
/// the sold-toward record (criterion 12), and a carry-over that re-reads a
/// checked row brings back a plan the person deleted.
///
/// `SellPlanStore` doesn't save — callers do, the `ItemSaleStore` shape,
/// except `runCarryOver` — so every persistence assertion here saves and
/// refetches on a **second** `ModelContext`: a same-context refetch hands
/// back objects carrying unsaved changes and would pass whether or not the
/// save happened (`makeInMemoryContainer`'s doc).
///
/// Every pinned instant is in the past and distinct from any row's
/// `createdAt` (which `init` stamps with the real `.now`), so a store that
/// wrote the row's own creation date instead of `now` is caught.
@Suite("Sell plan store")
struct SellPlanStoreTests {
    private let earlier = Date(timeIntervalSince1970: 1_760_000_000)
    private let soldOn = Date(timeIntervalSince1970: 1_770_000_000)
    private let now = Date(timeIntervalSince1970: 1_780_000_000)
    private let later = Date(timeIntervalSince1970: 1_790_000_000)

    private func sale(_ priceCents: Int) -> Sale {
        Sale(date: soldOn, priceCents: priceCents, location: "Reverb", note: nil)
    }

    private func wanted(named name: String, in context: ModelContext) throws -> WishlistItem {
        try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first { $0.name == name })
    }

    // MARK: - G5: create

    /// G5 (spec: "created when selecting Create a sell plan"). The plan is
    /// dated the instant passed, not the entry's own creation, and the row is
    /// settled at the same time.
    @Test func createDatesThePlanNowAndStampsTheRowChecked() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let entry = WishlistItem(name: "Rickenbacker 330")
        context.insert(entry)
        entry.sellPlanCheckedAt = nil
        try context.save()

        #expect(SellPlanStore.create(for: entry, at: now))
        try context.save()

        let stored = try wanted(named: "Rickenbacker 330", in: ModelContext(container))
        #expect(stored.sellPlanCreatedAt == now)
        #expect(now != stored.createdAt, "fixture: now must differ from the entry's createdAt")
        #expect(stored.sellPlanCheckedAt == now, "a plan-state write settles the row")
    }

    /// G5. Pressing Create again on an existing plan answers true and keeps
    /// the date the plan was first made.
    @Test func aSecondCreateKeepsTheFirstDate() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let entry = WishlistItem(name: "Rickenbacker 330")
        context.insert(entry)
        SellPlanStore.create(for: entry, at: earlier)
        try context.save()
        let checkedBefore = try #require(try wanted(named: "Rickenbacker 330", in: ModelContext(container)).sellPlanCheckedAt)

        #expect(SellPlanStore.create(for: entry, at: now), "an existing plan is still a plan")
        try context.save()

        let stored = try wanted(named: "Rickenbacker 330", in: ModelContext(container))
        #expect(stored.sellPlanCreatedAt == earlier, "a second create must not rewrite the date")
        #expect(stored.sellPlanCheckedAt == checkedBefore, "create stamps checked only when nil")
    }

    /// G5. A bought entry has nothing left to fund, so create refuses it and
    /// writes nothing — not the plan date, and not the checked stamp either.
    @Test func aBoughtEntryIsRefusedAndGainsNothing() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let entry = WishlistItem(name: "Rickenbacker 330")
        context.insert(entry)
        entry.boughtDate = soldOn
        entry.sellPlanCheckedAt = nil
        try context.save()

        #expect(!SellPlanStore.create(for: entry, at: now))
        try context.save()

        let stored = try wanted(named: "Rickenbacker 330", in: ModelContext(container))
        #expect(stored.sellPlanCreatedAt == nil, "a bought entry must not gain a plan")
        #expect(stored.sellPlanCheckedAt == nil, "a refused create writes nothing")
    }

    // MARK: - G6: delete

    /// Every sale and value field criterion 10 names, per item, so "changes
    /// no item anywhere" is one equality over the whole store.
    private struct ItemState: Equatable {
        let id: UUID
        let soldDate: Date?
        let salePriceCents: Int?
        let currentValueCents: Int?
        let desireToKeep: Int
    }

    private func itemStates(in context: ModelContext) throws -> [ItemState] {
        try context.fetch(FetchDescriptor<Item>())
            .map { ItemState(id: $0.id, soldDate: $0.soldDate, salePriceCents: $0.salePriceCents,
                             currentValueCents: $0.currentValueCents, desireToKeep: $0.desireToKeep) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func soldTowardIDs(of entry: WishlistItem) -> [UUID] {
        (entry.itemsSoldToward ?? []).map(\.id).sorted { $0.uuidString < $1.uuidString }
    }

    /// Three owned items — one on the plan's selection, one sold toward it,
    /// one on no plan at all — each with a sale price distinct from its
    /// current value and a keep rating off the initializer's default, so a
    /// delete that unsold, repriced or re-rated any of them is visible.
    private func seedPlan(in context: ModelContext) throws -> WishlistItem {
        let selected = Item(name: "Telecaster", purchasePriceCents: 100_000, currentValueCents: 120_000, desireToKeep: 2)
        let sold = Item(name: "Blues Junior", purchasePriceCents: 60_000, currentValueCents: 55_000, desireToKeep: 1)
        let bystander = Item(name: "Jazzmaster", purchasePriceCents: 90_000, currentValueCents: 95_000, desireToKeep: 5)
        let entry = WishlistItem(name: "Rickenbacker 330")
        for model in [selected, sold, bystander] { context.insert(model) }
        context.insert(entry)
        entry.sellPlanCheckedAt = earlier
        SellPlanStore.create(for: entry, at: earlier)
        entry.plannedSaleItems = [sold, selected]
        try ItemSaleStore.markSold(sold, sale: sale(70_000), toward: entry, at: soldOn, in: context)
        try context.save()
        return entry
    }

    /// Criteria 10–12, on a second context: the plan and selection gone, the
    /// entry standing, the sold-toward record the same, every item identical.
    private func expectOnlyThePlanWent(
        container: ModelContainer, itemsBefore: [ItemState], soldTowardBefore: [UUID]
    ) throws {
        let elsewhere = ModelContext(container)
        let entries = try elsewhere.fetch(FetchDescriptor<WishlistItem>())
        #expect(entries.count == 1, "deleting a plan never deletes the entry")
        let stored = try wanted(named: "Rickenbacker 330", in: elsewhere)
        #expect(stored.sellPlanCreatedAt == nil, "the plan is gone")
        #expect(stored.sellPlanCheckedAt == earlier, "delete stamps checked only when nil")
        #expect((stored.plannedSaleItems ?? []).isEmpty, "the current selection is gone")
        #expect(!soldTowardBefore.isEmpty)
        #expect(soldTowardIDs(of: stored) == soldTowardBefore, "the sold-toward record survives the delete")
        #expect(try itemStates(in: elsewhere) == itemsBefore, "no item is created, removed, unsold or repriced")
    }

    /// G6 (criteria 10–12). An active plan: the entry stays on the wishlist
    /// with no plan, and nothing about any item moves.
    @Test func deletingAnActivePlanTakesThePlanAndSelectionAndNothingElse() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let entry = try seedPlan(in: context)
        let before = ModelContext(container)
        let itemsBefore = try itemStates(in: before)
        let soldTowardBefore = soldTowardIDs(of: try wanted(named: "Rickenbacker 330", in: before))
        #expect(itemsBefore.count == 3)

        SellPlanStore.delete(planOf: entry, at: now)
        try context.save()

        try expectOnlyThePlanWent(container: container, itemsBefore: itemsBefore, soldTowardBefore: soldTowardBefore)
    }

    /// G6 (criterion 11). A completed plan: the purchased item stays in the
    /// collection untouched, and the entry stays bought.
    ///
    /// G27 (009 Amendment A, QA1): the delete leaves the purchase's record of
    /// the item it became exactly as it was — the record belongs to the
    /// purchase, not the plan (Decision 9's "only the plan").
    @Test func deletingACompletedPlanLeavesThePurchaseAndTheHistory() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let entry = try seedPlan(in: context)
        try WishlistPurchaseStore.markBought(
            entry, purchase: Purchase(date: soldOn, priceCents: 240_000, location: "Reverb", condition: .good),
            at: soldOn, in: context)
        try context.save()
        let before = ModelContext(container)
        let itemsBefore = try itemStates(in: before)
        let soldTowardBefore = soldTowardIDs(of: try wanted(named: "Rickenbacker 330", in: before))
        #expect(itemsBefore.count == 4, "the three owned items and the purchase")
        let recordBefore = try #require(
            try wanted(named: "Rickenbacker 330", in: before).boughtItem?.id,
            "the fixture: the purchase recorded the item it became"
        )

        SellPlanStore.delete(planOf: entry, at: now)
        try context.save()

        try expectOnlyThePlanWent(container: container, itemsBefore: itemsBefore, soldTowardBefore: soldTowardBefore)
        let stored = try wanted(named: "Rickenbacker 330", in: ModelContext(container))
        #expect(stored.boughtDate == soldOn, "the entry stays bought")
        #expect(stored.boughtItem?.id == recordBefore, "deleting the plan leaves the purchase's record identical")
    }

    /// G6 (Q4's defence, criterion 12's "does not come back"). A delete on a
    /// row the carry-over has not reached yet settles it, so the carry-over
    /// that follows cannot re-plan it from the sold-toward history it keeps.
    @Test func deletingOnAnUncheckedRowLeavesItCheckedSoTheCarryOverMakesNoPlan() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let entry = try seedPlan(in: context)
        entry.sellPlanCheckedAt = nil
        try context.save()

        SellPlanStore.delete(planOf: entry, at: now)
        try context.save()
        let carryContext = ModelContext(container)
        #expect(try SellPlanStore.carryOver(in: carryContext, at: later) == 0)
        try carryContext.save()

        let stored = try wanted(named: "Rickenbacker 330", in: ModelContext(container))
        #expect(stored.sellPlanCheckedAt == now, "the delete stamps the unchecked row")
        #expect(stored.sellPlanCreatedAt == nil, "a deleted plan does not come back")
    }

    // MARK: - G7: carryOver

    /// The six rows plan §4 names, in one store. The first five are older
    /// rows (unchecked); the sixth is a plan the person already deleted —
    /// checked, planless, with a sold-toward history.
    private func seedSixRows(in context: ModelContext) throws {
        let names = ["selection only", "sold-toward only", "bought with sold-toward",
                     "bought with neither", "wanted with neither", "deleted plan"]
        var rows: [String: WishlistItem] = [:]
        for name in names {
            let row = WishlistItem(name: name)
            context.insert(row)
            rows[name] = row
        }
        for (name, row) in rows where name != "deleted plan" { row.sellPlanCheckedAt = nil }
        rows["deleted plan"]?.sellPlanCheckedAt = earlier
        rows["bought with sold-toward"]?.boughtDate = soldOn
        rows["bought with neither"]?.boughtDate = soldOn

        let selected = Item(name: "Telecaster", purchasePriceCents: 100_000)
        context.insert(selected)
        rows["selection only"]?.plannedSaleItems = [selected]
        for name in ["sold-toward only", "bought with sold-toward", "deleted plan"] {
            let sold = Item(name: "Sold toward \(name)", purchasePriceCents: 50_000)
            context.insert(sold)
            try ItemSaleStore.markSold(sold, sale: sale(60_000), toward: rows[name], at: soldOn, in: context)
        }
        try context.save()
    }

    private func carriedOnce() throws -> (container: ModelContainer, made: Int) {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try seedSixRows(in: context)
        let made = try SellPlanStore.carryOver(in: context, at: now)
        try context.save()
        return (container, made)
    }

    /// G7 (criterion 4, P10). A selection, a sold-toward history, and a
    /// bought entry by its sold-toward history alone each become a plan dated
    /// `now` — not the row's own `createdAt`.
    @Test func theCarryOverPlansEachRowWithASelectionOrASoldTowardHistoryDatedNow() throws {
        let (container, made) = try carriedOnce()
        #expect(made == 3)

        let elsewhere = ModelContext(container)
        for name in ["selection only", "sold-toward only", "bought with sold-toward"] {
            let row = try wanted(named: name, in: elsewhere)
            #expect(row.sellPlanCreatedAt == now, "\(name) becomes a plan dated now")
            #expect(now != row.createdAt, "fixture: now must differ from the row's createdAt")
        }
    }

    /// G7. Nothing to carry, nothing made — bought or still wanted.
    @Test func theCarryOverLeavesRowsWithNothingToCarryPlanless() throws {
        let (container, _) = try carriedOnce()

        let elsewhere = ModelContext(container)
        for name in ["bought with neither", "wanted with neither"] {
            #expect(try wanted(named: name, in: elsewhere).sellPlanCreatedAt == nil, "\(name) has nothing to carry")
        }
    }

    /// G7 (criterion 12's "does not come back"). A checked row is never
    /// re-read, whatever history it carries: its plan stays deleted and its
    /// checked stamp stays the one it had.
    @Test func theCarryOverNeverResurrectsADeletedPlan() throws {
        let (container, _) = try carriedOnce()

        let row = try wanted(named: "deleted plan", in: ModelContext(container))
        #expect(!(row.itemsSoldToward ?? []).isEmpty, "the fixture carries a sold-toward history")
        #expect(row.sellPlanCreatedAt == nil, "a deleted plan must not come back")
        #expect(row.sellPlanCheckedAt == earlier, "a checked row is never re-read")
    }

    /// G7 (Q2's "once, per row"). Every unchecked row is stamped, planned or
    /// not, so no row is ever evaluated twice.
    @Test func theCarryOverLeavesAllSixRowsChecked() throws {
        let (container, _) = try carriedOnce()

        let rows = try ModelContext(container).fetch(FetchDescriptor<WishlistItem>())
        #expect(rows.count == 6)
        for row in rows where row.name != "deleted plan" {
            #expect(row.sellPlanCheckedAt == now, "\(row.name) is stamped checked")
        }
    }

    /// G7. A second run finds nothing unchecked: it makes no plan and moves
    /// no date.
    @Test func aSecondCarryOverMakesNoPlanAndChangesNothing() throws {
        let (container, _) = try carriedOnce()
        let first = try ModelContext(container).fetch(FetchDescriptor<WishlistItem>())
        let datesAfterFirst = Dictionary(uniqueKeysWithValues: first.map { ($0.name, [$0.sellPlanCreatedAt, $0.sellPlanCheckedAt]) })

        let context = ModelContext(container)
        #expect(try SellPlanStore.carryOver(in: context, at: later) == 0)
        try context.save()

        let second = try ModelContext(container).fetch(FetchDescriptor<WishlistItem>())
        let datesAfterSecond = Dictionary(uniqueKeysWithValues: second.map { ($0.name, [$0.sellPlanCreatedAt, $0.sellPlanCheckedAt]) })
        #expect(datesAfterSecond == datesAfterFirst)
    }

    // MARK: - runCarryOver

    /// The settle hook's intent saves for itself: the plan it makes is on
    /// disk for a context that never saw the run.
    @Test func runCarryOverSavesThePlansItMakes() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let selected = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let entry = WishlistItem(name: "Rickenbacker 330")
        context.insert(selected)
        context.insert(entry)
        entry.plannedSaleItems = [selected]
        entry.sellPlanCheckedAt = nil
        try context.save()

        SellPlanStore.runCarryOver(in: context, now: now)

        let stored = try wanted(named: "Rickenbacker 330", in: ModelContext(container))
        #expect(stored.sellPlanCreatedAt == now)
        #expect(stored.sellPlanCheckedAt == now)
    }

    // MARK: - awaitsCarryOver

    /// The one predicate `carryOver` and the pending displays share (plan
    /// §1, Q2): unchecked, with a selection or a sold-toward history.
    @Test func anUncheckedRowWithASelectionAwaitsTheCarryOver() throws {
        let context = try makeInMemoryContext()
        let entry = WishlistItem(name: "Rickenbacker 330")
        let selected = Item(name: "Telecaster", purchasePriceCents: 100_000)
        context.insert(entry)
        context.insert(selected)
        entry.plannedSaleItems = [selected]
        entry.sellPlanCheckedAt = nil
        #expect(entry.awaitsCarryOver)
    }

    @Test func anUncheckedRowWithASoldTowardHistoryAwaitsTheCarryOver() throws {
        let context = try makeInMemoryContext()
        let entry = WishlistItem(name: "Rickenbacker 330")
        let sold = Item(name: "Blues Junior", purchasePriceCents: 60_000)
        context.insert(entry)
        context.insert(sold)
        try ItemSaleStore.markSold(sold, sale: sale(70_000), toward: entry, at: soldOn, in: context)
        entry.sellPlanCheckedAt = nil
        #expect(entry.awaitsCarryOver)
    }

    @Test func anUncheckedRowWithNeitherDoesNotAwaitTheCarryOver() throws {
        let context = try makeInMemoryContext()
        let entry = WishlistItem(name: "Rickenbacker 330")
        context.insert(entry)
        entry.sellPlanCheckedAt = nil
        #expect(!entry.awaitsCarryOver)
    }

    @Test func aCheckedRowNeverAwaitsTheCarryOverWhateverItCarries() throws {
        let context = try makeInMemoryContext()
        let entry = WishlistItem(name: "Rickenbacker 330")
        let selected = Item(name: "Telecaster", purchasePriceCents: 100_000)
        let sold = Item(name: "Blues Junior", purchasePriceCents: 60_000)
        context.insert(entry)
        context.insert(selected)
        context.insert(sold)
        entry.plannedSaleItems = [selected]
        try ItemSaleStore.markSold(sold, sale: sale(70_000), toward: entry, at: soldOn, in: context)
        #expect(entry.sellPlanCheckedAt != nil)
        #expect(!entry.awaitsCarryOver)
    }
}

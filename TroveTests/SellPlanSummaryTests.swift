import Foundation
import SwiftData
import Testing
@testable import Trove

/// G4: `SellPlanSummary` — the counts, the covered rule (the sales alone
/// against the estimate, plan Q6), the row's lines with no line for a zero
/// count (criterion 7), the entry point's three readings, and agreement with
/// `SellPlanViewModel` over one entry.
///
/// Every sold item's `currentValueCents` differs from its sale price, so a
/// sum that read the value instead of the price would come out different.
@Suite("SellPlanSummary")
struct SellPlanSummaryTests {
    private let soldOn = Date(timeIntervalSince1970: 1_770_000_000)
    private let now = Date(timeIntervalSince1970: 1_780_000_000)
    private let boughtOn = Date(timeIntervalSince1970: 1_760_000_000)

    // MARK: - Fixtures

    private func owned(_ name: String, valueCents: Int, into context: ModelContext) -> Item {
        let item = Item(
            name: name,
            categoryPath: "Music/Guitars",
            purchasePriceCents: 100_000,
            currentValueCents: valueCents,
            desireToKeep: 1
        )
        context.insert(item)
        return item
    }

    /// A wanted entry with `setAside` items on its plan and one sale toward it
    /// per price in `soldPrices`. Each sold item is worth 7,000 more today
    /// than it sold for.
    private func wanted(
        estimateCents: Int = 240_000,
        setAside: Int = 0,
        soldPrices: [Int] = [],
        into context: ModelContext
    ) throws -> WishlistItem {
        let plan = WishlistItem(
            name: "Summicron 35mm f/2",
            categoryPath: "Photography/Lenses",
            estimatedCostCents: estimateCents
        )
        context.insert(plan)
        plan.plannedSaleItems = (0..<setAside).map {
            owned("Set aside \($0)", valueCents: 50_000, into: context)
        }
        for (index, price) in soldPrices.enumerated() {
            let item = owned("Sold \(index)", valueCents: price + 7_000, into: context)
            try ItemSaleStore.markSold(
                item,
                sale: Sale(date: soldOn, priceCents: price, location: "Reverb", note: nil),
                toward: plan,
                at: now,
                in: context
            )
        }
        try context.save()
        return plan
    }

    // MARK: - Counts

    @Test func theCountsReadThePlansTwoLists() throws {
        let context = try makeInMemoryContext()
        let plan = try wanted(setAside: 2, soldPrices: [30_000, 40_000, 50_000], into: context)

        let summary = SellPlanSummary(plan)

        #expect(summary.setAsideCount == 2)
        #expect(summary.soldTowardCount == 3)
    }

    // MARK: - Covered (plan Q6, criterion 8)

    /// Sales exactly at the estimate are covered.
    ///
    /// Mutation: `>` for `>=` → this fails.
    @Test func salesExactlyAtTheEstimateAreCovered() throws {
        let context = try makeInMemoryContext()
        let plan = try wanted(estimateCents: 240_000, soldPrices: [140_000, 100_000], into: context)

        #expect(SellPlanSummary(plan).isCovered)
    }

    @Test func salesADollarShortAreNotCovered() throws {
        let context = try makeInMemoryContext()
        let plan = try wanted(estimateCents: 240_000, soldPrices: [139_900, 100_000], into: context)

        #expect(SellPlanSummary(plan).isCovered == false)
    }

    /// An estimate of 0 means "none", and nothing covers no estimate.
    ///
    /// Mutation: drop the `estimatedCostCents > 0` guard → this fails.
    @Test func noEstimateIsNeverCovered() throws {
        let context = try makeInMemoryContext()
        let plan = try wanted(estimateCents: 0, soldPrices: [50_000], into: context)

        #expect(SellPlanSummary(plan).isCovered == false)
    }

    /// The selection is not a sale. On the same entry the Sell Plan screen's
    /// cue reads met — it adds the selection — while covered does not.
    ///
    /// Mutation: add the set-aside items' value to the sum → this fails.
    @Test func aSelectionOverSalesShortOfTheEstimateIsNotCovered() throws {
        let context = try makeInMemoryContext()
        let plan = try wanted(estimateCents: 240_000, soldPrices: [100_000], into: context)
        let bigOne = owned("Worth more than the estimate", valueCents: 300_000, into: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id, now: { self.now })
        viewModel.load()
        viewModel.toggle(bigOne)

        #expect(viewModel.selectedValueMeetsCost, "the screen's cue adds the selection")
        #expect(SellPlanSummary(plan).setAsideCount == 1)
        #expect(SellPlanSummary(plan).isCovered == false)
    }

    /// The price recorded at the sale decides, never what the item is worth
    /// today (Decision 10).
    ///
    /// Mutation: sum `currentValueCents` in `soldCents(of:)` → this fails.
    @Test func aValueOverTheEstimateWithASaleUnderItIsNotCovered() throws {
        let context = try makeInMemoryContext()
        let plan = try wanted(estimateCents: 240_000, soldPrices: [200_000], into: context)
        let sold = try #require(plan.itemsSoldToward?.first)
        sold.currentValueCents = 300_000
        try context.save()

        #expect(SellPlanSummary(plan).isCovered == false)
    }

    // MARK: - Agreement with the Sell Plan screen

    /// One sum, two readers (plan Q5): the count and the sum the Plans rows
    /// read are the ones the Sell Plan screen shows.
    @Test func theCountAndTheSumAgreeWithTheSellPlanScreen() throws {
        let context = try makeInMemoryContext()
        let plan = try wanted(soldPrices: [95_000, 60_000, 35_500], into: context)

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: plan.id, now: { self.now })
        viewModel.load()

        #expect(viewModel.soldCount == 3)
        #expect(viewModel.soldValueCents == 190_500)
        #expect(SellPlanSummary(plan).soldTowardCount == viewModel.soldCount)
        #expect(SellPlanSummary.soldCents(of: plan.itemsSoldToward ?? []) == viewModel.soldValueCents)
    }

    // MARK: - A row's lines (criterion 7)

    /// Mutation: emit `setAside(0)` → the empty and sold-only rows fail.
    @Test func anActiveRowHasALineOnlyForANonZeroCount() throws {
        let context = try makeInMemoryContext()

        let empty = try wanted(into: context)
        #expect(SellPlanSummary(empty).rowLines(boughtDate: nil) == [])

        let setAsideOnly = try wanted(setAside: 2, into: context)
        #expect(SellPlanSummary(setAsideOnly).rowLines(boughtDate: nil) == ["2 items set aside"])

        let soldOnly = try wanted(soldPrices: [30_000], into: context)
        #expect(SellPlanSummary(soldOnly).rowLines(boughtDate: nil) == ["1 sold toward it"])

        let both = try wanted(setAside: 1, soldPrices: [30_000, 40_000], into: context)
        #expect(SellPlanSummary(both).rowLines(boughtDate: nil) == ["1 item set aside", "2 sold toward it"])
    }

    @Test func anActiveRowSaysCoveredLastAndOnlyWhenCovered() throws {
        let context = try makeInMemoryContext()
        let covered = try wanted(estimateCents: 240_000, setAside: 1, soldPrices: [140_000, 100_000], into: context)

        #expect(SellPlanSummary(covered).rowLines(boughtDate: nil)
            == ["1 item set aside", "2 sold toward it", "Covered"])
    }

    /// The bought date first; no set-aside line on the completed side; the
    /// past tense for what was sold; Covered last and only when covered.
    @Test func aCompletedRowLeadsWithTheBoughtDate() throws {
        let context = try makeInMemoryContext()
        let bought = SellPlanCopy.bought(on: boughtOn)

        let nothingSold = try wanted(setAside: 2, into: context)
        #expect(SellPlanSummary(nothingSold).rowLines(boughtDate: boughtOn) == [bought])

        let shortOfIt = try wanted(estimateCents: 240_000, soldPrices: [30_000, 40_000], into: context)
        #expect(SellPlanSummary(shortOfIt).rowLines(boughtDate: boughtOn)
            == [bought, "2 were sold toward it"])

        let covered = try wanted(estimateCents: 240_000, soldPrices: [250_000], into: context)
        #expect(SellPlanSummary(covered).rowLines(boughtDate: boughtOn)
            == [bought, "1 was sold toward it", "Covered"])
    }

    // MARK: - The entry point's subtitle (P9)

    /// Set aside first, then sold toward, then nothing set aside.
    ///
    /// Mutations: check sold toward before set aside → the first reading
    /// fails; exchange sold toward and nothing set aside → the second and
    /// third fail.
    @Test func theEntrySubtitlesThreeReadings() throws {
        let context = try makeInMemoryContext()

        let both = try wanted(setAside: 2, soldPrices: [30_000], into: context)
        #expect(SellPlanSummary(both).entrySubtitle == "2 items set aside")

        let soldOnly = try wanted(soldPrices: [30_000, 40_000, 50_000], into: context)
        #expect(SellPlanSummary(soldOnly).entrySubtitle == "3 sold toward it")

        let empty = try wanted(into: context)
        #expect(SellPlanSummary(empty).entrySubtitle == "Nothing set aside yet")
    }
}

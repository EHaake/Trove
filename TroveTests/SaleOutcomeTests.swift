import Foundation
import SwiftData
import Testing
@testable import Trove

/// 006/T001: the one arithmetic this spec adds, and the one sum every "what
/// was sold" surface reads (G32). The list, the dashboard and the UI seed's
/// expected numbers all go through `SaleOutcome.totals(over:)`, so "the
/// summary matches the card" is one sum rather than two hand-written ones
/// that happen to agree today.
@Suite("Sale outcome")
struct SaleOutcomeTests {
    /// Breaking even is not a loss — the boundary the colour rule turns on,
    /// checked either side of it and on it.
    @Test func isLossTurnsAtZero() {
        let under = SaleOutcome(salePriceCents: 99_999, purchasePriceCents: 100_000)
        let even = SaleOutcome(salePriceCents: 100_000, purchasePriceCents: 100_000)
        let over = SaleOutcome(salePriceCents: 100_001, purchasePriceCents: 100_000)

        #expect(under.deltaCents == -1)
        #expect(even.deltaCents == 0)
        #expect(over.deltaCents == 1)

        #expect(under.isLoss)
        #expect(!even.isLoss, "breaking even is not a loss")
        #expect(!over.isLoss)
    }

    /// The same boundary for the rule over a *sum* of sales (T017a/S3), which
    /// the Sold side's summary line and the Dashboard's card both colour off.
    /// The static form is that rule for a surface handed the realised sum
    /// alone — `SoldCard` — so it has to turn at the same point.
    ///
    /// Mutation: `SaleTotals.isLoss` → `realisedDeltaCents <= 0` turns both
    /// halves of this red on the ledger that broke even.
    @Test func totalsIsLossTurnsAtZeroToo() {
        let loss = SaleTotals(count: 2, proceedsCents: 100_000, realisedDeltaCents: -1)
        let even = SaleTotals(count: 2, proceedsCents: 100_000, realisedDeltaCents: 0)
        let gain = SaleTotals(count: 2, proceedsCents: 100_000, realisedDeltaCents: 1)

        #expect(loss.isLoss)
        #expect(!even.isLoss, "a ledger that broke even is not a loss")
        #expect(!gain.isLoss)

        #expect(SaleTotals.isLoss(realisedDeltaCents: loss.realisedDeltaCents))
        #expect(
            !SaleTotals.isLoss(realisedDeltaCents: even.realisedDeltaCents),
            "the delta-only form has to break even where the ledger does"
        )
        #expect(!SaleTotals.isLoss(realisedDeltaCents: gain.realisedDeltaCents))
    }

    private func makeSold(
        in context: ModelContext,
        name: String,
        purchasePriceCents: Int,
        salePriceCents: Int
    ) -> Item {
        let item = Item(
            name: name,
            categoryPath: "Music/Guitars",
            purchasePriceCents: purchasePriceCents
        )
        context.insert(item)
        item.sale = Sale(date: .now, priceCents: salePriceCents, location: nil, note: nil)
        return item
    }

    /// A gain, a loss, an at-cost sale and an item still owned. The owned one
    /// contributes nothing — not to the count, not to the proceeds — and the
    /// two sums are of different quantities, which is what the numbers here
    /// are chosen to keep apart.
    @Test func totalsSumOnlyTheSoldItems() throws {
        let context = try makeInMemoryContext()
        let gain = makeSold(in: context, name: "Telecaster", purchasePriceCents: 100_000, salePriceCents: 130_000)
        let loss = makeSold(in: context, name: "Blues Junior", purchasePriceCents: 60_000, salePriceCents: 45_000)
        let atCost = makeSold(in: context, name: "Summicron", purchasePriceCents: 250_000, salePriceCents: 250_000)
        let owned = Item(name: "D-18", categoryPath: "Music/Guitars", purchasePriceCents: 200_000)
        context.insert(owned)

        let totals = SaleOutcome.totals(over: [gain, loss, atCost, owned])

        #expect(totals.count == 3, "the owned item was counted")
        #expect(totals.proceedsCents == 130_000 + 45_000 + 250_000)
        #expect(totals.realisedDeltaCents == 30_000 - 15_000 + 0)
    }

    @Test func totalsOverNothingSoldAreAllZero() throws {
        let context = try makeInMemoryContext()
        let owned = Item(name: "D-18", categoryPath: "Music/Guitars", purchasePriceCents: 200_000)
        context.insert(owned)

        let totals = SaleOutcome.totals(over: [owned])

        #expect(totals == SaleTotals(count: 0, proceedsCents: 0, realisedDeltaCents: 0))
    }
}

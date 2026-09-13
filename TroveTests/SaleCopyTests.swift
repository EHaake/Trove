import Foundation
import Testing
@testable import Trove

/// Spec 006's copy, pinned whole (the `StockPhotoCopyTests` model): every
/// string in the spec's Copy section, and each composed line at a gain, a
/// loss and zero — the three readings that must stay distinguishable without
/// colour (Decision 10) — plus the sale line with and without a place.
@Suite("Sale copy")
struct SaleCopyTests {
    // MARK: - The fixed strings

    @Test func theActionLabels() {
        #expect(SaleCopy.markAsSold == "Mark as sold…")
        #expect(SaleCopy.editSale == "Edit sale…")
        #expect(SaleCopy.returnToCollection == "Return to collection…")
    }

    @Test func theSheetTitlesAndButtonsByMode() {
        #expect(SaleCopy.sheetTitleMark == "Mark as sold")
        #expect(SaleCopy.confirmMark == "Mark as sold")
        #expect(SaleCopy.sheetTitleEdit == "Edit sale")
        #expect(SaleCopy.confirmEdit == "Save")
        #expect(SaleCopy.cancel == "Cancel")
    }

    @Test func theFieldLabelsAndPlaceholder() {
        #expect(SaleCopy.salePriceLabel == "Sale price")
        #expect(SaleCopy.soldOnLabel == "Sold on")
        #expect(SaleCopy.soldAtLabel == "Sold at")
        #expect(SaleCopy.soldAtPlaceholder == "eBay, Reverb, a friend…")
        #expect(SaleCopy.noteLabel == "Note")
    }

    @Test func theReturnAlert() {
        #expect(SaleCopy.returnTitle("Leica M6") == "Return Leica M6 to your collection?")
        #expect(SaleCopy.returnMessage == "Its sale details will be removed.")
        #expect(SaleCopy.returnConfirm == "Return")
        #expect(SaleCopy.returnCancel == "Keep as sold")
    }

    @Test func theSwitchTheEmptyStateAndTheHeaders() {
        #expect(SaleCopy.owned == "Owned")
        #expect(SaleCopy.sold == "Sold")
        #expect(SaleCopy.soldMark == "Sold")
        #expect(SaleCopy.cardHeader == "Sold")
        #expect(SaleCopy.sellPlanFigureHeader == "Sold")
        #expect(SaleCopy.sellPlanSectionTitle == "Sold")
        #expect(SaleCopy.nothingSoldHeadline == "Nothing sold yet.")
        #expect(SaleCopy.nothingSoldDetail
            == "Mark an item as sold from its page or from a sell plan.")
    }

    @Test func theSellPlanCaptionCountsItems() {
        #expect(SaleCopy.sellPlanSoldCaption(count: 2) == "2 items")
        #expect(SaleCopy.sellPlanSoldCaption(count: 1) == "1 item")
        #expect(SaleCopy.sellPlanSoldCaption(count: 0) == "0 items")
    }

    // MARK: - The composed lines

    /// The card's figures at a gain, a loss and zero. The realised line is a
    /// separate string beneath them, so the count-and-proceeds line reads the
    /// same whichever way the delta went — only `realised` moves.
    @Test func theDashboardSummaryAtAGainALossAndZero() {
        #expect(SaleCopy.dashboardSummary(totals(count: 3, proceeds: 240_000, delta: 35_000))
            == "3 items · $2,400")
        #expect(SaleCopy.dashboardSummary(totals(count: 3, proceeds: 240_000, delta: -15_000))
            == "3 items · $2,400")
        #expect(SaleCopy.dashboardSummary(totals(count: 3, proceeds: 240_000, delta: 0))
            == "3 items · $2,400")
        #expect(SaleCopy.dashboardSummary(totals(count: 1, proceeds: 120_000, delta: 0))
            == "1 item · $1,200")
    }

    /// Zero reads "+$0 vs paid" on the card and the summary, deliberately —
    /// the Dashboard's Gain figure already prints "+$0", and only the rows
    /// and the page say "Sold at cost" in words (plan Q11). The loss carries
    /// a real minus sign, not a hyphen, like every other signed figure.
    @Test func theRealisedLineAtAGainALossAndZero() {
        #expect(SaleCopy.realised(deltaCents: 35_000) == "+$350 vs paid")
        #expect(SaleCopy.realised(deltaCents: -15_000) == "−$150 vs paid")
        #expect(SaleCopy.realised(deltaCents: 0) == "+$0 vs paid")
    }

    @Test func theSoldSideSummaryAtAGainALossAndZero() {
        #expect(SaleCopy.soldSideSummary(totals(count: 3, proceeds: 240_000, delta: 35_000))
            == "3 sold · $2,400 · +$350 vs paid")
        #expect(SaleCopy.soldSideSummary(totals(count: 3, proceeds: 240_000, delta: -15_000))
            == "3 sold · $2,400 · −$150 vs paid")
        #expect(SaleCopy.soldSideSummary(totals(count: 3, proceeds: 240_000, delta: 0))
            == "3 sold · $2,400 · +$0 vs paid")
    }

    /// Decision 10, on a row: gain, loss and at-cost each say in words which
    /// one it is, so nothing is left to the colour.
    @Test func theRowOutcomeAtAGainALossAndZero() {
        #expect(SaleCopy.rowOutcome(deltaCents: 35_000) == "Gain $350")
        #expect(SaleCopy.rowOutcome(deltaCents: -15_000) == "Loss $150")
        #expect(SaleCopy.rowOutcome(deltaCents: 0) == "Sold at cost")
    }

    /// Decision 10, on the page.
    @Test func thePageOutcomeAtAGainALossAndZero() {
        #expect(SaleCopy.pageOutcome(deltaCents: 35_000) == "Sold at a gain of $350")
        #expect(SaleCopy.pageOutcome(deltaCents: -15_000) == "Sold at a loss of $150")
        #expect(SaleCopy.pageOutcome(deltaCents: 0) == "Sold at cost")
    }

    /// A loss must never read as a gain with a stray sign: the two outcome
    /// forms carry the direction in a word, and the at-cost reading carries
    /// no figure at all.
    @Test func aLossNeverReadsAsAGain() {
        #expect(!SaleCopy.rowOutcome(deltaCents: -15_000).localizedCaseInsensitiveContains("gain"))
        #expect(!SaleCopy.pageOutcome(deltaCents: -15_000).localizedCaseInsensitiveContains("gain"))
        #expect(!SaleCopy.rowOutcome(deltaCents: 35_000).localizedCaseInsensitiveContains("loss"))
        #expect(!SaleCopy.pageOutcome(deltaCents: 35_000).localizedCaseInsensitiveContains("loss"))
    }

    /// The word and the colour must not disagree. `rowOutcome` and
    /// `pageOutcome` re-derive the loss boundary with their own
    /// `deltaCents < 0`, while the colour comes from `SaleOutcome.isLoss`
    /// (breaking even is not a loss) — so the two are compared directly at
    /// the boundary and either side of it.
    @Test func theOutcomeWordAgreesWithTheColourRuleAtTheBoundary() {
        let purchase = 120_000

        for delta in [-1, 0, 1] {
            let outcome = SaleOutcome(
                salePriceCents: purchase + delta,
                purchasePriceCents: purchase
            )

            #expect(SaleCopy.rowOutcome(deltaCents: delta).hasPrefix("Loss") == outcome.isLoss)
            #expect(SaleCopy.pageOutcome(deltaCents: delta).contains("at a loss") == outcome.isLoss)
        }
    }

    /// The date is the device's own abbreviated form — the detail's "Bought"
    /// row's formatter — so the expectation composes it the same way rather
    /// than pinning one locale's order. Changing the style in `SaleCopy`
    /// turns this red; changing the device's locale does not.
    @Test func theSaleLineWithAPlace() {
        let date = Date(timeIntervalSince1970: 1_789_000_000)
        let sale = Sale(date: date, priceCents: 120_000, location: "eBay", note: nil)
        let day = date.formatted(date: .abbreviated, time: .omitted)

        #expect(SaleCopy.saleLine(sale) == "Sold \(day) · $1,200 · eBay")
    }

    /// No place, no trailing separator — and the note never appears in the
    /// line either.
    @Test func theSaleLineWithoutAPlace() {
        let date = Date(timeIntervalSince1970: 1_789_000_000)
        let sale = Sale(date: date, priceCents: 120_000, location: nil, note: "Paid in cash")
        let day = date.formatted(date: .abbreviated, time: .omitted)

        #expect(SaleCopy.saleLine(sale) == "Sold \(day) · $1,200")
        #expect(!SaleCopy.saleLine(sale).contains("Paid in cash"))
    }

    /// An empty place is the same as no place: a form that writes "" rather
    /// than nil must not produce a line ending in a middle dot.
    @Test func theSaleLineWithAnEmptyPlace() {
        let date = Date(timeIntervalSince1970: 1_789_000_000)
        let sale = Sale(date: date, priceCents: 120_000, location: "", note: nil)
        let day = date.formatted(date: .abbreviated, time: .omitted)

        #expect(SaleCopy.saleLine(sale) == "Sold \(day) · $1,200")
    }

    // MARK: - Helpers

    private func totals(count: Int, proceeds: Int, delta: Int) -> SaleTotals {
        SaleTotals(count: count, proceedsCents: proceeds, realisedDeltaCents: delta)
    }
}

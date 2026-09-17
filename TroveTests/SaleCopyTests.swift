import Foundation
import Testing
@testable import Trove

/// Spec 006's copy, pinned whole (the `StockPhotoCopyTests` model): every
/// string in the spec's Copy section, and each composed line at a gain, a
/// loss and zero — the three readings that must stay distinguishable without
/// colour (Decision 11's settled form) — plus the sale line with and without
/// a place.
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
        #expect(SaleCopy.notePlaceholder == "Anything worth remembering")
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
        #expect(SaleCopy.everythingSoldHeadline == "Everything's sold.")
        #expect(SaleCopy.everythingSoldDetail == "Add something new.")
        #expect(SaleCopy.planEverythingSoldHeadline == "Everything on this plan has sold.")
        #expect(SaleCopy.planEverythingSoldDetail == "The sales are listed below.")
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
    /// and the page say "At cost" in words (plan Q11). The loss carries a
    /// real minus sign, not a hyphen, like every other signed figure.
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

    /// Spec Decision 13's zero form, pinned here because this is where it is
    /// decided: two parts, not three. The realised part is dropped at zero
    /// sales — "+$0 vs paid" over nothing sold would state a measurement
    /// where none was made — and the line still exists, which is what keeps
    /// the Sold side's header slot the same height as the Owned side's and
    /// the `SideSwitch` above it from moving.
    ///
    /// Mutation: append `realised(deltaCents:)` unconditionally → this reads
    /// "0 sold · $0 · +$0 vs paid" and fails.
    @Test func theSoldSideSummaryAtZeroSalesIsALineWithNoRealisedPart() {
        let atZero = SaleCopy.soldSideSummary(totals(count: 0, proceeds: 0, delta: 0))

        #expect(atZero == "0 sold · $0")
        #expect(!atZero.contains("vs paid"))
        #expect(!atZero.isEmpty)

        // One sale brings the third part back, so the drop is the zero case
        // and not the whole line losing its realised figure.
        #expect(SaleCopy.soldSideSummary(totals(count: 1, proceeds: 0, delta: 0))
            == "1 sold · $0 · +$0 vs paid")
    }

    /// Decision 11's settled form, on a row: the word first, then the
    /// amount, then the basis — so nothing is left to the colour, and the
    /// figure says what it is measured against.
    @Test func theRowOutcomeAtAGainALossAndZero() {
        #expect(SaleCopy.rowOutcome(deltaCents: 35_000) == "Gain $350 vs paid")
        #expect(SaleCopy.rowOutcome(deltaCents: -15_000) == "Loss $150 vs paid")
        #expect(SaleCopy.rowOutcome(deltaCents: 0) == "At cost")
        #expect(SaleCopy.atCost == "At cost")
    }

    /// The page says exactly what the row says (Decision 11) — it only sets
    /// it larger. Pinned as its own strings rather than as
    /// `pageOutcome == rowOutcome`, which today's forwarding body could not
    /// make false: give `pageOutcome` a body of its own and this goes red.
    @Test func thePageOutcomeReadsTheSameAsTheRow() {
        #expect(SaleCopy.pageOutcome(deltaCents: 35_000) == "Gain $350 vs paid")
        #expect(SaleCopy.pageOutcome(deltaCents: -15_000) == "Loss $150 vs paid")
        #expect(SaleCopy.pageOutcome(deltaCents: 0) == "At cost")
    }

    /// A loss must never read as a gain with a stray sign: the outcome form
    /// carries the direction in a word, and the at-cost reading carries no
    /// figure at all.
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
            #expect(SaleCopy.pageOutcome(deltaCents: delta).hasPrefix("Loss") == outcome.isLoss)
        }
    }

    /// The date is the device's own abbreviated form — the detail's "Bought"
    /// row's formatter — so the expectation composes it the same way rather
    /// than pinning one locale's order. Changing the style in `SaleCopy`
    /// turns this red; changing the device's locale does not. The line opens
    /// on the date: the word "Sold" is gone (Decision 11).
    @Test func theSaleLineWithAPlace() {
        let date = Date(timeIntervalSince1970: 1_789_000_000)
        let sale = Sale(date: date, priceCents: 120_000, location: "eBay", note: nil)
        let day = date.formatted(date: .abbreviated, time: .omitted)

        #expect(SaleCopy.saleLine(sale) == "\(day) · $1,200 · eBay")
    }

    /// No place, no trailing separator — and the note never appears in the
    /// line either.
    @Test func theSaleLineWithoutAPlace() {
        let date = Date(timeIntervalSince1970: 1_789_000_000)
        let sale = Sale(date: date, priceCents: 120_000, location: nil, note: "Paid in cash")
        let day = date.formatted(date: .abbreviated, time: .omitted)

        #expect(SaleCopy.saleLine(sale) == "\(day) · $1,200")
        #expect(!SaleCopy.saleLine(sale).contains("Sold"))
        #expect(!SaleCopy.saleLine(sale).contains("Paid in cash"))
    }

    /// An empty place is the same as no place: a form that writes "" rather
    /// than nil must not produce a line ending in a middle dot.
    @Test func theSaleLineWithAnEmptyPlace() {
        let date = Date(timeIntervalSince1970: 1_789_000_000)
        let sale = Sale(date: date, priceCents: 120_000, location: "", note: nil)
        let day = date.formatted(date: .abbreviated, time: .omitted)

        #expect(SaleCopy.saleLine(sale) == "\(day) · $1,200")
    }

    // MARK: - Helpers

    private func totals(count: Int, proceeds: Int, delta: Int) -> SaleTotals {
        SaleTotals(count: count, proceedsCents: proceeds, realisedDeltaCents: delta)
    }
}

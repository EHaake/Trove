import Foundation
import Testing
@testable import Trove

/// Spec 015's copy, pinned whole (the `SaleCopyTests` model): every string in
/// the spec's Copy section, and the comparison line's five cases — under,
/// over, equal, no estimate, and less than a dollar apart — which are the
/// readings criterion 6 turns on.
@Suite("Purchase copy")
struct PurchaseCopyTests {
    // MARK: - The fixed strings

    @Test func theActionLabels() {
        #expect(PurchaseCopy.markAsBought == "Mark as bought…")
        // The swipe button's visible word, where "Mark as bought" does not
        // fit; the spoken name stays `markAsBought` above.
        #expect(PurchaseCopy.swipeBuy == "Buy")
    }

    @Test func theSheetTitleAndButtons() {
        #expect(PurchaseCopy.sheetTitle == "Mark as bought")
        #expect(PurchaseCopy.confirm == "Mark as bought")
        #expect(PurchaseCopy.cancel == "Cancel")
    }

    @Test func theFieldLabelsAndPlaceholder() {
        #expect(PurchaseCopy.purchasePriceLabel == "Purchase price")
        #expect(PurchaseCopy.purchaseDateLabel == "Purchase date")
        #expect(PurchaseCopy.boughtFromLabel == "Bought from")
        #expect(PurchaseCopy.boughtFromPlaceholder == "eBay, Reverb, a friend…")
        #expect(PurchaseCopy.conditionLabel == "Condition")
    }

    // MARK: - The comparison line

    /// The spec's two examples, pinned as literals: the word carries the
    /// direction, so paying under the estimate must never read "more".
    ///
    /// Mutation: swap "less" and "more" → both of these fail.
    @Test func theComparisonUnderAndOverTheEstimate() {
        #expect(PurchaseCopy.comparison(paidCents: 228_000, estimatedCostCents: 240_000)
            == "$120 less than you estimated")
        #expect(PurchaseCopy.comparison(paidCents: 248_500, estimatedCostCents: 240_000)
            == "$85 more than you estimated")
    }

    /// Equality is silence, not a sentence saying zero (spec Copy).
    @Test func theComparisonAtTheEstimateIsSilent() {
        #expect(PurchaseCopy.comparison(paidCents: 240_000, estimatedCostCents: 240_000) == nil)
    }

    /// No estimate is the same silence. `estimatedCostCents` is a
    /// non-optional `Int` whose 0 means "none" (plan Q7), so without the
    /// guard a $2,400 purchase against no estimate would announce the whole
    /// price as a difference.
    ///
    /// Mutation: drop the `estimatedCostCents != 0` guard → this reads
    /// "$2,400 more than you estimated" and fails.
    @Test func theComparisonWithNoEstimateIsSilent() {
        #expect(PurchaseCopy.comparison(paidCents: 240_000, estimatedCostCents: 0) == nil)
    }

    /// Below a dollar is silence too — the plan's floor, not the spec's.
    /// Every money figure here draws whole dollars, so 40 cents apart would
    /// otherwise render a difference of "$0".
    ///
    /// Mutation: drop the `abs(deltaCents) >= 100` floor → this reads
    /// "$0 more than you estimated" and fails.
    @Test func theComparisonBelowADollarIsSilent() {
        #expect(PurchaseCopy.comparison(paidCents: 240_040, estimatedCostCents: 240_000) == nil)
        #expect(PurchaseCopy.comparison(paidCents: 239_960, estimatedCostCents: 240_000) == nil)

        // A dollar apart is the first difference worth a sentence, so the
        // floor is a floor and not the line going quiet altogether.
        #expect(PurchaseCopy.comparison(paidCents: 240_100, estimatedCostCents: 240_000)
            == "$1 more than you estimated")
        #expect(PurchaseCopy.comparison(paidCents: 239_900, estimatedCostCents: 240_000)
            == "$1 less than you estimated")
    }
}

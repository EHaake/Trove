import Foundation
import Testing
@testable import Trove

/// `PurchaseCopy`'s table, pinned whole (the `SaleCopyTests` model): the
/// purchase sheet's and the purchase actions' strings, and the comparison
/// line's five cases — under, over, equal, no estimate, and less than a dollar
/// apart — which are the readings criterion 6 turns on.
///
/// Not all of spec 015's Copy section, since T012c: the Sell Plan entry
/// point's four strings live inline in
/// `WishlistDetailViewModel.sellPlanEntryTitle` and `.sellPlanEntrySubtitle`,
/// because which of them a person sees is a branch rather than a fixed label.
/// They are covered where the branch is, by `WishlistDetailViewModelTests`,
/// which is the behavioural reach a literal pinned here would not have.
@Suite("Purchase copy")
struct PurchaseCopyTests {
    // MARK: - The fixed strings

    @Test func theActionLabels() {
        #expect(PurchaseCopy.markAsBought == "Mark as bought…")
        // The swipe button's visible word, where "Mark as bought" does not
        // fit; the spoken name stays `markAsBought` above.
        #expect(PurchaseCopy.swipeBuy == "Buy")
    }

    /// No `sheetTitle` leg: T012a removed the sheet's navigation title (the
    /// person's decision at the device pass), and the constant went with it.
    @Test func theSheetButtons() {
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

    // MARK: - A refused purchase

    /// T012b's three strings, pinned as literals. The two messages both end
    /// "Nothing was changed", which is a claim about the code as much as a
    /// sentence: the already-bought guard sits ahead of the market clear,
    /// and every other refusal is rolled back
    /// (`WishlistDetailViewModelTests.everyHostRefusesToBuyAnEntryTwice`
    /// checks the store side of it).
    ///
    /// Mutation: swap the two messages → the behavioural tests on the three
    /// hosts go red as well as this one.
    @Test func theRefusalAlertsWords() {
        #expect(PurchaseCopy.failureTitle == "Couldn't mark it bought")
        #expect(PurchaseCopy.alreadyBought
            == "This one is already marked bought — it may have been bought on another device. Nothing was changed.")
        #expect(PurchaseCopy.failureMessage
            == "Something went wrong saving the purchase. Nothing was changed.")

        // No "the two messages differ" leg: the literals above already pin
        // both, so it could not fail. Which host maps which refusal to which
        // message is behaviour, checked by
        // `WishlistDetailViewModelTests.everyHostRefusesToBuyAnEntryTwice`.
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

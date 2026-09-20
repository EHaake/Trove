import Foundation
import Testing
@testable import Trove

/// 015/T005, G20. Where each field of the purchase sheet starts (plan §5,
/// Q10's seeding rule).
///
/// The clock is injected, so "today" is an exact instant rather than whatever
/// the machine happened to read — the seed's date claim is measurable only
/// against a clock the test controls.
///
/// The estimate is 240_000 cents and the seeded price is therefore `2400`:
/// deliberately three different numbers from the ones a broken seed would
/// produce (`240000` from forgetting the conversion, `0` from a `?? 0`), so no
/// assertion here can pass by coincidence.
@Suite("Purchase form — prefill")
struct PurchaseFormPrefillTests {
    private let t0 = Date(timeIntervalSince1970: 1_780_000_000)

    @Test func seedsThePriceFromTheEstimateAndTheDateFromTheClock() {
        let form = PurchaseFormViewModel(estimatedCostCents: 240_000, now: { self.t0 })

        #expect(form.price == Decimal(string: "2400"))
        #expect(form.date == t0)
        #expect(form.location.isEmpty)
        #expect(form.condition == .excellent)
    }

    /// Q10/`006` P1: no estimate, no pre-filled price — blank and required.
    /// `estimatedCostCents` is a non-optional `Int` whose 0 means "none"
    /// (Q7), and a pre-filled 0 cannot be typed over: the digits append.
    ///
    /// Mutation: seed with `Money.amount(fromCents: estimatedCostCents)`
    /// unconditionally (a `?? 0` seed) → `price` is `0`, the sheet validates,
    /// and this fails on all three counts.
    @Test func leavesThePriceBlankWithoutAnEstimate() {
        let form = PurchaseFormViewModel(estimatedCostCents: 0, now: { self.t0 })

        #expect(form.price == nil)
        #expect(form.purchase() == nil)
        #expect(form.validationErrors.contains(.priceMissing))
    }

    /// Title and confirm label come from `PurchaseCopy`, not from literals
    /// typed into the view model.
    ///
    /// **Corrected at T006a (S1); T005's version of this note understated
    /// it.** The weakness is not only that both constants spell "Mark as
    /// bought" and so cannot be told apart. It is that the *only* mutation
    /// that reddens this is a hand-typed literal whose text **differs** from
    /// the table: swap the two properties over, or return `PurchaseCopy`'s
    /// other constant, or type the identical string by hand, and it stays
    /// green. So what it guards is exactly one thing — a variant drifting
    /// out of step with the table — and it is not evidence that either
    /// property is wired to the right constant.
    ///
    /// Kept rather than deleted, because that one thing is real and nothing
    /// else covers it. Worth stating beside the inconsistency the Phase 1
    /// review turned up: T006's cross-host seed test drops its own
    /// `title`/`confirmLabel` comparison as unfalsifiable. That is consistent
    /// with this — there, all three hosts read the same get-only property, so
    /// there is no drift to catch at all; here there is.
    @Test func namesTheSheetFromTheCopyTable() {
        let form = PurchaseFormViewModel(estimatedCostCents: 240_000, now: { self.t0 })

        #expect(form.title == PurchaseCopy.sheetTitle)
        #expect(form.confirmLabel == PurchaseCopy.confirm)
    }
}

/// 015/T005, G20. What the purchase sheet refuses and what it records
/// (plan §5, Q9).
@Suite("Purchase form — validation")
struct PurchaseFormValidationTests {
    private let t0 = Date(timeIntervalSince1970: 1_780_000_000)

    private func viewModel(estimatedCostCents: Int = 240_000) -> PurchaseFormViewModel {
        PurchaseFormViewModel(estimatedCostCents: estimatedCostCents, now: { self.t0 })
    }

    /// Blank is not zero: the price is required, so a sheet whose seeded
    /// price has been cleared records nothing.
    @Test func refusesABlankPrice() {
        let form = viewModel()
        form.price = nil

        #expect(form.purchase() == nil)
        #expect(form.validationErrors.contains(.priceMissing))
    }

    @Test func refusesANegativePrice() {
        let form = viewModel()
        form.price = -1

        #expect(form.purchase() == nil)
        #expect(form.validationErrors.contains(.priceNegative))
        #expect(form.validationErrors.contains(.priceMissing) == false)
    }

    /// A gift is a purchase of $0 — a deliberate zero is not a missing price.
    @Test func acceptsAZeroPrice() throws {
        let form = viewModel()
        form.price = 0

        let purchase = try #require(form.purchase())
        #expect(purchase.priceCents == 0)
        #expect(form.validationErrors.isEmpty)
    }

    /// **Q9: the purchase date is unbounded, a stated divergence from the sale
    /// sheet.** `SaleFormViewModel` refuses any instant past `now()`; this one
    /// must not, because the field it fills is `Item.purchaseDate`, whose own
    /// editor — `ItemFormView`'s "Date bought" — takes any date at all, and a
    /// sheet that refuses what the Edit screen accepts is one rule with two
    /// answers. Pinned a week ahead so the divergence is deliberate rather
    /// than forgotten.
    ///
    /// Mutation: add a `dateInFuture` case and a `date <= now()` check → this
    /// fails, and it is the only test that does.
    @Test func acceptsADateAWeekAhead() throws {
        let aWeekAhead = t0.addingTimeInterval(7 * 24 * 60 * 60)
        let form = viewModel()
        form.price = 1_200
        form.date = aWeekAhead

        let purchase = try #require(form.purchase())
        #expect(purchase.date == aWeekAhead)
        #expect(form.validationErrors.isEmpty)
    }

    /// The typed amount rounds to the nearest cent, and the chosen condition
    /// travels with it — `.fair` rather than the `.excellent` the sheet
    /// defaults to, so a `purchase()` that hardcoded the default would fail
    /// here.
    @Test func recordsTheTypedAmountAndTheChosenCondition() throws {
        let form = viewModel()
        form.price = Decimal(string: "2399.005")
        form.condition = .fair

        let purchase = try #require(form.purchase())
        #expect(purchase.priceCents == 239_901)
        #expect(purchase.condition == .fair)
    }

    /// A blank place means "not provided", trimmed the way every other form
    /// field is (`FieldNormalization`).
    @Test func trimsAndNilsTheBlankPlace() throws {
        let form = viewModel()
        form.price = 1_200
        form.location = "  Reverb "

        #expect(try #require(form.purchase()).location == "Reverb")

        form.location = "   \n "
        #expect(try #require(form.purchase()).location == nil)
    }
}

/// 015/T005, G4. The line under the price, read through the view model at the
/// price the person has actually typed (criterion 6). The strings themselves
/// are `PurchaseCopyTests`' business; what these measure is that the *typed*
/// price and the entry's estimate reach it, in that order.
@Suite("Purchase form — comparison line")
struct PurchaseFormComparisonLineTests {
    private let t0 = Date(timeIntervalSince1970: 1_780_000_000)

    /// Three typed prices against one $2,400 estimate: under, over, and
    /// exactly at it. The direction word is the falsifiable part — swap the
    /// two arguments at the call site and "less" and "more" trade places.
    @Test func readsTheTypedPriceAgainstTheEstimate() {
        let form = PurchaseFormViewModel(estimatedCostCents: 240_000, now: { self.t0 })

        form.price = Decimal(string: "2280")
        #expect(form.comparisonLine == "$120 less than you estimated")

        form.price = Decimal(string: "2485")
        #expect(form.comparisonLine == "$85 more than you estimated")

        form.price = Decimal(string: "2400")
        #expect(form.comparisonLine == nil)
    }

    /// With the field blank the line compares 0 against the estimate — a real
    /// "less than you estimated" reading, and the one the spec's under-case
    /// describes (plan §5). Mutation: pass the estimate instead of 0 for a nil
    /// price and the line goes silent, failing here.
    @Test func readsABlankPriceAsZero() {
        let form = PurchaseFormViewModel(estimatedCostCents: 240_000, now: { self.t0 })

        #expect(form.price != nil)
        form.price = nil
        #expect(form.comparisonLine == "$2,400 less than you estimated")
    }
}

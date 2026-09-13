import Foundation
import Testing
@testable import Trove

/// 006/T004. The sale sheet's rules (plan §5, Q12; spec P1, P2).
///
/// The clock is injected everywhere, so "today" and "one second from now" are
/// exact instants rather than whatever the machine happened to read: a future
/// date has to be refused by the view model, not merely discouraged by the
/// picker's bound, and that claim can only be measured against a clock the
/// test controls.
@Suite("Sale form — validation")
struct SaleFormValidationTests {
    private let t0 = Date(timeIntervalSince1970: 1_780_000_000)

    private func viewModel(currentValueCents: Int? = 130_000) -> SaleFormViewModel {
        SaleFormViewModel(mode: .mark, prefill: nil, currentValueCents: currentValueCents, now: { self.t0 })
    }

    /// P1: blank is not zero. The field is required, so an untouched sheet
    /// records nothing.
    @Test func refusesABlankPrice() {
        let form = viewModel(currentValueCents: nil)

        #expect(form.sale() == nil)
        #expect(form.validationErrors.contains(.priceMissing))
    }

    @Test func refusesANegativePrice() {
        let form = viewModel()
        form.price = -1

        #expect(form.sale() == nil)
        #expect(form.validationErrors.contains(.priceNegative))
        #expect(form.validationErrors.contains(.priceMissing) == false)
    }

    /// Given away is a sale of $0 — a deliberate zero is not a missing price.
    @Test func acceptsAZeroPrice() throws {
        let form = viewModel()
        form.price = 0

        let sale = try #require(form.sale())
        #expect(sale.priceCents == 0)
        #expect(form.validationErrors.isEmpty)
    }

    @Test func convertsTheTypedAmountToCents() throws {
        let form = viewModel()
        form.price = Decimal(string: "1299.005")

        let sale = try #require(form.sale())
        #expect(sale.priceCents == 129_901)
    }

    /// P2: one second past the clock is the future.
    @Test func refusesADateOneSecondInTheFuture() {
        let form = viewModel()
        form.price = 1_200
        form.date = t0.addingTimeInterval(1)

        #expect(form.sale() == nil)
        #expect(form.validationErrors.contains(.dateInFuture))
    }

    /// The boundary is inclusive: the sheet opens pre-filled with this very
    /// instant, so `now` itself must be an allowed sale date.
    @Test func acceptsASaleDatedExactlyNow() throws {
        let form = viewModel()
        form.price = 1_200
        form.date = t0

        let sale = try #require(form.sale())
        #expect(sale.date == t0)
        #expect(form.validationErrors.isEmpty)
    }

    /// P2: any past date, including years before the item was bought. The app
    /// does not second-guess the person's own data entry.
    @Test func acceptsADateYearsBeforeThePurchase() throws {
        let purchaseDate = t0.addingTimeInterval(-365 * 24 * 60 * 60)
        let form = viewModel()
        form.price = 1_200
        form.date = purchaseDate.addingTimeInterval(-4 * 365 * 24 * 60 * 60)

        let sale = try #require(form.sale())
        #expect(sale.date < purchaseDate)
        #expect(form.validationErrors.isEmpty)
    }

    /// The picker's upper bound reads the injected clock, not `Date.now`.
    @Test func latestDateIsTheClock() {
        #expect(viewModel().latestDate == t0)
    }

    /// A second call clears an error the person has since fixed — the errors
    /// are the last validation's, not an accumulating set.
    @Test func revalidatesOnEveryCall() throws {
        let form = viewModel(currentValueCents: nil)
        #expect(form.sale() == nil)
        #expect(form.validationErrors.contains(.priceMissing))

        form.price = 900
        #expect(try #require(form.sale()).priceCents == 90_000)
        #expect(form.validationErrors.isEmpty)
    }

    /// Blank place and note mean "not provided", trimmed the way every other
    /// form field is (`FieldNormalization`).
    @Test func trimsAndNilsTheBlankPlaceAndNote() throws {
        let form = viewModel()
        form.price = 1_200
        form.location = "  Reverb "
        form.note = "   \n "

        let sale = try #require(form.sale())
        #expect(sale.location == "Reverb")
        #expect(sale.note == nil)

        form.location = "  "
        form.note = "  Shipped Tuesday  "
        let second = try #require(form.sale())
        #expect(second.location == nil)
        #expect(second.note == "Shipped Tuesday")
    }
}

/// G19: where each field's seed comes from. `.mark` reads the item's current
/// value and the clock; `.edit` reads the sale and nothing else.
@Suite("Sale form — prefill")
struct SaleFormPrefillTests {
    private let t0 = Date(timeIntervalSince1970: 1_780_000_000)
    private let soldOn = Date(timeIntervalSince1970: 1_770_000_000)

    private var recordedSale: Sale {
        Sale(date: soldOn, priceCents: 95_000, location: "Reverb", note: "Shipped Tuesday")
    }

    @Test func markPrefillsTheCurrentValueAndToday() {
        let form = SaleFormViewModel(mode: .mark, prefill: nil, currentValueCents: 130_000, now: { self.t0 })

        #expect(form.price == Decimal(string: "1300"))
        #expect(form.date == t0)
        #expect(form.location.isEmpty)
        #expect(form.note.isEmpty)
    }

    /// The seed's source, measured: even handed a sale, `.mark` takes the
    /// price from the current value. Nothing in the app passes one, which is
    /// exactly why the wrong source would otherwise go unnoticed.
    @Test func markTakesThePriceFromTheCurrentValueNotASale() {
        let form = SaleFormViewModel(
            mode: .mark, prefill: recordedSale, currentValueCents: 130_000, now: { self.t0 }
        )

        #expect(form.price == Decimal(string: "1300"))
        #expect(form.date == t0)
        #expect(form.location.isEmpty)
        #expect(form.note.isEmpty)
    }

    /// P1: no current value, no pre-filled price — blank and required.
    @Test func markLeavesThePriceBlankWithoutACurrentValue() {
        let form = SaleFormViewModel(mode: .mark, prefill: nil, currentValueCents: nil, now: { self.t0 })

        #expect(form.price == nil)
        #expect(form.date == t0)
        #expect(form.sale() == nil)
        #expect(form.validationErrors.contains(.priceMissing))
    }

    @Test func editPrefillsEveryFieldOfTheSale() {
        let form = SaleFormViewModel(
            mode: .edit, prefill: recordedSale, currentValueCents: 130_000, now: { self.t0 }
        )

        #expect(form.price == Decimal(string: "950"))
        #expect(form.date == soldOn)
        #expect(form.location == "Reverb")
        #expect(form.note == "Shipped Tuesday")
    }

    /// An edited sale that changed nothing round-trips to the same value.
    @Test func editRoundTripsAnUntouchedSale() throws {
        let form = SaleFormViewModel(
            mode: .edit, prefill: recordedSale, currentValueCents: nil, now: { self.t0 }
        )

        #expect(try #require(form.sale()) == recordedSale)
    }

    /// Title and confirm label come from `SaleCopy`, by mode.
    @Test func namesTheSheetByMode() {
        let mark = SaleFormViewModel(mode: .mark, prefill: nil, currentValueCents: nil, now: { self.t0 })
        let edit = SaleFormViewModel(mode: .edit, prefill: recordedSale, currentValueCents: nil, now: { self.t0 })

        #expect(mark.title == SaleCopy.sheetTitleMark)
        #expect(mark.confirmLabel == SaleCopy.confirmMark)
        #expect(edit.title == SaleCopy.sheetTitleEdit)
        #expect(edit.confirmLabel == SaleCopy.confirmEdit)
    }
}

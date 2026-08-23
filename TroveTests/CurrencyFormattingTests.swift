import Foundation
import Testing
@testable import Trove

@Suite("Int+Currency formatting")
struct CurrencyFormattingTests {
    @Test func formatsATypicalAmount() {
        #expect(129_900.formattedAsCurrency(currencyCode: "USD") == "$1,299.00")
    }

    @Test func formatsZero() {
        #expect(0.formattedAsCurrency(currencyCode: "USD") == "$0.00")
    }

    @Test func formatsASingleCent() {
        #expect(1.formattedAsCurrency(currencyCode: "USD") == "$0.01")
    }

    @Test func formatsAnAmountUnderADollar() {
        #expect(50.formattedAsCurrency(currencyCode: "USD") == "$0.50")
    }

    /// Not hypothetical: the dashboard's spent-vs-worth delta can go negative.
    @Test func formatsANegativeAmount() {
        #expect((-500).formattedAsCurrency(currencyCode: "USD") == "-$5.00")
    }

    @Test func formatsALargeAmountWithGrouping() {
        #expect(1_234_567_89.formattedAsCurrency(currencyCode: "USD") == "$1,234,567.89")
    }
}

/// Design draws every money figure without cents. Beyond matching, the cents
/// cost enough width to wrap a list row onto two lines — which is how this
/// surfaced.
@Suite("Int+Currency whole-dollar formatting")
struct WholeCurrencyFormattingTests {
    @Test func dropsTheCents() {
        #expect(345_000.formattedAsWholeCurrency(currencyCode: "USD") == "$3,450")
        #expect(178_000.formattedAsWholeCurrency(currencyCode: "USD") == "$1,780")
        #expect(54_000.formattedAsWholeCurrency(currencyCode: "USD") == "$540")
    }

    @Test func roundsRatherThanTruncating() {
        #expect(199.formattedAsWholeCurrency(currencyCode: "USD") == "$2")
        #expect(149.formattedAsWholeCurrency(currencyCode: "USD") == "$1")
    }

    @Test func formatsZero() {
        #expect(0.formattedAsWholeCurrency(currencyCode: "USD") == "$0")
    }
}

@Suite("Int+Currency signed differences")
struct SignedAmountFormattingTests {
    /// Design's own form: no currency symbol, no cents, beside the value it
    /// refers to — "+550 vs paid".
    @Test func signsTheDifferenceWithoutACurrencySymbol() {
        #expect(55_000.formattedAsSignedWholeAmount == "+550")
        #expect(53_000.formattedAsSignedWholeAmount == "+530")
    }

    /// A real minus sign, not a hyphen — it aligns with the digits in mono.
    @Test func usesAProperMinusSignForLosses() {
        #expect((-15_000).formattedAsSignedWholeAmount == "−150")
    }

    @Test func groupsLargeDifferences() {
        #expect(1_250_000.formattedAsSignedWholeAmount == "+12,500")
    }

    @Test func showsBreakingEvenAsPlusZero() {
        #expect(0.formattedAsSignedWholeAmount == "+0")
    }
}

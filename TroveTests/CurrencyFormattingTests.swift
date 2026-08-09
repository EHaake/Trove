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

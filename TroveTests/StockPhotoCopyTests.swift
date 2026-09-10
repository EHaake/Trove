import Foundation
import Testing
@testable import Trove

/// Spec 005's copy. This task lands only the one guard that can block work —
/// the contact address the Wikimedia User-Agent carries (plan Q6, the
/// `MarketCopyTests.theContactAddressIsARealOne` model). T004 extends this.
@Suite("Stock photo copy")
struct StockPhotoCopyTests {
    @Test func theContactAddressIsARealOne() {
        let address = StockPhotoCopy.contactAddress
        let lowered = address.lowercased()
        // Computed ahead of the expectations: a closure inside `#expect`
        // trips the macro's throwing inference.
        let atSigns = address.filter { $0 == "@" }.count
        let hasWhitespace = address.contains(where: \.isWhitespace)
        let domain = address.split(separator: "@").last.map(String.init) ?? ""
        let domainHasADot = domain.range(of: ".") != nil
        let isPlaceholder = lowered.range(of: "todo") != nil || lowered.range(of: "example.com") != nil

        #expect(atSigns == 1, "not one @: \(address)")
        #expect(!hasWhitespace, "whitespace in the address: \(address)")
        #expect(!isPlaceholder, "the placeholder is still in place: \(address)")
        #expect(domainHasADot, "no domain after the @: \(address)")
    }
}

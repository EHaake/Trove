import Foundation
import Testing
@testable import Trove

/// Spec 002's copy, pinned whole (T007). T004 lands the one string the API
/// client needs first: the contact address, and the guard that keeps a
/// placeholder from shipping in About, the policy and every request's
/// `User-Agent` (Decision 25).
@Suite("Market copy")
struct MarketCopyTests {
    @Test func theContactAddressIsARealOne() {
        let address = MarketCopy.contactAddress
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

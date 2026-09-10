import Testing
@testable import Trove

/// Wiring/render guards for the shared stock-photo badge and credit (T007).
///
/// These scan the two view files' *production* source (comments stripped,
/// `#Preview` dropped by `SourceScan.production`) so a guard can't be satisfied
/// by a comment or a preview. The one value-level test exercises the no-author
/// fallback branch T001's review asked T007/T009 to cover.
@Suite("Stock photo badge and credit")
struct StockPhotoBadgeTests {
    private static let badge = "Trove/Views/Shared/StockPhotoBadge.swift"
    private static let credit = "Trove/Views/Shared/StockPhotoCredit.swift"

    /// The credit draws a real `Link`, once — not a `Button`, not `openURL`.
    /// The non-identifier-boundary regex is `MarketWiringTests`'
    /// `theOutwardLinkIsALinkNotAButton` pattern, so `NavigationLink(` can't
    /// stand in for it.
    @Test func theCreditComposesALinkNotAButton() throws {
        let code = try SourceScan.production(Self.credit)
        let link = try Regex(#"(?:^|[^A-Za-z0-9_])Link\("#)
        let links = code.ranges(of: link).count
        #expect(links == 1, "the credit draws \(links) links — the source link is the one and only")
        #expect(!code.contains("openURL"), "the credit opens a URL by hand instead of linking")
    }

    /// The link carries a hint that it leaves the app (criterion 11).
    @Test func theLinkSaysItLeavesTheApp() throws {
        let code = try SourceScan.production(Self.credit)
        #expect(code.contains("StockPhotoCopy.creditLinkHint"), "the link carries no hint that it leaves the app")
    }

    /// The credit's words come from `StockPhotoCopy`, never typed inline.
    @Test func theCreditReadsItsStringsFromCopy() throws {
        let code = try SourceScan.production(Self.credit)
        #expect(code.contains("StockPhotoCopy.creditSource"), "the credit doesn't read its link title from StockPhotoCopy")
        #expect(code.contains("StockPhotoCopy.credit("), "the credit doesn't compose from StockPhotoCopy.credit(author:licenseName:)")
        #expect(!code.contains("\"Wikimedia Commons\""), "the credit types \"Wikimedia Commons\" inline")
    }

    /// The badge's words come from `StockPhotoCopy`, never typed inline.
    @Test func theBadgeReadsItsStringsFromCopy() throws {
        let code = try SourceScan.production(Self.badge)
        #expect(code.contains("StockPhotoCopy.badge"), "the badge doesn't read its label from StockPhotoCopy")
        #expect(code.contains("StockPhotoCopy.badgeAccessibilityLabel"), "the badge doesn't read its a11y label from StockPhotoCopy")
        #expect(!code.contains("\"Stock photo\""), "the badge types \"Stock photo\" inline")
        #expect(!code.contains("\"Representative stock image\""), "the badge types its a11y label inline")
    }

    /// The badge uppercases by style, not by string: the view uses
    /// `.textCase(.uppercase)` and the stored copy stays "Stock photo".
    @Test func theBadgeUppercasesByStyleNotByString() throws {
        let code = try SourceScan.production(Self.badge)
        #expect(code.contains(".textCase(.uppercase)"), "the badge doesn't uppercase its label by style")
        #expect(StockPhotoCopy.badge == "Stock photo", "the stored badge string was changed")
    }

    /// The no-author fallback composes correctly (T001 carry-forward): when the
    /// file names no author, the attribution falls back to "Wikimedia Commons"
    /// as the author, and the credit machinery still assembles the full line.
    @Test func theNoAuthorFallbackComposes() {
        let credit = StockPhotoCopy.credit(author: "Wikimedia Commons", licenseName: "Public domain")
        #expect(credit == "Photo: Wikimedia Commons \u{00B7} Public domain \u{00B7} Wikimedia Commons")
    }
}

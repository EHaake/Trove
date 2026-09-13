import Foundation
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

    /// The credit's one `Link` is the accessibility representation's, not a view
    /// in the layout (T015b, plan §6): the paragraph has to wrap, so the tap
    /// target is the `.link` run and VoiceOver gets the `Link` back through
    /// `accessibilityRepresentation`. Still never a `Button` + `openURL`. The
    /// non-identifier-boundary regex is `MarketWiringTests`'
    /// `theOutwardLinkIsALinkNotAButton` pattern, so `NavigationLink(` can't
    /// stand in for it.
    @Test func theCreditComposesALinkNotAButton() throws {
        let code = try SourceScan.production(Self.credit)
        let link = try Regex(#"(?:^|[^A-Za-z0-9_])Link\("#)
        let links = code.ranges(of: link).count
        #expect(links == 1, "the credit draws \(links) links — the represented link is the one and only")
        #expect(code.contains("accessibilityRepresentation"),
                "the credit's link isn't presented through an accessibility representation")
        #expect(!code.contains("openURL"), "the credit opens a URL by hand instead of linking")
        let button = try Regex(#"(?:^|[^A-Za-z0-9_])Button\("#)
        #expect(code.ranges(of: button).isEmpty, "the credit drives its link from a Button")
    }

    /// The `.full` credit is one paragraph that links only its source run and
    /// keeps the whole author (T015b, plan §6): the characters are exactly the
    /// copy string — so a rebuilt-from-pieces or truncated line fails — exactly
    /// one run carries `.link`, that link is the Commons file page, and that
    /// run's characters are exactly `creditSource`, so linking the whole line
    /// fails too. The author is the real Commons worst case.
    @Test func theCreditLinksOnlyItsSourceRunAndKeepsTheWholeAuthor() {
        let attribution = StockPhotoAttribution(
            author: "Rama, Wikimedia Commons, Cc-by-sa-2.0-fr",
            licenseName: "CC BY-SA 2.0 FR",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Nikon_F3.jpg")!
        )
        let credit = StockPhotoCredit.attributedCredit(attribution, theme: .dark)

        let plain = StockPhotoCopy.credit(
            author: attribution.author, licenseName: attribution.licenseName)
        #expect(String(credit.characters) == plain,
                "the credit's words aren't exactly StockPhotoCopy.credit(author:licenseName:)")

        let linked = credit.runs.filter { $0.link != nil }
        #expect(linked.count == 1, "\(linked.count) runs carry a link — exactly the source run should")
        #expect(linked.first?.link == attribution.sourceURL, "the link doesn't open the Commons file page")
        let linkedText = linked.first.map { String(credit.characters[$0.range]) }
        #expect(linkedText == StockPhotoCopy.creditSource,
                "the linked run is \(linkedText ?? "nothing"), not just the source segment")
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

/// The row a11y wiring for the stock thumbnail (T011, criterion 11). The
/// runtime `.accessibilityValue` isn't unit-inspectable — it lives in the view —
/// so the falsifiable decomposition is `PhotoSelection.leadsWithStock`'s own
/// predicate test (in `PhotoSelectionLeadsWithStockTests`) plus this source
/// scan: each row gates its stock announcement on the shared predicate and
/// reads the wording from `StockPhotoCopy`, never inline.
@Suite("Row stock a11y wiring")
struct RowStockA11yTests {
    private static let itemRow = "Trove/Views/Items/ItemRow.swift"
    private static let wishlistView = "Trove/Views/Wishlist/WishlistView.swift"

    /// `ItemRow` announces the stock thumbnail via the shared predicate and the
    /// copy string, never a typed-in literal.
    @Test func itemRowAnnouncesTheStockThumbnailFromTheSharedSources() throws {
        let code = try SourceScan.production(Self.itemRow)
        #expect(code.contains("PhotoSelection.leadsWithStock"),
                "ItemRow doesn't gate its stock a11y value on the shared predicate")
        #expect(code.contains("StockPhotoCopy.badgeAccessibilityLabel"),
                "ItemRow doesn't read its stock a11y wording from StockPhotoCopy")
        #expect(!code.contains("\"Representative stock image\""),
                "ItemRow types its stock a11y wording inline")
    }

    /// `WishlistRow` (inside `WishlistView`) does the same.
    @Test func wishlistRowAnnouncesTheStockThumbnailFromTheSharedSources() throws {
        let code = try SourceScan.production(Self.wishlistView)
        #expect(code.contains("PhotoSelection.leadsWithStock"),
                "WishlistRow doesn't gate its stock a11y value on the shared predicate")
        #expect(code.contains("StockPhotoCopy.badgeAccessibilityLabel"),
                "WishlistRow doesn't read its stock a11y wording from StockPhotoCopy")
        #expect(!code.contains("\"Representative stock image\""),
                "WishlistRow types its stock a11y wording inline")
    }
}

/// The credit's trailing glyph (T015c).
///
/// The T015b device pass found the `arrow.up.right` appended after the link run
/// scaling with Dynamic Type while the theme's fixed-size text beside it did
/// not, and drawing in the primary ink rather than the link's brass — an
/// unstyled `Text(Image(systemName:))` falls through to the environment's body
/// font, and the paragraph's `.tint` reaches `.link` runs and nothing else.
///
/// **This is a source scan because a render cannot see it, which was measured,
/// not assumed.** `ImageRenderer` draws a symbol inside a `Text` as a constant
/// 51x55 white placeholder — identical at `.large` and `.accessibility5`, and
/// identical with or without a font or foreground on the `Text` (a plain
/// `Image` view renders correctly at 13x12 in brass, so the harness itself is
/// fine). A size-comparison test over the real construct therefore passes no
/// matter what the code does: exactly the false-passing shape `CLAUDE.md`
/// warns about, caught here by probing before trusting it. The behaviour is
/// attested on the device instead (T015c's accessibility-XXXL screenshot); what
/// these guards hold is the wiring that produced it.
@Suite("Stock photo credit glyph")
struct StockPhotoCreditGlyphTests {
    private static let credit = "Trove/Views/Shared/StockPhotoCredit.swift"

    /// The glyph takes *the credit's own* font — read out of `attributedCredit`
    /// rather than named here, so changing the credit's base font without
    /// moving the glyph with it goes red, which is the defect restated.
    @Test func theGlyphTakesTheCreditsOwnFixedFont() throws {
        let code = try SourceScan.production(Self.credit)
        let creditFont = try creditBaseFont(in: code)
        let glyph = try body(of: "static func sourceGlyph(theme: Theme) -> Text {", in: code)

        #expect(
            glyph.contains(".font(\(creditFont))"),
            "the glyph doesn't take the credit's own font (\(creditFont)) — it follows Dynamic Type: \(glyph)"
        )
    }

    /// And the brass, which the tint can't hand it.
    @Test func theGlyphCarriesTheBrassItself() throws {
        let code = try SourceScan.production(Self.credit)
        let glyph = try body(of: "static func sourceGlyph(theme: Theme) -> Text {", in: code)

        #expect(
            glyph.contains(".foregroundStyle(theme.colors.accentBrass)"),
            "the glyph carries no brass of its own, so it draws in the primary ink: \(glyph)"
        )
    }

    /// And the paragraph composes the styled glyph rather than a bare one — the
    /// guard that keeps the two above from being bypassed at the call site.
    @Test func theParagraphAppendsTheStyledGlyph() throws {
        let code = try SourceScan.production(Self.credit)
        let full = try body(of: "private var full: some View {", in: code)

        #expect(
            full.contains("Self.sourceGlyph(theme: theme)"),
            "the credit doesn't append the styled glyph: \(full)"
        )
        #expect(
            !full.contains("Text(Image("),
            "the credit appends a bare, unstyled glyph beside the styled one: \(full)"
        )
    }

    // MARK: - Helpers

    /// The font `attributedCredit` sets on the whole credit, as written.
    private func creditBaseFont(in code: String) throws -> String {
        let assignment = try #require(
            code.range(of: "credit.font = "),
            "attributedCredit no longer sets a base font — this guard is measuring nothing"
        )
        let rest = code[assignment.upperBound...]
        let end = try #require(rest.firstIndex(where: { $0.isNewline }), "the base font assignment never ends")
        return String(rest[..<end]).trimmingCharacters(in: .whitespaces)
    }

    /// `TrendArrowWiringTests`' brace matcher: the question is what a single
    /// declaration's body contains.
    private func body(of declaration: String, in code: String) throws -> String {
        let start = try #require(code.range(of: declaration), "\(declaration) is gone")
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 }
            if code[index] == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.upperBound..<index]) }
            }
            index = code.index(after: index)
        }
        Issue.record("\(declaration) never closes")
        return ""
    }
}

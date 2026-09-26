import Foundation
import Testing
@testable import Trove

/// `018`'s header controls — Sort By, the "…", the side switches — as system
/// controls rather than the bespoke badges and dropdowns they replace (plan
/// §1, Q10). The shared wiring each screen's conversion leaves behind lives
/// here, one task at a time; what a view-model test can reach stays in the
/// view-model suites.
///
/// Every scan `#require`s its anchor and compares whole literals, and every
/// call it looks for is matched on a word boundary (plan §7), so a longer
/// name ending in the same word never satisfies it.
@Suite("Header controls wiring")
struct HeaderControlsWiringTests {
    private let toggleCall = #"(?:^|[^A-Za-z0-9_])Toggle\s*\("#

    /// G2: `SortMenu` is a system `Menu` holding one "Sort by" section of
    /// `Toggle` rows built by a `ForEach`, drawn in the glass button style,
    /// and its label is in the system's primary label colour (spec Decisions
    /// 15 and 17, overtaking R3). The glass style paints its label with the
    /// button's tint and ignores the label's own foreground, so the colour is
    /// the tint, set to `.primary` directly after the glass style — overriding
    /// the root brass tint — and the file sets no foreground style, which the
    /// style would ignore (the device showed it staying brass). The file
    /// still names no theme colour.
    ///
    /// **This checks spelling only.** It pins how the menu is composed, not
    /// what iOS draws from it. The checkmark on the current row and the
    /// selected trait VoiceOver reads are the UI test's to guard: the one
    /// header and the rows are checked by `assertMarketSortRows`, and
    /// criterion 11 is checked on the device (plan Q8).
    ///
    /// Mutations (T001): the `Toggle` rows replaced by `Button` rows → red
    /// (the toggle leg); `.foregroundStyle(theme.colors.accentBrass)` on the
    /// label → red (the no-colour leg). T004a: the label's
    /// `.foregroundStyle(.primary)` removed → red (the system-colour leg, as
    /// it was then). T004b: the tint removed → red (the tint leg).
    @Test func theSortMenuIsASystemMenuOfToggleRowsUnderOneHeaderInGlassWithNoColourOfItsOwn() throws {
        let code = try SourceScan.production("Trove/Views/Shared/SortMenu.swift")
        let anchor = "struct SortMenu<Option: Hashable>: View"
        try #require(code.contains(anchor), "SortMenu.swift no longer declares `\(anchor)`")
        let bodies = SourceScan.closureBodies(after: "var body: some View", in: code)
        try #require(bodies.count == 1, "SortMenu.swift declares \(bodies.count) bodies, expected exactly 1")
        let body = try #require(bodies.first)

        #expect(body.contains("Menu {"), "Sort By is no longer a system `Menu`: \(body)")
        let sections = SourceScan.closureBodies(after: "Section(SortMenuCopy.header)", in: body)
        try #require(sections.count == 1, "Sort By opens \(sections.count) sections under `SortMenuCopy.header`, expected exactly 1 — the one \"Sort by\" header: \(body)")
        let section = try #require(sections.first)
        let rows = SourceScan.closureBodies(after: "ForEach(", in: section)
        try #require(rows.count == 1, "Sort By's section builds its rows with \(rows.count) `ForEach`es, expected exactly 1: \(section)")
        let row = try #require(rows.first)
        #expect(
            row.contains(try Regex(toggleCall)),
            "Sort By's rows are no longer `Toggle`s, so nothing draws the current sort checked: \(row)"
        )
        #expect(body.contains(".buttonStyle(.glass)"), "Sort By's badge isn't a glass button: \(body)")
        let labels = SourceScan.closureBodies(after: "} label:", in: body)
        try #require(labels.count == 1, "Sort By's `Menu` opens \(labels.count) label closures, expected exactly 1: \(body)")
        #expect(
            body.contains(try Regex(#"\.buttonStyle\(\.glass\)\s*\.tint\(\.primary\)"#)),
            "Sort By's glass button isn't tinted `.primary` directly after `.buttonStyle(.glass)`, so the root brass tint colours its label again (spec Decision 17): \(body)"
        )
        #expect(
            !code.contains(".foregroundStyle("),
            "SortMenu.swift sets a foreground style — the glass style ignores it and paints the label with the tint (spec Decision 17)"
        )
        #expect(
            !code.contains("theme.colors"),
            "SortMenu.swift names a theme colour — the badge draws no colour of its own (R3)"
        )
    }

    /// G3, one control at a time as each is converted: every header control
    /// keeps the identifier the UI tests find it by, and carries no hint — a
    /// system menu's button announces itself as a pop-up button, which is the
    /// job "Opens sort options" did for a bespoke button (criterion 11).
    ///
    /// Mutations: the Items sort control's identifier dropped → red (T001);
    /// the Plans sort control's identifier dropped → red, and the Wishlist's
    /// "Opens sort options" hint put back → red (T004).
    @Test func everyConvertedHeaderControlKeepsItsIdentifierAndCarriesNoHint() throws {
        for (path, identifier) in [
            ("Trove/Views/Items/ItemListView.swift", "sortOptions.items"),
            ("Trove/Views/Wishlist/WishlistView.swift", "sortOptions.wishlist"),
            ("Trove/Views/Plans/PlansView.swift", "sortOptions.plans"),
        ] {
            let code = try SourceScan.production(path)
            let controls = SourceScan.closureBodies(after: "private var sortControl: some View", in: code)
            try #require(controls.count == 1, "\(path) declares \(controls.count) `sortControl`s, expected exactly 1")
            let control = try #require(controls.first)
            #expect(
                control.contains(".accessibilityIdentifier(\"\(identifier)\")"),
                "\(path): the sort control lost its identifier `\(identifier)`: \(control)"
            )
            #expect(
                !control.contains(".accessibilityHint("),
                "\(path): the sort control carries a hint again — the system menu announces itself (criterion 11): \(control)"
            )
        }
    }
}

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
    /// "Opens sort options" hint put back → red (T004); the Dashboard's
    /// `moreActions.dashboard` dropped → red (T005); the Dashboard's
    /// `orderOptions.dashboard` dropped → red (T006).
    @Test func everyConvertedHeaderControlKeepsItsIdentifierAndCarriesNoHint() throws {
        for (path, anchor, identifier) in [
            ("Trove/Views/Items/ItemListView.swift", "private var sortControl: some View", "sortOptions.items"),
            ("Trove/Views/Wishlist/WishlistView.swift", "private var sortControl: some View", "sortOptions.wishlist"),
            ("Trove/Views/Plans/PlansView.swift", "private var sortControl: some View", "sortOptions.plans"),
            ("Trove/Views/Items/ItemListView.swift", "private var overflowControl: some View", "moreActions.items"),
            ("Trove/Views/Wishlist/WishlistView.swift", "private var overflowControl: some View", "moreActions.wishlist"),
            ("Trove/Views/Plans/PlansView.swift", "private var overflowControl: some View", "moreActions.plans"),
            ("Trove/Views/Dashboard/DashboardView.swift", "private var overflowControl: some View", "moreActions.dashboard"),
            ("Trove/Views/Dashboard/DashboardView.swift", "private var orderControl: some View", "orderOptions.dashboard"),
        ] {
            let code = try SourceScan.production(path)
            let controls = SourceScan.closureBodies(after: anchor, in: code)
            try #require(controls.count == 1, "\(path) declares \(controls.count) `\(anchor)`s, expected exactly 1")
            let control = try #require(controls.first)
            #expect(
                control.contains(".accessibilityIdentifier(\"\(identifier)\")"),
                "\(path): the control lost its identifier `\(identifier)`: \(control)"
            )
            #expect(
                !control.contains(".accessibilityHint("),
                "\(path): the `\(identifier)` control carries a hint again — the system menu announces itself (criterion 11): \(control)"
            )
        }
    }

    /// G4 (criterion 4, plan §2): `OverflowMenu`'s busy branch — while an
    /// export or import runs the glyph gives way to the spinner, the whole
    /// control is inert, and it is spoken "Working" rather than "More
    /// actions" — and each list feeds it the view model's busy state. No UI
    /// test can hold an export mid-run, so the branch is read from the body.
    /// It is drawn like the sort badge beside it: the glass style with the
    /// system's label colour set as the tint directly after it (spec Decision
    /// 17), and no hint, since a menu's button announces itself (criterion
    /// 11).
    ///
    /// **This checks spelling only**, as G2 does: the spinner on screen is
    /// the device pass's to see.
    ///
    /// Mutations (T005): `.disabled(isBusy)` removed → red; `isBusy: false`
    /// on the Items list → red; the tint removed → red.
    @Test func theOverflowMenuShowsTheSpinnerAndIsInertWhileBusyAndEachListFeedsIt() throws {
        let code = try SourceScan.production("Trove/Views/Shared/OverflowMenu.swift")
        let anchor = "struct OverflowMenu<Content: View>: View"
        try #require(code.contains(anchor), "OverflowMenu.swift no longer declares `\(anchor)`")
        let bodies = SourceScan.closureBodies(after: "var body: some View", in: code)
        try #require(bodies.count == 1, "OverflowMenu.swift declares \(bodies.count) bodies, expected exactly 1")
        let body = try #require(bodies.first)

        #expect(body.contains("Menu {"), "the \"…\" is no longer a system `Menu`: \(body)")
        let busy = SourceScan.closureBodies(after: "if isBusy", in: body)
        try #require(busy.count == 1, "the \"…\"'s label branches on `isBusy` \(busy.count) times, expected exactly 1: \(body)")
        #expect(busy[0].contains("ProgressView()"), "the busy branch doesn't show the spinner: \(busy[0])")
        #expect(!busy[0].contains("Image(systemName:"), "the busy branch still draws the glyph: \(busy[0])")
        #expect(body.contains("Image(systemName: \"ellipsis\")"), "the idle branch doesn't show the ellipsis: \(body)")
        #expect(body.contains(".disabled(isBusy)"), "the \"…\" isn't inert while busy: \(body)")
        #expect(
            body.contains(".accessibilityLabel(isBusy ? \"Working\" : \"More actions\")"),
            "the \"…\" isn't spoken \"Working\" while busy and \"More actions\" otherwise: \(body)"
        )
        #expect(!code.contains(".accessibilityHint("), "the \"…\" carries a hint — the system menu announces itself (criterion 11)")
        #expect(
            body.contains(try Regex(#"\.buttonStyle\(\.glass\)\s*\.tint\(\.primary\)"#)),
            "the \"…\"'s glass button isn't tinted `.primary` directly after `.buttonStyle(.glass)`, so the root brass tint colours its glyph (spec Decision 17): \(body)"
        )
        #expect(!code.contains("theme.colors"), "OverflowMenu.swift names a theme colour — the badge draws no colour of its own")

        for path in ["Trove/Views/Items/ItemListView.swift", "Trove/Views/Wishlist/WishlistView.swift"] {
            let screen = try SourceScan.production(path)
            let calls = SourceScan.argumentLists(of: "OverflowMenu", in: screen)
            #expect(
                calls == ["isBusy: viewModel.isBusy"],
                "\(path) doesn't feed its one \"…\" the view model's busy state: \(calls)"
            )
        }
    }

    /// G5, its first leg (`013` spec Decision 16, carried): the Dashboard's
    /// "…" stands on the root alone — `overflowControl` is used inside exactly
    /// one `if isRoot` span and nowhere else, and it is the system menu.
    ///
    /// Its mutation (T005): `overflowControl` moved outside the `if isRoot`
    /// gate → red.
    @Test func theDashboardsOverflowMenuStandsOnTheRootAlone() throws {
        let code = try SourceScan.production("Trove/Views/Dashboard/DashboardView.swift")
        let controls = SourceScan.closureBodies(after: "private var overflowControl: some View", in: code)
        try #require(controls.count == 1, "DashboardView declares \(controls.count) `overflowControl`s, expected exactly 1")
        #expect(controls[0].contains("OverflowMenu("), "the Dashboard's \"…\" isn't the system menu: \(controls[0])")

        let rootSpans = SourceScan.closureBodies(after: "if isRoot", in: code)
        try #require(!rootSpans.isEmpty, "no `if isRoot` gates — wrong scan target?")
        #expect(
            rootSpans.filter { $0.contains("overflowControl") }.count == 1,
            "the Dashboard's \"…\" must be gated on `isRoot`, in exactly one span"
        )
        let uses = code.ranges(of: try Regex(#"(?:^|[^A-Za-z0-9_])overflowControl(?![A-Za-z0-9_])"#)).count
        #expect(uses == 2, "`overflowControl` appears \(uses) times in the Dashboard, expected 2 — its declaration and its one gated use")
    }

    /// G5, its order legs (plan §3, R5): the Dashboard's order control is a
    /// system `Menu` holding one "Order by" section of `Toggle` rows built by
    /// one `ForEach` over `BreakdownOrder.allCases`, each row's setter
    /// writing the order and reloading; its label is the mock's mono text,
    /// and nothing in the control is glass — the label sits inside the
    /// breakdown card, in the body, where a glass capsule inside a plate is
    /// the stacking P8 forbids (Decision 13).
    ///
    /// **This checks spelling only**, as G2 does: the one header, the
    /// checked row and the chosen order on screen are
    /// `testTheOverviewsOrderMenuOffersValueAndCountUnderOrderBy`'s to guard.
    ///
    /// Mutations (T006): `viewModel.load()` dropped from the setter → red
    /// (the reload leg); `.buttonStyle(.glass)` on the label → red (the
    /// no-glass leg).
    @Test func theDashboardsOrderControlIsASystemMenuOfToggleRowsUnderOrderByOnTheMonoLabel() throws {
        let code = try SourceScan.production("Trove/Views/Dashboard/DashboardView.swift")
        let controls = SourceScan.closureBodies(after: "private var orderControl: some View", in: code)
        try #require(controls.count == 1, "DashboardView declares \(controls.count) `orderControl`s, expected exactly 1")
        let control = try #require(controls.first)

        #expect(control.contains("Menu {"), "the order control is no longer a system `Menu`: \(control)")
        let sections = SourceScan.closureBodies(after: "Section(\"Order by\")", in: control)
        try #require(sections.count == 1, "the order control opens \(sections.count) \"Order by\" sections, expected exactly 1: \(control)")
        let section = try #require(sections.first)
        let rows = SourceScan.closureBodies(after: "ForEach(DashboardViewModel.BreakdownOrder.allCases)", in: section)
        try #require(rows.count == 1, "the \"Order by\" section builds its rows over `BreakdownOrder.allCases` with \(rows.count) `ForEach`es, expected exactly 1: \(section)")
        let row = try #require(rows.first)
        #expect(
            row.contains(try Regex(toggleCall)),
            "the order rows are no longer `Toggle`s, so nothing draws the current order checked: \(row)"
        )
        let setters = SourceScan.closureBodies(after: "set:", in: row)
        try #require(setters.count == 1, "the order row's binding has \(setters.count) setters, expected exactly 1: \(row)")
        let setter = try #require(setters.first)
        #expect(setter.contains("viewModel.breakdownOrder = order"), "choosing an order no longer writes it: \(setter)")
        #expect(setter.contains("viewModel.load()"), "choosing an order no longer reloads the breakdown: \(setter)")

        let labels = SourceScan.closureBodies(after: "} label:", in: control)
        try #require(labels.count == 1, "the order control's `Menu` opens \(labels.count) label closures, expected exactly 1: \(control)")
        #expect(labels[0].contains(".monoLabel("), "the order control's label is no longer the mock's mono text: \(labels[0])")
        #expect(!control.contains(".glass"), "the order control wears glass — it sits in the body, inside a card (Decision 13, P8): \(control)")
    }
}

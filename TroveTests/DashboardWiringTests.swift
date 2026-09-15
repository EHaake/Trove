import Foundation
import Testing
@testable import Trove

/// T016. How the Dashboard hangs its Sold card, pinned as source scans — the
/// `SoldStateWiringTests` / `MarketWiringTests` shape, and for the same
/// reason: no unit test can read a rendered screen, and what a scan *can*
/// catch is the wiring quietly changing out from under the spec (criterion 6,
/// plan §6).
///
/// The figures themselves are `DashboardViewModelTests`' business (G22, G23).
/// What lives here is everything between those figures and the screen: that
/// the card exists only when something in scope has been sold, that it sits
/// apart from the collection's totals, that it says the view model's words
/// rather than words of its own, and that tapping it leaves for the Sold side.
///
/// Every scan `#require`s its anchor before asserting anything about it
/// (`CLAUDE.md` Testing, plan §10): a branch that has been renamed away fails
/// loudly here rather than passing over a span that no longer exists.
@Suite("Dashboard wiring")
struct DashboardWiringTests {
    private nonisolated static let dashboard = "Trove/Views/Dashboard/DashboardView.swift"
    private nonisolated static let card = "Trove/Views/Dashboard/SoldCard.swift"

    /// The scrolling half of `body`, which every layout scan below works over:
    /// the whole file would also see the preview and the helpers, and the
    /// claim is about what the screen *composes*.
    private func scrollContent() throws -> String {
        let code = try SourceScan.production(Self.dashboard)
        let bodies = SourceScan.closureBodies(after: "ScrollView", in: code)
        try #require(bodies.count == 1, "the Dashboard has \(bodies.count) ScrollViews, expected exactly 1")
        return try #require(bodies.first)
    }

    /// The sales branch — `#require`d to be found exactly once, so nothing
    /// below can assert over an empty string. Mutation: rename the
    /// `if viewModel.hasSales` anchor → this fails.
    private func salesBranch() throws -> String {
        let content = try scrollContent()
        let branches = SourceScan.closureBodies(after: "if viewModel.hasSales", in: content)
        try #require(
            branches.count == 1,
            "the Dashboard has \(branches.count) `if viewModel.hasSales` branches, expected exactly 1"
        )
        return try #require(branches.first)
    }

    // MARK: - When the card exists at all (criterion 6)

    /// The card is composed, and composed only behind `hasSales` — the spec's
    /// "hides entirely when nothing in scope has been sold". Mutation: render
    /// it unconditionally → the count inside the branch drops to zero.
    @Test func theCardIsComposedOnlyBehindTheSalesGate() throws {
        let content = try scrollContent()
        let branch = try salesBranch()

        #expect(branch.contains("SoldCard("), "the sales branch doesn't compose the Sold card")
        #expect(
            content.ranges(of: "SoldCard(").count == 1,
            "the Sold card is composed more than once — a Dashboard with no sales would show one"
        )
    }

    /// Where it sits: after the un-valued callout, before the breakdown, and
    /// outside `spentAndGain` and the headline — which is what the spec's
    /// "sits apart from the totals" means structurally (plan §6). The scoped
    /// copy inherits it, being this same view narrowed.
    @Test func theCardSitsBetweenTheCalloutAndTheBreakdownAndInsideNoFigure() throws {
        let content = try scrollContent()

        let callout = try #require(content.range(of: "unvaluedCallout"), "the un-valued callout is gone — wrong target?")
        let gate = try #require(content.range(of: "if viewModel.hasSales"))
        let breakdown = try #require(content.range(of: "breakdown"), "the breakdown is gone — wrong target?")

        #expect(callout.upperBound < gate.lowerBound, "the Sold card is composed above the un-valued callout")
        #expect(gate.upperBound < breakdown.lowerBound, "the Sold card is composed below the breakdown")

        let code = try SourceScan.production(Self.dashboard)
        for figure in ["private var spentAndGain", "private var headline"] {
            let bodies = SourceScan.closureBodies(after: figure, in: code)
            try #require(bodies.count == 1, "\(figure) declares \(bodies.count) bodies, expected exactly 1")
            #expect(
                bodies[0].contains("SoldCard(") == false,
                "\(figure) draws the Sold card — sold money and collection money must never sit in one figure"
            )
        }
    }

    // MARK: - What it says and where it goes (criterion 6)

    /// Tapping it lands on the Items tab's Sold side, through the router the
    /// breakdown's own rows go through — not by reaching into the list's
    /// state.
    @Test func tappingTheCardAsksTheRouterForTheSoldSide() throws {
        let branch = try salesBranch()

        let closures = SourceScan.closureBodies(after: "SoldCard(", in: branch)
        try #require(closures.count == 1, "the Sold card has \(closures.count) trailing closures, expected exactly 1")
        #expect(
            closures[0].contains("router.showSoldItems()"),
            "the Sold card's action doesn't show the Sold side: \(closures[0])"
        )
    }

    /// Both lines are the view model's — `SaleCopy` composed once, where the
    /// Sold side's summary composes it too, so the card and the summary cannot
    /// disagree (AC7). Mutation: put a literal in place of either line → red.
    @Test func theCardShowsTheViewModelsTwoLinesRatherThanWordsOfItsOwn() throws {
        let branch = try salesBranch()

        let arguments = SourceScan.argumentLists(of: "SoldCard", in: branch)
        try #require(arguments.count == 1, "the branch builds \(arguments.count) Sold cards, expected exactly 1")
        let composed = try #require(arguments.first)

        #expect(
            composed.contains("viewModel.soldLine"),
            "the card's figures aren't the view model's soldLine: \(composed)"
        )
        #expect(
            composed.contains("viewModel.soldDeltaLine"),
            "the card's realised line isn't the view model's soldDeltaLine: \(composed)"
        )

        // And the card can't quietly compose its own: the only string it may
        // type is the header, which is `SaleCopy`'s word.
        let card = try SourceScan.production(Self.card)
        for composer in ["SaleCopy.dashboardSummary(", "SaleCopy.realised(", "formattedAs"] {
            #expect(
                card.contains(composer) == false,
                "SoldCard composes \(composer) itself — the figures would exist in two places"
            )
        }
        #expect(card.contains("SaleCopy.cardHeader"), "the card's header isn't SaleCopy's word")
    }

    /// The realised line's colour follows the model's rule, not a sign test
    /// re-derived in the view (plan Q11). The rust/moss tokens themselves are
    /// checked across all three sold surfaces by `SoldStateWiringTests`;
    /// what's pinned here is that this one reads `isLoss` to choose between
    /// them. Mutation: swap `isLoss` for `realisedDeltaCents < 0` → red.
    @Test func theRealisedLinesColourComesFromTheModelsLossRule() throws {
        let card = try SourceScan.production(Self.card)

        #expect(card.contains("isLoss"), "the card picks its colour without reading SaleOutcome.isLoss")
        #expect(
            card.contains("realisedDeltaCents < 0") == false,
            "the card tests the sign of the delta itself instead of asking the model"
        )
        #expect(
            card.contains("deltaColor"),
            "the realised line no longer takes a colour of its own — wrong target?"
        )
    }

    // MARK: - VoiceOver (criterion 16)

    /// One stop, one hint, and the identifier T018's UI test taps.
    @Test func theCardIsOneElementWithAHintAndAnIdentifier() throws {
        let card = try SourceScan.production(Self.card)

        #expect(
            card.contains(".accessibilityElement(children: .combine)"),
            "the Sold card isn't announced as one element (criterion 16)"
        )
        #expect(card.contains(".accessibilityHint("), "the Sold card says nothing about where it goes")
        #expect(card.contains("dashboard.soldCard"), "the Sold card carries no identifier")
    }
}

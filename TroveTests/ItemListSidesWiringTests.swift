import Foundation
import Testing
@testable import Trove

/// T015. How the Items tab's two sides are wired, pinned as source scans —
/// the `SoldStateWiringTests` / `ImportWiringTests` shape, for the same
/// reason: no unit test can tap a switch or swipe a row, and what a scan
/// *can* catch is one side quietly acquiring the other's controls (criteria
/// 1, 7 and 16, plan §4 and Q15).
///
/// Every scan `#require`s its anchor before asserting anything about it
/// (`CLAUDE.md` Testing, plan §10): a branch renamed away fails loudly here
/// rather than passing over a span that no longer exists.
@Suite("Item list sides wiring")
struct ItemListSidesWiringTests {
    private nonisolated static let list = "Trove/Views/Items/ItemListView.swift"
    private nonisolated static let control = "Trove/Views/Items/SideSwitch.swift"

    private func code() throws -> String {
        try SourceScan.production(Self.list)
    }

    /// The body of a declaration in the list, brace-matched and `#require`d to
    /// be found exactly once — so nothing below asserts over an empty string.
    private func body(of declaration: String) throws -> String {
        let bodies = SourceScan.closureBodies(after: declaration, in: try code())
        try #require(
            bodies.count == 1,
            "ItemListView declares \(bodies.count) `\(declaration)`, expected exactly 1"
        )
        return try #require(bodies.first)
    }

    // MARK: - The two branches

    /// The rows follow the side, and the Sold branch draws the Sold row over
    /// the view model's sold array — not a filtered pass over `items`, which
    /// the split in `load()` (G13) has already excluded them from.
    @Test func theRowsFollowTheSideAndTheSoldBranchDrawsTheSoldRow() throws {
        let rows = try body(of: "private var rows: some View")

        #expect(rows.contains("case .owned: ownedRows"), "the Owned side isn't wired to its own rows: \(rows)")
        #expect(rows.contains("case .sold: soldRows"), "the Sold side isn't wired to its own rows: \(rows)")

        let sold = try body(of: "private var soldRows: some View")
        #expect(sold.contains("SoldItemRow("), "the Sold side doesn't compose SoldItemRow")
        #expect(sold.contains("viewModel.soldItems"), "the Sold rows are built from something other than `soldItems`")
        #expect(sold.contains("router.itemsPath.append"), "a sold row doesn't open its item's page")
    }

    /// Criterion 7 and P16: no Sort By and no search field on the Sold side.
    /// Both halves of the claim — the branch carries neither, and the file
    /// composes each exactly once, inside the one gate that names the side.
    @Test func theSoldSideRendersNoSortControlAndNoSearchField() throws {
        let code = try code()
        let sold = try body(of: "private var soldRows: some View")

        #expect(!sold.contains("SearchField("), "the Sold side renders a search field")
        #expect(!sold.contains("sortControl"), "the Sold side renders the sort control")

        // The gate itself, which is what actually keeps them off that side —
        // one spelling in both places (the sort badge, and the search field
        // with the chips). Mutation: drop the `viewModel.side == .owned`
        // clause from either → the count falls to 1 and this fails.
        let gate = "if viewModel.totalCount > 0, viewModel.side == .owned"
        #expect(
            code.ranges(of: gate).count == 2,
            "the screen spells the narrowing gate \(code.ranges(of: gate).count) times, expected 2 — one of them no longer names the side"
        )

        let gated = SourceScan.closureBodies(after: gate, in: code)
        try #require(gated.count == 2, "the gate opens \(gated.count) spans, expected 2 (the sort badge, and the search field with the chips)")
        let inside = gated.joined(separator: "\n")
        #expect(inside.contains("sortControl"), "the sort control sits outside the gate")
        #expect(inside.contains("SearchField("), "the search field sits outside the gate")
        #expect(inside.contains("categoryChips"), "the chip row sits outside the gate")

        // Each appears once in the whole screen, so the gated copy above is
        // the only copy. Two uses of `sortControl` — its declaration and the
        // gated use — and one `SearchField(`, which `categoryChips` renders
        // none of.
        #expect(
            code.ranges(of: "SearchField(").count == 1,
            "the screen composes \(code.ranges(of: "SearchField(").count) search fields — one of them is outside the gate"
        )
        #expect(
            code.ranges(of: "sortControl").count == 2,
            "the screen names `sortControl` \(code.ranges(of: "sortControl").count) times — its declaration plus one gated use is two"
        )
    }

    /// Criterion 1, from the list's side: the swipe on an owned row offers
    /// Edit, Copy and Delete, and nothing about selling — marking sold is an
    /// action on the item's own page.
    @Test func theOwnedRowsSwipesDoNotOfferMarkAsSold() throws {
        let owned = try body(of: "private var ownedRows: some View")

        let trailing = SourceScan.closureBodies(after: ".swipeActions(edge: .trailing)", in: owned)
        try #require(trailing.count == 1, "the Owned rows carry \(trailing.count) trailing swipe blocks, expected exactly 1")
        let leading = SourceScan.closureBodies(after: ".swipeActions(edge: .leading)", in: owned)
        try #require(leading.count == 1, "the Owned rows carry \(leading.count) leading swipe blocks, expected exactly 1")

        for block in trailing + leading {
            #expect(!block.contains("SaleCopy"), "an Owned row's swipe names SaleCopy (criterion 1): \(block)")
        }
        #expect(!owned.contains("SaleCopy.markAsSold"), "the Items list's swipe offers Mark as sold… (criterion 1)")
    }

    /// The Sold row's gestures, exactly: a trailing delete that stages the
    /// same alert, no leading swipe, no drag.
    @Test func theSoldRowsCarryOnlyTheTrailingDelete() throws {
        let sold = try body(of: "private var soldRows: some View")

        let trailing = SourceScan.closureBodies(after: ".swipeActions(edge: .trailing)", in: sold)
        try #require(trailing.count == 1, "the Sold rows carry \(trailing.count) trailing swipe blocks, expected exactly 1")
        #expect(
            trailing[0].contains("pendingDeletion = item"),
            "the Sold side's swipe deletes without staging the alert: \(trailing[0])"
        )

        #expect(!sold.contains(".swipeActions(edge: .leading)"), "a sold row offers Edit or Copy on a leading swipe")
        #expect(!sold.contains(".onMove"), "the Sold side is draggable — its order is the sale dates' (P16)")
    }

    // MARK: - The switch (plan Q15)

    /// The one call site, and the whole of Q15 as the view can express it:
    /// the switch reports a tap through `show(_:)`, and binds to nothing.
    ///
    /// Mutation: bind it to a `side` setter (`SideSwitch(side: $viewModel.side)`)
    /// → both expectations fail.
    @Test func theSwitchReportsThroughShowAndBindsToNothing() throws {
        let code = try code()

        let calls = SourceScan.argumentLists(of: "SideSwitch", in: code)
        try #require(calls.count == 1, "the screen composes \(calls.count) side switches, expected exactly 1")
        let call = try #require(calls.first)

        #expect(call.contains("viewModel.show"), "the switch doesn't call `show(_:)`: \(call)")
        #expect(!call.contains("$viewModel.side"), "the switch is bound to `side` itself, skipping the clearing `show(_:)` does: \(call)")
    }

    /// Plan §4: the switch lives in the standing header, so it is on screen
    /// over an empty Owned side exactly as it is over rows. Mutation: move
    /// the `SideSwitch(` call inside either branch → it lands in this span.
    @Test func theSwitchStandsOutsideTheEmptyState() throws {
        let branches = try body(of: "if let reason = viewModel.emptyReason")

        #expect(
            !branches.contains("SideSwitch("),
            "the switch is composed inside the empty-state branch, so an emptied side would lose it"
        )
        #expect(
            branches.contains("emptyState(reason)"),
            "the empty-state branch no longer shows the empty state — wrong span?"
        )
    }

    /// The Dashboard's Sold card lands here, and the side carries no
    /// narrowing to ask for: one call, nothing else in the case.
    @Test func theSoldRequestIsExactlyOneShowCall() throws {
        let apply = try body(of: "private func apply(_ request: AppRouter.ItemsRequest?)")

        let marker = try #require(apply.range(of: "case .sold:"), "`apply` no longer handles the Sold request")
        // The `.sold` case is written last, so its statements run to the
        // switch's own closing brace.
        let rest = apply[marker.upperBound...]
        let end = try #require(rest.firstIndex(of: "}"), "the switch in `apply` never closes")
        let statements = rest[..<end].trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(
            statements == "viewModel.show(.sold)",
            "the Sold request does more (or less) than one `show(.sold)`: \(statements)"
        )

        // Its two neighbours cross to the Owned side *before* writing the
        // narrowing they came to set (plan Q15).
        for request in ["case .category(let path):", "case .unvalued:"] {
            let start = try #require(apply.range(of: request), "`apply` no longer handles \(request)")
            let branch = apply[start.upperBound...]
            let show = try #require(branch.range(of: "viewModel.show(.owned)"), "\(request) doesn't cross to the Owned side")
            let write = try #require(
                branch.range(of: "viewModel.categoryFilter"),
                "\(request) no longer sets the category filter — wrong span?"
            )
            #expect(
                show.upperBound < write.lowerBound,
                "\(request) writes its narrowing before `show(.owned)`, which would clear it again"
            )
        }
    }

    // MARK: - The summary and the empty state

    /// The line above the Sold rows is the view model's — the same
    /// `SaleTotals` the Dashboard card reads (criterion 7's "its summary
    /// matches the card"), never a sum composed here.
    @Test func theSoldSideReadsTheViewModelsSummaryLine() throws {
        let meta = try body(of: "private var metaLine: some View")

        #expect(meta.contains("viewModel.soldSummaryLine"), "the Sold side composes its own summary: \(meta)")
        #expect(meta.contains("Text(summaryLine)"), "the Owned side lost its running total: \(meta)")
        #expect(
            !meta.contains("SaleCopy.soldSideSummary"),
            "the header composes the summary string itself instead of reading the view model's"
        )
    }

    /// The Sold side's empty state says the Sold side's words and offers no
    /// action (Design pass) — and reads both of them from `SaleCopy`.
    @Test func theNothingSoldStateReadsTheSoldCopyAndOffersNoAction() throws {
        let code = try code()

        let states = SourceScan.argumentLists(of: "EmptyStateView", in: code)
            .filter { $0.contains("SaleCopy.nothingSoldHeadline") }
        try #require(states.count == 1, "\(states.count) empty states read the nothing-sold headline, expected exactly 1")
        let state = try #require(states.first)

        #expect(state.contains("SaleCopy.nothingSoldDetail"), "the nothing-sold state types its own detail line")
        #expect(!state.contains("action:"), "the nothing-sold state offers an action — there is nothing to do from here")
    }

    /// Spec Decision 12's state on the screen: its own two words from
    /// `SaleCopy`, and the first-launch state's mark and Add button — the
    /// same door "Add something new." is inviting the person through.
    @Test func theEverythingSoldStateReadsItsCopyAndKeepsTheAddItemDoor() throws {
        let code = try code()

        let states = SourceScan.argumentLists(of: "EmptyStateView", in: code)
            .filter { $0.contains("SaleCopy.everythingSoldHeadline") }
        try #require(states.count == 1, "\(states.count) empty states read the everything-sold headline, expected exactly 1")
        let state = try #require(states.first)

        #expect(state.contains("SaleCopy.everythingSoldDetail"), "the everything-sold state types its own detail line")
        #expect(state.contains(".asset(\"TabItems\")"), "the everything-sold state doesn't carry the Items mark")
        #expect(state.contains("isAddingItem = true"), "the everything-sold state offers no way to add something new")
    }

    // MARK: - The control itself (criterion 16)

    /// What the switch says, and to whom: `SaleCopy`'s two words on screen,
    /// one identifier, a label for the pair and the selected trait on the half
    /// that is showing.
    @Test func theSwitchIsLabelledAndMarksItsActiveHalfSelected() throws {
        let code = try SourceScan.production(Self.control)

        #expect(code.contains("SaleCopy.owned"), "the switch types its own \"Owned\"")
        #expect(code.contains("SaleCopy.sold"), "the switch types its own \"Sold\"")
        #expect(code.contains("\"items.sideSwitch\""), "the switch carries no identifier")
        #expect(code.contains("\"Owned or sold\""), "the switch isn't labelled for VoiceOver (criterion 16)")
        #expect(code.contains(".accessibilityValue("), "the switch doesn't say which side is showing (criterion 16)")
        #expect(code.contains(".isSelected"), "the active half isn't announced as selected (criterion 16)")

        // It reports; it never writes. A `@Binding` here would be a second
        // way to change sides, and the one that skips Q15's clearing.
        #expect(!code.contains("@Binding"), "the switch binds the side instead of reporting a tap (plan Q15)")
    }
}

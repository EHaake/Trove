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

    /// G20, the header as one control set over two sides (criteria 3 and 7):
    /// the narrowing gate is spelled once, in two places, and reads the view
    /// model's rule rather than the side; the search field and the sort control
    /// are each composed once and both sit inside it; the sort control is one
    /// `SortMenu` per side, each writing its own selection, the Owned one
    /// alone carrying the manual order (`018` G6); and `apply` writes nothing
    /// before it has crossed to the side it is narrowing.
    ///
    /// Mutations: put a `viewModel.side == .owned` clause back on either gate
    /// → red (the gate count and the no-side-in-the-header expectation);
    /// move `viewModel.searchText = ""` back above `switch request` → red
    /// (the pre-switch span); `manualOrder:` on the Sold menu → red; the
    /// Sold menu writing `viewModel.sortOrder` → red (T001); the Sold menu
    /// writing both orders → red (T004).
    @Test func oneNarrowingGateCoversBothSidesAndEachSideBringsItsOwnSort() throws {
        let code = try code()

        // The gate itself — one spelling in both places (the sort badge, and
        // the search field with the chips), and the rule behind it lives in
        // the view model, so neither place can drift from the other or from
        // what the rows are actually showing (plan Q10).
        let gate = "if viewModel.offersNarrowingControls"
        #expect(
            code.ranges(of: gate).count == 2,
            "the screen spells the narrowing gate \(code.ranges(of: gate).count) times, expected 2 — the sort badge and the search field with the chips"
        )
        #expect(
            !code.contains("viewModel.side == .owned"),
            "the header gates a narrowing control on the side again — since 014 both sides narrow (criterion 3)"
        )

        let gated = SourceScan.closureBodies(after: gate, in: code)
        try #require(gated.count == 2, "the gate opens \(gated.count) spans, expected 2 (the sort badge, and the search field with the chips)")
        let inside = gated.joined(separator: "\n")
        #expect(inside.contains("sortControl"), "the sort control sits outside the gate")
        #expect(inside.contains("SearchField("), "the search field sits outside the gate")
        #expect(inside.contains("categoryChips"), "the chip row sits outside the gate")

        // Each appears once in the whole screen, so the gated copy above is
        // the only copy — one control set, shared, rather than a second copy
        // grown on the Sold side. Two uses of `sortControl` — its declaration
        // and the gated use — and one `SearchField(`, which `categoryChips`
        // renders none of.
        #expect(
            code.ranges(of: "SearchField(").count == 1,
            "the screen composes \(code.ranges(of: "SearchField(").count) search fields — one of them is outside the gate"
        )
        #expect(
            code.ranges(of: "sortControl").count == 2,
            "the screen names `sortControl` \(code.ranges(of: "sortControl").count) times — its declaration plus one gated use is two"
        )

        // The control names whichever side's order is showing, aloud, rather
        // than the Owned side's through both (014 plan §6).
        let control = try body(of: "private var sortControl: some View")
        #expect(
            control.contains(".accessibilityLabel(\"Sort by \\(viewModel.visibleSortLabel)\")"),
            "the sort control's spoken label reads a side's order directly instead of the visible label: \(control)"
        )

        // One menu per side, over that side's own options, writing that
        // side's own selection (018 plan §1, G6).
        #expect(
            control.ranges(of: "SortMenu(").count == 2,
            "`sortControl` composes \(control.ranges(of: "SortMenu(").count) sort menus, expected 2 — one per side"
        )
        // A `case` has no braces to span, so the branches are cut at their
        // own labels: Owned runs to the Sold label, Sold to the end.
        let ownedCase = try #require(control.range(of: "case .owned:"), "`sortControl` has no Owned branch: \(control)")
        let soldCase = try #require(control.range(of: "case .sold:"), "`sortControl` has no Sold branch: \(control)")
        try #require(ownedCase.upperBound <= soldCase.lowerBound, "`sortControl`'s Sold branch comes before its Owned branch — the cut below assumes the other order")
        let owned = String(control[ownedCase.upperBound..<soldCase.lowerBound])
        let sold = String(control[soldCase.upperBound...])
        let ownedMenu = try #require(
            SourceScan.argumentLists(of: "SortMenu", in: owned).first,
            "the Owned branch composes no `SortMenu`: \(owned)"
        )
        #expect(ownedMenu.contains("options: ItemListViewModel.SortOrder.allCases"), "the Owned menu isn't over the Owned side's orders: \(ownedMenu)")
        #expect(ownedMenu.contains("selection: viewModel.sortOrder"), "the Owned menu doesn't show the Owned side's selection: \(ownedMenu)")
        #expect(ownedMenu.contains("manualOrder: .custom"), "the Owned menu's Custom row lost its reorder subtitle (P3): \(ownedMenu)")
        let ownedSelect = try #require(
            SourceScan.closureBodies(after: ownedMenu, in: owned).first,
            "the Owned menu selects nothing"
        )
        #expect(
            ownedSelect.contains("viewModel.sortOrder = $0") && !ownedSelect.contains("soldSortOrder"),
            "the Owned menu writes something other than the Owned side's order: \(ownedSelect)"
        )

        let soldMenu = try #require(
            SourceScan.argumentLists(of: "SortMenu", in: sold).first,
            "the Sold branch composes no `SortMenu`: \(sold)"
        )
        #expect(soldMenu.contains("options: ItemListViewModel.SoldSortOrder.allCases"), "the Sold menu isn't over the Sold side's orders: \(soldMenu)")
        #expect(soldMenu.contains("selection: viewModel.soldSortOrder"), "the Sold menu doesn't show the Sold side's selection: \(soldMenu)")
        #expect(!soldMenu.contains("manualOrder:"), "the Sold menu gives a row the reorder subtitle — there is no manual order on that side (P16): \(soldMenu)")
        let soldSelect = try #require(
            SourceScan.closureBodies(after: soldMenu, in: sold).first,
            "the Sold menu selects nothing"
        )
        #expect(
            soldSelect.contains("viewModel.soldSortOrder = $0") && !soldSelect.contains("viewModel.sortOrder"),
            "the Sold menu writes something other than the Sold side's order: \(soldSelect)"
        )

        // Nothing in `apply` runs before the switch: a clear up here would
        // reach the Sold side's query on the way to an Owned request (Q3).
        let apply = try body(of: "private func apply(_ request: AppRouter.ItemsRequest?)")
        let guardEnd = try #require(apply.range(of: "guard let request"), "`apply` no longer guards its request — wrong span?")
        let switchStart = try #require(apply.range(of: "switch request"), "`apply` no longer switches on the request — wrong span?")
        let before = apply[guardEnd.upperBound..<switchStart.lowerBound]
        #expect(
            !before.contains("viewModel."),
            "`apply` writes to the view model before it knows which side the request is for: \(before)"
        )
    }

    /// G19, criterion 1 from the list's side: the Owned row's one leading
    /// swipe is Edit, **Sell**, Copy in that order — Edit still nearest the
    /// edge, so a full swipe still edits (spec Decision 2) — the middle
    /// button stages the row for the sale sheet rather than the form sheet,
    /// says `markAsSold` to VoiceOver while reading "Sell" on screen
    /// (criterion 12), and wears the brass mid-tone and the tag glyph; the
    /// trailing swipe is still the delete alone, naming nothing about selling.
    ///
    /// The three buttons are cut apart at their own `Button` keywords rather
    /// than scanned over the whole block, so *which* button carries which
    /// word, target and tint is what's pinned — a block containing all three
    /// words in any arrangement would otherwise pass.
    ///
    /// Mutations: swap the Sell and Copy buttons → red; the middle button
    /// writing `itemBeingEdited` → red.
    @Test func theOwnedRowsLeadingSwipeOffersEditThenSellThenCopy() throws {
        let owned = try body(of: "private var ownedRows: some View")

        let trailing = SourceScan.closureBodies(after: ".swipeActions(edge: .trailing)", in: owned)
        try #require(trailing.count == 1, "the Owned rows carry \(trailing.count) trailing swipe blocks, expected exactly 1")
        #expect(
            !trailing[0].contains("SaleCopy"),
            "the Owned rows' trailing swipe names SaleCopy — selling belongs on the leading swipe, the delete stays alone (criterion 1): \(trailing[0])"
        )

        let blocks = SourceScan.closureBodies(after: ".swipeActions(edge: .leading)", in: owned)
        try #require(blocks.count == 1, "the Owned rows carry \(blocks.count) leading swipe blocks, expected exactly 1")
        let leading = try #require(blocks.first)

        let starts = leading.ranges(of: "Button").map(\.lowerBound)
        try #require(
            starts.count == 3,
            "the leading swipe carries \(starts.count) buttons, expected 3 — Edit, Sell, Copy"
        )
        let buttons = starts.indices.map { index -> String in
            let end = index + 1 < starts.count ? starts[index + 1] : leading.endIndex
            return String(leading[starts[index]..<end])
        }

        #expect(buttons[0].contains("Text(\"Edit\")"), "the button nearest the edge isn't Edit — a full swipe would stop editing (Decision 2): \(buttons[0])")
        #expect(buttons[0].contains("itemBeingEdited = item"), "the first button doesn't open the form sheet: \(buttons[0])")

        #expect(buttons[1].contains("Text(SaleCopy.swipeSell)"), "the middle button doesn't read the swipe's own word: \(buttons[1])")
        #expect(buttons[1].contains("itemBeingSold = item"), "the middle button doesn't stage the row for the sale sheet: \(buttons[1])")
        #expect(
            buttons[1].contains(".accessibilityLabel(SaleCopy.markAsSold)"),
            "the Sell button doesn't say the menu row's own name to VoiceOver (criterion 12, G23): \(buttons[1])"
        )
        #expect(buttons[1].contains("Image(\"ActionSell\")"), "the Sell button wears no tag glyph: \(buttons[1])")
        #expect(
            buttons[1].contains(".tint(theme.colors.accentBrassMid)"),
            "the Sell button isn't the brass mid-tone — the one brass that reads mid in both appearances (plan Q9): \(buttons[1])"
        )
        #expect(
            !buttons[1].contains("accentRust"),
            "the Sell button is rust, which stays the one consequential colour on a swiped-open row: \(buttons[1])"
        )

        #expect(buttons[2].contains("Text(\"Copy\")"), "the last button isn't Copy: \(buttons[2])")
        #expect(buttons[2].contains("viewModel.duplicate"), "the last button doesn't duplicate: \(buttons[2])")
    }

    /// G19's other half: the sale sheet is hosted here, once, over the row's
    /// own item — the `.sheet(item:)` shape the item page uses (006 plan §5),
    /// so two rows can never both be selling — seeded by the view model's
    /// factory rather than a `SaleFormViewModel` built in the view, confirming
    /// through `markSold` and clearing the staging on both exits.
    ///
    /// Mutation: drop `itemBeingSold = nil` from the confirm closure → red
    /// (the sheet would stay up over a sold row).
    @Test func theSaleSheetIsHostedOnceOverTheStagedRow() throws {
        let code = try code()

        #expect(
            code.ranges(of: ".sheet(item: $itemBeingSold").count == 1,
            "the list presents \(code.ranges(of: ".sheet(item: $itemBeingSold").count) sale sheets, expected exactly 1"
        )
        #expect(
            code.contains(".sheet(item: $itemBeingSold, onDismiss: viewModel.load)"),
            "the sale sheet doesn't re-read the collection on dismiss, so a sold row would linger on the Owned side"
        )

        let bodies = SourceScan.closureBodies(after: ".sheet(item: $itemBeingSold", in: code)
        try #require(bodies.count == 1, "the sale sheet opens \(bodies.count) spans, expected exactly 1")
        let sheet = try #require(bodies.first)

        #expect(sheet.contains("SaleFormView("), "the sale sheet composes something other than the shared sale form: \(sheet)")
        #expect(
            sheet.contains("viewModel.makeSaleFormViewModel(for: item)"),
            "the sheet seeds its own form instead of the view model's, which is what keeps all three hosts' defaults equal (G17): \(sheet)"
        )
        #expect(
            sheet.contains("viewModel.markSold(item, sale: sale)"),
            "the sheet confirms into something other than `markSold`: \(sheet)"
        )
        #expect(
            sheet.ranges(of: "itemBeingSold = nil").count == 2,
            "the sheet clears its staging \(sheet.ranges(of: "itemBeingSold = nil").count) times, expected 2 — confirm and cancel both close it"
        )

        // The one writer stays the view model's: the screen never reaches the
        // store itself (T005's note).
        #expect(
            !code.contains("ItemSaleStore"),
            "the list names the sale store directly — the write belongs behind the view model"
        )
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

    /// Spec Decision 13, as the view can express it: neither side's meta line
    /// is conditional, so the slot under the title is there on both sides and
    /// the `SideSwitch` beneath it cannot jump as the sides change. The
    /// person saw exactly that jump at the Phase 5 pause.
    ///
    /// The type carries most of the guarantee — `soldSummaryLine` is a
    /// `String`, so there is nothing to unwrap — and this catches the other
    /// way back to a vanishing line: an `if` around the line itself.
    /// Mutation: wrap the Sold branch in `if !viewModel.soldItems.isEmpty`
    /// → red.
    @Test func neitherSidesMetaLineIsConditional() throws {
        let meta = try body(of: "private var metaLine: some View")

        #expect(
            !meta.contains("if "),
            "a branch of the meta line is conditional, so one side's header can lose its slot and move the switch: \(meta)"
        )
        #expect(
            meta.ranges(of: ".monoLabel()").count == 2,
            "the meta line draws \(meta.ranges(of: ".monoLabel()").count) mono lines, expected one per side — the two slots have to be the same height"
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

    /// Spec Decision 13's other half: the slide is fast. T018b measured the
    /// travel on the simulator frame by frame — at 0.25 s it took 198–222 ms
    /// of visible travel, and the bound Decision 13 is held to is 0.2 s, the
    /// rate every other in-page control in the app already moves at.
    ///
    /// One constant, both arms: the value is asserted rather than the source
    /// scanned, so a literal typed back into either arm of the `.animation`
    /// leaves the constant unused and the travelling arm un-pinned — which
    /// is what the second half of this test checks.
    ///
    /// Mutation: `slideDuration = 0.25` → red.
    @Test func theSwitchesSlideIsAtOrUnderTwoTenthsOfASecond() throws {
        #expect(SideSwitchMetrics.slideDuration <= 0.2)

        let code = try SourceScan.production(Self.control)
        #expect(
            code.ranges(of: "SideSwitchMetrics.slideDuration").count == 2,
            "the switch names `SideSwitchMetrics.slideDuration` \(code.ranges(of: "SideSwitchMetrics.slideDuration").count) times, expected 2 — one arm of the animation types its own duration"
        )
    }

    /// The fill is **one** rectangle that moves, not one per half appearing
    /// as the other disappears. T018b measured the difference on the device:
    /// the paired form is a structural insert-and-remove, which
    /// `.animation(_:value:)` does not cover, so it cross-faded — the control
    /// dimming to 22 % halfway across — and ignored its own duration
    /// entirely (a literal 2 s ease changed nothing). An animatable
    /// `.offset` is covered, and measures as a real slide: the fill's edge
    /// crosses in 9 to 11 distinct frames at 60 Hz with the control's
    /// brightness flat throughout.
    ///
    /// Mutation: put the `matchedGeometryEffect` pair back → both
    /// expectations fail.
    @Test func theSwitchesFillIsOneMovingRectangle() throws {
        let code = try SourceScan.production(Self.control)

        #expect(
            !code.contains("matchedGeometryEffect"),
            "the fill is paired across the halves again — that form cross-fades rather than sliding, and ignores the animation"
        )
        #expect(
            code.ranges(of: "Rectangle()\n                .fill(theme.colors.accentBrass)").count == 1,
            "the switch draws \(code.ranges(of: "Rectangle()\n                .fill(theme.colors.accentBrass)").count) brass fills, expected exactly 1 — the one that slides"
        )
        #expect(code.contains(".offset(x: side =="), "the fill doesn't move with the side, so nothing about it is animatable")
    }
}

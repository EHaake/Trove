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
    private nonisolated static let control = "Trove/Views/Shared/SideToggle.swift"

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

    // MARK: - The switch (plan Q15, 018 G10)

    /// The one call site, and the whole of Q15 as the view can express it:
    /// the switch reports a choice through `show(_:)`, and the screen binds
    /// nothing — no `$` projection among its arguments (the closure's own
    /// `$0` aside).
    ///
    /// Mutation (018 T007): `SidePicker(side: $viewModel.side, …)` → red.
    /// Re-run on `SideToggle` at T009a: `side: $viewModel.wrappedValue.side`
    /// → red.
    @Test func theSwitchReportsThroughShowAndBindsToNothing() throws {
        let code = try code()

        let calls = SourceScan.argumentLists(of: "SideToggle", in: code)
        try #require(calls.count == 1, "the screen composes \(calls.count) side switches, expected exactly 1")
        let call = try #require(calls.first)

        #expect(call.contains("viewModel.show($0)"), "the switch doesn't call `show(_:)`: \(call)")
        let projection = try Regex(#"\$[A-Za-z_]"#)
        #expect(
            !call.contains(projection),
            "the switch is bound to `side` itself, skipping `show(_:)`: \(call)"
        )
    }

    /// Spec Decision 20: the control row is Sort By, then the side toggle, then
    /// the "…" — so the toggle sits beside the "…" whether or not Sort By is
    /// shown, and never moves when it comes and goes. A fact about the view
    /// body no view-model test can observe.
    ///
    /// Mutation (T009b): the toggle and the sort control swapped → red.
    @Test func theControlRowIsSortThenToggleThenOverflow() throws {
        let header = try body(of: "private var header: some View")
        let rows = SourceScan.closureBodies(after: "HStack(spacing: 8)", in: header)
        try #require(rows.count == 1, "the header composes \(rows.count) control rows, expected exactly 1: \(header)")
        let row = try #require(rows.first)

        var starts: [String.Index] = []
        for part in ["sortControl", "SideToggle(", "overflowControl"] {
            let found = row.ranges(of: part)
            try #require(found.count == 1, "the control row names `\(part)` \(found.count) times, expected exactly 1: \(row)")
            starts.append(found[0].lowerBound)
        }
        #expect(
            starts[0] < starts[1] && starts[1] < starts[2],
            "the control row isn't Sort By, then the side toggle, then the \"…\" (spec Decision 20): \(row)"
        )
    }

    /// Plan §4: the switch lives in the standing header, so it is on screen
    /// over an empty Owned side exactly as it is over rows.
    ///
    /// Mutation (018 T007): the `SidePicker(` call moved into the empty-state
    /// branch → red. Re-run on `SideToggle` at T009a → red.
    @Test func theSwitchStandsOutsideTheEmptyState() throws {
        let branches = try body(of: "if let reason = viewModel.emptyReason")

        #expect(
            !branches.contains("SideToggle("),
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
    /// the list beneath it cannot jump as the sides change. The
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

    // MARK: - The control itself (018 G10, plan §4 and Q3, Decision 19)

    /// Since `018` T009a (spec Decision 19) the switch is one glass button in
    /// the header's control row showing the current side, and a tap asks
    /// `select` for the other side — so a choice reaches the screen's
    /// `show(_:)` and nothing writes the side directly. The action is read
    /// whole and compared as a whole literal; the style as `OverflowMenu`'s
    /// minus the circle, and since T009b (spec Decision 20) the tint the
    /// ternary over `leading` — brass on the leading side, the system's label
    /// colour on the trailing — with no other theme colour in the file. The Items toggle's words,
    /// glyphs, VoiceOver label, identifier and the side a tap asks for are
    /// read off a toggle built through its own `init(side:select:)`, so they
    /// are values rather than spellings.
    ///
    /// Mutations (T009a): the action `select(side)` → red; a theme colour
    /// named in the file → red. (T009b): the ternary's two colours swapped →
    /// red; a second theme colour named in the file → red. (T009c): the
    /// label row's `.animation(nil, value: side)` removed → red.
    @Test func theSwitchIsAGlassToggleAskingForTheOtherSide() throws {
        let code = try SourceScan.production(Self.control)
        let anchor = "struct SideToggle<Side: Hashable>: View"
        try #require(code.contains(anchor), "SideToggle.swift no longer declares `\(anchor)`")

        let bodies = SourceScan.closureBodies(after: "var body: some View", in: code)
        try #require(bodies.count == 1, "SideToggle declares \(bodies.count) bodies, expected exactly 1")
        let body = try #require(bodies.first)

        // A `Button`, and no menu: a tap shows the other side (Decision 19).
        let actions = SourceScan.closureBodies(after: "Button", in: body)
        try #require(actions.count == 1, "SideToggle's body builds \(actions.count) buttons, expected exactly 1: \(body)")
        let action = try #require(actions.first).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(action == "select(other)", "a tap doesn't ask for the other side — the action reads `\(action)`")
        // Word-bounded, so `SortMenuCopy` (the label type) doesn't match.
        #expect(
            !body.contains(try Regex(#"(?:^|[^A-Za-z0-9_])Menu\s*[{(]"#)),
            "the toggle opens a menu — a tap shows the other side (Decision 19): \(body)"
        )

        // Decision 20: brass while the leading side shows, the system's label
        // colour while the trailing side does — the whole ternary, in that
        // order, directly after the glass style.
        #expect(
            body.contains(try Regex(#"\.buttonStyle\(\.glass\)\s*\.tint\(side == leading \? theme\.colors\.accentBrass : Color\.primary\)\s*\.controlSize\(\.regular\)"#)),
            "the toggle isn't `OverflowMenu`'s glass button at the regular control size, tinted brass on the leading side and the system's label colour on the trailing one (spec Decision 20): \(body)"
        )
        // T009c: the label swaps in one frame. Without this line Owned → Sold
        // crossfades, both words superimposed for ~0.1 s — only film sees it.
        let labelRow = ".frame(height: 0)"
        try #require(body.contains(labelRow), "SideToggle's label row no longer carries `\(labelRow)`: \(body)")
        #expect(
            body.contains(try Regex(#"\.frame\(height: 0\)\s*\.animation\(nil, value: side\)"#)),
            "the toggle's label row isn't followed by `.animation(nil, value: side)` — Owned → Sold crossfades the two words (T009c): \(body)"
        )
        #expect(!body.contains(".buttonBorderShape("), "the toggle sets a border shape — it is a capsule, the \"…\" alone is a circle: \(body)")
        #expect(body.contains(".accessibilityLabel(accessibilityLabel)"), "the toggle carries no VoiceOver label: \(body)")
        #expect(body.contains(".accessibilityValue(word(side))"), "the toggle doesn't speak the side showing as its value: \(body)")
        #expect(body.contains(".accessibilityIdentifier(identifier)"), "the toggle carries no identifier: \(body)")
        // It reports; it never writes. A `@Binding` here would be a second
        // way to change sides, one that skips `show(_:)`.
        #expect(!code.contains("@Binding"), "the toggle binds the side instead of reporting a choice (plan Q3)")
        #expect(
            code.ranges(of: "theme.colors").count == 1,
            "SideToggle.swift names \(code.ranges(of: "theme.colors").count) theme colours — brass in the tint is the only one it draws (spec Decision 20)"
        )

        let owned = SideToggle(side: ItemListViewModel.Side.owned, select: { _ in })
        let sold = SideToggle(side: ItemListViewModel.Side.sold, select: { _ in })
        #expect(owned.side == .owned && sold.side == .sold)
        #expect(owned.other == .sold, "a tap on Owned doesn't ask for Sold")
        #expect(sold.other == .owned, "a tap on Sold doesn't ask for Owned")
        #expect(owned.word(.owned) == SaleCopy.owned && owned.word(.sold) == SaleCopy.sold, "the Items toggle's words aren't Owned and Sold")
        #expect(owned.icon(.owned) == "shippingbox", "Owned's glyph isn't `shippingbox` (Decision 19)")
        #expect(owned.icon(.sold) == "tag", "Sold's glyph isn't `tag` (Decision 19)")
        #expect(owned.accessibilityLabel == "Owned or sold", "the Items toggle isn't labelled for VoiceOver")
        #expect(owned.identifier == "items.sideSwitch", "the Items toggle's identifier changed — the UI tests find it by it")
    }
}

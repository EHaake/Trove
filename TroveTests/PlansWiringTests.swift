import Foundation
import Testing
@testable import Trove

/// How the Plans tab is wired (spec `009`). T010 opened it with G18 (gone
/// with the bespoke switch at `018` T007); T011
/// adds G19, the screen's view-body facts, as source scans that each
/// `#require` their anchor.
@Suite("Plans wiring")
@MainActor
struct PlansWiringTests {
    // MARK: - The screen (plan §11, G19)

    private static let view = "Trove/Views/Plans/PlansView.swift"

    /// G19, Q13: Buy from a row is the leading swipe on Active rows only.
    /// The whole leading block must be one `if viewModel.side == .active`
    /// and nothing else — compared whole, so a button moved outside the gate
    /// (a completed row offering Buy) or an `else` beside it fails — and the
    /// gated button is the Wishlist's Buy: its word, its glyph, the menu row's
    /// spoken name, and the staging it writes.
    ///
    /// Mutation (T011): the Buy button moved outside the gate → red.
    @Test func theBuySwipeIsTheLeadingBlockOnActiveRowsOnly() throws {
        let code = try SourceScan.production(Self.view)

        let blocks = SourceScan.closureBodies(after: ".swipeActions(edge: .leading)", in: code)
        try #require(blocks.count == 1, "the plan rows carry \(blocks.count) leading swipe blocks, expected exactly 1")
        let leading = blocks[0].trimmingCharacters(in: .whitespacesAndNewlines)

        let gate = "if viewModel.side == .active"
        let gated = SourceScan.closureBodies(after: gate, in: leading)
        try #require(gated.count == 1, "the leading swipe holds \(gated.count) Active gates, expected exactly 1: \(leading)")
        #expect(
            leading == "\(gate) {\(gated[0])}",
            "the leading swipe composes something outside its Active gate — a completed row would offer it (Q13): \(leading)"
        )

        let buy = gated[0]
        #expect(buy.contains("Text(PurchaseCopy.swipeBuy)"), "the Buy button doesn't read the swipe's own word: \(buy)")
        #expect(buy.contains("Image(\"ActionBuy\")"), "the Buy button wears no bag glyph: \(buy)")
        #expect(
            buy.contains(".accessibilityLabel(PurchaseCopy.markAsBought)"),
            "the Buy button doesn't say the menu row's own name to VoiceOver: \(buy)"
        )
        #expect(buy.contains("planBeingBought = row"), "the Buy button doesn't stage the row for the purchase sheet: \(buy)")
    }

    /// G19, Q12: the trailing swipe stages the row for the delete alert and
    /// names nothing about buying.
    @Test func theTrailingSwipeStagesTheDeletionAndNamesNoPurchase() throws {
        let code = try SourceScan.production(Self.view)

        let blocks = SourceScan.closureBodies(after: ".swipeActions(edge: .trailing)", in: code)
        try #require(blocks.count == 1, "the plan rows carry \(blocks.count) trailing swipe blocks, expected exactly 1")
        let trailing = blocks[0]

        #expect(trailing.contains("pendingDeletion = row"), "the trailing swipe doesn't stage the row for the delete alert: \(trailing)")
        #expect(!trailing.contains("PurchaseCopy"), "the trailing swipe names PurchaseCopy — buying is the leading swipe's: \(trailing)")
    }

    /// G19, criterion 14: one purchase sheet over the staged row, seeded by
    /// the view model's factory, confirming through `markBought` — and a
    /// cancel closure that clears the staging, read as that closure alone
    /// (the `015` T011a lesson: a count over the whole sheet is satisfied by
    /// the confirm closure's line while cancel does nothing).
    ///
    /// Mutation (T011): the cancel closure emptied → red.
    @Test func thePurchaseSheetIsHostedOnceAndCancelClearsTheStaging() throws {
        let code = try SourceScan.production(Self.view)

        let marker = ".sheet(item: $planBeingBought, onDismiss: viewModel.load)"
        #expect(
            code.ranges(of: ".sheet(item: $planBeingBought").count == 1,
            "the screen presents \(code.ranges(of: ".sheet(item: $planBeingBought").count) purchase sheets, expected exactly 1"
        )
        let bodies = SourceScan.closureBodies(after: marker, in: code)
        try #require(bodies.count == 1, "no `\(marker)` — the sheet must re-read the rows on dismiss, which moves a bought row to Completed")
        let sheet = bodies[0]

        #expect(sheet.contains("PurchaseFormView("), "the sheet composes something other than the shared purchase form: \(sheet)")
        #expect(
            sheet.contains("viewModel.makePurchaseFormViewModel(for: row)"),
            "the sheet seeds its own form instead of the view model's: \(sheet)"
        )
        #expect(sheet.contains("viewModel.markBought(row, purchase: purchase)"), "the sheet confirms into something other than `markBought`: \(sheet)")

        let confirm = try #require(SourceScan.closureBodies(after: "confirm:", in: sheet).first, "the sheet has no confirm closure: \(sheet)")
        #expect(confirm.contains("planBeingBought = nil"), "confirming leaves the sheet staged: \(confirm)")

        let cancel = try #require(SourceScan.closureBodies(after: "cancel:", in: sheet).first, "the sheet has no cancel closure: \(sheet)")
        #expect(
            cancel.trimmingCharacters(in: .whitespacesAndNewlines) == "planBeingBought = nil",
            "cancelling doesn't clear the staging, so the sheet stays up (criterion 14): {\(cancel)}"
        )
    }

    /// G19, criterion 8 and Q8: the screen draws no money. The row value
    /// could reach a figure (its photos reach their item through
    /// `Photo.item`), so this test is what keeps money off the row — no
    /// currency formatter, no `Cents` field, and no store reached past the
    /// view model.
    ///
    /// Mutation (T011): `formattedAsWholeCurrency` added to the row → red;
    /// a `.currency(` format added → red.
    @Test func theScreenDrawsNoMoneyAndReachesNoStore() throws {
        let code = try SourceScan.production(Self.view)
        try #require(code.contains("struct PlanRowView"), "the scan read no PlanRowView — wrong file?")

        for forbidden in ["formattedAsWholeCurrency", ".currency(", "Cents", "SellPlanStore", "WishlistPurchaseStore"] {
            #expect(!code.contains(forbidden), "PlansView.swift names `\(forbidden)` — a Plans row shows no money, and writes go through the view model (criterion 8)")
        }
    }

    /// G19 and Q5: the row draws the view model's lines and composes none of
    /// its own. G31 (Amendment A, QA2, criterion 20): it draws
    /// `RowThumbnail(photos: row.photos)` — the file's one thumbnail — in
    /// `PlanRowView`'s body on every row, inside no `if` or `else`, so a
    /// completed row keeps the slot an active one has; and no
    /// `showsThumbnail` survives in the file's code.
    ///
    /// Mutations: a `SellPlanCopy.setAside(` composed in the row → red
    /// (T011); the thumbnail gated on `!row.isCompleted` → red (T018);
    /// `RowThumbnail(photos: [])` → red (T018).
    @Test func theRowDrawsItsLinesAndAThumbnailOnEveryRow() throws {
        let code = try SourceScan.production(Self.view)
        let start = try #require(code.range(of: "private struct PlanRowView"), "no PlanRowView in \(Self.view)")
        let rowCode = String(code[start.lowerBound...])

        #expect(rowCode.contains("ForEach(row.lines"), "the row doesn't draw `row.lines` — which counts show is the view model's call (Q5)")
        for member in [
            "SellPlanCopy.setAside(",
            "SellPlanCopy.soldToward(",
            "SellPlanCopy.soldTowardPast(",
            "SellPlanCopy.nothingSetAside",
            "SellPlanCopy.covered",
            "SellPlanCopy.bought(",
        ] {
            #expect(!rowCode.contains(member), "PlanRowView composes `\(member)` itself instead of drawing `row.lines` (Q5)")
        }

        let thumbnail = "RowThumbnail(photos: row.photos)"
        #expect(
            code.ranges(of: "RowThumbnail(").count == 1,
            "PlansView.swift draws \(code.ranges(of: "RowThumbnail(").count) thumbnails, expected exactly 1"
        )
        let bodies = SourceScan.closureBodies(after: "var body: some View", in: rowCode)
        let body = try #require(bodies.first, "no `var body` in PlanRowView")
        #expect(
            body.ranges(of: thumbnail).count == 1,
            "PlanRowView's body draws `\(thumbnail)` \(body.ranges(of: thumbnail).count) times, expected exactly 1 — the view model chose the photos (QA2)"
        )
        let branches = SourceScan.closureBodies(after: "if ", in: body)
            + SourceScan.closureBodies(after: "else", in: body)
        for branch in branches {
            #expect(
                !branch.contains("RowThumbnail("),
                "the thumbnail sits inside a branch — every row on both sides keeps its slot (criterion 20): {\(branch)}"
            )
        }
        #expect(!code.contains("showsThumbnail"), "PlansView.swift still names `showsThumbnail` — the property is gone (QA2)")
    }

    /// G19, criterion 5, and `018` G10: the switch reports through
    /// `show(_:)` and is never bound (no `$` projection in its arguments), so
    /// changing side reloads and clears nothing; it stands in the header,
    /// outside the empty-state branch; and since T009a (spec Decision 19) it
    /// is the glass `SideToggle`, carrying the Plans words, glyphs, label and
    /// identifier and asking for the other side, read off a toggle built
    /// through its own `init(side:select:)`. The toggle's body is
    /// `ItemListSidesWiringTests`' to read.
    ///
    /// Mutations (018 T007): `SidePicker(side: $viewModel.side, …)` → red;
    /// the call moved into the empty-state branch → red. Re-run on
    /// `SideToggle` at T009a: `side: $viewModel.wrappedValue.side` → red;
    /// the call moved into the empty-state branch → red.
    @Test func theSideSwitchReportsThroughShow() throws {
        let code = try SourceScan.production(Self.view)

        let calls = SourceScan.argumentLists(of: "SideToggle", in: code)
        try #require(calls.count == 1, "the screen builds \(calls.count) side switches, expected exactly 1")
        #expect(calls[0].contains("viewModel.show($0)"), "the switch doesn't report through `viewModel.show`: \(calls[0])")
        // A `$` projection, not the closure's own `$0`.
        let projection = try Regex(#"\$[A-Za-z_]"#)
        #expect(
            !calls[0].contains(projection),
            "the switch is bound — a side change must go through `show(_:)`: \(calls[0])"
        )

        let branches = SourceScan.closureBodies(after: "if let reason = viewModel.emptyReason", in: code)
        try #require(branches.count == 1, "PlansView declares \(branches.count) empty-state branches, expected exactly 1")
        let branch = try #require(branches.first)
        #expect(branch.contains("emptyState(reason)"), "the empty-state branch no longer shows the empty state — wrong span?")
        #expect(!branch.contains("SideToggle("), "the switch is composed inside the empty-state branch, so an emptied side would lose it")

        let active = SideToggle(side: PlansViewModel.Side.active, select: { _ in })
        let completed = SideToggle(side: PlansViewModel.Side.completed, select: { _ in })
        #expect(active.side == .active && completed.side == .completed)
        #expect(active.other == .completed, "a tap on Active doesn't ask for Completed")
        #expect(completed.other == .active, "a tap on Completed doesn't ask for Active")
        #expect(
            active.word(.active) == SellPlanCopy.active && active.word(.completed) == SellPlanCopy.completed,
            "the Plans toggle's words aren't Active and Completed"
        )
        #expect(active.icon(.active) == "clock", "Active's glyph isn't `clock` (Decision 19)")
        #expect(active.icon(.completed) == "checkmark.circle", "Completed's glyph isn't `checkmark.circle` (Decision 19)")
        #expect(active.accessibilityLabel == SellPlanCopy.sideSwitchLabel, "the Plans toggle isn't labelled for VoiceOver")
        #expect(active.identifier == "plans.sideSwitch", "the Plans toggle's identifier changed — the UI tests find it by it")
    }

    /// Spec Decision 20, as on Items: the control row is Sort By, then the
    /// side toggle, then the "…" — so the toggle sits beside the "…" whether
    /// or not Sort By is shown. A fact about the view body no view-model test
    /// can observe.
    ///
    /// Mutation (T009b): the toggle and the sort control swapped → red.
    @Test func theControlRowIsSortThenToggleThenOverflow() throws {
        let headers = SourceScan.closureBodies(after: "private var header: some View", in: try SourceScan.production(Self.view))
        try #require(headers.count == 1, "PlansView declares \(headers.count) headers, expected exactly 1")
        let header = try #require(headers.first)
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

    /// `018` G7 (was 009's G19, P5): neither side's Sort By offers a manual
    /// order, so no row carries the "Drag rows to reorder" subtitle. Both
    /// menus are required, one per side, read from `sortControl`'s body.
    ///
    /// Mutation (T004): `manualOrder: .newest` on one menu → red.
    @Test func noSortMenuOffersAManualOrder() throws {
        let code = try SourceScan.production(Self.view)

        let controls = SourceScan.closureBodies(after: "private var sortControl: some View", in: code)
        try #require(controls.count == 1, "PlansView declares \(controls.count) `sortControl`s, expected exactly 1")
        let control = try #require(controls.first)
        let menus = SourceScan.argumentLists(of: "SortMenu", in: control)
        try #require(menus.count == 2, "`sortControl` builds \(menus.count) sort menus, expected 2 — one per side: \(control)")
        for menu in menus {
            #expect(
                !menu.contains("manualOrder:"),
                "a Plans sort menu gives a row the reorder subtitle — a plan list has no manual order (P5): \(menu)"
            )
        }
    }

    /// `018` spec Decision 23: the Active side's Sort By passes the order's
    /// short `badgeLabel` to its capsule, the Completed side's does not. The
    /// short label itself is `PlansViewModelTests`', and what it buys — the
    /// title at full size — `ItemListHeaderLayoutTests`'; which menu is
    /// handed it is a view-body fact neither can reach, so it is scanned.
    ///
    /// Mutation (T009f): `badgeLabel:` dropped from the Active menu → red.
    @Test func theActiveCapsuleReadsTheShortLabel() throws {
        let code = try SourceScan.production(Self.view)

        let controls = SourceScan.closureBodies(after: "private var sortControl: some View", in: code)
        try #require(controls.count == 1, "PlansView declares \(controls.count) `sortControl`s, expected exactly 1")
        let control = try #require(controls.first)
        let menus = SourceScan.argumentLists(of: "SortMenu", in: control)
        try #require(menus.count == 2, "`sortControl` builds \(menus.count) sort menus, expected 2 — one per side: \(control)")
        let active = try #require(menus.first { $0.contains("ActiveSortOrder") }, "no Active sort menu: \(control)")
        let completed = try #require(menus.first { $0.contains("CompletedSortOrder") }, "no Completed sort menu: \(control)")
        #expect(
            active.contains("badgeLabel: \\.badgeLabel"),
            "the Active side's capsule no longer reads the order's short label, so \"Wishlist order\" crowds the title (spec Decision 23): \(active)"
        )
        #expect(
            !completed.contains("badgeLabel:"),
            "the Completed side's capsule reads a short label it has no order for: \(completed)"
        )
    }

    /// Plan Q3 and §11: the screen reloads when an import lands and when the
    /// carry-over has run — the second is how carried-over plans appear on a
    /// screen already open. The view model's counters are its own tests';
    /// the subscription is a view-body fact.
    ///
    /// Mutation (T011): the `settledCount` reload dropped → red.
    @Test func theScreenReloadsOnImportsAndOnTheCarryOver() throws {
        let code = try SourceScan.production(Self.view)

        #expect(
            code.contains(".onChange(of: viewModel.completedImports) { viewModel.load() }"),
            "the screen doesn't reload when an import lands"
        )
        #expect(
            code.contains(".onChange(of: viewModel.settledCount) { viewModel.load() }"),
            "the screen doesn't reload when the carry-over has run, so carried-over plans wait for the next visit"
        )
    }
}

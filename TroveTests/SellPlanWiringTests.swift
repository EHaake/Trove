import Foundation
import Testing
@testable import Trove

/// T017. What the Sell Plan screen is wired to once a sale can be recorded
/// from it, pinned as source scans — the `SoldStateWiringTests` shape, for the
/// same reason: no unit test can tap a row's control or read a rendered header,
/// and what a scan *can* catch is the wiring quietly changing out from under
/// the spec (criterion 10, plan §3).
///
/// Every scan `#require`s its anchor before asserting anything about it
/// (`CLAUDE.md` Testing, plan §10): the `if viewModel.hasSales` branches are
/// found, and counted, before anything is read out of their spans, so a branch
/// renamed away fails loudly here rather than passing over a span that no
/// longer exists.
///
/// The framing half is guarded next door and deliberately not repeated here:
/// `SellPlanFramingTests` scans this file's string literals for the words that
/// would turn the third figure into a gap to close, and pins the three figures
/// as independent numbers.
@Suite("Sell Plan wiring")
struct SellPlanWiringTests {
    private nonisolated static let screen = "Trove/Views/Wishlist/SellPlanView.swift"

    /// The body of `figures(for:)`, which the header scans work over — the
    /// whole file would also see the candidate list's own `hasSales` branch,
    /// and the claim is about what the header composes.
    private func figuresBody() throws -> String {
        let code = try SourceScan.production(Self.screen)
        let bodies = SourceScan.closureBodies(
            after: "private func figures(for wanted: WishlistItem) -> some View",
            in: code
        )
        try #require(bodies.count == 1, "the screen declares \(bodies.count) figures(for:) bodies, expected exactly 1")
        return try #require(bodies.first)
    }

    /// The single `if viewModel.hasSales` branch inside a span — `#require`d
    /// to be found exactly once, so nothing below asserts over an empty
    /// string. Mutation: rename the anchor → this fails.
    private func hasSalesBranch(in span: String, describing what: String) throws -> String {
        let branches = SourceScan.closureBodies(after: "if viewModel.hasSales", in: span)
        try #require(
            branches.count == 1,
            "\(what) has \(branches.count) `if viewModel.hasSales` branches, expected exactly 1"
        )
        return try #require(branches.first)
    }

    /// The body of `record(for:)`, the bought plan's face (009 plan §9) —
    /// `#require`d to be declared exactly once, so no leg below reads an
    /// empty string.
    private func recordBody() throws -> String {
        let code = try SourceScan.production(Self.screen)
        let bodies = SourceScan.closureBodies(
            after: "private func record(for wanted: WishlistItem) -> some View",
            in: code
        )
        try #require(bodies.count == 1, "the screen declares \(bodies.count) record(for:) bodies, expected exactly 1")
        return try #require(bodies.first)
    }

    /// A span with its surrounding whitespace dropped, so a whole-literal
    /// comparison reads the code rather than its indentation.
    private func trimmed(_ span: String) -> String {
        span.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - The third figure (criterion 10, Decision 5)

    /// The Sold cell is drawn, it is drawn inside the `hasSales` branch, and
    /// it is drawn nowhere else — a plan with no sales is the two-figure
    /// screen it was.
    @Test func theSoldCellIsInsideTheHasSalesBranchAndNowhereElse() throws {
        let code = try SourceScan.production(Self.screen)
        let body = try figuresBody()
        let branch = try hasSalesBranch(in: body, describing: "figures(for:)")

        // The control first: both layouts still draw the two figures 001
        // settled, so the scan is reading the real header.
        #expect(body.contains("\"Selected\""), "the header draws no Selected figure — wrong target?")
        #expect(body.contains("\"Estimated cost\""), "the header draws no Estimated cost figure — wrong target?")

        for member in ["SaleCopy.sellPlanFigureHeader", "viewModel.soldValueCents", "SaleCopy.sellPlanSoldCaption("] {
            #expect(branch.contains(member), "the third cell doesn't read \(member)")
            // Counted over the whole screen, not over `figures(for:)`: the
            // two-figure card is a function of its own, so a Sold cell added
            // *there* would sit outside the header body entirely — which is
            // exactly how this half passed over a mutation that put it there.
            #expect(
                code.ranges(of: member).count == 1,
                "\(member) is composed \(code.ranges(of: member).count) times — a plan with no sales would show a Sold figure too"
            )
        }
    }

    /// Nothing on this screen nets the sale off anything (G10 from the view's
    /// side): the Sold figure is `soldValueCents` as it stands, and no cell's
    /// figure is an expression over two of the three.
    @Test func theHeaderSubtractsTheSaleFromNothing() throws {
        let body = try figuresBody()

        for arithmetic in ["estimatedCostCents -", "- viewModel.soldValueCents", "- viewModel.selectedValueCents"] {
            #expect(
                !body.contains(arithmetic),
                "the header computes `\(arithmetic)` — the three figures sit side by side, with nothing subtracted (Decision 5)"
            )
        }
    }

    // MARK: - The Sold section (P15)

    /// The section is under the candidates, inside the same scroll, and only
    /// when there are sales.
    @Test func theSoldSectionFollowsTheCandidatesAndOnlyWhenThereAreSales() throws {
        let code = try SourceScan.production(Self.screen)
        let bodies = SourceScan.closureBodies(after: "private var candidateList: some View", in: code)
        try #require(bodies.count == 1, "the screen declares \(bodies.count) candidateList bodies, expected exactly 1")
        let list = try #require(bodies.first)

        let branch = try hasSalesBranch(in: list, describing: "candidateList")
        #expect(branch.contains("soldSection"), "the Sold section isn't gated on the plan having sales")

        let candidates = try #require(
            list.range(of: "ForEach(viewModel.candidates"),
            "the candidate list no longer lists the candidates — wrong target?"
        )
        let section = try #require(list.range(of: "soldSection"), "the candidate list doesn't carry the Sold section")
        #expect(
            candidates.upperBound < section.lowerBound,
            "the Sold section is composed above the candidates, not under them (P15)"
        )
    }

    /// The same section under the other half of `content(for:)`: selling the
    /// last candidate empties the pool, and the plan still lists what was sold
    /// toward it (spec Decision 14). One `soldSection`, hosted once per
    /// branch, gated on `hasSales` in both.
    ///
    /// **009 adds a third host** (plan §9, Q19): a bought plan's record is
    /// the same section, gated the same way, so the count moves from three to
    /// four — one declaration and three hosts — and the record's branch is
    /// required to be the section and nothing else.
    ///
    /// Mutation: drop `soldSection` from the empty branch, or send
    /// `content(for:)` straight back to `emptyState(reason)` → red. 009:
    /// drop it from the record → red.
    @Test func theSoldSectionIsHostedUnderTheEmptyStateToo() throws {
        let code = try SourceScan.production(Self.screen)

        let contents = SourceScan.closureBodies(
            after: "private func content(for wanted: WishlistItem) -> some View",
            in: code
        )
        try #require(contents.count == 1, "the screen declares \(contents.count) content(for:) bodies, expected exactly 1")
        let content = try #require(contents.first)

        #expect(content.contains("candidateList"), "the screen no longer lists the candidates — wrong target?")
        #expect(
            content.contains("emptyPlan(reason)"),
            "an emptied plan is composed as the bare empty state, which can host nothing under it (Decision 14)"
        )

        let empties = SourceScan.closureBodies(
            after: "private func emptyPlan(_ reason: SellPlanViewModel.EmptyReason) -> some View",
            in: code
        )
        try #require(empties.count == 1, "the screen declares \(empties.count) emptyPlan(_:) bodies, expected exactly 1")
        let empty = try #require(empties.first)

        #expect(empty.contains("emptyState(reason)"), "the empty branch stopped saying why the pool is empty — wrong target?")

        let branch = try hasSalesBranch(in: empty, describing: "emptyPlan(_:)")
        #expect(
            branch.contains("soldSection"),
            "an emptied plan drops the sales already made toward it — they stay listed (Decision 14)"
        )

        // 009: the record is the third host, inside its own `hasSales`
        // branch and as the whole of it.
        let record = try recordBody()
        let recorded = try hasSalesBranch(in: record, describing: "record(for:)")
        #expect(
            trimmed(recorded) == "soldSection",
            "a bought plan's record doesn't host the Sold section as the whole of its hasSales branch:\n\(recorded)"
        )

        // One section, three hosts: its own declaration plus one mention in
        // each. A second copy of the rows, or a host that quietly stopped
        // composing it, moves this count.
        #expect(
            code.ranges(of: "soldSection").count == 4,
            "soldSection is named \(code.ranges(of: "soldSection").count) times — expected one declaration and three hosts"
        )
    }

    /// What the section says, and what it doesn't: the sales themselves, the
    /// title from `SaleCopy`, and no total — the figure lives in the header,
    /// beside the cost rather than against it.
    @Test func theSoldSectionListsTheSalesAndAddsNothingUp() throws {
        let code = try SourceScan.production(Self.screen)
        let bodies = SourceScan.closureBodies(after: "private var soldSection: some View", in: code)
        try #require(bodies.count == 1, "the screen declares \(bodies.count) soldSection bodies, expected exactly 1")
        let section = try #require(bodies.first)

        #expect(section.contains("SaleCopy.sellPlanSectionTitle"), "the section's title isn't SaleCopy's word")
        #expect(
            section.contains("ForEach(viewModel.soldItems"),
            "the section lists something other than the view model's sold items"
        )
        #expect(
            !section.contains("soldValueCents"),
            "the section totals the sales under them — the Sold figure is the header's, and it is not a sum drawn twice"
        )

        let rows = SourceScan.closureBodies(after: "private func soldRow(_ item: Item) -> some View", in: code)
        try #require(rows.count == 1, "the screen declares \(rows.count) soldRow(_:) bodies, expected exactly 1")
        let row = try #require(rows.first)

        #expect(row.contains("item.name"), "a sold row doesn't name the item")
        #expect(row.contains("sale.date"), "a sold row doesn't date the sale")
        #expect(
            row.contains("sale.priceCents"),
            "a sold row shows something other than what the item actually sold for"
        )
        #expect(
            !row.contains("currentValueCents"),
            "a sold row reads a current value — the sale is settled, and the market has nothing left to say about it"
        )
        #expect(
            row.contains(".accessibilityElement(children: .combine)"),
            "a sold row isn't announced as one element (criterion 16)"
        )
    }

    /// Every row in the section carries the mark, so it reads as sold on its
    /// own rather than by the header above it — which is the whole of what an
    /// emptied plan shows (spec Decision 14). The mark is composed before the
    /// name, so the row's one combined announcement opens with the word
    /// (criterion 16), and it is `SaleCopy`'s word: the file's inline-copy
    /// scan next door only filters literals with a space in them, so a bare
    /// `"Sold"` typed here would walk straight past it.
    ///
    /// Mutation: drop the mark, type the word inline, or compose it after the
    /// name → red.
    @Test func eachSoldRowCarriesTheSoldMark() throws {
        let code = try SourceScan.production(Self.screen)
        let rows = SourceScan.closureBodies(after: "private func soldRow(_ item: Item) -> some View", in: code)
        try #require(rows.count == 1, "the screen declares \(rows.count) soldRow(_:) bodies, expected exactly 1")
        let row = try #require(rows.first)

        let mark = try #require(
            row.range(of: "SaleCopy.soldMark"),
            "a sold row doesn't say it is sold — only the section's header does, and an emptied plan is nothing but rows"
        )
        let name = try #require(row.range(of: "item.name"), "a sold row doesn't name the item — wrong target?")
        #expect(
            mark.upperBound < name.lowerBound,
            "the mark is composed after the name, so the row's combined label doesn't open with it (criterion 16)"
        )

        let typed = SourceScan.stringLiterals(in: row).filter { $0.localizedCaseInsensitiveContains("sold") }
        #expect(
            typed.isEmpty,
            "the row types a sale's word inline instead of reading SaleCopy: \(typed.joined(separator: " | "))"
        )
    }

    // MARK: - The plan emptied by selling (spec Decision 15)

    /// T020a's state on the screen: its own two lines from `SaleCopy`, the
    /// Items mark the other collection-level state carries, and no action —
    /// what it describes is already on screen beneath it. Mutation: point
    /// either line at the Owned side's `everythingSold*` copy → red.
    @Test func thePlanEverythingSoldStateReadsItsCopyAndOffersNoAction() throws {
        let code = try SourceScan.production(Self.screen)

        let states = SourceScan.argumentLists(of: "EmptyStateView", in: code)
            .filter { $0.contains("SaleCopy.planEverythingSoldHeadline") }
        try #require(
            states.count == 1,
            "\(states.count) empty states read the plan's everything-sold headline, expected exactly 1"
        )
        let state = try #require(states.first)

        #expect(state.contains("SaleCopy.planEverythingSoldDetail"), "the state types its own detail line")
        #expect(state.contains(".asset(\"TabItems\")"), "the state doesn't carry the Items mark")
        #expect(!state.contains("action:"), "the state offers an action — the sales are already below it")
    }

    // MARK: - The row's control and the sheet it opens (criterion 10, Decision 4)

    /// Two tap targets, not one: the card toggles, the strip beneath it opens
    /// the sheet, and the strip's action reaches the screen's `saleCandidate`.
    /// Mutation: point the control anywhere but `saleCandidate` → red.
    @Test func theRowsControlIsASecondTapTargetThatSetsTheSaleCandidate() throws {
        let code = try SourceScan.production(Self.screen)

        let rows = SourceScan.argumentLists(of: "SellPlanRow", in: code)
        try #require(rows.count == 1, "the list builds \(rows.count) SellPlanRow call sites, expected exactly 1")
        let built = try #require(rows.first)

        #expect(
            built.contains("markAsSold: { viewModel.saleCandidate = item }"),
            "the row's control doesn't open this row's sheet: \(built)"
        )
        #expect(built.contains("toggle: { viewModel.toggle(item) }"), "the row no longer toggles — wrong target?")

        let strip = SourceScan.closureBodies(after: "private var markAsSoldStrip: some View", in: code)
        try #require(strip.count == 1, "the row declares \(strip.count) markAsSoldStrip bodies, expected exactly 1")
        let control = try #require(strip.first)

        #expect(control.contains("Button(action: markAsSold)"), "the control isn't a button over the row's action")
        #expect(control.contains("Text(SaleCopy.markAsSold)"), "the control's words aren't SaleCopy's")
        #expect(
            control.contains("\"sellPlan.row.markAsSold\""),
            "the control carries no identifier — the device pass and criterion 16 both need one"
        )

        // The toggle is still a button of its own, so the card really is two
        // targets rather than one wrapped around both.
        #expect(
            code.contains("Button(action: toggle)"),
            "the card's body is no longer a button of its own — one tap would have to guess which action it meant"
        )
    }

    /// One component and one seeding rule: the row's sheet is `SaleFormView`
    /// over `makeSaleFormViewModel(for:)`, exactly as the item detail presents
    /// its own (T014). Mutation: build a second form, or seed it here → red.
    @Test func theSheetIsTheOneSaleFormOverTheOneSeedingRule() throws {
        let code = try SourceScan.production(Self.screen)

        #expect(
            code.contains(".sheet(item: $viewModel.saleCandidate)"),
            "the sale sheet isn't presented over the view model's saleCandidate"
        )

        let forms = SourceScan.argumentLists(of: "SaleFormView", in: code)
        try #require(forms.count == 1, "the screen composes \(forms.count) sale sheets, expected exactly 1")
        let form = try #require(forms.first)

        #expect(
            form.contains("viewModel: viewModel.makeSaleFormViewModel(for: item)"),
            "the sheet's view model is built somewhere other than the screen's factory: \(form)"
        )
        #expect(
            form.contains("viewModel.markSold(item, sale: sale)"),
            "confirming the sheet doesn't mark this row sold: \(form)"
        )
        // The factory's own name ends in `SaleFormViewModel(`, so it comes out
        // of the text before the file is asked whether anything *constructs*
        // one.
        let constructed = code.replacingOccurrences(of: "makeSaleFormViewModel(", with: "")
        #expect(
            !constructed.contains("SaleFormViewModel("),
            "the screen seeds a sale form of its own — the detail and the plan share one seeding rule (plan §3)"
        )
        #expect(
            !code.contains("ItemSaleStore"),
            "the screen writes the sale itself — `markSold` is the one intent, and the store is its business (plan Q3)"
        )
    }

    /// The whole file's copy: every new word on this screen is `SaleCopy`'s,
    /// so the row's action, the third figure's header and the section's title
    /// cannot drift from the sheet they open and the page they mirror.
    @Test func theNewCopyIsNeverTypedInline() throws {
        let code = try SourceScan.production(Self.screen)
        let literals = SourceScan.stringLiterals(in: code)

        #expect(!literals.isEmpty, "found no copy on SellPlanView — this would pass over nothing")

        // Copy, not identifiers: `sellPlan.row.markAsSold` is a hook for the
        // device pass and says nothing to anyone. A sentence has a space in
        // it — the `SoldStateWiringTests` filter, for the same reason.
        let sold = literals
            .filter { $0.contains(" ") }
            .filter { $0.localizedCaseInsensitiveContains("sold") }
        #expect(
            sold.isEmpty,
            "the screen types a sale's words inline instead of reading SaleCopy: \(sold.joined(separator: " | "))"
        )
    }

    // MARK: - The record and the delete (009, G17)

    /// A bought plan opens as a record (criterion 9, plan §9): the body
    /// branches on `isCompleted` to `record(for:)`, which draws the heading,
    /// the day it was bought and what sold toward it — and names nothing
    /// that selects, sells or buys. Its *behaviour* — the view model
    /// refusing those writes — is `SellPlanViewModelTests`' (G14); this is
    /// the face.
    ///
    /// Mutations: put `viewModel.toggle`, a `SellPlanRow(` or a `Button(`
    /// into the record → red; put an `.onTapGesture` on `soldRow(_:)` → red;
    /// send the `isCompleted` branch to `content(for:)` → red.
    @Test func aBoughtPlanOpensAsARecordThatComposesNothingThatActs() throws {
        let code = try SourceScan.production(Self.screen)

        let wholeBranches = code.ranges(of: "if viewModel.isCompleted {").count
        try #require(
            wholeBranches == 1,
            "the screen carries \(wholeBranches) `if viewModel.isCompleted {` branches, expected exactly 1"
        )
        let branches = SourceScan.closureBodies(after: "if viewModel.isCompleted", in: code)
        let branch = try #require(branches.first)
        #expect(
            trimmed(branch) == "record(for: wanted)",
            "a bought plan opens as something other than its record:\n\(branch)"
        )
        #expect(
            code.ranges(of: "record(for: wanted)").count == 1,
            "the record is composed \(code.ranges(of: "record(for: wanted)").count) times, expected exactly once"
        )

        let record = try recordBody()

        // The control: the record is really the bought plan's face.
        #expect(record.contains("heading(SellPlanCopy.completed, for: wanted)"), "the record isn't headed Completed — wrong target?")
        #expect(record.contains("Text(SellPlanCopy.bought(on: boughtOn))"), "the record doesn't say when it was bought")
        #expect(
            record.contains("Text(SellPlanCopy.nothingSoldToward)"),
            "a record with no sales says nothing at all, rather than that nothing was sold toward it"
        )

        // The record hosts `soldSection`, which draws `soldRow(_:)` — so what
        // the record composes is all three bodies, and a control added to
        // either of the other two lands on the record as surely as one added
        // to it directly. Each anchor is required once before it is read.
        let sections = SourceScan.closureBodies(after: "private var soldSection: some View", in: code)
        try #require(sections.count == 1, "the screen declares \(sections.count) soldSection bodies, expected exactly 1")
        let section = try #require(sections.first)
        let rows = SourceScan.closureBodies(after: "private func soldRow(_ item: Item) -> some View", in: code)
        try #require(rows.count == 1, "the screen declares \(rows.count) soldRow(_:) bodies, expected exactly 1")
        let row = try #require(rows.first)

        let acting = [
            "candidateList", "SellPlanRow", "figures(", "saleCandidate", "isMarkingBought", "viewModel.toggle",
            "Button(", "NavigationLink", ".swipeActions", ".onTapGesture", "markSold",
        ]
        for (name, body) in [("record(for:)", record), ("soldSection", section), ("soldRow(_:)", row)] {
            for control in acting {
                #expect(
                    !body.contains(control),
                    "\(name) composes `\(control)` — a bought plan offers no candidate, no selection, no sale and no purchase, and nothing else that acts (criterion 9)"
                )
            }
        }
    }

    /// Delete is a red bar button of its own, offered only while there is a
    /// plan to delete, and set apart from Buy (plan Q12 as amended at the
    /// Phase 3 walkthrough): inside the toolbar's `offersDelete` gate —
    /// required whole — a fixed `ToolbarSpacer` and then one top-right item
    /// holding one `.destructive` button, whose whole action is raising the
    /// confirmation, so Delete still takes its second tap. The spacer is
    /// what splits the shared glass capsule iOS 26 draws around adjacent bar
    /// items; it is required to sit ahead of the item, between it and Buy.
    /// And no "…" anywhere on the screen: no `DetailOverflowMenu` and no
    /// system `Menu`, since a menu of one row read as a menu with nothing in
    /// it.
    ///
    /// Mutations: put the Delete back into a "…" → red; drop the spacer, or
    /// move it after the item → red; move the button out of the gate → red;
    /// drop `.destructive` → red.
    @Test func theDeleteIsARedButtonOfItsOwnApartFromBuyOfferedOnlyWhileThereIsAPlan() throws {
        let code = try SourceScan.production(Self.screen)

        let toolbars = SourceScan.closureBodies(after: ".toolbar", in: code)
        try #require(toolbars.count == 1, "the plan carries \(toolbars.count) toolbars, expected exactly 1")
        let toolbar = try #require(toolbars.first)

        let wholeGates = code.ranges(of: "if viewModel.offersDelete {").count
        try #require(
            wholeGates == 1,
            "the plan carries \(wholeGates) `if viewModel.offersDelete {` gates, expected exactly 1"
        )
        let gates = SourceScan.closureBodies(after: "if viewModel.offersDelete", in: toolbar)
        try #require(gates.count == 1, "the toolbar carries \(gates.count) `offersDelete` gates, expected exactly 1")
        let gate = try #require(gates.first)

        // The separation: the spacer, whole, ahead of the item.
        let spacer = try #require(
            gate.range(of: "ToolbarSpacer(.fixed, placement: .topBarTrailing)"),
            "nothing sets Delete apart from Buy \u{2014} adjacent bar items share one glass capsule:\n\(gate)"
        )
        let item = try #require(
            gate.range(of: "ToolbarItem(placement: .topBarTrailing)"),
            "Delete isn't a top-right bar item:\n\(gate)"
        )
        #expect(
            spacer.upperBound <= item.lowerBound,
            "the spacer sits after Delete rather than between it and Buy:\n\(gate)"
        )

        // One button, red, whose whole action raises the confirmation.
        let deletes = code.ranges(of: "Button(role: .destructive)").count
        try #require(deletes == 1, "the plan carries \(deletes) `Button(role: .destructive)` buttons, expected exactly 1")
        let buttons = SourceScan.closureBodies(after: "Button(role: .destructive)", in: gate)
        try #require(buttons.count == 1, "the red Delete isn't inside the offersDelete gate:\n\(gate)")
        #expect(
            trimmed(buttons[0]) == "isConfirmingDelete = true",
            "Delete does something other than raise the confirmation \u{2014} it keeps its second tap:\n\(buttons[0])"
        )
        #expect(
            gate.contains("Text(SellPlanCopy.deleteConfirm)"),
            "the button doesn't wear SellPlanCopy's word Delete:\n\(gate)"
        )

        // No "…" on this screen at all.
        #expect(
            !code.contains("DetailOverflowMenu"),
            "the plan builds a \u{2026} again \u{2014} Delete is a button of its own"
        )
        let systemMenu = try Regex(#"(?:^|[^A-Za-z0-9_])Menu\s*[({]"#)
        #expect(!code.contains(systemMenu), "the plan builds a menu again \u{2014} Delete is a button of its own")
    }

    /// Both sides say what will happen before it happens (criterion 11), in
    /// `SellPlanCopy`'s words, and confirming pops the screen only when the
    /// delete took — a refused save rolls back and leaves the screen correct
    /// where it stands. The destructive action is compared whole, so a
    /// `dismiss()` anywhere else in it fails.
    ///
    /// Mutations: dismiss outside the `deletePlan()` branch → red; read the
    /// store from the view → red.
    @Test func confirmingTheDeletePopsTheScreenOnlyOnceItTook() throws {
        let code = try SourceScan.production(Self.screen)

        let alerts = SourceScan.argumentLists(of: ".alert", in: code)
            .filter { $0.contains("isPresented: $isConfirmingDelete") }
        try #require(alerts.count == 1, "the plan carries \(alerts.count) delete alerts, expected exactly 1")
        #expect(
            alerts[0].contains("SellPlanCopy.deleteTitle(for: viewModel.wishlistItem?.name"),
            "the alert's title isn't SellPlanCopy's:\n\(alerts[0])"
        )

        let actionLists = SourceScan.closureBodies(after: "isPresented: $isConfirmingDelete", in: code)
        try #require(actionLists.count == 1, "found \(actionLists.count) delete alert action lists, expected exactly 1")
        let actions = try #require(actionLists.first)

        let confirms = SourceScan.closureBodies(
            after: "Button(SellPlanCopy.deleteConfirm, role: .destructive)",
            in: actions
        )
        try #require(confirms.count == 1, "the alert carries \(confirms.count) destructive Delete buttons, expected exactly 1")
        #expect(
            trimmed(confirms[0]) == "if viewModel.deletePlan() { dismiss() }",
            "confirming does something other than delete and pop only once it took:\n\(confirms[0])"
        )
        #expect(
            actions.contains("Button(SellPlanCopy.deleteCancel, role: .cancel) {}"),
            "the alert has no way out that keeps the plan:\n\(actions)"
        )

        let messages = SourceScan.closureBodies(after: "message:", in: code)
            .filter { $0.contains("SellPlanCopy.deleteMessage") }
        try #require(messages.count == 1, "found \(messages.count) delete messages, expected exactly 1")
        #expect(
            trimmed(messages[0]) == "Text(SellPlanCopy.deleteMessage(isCompleted: viewModel.isCompleted))",
            "the message doesn't say which side's plan is going:\n\(messages[0])"
        )

        #expect(
            code.ranges(of: "viewModel.deletePlan()").count == 1,
            "the plan is deleted from \(code.ranges(of: "viewModel.deletePlan()").count) places, expected exactly 1"
        )
        #expect(
            !code.contains("SellPlanStore"),
            "the screen names the plan store directly — the write belongs behind the view model"
        )
    }
}

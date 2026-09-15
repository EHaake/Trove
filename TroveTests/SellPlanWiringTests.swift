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
}

import Foundation
import Testing
@testable import Trove

/// T014. What the item detail does once an item is sold, pinned as source
/// scans — the `ImportWiringTests` / `MarketWiringTests` shape, for the same
/// reason: no unit test can open a system menu or read a rendered page, and
/// what a scan *can* catch is the wiring quietly changing out from under the
/// spec (criteria 1, 8 and 9, plan Q8).
///
/// Every scan `#require`s its anchor before asserting anything about it
/// (`CLAUDE.md` Testing, plan §10): a branch that has been renamed away fails
/// loudly here rather than passing over a span that no longer exists.
@Suite("Sold state wiring")
struct SoldStateWiringTests {
    private nonisolated static let detail = "Trove/Views/Items/ItemDetailView.swift"
    private nonisolated static let menu = "Trove/Views/Shared/DetailOverflowMenu.swift"
    private nonisolated static let wishlistDetail = "Trove/Views/Wishlist/WishlistDetailView.swift"

    /// The content of `content(for:)`, which every layout scan below works
    /// over: the whole file would also see the preview and the helpers, and
    /// the claim is about what the page *composes*.
    private func pageContent() throws -> String {
        let code = try SourceScan.production(Self.detail)
        let bodies = SourceScan.closureBodies(
            after: "private func content(for item: Item) -> some View",
            in: code
        )
        try #require(bodies.count == 1, "the detail declares \(bodies.count) content(for:) bodies, expected exactly 1")
        return try #require(bodies.first)
    }

    /// The sold branch of the page — `#require`d to be found exactly once, so
    /// nothing below can assert over an empty string. Mutation: rename the
    /// `if viewModel.isSold` anchor → this fails.
    private func soldBranch() throws -> String {
        let content = try pageContent()
        let branches = SourceScan.closureBodies(after: "if viewModel.isSold", in: content)
        try #require(
            branches.count == 1,
            "content(for:) has \(branches.count) `if viewModel.isSold` branches, expected exactly 1"
        )
        return try #require(branches.first)
    }

    // MARK: - The two menus (criteria 1 and 8)

    /// Both middle rows and the sold page's edit label are `SaleCopy`'s
    /// words, never typed here — the sheet's title and the menu row that
    /// opens it have to say the same thing.
    @Test func bothMenuRowsAndTheSoldEditLabelReadSaleCopy() throws {
        let code = try SourceScan.production(Self.detail)

        let rows = SourceScan.argumentLists(of: "DetailOverflowMenu.Row", in: code)
        try #require(rows.count == 4, "the detail builds \(rows.count) menu rows, expected 4 (two menus of two)")

        for (member, action) in [
            ("SaleCopy.markAsSold", "viewModel.saleSheet = .mark"),
            ("SaleCopy.editSale", "viewModel.saleSheet = .edit"),
            ("SaleCopy.returnToCollection", "isConfirmingReturn = true"),
        ] {
            let matching = rows.filter { $0.contains(member) }
            #expect(matching.count == 1, "\(member) labels \(matching.count) rows, expected exactly 1")
            #expect(
                matching.first?.contains(action) == true,
                "the \(member) row doesn't do `\(action)`: \(matching.first ?? "—")"
            )
        }

        // The control: the owned page's first row is still the item's own
        // Edit, so the scan above is reading two menus rather than one.
        #expect(
            rows.contains { $0.contains("isEditing = true") },
            "no row opens the item form — the owned menu lost its Edit"
        )
    }

    /// One menu composition, with the rows swapped by `isSold` — criterion
    /// 8's "exactly Edit sale…, Return to collection… and Delete", and the
    /// reason `MenuPolicyTests` still sees one system `Menu`.
    @Test func theMenuIsComposedOnceWithItsRowsSwappedByTheSoldFlag() throws {
        let code = try SourceScan.production(Self.detail)

        let menus = SourceScan.argumentLists(of: "DetailOverflowMenu", in: code)
            .filter { $0.contains("noun:") }
        try #require(menus.count == 1, "the detail composes \(menus.count) overflow menus, expected exactly 1")
        let composed = try #require(menus.first)

        #expect(
            composed.contains("edit: viewModel.isSold ?"),
            "the edit row doesn't follow the sold flag: \(composed)"
        )
        #expect(
            composed.contains("middle: viewModel.isSold ?"),
            "the middle row doesn't follow the sold flag: \(composed)"
        )
    }

    /// `DetailOverflowMenu` stays the app's one system `Menu` — the existing
    /// allowlist (`MenuPolicyTests`) re-confirmed from the other side, so a
    /// second menu added for the sold rows fails here as well as there.
    @Test func theOverflowMenuHostsExactlyOneSystemMenu() throws {
        let code = try SourceScan.production(Self.menu)
        let menus = code.ranges(of: "Menu {").count
        #expect(menus == 1, "DetailOverflowMenu hosts \(menus) system menus, expected exactly 1")
        #expect(
            code.contains("if let middle {"),
            "the middle row is no longer optional — WishlistDetailView's menu would grow one"
        )
    }

    /// The kept initializer, from the caller's side: the wishlist's page is
    /// untouched by this spec, and it names none of its words.
    @Test func theWishlistPageKeepsTheOriginalMenuAndNamesNoSaleCopy() throws {
        let code = try SourceScan.production(Self.wishlistDetail)

        #expect(
            code.contains("DetailOverflowMenu("),
            "the wishlist page no longer composes the overflow menu — wrong scan target?"
        )
        #expect(
            !code.contains("SaleCopy"),
            "the wishlist page names SaleCopy — selling is the owned side's business"
        )
        #expect(
            !code.contains("DetailOverflowMenu.Row"),
            "the wishlist page builds menu rows — it should still use the (noun:edit:delete:) initializer"
        )
    }

    // MARK: - The sold page (criterion 8, plan Q8)

    /// The mark is composed, and composed only in the sold branch.
    @Test func theSoldBranchStampsTheMark() throws {
        let content = try pageContent()
        let branch = try soldBranch()

        #expect(branch.contains("SoldMark("), "the sold page doesn't stamp the Sold mark")
        #expect(
            content.ranges(of: "SoldMark(").count == 1,
            "the Sold mark is composed more than once — an owned page would show it too"
        )
        #expect(
            branch.contains("viewModel.sale") && branch.contains("viewModel.saleOutcome"),
            "the mark is built from something other than the view model's sale and outcome"
        )
    }

    /// Q8, the whole of it: what would *act* is left out of the sold page.
    /// The controls prove the scan is reading the real page — both live on
    /// in the owned branch — and the mutation is moving either of them out
    /// of the `else`.
    @Test func theSoldBranchOmitsTheMarketSectionAndFindAPhoto() throws {
        let content = try pageContent()
        let branch = try soldBranch()

        #expect(content.contains("marketSection(for: item)"), "the page draws no Market section at all — wrong target?")
        #expect(content.contains("findPhotoAction"), "the page offers Find a photo… nowhere — wrong target?")

        #expect(!branch.contains("marketSection("), "a sold item's page draws the Market section (Q8)")
        #expect(!branch.contains("MarketSection("), "a sold item's page builds a Market section (Q8)")
        #expect(!branch.contains("findPhotoAction"), "a sold item's page offers Find a photo… (Q8)")
        #expect(!branch.contains("canFindPhoto"), "a sold item's page still asks whether it may fetch a photo (Q8)")
    }

    /// The dial comes along for the read only (Q8): the sold branch's card is
    /// built `isInteractive: false`, the owned one true.
    @Test func theSoldPagesDialIsNotInteractive() throws {
        let content = try pageContent()
        let branch = try soldBranch()

        #expect(
            branch.contains("desireCard(for: item, isInteractive: false)"),
            "a sold item's dial is still editable (Q8)"
        )
        #expect(
            content.contains("desireCard(for: item, isInteractive: true)"),
            "the owned page's dial stopped being editable — the flag is wired the wrong way round"
        )
    }

    /// The sheet and the alert the two new menu rows lead to (criterion 9):
    /// one `.sheet(item:)` over the view model's optional, and the return
    /// alert's three strings from `SaleCopy`.
    @Test func theSaleSheetAndReturnAlertAreHostedHere() throws {
        let code = try SourceScan.production(Self.detail)

        #expect(
            code.contains(".sheet(item: $viewModel.saleSheet"),
            "the sale sheet isn't presented over the view model's saleSheet"
        )
        #expect(code.contains("SaleFormView("), "the detail doesn't host the sale sheet")
        #expect(
            code.contains("viewModel.makeSaleFormViewModel()"),
            "the sheet's view model is built somewhere other than the factory"
        )

        // Mark records a sale, Edit corrects one — and never the other way
        // round (G21: `editSale` must not route through `markSold`).
        let record = SourceScan.closureBodies(after: "private func record(", in: code)
        try #require(record.count == 1, "the detail declares \(record.count) record(_:from:), expected exactly 1")
        #expect(record[0].contains("case .mark: viewModel.markSold(sale)"), "Mark as sold… doesn't record a sale")
        #expect(record[0].contains("case .edit: viewModel.editSale(sale)"), "Edit sale… doesn't correct the sale")

        for member in ["SaleCopy.returnTitle", "SaleCopy.returnMessage", "SaleCopy.returnConfirm", "SaleCopy.returnCancel"] {
            #expect(code.contains(member), "the return alert doesn't read \(member)")
        }
        #expect(
            code.contains("viewModel.returnToCollection()"),
            "the return alert's confirm button doesn't return the item"
        )
    }

    /// The delete alert speaks for the side the item is on (P13, G17) — the
    /// call `ItemDeleteCopy.message(isSold:)` rather than the owned message
    /// on both.
    @Test func theDeleteAlertAsksTheItemWhichSideItIsOn() throws {
        let code = try SourceScan.production(Self.detail)
        #expect(
            code.contains("ItemDeleteCopy.message(isSold:"),
            "the delete alert promises the same thing on both sides"
        )
    }

    // MARK: - Colour (plan Q11)

    /// Every surface that shows an outcome maps the model's `isLoss` to the
    /// theme's rust/moss text tokens, and none of them re-derives the rule
    /// from the sign of a figure of its own or names a colour literal.
    ///
    /// Every surface on the list now exists — the Sold mark, the Sold side's
    /// row, the Dashboard's card and the Sold side's summary line — so none
    /// of them is skipped by name any more (T017a/B2). A path that can't be
    /// read throws out of `SourceScan.production` instead of being passed
    /// over, and the `#require` below is the second lock: it records what was
    /// actually scanned, so a skip arm put back here fails rather than
    /// quietly covering nothing.
    @Test func everySoldSurfaceMapsIsLossToTheRustAndMossTokens() throws {
        let surfaces = [
            "Trove/Views/Items/SoldMark.swift",
            "Trove/Views/Items/SoldItemRow.swift",
            "Trove/Views/Dashboard/SoldCard.swift",
            "Trove/Views/Items/ItemListView.swift",
        ]
        var scanned: [String] = []

        for path in surfaces {
            let code = try SourceScan.production(path)
            scanned.append(path)

            #expect(code.contains("isLoss"), "\(path) shows an outcome without reading the model's isLoss rule")
            #expect(
                code.contains("theme.colors.accentRustText"),
                "\(path) doesn't paint a loss with the rust text token"
            )
            #expect(
                code.contains("theme.colors.accentMossText"),
                "\(path) doesn't paint a gain with the moss text token"
            )
            #expect(
                !code.contains("Color(hex:"),
                "\(path) names a colour literal instead of a theme token"
            )
        }

        try #require(
            scanned == surfaces,
            "the scan covered \(scanned) rather than every sold surface — the rest are unguarded"
        )
    }

    /// The mark's own wiring: `SaleCopy`'s composed lines, no copy typed
    /// inline, and the one accessibility element criterion 16 asks for.
    @Test func theMarkReadsSaleCopyAndAnnouncesItselfAsOneElement() throws {
        let code = try SourceScan.production("Trove/Views/Items/SoldMark.swift")

        for member in ["SaleCopy.soldMark", "SaleCopy.pageOutcome(", "SaleCopy.saleLine("] {
            #expect(code.contains(member), "the Sold mark doesn't read \(member)")
        }
        #expect(
            code.contains(".accessibilityElement(children: .combine)"),
            "the Sold mark isn't announced as one element (criterion 16)"
        )
        #expect(code.contains("sold.mark"), "the Sold mark carries no identifier")

        let inlined = SourceScan.stringLiterals(in: code).filter { $0.contains(" ") }
        #expect(inlined.isEmpty, "copy typed inline in the Sold mark: \(inlined)")
    }
}

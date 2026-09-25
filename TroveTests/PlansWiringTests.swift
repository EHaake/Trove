import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// How the Plans tab is wired (spec `009`). T010 opens it with G18; T011
/// adds G19, the screen's view-body facts, as source scans that each
/// `#require` their anchor.
@Suite("Plans wiring")
@MainActor
struct PlansWiringTests {
    // MARK: - The side switch (plan §10, Q14)

    /// G18: every label of both side switches fits its half. Each word is
    /// rendered on a scratch `ImageRenderer` at the font the switch draws it
    /// in — `SideSwitchMetrics.labelFont`, at both weights, since the active
    /// half lifts to medium — and must be narrower than the switch's own half
    /// less 4 pt either side. The words and the widths are read off switches
    /// built through each screen's own `init(side:select:)`, so a label or a
    /// half changed in production lands in this measurement rather than being
    /// typed out here.
    ///
    /// Mutation (T010): the Plans half at 50 pt → red on "Completed".
    @Test func everyLabelOfBothSwitchesFitsItsHalf() throws {
        let items = SideSwitch(side: ItemListViewModel.Side.owned, select: { _ in })
        let plans = SideSwitch(side: PlansViewModel.Side.active, select: { _ in })

        let switches: [(name: String, labels: [String], halfWidth: CGFloat)] = [
            ("Items", [items.leadingLabel, items.trailingLabel], items.halfWidth),
            ("Plans", [plans.leadingLabel, plans.trailingLabel], plans.halfWidth),
        ]

        for control in switches {
            let room = control.halfWidth - 2 * 4
            for label in control.labels {
                try #require(!label.isEmpty, "the \(control.name) switch has an empty label")
                for isActive in [false, true] {
                    let width = try labelWidth(label, isActive: isActive)
                    #expect(
                        CGFloat(width) < room,
                        "the \(control.name) switch's \"\(label)\" measures \(width) pt at \(isActive ? "medium" : "regular"), not narrower than its \(control.halfWidth) pt half less 4 pt either side (\(room) pt)"
                    )
                }
            }
        }
    }

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

    /// G19, criterion 5: the switch reports through `show(_:)` and is never
    /// bound (no `$` projection in its arguments), so changing side reloads and clears nothing.
    @Test func theSideSwitchReportsThroughShow() throws {
        let code = try SourceScan.production(Self.view)

        let calls = SourceScan.argumentLists(of: "SideSwitch", in: code)
        try #require(calls.count == 1, "the screen builds \(calls.count) side switches, expected exactly 1")
        #expect(calls[0].contains("viewModel.show"), "the switch doesn't report through `viewModel.show`: \(calls[0])")
        // A `$` projection, not the closure's own `$0`.
        let projection = try Regex(#"\$[A-Za-z_]"#)
        #expect(
            !calls[0].contains(projection),
            "the switch is bound — a side change must go through `show(_:)`: \(calls[0])"
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

    // MARK: - The instrument

    /// A label's rendered width at the switch's own type, at 1×.
    private func labelWidth(_ label: String, isActive: Bool) throws -> Int {
        try #require(
            renderBitmap(Text(label).font(SideSwitchMetrics.labelFont(isActive: isActive))),
            "ImageRenderer produced nothing to measure for \"\(label)\"."
        ).width
    }
}

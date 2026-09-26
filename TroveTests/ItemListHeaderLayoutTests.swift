import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// G38 — spec criterion 3 as a height rather than as a sentence: the Items
/// header is one meta line tall whatever that line says and whatever the
/// sort badge beside it is called, so the `SideSwitch` under it sits at the
/// same point on both sides.
///
/// `006` Decision 13 made the meta slot unconditional, and the device pass at
/// T010 measured that necessary and not sufficient: the Sold summary still
/// wrapped, because the slot's *width* ended where the sort badge began, and
/// the badge only arrived on the Sold side with `014` (plan Q18). A source
/// scan cannot see a wrap, and the device pass that found it costs a person's
/// afternoon; the render can, off-device, in a second.
///
/// Every case measures the real ingredients — `SortMenu` and `OverflowBadge`
/// as the trailing row, a `.monoLabel()` line as the meta, the copy composed
/// by `SaleCopy` rather than typed out here — at the width the header is laid
/// out in on the device criterion 3 was measured on.
///
/// **Since `018` the badge row is measured on its own and stood in for.**
/// `ImageRenderer` can't render a glass `Menu` in place: in a `VStack` with
/// any sibling (which `ItemsListHeader` is) it kills the test process with
/// `precondition failure: invalid type ID: 0`, at every control size and
/// under `.fixedSize()`, `.compositingGroup()` or `.drawingGroup()` (T001's
/// probes). The row *does* render alone in its `HStack`, so
/// `badgeRowSize(sortLabel:)` measures it there, and the header is rendered
/// with a clear box of that size in the trailing slot. Nothing asserts that
/// the box matches the row it was measured from — that could only pass. Each case differs from
/// the baseline in something the *production* view controls; a case that
/// could only be reddened by editing this file guards nothing (T010a's
/// review found one and it was deleted).
///
/// Its mutations, all run at T010a: put the meta line back inside the leading
/// `VStack` beside the badges and every line long enough to wrap goes red;
/// render the baseline at width 200 instead and **all** of them go red, which
/// is what proves the instrument can see a wrap at all rather than only
/// agreeing with itself; fatten `OverflowBadge`'s vertical padding and the
/// empty-trailing case alone goes red, which is what made the 30 pt proviso
/// a measurement instead of a claim. T001 (`018`) re-ran all three
/// on the stand-in, and added a fourth: `SortMenu` at `.controlSize(.large)`
/// turned the proviso red, since its 45 pt badge is taller than the title's
/// line box.
///
/// **Since `018` T004a the badge row sets the header's height** (spec
/// Decision 16, plan Q6's pre-authorised rewrite): the person found the
/// 28 pt capsule squashed, `SortMenu` went to `.large`, and the proviso case
/// now pins the new relationship — header = badge row + 6 + one meta line on
/// both sides, and the header with no badges shorter than that. Its
/// mutations, run at T004a: the meta line back beside the badges → red;
/// `SortMenu` back at `.regular` → the rewritten proviso red.
@Suite("Items header layout")
@MainActor
struct ItemListHeaderLayoutTests {
    /// The iPhone 17 Pro's width as `T020`'s probe recorded it, less the two
    /// screen gutters the list's body applies — the width the header is
    /// actually given on the device where the switch was row-profiled at
    /// 154.33 pt and 168.00 pt.
    private let contentWidth: CGFloat = 402 - 2 * ThemeMetrics.standard.screenGutter

    /// The header at one meta line, whatever it reads and whatever stands
    /// beside it.
    ///
    /// The baseline is the zero-sales line under the Sold side's default
    /// label, measured rather than remembered as a number (the
    /// `DropdownPlacementTests` rule) — the title's type, the badges' padding
    /// or the mono line's leading could all move it, and every case is a
    /// comparison against this one rather than against a constant that would
    /// quietly describe last year's header. It is also the case the device
    /// pass found *healthy*: at "0 sold · $0" both sides read 154.33 pt, so a
    /// header that matches this one matches the Owned side.
    @Test func theHeaderIsOneMetaLineTallForEverySummaryAndEverySortLabel() throws {
        let baselineRow = try badgeRowSize(sortLabel: "Date sold")
        let baseline = try headerHeight(meta: soldSummary(count: 0, proceeds: 0, realised: 0), trailingSize: baselineRow)

        // The proviso as plan Q6 rewrote it (spec Decision 16, T004a): the
        // badges are at the system's control size, taller than the title's
        // line box, so the badge row — not the title — sets the header's
        // height, and it must do so the same way on both sides: badge row
        // plus the header's 6 pt spacing plus one meta line. The meta line is
        // measured alone, where it cannot wrap. Stripping the badges out must
        // then *drop* the height — if it doesn't, the title is driving it
        // again, and the relationship pinned below describes a header the
        // screen no longer draws.
        let withoutBadges = try #require(
            renderBitmap(
                ItemsListHeader(title: "Items") {
                    Text(soldSummary(count: 0, proceeds: 0, realised: 0)).monoLabel()
                } trailing: {
                    EmptyView()
                }
                .frame(width: contentWidth)
            ),
            "ImageRenderer produced nothing to measure."
        ).height

        // The Owned side's own line — Design's "34 ITEMS · $18,420" with the
        // unvalued count `ItemListView.summaryLine` appends — under the widest
        // label its Sort By can show. The same latent wrap lived here: nothing
        // about this defect was Sold-only once both sides carry a badge.
        let ownedWidest = try widestLabel(of: ItemListViewModel.SortOrder.allCases.map(\.label))
        let ownedRow = try badgeRowSize(sortLabel: ownedWidest)
        let owned = try headerHeight(meta: "34 items · $18,420 · 3 unvalued", trailingSize: ownedRow)

        // And the Owned line at a size a serious collection reaches: "full
        // width" is not the same claim as "never wraps", and this is the case
        // that would notice the difference on this side.
        let ownedLarge = try headerHeight(meta: "1,284 items · $1,248,200 · 37 unvalued", trailingSize: ownedRow)

        // The seeded Sold collection's line at a plausible size — the shape
        // the device pass measured wrapping.
        let sold = try headerHeight(meta: soldSummary(count: 6, proceeds: 398_500, realised: 10_500), trailingSize: baselineRow)

        // The same line at figures that will not fit in any reading of "about
        // 232 pt", under the widest label `SoldSortOrder` offers — so a longer
        // label added later cannot sneak past this suite either.
        let soldWidest = try widestLabel(of: ItemListViewModel.SoldSortOrder.allCases.map(\.label))
        let soldLarge = try headerHeight(
            meta: soldSummary(count: 999, proceeds: 124_820_000, realised: 11_245_000),
            trailingSize: try badgeRowSize(sortLabel: soldWidest)
        )

        let soldMetaLine = try metaLineHeight(soldSummary(count: 0, proceeds: 0, realised: 0))
        let ownedMetaLine = try metaLineHeight("34 items · $18,420 · 3 unvalued")

        print("ItemsListHeader heights at width \(contentWidth) — badge row: \(baselineRow), owned badge row: \(ownedRow), meta line: sold \(soldMetaLine) owned \(ownedMetaLine), baseline: \(baseline), no badges: \(withoutBadges), owned under \"\(ownedWidest)\": \(owned), owned at scale: \(ownedLarge), sold: \(sold), sold at scale under \"\(soldWidest)\": \(soldLarge)")

        #expect(
            baseline == Int(baselineRow.height) + 6 + soldMetaLine,
            "the Sold header measured \(baseline) pt against its badge row's \(baselineRow.height) + 6 + one \(soldMetaLine) pt meta line — the badge row is no longer what sets the header's height (plan Q6 as rewritten, spec Decision 16)"
        )
        #expect(
            owned == Int(ownedRow.height) + 6 + ownedMetaLine,
            "the Owned header measured \(owned) pt against its badge row's \(ownedRow.height) + 6 + one \(ownedMetaLine) pt meta line — the badge row is no longer what sets the header's height (plan Q6 as rewritten, spec Decision 16)"
        )
        #expect(
            withoutBadges < baseline,
            "the header measured \(withoutBadges) pt with no badges against \(baseline) pt with them — stripping the badges didn't lower it, so the title and not the badge row is setting the header's height (plan Q6 as rewritten)"
        )
        #expect(
            owned == baseline,
            "the Owned summary under its widest sort label measured \(owned) pt against the one-line baseline's \(baseline) pt — the meta line wrapped, so the switch sits \(owned - baseline) pt lower on this side"
        )
        #expect(
            ownedLarge == baseline,
            "the Owned summary at a large collection's figures measured \(ownedLarge) pt against the one-line baseline's \(baseline) pt — the meta line wrapped, so the switch sits \(ownedLarge - baseline) pt lower on this side"
        )
        #expect(
            sold == baseline,
            "the Sold summary measured \(sold) pt against the one-line baseline's \(baseline) pt — the meta line wrapped, so the switch sits \(sold - baseline) pt lower on this side (criterion 3)"
        )
        #expect(
            soldLarge == baseline,
            "the Sold summary at six figures under the widest sold sort label measured \(soldLarge) pt against the one-line baseline's \(baseline) pt — the meta line wrapped, so the switch sits \(soldLarge - baseline) pt lower on this side (criterion 3)"
        )
    }

    /// P4 (`018`, T003): the sort badge is one width whatever it is set to.
    /// T002 filmed the glass capsule on iOS 26.5 keeping the previous label's
    /// width after a menu-driven relabel; with every option's label reserved
    /// under the visible one, a relabel has no width to change. The Owned
    /// side's real options, one render per selection over the same set.
    ///
    /// Its mutation, run at T003: the hidden labels removed from `SortMenu`'s
    /// label, and the widths split by label length → red.
    @Test func theSortBadgeIsOneWidthForEverySelection() throws {
        let options = ItemListViewModel.SortOrder.allCases
        try #require(options.count > 1, "one sort option can't show a width change")
        var widths: [String: Int] = [:]
        for selection in options {
            widths[selection.label] = try #require(
                renderBitmap(SortMenu(options: options, selection: selection, label: \.label) { _ in }),
                "ImageRenderer produced nothing to measure for the badge set to \"\(selection.label)\"."
            ).width
        }
        print("SortMenu widths over the Owned options, per selection: \(widths)")
        #expect(
            Set(widths.values).count == 1,
            "the sort badge's width follows its selection — \(widths) — so a relabel changes the capsule's width and iOS 26.5's stale-width tear returns (P4, T002)"
        )
    }

    /// The composition half, which the renders above cannot see: `G38`
    /// measures `ItemsListHeader`, and a screen that stopped composing it —
    /// or that passed the meta line into the badges' slot — would keep every
    /// height in this suite green while the device went back to 168.00 pt.
    /// The scan shape and its `#require`d anchors are `ItemListSidesWiringTests`'.
    @Test func theScreensHeaderPutsTheMetaLineUnderTheBadgesRatherThanBesideThem() throws {
        let code = try SourceScan.production("Trove/Views/Items/ItemListView.swift")
        let headers = SourceScan.closureBodies(after: "private var header: some View", in: code)
        try #require(headers.count == 1, "ItemListView declares \(headers.count) headers, expected exactly 1")
        let header = try #require(headers.first)

        let anchor = "ItemsListHeader(title: \"Items\")"
        try #require(
            header.contains(anchor),
            "the screen's header no longer composes `ItemsListHeader` — this suite would be measuring a view the screen doesn't use: \(header)"
        )

        let metaSlots = SourceScan.closureBodies(after: anchor, in: header)
        try #require(metaSlots.count == 1, "the header opens \(metaSlots.count) meta slots, expected exactly 1")
        let meta = try #require(metaSlots.first)
        #expect(
            meta.contains("metaLine"),
            "the header's meta slot doesn't carry `metaLine`: \(meta)"
        )

        let trailingSlots = SourceScan.closureBodies(after: "} trailing:", in: header)
        try #require(trailingSlots.count == 1, "the header opens \(trailingSlots.count) trailing slots, expected exactly 1")
        let trailing = try #require(trailingSlots.first)
        #expect(
            trailing.contains("sortControl") && trailing.contains("overflowControl"),
            "the badge row isn't in the header's trailing slot: \(trailing)"
        )
        #expect(
            !trailing.contains("metaLine"),
            "the meta line is back inside the badges' slot — the wrap this suite measures returns at the call site (plan Q18): \(trailing)"
        )
    }

    // MARK: - The instrument

    /// The header as the screen composes it: the title, a stand-in for the
    /// badge row the trailing slot carries on both sides since `014`, and one
    /// mono meta line — rendered at the device's content width, which is the
    /// only width at which "does this wrap" has an answer. The stand-in is a
    /// clear box at the size `badgeRowSize(sortLabel:)` measured (see the
    /// suite's comment for why the row itself can't be rendered here).
    ///
    /// `width` has no shipped caller: it exists so the instrument check
    /// (mutation (b) — render the baseline narrow and watch every case go
    /// red) can be run without restructuring the suite.
    private func headerHeight(meta: String, trailingSize: CGSize, width: CGFloat? = nil) throws -> Int {
        let header = ItemsListHeader(title: "Items") {
            Text(meta).monoLabel()
        } trailing: {
            Color.clear.frame(width: trailingSize.width, height: trailingSize.height)
        }
        return try #require(
            renderBitmap(header.frame(width: width ?? contentWidth)),
            "ImageRenderer produced nothing to measure."
        ).height
    }

    /// The badge row as `ItemListView` composes it — `SortMenu` beside
    /// `OverflowBadge`, 8 pt apart — rendered on its own, which works where
    /// rendering it inside the header does not.
    private func badgeRowSize(sortLabel: String) throws -> CGSize {
        let row = HStack(spacing: 8) {
            SortMenu(options: [sortLabel], selection: sortLabel, label: { $0 }) { _ in }
            OverflowBadge(isBusy: false) {}
        }
        let image = try #require(
            renderBitmap(row),
            "ImageRenderer produced nothing to measure for the badge row under \"\(sortLabel)\"."
        )
        return CGSize(width: image.width, height: image.height)
    }

    /// One meta line's height: the line rendered alone, at its own width, where
    /// it cannot wrap.
    private func metaLineHeight(_ meta: String) throws -> Int {
        try #require(
            renderBitmap(Text(meta).monoLabel()),
            "ImageRenderer produced nothing to measure for the meta line \"\(meta)\"."
        ).height
    }

    /// The Sold side's line through the one function that composes it, so a
    /// copy change lands in this measurement rather than being typed out here
    /// in a shape the screen no longer shows.
    private func soldSummary(count: Int, proceeds: Int, realised: Int) -> String {
        SaleCopy.soldSideSummary(
            SaleTotals(count: count, proceedsCents: proceeds, realisedDeltaCents: realised)
        )
    }

    /// The widest badge a sort menu can produce, measured: every label is
    /// rendered as a one-option `SortMenu` and the widest bitmap wins. Picking
    /// the longest string instead would be an unasserted claim about the
    /// badge's font, and the label that takes the most width from the meta
    /// line is the one this suite needs.
    private func widestLabel(of labels: [String]) throws -> String {
        try #require(!labels.isEmpty, "no sort labels to measure")
        var widest = ""
        var widestWidth = -1
        for label in labels {
            let width = try #require(
                renderBitmap(SortMenu(options: [label], selection: label, label: { $0 }) { _ in }),
                "ImageRenderer produced nothing to measure for the \"\(label)\" badge."
            ).width
            if width > widestWidth {
                widestWidth = width
                widest = label
            }
        }
        return widest
    }
}

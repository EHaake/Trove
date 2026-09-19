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
/// Every case measures the real ingredients — `SortBadge` and `OverflowBadge`
/// as the trailing row, a `.monoLabel()` line as the meta, the copy composed
/// by `SaleCopy` rather than typed out here — at the width the header is laid
/// out in on the device criterion 3 was measured on. Each case differs from
/// the baseline in something the *production* view controls; a case that
/// could only be reddened by editing this file guards nothing (T010a's
/// review found one and it was deleted).
///
/// Its mutations, all run at T010a: put the meta line back inside the leading
/// `VStack` beside the badges and every line long enough to wrap goes red;
/// render the baseline at width 200 instead and **all** of them go red, which
/// is what proves the instrument can see a wrap at all rather than only
/// agreeing with itself; fatten `OverflowBadge`'s vertical padding and the
/// empty-trailing case alone goes red, which is what makes the 30 pt proviso
/// below a measurement instead of a claim.
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
        let baseline = try headerHeight(meta: soldSummary(count: 0, proceeds: 0, realised: 0), sortLabel: "Date sold")

        // The proviso plan Q18 states: the header is the title's line box
        // plus 6 plus one meta line only while the title's box is at least
        // the badge row's 30 pt. Strip the badges out and the height must not
        // move — if it drops, the badge row was driving it, and every other
        // case here (all of which carry the same badges) would have agreed
        // with itself about the wrong number.
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
        let owned = try headerHeight(meta: "34 items · $18,420 · 3 unvalued", sortLabel: ownedWidest)

        // And the Owned line at a size a serious collection reaches: "full
        // width" is not the same claim as "never wraps", and this is the case
        // that would notice the difference on this side.
        let ownedLarge = try headerHeight(meta: "1,284 items · $1,248,200 · 37 unvalued", sortLabel: ownedWidest)

        // The seeded Sold collection's line at a plausible size — the shape
        // the device pass measured wrapping.
        let sold = try headerHeight(meta: soldSummary(count: 6, proceeds: 398_500, realised: 10_500), sortLabel: "Date sold")

        // The same line at figures that will not fit in any reading of "about
        // 232 pt", under the widest label `SoldSortOrder` offers — so a longer
        // label added later cannot sneak past this suite either.
        let soldWidest = try widestLabel(of: ItemListViewModel.SoldSortOrder.allCases.map(\.label))
        let soldLarge = try headerHeight(
            meta: soldSummary(count: 999, proceeds: 124_820_000, realised: 11_245_000),
            sortLabel: soldWidest
        )

        print("ItemsListHeader heights at width \(contentWidth) — baseline: \(baseline), no badges: \(withoutBadges), owned under \"\(ownedWidest)\": \(owned), owned at scale: \(ownedLarge), sold: \(sold), sold at scale under \"\(soldWidest)\": \(soldLarge)")

        #expect(
            withoutBadges == baseline,
            "the header measured \(withoutBadges) pt with no badges against \(baseline) pt with them — the badge row is taller than the title's line box, so it and not the title is setting the header's height (plan Q18's proviso)"
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

    /// The header as the screen composes it: the title, the badge row the
    /// trailing slot carries on both sides since `014`, and one mono meta
    /// line — rendered at the device's content width, which is the only width
    /// at which "does this wrap" has an answer.
    ///
    /// `width` has no shipped caller: it exists so the instrument check
    /// (mutation (b) — render the baseline narrow and watch every case go
    /// red) can be run without restructuring the suite.
    private func headerHeight(meta: String, sortLabel: String, width: CGFloat? = nil) throws -> Int {
        let header = ItemsListHeader(title: "Items") {
            Text(meta).monoLabel()
        } trailing: {
            HStack(spacing: 8) {
                SortBadge(label: sortLabel) {}
                OverflowBadge(isBusy: false) {}
            }
        }
        return try #require(
            renderBitmap(header.frame(width: width ?? contentWidth)),
            "ImageRenderer produced nothing to measure."
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
    /// rendered as the real `SortBadge` and the widest bitmap wins. Picking
    /// the longest string instead would be an unasserted claim about the
    /// badge's font, and the label that takes the most width from the meta
    /// line is the one this suite needs.
    private func widestLabel(of labels: [String]) throws -> String {
        try #require(!labels.isEmpty, "no sort labels to measure")
        var widest = ""
        var widestWidth = -1
        for label in labels {
            let width = try #require(
                renderBitmap(SortBadge(label: label) {}),
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

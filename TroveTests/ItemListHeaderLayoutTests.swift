import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// G38 — spec criterion 3 as a height rather than as a sentence: the Items
/// header is one meta line tall whatever that line says and whatever the
/// sort badge beside it is called, so the list under it sits at the same
/// point on both sides.
///
/// `006` Decision 13 made the meta slot unconditional, and the device pass at
/// T010 measured that necessary and not sufficient: the Sold summary still
/// wrapped, because the slot's *width* ended where the sort badge began, and
/// the badge only arrived on the Sold side with `014` (plan Q18). A source
/// scan cannot see a wrap, and the device pass that found it costs a person's
/// afternoon; the render can, off-device, in a second.
///
/// Every case measures the real ingredients — `SortMenu` and `OverflowMenu`
/// (`OverflowBadge` until `018` T005) as the trailing row, a `.monoLabel()` line as the meta, the copy composed
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
///
/// **Re-measured at `018` T004b** (spec Decision 17): `SortMenu` at
/// `.regular` with 4 pt of vertical padding on its label. The badge renders
/// 95 × 37 on the Owned side — 95 wide under every one of its seven
/// selections — and 102 × 37 on the Sold side; the badge row 145 × 37 on
/// the Owned side (under "Market ↓") and 152 × 37 on the Sold side (under
/// "Date sold"), `OverflowBadge` 42 × 30 beside it; the header 57 pt on both
/// sides against 53 pt with no badges, the meta line 14 pt — so 37 + 6 + 14
/// still holds and the badge row still sets the height. Its mutation: the
/// label's padding removed → the badge row falls to `OverflowBadge`'s 30 pt,
/// the header to 53 pt on both sides, level with the no-badge header, and
/// all three proviso expectations go red.
///
/// **At `018` T005** the row composes `OverflowMenu`, and `SortMenu` renders
/// over the side's real options set to the case's selection rather than as
/// a one-option menu, so the row is as wide as it ships. The badge row
/// renders 145 × 37 on the Owned side (under "Market ↓") and 152 × 37 on the
/// Sold side, `OverflowMenu` 42 × 36 beside it; the header 57 pt on both
/// sides against 53 pt with no badges. The Owned sort badge renders 95 × 37,
/// the Sold 102 × 37 — so `theTwoBadgesRenderAtOneHeight` reads 36 against
/// 37.
///
/// **Re-measured at `018` T006a** (spec Decision 18): Sort By sized to its
/// text, the "…" a glass circle on a 22 pt glyph row. The badge row renders
/// 146 × 37 on the Sold side (under "Date sold") and, on the Owned side, from
/// 113 × 37 under "Date" to 139 × 37 under "Market ↓"/"Market ↑" — so the
/// widest-label proviso case still measures the Owned side under "Market ↓".
/// The header is 57 pt on both sides and under every Owned label, against
/// 53 pt with no badges, the meta line 14 pt: 37 + 6 + 14 still holds. At 3×
/// the "…" renders 108 × 109 px, the Owned sort badge (under "Custom")
/// 245 × 109 and the Sold 305 × 109. `theSortBadgeIsOneWidthForEverySelection`
/// is retired with P4.
///
/// **At `018` T009a** (spec Decision 19) the side toggle joins the row,
/// leading Sort By, and its own row under the header goes: the badge row
/// is toggle, sort, "…" as `ItemListView` composes it, and the header's
/// relation — badge row + 6 + one meta line, on both sides and under every
/// Owned label — is re-measured with the toggle in it. The three controls
/// render at one height at 3×, the toggle on every side of both screens.
///
/// **At `018` T009b** (spec Decision 20) the screens' row becomes Sort By,
/// toggle, "…"; this suite still renders toggle, sort, "…" (see
/// `badgeRowSize` for why), which is the same size. Heights unchanged: the
/// badge row 228 × 37 on the Sold side (under "Date sold") and on the Owned
/// side from 200 × 37 under "Date" to 226 × 37 under "Market ↓"/"Market ↑";
/// the header 57 pt on both sides and under every Owned label, 53 pt with
/// no badges, the meta line 14 pt. At 3× the "…" 108 × 109 px, the toggles
/// 237 (Owned), 221 (Sold), 255 (Active) and 315 (Completed) × 109 px.
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
        let soldOptions = ItemListViewModel.SoldSortOrder.allCases
        let ownedOptions = ItemListViewModel.SortOrder.allCases
        let baselineRow = try badgeRowSize(side: .sold, options: soldOptions, selection: .soldDate, label: \.label)
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
        let ownedWidest = try widestLabel(of: ownedOptions.map(\.label))
        let ownedRow = try badgeRowSize(
            side: .owned,
            options: ownedOptions,
            selection: try #require(ownedOptions.first { $0.label == ownedWidest }),
            label: \.label
        )
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
        let soldWidest = try widestLabel(of: soldOptions.map(\.label))
        let soldLarge = try headerHeight(
            meta: soldSummary(count: 999, proceeds: 124_820_000, realised: 11_245_000),
            trailingSize: try badgeRowSize(
                side: .sold,
                options: soldOptions,
                selection: try #require(soldOptions.first { $0.label == soldWidest }),
                label: \.label
            )
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

    /// Spec Decision 18 (`018` T006a): Sort By is sized to its text, so the
    /// Owned side's badge row is narrower under its narrowest label than under
    /// its widest — and the header's height must not follow it, or the switch
    /// under it moves when the person changes the sort. Every Owned selection
    /// is rendered over the side's real options, the narrowest and the widest
    /// row are taken as measured, and the header is laid out around each.
    ///
    /// Its mutation, run at T006a: a fixed-height frame on `SortMenu`'s label
    /// keyed to the label → red.
    @Test func theHeaderIsOneHeightUnderTheNarrowestAndTheWidestOwnedLabel() throws {
        let options = ItemListViewModel.SortOrder.allCases
        var rows: [String: CGSize] = [:]
        for selection in options {
            rows[selection.label] = try badgeRowSize(side: .owned, options: options, selection: selection, label: \.label)
        }
        let narrowest = try #require(rows.min { $0.value.width < $1.value.width })
        let widest = try #require(rows.max { $0.value.width < $1.value.width })
        try #require(
            narrowest.value.width < widest.value.width,
            "every Owned sort label renders the badge row at one width — \(rows) — so this case can't see the header following the label"
        )
        let meta = "34 items · $18,420 · 3 unvalued"
        let narrowHeader = try headerHeight(meta: meta, trailingSize: narrowest.value)
        let wideHeader = try headerHeight(meta: meta, trailingSize: widest.value)
        print("Owned badge rows per selection: \(rows); header under \"\(narrowest.key)\": \(narrowHeader), under \"\(widest.key)\": \(wideHeader)")
        #expect(
            narrowHeader == wideHeader,
            "the Owned header measured \(narrowHeader) pt under \"\(narrowest.key)\" (row \(narrowest.value)) against \(wideHeader) pt under \"\(widest.key)\" (row \(widest.value)) — the header's height follows the sort label, so the switch moves when the sort changes (spec Decision 18)"
        )
    }

    /// The two badges render at one height (`018` plan §11, G1): `OverflowMenu`
    /// copies `SortMenu`'s control size and label padding (spec Decisions 16
    /// and 17), and its glyph row is one hidden line of the sort badge's label
    /// type (`SortMenuCopy.labelFont`), so the "…" beside Sort By is the same
    /// capsule height on both sides. Measured at 3× with exact equality, each
    /// rendered alone, against both sides' sort badges: at 1× a third of a
    /// point rounds away or up by accident, and a 14 pt glyph row (the height
    /// `OverflowBadge` used) is exactly that third short.
    ///
    /// Its mutations (T005): the glyph row back at `.frame(height: 14)` → red;
    /// `OverflowMenu` at `.controlSize(.small)` → red; the hidden line's font
    /// at size 12 → red. Since T006a the "…" is a glass circle (spec Decision
    /// 18) with a 22 pt glyph row; it renders here 108 × 109 px against both
    /// sort badges' 109 px. **The glyph row's width is untested off-device**:
    /// `ImageRenderer` draws the circle as width × the label's height, not at
    /// its diameter, so the row back at 18 pt wide renders 96 × 109 px and
    /// stays green, where the device draws a 32.67 pt circle. The circle's
    /// 36.67 × 36.33 is the device pass's to check (T009 films the header,
    /// T013 measures the circle); this test carries no tolerance (T005's
    /// decision review).
    ///
    /// Since T009a (spec Decision 19) the side toggle is the row's third
    /// control, rendered on every side of both screens against the "…": its
    /// glyph and word stand in one hidden line of the same label type. Its
    /// mutation (T009a): the toggle's line box removed → red.
    @Test func theThreeBadgesRenderAtOneHeight() throws {
        let toggles = [
            ("Owned", renderAt3x(SideToggle(side: ItemListViewModel.Side.owned, select: { _ in }))),
            ("Sold", renderAt3x(SideToggle(side: ItemListViewModel.Side.sold, select: { _ in }))),
            ("Active", renderAt3x(SideToggle(side: PlansViewModel.Side.active, select: { _ in }))),
            ("Completed", renderAt3x(SideToggle(side: PlansViewModel.Side.completed, select: { _ in }))),
        ]
        let overflow = try #require(
            renderAt3x(OverflowMenu { Button("Settings") {} }),
            "ImageRenderer produced nothing to measure for the \"…\" badge."
        )
        let owned = try #require(
            renderAt3x(SortMenu(options: ItemListViewModel.SortOrder.allCases, selection: .custom, label: \.label) { _ in }),
            "ImageRenderer produced nothing to measure for the Owned side's sort badge."
        )
        let sold = try #require(
            renderAt3x(SortMenu(options: ItemListViewModel.SoldSortOrder.allCases, selection: .soldDate, label: \.label) { _ in }),
            "ImageRenderer produced nothing to measure for the Sold side's sort badge."
        )
        print("Badge sizes at 3× — \"…\": \(overflow.width) × \(overflow.height) px, Owned sort: \(owned.width) × \(owned.height) px, Sold sort: \(sold.width) × \(sold.height) px")
        #expect(
            overflow.height == owned.height,
            "the \"…\" renders \(overflow.height) px tall at 3× beside the Owned side's \(owned.height) px sort badge — the two badges are no longer one height"
        )
        #expect(
            overflow.height == sold.height,
            "the \"…\" renders \(overflow.height) px tall at 3× beside the Sold side's \(sold.height) px sort badge — the two badges are no longer one height"
        )
        for (side, image) in toggles {
            let toggle = try #require(image, "ImageRenderer produced nothing to measure for the \(side) toggle.")
            print("Side toggle at 3× — \(side): \(toggle.width) × \(toggle.height) px")
            #expect(
                toggle.height == overflow.height,
                "the \(side) toggle renders \(toggle.height) px tall at 3× beside the \"…\"'s \(overflow.height) px — the three controls are no longer one height"
            )
        }
    }

    /// A view rendered at 3×, the device's scale, so a fraction of a point
    /// shows as whole pixels rather than rounding away.
    private func renderAt3x(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view.environment(\.theme, .dark))
        renderer.scale = 3
        return renderer.cgImage
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
            trailing.contains("SideToggle(") && trailing.contains("sortControl") && trailing.contains("overflowControl"),
            "the side toggle, Sort By and the \"…\" aren't all in the header's trailing slot — the title row holds the controls since T009a (spec Decision 19): \(trailing)"
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

    /// The badge row as `ItemListView` composes it — the side's
    /// `SideToggle` (since T009a), `SortMenu` over the side's real options
    /// set to the case's selection, and `OverflowMenu`, 8 pt apart — rendered on its own, which works where rendering it
    /// inside the header does not. Over the side's real option set, as it
    /// ships (`018` T005); since T006a (spec Decision 18) the badge is sized
    /// to the selection's text, so the row's width follows the selection.
    ///
    /// **Not the shipped order since T009b** (spec Decision 20): the screens
    /// compose Sort By, then the toggle, then the "…", but `ImageRenderer`
    /// kills the test process (`precondition failure: invalid type ID`) when a
    /// glass `Menu` precedes a glass `Button` in the row, even nested in an
    /// inner `HStack`. An `HStack` at one spacing is the same size in any
    /// order — the widths summed plus the gaps, the tallest child's height —
    /// so the numbers hold. The order itself is pinned by the wiring suites'
    /// `theControlRowIsSortThenToggleThenOverflow`.
    private func badgeRowSize<Option: Hashable>(
        side: ItemListViewModel.Side,
        options: [Option],
        selection: Option,
        label: @escaping (Option) -> String
    ) throws -> CGSize {
        let row = HStack(spacing: 8) {
            SideToggle(side: side, select: { _ in })
            SortMenu(options: options, selection: selection, label: label) { _ in }
            OverflowMenu { Button("Settings") {} }
        }
        let image = try #require(
            renderBitmap(row),
            "ImageRenderer produced nothing to measure for the badge row under \"\(label(selection))\"."
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

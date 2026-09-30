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
/// (the bespoke "…" badge until `018` T005) as the trailing row, a `.monoLabel()` line as the meta, the copy composed
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
/// agreeing with itself; fatten the bespoke "…" badge's vertical padding and the
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
/// "Date sold"), the bespoke "…" badge 42 × 30 beside it; the header 57 pt on both
/// sides against 53 pt with no badges, the meta line 14 pt — so 37 + 6 + 14
/// still holds and the badge row still sets the height. Its mutation: the
/// label's padding removed → the badge row falls to the "…" badge's 30 pt,
/// the header to 53 pt on both sides, level with the no-badge header, and
/// all three proviso expectations go red.
///
/// **At `018` T005** the row composes `OverflowMenu`, and `SortMenu` renders
/// over the side's real options set to the case's selection rather than as
/// a one-option menu, so the row is as wide as it ships. The badge row
/// renders 145 × 37 on the Owned side (under "Market ↓") and 152 × 37 on the
/// Sold side, `OverflowMenu` 42 × 36 beside it; the header 57 pt on both
/// sides against 53 pt with no badges. The Owned sort badge renders 95 × 37,
/// the Sold 102 × 37 — 36 against 37 at 1×, a third of a point rounded
/// apart. `theTwoBadgesRenderAtOneHeight` (since T009a
/// `theThreeBadgesRenderAtOneHeight`) therefore measures at 3×, where the
/// "…" and both sort badges render 109 px tall, exactly equal.
///
/// **Re-measured at `018` T006a** (spec Decision 18): Sort By sized to its
/// text, the "…" a glass circle on a 22 pt glyph row. The badge row renders
/// 146 × 37 on the Sold side (under "Date sold") and, on the Owned side, from
/// 113 × 37 under "Date" to 139 × 37 under "Market ↓"/"Market ↑" — so the
/// widest-label proviso case still measures the Owned side under "Market ↓".
/// The header is 57 pt on both sides and under every Owned label, against
/// 53 pt with no badges, the meta line 14 pt: 37 + 6 + 14 still holds. At 3×
/// the "…" renders 108 × 109 px, the Owned sort badge (under "Custom")
/// 245 × 109 and the Sold 305 × 109. The case that held Sort By at one width
/// for every selection is retired with P4.
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
///
/// **At `018` T009d** (spec Decision 21) the toggle is the wider side's
/// width on both sides: at 3× Owned and Sold 237 × 109 px, Active and
/// Completed 315 × 109 px. The Sold badge row widens to 233 × 37 under
/// "Date sold"; the Owned rows are unchanged (to 226 × 37 under
/// "Market ↓"). Heights unchanged: the header 57 pt on both sides and under
/// every Owned label, 53 pt with no badges, the meta line 14 pt, every
/// badge 109 px tall at 3×.
///
/// **At `018` T009e** (spec Decision 22) the title's baseline sits on the
/// controls' bottom edge (`TitleRowLayout`) and the meta line midway between
/// the title row and what follows (`MetaLineSpacing`): the header is the
/// badge row + 15 + one meta line — 66 pt on both sides and under every
/// Owned label, 55 pt with no badges (the row falls to the title's baseline),
/// the meta line 14 pt. G38's 6 is now `MetaLineSpacing.split(before:)`
/// over the `sectionGap` a search field follows. The new cases below render
/// at 3×, exact; see each for its measurements and mutations.
///
/// **At `018` T009f** (spec Decision 23) the list screens' title is
/// `listTitle`, 34 pt, drawn by `ListTitle` and centred on the controls. Its
/// line box is 37 pt, level with the badge row: the header is still 66 pt on
/// both sides and under every Owned label, and with no badges it is now
/// 66 pt too (the title's 37 pt line box in the row's place) where it was
/// 55 — so the proviso is the measured equality rather than "shorter". The
/// search field stays at 81 pt, Plans' first card at 52 pt. The title
/// shrinks to fit rather than truncating where a narrower phone leaves it
/// less room; the last two cases measure both widths.
@Suite("Items header layout")
@MainActor
struct ItemListHeaderLayoutTests {
    /// The iPhone 17 Pro's width as `T020`'s probe recorded it, less the two
    /// screen gutters the list's body applies — the width the header is
    /// actually given on the device where the switch was row-profiled at
    /// 154.33 pt and 168.00 pt.
    private let contentWidth: CGFloat = 402 - 2 * ThemeMetrics.standard.screenGutter

    /// The same on the 375 pt phones — the narrowest the app runs on, where
    /// the title has least room beside the controls (spec Decision 23).
    private let narrowContentWidth: CGFloat = 375 - 2 * ThemeMetrics.standard.screenGutter

    /// The header at one meta line, whatever it reads and whatever stands
    /// beside it.
    ///
    /// The baseline is the zero-sales line under the Sold side's default
    /// label, measured rather than remembered as a number (the rule
    /// the retired dropdown placement suite kept) — the title's type, the badges' padding
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
        // badges are at `SortMenu`'s `.regular` size and label padding (spec
        // Decision 17, T004b), so the badge row — not the title — sets the
        // header's height, and it must do so the same way on both sides: badge row
        // plus the meta line's share of the gap under the header (spec
        // Decision 22, T009e) plus one meta line. The meta line is
        // measured alone, where it cannot wrap. Stripping the badges out
        // leaves the title's own line box in the row's place (spec Decision
        // 23, T009f). Until T009f that came out *shorter* than the badge
        // row, and the proviso said so; at 34 pt the title's line box is
        // 37 pt, the badge row's own height, so "shorter" is no longer the
        // geometry and the proviso is the equality it measures instead: the
        // title's line box, the same share of the gap, one meta line. A row
        // that kept any other height with its slot empty — the controls'
        // zero, a leftover minimum — fails it.
        let withoutBadges = try #require(
            renderBitmap(
                ItemsListHeader(title: "Items", gapBelow: ThemeMetrics.standard.sectionGap) {
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
        let titleLineBox = try #require(
            renderBitmap(ListTitle("Items").fixedSize()),
            "ImageRenderer produced nothing to measure for the title alone."
        ).height
        let metaGap = Int(MetaLineSpacing.split(before: ThemeMetrics.standard.sectionGap))
        let ownedMetaLine = try metaLineHeight("34 items · $18,420 · 3 unvalued")

        print("ItemsListHeader heights at width \(contentWidth) — badge row: \(baselineRow), owned badge row: \(ownedRow), meta line: sold \(soldMetaLine) owned \(ownedMetaLine), baseline: \(baseline), no badges: \(withoutBadges), title line box: \(titleLineBox), owned under \"\(ownedWidest)\": \(owned), owned at scale: \(ownedLarge), sold: \(sold), sold at scale under \"\(soldWidest)\": \(soldLarge)")

        #expect(
            baseline == Int(baselineRow.height) + metaGap + soldMetaLine,
            "the Sold header measured \(baseline) pt against its badge row's \(baselineRow.height) + \(metaGap) + one \(soldMetaLine) pt meta line — the badge row is no longer what sets the header's height (plan Q6 as rewritten, spec Decision 16)"
        )
        #expect(
            owned == Int(ownedRow.height) + metaGap + ownedMetaLine,
            "the Owned header measured \(owned) pt against its badge row's \(ownedRow.height) + \(metaGap) + one \(ownedMetaLine) pt meta line — the badge row is no longer what sets the header's height (plan Q6 as rewritten, spec Decision 16)"
        )
        #expect(
            withoutBadges == titleLineBox + metaGap + soldMetaLine,
            "the header measured \(withoutBadges) pt with no badges against the title's \(titleLineBox) pt line box + \(metaGap) + one \(soldMetaLine) pt meta line — with its trailing slot empty the title row is no longer the title's own height (spec Decision 23)"
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
    /// the bespoke "…" badge used) is exactly that third short.
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

    /// The side toggle is one width on both its sides (`018` spec Decision
    /// 21, G1): each screen's toggle lays out both sides' glyph and word
    /// hidden under the showing one, so its glass capsule is the wider side's
    /// width whichever side shows and never resizes on a tap — the resize
    /// runs outside SwiftUI's transactions and clipped "Completed" for
    /// ~0.17 s (filmed, T009d). Each screen's two sides rendered alone at 3×,
    /// exact equality, no tolerance (the standing G1 ruling).
    ///
    /// Its mutations (T009d): the hidden leading row removed → red; the
    /// hidden trailing row removed → red.
    @Test func theSideToggleIsOneWidthOnBothSidesOfEachScreen() throws {
        let screens = [
            ("Items", "Owned", renderAt3x(SideToggle(side: ItemListViewModel.Side.owned, select: { _ in })),
             "Sold", renderAt3x(SideToggle(side: ItemListViewModel.Side.sold, select: { _ in }))),
            ("Plans", "Active", renderAt3x(SideToggle(side: PlansViewModel.Side.active, select: { _ in })),
             "Completed", renderAt3x(SideToggle(side: PlansViewModel.Side.completed, select: { _ in }))),
        ]
        for (screen, leadingName, leadingImage, trailingName, trailingImage) in screens {
            let leading = try #require(leadingImage, "ImageRenderer produced nothing to measure for the \(leadingName) toggle.")
            let trailing = try #require(trailingImage, "ImageRenderer produced nothing to measure for the \(trailingName) toggle.")
            print("Side toggle widths at 3× on \(screen) — \(leadingName): \(leading.width) px, \(trailingName): \(trailing.width) px")
            #expect(
                leading.width == trailing.width,
                "the \(screen) toggle renders \(leading.width) px wide at 3× on \(leadingName) and \(trailing.width) px on \(trailingName) — the capsule resizes on a tap and clips the wider word (spec Decision 21)"
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

        let anchor = "ItemsListHeader(title: \"Items\", gapBelow: headerGapBelow)"
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


    // MARK: - The title row and the meta line (spec Decisions 22 and 23)

    /// The title row is the controls' height, and the title's line box is
    /// centred on them (`018` spec Decision 23, T009f; T009e's Decision 22
    /// had its baseline on their bottom edge): `TitleRowLayout` rendered at
    /// 3× with the title's line box painted behind it. Exact, no tolerance.
    ///
    /// Two stand-ins. The Sold side's measured badge row is the shipped
    /// case, and the row must be its height: 111 px, the controls on rows
    /// 0…110. But the title's line box at 34 pt is 37 pt too, so over that
    /// row top, centre and bottom placement draw the same pixels (the box on
    /// rows 0…110 whichever it is). A stand-in 8 pt taller separates them:
    /// the row 135 px, the box on rows 12…122 — 12 px above and 12 below.
    ///
    /// Before T009f the title's baseline ended on the controls' last row
    /// (111 px), its 30 pt line box hanging 7 pt below the row.
    ///
    /// Its mutations (T009f): the title placed with its line box on the
    /// row's bottom edge → red (24 px above, 0 below); at the row's top → red
    /// (0 above, 24 below); the row reporting the title's height rather than
    /// the controls' → red (the taller row renders 111 px, not 135).
    @Test func theTitleRowIsTheControlsHeightWithTheTitleCentredOnThem() throws {
        let row = try badgeRowSize(side: .sold, options: ItemListViewModel.SoldSortOrder.allCases, selection: .soldDate, label: \.label)
        let image = try #require(
            renderAt3x(
                TitleRowLayout {
                    boxedTitle("Items")
                    Probe.controls.colour.frame(width: row.width, height: row.height)
                }
                .frame(width: contentWidth)
            ),
            "ImageRenderer produced nothing to measure for the title row."
        )
        let controls = try pixelRows(.controls, in: image)
        let box = try pixelRows(.titleBox, in: image)
        print("Title row at 3× — \(image.width) × \(image.height) px, controls rows \(controls), title line box rows \(box)")
        #expect(
            image.height == Int(row.height) * 3 && controls == 0...(image.height - 1),
            "the title row renders \(image.height) px tall at 3× with the controls on rows \(controls), against the controls' \(Int(row.height) * 3) px — the row is no longer the controls' height, so every first row under it moves (spec Decision 22)"
        )

        let tallerHeight = row.height + 8
        let taller = try #require(
            renderAt3x(
                TitleRowLayout {
                    boxedTitle("Items")
                    Probe.controls.colour.frame(width: row.width, height: tallerHeight)
                }
                .frame(width: contentWidth)
            ),
            "ImageRenderer produced nothing to measure for the title row over the taller stand-in."
        )
        let tallerControls = try pixelRows(.controls, in: taller)
        let tallerBox = try pixelRows(.titleBox, in: taller)
        let above = tallerBox.lowerBound - tallerControls.lowerBound
        let below = tallerControls.upperBound - tallerBox.upperBound
        print("Title row over a \(tallerHeight) pt stand-in at 3× — \(taller.width) × \(taller.height) px, controls rows \(tallerControls), title line box rows \(tallerBox), \(above) px above and \(below) px below")
        #expect(
            taller.height == Int(tallerHeight) * 3 && tallerControls == 0...(taller.height - 1),
            "over a \(tallerHeight) pt stand-in the title row renders \(taller.height) px tall at 3× with the controls on rows \(tallerControls), against \(Int(tallerHeight) * 3) px — the row is no longer the controls' height (spec Decision 23)"
        )
        #expect(
            above == below,
            "the title's line box sits \(above) px under the controls' top and \(below) px over their bottom at 3× — it is no longer centred on them (spec Decision 23)"
        )
    }

    /// The meta line sits midway between the title row and what follows, and
    /// what follows stays where it was (`018` spec Decision 22, T009e). Each
    /// screen's header block is rendered at 3× as the screen stacks it — the
    /// header, the screen's padding of `MetaLineSpacing.split(before:)`
    /// under it, and a stand-in for the search field or the first row — over
    /// the side's measured badge row; the stacking is this suite's copy of
    /// the screens', since the screens themselves can't be rendered here.
    /// "Where it was" is the old stack written out: the row, 6 pt, the meta
    /// line, then the gap that follows.
    ///
    /// Before T009e: the Items search field at 242 px (80.67 pt; the meta line
    /// is 41 px), the meta line 18 px under the row and 72 px above the
    /// field; the Wishlist field at 230 px (76.67 pt, its stacked header
    /// 53 pt); the empty state under an Items side with nothing to narrow at
    /// 200 px; Plans' first card at 156 px (52 pt). After: Items 242, the
    /// Wishlist 242 (level with Items, 4 pt lower than before — put to the
    /// person), the empty state 200, Plans 156; the meta line 45 px from each
    /// neighbour over a search field and 24 px over nothing to narrow.
    ///
    /// Its mutations (T009e): the layout reporting the title's full line box
    /// → red (every position); `split(before:)` + 1 → red (the search field
    /// and the empty state move); the header's meta spacing at split − 1 and
    /// the stacks' padding at split + 1 (14/16 over a search field) → red on
    /// the equal gaps alone, every position green.
    @Test func theMetaLineSitsMidwayAndWhatFollowsDoesNotMove() throws {
        let metrics = ThemeMetrics.standard
        let itemsRow = try badgeRowSize(side: .sold, options: ItemListViewModel.SoldSortOrder.allCases, selection: .soldDate, label: \.label)
        let wishlistRow = try wishlistBadgeRowSize()
        let plansRow = try plansBadgeRowSize()
        let soldLine = soldSummary(count: 4, proceeds: 320_000, realised: 60_000)
        let metaPixels = try #require(renderAt3x(Text(soldLine).monoLabel()), "ImageRenderer produced nothing to measure for the meta line.").height

        let cases: [(String, String, String, CGSize, CGFloat)] = [
            ("Items over a search field", "Items", soldLine, itemsRow, metrics.sectionGap),
            ("Items with nothing to narrow", "Items", soldLine, itemsRow, metrics.listRowGap),
            ("the Wishlist over a search field", "Wishlist", "4 wanted · $4,740", wishlistRow, metrics.sectionGap),
        ]
        for (name, title, meta, row, gap) in cases {
            let block = VStack(alignment: .leading, spacing: 0) {
                ItemsListHeader(title: title, gapBelow: gap) {
                    Text(meta).monoLabel().background(Probe.meta.colour)
                } trailing: {
                    Probe.controls.colour.frame(width: row.width, height: row.height)
                }
                .padding(.bottom, MetaLineSpacing.split(before: gap))

                Probe.following.colour.frame(height: metrics.searchFieldHeight)
            }
            .frame(width: contentWidth)
            let image = try #require(renderAt3x(block), "ImageRenderer produced nothing to measure for \(name).")
            let controls = try pixelRows(.controls, in: image)
            let metaRows = try pixelRows(.meta, in: image)
            let following = try pixelRows(.following, in: image)
            let above = metaRows.lowerBound - (controls.upperBound + 1)
            let below = following.lowerBound - (metaRows.upperBound + 1)
            let unmoved = Int((row.height + MetaLineSpacing.titleRowToMeta + gap) * 3) + metaPixels
            print("\(name) at 3× — controls \(controls), meta \(metaRows), what follows from \(following.lowerBound) px; gaps \(above)/\(below) px, before T009e \(unmoved) px")
            #expect(
                above == below,
                "\(name): the meta line sits \(above) px under the title row and \(below) px over what follows at 3× — it is no longer midway (spec Decision 22)"
            )
            #expect(
                following.lowerBound == unmoved,
                "\(name): what follows the header starts at \(following.lowerBound) px at 3× against \(unmoved) px before — it moved (spec Decision 22)"
            )
        }

        // Plans has no meta line: its title row, then the list's row gap under
        // the header block and half a row gap of the first row's inset.
        let plans = VStack(alignment: .leading, spacing: 0) {
            TitleRowLayout {
                ListTitle(SellPlanCopy.tab)
                Probe.controls.colour.frame(width: plansRow.width, height: plansRow.height)
            }
            .padding(.bottom, metrics.listRowGap + metrics.listRowGap / 2)

            Probe.following.colour.frame(height: metrics.sellPlanRowMinHeight)
        }
        .frame(width: contentWidth)
        let plansImage = try #require(renderAt3x(plans), "ImageRenderer produced nothing to measure for Plans.")
        let firstCard = try pixelRows(.following, in: plansImage).lowerBound
        let unmoved = Int((plansRow.height + metrics.listRowGap + metrics.listRowGap / 2) * 3)
        print("Plans at 3× — first card from \(firstCard) px, before T009e \(unmoved) px")
        #expect(
            firstCard == unmoved,
            "Plans' first card starts at \(firstCard) px at 3× against \(unmoved) px before — it moved (spec Decision 22)"
        )
    }

    // MARK: - The title's size and fit (spec Decision 23)

    /// "Plans" fits at its full 34 pt beside every control row Plans can show
    /// on a 402 pt phone, and so do Items and the Wishlist beside their
    /// widest (`018` spec Decision 23, settled by measurement). The reason
    /// Plans' capsule reads "Wishlist" for the wishlist order: under
    /// "Wishlist order" the row is 293 pt and leaves the title 53 of the
    /// 88.67 pt it needs. Each title is drawn through a recording
    /// `TextRenderer`, which reads the laid-out line as the title was drawn,
    /// and compared against the same title drawn alone at its ideal size:
    /// untruncated, every glyph, and a line exactly as tall — so not shrunk.
    ///
    /// Measured at T009f (the space the row leaves the title, which needs
    /// 88.67 pt for "Plans", 87.33 for "Items", 125.67 for "Wishlist"):
    /// Plans 93 pt under "Wishlist" (row 253), 106 under "Newest"/"Oldest"
    /// (240), 119 under "Name" (227), 196 on an empty side (150); Items 113
    /// under "Date sold" (233); the Wishlist 180 under "Alphabetical" (166).
    ///
    /// Its mutations (T009f): the wishlist order's capsule label back to
    /// "Wishlist order" → red (the title shrinks to the floor and truncates
    /// to "Pl…"); `SortMenu` ignoring its `badgeLabel` → red, the same way.
    @Test func everyListTitleIsFullSizeOnA402PointPhone() throws {
        var cases = try plansControlRows().map { ("Plans", $0.name, $0.size) }
        cases.append(("Items", "its widest row", try itemsWidestRow()))
        cases.append(("Wishlist", "its widest row", try wishlistWidestRow()))
        for (title, rowName, row) in cases {
            let alone = try drawnTitle(ListTitle(title).fixedSize())
            let inRow = try drawnTitle(
                TitleRowLayout {
                    ListTitle(title)
                    Probe.controls.colour.frame(width: row.width, height: row.height)
                }
                .frame(width: contentWidth)
            )
            print("\(title) at 402 pt beside \(rowName) (\(row.width) pt): \(inRow.line), alone \(alone.line)")
            #expect(
                !inRow.line.truncated && inRow.line.glyphs == title.count,
                "\(title) beside \(rowName) (\(row.width) pt) on a 402 pt phone is drawn truncated — \(inRow.line) (spec Decision 23)"
            )
            #expect(
                inRow.line.height == alone.line.height,
                "\(title) beside \(rowName) (\(row.width) pt) on a 402 pt phone is drawn \(inRow.line.height) pt tall against its full \(alone.line.height) pt — it shrank where there is room for it at full size (spec Decision 23)"
            )
        }
    }

    /// On a 375 pt phone the title shrinks to fit rather than ending in "…"
    /// (`018` spec Decision 23): each screen's title beside its widest
    /// control row, drawn through a recording `TextRenderer` as the screen
    /// composes it — Items and the Wishlist through `ItemsListHeader`, Plans
    /// through its own title row. Untruncated, every glyph drawn, and its ink
    /// ending before the controls' first pixel column; Plans, the tightest,
    /// must actually have shrunk, or the case would pass without the scale
    /// ever engaging.
    ///
    /// Measured at T009f (the title's line, typographic ascent + descent,
    /// against 36.99 pt at full size): Plans under "Wishlist" (row 253 pt,
    /// 66 pt left) drawn 27.28 pt tall, 65.27 wide — about 25 pt type, scale
    /// 0.74 against `ListTitle.minimumScale`'s 0.7; Items under "Date sold"
    /// (233 pt, 86 left) about 33.4 pt; the Wishlist (166 pt, 153 left) at
    /// full size.
    ///
    /// Its mutations (T009f): `ListTitle`'s `.minimumScaleFactor` removed →
    /// red (Plans and Items truncated).
    @Test func theTitleShrinksToFitRatherThanTruncatingOnA375PointPhone() throws {
        let plansRow = try #require(try plansControlRows().max { $0.size.width < $1.size.width })
        let cases: [(String, CGSize, (CGSize) -> AnyView)] = [
            ("Plans", plansRow.size, { row in
                AnyView(TitleRowLayout {
                    ListTitle(SellPlanCopy.tab)
                    Probe.controls.colour.frame(width: row.width, height: row.height)
                })
            }),
            ("Items", try itemsWidestRow(), { row in
                AnyView(ItemsListHeader(title: "Items", gapBelow: ThemeMetrics.standard.sectionGap) {
                    EmptyView()
                } trailing: {
                    Probe.controls.colour.frame(width: row.width, height: row.height)
                })
            }),
            ("Wishlist", try wishlistWidestRow(), { row in
                AnyView(ItemsListHeader(title: "Wishlist", gapBelow: ThemeMetrics.standard.sectionGap) {
                    EmptyView()
                } trailing: {
                    Probe.controls.colour.frame(width: row.width, height: row.height)
                })
            }),
        ]
        for (title, row, compose) in cases {
            let alone = try drawnTitle(ListTitle(title).fixedSize())
            let drawn = try drawnTitle(compose(row).frame(width: narrowContentWidth))
            let ink = try #require(inkColumns(in: drawn.image), "\(title) drew no ink at 375 pt")
            let controlsStart = try #require(firstColumn(of: .controls, in: drawn.image), "no controls stand-in in \(title)'s render")
            print("\(title) at 375 pt beside its widest row (\(row.width) pt): \(drawn.line), alone \(alone.line) — drawn at about \(34 * drawn.line.height / alone.line.height) pt; ink columns \(ink) px, controls from \(controlsStart) px")
            #expect(
                !drawn.line.truncated && drawn.line.glyphs == title.count,
                "\(title) beside its widest row (\(row.width) pt) on a 375 pt phone is drawn truncated — \(drawn.line) — where it should shrink to fit (spec Decision 23)"
            )
            #expect(
                ink.upperBound < controlsStart,
                "\(title)'s ink ends on pixel column \(ink.upperBound) at 3× and the controls start on \(controlsStart) — the title runs into them on a 375 pt phone (spec Decision 23)"
            )
            if title == "Plans" {
                #expect(
                    drawn.line.height < alone.line.height,
                    "Plans beside its widest row (\(row.width) pt) at 375 pt is drawn at its full \(alone.line.height) pt — it didn't shrink, so this case can't see the scale engage"
                )
            }
        }
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
        let header = ItemsListHeader(title: "Items", gapBelow: ThemeMetrics.standard.sectionGap) {
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

    /// The Wishlist's control row as `WishlistView` composes it — Sort By and
    /// the "…", 8 pt apart — rendered on its own, as `badgeRowSize` does.
    private func wishlistBadgeRowSize() throws -> CGSize {
        let options = WishlistViewModel.SortOrder.allCases
        let row = HStack(spacing: 8) {
            SortMenu(options: options, selection: options[0], label: \.label, manualOrder: .custom) { _ in }
            OverflowMenu { Button("Settings") {} }
        }
        let image = try #require(renderBitmap(row), "ImageRenderer produced nothing to measure for the Wishlist's badge row.")
        return CGSize(width: image.width, height: image.height)
    }

    /// Plans' control row on its Active side — the toggle, Sort By and the
    /// "…", 8 pt apart, in `badgeRowSize`'s renderable order — on its own.
    private func plansBadgeRowSize() throws -> CGSize {
        let options = PlansViewModel.ActiveSortOrder.allCases
        let row = HStack(spacing: 8) {
            SideToggle(side: PlansViewModel.Side.active, select: { _ in })
            SortMenu(options: options, selection: options[0], label: \.label) { _ in }
            OverflowMenu { Button("Settings") {} }
        }
        let image = try #require(renderBitmap(row), "ImageRenderer produced nothing to measure for Plans' badge row.")
        return CGSize(width: image.width, height: image.height)
    }

    /// The list title with its line box painted behind it, so the box's
    /// first and last pixel rows are the line box's top and bottom.
    private func boxedTitle(_ title: String) -> some View {
        ListTitle(title)
            .background(Probe.titleBox.colour)
    }

    /// Every control row Plans can show, as `plansBadgeRowSize` renders it:
    /// the side toggle, Sort By over each order of each side with the
    /// capsule's short label (spec Decision 23), and the "…" — and a side
    /// with nothing to sort, which has no Sort By.
    private func plansControlRows() throws -> [(name: String, size: CGSize)] {
        func size(_ row: some View, _ name: String) throws -> (name: String, size: CGSize) {
            let image = try #require(renderBitmap(row), "ImageRenderer produced nothing to measure for Plans' row \(name).")
            return (name, CGSize(width: image.width, height: image.height))
        }
        var rows = [try size(HStack(spacing: 8) {
            SideToggle(side: PlansViewModel.Side.active, select: { _ in })
            OverflowMenu { Button("Settings") {} }
        }, "an empty side")]
        for order in PlansViewModel.ActiveSortOrder.allCases {
            rows.append(try size(HStack(spacing: 8) {
                SideToggle(side: PlansViewModel.Side.active, select: { _ in })
                SortMenu(options: PlansViewModel.ActiveSortOrder.allCases, selection: order, label: \.label, badgeLabel: \.badgeLabel) { _ in }
                OverflowMenu { Button("Settings") {} }
            }, "Active under \"\(order.badgeLabel)\""))
        }
        for order in PlansViewModel.CompletedSortOrder.allCases {
            rows.append(try size(HStack(spacing: 8) {
                SideToggle(side: PlansViewModel.Side.completed, select: { _ in })
                SortMenu(options: PlansViewModel.CompletedSortOrder.allCases, selection: order, label: \.label) { _ in }
                OverflowMenu { Button("Settings") {} }
            }, "Completed under \"\(order.label)\""))
        }
        return rows
    }

    /// Items' widest control row over both sides' every selection.
    private func itemsWidestRow() throws -> CGSize {
        var rows: [CGSize] = []
        for order in ItemListViewModel.SortOrder.allCases {
            rows.append(try badgeRowSize(side: .owned, options: ItemListViewModel.SortOrder.allCases, selection: order, label: \.label))
        }
        for order in ItemListViewModel.SoldSortOrder.allCases {
            rows.append(try badgeRowSize(side: .sold, options: ItemListViewModel.SoldSortOrder.allCases, selection: order, label: \.label))
        }
        return try #require(rows.max { $0.width < $1.width })
    }

    /// The Wishlist's widest control row over its every selection.
    private func wishlistWidestRow() throws -> CGSize {
        let options = WishlistViewModel.SortOrder.allCases
        var rows: [CGSize] = []
        for order in options {
            let row = HStack(spacing: 8) {
                SortMenu(options: options, selection: order, label: \.label, manualOrder: .custom) { _ in }
                OverflowMenu { Button("Settings") {} }
            }
            let image = try #require(renderBitmap(row), "ImageRenderer produced nothing to measure for the Wishlist's row under \"\(order.label)\".")
            rows.append(CGSize(width: image.width, height: image.height))
        }
        return try #require(rows.max { $0.width < $1.width })
    }

    /// A view rendered at 3× through `TitleLineRecorder`, with the one text
    /// line it drew — the title, in every case that calls this, since each
    /// renders no other text.
    private func drawnTitle(_ view: some View) throws -> (line: TitleLine, image: CGImage) {
        let recorder = TitleLineRecorder()
        let image = try #require(renderAt3x(view.textRenderer(recorder)), "ImageRenderer produced nothing to measure for the title.")
        let line = try #require(recorder.lines.last, "the title drew no text line")
        return (line, image)
    }

    /// The first and last pixel columns holding the title's ink — the dark
    /// theme's light text, which no probe colour comes near.
    private func inkColumns(in image: CGImage) -> ClosedRange<Int>? {
        guard let bitmap = Bitmap(image) else { return nil }
        var first: Int?
        var last: Int?
        for x in 0..<bitmap.width {
            for y in 0..<bitmap.height {
                if let pixel = bitmap.pixel(at: CGPoint(x: x, y: y)), pixel.red >= 128, pixel.green >= 128, pixel.blue >= 128 {
                    if first == nil { first = x }
                    last = x
                    break
                }
            }
        }
        guard let first, let last else { return nil }
        return first...last
    }

    /// The first pixel column holding any pixel of `probe`'s colour.
    private func firstColumn(of probe: Probe, in image: CGImage) -> Int? {
        guard let bitmap = Bitmap(image) else { return nil }
        for x in 0..<bitmap.width {
            for y in 0..<bitmap.height {
                if let pixel = bitmap.pixel(at: CGPoint(x: x, y: y)), probe.matches(pixel) { return x }
            }
        }
        return nil
    }

    /// The pure colours the geometry cases paint their stand-ins in, none of
    /// which the theme's text or background comes near.
    private enum Probe {
        case controls, meta, following, titleBox

        var colour: Color {
            switch self {
            case .controls: Color(red: 1, green: 0, blue: 0)
            case .meta: Color(red: 0, green: 1, blue: 0)
            case .following: Color(red: 1, green: 0, blue: 1)
            case .titleBox: Color(red: 0, green: 0, blue: 1)
            }
        }

        func matches(_ pixel: RGB8) -> Bool {
            switch self {
            case .controls: pixel.red >= 128 && pixel.green < 60 && pixel.blue < 60
            case .meta: pixel.green >= 128 && pixel.red < 60 && pixel.blue < 60
            case .following: pixel.red >= 128 && pixel.blue >= 128 && pixel.green < 60
            case .titleBox: pixel.blue >= 128 && pixel.red < 60 && pixel.green < 60
            }
        }
    }

    /// The first and last pixel rows holding any pixel of `probe`'s colour.
    private func pixelRows(_ probe: Probe, in image: CGImage) throws -> ClosedRange<Int> {
        let bitmap = try #require(Bitmap(image), "couldn't read the rendered image's pixels")
        var first: Int?
        var last: Int?
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                if let pixel = bitmap.pixel(at: CGPoint(x: x, y: y)), probe.matches(pixel) {
                    if first == nil { first = y }
                    last = y
                    break
                }
            }
        }
        let top = try #require(first, "no \(probe) pixels in the render")
        return top...(try #require(last))
    }
}

/// One laid-out text line as `TitleLineRecorder` saw it drawn: whether the
/// system truncated it, how many glyphs it drew (an ellipsis is one), and its
/// typographic height (ascent + descent) and width, in points.
private nonisolated struct TitleLine: CustomStringConvertible {
    let truncated: Bool
    let glyphs: Int
    let height: CGFloat
    let width: CGFloat

    var description: String {
        "\(truncated ? "truncated" : "untruncated"), \(glyphs) glyphs, \(height) × \(width) pt"
    }
}

/// A `TextRenderer` that draws its text unchanged and records each line it
/// is handed (`018` T009f). `Text.Layout` is the one place the system says
/// whether it truncated a line and which glyphs it laid out — a bitmap alone
/// can't tell "Plans" shrunk from "Pl…" at the same width. A class, so the
/// test can read what a renderer value recorded while drawing.
private nonisolated final class TitleLineRecorder: TextRenderer, @unchecked Sendable {
    private(set) var lines: [TitleLine] = []

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout {
            let bounds = line.typographicBounds
            lines.append(TitleLine(
                truncated: layout.isTruncated,
                glyphs: line.reduce(0) { $0 + $1.count },
                height: bounds.ascent + bounds.descent,
                width: bounds.width
            ))
            ctx.draw(line)
        }
    }
}

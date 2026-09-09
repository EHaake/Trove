import SwiftUI

/// Spacing, sizing and corner radii from `design/tokens.md`. Everything sits
/// on the 4pt base grid except where Design specified otherwise.
struct ThemeMetrics: Sendable, Equatable {
    let screenGutter: CGFloat
    let cardPadding: CGFloat
    /// List-row internals run tighter than a card's (`010`'s row treatment):
    /// the padding inside the plate, and the thumbnail-to-text gap. Two
    /// tokens because tokens.md lists them separately, the same reasoning
    /// that keeps `textLabel`/`textLabelSecondary` apart.
    let rowPadding: CGFloat
    let rowContentGap: CGFloat
    let sectionGap: CGFloat
    let listRowGap: CGFloat
    let fieldGap: CGFloat

    /// Letter-spacing for all-caps mono labels. tokens.md gives 0.06–0.16em;
    /// this is expressed in points at the label's own size.
    let monoLabelTracking: CGFloat

    let cardRadius: CGFloat
    let buttonRadius: CGFloat
    let thumbnailRadius: CGFloat
    /// Fully rounded, per tokens.md — `Capsule()` in practice.
    let chipRadius: CGFloat

    let fieldPaddingVertical: CGFloat
    let fieldPaddingHorizontal: CGFloat
    let hairline: CGFloat

    /// The list screens' search box. Measured off `Trove Item List.png` (79px
    /// at 2×) rather than derived from padding — Design drew it shorter than a
    /// form field, which is what keeps the fixed header from eating the list.
    let searchFieldHeight: CGFloat

    /// The dashboard's ruler, all measured off `Trove Dashboard.png` at 2×:
    /// 4px-wide ticks on a 10px pitch, 28/14/12px tall for major, minor and
    /// spent.
    let rulerTickWidth: CGFloat
    let rulerTickSpacing: CGFloat
    let rulerMajorTickHeight: CGFloat
    let rulerMinorTickHeight: CGFloat
    let rulerSpentTickHeight: CGFloat
    /// The stacked proportion bar above the category rows, and the gap Design
    /// leaves between its segments.
    let stackedBarHeight: CGFloat
    let stackedBarSegmentGap: CGFloat
    /// The colour tick at the head of each breakdown row.
    let categorySwatchWidth: CGFloat
    /// The accent stripe down the side of a callout card.
    let calloutEdgeWidth: CGFloat
    /// Letter-spacing on the dashboard's TROVE wordmark, which is set much
    /// wider than the all-caps mono labels.
    let wordmarkTracking: CGFloat
    /// Between the search box and the category chip row beneath it. Tighter
    /// than a section gap: the two are one filter control, not two sections.
    let controlRowGap: CGFloat
    /// Between a header badge's bottom edge and the dropdown it opens (013
    /// Amendment A). What the lists' old fixed offset resolved to: 60 =
    /// `sectionGap` 24 + the badge's 30 + this 6.
    let dropdownGap: CGFloat

    /// tokens.md calls these out individually because the Sell Plan row is the
    /// one layout with a future trend indicator to leave room for.
    let sellPlanRowPaddingVertical: CGFloat
    let sellPlanRowPaddingHorizontal: CGFloat
    let sellPlanRowInternalGap: CGFloat
    let sellPlanRowMinHeight: CGFloat
    let sellPlanPriceColumnMinWidth: CGFloat
    /// Reserved for the per-item resale-trend indicator that arrives with live
    /// market data. Deliberately occupied now so adding it later doesn't mean
    /// relaying out the row — see spec.md's non-goals.
    let sellPlanTrendSlot: CGSize
}

extension ThemeMetrics {
    /// How far list rows sit in from the screen edge — less than the gutter,
    /// by exactly the card's own padding.
    ///
    /// Cards reach closer to the edge than the header block does, while the
    /// text *inside* a card still lines up with the title above it. Derived
    /// rather than written out so it survives either token changing, and so
    /// it can't be mistaken for a spacing value of its own. Off `rowPadding`
    /// since `010`'s row treatment — it's list rows this insets.
    var listRowInset: CGFloat { screenGutter - rowPadding }
}

extension ThemeMetrics {
    static let standard = ThemeMetrics(
        screenGutter: 24,
        cardPadding: 16,
        rowPadding: 13,
        rowContentGap: 13,
        sectionGap: 24,
        listRowGap: 10,
        fieldGap: 8,
        monoLabelTracking: 1.2,
        cardRadius: 3,
        buttonRadius: 3,
        thumbnailRadius: 2,
        chipRadius: 999,
        fieldPaddingVertical: 14,
        fieldPaddingHorizontal: 14,
        hairline: 1,
        searchFieldHeight: 40,
        rulerTickWidth: 2,
        rulerTickSpacing: 3,
        rulerMajorTickHeight: 14,
        rulerMinorTickHeight: 7,
        rulerSpentTickHeight: 6,
        stackedBarHeight: 6,
        stackedBarSegmentGap: 2,
        categorySwatchWidth: 3,
        calloutEdgeWidth: 2,
        wordmarkTracking: 5,
        controlRowGap: 16,
        dropdownGap: 6,
        sellPlanRowPaddingVertical: 15,
        sellPlanRowPaddingHorizontal: 14,
        sellPlanRowInternalGap: 12,
        sellPlanRowMinHeight: 66,
        sellPlanPriceColumnMinWidth: 92,
        sellPlanTrendSlot: CGSize(width: 12, height: 14)
    )
}

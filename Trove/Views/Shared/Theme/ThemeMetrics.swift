import SwiftUI

/// Spacing, sizing and corner radii from `design/tokens.md`. Everything sits
/// on the 4pt base grid except where Design specified otherwise.
struct ThemeMetrics: Sendable {
    let screenGutter: CGFloat
    let cardPadding: CGFloat
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
    /// Between the search box and the category chip row beneath it. Tighter
    /// than a section gap: the two are one filter control, not two sections.
    let controlRowGap: CGFloat

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
    static let standard = ThemeMetrics(
        screenGutter: 24,
        cardPadding: 16,
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
        controlRowGap: 16,
        sellPlanRowPaddingVertical: 15,
        sellPlanRowPaddingHorizontal: 14,
        sellPlanRowInternalGap: 12,
        sellPlanRowMinHeight: 66,
        sellPlanPriceColumnMinWidth: 92,
        sellPlanTrendSlot: CGSize(width: 12, height: 14)
    )
}

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
        sellPlanRowPaddingVertical: 15,
        sellPlanRowPaddingHorizontal: 14,
        sellPlanRowInternalGap: 12,
        sellPlanRowMinHeight: 66,
        sellPlanPriceColumnMinWidth: 92,
        sellPlanTrendSlot: CGSize(width: 12, height: 14)
    )
}

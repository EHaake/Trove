import SwiftUI

/// A labelled block on a detail screen — heading, then content (`010`).
///
/// Shared by `ItemDetailView` and `WishlistDetailView` so the two screens
/// can't drift apart on the shape they both draw, the same reasoning that
/// pulled `PhotoCarousel` out of the item screen.
///
/// The heading uses the app's established `monoLabel` rather than the
/// refreshed mock's sans-semibold: every all-caps label on every other screen
/// is mono, and one screen breaking that reads as a mistake rather than a
/// refinement. Recorded as a deliberate divergence in `tokens.md`.
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap + 2) {
            Text(title).monoLabel()
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One row of a detail screen's field table: label left, value right, a
/// hairline underneath — `tokens.md`'s detail tables.
///
/// Values right-align because the columns they form (dates, money, serials)
/// read down the edge; the label column stays left so the pair still scans as
/// a sentence.
struct DetailRow: View {
    let label: String
    let value: String
    /// Money, dates and serial numbers set in mono, per the type roles —
    /// prose values stay in the body face.
    var isMono: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.metrics.cardPadding) {
            Text(label)
                .font(theme.typography.secondary)
                .foregroundStyle(theme.colors.textLabelSecondary)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
            Text(value)
                .font(isMono ? theme.typography.monoMeta : theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            theme.colors.surfaceInset.frame(height: theme.metrics.hairline)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Body prose on a detail screen — the NOTES block on both.
struct DetailProse: View {
    let text: String

    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textBody)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

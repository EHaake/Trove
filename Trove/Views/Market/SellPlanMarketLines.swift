import SwiftUI

/// The Sell Plan's market line (003 spec, "What a row shows"): the Reverb
/// median under the person's own value, with the trend arrow beside it in
/// the same tones the list rows draw.
///
/// The median is **non-optional** on purpose. Criterion 6 — no market line
/// for a withheld or stale figure — then holds by construction rather than
/// by a branch inside this view: the row can only build one under `if let`
/// on `summary.medianCents`, which is nil for both of those cases (003 plan
/// §5, sign-off N4).
///
/// The accessibility label sits on the `Text`, never on the `HStack`. The
/// row is `.combine`d, so the label joins the arrow's own "trending up" and
/// the row reads "Median asking price $1,400, trending up"; a label on the
/// container would swallow the arrow's half of that sentence.
///
/// Every word comes from `MarketCopy`; this file may not contain a string
/// literal with a space in it, and `MarketVocabularyTests` holds it to that.
struct SellPlanMarketLine: View {
    let medianCents: Int
    let trend: MarketTrend?

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(MarketCopy.sellPlanMarketLine(medianCents: medianCents))
                .font(theme.typography.monoMeta)
                .foregroundStyle(theme.colors.textQuiet)
                .lineLimit(1)
                .accessibilityLabel(MarketCopy.figureAccessibilityLabel(medianCents: medianCents))

            TrendArrow(trend: trend)
        }
        .accessibilityIdentifier("sellPlan.market")
    }
}

/// Why a rising row is rising (003 spec, Decision 2): one sentence under the
/// category, naming the same comparison the arrow made and dating it by the
/// earlier reading. Falling and neutral rows carry none — the arrow is the
/// whole statement there.
///
/// It wraps rather than truncates (criterion 11): `lineLimit(nil)` with
/// `fixedSize(horizontal: false, vertical: true)`, so the sentence takes the
/// height it needs in its own column instead of eliding at the row's width.
struct SellPlanReasonLine: View {
    let rise: MarketRise
    let now: Date

    @Environment(\.theme) private var theme

    var body: some View {
        Text(MarketCopy.sellPlanReason(percent: rise.percent, since: rise.since, now: now))
            .font(theme.typography.secondary)
            .foregroundStyle(theme.colors.textQuiet)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("sellPlan.reason")
    }
}

#Preview {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let rise = MarketRise(comparison: MarketTrend.Comparison(
        latestCents: 140_000,
        previousCents: 125_000,
        previousAt: now.addingTimeInterval(-32 * 24 * 60 * 60),
        trend: .up
    ))

    return ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 10) {
            SellPlanMarketLine(medianCents: 140_000, trend: .up)
            SellPlanMarketLine(medianCents: 64_000, trend: .down)
            SellPlanMarketLine(medianCents: 38_000, trend: nil)
            if let rise {
                SellPlanReasonLine(rise: rise, now: now)
            }
        }
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
}

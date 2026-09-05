import SwiftUI

/// The market trend as a small glyph beside a row's own figure (spec
/// criterion 13, Decision 8): moss pointing up, rust pointing down, and
/// nothing at all otherwise.
///
/// Flat draws nothing on purpose — a third mark for "it hasn't moved"
/// would put a symbol on almost every row and say the least of the three.
/// `nil` (no trend yet: one point, or two closer together than a week)
/// draws nothing for the same reason, so the two indistinguishable states
/// look indistinguishable.
///
/// The tones are the `*Text` pair rather than the base accents: this sits
/// on a row plate at 9 pt, which is exactly the case `ThemeColors` says to
/// use them for. Its labels come from `MarketCopy` — nothing here is typed
/// (`MarketVocabularyTests` scans this file for it) — and both rows that
/// draw it are `.combine`d, so the label joins the row's own sentence
/// rather than becoming a stop of its own.
struct TrendArrow: View {
    let trend: MarketTrend?

    @Environment(\.theme) private var theme

    var body: some View {
        switch trend {
        case .up:
            arrow(named: "arrowtriangle.up.fill", tint: theme.colors.accentMossText, label: MarketCopy.trendUp)
        case .down:
            arrow(named: "arrowtriangle.down.fill", tint: theme.colors.accentRustText, label: MarketCopy.trendDown)
        case .flat, nil:
            EmptyView()
        }
    }

    private func arrow(named name: String, tint: Color, label: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 9))
            .foregroundStyle(tint)
            .accessibilityLabel(label)
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 10) {
            ForEach([MarketTrend.up, .down, .flat], id: \.self) { trend in
                HStack(spacing: 8) {
                    Text("$1,450")
                        .font(Theme.dark.typography.monoValue)
                        .foregroundStyle(Theme.dark.colors.textPrimary)
                    TrendArrow(trend: trend)
                }
            }
        }
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
}

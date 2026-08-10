import SwiftUI

/// The tick row under the dashboard's total, per
/// `design/screens/Trove Dashboard.png`: 28 ticks with every seventh drawn
/// tall, lit from the left up to `fraction`.
///
/// **What it measures is ours, not Design's.** The mock lights 22 of 28,
/// which matches none of its own figures (31/34 valued, 18,420/16,905 spent)
/// and lands exactly on a major gradation — so the position was drawn to look
/// right rather than derived from data. Rather than reproduce a number that
/// means nothing, it shows how much of the collection the total above it
/// actually accounts for: full when every item has a value, short by whatever
/// the callout underneath is about to name. That keeps it an instrument
/// rather than an ornament, which is the line design/brief.md draws.
struct ValueRuler: View {
    /// 0–1. Values outside are clamped rather than trusted.
    let fraction: Double

    @Environment(\.theme) private var theme

    private let tickCount = 28
    private let majorEvery = 7

    private var litCount: Int {
        Int((Double(tickCount) * min(max(fraction, 0), 1)).rounded())
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: theme.metrics.rulerTickSpacing) {
            ForEach(0..<tickCount, id: \.self) { index in
                let isMajor = index % majorEvery == 0
                let isLit = index < litCount

                Capsule()
                    .fill(color(isLit: isLit, isMajor: isMajor))
                    .frame(
                        width: theme.metrics.rulerTickWidth,
                        height: height(isLit: isLit, isMajor: isMajor)
                    )
            }
        }
        .frame(height: theme.metrics.rulerMajorTickHeight, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel("Valued")
        .accessibilityValue("\(Int((min(max(fraction, 0), 1)) * 100))% of items have a value")
    }

    private func color(isLit: Bool, isMajor: Bool) -> Color {
        guard isLit else { return theme.colors.divider }
        return isMajor ? theme.colors.accentBrass : theme.colors.accentBrassDim
    }

    private func height(isLit: Bool, isMajor: Bool) -> CGFloat {
        if !isLit { return theme.metrics.rulerSpentTickHeight }
        return isMajor ? theme.metrics.rulerMajorTickHeight : theme.metrics.rulerMinorTickHeight
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 28) {
            ValueRuler(fraction: 1)
            ValueRuler(fraction: 0.786)
            ValueRuler(fraction: 0.5)
            ValueRuler(fraction: 0)
        }
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
}

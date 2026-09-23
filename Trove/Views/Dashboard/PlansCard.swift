import SwiftUI

/// The Dashboard's Plans card (`009` plan §12): the SELL PLANS header, how many
/// plans are active, and the arrow that says the whole plate is a way through
/// to the Plans tab's Active side.
///
/// `SoldCard`'s chrome copied rather than generalized (plan Q16): the Sold
/// card's delta line, colour rule and attributed figures are `006`-guarded,
/// and this card needs a header, one line and the arrow. An extraction is a
/// roadmap line if a third card appears.
///
/// Only composed when there is something to count — the caller gates it on
/// `DashboardViewModel.showsPlansCard` inside the Dashboard's non-empty branch
/// (spec Decision 12), so this view never draws a zero. The line arrives
/// already made by the view model out of `SellPlanCopy`.
///
/// One element to VoiceOver: the header and the line arrive as one
/// announcement with one hint. `.extrudedPlate()` fills the whole card, so a
/// tap anywhere on it acts, not only on the text.
struct PlansCard: View {
    /// "2 active sell plans" — `DashboardViewModel.plansLine`.
    let line: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: theme.metrics.cardPadding) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(SellPlanCopy.cardHeader).monoLabel()

                    Text(line)
                        .font(theme.typography.monoValue)
                        .foregroundStyle(theme.colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, 6)
                }

                Spacer(minLength: 0)

                // The Sold card's arrow alone, for the same reason: the header
                // already says what the card is about.
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.colors.accentBrass)
            }
            .padding(theme.metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .extrudedPlate()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(SellPlanCopy.cardHint)
        .accessibilityIdentifier("dashboard.plansCard")
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 24) {
            PlansCard(line: SellPlanCopy.activeCount(1)) {}
            PlansCard(line: SellPlanCopy.activeCount(3)) {}
        }
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}

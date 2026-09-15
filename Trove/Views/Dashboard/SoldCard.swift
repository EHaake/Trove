import SwiftUI

/// The Dashboard's Sold card, per the Design pass's
/// `design/elements/006-mark-as-sold/DashboardRoot` and `DashboardCategory`
/// artboards (`006` plan §6): the SOLD header, how many and for how much, the
/// realised gain or loss beneath, and the arrow that says the whole plate is a
/// way through to the Items tab's Sold side.
///
/// A ledger apart from the collection's totals, which is why it is its own
/// plate below the un-valued callout rather than a fourth figure inside
/// `spentAndGain` — sold money and collection money are never added together
/// (spec, Non-goals). It is only composed when something in scope has been
/// sold; a card reading "0 items · $0" is the claim the Dashboard's other
/// gates exist to avoid, so the caller hides it rather than this view drawing
/// zeroes.
///
/// The words are not composed here: both lines arrive already made by
/// `DashboardViewModel` out of `SaleCopy`, which is the same table the Sold
/// side's summary reads, so the card and the summary cannot drift (AC7). The
/// *colour* is not `SaleCopy`'s business (plan Q11): the rule is
/// `SaleTotals.isLoss`, which this view maps to `accentRustText` /
/// `accentMossText` exactly as `SoldMark` and `SoldItemRow` do — so a ledger
/// that broke even is moss, the way a zero Gain already is.
///
/// One element to VoiceOver (criterion 16): the header, the figures and the
/// realised line arrive as one announcement with one hint, rather than three
/// stops in front of a button.
struct SoldCard: View {
    /// "3 items · $2,400" — `DashboardViewModel.soldLine`.
    let line: String
    /// "+$200 vs paid" — `DashboardViewModel.soldDeltaLine`.
    let deltaLine: String
    /// The sign behind that second line, for the colour alone. The figure
    /// itself is already inside `deltaLine`; this is never formatted here,
    /// where it could drift from the string the view model made.
    let realisedDeltaCents: Int
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: theme.metrics.cardPadding) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(SaleCopy.cardHeader).monoLabel()

                    Text(figures)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, 6)

                    Text(deltaLine)
                        .font(theme.typography.monoMeta)
                        .foregroundStyle(deltaColor)
                        .lineLimit(1)
                        .padding(.top, 4)
                }

                Spacer(minLength: 0)

                // The un-valued callout's arrow without its "VALUE" word:
                // the header already says what the card is about, and the
                // person settled on the arrow alone (spec Decision 11).
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
        .accessibilityHint("Shows what you've sold in Items")
        .accessibilityIdentifier("dashboard.soldCard")
    }

    /// The count and the proceeds in one mono line with the money lifted —
    /// the artboard's one emphasis inside the line, applied the way `SoldMark`
    /// lifts the price inside `SaleCopy.saleLine`: to the composed string's
    /// second component, rather than by formatting a second copy of the figure
    /// here where it could drift from the one the Sold side shows.
    ///
    /// The base weight is the regular mono face at the money size, which has
    /// no token of its own — `monoValue` is the medium cut, and that is what
    /// the proceeds are lifted *to*. A line whose second component can't be
    /// found renders uniform, which is legible rather than wrong.
    private var figures: AttributedString {
        var attributed = AttributedString(line)
        attributed.font = ThemeTypography.font(.mono, size: 15)
        attributed.foregroundColor = theme.colors.textBody

        let parts = line.components(separatedBy: SaleCopy.separator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count > 1, let proceeds = attributed.range(of: parts[1]) else { return attributed }
        attributed[proceeds].font = theme.typography.monoValue
        attributed[proceeds].foregroundColor = theme.colors.textPrimary
        return attributed
    }

    /// The moss/rust rule from the model, not from a sign test repeated in a
    /// view — and from the rule over a *sum* of sales, `SaleTotals.isLoss`,
    /// which the Sold side's summary line reads too. Until T017a this stood a
    /// `SaleOutcome` up over the delta to borrow the single sale's rule,
    /// which agreed with it by arithmetic accident rather than by design.
    private var deltaColor: Color {
        SaleTotals.isLoss(realisedDeltaCents: realisedDeltaCents)
            ? theme.colors.accentRustText
            : theme.colors.accentMossText
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 24) {
            SoldCard(
                line: SaleCopy.dashboardSummary(
                    SaleTotals(count: 3, proceedsCents: 240_000, realisedDeltaCents: 20_000)
                ),
                deltaLine: SaleCopy.realised(deltaCents: 20_000),
                realisedDeltaCents: 20_000
            ) {}

            SoldCard(
                line: SaleCopy.dashboardSummary(
                    SaleTotals(count: 1, proceedsCents: 120_000, realisedDeltaCents: -15_000)
                ),
                deltaLine: SaleCopy.realised(deltaCents: -15_000),
                realisedDeltaCents: -15_000
            ) {}
        }
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}

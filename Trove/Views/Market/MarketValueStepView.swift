import SwiftUI

/// The three intents the value step has, handed over as one value so the
/// two detail screens wire the step the same way and the compiler checks
/// that they did — `MarketSectionActions`' shape, for its reason.
///
/// `use` carries the amount rather than reading it back from the step: the
/// view holds the step, so the number the button names and the number it
/// writes are the same expression, and no caller can capture a stale copy.
struct MarketValueStepActions {
    /// The slider's write — the view model's `setChosen`, which rounds to
    /// whole currency and clamps to the bounds.
    let choose: (Int) -> Void
    /// The filled button: adopt this amount and close the sheet.
    let use: (Int) -> Void
    /// Not now: close without writing.
    let notNow: () -> Void
}

/// The match sheet's fourth phase — the value step (spec Decisions 34 and
/// 36, criterion 23, plan Amendment B; the visual is
/// `design/elements/002-market-values/ValueStep`).
///
/// The figure it came from, drawn in the section's own registers
/// (`MarketFigureRow`, `MarketSpreadLine`, `MarketQuietLine` — the same
/// pieces `MarketSection` draws, so the two can't drift), then the slider
/// between the trimmed bounds, the guidance line, and the two buttons.
/// The spread is the **true** low–high, deliberately not the slider's ends
/// (Decision 36).
///
/// It decides nothing: the step arrives whole from the view model,
/// `chosenCents` is the view model's to move through `choose`, and the
/// button hands that amount straight back. No rounding, no clamping and no
/// derivation happen here — `MarketValueStep` owns all three.
///
/// Every word comes from `MarketCopy`; this file may not contain a string
/// literal with a space in it, and `MarketVocabularyTests` holds it to that.
struct MarketValueStepView: View {
    let step: MarketValueStep
    /// A wanted item sets an *estimated cost*, an owned one its value
    /// (spec P6): the title and the button both read from it.
    let isWanted: Bool
    /// The matched product's title, for the source line — the section's own
    /// line, minus the age it has no room for here.
    let productTitle: String?
    /// The item's own year (spec Decision 29), the source line's third part.
    let year: Int?
    let actions: MarketValueStepActions

    @Environment(\.theme) private var theme

    /// The artboard's own rhythm: `22 24 32` padding as the notice sheet
    /// has, `20px` between blocks, `10px` inside the figure block, and the
    /// prose line-height the section's quiet lines carry.
    private static let topPadding: CGFloat = 22
    private static let bottomPadding: CGFloat = 32
    private static let blockGap: CGFloat = 20
    private static let figureGap: CGFloat = 10

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Self.blockGap) {
                title
                figureBlock
                slider
                MarketQuietLine(text: MarketCopy.valueGuidance)
                buttons
            }
            .padding(.top, Self.topPadding)
            .padding(.horizontal, theme.metrics.screenGutter)
            .padding(.bottom, Self.bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // The figure, the slider and the buttons each keep their own label,
        // as the section's parts do (criterion 20's reasoning).
        .accessibilityElement(children: .contain)
    }

    private var title: some View {
        Text(MarketCopy.valueStepTitle(wanted: isWanted))
            .font(theme.typography.emptyStateTitle)
            .foregroundStyle(theme.colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The reading the step stands on, in the section's registers: where it
    /// came from, the median and the count, and the true spread.
    private var figureBlock: some View {
        VStack(alignment: .leading, spacing: Self.figureGap) {
            MarketQuietLine(text: MarketCopy.sourceLine(title: productTitle, year: year))
            MarketFigureRow(medianCents: step.medianCents, count: step.count)
            MarketSpreadLine(lowCents: step.lowCents, highCents: step.highCents)
        }
    }

    private var slider: some View {
        MarketValueSlider(step: step, isWanted: isWanted, onChange: actions.choose)
            .accessibilityIdentifier("market.value.slider")
    }

    /// Filled to write the person's own number, outlined to step back
    /// (`tokens.md`'s button rule) — the notice sheet's pair, at its height.
    private var buttons: some View {
        VStack(spacing: theme.metrics.fieldGap) {
            Button {
                actions.use(step.chosenCents)
            } label: {
                Text(MarketCopy.useAmount(cents: step.chosenCents, wanted: isWanted))
                    .font(theme.typography.buttonProminent)
                    .marketFilledChrome(minHeight: MarketButtons.noticeHeight)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("market.value.use")

            Button(action: actions.notNow) {
                Text(MarketCopy.noticeNotNow)
                    .font(theme.typography.button)
                    .marketOutlinedChrome(fills: true, minHeight: MarketButtons.noticeHeight)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("market.value.notNow")
        }
    }
}

#Preview {
    @Previewable @State var chosen = 145_000

    let record = MarketFigureRecord(
        subjectID: UUID(),
        subjectKind: .owned,
        productID: 126_161,
        fetchedAt: .now
    )
    record.medianCents = 145_000
    record.lowCents = 110_000
    record.highCents = 200_000
    record.p10Cents = 115_000
    record.p90Cents = 190_000
    record.count = 12
    var step = MarketValueStep(figure: MarketSnapshotValue(record: record))
    step.setChosen(chosen)

    return MarketValueStepView(
        step: step,
        isWanted: false,
        productTitle: "Fender American Professional II Telecaster",
        year: nil,
        actions: MarketValueStepActions(choose: { chosen = $0 }, use: { _ in }, notNow: {})
    )
    .environment(\.theme, .dark)
}

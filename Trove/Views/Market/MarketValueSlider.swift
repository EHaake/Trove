import SwiftUI

/// The adopt sheet's value slider (spec `002` Decisions 34 and 36, plan
/// Amendment B; the visual is `design/elements/002-market-values/ValueStep`).
///
/// **Trove's own control, not a system `Slider`** — the spec's Design line:
/// it sits inside the page, in the app's instrument language, beside the
/// figure it came from. A thin `divider` track with the reached portion in
/// `accentBrass`, the two trimmed ends and the median marked, the ends'
/// amounts beneath, and a knob the drag carries between them.
///
/// **The geometry is a pure seam.** `cents(atX:trackWidth:lower:upper:median:)`
/// and its inverse `x(forCents:trackWidth:lower:upper:)` are `nonisolated`
/// statics, so the drag mapping, the median's snap and the whole-currency
/// rounding are driven directly by tests rather than through a gesture no
/// unit test can send: the `DragGesture` closure does nothing but call the
/// seam and hand the result to `onChange`. The same reasoning
/// `DesireGauge.value(atX:totalWidth:)` records — it is the piece with the
/// off-by-one in it, and a wrong answer's only symptom is a control that
/// writes the wrong number.
///
/// Nothing here decides what an amount *means*: `onChange` is the view
/// model's `setChosen`, which rounds to whole currency and clamps to the
/// bounds, so this file can never write an amount the step wouldn't allow.
/// Every word comes from `MarketCopy`; this file may carry no string
/// literal containing a space, and `MarketVocabularyTests` holds it to that.
struct MarketValueSlider: View {
    let step: MarketValueStep
    /// A wanted item slides an *estimated cost*, an owned one its value
    /// (spec P6) — the only thing the control says about itself.
    let isWanted: Bool
    /// The amount the drag or the adjustable action lands on, in cents,
    /// handed to the step's `setChosen` — which rounds and clamps it.
    let onChange: (Int) -> Void

    @Environment(\.theme) private var theme

    // MARK: - Geometry (`tokens.md`, "The value step and the slider")

    /// How far from the median's own x a drag still counts as the median.
    nonisolated static let snapTolerance: CGFloat = 6

    nonisolated static let trackRowHeight: CGFloat = 36
    nonisolated static let trackHeight: CGFloat = 2
    nonisolated static let trackRadius: CGFloat = 1
    nonisolated static let trackTop: CGFloat = 17
    nonisolated static let endMarkWidth: CGFloat = 1
    nonisolated static let endMarkHeight: CGFloat = 12
    nonisolated static let endMarkTop: CGFloat = 12
    nonisolated static let medianMarkWidth: CGFloat = 1.5
    nonisolated static let medianMarkHeight: CGFloat = 18
    nonisolated static let medianMarkTop: CGFloat = 9
    nonisolated static let knobDiameter: CGFloat = 20
    nonisolated static let knobRing: CGFloat = 3
    nonisolated static let knobRadius: CGFloat = knobDiameter / 2
    nonisolated static let knobOuterRadius: CGFloat = knobRadius + knobRing
    nonisolated static let knobTop: CGFloat = trackTop + trackHeight / 2 - knobOuterRadius
    nonisolated static let knobShadowRadius: CGFloat = 3
    nonisolated static let knobShadowOffset: CGFloat = 2
    nonisolated static let rowGap: CGFloat = 8
    /// The frame draws a `14px` label row; the mono register's own line box
    /// is taller than that, so the row is fixed here and the labels are
    /// fitted to it — a control whose height moved with the font would move
    /// every measurement the render tests take.
    nonisolated static let labelRowHeight: CGFloat = 16
    /// The frame's `0.08em` at the caption's size.
    nonisolated static let medianMarkTracking: CGFloat = 0.8

    nonisolated static let height: CGFloat = trackRowHeight + rowGap + labelRowHeight

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            VStack(alignment: .leading, spacing: Self.rowGap) {
                trackRow(width: width)
                labelRow(width: width)
            }
        }
        .frame(height: Self.height)
    }

    // MARK: - The track

    /// The track, the reached portion, the marks and the knob, stacked from
    /// the row's top-left corner so every offset is the frame's own number.
    private func trackRow(width: CGFloat) -> some View {
        let knobX = Self.x(
            forCents: step.chosenCents,
            trackWidth: width,
            lower: step.lowerCents,
            upper: step.upperCents
        )
        return ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: width, height: Self.trackRowHeight)
            RoundedRectangle(cornerRadius: Self.trackRadius)
                .fill(theme.colors.divider)
                .frame(width: width, height: Self.trackHeight)
                .offset(y: Self.trackTop)
            RoundedRectangle(cornerRadius: Self.trackRadius)
                .fill(theme.colors.accentBrass)
                .frame(width: knobX, height: Self.trackHeight)
                .offset(y: Self.trackTop)
            ForEach(
                Self.marks(
                    trackWidth: width,
                    lower: step.lowerCents,
                    upper: step.upperCents,
                    median: step.medianCents
                ),
                id: \.self
            ) { mark in
                markShape(mark)
            }
            knob.offset(x: knobX - Self.knobOuterRadius, y: Self.knobTop)
        }
        // The whole row takes the touch, not the 20pt knob — the reasoning
        // `DesireGauge`'s gesture records.
        .contentShape(Rectangle())
        .gesture(drag(width: width))
        // The marks are decoration: what they say is spoken once, by the
        // label row beneath, which combines the three into one element.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MarketCopy.yourValue(wanted: isWanted))
        .accessibilityValue(MarketCopy.median(cents: step.chosenCents))
        .accessibilityHint(MarketCopy.sliderHint)
        .accessibilityAdjustableAction { direction in
            let stride = Self.adjustableStep(lower: step.lowerCents, upper: step.upperCents)
            switch direction {
            case .increment: onChange(step.chosenCents + stride)
            case .decrement: onChange(step.chosenCents - stride)
            @unknown default: break
            }
        }
    }

    private func markShape(_ mark: Mark) -> some View {
        let markWidth = mark.isMedian ? Self.medianMarkWidth : Self.endMarkWidth
        return Rectangle()
            .fill(mark.isMedian ? theme.colors.accentBrassDim : theme.colors.divider)
            .frame(width: markWidth, height: mark.isMedian ? Self.medianMarkHeight : Self.endMarkHeight)
            .offset(x: mark.x - markWidth / 2, y: mark.isMedian ? Self.medianMarkTop : Self.endMarkTop)
    }

    /// The frame's knob: brass, ringed in the background so it reads clear
    /// of the track it sits on, over the plate's own cast shadow.
    private var knob: some View {
        Circle()
            .fill(theme.colors.background)
            .frame(width: Self.knobOuterRadius * 2, height: Self.knobOuterRadius * 2)
            .overlay(
                Circle()
                    .fill(theme.colors.accentBrass)
                    .frame(width: Self.knobDiameter, height: Self.knobDiameter)
            )
            .shadow(
                color: theme.colors.plateEdgeShadow,
                radius: Self.knobShadowRadius,
                x: 0,
                y: Self.knobShadowOffset
            )
    }

    /// The gesture calls the seam and nothing else.
    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                onChange(Self.cents(atX: gesture.location.x,
                                    trackWidth: width,
                                    lower: step.lowerCents,
                                    upper: step.upperCents,
                                    median: step.medianCents))
            }
    }

    // MARK: - The labels

    /// The two ends' amounts and the median's caption, combined into the one
    /// element that speaks the marks. A zero-width range has one mark, so it
    /// says one thing: the amount both ends stand on.
    private func labelRow(width: CGFloat) -> some View {
        let medianX = Self.x(
            forCents: step.medianCents,
            trackWidth: width,
            lower: step.lowerCents,
            upper: step.upperCents
        )
        return ZStack(alignment: .topLeading) {
            if step.lowerCents == step.upperCents {
                amount(
                    cents: step.lowerCents,
                    spoken: MarketCopy.medianAskingPriceLabel(cents: step.medianCents)
                )
                .frame(width: width, height: Self.labelRowHeight, alignment: .leading)
            } else {
                amount(
                    cents: step.lowerCents,
                    spoken: MarketCopy.typicalLowLabel(cents: step.lowerCents)
                )
                .frame(width: width, height: Self.labelRowHeight, alignment: .leading)
                medianCaption
                    .frame(width: width, height: Self.labelRowHeight, alignment: .center)
                    .offset(x: medianX - width / 2)
                amount(
                    cents: step.upperCents,
                    spoken: MarketCopy.typicalHighLabel(cents: step.upperCents)
                )
                .frame(width: width, height: Self.labelRowHeight, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func amount(cents: Int, spoken: String) -> some View {
        Text(MarketCopy.median(cents: cents))
            .font(theme.typography.monoMeta)
            .foregroundStyle(theme.colors.textMonoMeta)
            .monospacedDigit()
            .fixedSize()
            .accessibilityLabel(spoken)
    }

    private var medianCaption: some View {
        Text(MarketCopy.medianMark)
            .font(theme.typography.monoLabel)
            .tracking(Self.medianMarkTracking)
            .foregroundStyle(theme.colors.textQuiet)
            .fixedSize()
            .accessibilityLabel(MarketCopy.medianAskingPriceLabel(cents: step.medianCents))
    }

    // MARK: - The seam

    /// One mark on the track, by its centre. The median's is the taller one.
    nonisolated struct Mark: Hashable, Sendable {
        let x: CGFloat
        let isMedian: Bool
    }

    /// The two ends and the median — or, when the bounds have no width at
    /// all (three identical asking prices, plan Amendment B), the single
    /// mark all three collapse into. It is drawn as the median's, because
    /// that is what the amount under it is.
    nonisolated static func marks(trackWidth: CGFloat, lower: Int, upper: Int, median: Int) -> [Mark] {
        let medianX = x(forCents: median, trackWidth: trackWidth, lower: lower, upper: upper)
        guard upper > lower else { return [Mark(x: medianX, isMedian: true)] }
        return [
            Mark(x: endMarkWidth / 2, isMedian: false),
            Mark(x: medianX, isMedian: true),
            Mark(x: trackWidth - endMarkWidth / 2, isMedian: false),
        ]
    }

    /// An amount's place on the track. A zero-width range sits at the left
    /// end rather than dividing by nothing — the guard that keeps a NaN out
    /// of the layout.
    nonisolated static func x(forCents cents: Int, trackWidth: CGFloat, lower: Int, upper: Int) -> CGFloat {
        guard upper > lower else { return 0 }
        let clamped = min(max(cents, lower), upper)
        return CGFloat(clamped - lower) / CGFloat(upper - lower) * trackWidth
    }

    /// A drag's x as an amount: linear between the bounds, rounded to whole
    /// currency through `MarketAdoption` — the app's one rounding — and
    /// snapped to the median within `snapTolerance` of its mark, so the
    /// default is a position the hand can find again.
    ///
    /// A zero-width range answers with its one amount, whatever the drag
    /// does: the control is inert rather than undefined.
    nonisolated static func cents(
        atX x: CGFloat,
        trackWidth: CGFloat,
        lower: Int,
        upper: Int,
        median: Int
    ) -> Int {
        guard upper > lower, trackWidth > 0 else { return lower }

        let snapped = min(max(median, lower), upper)
        let medianX = Self.x(forCents: snapped, trackWidth: trackWidth, lower: lower, upper: upper)
        if abs(x - medianX) <= snapTolerance {
            return MarketAdoption.wholeCurrencyCents(from: snapped)
        }

        let fraction = min(max(x / trackWidth, 0), 1)
        let raw = Double(lower) + Double(upper - lower) * Double(fraction)
        let whole = MarketAdoption.wholeCurrencyCents(from: Int(raw.rounded()))
        return min(max(whole, lower), upper)
    }

    /// What one VoiceOver adjustment moves: 1 % of the range in whole
    /// currency, never less than a single unit — so a narrow range still
    /// moves, and a wide one doesn't take four hundred swipes to cross.
    nonisolated static func adjustableStep(lower: Int, upper: Int) -> Int {
        let onePercent = Int((Double(upper - lower) / 100).rounded())
        return max(MarketAdoption.wholeCurrencyCents(from: onePercent), 100)
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

    return ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        MarketValueSlider(step: step, isWanted: false, onChange: { chosen = $0 })
            .padding(.horizontal, 24)
    }
    .environment(\.theme, .dark)
}

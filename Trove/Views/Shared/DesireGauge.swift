import SwiftUI

/// The desire-to-*own* gauge — the wishlist's counterpart to `DesireDial`, and
/// deliberately not the same control.
///
/// The dial's rust→moss sweep encodes a keep/sell axis, which means nothing for
/// something you don't own yet: a "1" on a wishlist is low priority, not "get
/// rid of this". Two near-identical dials standing for structurally different
/// measurements would read worse than two obviously different controls, so this
/// is a different shape on a different scale (1–3, not 1–5). See plan.md's
/// `DesireGauge` entry.
///
/// `010` redesigned the ramp for at-a-glance legibility (tokens.md's "stepped
/// ramp" table): the three sheared segments now *ascend in height* — carrying
/// the ramp's direction even where the brass progression alone might not (a
/// quick glance, or limited color perception) — unfilled segments became
/// hairline outlines rather than solid tracks, and list rows gained a small
/// always-on "DESIRE" legend. Flat fills and hard edges throughout; the brief
/// still rules out rendered materials here as everywhere else.
struct DesireGauge: View {
    @Binding var value: Int

    /// The tallest (third) segment's height; the other two derive from
    /// tokens.md's 8/11/14 ratio, and every other dimension scales off this so
    /// larger gauges keep the row gauge's proportions. Row default `14`.
    var maxSegmentHeight: CGFloat = 14
    /// One segment's width. Row default `12`, per tokens.md.
    var segmentWidth: CGFloat = 12
    /// The per-row "DESIRE" legend — list rows only. The form and detail
    /// screens carry their own headings, where the word would be a repeat.
    var showsLegend: Bool = false
    var showsLabel: Bool = false
    var isInteractive: Bool = false

    @Environment(\.theme) private var theme

    private var level: DesireToOwnLevel { DesireToOwnLevel(clamping: value) }

    private var gap: CGFloat { Self.gap(forMaxHeight: maxSegmentHeight) }
    private var totalWidth: CGFloat {
        Self.totalWidth(segmentWidth: segmentWidth, maxHeight: maxSegmentHeight)
    }

    var body: some View {
        // Adjustable only where the gauge is actually a control — the list
        // rows build it read-only over a `.constant` binding, and an
        // adjustable element whose adjustments go nowhere is worse for
        // VoiceOver than a plain value read-out (T039 review, finding 12).
        // Attached conditionally rather than guarded inside the action, so
        // the read-only gauge doesn't advertise "adjustable" at all.
        if isInteractive {
            labeledGauge.accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: value = min(value + 1, DesireToOwnLevel.allCases.count)
                case .decrement: value = max(value - 1, 1)
                default: break
                }
            }
        } else {
            labeledGauge
        }
    }

    private var labeledGauge: some View {
        HStack(alignment: .bottom, spacing: showsLegend ? 7 : (showsLabel ? 10 : 0)) {
            if showsLegend {
                // Baseline flush with the segments' bottom edge — the design
                // nudges it 1px below the flex line (tokens.md's legend row).
                Text("DESIRE")
                    .font(ThemeTypography.font(.mono, size: 8.5))
                    .tracking(1.02)
                    .foregroundStyle(theme.colors.textDisabled)
                    .offset(y: 1)
            }
            segments
            if showsLabel {
                Text(level.summary)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textBody)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Desire to own")
        .accessibilityValue("\(level.rawValue) of \(DesireToOwnLevel.allCases.count), \(level.summary)")
    }

    private var segments: some View {
        HStack(alignment: .bottom, spacing: gap) {
            ForEach(DesireToOwnLevel.allCases, id: \.rawValue) { segment in
                let height = Self.height(of: segment, maxHeight: maxSegmentHeight)
                shape(for: segment, height: height)
                    .frame(width: segmentWidth, height: height)
                    .animation(.snappy(duration: 0.2), value: value)
            }
        }
        .frame(width: totalWidth, height: maxSegmentHeight, alignment: .bottom)
        .contentShape(Rectangle())
        .gesture(isInteractive ? dragGesture : nil)
    }

    /// A filled segment draws its position's tone; an unfilled one draws only
    /// tokens.md's hairline outline, so the scale stays visible without a
    /// solid track competing with the reading.
    @ViewBuilder
    private func shape(for segment: DesireToOwnLevel, height: CGFloat) -> some View {
        let parallelogram = Parallelogram(shear: Self.shear(forHeight: height))
        if let tone = Self.segmentFill(segment, filledThrough: level, in: theme.colors) {
            parallelogram.fill(tone)
        } else {
            parallelogram.strokeBorder(theme.colors.gaugeTrack, lineWidth: theme.metrics.hairline)
        }
    }

    /// Tap or drag anywhere across the gauge, rather than requiring a hit on
    /// one small segment — the same reasoning as the dial accepting a touch
    /// anywhere on the control.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let newValue = Self.value(atX: gesture.location.x, totalWidth: totalWidth)
                if newValue != value { value = newValue }
            }
    }

    // MARK: - Colour ramp

    /// A segment's fill: its own tone if the reading has reached it, `nil` if
    /// it hasn't — an unfilled segment has no fill at all since `010`, only
    /// the hairline track outline.
    ///
    /// The tone belongs to the *position*, not to the reading — segment 1 is
    /// always the dimmest brass, segment 3 always the brightest. So count,
    /// brightness and now height all reinforce each other, and the brightest
    /// tone appears only at "Next". Reading the ramp off the level instead
    /// would light every segment the same and throw that away.
    static func segmentFill(
        _ segment: DesireToOwnLevel,
        filledThrough level: DesireToOwnLevel,
        in colors: ThemeColors
    ) -> Color? {
        guard segment.rawValue <= level.rawValue else { return nil }
        return fillTone(segment, in: colors)
    }

    /// The three fill tones, dimmest first.
    ///
    /// Held between `accentBrassDim` and `accentBrass` rather than reaching for
    /// `accentBrassHover` at the top: hover is a state token, not a brightness
    /// step, and the app's canonical brass is the right place for the scale to
    /// top out. The middle is `accentBrassMid`, the Oklab-searched half-mix —
    /// the three land 0.109 and 0.108 apart, against the 0.06 floor the dial's
    /// stops are held to. `DesireGaugeColorTests` measures the rendered pixels
    /// rather than trusting this comment.
    static func fillTone(_ segment: DesireToOwnLevel, in colors: ThemeColors) -> Color {
        switch segment {
        case .someday: colors.accentBrassDim
        case .soon: colors.accentBrassMid
        case .next: colors.accentBrass
        }
    }

    // MARK: - Geometry

    /// tokens.md's 8/11/14 ascending heights, expressed as ratios of the
    /// tallest so larger gauges keep the proportion.
    static func height(of segment: DesireToOwnLevel, maxHeight: CGFloat) -> CGFloat {
        let ratios: [CGFloat] = [8.0 / 14.0, 11.0 / 14.0, 1.0]
        return ratios[segment.rawValue - 1] * maxHeight
    }

    /// `4` at the row's 14pt height, scaling with it.
    static func gap(forMaxHeight maxHeight: CGFloat) -> CGFloat { maxHeight * 4.0 / 14.0 }

    /// tokens.md's `skewX(-12deg)`: each segment leans by its *own* height's
    /// tangent, so all three share one angle rather than one offset.
    static func shear(forHeight height: CGFloat) -> CGFloat {
        height * tan(12 * .pi / 180)
    }

    static func totalWidth(segmentWidth: CGFloat, maxHeight: CGFloat) -> CGFloat {
        let count = CGFloat(DesireToOwnLevel.allCases.count)
        return segmentWidth * count + gap(forMaxHeight: maxHeight) * (count - 1)
    }

    /// A segment's centre in the gauge's own coordinate space — bottom-aligned
    /// since the heights ascend, so each centre sits half its own height above
    /// the shared baseline.
    ///
    /// The shear is symmetric about a segment's mid-height, so the centre
    /// stays inside the shape however far it leans — which is what makes it a
    /// safe place to sample a fill from.
    static func segmentCentre(
        _ segment: DesireToOwnLevel,
        segmentWidth: CGFloat,
        maxHeight: CGFloat
    ) -> CGPoint {
        let index = CGFloat(segment.rawValue - 1)
        let pitch = segmentWidth + gap(forMaxHeight: maxHeight)
        let height = Self.height(of: segment, maxHeight: maxHeight)
        return CGPoint(x: index * pitch + segmentWidth / 2, y: maxHeight - height / 2)
    }

    // MARK: - Touch mapping

    /// Maps a touch to 1–3 by which third of the gauge it lands in.
    ///
    /// Static and separate from the gesture for the same reason the dial's is:
    /// it's the piece with an off-by-one in it, and the only symptom of getting
    /// it wrong is a control that sets the wrong number.
    static func value(atX x: CGFloat, totalWidth: CGFloat) -> Int {
        let count = DesireToOwnLevel.allCases.count
        guard totalWidth > 0 else { return 1 }

        let fraction = min(max(Double(x / totalWidth), 0), 0.999_999)
        return Int(fraction * Double(count)) + 1
    }
}

/// A sheared rectangle — the gauge's segment shape.
///
/// Leans right by `shear` points, top edge shifted forward and bottom edge
/// back, so a row of them reads as an instrument scale rather than a progress
/// bar. Hard corners and a flat fill, per the brief's no-rendered-materials
/// constraint. Insettable so an unfilled segment can carry tokens.md's
/// border-box hairline via `strokeBorder`.
nonisolated struct Parallelogram: InsettableShape {
    let shear: CGFloat
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> Parallelogram {
        var shape = self
        shape.insetAmount += amount
        return shape
    }

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + shear, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - shear, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Every level") {
    @Previewable @State var values = [1, 2, 3]

    return ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 24) {
            ForEach(values.indices, id: \.self) { index in
                DesireGauge(value: .constant(values[index]), showsLegend: true)
            }
            Divider().overlay(Theme.dark.colors.divider)
            ForEach(values.indices, id: \.self) { index in
                DesireGauge(
                    value: .constant(values[index]),
                    maxSegmentHeight: 18,
                    segmentWidth: 30,
                    showsLabel: true
                )
            }
        }
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
}

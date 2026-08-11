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
/// Three sheared segments filled left to right. Flat fills and hard edges, no
/// gradient — the design brief rules out rendered materials here as everywhere
/// else. Unfilled segments stay visible as dim tracks so it reads as a scale
/// with a reading on it rather than a tally of marks.
struct DesireGauge: View {
    @Binding var value: Int

    /// One segment. Row default; the form and detail screens pass something
    /// larger. Height drives the shear, so a bigger gauge leans by the same
    /// angle rather than the same number of points.
    var segmentSize = CGSize(width: 14, height: 10)
    var showsLabel: Bool = false
    var isInteractive: Bool = false

    @Environment(\.theme) private var theme

    private var level: DesireToOwnLevel { DesireToOwnLevel(clamping: value) }

    private var gap: CGFloat { Self.gap(forHeight: segmentSize.height) }
    private var shear: CGFloat { Self.shear(forHeight: segmentSize.height) }
    private var totalWidth: CGFloat { Self.totalWidth(segmentSize: segmentSize) }

    var body: some View {
        HStack(spacing: showsLabel ? 10 : 0) {
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
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, DesireToOwnLevel.allCases.count)
            case .decrement: value = max(value - 1, 1)
            default: break
            }
        }
    }

    private var segments: some View {
        HStack(spacing: gap) {
            ForEach(DesireToOwnLevel.allCases, id: \.rawValue) { segment in
                Parallelogram(shear: shear)
                    .fill(Self.segmentColor(segment, filledThrough: level, in: theme.colors))
                    .frame(width: segmentSize.width, height: segmentSize.height)
                    .animation(.snappy(duration: 0.2), value: value)
            }
        }
        .frame(width: totalWidth, height: segmentSize.height)
        .contentShape(Rectangle())
        .gesture(isInteractive ? dragGesture : nil)
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

    /// A segment's fill: its own tone if the reading has reached it, the empty
    /// track if it hasn't.
    ///
    /// The tone belongs to the *position*, not to the reading — segment 1 is
    /// always the dimmest brass, segment 3 always the brightest. So count and
    /// brightness reinforce each other, and the brightest tone appears only at
    /// "Next". Reading the ramp off the level instead would light every
    /// segment the same and throw that away.
    static func segmentColor(
        _ segment: DesireToOwnLevel,
        filledThrough level: DesireToOwnLevel,
        in colors: ThemeColors
    ) -> Color {
        guard segment.rawValue <= level.rawValue else { return colors.divider }
        return fillTone(segment, in: colors)
    }

    /// The three fill tones, dimmest first.
    ///
    /// Held between `accentBrassDim` and `accentBrass` rather than reaching for
    /// `accentBrassHover` at the top: hover is a state token, not a brightness
    /// step, and the app's canonical brass is the right place for the scale to
    /// top out. Picked by measuring an Oklab model of the ramp, not by eye —
    /// the three land 0.109 and 0.108 apart, against the 0.06 floor the dial's
    /// stops are held to. `DesireGaugeColorTests` measures the rendered pixels
    /// rather than trusting this comment.
    static func fillTone(_ segment: DesireToOwnLevel, in colors: ThemeColors) -> Color {
        switch segment {
        case .someday: colors.accentBrassDim
        case .soon: colors.accentBrassDim.mix(with: colors.accentBrass, by: 0.5)
        case .next: colors.accentBrass
        }
    }

    // MARK: - Geometry

    /// Exposed the same way `DesireDial`'s arc geometry is: a test that has to
    /// re-derive where a segment sits would be checking its own arithmetic
    /// rather than the view's.
    static func gap(forHeight height: CGFloat) -> CGFloat { max(height * 0.3, 2) }

    /// Slight and consistent, per the brief — enough that the row of segments
    /// doesn't read as a plain progress bar, not so much that it becomes a
    /// chevron. Scales with height so a larger gauge leans at the same angle
    /// rather than by the same number of points.
    static func shear(forHeight height: CGFloat) -> CGFloat { height * 0.35 }

    static func totalWidth(segmentSize: CGSize) -> CGFloat {
        let count = CGFloat(DesireToOwnLevel.allCases.count)
        return segmentSize.width * count + gap(forHeight: segmentSize.height) * (count - 1)
    }

    /// A segment's centre in the gauge's own coordinate space.
    ///
    /// The shear is symmetric about mid-height — the top edge leads by `shear`
    /// and the bottom trails by the same — so the centre stays at the
    /// segment's midpoint however far it leans. That's what makes the centre a
    /// safe place to sample a fill from.
    static func segmentCentre(_ segment: DesireToOwnLevel, segmentSize: CGSize) -> CGPoint {
        let index = CGFloat(segment.rawValue - 1)
        let pitch = segmentSize.width + gap(forHeight: segmentSize.height)
        return CGPoint(x: index * pitch + segmentSize.width / 2, y: segmentSize.height / 2)
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
/// constraint.
struct Parallelogram: Shape {
    let shear: CGFloat

    func path(in rect: CGRect) -> Path {
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
                DesireGauge(value: .constant(values[index]))
            }
            Divider().overlay(Theme.dark.colors.divider)
            ForEach(values.indices, id: \.self) { index in
                DesireGauge(
                    value: .constant(values[index]),
                    segmentSize: CGSize(width: 30, height: 18),
                    showsLabel: true
                )
            }
        }
        .padding(Theme.dark.metrics.screenGutter)
    }
    .environment(\.theme, .dark)
}

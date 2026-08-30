import SwiftUI

/// The desire-to-keep dial — the app's one recurring piece of visual identity
/// (design/brief.md), replacing a star rating everywhere one would appear.
///
/// A thin arc and a numeral, deliberately not a knob: the brief rules out
/// rendered materials, bevels and shadows. It sweeps rust at 1 through to
/// moss at 5, so the colour carries the meaning as much as the number does.
///
/// Set `isInteractive` for the form and detail screens, where the brief calls
/// for tap-or-drag editing; list rows show it small and static.
struct DesireDial: View {
    @Binding var value: Int
    var diameter: CGFloat = 96
    var isInteractive: Bool = false
    /// The "OF 5" caption under the numeral, as on the item detail mock.
    var showsScale: Bool = false

    @Environment(\.theme) private var theme

    /// Leaves a gap at the bottom so the ends read as a scale with two ends
    /// rather than a closed ring.
    private let startAngle = Angle.degrees(150)
    private let sweep = Angle.degrees(240)

    private var level: DesireLevel { DesireLevel(clamping: value) }

    private var progress: CGFloat { CGFloat(Self.progress(for: level)) }

    private var lineWidth: CGFloat { max(diameter * 0.035, 2) }

    private var arcColor: Color { Self.arcColor(for: level, in: theme.colors) }
    private var numeralColor: Color { Self.numeralColor(for: level, in: theme.colors) }

    var body: some View {
        ZStack {
            track
            filledArc
            knob
            numerals
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(isInteractive ? dragGesture : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Desire to keep")
        .accessibilityValue("\(level.rawValue) of 5, \(level.summary)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, 5)
            case .decrement: value = max(value - 1, 1)
            default: break
            }
        }
    }

    private var track: some View {
        Circle()
            .trim(from: 0, to: sweep.degrees / 360)
            .stroke(theme.colors.divider, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(startAngle)
    }

    private var filledArc: some View {
        Circle()
            .trim(from: 0, to: (sweep.degrees / 360) * progress)
            .stroke(arcColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(startAngle)
            .animation(.snappy(duration: 0.2), value: value)
    }

    /// Marks the current point on the scale. At value 1 it sits at the arc's
    /// start, which is why the filled arc can legitimately have zero length.
    ///
    /// Offsets straight up and then rotates, rather than being `.position`ed:
    /// the rotation is what makes the knob travel *along* the arc between
    /// values instead of cutting the chord across it.
    private var knob: some View {
        Circle()
            .fill(arcColor)
            .frame(width: lineWidth * 2.2, height: lineWidth * 2.2)
            .offset(y: -Self.arcRadius(diameter: diameter))
            .rotationEffect(Self.angle(for: level, startAngle: startAngle, sweep: sweep) + .degrees(90))
            .animation(.snappy(duration: 0.2), value: value)
    }

    private var numerals: some View {
        VStack(spacing: 1) {
            Text("\(level.rawValue)")
                .font(theme.typography.dialNumeral(diameter: diameter))
                .foregroundStyle(numeralColor)
            if showsScale {
                Text("of \(DesireLevel.allCases.count)")
                    .monoLabel(color: theme.colors.textQuiet)
            }
        }
    }

    /// Angle around the dial decides the value, so a drag anywhere on the
    /// control works — the user doesn't have to catch the knob itself.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let newValue = Self.value(
                    at: gesture.location,
                    centre: CGPoint(x: diameter / 2, y: diameter / 2),
                    startAngle: startAngle,
                    sweep: sweep
                )
                if newValue != value { value = newValue }
            }
    }

    // MARK: - Colour ramp

    /// The arc and knob: rust at 1, through tokens.md's `dialMidpoint`, to
    /// moss at 5. Sell at one end, keep at the other, with the midpoint
    /// keeping the intermediate values from being just one of the three
    /// named colours.
    ///
    /// Brass used to hold the "keep" end, which put the app's primary accent
    /// — the colour of every value figure and CTA — on a rating rather than
    /// on money. Moss says "settled, growing, staying put" and leaves brass
    /// to mean what it means everywhere else.
    static func arcColor(for level: DesireLevel, in colors: ThemeColors) -> Color {
        ramp(level, low: colors.accentRust, mid: colors.dialMidpoint, high: colors.accentMoss)
    }

    /// The numeral. Same ramp, but built from the text-safe lifts at both
    /// ends, because this one renders as type.
    ///
    /// tokens.md is explicit that `accentRust`/`accentMoss` are for strokes
    /// and fills only — as text on `surface` they measure 2.7:1 and 2.6:1.
    /// The dial drew its numeral in the shape colour until moss arrived,
    /// which made the "1" a real contrast failure; `DesireDialColorTests`
    /// now measures every stop rather than trusting the token names.
    static func numeralColor(for level: DesireLevel, in colors: ThemeColors) -> Color {
        ramp(level, low: colors.accentRustText, mid: colors.dialMidpoint, high: colors.accentMossText)
    }

    private static func ramp(
        _ level: DesireLevel,
        low: Color,
        mid: Color,
        high: Color
    ) -> Color {
        switch level {
        case .readyToSell: low
        case .wouldLetItGo: low.mix(with: mid, by: 0.5)
        case .undecided: mid
        case .keepingForNow: mid.mix(with: high, by: 0.5)
        case .absolutelyKeeping: high
        }
    }

    // MARK: - Geometry

    /// 1 sits at the very start of the arc, 5 at the very end.
    static func progress(for level: DesireLevel) -> Double {
        Double(level.rawValue - 1) / Double(DesireLevel.allCases.count - 1)
    }

    /// The arc's centreline radius.
    ///
    /// `Circle()` inscribes itself in its frame and `stroke` centres the line
    /// on that path, so the arc runs at exactly half the diameter with the
    /// stroke spreading either side of it. The knob offset by
    /// `(diameter - lineWidth) / 2` instead, which parked it half a
    /// stroke-width inboard at every value — subtle enough to look
    /// deliberate, obvious once you rest on one dial.
    static func arcRadius(diameter: CGFloat) -> CGFloat { diameter / 2 }

    /// How much of the dial's own square sits empty below its ink.
    ///
    /// The sweep runs 150°→390°, so it never reaches 6 o'clock: both ends
    /// stop at `sin 30° = 0.5`, putting the lowest ink at ¾ of the diameter
    /// plus the knob's overhang. The remaining quarter is blank — which is
    /// why a card that pads the dial equally top and bottom *measures* even
    /// and *looks* bottom-heavy. Cards trim it with a negative bottom
    /// padding; `DesireDialTests` pins the arithmetic against the rendered
    /// arc rather than trusting this comment.
    static func emptyBottomInset(diameter: CGFloat) -> CGFloat {
        diameter * 0.25 - knobOverhang(diameter: diameter)
    }

    /// How far the knob spills past the arc — and so past the dial's frame at
    /// 12 o'clock, where the arc runs along the frame's own edge. A card that
    /// wants even-looking gaps has to give this back at the top, the mirror
    /// of `emptyBottomInset` at the bottom.
    static func knobOverhang(diameter: CGFloat) -> CGFloat {
        max(diameter * 0.035, 2) * 1.1
    }

    /// Where a level sits on the dial, as a screen bearing measured clockwise
    /// from 3 o'clock — the same convention the trimmed `Circle` is drawn in
    /// and `value(at:)` reads back.
    static func angle(for level: DesireLevel, startAngle: Angle, sweep: Angle) -> Angle {
        .degrees(startAngle.degrees + sweep.degrees * progress(for: level))
    }

    /// The knob's centre in the dial's own coordinate space.
    ///
    /// Exists so the placement can be tested as the exact inverse of
    /// `value(at:centre:startAngle:sweep:)`: a knob that doesn't sit where a
    /// tap on it would read is the whole class of bug here.
    static func knobCentre(
        for level: DesireLevel,
        diameter: CGFloat,
        startAngle: Angle,
        sweep: Angle
    ) -> CGPoint {
        let bearing = angle(for: level, startAngle: startAngle, sweep: sweep).radians
        let radius = arcRadius(diameter: diameter)
        return CGPoint(
            x: diameter / 2 + radius * cos(bearing),
            y: diameter / 2 + radius * sin(bearing)
        )
    }

    // MARK: - Touch mapping

    /// Maps a touch point onto 1–5 by its angle around the centre.
    ///
    /// Static and separate from the gesture so it can be tested: the mapping
    /// is pure trigonometry with an easy off-by-90 in it, and the only symptom
    /// of getting it wrong is a dial that sets the wrong number — which needs
    /// a hand on the simulator to notice.
    static func value(
        at point: CGPoint,
        centre: CGPoint,
        startAngle: Angle,
        sweep: Angle
    ) -> Int {
        let dx = point.x - centre.x
        let dy = point.y - centre.y

        // atan2 in view coordinates (y grows downward) is measured clockwise
        // from 3 o'clock, which is also where a trimmed Circle path begins —
        // so subtracting the arc's own rotation gives the offset along it.
        var degrees = atan2(dy, dx) * 180 / .pi - startAngle.degrees
        while degrees < 0 { degrees += 360 }
        while degrees >= 360 { degrees -= 360 }

        let steps = Double(DesireLevel.allCases.count - 1)

        // Past the end of the sweep is the gap at the bottom. Snap to whichever
        // end is nearer rather than letting the value jump across the gap.
        guard degrees <= sweep.degrees else {
            let past = degrees - sweep.degrees
            let gap = 360 - sweep.degrees
            return past > gap / 2 ? 1 : Int(steps) + 1
        }

        return Int((degrees / sweep.degrees * steps).rounded()) + 1
    }
}

#Preview("Every level") {
    @Previewable @State var values = [1, 2, 3, 4, 5]

    return ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                ForEach(values.indices, id: \.self) { index in
                    DesireDial(value: .constant(values[index]), diameter: 62)
                }
            }
            DesireDial(value: .constant(5), diameter: 130, isInteractive: true, showsScale: true)
        }
    }
    .environment(\.theme, .dark)
}

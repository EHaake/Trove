import SwiftUI

/// The desire-to-keep dial — the app's one recurring piece of visual identity
/// (design/brief.md), replacing a star rating everywhere one would appear.
///
/// A thin arc and a numeral, deliberately not a knob: the brief rules out
/// rendered materials, bevels and shadows. It sweeps rust at 1 through to
/// brass at 5, so the colour carries the meaning as much as the number does.
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

    /// 1 sits at the very start of the arc, 5 at the very end.
    private var progress: CGFloat {
        CGFloat(level.rawValue - 1) / CGFloat(DesireLevel.allCases.count - 1)
    }

    private var lineWidth: CGFloat { max(diameter * 0.035, 2) }

    /// Rust through brass, with tokens.md's midpoint as the middle stop, so
    /// intermediate values aren't just one of the three named colours.
    private var valueColor: Color {
        switch level {
        case .readyToSell: theme.colors.accentRust
        case .wouldLetItGo: theme.colors.accentRust.mix(with: theme.colors.dialMidpoint, by: 0.5)
        case .undecided: theme.colors.dialMidpoint
        case .keepingForNow: theme.colors.dialMidpoint.mix(with: theme.colors.accentBrass, by: 0.5)
        case .absolutelyKeeping: theme.colors.accentBrass
        }
    }

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
            .stroke(valueColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(startAngle)
            .animation(.snappy(duration: 0.2), value: value)
    }

    /// Marks the current point on the scale. At value 1 it sits at the arc's
    /// start, which is why the filled arc can legitimately have zero length.
    private var knob: some View {
        Circle()
            .fill(valueColor)
            .frame(width: lineWidth * 2.2, height: lineWidth * 2.2)
            .offset(y: -(diameter - lineWidth) / 2)
            .rotationEffect(startAngle + Angle.degrees(sweep.degrees * Double(progress)) + .degrees(90))
            .animation(.snappy(duration: 0.2), value: value)
    }

    private var numerals: some View {
        VStack(spacing: 1) {
            Text("\(level.rawValue)")
                .font(theme.typography.dialNumeral)
                .foregroundStyle(valueColor)
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

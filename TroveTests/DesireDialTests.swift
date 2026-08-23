import Foundation
import SwiftUI
import Testing
@testable import Trove

/// The dial's touch-to-value mapping.
///
/// This shipped wrong once: the gesture subtracted `startAngle - 90` instead of
/// `startAngle`, borrowing the +90 that belongs to the knob's upward offset.
/// Tapping the "keep" end set 1 instead of 5. Nothing catches that but a hand
/// on the simulator or this suite.
@Suite("DesireDial touch mapping")
struct DesireDialTests {
    private let centre = CGPoint(x: 50, y: 50)
    private let radius: CGFloat = 40
    private let startAngle = Angle.degrees(150)
    private let sweep = Angle.degrees(240)

    /// A point on the dial at a screen bearing measured clockwise from
    /// 3 o'clock — the same convention the arc is drawn in.
    private func point(atScreenDegrees degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: centre.x + radius * cos(radians),
            y: centre.y + radius * sin(radians)
        )
    }

    private func value(atScreenDegrees degrees: Double) -> Int {
        DesireDial.value(
            at: point(atScreenDegrees: degrees),
            centre: centre,
            startAngle: startAngle,
            sweep: sweep
        )
    }

    /// The arc starts at 150° (lower left) and sweeps 240° clockwise, so the
    /// five stops land every 60°.
    @Test(arguments: [(150.0, 1), (210.0, 2), (270.0, 3), (330.0, 4), (30.0, 5)])
    func mapsEachStopOnTheArcToItsValue(screenDegrees: Double, expected: Int) {
        #expect(value(atScreenDegrees: screenDegrees) == expected)
    }

    /// Straight up is the middle of the scale — the single easiest position to
    /// eyeball against the running app.
    @Test func twelveOClockIsTheMiddleOfTheScale() {
        #expect(value(atScreenDegrees: 270) == 3)
    }

    @Test func roundsToTheNearestStopBetweenTwoOfThem() {
        #expect(value(atScreenDegrees: 175) == 1)
        #expect(value(atScreenDegrees: 195) == 2)
    }

    /// Below the dial is the gap in the arc. Sliding off either end should
    /// stick at that end rather than leaping to the opposite one.
    @Test func snapsToTheNearerEndInsideTheGap() {
        // Just past the "keep" end at 30°, heading down toward 6 o'clock.
        #expect(value(atScreenDegrees: 50) == 5)
        // Just before the "sell" end at 150°.
        #expect(value(atScreenDegrees: 130) == 1)
    }

    @Test func staysWithinTheScaleForEveryAngle() {
        for degrees in stride(from: 0.0, to: 360.0, by: 1.0) {
            let result = value(atScreenDegrees: degrees)
            #expect(result >= 1 && result <= 5, "angle \(degrees) produced \(result)")
        }
    }

    /// Only the angle matters, so a touch near the centre or outside the ring
    /// still reads as the same value.
    @Test func dependsOnAngleNotDistanceFromCentre() {
        let near = DesireDial.value(
            at: CGPoint(x: centre.x + 5, y: centre.y - 5 * 0.0001),
            centre: centre,
            startAngle: startAngle,
            sweep: sweep
        )
        let far = DesireDial.value(
            at: CGPoint(x: centre.x + 500, y: centre.y - 500 * 0.0001),
            centre: centre,
            startAngle: startAngle,
            sweep: sweep
        )

        #expect(near == far)
    }

    // MARK: - Knob placement

    /// The knob shipped half a stroke-width inboard of the arc at every
    /// value, because it offset by `(diameter - lineWidth) / 2` while the arc
    /// runs at `diameter / 2`. Reads as the dot floating just below the line
    /// it's supposed to be riding.
    @Test(arguments: [36.0, 62.0, 116.0, 130.0] as [CGFloat])
    func theKnobSitsOnTheArcNotInsideIt(diameter: CGFloat) {
        let centre = CGPoint(x: diameter / 2, y: diameter / 2)

        for level in DesireLevel.allCases {
            let knob = DesireDial.knobCentre(
                for: level,
                diameter: diameter,
                startAngle: startAngle,
                sweep: sweep
            )
            let radius = hypot(knob.x - centre.x, knob.y - centre.y)
            #expect(
                abs(radius - diameter / 2) < 0.001,
                "level \(level.rawValue) sits at r=\(radius), arc is at r=\(diameter / 2)"
            )
        }
    }

    /// The other half of the contract, and the one that catches an angle
    /// error rather than a radius one: tapping the knob has to read back as
    /// the value the knob is showing.
    @Test(arguments: DesireLevel.allCases)
    func tappingTheKnobReadsBackItsOwnValue(level: DesireLevel) {
        let diameter: CGFloat = 116
        let knob = DesireDial.knobCentre(
            for: level,
            diameter: diameter,
            startAngle: startAngle,
            sweep: sweep
        )
        let readBack = DesireDial.value(
            at: knob,
            centre: CGPoint(x: diameter / 2, y: diameter / 2),
            startAngle: startAngle,
            sweep: sweep
        )

        #expect(readBack == level.rawValue)
    }

    /// Anchors the ends against the arc's own drawing: 1 at the start of the
    /// sweep, 5 at the end of it.
    @Test func theEndsOfTheScaleSitAtTheEndsOfTheSweep() {
        // Degrees with a tolerance rather than `Angle ==`: the sweep is
        // reached by multiplying through a fraction, so the last stop lands a
        // few ulps off the sum however correct the arithmetic is.
        let start = DesireDial.angle(for: .readyToSell, startAngle: startAngle, sweep: sweep)
        let end = DesireDial.angle(for: .absolutelyKeeping, startAngle: startAngle, sweep: sweep)

        #expect(abs(start.degrees - startAngle.degrees) < 0.001)
        #expect(abs(end.degrees - (startAngle + sweep).degrees) < 0.001)
    }
}

/// The dial's colour ramp, and the contrast claim underneath it.
///
/// tokens.md says `accentRust` and `accentMoss` are "strokes, borders and
/// fills only" because they fail contrast on `surface` as text. That's an
/// architectural claim in a design document, so it gets measured here rather
/// than trusted — the more so because the dial drew its numeral in the shape
/// colour for several phases and nobody's eye caught it.
@Suite("DesireDial colour ramp")
struct DesireDialColorTests {
    private let colors = ThemeColors.dark

    /// WCAG 2.1 relative luminance. `Color.Resolved` exposes the linearised
    /// channels directly, which is exactly the transfer function the formula
    /// calls for, so there's no gamma maths to get wrong here.
    private func relativeLuminance(_ color: Color) -> Double {
        let resolved = color.resolve(in: EnvironmentValues())
        return 0.2126 * Double(resolved.linearRed)
            + 0.7152 * Double(resolved.linearGreen)
            + 0.0722 * Double(resolved.linearBlue)
    }

    private func contrastRatio(_ foreground: Color, on background: Color) -> Double {
        let a = relativeLuminance(foreground)
        let b = relativeLuminance(background)
        let (lighter, darker) = a > b ? (a, b) : (b, a)
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - The ramp's ends

    @Test func theArcRunsFromRustToMoss() {
        #expect(DesireDial.arcColor(for: .readyToSell, in: colors) == colors.accentRust)
        #expect(DesireDial.arcColor(for: .absolutelyKeeping, in: colors) == colors.accentMoss)
    }

    /// Brass is the app's money colour. It held the "keep" end until moss
    /// took over; if it ever comes back, it belongs on a value figure.
    @Test func brassNoLongerAppearsAnywhereOnTheDial() {
        for level in DesireLevel.allCases {
            #expect(DesireDial.arcColor(for: level, in: colors) != colors.accentBrass)
            #expect(DesireDial.numeralColor(for: level, in: colors) != colors.accentBrass)
        }
    }

    /// Not being *equal* to brass isn't enough — the midpoint is a yellow, and
    /// pushing it yellow enough to separate from moss walks it straight at
    /// brass. The rule that keeps both true at once: no stop may be closer to
    /// the money colour than it is to its own neighbours on the dial.
    ///
    /// Caught a real candidate during the retune that measured 0.058 from
    /// brass against 0.12 between stops — a "3" that read as a price.
    @Test func noStopIsMoreConfusableWithBrassThanWithItsNeighbours() {
        let toBrass = DesireLevel.allCases
            .map { perceptualDistance(DesireDial.arcColor(for: $0, in: colors), colors.accentBrass) }
            .min() ?? 0

        #expect(
            toBrass >= smallestGapBetweenStops,
            "closest stop sits \(toBrass) from brass, stops are \(smallestGapBetweenStops) apart"
        )
    }

    /// The complaint this ramp was retuned for: 3 read as a near-neighbour of
    /// 4 and 5 rather than as its own colour. Adjacent stops measured 0.062,
    /// 0.063, 0.043, 0.042 apart — the top half of the scale separated barely
    /// two-thirds as well as the bottom.
    ///
    /// The floor sits above what that ramp managed and below what this one
    /// does, so it fails on the version that prompted the complaint.
    @Test func noTwoAdjacentLevelsLookAlike() {
        #expect(
            smallestGapBetweenStops > 0.06,
            "closest pair of levels measures \(smallestGapBetweenStops) apart"
        )
    }

    /// Evenness, separately from magnitude: one generous gap doesn't excuse a
    /// cramped one elsewhere, which is exactly how the first rust→moss
    /// attempt failed.
    @Test func theStopsAreSpacedEvenly() {
        let gaps = adjacentGaps
        let widest = gaps.max() ?? 0
        let narrowest = gaps.min() ?? 0

        #expect(widest / narrowest < 1.5, "gaps between stops: \(gaps)")
    }

    private var adjacentGaps: [Double] {
        let stops = DesireLevel.allCases.map { DesireDial.arcColor(for: $0, in: colors) }
        return (0..<stops.count - 1).map { perceptualDistance(stops[$0], stops[$0 + 1]) }
    }

    private var smallestGapBetweenStops: Double { adjacentGaps.min() ?? 0 }

    /// Oklab ΔE, from the shared model in `TestSupport` — the gauge's tones are
    /// measured against the same one, so the two sets of thresholds mean the
    /// same thing.
    private func perceptualDistance(_ first: Color, _ second: Color) -> Double {
        Perceptual.distance(first, second)
    }

    @Test func theMidpointSitsAtTheMiddleOfTheScale() {
        #expect(DesireDial.arcColor(for: .undecided, in: colors) == colors.dialMidpoint)
        #expect(DesireDial.numeralColor(for: .undecided, in: colors) == colors.dialMidpoint)
    }

    @Test func theNumeralUsesTheTextSafeLiftsAtBothEnds() {
        #expect(DesireDial.numeralColor(for: .readyToSell, in: colors) == colors.accentRustText)
        #expect(DesireDial.numeralColor(for: .absolutelyKeeping, in: colors) == colors.accentMossText)
    }

    @Test func everyLevelGetsItsOwnColour() {
        let arc = DesireLevel.allCases.map { DesireDial.arcColor(for: $0, in: colors) }
        #expect(Set(arc).count == DesireLevel.allCases.count)
    }

    // MARK: - The contrast claim

    /// 3:1 is WCAG AA for large text, which is what the dial numeral is on the
    /// detail screen. It's also the threshold that separates the token pairs:
    /// the lifts clear it, the shape colours don't — see the test below, which
    /// is what stops this one from passing on a palette where nothing does.
    @Test(arguments: DesireLevel.allCases)
    func theNumeralStaysLegibleOnASurfaceCard(level: DesireLevel) {
        let ratio = contrastRatio(DesireDial.numeralColor(for: level, in: colors), on: colors.surface)
        #expect(ratio >= 3.0, "level \(level.rawValue) numeral measures \(ratio):1 on surface")
    }

    /// The other half of the pair, and the reason the split exists at all.
    /// Drawing the numeral in either of these — which is what the dial did
    /// before — puts unreadable text on the card.
    @Test func theShapeOnlyAccentsWouldFailAsNumerals() {
        #expect(contrastRatio(colors.accentRust, on: colors.surface) < 3.0)
        #expect(contrastRatio(colors.accentMoss, on: colors.surface) < 3.0)
    }

    /// Sanity check on the measurement itself: a formula that returned a
    /// constant, or ran the channels in the wrong order, would still satisfy
    /// the thresholds above by accident.
    @Test func theContrastFormulaAgreesWithKnownPairs() {
        #expect(contrastRatio(colors.surface, on: colors.surface) == 1.0)
        // Warm ivory on the card is the app's highest-contrast pairing.
        #expect(contrastRatio(colors.textPrimary, on: colors.surface) > 14.0)
    }
}

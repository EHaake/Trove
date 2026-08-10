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

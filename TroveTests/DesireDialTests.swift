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

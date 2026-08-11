import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// The gauge's touch-to-value mapping — the piece with an off-by-one in it,
/// whose only symptom is a control that sets the wrong number.
@Suite("DesireGauge touch mapping")
struct DesireGaugeTouchTests {
    private let width = DesireGauge.totalWidth(segmentSize: CGSize(width: 30, height: 18))

    private func value(atFraction fraction: CGFloat) -> Int {
        DesireGauge.value(atX: width * fraction, totalWidth: width)
    }

    @Test(arguments: [(0.0, 1), (0.2, 1), (0.4, 2), (0.5, 2), (0.7, 3), (1.0, 3)])
    func mapsEachThirdOfTheGaugeToItsLevel(fraction: CGFloat, expected: Int) {
        #expect(value(atFraction: fraction) == expected)
    }

    /// Dragging off either end sticks there rather than wrapping.
    @Test func clampsBeyondBothEnds() {
        #expect(DesireGauge.value(atX: -500, totalWidth: width) == 1)
        #expect(DesireGauge.value(atX: width + 500, totalWidth: width) == 3)
    }

    @Test func staysWithinTheScaleAcrossTheWholeControl() {
        for step in stride(from: -0.5, through: 1.5, by: 0.01) {
            let result = value(atFraction: CGFloat(step))
            #expect(result >= 1 && result <= 3, "fraction \(step) produced \(result)")
        }
    }

    /// A zero-width gauge can't be divided into thirds; it must not divide by
    /// zero either.
    @Test func aZeroWidthGaugeReadsAsTheBottomOfTheScale() {
        #expect(DesireGauge.value(atX: 0, totalWidth: 0) == 1)
    }

    /// Tapping a segment has to read back as that segment's own level, the
    /// same contract the dial's knob is held to.
    @Test(arguments: DesireToOwnLevel.allCases)
    func tappingASegmentReadsBackItsOwnLevel(segment: DesireToOwnLevel) {
        let size = CGSize(width: 30, height: 18)
        let centre = DesireGauge.segmentCentre(segment, segmentSize: size)
        let readBack = DesireGauge.value(
            atX: centre.x,
            totalWidth: DesireGauge.totalWidth(segmentSize: size)
        )

        #expect(readBack == segment.rawValue)
    }
}

/// Which segments light, and in which tone.
@Suite("DesireGauge fill logic")
struct DesireGaugeFillTests {
    private let colors = ThemeColors.dark

    @Test(arguments: DesireToOwnLevel.allCases)
    func segmentsUpToTheLevelAreFilledAndTheRestAreEmptyTrack(level: DesireToOwnLevel) {
        for segment in DesireToOwnLevel.allCases {
            let color = DesireGauge.segmentColor(segment, filledThrough: level, in: colors)
            if segment.rawValue <= level.rawValue {
                #expect(color == DesireGauge.fillTone(segment, in: colors))
            } else {
                #expect(color == colors.divider)
            }
        }
    }

    /// The tone belongs to the segment's position, not to the reading — which
    /// is what makes count and brightness reinforce each other. A ramp keyed
    /// off the level instead would light every segment the same.
    @Test func aSegmentKeepsItsOwnToneWhicheverLevelLitIt() {
        for segment in DesireToOwnLevel.allCases {
            let tones = DesireToOwnLevel.allCases
                .filter { segment.rawValue <= $0.rawValue }
                .map { DesireGauge.segmentColor(segment, filledThrough: $0, in: colors) }

            #expect(Set(tones).count == 1, "segment \(segment.rawValue) changed tone by level")
        }
    }

    /// The brightest tone is the payoff for reaching the top of the scale, so
    /// it must not appear below it.
    @Test func theBrightestToneAppearsOnlyAtTheTopLevel() {
        let brightest = DesireGauge.fillTone(.next, in: colors)

        for level in [DesireToOwnLevel.someday, .soon] {
            let shown = DesireToOwnLevel.allCases
                .map { DesireGauge.segmentColor($0, filledThrough: level, in: colors) }
            #expect(shown.contains(brightest) == false, "level \(level.rawValue) showed \(brightest)")
        }

        let atTop = DesireToOwnLevel.allCases
            .map { DesireGauge.segmentColor($0, filledThrough: .next, in: colors) }
        #expect(atTop.contains(brightest))
    }

    @Test func everySegmentGetsItsOwnTone() {
        let tones = DesireToOwnLevel.allCases.map { DesireGauge.fillTone($0, in: colors) }
        #expect(Set(tones).count == DesireToOwnLevel.allCases.count)
    }
}

/// The design-correctness claim, per CLAUDE.md: the three fill states have to
/// be perceptually distinguishable **at the size a list row actually draws
/// them**, measured off sampled pixels rather than eyeballed.
///
/// Sampling the rendered view rather than the palette tokens is the point. The
/// tokens are only what the gauge is *asked* to draw with; what reaches the eye
/// has been through compositing over `surface` and antialiasing on a sheared
/// edge at 14×10pt. A tone that measured fine in the palette and washed out on
/// a small parallelogram would pass a token-level test and still ship states
/// that look alike.
@Suite("DesireGauge perceptual separation at row size")
struct DesireGaugeColorTests {
    /// The row default — the smallest the gauge is ever drawn, so the hardest
    /// case. `WishlistView` uses `DesireGauge(value:)` with no size override.
    private let rowSize = CGSize(width: 14, height: 10)

    /// The floor `DesireDialColorTests` holds the dial's adjacent stops to.
    /// Reused deliberately: two ratings a tab apart shouldn't be separated to
    /// different standards.
    private let floor = 0.06

    /// One gauge, rendered on a card the way a row draws it, sampled at each
    /// segment's centre.
    @MainActor
    private func sampledSegments(atLevel level: Int) throws -> [RGB8] {
        let gauge = DesireGauge(value: .constant(level), segmentSize: rowSize)
            .background(ThemeColors.dark.surface)

        let image = try #require(renderBitmap(gauge), "ImageRenderer produced nothing to sample.")
        let bitmap = try #require(Bitmap(image), "Couldn't read the rendered pixels.")

        return try DesireToOwnLevel.allCases.map { segment in
            let centre = DesireGauge.segmentCentre(segment, segmentSize: rowSize)
            return try #require(
                bitmap.pixel(at: centre),
                "Segment \(segment.rawValue) centre \(centre) fell outside the \(bitmap.width)×\(bitmap.height) render."
            )
        }
    }

    /// A lit segment must not read as an unlit one. This is the failure the
    /// small size actually threatens: the dimmest brass sits closest to the
    /// empty track, and it's segment 1, which is lit at every level.
    @Test func everyFilledSegmentIsDistinguishableFromAnEmptyTrack() throws {
        let empty = try sampledSegments(atLevel: 1)[2]

        for level in DesireToOwnLevel.allCases {
            let sampled = try sampledSegments(atLevel: level.rawValue)
            for segment in DesireToOwnLevel.allCases where segment.rawValue <= level.rawValue {
                let lit = sampled[segment.rawValue - 1]
                let separation = Perceptual.distance(lit, empty)
                #expect(
                    separation > floor,
                    "level \(level.rawValue) segment \(segment.rawValue) is \(lit), empty track is \(empty), only \(separation) apart"
                )
            }
        }
    }

    /// The ramp has to read as a ramp: adjacent filled tones distinguishable
    /// from each other, or the brightness cue adds nothing to the count.
    @Test func adjacentFilledTonesAreDistinguishableFromEachOther() throws {
        let sampled = try sampledSegments(atLevel: 3)

        for index in 0..<sampled.count - 1 {
            let separation = Perceptual.distance(sampled[index], sampled[index + 1])
            #expect(
                separation > floor,
                "segments \(index + 1) and \(index + 2) are \(sampled[index]) and \(sampled[index + 1]), only \(separation) apart"
            )
        }
    }

    /// The claim as a user would state it: the three readings don't look alike.
    /// Each pair of states must differ somewhere a reader can see.
    @Test func theThreeReadingsAreTellableApart() throws {
        let states = try DesireToOwnLevel.allCases.map { try sampledSegments(atLevel: $0.rawValue) }

        for (first, second) in [(0, 1), (1, 2), (0, 2)] {
            let widest = zip(states[first], states[second])
                .map { Perceptual.distance($0, $1) }
                .max() ?? 0
            #expect(
                widest > floor,
                "levels \(first + 1) and \(second + 1) differ by at most \(widest): \(states[first]) vs \(states[second])"
            )
        }
    }

    /// Guards the measurement itself. If sampling were landing on background
    /// instead of fill — a geometry slip, a render that came back empty — every
    /// separation above would collapse toward zero and the suite would go quiet
    /// about it. Segment 1 lit is a brass; the card behind it is not.
    @Test func theSamplingLandsOnFillRatherThanTheCardBehindIt() throws {
        let lit = try sampledSegments(atLevel: 3)

        for (index, pixel) in lit.enumerated() {
            let expected = DesireGauge.fillTone(
                DesireToOwnLevel(clamping: index + 1),
                in: ThemeColors.dark
            )
            let drift = Perceptual.distance(pixel, expected)
            #expect(
                drift < 0.02,
                "segment \(index + 1) sampled \(pixel), token says \(expected), \(drift) apart"
            )
        }
    }
}

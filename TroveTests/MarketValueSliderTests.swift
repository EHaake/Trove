import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Trove

/// A figure row as the slider reads it, built the way `MarketValueStepTests`
/// builds one: a real record, its fields set, read back as a value.
private func snapshotValue(
    median: Int, low: Int, high: Int, p10: Int, p90: Int, count: Int = 12
) -> MarketSnapshotValue {
    let record = MarketFigureRecord(
        subjectID: UUID(),
        subjectKind: .owned,
        productID: 126_161,
        fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    record.medianCents = median
    record.lowCents = low
    record.highCents = high
    record.p10Cents = p10
    record.p90Cents = p90
    record.count = count
    return MarketSnapshotValue(record: record)
}

/// The bounds every test here uses: `$1,000` to `$2,000` with the median at
/// `$1,300` — off-centre and strictly inside, so a midpoint and a median can
/// never be mistaken for each other (plan Amendment B, guard B6). The true
/// spread is wider, as it is on a real row, and is not what the slider runs
/// between.
private let lowerCents = 100_000
private let upperCents = 200_000
private let medianCents = 130_000
private func boundedStep() -> MarketValueStep {
    MarketValueStep(
        figure: snapshotValue(
            median: medianCents,
            low: 90_000,
            high: 250_000,
            p10: lowerCents,
            p90: upperCents
        )
    )
}

/// Three identical asking prices: the bounds have no width, and every
/// division the geometry could make is a division by nothing.
private func zeroWidthStep() -> MarketValueStep {
    MarketValueStep(
        figure: snapshotValue(
            median: lowerCents,
            low: lowerCents,
            high: lowerCents,
            p10: lowerCents,
            p90: lowerCents,
            count: 3
        )
    )
}

/// The slider's geometry as a pure function (plan Amendment B, guard B6):
/// the drag mapping, the median's snap, the whole-currency rounding, the
/// VoiceOver step and the zero-width range — driven directly, because a
/// `DragGesture` is not something a unit test can send.
///
/// Each check names the mutation it dies to: remove the snap and
/// `aDragWithinTheToleranceLandsOnTheMedian` goes red; put a literal step in
/// place of `adjustableStep` and `theStepIsOnePercentOfTheRange` still holds
/// but `MarketWiringTests`' scan goes red; divide by a zero-width range and
/// `aZeroWidthRangeHasNoFractionToDivide` goes red with a NaN.
@Suite("Market value slider geometry")
struct MarketValueSliderTests {
    /// The track the frame is drawn against, and the fraction the median
    /// sits at within these bounds — a literal, so a knob that drifted to
    /// the midpoint (0.5) or an end has nowhere to hide.
    private let trackWidth: CGFloat = 300
    private let medianFraction: CGFloat = 0.3

    @Test func theMediansMarkSitsAtItsFractionOfTheBounds() {
        let x = MarketValueSlider.x(
            forCents: medianCents,
            trackWidth: trackWidth,
            lower: lowerCents,
            upper: upperCents
        )
        #expect(x == medianFraction * trackWidth)
        #expect(abs(x - 90) < 0.001, "the median's mark measured \(x) points along a 300pt track")
    }

    /// The default is the median's own place, not a midpoint: what the step
    /// hands the slider and what the median's mark stands on are one x.
    @Test func theDefaultKnobSitsOnTheMediansMark() {
        let step = boundedStep()
        let knob = MarketValueSlider.x(
            forCents: step.chosenCents,
            trackWidth: trackWidth,
            lower: step.lowerCents,
            upper: step.upperCents
        )
        let median = MarketValueSlider.x(
            forCents: step.medianCents,
            trackWidth: trackWidth,
            lower: step.lowerCents,
            upper: step.upperCents
        )
        #expect(knob == median)
        #expect(knob == medianFraction * trackWidth)
    }

    @Test func theMediansOwnPositionMapsBackToTheMedian() {
        let cents = MarketValueSlider.cents(
            atX: medianFraction * trackWidth,
            trackWidth: trackWidth,
            lower: lowerCents,
            upper: upperCents,
            median: medianCents
        )
        #expect(cents == medianCents)
    }

    /// Inside the tolerance the drag lands on the median exactly — and the
    /// control is the line beneath it: the *same* drag mapped linearly is a
    /// different amount, so a passing first check can't be the linear map
    /// happening to agree.
    @Test func aDragWithinTheToleranceLandsOnTheMedian() {
        let inside = medianFraction * trackWidth + MarketValueSlider.snapTolerance - 2
        #expect(inside == 94)
        let cents = MarketValueSlider.cents(
            atX: inside,
            trackWidth: trackWidth,
            lower: lowerCents,
            upper: upperCents,
            median: medianCents
        )
        #expect(cents == medianCents, "a drag \(inside - 90) points from the median's mark didn't snap to it")

        let unsnapped = MarketValueSlider.cents(
            atX: inside,
            trackWidth: trackWidth,
            lower: lowerCents,
            upper: upperCents,
            median: upperCents
        )
        #expect(
            unsnapped != medianCents,
            "the control failed: x = \(inside) maps to the median without any snap, so the check measures nothing"
        )
    }

    /// Just outside it, the drag is the linear map again, in whole currency.
    @Test func aDragOutsideTheToleranceTakesTheMappedAmount() {
        let outside = medianFraction * trackWidth + MarketValueSlider.snapTolerance + 1
        #expect(outside == 97)
        let cents = MarketValueSlider.cents(
            atX: outside,
            trackWidth: trackWidth,
            lower: lowerCents,
            upper: upperCents,
            median: medianCents
        )
        #expect(cents != medianCents, "a drag \(outside - 90) points from the mark still snapped to it")
        #expect(cents == 132_300, "the mapped amount is the whole-currency $1,323.00, measured \(cents)")
    }

    /// Every position the track has, in whole currency and inside the
    /// bounds — the invariant the step would clamp anyway, held here so the
    /// view can never hand it an amount it has to correct.
    @Test func everyPositionMapsToAWholeAmountInsideTheBounds() {
        for x in stride(from: CGFloat(-20), through: 320, by: 3.5) {
            let cents = MarketValueSlider.cents(
                atX: x,
                trackWidth: trackWidth,
                lower: lowerCents,
                upper: upperCents,
                median: medianCents
            )
            #expect(cents >= lowerCents && cents <= upperCents, "x = \(x) mapped outside the bounds: \(cents)")
            #expect(cents % 100 == 0, "x = \(x) mapped to \(cents), which isn't whole currency")
        }
    }

    @Test func theEndsMapToTheBounds() {
        #expect(
            MarketValueSlider.cents(atX: 0, trackWidth: trackWidth, lower: lowerCents, upper: upperCents, median: medianCents)
                == lowerCents
        )
        #expect(
            MarketValueSlider.cents(atX: trackWidth, trackWidth: trackWidth, lower: lowerCents, upper: upperCents, median: medianCents)
                == upperCents
        )
    }

    /// 1 % of the range, in whole currency.
    @Test func theStepIsOnePercentOfTheRange() {
        #expect(MarketValueSlider.adjustableStep(lower: lowerCents, upper: upperCents) == 1_000)
    }

    /// …and never less than one unit, so a $50 range still moves: 1 % of it
    /// rounds to nothing, and a control that can't be adjusted is worse than
    /// a coarse one.
    @Test func theStepNeverFallsBelowOneUnit() {
        #expect(MarketValueSlider.adjustableStep(lower: lowerCents, upper: lowerCents + 5_000) == 100)
    }

    /// The zero-width range, which is legal (plan Amendment B): no fraction
    /// to divide, one mark, and a drag that answers with the one amount
    /// rather than a NaN.
    @Test func aZeroWidthRangeHasNoFractionToDivide() {
        let x = MarketValueSlider.x(
            forCents: lowerCents,
            trackWidth: trackWidth,
            lower: lowerCents,
            upper: lowerCents
        )
        #expect(x.isFinite, "a zero-width range divided by nothing: x = \(x)")
        #expect(x == 0)
    }

    @Test func aDragIsInertOnAZeroWidthRange() {
        var step = zeroWidthStep()
        for x in stride(from: CGFloat(0), through: 300, by: 25) {
            let cents = MarketValueSlider.cents(
                atX: x,
                trackWidth: trackWidth,
                lower: step.lowerCents,
                upper: step.upperCents,
                median: step.medianCents
            )
            #expect(cents == lowerCents, "a drag to x = \(x) moved a zero-width range to \(cents)")
            step.setChosen(cents)
        }
        #expect(step.chosenCents == lowerCents)
    }

    @Test func theTrackCarriesThreeMarksAndAZeroWidthRangeOne() {
        let three = MarketValueSlider.marks(
            trackWidth: trackWidth,
            lower: lowerCents,
            upper: upperCents,
            median: medianCents
        )
        #expect(three.count == 3)
        #expect(three.filter(\.isMedian).count == 1, "one of the three is the median's taller mark")
        #expect(three[1].x == medianFraction * trackWidth)

        let one = MarketValueSlider.marks(
            trackWidth: trackWidth,
            lower: lowerCents,
            upper: lowerCents,
            median: lowerCents
        )
        #expect(one.count == 1, "a zero-width range draws \(one.count) marks — its three coincide")
        #expect(one[0].isMedian, "the one mark is the median's, which is what the amount under it says")
    }
}

/// The slider in pixels (guard B6) — the half no source scan can see: a fill
/// that stopped at the midpoint, or was swapped to the dimmer brass, leaves
/// every scan green and every artboard wrong. The `TrendArrowRenderTests`
/// instrument: render, sample, measure.
@Suite("Market value slider render")
struct MarketValueSliderRenderTests {
    private let colors = ThemeColors.dark
    /// The rendered ink is the token at full strength, so the tolerance only
    /// covers 8-bit rounding — `TrendArrowRenderTests`' reasoning.
    private let tolerance = 0.02
    private let trackWidth: CGFloat = 300
    private let medianFraction: CGFloat = 0.3

    /// The fill runs from the left end to the knob, and the knob stands on
    /// the median's fraction of the bounds — 30 % of the track, from the
    /// literal, not from the midpoint the bounds would suggest.
    @Test func theBrassFillReachesTheMediansFractionOfTheTrack() throws {
        let bitmap = try render(boundedStep())
        let runs = brassRuns(in: bitmap, row: Int(MarketValueSlider.trackTop))
        try #require(
            runs.count >= 2,
            "the track's centre row has \(runs.count) runs of brass — the fill, and the knob across its ring"
        )

        // The fill starts at the very left end (within the track's own 1pt
        // corner radius, which antialiases the first column), and the last
        // run is the knob's disc: the fill's own end, ringed in background.
        #expect(runs[0].lowerBound <= 1, "the fill doesn't start at the track's left end: \(runs[0])")

        let disc = runs[runs.count - 1]
        let knobCentre = CGFloat(disc.lowerBound + disc.upperBound + 1) / 2
        #expect(
            abs(knobCentre - medianFraction * trackWidth) <= 1,
            "the fill reaches \(knobCentre / trackWidth) of the track, not \(medianFraction)"
        )

        // …and stops there: past the knob the track is the divider again.
        let beyond = try #require(bitmap.pixel(at: CGPoint(x: medianFraction * trackWidth + 40, y: MarketValueSlider.trackTop)))
        #expect(
            Perceptual.distance(beyond, colors.accentBrass) > tolerance,
            "the fill runs past the knob — measured \(beyond) 40 points beyond it"
        )
        #expect(Perceptual.distance(beyond, colors.divider) < tolerance, "the unfilled track is the divider — measured \(beyond)")
    }

    /// The fill's own ink, sampled well clear of the knob and its shadow.
    @Test func theFillIsDrawnInTheBrassTheDesignGivesIt() throws {
        let bitmap = try render(boundedStep())
        let ink = try #require(
            bitmap.pixel(at: CGPoint(x: trackWidth * 0.1, y: MarketValueSlider.trackTop)),
            "nothing was drawn where the fill should be"
        )
        #expect(
            Perceptual.distance(ink, colors.accentBrass) < tolerance,
            "the fill is not accentBrass — measured \(ink), ΔE \(Perceptual.distance(ink, colors.accentBrass))"
        )
        // The mutation this is really watching for: the fill swapped for the
        // dimmer brass the median's mark wears, which no scan would notice.
        #expect(
            Perceptual.distance(ink, colors.accentBrass) < Perceptual.distance(ink, colors.accentBrassDim),
            "the fill read closer to accentBrassDim than to accentBrass — measured \(ink)"
        )
    }

    /// A zero-width range draws, draws one mark, and moves nothing.
    @Test func aZeroWidthRangeDrawsOneMarkAndNoNaN() throws {
        var step = zeroWidthStep()
        let bitmap = try render(step)

        var inked = 0
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width {
                guard let pixel = bitmap.pixel(at: CGPoint(x: x, y: y)) else { continue }
                if pixel != RGB8(red: 0, green: 0, blue: 0) { inked += 1 }
            }
        }
        #expect(inked > 0, "a zero-width range drew nothing at all")

        // The knob still draws, at the one end its one amount stands on: a
        // NaN fraction would leave the track and its mark behind and simply
        // drop the knob, which is a rendering the ink count alone can't tell
        // from a correct one.
        let brass = brassRuns(in: bitmap, row: Int(MarketValueSlider.trackTop))
        #expect(!brass.isEmpty, "the knob drew nothing — a NaN reached the layout")
        #expect(brass.first?.lowerBound == 0, "the knob isn't at the end its amount stands on: \(brass)")

        #expect(
            MarketValueSlider.marks(
                trackWidth: trackWidth,
                lower: step.lowerCents,
                upper: step.upperCents,
                median: step.medianCents
            ).count == 1
        )

        step.setChosen(
            MarketValueSlider.cents(
                atX: trackWidth * 0.8,
                trackWidth: trackWidth,
                lower: step.lowerCents,
                upper: step.upperCents,
                median: step.medianCents
            )
        )
        #expect(step.chosenCents == 100_000, "a drag moved a zero-width range to \(step.chosenCents)")
    }

    // MARK: - Helpers

    /// The slider at the frame's own width, as pixels. Both dimensions are
    /// required, so a layout surprise fails here rather than quietly moving
    /// every row the measurements read.
    private func render(_ step: MarketValueStep) throws -> Bitmap {
        let view = MarketValueSlider(step: step, isWanted: false, onChange: { _ in })
            .frame(width: trackWidth)
        let image = try #require(renderBitmap(view), "ImageRenderer produced nothing to sample.")
        let bitmap = try #require(Bitmap(image), "Couldn't read the rendered pixels.")
        try #require(bitmap.width == Int(trackWidth), "rendered \(bitmap.width) points wide, not \(Int(trackWidth))")
        try #require(
            bitmap.height == Int(MarketValueSlider.height),
            "rendered \(bitmap.height) points tall, not \(Int(MarketValueSlider.height))"
        )
        return bitmap
    }

    /// The maximal runs of brass along one row, left to right. The knob's
    /// ring is drawn in the background colour over the fill's last few
    /// points, so a filled track reads as two runs: the fill, then the
    /// knob's own disc.
    private func brassRuns(in bitmap: Bitmap, row: Int) -> [ClosedRange<Int>] {
        var runs: [ClosedRange<Int>] = []
        var start: Int?
        for x in 0..<bitmap.width {
            let isBrass = bitmap.pixel(at: CGPoint(x: x, y: row))
                .map { Perceptual.distance($0, colors.accentBrass) < tolerance } ?? false
            if isBrass, start == nil { start = x }
            if !isBrass, let began = start {
                runs.append(began...(x - 1))
                start = nil
            }
        }
        if let began = start { runs.append(began...(bitmap.width - 1)) }
        return runs
    }
}

import Foundation
import Testing
@testable import Trove

/// A figure row as the value step reads it, built the way `MarketIndexTests`
/// builds one: a real record, its fields set, read back as a value.
private func snapshotValue(
    median: Int?, low: Int?, high: Int?, p10: Int?, p90: Int?, count: Int = 12
) -> MarketSnapshotValue {
    let record = MarketFigureRecord(subjectID: UUID(), subjectKind: .owned, productID: 126_161, fetchedAt: Date(timeIntervalSince1970: 1_800_000_000))
    record.medianCents = median
    record.lowCents = low
    record.highCents = high
    record.p10Cents = p10
    record.p90Cents = p90
    record.count = count
    return MarketSnapshotValue(record: record)
}

/// B4 (plan Amendment B): the one place the slider's ends fall back from
/// the trimmed bounds to the true spread — for a row written before
/// Amendment B, which has no percentiles.
@Suite("Market value bounds")
struct MarketValueBoundsTests {
    @Test func thePercentilesAreTheBoundsWhenTheRowHasThem() {
        let bounds = MarketValueBounds.bounds(for: snapshotValue(median: 139_999, low: 115_249, high: 325_001, p10: 120_050, p90: 300_049))
        #expect(bounds.lowerCents == 120_050)
        #expect(bounds.upperCents == 300_049)
    }

    @Test func aRowWithoutPercentilesFallsBackToTheLowAndTheHigh() {
        let bounds = MarketValueBounds.bounds(for: snapshotValue(median: 139_999, low: 115_249, high: 325_001, p10: nil, p90: nil))
        #expect(bounds.lowerCents == 115_249)
        #expect(bounds.upperCents == 325_001)
    }

    /// The fallback is one decision over the pair, not two per field: a
    /// half-populated row — a shape no writer produces — takes the true
    /// spread whole rather than mixing a trimmed end with a raw one.
    @Test func aHalfPopulatedPairFallsBackToTheLowAndTheHighTogether() {
        let lowerOnly = MarketValueBounds.bounds(for: snapshotValue(median: 139_999, low: 115_249, high: 325_001, p10: 120_050, p90: nil))
        #expect(lowerOnly.lowerCents == 115_249, "not the trimmed lower against a raw upper")
        #expect(lowerOnly.upperCents == 325_001)

        let upperOnly = MarketValueBounds.bounds(for: snapshotValue(median: 139_999, low: 115_249, high: 325_001, p10: nil, p90: 300_049))
        #expect(upperOnly.lowerCents == 115_249)
        #expect(upperOnly.upperCents == 325_001, "nor a raw lower against a trimmed upper")
    }
}

/// The value the adopt sheet's slider binds to (plan Amendment B): whole
/// currency once, at construction and on every move, and the bounds it can
/// never leave.
@Suite("Market value step")
struct MarketValueStepTests {
    private let figure = snapshotValue(median: 139_999, low: 115_249, high: 325_001, p10: 120_050, p90: 300_049, count: 34)

    /// Criterion 8: the whole-currency median by default. The record keeps
    /// raw cents — the oracle's excellent median is `139_999` — and every
    /// number the slider works in is rounded the way the display rounds
    /// (`MarketAdoption.wholeCurrencyCents`, half to even).
    @Test func theStepIsWholeCurrencyFromANonWholeMedian() {
        let step = MarketValueStep(figure: figure)

        #expect(step.chosenCents == 140_000)
        #expect(step.lowerCents == 120_000, "1200.50 rounds half to even")
        #expect(step.upperCents == 300_000, "3000.49 rounds down")
        #expect(step.medianCents == 139_999, "the figure's own numbers are untouched")
        #expect(step.lowCents == 115_249)
        #expect(step.highCents == 325_001)
        #expect(step.count == 34)
    }

    @Test func theChosenAmountIsClampedAndRounded() {
        var step = MarketValueStep(figure: figure)

        step.setChosen(123_456)
        #expect(step.chosenCents == 123_500, "1234.56 rounds up to a whole 1235")

        step.setChosen(150_049)
        #expect(step.chosenCents == 150_000, "1500.49 rounds down, strictly inside the bounds")

        step.setChosen(999_999)
        #expect(step.chosenCents == 300_000, "above the upper bound clamps to it")

        step.setChosen(1)
        #expect(step.chosenCents == 120_000, "below the lower bound clamps to it")
    }

    /// Three identical asking prices: the range has no width, the amount is
    /// fixed, and every move returns to it (the slider draws one mark and
    /// the drag is inert — T023).
    @Test func aZeroWidthRangeIsFixed() {
        var step = MarketValueStep(figure: snapshotValue(median: 150_000, low: 150_000, high: 150_000, p10: 150_000, p90: 150_000, count: 3))

        #expect(step.lowerCents == step.upperCents)
        #expect(step.chosenCents == 150_000)

        step.setChosen(999_999)
        #expect(step.chosenCents == 150_000)
        step.setChosen(1)
        #expect(step.chosenCents == 150_000)
    }

    /// The fallback reaching the step: a row written before Amendment B
    /// slides across its true spread, in whole currency.
    @Test func aRowWithoutPercentilesSlidesAcrossTheTrueSpread() {
        let step = MarketValueStep(figure: snapshotValue(median: 139_999, low: 115_249, high: 325_001, p10: nil, p90: nil))

        #expect(step.lowerCents == 115_200, "1152.49 rounds down")
        #expect(step.upperCents == 325_000)
        #expect(step.chosenCents == 140_000)
    }
}

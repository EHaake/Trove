import Foundation

/// The range the value slider runs between (spec Decision 36, plan
/// Amendment B): the figure's trimmed bounds when the row has them, its
/// low and high when it doesn't. **The one place that fallback lives** — a
/// row written before Amendment B has no percentiles, and no shipped
/// device has such a row, but the slider must still have two ends.
///
/// The fallback is one decision over the *pair*, not two per field: the
/// percentiles are written together, and a half-populated row is a shape no
/// writer produces — so if it ever appeared, taking a trimmed lower against
/// a raw upper would silently mix two ranges. Either both percentiles are
/// there and both are used, or neither is and the true spread is used
/// whole. Only the low and the high keep a `?? 0`, and the step's own
/// preconditions guard those.
///
/// A withheld figure has neither pair and never reaches here: the value
/// step is only opened over a `.current` reading (plan Amendment B, the
/// landing rule).
nonisolated enum MarketValueBounds {
    static func bounds(for figure: MarketSnapshotValue) -> (lowerCents: Int, upperCents: Int) {
        if let p10 = figure.p10Cents, let p90 = figure.p90Cents { return (p10, p90) }
        return (figure.lowCents ?? 0, figure.highCents ?? 0)
    }
}

/// What the adopt sheet's value step is showing and what the person has
/// chosen (plan Amendment B): the figure as the section draws it, the
/// trimmed bounds the slider runs between, and the amount the button will
/// write.
///
/// Whole currency lives here, once: both bounds and every chosen amount go
/// through `MarketAdoption.wholeCurrencyCents(from:)`, so the slider starts
/// on a whole amount, moves in whole steps, and no view path can hand
/// `adopt(cents:)` unrounded cents. The record keeps raw cents — the
/// oracle's excellent median is `139_999`; this step's default is
/// `140_000`.
///
/// A zero-width range (`lowerCents == upperCents`, three identical asking
/// prices) is legal: `chosenCents` is fixed there and `setChosen` returns
/// to it.
nonisolated struct MarketValueStep: Equatable, Sendable {
    let medianCents: Int
    /// The figure's true spread — shown beside the slider, not its ends.
    let lowCents: Int
    let highCents: Int
    let count: Int
    /// The slider's ends: the trimmed bounds, in whole currency.
    let lowerCents: Int
    let upperCents: Int
    private(set) var chosenCents: Int

    /// **The caller's obligation** (plan Amendment B, the landing rule): the
    /// value step is only ever opened over a `.current` reading, which
    /// always carries a median and a pair of ends. A withheld or partial row
    /// is a programmer error reaching here, and the preconditions below trap
    /// on it rather than default it into a plausible "$0" step — the median
    /// and the true spread are each required, because `MarketLocalStore`
    /// writes the trio together and a row missing either end would otherwise
    /// slide between `(0, 0)`. The percentiles are *not* required: a row
    /// written before Amendment B legitimately has none, and
    /// `MarketValueBounds` falls back to the ends for it.
    init(figure: MarketSnapshotValue) {
        precondition(figure.medianCents != nil, "the value step is only opened over a current reading")
        precondition(
            figure.lowCents != nil && figure.highCents != nil,
            "a current reading carries a low and a high"
        )
        let median = figure.medianCents ?? 0
        let bounds = MarketValueBounds.bounds(for: figure)
        let lower = MarketAdoption.wholeCurrencyCents(from: bounds.lowerCents)
        let upper = MarketAdoption.wholeCurrencyCents(from: bounds.upperCents)
        precondition(lower <= upper, "the slider's ends are out of order")

        medianCents = median
        lowCents = figure.lowCents ?? 0
        highCents = figure.highCents ?? 0
        count = figure.count
        lowerCents = lower
        upperCents = upper
        chosenCents = 0
        // Through the same rounding and clamping every later move takes, so
        // the default can't be a shape the slider could never produce.
        setChosen(median)
    }

    /// Rounded to whole currency, then clamped to the bounds — the
    /// invariant in one place.
    mutating func setChosen(_ cents: Int) {
        let whole = MarketAdoption.wholeCurrencyCents(from: cents)
        chosenCents = min(max(whole, lowerCents), upperCents)
    }
}

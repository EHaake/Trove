import Foundation

/// One history point as a value — the mirror of `MarketHistoryPoint` the
/// pure functions read.
nonisolated struct MarketHistoryEntry: Sendable, Equatable {
    let fetchedAt: Date
    let medianCents: Int
    let lowCents: Int
    let highCents: Int
    let count: Int
}

/// The trend the rows draw (spec P12): the latest median against the most
/// recent point at least seven days older — up at +5 % or more, down at
/// −5 % or less, flat between, and flat draws nothing. `nil` is no trend
/// yet.
///
/// "Previous" is the most recent qualifying point, not the immediately
/// preceding one: the rejected reading would blank the arrow for anyone
/// who refreshes twice in a week (plan Q6). No maximum age on it either —
/// a trend against a months-old point is the trend since then.
nonisolated enum MarketTrend: String, Sendable, CaseIterable {
    case up
    case down
    case flat

    /// The two readings a trend is drawn from, kept together (003 plan Q3):
    /// the latest median, the median and date of the point it was compared
    /// against, and the classification. The Sell Plan's reason line dates
    /// itself by `previousAt`, so the date and the figure it belongs to must
    /// come from the *same* point — carrying them as one value is what makes
    /// that true by construction rather than by two matching lookups.
    struct Comparison: Sendable, Equatable {
        let latestCents: Int
        let previousCents: Int
        let previousAt: Date
        let trend: MarketTrend

        /// (latest − previous) × 100 / previous, signed.
        ///
        /// The numerator is multiplied in exact integers **before** the one
        /// division, so a true half is representable and rounds half away
        /// from zero: 1000 → 1145 is 14500/1000 = 14.5 → 15, where dividing
        /// first gives 0.145 × 100 = 14.499… → 14.
        var percent: Int {
            let delta = latestCents - previousCents
            return Int((Double(delta * 100) / Double(previousCents)).rounded())
        }
    }

    static let minimumGap: TimeInterval = 7 * 24 * 60 * 60

    /// The latest reading against the most recent point at least seven days
    /// older — the whole of the trend derivation, so `compute` and anything
    /// that needs the numbers behind the arrow read one selection.
    static func comparison(history: [MarketHistoryEntry]) -> Comparison? {
        let sorted = history.sorted { $0.fetchedAt < $1.fetchedAt }
        guard let latest = sorted.last else { return nil }
        guard let previous = sorted.dropLast().last(where: {
            latest.fetchedAt.timeIntervalSince($0.fetchedAt) >= minimumGap
        }) else { return nil }
        guard previous.medianCents > 0 else { return nil }

        // Integer arithmetic so the 5 % boundary is exact.
        let delta = latest.medianCents - previous.medianCents
        let trend: MarketTrend
        if 20 * delta >= previous.medianCents {
            trend = .up
        } else if 20 * -delta >= previous.medianCents {
            trend = .down
        } else {
            trend = .flat
        }
        return Comparison(
            latestCents: latest.medianCents,
            previousCents: previous.medianCents,
            previousAt: previous.fetchedAt,
            trend: trend
        )
    }

    static func compute(history: [MarketHistoryEntry]) -> MarketTrend? {
        comparison(history: history)?.trend
    }
}

/// What the Sell Plan's reason line says (003 plan Q3): a rise, and only a
/// rise. The initialiser is failable on the trend rather than on the sign of
/// the percentage, so a flat item whose percentage rounds to 5 % can never
/// produce a sentence saying it is up — the bands decide, the rounding only
/// draws.
nonisolated struct MarketRise: Sendable, Equatable {
    let percent: Int
    /// The earlier reading's date — the "since" of the sentence.
    let since: Date

    init?(comparison: MarketTrend.Comparison) {
        guard comparison.trend == .up else { return nil }
        percent = comparison.percent
        since = comparison.previousAt
    }
}

/// Whether a figure still shows as current (spec P13, Decision 21): thirty
/// days from its fetch. Display-time only — nothing is deleted by age, and
/// the history is never trimmed (Decision 16). `currentMedianCents` is the
/// one predicate the section, the sort and the dashboard all read, so the
/// three agree by construction.
nonisolated enum MarketFreshness {
    static let currentWindow: TimeInterval = 30 * 24 * 60 * 60

    static func isCurrent(fetchedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) < currentWindow
    }

    /// The median a surface may use: nil when withheld or no longer current.
    static func currentMedianCents(medianCents: Int?, fetchedAt: Date, now: Date) -> Int? {
        guard let medianCents, isCurrent(fetchedAt: fetchedAt, now: now) else { return nil }
        return medianCents
    }
}

/// "Use as my value" (spec P6, plan Q15): the median rounded to whole
/// currency **the way the display formatter rounds** — half to even — so
/// the number written is the number the section showed.
nonisolated enum MarketAdoption {
    static func wholeCurrencyCents(from medianCents: Int) -> Int {
        var units = Decimal(medianCents) / 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &units, 0, .bankers)
        return NSDecimalNumber(decimal: rounded * 100).intValue
    }
}

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

    static let minimumGap: TimeInterval = 7 * 24 * 60 * 60

    static func compute(history: [MarketHistoryEntry]) -> MarketTrend? {
        let sorted = history.sorted { $0.fetchedAt < $1.fetchedAt }
        guard let latest = sorted.last else { return nil }
        guard let previous = sorted.dropLast().last(where: {
            latest.fetchedAt.timeIntervalSince($0.fetchedAt) >= minimumGap
        }) else { return nil }
        guard previous.medianCents > 0 else { return nil }

        // Integer arithmetic so the 5 % boundary is exact.
        let delta = latest.medianCents - previous.medianCents
        if 20 * delta >= previous.medianCents { return .up }
        if 20 * -delta >= previous.medianCents { return .down }
        return .flat
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

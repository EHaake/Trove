import Foundation

/// Whose figure is being computed: an owned item brings its condition, a
/// wanted item has none and reads all used listings (spec P2, P16).
nonisolated enum MarketSubject: Sendable, Equatable {
    case owned(condition: Condition)
    case wanted
}

/// Trove's five conditions against Reverb's condition slugs (spec P2,
/// plan Q1), verified against the recorded fixtures — every slug seen on
/// the Telecaster's 337 listings is in `knownSlugs`, and
/// `MarketFigureComputationTests` keeps it that way.
///
/// `b-stock` sits with new stock: unused dealer inventory with cosmetic
/// flaws, priced with mint on the oracle product. "Used", for a wanted
/// item, is everything that is *not* new stock — failure-open, so a slug
/// Reverb adds later never silently shrinks a wanted item's count.
nonisolated enum MarketConditionMap {
    static let newStockSlugs: Set<String> = ["brand-new", "b-stock"]

    static let knownSlugs: Set<String> = [
        "brand-new", "b-stock", "mint", "mint-inventory", "excellent",
        "very-good", "good", "fair", "poor", "non-functioning",
    ]

    static func reverbSlugs(for condition: Condition) -> Set<String> {
        switch condition {
        case .new: ["brand-new", "b-stock", "mint", "mint-inventory"]
        case .excellent: ["excellent"]
        case .good: ["very-good", "good"]
        case .fair: ["fair"]
        case .broken: ["poor", "non-functioning"]
        }
    }

    static func counts(_ slug: String, for subject: MarketSubject) -> Bool {
        switch subject {
        case .owned(let condition): reverbSlugs(for: condition).contains(slug)
        case .wanted: !newStockSlugs.contains(slug)
        }
    }
}

/// Whether a listing's free-text year covers an item's year (spec P19).
/// Reverb writes a single year, a range ("1970 - 1984"), an open range
/// ("2020 - Present") or a decade ("2020s") — and, as the fixtures show,
/// sometimes nothing, "0", "2003-04" or "LATE 2000’s". Nothing stated
/// counts; anything that can't be read is a mismatch.
nonisolated enum MarketYearCoverage {
    enum Coverage: Equatable {
        case unstated
        case covers
        case mismatch
    }

    static func coverage(of stated: String?, for year: Int, now: Date) -> Coverage {
        guard let stated else { return .unstated }
        let text = stated.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.isEmpty { return .unstated }

        if let single = fourDigits(text) {
            return single == year ? .covers : .mismatch
        }
        if text.hasSuffix("s"), let decade = fourDigits(String(text.dropLast())) {
            return (year / 10) * 10 == decade ? .covers : .mismatch
        }
        let parts = text.split(separator: "-", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2, let from = fourDigits(parts[0]) {
            if parts[1] == "present" {
                let thisYear = Calendar(identifier: .gregorian).component(.year, from: now)
                return (from...max(from, thisYear)).contains(year) ? .covers : .mismatch
            }
            if let to = fourDigits(parts[1]), from <= to {
                return (from...to).contains(year) ? .covers : .mismatch
            }
        }
        return .mismatch
    }

    private static func fourDigits(_ text: String) -> Int? {
        guard text.count == 4, text.allSatisfy(\.isNumber) else { return nil }
        return Int(text)
    }
}

/// Which years a figure was computed over (spec Decision 29, P20).
nonisolated enum YearScope: Sendable, Equatable {
    /// The item has no year.
    case any
    /// Narrowed to the item's year.
    case year(Int)
    /// Narrowing left fewer than three, so every year counted — and the
    /// section says so.
    case allYears(fallbackFrom: Int)
}

/// A computed figure: the median asking price with its spread and count
/// (spec Decision 6).
nonisolated struct MarketFigure: Sendable, Equatable {
    let medianCents: Int
    let lowCents: Int
    let highCents: Int
    /// The trimmed bounds the value slider runs between (spec Decision 36,
    /// Amendment B): the 10th and 90th percentiles of the same counted
    /// prices, so one mispriced or bundled listing can't stretch the range
    /// the person drags across. The nearest rank puts these on the ends of a
    /// small count, at a different size for each: `p10Cents == lowCents` for
    /// n ≤ 10, `p90Cents == highCents` for n ≤ 9 only — at ten the 90th's
    /// rank is `⌈0.9·10⌉ = 9`, the ninth of the ten. So both coincide with
    /// the ends up to nine listings, and the low end alone at ten.
    let p10Cents: Int
    let p90Cents: Int
    let count: Int
    let fetchedAt: Date
    let isTruncated: Bool
    let yearScope: YearScope
}

/// What one refresh produced.
nonisolated enum MarketReading: Sendable, Equatable {
    case figure(MarketFigure)
    /// Fewer than three listings counted: the section offers the catalog's
    /// lowest used asking price instead (spec Decision 6).
    case withheld(count: Int, usedLowCents: Int?, fetchedAt: Date, yearScope: YearScope)
}

/// The figure, as a pure function of the listings (plan §4, Amendment A):
/// currency first, then condition, then — when the item has a year — the
/// year; a median over what survives, withheld under three.
nonisolated enum MarketFigureComputation {
    static let currency = "USD"
    static let minimumCount = 3

    static func compute(
        listings: MarketListings,
        subject: MarketSubject,
        year: Int?,
        product: MarketProduct,
        fetchedAt: Date,
        now: Date
    ) -> MarketReading {
        let eligible = listings.listings.filter {
            $0.currency == currency && MarketConditionMap.counts($0.conditionSlug, for: subject)
        }

        let counted: [MarketListing]
        let scope: YearScope
        if let year {
            let narrowed = eligible.filter {
                MarketYearCoverage.coverage(of: $0.year, for: year, now: now) != .mismatch
            }
            if narrowed.count >= minimumCount {
                counted = narrowed
                scope = .year(year)
            } else {
                counted = eligible
                scope = .allYears(fallbackFrom: year)
            }
        } else {
            counted = eligible
            scope = .any
        }

        guard counted.count >= minimumCount else {
            return .withheld(count: counted.count, usedLowCents: product.usedLowCents, fetchedAt: fetchedAt, yearScope: scope)
        }
        let cents = counted.map(\.priceCents).sorted()
        return .figure(MarketFigure(
            medianCents: median(sortedCents: cents),
            lowCents: cents[0],
            highCents: cents[cents.count - 1],
            p10Cents: percentile(10, sortedCents: cents),
            p90Cents: percentile(90, sortedCents: cents),
            count: cents.count,
            fetchedAt: fetchedAt,
            isTruncated: listings.isTruncated,
            yearScope: scope
        ))
    }

    /// The middle value; for an even count the mean of the two middles,
    /// rounded half up in cents.
    static func median(sortedCents cents: [Int]) -> Int {
        precondition(!cents.isEmpty)
        let n = cents.count
        if n % 2 == 1 { return cents[n / 2] }
        return (cents[n / 2 - 1] + cents[n / 2] + 1) / 2
    }

    /// The nearest-rank percentile (spec Decision 36): the `⌈P/100 · n⌉`-th
    /// smallest, 1-based — never an interpolation, so every bound is a price
    /// someone is actually asking. Integer arithmetic so the rank is exact,
    /// the way `MarketTrend`'s 5 % boundary is.
    static func percentile(_ p: Int, sortedCents cents: [Int]) -> Int {
        precondition(!cents.isEmpty)
        let rank = (p * cents.count + 99) / 100
        return cents[min(max(rank, 1), cents.count) - 1]
    }
}

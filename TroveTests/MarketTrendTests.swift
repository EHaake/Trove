import Foundation
import Testing
@testable import Trove

/// Spec P12's trend at its boundaries, P13's freshness at its, and P6's
/// adoption against the display formatter (plan §4, Q6, Q15).
@Suite("Market trend, freshness, adoption")
struct MarketTrendTests {
    private let day: TimeInterval = 24 * 60 * 60
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func point(daysAgo: Double, median: Int) -> MarketHistoryEntry {
        MarketHistoryEntry(fetchedAt: base.addingTimeInterval(-daysAgo * day), medianCents: median, lowCents: median, highCents: median, count: 5)
    }

    // MARK: - Trend

    @Test func sevenDaysExactlyIsATrendAndASecondLessIsNot() {
        #expect(MarketTrend.compute(history: [point(daysAgo: 7, median: 1000), point(daysAgo: 0, median: 1100)]) == .up)
        let justUnder = MarketHistoryEntry(fetchedAt: base.addingTimeInterval(-7 * day + 1), medianCents: 1000, lowCents: 1000, highCents: 1000, count: 5)
        #expect(MarketTrend.compute(history: [justUnder, point(daysAgo: 0, median: 1100)]) == nil)
    }

    @Test(arguments: [(1050, MarketTrend.up), (1049, .flat), (950, .down), (951, .flat), (1000, .flat)])
    func fivePercentIsTheBoundaryOnBothSides(latest: Int, expected: MarketTrend) {
        #expect(MarketTrend.compute(history: [point(daysAgo: 10, median: 1000), point(daysAgo: 0, median: latest)]) == expected)
    }

    /// Q6: the most recent qualifying point, not the oldest.
    @Test func theMostRecentPointAtLeastAWeekOldIsThePrevious() {
        let history = [point(daysAgo: 20, median: 500), point(daysAgo: 8, median: 1000), point(daysAgo: 1, median: 1040)]
        // Against the 8-day point (1000 → 1040) it's flat; against the
        // 20-day point (500 → 1040) it would be up.
        #expect(MarketTrend.compute(history: history) == .flat)
    }

    @Test func orderInTheArrayDoesNotMatter() {
        #expect(MarketTrend.compute(history: [point(daysAgo: 0, median: 1100), point(daysAgo: 7, median: 1000)]) == .up)
    }

    @Test func onePointOrTwoTooCloseIsNoTrend() {
        #expect(MarketTrend.compute(history: []) == nil)
        #expect(MarketTrend.compute(history: [point(daysAgo: 0, median: 1000)]) == nil)
        #expect(MarketTrend.compute(history: [point(daysAgo: 3, median: 1000), point(daysAgo: 0, median: 2000)]) == nil)
    }

    @Test func aZeroPreviousMedianIsNoTrend() {
        #expect(MarketTrend.compute(history: [point(daysAgo: 10, median: 0), point(daysAgo: 0, median: 100)]) == nil)
    }

    // MARK: - Comparison and rise (003 §1)

    /// The whole comparison, pinned: both numbers and the date come from the
    /// *same* previous point — the most recent qualifying one, not the oldest.
    @Test func theComparisonCarriesBothFiguresAndTheDateOfOnePoint() throws {
        let history = [point(daysAgo: 20, median: 500), point(daysAgo: 8, median: 1000), point(daysAgo: 1, median: 1040)]
        let comparison = try #require(MarketTrend.comparison(history: history))
        #expect(comparison == MarketTrend.Comparison(
            latestCents: 1040,
            previousCents: 1000,
            previousAt: base.addingTimeInterval(-8 * day),
            trend: .flat
        ))
    }

    /// The numerator is exact before the one division, and the result rounds
    /// half away from zero. 1000 → 1145 is the row that discriminates:
    /// 14500/1000 = 14.5 → 15, where dividing first gives 0.145 × 100 =
    /// 14.499… → 14. 1000 → 1049 rounds *up* to 5 yet classifies `.flat` —
    /// the reason no sentence can be built from the percentage alone.
    @Test(arguments: [(1050, 5), (1124, 12), (1125, 13), (1145, 15), (950, -5), (850, -15), (1049, 5)])
    func thePercentIsExactBeforeTheDivisionAndRoundsHalfAwayFromZero(latest: Int, expected: Int) throws {
        let comparison = try #require(MarketTrend.comparison(history: [point(daysAgo: 10, median: 1000), point(daysAgo: 0, median: latest)]))
        #expect(comparison.percent == expected)
    }

    /// A value pin, not the guard: 4000 → 4700 is 17.5 → 18 either way the
    /// arithmetic is ordered, by IEEE luck.
    @Test func thePercentOfAHigherBase() throws {
        let comparison = try #require(MarketTrend.comparison(history: [point(daysAgo: 10, median: 4000), point(daysAgo: 0, median: 4700)]))
        #expect(comparison.percent == 18)
    }

    /// Only a rising comparison becomes a rise — `.flat` included, even where
    /// its percentage rounds to 5, so no row ever reads "up 5 %" while flat.
    @Test func onlyARisingComparisonBecomesARise() throws {
        let rising = try #require(MarketTrend.comparison(history: [point(daysAgo: 10, median: 1000), point(daysAgo: 0, median: 1120)]))
        let rise = try #require(MarketRise(comparison: rising))
        #expect(rise.percent == 12)
        #expect(rise.since == base.addingTimeInterval(-10 * day))
        #expect(rise.since == rising.previousAt)

        let flat = try #require(MarketTrend.comparison(history: [point(daysAgo: 10, median: 1000), point(daysAgo: 0, median: 1049)]))
        #expect(flat.trend == .flat)
        #expect(MarketRise(comparison: flat) == nil)

        let falling = try #require(MarketTrend.comparison(history: [point(daysAgo: 10, median: 1000), point(daysAgo: 0, median: 850)]))
        #expect(falling.trend == .down)
        #expect(MarketRise(comparison: falling) == nil)
    }

    // MARK: - Freshness

    @Test func thirtyDaysLessASecondIsCurrentAndThirtyIsNot() {
        let fetched = base
        #expect(MarketFreshness.isCurrent(fetchedAt: fetched, now: fetched.addingTimeInterval(30 * day - 1)))
        #expect(!MarketFreshness.isCurrent(fetchedAt: fetched, now: fetched.addingTimeInterval(30 * day)))
    }

    /// The one predicate every surface reads (Decision 21).
    @Test func theCurrentMedianIsNilWhenWithheldOrStale() {
        #expect(MarketFreshness.currentMedianCents(medianCents: 1000, fetchedAt: base, now: base.addingTimeInterval(day)) == 1000)
        #expect(MarketFreshness.currentMedianCents(medianCents: nil, fetchedAt: base, now: base.addingTimeInterval(day)) == nil)
        #expect(MarketFreshness.currentMedianCents(medianCents: 1000, fetchedAt: base, now: base.addingTimeInterval(31 * day)) == nil)
    }

    // MARK: - Adoption

    /// Q15: the adopted value re-renders as the string the section showed —
    /// half-cases of both parities included, where half-up would diverge.
    @Test(arguments: [145_050, 145_150, 145_049, 145_151, 139_999, 100_000, 50, 150])
    func theAdoptedValueRendersAsTheDisplayedFigure(medianCents: Int) {
        let adopted = MarketAdoption.wholeCurrencyCents(from: medianCents)
        #expect(adopted % 100 == 0)
        #expect(adopted.formattedAsWholeCurrency(currencyCode: "USD") == medianCents.formattedAsWholeCurrency(currencyCode: "USD"), "\(medianCents) → \(adopted)")
    }

    @Test func adoptionRoundsHalfToEven() {
        #expect(MarketAdoption.wholeCurrencyCents(from: 145_050) == 145_000)
        #expect(MarketAdoption.wholeCurrencyCents(from: 145_150) == 145_200)
    }
}

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

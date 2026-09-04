import Foundation
import Testing
@testable import Trove

/// The figure as a pure function (plan §4, Amendment A), against the
/// recorded oracle in `TroveTests/Fixtures/Reverb/README.md` — every number
/// below is copied from there, not derived here.
@Suite("Market figure computation")
struct MarketFigureComputationTests {
    private static let fetchedAt = Date(timeIntervalSince1970: 1_800_000_000)
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func telecaster() throws -> (MarketListings, MarketProduct) {
        var all: [MarketListing] = []
        for page in 1...7 {
            all += try ReverbDecoding.page(from: try reverbFixture("listings-126161-p\(page).json")).listings
        }
        let product = try ReverbDecoding.product(from: try reverbFixture("csp-126161.json"))
        return (MarketListings(listings: all, reportedTotal: 337, isTruncated: false), product)
    }

    private func compute(_ subject: MarketSubject, year: Int? = nil, over listings: MarketListings, product: MarketProduct) -> MarketReading {
        MarketFigureComputation.compute(listings: listings, subject: subject, year: year, product: product, fetchedAt: Self.fetchedAt, now: Self.now)
    }

    private func figure(_ reading: MarketReading) throws -> MarketFigure {
        guard case .figure(let figure) = reading else { throw TestFailure("withheld: \(reading)") }
        return figure
    }

    // MARK: - The oracle

    @Test func anExcellentOwnedItemReadsTheOracle() throws {
        let (listings, product) = try telecaster()
        let figure = try figure(compute(.owned(condition: .excellent), over: listings, product: product))

        #expect(figure.count == 34)
        #expect(figure.medianCents == 139_999)
        #expect(figure.lowCents == 115_200)
        #expect(figure.highCents == 325_000)
        #expect(figure.yearScope == .any)
        #expect(!figure.isTruncated)
    }

    @Test func aGoodOwnedItemSpansVeryGoodAndGood() throws {
        let (listings, product) = try telecaster()
        let figure = try figure(compute(.owned(condition: .good), over: listings, product: product))

        #expect(figure.count == 17)
        #expect(figure.medianCents == 139_999)
        #expect(figure.lowCents == 100_000)
        #expect(figure.highCents == 170_000)
    }

    @Test func aNewOwnedItemSpansNewStockAndMint() throws {
        let (listings, product) = try telecaster()
        let figure = try figure(compute(.owned(condition: .new), over: listings, product: product))

        #expect(figure.count == 208)
        #expect(figure.medianCents == 183_999)
        #expect(figure.lowCents == 119_800)
        #expect(figure.highCents == 256_999)
    }

    @Test func aWantedItemReadsEveryUsedListingInDollars() throws {
        let (listings, product) = try telecaster()
        let figure = try figure(compute(.wanted, over: listings, product: product))

        #expect(figure.count == 72)
        #expect(figure.medianCents == 149_999)
        #expect(figure.lowCents == 100_000)
        #expect(figure.highCents == 325_000)
        // Reverb's own used count spans every currency; ours is dollars
        // only, so it is smaller. Recorded, not asserted equal.
        #expect(product.usedTotal == 108)
        #expect(figure.count < product.usedTotal)
    }

    @Test(arguments: [Condition.fair, .broken])
    func aConditionWithNoListingsIsWithheldWithTheCatalogsLowestUsedPrice(condition: Condition) throws {
        let (listings, product) = try telecaster()
        let reading = compute(.owned(condition: condition), over: listings, product: product)

        #expect(reading == .withheld(count: 0, usedLowCents: 100_000, fetchedAt: Self.fetchedAt, yearScope: .any))
    }

    @Test func everyRecordedSlugIsKnown() throws {
        let (listings, _) = try telecaster()
        let seen = Set(listings.listings.map(\.conditionSlug))
        #expect(seen.isSubset(of: MarketConditionMap.knownSlugs), "unknown: \(seen.subtracting(MarketConditionMap.knownSlugs).sorted())")
    }

    // MARK: - The rules, on synthetic sets

    private func listing(_ cents: Int, _ slug: String = "excellent", currency: String = "USD", year: String? = nil) -> MarketListing {
        MarketListing(priceCents: cents, currency: currency, conditionSlug: slug, year: year)
    }

    private var product: MarketProduct {
        MarketProduct(id: 1, slug: "x", title: "X", usedLowCents: 90_000, usedTotal: 9, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=1")!)
    }

    private func set(_ listings: [MarketListing], truncated: Bool = false) -> MarketListings {
        MarketListings(listings: listings, reportedTotal: listings.count, isTruncated: truncated)
    }

    @Test func twoListingsAreWithheldAndThreeAreAFigure() throws {
        let two = compute(.owned(condition: .excellent), over: set([listing(100), listing(200)]), product: product)
        #expect(two == .withheld(count: 2, usedLowCents: 90_000, fetchedAt: Self.fetchedAt, yearScope: .any))

        let three = try figure(compute(.owned(condition: .excellent), over: set([listing(100), listing(300), listing(200)]), product: product))
        #expect(three.medianCents == 200)
        #expect(three.count == 3)
    }

    @Test func anEvenCountTakesTheMeanOfTheMiddlesRoundedHalfUp() throws {
        let figure = try figure(compute(.owned(condition: .excellent), over: set([listing(100), listing(101), listing(104), listing(400)]), product: product))
        #expect(figure.medianCents == 103)
        #expect(MarketFigureComputation.median(sortedCents: [1, 2]) == 2)
        #expect(MarketFigureComputation.median(sortedCents: [1, 2, 3]) == 2)
    }

    /// Criterion 7: a EUR listing and a display-converted price are out,
    /// and the count says so.
    @Test func onlyDollarListingsCount() throws {
        let listings = set([listing(100), listing(110), listing(120), listing(50, currency: "EUR"), listing(60, currency: "GBP≠USD")])
        let figure = try figure(compute(.owned(condition: .excellent), over: listings, product: product))
        #expect(figure.count == 3)
        #expect(figure.lowCents == 100)
    }

    @Test func anUnknownSlugIsOutForAnOwnedItemAndInForAWantedOne() throws {
        let listings = set([listing(100), listing(110), listing(120), listing(130, "player-grade")])
        let owned = try figure(compute(.owned(condition: .excellent), over: listings, product: product))
        let wanted = try figure(compute(.wanted, over: listings, product: product))
        #expect(owned.count == 3)
        #expect(wanted.count == 4)
    }

    @Test func newStockNeverCountsForAWantedItem() throws {
        let listings = set([listing(100, "brand-new"), listing(110, "b-stock"), listing(120, "mint"), listing(130, "good"), listing(140, "fair")])
        let wanted = try figure(compute(.wanted, over: listings, product: product))
        #expect(wanted.count == 3)
        #expect(wanted.lowCents == 120)
    }

    @Test func theConditionBucketsAreDisjointAndNonEmpty() {
        var seen: Set<String> = []
        for condition in Condition.allCases {
            let slugs = MarketConditionMap.reverbSlugs(for: condition)
            #expect(!slugs.isEmpty, "\(condition) maps to nothing")
            #expect(seen.isDisjoint(with: slugs), "\(condition) shares a slug with an earlier bucket")
            seen.formUnion(slugs)
        }
        #expect(seen == MarketConditionMap.knownSlugs, "a known slug belongs to no owned condition, or a bucket names an unknown one")
    }

    @Test func truncationIsCarriedOntoTheFigure() throws {
        let figure = try figure(compute(.owned(condition: .excellent), over: set([listing(1), listing(2), listing(3)], truncated: true), product: product))
        #expect(figure.isTruncated)
    }

    // MARK: - Year narrowing (Decision 29)

    /// A D-18-shaped set: the catalog's own range on twelve listings,
    /// singles, and two that state nothing.
    private var vintage: MarketListings {
        var listings: [MarketListing] = []
        for i in 0..<12 { listings.append(listing(150_000 + i, "excellent", year: "1970 - 1984")) }
        for i in 0..<6 { listings.append(listing(140_000 + i, "excellent", year: "1973")) }
        for i in 0..<3 { listings.append(listing(160_000 + i, "excellent", year: "1975")) }
        listings.append(listing(100_000, "excellent", year: nil))
        listings.append(listing(101_000, "excellent", year: ""))
        return set(listings)
    }

    @Test func aYearKeepsTheRangeTheSinglesThatMatchAndTheUnstated() throws {
        let figure = try figure(compute(.owned(condition: .excellent), year: 1975, over: vintage, product: product))
        // 12 in range + 3 singles of 1975 + 2 unstated; the six 1973s are out.
        #expect(figure.count == 17)
        #expect(figure.yearScope == .year(1975))
        #expect(figure.lowCents == 100_000, "an unstated year still counts")
    }

    @Test func aYearWithTooFewSurvivorsFallsBackToAllYearsAndSaysSo() throws {
        let figure = try figure(compute(.owned(condition: .excellent), year: 1999, over: vintage, product: product))
        // Only the two unstated cover 1999; under three, so every year counts.
        #expect(figure.count == 23)
        #expect(figure.yearScope == .allYears(fallbackFrom: 1999))
    }

    @Test func noYearLeavesTheOracleUntouched() throws {
        let (listings, product) = try telecaster()
        let plain = try figure(compute(.owned(condition: .excellent), over: listings, product: product))
        #expect(plain.count == 34)
        #expect(plain.yearScope == .any)
    }

    /// Against the recording, with the expected count derived from the raw
    /// fixture years by an independent rule — the strings seen to cover
    /// 2021 on the Telecaster — not by calling the parser under test.
    @Test func theTelecasterNarrowedTo2021DropsOnlyStatedMismatches() throws {
        let (listings, product) = try telecaster()
        let covering: Set<String> = ["2021", "2020 - Present", "2020s", "2020 - 2023"]
        let expected = listings.listings.filter {
            $0.currency == "USD" && $0.conditionSlug == "excellent" && ($0.year == nil || covering.contains($0.year!))
        }.count
        try #require(expected >= 3)

        let figure = try figure(compute(.owned(condition: .excellent), year: 2021, over: listings, product: product))
        #expect(figure.count == expected)
        #expect(figure.count < 34)
        #expect(figure.yearScope == .year(2021))
    }

    @Test func aWithheldReadingCarriesTheYearScopeItEndedOn() {
        let reading = compute(.owned(condition: .excellent), year: 1975, over: set([listing(1, year: "1975"), listing(2, year: "1960")]), product: product)
        #expect(reading == .withheld(count: 2, usedLowCents: 90_000, fetchedAt: Self.fetchedAt, yearScope: .allYears(fallbackFrom: 1975)))
    }
}

/// Spec P19's parser, one row per shape Reverb writes — and the three
/// unreadable shapes the recording turned up.
@Suite("Market year coverage")
struct MarketYearCoverageTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15

    private func coverage(_ stated: String?, _ year: Int) -> MarketYearCoverage.Coverage {
        MarketYearCoverage.coverage(of: stated, for: year, now: now)
    }

    @Test func nothingStatedCounts() {
        #expect(coverage(nil, 1975) == .unstated)
        #expect(coverage("", 1975) == .unstated)
        #expect(coverage("   ", 1975) == .unstated)
    }

    @Test func aSingleYearCoversItselfOnly() {
        #expect(coverage("1975", 1975) == .covers)
        #expect(coverage("1979 ", 1979) == .covers)
        #expect(coverage("1974", 1975) == .mismatch)
    }

    @Test func aRangeCoversItsYearsInclusive() {
        #expect(coverage("1970 - 1984", 1970) == .covers)
        #expect(coverage("1970 - 1984", 1984) == .covers)
        #expect(coverage("1970-1984", 1975) == .covers)
        #expect(coverage("1970 - 1984", 1985) == .mismatch)
        #expect(coverage("1984 - 1970", 1975) == .mismatch, "a backwards range is unreadable")
    }

    @Test func anOpenRangeReachesTheCurrentYear() {
        #expect(coverage("2020 - Present", 2020) == .covers)
        #expect(coverage("2020 - Present", 2027) == .covers)
        #expect(coverage("2020 - present", 2024) == .covers)
        #expect(coverage("2020 - Present", 2028) == .mismatch, "next year is not present")
        #expect(coverage("2020 - Present", 2019) == .mismatch)
    }

    @Test func aDecadeCoversItsTenYears() {
        #expect(coverage("1970s", 1970) == .covers)
        #expect(coverage("1970s", 1979) == .covers)
        #expect(coverage("1970s", 1980) == .mismatch)
        #expect(coverage("2020s", 2021) == .covers)
    }

    @Test(arguments: ["0", "2003-04", "LATE 2000’s", "seventies", "19750", "197"])
    func anUnreadableYearIsAMismatch(stated: String) {
        #expect(coverage(stated, 1975) == .mismatch, "\(stated)")
        #expect(coverage(stated, 2004) == .mismatch, "\(stated)")
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

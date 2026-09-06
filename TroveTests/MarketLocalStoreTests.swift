import Foundation
import SwiftData
import Testing
@testable import Trove

/// The local rows through the caller's context (plan §1, §5). Every
/// persistence assertion refetches on a **second** context: the helpers
/// don't save, the tests do, and a same-context refetch would pass whether
/// or not the save happened (`makeInMemoryContainer`'s doc).
@Suite("Market local store")
struct MarketLocalStoreTests {
    private let day: TimeInterval = 24 * 60 * 60
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private let product = MarketProduct(
        id: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster",
        usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
    )

    /// The trimmed bounds sit inside the spread on purpose (Amendment B), so
    /// a row that stored a bound as its low or high would be visible.
    private func figure(median: Int, at: Date, scope: YearScope = .any, truncated: Bool = false) -> MarketReading {
        .figure(MarketFigure(
            medianCents: median, lowCents: median - 100, highCents: median + 100,
            p10Cents: median - 50, p90Cents: median + 50,
            count: 12, fetchedAt: at, isTruncated: truncated, yearScope: scope
        ))
    }

    // MARK: - record

    @Test func aFigureLandsAsARowAPointATrendlessTrendAndASnapshot() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let key = MarketSubjectKey(subjectID: UUID(), kind: .owned)

        try MarketLocalStore.record(figure(median: 140_000, at: t0, scope: .year(2021), truncated: true), product: product, for: key, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        let row = try #require(try MarketLocalStore.figure(for: key.subjectID, in: elsewhere))
        #expect(row.productID == 126_161)
        #expect(row.subjectKindRawValue == "owned")
        #expect(row.fetchedAt == t0)
        #expect(row.count == 12)
        #expect(row.medianCents == 140_000)
        #expect(row.lowCents == 139_900)
        #expect(row.highCents == 140_100)
        #expect(row.p10Cents == 139_950, "the trimmed bounds round-trip (Amendment B)")
        #expect(row.p90Cents == 140_050)
        #expect(row.usedLowCents == 100_000)
        #expect(row.isTruncated)
        #expect(row.yearFilter == 2021)
        #expect(!row.isAllYearsFallback)
        #expect(row.trendRawValue == nil, "one point is no trend")

        let points = try MarketLocalStore.history(for: key.subjectID, in: elsewhere)
        #expect(points.map(\.medianCents) == [140_000])

        let snapshot = try #require(try MarketLocalStore.snapshot(for: key.subjectID, in: elsewhere))
        #expect(snapshot.slug == product.slug)
        #expect(snapshot.title == product.title)
        #expect(snapshot.usedLowCents == 100_000)
        #expect(snapshot.takenAt == t0)
    }

    @Test func aSecondRefreshUpsertsTheRowAppendsAPointAndStoresTheTrend() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let key = MarketSubjectKey(subjectID: UUID(), kind: .owned)

        try MarketLocalStore.record(figure(median: 100_000, at: t0), product: product, for: key, in: context)
        try context.save()
        try MarketLocalStore.record(figure(median: 110_000, at: t0.addingTimeInterval(8 * day)), product: product, for: key, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        #expect(try elsewhere.fetchCount(FetchDescriptor<MarketFigureRecord>()) == 1, "the figure row is one per item")
        let row = try #require(try MarketLocalStore.figure(for: key.subjectID, in: elsewhere))
        #expect(row.medianCents == 110_000)
        #expect(row.trendRawValue == MarketTrend.up.rawValue)
        #expect(try MarketLocalStore.history(for: key.subjectID, in: elsewhere).map(\.medianCents) == [100_000, 110_000])
        // The cached trend agrees with the pure function over the history.
        #expect(row.trendRawValue == MarketTrend.compute(history: try MarketLocalStore.historyEntries(for: key.subjectID, in: elsewhere))?.rawValue)
    }

    /// Decision 16, criterion 16: history is never trimmed by age — a point
    /// four hundred days old survives the next refresh. The one place the
    /// no-time-limit decision is enforced, and `003`'s raw material.
    @Test func historyIsNeverTrimmedByAge() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let key = MarketSubjectKey(subjectID: UUID(), kind: .owned)
        let longAgo = t0.addingTimeInterval(-400 * day)

        try MarketLocalStore.record(figure(median: 100_000, at: longAgo), product: product, for: key, in: context)
        try context.save()
        try MarketLocalStore.record(figure(median: 120_000, at: t0), product: product, for: key, in: context)
        try context.save()

        let points = try MarketLocalStore.history(for: key.subjectID, in: ModelContext(container))
        #expect(points.map(\.fetchedAt) == [longAgo, t0])
        #expect(try MarketLocalStore.figure(for: key.subjectID, in: ModelContext(container))?.trendRawValue == MarketTrend.up.rawValue, "a 400-day-old point is still the previous point (plan Q6)")
    }

    /// Decision 23: a withheld refresh updates the row — the age, the
    /// catalog's lowest used price — and adds no point.
    @Test func aWithheldRefreshUpdatesTheRowAndAddsNoPoint() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let key = MarketSubjectKey(subjectID: UUID(), kind: .wanted)

        try MarketLocalStore.record(figure(median: 100_000, at: t0), product: product, for: key, in: context)
        try context.save()
        let later = t0.addingTimeInterval(day)
        try MarketLocalStore.record(.withheld(count: 2, usedLowCents: 100_000, fetchedAt: later, yearScope: .allYears(fallbackFrom: 1975)), product: product, for: key, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        let row = try #require(try MarketLocalStore.figure(for: key.subjectID, in: elsewhere))
        #expect(row.medianCents == nil)
        #expect(row.lowCents == nil)
        #expect(row.p10Cents == nil, "a withheld refresh clears the trimmed bounds too")
        #expect(row.p90Cents == nil)
        #expect(row.count == 2)
        #expect(row.fetchedAt == later)
        #expect(row.usedLowCents == 100_000)
        #expect(row.yearFilter == 1975)
        #expect(row.isAllYearsFallback)
        #expect(row.subjectKindRawValue == "wanted")
        #expect(try MarketLocalStore.history(for: key.subjectID, in: elsewhere).count == 1, "a withheld refresh is not a point")
    }

    // MARK: - recordMatch, clear

    @Test func thePickWritesTheSnapshotBeforeAnyRefresh() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let id = UUID()
        let candidate = MarketCandidate(id: 182_769, slug: "martin-d-18", title: "Martin Standard Series D-18 (2018 - 2024)", brand: "Martin", imageURL: nil, usedLowCents: 192_100, usedTotal: 19)

        try MarketLocalStore.recordMatch(candidate, for: id, at: t0, in: context)
        try context.save()

        let snapshot = try #require(try MarketLocalStore.snapshot(for: id, in: ModelContext(container)))
        #expect(snapshot.productID == 182_769)
        #expect(snapshot.slug == "martin-d-18")
        #expect(snapshot.title == candidate.title)
        #expect(snapshot.usedLowCents == 192_100)
        #expect(try MarketLocalStore.figure(for: id, in: ModelContext(container)) == nil, "a pick is not a figure")
    }

    @Test func clearRemovesTheRowThePointsAndTheSnapshotForThatItemOnly() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let gone = MarketSubjectKey(subjectID: UUID(), kind: .owned)
        let kept = MarketSubjectKey(subjectID: UUID(), kind: .owned)
        for key in [gone, kept] {
            try MarketLocalStore.record(figure(median: 100_000, at: t0), product: product, for: key, in: context)
            try MarketLocalStore.record(figure(median: 100_500, at: t0.addingTimeInterval(day)), product: product, for: key, in: context)
        }
        try context.save()

        try MarketLocalStore.clear(subjectID: gone.subjectID, in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        #expect(try MarketLocalStore.figure(for: gone.subjectID, in: elsewhere) == nil)
        #expect(try MarketLocalStore.snapshot(for: gone.subjectID, in: elsewhere) == nil)
        #expect(try MarketLocalStore.history(for: gone.subjectID, in: elsewhere).isEmpty)
        #expect(try MarketLocalStore.figure(for: kept.subjectID, in: elsewhere) != nil)
        #expect(try MarketLocalStore.history(for: kept.subjectID, in: elsewhere).count == 2)
    }

    // MARK: - The notice flag

    @Test func theNoticeStartsUnacknowledgedAndStaysSoUntilSaved() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        #expect(!MarketLocalStore.hasAcknowledgedNotice(in: context))

        try MarketLocalStore.acknowledgeNotice(at: t0, in: context)
        #expect(!MarketLocalStore.hasAcknowledgedNotice(in: ModelContext(container)), "nothing reached the store before the save")

        try context.save()
        #expect(MarketLocalStore.hasAcknowledgedNotice(in: ModelContext(container)))
    }

    @Test func acknowledgingTwiceKeepsOneRowAndTheFirstTime() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try MarketLocalStore.acknowledgeNotice(at: t0, in: context)
        try context.save()
        try MarketLocalStore.acknowledgeNotice(at: t0.addingTimeInterval(day), in: context)
        try context.save()

        let elsewhere = ModelContext(container)
        let rows = try elsewhere.fetch(FetchDescriptor<MarketDeviceState>())
        #expect(rows.count == 1)
        #expect(rows.first?.noticeAcknowledgedAt == t0)
    }

    // MARK: - The spies' own discipline

    @Test func theSpyThrowsOnceItsScriptIsExhausted() async throws {
        let spy = MarketServiceSpy(products: [.success(product)])
        let first = try await spy.product(id: 126_161)
        #expect(first == product)
        await #expect(throws: MarketServiceSpy.ScriptExhausted(call: .product(126_161))) {
            _ = try await spy.product(id: 126_161)
        }
        #expect(spy.calls == [.product(126_161), .product(126_161)])
    }
}

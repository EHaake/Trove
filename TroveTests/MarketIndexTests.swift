import Foundation
import SwiftData
import Testing
@testable import Trove

/// One fetch, one dictionary (plan §5), and the section-state table the
/// detail view models read (plan §6).
@Suite("Market index and section state")
struct MarketIndexTests {
    private let day: TimeInterval = 24 * 60 * 60
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private let product = MarketProduct(
        id: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster",
        usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!
    )

    private func reading(median: Int?, at: Date) -> MarketReading {
        if let median {
            return .figure(MarketFigure(medianCents: median, lowCents: median, highCents: median, count: 5, fetchedAt: at, isTruncated: false, yearScope: .any))
        }
        return .withheld(count: 1, usedLowCents: 100_000, fetchedAt: at, yearScope: .any)
    }

    @Test func theIndexHasOneEntryPerFigureRowKeyedByTheItem() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let a = UUID(), b = UUID(), orphan = UUID()
        try MarketLocalStore.record(reading(median: 140_000, at: t0), product: product, for: MarketSubjectKey(subjectID: a, kind: .owned), in: context)
        try MarketLocalStore.record(reading(median: nil, at: t0), product: product, for: MarketSubjectKey(subjectID: b, kind: .wanted), in: context)
        try MarketLocalStore.record(reading(median: 90_000, at: t0), product: product, for: MarketSubjectKey(subjectID: orphan, kind: .owned), in: context)
        try context.save()

        let index = try MarketIndex.load(from: ModelContext(container))

        #expect(Set(index.figures.keys) == [a, b, orphan])
        #expect(index.figures[a]?.medianCents == 140_000)
        #expect(index.figures[a]?.currentMedianCents(now: t0.addingTimeInterval(day)) == 140_000)
        #expect(index.figures[b]?.medianCents == nil)
        #expect(index.figures[b]?.currentMedianCents(now: t0) == nil, "withheld has no median to sort by")
        #expect(index.figures[a]?.currentMedianCents(now: t0.addingTimeInterval(31 * day)) == nil, "stale drops out (Decision 21)")
    }

    @Test func anEmptyStoreIsAnEmptyIndex() throws {
        let index = try MarketIndex.load(from: try makeInMemoryContext())
        #expect(index == .empty)
    }

    // MARK: - resolve

    private func value(median: Int?, at: Date) -> MarketSnapshotValue {
        let record = MarketFigureRecord(subjectID: UUID(), subjectKind: .owned, productID: 126_161, fetchedAt: at)
        record.medianCents = median
        record.count = median == nil ? 1 : 5
        return MarketSnapshotValue(record: record)
    }

    private var snapshot: MarketMatchSnapshotValue {
        MarketMatchSnapshotValue(productID: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster", usedLowCents: 100_000, takenAt: t0)
    }

    @Test func noProductIsUnmatchedWhateverElseIsAround() {
        #expect(MarketSectionState.resolve(productID: nil, figure: value(median: 1, at: t0), snapshot: snapshot, now: t0) == .unmatched)
    }

    @Test func matchedWithoutAFigureReadsNoneAndStillCarriesTheSnapshot() throws {
        let state = MarketSectionState.resolve(productID: 126_161, figure: nil, snapshot: snapshot, now: t0)
        guard case .matched(let display) = state else { throw TestFailure("not matched") }
        #expect(display.reading == .none)
        #expect(display.title == "Fender American Professional II Telecaster")
        #expect(display.webURL == URL(string: "https://reverb.com/p/fender-american-professional-ii-telecaster"))
    }

    @Test func matchedWithoutASnapshotHasNoTitleAndNoLink() throws {
        let state = MarketSectionState.resolve(productID: 126_161, figure: nil, snapshot: nil, now: t0)
        guard case .matched(let display) = state else { throw TestFailure("not matched") }
        #expect(display.title == nil)
        #expect(display.webURL == nil)
    }

    @Test func aFreshMedianIsCurrentAndAFreshNilIsWithheld() throws {
        let now = t0.addingTimeInterval(day)
        let current = value(median: 140_000, at: t0)
        let withheld = value(median: nil, at: t0)
        guard case .matched(let a) = MarketSectionState.resolve(productID: 1, figure: current, snapshot: nil, now: now),
              case .matched(let b) = MarketSectionState.resolve(productID: 1, figure: withheld, snapshot: nil, now: now) else { throw TestFailure("not matched") }
        #expect(a.reading == .current(current))
        #expect(b.reading == .withheld(withheld))
    }

    /// Stale is checked before withheld: a thirty-day-old withheld figure
    /// carries a thirty-day-old catalog price, and neither is current.
    @Test func thirtyDaysMakesEitherReadingStale() throws {
        let now = t0.addingTimeInterval(30 * day)
        for figure in [value(median: 140_000, at: t0), value(median: nil, at: t0)] {
            guard case .matched(let display) = MarketSectionState.resolve(productID: 1, figure: figure, snapshot: nil, now: now) else { throw TestFailure("not matched") }
            #expect(display.reading == .stale(fetchedAt: t0))
        }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

import Foundation
import SwiftData
import Testing
@testable import Trove

/// The refresh pipeline against the scripted spy (plan §5): the hour
/// budget before any call, nothing written before the computation, the
/// re-check after the awaits, one save. Persistence read on a second
/// context throughout.
@Suite("Market refresher")
struct MarketRefresherTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let minute: TimeInterval = 60

    private func product() throws -> MarketProduct {
        try ReverbDecoding.product(from: try reverbFixture("csp-126161.json"))
    }

    private func allPages() throws -> MarketListings {
        var all: [MarketListing] = []
        for page in 1...7 { all += try ReverbDecoding.page(from: try reverbFixture("listings-126161-p\(page).json")).listings }
        return MarketListings(listings: all, reportedTotal: 337, isTruncated: false)
    }

    private struct World {
        let container: ModelContainer
        let context: ModelContext
        let item: Item
        var target: MarketRefreshTarget {
            MarketRefreshTarget(key: MarketSubjectKey(subjectID: item.id, kind: .owned), productID: 126_161, subject: .owned(condition: .excellent), year: item.year)
        }
    }

    private func world(year: Int? = nil) throws -> World {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let item = Item(name: "Telecaster", condition: .excellent, reverbProductID: 126_161, year: year)
        context.insert(item)
        try context.save()
        return World(container: container, context: context, item: item)
    }

    private func spy(products: [Result<MarketProduct, MarketError>]? = nil, listings: [Result<MarketListings, MarketError>]? = nil) throws -> MarketServiceSpy {
        let defaultProduct = try product()
        let defaultListings = try allPages()
        return MarketServiceSpy(products: products ?? [.success(defaultProduct)], listings: listings ?? [.success(defaultListings)])
    }

    // MARK: - The hour budget (P7, criterion 9)

    @Test func withinTheHourNothingIsSent() async throws {
        let w = try world()
        try MarketLocalStore.record(.figure(MarketFigure(medianCents: 1, lowCents: 1, highCents: 1, count: 3, fetchedAt: t0.addingTimeInterval(-59 * minute), isTruncated: false, yearScope: .any)), product: try product(), for: w.target.key, in: w.context)
        try w.context.save()
        let spy = try spy()
        let refresher = MarketRefresher(modelContext: w.context, service: spy, now: { self.t0 })

        let outcome = await refresher.refresh(w.target)

        #expect(outcome == .stillFresh(fetchedAt: t0.addingTimeInterval(-59 * minute)))
        #expect(spy.calls.isEmpty)
    }

    @Test func atTheHourItFetches() async throws {
        let w = try world()
        try MarketLocalStore.record(.figure(MarketFigure(medianCents: 1, lowCents: 1, highCents: 1, count: 3, fetchedAt: t0.addingTimeInterval(-60 * minute), isTruncated: false, yearScope: .any)), product: try product(), for: w.target.key, in: w.context)
        try w.context.save()
        let spy = try spy()
        let refresher = MarketRefresher(modelContext: w.context, service: spy, now: { self.t0 })

        _ = await refresher.refresh(w.target)

        #expect(spy.calls == [.product(126_161), .listings(productID: 126_161)])
    }

    // MARK: - Success

    @Test func aRefreshWritesTheFigureAPointATrendAndTheSnapshotInOneSave() async throws {
        let w = try world()
        let refresher = MarketRefresher(modelContext: w.context, service: try spy(), now: { self.t0 })

        let outcome = await refresher.refresh(w.target)

        guard case .refreshed(.figure(let figure)) = outcome else { throw TestFailure("\(outcome)") }
        #expect(figure.count == 34)
        #expect(figure.medianCents == 139_999)
        #expect(figure.fetchedAt == t0)
        #expect(!w.context.hasChanges, "the refresher left unsaved changes behind")

        let elsewhere = ModelContext(w.container)
        let row = try #require(try MarketLocalStore.figure(for: w.item.id, in: elsewhere))
        #expect(row.medianCents == 139_999)
        #expect(row.productID == 126_161)
        #expect(try MarketLocalStore.history(for: w.item.id, in: elsewhere).count == 1)
        #expect(try MarketLocalStore.snapshot(for: w.item.id, in: elsewhere)?.title == "Fender American Professional II Telecaster")
    }

    @Test func theItemsYearNarrowsTheFigure() async throws {
        let w = try world(year: 2021)
        let refresher = MarketRefresher(modelContext: w.context, service: try spy(), now: { self.t0 })

        let outcome = await refresher.refresh(w.target)

        guard case .refreshed(.figure(let figure)) = outcome else { throw TestFailure("\(outcome)") }
        #expect(figure.yearScope == .year(2021))
        #expect(figure.count < 34)
        #expect(try MarketLocalStore.figure(for: w.item.id, in: ModelContext(w.container))?.yearFilter == 2021)
    }

    @Test func aWithheldReadingIsSavedWithoutAPoint() async throws {
        let w = try world()
        let two = MarketListings(listings: Array(try allPages().listings.filter { $0.conditionSlug == "excellent" && $0.currency == "USD" }.prefix(2)), reportedTotal: 2, isTruncated: false)
        let refresher = MarketRefresher(modelContext: w.context, service: try spy(listings: [.success(two)]), now: { self.t0 })

        let outcome = await refresher.refresh(w.target)

        #expect(outcome == .refreshed(.withheld(count: 2, usedLowCents: 100_000, fetchedAt: t0, yearScope: .any)))
        let elsewhere = ModelContext(w.container)
        #expect(try MarketLocalStore.figure(for: w.item.id, in: elsewhere)?.medianCents == nil)
        #expect(try MarketLocalStore.history(for: w.item.id, in: elsewhere).isEmpty)
    }

    // MARK: - Failure leaves the last figure alone (P8)

    @Test(arguments: [MarketError.unreachable, .rateLimited, .productNotFound, .serverError(status: 500)])
    func aFailedFetchLeavesTheRecordFieldByField(error: MarketError) async throws {
        let w = try world()
        let old = MarketFigure(medianCents: 111_111, lowCents: 100_000, highCents: 120_000, count: 7, fetchedAt: t0.addingTimeInterval(-3 * 60 * minute), isTruncated: false, yearScope: .any)
        try MarketLocalStore.record(.figure(old), product: try product(), for: w.target.key, in: w.context)
        try w.context.save()
        let refresher = MarketRefresher(modelContext: w.context, service: try spy(products: [.failure(error)]), now: { self.t0 })

        let outcome = await refresher.refresh(w.target)

        #expect(outcome == .failed(error))
        let row = try #require(try MarketLocalStore.figure(for: w.item.id, in: ModelContext(w.container)))
        #expect(row.medianCents == 111_111)
        #expect(row.lowCents == 100_000)
        #expect(row.highCents == 120_000)
        #expect(row.count == 7)
        #expect(row.fetchedAt == old.fetchedAt)
        #expect(try MarketLocalStore.history(for: w.item.id, in: ModelContext(w.container)).count == 1)
    }

    // MARK: - The world changing under the awaits

    @Test func anUnmatchDuringTheFetchDropsTheResult() async throws {
        let w = try world()
        let gated = GatedMarketServiceSpy(product: .success(try product()), listings: .success(try allPages()))
        let refresher = MarketRefresher(modelContext: w.context, service: gated, now: { self.t0 })

        let task = Task { await refresher.refresh(w.target) }
        while gated.listingsCalls == 0 { await Task.yield() }
        w.item.reverbProductID = nil
        try w.context.save()
        gated.release()

        let outcome = await task.value
        #expect(outcome == .superseded)
        #expect(try MarketLocalStore.figure(for: w.item.id, in: ModelContext(w.container)) == nil)
        #expect(try MarketLocalStore.history(for: w.item.id, in: ModelContext(w.container)).isEmpty)
    }

    @Test func aReMatchDuringTheFetchDropsTheResultToo() async throws {
        let w = try world()
        let gated = GatedMarketServiceSpy(product: .success(try product()), listings: .success(try allPages()))
        let refresher = MarketRefresher(modelContext: w.context, service: gated, now: { self.t0 })

        let task = Task { await refresher.refresh(w.target) }
        while gated.listingsCalls == 0 { await Task.yield() }
        w.item.reverbProductID = 999
        try w.context.save()
        gated.release()

        #expect(await task.value == .superseded)
        #expect(try MarketLocalStore.figure(for: w.item.id, in: ModelContext(w.container)) == nil)
    }

    // MARK: - targets

    @Test func targetsAreTheMatchedOwnedInCustomOrderThenTheMatchedWanted() throws {
        let context = try makeInMemoryContext()
        let second = Item(name: "B", condition: .good, sortOrder: 2, reverbProductID: 2, year: 1975)
        let first = Item(name: "A", condition: .new, sortOrder: 1, reverbProductID: 1)
        let unmatched = Item(name: "C", sortOrder: 0)
        let wanted = WishlistItem(name: "W", reverbProductID: 3, year: 1999)
        let unmatchedWanted = WishlistItem(name: "X")
        for model in [second, first, unmatched] as [Item] { context.insert(model) }
        for model in [wanted, unmatchedWanted] as [WishlistItem] { context.insert(model) }
        try context.save()

        let targets = try MarketRefresher.targets(in: context)

        #expect(targets.map(\.productID) == [1, 2, 3])
        #expect(targets.map(\.key.kind) == [.owned, .owned, .wanted])
        #expect(targets[0].subject == .owned(condition: .new))
        #expect(targets[1].subject == .owned(condition: .good))
        #expect(targets[1].year == 1975)
        #expect(targets[2].subject == .wanted)
        #expect(targets[2].year == 1999)
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

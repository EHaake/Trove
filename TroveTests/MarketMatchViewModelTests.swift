import Foundation
import SwiftData
import Testing
@testable import Trove

/// The picker's view model (plan §6): what it sends, when it sends it, and
/// what each answer leaves on screen.
///
/// The first two tests are the ones spec criterion 3 rests on — the request
/// carries the item's name and nothing else, and no request goes out at all
/// for a blank query. They go through the *detail* view models' factory
/// rather than constructing the picker by hand, because the seed is exactly
/// where a category or a condition would get appended.
@Suite("MarketMatchViewModel")
struct MarketMatchViewModelTests {
    private let telecaster = MarketCandidate(
        id: 126_161,
        slug: "fender-american-professional-ii-telecaster",
        title: "Fender American Professional II Telecaster",
        brand: "Fender",
        imageURL: nil,
        usedLowCents: 110_000,
        usedTotal: 34
    )

    // MARK: - The seed (criterion 3)

    @Test func theOwnedScreenSeedsThePickerWithTheItemsNameAlone() async throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        context.insert(item)
        try context.save()

        let spy = MarketServiceSpy(search: [.success([telecaster])])
        let detail = ItemDetailViewModel(modelContext: context, itemID: item.id, marketService: spy)
        detail.load()

        let picker = detail.makeMatchViewModel()
        #expect(picker.query == "Fender Telecaster", "the picker opened seeded with something other than the name")

        await picker.search()

        #expect(
            spy.calls == [.search("Fender Telecaster")],
            "the search sent \(spy.calls) — criterion 3 allows the name and nothing else"
        )
    }

    @Test func theWantedScreenSeedsThePickerWithTheItemsNameAlone() async throws {
        let context = try makeInMemoryContext()
        let item = WishlistItem(name: "Martin D-18", estimatedCostCents: 240_000)
        context.insert(item)
        try context.save()

        let spy = MarketServiceSpy(search: [.success([telecaster])])
        let detail = WishlistDetailViewModel(modelContext: context, itemID: item.id, marketService: spy)
        detail.load()

        let picker = detail.makeMatchViewModel()
        #expect(picker.query == "Martin D-18")

        await picker.search()

        #expect(spy.calls == [.search("Martin D-18")], "the search sent \(spy.calls)")
    }

    /// Change match… seeds from the item, not from what it is matched to
    /// (Q10) — otherwise a wrong match narrows every search after it.
    @Test func changingAMatchSeedsFromTheItemNotFromTheMatchedProduct() throws {
        let context = try makeInMemoryContext()
        let item = Item(name: "Fender Telecaster", categoryPath: "Music/Guitars")
        item.reverbProductID = telecaster.id
        context.insert(item)
        try context.save()

        let detail = ItemDetailViewModel(modelContext: context, itemID: item.id, marketService: MarketServiceSpy())
        detail.load()
        detail.setMatch(telecaster)

        #expect(
            detail.makeMatchViewModel().query == "Fender Telecaster",
            "the picker re-opened seeded with the matched product's title"
        )
    }

    // MARK: - What is searched

    @Test func aBlankQueryReachesNothingAndLeavesTheSheetIdle() async throws {
        let spy = MarketServiceSpy(search: [.success([telecaster])])
        let picker = MarketMatchViewModel(seed: "   ", service: spy)

        await picker.search()

        #expect(spy.calls.isEmpty, "a blank query reached Reverb")
        #expect(picker.phase == .idle)
    }

    @Test func aClearedFieldReachesNothingAfterAResultIsAlreadyShowing() async throws {
        let spy = MarketServiceSpy(search: [.success([telecaster])])
        let picker = MarketMatchViewModel(seed: "Telecaster", service: spy)
        await picker.search()
        #expect(picker.phase == .results([telecaster]))

        picker.query = ""
        await picker.search()

        #expect(spy.calls == [.search("Telecaster")], "clearing the field searched again")
        #expect(picker.phase == .idle)
    }

    @Test func theQueryIsTrimmedBeforeItIsSent() async throws {
        let spy = MarketServiceSpy(search: [.success([telecaster])])
        let picker = MarketMatchViewModel(seed: "  Fender Telecaster \n", service: spy)

        await picker.search()

        #expect(spy.calls == [.search("Fender Telecaster")])
    }

    // MARK: - Phases

    @Test func candidatesBecomeResults() async throws {
        let spy = MarketServiceSpy(search: [.success([telecaster])])
        let picker = MarketMatchViewModel(seed: "Telecaster", service: spy)

        await picker.search()

        #expect(picker.phase == .results([telecaster]))
    }

    /// The empty phase carries the query, because the copy names it back.
    @Test func noCandidatesBecomesTheEmptyPhaseCarryingTheTrimmedQuery() async throws {
        let spy = MarketServiceSpy(search: [.success([])])
        let picker = MarketMatchViewModel(seed: " Telecaster ", service: spy)

        await picker.search()

        #expect(picker.phase == .empty("Telecaster"))
    }

    /// Only the rate limit has its own line (spec P7); everything else —
    /// including an error that isn't a `MarketError` at all — reads as
    /// "couldn't reach Reverb".
    @Test(arguments: [
        (MarketError.rateLimited, MarketMatchViewModel.Failure.rateLimited),
        (MarketError.unreachable, .unreachable),
        (MarketError.productNotFound, .unreachable),
        (MarketError.serverError(status: 503), .unreachable),
        (MarketError.malformedResponse, .unreachable),
    ])
    func everyErrorMapsToItsFailure(error: MarketError, expected: MarketMatchViewModel.Failure) async {
        let spy = MarketServiceSpy(search: [.failure(error)])
        let picker = MarketMatchViewModel(seed: "Telecaster", service: spy)

        await picker.search()

        #expect(picker.phase == .failed(expected))
    }

    /// The spy's own `ScriptExhausted` stands in for anything that isn't a
    /// `MarketError`: a cancellation, a decoding slip, a bug.
    @Test func anErrorThatIsNotAMarketErrorReadsAsUnreachable() async {
        let picker = MarketMatchViewModel(seed: "Telecaster", service: MarketServiceSpy())

        await picker.search()

        #expect(picker.phase == .failed(.unreachable))
    }

    // MARK: - Reentry

    /// A submit while a search is in flight is dropped, not queued — the
    /// `aRefreshIsObservableMidFlightAndASecondTapIsRefused` shape, one call
    /// further out.
    @Test func aSecondSearchWhileOneIsRunningIsIgnored() async throws {
        let gated = GatedMarketServiceSpy(
            candidates: [telecaster],
            product: .failure(.productNotFound),
            listings: .failure(.productNotFound),
            gatesSearch: true
        )
        let picker = MarketMatchViewModel(seed: "Fender Telecaster", service: gated)

        let task = Task { await picker.search() }
        // Bounded: a search that never reaches the spy turns the require
        // below red instead of spinning the suite forever.
        var yields = 0
        while gated.searchCalls == 0 && yields < 10_000 {
            await Task.yield()
            yields += 1
        }
        try #require(gated.searchCalls == 1)
        #expect(picker.phase == .searching)

        // The second submit, mid-flight — and a different query, so a call
        // that wrongly got through would be visible in `queries` too.
        picker.query = "Martin D-18"
        await picker.search()
        #expect(gated.searchCalls == 1, "a second search mid-flight reached Reverb: \(gated.queries)")

        gated.release()
        await task.value
        #expect(picker.phase == .results([telecaster]))

        // And the guard lifts once the first one is done.
        await picker.search()
        #expect(gated.queries == ["Fender Telecaster", "Martin D-18"], "the guard never lifted")
    }
}

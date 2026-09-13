import Foundation
import Synchronization
import Testing
@testable import Trove

/// The stock-photo picker's view model (plan §4): what it sends, when it sends
/// it, what each answer leaves on screen, and what a download hands back.
///
/// The seed test is the one spec criterion 2 (P1) rests on at the view-model
/// boundary — the request carries the trimmed seed verbatim, nothing appended.
/// The host-factory "seed is the item's name, not name+category" test is
/// T009/T010's.
@Suite("PhotoFetchViewModel")
struct PhotoFetchViewModelTests {
    private func candidate(id: Int = 1, storage: String = "https://upload.wikimedia.org/a.jpg") -> StockPhotoCandidate {
        StockPhotoCandidate(
            id: id,
            title: "Leica M6",
            thumbnailURL: URL(string: "https://upload.wikimedia.org/thumb.jpg")!,
            storageURL: URL(string: storage)!,
            attribution: StockPhotoAttribution(
                author: "Jane Photographer",
                licenseName: "CC BY-SA 4.0",
                sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Leica.jpg")!
            )
        )
    }

    // MARK: - The seed (criterion 2 / P1)

    /// The seed drives the search verbatim — nothing appended to the trimmed
    /// query. Mutation: append anything before the call → this goes red.
    @Test func theSeedDrivesTheSearchVerbatim() async {
        let spy = StockPhotoServiceSpy(search: [.success([candidate()])])
        let vm = PhotoFetchViewModel(seed: "Leica M6", service: spy)

        await vm.search()

        #expect(
            spy.calls == [.search("Leica M6")],
            "the search sent \(spy.calls) — criterion 2 allows the name and nothing else"
        )
    }

    @Test func theQueryIsTrimmedBeforeItIsSent() async {
        let spy = StockPhotoServiceSpy(search: [.success([candidate()])])
        let vm = PhotoFetchViewModel(seed: "  Leica M6 \n", service: spy)

        await vm.search()

        #expect(spy.calls == [.search("Leica M6")])
    }

    // MARK: - Blank

    @Test func aBlankQueryReachesNothingAndLeavesTheSheetIdle() async {
        let spy = StockPhotoServiceSpy(search: [.success([candidate()])])
        let vm = PhotoFetchViewModel(seed: "   ", service: spy)

        await vm.search()

        #expect(spy.calls.isEmpty, "a blank query reached Wikimedia")
        #expect(vm.phase == .idle)
    }

    // MARK: - Phases

    @Test func candidatesBecomeResults() async {
        let card = candidate()
        let spy = StockPhotoServiceSpy(search: [.success([card])])
        let vm = PhotoFetchViewModel(seed: "Leica M6", service: spy)

        await vm.search()

        #expect(vm.phase == .results([card]))
    }

    @Test func noCandidatesBecomesTheEmptyPhaseCarryingTheTrimmedQuery() async {
        let spy = StockPhotoServiceSpy(search: [.success([])])
        let vm = PhotoFetchViewModel(seed: " Leica M6 ", service: spy)

        await vm.search()

        #expect(vm.phase == .empty("Leica M6"))
    }

    /// Every thrown error reads as `.failed` — the stock picker has one failure
    /// message (`imageTooLarge` can't arise from a search, so mapping all
    /// search errors to `.failed` satisfies the plan).
    @Test func anErrorBecomesTheFailedPhase() async {
        let spy = StockPhotoServiceSpy(search: [.failure(.unreachable)])
        let vm = PhotoFetchViewModel(seed: "Leica M6", service: spy)

        await vm.search()

        #expect(vm.phase == .failed)
    }

    /// The spy's own `ScriptExhausted` stands in for anything that isn't a
    /// `StockPhotoError` — a cancellation, a decoding slip, a bug.
    @Test func anErrorThatIsNotAStockPhotoErrorReadsAsFailed() async {
        let vm = PhotoFetchViewModel(seed: "Leica M6", service: StockPhotoServiceSpy())

        await vm.search()

        #expect(vm.phase == .failed)
    }

    // MARK: - Reentry

    /// A submit while a search is in flight is dropped, not queued — the
    /// `MarketMatchViewModelTests` reentry shape, driven by a gated spy so the
    /// second call lands genuinely mid-flight. Mutation: delete the
    /// `isSearching` guard in `search()` → `searchCalls` reaches 2 → red.
    @Test func aSecondSearchWhileOneIsRunningIsIgnored() async throws {
        let gated = GatedStockPhotoServiceSpy(candidates: [candidate()])
        let vm = PhotoFetchViewModel(seed: "Leica M6", service: gated)

        let task = Task { await vm.search() }
        var yields = 0
        while gated.searchCalls == 0 && yields < 10_000 {
            await Task.yield()
            yields += 1
        }
        try #require(gated.searchCalls == 1)
        #expect(vm.phase == .searching)

        // The second submit, mid-flight, with a different query so a call that
        // wrongly got through would be visible in `queries` too.
        vm.query = "Nikon FM2"
        await vm.search()
        #expect(gated.searchCalls == 1, "a second search mid-flight reached Wikimedia: \(gated.queries)")

        gated.release()
        await task.value
        #expect(vm.phase == .results([candidate()]))

        // And the guard lifts once the first one is done.
        await vm.search()
        #expect(gated.queries == ["Leica M6", "Nikon FM2"], "the guard never lifted")
    }

    // MARK: - Download

    @Test func aDownloadReturnsTheBytesAndTheAttribution() async {
        let card = candidate()
        let bytes = Data([0x01, 0x02, 0x03])
        let spy = StockPhotoServiceSpy(imageData: [.success(bytes)])
        let vm = PhotoFetchViewModel(seed: "Leica M6", service: spy)

        let result = await vm.download(card)

        #expect(result == StockPhotoDownload(imageData: bytes, attribution: card.attribution))
        #expect(spy.calls == [.imageData(card.storageURL)])
        #expect(vm.isDownloading == false)
    }

    @Test func aFailedDownloadReturnsNil() async {
        let card = candidate()
        let spy = StockPhotoServiceSpy(imageData: [.failure(.imageTooLarge)])
        let vm = PhotoFetchViewModel(seed: "Leica M6", service: spy)

        let result = await vm.download(card)

        #expect(result == nil)
        #expect(vm.isDownloading == false)
    }
}

/// A `StockPhotoService` spy whose first `searchPhotos` call gates until
/// `release()`, so the reentry test's second submit lands genuinely
/// mid-flight — the `GatedMarketServiceSpy(gatesSearch:)` shape for 005. Later
/// calls answer at once. Capture behind a `Mutex` because the requirements are
/// `@concurrent`.
nonisolated final class GatedStockPhotoServiceSpy: StockPhotoService {
    private struct State {
        var searchCalls = 0
        var queries: [String] = []
        var released = false
        var waiter: CheckedContinuation<Void, Never>?
    }

    private let state = Mutex(State())
    private let candidates: [StockPhotoCandidate]

    init(candidates: [StockPhotoCandidate] = []) {
        self.candidates = candidates
    }

    var searchCalls: Int { state.withLock { $0.searchCalls } }
    var queries: [String] { state.withLock { $0.queries } }

    @concurrent func searchPhotos(named query: String) async throws -> [StockPhotoCandidate] {
        let isFirstCall = state.withLock { state -> Bool in
            state.searchCalls += 1
            state.queries.append(query)
            return state.searchCalls == 1
        }
        if isFirstCall { await waitUntilReleased() }
        return candidates
    }

    @concurrent func imageData(from url: URL) async throws -> Data {
        Data()
    }

    private func waitUntilReleased() async {
        await withCheckedContinuation { continuation in
            let resumeNow = state.withLock { state -> Bool in
                guard !state.released else { return true }
                state.waiter = continuation
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func release() {
        let waiter = state.withLock { state -> CheckedContinuation<Void, Never>? in
            state.released = true
            defer { state.waiter = nil }
            return state.waiter
        }
        waiter?.resume()
    }
}

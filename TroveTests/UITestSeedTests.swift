import Foundation
import SwiftData
import Testing
@testable import Trove

/// Spec 003, Decision 9 and criterion 12: the seeded Sell Plan the UI test
/// and the device pass are verified against, and the two conditions the
/// constitution puts on a test-only branch that *adds* rows — the in-memory
/// bound is structural, and the seed takes its own second argument.
///
/// Each test is named for the mutation that turns it red (plan §7, G8–G11).
@Suite("UITestSeed")
struct UITestSeedTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private struct Seeded {
        let context: ModelContext
        let items: [String: Item]
        let wishlistItem: WishlistItem
    }

    // MARK: - G8, the gate

    /// The flag alone seeds nothing, and — the structural half — neither
    /// does every flag set against a store that is on disk. Mutation: gate on
    /// the arguments alone, and the two persistent modes go red.
    @Test func seedsOnlyTheInMemoryStoreAndOnlyWithItsOwnArgument() {
        let both = ["-uiTesting", UITestSeed.argument]

        #expect(UITestSeed.shouldSeed(mode: .ephemeral, arguments: both))

        #expect(
            !UITestSeed.shouldSeed(mode: .ephemeral, arguments: []),
            "an in-memory store with no arguments at all still needs the seed's own flag"
        )
        #expect(
            !UITestSeed.shouldSeed(mode: .ephemeral, arguments: ["-uiTesting"]),
            "-uiTesting alone must keep starting from an empty collection"
        )
        #expect(
            !UITestSeed.shouldSeed(mode: .cloudKit, arguments: both),
            "a synced store would be seeded with test data"
        )
        #expect(
            !UITestSeed.shouldSeed(mode: .localOnly, arguments: both),
            "an on-disk store would be seeded with test data"
        )
    }

    /// The app calls the seed once, under the guard, and still reads
    /// `-uiTesting` in exactly one place. Mutations: a second call outside the
    /// block; a second `-uiTesting` literal.
    @Test func theAppCallsTheSeedOnceUnderTheGuardAndReadsTheFlagOnce() throws {
        let code = try SourceScan.production("Trove/App/TroveApp.swift")

        #expect(code.ranges(of: "UITestSeed.sellPlan(").count == 1, "the seed is called more than once, or not at all")

        let guarded = SourceScan.closureBodies(after: "if UITestSeed.shouldSeed(mode: store.mode", in: code)
        try #require(guarded.count == 1, "TroveApp should gate the seed on shouldSeed(mode: store.mode …) exactly once")
        #expect(guarded[0].contains("UITestSeed.sellPlan("), "the seed call sits outside its guard")

        let literals = SourceScan.stringLiterals(in: code)
        #expect(literals.filter { $0 == "-uiTesting" }.count == 1, "-uiTesting is read in more than one place")
        #expect(!literals.contains(UITestSeed.argument), "the seed's argument is spelled in TroveApp — it lives in UITestSeed.argument alone")
    }

    // MARK: - G9, what the seed writes

    /// Through the production container pairing, so the local rows are proven
    /// to insert beside the collection's under the real configurations.
    @Test func theSeedFillsBothStoresThroughTheProductionContainer() throws {
        let seeded = try seed()

        #expect(try seeded.context.fetch(FetchDescriptor<Item>()).count == 4)
        #expect(try seeded.context.fetch(FetchDescriptor<WishlistItem>()).count == 1)
        #expect(seeded.wishlistItem.estimatedCostCents == 240_000)
        #expect(try seeded.context.fetch(FetchDescriptor<Item>()).filter { $0.reverbProductID != nil }.count == 3)
        #expect(seeded.items["Telecaster"]?.reverbProductID == 126_161)
        #expect(seeded.items["Squier Classic Vibe"]?.reverbProductID == nil, "the neutral candidate is unmatched")
        #expect(try seeded.context.fetch(FetchDescriptor<MarketMatchSnapshot>()).count == 3)
        #expect(try seeded.context.fetch(FetchDescriptor<MarketHistoryPoint>()).count == 6, "two readings per matched item")

        let figures = try seeded.context.fetch(FetchDescriptor<MarketFigureRecord>())
        #expect(figures.count == 3)
        #expect(figures.allSatisfy { $0.fetchedAt == now }, "the current reading is the one the row carries")
    }

    /// The stored trend is the one two refreshes would have left behind —
    /// equal to `compute` over the same history, and equal to what the seed
    /// set out to produce. Mutation: replace the Telecaster's second `record`
    /// call with a direct `MarketFigureRecord` insert carrying `"flat"`.
    @Test func everyStoredTrendIsTheComputedOneAndTheThreeAreUpFlatDown() throws {
        let seeded = try seed()
        let expected: [String: MarketTrend] = ["Telecaster": .up, "Blues Junior": .flat, "NT1-A": .down]

        for (name, trend) in expected {
            let item = try #require(seeded.items[name])
            let record = try #require(try MarketLocalStore.figure(for: item.id, in: seeded.context), "\(name) has no figure row")
            let history = try MarketLocalStore.historyEntries(for: item.id, in: seeded.context)
            #expect(history.count == 2, "\(name) should carry two readings")
            #expect(record.trendRawValue == MarketTrend.compute(history: history)?.rawValue, "\(name)'s stored trend disagrees with its history")
            #expect(record.trendRawValue == trend.rawValue, "\(name) was seeded as \(trend.rawValue)")
        }

        let squier = try #require(seeded.items["Squier Classic Vibe"])
        #expect(try MarketLocalStore.figure(for: squier.id, in: seeded.context) == nil, "the unmatched candidate has no market line")
    }

    /// The seed writes market rows only through the writer, so the figure,
    /// the history and the snapshot can't drift out of the shape a refresh
    /// leaves behind.
    @Test func theSeedConstructsNoLocalRowItself() throws {
        let code = try SourceScan.production("Trove/App/UITestSeed.swift")

        #expect(code.contains("MarketLocalStore.record("), "the seed writes no market rows at all")
        for constructor in ["MarketFigureRecord(", "MarketHistoryPoint(", "MarketMatchSnapshot("] {
            #expect(!code.contains(constructor), "the seed builds a \(constructor.dropLast()) directly instead of writing through MarketLocalStore.record")
        }
    }

    // MARK: - G11, the order the UI test reads

    /// The whole point of the values: the trend key disagrees with the value
    /// order at both ends. Mutation: drop the group key from `rank`, and this
    /// becomes Blues Junior, Telecaster, NT1-A, Squier.
    @Test func theSeededPlanRanksTheRisingCandidateFirstAndTheFallingOneLast() throws {
        let seeded = try seed()
        let viewModel = SellPlanViewModel(modelContext: seeded.context, wishlistItemID: seeded.wishlistItem.id, now: { self.now })

        viewModel.load()

        #expect(viewModel.candidates.map(\.name) == ["Telecaster", "Blues Junior", "Squier Classic Vibe", "NT1-A"])
        #expect(
            viewModel.candidates.map(\.currentValueCents) == [60_000, 64_000, 38_000, 40_000],
            "value alone would order these Blues Junior, Telecaster, NT1-A, Squier — the seed proves nothing if it doesn't"
        )

        let telecaster = try #require(seeded.items["Telecaster"])
        let rise = try #require(viewModel.rise(for: telecaster.id))
        #expect(rise.percent == 12)
        #expect(rise.since == now - 14 * day)
        for candidate in viewModel.candidates where candidate.id != telecaster.id {
            #expect(viewModel.rise(for: candidate.id) == nil, "\(candidate.name) draws a reason line it has no rise for")
        }
    }

    // MARK: - Private

    /// The seed run into a context over the container the app itself builds
    /// for a UI test launch — `TroveStore.make`, not a hand-rolled pair.
    private func seed() throws -> Seeded {
        let store = try TroveStore.make(isUITesting: true)
        try #require(store.mode == .ephemeral)

        try UITestSeed.sellPlan(into: ModelContext(store.container), now: now)

        // Read back through a *second* context over the same store, per
        // `makeInMemoryContainer`'s note: a same-context refetch hands back
        // objects carrying unsaved changes, so every assertion below would
        // hold with the seed's `save()` deleted. This one sees only what
        // actually reached the store.
        let context = ModelContext(store.container)
        let items = try context.fetch(FetchDescriptor<Item>())
        let wishlistItem = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)
        return Seeded(
            context: context,
            items: Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) }),
            wishlistItem: wishlistItem
        )
    }
}

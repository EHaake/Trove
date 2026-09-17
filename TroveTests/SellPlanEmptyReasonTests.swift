import Foundation
import SwiftData
import Testing
@testable import Trove

/// The Sell Plan's three empty reasons, and specifically the order they're
/// resolved in.
///
/// `EmptyStateTests` covers one clean example of each. This suite exists for
/// the case they don't cover: **the reasons overlap**, so more than one can be
/// true of the same collection, and which one the screen names is a decision
/// rather than a consequence. Raised at the Phase 9 review — the precedence was
/// only implicit in the order of two `guard`s, unlike the list screens', which
/// `ListEmptyReasonTests` had pinned from the start.
@Suite("Sell plan empty reason precedence")
struct SellPlanEmptyReasonTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try makeInMemoryContainer())
    }

    private func wanted(in context: ModelContext) -> WishlistItem {
        let item = WishlistItem(name: "Summicron 35mm", categoryPath: "Photography/Lenses")
        context.insert(item)
        return item
    }

    private let soldOn = Date(timeIntervalSince1970: 1_770_000_000)

    private func sale() -> Sale {
        Sale(date: soldOn, priceCents: 42_000, location: "Reverb", note: nil)
    }

    /// A monitor mid-first-import, built the way `StillSyncingTests` builds
    /// one — from a real event, not from a stubbed flag.
    private func importing() -> SyncMonitor {
        let monitor = SyncMonitor(mode: .cloudKit)
        monitor.record(SyncEvent(kind: .importChanges, isFinished: false, succeeded: false))
        return monitor
    }

    // MARK: - The overlap

    /// Both true at once: nothing is rated low enough to sell, *and* nothing
    /// has a value. Desire wins.
    ///
    /// Someone unwilling to part with anything doesn't have a pricing problem.
    /// Telling them "nothing has a value yet" sends them off to price a
    /// collection they've already said they're keeping — work that wouldn't
    /// put a single row on this screen.
    @Test func desireWinsWhenNothingIsRatedLowAndNothingIsValued() throws {
        let context = try makeContext()
        let wishlistItem = wanted(in: context)
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras", desireToKeep: 5))
        context.insert(Item(name: "Hasselblad", categoryPath: "Photography/Cameras", desireToKeep: 4))

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wishlistItem.id)
        viewModel.load()

        #expect(viewModel.emptyReason == .everythingIsAKeeper)
    }

    /// The same overlap one step up: with nothing owned at all, every other
    /// reason is vacuously true too. `nothingOwned` outranks both, for the same
    /// reason `nothingAdded` outranks every list filter — naming a rule to
    /// someone with an empty collection is advice they can't act on.
    @Test func nothingOwnedOutranksBothOtherReasons() throws {
        let context = try makeContext()
        let wishlistItem = wanted(in: context)

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wishlistItem.id)
        viewModel.load()

        #expect(viewModel.emptyReason == .nothingOwned)
    }

    // MARK: - The unambiguous cases

    /// Only reachable when desire has already been satisfied by something:
    /// one item rated low enough, missing only a value.
    @Test func valueIsNamedOnlyWhenDesireIsAlreadySatisfied() throws {
        let context = try makeContext()
        let wishlistItem = wanted(in: context)
        context.insert(Item(name: "Squier CV50s", categoryPath: "Music/Guitars", desireToKeep: 1))

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wishlistItem.id)
        viewModel.load()

        #expect(viewModel.emptyReason == .nothingValued)
    }

    /// A low-desire item with a value is a candidate, so there's no empty
    /// state at all — the boundary the three reasons sit behind.
    @Test func oneQualifyingItemEndsTheEmptyState() throws {
        let context = try makeContext()
        let wishlistItem = wanted(in: context)
        context.insert(Item(name: "Squier CV50s", categoryPath: "Music/Guitars",
                            currentValueCents: 38_000, desireToKeep: 1))
        context.insert(Item(name: "Leica M6", categoryPath: "Photography/Cameras", desireToKeep: 5))

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wishlistItem.id)
        viewModel.load()

        #expect(viewModel.emptyReason == nil)
    }

    // MARK: - The plan emptied by selling (spec Decision 15)

    /// Every candidate sold, nothing owned left: the plan says so rather than
    /// opening with the first-launch invitation above a list of the sales
    /// that emptied it.
    @Test func aPlanWhoseEveryCandidateSoldSaysSo() throws {
        let context = try makeContext()
        let wishlistItem = wanted(in: context)
        let item = Item(name: "Squier CV50s", categoryPath: "Music/Guitars",
                        currentValueCents: 38_000, desireToKeep: 1)
        context.insert(item)
        try ItemSaleStore.markSold(item, sale: sale(), toward: wishlistItem, at: soldOn, in: context)
        try context.save()

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wishlistItem.id)
        viewModel.load()

        #expect(viewModel.hasSales)
        #expect(viewModel.emptyReason == .everythingSold)
    }

    /// The boundary the mapping sits behind: an empty collection with no sale
    /// on this plan is still a first launch, and still gets the first-launch
    /// words. Nothing sold, nothing to say sold.
    @Test func aPlanWithNoSalesKeepsTheFirstLaunchReason() throws {
        let context = try makeContext()
        let wishlistItem = wanted(in: context)

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wishlistItem.id)
        viewModel.load()

        #expect(!viewModel.hasSales)
        #expect(viewModel.emptyReason == .nothingOwned)
    }

    /// `stillSyncing` keeps outranking the new case as it outranks the other
    /// three: an owned side that looks empty mid-import may just be gear that
    /// hasn't arrived, and "everything on this plan has sold" is exactly as
    /// wrong there as "nothing to sell yet". The sale is real either way — the
    /// claim about what is *left* is the one that can't be made yet.
    @Test func anImportInFlightOutranksTheSoldOutPlan() throws {
        let context = try makeContext()
        let wishlistItem = wanted(in: context)
        let item = Item(name: "Squier CV50s", categoryPath: "Music/Guitars",
                        currentValueCents: 38_000, desireToKeep: 1)
        context.insert(item)
        try ItemSaleStore.markSold(item, sale: sale(), toward: wishlistItem, at: soldOn, in: context)
        try context.save()

        let viewModel = SellPlanViewModel(
            modelContext: context,
            wishlistItemID: wishlistItem.id,
            syncMonitor: importing()
        )
        viewModel.load()

        #expect(viewModel.hasSales)
        #expect(viewModel.emptyReason == .stillSyncing)
    }

    /// The threshold itself comes from `DesireLevel`, not from a number
    /// re-derived here — 3 qualifies, 4 doesn't. If that boundary ever moves,
    /// this suite's other cases move with it rather than quietly testing an
    /// old rule.
    @Test func theThresholdIsTheSharedOne() throws {
        let context = try makeContext()
        let wishlistItem = wanted(in: context)
        context.insert(Item(name: "Schiit Vali", categoryPath: "Audio/Amps", desireToKeep: 3))

        let viewModel = SellPlanViewModel(modelContext: context, wishlistItemID: wishlistItem.id)
        viewModel.load()

        #expect(
            viewModel.emptyReason == .nothingValued,
            "Desire 3 should count as willing-to-sell, per DesireLevel.isSellCandidate"
        )
    }
}

import Foundation
import Observation
import SwiftData

/// The Sell Plan for one wishlist item: which owned gear the user is weighing
/// selling toward it.
///
/// **Advisory, not goal-directed.** spec.md is emphatic and the shape of this
/// type follows from it: the plan starts empty, nothing is auto-selected, and
/// there is no target to reach. The question it answers is "if I sold something
/// toward this, what would make sense" — not "have I covered the cost yet".
///
/// The clearest expression of that is what this type deliberately *doesn't*
/// have: no surplus, no shortfall, no remaining-to-go. `selectedValueCents` and
/// `estimatedCostCents` are two separate figures the view places side by side,
/// and the user draws their own conclusion. Collapsing them into one signed
/// number would read as tidier code and would smuggle back the framing an
/// earlier revision of this spec was corrected for — a single figure captioned
/// "surplus or shortfall" tells the user they were supposed to close a gap.
/// `SellPlanFramingTests` guards that rather than trusting this comment.
@Observable
final class SellPlanViewModel {
    /// Owned gear worth offering, ranked. See `SellPlanRanking` for the order.
    private(set) var candidates: [Item] = []

    /// Held as ids rather than as `Item` references so membership is a cheap,
    /// identity-free lookup — two fetches can hand back different instances of
    /// the same row.
    private(set) var selectedIDs: Set<UUID> = []

    private(set) var wishlistItem: WishlistItem?
    private(set) var hasLoaded = false
    private(set) var loadFailureMessage: String?
    private(set) var saveFailureMessage: String?

    /// A refused purchase (015 T012b). Its own property rather than the
    /// share of `saveFailureMessage` §6 gave it: that was right while both
    /// were invisible, but the purchase alert this screen now shows would
    /// read a refused *sale* out of a shared property, and this spec's
    /// non-goals forbid any change to the sale sheet or the sold side.
    /// Settable so the alert's binding can clear it on OK, the
    /// `exportFailureMessage` shape; `markSold` is untouched.
    var purchaseFailureMessage: String?

    /// The device's own market figures for the owned items, keyed by item —
    /// one fetch per `load()`, the same step every other row surface goes
    /// through (`MarketSummary.summaries(forSubjects:in:now:)`), so this
    /// screen can never derive a figure differently from the item list.
    private(set) var marketSummaries: [UUID: MarketSummary] = [:]

    /// The reason line's numbers, for the rising candidates only (003 plan
    /// Q3). A candidate that isn't rising has no entry at all, so a row can't
    /// draw a rise beside a flat or falling arrow.
    private(set) var rises: [UUID: MarketRise] = [:]

    /// The clock the figures' freshness was measured against on the last
    /// `load()` — the row's dates read this rather than calling `Date()`
    /// again, so everything on screen agrees about "now".
    private(set) var loadedAt: Date

    private let modelContext: ModelContext
    private let wishlistItemID: UUID

    private let syncMonitor: SyncMonitor

    private let now: () -> Date

    /// Where the history behind a rise comes from. Injected as a closure over
    /// the local store rather than as a protocol because it's one read with
    /// no state of its own — the `TroveStore.make(recreateLocalStore:)` shape
    /// — and a test needs it to throw far more than it needs it to be a type.
    private let history: (UUID, ModelContext) throws -> [MarketHistoryEntry]

    /// - Parameters:
    ///   - now: the clock the market figures' freshness is measured against
    ///     (002/T012), injected so a test can age a figure past the thirty-day
    ///     window without waiting a month.
    ///   - history: the item's history points, for the rise behind a rising
    ///     candidate. Defaults to the device-local store.
    init(
        modelContext: ModelContext,
        wishlistItemID: UUID,
        syncMonitor: SyncMonitor = .notSyncing,
        now: @escaping () -> Date = Date.init,
        history: @escaping (UUID, ModelContext) throws -> [MarketHistoryEntry] = { try MarketLocalStore.historyEntries(for: $0, in: $1) }
    ) {
        self.modelContext = modelContext
        self.wishlistItemID = wishlistItemID
        self.syncMonitor = syncMonitor
        self.now = now
        self.history = history
        self.loadedAt = now()
    }

    // MARK: - The two figures

    /// What the wishlist item is expected to cost. The user's own estimate.
    var estimatedCostCents: Int {
        wishlistItem?.estimatedCostCents ?? 0
    }

    /// Combined current value of what's selected.
    ///
    /// Un-valued items contribute nothing rather than counting as zero — the
    /// same floor-not-total rule the dashboard and the item list header use.
    /// They can't normally be selected (the pool excludes them), but an item
    /// already on the plan can lose its value later.
    var selectedValueCents: Int {
        selectedItems.compactMap(\.currentValueCents).reduce(0, +)
    }

    var selectedCount: Int { selectedIDs.count }

    /// Whether the selection reaches the estimate — for the quiet colour cue
    /// spec.md permits, and nothing else.
    ///
    /// A boolean rather than a figure, deliberately. The spec allows "one tone
    /// once selected value meets or exceeds the cost, another when it doesn't"
    /// while forbidding copy that urges the user to close the gap; a tone needs
    /// a side, not a distance. Naming it for what's true rather than for what's
    /// left to do keeps it from growing a caption.
    ///
    /// Sales sit on the same side as the selection (006 plan Q14): money
    /// already raised toward this wishlist item is no less real than money a
    /// selection would raise, and a cue that ignored it would read as unmet on
    /// a plan the person has already funded by selling. Still one boolean and
    /// still no third figure — the name is kept so the framing guard keeps its
    /// target.
    var selectedValueMeetsCost: Bool {
        (selectedCount + soldCount) > 0
            && selectedValueCents + soldValueCents >= estimatedCostCents
    }

    // MARK: - The Sold figure

    /// What has already been sold toward this wishlist item, most recent sale
    /// first.
    ///
    /// Read off `wishlistItem.itemsSoldToward` rather than fetched over every
    /// sold item (006 plan Q14): the link is the fact (spec P5), and reading
    /// the relationship is how this type already reads `plannedSaleItems`, so
    /// the two halves of the plan have one shape. The order is
    /// `ItemListViewModel.areInSoldOrder` — the Sold side's own comparator, so
    /// this section and the item list can't disagree about which sale is the
    /// most recent, and two sales on one day can't reshuffle between visits.
    var soldItems: [Item] {
        (wishlistItem?.itemsSoldToward ?? []).sorted(by: ItemListViewModel.areInSoldOrder)
    }

    var soldCount: Int { soldItems.count }

    /// What those sales actually brought in: `salePriceCents`, the figure the
    /// person recorded, never a current value — the sale is settled and the
    /// market has nothing left to say about it. `SellPlanSummary.soldCents`
    /// is the one sum, so this figure and the Plans rows' covered marker
    /// cannot read different ones (009 plan Q5).
    var soldValueCents: Int {
        SellPlanSummary.soldCents(of: soldItems)
    }

    /// Whether the screen carries the third figure and the Sold section at
    /// all. A plan with no sales stays the two-figure screen it was.
    var hasSales: Bool { soldCount > 0 }

    var isEmpty: Bool { candidates.isEmpty }

    // MARK: - The completed record (009)

    /// The wanted entry has been bought, so this plan is a record — what sold
    /// toward it and when it was bought — and nothing on it acts (009 plan
    /// Q11). Gated here rather than by the stores' refusals: `toggle`,
    /// `markSold` and `load()` read it, and the view branches on it.
    var isCompleted: Bool { wishlistItem?.isBought == true }

    /// Whether the screen offers Mark as bought… — only on a loaded plan whose
    /// entry is still wanted. `WishlistPurchaseStore`'s refusal stays the
    /// backstop, never the thing that hides the action.
    var offersPurchase: Bool { wishlistItem != nil && !isCompleted }

    /// Whether there is a plan to delete, on either side.
    var offersDelete: Bool { wishlistItem?.hasSellPlan == true }

    /// When the entry was bought, for the record's date line; nil while it is
    /// still wanted.
    var boughtDate: Date? { wishlistItem?.boughtDate }

    /// Why the pool is empty, so the screen can name the missing half rather
    /// than reciting both rules at someone who only needs one.
    ///
    /// Qualifying takes two things — desire-to-keep of 3 or lower, and a
    /// current value — and which one is missing decides what the user should go
    /// and do. This was already promised in prose on `SellPlanView`'s empty
    /// state ("says which, since the two have different fixes") and never
    /// actually implemented; T047a is where the code caught up with the
    /// comment.
    enum EmptyReason: Equatable {
        /// No owned gear at all.
        case nothingOwned
        /// Everything is rated 4 or 5 — nothing the user is relaxed about.
        case everythingIsAKeeper
        /// Willing to part with things, but none of them has a value yet.
        case nothingValued
        /// The owned items this screen reasons over may not all have arrived
        /// yet — see `ListEmptyReason.stillSyncing`.
        case stillSyncing

        /// The pool is empty because every item on this plan has been sold
        /// (spec Decision 15) — the Items-tab `ListEmptyReason.everythingSold`
        /// one screen over, and the same misreading it exists to prevent.
        ///
        /// Never returned by the precedence chain in `poolEmptyReason`: that
        /// rule reasons over owned gear alone and knows nothing about the
        /// sales beneath it. `emptyReason` maps the `nothingOwned` it hands
        /// back to this when the plan has sales, so the order there — the
        /// import outranking every diagnosis, desire outranking value — stays
        /// exactly as it was. Someone whose plan emptied by selling has been
        /// doing the thing the screen asks for, and "Add the gear you own"
        /// reads as though none of it happened.
        case everythingSold
    }

    private(set) var ownedCount = 0

    /// Bumped each time an import lands, so the screen can refetch — see
    /// `SyncMonitor.completedImports`.
    var completedImports: Int { syncMonitor.completedImports }
    private(set) var lowDesireCount = 0

    /// **The cases overlap, and the order below is the answer.** With nothing
    /// rated low enough, it's also trivially true that nothing rated low enough
    /// has a value — so `everythingIsAKeeper` and `nothingValued` both describe
    /// that collection, and one of them has to win.
    ///
    /// Desire wins, because it's the more fundamental miss: someone unwilling
    /// to part with anything doesn't have a pricing problem, and telling them
    /// to go and value things would send them off to do work that changes
    /// nothing. The reverse reading — "nothing has a value" to someone who
    /// never said they'd sell — is advice for a situation they aren't in.
    ///
    /// `SellPlanEmptyReasonTests` pins this the way `ListEmptyReasonTests`
    /// pins the list screens' precedence, rather than leaving it implicit in
    /// the order of two `guard`s.
    ///
    /// Spec Decision 15 sits on top of that rule rather than inside it, the
    /// way `ItemListViewModel.ownedEmptyReason` layers Decision 12 over the
    /// shared `ListEmptyReason.reason`. The chain decides everything first —
    /// which is what keeps `stillSyncing` winning while the collection may
    /// still be arriving — and only the `nothingOwned` it hands back is
    /// reconsidered, and only when this plan has sales beneath it.
    var emptyReason: EmptyReason? {
        let reason = poolEmptyReason
        guard reason == .nothingOwned, hasSales else { return reason }
        return .everythingSold
    }

    /// The pool's own reason, over owned gear only — Decision 15's mapping is
    /// `emptyReason`'s, above.
    private var poolEmptyReason: EmptyReason? {
        guard candidates.isEmpty else { return nil }
        // Outranks all three, unlike the list screens where the filtered cases
        // win: none of these is feedback on something the user just typed —
        // each is a claim about the whole collection, and mid-import this
        // screen hasn't seen the whole collection. "Everything is a keeper" is
        // as wrong as "you own nothing" when the low-desire items are the ones
        // still in flight.
        guard !syncMonitor.mayStillBeImporting else { return .stillSyncing }
        guard ownedCount > 0 else { return .nothingOwned }
        guard lowDesireCount > 0 else { return .everythingIsAKeeper }
        // Something is rated low enough, so the only reason it isn't here is
        // the value — every low-desire item is missing one.
        return .nothingValued
    }

    // MARK: - Loading

    func load() {
        loadFailureMessage = nil
        do {
            // By id, unchanged by 015 (plan §4): R2's job, not this fetch's.
            let id = wishlistItemID
            var descriptor = FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            let wanted = try modelContext.fetch(descriptor).first
            wishlistItem = wanted

            // Whatever was persisted, and only that. No auto-selection: the
            // plan stays empty until the user picks something.
            let planned = wanted?.plannedSaleItems ?? []
            selectedIDs = Set(planned.map(\.id))

            // A completed plan is a record, not a pool (009 plan §6): no
            // owned fetch, no candidates, nothing to rank or figure.
            guard !isCompleted else {
                ownedCount = 0
                lowDesireCount = 0
                loadedAt = now()
                marketSummaries = [:]
                candidates = []
                rises = [:]
                hasLoaded = true
                return
            }

            // Sold gear leaves this screen before anything is counted (006
            // plan §3): a sold item is never a candidate, and it reaches
            // neither `ownedCount` nor `lowDesireCount`, so the empty reasons
            // describe the collection the person could actually offer rather
            // than one padded with gear that is already gone.
            let owned = try modelContext.fetch(FetchDescriptor<Item>()).filter { !$0.isSold }
            ownedCount = owned.count
            lowDesireCount = owned.count { DesireLevel(clamping: $0.desireToKeep).isSellCandidate }

            loadedAt = now()
            // Before the sort, not after: the order reads these (002/T012 —
            // the list's market sorts learned the same lesson the hard way).
            marketSummaries = MarketSummary.summaries(forSubjects: owned.map(\.id), in: modelContext, now: loadedAt)
            candidates = Self.candidates(from: owned, alreadySelected: selectedIDs, trend: { self.currentTrend(for: $0) })
            rises = risesForRisingCandidates()
        } catch {
            loadFailureMessage = error.localizedDescription
            ownedCount = 0
            lowDesireCount = 0
            candidates = []
            selectedIDs = []
            wishlistItem = nil
            marketSummaries = [:]
            rises = [:]
        }
        hasLoaded = true
    }

    /// The reason numbers, derived once per `load()` for the candidates the
    /// stored trend already calls rising.
    ///
    /// The history read is `try?` and a failure yields no entry: the device's
    /// market rows are an addition to the collection, so a local-store problem
    /// must cost a sentence, never a candidate (the 002 direction
    /// `MarketSummary.summaries` takes for the figures themselves). The
    /// comparison must agree that it's a rise — `MarketRise.init` is failable
    /// on exactly that — so a history that no longer says `.up` draws nothing
    /// rather than contradicting the arrow beside it.
    private func risesForRisingCandidates() -> [UUID: MarketRise] {
        var found: [UUID: MarketRise] = [:]
        for candidate in candidates where currentTrend(for: candidate.id) == .up {
            found[candidate.id] = (try? history(candidate.id, modelContext))
                .flatMap(MarketTrend.comparison)
                .flatMap(MarketRise.init)
        }
        return found
    }

    // MARK: - What the rows read

    /// The item's figure, or nil when it's unmatched or nothing was fetched
    /// for it on this device.
    func summary(for id: UUID) -> MarketSummary? {
        marketSummaries[id]
    }

    /// The trend the row draws *and* ranks by — `currentTrend`, so a withheld
    /// or no-longer-current figure is neutral and silent rather than carrying
    /// a stale classification (003 plan Q2).
    func currentTrend(for id: UUID) -> MarketTrend? {
        marketSummaries[id]?.currentTrend
    }

    /// The rise behind a rising row's reason line, or nil for every other row.
    func rise(for id: UUID) -> MarketRise? {
        rises[id]
    }

    /// The pool, ranked — plus anything already on the plan that no longer
    /// qualifies.
    ///
    /// That second part isn't in plan.md, which doesn't say what happens when a
    /// selected item drifts out of the pool: raise its desire-to-keep to 4, or
    /// clear its value, and it stops being a candidate while staying on the
    /// plan. Dropping it from the list would strand it — still counted, with no
    /// row to switch it off from. Keeping it visible means every selection is
    /// reversible, which matters more than a tidy pool.
    static func candidates(
        from owned: [Item],
        alreadySelected: Set<UUID>,
        trend: (UUID) -> MarketTrend? = { _ in nil }
    ) -> [Item] {
        owned
            .filter { qualifies($0) || alreadySelected.contains($0.id) }
            .sorted { SellPlanRanking.rank($0, $1, trend: trend) }
    }

    /// Owned gear the user has already said they're relaxed about, with a value
    /// to weigh.
    ///
    /// The threshold comes from `DesireLevel.isSellCandidate`, never from a
    /// `<= 3` written here. plan.md added that property specifically so this
    /// filter and the item screens can't drift apart about what "would let it
    /// go" means.
    static func qualifies(_ item: Item) -> Bool {
        DesireLevel(clamping: item.desireToKeep).isSellCandidate
            && item.currentValueCents != nil
    }

    // MARK: - Selecting

    func isSelected(_ item: Item) -> Bool {
        selectedIDs.contains(item.id)
    }

    /// Adds or removes a candidate, persisting immediately — no separate save
    /// step, consistent with the app's low-friction bar.
    func toggle(_ item: Item) {
        saveFailureMessage = nil
        // A completed plan has no selection to change (009 plan Q11).
        guard let wishlistItem, !isCompleted else { return }

        var planned = wishlistItem.plannedSaleItems ?? []
        if selectedIDs.contains(item.id) {
            planned.removeAll { $0.id == item.id }
            selectedIDs.remove(item.id)
        } else {
            planned.append(item)
            selectedIDs.insert(item.id)
        }
        wishlistItem.plannedSaleItems = planned

        do {
            try modelContext.save()
        } catch {
            saveFailureMessage = error.localizedDescription
        }
    }

    /// The selected rows, in the order they appear on screen.
    private var selectedItems: [Item] {
        candidates.filter { selectedIDs.contains($0.id) }
    }

    // MARK: - Marking a candidate sold

    /// The row whose sale sheet is up — `.sheet(item:)` state, which the view
    /// sets both ways.
    var saleCandidate: Item?

    /// Mark as sold… from a row: the sale points at this plan (spec P5), the
    /// item leaves the candidates, and the figures re-derive.
    ///
    /// `ItemSaleStore` is the one writer (006 plan Q3) and callers save — the
    /// `toggle(_:)` shape, one intent, one immediate save, no separate step.
    /// The store drops every plan selection itself, so the item is on no
    /// selection by the time `load()` re-reads them; `load()` also drops it
    /// from the pool, since it is sold now.
    ///
    /// Returns false on a refused save, which rolls back.
    @discardableResult
    func markSold(_ item: Item, sale: Sale) -> Bool {
        saveFailureMessage = nil
        // Nothing is sold from a completed plan's record (009 plan Q11).
        guard !isCompleted else { return false }
        do {
            try ItemSaleStore.markSold(item, sale: sale, toward: wishlistItem, at: now(), in: modelContext)
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared
            // context, not only this intent's — the same recovery
            // `ItemDetailViewModel` uses. The reload below then shows what is
            // actually stored, which is the screen as it was: the row is still
            // a candidate and no sale is listed.
            modelContext.rollback()
            saveFailureMessage = error.localizedDescription
            load()
            return false
        }
        load()
        return true
    }

    /// The sheet's view model for a row, seeded exactly as the detail screen
    /// seeds its own Mark as sold sheet (spec P1): mode `.mark`, nothing to
    /// pre-fill, the price from the item's current value when it has one and
    /// blank when it doesn't, today's date. One seeding rule for both hosts —
    /// the clock is this screen's injected one, so a test can pin the date.
    func makeSaleFormViewModel(for item: Item) -> SaleFormViewModel {
        SaleFormViewModel(mode: .mark, prefill: nil, currentValueCents: item.currentValueCents, now: now)
    }

    // MARK: - Marking this plan's wanted entry bought (015)

    /// The purchase sheet, seeded exactly as the Wishlist row's and the
    /// wanted-entry page's are (plan Q10): the price from the entry's
    /// estimated cost when it has one and blank when it doesn't — never a
    /// pre-filled $0, the 006 P1 rule — and today's date from this screen's
    /// injected clock. No argument: the subject is this plan's own
    /// `wishlistItem`. G12 pins the three hosts equal.
    func makePurchaseFormViewModel() -> PurchaseFormViewModel {
        PurchaseFormViewModel(estimatedCostCents: estimatedCostCents, now: now)
    }

    /// Mark as bought… from the plan: the entry becomes an owned item, its
    /// remaining selections are released by the store, and this screen
    /// dismisses (plan R2).
    ///
    /// `WishlistPurchaseStore` is the one writer (015 plan Q4) and callers
    /// save — the `markSold(_:sale:)` shape beside it, one intent, one
    /// immediate save. **No reload on success**, unlike its neighbour: the
    /// screen is going away, and re-deriving a plan whose subject has just
    /// been bought would only repopulate it to be thrown out.
    ///
    /// Reports a refusal in `purchaseFailureMessage`, its own property and
    /// not `markSold`'s `saveFailureMessage` (T012b). §6 shared the two
    /// because two intents on one screen should read alike, which was right
    /// while neither was rendered; now that this one has an alert, sharing
    /// would surface a refused *sale* through it, and this spec's non-goals
    /// forbid any change to the sale sheet or the sold side. Neither
    /// property is cleared by `load()`, so the message still outlives the
    /// reload below.
    ///
    /// Returns false on a refused save, which rolls back.
    @discardableResult
    func markBought(purchase: Purchase) -> Bool {
        purchaseFailureMessage = nil
        guard let wishlistItem else {
            // T012e: not silent. The toolbar gate makes this near
            // unreachable — but the entry can vanish from another device
            // while the sheet is already open, and a confirm that closes the
            // sheet saying nothing is exactly the state T012b existed to
            // remove. `failureMessage` rather than `alreadyBought`: nothing
            // is known about why the entry is gone, and "Nothing was
            // changed" is true of this path — it returns ahead of every
            // write.
            purchaseFailureMessage = PurchaseCopy.failureMessage
            return false
        }
        do {
            try WishlistPurchaseStore.markBought(wishlistItem, purchase: purchase, at: now(), in: modelContext)
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared
            // context, not only this intent's — the same recovery `markSold`
            // uses. The reload below then shows what is actually stored: the
            // plan as it was, with its selections intact.
            modelContext.rollback()
            // Which refusal it was, since the two read nothing alike: an
            // entry bought on another device mid-screen (B1, the one a
            // person can actually meet) against a failed write.
            purchaseFailureMessage = error as? WishlistPurchaseStore.PurchaseError == .alreadyBought
                ? PurchaseCopy.alreadyBought
                : PurchaseCopy.failureMessage
            load()
            return false
        }
        return true
    }

    // MARK: - Deleting the plan (009)

    /// Delete this plan, on either side: the plan and its selection go, and
    /// nothing else — every item, the sold-toward record and the entry itself
    /// stay (spec criteria 10–12).
    ///
    /// `SellPlanStore` is the one writer (009 plan Q4) and callers save — the
    /// `markSold(_:sale:)` shape beside it, one intent, one immediate save,
    /// and a reload so the screen shows what is stored. Returns false, writing
    /// nothing, with no plan loaded, and on a refused save, which rolls back.
    @discardableResult
    func deletePlan() -> Bool {
        saveFailureMessage = nil
        guard let wishlistItem else { return false }
        do {
            SellPlanStore.delete(planOf: wishlistItem, at: now())
            try modelContext.save()
        } catch {
            // `rollback()` discards every pending change on the shared
            // context, not only this intent's — the same recovery `markSold`
            // uses; the reload shows the plan as it is still stored.
            modelContext.rollback()
            saveFailureMessage = error.localizedDescription
            load()
            return false
        }
        load()
        return true
    }
}

/// The order the plan lists candidates in (003 plan Q1).
///
/// Least-wanted first; then the trend, so what the market is doing decides
/// between two items you feel the same about; then the more valuable, since
/// between two you feel the same about and the market agrees on, the one that
/// raises more is the better suggestion.
///
/// Falls through to name then id so the order is fully determined by the data
/// — `FetchDescriptor` promises no ordering, and a list that reshuffles equal
/// rows between visits looks broken.
///
/// MainActor (the project's default) rather than `nonisolated`: it compares
/// `Item`, a `@Model`, which `nonisolated` code cannot touch.
enum SellPlanRanking {
    /// Rising first, falling last, everything else in the middle.
    ///
    /// No trend and a flat one are deliberately **one** group, not two: the
    /// spec ranks an unmatched item, one with too little history, and one
    /// whose figure is no longer current exactly where a flat one sits —
    /// nothing about them is guessed, in either direction.
    static func group(of trend: MarketTrend?) -> Int {
        switch trend {
        case .up: 0
        case .flat, nil: 1
        case .down: 2
        }
    }

    /// - Parameter trend: the trend to rank an item by, taken as a closure so
    ///   the whole order is testable against a dictionary. Its default of no
    ///   trend anywhere is 001's order exactly.
    static func rank(_ lhs: Item, _ rhs: Item, trend: (UUID) -> MarketTrend?) -> Bool {
        // Desire outranks the trend: the market never promotes something the
        // user said they want to keep above something they'd let go.
        if lhs.desireToKeep != rhs.desireToKeep {
            return lhs.desireToKeep < rhs.desireToKeep
        }
        let leftGroup = group(of: trend(lhs.id))
        let rightGroup = group(of: trend(rhs.id))
        if leftGroup != rightGroup {
            return leftGroup < rightGroup
        }
        if lhs.currentValueCents != rhs.currentValueCents {
            // An item with no value sorts last among its equals rather than as
            // zero — it's unknown, not worthless.
            guard let left = lhs.currentValueCents else { return false }
            guard let right = rhs.currentValueCents else { return true }
            return left > right
        }
        let byName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if byName != .orderedSame {
            return byName == .orderedAscending
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

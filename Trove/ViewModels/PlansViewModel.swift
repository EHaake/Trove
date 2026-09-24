import Foundation
import Observation
import SwiftData

/// The Plans tab (009, plan §5): every sell plan, split into the ones still
/// waiting on their purchase and the ones whose wanted item has been bought.
///
/// `ItemListViewModel`'s two-sided shape: one fetch per `load()`, split once;
/// `show(_:)` is the only way the side changes and it clears nothing, so each
/// side keeps its own sort across visits within a launch (criterion 5). The
/// side and both sorts are plain state, never stored — every launch opens on
/// Active with both sorts at Newest.
///
/// Membership reads the stored plan, never the selection (spec Decision 1): a
/// plan whose every item has been sold is still a plan, still active
/// (criterion 2).
@Observable
final class PlansViewModel {
    /// Which half of the tab is on screen.
    enum Side: Hashable {
        case active
        case completed
    }

    /// The Active side's Sort By (plan Q9). "Newest"/"Oldest" read the date
    /// the plan was created.
    enum ActiveSortOrder: String, CaseIterable, Identifiable {
        case newest
        case oldest
        case name
        case wishlistOrder

        var id: String { rawValue }

        /// What the sort control calls this — on the enum, the
        /// `SoldSortOrder.label` pattern.
        var label: String {
            switch self {
            case .newest: "Newest"
            case .oldest: "Oldest"
            case .name: "Name"
            case .wishlistOrder: "Wishlist order"
            }
        }
    }

    /// The Completed side's Sort By (plan Q9). "Newest"/"Oldest" read the
    /// **date bought** here, not the plan's own date.
    enum CompletedSortOrder: String, CaseIterable, Identifiable {
        case newest
        case oldest
        case name

        var id: String { rawValue }

        var label: String {
            switch self {
            case .newest: "Newest"
            case .oldest: "Oldest"
            case .name: "Name"
            }
        }
    }

    /// The screen's own empty reasons (plan Q10) — not `ListEmptyReason`,
    /// which is about narrowing a list, and this screen narrows nothing.
    enum EmptyReason: Equatable {
        case noPlans
        case nothingWanted
        case nothingCompleted
        case stillSyncing
    }

    /// One row, as a value (plan Q8): it declares no money field, so no row
    /// is handed a figure to draw (criterion 8). It carries the row's photos,
    /// never the `Item` they came from (Amendment A, QA2) — though that is no
    /// type-level wall, since `Photo.item` reaches the item's prices;
    /// `PlansWiringTests.theScreenDrawsNoMoneyAndReachesNoStore` is what keeps
    /// money off the row.
    struct PlanRow: Identifiable {
        let id: UUID
        let name: String
        let categoryPath: String
        /// The picture every row draws (Amendment A, criterion 20): an active
        /// row's are its wanted entry's; a completed row's are the bought
        /// item's, read through `boughtItem` and never from the entry (RA1) —
        /// empty when the purchase recorded no item or that item was deleted,
        /// so the row draws the placeholder.
        let photos: [Photo]
        /// `SellPlanSummary.rowLines` for the entry — which counts show is
        /// decided here, not in the view (criterion 7).
        let lines: [String]
        let boughtDate: Date?

        var isCompleted: Bool { boughtDate != nil }
    }

    /// Read-only from outside: `show(_:)` is the only way it changes, because
    /// changing side also reloads.
    private(set) var side: Side = .active
    /// Read-only from outside, like `side`: `setActiveSort(_:)` and
    /// `setCompletedSort(_:)` are the only ways they change, because changing
    /// an order also reloads (plan §5, as amended at Phase 4's review).
    private(set) var activeSortOrder: ActiveSortOrder = .newest
    private(set) var completedSortOrder: CompletedSortOrder = .newest
    private(set) var activeRows: [PlanRow] = []
    private(set) var completedRows: [PlanRow] = []

    var rows: [PlanRow] { side == .active ? activeRows : completedRows }

    /// Which empty state applies to the side on screen, or `nil` when it has
    /// rows (plan Q10, criterion 16).
    ///
    /// `stillSyncing` outranks the others, since each is a claim about the
    /// whole collection: it is chosen while the monitor may still be importing
    /// **or** while any entry still awaits the carry-over — an offline
    /// signed-in device is not importing, yet has plans still to carry, and
    /// "No sell plans yet" would be the wrong diagnosis (plan R7).
    var emptyReason: EmptyReason? {
        guard rows.isEmpty else { return nil }
        if syncMonitor.mayStillBeImporting || anyAwaitsCarryOver { return .stillSyncing }
        switch side {
        case .active: return unboughtCount == 0 ? .nothingWanted : .noPlans
        case .completed: return .nothingCompleted
        }
    }

    /// What the sort badge shows for the side on screen — each side carries
    /// its own selection.
    var visibleSortLabel: String {
        side == .active ? activeSortOrder.label : completedSortOrder.label
    }

    /// A refused purchase — the fourth host's own property, `015` T012b's
    /// shape: no `load()` clears it, so the reload the sheet's dismissal
    /// triggers can't wipe it before the alert reads it. Settable so the
    /// alert's binding can clear it on OK.
    var purchaseFailureMessage: String?

    /// Bumped each time an import lands — see `SyncMonitor.completedImports`.
    var completedImports: Int { syncMonitor.completedImports }

    /// Bumped each time the carry-over has run — see
    /// `SyncMonitor.settledCount`. The screen reloads on both (plan Q3).
    var settledCount: Int { syncMonitor.settledCount }

    private let modelContext: ModelContext
    private let syncMonitor: SyncMonitor
    private let now: () -> Date

    /// Wanted entries not yet bought, for `noPlans` against `nothingWanted`.
    private var unboughtCount = 0

    /// Whether any entry is an older row the carry-over will make a plan of.
    private var anyAwaitsCarryOver = false

    /// The planned entries behind the rows, by id, for the two intents.
    private var entries: [UUID: WishlistItem] = [:]

    /// - Parameters:
    ///   - syncMonitor: defaults to a store with no mirror, so tests and
    ///     previews get the settled behaviour unless they ask otherwise.
    ///   - now: the clock the purchase sheet's date, the purchase marker and
    ///     a deleted plan's check stamp read — injected so a test can pin it.
    init(
        modelContext: ModelContext,
        syncMonitor: SyncMonitor = .notSyncing,
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.syncMonitor = syncMonitor
        self.now = now
    }

    /// Sets the side and reloads. That is all — it clears nothing, so each
    /// side's sort survives a visit to the other.
    func show(_ side: Side) {
        self.side = side
        load()
    }

    /// Sets the Active side's order and reloads, so the rows on screen follow
    /// it. The Completed side's order is untouched.
    func setActiveSort(_ order: ActiveSortOrder) {
        activeSortOrder = order
        load()
    }

    /// Sets the Completed side's order and reloads. The Active side's order
    /// is untouched.
    func setCompletedSort(_ order: CompletedSortOrder) {
        completedSortOrder = order
        load()
    }

    /// One fetch, split once (plan §5): the planned entries into active and
    /// completed by whether they are bought, the unbought count, and whether
    /// anything still awaits the carry-over.
    func load() {
        let all: [WishlistItem]
        do {
            all = try modelContext.fetch(FetchDescriptor<WishlistItem>())
        } catch {
            all = []
        }
        let planned = all.filter(\.hasSellPlan)
        let active = planned.filter { !$0.isBought }
        let completed = planned.filter(\.isBought)

        unboughtCount = all.count(where: { !$0.isBought })
        anyAwaitsCarryOver = all.contains(where: \.awaitsCarryOver)
        // Not `uniqueKeysWithValues`, which traps: nothing in a CloudKit
        // schema can enforce a unique id, so a duplicate keeps the first.
        entries = Dictionary(planned.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        activeRows = active
            .sorted { Self.areInActiveOrder($0, $1, under: activeSortOrder) }
            .map(Self.row(for:))
        completedRows = completed
            .sorted { Self.areInCompletedOrder($0, $1, under: completedSortOrder) }
            .map(Self.row(for:))
    }

    private static func row(for wanted: WishlistItem) -> PlanRow {
        PlanRow(
            id: wanted.id,
            name: wanted.name,
            categoryPath: wanted.categoryPath,
            // RA1: a completed row has one source — the item the purchase
            // became. `015` moved the entry's own photos to it, so the entry's
            // are empty on every plan the app completed; a fallback to them
            // would show only a photo synced in from another device before it
            // heard of the purchase.
            photos: wanted.isBought ? (wanted.boughtItem?.photos ?? []) : (wanted.photos ?? []),
            lines: SellPlanSummary(wanted).rowLines(boughtDate: wanted.boughtDate),
            boughtDate: wanted.boughtDate
        )
    }

    // MARK: - Marking a wanted entry bought (the fourth host)

    /// The purchase sheet for a row, seeded exactly as the other three hosts
    /// seed theirs: the price from the entry's estimate when it has one and
    /// blank when it doesn't, today's date from this screen's clock.
    func makePurchaseFormViewModel(for row: PlanRow) -> PurchaseFormViewModel {
        PurchaseFormViewModel(estimatedCostCents: entries[row.id]?.estimatedCostCents ?? 0, now: now)
    }

    /// Mark as bought… from an active row: `WishlistViewModel.markBought`'s
    /// body over the looked-up entry. The row moves to Completed on the
    /// reload (criterion 14).
    ///
    /// Returns false on a refused save, which rolls back and says so in
    /// `purchaseFailureMessage`.
    @discardableResult
    func markBought(_ row: PlanRow, purchase: Purchase) -> Bool {
        purchaseFailureMessage = nil
        guard let wanted = entries[row.id] else {
            // Not silent (`015` T012e): the row's entry is gone, and "Nothing
            // was changed" is true — this returns ahead of every write.
            purchaseFailureMessage = PurchaseCopy.failureMessage
            return false
        }
        do {
            try WishlistPurchaseStore.markBought(wanted, purchase: purchase, at: now(), in: modelContext)
            try modelContext.save()
        } catch {
            // The reload below would otherwise fetch a context still holding
            // the pending insert and marker.
            modelContext.rollback()
            purchaseFailureMessage = error as? WishlistPurchaseStore.PurchaseError == .alreadyBought
                ? PurchaseCopy.alreadyBought
                : PurchaseCopy.failureMessage
            load()
            return false
        }
        load()
        return true
    }

    // MARK: - Deleting a plan

    /// Decision 9: the plan goes, through the one writer; the entry, every
    /// item and the sold-toward record stay. Silent on refusal, as every
    /// delete in the app is — roll back and re-read what is stored.
    @discardableResult
    func deletePlan(id: UUID) -> Bool {
        guard let wanted = entries[id] else { return false }
        SellPlanStore.delete(planOf: wanted, at: now())
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            load()
            return false
        }
        load()
        return true
    }

    // MARK: - Sorting (plan Q9)

    /// The Active side's sort under one option, falling back to the wishlist's
    /// own order on any tie — so two plans carried over at one instant are
    /// fully determined. `wishlistOrder` *is* that fallback.
    ///
    /// Static, with the order as an argument, so a test can ask about a tie
    /// directly in both argument orders rather than through a fetch.
    static func areInActiveOrder(_ l: WishlistItem, _ r: WishlistItem, under order: ActiveSortOrder) -> Bool {
        activeAttributeOrder(l, r, under: order) ?? ManualOrderHelper.areInCustomOrder(l, r)
    }

    /// The Completed side's sort under one option — "Newest"/"Oldest" by the
    /// date bought — with the same fallback.
    static func areInCompletedOrder(_ l: WishlistItem, _ r: WishlistItem, under order: CompletedSortOrder) -> Bool {
        completedAttributeOrder(l, r, under: order) ?? ManualOrderHelper.areInCustomOrder(l, r)
    }

    /// The option's own comparison, `nil` on a tie.
    private static func activeAttributeOrder(
        _ lhs: WishlistItem,
        _ rhs: WishlistItem,
        under order: ActiveSortOrder
    ) -> Bool? {
        switch order {
        case .newest, .oldest:
            dateOrder(lhs.sellPlanCreatedAt, rhs.sellPlanCreatedAt, newestFirst: order == .newest)
        case .name:
            nameOrder(lhs, rhs)
        case .wishlistOrder:
            nil
        }
    }

    private static func completedAttributeOrder(
        _ lhs: WishlistItem,
        _ rhs: WishlistItem,
        under order: CompletedSortOrder
    ) -> Bool? {
        switch order {
        case .newest, .oldest:
            dateOrder(lhs.boughtDate, rhs.boughtDate, newestFirst: order == .newest)
        case .name:
            nameOrder(lhs, rhs)
        }
    }

    /// A missing date sorts last either way — defensive, since every row on
    /// a side carries the date that side sorts by.
    private static func dateOrder(_ lhs: Date?, _ rhs: Date?, newestFirst: Bool) -> Bool? {
        guard lhs != rhs else { return nil }
        guard let left = lhs else { return false }
        guard let right = rhs else { return true }
        return newestFirst ? left > right : left < right
    }

    private static func nameOrder(_ lhs: WishlistItem, _ rhs: WishlistItem) -> Bool? {
        let byName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        guard byName != .orderedSame else { return nil }
        return byName == .orderedAscending
    }
}

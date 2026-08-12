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
    /// Owned gear worth offering, ranked. See `rank(_:_:)` for the order.
    private(set) var candidates: [Item] = []

    /// Held as ids rather than as `Item` references so membership is a cheap,
    /// identity-free lookup — two fetches can hand back different instances of
    /// the same row.
    private(set) var selectedIDs: Set<UUID> = []

    private(set) var wishlistItem: WishlistItem?
    private(set) var hasLoaded = false
    private(set) var loadFailureMessage: String?
    private(set) var saveFailureMessage: String?

    private let modelContext: ModelContext
    private let wishlistItemID: UUID

    init(modelContext: ModelContext, wishlistItemID: UUID) {
        self.modelContext = modelContext
        self.wishlistItemID = wishlistItemID
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
    var selectedValueMeetsCost: Bool {
        selectedCount > 0 && selectedValueCents >= estimatedCostCents
    }

    var isEmpty: Bool { candidates.isEmpty }

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
    }

    private(set) var ownedCount = 0
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
    var emptyReason: EmptyReason? {
        guard candidates.isEmpty else { return nil }
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
            let id = wishlistItemID
            var descriptor = FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            let wanted = try modelContext.fetch(descriptor).first
            wishlistItem = wanted

            // Whatever was persisted, and only that. No auto-selection: the
            // plan stays empty until the user picks something.
            let planned = wanted?.plannedSaleItems ?? []
            selectedIDs = Set(planned.map(\.id))

            let owned = try modelContext.fetch(FetchDescriptor<Item>())
            ownedCount = owned.count
            lowDesireCount = owned.count { DesireLevel(clamping: $0.desireToKeep).isSellCandidate }
            candidates = Self.candidates(from: owned, alreadySelected: selectedIDs)
        } catch {
            loadFailureMessage = error.localizedDescription
            ownedCount = 0
            lowDesireCount = 0
            candidates = []
            selectedIDs = []
            wishlistItem = nil
        }
        hasLoaded = true
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
    static func candidates(from owned: [Item], alreadySelected: Set<UUID>) -> [Item] {
        owned
            .filter { qualifies($0) || alreadySelected.contains($0.id) }
            .sorted(by: rank)
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

    /// Least-wanted first; ties go to the more valuable, since between two
    /// items you feel the same about, the one that raises more is the better
    /// suggestion.
    ///
    /// Falls through to name then id so the order is fully determined by the
    /// data — `FetchDescriptor` promises no ordering, and a list that reshuffles
    /// equal rows between visits looks broken.
    private static func rank(_ lhs: Item, _ rhs: Item) -> Bool {
        if lhs.desireToKeep != rhs.desireToKeep {
            return lhs.desireToKeep < rhs.desireToKeep
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

    // MARK: - Selecting

    func isSelected(_ item: Item) -> Bool {
        selectedIDs.contains(item.id)
    }

    /// Adds or removes a candidate, persisting immediately — no separate save
    /// step, consistent with the app's low-friction bar.
    func toggle(_ item: Item) {
        saveFailureMessage = nil
        guard let wishlistItem else { return }

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
}

import Foundation
import Observation
import SwiftData

/// The overview screen's figures, per `design/screens/Trove Dashboard.png`:
/// what the collection is worth, what it cost, the gap between them, and how
/// that splits by category.
///
/// Scopable. spec.md asks to "drill into a category to see the same numbers
/// scoped to it", so the same type serves the whole collection and any one
/// category — `scope` is the only difference, and every figure below respects
/// it. That's why it's `let`: a scoped dashboard is a different screen pushed
/// onto the stack, not this one mutating underneath the user.
@Observable
final class DashboardViewModel {
    /// One row of the "by category" breakdown.
    struct CategorySlice: Identifiable, Equatable {
        /// The full path this row stands for — `Photography` at the top level,
        /// `Photography/Cameras` one level in. Drilling in scopes to this.
        let path: String
        /// Only the segment this row adds; the ones above it are already
        /// implied by the scope the user is looking at.
        let label: String
        let itemCount: Int
        let unvaluedCount: Int
        let currentValueCents: Int
        let spentCents: Int
        /// Whether there's a further level underneath worth opening.
        let canDrillIn: Bool

        var id: String { path }
        var valueDeltaCents: Int { currentValueCents - spentCents }

        /// Whether any member of this row has a value. `currentValueCents` sums
        /// the valued ones, so a row with none sums to zero — and printing "$0"
        /// against a category that just hasn't been priced says it's worthless.
        var hasAnyValues: Bool { itemCount > unvaluedCount }
    }

    /// Design's "BY VALUE" control on the breakdown header.
    enum BreakdownOrder: String, CaseIterable, Identifiable {
        case value
        case count

        var id: String { rawValue }

        var label: String {
            switch self {
            case .value: "By value"
            case .count: "By count"
            }
        }
    }

    /// Empty is the whole collection; anything else is a category the user
    /// drilled into.
    let scope: String
    var breakdownOrder: BreakdownOrder = .value

    private(set) var valuedCount = 0
    private(set) var unvaluedCount = 0
    private(set) var totalCurrentValueCents = 0
    private(set) var totalSpentCents = 0
    private(set) var breakdown: [CategorySlice] = []
    private(set) var loadFailureMessage: String?

    /// The only un-valued item, when there is exactly one.
    ///
    /// Held so `unvaluedDestination` can name it. Not exposed directly: the
    /// count and the id together are one decision, and splitting them invites
    /// a caller to check one and use the other.
    private var soleUnvaluedItemID: UUID?

    private let modelContext: ModelContext

    init(modelContext: ModelContext, scope: String = "") {
        self.modelContext = modelContext
        self.scope = scope
    }

    /// Where the "Value →" callout should go.
    ///
    /// A single un-valued item goes straight to its own screen rather than to a
    /// filtered list holding one row — that list costs a tap to get through and
    /// ends up in the same place. Decided at the Phase 7 review; plan.md's
    /// `DashboardView` entry records it.
    ///
    /// One value rather than a count plus an id, so a caller can't check the
    /// count and then use a stale id.
    enum UnvaluedDestination: Hashable {
        /// Nothing is un-valued, so the callout isn't shown at all.
        case none
        case item(UUID)
        case filteredList
    }

    var unvaluedDestination: UnvaluedDestination {
        switch unvaluedCount {
        case 0: .none
        case 1: soleUnvaluedItemID.map(UnvaluedDestination.item) ?? .filteredList
        default: .filteredList
        }
    }

    var totalItemCount: Int { valuedCount + unvaluedCount }
    var isEmpty: Bool { totalItemCount == 0 }
    var categoryCount: Int { breakdown.count }

    /// Whether anything here has a value yet.
    ///
    /// The state this exists for is items with no values — reachable the moment
    /// someone adds their first few pieces and hasn't priced them, and the one
    /// place this screen degrades badly. Every figure it derives is zero, so the
    /// dashboard reads "$0" over a category breakdown where each row is worth
    /// "$0 · 0%": a collection reported as worthless rather than un-priced,
    /// which is exactly the claim the rest of this type is careful never to
    /// make (see `valueDeltaCents`).
    ///
    /// `isEmpty` doesn't cover it — there *is* data, it just has no money in it
    /// — so the screen gates its money-derived parts on this instead.
    var hasAnyValues: Bool { valuedCount > 0 }

    /// Worth now against what was paid.
    ///
    /// **Every figure here — `totalSpentCents` included — covers valued items
    /// only**, which is what lets the three reconcile: value − spent = delta,
    /// the arithmetic spec.md's "the delta between them" implies and Design's
    /// mock shows.
    ///
    /// Counting what un-valued items cost while leaving their worth out would
    /// understate the gain by exactly their purchase price. Buy three cameras,
    /// don't get round to valuing them, and a collection that's up reads as
    /// down. `unvaluedCount` is what makes the omission visible instead.
    var valueDeltaCents: Int { totalCurrentValueCents - totalSpentCents }

    /// How much of the collection the headline figure actually accounts for,
    /// 0–1, for the ruler under it.
    var valuedShare: Double {
        guard totalItemCount > 0 else { return 0 }
        return Double(valuedCount) / Double(totalItemCount)
    }

    /// A slice's share of the scope's current value — Design's "14 items ·
    /// 45%", which is a share of value, not of item count.
    func valueShare(of slice: CategorySlice) -> Double {
        guard totalCurrentValueCents > 0 else { return 0 }
        return Double(slice.currentValueCents) / Double(totalCurrentValueCents)
    }

    func load() {
        loadFailureMessage = nil
        do {
            let all = try modelContext.fetch(FetchDescriptor<Item>())
            apply(all.filter { CategoryPathHelper.path($0.categoryPath, isWithin: scope) })
        } catch {
            loadFailureMessage = error.localizedDescription
            valuedCount = 0
            unvaluedCount = 0
            totalCurrentValueCents = 0
            totalSpentCents = 0
            breakdown = []
            soleUnvaluedItemID = nil
        }
    }

    private func apply(_ items: [Item]) {
        let valued = items.filter { $0.currentValueCents != nil }
        let unvalued = items.filter { $0.currentValueCents == nil }

        valuedCount = valued.count
        unvaluedCount = unvalued.count
        soleUnvaluedItemID = unvalued.count == 1 ? unvalued.first?.id : nil
        totalCurrentValueCents = valued.compactMap(\.currentValueCents).reduce(0, +)
        totalSpentCents = valued.reduce(0) { $0 + $1.purchasePriceCents }
        breakdown = makeBreakdown(items)
    }

    private func makeBreakdown(_ items: [Item]) -> [CategorySlice] {
        let keyed = items.map {
            (key: CategoryPathHelper.categoryGroupKey(for: $0.categoryPath, under: scope), item: $0)
        }

        // Canonical casing through the same rule the chips and autocomplete
        // use, so one category can't be spelled two ways across two screens —
        // and so the order doesn't depend on what `FetchDescriptor` hands back.
        let keys = CategoryPathHelper.distinctPathsPreferringEarliestCasing(
            keyed.map { (path: $0.key, createdAt: $0.item.createdAt) }
        )

        return keys.map { key in
            let members = keyed
                .filter { $0.key.caseInsensitiveCompare(key) == .orderedSame }
                .map(\.item)
            let valued = members.filter { $0.currentValueCents != nil }

            return CategorySlice(
                path: key,
                label: CategoryPathHelper.trailingSegments(of: key, limit: 1).first ?? key,
                itemCount: members.count,
                unvaluedCount: members.count - valued.count,
                currentValueCents: valued.compactMap(\.currentValueCents).reduce(0, +),
                spentCents: valued.reduce(0) { $0 + $1.purchasePriceCents },
                canDrillIn: members.contains { $0.categoryPath.caseInsensitiveCompare(key) != .orderedSame }
            )
        }
        .sorted(by: isOrderedBefore)
    }

    private func isOrderedBefore(_ lhs: CategorySlice, _ rhs: CategorySlice) -> Bool {
        switch breakdownOrder {
        case .value:
            if lhs.currentValueCents != rhs.currentValueCents {
                return lhs.currentValueCents > rhs.currentValueCents
            }
        case .count:
            if lhs.itemCount != rhs.itemCount {
                return lhs.itemCount > rhs.itemCount
            }
        }

        // Same reasoning as the item list: equal keys must not leave the order
        // to the fetch, or the breakdown reshuffles between launches.
        let byLabel = lhs.label.localizedCaseInsensitiveCompare(rhs.label)
        if byLabel != .orderedSame {
            return byLabel == .orderedAscending
        }
        return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
    }
}

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

    /// The asking-price variant beside the person's own total (002,
    /// criterion 15, Decision 22): the sum of this device's *current*
    /// medians over the scoped owned items that have one.
    ///
    /// Never mixed into `totalCurrentValueCents` — that figure, what was
    /// spent, the gain and the breakdown all stay the person's own values.
    /// Withheld, stale (Decision 21) and unmatched items carry no median
    /// and are simply absent from the sum, which is why the count travels
    /// with it: the line says how much of the collection it covers.
    private(set) var marketTotalCents = 0
    private(set) var marketFigureCount = 0

    /// The only un-valued item, when there is exactly one.
    ///
    /// Held so `unvaluedDestination` can name it. Not exposed directly: the
    /// count and the id together are one decision, and splitting them invites
    /// a caller to check one and use the other.
    private var soleUnvaluedItemID: UUID?

    private let modelContext: ModelContext

    private let syncMonitor: SyncMonitor

    /// The clock the market figures' freshness is measured against —
    /// injected in the shape `ItemListViewModel` takes, so a test can make
    /// "thirty-one days old" a fact about its fixture.
    private let now: () -> Date

    init(
        modelContext: ModelContext,
        scope: String = "",
        syncMonitor: SyncMonitor = .notSyncing,
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContext = modelContext
        self.scope = scope
        self.syncMonitor = syncMonitor
        self.now = now
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

    /// Empty, but not necessarily empty — this device may still be receiving
    /// the collection (T053).
    ///
    /// The dashboard is the worst of the four places to get this wrong, since
    /// it's the launch tab: it's the first thing a new device shows, and
    /// during the first import it would otherwise open on "Nothing tracked
    /// yet" over a collection of two hundred.
    var isStillSyncing: Bool { isEmpty && syncMonitor.mayStillBeImporting }

    /// Bumped each time an import lands, so the screen can refetch — see
    /// `SyncMonitor.completedImports`.
    var completedImports: Int { syncMonitor.completedImports }
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

    /// Whether the market line has anything to say.
    ///
    /// Gated rather than printed empty: "Market · $0 · 0 of 34 items" is a
    /// claim that the collection is worth nothing on Reverb, the same
    /// mistake `hasAnyValues` exists to prevent one line above.
    var hasMarketFigures: Bool { marketFigureCount > 0 }

    /// Decision 22's whole line — "Market · $18,400 · 12 of 34 items".
    ///
    /// One string, composed here rather than in the view: the amount and
    /// the coverage it covers are one statement (spec P5), and a view that
    /// assembled them from parts could drop the qualifier. `totalCount` is
    /// the scoped item count the screen already shows, valued and un-valued
    /// alike.
    var marketLine: String {
        MarketCopy.dashboardLine(
            totalCents: marketTotalCents,
            count: marketFigureCount,
            totalCount: totalItemCount
        )
    }

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
            let scoped = all.filter { CategoryPathHelper.path($0.categoryPath, isWithin: scope) }
            // Built before `apply`, never inside it: the figures are read
            // while the totals are computed, and a market read that arrives
            // after its readers is the T012 defect (plan §6).
            let summaries = MarketSummary.summaries(forSubjects: scoped.map(\.id), in: modelContext, now: now())
            apply(scoped, marketSummaries: summaries)
        } catch {
            loadFailureMessage = error.localizedDescription
            valuedCount = 0
            unvaluedCount = 0
            totalCurrentValueCents = 0
            totalSpentCents = 0
            marketTotalCents = 0
            marketFigureCount = 0
            breakdown = []
            soleUnvaluedItemID = nil
        }
    }

    private func apply(_ items: [Item], marketSummaries: [UUID: MarketSummary]) {
        let valued = items.filter { $0.currentValueCents != nil }
        let unvalued = items.filter { $0.currentValueCents == nil }

        valuedCount = valued.count
        unvaluedCount = unvalued.count
        soleUnvaluedItemID = unvalued.count == 1 ? unvalued.first?.id : nil
        totalCurrentValueCents = valued.compactMap(\.currentValueCents).reduce(0, +)
        totalSpentCents = valued.reduce(0) { $0 + $1.purchasePriceCents }
        breakdown = makeBreakdown(items)

        // Over every scoped item, valued or not: a market figure exists
        // independently of whether the person has priced the thing.
        let medians = items.compactMap { marketSummaries[$0.id]?.medianCents }
        marketFigureCount = medians.count
        marketTotalCents = medians.reduce(0, +)
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

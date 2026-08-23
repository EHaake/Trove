import Foundation
import Observation
import SwiftData

/// Browse, filter, search and sort owned items.
///
/// `categoryFilter`, `searchText` and `sortOrder` are plain properties so the
/// view can bind controls straight to them; nothing recomputes until `load()`
/// is called.
/// That keeps the reload point explicit and the type trivially testable,
/// rather than hiding fetches inside property observers.
@Observable
final class ItemListViewModel {
    /// Each order has one sensible direction, so there's no ascending/
    /// descending toggle to get lost in: keepers, most valuable, and most
    /// recent all lead.
    enum SortOrder: String, CaseIterable, Identifiable {
        case purchaseDate
        case currentValue
        case desireToKeep

        var id: String { rawValue }

        /// What the sort control calls this. Here rather than in the view so
        /// the list and any future control can't disagree.
        var label: String {
            switch self {
            case .purchaseDate: "Date"
            case .currentValue: "Value"
            case .desireToKeep: "Desire"
            }
        }
    }

    var categoryFilter: String = ""

    /// Free text over name and serial number. Narrows the same set the
    /// category filter narrows rather than replacing it — spec.md is explicit
    /// that the two combine, so a category chip stays in force while typing.
    var searchText: String = ""

    /// Narrows to items with no value entered — the destination of the
    /// dashboard's "Value →" callout.
    ///
    /// Combines with the category filter and search the same way they combine
    /// with each other: every active narrowing applies to the same set. Set
    /// from outside via `AppRouter`, and the only filter with no control of its
    /// own in the header, so the chip row grows a dismissible chip while it's on
    /// — a filter the user can't see or clear is worse than one they can't set.
    var showsOnlyUnvalued: Bool = false

    var sortOrder: SortOrder = .purchaseDate

    private(set) var items: [Item] = []
    private(set) var loadFailureMessage: String?

    /// Every category path in use, for the filter chips. Includes paths whose
    /// items the current filter or search excludes — otherwise choosing one
    /// filter would hide the means of choosing another, and typing a query
    /// would dissolve the chip row underneath the field.
    private(set) var categoryOptions: [String] = []

    /// Short chip labels keyed by path — leaf-only where unambiguous. Computed
    /// once per load rather than per render.
    private(set) var categoryLabels: [String: String] = [:]

    /// Owned items before any narrowing. Held so an empty list can tell an
    /// empty collection apart from a filter that excluded everything — the two
    /// need opposite invitations.
    private(set) var totalCount = 0

    var isEmpty: Bool { items.isEmpty }

    /// Which empty state applies, or `nil` when there's something to show.
    var emptyReason: ListEmptyReason? {
        ListEmptyReason.reason(
            totalCount: totalCount,
            visibleCount: items.count,
            searchText: searchText,
            categoryFilter: categoryFilter,
            showsOnlyUnvalued: showsOnlyUnvalued,
            mayStillBeImporting: syncMonitor.mayStillBeImporting
        )
    }

    /// Combined current value of the items on screen, so the header total
    /// tracks the filter. Un-valued items contribute nothing rather than
    /// counting as zero — the same floor-not-total rule as the dashboard.
    var totalCurrentValueCents: Int {
        items.compactMap(\.currentValueCents).reduce(0, +)
    }

    /// How many of the items on screen have no value entered, so the header
    /// can be honest that the total above is a floor.
    var unvaluedCount: Int {
        items.count { $0.currentValueCents == nil }
    }

    private let modelContext: ModelContext

    private let syncMonitor: SyncMonitor

    /// - Parameter syncMonitor: defaults to a store with no mirror, so tests
    ///   and previews get the settled behaviour unless they ask otherwise.
    init(modelContext: ModelContext, syncMonitor: SyncMonitor = .notSyncing) {
        self.modelContext = modelContext
        self.syncMonitor = syncMonitor
    }

    /// Whether this device might still be receiving the collection. Read by
    /// the empty states, and by the note appended to the ones that survive
    /// mid-import.
    var mayStillBeImporting: Bool { syncMonitor.mayStillBeImporting }

    /// Bumped each time an import lands, so the screen can refetch — see
    /// `SyncMonitor.completedImports`.
    var completedImports: Int { syncMonitor.completedImports }

    func load() {
        loadFailureMessage = nil
        do {
            let all = try modelContext.fetch(FetchDescriptor<Item>())
            totalCount = all.count
            items = all
                // `isWithin`, not `matchesPrefix`: a chip is a category that
                // exists, so "Music/Amps" must not also match
                // "Music/Amplifiers". The typing rule stays in the picker.
                .filter { CategoryPathHelper.path($0.categoryPath, isWithin: categoryFilter) }
                // Design's field says "name, brand, serial"; there is no brand
                // in the schema, same gap `ItemRow`'s meta line works around.
                .filter { SearchMatching.matches(query: searchText, in: [$0.name, $0.serialNumber]) }
                .filter { !showsOnlyUnvalued || $0.currentValueCents == nil }
                .sorted(by: isOrderedBefore)
            // Built from the unfiltered fetch, so the chips stay put as the
            // filter changes — and from owned items only, so the row doesn't
            // offer categories that only wishlist entries sit in.
            categoryOptions = CategoryPathHelper.sortedDistinctPaths(
                all.map { (path: $0.categoryPath, createdAt: $0.createdAt) }
            )
            categoryLabels = CategoryPathHelper.displayLabels(for: categoryOptions)
        } catch {
            loadFailureMessage = error.localizedDescription
            totalCount = 0
            items = []
            categoryOptions = []
            categoryLabels = [:]
        }
    }

    private func isOrderedBefore(_ lhs: Item, _ rhs: Item) -> Bool {
        switch sortOrder {
        case .purchaseDate:
            if lhs.purchaseDate != rhs.purchaseDate {
                return lhs.purchaseDate > rhs.purchaseDate
            }
        case .currentValue:
            if lhs.currentValueCents != rhs.currentValueCents {
                // Un-valued items sort last whichever side they're on — they're
                // not worth zero, they're unknown, same as on the dashboard.
                guard let left = lhs.currentValueCents else { return false }
                guard let right = rhs.currentValueCents else { return true }
                return left > right
            }
        case .desireToKeep:
            if lhs.desireToKeep != rhs.desireToKeep {
                return lhs.desireToKeep > rhs.desireToKeep
            }
        }

        // Ties fall back to name, then id, so the order is fully determined by
        // the data. FetchDescriptor guarantees no ordering of its own, and a
        // list that reshuffles equal rows between launches looks broken.
        let byName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if byName != .orderedSame {
            return byName == .orderedAscending
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

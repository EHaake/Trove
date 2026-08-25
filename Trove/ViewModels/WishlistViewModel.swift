import Foundation
import Observation
import SwiftData

/// Browse, filter, search and reorder the wishlist.
///
/// Same shape as `ItemListViewModel` — plain properties for the controls,
/// nothing recomputes until `load()` — and the same shared rules for category
/// matching and search, so the two list screens can't disagree about what a
/// filter or a query means.
@Observable
final class WishlistViewModel {
    /// "Custom" is the default because `WishlistItem.sortOrder` exists
    /// precisely so the user can rank what they want most, which no derived
    /// order can express. It shipped in `001` as "Yours" and was renamed by
    /// `010` after real use found that name unclear even to the person who
    /// chose it — spec.md's Resolved decisions record the reversal.
    enum SortOrder: String, CaseIterable, Identifiable {
        case custom
        case cost

        var id: String { rawValue }

        var label: String {
            switch self {
            case .custom: "Custom"
            case .cost: "Cost"
            }
        }
    }

    var categoryFilter: String = ""
    var searchText: String = ""
    var sortOrder: SortOrder = .custom

    private(set) var items: [WishlistItem] = []
    private(set) var categoryOptions: [String] = []
    private(set) var categoryLabels: [String: String] = [:]
    private(set) var loadFailureMessage: String?

    private let modelContext: ModelContext

    private let syncMonitor: SyncMonitor

    init(modelContext: ModelContext, syncMonitor: SyncMonitor = .notSyncing) {
        self.modelContext = modelContext
        self.syncMonitor = syncMonitor
    }

    /// See `ItemListViewModel.mayStillBeImporting`.
    var mayStillBeImporting: Bool { syncMonitor.mayStillBeImporting }

    /// Bumped each time an import lands, so the screen can refetch — see
    /// `SyncMonitor.completedImports`.
    var completedImports: Int { syncMonitor.completedImports }

    /// Wanted items before any narrowing — see `ItemListViewModel.totalCount`.
    private(set) var totalCount = 0

    var isEmpty: Bool { items.isEmpty }

    /// Which empty state applies, or `nil` when there's something to show.
    ///
    /// Never `.everythingIsValued`: the wishlist has no un-valued filter, since
    /// nothing on it is owned yet. The shared rule is still what decides, so
    /// the two lists can't drift apart on the cases they do share.
    var emptyReason: ListEmptyReason? {
        ListEmptyReason.reason(
            totalCount: totalCount,
            visibleCount: items.count,
            searchText: searchText,
            categoryFilter: categoryFilter,
            mayStillBeImporting: syncMonitor.mayStillBeImporting
        )
    }

    /// Design's "4 WANTED · $4,740" — everything currently on screen, so the
    /// figure tracks the filter the same way the item list's total does.
    var totalEstimatedCostCents: Int {
        items.reduce(0) { $0 + $1.estimatedCostCents }
    }

    /// Dragging only makes sense against the real, whole list in its own
    /// order. Reordering a filtered subset would have to invent positions for
    /// the rows that aren't showing, and sorting by cost already fixes the
    /// order — a drag there would be undone by the next `load()`.
    var canReorder: Bool {
        sortOrder == .custom
            && categoryFilter.isEmpty
            && SearchMatching.normalized(searchText).isEmpty
    }

    func load() {
        loadFailureMessage = nil
        do {
            let all = try modelContext.fetch(FetchDescriptor<WishlistItem>())
            totalCount = all.count
            items = all
                .filter { CategoryPathHelper.path($0.categoryPath, isWithin: categoryFilter) }
                // Name only. A wishlist item has no serial number — it isn't
                // owned yet — so there's nothing else to match on.
                .filter { SearchMatching.matches(query: searchText, in: [$0.name]) }
                .sorted(by: isOrderedBefore)

            // Wishlist categories only. Offering every path the owned-items
            // list uses would fill most of this row with chips that lead
            // nowhere, since a wishlist is short and a collection isn't.
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

    /// Applies a drag through `ManualOrderHelper`, which renumbers every row
    /// densely so the stored order matches what the user just saw — see the
    /// helper for the invariant's rationale, and
    /// `positionsStayDenseAndUniqueAcrossManyMoves` for its guard.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard canReorder else { return }

        items = ManualOrderHelper.reorder(items, fromOffsets: source, toOffset: destination)

        do {
            try modelContext.save()
        } catch {
            loadFailureMessage = error.localizedDescription
        }
    }

    /// Deletes a wanted item by id. The list's swipe used to call
    /// `modelContext.delete` straight from the view — business logic in a
    /// view, and the one deletion in the app with no tests behind it. Routed
    /// through here so both routes to the same deletion share one tested path.
    ///
    /// Photos cascade with it; sell-plan items are unlinked, not deleted —
    /// the same asymmetry `WishlistDeleteCopy.message` states to the user.
    func delete(id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }

        modelContext.delete(item)
        do {
            try modelContext.save()
        } catch {
            loadFailureMessage = error.localizedDescription
        }
        load()
    }

    /// Creates a copy per spec.md's wishlist duplicate flow — the same shape
    /// as `ItemListViewModel.duplicate(id:)` adjusted for the entity: no
    /// serial number exists to clear, photos become genuinely new `Photo`
    /// rows (same one-photo-one-parent reasoning), and the copy's own Sell
    /// Plan selection starts empty rather than inheriting
    /// `plannedSaleItems`. Lands immediately after the original in manual
    /// order.
    func duplicate(id: UUID) {
        guard let original = items.first(where: { $0.id == id }) else { return }

        let copy = WishlistItem(
            name: original.name,
            categoryPath: original.categoryPath,
            estimatedCostCents: original.estimatedCostCents,
            currencyCode: original.currencyCode,
            notes: original.notes,
            desireToOwn: original.desireToOwn,
            photos: (original.photos ?? []).map {
                Photo(imageData: $0.imageData, source: $0.source, sortOrder: $0.sortOrder)
            },
            plannedSaleItems: []
        )
        modelContext.insert(copy)

        // Whole collection in manual order, never the filtered slice.
        let ordered = (try? modelContext.fetch(
            FetchDescriptor<WishlistItem>(sortBy: [SortDescriptor(\.sortOrder)])
        )) ?? []
        ManualOrderHelper.insert(copy, after: original, in: ordered)

        do {
            try modelContext.save()
        } catch {
            loadFailureMessage = error.localizedDescription
        }
        load()
    }

    private func isOrderedBefore(_ lhs: WishlistItem, _ rhs: WishlistItem) -> Bool {
        switch sortOrder {
        case .custom:
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
        case .cost:
            if lhs.estimatedCostCents != rhs.estimatedCostCents {
                return lhs.estimatedCostCents > rhs.estimatedCostCents
            }
        }

        // Ties fall back to name then id, so the order is fully determined by
        // the data rather than by whatever `FetchDescriptor` returns. Matters
        // more here than on the item list: two wishlist items added in one
        // sitting can easily share a `sortOrder` of 0 from an older build.
        let byName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if byName != .orderedSame {
            return byName == .orderedAscending
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

import Foundation
import Observation
import SwiftData

/// Browse, filter and sort owned items.
///
/// `categoryFilter` and `sortOrder` are plain properties so the view can bind
/// controls straight to them; nothing recomputes until `load()` is called.
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
    }

    var categoryFilter: String = ""
    var sortOrder: SortOrder = .purchaseDate

    private(set) var items: [Item] = []
    private(set) var loadFailureMessage: String?

    var isEmpty: Bool { items.isEmpty }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load() {
        loadFailureMessage = nil
        do {
            let all = try modelContext.fetch(FetchDescriptor<Item>())
            items = all
                .filter { CategoryPathHelper.path($0.categoryPath, matchesPrefix: categoryFilter) }
                .sorted(by: isOrderedBefore)
        } catch {
            loadFailureMessage = error.localizedDescription
            items = []
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

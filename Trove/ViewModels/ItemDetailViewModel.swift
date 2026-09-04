import Foundation
import Observation
import SwiftData

/// A single owned item, and deleting it.
///
/// Holds the item's `id` rather than the `Item` itself and re-fetches on
/// `load()`. Once sync is on, an item can disappear out from under this screen
/// because another device deleted it; looking it up by id means that surfaces
/// as `item == nil`, which the view can handle, instead of a stale reference.
@Observable
final class ItemDetailViewModel {
    private(set) var item: Item?
    private(set) var deleteFailureMessage: String?

    /// Distinguishes "not loaded yet" from "loaded, and it's gone".
    private(set) var hasLoaded = false

    private let modelContext: ModelContext
    private let itemID: UUID

    init(modelContext: ModelContext, itemID: UUID) {
        self.modelContext = modelContext
        self.itemID = itemID
    }

    func load() {
        let id = itemID
        var descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        item = try? modelContext.fetch(descriptor).first
        hasLoaded = true
    }

    /// The item's photos in the user's own order.
    ///
    /// Sorted here rather than at the call site: the relationship comes back
    /// unordered from SwiftData, so this is a correctness rule rather than a
    /// layout choice, and CLAUDE.md keeps those out of views. `ItemDetailView`
    /// applied `PhotoSelection.inDisplayOrder` inline until
    /// `WishlistDetailViewModel` put the same rule in a view model — one job in
    /// two places, the shape of bug this build has hit more than once.
    var photos: [Photo] {
        PhotoSelection.inDisplayOrder(item?.photos ?? [])
    }

    /// Deletes the loaded item. Its photos go with it, by the cascade rule on
    /// `Item.photos`; any Sell Plan referencing it just drops the reference.
    @discardableResult
    func delete() -> Bool {
        deleteFailureMessage = nil
        guard let item else { return false }

        // 002: the device's market rows for this item go with it, in the
        // same save (plan §1, "who clears").
        modelContext.delete(item)
        do {
            try MarketLocalStore.clear(subjectID: item.id, in: modelContext)
            try modelContext.save()
            self.item = nil
            return true
        } catch {
            deleteFailureMessage = error.localizedDescription
            return false
        }
    }
}

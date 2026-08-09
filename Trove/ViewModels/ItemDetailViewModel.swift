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

    /// Deletes the loaded item. Its photos go with it, by the cascade rule on
    /// `Item.photos`; any Sell Plan referencing it just drops the reference.
    @discardableResult
    func delete() -> Bool {
        deleteFailureMessage = nil
        guard let item else { return false }

        modelContext.delete(item)
        do {
            try modelContext.save()
            self.item = nil
            return true
        } catch {
            deleteFailureMessage = error.localizedDescription
            return false
        }
    }
}

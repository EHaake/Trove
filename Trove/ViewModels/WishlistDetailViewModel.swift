import Foundation
import Observation
import SwiftData

/// A single wishlist item, for the plain detail screen.
///
/// Holds the item's `id` and re-fetches on `load()`, the same as
/// `ItemDetailViewModel` and for the same reason: once sync is on, an entry can
/// disappear out from under this screen because another device deleted it.
/// Looking it up by id surfaces that as `item == nil`, which the view can
/// handle, rather than as a stale reference.
///
/// **No ranking or Sell Plan logic lives here.** `plannedSaleItems` belongs to
/// `SellPlanViewModel`, one screen further in — plan.md is explicit that the
/// plan is reached by a deliberate tap rather than shown alongside the item, and
/// a detail model that quietly computed candidates would undo that by making
/// them available to render here.
@Observable
final class WishlistDetailViewModel {
    private(set) var item: WishlistItem?

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
        var descriptor = FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        item = try? modelContext.fetch(descriptor).first
        hasLoaded = true
    }

    // MARK: - Display

    /// The item's photos in the user's own order.
    ///
    /// Sorted here rather than at the call site: the relationship comes back
    /// unordered from SwiftData, so this is a correctness rule rather than a
    /// layout choice, and CLAUDE.md keeps those out of views. (`ItemDetailView`
    /// still sorts inline — worth aligning when that screen is next touched,
    /// not worth a drive-by change now.)
    var photos: [Photo] {
        PhotoSelection.inDisplayOrder(item?.photos ?? [])
    }

    /// The full category path, split for display. The detail screen shows every
    /// segment, unlike list rows, which show only the trailing two.
    var categorySegments: [String] {
        item?.categoryPath.split(separator: "/").map(String.init) ?? []
    }

    /// Clamped on the way out, so a value stored before the view model's range
    /// rule — or by a future import — still renders as a real level.
    var desireLevel: DesireToOwnLevel? {
        item.map { DesireToOwnLevel(clamping: $0.desireToOwn) }
    }

    /// Whether there's anything to show under a "Notes" heading, so the view
    /// can drop the heading too rather than leaving a label over blank space.
    var hasNotes: Bool {
        item?.notes?.isEmpty == false
    }
}

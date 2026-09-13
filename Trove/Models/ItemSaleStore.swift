import Foundation
import SwiftData

/// The one writer of a sale (plan Q3). Both entry points — the detail screen
/// and the Sell Plan row — and both later actions go through these three
/// statics, so "drops every plan selection, clears the device's market rows,
/// keeps the funding link, never touches `sortOrder`" is one function's
/// contract rather than four screens' agreement.
///
/// **Callers save**, the `MarketLocalStore` shape: every writer here leaves
/// its changes in the caller's context, so the item's write and the local
/// market rows commit in one `save()` and a failed save leaves neither half
/// behind.
///
/// MainActor by the project default, like `MarketLocalStore`: it writes
/// through the caller's `ModelContext`.
enum ItemSaleStore {
    /// Mark as sold: the sale, the optional plan it was sold toward, every
    /// plan *selection* dropped (spec P6), the device's market rows cleared
    /// (Decision 7), `updatedAt` bumped, `sortOrder` untouched — so a later
    /// return puts the item back in its own Custom-order slot.
    ///
    /// The item's own fields, its photos and its `reverbProductID` match are
    /// left exactly as they were (Decision 1): only the device-local rows go.
    ///
    /// Throws only from the market clear, which runs first so a failure there
    /// leaves the item unwritten.
    static func markSold(_ item: Item, sale: Sale, toward plan: WishlistItem?, at now: Date, in context: ModelContext) throws {
        try MarketLocalStore.clear(subjectID: item.id, in: context)
        item.sale = sale
        item.soldTowardWishlistItem = plan
        // The inverse of what deletion's `.nullify` does today, written
        // explicitly because the item survives its own sale (plan §2).
        item.plannedForWishlistItems = []
        item.updatedAt = now
    }

    /// Edit sale…: the four sale fields only. The plan link and the (already
    /// empty) plan selections are not touched — `Item.sale`'s setter writes
    /// the fields and leaves the link alone.
    static func editSale(_ item: Item, sale: Sale, at now: Date) {
        item.sale = sale
        item.updatedAt = now
    }

    /// Return to collection…: `sale = nil` clears the four fields *and* the
    /// funding link (spec P12), and `updatedAt` is bumped. `sortOrder` is
    /// untouched, so the item reappears at its former place in Custom order
    /// by construction; it rejoins no plan.
    static func returnToCollection(_ item: Item, at now: Date) {
        item.sale = nil
        item.updatedAt = now
    }
}

import Foundation
import SwiftData

/// The one writer of a purchase (plan Q4, §3), the shape and the contract
/// `ItemSaleStore` holds for a sale: all three hosts mark a wanted entry
/// bought through this one static, so "creates the item, moves the photos,
/// marks the entry, releases the plan, clears the device's market rows" is
/// one function's contract rather than three screens' agreement.
///
/// **Callers save**, the `MarketLocalStore` shape: this leaves its changes in
/// the caller's context, so the new item, the marker and the local market
/// clear commit in one `save()` and a refused save leaves none of them.
///
/// MainActor by the project default, like `ItemSaleStore`: it writes through
/// the caller's `ModelContext`.
enum WishlistPurchaseStore {
    /// Why a purchase was refused.
    ///
    /// Thrown rather than `precondition`ed: a precondition can only "fail" by
    /// trapping, so no test could reach the refusal behaviourally — the exact
    /// mistake `CLAUDE.md` records from `002`'s T021.
    nonisolated enum PurchaseError: Error, Equatable, Sendable {
        /// The entry already carries a marker, so buying it again would
        /// insert a **second** `Item` from fields still sitting on the entry
        /// and re-stamp `boughtDate`, destroying the first purchase's date —
        /// and Decision 5 leaves no undo to correct either with.
        case alreadyBought
    }

    /// The purchase: a new owned item carrying everything the wanted entry
    /// knew, its photos moved across, the entry marked bought, its unsold
    /// candidates released and its sold-toward history kept.
    ///
    /// **An entry is bought once.** The guard lives here rather than in the
    /// three hosts because the two windows in which a second tap is reachable
    /// are windows the hosts cannot close: `WishlistDetailView`'s `.onAppear`
    /// (R2's mechanism) fires on push and on return, not when a marker
    /// arrives from another device mid-screen (criterion 12), and
    /// `SellPlanViewModel.markBought` deliberately does not reload on success
    /// (§6), so its subject and its button stay live while the screen
    /// dismisses. One guard in the one writer closes both, and every future
    /// host with them.
    ///
    /// Throws `PurchaseError.alreadyBought`, or from the market clear. Both
    /// run before anything is written, so a failure leaves nothing behind.
    /// The caller saves.
    ///
    /// `Item.init` hard-sets `createdAt`/`updatedAt` to `.now`; `now` here is
    /// the marker's own stamp, and the `at:` parameter exists so a test can
    /// pin it — the same asymmetry `ItemSaleStore.markSold` carries.
    @discardableResult
    static func markBought(
        _ wanted: WishlistItem, purchase: Purchase, at now: Date, in context: ModelContext
    ) throws -> Item {
        // Before the clear, and before anything else: a refused second
        // purchase must not even drop the market rows of the entry whose
        // first purchase already cleared them.
        guard !wanted.isBought else { throw PurchaseError.alreadyBought }

        // First, so a failure here leaves nothing written (ItemSaleStore's shape).
        try MarketLocalStore.clear(subjectID: wanted.id, in: context)

        // P5: `desireToKeep` is left at the initializer's 3 rather than passed —
        // the wishlist's three-level *wanting* scale is not the item's
        // five-level *keeping* scale, so the absence is the decision.
        let item = Item(
            name: wanted.name,
            categoryPath: wanted.categoryPath,
            purchasePriceCents: purchase.priceCents,
            purchaseDate: purchase.date,
            currencyCode: wanted.currencyCode,
            purchaseLocation: purchase.location,
            currentValueCents: purchase.priceCents,          // P4
            condition: purchase.condition,
            notes: wanted.notes,                             // Decision 7
            reverbProductID: wanted.reverbProductID,
            year: wanted.year
        )
        item.sortOrder = ManualOrderHelper.nextPosition(
            after: (try? context.fetch(FetchDescriptor<Item>())) ?? [])
        context.insert(item)

        // Moved, never copied (Q6): the credit on a 005 stock photo is three
        // stored strings on the row itself, and a rebuilt row loses them —
        // which is what `WishlistViewModel.duplicate(id:)` does and this
        // deliberately does not.
        for (position, photo) in PhotoSelection.inDisplayOrder(wanted.photos ?? []).enumerated() {
            photo.wishlistItem = nil
            photo.item = item
            photo.sortOrder = position
        }

        wanted.boughtDate = now
        // P6: nothing is earmarked toward a purchase that has happened. The
        // sales already recorded toward it (`itemsSoldToward`) are the record
        // Decision 3 keeps, and are deliberately untouched.
        wanted.plannedSaleItems = []
        return item
    }
}

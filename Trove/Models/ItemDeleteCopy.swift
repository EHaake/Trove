import Foundation

/// What deleting an owned item says for itself, in the one place both routes
/// to that deletion will read from: `ItemListView`'s swipe (T015) and
/// `ItemDetailView`'s overflow menu (T017). Same construction as
/// `WishlistDeleteCopy`, and for the same reason — two entry points to one
/// deletion must not drift apart about what it costs.
///
/// The content extends the alert `ItemDetailView` already shipped (T002's
/// finding: it named the photo cascade and permanence, but not the Sell Plan
/// consequence spec.md requires). The sell-plan line matters because it isn't
/// guessable from the button: gear picked to fund a wishlist purchase
/// silently drops out of that plan when it's deleted, and the plan's math
/// changes without a word unless the alert says so here.
enum ItemDeleteCopy {
    static func title(for name: String) -> String {
        "Delete \(name)?"
    }

    /// All three consequences, deliberately: photos cascade, sell plans drop
    /// it (the nullify direction — the *plan* loses the item, the item never
    /// takes the plan down), and there's no undo. `ItemDeleteCopyTests` pins
    /// each one.
    static let message = "Its photos go too. Any sell plan it's on drops it. This can't be undone."

    static let confirm = "Delete"
    static let cancel = "Keep"
}

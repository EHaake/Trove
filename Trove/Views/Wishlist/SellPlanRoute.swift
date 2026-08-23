import Foundation

/// Navigation route to a wishlist item's Sell Plan.
///
/// A named type rather than a bare `UUID`, because the wishlist stack already
/// pushes wishlist items by id: "open this item" and "open this item's sell
/// plan" carry the same value and mean different things, and a stack that can't
/// tell them apart picks whichever destination was declared last.
struct SellPlanRoute: Hashable, Identifiable {
    let wishlistItemID: UUID

    var id: UUID { wishlistItemID }
}

import Foundation
import SwiftData

/// Something the user wants to buy.
///
/// Same CloudKit constraints as `Item`: every property optional or defaulted,
/// every relationship optional, no `@Attribute(.unique)`.
@Model
final class WishlistItem {
    var id: UUID = UUID()
    var name: String = ""
    var categoryPath: String = ""

    /// Minor units, like every other money field in the schema.
    var estimatedCostCents: Int = 0

    /// ISO 4217. v1 only ever writes `"USD"`.
    var currencyCode: String = "USD"

    var notes: String?

    /// User-adjustable manual ordering of the wishlist.
    var sortOrder: Int = 0

    var createdAt: Date = Date.now

    /// Optional for the same CloudKit reason as `Item.photos` — read it as
    /// `photos ?? []`.
    ///
    /// `.cascade` here, `.nullify` for `plannedSaleItems` below, and the
    /// contrast is the point: a photo of something you wanted has no life once
    /// the wishlist entry is gone, whereas the gear on its Sell Plan very much
    /// does.
    @Relationship(deleteRule: .cascade, inverse: \Photo.wishlistItem)
    var photos: [Photo]? = []

    /// The Sell Plan: owned items the user is weighing selling to fund this
    /// purchase. Persisted rather than recomputed, starts empty, and never
    /// auto-populated — see spec.md on why this is advisory rather than a
    /// target to hit.
    ///
    /// The delete rule is deliberately `.nullify`: abandoning a wishlist item
    /// must never delete the gear on its Sell Plan. `Item` owns the
    /// `@Relationship(inverse:)` declaration for this pair.
    @Relationship(deleteRule: .nullify)
    var plannedSaleItems: [Item]? = []

    init(
        name: String = "",
        categoryPath: String = "",
        estimatedCostCents: Int = 0,
        currencyCode: String = "USD",
        notes: String? = nil,
        sortOrder: Int = 0,
        photos: [Photo]? = [],
        plannedSaleItems: [Item]? = []
    ) {
        self.name = name
        self.categoryPath = categoryPath
        self.estimatedCostCents = estimatedCostCents
        self.currencyCode = currencyCode
        self.notes = notes
        self.sortOrder = sortOrder
        self.photos = photos
        self.plannedSaleItems = plannedSaleItems
        self.createdAt = .now
    }
}

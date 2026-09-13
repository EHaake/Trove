import Foundation
import SwiftData

/// A piece of gear the user owns.
///
/// Every property is optional or carries a default, and nothing uses
/// `@Attribute(.unique)` — both are hard requirements for the CloudKit sync
/// this schema is built to accept later (see plan.md).
@Model
final class Item {
    var id: UUID = UUID()
    var name: String = ""

    /// Slash-delimited, user-defined, e.g. `"Photography/Cameras"`. A plain
    /// string rather than an enum so a future auto-categorization feature can
    /// fill it in without a schema change.
    var categoryPath: String = ""

    var serialNumber: String?

    /// Money is stored in minor units to avoid floating-point rounding
    /// entirely; formatting happens at the view-model/view boundary.
    var purchasePriceCents: Int = 0

    /// ISO 4217. v1 only ever writes `"USD"` and has no currency picker — the
    /// field exists so international support is additive rather than a
    /// CloudKit migration after real data exists.
    var currencyCode: String = "USD"

    var purchaseDate: Date = Date.now
    var purchaseLocation: String?

    /// `nil` means "not yet estimated", which is distinct from zero: the
    /// dashboard excludes these from its total and counts them separately, and
    /// the Sell Plan leaves them out of the candidate pool entirely.
    var currentValueCents: Int?

    /// 1 (ready to sell) to 5 (absolutely keeping it). The valid range is
    /// enforced in the view model, not the schema.
    var desireToKeep: Int = 3

    /// Backing store for ``condition``. See plan.md's naming convention:
    /// predicates and sort descriptors can only see this, not `condition`.
    var conditionRawValue: String = Condition.excellent.rawValue

    var conditionNotes: String?
    var notes: String?

    /// User-adjustable manual ordering of the item list — the same concept
    /// `WishlistItem.sortOrder` has represented since `001`, added here by
    /// `010`. A scalar with a default needs no optionality for CloudKit.
    /// Rows that predate this field all sit at 0 until the one-time launch
    /// backfill (`010`'s T005) assigns them a real order.
    var sortOrder: Int = 0

    /// 002: the Reverb catalog product this item is matched to; nil is
    /// unmatched. The person's own data, so it syncs (spec P1). Reverb's
    /// identifier is an integer and the product endpoint takes one — `Int`,
    /// not a string that could quietly start holding slugs. Everything the
    /// device learns *about* the product lives in the local store, never
    /// here.
    var reverbProductID: Int?

    /// 002, Decision 29: the instrument's year, when the person gives one —
    /// four digits, optional, distinct from `purchaseDate`. Narrows the
    /// market listings a figure is computed from; never leaves the device.
    var year: Int?

    /// 006: when this item was sold, or nil while it is owned. **The one sold
    /// predicate** — `soldDate == nil` is "owned" everywhere, in `#Predicate`
    /// and in memory alike (plan Q2). Written together with `salePriceCents`
    /// by `ItemSaleStore` and the import commit, never alone.
    var soldDate: Date?

    /// The sale price in minor units, as every money field is. Nil while owned.
    var salePriceCents: Int?

    /// Where it sold ("eBay, Reverb, a friend…"), optional as `purchaseLocation` is.
    var saleLocation: String?

    var saleNote: String?

    /// 006 (spec P5): the wishlist item this sale was recorded toward, set only
    /// when sold from that item's Sell Plan. `.nullify` both ways: deleting the
    /// wishlist item leaves the sale standing with no plan (P10); deleting the
    /// item drops it from the wishlist item's list. Distinct from
    /// `plannedForWishlistItems`, which is a *selection* and is emptied at the
    /// sale (P6).
    @Relationship(deleteRule: .nullify, inverse: \WishlistItem.itemsSoldToward)
    var soldTowardWishlistItem: WishlistItem?

    /// Optional, not `[Photo]`, because CloudKit rejects non-optional
    /// relationships outright — see the note in plan.md. Read it as
    /// `photos ?? []`; nil and empty mean the same thing here.
    @Relationship(deleteRule: .cascade, inverse: \Photo.item)
    var photos: [Photo]? = []

    var createdAt: Date = Date.now

    /// Bumped on every edit by the view models that own mutation.
    var updatedAt: Date = Date.now

    /// Every Sell Plan this item currently appears on. Optional for the same
    /// CloudKit reason as `photos`.
    ///
    /// `.nullify`, never `.cascade`: removing an item from a Sell Plan — or
    /// deleting the wishlist item entirely — must not touch the owned gear.
    @Relationship(deleteRule: .nullify, inverse: \WishlistItem.plannedSaleItems)
    var plannedForWishlistItems: [WishlistItem]? = []

    var condition: Condition {
        get { Condition(rawValue: conditionRawValue) ?? .excellent }
        set { conditionRawValue = newValue.rawValue }
    }

    /// What the item is worth now against what it cost, or `nil` while it
    /// hasn't been valued — which is not the same as having broken even.
    var valueDeltaCents: Int? {
        guard let currentValueCents else { return nil }
        return currentValueCents - purchasePriceCents
    }

    /// The category path split for display, e.g. `["Photography", "Cameras"]`.
    var categorySegments: [String] {
        categoryPath.split(separator: "/").map(String.init)
    }

    init(
        name: String = "",
        categoryPath: String = "",
        purchasePriceCents: Int = 0,
        purchaseDate: Date = .now,
        currencyCode: String = "USD",
        serialNumber: String? = nil,
        purchaseLocation: String? = nil,
        currentValueCents: Int? = nil,
        desireToKeep: Int = 3,
        condition: Condition = .excellent,
        conditionNotes: String? = nil,
        notes: String? = nil,
        sortOrder: Int = 0,
        photos: [Photo]? = [],
        reverbProductID: Int? = nil,
        year: Int? = nil
    ) {
        let now = Date.now
        self.name = name
        self.categoryPath = categoryPath
        self.purchasePriceCents = purchasePriceCents
        self.purchaseDate = purchaseDate
        self.currencyCode = currencyCode
        self.serialNumber = serialNumber
        self.purchaseLocation = purchaseLocation
        self.currentValueCents = currentValueCents
        self.desireToKeep = desireToKeep
        self.conditionRawValue = condition.rawValue
        self.conditionNotes = conditionNotes
        self.notes = notes
        self.sortOrder = sortOrder
        self.photos = photos
        self.reverbProductID = reverbProductID
        self.year = year
        self.createdAt = now
        self.updatedAt = now
    }
}

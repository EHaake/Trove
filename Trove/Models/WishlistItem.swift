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

    /// 1 ("Someday") to 3 ("Next"). Like `Item.desireToKeep`, the valid range
    /// is enforced in the view model rather than the schema.
    ///
    /// Defaults to 2 — a wishlist entry someone bothered to type is already
    /// past "someday", and starting everything at the top would make the
    /// rating meaningless as a way to tell entries apart.
    ///
    /// Display only. It never reorders the wishlist: `sortOrder` below stays
    /// the single ordering, per spec.md.
    var desireToOwn: Int = 2

    /// User-adjustable manual ordering of the wishlist.
    var sortOrder: Int = 0

    /// 002: the matched Reverb product, as on `Item.reverbProductID`.
    var reverbProductID: Int?

    /// 002, Decision 29: the wanted instrument's year, as on `Item.year`.
    var year: Int?

    /// 015: when this wanted item was bought, or nil while it is still wanted.
    /// **The one bought predicate** — `boughtDate == nil` is "still wanted"
    /// everywhere, in `#Predicate` and in memory alike, the way `Item.soldDate`
    /// is the one sold predicate. Written only by `WishlistPurchaseStore`, and
    /// never cleared: there is no undo (spec Decision 5, guarded by
    /// `PurchaseUndoTests`).
    var boughtDate: Date?

    /// 009: when this wanted item's sell plan was created, or nil when it has
    /// none. **The one plan predicate** — a plan is a stored fact, never
    /// inferred from the selection (spec Decision 1). Written only by
    /// `SellPlanStore`.
    var sellPlanCreatedAt: Date?

    /// 009: when this entry's plan state became stored rather than inferred —
    /// stamped at `init` for every entry made from 009 on, and by the one-time
    /// carry-over (spec P10) for older ones. Nil only on a row an app older than
    /// 009 wrote and no 009 device has checked yet. Synced, so "once" travels
    /// with the row (plan Q2).
    var sellPlanCheckedAt: Date?

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
    ///
    /// 015: buying the wanted item empties this — the candidates still unsold
    /// are released from the plan, since there is nothing left to fund (spec
    /// P6).
    @Relationship(deleteRule: .nullify)
    var plannedSaleItems: [Item]? = []

    /// 006 (spec P5): items that were sold *toward* this purchase — the
    /// history, not the plan. Distinct from `plannedSaleItems`, which is the
    /// current selection and is emptied at the sale (P6).
    ///
    /// `.nullify` here as well: deleting this wishlist item leaves those sales
    /// standing with no plan attached (P10). `Item` owns the
    /// `@Relationship(inverse:)` declaration for this pair, as it does above.
    ///
    /// 015: buying the wanted item leaves this untouched — what was sold
    /// toward the purchase stays recorded against it (spec P6, Decision 3).
    @Relationship(deleteRule: .nullify)
    var itemsSoldToward: [Item]? = []

    /// 009 Amendment A (Decision 16): the item this entry became when it was
    /// bought — nil while wanted, nil on a purchase made before Amendment A,
    /// and nil again once that item is deleted. Written only by
    /// `WishlistPurchaseStore.markBought`. Read in one place: the Plans row's
    /// picture (`PlansViewModel`). Never a source of money — `015` Decision 2
    /// and this spec's Decision 5 stand. `Item` owns the inverse declaration.
    @Relationship(deleteRule: .nullify)
    var boughtItem: Item?

    /// The one bought predicate, in memory, as `Item.isSold` is for the sale.
    /// Predicates and sort descriptors can only see the stored `boughtDate`,
    /// so they spell out `boughtDate == nil` themselves (plan Q1).
    var isBought: Bool { boughtDate != nil }

    var hasSellPlan: Bool { sellPlanCreatedAt != nil }

    /// 009: an older row the carry-over has yet to reach that will become a plan
    /// when it does — unchecked, with a selection or a sold-toward history. **The
    /// carry-over's own predicate** (`SellPlanStore.carryOver` reads it), and
    /// read-only everywhere else (plan Q2): it never makes a plan by itself.
    var awaitsCarryOver: Bool {
        sellPlanCheckedAt == nil
            && (!(plannedSaleItems ?? []).isEmpty || !(itemsSoldToward ?? []).isEmpty)
    }

    init(
        name: String = "",
        categoryPath: String = "",
        estimatedCostCents: Int = 0,
        currencyCode: String = "USD",
        notes: String? = nil,
        desireToOwn: Int = 2,
        sortOrder: Int = 0,
        photos: [Photo]? = [],
        plannedSaleItems: [Item]? = [],
        reverbProductID: Int? = nil,
        year: Int? = nil
    ) {
        self.name = name
        self.categoryPath = categoryPath
        self.estimatedCostCents = estimatedCostCents
        self.currencyCode = currencyCode
        self.notes = notes
        self.desireToOwn = desireToOwn
        self.sortOrder = sortOrder
        self.photos = photos
        self.plannedSaleItems = plannedSaleItems
        self.reverbProductID = reverbProductID
        self.year = year
        self.createdAt = .now
        self.sellPlanCheckedAt = .now
    }
}

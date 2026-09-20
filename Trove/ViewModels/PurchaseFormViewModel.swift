import Foundation
import Observation

/// Backs the purchase sheet — Mark as bought (plan §5). One mode, unlike
/// `SaleFormViewModel`: a wanted entry is bought once and there is nothing to
/// go back and edit. Hosted from the wishlist, the wanted-entry page and the
/// Sell Plan; none of them writes anything itself, they hand `purchase()`'s
/// value to `WishlistPurchaseStore`.
///
/// Money is held as `Decimal` here rather than the model's `Int` cents, for
/// the reason `SaleFormViewModel` gives: this is the boundary where someone
/// types "2399.00", so the conversion — and its rounding — belongs on this
/// side of it. The price rules mirror the sale sheet exactly: required, zero
/// allowed, negative rejected.
@Observable
final class PurchaseFormViewModel {
    /// Q9: no date case. The field this sheet fills is `Item.purchaseDate`,
    /// whose own editor — `ItemFormView`'s "Date bought" — takes any date at
    /// all, and a sheet that refuses what the Edit screen accepts is one rule
    /// with two answers. A deliberate divergence from the sale sheet's
    /// `dateInFuture`, not an oversight.
    enum ValidationError: Hashable {
        /// Left blank. Distinct from a deliberate zero: a gift is a purchase
        /// of $0, an untouched field is not a purchase at all.
        case priceMissing
        case priceNegative
    }

    /// Optional so a wanted entry with no estimate starts blank rather than
    /// showing `0` — the `006` P1 rule: a pre-filled zero can't be typed over,
    /// the digits append.
    var price: Decimal?
    var date: Date
    var location: String = ""
    /// `Item`'s own default, so a bought entry lands with the same value a new
    /// item defaults to.
    var condition: Condition = .excellent

    private(set) var validationErrors: Set<ValidationError> = []

    private let estimatedCostCents: Int

    /// Title and confirm label come from `PurchaseCopy`, never typed inline,
    /// so the sheet and its tests read the same strings.
    var title: String { PurchaseCopy.sheetTitle }
    var confirmLabel: String { PurchaseCopy.confirm }

    /// The spec's one line of copy under the price, or nothing (Q7). Computed
    /// rather than stored, so it reads the *typed* price on every body
    /// evaluation and tracks the field live; with the field blank it compares
    /// 0 against the estimate, which is a real "less than you estimated"
    /// reading and the one the spec's under-case describes.
    var comparisonLine: String? {
        PurchaseCopy.comparison(
            paidCents: price.map(Money.cents(from:)) ?? 0,
            estimatedCostCents: estimatedCostCents
        )
    }

    /// Seeding, per Q10: the price pre-fills from the entry's estimated cost
    /// when there is one and stays blank otherwise — `estimatedCostCents` is a
    /// non-optional `Int` whose 0 means "none" (Q7), and a pre-filled 0 cannot
    /// be typed over. Today's date, no place, and the default condition.
    init(estimatedCostCents: Int, now: @escaping () -> Date = Date.init) {
        self.estimatedCostCents = estimatedCostCents
        price = estimatedCostCents == 0 ? nil : Money.amount(fromCents: estimatedCostCents)
        date = now()
    }

    /// Validates; `nil` with `validationErrors` set, else the purchase to
    /// record. The place is trimmed and blanks nil'd through
    /// `FieldNormalization`, exactly as the sale sheet does it.
    func purchase() -> Purchase? {
        validationErrors = validate()
        guard validationErrors.isEmpty, let price else { return nil }
        return Purchase(
            date: date,
            priceCents: Money.cents(from: price),
            location: FieldNormalization.nilIfBlank(location),
            condition: condition
        )
    }

    // MARK: - Private

    private func validate() -> Set<ValidationError> {
        var errors: Set<ValidationError> = []
        if let price {
            if price < 0 { errors.insert(.priceNegative) }
        } else {
            errors.insert(.priceMissing)
        }
        return errors
    }
}

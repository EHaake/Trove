import Foundation
import Observation

/// Backs the sale sheet — Mark as sold and Edit sale, one component in two
/// modes (plan §5). Hosted from the item detail page and from a Sell Plan
/// row; neither of them writes anything itself, they hand `sale()`'s value
/// to whoever records it.
///
/// Money is held as `Decimal` here rather than the model's `Int` cents, for
/// the reason `ItemFormViewModel` gives: this is the boundary where someone
/// types "1299.00", so the conversion — and its rounding — belongs on this
/// side of it. The price rules mirror that form's purchase price exactly
/// (Q12): required, zero allowed, negative rejected.
@Observable
final class SaleFormViewModel {
    enum ValidationError: Hashable {
        /// Left blank. Distinct from a deliberate zero: giving something away
        /// is a sale of $0, an untouched field is not a sale at all (P1).
        case priceMissing
        case priceNegative
        /// Later than `now()`. Any past instant is fine, including one before
        /// the purchase date — the app does not second-guess the person's own
        /// data entry (P2).
        case dateInFuture
    }

    enum Mode {
        case mark
        case edit
    }

    let mode: Mode

    /// Optional so a sheet with nothing to pre-fill starts blank rather than
    /// showing `0` — the same reason `ItemFormViewModel.purchasePrice` is
    /// optional: a pre-filled zero can't be typed over, the digits append.
    var price: Decimal?
    var date: Date
    var location: String = ""
    var note: String = ""

    private(set) var validationErrors: Set<ValidationError> = []

    private let now: () -> Date

    /// Title and confirm label come from `SaleCopy`, never typed inline, so
    /// the sheet and its tests read the same strings.
    var title: String {
        switch mode {
        case .mark: SaleCopy.sheetTitleMark
        case .edit: SaleCopy.sheetTitleEdit
        }
    }

    var confirmLabel: String {
        switch mode {
        case .mark: SaleCopy.confirmMark
        case .edit: SaleCopy.confirmEdit
        }
    }

    /// The date picker's upper bound. Read from the clock each time rather
    /// than captured at init, so a sheet left open across midnight isn't
    /// stale. The bound is a courtesy; `sale()`'s check is the falsifiable
    /// one (Q12).
    var latestDate: Date { now() }

    /// Seeding, per P1: `.edit` pre-fills from the sale; `.mark` pre-fills the
    /// price from `currentValueCents` when the item has one, blank otherwise,
    /// with today's date and no place or note.
    ///
    /// `.edit` without a sale can't arrive from the app — the sheet only opens
    /// in that mode for an item that is already sold — and falls back to the
    /// `.mark` seed rather than inventing a sale.
    init(
        mode: Mode,
        prefill: Sale?,
        currentValueCents: Int?,
        now: @escaping () -> Date = Date.init
    ) {
        self.mode = mode
        self.now = now
        if case .edit = mode, let prefill {
            price = Money.amount(fromCents: prefill.priceCents)
            date = prefill.date
            location = prefill.location ?? ""
            note = prefill.note ?? ""
        } else {
            price = currentValueCents.map(Money.amount(fromCents:))
            date = now()
        }
    }

    /// Validates; `nil` with `validationErrors` set, else the sale to record.
    /// Location and note are trimmed and blanks nil'd through
    /// `FieldNormalization`, exactly as the item form does it.
    func sale() -> Sale? {
        validationErrors = validate()
        guard validationErrors.isEmpty, let price else { return nil }
        return Sale(
            date: date,
            priceCents: Money.cents(from: price),
            location: FieldNormalization.nilIfBlank(location),
            note: FieldNormalization.nilIfBlank(note)
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
        if !isDateAllowed { errors.insert(.dateInFuture) }
        return errors
    }

    /// P2/Q12: any instant at or before `now()`. Inclusive on purpose — the
    /// sheet opens pre-filled with this very instant, so a strict `<` would
    /// reject the default it hands the person.
    private var isDateAllowed: Bool { date <= latestDate }
}

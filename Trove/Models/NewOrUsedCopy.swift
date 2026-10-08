import Foundation

/// 020's user-facing strings for bought-new-or-used and, on a wanted entry,
/// which the person is looking for — pinned by `NewOrUsedCopyTests` and read
/// by the views and view models, never typed inline. `PurchaseCopy`'s shape
/// and rules, for the same reason: three screens saying the same thing must
/// not drift apart.
///
/// Not the CSV headers: those stay in `ExportSchema`, which is the schema's
/// one home (plan §2).
///
/// Strings only. This is a `Trove/Models/` file, so it imports no SwiftUI and
/// names no colour.
nonisolated enum NewOrUsedCopy {
    // MARK: - Field labels

    /// The form's and the purchase sheet's field label. Form labels go
    /// through `.monoLabel()`, which uppercases, so the spec's **BOUGHT** is
    /// this string rendered.
    static let boughtLabel = "Bought"

    /// The wishlist form's field label and the wanted item's details row.
    /// The spec's **LOOKING FOR** is this string through `.monoLabel()`.
    static let lookingForLabel = "Looking for"

    // MARK: - Chips

    /// The chip's word, and the value a wanted item's page and PDF show
    /// beside `lookingForLabel`.
    static func chip(_ value: NewOrUsed) -> String {
        switch value {
        case .new: "New"
        case .used: "Used"
        }
    }

    // MARK: - The item page's purchase-date row

    /// The label of the existing purchase-date row (R1): "Bought new" /
    /// "Bought used" when it was recorded, and plain "Bought" when it was
    /// not — which is the row's label before 020, so an item nobody has
    /// answered the question for reads exactly as it did.
    static func detailDateRowLabel(bought: NewOrUsed?) -> String {
        switch bought {
        case .new: "Bought new"
        case .used: "Bought used"
        case nil: "Bought"
        }
    }
}

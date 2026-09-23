import Foundation

/// Spec 009's user-facing strings — the Plans tab, its rows, the delete
/// confirmation, the dashboard card and the empty states — pinned whole by
/// `SellPlanCopyTests` and read by the views and view models, never typed
/// inline. `PurchaseCopy`'s shape and rules, for the same reason: two surfaces
/// saying the same thing must not drift apart.
///
/// The one string table for this spec (plan Q7). The wanted item's
/// entry-point strings (`noPlanSubtitle`, `viewPlan`, `setAside(_:)`) are
/// here word for word as they read today.
///
/// Sort labels are not here: they stay on their enums, the
/// `SoldSortOrder.label` pattern.
///
/// Strings only. This is a `Trove/Models/` file, so it imports no SwiftUI and
/// names no colour.
nonisolated enum SellPlanCopy {
    // MARK: - The tab and its sides

    static let tab = "Plans"
    static let active = "Active"
    static let completed = "Completed"
    static let sideSwitchLabel = "Active or completed"

    // MARK: - The wanted item's entry point

    static let createPlan = "Create a sell plan"
    static let noPlanSubtitle = "Browse your lowest desire-to-keep items"
    static let viewPlan = "View your sell plan"

    // MARK: - A row's lines

    /// Pluralised inline with a ternary because the app has no
    /// pluralisation helper — `SaleCopy.sellPlanSoldCaption`'s shape.
    static func setAside(_ n: Int) -> String {
        "\(n) \(n == 1 ? "item" : "items") set aside"
    }

    /// One form for every count: "1 sold toward it", "2 sold toward it".
    static func soldToward(_ n: Int) -> String {
        "\(n) sold toward it"
    }

    /// The completed side's past tense, where the verb does agree with the
    /// count.
    static func soldTowardPast(_ n: Int) -> String {
        n == 1 ? "1 was sold toward it" : "\(n) were sold toward it"
    }

    static let nothingSetAside = "Nothing set aside yet"
    static let covered = "Covered"

    /// Through the `formatted(date: .abbreviated, time: .omitted)` every
    /// other date in the app uses.
    static func bought(on date: Date) -> String {
        "Bought \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    static let nothingSoldToward = "Nothing was sold toward it."

    // MARK: - Deleting a plan

    /// The noun the overflow's spoken label names ("More actions for this
    /// sell plan").
    static let overflowNoun = "sell plan"

    static func deleteTitle(for name: String) -> String {
        "Delete the sell plan for \(name)?"
    }

    /// One sentence frame with one varying clause (plan §3) — so the two
    /// sides cannot drift apart the way `WishlistDeleteCopy`'s did.
    static func deleteMessage(isCompleted: Bool) -> String {
        let clause = isCompleted
            ? "the item you bought stays in your collection"
            : "it stays on your wishlist"
        return "Nothing you own or sold is touched, and \(clause). What sold toward it stays on the record. This can't be undone."
    }

    static let deleteConfirm = "Delete"
    static let deleteCancel = "Keep"

    // MARK: - The dashboard card

    static let cardHeader = "Sell plans"

    static func activeCount(_ n: Int) -> String {
        "\(n) active sell \(n == 1 ? "plan" : "plans")"
    }

    static let cardHint = "Shows your active sell plans"

    // MARK: - Empty states

    static let noPlansHeadline = "No sell plans yet"
    static let noPlansDetail = "A plan starts from something on your wishlist. Open it and tap Create a sell plan."

    static let nothingWantedHeadline = "Nothing on your wishlist"
    static let nothingWantedDetail = "A sell plan starts with something you want. Add it to your wishlist first."

    static let nothingCompletedHeadline = "Nothing completed yet"
    static let nothingCompletedDetail = "A plan lands here when you mark its item bought."

    /// The headline is the app's existing "Catching up with iCloud", not a
    /// second copy of it here.
    static let stillSyncingDetail = "Your plans are on their way to this device. They'll appear here as they arrive."
}

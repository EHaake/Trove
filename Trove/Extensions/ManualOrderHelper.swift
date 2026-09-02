import Foundation

/// A row that carries a user-arranged position. `Item` and `WishlistItem`
/// both do, as of `010` — and the logic that maintains those positions lives
/// once, here, rather than twice in two view models that could quietly drift
/// apart (plan.md's `ManualOrderHelper` section).
///
/// Class-bound because positions are assigned in place on `@Model` objects;
/// a value-type conformer would silently receive positions nothing keeps.
protocol ManuallyOrdered: AnyObject {
    var sortOrder: Int { get set }
}

extension Item: ManuallyOrdered {}
extension WishlistItem: ManuallyOrdered {}

/// The three manual-order jobs both lists share: where a new row goes, how a
/// drag renumbers, and how an attribute sort falls back to the user's own
/// order when it ties.
enum ManualOrderHelper {
    /// The position after everything that exists — max plus one, not a count,
    /// so a gap left by a deletion can't put two rows on the same rung.
    static func nextPosition(after existing: [some ManuallyOrdered]) -> Int {
        (existing.map(\.sortOrder).max() ?? -1) + 1
    }

    /// Applies a drag and renumbers densely, so the stored order matches what
    /// the user just saw.
    ///
    /// Renumbering everything from zero rather than nudging the moved row is
    /// the same choice `PhotoSelection` makes: "position in the list equals
    /// `sortOrder`" is an invariant that's trivial to check and leaves no
    /// room for two rows to collide or drift apart over many moves.
    static func reorder<T: ManuallyOrdered>(
        _ items: [T],
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) -> [T] {
        var reordered = items
        reordered.move(fromOffsets: source, toOffset: destination)
        renumber(reordered)
        return reordered
    }

    /// Makes the given order the stored order: dense, unique, from zero.
    /// Public on its own because inserting a row mid-list (duplication) needs
    /// the renumber without the move.
    static func renumber(_ items: [some ManuallyOrdered]) {
        for (position, item) in items.enumerated() where item.sortOrder != position {
            item.sortOrder = position
        }
    }

    /// Slots a new row immediately after its original and renumbers densely —
    /// the duplicate-placement rule both lists share (spec.md: "placed
    /// immediately after the original in the manual order"). Operates on
    /// whatever ordering the caller passes, which should be the *whole*
    /// collection in manual order, never a filtered slice — placement in a
    /// slice would renumber only what happened to be visible.
    static func insert<T: ManuallyOrdered>(_ newRow: T, after original: T, in ordered: [T]) {
        var result = ordered.filter { $0 !== newRow }
        let index = result.firstIndex { $0 === original } ?? result.count - 1
        result.insert(newRow, at: index + 1)
        renumber(result)
    }

    /// Combines an attribute comparison with manual order as its tie-break —
    /// spec.md's confirmed rule for every non-manual sort: when `primary`
    /// can't decide (returns `nil`), the user's own arrangement does.
    static func areInOrder<T: ManuallyOrdered>(
        _ lhs: T,
        _ rhs: T,
        primary: (T, T) -> Bool?
    ) -> Bool {
        primary(lhs, rhs) ?? (lhs.sortOrder < rhs.sortOrder)
    }

    // MARK: - Custom order (013)

    /// The user's own order, fully determined: manual position first; where
    /// two rows share a position — the real state of a pre-`010` store,
    /// every legacy row at 0 until the first drag renumbers — the entity's
    /// tie-break. Built on `areInOrder` so the position rule is written
    /// once: the "primary" abstains whenever positions differ, and lets the
    /// tie-break speak only when they collide.
    ///
    /// Both list view models sort "Custom" with this, and so does
    /// export-everything (`SettingsViewModel`), which has no view to
    /// follow — one function, not two that happen to agree.
    static func areInCustomOrder<T: ManuallyOrdered>(
        _ lhs: T,
        _ rhs: T,
        tieBreak: (T, T) -> Bool
    ) -> Bool {
        areInOrder(lhs, rhs) { lhs, rhs in
            lhs.sortOrder == rhs.sortOrder ? tieBreak(lhs, rhs) : nil
        }
    }

    /// Items break a shared position by creation order, then id. The
    /// launch-time backfill that used to assign positions was removed at the
    /// T039 close-out (2026-08-30): its per-device flag raced CloudKit sync,
    /// so a second device's upgrade could rewrite an arrangement the first
    /// had already synced. Falling back to `createdAt` at *sort time* shows
    /// the same order the backfill wrote — the order things were added —
    /// with no migration write to race; `id` beneath it keeps even
    /// same-instant creations deterministic.
    static func areInCustomOrder(_ lhs: Item, _ rhs: Item) -> Bool {
        areInCustomOrder(lhs, rhs) { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Wanted items break a shared position by name — case-insensitively,
    /// like every other name comparison in the app — then id, so the order
    /// is fully determined by the data rather than by whatever
    /// `FetchDescriptor` happens to return.
    static func areInCustomOrder(_ lhs: WishlistItem, _ rhs: WishlistItem) -> Bool {
        areInCustomOrder(lhs, rhs) { lhs, rhs in
            let byName = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if byName != .orderedSame {
                return byName == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

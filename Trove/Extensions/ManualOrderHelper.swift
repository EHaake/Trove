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
}

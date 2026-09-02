import Foundation
import Testing
@testable import Trove

/// T009. The helper directly, not through a view model: `WishlistViewModelTests`
/// proves the wishlist still behaves; this proves the shared logic itself, so
/// that when `ItemListViewModel` adopts it (T025) the invariant arrives
/// already guarded instead of re-implemented and re-tested from scratch —
/// plan.md's stated payoff for sharing.
///
/// Runs against a plain class, no SwiftData: `ManuallyOrdered` asks only for
/// a `sortOrder`, and testing through the protocol keeps these tests honest
/// about what the helper can see.
@Suite("Manual order helper")
struct ManualOrderHelperTests {
    private final class Row: ManuallyOrdered {
        let name: String
        var sortOrder: Int
        init(_ name: String, order: Int) {
            self.name = name
            sortOrder = order
        }
    }

    // MARK: - Next-append position

    @Test func theFirstRowLandsAtZero() {
        #expect(ManualOrderHelper.nextPosition(after: [Row]()) == 0)
    }

    /// Max plus one, not a count: after a deletion leaves [0, 5], a
    /// count-based answer of 2 would collide with nothing *yet* — until the
    /// next drag renumbers and two rows fight over one rung. The gap in this
    /// fixture is what makes a count-based mutation fail here.
    @Test func aDeletionGapCannotCauseACollision() {
        let rows = [Row("kept", order: 0), Row("survivor", order: 5)]

        #expect(ManualOrderHelper.nextPosition(after: rows) == 6)
    }

    @Test func thePositionsOrderInTheArrayDoesNotMatter() {
        let rows = [Row("late", order: 3), Row("early", order: 1)]

        #expect(ManualOrderHelper.nextPosition(after: rows) == 4)
    }

    // MARK: - Reorder

    @Test func aMoveRenumbersToMatchWhatTheUserSaw() {
        let rows = [Row("First", order: 0), Row("Second", order: 1), Row("Third", order: 2)]

        let reordered = ManualOrderHelper.reorder(rows, fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(reordered.map(\.name) == ["Third", "First", "Second"])
        #expect(reordered.map(\.sortOrder) == [0, 1, 2])
    }

    /// The invariant, stated the same way `WishlistViewModelTests` states it:
    /// after any sequence of moves, position in the array is `sortOrder`,
    /// with no gaps or collisions.
    @Test func positionsStayDenseAndUniqueAcrossManyMoves() {
        var rows = (0..<6).map { Row("Row \($0)", order: $0) }

        for (from, to) in [(5, 0), (0, 3), (2, 5), (4, 1), (1, 4)] {
            rows = ManualOrderHelper.reorder(rows, fromOffsets: IndexSet(integer: from), toOffset: to)
            #expect(rows.map(\.sortOrder) == Array(0..<rows.count))
        }
    }

    /// Duplication inserts a row mid-list and renumbers without a move —
    /// `renumber` is public for exactly that, so it's pinned on its own.
    @Test func renumberMakesAnyOrderTheStoredOrder() {
        let rows = [Row("a", order: 7), Row("b", order: 7), Row("c", order: 0)]

        ManualOrderHelper.renumber(rows)

        #expect(rows.map(\.sortOrder) == [0, 1, 2])
    }

    /// The duplicate-placement rule (T019/T021), directly: the new row slots
    /// immediately after its original — not at the end — and the whole
    /// ordering renumbers densely around it.
    @Test func insertAfterSlotsTheNewRowAdjacentAndRenumbers() {
        let rows = [Row("Alpha", order: 0), Row("Bravo", order: 1), Row("Charlie", order: 2)]
        let copy = Row("Bravo copy", order: 0)

        ManualOrderHelper.insert(copy, after: rows[1], in: rows)

        let ordered = (rows + [copy]).sorted { $0.sortOrder < $1.sortOrder }
        #expect(ordered.map(\.name) == ["Alpha", "Bravo", "Bravo copy", "Charlie"])
        #expect(ordered.map(\.sortOrder) == [0, 1, 2, 3])
    }

    // MARK: - Tie-break combination

    /// When the attribute decides, manual order must not leak in — otherwise
    /// every sort would just be "Custom" wearing a costume.
    @Test func thePrimaryComparatorWinsWhenItDecides() {
        let cheap = Row("cheap", order: 1)
        let dear = Row("dear", order: 0)

        let byNameLength: (Row, Row) -> Bool? = { lhs, rhs in
            lhs.name.count != rhs.name.count ? lhs.name.count < rhs.name.count : nil
        }

        #expect(ManualOrderHelper.areInOrder(dear, cheap, primary: byNameLength))
        #expect(!ManualOrderHelper.areInOrder(cheap, dear, primary: byNameLength))
    }

    /// spec.md's confirmed rule: ties within a non-manual sort resolve by
    /// manual order — the user's own ranking, not name, not id, not luck.
    @Test func tiesResolveByManualOrder() {
        let ranked = Row("ranked first", order: 0)
        let rankedLater = Row("ranked later", order: 4)
        let alwaysTied: (Row, Row) -> Bool? = { _, _ in nil }

        #expect(ManualOrderHelper.areInOrder(ranked, rankedLater, primary: alwaysTied))
        #expect(!ManualOrderHelper.areInOrder(rankedLater, ranked, primary: alwaysTied))
    }

    // MARK: - Custom order (013)

    private let byName: (Row, Row) -> Bool = { $0.name < $1.name }

    /// Position is the whole answer when positions differ — the tie-break
    /// must not leak in, or "Custom" would quietly become an alphabetical
    /// sort for anyone whose rows happen to be numbered.
    @Test func customOrderIsThePositionWhenPositionsDiffer() {
        let zed = Row("zed", order: 0)
        let alpha = Row("alpha", order: 1)

        #expect(ManualOrderHelper.areInCustomOrder(zed, alpha, tieBreak: byName))
        #expect(!ManualOrderHelper.areInCustomOrder(alpha, zed, tieBreak: byName))
    }

    @Test func aSharedPositionFallsToTheTieBreak() {
        let alpha = Row("alpha", order: 0)
        let bravo = Row("bravo", order: 0)

        #expect(ManualOrderHelper.areInCustomOrder(alpha, bravo, tieBreak: byName))
        #expect(!ManualOrderHelper.areInCustomOrder(bravo, alpha, tieBreak: byName))
    }

    /// The items overload: creation order breaks a shared position, and a
    /// shared instant falls to id — deterministic and antisymmetric, never
    /// "both before each other".
    @Test func itemsBreakASharedPositionByCreationThenID() {
        let older = Item(name: "Older")
        older.createdAt = Date(timeIntervalSince1970: 1_000)
        let newer = Item(name: "Newer")
        newer.createdAt = Date(timeIntervalSince1970: 2_000)

        #expect(ManualOrderHelper.areInCustomOrder(older, newer))
        #expect(!ManualOrderHelper.areInCustomOrder(newer, older))

        let twinA = Item(name: "Twin")
        let twinB = Item(name: "Twin")
        twinA.createdAt = older.createdAt
        twinB.createdAt = older.createdAt
        #expect(ManualOrderHelper.areInCustomOrder(twinA, twinB)
            == (twinA.id.uuidString < twinB.id.uuidString))
        #expect(ManualOrderHelper.areInCustomOrder(twinA, twinB)
            != ManualOrderHelper.areInCustomOrder(twinB, twinA))
    }

    /// Position still wins for the entity overloads: a row the user placed
    /// first stays first however recently it was created.
    @Test func positionOutranksCreationForItems() {
        let placedFirst = Item(name: "Placed first", sortOrder: 0)
        placedFirst.createdAt = Date(timeIntervalSince1970: 2_000)
        let placedSecond = Item(name: "Placed second", sortOrder: 1)
        placedSecond.createdAt = Date(timeIntervalSince1970: 1_000)

        #expect(ManualOrderHelper.areInCustomOrder(placedFirst, placedSecond))
        #expect(!ManualOrderHelper.areInCustomOrder(placedSecond, placedFirst))
    }

    /// The wishlist overload: case-insensitive name breaks a shared
    /// position ("amp" before "Bass"), and identical names fall to id.
    @Test func wantedItemsBreakASharedPositionByNameThenID() {
        let amp = WishlistItem(name: "amp")
        let bass = WishlistItem(name: "Bass")

        #expect(ManualOrderHelper.areInCustomOrder(amp, bass))
        #expect(!ManualOrderHelper.areInCustomOrder(bass, amp))

        let twinA = WishlistItem(name: "Twin")
        let twinB = WishlistItem(name: "Twin")
        #expect(ManualOrderHelper.areInCustomOrder(twinA, twinB)
            == (twinA.id.uuidString < twinB.id.uuidString))
        #expect(ManualOrderHelper.areInCustomOrder(twinA, twinB)
            != ManualOrderHelper.areInCustomOrder(twinB, twinA))
    }
}

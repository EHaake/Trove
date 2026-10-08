import Foundation
import Testing
@testable import Trove

/// `NewOrUsedCopy`'s table, pinned whole (the `PurchaseCopyTests` model), and
/// the clear-on-tap rule's four cases (plan P1) — guard G7.
///
/// The CSV headers are not here: they stay in `ExportSchema`, the schema's
/// one home (plan §2), and are pinned where that is.
@Suite("New or used copy")
struct NewOrUsedCopyTests {
    // MARK: - The fixed strings

    /// Form labels go through `.monoLabel()`, which uppercases, so the spec's
    /// **BOUGHT** and **LOOKING FOR** are these strings rendered.
    @Test func theFieldLabels() {
        #expect(NewOrUsedCopy.boughtLabel == "Bought")
        #expect(NewOrUsedCopy.lookingForLabel == "Looking for")
    }

    @Test func theChips() {
        #expect(NewOrUsedCopy.chip(.new) == "New")
        #expect(NewOrUsedCopy.chip(.used) == "Used")
    }

    // MARK: - The item page's purchase-date row

    /// The existing purchase-date row's label (R1). Not recorded is plain
    /// "Bought" — today's page row (P3), so an item nobody has answered the
    /// question for reads exactly as it did before 020.
    @Test func theDetailDateRowLabel() {
        #expect(NewOrUsedCopy.detailDateRowLabel(bought: nil) == "Bought")
        #expect(NewOrUsedCopy.detailDateRowLabel(bought: .new) == "Bought new")
        #expect(NewOrUsedCopy.detailDateRowLabel(bought: .used) == "Bought used")
    }

    // MARK: - The clear-on-tap rule

    /// A tap on a chip that is not the one selected selects it — from
    /// nothing, and from the other chip.
    @Test func tappingAnUnselectedChipSelectsIt() {
        #expect(NewOrUsed.selection(afterTapping: .new, current: nil) == .new)
        #expect(NewOrUsed.selection(afterTapping: .used, current: .new) == .used)
    }

    /// P1: a tap on the chip already selected clears the field, which is the
    /// only way back to "not recorded" — nil is never a third chip.
    ///
    /// Mutation: return `tapped` always → both of these fail.
    @Test func tappingTheSelectedChipClearsIt() {
        #expect(NewOrUsed.selection(afterTapping: .new, current: .new) == nil)
        #expect(NewOrUsed.selection(afterTapping: .used, current: .used) == nil)
    }
}

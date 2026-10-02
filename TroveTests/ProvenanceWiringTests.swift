import Foundation
import Testing
@testable import Trove

/// `020` G14's and G15's source scans (plan §6). Facts about view bodies
/// only, which no view-model test can observe: which chip component a form
/// composes, and that the shared fields carry the two calls the design rests
/// on. What the chips *do* is elsewhere — that the row is one row, overflows,
/// scrolls and opens on the selected grade is the UI suite's; that tapping
/// the selected chip clears the field is `NewOrUsed`'s own tests'.
///
/// Deliberately absent: a scan for `ScrollView(.horizontal` (the UI tests
/// reach that behaviour) and one for "no `FlowLayout(`" (the type is deleted;
/// the compiler is the guard).
///
/// Each scan `#require`s its anchor before asserting anything about it, so a
/// renamed or deleted declaration fails loudly here rather than passing over
/// nothing.
@Suite("Provenance wiring")
struct ProvenanceWiringTests {
    private nonisolated static let itemForm = "Trove/Views/Items/ItemFormView.swift"
    private nonisolated static let purchaseSheet = "Trove/Views/Wishlist/PurchaseFormView.swift"
    private nonisolated static let chips = "Trove/Views/Shared/ChoiceChips.swift"

    /// Both forms draw the condition row through the one shared field, and
    /// neither draws a capsule of its own — which is what makes "the chips
    /// match" structural rather than a thing to eyeball.
    ///
    /// Mutations: paste the old private chip back into either form → red
    /// (its `Capsule()`); compose the field twice, or not at all → red.
    @Test(arguments: [itemForm, purchaseSheet])
    func eachFormComposesTheSharedConditionFieldOnceAndDrawsNoChipOfItsOwn(path: String) throws {
        let code = try SourceScan.production(path)

        let fields = code.components(separatedBy: "ConditionField(").count - 1
        try #require(fields > 0, "\(path) doesn't compose `ConditionField(` at all")
        #expect(fields == 1, "\(path) composes `ConditionField(` \(fields) times, expected exactly 1")

        #expect(
            !code.contains("Capsule()"),
            "\(path) draws a `Capsule()` of its own — the chips are `ChoiceChip`'s, in \(Self.chips)"
        )
    }

    /// The condition row draws through the gutter rather than clipping at
    /// it. **This pins a spelling, not the look**: whether a chip really does
    /// show cut off at the screen edge is untested, and stays with eyes.
    ///
    /// Mutation: remove `.scrollClipDisabled()` → red.
    @Test func theConditionRowIsNotClippedAtTheGutter() throws {
        let field = try declaration("struct ConditionField: View")

        #expect(
            field.contains(".scrollClipDisabled()"),
            "`ConditionField` doesn't carry `.scrollClipDisabled()` — the row would clip at the gutter, with no chip cut off at the screen edge:\n\(field)"
        )
    }

    /// The Bought / Looking for chips decide what a tap selects by asking
    /// `NewOrUsed`, whose rule — tapping the selected chip clears the field —
    /// is tested there. A toggle written out in the view would be a second,
    /// untested copy of it.
    ///
    /// Mutation: a hand-rolled toggle in place of the call → red.
    @Test func theNewOrUsedFieldAsksTheModelWhatATapSelects() throws {
        let field = try declaration("struct NewOrUsedField: View")

        #expect(
            field.contains("NewOrUsed.selection(afterTapping:"),
            "`NewOrUsedField` doesn't call `NewOrUsed.selection(afterTapping:current:)`:\n\(field)"
        )
    }

    // MARK: - Private

    /// The body of the one declaration in `ChoiceChips.swift` that opens with
    /// `header`.
    private func declaration(_ header: String) throws -> String {
        let code = try SourceScan.production(Self.chips)
        let bodies = SourceScan.closureBodies(after: header, in: code)
        try #require(bodies.count == 1, "\(Self.chips) declares `\(header)` \(bodies.count) times, expected exactly 1")
        return try #require(bodies.first)
    }
}

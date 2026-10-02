import Foundation
import Testing
@testable import Trove

/// `020` G14's and G15's source scans (plan §6). Facts about view bodies
/// only, which no view-model test can observe: which chip component a form
/// composes, where the Bought field sits and what it is identified by, and
/// that the shared fields carry the two calls the design rests on. What the
/// chips *do* is elsewhere — that the row is one row, overflows,
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

    // MARK: - Where Bought is set (G15)

    /// Each form that records how the thing was bought composes the shared
    /// `NewOrUsedField` exactly once, under the Bought label and the "bought"
    /// identifier. The identifier is what addresses the chips ("bought.new",
    /// "bought.used"): the condition row on the same screen has a "New" chip
    /// too, so a label cannot tell the two apart.
    ///
    /// Where the field sits is the next test's on the item form, and
    /// `WishlistPurchaseWiringTests`' order test's on the purchase sheet.
    ///
    /// Mutations: drop the field from either form → the anchor `#require`
    /// fails; compose it twice → red; give it another label or identifier →
    /// red.
    @Test(arguments: [itemForm, purchaseSheet])
    func eachFormComposesTheBoughtFieldOnceWithItsLabelAndIdentifier(path: String) throws {
        let code = try SourceScan.production(path)

        let fields = SourceScan.argumentLists(of: "NewOrUsedField", in: code)
        let field = try #require(fields.first, "\(path) doesn't compose `NewOrUsedField(` at all")
        #expect(fields.count == 1, "\(path) composes `NewOrUsedField(` \(fields.count) times, expected exactly 1")

        #expect(
            field.contains("label: NewOrUsedCopy.boughtLabel"),
            "\(path)'s Bought field isn't labelled from `NewOrUsedCopy.boughtLabel`:\n\(field)"
        )
        #expect(
            field.contains("identifier: \"bought\""),
            "\(path)'s Bought field doesn't carry the \"bought\" identifier its chips are addressed by:\n\(field)"
        )
    }

    /// On the item form the Bought field sits directly above the condition
    /// row, inside More details: the two chip rows read together, and
    /// Condition keeps its notes beneath it (plan §6). Directly — nothing is
    /// composed between the two — so a field moved up the section fails here
    /// as one moved below Condition does.
    ///
    /// Mutations: move the field below Condition → red; move it anywhere
    /// else in More details → red; drop it → the anchor `#require` fails.
    @Test func theItemFormsBoughtFieldSitsDirectlyAboveItsConditionRow() throws {
        let code = try SourceScan.production(Self.itemForm)

        let sections = SourceScan.closureBodies(after: "private var optionalFields: some View", in: code)
        try #require(
            sections.count == 1,
            "\(Self.itemForm) declares `optionalFields` \(sections.count) times, expected exactly 1"
        )
        let section = try #require(sections.first)

        let fields = SourceScan.argumentLists(of: "NewOrUsedField", in: section)
        try #require(
            fields.count == 1,
            "More details composes `NewOrUsedField(` \(fields.count) times, expected exactly 1"
        )
        let call = try #require(section.range(of: "NewOrUsedField(\(fields[0]))"))

        let next = section[call.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(
            next.hasPrefix("ConditionField("),
            "the Bought field isn't directly above the condition row — what follows it is:\n\(next.prefix(120))"
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

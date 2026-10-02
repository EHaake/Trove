import Foundation
import Testing
@testable import Trove

/// `020` G14's, G15's and G16's source scans (plan §6 and §7). Facts about
/// view bodies only, which no view-model test can observe: which chip
/// component a form composes, where the Bought and Looking for fields sit and
/// what each is identified by, that the shared fields carry the two calls the
/// design rests on, and that each page's Details row is built from its own
/// item's field. What the
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
    private nonisolated static let wishlistForm = "Trove/Views/Wishlist/WishlistFormView.swift"
    private nonisolated static let chips = "Trove/Views/Shared/ChoiceChips.swift"
    private nonisolated static let itemPage = "Trove/Views/Items/ItemDetailView.swift"
    private nonisolated static let wishlistPage = "Trove/Views/Wishlist/WishlistDetailView.swift"

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

    // MARK: - Where Looking for is set (G15)

    /// The wishlist form's `lookingForField` is the shared `NewOrUsedField`,
    /// composed exactly once in the file, under the Looking for label and the
    /// "lookingFor" identifier — what addresses its chips ("lookingFor.new",
    /// "lookingFor.used"), since the purchase sheet this entry leads to has a
    /// Bought field with the same two words.
    ///
    /// Where the field sits is the next test's.
    ///
    /// Mutations: build `lookingForField` from anything else → the anchor
    /// `#require` fails; compose the shared field a second time → red; give
    /// it another label or identifier → red.
    @Test func theWishlistFormsLookingForFieldIsTheSharedFieldOnceWithItsLabelAndIdentifier() throws {
        let code = try SourceScan.production(Self.wishlistForm)

        let declarations = SourceScan.closureBodies(after: "private var lookingForField: some View", in: code)
        let fields = declarations.flatMap { SourceScan.argumentLists(of: "NewOrUsedField", in: $0) }
        let field = try #require(
            fields.first,
            "\(Self.wishlistForm)'s `lookingForField` doesn't compose `NewOrUsedField(` — or isn't declared at all"
        )

        let composed = SourceScan.argumentLists(of: "NewOrUsedField", in: code).count
        #expect(
            composed == 1,
            "\(Self.wishlistForm) composes `NewOrUsedField(` \(composed) times, expected exactly 1"
        )

        #expect(
            field.contains("label: NewOrUsedCopy.lookingForLabel"),
            "\(Self.wishlistForm)'s Looking for field isn't labelled from `NewOrUsedCopy.lookingForLabel`:\n\(field)"
        )
        #expect(
            field.contains("identifier: \"lookingFor\""),
            "\(Self.wishlistForm)'s Looking for field doesn't carry the \"lookingFor\" identifier its chips are addressed by:\n\(field)"
        )
    }

    /// On the wishlist form Looking for sits directly after the desire gauge
    /// and before the photos (plan §6). Directly — nothing is composed
    /// between the gauge and it — so a field moved up the form fails here as
    /// one moved below the photos does.
    ///
    /// Mutations: move the field below `PhotoPickerField` → red, on both
    /// expectations; drop it from the body → the anchor `#require` fails.
    @Test func theWishlistFormsLookingForFieldSitsDirectlyAfterDesireAndBeforeThePhotos() throws {
        let code = try SourceScan.production(Self.wishlistForm)

        let bodies = SourceScan.closureBodies(after: "var body: some View", in: code)
        try #require(
            bodies.count == 1,
            "\(Self.wishlistForm) declares `body` \(bodies.count) times, expected exactly 1"
        )
        let body = try #require(bodies.first)

        let around = body.components(separatedBy: "lookingForField")
        try #require(
            around.count == 2,
            "the wishlist form's body composes `lookingForField` \(around.count - 1) times, expected exactly 1"
        )

        let previous = around[0].trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(
            previous.hasSuffix("desireField"),
            "the Looking for field isn't directly after `desireField` — what precedes it is:\n\(previous.suffix(120))"
        )
        #expect(
            around[1].contains("PhotoPickerField("),
            "the Looking for field isn't before `PhotoPickerField(` — what follows it is:\n\(around[1].prefix(200))"
        )
    }

    // MARK: - What the two pages show (G16)

    /// The item's page labels a Details row from the item's own `bought`:
    /// "Bought new", "Bought used", or plain "Bought" when not recorded. The
    /// words are `NewOrUsedCopyTests'`; that the page hands the function
    /// *this item's* field is a fact about the view body, where the rows are
    /// built.
    ///
    /// **This scan and the next are the whole of the unit coverage for the
    /// two rows.** What a person sees on the page is the UI suite's.
    ///
    /// Mutation: the literal `"Bought"` restored in place of the call → red.
    @Test func theItemPagesDateRowIsLabelledFromTheItemsBoughtField() throws {
        let details = try detailsBody(in: Self.itemPage, of: "Item")

        #expect(
            details.contains("NewOrUsedCopy.detailDateRowLabel(bought: item.bought)"),
            "\(Self.itemPage)'s `details(for:)` doesn't label a row from `NewOrUsedCopy.detailDateRowLabel(bought: item.bought)`:\n\(details)"
        )
    }

    /// The wanted item's page builds one Details row under the Looking for
    /// label, and its value is the item's own `lookingFor` put through
    /// `NewOrUsedCopy.chip` — empty when not recorded, which the table's
    /// existing empty-value filter drops (P3).
    ///
    /// Mutation: the row's value reading a constant → red.
    @Test func theWantedPagesLookingForRowReadsTheItemsLookingForField() throws {
        let details = try detailsBody(in: Self.wishlistPage, of: "WishlistItem")

        let around = details.components(separatedBy: "NewOrUsedCopy.lookingForLabel")
        try #require(
            around.count == 2,
            "\(Self.wishlistPage)'s `details(for:)` builds a row under `NewOrUsedCopy.lookingForLabel` \(around.count - 1) times, expected exactly 1"
        )

        let value = around[1].drop(while: { $0 == "," || $0.isWhitespace })
        #expect(
            value.hasPrefix("item.lookingFor.map(NewOrUsedCopy.chip)"),
            "the wanted page's Looking for row doesn't read `item.lookingFor` — its value is:\n\(value.prefix(120))"
        )
    }

    // MARK: - Private

    /// The body of the one `details(for:)` a page declares for `model`.
    private func detailsBody(in path: String, of model: String) throws -> String {
        let code = try SourceScan.production(path)
        let header = "private func details(for item: \(model)) -> some View"
        let bodies = SourceScan.closureBodies(after: header, in: code)
        try #require(bodies.count == 1, "\(path) declares `\(header)` \(bodies.count) times, expected exactly 1")
        return try #require(bodies.first)
    }

    /// The body of the one declaration in `ChoiceChips.swift` that opens with
    /// `header`.
    private func declaration(_ header: String) throws -> String {
        let code = try SourceScan.production(Self.chips)
        let bodies = SourceScan.closureBodies(after: header, in: code)
        try #require(bodies.count == 1, "\(Self.chips) declares `\(header)` \(bodies.count) times, expected exactly 1")
        return try #require(bodies.first)
    }
}

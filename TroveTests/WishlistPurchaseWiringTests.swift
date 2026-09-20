import Testing
@testable import Trove

/// T007, G21. The purchase sheet's load-bearing wiring, pinned as source
/// scans — `SaleFormWiringTests`' shape, for the same reason: no unit test can
/// tap a date in a popover or press a toolbar button, so what a test *can*
/// catch is a view body quietly changing out from under the spec. These are
/// facts about the body only. The sheet's *behaviour* — what the comparison
/// line says, what validation refuses, what a purchase carries — is
/// `PurchaseFormViewModelTests`' and is deliberately not restated here.
///
/// Each scan `#require`s its anchor before asserting anything about it, so a
/// renamed or deleted call fails loudly here rather than passing over nothing.
@Suite("Wishlist purchase sheet wiring")
struct WishlistPurchaseWiringTests {
    private nonisolated static let sheet = "Trove/Views/Wishlist/PurchaseFormView.swift"
    private nonisolated static let list = "Trove/Views/Wishlist/WishlistView.swift"

    /// The spec's field order, twice over: the five elements are *declared* in
    /// that order, and the sheet's one column *composes* them in that order —
    /// two different edits, and either alone would move the comparison line
    /// out from under the price it comments on.
    ///
    /// Mutation: swap any two of the five, in either place → red.
    @Test func theFiveElementsAppearInTheSpecsOrder() throws {
        let code = try SourceScan.production(Self.sheet)

        try expectAscending(
            [
                "PurchaseCopy.purchasePriceLabel",
                "PurchaseCopy.purchaseDateLabel",
                "viewModel.comparisonLine",
                "PurchaseCopy.boughtFromLabel",
                "PurchaseCopy.conditionLabel",
            ],
            in: code,
            what: "the sheet's fields, declared"
        )

        let columns = SourceScan.closureBodies(
            after: "VStack(alignment: .leading, spacing: theme.metrics.sectionGap)",
            in: code
        )
        try #require(columns.count == 1, "the sheet builds \(columns.count) form columns, expected exactly 1")
        let column = try #require(columns.first)

        try expectAscending(
            ["priceAndDate", "comparison", "boughtFromField", "conditionField"],
            in: column,
            what: "the sheet's fields, composed"
        )
    }

    /// The sheet writes nothing and borrows nothing: it hands a `Purchase`
    /// to its host, so no store and no context appear here (the rule
    /// `SaleFormView` holds), and its words are its own — a `SaleCopy` string
    /// or a note field would be the sale sheet leaking into its twin, which
    /// this spec's non-goals rule out in both directions.
    ///
    /// Mutation: name any of the four → red.
    @Test func theSheetNamesNoSaleCopyNoNoteAndNothingThatWrites() throws {
        let code = try SourceScan.production(Self.sheet)

        #expect(
            !code.contains("SaleCopy"),
            "the purchase sheet reads SaleCopy — every word here comes from PurchaseCopy"
        )
        #expect(
            !code.contains("Note"),
            "the purchase sheet has a note field — the spec's four fields are the whole sheet"
        )
        #expect(
            !code.contains("ModelContext") && !code.contains("modelContext"),
            "the purchase sheet reaches a ModelContext — the host records the purchase, this view doesn't"
        )
        #expect(
            !code.contains("WishlistPurchaseStore"),
            "the purchase sheet writes through WishlistPurchaseStore — the host records the purchase, this view doesn't"
        )
    }

    /// Confirming asks the view model first: the toolbar button runs
    /// `record`, and `record` guards on `viewModel.purchase()` — returning
    /// rather than handing anything out when it comes back nil, which is how
    /// an invalid sheet stays open with the rust border on.
    ///
    /// Mutation: have `record` call `confirm` without the guard, or ahead of
    /// it → red.
    @Test func confirmingHandsThePurchaseOutPastTheViewModelsGuard() throws {
        let code = try SourceScan.production(Self.sheet)

        let confirmButtons = SourceScan.argumentLists(of: "Button", in: code)
            .filter { $0.contains("viewModel.confirmLabel") }
        try #require(
            confirmButtons.count == 1,
            "the sheet builds \(confirmButtons.count) confirm buttons, expected exactly 1"
        )
        let confirmButton = try #require(confirmButtons.first)
        #expect(
            confirmButton.contains("action: record"),
            "the confirm button doesn't run `record`:\n\(confirmButton)"
        )

        let bodies = SourceScan.closureBodies(after: "private func record()", in: code)
        try #require(bodies.count == 1, "the sheet declares \(bodies.count) `record` functions, expected exactly 1")
        let record = try #require(bodies.first)

        let guardWord = try #require(record.range(of: "guard"), "`record` doesn't guard:\n\(record)")
        let asks = try #require(
            record.range(of: "viewModel.purchase()"),
            "`record` never asks the view model for a purchase:\n\(record)"
        )
        let handsOut = try #require(
            record.range(of: "confirm("),
            "`record` never hands a purchase to its host:\n\(record)"
        )

        #expect(guardWord.lowerBound < asks.lowerBound, "`viewModel.purchase()` isn't the guard's own call:\n\(record)")
        #expect(
            asks.upperBound < handsOut.lowerBound,
            "`record` hands a purchase out before asking the view model for one:\n\(record)"
        )
        #expect(
            record.contains("else { return }"),
            "`record`'s guard doesn't return — an invalid sheet must stay open:\n\(record)"
        )
    }

    /// The two identifiers T012's device pass and any later UI test drive the
    /// sheet by. Whole literals, not substrings: a scan for
    /// `contains("purchase.sheet.comparison")` is satisfied by
    /// `"purchase.sheet.comparisonX"`, so a renamed identifier would slip
    /// past it — measured, not guessed. Mutation: rename or delete either →
    /// red.
    @Test func theIdentifiersArePresent() throws {
        let code = try SourceScan.production(Self.sheet)
        let literals = Set(SourceScan.stringLiterals(in: code))
        #expect(literals.contains("purchase.sheet.price"), "the price field's identifier is missing or renamed")
        #expect(
            literals.contains("purchase.sheet.comparison"),
            "the comparison line's identifier is missing or renamed"
        )
    }

    /// Q9, the one deliberate divergence from the twin: the purchase date is
    /// **unbounded**. `SaleFormView`'s picker carries `in: ...viewModel.latestDate`
    /// because a sale in the future is not a sale; this sheet fills
    /// `Item.purchaseDate`, whose own editor takes any date at all. The bound
    /// is a fact about the popover's own control, which no view-model test can
    /// observe — `PurchaseFormViewModelTests` can only show that a future date
    /// validates, not that it is selectable.
    ///
    /// Mutation: paste a bound back in → red.
    @Test func theDatePickerIsUnbounded() throws {
        let code = try SourceScan.production(Self.sheet)

        let pickers = SourceScan.argumentLists(of: "DatePicker", in: code)
        try #require(pickers.count == 1, "the sheet builds \(pickers.count) DatePickers, expected exactly 1")
        let picker = try #require(pickers.first)

        #expect(
            picker.contains("selection: $viewModel.date"),
            "the picker doesn't write the view model's date:\n\(picker)"
        )
        #expect(
            !picker.contains("in:"),
            "the purchase date picker carries a bound — Q9 leaves it unbounded, as Item.purchaseDate's own editor is:\n\(picker)"
        )
    }

    // MARK: - The list's swipe (G15)

    /// G15, criterion 1 from the list's side: the wishlist row's one leading
    /// swipe is Edit, **Buy**, Copy in that order — Edit still nearest the
    /// edge, so a full swipe still edits — the middle button stages the row
    /// for the purchase sheet rather than the form sheet, says `markAsBought`
    /// to VoiceOver while reading "Buy" on screen (plan Q14), and wears the
    /// brass mid-tone and the bag glyph; the trailing swipe is still the
    /// delete alone, naming nothing about buying.
    ///
    /// The three buttons are cut apart at their own `Button` keywords rather
    /// than scanned over the whole block, so *which* button carries which
    /// word, target and tint is what's pinned — a block containing all three
    /// words in any arrangement would otherwise pass. `ItemListSidesWiringTests`'
    /// twin, since `014` settled this shape on the Items list.
    ///
    /// Mutations: swap the Buy and Copy buttons → red; the middle button
    /// writing `itemBeingEdited` → red.
    @Test func theWishlistRowsLeadingSwipeOffersEditThenBuyThenCopy() throws {
        let code = try SourceScan.production(Self.list)

        let trailing = SourceScan.closureBodies(after: ".swipeActions(edge: .trailing)", in: code)
        try #require(trailing.count == 1, "the wishlist rows carry \(trailing.count) trailing swipe blocks, expected exactly 1")
        #expect(
            !trailing[0].contains("PurchaseCopy"),
            "the trailing swipe names PurchaseCopy — buying belongs on the leading swipe, the delete stays alone (criterion 1): \(trailing[0])"
        )

        let blocks = SourceScan.closureBodies(after: ".swipeActions(edge: .leading)", in: code)
        try #require(blocks.count == 1, "the wishlist rows carry \(blocks.count) leading swipe blocks, expected exactly 1")
        let leading = try #require(blocks.first)

        let starts = leading.ranges(of: "Button").map(\.lowerBound)
        try #require(
            starts.count == 3,
            "the leading swipe carries \(starts.count) buttons, expected 3 — Edit, Buy, Copy"
        )
        let buttons = starts.indices.map { index -> String in
            let end = index + 1 < starts.count ? starts[index + 1] : leading.endIndex
            return String(leading[starts[index]..<end])
        }

        #expect(
            buttons[0].contains("Text(\"Edit\")"),
            "the button nearest the edge isn't Edit — a full swipe would stop editing (criterion 1): \(buttons[0])"
        )
        #expect(buttons[0].contains("itemBeingEdited = item"), "the first button doesn't open the form sheet: \(buttons[0])")

        #expect(
            buttons[1].contains("Text(PurchaseCopy.swipeBuy)"),
            "the middle button doesn't read the swipe's own word: \(buttons[1])"
        )
        #expect(
            buttons[1].contains("itemBeingBought = item"),
            "the middle button doesn't stage the row for the purchase sheet: \(buttons[1])"
        )
        #expect(
            buttons[1].contains(".accessibilityLabel(PurchaseCopy.markAsBought)"),
            "the Buy button doesn't say the menu row's own name to VoiceOver (plan Q14): \(buttons[1])"
        )
        #expect(buttons[1].contains("Image(\"ActionBuy\")"), "the Buy button wears no bag glyph: \(buttons[1])")
        #expect(
            buttons[1].contains(".tint(theme.colors.accentBrassMid)"),
            "the Buy button isn't the brass mid-tone — the one brass that reads mid in both appearances (plan Q14): \(buttons[1])"
        )
        #expect(
            !buttons[1].contains("accentRust"),
            "the Buy button is rust, which stays the one consequential colour on a swiped-open row: \(buttons[1])"
        )

        #expect(buttons[2].contains("Text(\"Copy\")"), "the last button isn't Copy: \(buttons[2])")
        #expect(buttons[2].contains("viewModel.duplicate"), "the last button doesn't duplicate: \(buttons[2])")
    }

    /// G15's other half: the purchase sheet is hosted here, once, over the
    /// row's own entry — the `.sheet(item:)` shape the Items list uses for the
    /// sale sheet (014 plan §5), so two rows can never both be being bought —
    /// seeded by the view model's factory rather than a `PurchaseFormViewModel`
    /// built in the view, confirming through `markBought` and clearing the
    /// staging on both exits. The write stays the view model's: the screen
    /// never names the store itself (plan Q4).
    ///
    /// Mutation: drop `itemBeingBought = nil` from the confirm closure → red
    /// (the sheet would stay up over a bought entry).
    @Test func thePurchaseSheetIsHostedOnceOverTheStagedRow() throws {
        let code = try SourceScan.production(Self.list)

        #expect(
            code.ranges(of: ".sheet(item: $itemBeingBought").count == 1,
            "the list presents \(code.ranges(of: ".sheet(item: $itemBeingBought").count) purchase sheets, expected exactly 1"
        )
        #expect(
            code.contains(".sheet(item: $itemBeingBought, onDismiss: viewModel.load)"),
            "the purchase sheet doesn't re-read the list on dismiss, so a bought entry would linger on the wishlist"
        )

        let bodies = SourceScan.closureBodies(after: ".sheet(item: $itemBeingBought", in: code)
        try #require(bodies.count == 1, "the purchase sheet opens \(bodies.count) spans, expected exactly 1")
        let sheet = try #require(bodies.first)

        #expect(sheet.contains("PurchaseFormView("), "the purchase sheet composes something other than the shared purchase form: \(sheet)")
        #expect(
            sheet.contains("viewModel.makePurchaseFormViewModel(for: item)"),
            "the sheet seeds its own form instead of the view model's, which is what keeps every host's defaults equal: \(sheet)"
        )
        #expect(
            sheet.contains("viewModel.markBought(item, purchase: purchase)"),
            "the sheet confirms into something other than `markBought`: \(sheet)"
        )
        #expect(
            sheet.ranges(of: "itemBeingBought = nil").count == 2,
            "the sheet clears its staging \(sheet.ranges(of: "itemBeingBought = nil").count) times, expected 2 — confirm and cancel both close it"
        )

        #expect(
            !code.contains("WishlistPurchaseStore"),
            "the list names the purchase store directly — the write belongs behind the view model"
        )
    }

    // MARK: - Private

    /// Each token present, and each one's first appearance after the last —
    /// first appearance, so a later mention can't stand in for the missing
    /// one.
    private func expectAscending(_ tokens: [String], in source: String, what: String) throws {
        var offsets: [Int] = []
        for token in tokens {
            let range = try #require(source.range(of: token), "\(what): `\(token)` is missing")
            offsets.append(source.distance(from: source.startIndex, to: range.lowerBound))
        }

        for index in offsets.indices.dropFirst() {
            #expect(
                offsets[index] > offsets[index - 1],
                "\(what): `\(tokens[index])` comes before `\(tokens[index - 1])` — expected \(tokens)"
            )
        }
    }
}

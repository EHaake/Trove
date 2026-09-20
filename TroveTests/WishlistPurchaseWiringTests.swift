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

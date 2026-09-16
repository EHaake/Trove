import Testing
@testable import Trove

/// T013. The sale sheet's load-bearing wiring, pinned as source scans — the
/// `ExportWiringTests` / `PhotoPickerWiringTests` shape, for the same reason:
/// no unit test can tap a date in a popover or press a toolbar button, so what
/// a test *can* catch is the wiring quietly changing out from under the spec.
///
/// Each scan `#require`s its anchor before asserting anything about it, so a
/// renamed or deleted call fails loudly here rather than passing over nothing.
@Suite("Sale sheet wiring")
struct SaleFormWiringTests {
    private nonisolated static let sheet = "Trove/Views/Items/SaleFormView.swift"

    /// Spec criterion 2 / P2: the date picker is bounded, and its ceiling is
    /// the view model's `latestDate` — the clock, read afresh — rather than a
    /// captured or invented date. Mutation: drop the `in:` argument → red.
    @Test func theDatePickerIsBoundedAtLatestDate() throws {
        let code = try SourceScan.production(Self.sheet)

        let pickers = SourceScan.argumentLists(of: "DatePicker", in: code)
        try #require(pickers.count == 1, "the sheet builds \(pickers.count) DatePickers, expected exactly 1")
        let picker = try #require(pickers.first)

        #expect(
            picker.contains("in: ...viewModel.latestDate"),
            "the sale date picker has no upper bound at latestDate — a future day is selectable:\n\(picker)"
        )
        #expect(
            picker.contains("selection: $viewModel.date"),
            "the picker doesn't write the view model's date:\n\(picker)"
        )
    }

    /// The sheet hands `sale()`'s value out and records nothing itself: the
    /// confirm button runs `viewModel.sale()`, and no `ModelContext` is
    /// touched anywhere in the file (`DeletionGuardTests`' no-store-in-views
    /// instinct, one file at a time). Mutation: write the sale here → red.
    @Test func confirmingHandsTheSaleOutAndWritesNothing() throws {
        let code = try SourceScan.production(Self.sheet)

        let confirms = SourceScan.argumentLists(of: "Button", in: code)
            .filter { $0.contains("viewModel.confirmLabel") }
        try #require(confirms.count == 1, "the sheet builds \(confirms.count) confirm buttons, expected exactly 1")

        #expect(code.contains("viewModel.sale()"), "the sheet never asks the view model for the sale")
        #expect(code.contains("confirm(sale)"), "the sheet doesn't hand the sale to its host")
        #expect(
            !code.contains("modelContext"),
            "the sale sheet reaches a ModelContext — the host records the sale, this view doesn't"
        )
        #expect(
            !code.contains("ItemSaleStore"),
            "the sale sheet writes through ItemSaleStore — the host records the sale, this view doesn't"
        )
    }

    /// Every word on the sheet comes from `SaleCopy` (the 005/T007 shape):
    /// each label and placeholder is wired by name, the title and confirm
    /// label come from the view model — which reads `SaleCopy` itself, by
    /// mode — and no string literal in the file carries a space, which is
    /// what proves no copy was typed inline where this scan can't see it.
    @Test func everyWordComesFromSaleCopy() throws {
        let code = try SourceScan.production(Self.sheet)

        for member in [
            "SaleCopy.cancel",
            "SaleCopy.salePriceLabel",
            "SaleCopy.soldOnLabel",
            "SaleCopy.soldAtLabel",
            "SaleCopy.soldAtPlaceholder",
            "SaleCopy.noteLabel",
            "SaleCopy.notePlaceholder",
        ] {
            #expect(code.contains(member), "the sheet doesn't read \(member)")
        }

        #expect(code.contains("viewModel.title"), "the sheet titles itself rather than reading the mode's title")
        #expect(
            code.contains("viewModel.confirmLabel"),
            "the sheet labels its confirm button rather than reading the mode's label"
        )

        let inlined = SourceScan.stringLiterals(in: code).filter { $0.contains(" ") }
        #expect(inlined.isEmpty, "copy typed inline in the sale sheet: \(inlined)")
    }

    /// The two identifiers the UI suite and the device pass drive the sheet
    /// by (T013's task line).
    @Test func theIdentifiersArePresent() throws {
        let code = try SourceScan.production(Self.sheet)
        #expect(code.contains("sale.sheet.price"))
        #expect(code.contains("sale.sheet.confirm"))
    }

    /// The Design pass's size and bar: both detents, so the sheet has
    /// somewhere to go when the keyboard rises, and Cancel in the bar rather
    /// than a bottom save bar.
    @Test func theSheetTakesBothDetentsAndCarriesCancelInTheBar() throws {
        let code = try SourceScan.production(Self.sheet)

        let detents = SourceScan.argumentLists(of: "presentationDetents", in: code)
        try #require(detents.count == 1, "the sheet sets \(detents.count) detent lists, expected exactly 1")
        let detent = try #require(detents.first)
        #expect(detent.contains(".medium"), "the sheet doesn't offer the medium detent")
        #expect(detent.contains(".large"), "the sheet can't grow when the keyboard rises")

        #expect(code.contains("placement: .cancellationAction"), "Cancel isn't in the bar")
        #expect(code.contains("placement: .confirmationAction"), "the confirm button isn't in the bar")
    }
}

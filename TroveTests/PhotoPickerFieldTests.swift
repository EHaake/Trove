import Testing
@testable import Trove

/// Wiring guards for `PhotoPickerField`'s replace/keep prompt (T010).
///
/// An alert's runtime presentation isn't unit-inspectable without a
/// third-party tool, so the prompt's correctness is decomposed in two: the
/// pure predicate and list helpers are proven by `PhotoSelectionReplaceKeepTests`,
/// and this scan proves the field actually consults them and wires the alert.
/// It reads the field's *production* source (comments stripped, `#Preview`
/// dropped by `SourceScan.production`) so a guard can't be satisfied by a
/// comment or a preview.
@Suite("PhotoPickerField — replace/keep wiring")
struct PhotoPickerFieldTests {
    private static let field = "Trove/Views/Shared/PhotoPickerField.swift"

    /// The field draws the alert and reads every word of the prompt from
    /// `StockPhotoCopy` — none typed inline.
    @Test func drawsTheAlertFromStockPhotoCopy() throws {
        let code = try SourceScan.production(Self.field)
        #expect(code.contains(".alert("), "the field draws no alert")
        #expect(code.contains("StockPhotoCopy.replaceKeepMessage"), "the alert doesn't use the pinned question")
        #expect(code.contains("StockPhotoCopy.keepBoth"), "the alert has no Keep both button")
        #expect(code.contains("StockPhotoCopy.replace"), "the alert has no Replace button")
    }

    /// The field consults the pure decision and both list helpers.
    /// **Mutation (the "append silently" case):** in `load(_:)`, remove the
    /// prompt branch and append straight away → the `shouldPromptReplaceOrKeep`
    /// (and `addingKeepingStock` / `addingReplacingStock`) checks go red.
    @Test func consultsPhotoSelectionForTheDecisionAndTheOutcomes() throws {
        let code = try SourceScan.production(Self.field)
        #expect(code.contains("PhotoSelection.shouldPromptReplaceOrKeep"), "the field never asks whether to prompt")
        #expect(code.contains("PhotoSelection.addingReplacingStock"), "Replace isn't wired to the helper")
        #expect(code.contains("PhotoSelection.addingKeepingStock"), "Keep both isn't wired to the helper")
    }
}

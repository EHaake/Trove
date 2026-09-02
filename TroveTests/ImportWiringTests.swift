import Foundation
import Testing
@testable import Trove

/// 012's load-bearing wiring claims, pinned as source scans — the
/// `ExportWiringTests` shape, for the same reason: no unit test can tap a
/// menu item, but a scan catches the wiring quietly changing out from under
/// the spec. Grows at T014 with the view-layer wiring; this slice is
/// T011's commit-path guard.
@Suite("Import wiring")
struct ImportWiringTests {
    private nonisolated static let viewModels = [
        "Trove/ViewModels/ItemListViewModel.swift",
        "Trove/ViewModels/WishlistViewModel.swift",
    ]

    /// Criterion 14's never-a-partial-batch, on the commit side: the
    /// catch in `confirmImport` must roll the context back before staging
    /// the failure. This scan is the falsifiable half of the guard — the
    /// rollback *mechanism* is tested in the commit suites, and forcing a
    /// real SwiftData save failure deterministically is not practical
    /// (plan §The commit path records that honestly).
    @Test(arguments: viewModels)
    func confirmImportRollsBackOnSaveFailure(path: String) throws {
        let code = try SourceScan.production(path)
        let bodies = SourceScan.closureBodies(after: "func confirmImport", in: code)
        try #require(bodies.count == 1, "\(path) should define exactly one confirmImport")
        #expect(
            bodies[0].contains("modelContext.rollback()"),
            "\(path) confirmImport's failure path must roll back the context"
        )
    }

    private nonisolated static let lists = [
        "Trove/Views/Items/ItemListView.swift",
        "Trove/Views/Wishlist/WishlistView.swift",
    ]

    /// 012 criterion 1's structural half: the overflow control lives
    /// OUTSIDE every `totalCount > 0` gate, on both screens — the badge
    /// must exist on a fresh install. The sort badge staying *inside* one
    /// of those gates proves the scan is looking at the real header, not
    /// an empty span. The empty-collection UI test is this guard's
    /// behavioral twin; re-nesting the control must turn both red.
    @Test(arguments: lists)
    func theOverflowControlSitsOutsideEveryEmptyCollectionGate(path: String) throws {
        let code = try SourceScan.production(path)
        try #require(code.contains("overflowControl"), "\(path) doesn't build the overflow control")

        let gatedSpans = SourceScan.closureBodies(after: "if viewModel.totalCount > 0", in: code)
        try #require(!gatedSpans.isEmpty, "\(path) has no totalCount gates — wrong scan target?")
        #expect(
            gatedSpans.contains { $0.contains("sortControl") },
            "\(path): the sort badge should still hide when empty — did the header move?"
        )
        for span in gatedSpans {
            #expect(
                !span.contains("overflowControl"),
                "\(path) nests the overflow control inside a totalCount gate — criterion 1 broken"
            )
        }
    }

    /// The picker's contract: attached on both screens, offering both
    /// content types — `.plainText` deliberately, since mailed CSVs are
    /// routinely `.txt` and the header gate is the real filter.
    @Test(arguments: lists)
    func theFileImporterIsAttachedWithBothContentTypes(path: String) throws {
        let code = try SourceScan.production(path)
        #expect(code.contains(".fileImporter("), "\(path) doesn't attach the file picker")
        #expect(code.contains("$isPickingImportFile"), "\(path) picker not driven by the badge's state")
        #expect(code.contains(".commaSeparatedText"), "\(path) picker missing the CSV type")
        #expect(code.contains(".plainText"), "\(path) picker missing the plain-text type")
        #expect(
            code.contains("viewModel.importCSV(from: url)"),
            "\(path) a picked URL must start the view-model flow"
        )
    }

    /// The one import alert, wired to the one presentation optional, with
    /// the confirm/cancel intents and the dismiss-only informational case.
    @Test(arguments: lists)
    func theImportAlertPresentsOffTheSinglePresentation(path: String) throws {
        let code = try SourceScan.production(path)
        #expect(code.contains("viewModel.importAlertTitle"), "\(path) alert title not composed by the VM")
        #expect(code.contains("viewModel.importAlertMessage"), "\(path) alert message not composed by the VM")
        #expect(code.contains("viewModel.importPresentation != nil"), "\(path) alert not driven by the presentation")
        #expect(code.contains("viewModel.importOffersConfirmation"), "\(path) informational case not handled")
        #expect(code.contains("viewModel.confirmImport()"), "\(path) Import button doesn't commit")
        #expect(code.contains("viewModel.cancelImport()"), "\(path) Cancel doesn't clear the staging")
        // The T017 device finding, pinned: the Import button must call the
        // intent SYNCHRONOUSLY. A `Task { await ... }` wrapper defers the
        // preview capture past the alert's own dismissal write (the
        // isPresented binding sets the presentation nil on any button),
        // and the guard then reads nil — Import silently does nothing.
        #expect(
            !code.contains("await viewModel.confirmImport"),
            "\(path) wraps confirmImport in a Task — the dismissal write will race the capture"
        )
    }
}

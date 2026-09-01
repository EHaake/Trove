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
}

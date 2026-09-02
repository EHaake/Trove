import Foundation
import Testing
@testable import Trove

/// T015. 011's load-bearing wiring claims, pinned as source scans — the
/// `ReorderWiringTests` shape, for the same reason: no unit test can tap a
/// menu item or cancel a share sheet, so what a test *can* catch is the
/// wiring quietly changing out from under the spec.
@Suite("Export wiring")
struct ExportWiringTests {
    private nonisolated static let lists = [
        "Trove/Views/Items/ItemListView.swift",
        "Trove/Views/Wishlist/WishlistView.swift",
    ]

    /// Each list screen builds exactly one `OverflowBadge` (012's rename of
    /// `ExportBadge`), fed by the view model's own state and firing all
    /// four intents — 011's criterion-1/2 wiring plus 012's criterion 1.
    @Test(arguments: lists)
    func theBadgeIsFedByTheViewModelAndFiresAllFourIntents(path: String) throws {
        let code = try SourceScan.production(path)
        let calls = SourceScan.argumentLists(of: "OverflowBadge", in: code)
        #expect(calls.count == 1, "\(path) builds \(calls.count) OverflowBadges, expected exactly 1")
        for call in calls {
            #expect(call.contains("isBusy: viewModel.isBusy"), "\(path) badge not fed isBusy")
            #expect(call.contains("canExport: viewModel.canExport"), "\(path) badge not fed canExport")
            #expect(call.contains("viewModel.exportCSV()"), "\(path) badge doesn't fire exportCSV")
            #expect(call.contains("viewModel.exportPDF()"), "\(path) badge doesn't fire exportPDF")
            #expect(call.contains("isPickingImportFile = true"), "\(path) badge doesn't open the picker")
            #expect(
                call.contains("viewModel.exportBlankTemplate()"),
                "\(path) badge doesn't fire the template intent"
            )
        }
    }

    /// Delivery and failure surfaces: the share sheet presents off
    /// `stagedExport` and the criterion-2a alert off `exportFailureMessage`,
    /// on both screens.
    @Test(arguments: lists)
    func theShareSheetAndFailureAlertAreWired(path: String) throws {
        let code = try SourceScan.production(path)
        #expect(code.contains(".sheet(item: $viewModel.stagedExport)"), "\(path) doesn't present the share sheet")
        #expect(code.contains("ExportCopy.failureTitle"), "\(path) doesn't use the shared failure title")
        #expect(code.contains("viewModel.exportFailureMessage"), "\(path) doesn't wire the failure state")
    }

    /// The menu's contract after 012: all four pinned strings and the
    /// divider between the export and import groups; the two *export*
    /// actions individually gated on `canExport` and — the count being
    /// exactly 2 — the import actions provably ungated, since an empty
    /// collection is exactly who they serve (012 criterion 1).
    @Test func theMenuCarriesFourActionsWithOnlyExportsGated() throws {
        let code = try SourceScan.production("Trove/Views/Shared/OverflowBadge.swift")
        let literals = SourceScan.stringLiterals(in: code)
        #expect(literals.contains("Export as CSV…"))
        #expect(literals.contains("Export as PDF…"))
        #expect(literals.contains("Import from CSV…"))
        #expect(literals.contains("Get Blank Template…"))
        #expect(code.contains("Divider()"), "the export and import groups must stay visually separated")
        #expect(
            code.ranges(of: ".disabled(!canExport)").count == 2,
            "exactly the two export actions gate on canExport — imports must stay ungated"
        )
    }

    /// The constitution's UIKit boundary, pinned as a walk: the activity
    /// controller lives only in `ShareSheet.swift`, and `import UIKit`
    /// appears only in the two flagged exception files.
    @Test func uiKitStaysInsideTheFlaggedExceptions() throws {
        let allowedImports = [
            "Trove/Views/Shared/ShareSheet.swift",
            "Trove/Extensions/Image+Data.swift",
        ]
        for path in try Self.allAppSwiftFiles() {
            let code = try SourceScan.production(path)
            if code.contains("UIActivityViewController") {
                #expect(
                    path == "Trove/Views/Shared/ShareSheet.swift",
                    "\(path) reaches UIActivityViewController outside the flagged exception"
                )
            }
            if code.contains("import UIKit") {
                #expect(allowedImports.contains(path), "\(path) imports UIKit unflagged")
            }
        }
    }

    /// Criterion 10's launch half is actually called at startup — the
    /// static sweep exists whether or not anything invokes it.
    @Test func theLaunchSweepIsWiredIntoAppStartup() throws {
        let code = try SourceScan.production("Trove/App/TroveApp.swift")
        #expect(code.contains("FileExportService.purgeAtLaunch()"))
    }

    /// Same walk as `ReorderWiringTests` — asserted non-trivial so a moved
    /// source root fails loudly instead of scanning nothing and passing.
    private static func allAppSwiftFiles(file: StaticString = #filePath) throws -> [String] {
        let root = URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Trove")
        let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var paths: [String] = []
        while let url = walker?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                paths.append("Trove/" + url.path.replacingOccurrences(of: root.path + "/", with: ""))
            }
        }
        try #require(paths.count > 20, "source walk found only \(paths.count) files — wrong root?")
        return paths.sorted()
    }
}

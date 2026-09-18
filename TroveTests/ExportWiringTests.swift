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

    /// A list screen and the two gate expressions its dropdown must be fed
    /// (006, plan Q5). Separate arguments rather than one, because the Items
    /// list feeds two different flags and the Wishlist feeds one flag twice —
    /// a scan for a single `canExport:` can no longer say which.
    nonisolated struct DropdownGates: Sendable {
        let path: String
        let csv: String
        let pdf: String
        /// The exact CSV intent this screen's row must fire. Per screen since
        /// 014/T009b, and since T009e the two screens don't even fire the same
        /// *kind* of thing: the Items list's row opens the scope chooser
        /// (Decision 7 — the scope is chosen there, so the row exports
        /// nothing itself), while the Wishlist's still exports directly. A
        /// scan for one shared literal could not tell the two apart.
        let csvAction: String
        /// The exact PDF intent, per screen for the same reason since
        /// 014/T009d — and re-pointed at the chooser at T009e, like the CSV
        /// one above. Re-pointed, never broadened: each screen still names
        /// one literal, so either row quietly going back to a direct export
        /// (or to the wrong format's chooser) fails here.
        let pdfAction: String
    }

    private nonisolated static let gates = [
        DropdownGates(
            path: "Trove/Views/Items/ItemListView.swift",
            csv: "canExportCSV: viewModel.canExportCSV",
            pdf: "canExportPDF: viewModel.canExportPDF",
            csvAction: "openDropdown = .exportScope(.csv)",
            pdfAction: "openDropdown = .exportScope(.pdf)"
        ),
        DropdownGates(
            path: "Trove/Views/Wishlist/WishlistView.swift",
            csv: "canExportCSV: viewModel.canExport",
            pdf: "canExportPDF: viewModel.canExport",
            csvAction: "viewModel.exportCSV()",
            pdfAction: "viewModel.exportPDF()"
        ),
    ]

    /// Each list screen builds exactly one `OverflowBadge` (012's rename of
    /// `ExportBadge`; since 013 Amendment A the pill alone), fed the view
    /// model's busy state and opening the overflow on the screen's host —
    /// and exactly one `OverflowDropdown`, fed both export gates (006) and firing the
    /// three list intents and Settings: 011's criterion-1/2 wiring, 012's
    /// criterion 1, and 013's criterion 1, which took the template intent
    /// out of this menu.
    @Test(arguments: gates)
    func theBadgeOpensTheDropdownWhichFiresEveryIntentAndOpensSettings(gates: DropdownGates) throws {
        let path = gates.path
        let code = try SourceScan.production(path)

        let badges = SourceScan.argumentLists(of: "OverflowBadge", in: code)
        #expect(badges.count == 1, "\(path) builds \(badges.count) OverflowBadges, expected exactly 1")
        #expect(badges.first?.contains("isBusy: viewModel.isBusy") == true, "\(path) badge not fed isBusy")
        let opens = SourceScan.closureBodies(after: "OverflowBadge(isBusy: viewModel.isBusy)", in: code)
        #expect(opens.first?.contains("openDropdown = .overflow") == true, "\(path) badge doesn't open the overflow")

        let dropdowns = SourceScan.argumentLists(of: "OverflowDropdown", in: code)
        #expect(dropdowns.count == 1, "\(path) builds \(dropdowns.count) OverflowDropdowns, expected exactly 1")
        for call in dropdowns {
            #expect(call.contains(gates.csv), "\(path) dropdown not fed \(gates.csv)")
            #expect(call.contains(gates.pdf), "\(path) dropdown not fed \(gates.pdf)")
            #expect(call.contains(gates.csvAction), "\(path) dropdown doesn't fire \(gates.csvAction)")
            #expect(call.contains(gates.pdfAction), "\(path) dropdown doesn't fire \(gates.pdfAction)")
            #expect(call.contains("isPickingImportFile = true"), "\(path) dropdown doesn't open the picker")
            #expect(call.contains("isShowingSettings = true"), "\(path) dropdown doesn't open Settings")
            #expect(
                !call.contains("exportBlankTemplate"),
                "\(path) dropdown still fires the template intent 013 moved to Settings"
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

    /// The menu's contract after 013 (criterion 1), on the surface Amendment
    /// A moved it to: five items in three groups — the two exports, Import,
    /// Settings — with the template gone to Settings; the two *export* rows
    /// each gated on its own flag (006/G29) and, the count being exactly 2,
    /// Import and Settings provably ungated, since an empty collection is
    /// exactly who they serve; the two group breaks on exactly the Import
    /// and Settings rows (`startsGroup`, which replaced the system menu's
    /// two `Divider()`s); and Settings last, in its own group.
    @Test func theMenuCarriesFiveItemsInThreeGroups() throws {
        let code = try SourceScan.production("Trove/Views/Shared/OverflowDropdown.swift")
        let literals = SourceScan.stringLiterals(in: code)
        #expect(literals.contains("Export as CSV…"))
        #expect(literals.contains("Export as PDF…"))
        #expect(literals.contains("Import from CSV…"))
        #expect(literals.contains("Settings"))
        #expect(!literals.contains("Get Blank Template…"), "the template left this menu for Settings")

        let rows = SourceScan.argumentLists(of: "DropdownRow", in: code)
        try #require(rows.count == 4, "four rows, found \(rows.count)")
        #expect(rows[0].contains("Export as CSV…") && rows[0].contains("isEnabled: canExportCSV"))
        #expect(rows[1].contains("Export as PDF…") && rows[1].contains("isEnabled: canExportPDF"))
        #expect(rows[2].contains("Import from CSV…") && rows[2].contains("startsGroup: true"))
        #expect(rows[3].contains("Settings") && rows[3].contains("startsGroup: true"))
        // 006/G29 broadened, not weakened: one gate each, on its own flag —
        // the two rows sharing one flag was the whole of the old contract and
        // is now the failure — and still exactly two gates in the file, which
        // is what proves Import and Settings ungated.
        #expect(
            code.ranges(of: "isEnabled: canExportCSV").count == 1,
            "the CSV row must gate on canExportCSV, once"
        )
        #expect(
            code.ranges(of: "isEnabled: canExportPDF").count == 1,
            "the PDF row must gate on canExportPDF, once"
        )
        #expect(
            code.ranges(of: "isEnabled:").count == 2,
            "exactly the two export rows are gated — Import and Settings must stay ungated"
        )
        #expect(code.ranges(of: "startsGroup: true").count == 2, "three groups need two breaks")
    }

    /// G37 — the scope chooser the two export rows now open (014 Decision 7,
    /// spec P12 and criterion 14). That they *open* it rather than export is
    /// pinned per screen in `gates` above, alongside the Wishlist's rows,
    /// which still export directly; this is what the Items list's host draws
    /// when they do: one titled surface, one row per scope in the enum's own
    /// order, each gated on that scope's own rows, and one action handing the
    /// scope to whichever intent the format names.
    ///
    /// The `no literal` half is the load-bearing one: a chooser that named
    /// `.owned` or `.both` anywhere inside it would be exporting a fixed half
    /// under a row that says otherwise — which is the six-row menu plan Q14
    /// refused, wearing a chooser's clothes.
    @Test func theItemsListComposesTheScopeChooserOverEveryScope() throws {
        let code = try SourceScan.production("Trove/Views/Items/ItemListView.swift")

        let surfaces = SourceScan.argumentLists(of: "DropdownSurface", in: code)
        try #require(surfaces.count == 1, "the Items list composes \(surfaces.count) DropdownSurfaces, expected exactly 1")
        #expect(surfaces[0].hasPrefix("title:"), "the chooser's surface carries no header")
        #expect(surfaces[0].contains("ExportCopy.scopeTitleCSV"), "the CSV header isn't the shared copy")
        #expect(surfaces[0].contains("ExportCopy.scopeTitlePDF"), "the PDF header isn't the shared copy")

        let chooser = try #require(
            SourceScan.closureBodies(after: "case .exportScope(let format):", in: code).first,
            "the host draws nothing for .exportScope"
        )
        #expect(
            chooser.ranges(of: "ForEach(ItemListViewModel.ExportScope.allCases").count == 1,
            "the chooser must list every scope, once — a hand-written row set can go stale"
        )

        let rows = SourceScan.argumentLists(of: "DropdownRow", in: chooser)
        try #require(rows.count == 1, "one row built per scope, found \(rows.count) DropdownRows")
        #expect(rows[0].contains("title: scope.label"), "the row doesn't name its scope from the enum")
        #expect(
            rows[0].contains("isEnabled: viewModel.canExport(scope)"),
            "the row must be gated on its own scope — a menu-level flag enables rows with nothing in them"
        )

        #expect(chooser.contains("viewModel.exportCSV(scope: scope)"), "the CSV action doesn't carry the row's scope")
        #expect(chooser.contains("viewModel.exportPDF(scope: scope)"), "the PDF action doesn't carry the row's scope")
        for literal in [".owned", ".sold", ".both"] {
            #expect(
                !chooser.contains(literal),
                "the chooser names \(literal) — the scope must travel from the row it was chosen on"
            )
        }

        // `DropdownHost` draws a dropdown only for an identifier that has an
        // anchor, so the badge wears all three: drop one and that row opens a
        // chooser nothing positions or renders (plan Q17).
        let badge = try #require(
            SourceScan.closureBodies(after: "private var overflowControl: some View", in: code).first,
            "the Items list has no overflowControl"
        )
        for anchor in [
            ".dropdownAnchor(HeaderDropdown.overflow)",
            ".dropdownAnchor(HeaderDropdown.exportScope(.csv))",
            ".dropdownAnchor(HeaderDropdown.exportScope(.pdf))",
        ] {
            try #require(badge.contains(anchor), "overflowControl is missing \(anchor)")
        }
    }

    /// The chooser's two headers as the spec writes them (P12), pinned by
    /// literal beside the failure copy they share an enum with.
    @Test func theScopeChooserHeadersReadAsTheSpecWritesThem() {
        #expect(ExportCopy.scopeTitleCSV == "EXPORT AS CSV")
        #expect(ExportCopy.scopeTitlePDF == "EXPORT AS PDF")
    }

    /// The constitution's UIKit boundary, pinned as a walk: the activity
    /// controller lives only in `ShareSheet.swift`, and `import UIKit`
    /// appears only in the flagged exception files.
    @Test func uiKitStaysInsideTheFlaggedExceptions() throws {
        let allowedImports = [
            "Trove/Views/Shared/ShareSheet.swift",
            "Trove/Extensions/Image+Data.swift",
        ]
        for path in try SourceScan.swiftFiles(under: "Trove", minimum: 20) {
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
}

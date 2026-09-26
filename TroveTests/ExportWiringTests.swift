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

    /// One row of a list's "…" menu, as the screen writes it (`018` plan §2):
    /// where it starts, the one gate that may follow it before the next row,
    /// and the action its segment must carry. A row with no gate is provably
    /// ungated — nothing between it and the next row says `.disabled(`.
    nonisolated struct MenuRow: Sendable {
        /// The row's whole opening, matched as a literal: a titled `Button`,
        /// a `Divider()`, or the Items list's `exportMenu(_:)` call.
        let start: String
        /// The whole `.disabled(…)` this row wears, or nil for an ungated row.
        var gate: String? = nil
        /// A literal the row's segment must contain — its intent or its
        /// navigation. Nil for a `Divider()`, and for the Items list's two
        /// submenus, whose rows `theItemsListsExportRowsAreSubmenusOverEveryScope`
        /// reads.
        var action: String? = nil
    }

    /// A list screen and its "…" menu, row by row in order (spec "The '…'
    /// menus", criterion 2): two export rows, Import, then Settings, in three
    /// groups. The Wishlist's two exports are buttons that export directly
    /// and keep their ellipsis, each gated on the one flag a wishlist has;
    /// the Items list's are submenus (plan Q9), ungated here because their
    /// gates live in `exportMenu(_:)`.
    nonisolated struct ListMenu: Sendable {
        let path: String
        let rows: [MenuRow]
    }

    private nonisolated static let menus = [
        ListMenu(path: "Trove/Views/Items/ItemListView.swift", rows: [
            MenuRow(start: "exportMenu(.csv)"),
            MenuRow(start: "exportMenu(.pdf)"),
            MenuRow(start: "Divider()"),
            MenuRow(start: "Button(\"Import from CSV…\")", action: "isPickingImportFile = true"),
            MenuRow(start: "Divider()"),
            MenuRow(start: "Button(\"Settings\")", action: "isShowingSettings = true"),
        ]),
        ListMenu(path: "Trove/Views/Wishlist/WishlistView.swift", rows: [
            MenuRow(
                start: "Button(\"Export as CSV…\")",
                gate: ".disabled(!viewModel.canExport)",
                action: "Task { await viewModel.exportCSV() }"
            ),
            MenuRow(
                start: "Button(\"Export as PDF…\")",
                gate: ".disabled(!viewModel.canExport)",
                action: "Task { await viewModel.exportPDF() }"
            ),
            MenuRow(start: "Divider()"),
            MenuRow(start: "Button(\"Import from CSV…\")", action: "isPickingImportFile = true"),
            MenuRow(start: "Divider()"),
            MenuRow(start: "Button(\"Settings\")", action: "isShowingSettings = true"),
        ]),
    ]

    /// A menu row's opening, for reading a menu's rows in order: a titled
    /// `Button`, a `Divider()`, or an `exportMenu(_:)` call, each on a word
    /// boundary so a longer name ending in the same word never counts.
    private let rowStart = #"(?:^|[^A-Za-z0-9_])(Button\("[^"]*"\)|Divider\(\)|exportMenu\(\.[a-z]+\))"#

    /// The content of the one `OverflowMenu` a list's `overflowControl`
    /// builds, split into one segment per row — each running from its row's
    /// opening to the next one's — with the row openings in order.
    private func menuSegments(_ path: String) throws -> (starts: [String], segments: [String]) {
        let code = try SourceScan.production(path)
        let controls = SourceScan.closureBodies(after: "private var overflowControl: some View", in: code)
        try #require(controls.count == 1, "\(path) declares \(controls.count) `overflowControl`s, expected exactly 1")
        let control = try #require(controls.first)
        let menus = SourceScan.closureBodies(after: "OverflowMenu(", in: control)
        try #require(menus.count == 1, "\(path)'s overflowControl builds \(menus.count) OverflowMenus, expected exactly 1: \(control)")
        let content = try #require(menus.first)
        let matches = content.matches(of: try Regex(rowStart, as: (Substring, Substring).self))
        let starts = matches.map { String($0.output.1) }
        var segments: [String] = []
        for (index, match) in matches.enumerated() {
            let end = index + 1 < matches.count ? matches[index + 1].range.lowerBound : content.endIndex
            segments.append(String(content[match.range.lowerBound..<end]))
        }
        return (starts, segments)
    }

    /// G8. Each list screen builds exactly one `OverflowMenu`, in its
    /// `overflowControl`, fed the view model's busy state (criterion 4) —
    /// and each of its rows fires what it did: the Wishlist's two exports
    /// straight into their intents, Import into the file picker, Settings
    /// into its sheet (011's criterion-1/2 wiring, 012's criterion 1, 013's
    /// criterion 1). The template intent 013 moved to Settings stays out.
    ///
    /// Mutations (T005): see `eachListsMenuCarriesItsRowsInThreeGroupsWithOnlyTheExportsGated`
    /// and `theItemsListsExportRowsAreSubmenusOverEveryScope`, which share
    /// this reading.
    @Test(arguments: menus)
    func eachListBuildsOneMenuFedItsBusyStateWhoseRowsFireEveryIntent(menu: ListMenu) throws {
        let path = menu.path
        let code = try SourceScan.production(path)

        let calls = SourceScan.argumentLists(of: "OverflowMenu", in: code)
        #expect(calls.count == 1, "\(path) builds \(calls.count) OverflowMenus, expected exactly 1")
        #expect(calls.first == "isBusy: viewModel.isBusy", "\(path)'s menu isn't fed `isBusy: viewModel.isBusy`: \(calls)")

        let (starts, segments) = try menuSegments(path)
        try #require(
            starts == menu.rows.map(\.start),
            "\(path)'s menu rows are \(starts), expected \(menu.rows.map(\.start))"
        )
        for (row, segment) in zip(menu.rows, segments) {
            if let action = row.action {
                #expect(segment.contains(action), "\(path): \(row.start) doesn't fire `\(action)`: \(segment)")
            }
            #expect(
                !segment.contains("exportBlankTemplate"),
                "\(path): \(row.start) fires the template intent 013 moved to Settings"
            )
        }
        #expect(
            !SourceScan.stringLiterals(in: code).contains("Get Blank Template…"),
            "\(path) still offers the template 013 moved to Settings"
        )
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

    /// G8, the menu's contract after 013 (criterion 1) as `018` writes it —
    /// the rows in order in three groups, the two exports then Import then
    /// Settings, with two `Divider()`s between them (plan Q9, the pre-`013`
    /// system menu's breaks); each row wearing exactly the gate its entry
    /// names and nothing else. Import and Settings are provably ungated —
    /// no `.disabled(` anywhere between their openings and the next row's —
    /// since an empty collection is exactly who they serve (criterion 2).
    ///
    /// Its mutation (T005): Import on the Items list gated
    /// `.disabled(!viewModel.canExportCSV)` → red (the ungated leg).
    @Test(arguments: menus)
    func eachListsMenuCarriesItsRowsInThreeGroupsWithOnlyTheExportsGated(menu: ListMenu) throws {
        let path = menu.path
        let (starts, segments) = try menuSegments(path)
        try #require(
            starts == menu.rows.map(\.start),
            "\(path)'s menu rows are \(starts), expected \(menu.rows.map(\.start))"
        )
        #expect(starts.filter { $0 == "Divider()" }.count == 2, "\(path): three groups need two breaks")
        #expect(starts.last == "Button(\"Settings\")", "\(path): Settings is last, in its own group")
        for (row, segment) in zip(menu.rows, segments) {
            let gates = SourceScan.argumentLists(of: ".disabled", in: segment).map { ".disabled(\($0))" }
            if let gate = row.gate {
                #expect(gates == [gate], "\(path): \(row.start) is gated \(gates), expected exactly [\(gate)]")
            } else {
                #expect(gates.isEmpty, "\(path): \(row.start) is gated \(gates) — it must stay ungated")
            }
        }
    }

    /// G8, G37 as `018` writes it (plan Q9; spec criteria 2 and 3, 014
    /// Decision 7): the Items list's two export rows are submenus titled
    /// "Export as CSV" / "Export as PDF", without the ellipsis (spec P2) —
    /// written once by `exportMenu(_:)`: one row per scope in the enum's own
    /// order, each gated on that scope's own rows, and one action handing the
    /// row's scope to whichever intent the format names. While the format's
    /// own flag is false the row is a plain `Button` under the same title,
    /// `.disabled(true)`: a `Menu`'s `.disabled` is not honoured inside a
    /// system menu on iOS 27.0 (T005's finding), so the branch on the
    /// format's own flag is the gate.
    ///
    /// The `no literal` half is the load-bearing one: a submenu that named
    /// `.owned` or `.both` anywhere inside it would be exporting a fixed half
    /// under a row that says otherwise — which is the six-row menu 014 plan
    /// Q14 refused, wearing a submenu's clothes.
    ///
    /// Mutations (T005): the PDF branch on the CSV flag → red (the branch
    /// leg); `.disabled(true)` dropped from the else branch → red (the else
    /// leg); the CSV action exporting `.both` directly → red (the scope
    /// literal and the scope-carrying action); the title "Export as CSV…" →
    /// red (the titles and the no-ellipsis leg).
    @Test func theItemsListsExportRowsAreSubmenusOverEveryScope() throws {
        let path = "Trove/Views/Items/ItemListView.swift"
        let code = try SourceScan.production(path)
        let helpers = SourceScan.closureBodies(after: "private func exportMenu(_ format: ExportFormat) -> some View", in: code)
        try #require(helpers.count == 1, "the Items list declares \(helpers.count) `exportMenu(_:)`s, expected exactly 1")
        let helper = try #require(helpers.first)

        #expect(
            helper.contains("let title = format == .csv ? \"Export as CSV\" : \"Export as PDF\""),
            "the export rows aren't titled \"Export as CSV\" / \"Export as PDF\" by format: \(helper)"
        )
        #expect(
            helper.contains("let isEnabled = format == .csv ? viewModel.canExportCSV : viewModel.canExportPDF"),
            "each format's row must branch on its own format's flag: \(helper)"
        )
        let enabled = SourceScan.closureBodies(after: "if isEnabled", in: helper)
        try #require(enabled.count == 1, "`exportMenu(_:)` branches on `isEnabled` \(enabled.count) times, expected exactly 1: \(helper)")
        #expect(
            SourceScan.argumentLists(of: "Menu", in: enabled[0]).first == "title",
            "the enabled branch isn't the submenu under the row's title: \(enabled[0])"
        )
        let disabled = SourceScan.closureBodies(after: "} else", in: helper)
        try #require(disabled.count == 1, "`exportMenu(_:)` has \(disabled.count) else branches, expected exactly 1: \(helper)")
        #expect(
            disabled[0].contains(try Regex(#"Button\(title\)\s*\{\s*\}\s*\.disabled\(true\)"#)),
            "with nothing to export the row must be a plain `Button(title) {}` wearing `.disabled(true)` (criterion 2): \(disabled[0])"
        )
        let literals = SourceScan.stringLiterals(in: code)
        for title in ["Export as CSV…", "Export as PDF…"] {
            #expect(
                !literals.contains(title),
                "the Items list still titles a row \"\(title)\" — a row that opens a submenu drops its ellipsis (spec P2)"
            )
        }

        #expect(
            helper.ranges(of: "ForEach(ItemListViewModel.ExportScope.allCases)").count == 1,
            "the submenu must list every scope, once — a hand-written row set can go stale"
        )
        let rows = SourceScan.argumentLists(of: "Button", in: enabled[0])
        #expect(rows == ["scope.label"], "one row built per scope, named from the enum: \(rows)")
        let gates = SourceScan.argumentLists(of: ".disabled", in: enabled[0]).map { ".disabled(\($0))" }
        #expect(
            gates == [".disabled(!viewModel.canExport(scope))"],
            "each scope row must be gated on its own scope, and nothing else: \(gates)"
        )

        #expect(helper.contains("case .csv: await viewModel.exportCSV(scope: scope)"), "the CSV action doesn't carry the row's scope")
        #expect(helper.contains("case .pdf: await viewModel.exportPDF(scope: scope)"), "the PDF action doesn't carry the row's scope")
        for literal in [".owned", ".sold", ".both"] {
            #expect(
                !helper.contains(literal),
                "the submenu names \(literal) — the scope must travel from the row it was chosen on"
            )
        }
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

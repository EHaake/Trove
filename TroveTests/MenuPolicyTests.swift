import Foundation
import Testing
@testable import Trove

/// `018` criterion 10 (spec Decision 12, plan §7): **every "…", sort and
/// order control opens a system menu, and no view floats a surface of its
/// own.** The app draws no menu, picker or segmented switch of its own; the
/// system's controls are the rule, glass is kept to the header's controls
/// and the add button, and no UIKit appearance proxy reaches them
/// (criterion 8).
///
/// **This replaces `013` Amendment A** (Decision 17, criterion 27) —
/// "bespoke inside the page, system in the bars" — which this suite held
/// from `013` until `018`: an allowlist of the files that might host a
/// system `Menu`, the detail screens' nav-bar "…" the only one at first,
/// and a ban on one anywhere else. `018` reversed the rule, so the suite
/// asserts the opposite now and the allowlist is gone.
///
/// Four tests, each a fact about view bodies that no view model can
/// observe — `CLAUDE.md`'s legitimate source-scan shape — each walking the
/// view files or `#require`-ing its anchors, so a renamed control or a moved
/// root fails rather than being skipped. Every call-site match is on a
/// word boundary, spelled out as "start of text or a non-identifier
/// character" since Swift's `Regex` has no lookbehind: `Menu {` is a system
/// menu and `DetailOverflowMenu(` is not.
///
/// **One control in the header opens no menu, by decision**: the side
/// toggle (`SideToggle`, spec Decision 19) is one glass button whose tap
/// shows the other side. G12a pins that it is a `Button` hosting no `Menu`;
/// its shape is `ItemListSidesWiringTests`' and `PlansWiringTests`' (G10).
///
/// **What it does not claim**: a bespoke control built some other way — an
/// `HStack` of buttons with a selected trait — is invisible to these scans.
/// G12a's positive half (each named control composes the system menu) and
/// review are what catch that.
@Suite("Menu policy")
struct MenuPolicyTests {
    /// A system menu composed at a call site: `Menu {` or `Menu(` on a word
    /// boundary, so `DetailOverflowMenu(` and `SortMenu(` never count.
    private let systemMenu = #"(?:^|[^A-Za-z0-9_])Menu\s*[({]"#

    /// Each tab root's sort or order control, by name (plan §7): Sort By on
    /// the three lists, the Overview's "BY VALUE" order control.
    private let orderingControls: [String: String] = [
        "ItemListView": "sortControl",
        "WishlistView": "sortControl",
        "PlansView": "sortControl",
        "DashboardView": "orderControl",
    ]

    /// Every screen: the views, and the app folder that composes them
    /// (`ContentView` is a screen too).
    private func screenFiles() throws -> [String] {
        try SourceScan.swiftFiles(under: "Trove/Views", minimum: 40)
            + SourceScan.swiftFiles(under: "Trove/App", minimum: 5)
    }

    /// The file declaring `struct <name>: View`, found by its declaration.
    private func file(declaring name: String, in files: [String]) throws -> String {
        let declaration = "struct \(name): View"
        let matches = try files.filter { try SourceScan.production($0).contains(declaration) }
        try #require(matches.count == 1, "expected one file declaring `\(declaration)`, found \(matches)")
        return matches[0]
    }

    /// G12a. The tab roots are derived from `ContentView`'s `Tab(` closures
    /// (`SettingsWiringTests.everyTabsRootReachesSettings`' derivation), as
    /// many as `AppRouter.Tab.allCases`. Each root's `overflowControl`
    /// composes `OverflowMenu(`; its sort or order control, required by name
    /// and declared exactly once, composes `SortMenu(` — or, on the Overview,
    /// a system `Menu` directly. `SortMenu`, `OverflowMenu` and
    /// `DetailOverflowMenu` each compose one. The side toggle is a `Button`
    /// and composes no `Menu` (Decision 19).
    ///
    /// Mutation (T011, criterion 10's "a bespoke row put back"): the
    /// Wishlist's `sortControl` a `Button` toggling a `@State` that shows an
    /// `.overlay` of hand-drawn rows → red.
    @Test func everyMenuControlOpensASystemMenu() throws {
        let menu = try Regex(systemMenu)
        let content = try SourceScan.production("Trove/App/ContentView.swift")
        let tabs = SourceScan.closureBodies(after: "Tab(", in: content)
        let rootCall = try Regex(#"(?:^|[^A-Za-z0-9_.])([A-Z][A-Za-z0-9_]*View)\("#, as: (Substring, Substring).self)
        let roots = tabs.compactMap { tab in tab.firstMatch(of: rootCall).map { String($0.output.1) } }
        try #require(
            roots.count == AppRouter.Tab.allCases.count,
            "found \(roots.count) tab roots in ContentView (\(roots)), expected \(AppRouter.Tab.allCases.count)"
        )

        let files = try SourceScan.swiftFiles(under: "Trove/Views", minimum: 40)
        for root in roots {
            let path = try file(declaring: root, in: files)
            let code = try SourceScan.production(path)

            let overflows = SourceScan.closureBodies(after: "private var overflowControl: some View", in: code)
            try #require(overflows.count == 1, "\(root) declares \(overflows.count) `overflowControl`s, expected exactly 1")
            #expect(
                overflows[0].contains("OverflowMenu("),
                "\(root)'s \"…\" doesn't open the system menu through `OverflowMenu`: \(overflows[0])"
            )

            let name = try #require(orderingControls[root], "\(root) is a tab's root with no sort or order control named here")
            let controls = SourceScan.closureBodies(after: "private var \(name): some View", in: code)
            try #require(controls.count == 1, "\(root) declares \(controls.count) `\(name)`s, expected exactly 1")
            let control = controls[0]
            if name == "sortControl" {
                #expect(
                    control.contains("SortMenu("),
                    "\(root)'s Sort By doesn't open the system menu through `SortMenu` — a sort of its own is back (criterion 10): \(control)"
                )
            } else {
                #expect(
                    control.contains(menu),
                    "\(root)'s `\(name)` doesn't compose a system `Menu` — an order control of its own is back (criterion 10): \(control)"
                )
            }
        }

        for path in [
            "Trove/Views/Shared/SortMenu.swift",
            "Trove/Views/Shared/OverflowMenu.swift",
            "Trove/Views/Shared/DetailOverflowMenu.swift",
        ] {
            let code = try SourceScan.production(path)
            #expect(code.contains(menu), "\(path) no longer composes a system `Menu`")
        }

        let toggle = try SourceScan.production("Trove/Views/Shared/SideToggle.swift")
        #expect(toggle.contains("Button {"), "the side toggle is no longer a `Button` (spec Decision 19)")
        #expect(!toggle.contains(menu), "the side toggle composes a `Menu` — it is one tap that shows the other side (spec Decision 19)")
    }

    /// G12b. No screen uses `overlayPreferenceValue`, `anchorPreference` or
    /// `transformAnchorPreference` — the mechanism every floating in-page
    /// surface in this app used (the bespoke dropdown's host and its
    /// anchors). The mechanism, not the catchers' "Dismiss …" labels: a scan
    /// for a wording pins the spelling. No leg on picker styles:
    /// `.pickerStyle(.menu)` and unstyled pickers are system controls the
    /// rule allows (Decision 12).
    ///
    /// Mutation (T011): `DropdownHost.swift` restored from `main` with one
    /// host re-attached → red.
    @Test func noViewFloatsASurfaceOfItsOwn() throws {
        let mechanisms = ["overlayPreferenceValue", "anchorPreference", "transformAnchorPreference"]
        var offenders: [String] = []
        for file in try screenFiles() {
            let code = try SourceScan.production(file)
            for mechanism in mechanisms where code.contains(mechanism) {
                offenders.append("\(file): \(mechanism)")
            }
        }
        #expect(offenders.isEmpty, "a view floats a surface of its own (criteria 9 and 10): \(offenders)")
    }

    /// G12c (P8, Q5; since T009a four files — `SideToggle.swift` joined,
    /// Decision 19). Every `.glass`, `.glassProminent`, `.glassEffect(` and
    /// `GlassEffectContainer` in a screen sits in `SortMenu.swift`,
    /// `OverflowMenu.swift`, `SideToggle.swift` or `AddButton.swift`, and
    /// each of the four has exactly one.
    ///
    /// Mutation (T011): `.glassEffect()` on `PlansCard` → red.
    @Test func glassIsOnlyOnTheHeaderBadgesAndTheAddButton() throws {
        let glass = try Regex(#"(?:\.glass(?:Prominent|Effect)?|GlassEffectContainer)(?![A-Za-z0-9_])"#)
        let allowed: Set<String> = ["SortMenu.swift", "OverflowMenu.swift", "SideToggle.swift", "AddButton.swift"]
        var counts: [String: Int] = [:]
        var offenders: [String] = []
        for file in try screenFiles() {
            let name = (file as NSString).lastPathComponent
            let uses = try SourceScan.production(file).ranges(of: glass).count
            if allowed.contains(name) {
                counts[name] = uses
            } else if uses > 0 {
                offenders.append("\(file) (\(uses))")
            }
        }
        #expect(offenders.isEmpty, "glass outside the header's controls and the add button (P8): \(offenders)")
        for name in allowed.sorted() {
            #expect(counts[name] == 1, "\(name) carries \(counts[name].map(String.init) ?? "no file, so no") glass uses, expected exactly 1")
        }
    }

    /// G12d (criterion 8, R6). No UIKit appearance proxy anywhere in the app
    /// — `import SwiftUI` re-exports UIKit, so `ExportWiringTests`' import
    /// check can't see one, and `004`'s defect was one — and no
    /// `.confirmationDialog(` in a screen: alerts over dialogs is its own
    /// standing decision (`015`, `009`: from a bar button the dialog drops
    /// its cancel), which the old guard carried and this keeps.
    ///
    /// Mutations (T011): `UISegmentedControl.appearance().selectedSegmentTintColor
    /// = .brown` in `TroveApp.init` → red; a `.confirmationDialog` on a
    /// Delete → red.
    @Test func noUIKitAppearanceProxyAndNoConfirmationDialog() throws {
        let proxy = try Regex(#"UI[A-Za-z]+\s*\.\s*appearance\s*\("#)
        var proxies: [String] = []
        for file in try SourceScan.swiftFiles(under: "Trove", minimum: 100) {
            if try SourceScan.production(file).contains(proxy) { proxies.append(file) }
        }
        #expect(proxies.isEmpty, "a UIKit appearance proxy themes the app (criterion 8): \(proxies)")

        var dialogs: [String] = []
        for file in try screenFiles() {
            if try SourceScan.production(file).contains(".confirmationDialog(") { dialogs.append(file) }
        }
        #expect(dialogs.isEmpty, "a confirmation dialog where the app uses an alert (R6): \(dialogs)")
    }
}

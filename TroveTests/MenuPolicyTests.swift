import Foundation
import Testing
@testable import Trove

/// Spec 013 Amendment A, Decision 17 and criterion 27: **bespoke inside the
/// page, system in the bars.** Every menu drawn inside a page's content is
/// the app's own `DropdownSurface`; the one system `Menu` left is the
/// detail screens' nav-bar "…" (`DetailOverflowMenu`), which lives in the
/// bar beside the system back chevron.
///
/// A walk over every view file, on a word boundary: `Menu {` and `Menu(`
/// are system menus, `DetailOverflowMenu(` is not (the over-broad-pattern
/// failure CLAUDE.md names — the first draft of this guard would have been
/// red on the app's own component name). Swift's `Regex` has no
/// lookbehind, so the boundary is "start of text or a non-identifier
/// character" spelled out. `.pickerStyle(.menu)` and `.contextMenu` are
/// system menus too, and are covered so the rule can't be routed around.
@Suite("Menu policy")
struct MenuPolicyTests {
    private let allowlist: Set<String> = ["DetailOverflowMenu.swift"]

    @Test func theOnlySystemMenuIsTheDetailScreensNavBarOverflow() throws {
        let root = URL(filePath: "\(#filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        // Every screen: the views, and the app folder that composes them
        // (`ContentView` is a screen too).
        var files: [String] = []
        for folder in ["Trove/Views", "Trove/App"] {
            let url = root.appending(path: folder)
            files += try FileManager.default.subpathsOfDirectory(atPath: url.path)
                .filter { $0.hasSuffix(".swift") }
                .map { "\(folder)/\($0)" }
        }
        files.sort()
        try #require(files.count > 10, "scanned only \(files.count) view files — wrong root?")

        let systemMenu = try Regex(#"(?:^|[^A-Za-z0-9_])Menu\s*[({]"#)
        var offenders: [String] = []
        var allowedSeen = 0

        for file in files {
            let name = (file as NSString).lastPathComponent
            let code = try SourceScan.production(file)
            let hostsOne = code.contains(systemMenu)
                || code.contains(".pickerStyle(.menu)")
                || code.contains(".contextMenu")
            if allowlist.contains(name) {
                #expect(hostsOne, "\(file) is allowed a system menu and must still host one — else the allowlist is stale")
                allowedSeen += 1
            } else if hostsOne {
                offenders.append(file)
            }
        }

        #expect(offenders.isEmpty, "system menus inside page content: \(offenders)")
        #expect(allowedSeen == allowlist.count, "expected every allowlisted file to be scanned")
    }
}

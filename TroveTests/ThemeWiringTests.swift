import Testing
@testable import Trove

/// Spec 004 T003's source scans — the `SettingsWiringTests` discipline: what a
/// view-model or resolver unit test can't see (that the root drops its
/// hardcoded palette/scheme and drives both from the choice, that the app
/// injects the store) is pinned against the production source with comments
/// stripped, so a comment mentioning a string can't satisfy a scan.
///
/// The live/no-relaunch behaviour (criteria 3, 4) rests on SwiftUI's
/// `@Observable` re-render and `@Environment(\.colorScheme)` — long-standing
/// platform capabilities attested by the person at the phase pause. These
/// scans are what make that attestation about *this* code and not the
/// framework: the resolver's mapping is already pinned in `AppearanceStore`
/// / `AppearanceChoice+Theme` tests, and here we pin that the root is wired to
/// it at all.
@Suite("Theme wiring")
struct ThemeWiringTests {
    private nonisolated static let troveApp = "Trove/App/TroveApp.swift"
    private nonisolated static let themedRoot = "Trove/Views/Shared/Theme/ThemedRoot.swift"

    /// G9a: `TroveApp` wraps `ContentView` in `ThemedRoot`, injects the store,
    /// and carries neither hardcoded modifier the root used to pin.
    /// Mutation: leave `.preferredColorScheme(.dark)` in `TroveApp` → the
    /// no-hardcoded-scheme expectation fires.
    @Test func theAppWrapsContentInThemedRootAndDropsTheHardcodedPins() throws {
        let code = try SourceScan.production(Self.troveApp)
        #expect(code.contains("ThemedRoot(appearanceStore:"), "TroveApp doesn't wrap its root in ThemedRoot(appearanceStore:)")
        #expect(code.contains("ContentView()"), "TroveApp no longer builds ContentView")
        #expect(code.contains(".environment(appearanceStore)"), "TroveApp doesn't inject the appearance store")
        #expect(
            !code.contains(".preferredColorScheme(.dark)"),
            "TroveApp still hardcodes .preferredColorScheme(.dark) — the scheme must come from the choice"
        )
        #expect(
            !code.contains(".environment(\\.theme, .dark)"),
            "TroveApp still hardcodes .environment(\\.theme, .dark) — the palette must come from the choice"
        )
    }

    /// G9b: `ThemedRoot` drives both modifiers from `appearanceStore.choice` —
    /// the resolver for the palette, the choice's `preferredColorScheme` for
    /// the scheme. Mutation: hardcode `.dark` / `.environment(\.theme, .dark)`
    /// in `ThemedRoot` → the corresponding expectation fires.
    @Test func themedRootDrivesBothModifiersFromTheChoice() throws {
        let code = try SourceScan.production(Self.themedRoot)
        #expect(
            code.contains(".environment(\\.theme, appearanceStore.choice.resolvedTheme(systemColorScheme:"),
            "ThemedRoot doesn't inject the resolved theme for the choice"
        )
        #expect(
            code.contains(".preferredColorScheme(appearanceStore.choice.preferredColorScheme"),
            "ThemedRoot doesn't drive the preferred colour scheme from the choice"
        )
        #expect(
            !code.contains(".environment(\\.theme, .dark)"),
            "ThemedRoot hardcodes .environment(\\.theme, .dark) — the palette must come from the choice"
        )
        #expect(
            !code.contains(".preferredColorScheme(.dark)"),
            "ThemedRoot hardcodes .preferredColorScheme(.dark) — the scheme must come from the choice"
        )
    }
}

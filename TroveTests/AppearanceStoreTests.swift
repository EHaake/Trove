import Foundation
import Testing
@testable import Trove

/// The store's default and its persistence (plan.md Q2, guards G2 and G13).
///
/// Over an isolated `UserDefaults(suiteName:)` cleared in the test — a
/// legitimate persistence/infrastructure check, not a view-model test, so the
/// "no disk I/O" rule doesn't reach it. The round-trip reads through a *second*
/// store for the reason `TestSupport`'s `makeInMemoryContainer` note gives: a
/// same-instance read would pass whether or not the value was written.
@Suite("Appearance store")
struct AppearanceStoreTests {
    /// The key the store persists under, transcribed by hand rather than read
    /// back from the source, so the forward-compat guard sets what the store
    /// actually reads.
    private static let key = "appearanceChoice"

    /// A fresh, isolated defaults suite, wiped before use so a previous run
    /// can't leak a value in.
    private func freshSuite() -> (name: String, defaults: UserDefaults) {
        let name = "AppearanceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (name, defaults)
    }

    /// Criterion 6: a fresh or upgrading install opens in Dark with nothing
    /// stored (G2: defaulting to `.system` turns this red).
    @Test func aFreshSuiteReadsDark() {
        let store = AppearanceStore(defaults: freshSuite().defaults)
        #expect(store.choice == .dark)
    }

    /// Criterion 5: the choice survives into a second store over the same
    /// suite (G2: dropping `persist()` from `didSet` turns this red).
    @Test func theChoicePersistsIntoASecondStore() {
        let suite = freshSuite()
        let first = AppearanceStore(defaults: suite.defaults)
        first.choice = .light

        let second = AppearanceStore(defaults: UserDefaults(suiteName: suite.name)!)
        #expect(second.choice == .light)
    }

    /// A forward-compat guard: a stored string this version doesn't recognise
    /// reads as Dark rather than trapping.
    @Test func anUnrecognisedStoredStringReadsDark() {
        let suite = freshSuite()
        suite.defaults.set("sepia", forKey: Self.key)
        let store = AppearanceStore(defaults: suite.defaults)
        #expect(store.choice == .dark)
    }

    /// G13 (added at sign-off): criterion 5's does-not-sync half as a checked
    /// claim. The store persists per-device and never mirrors the choice, so
    /// its source names no ubiquitous or CloudKit symbol (mutation: wire it to
    /// `NSUbiquitousKeyValueStore` → red).
    @Test func theStoreNamesNoUbiquitousOrCloudKitSymbol() throws {
        let code = try SourceScan.production("Trove/App/AppearanceStore.swift")
        for symbol in ["NSUbiquitousKeyValueStore", "CloudKit", "ubiquitous"] {
            #expect(
                !code.contains(symbol),
                "AppearanceStore must not reference \(symbol) — the choice is per-device (spec Decision 4)"
            )
        }
    }
}

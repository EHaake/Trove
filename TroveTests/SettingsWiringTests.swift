import Testing
@testable import Trove

/// 013's source scans — the shape `ExportWiringTests` and
/// `ImportWiringTests` established: what a unit test on a view model can't
/// see (that a view is wired to it, that the app forwards a value) is
/// pinned against the production source with comments stripped.
@Suite("Settings wiring")
struct SettingsWiringTests {
    /// T005: the store's recorded fallback reason reaches the environment.
    /// `TroveStoreTests` pins that the reason isn't thrown away; this pins
    /// that, for the first time since 001, something reads it.
    @Test func theAppForwardsTheStoresFallbackReason() throws {
        let code = try SourceScan.production("Trove/App/TroveApp.swift")
        #expect(
            code.contains(".environment(\\.storageFallbackReason, store.cloudKitFailure"),
            "TroveApp doesn't forward the fallback reason into the environment"
        )
    }
}

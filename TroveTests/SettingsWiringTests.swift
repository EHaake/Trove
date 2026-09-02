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

    /// T011: the delete commit rolls back on a failed save — the
    /// `confirmImport` template. An in-memory save can't be made to throw
    /// on demand, so the all-or-nothing half of criterion 13 is pinned
    /// structurally, as 012's was; the mechanism (`rollback` discards
    /// pending deletions) is SwiftData's own.
    @Test func confirmDeleteAllRollsBackOnSaveFailure() throws {
        let code = try SourceScan.production("Trove/ViewModels/SettingsViewModel.swift")
        let bodies = SourceScan.closureBodies(after: "func confirmDeleteAll", in: code)
        try #require(bodies.count == 1, "SettingsViewModel should define exactly one confirmDeleteAll")
        #expect(bodies[0].contains("modelContext.save()"), "confirmDeleteAll must save once")
        #expect(
            bodies[0].contains("modelContext.rollback()"),
            "confirmDeleteAll's failure path must roll back the context"
        )
    }
}

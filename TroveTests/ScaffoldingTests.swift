import Testing
@testable import Trove

/// Placeholder proving the unit-test target builds, links Swift Testing, and
/// can see the app module. Replaced by real model tests in T010.
@Suite("Scaffolding")
struct ScaffoldingTests {
    @Test func appModuleIsVisibleToTests() {
        #expect(String(describing: TroveApp.self) == "TroveApp")
    }
}

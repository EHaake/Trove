import XCTest

/// Placeholder proving the UI-test target builds and can drive the app.
/// The real add-item smoke test lands in T050.
final class TroveUITests: XCTestCase {
    @MainActor
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}

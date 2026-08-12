import XCTest

/// The one end-to-end test that drives the real app: launch, add a piece of
/// gear, see it in the list.
///
/// Everything else in this project is a unit test against a view model or a
/// rendered component, which between them can't catch a screen that never
/// appears — a broken tab, a sheet that won't present, a save button wired to
/// nothing. This is the test that would.
///
/// **Runs against an in-memory store**, via the `-uiTesting` launch argument
/// `TroveApp` reads. Without it the starting state is whatever the last run
/// left in the simulator, and a UI test with ambient state passes or fails for
/// reasons nobody in the test can see. It also means this starts on the real
/// first-run empty state, which is worth asserting on its own now that Phase 9
/// made it a designed screen rather than a placeholder.
///
/// `XCTest` rather than Swift Testing because `XCUIApplication` requires it —
/// the one exception CLAUDE.md carves out.
final class TroveUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    @MainActor
    func testAppLaunches() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    /// Launch → Items → add → the row is there.
    ///
    /// The name is unique per run so the final assertion can't be satisfied by
    /// something left over, even if the in-memory store ever stops being
    /// in-memory.
    @MainActor
    func testAddingAnItemThroughQuickAddPutsItInTheList() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let name = "Rolleiflex \(UUID().uuidString.prefix(6))"

        // A fresh install opens on the dashboard's empty state. Asserting it
        // here is what makes the rest of this test meaningful: it proves the
        // store really is empty, so the row found at the end was added by this
        // test rather than already sitting there.
        XCTAssertTrue(
            app.staticTexts["Nothing tracked yet"].waitForExistence(timeout: 5),
            "Expected the first-run dashboard. The store wasn't empty, so this test proves nothing."
        )

        app.buttons["Items"].tap()

        // The floating brass disc, not the empty state's "Add an item" button —
        // this is the quick-add entry point that exists on every visit to the
        // screen, so it's the one worth smoke-testing.
        let addButton = app.buttons["Add item"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The add-item sheet didn't present")
        nameField.tap()
        nameField.typeText(name)

        let categoryField = app.textFields["Category"]
        categoryField.tap()
        categoryField.typeText("Photography/Cameras")

        let priceField = app.textFields["Price paid"]
        priceField.tap()
        priceField.typeText("1850")

        app.buttons["Save item"].tap()

        // Back on the list, and the sheet is gone.
        XCTAssertTrue(
            app.buttons["Save item"].waitForNonExistence(timeout: 5),
            "The sheet stayed up — the save was probably rejected by validation"
        )

        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: 5),
            "Saved \"\(name)\" but no row for it appeared in the items list"
        )
    }

    /// The half of the category field that a unit test can't reach: it swaps a
    /// breadcrumb read-out in for the text field once a path is set, and until
    /// T044 that swap fired on the *first* keystroke and destroyed the focused
    /// field mid-word. Typing "Photography/Cameras" left "P".
    ///
    /// `CategoryPickerFieldTests` pins the rule that went wrong.  This pins
    /// that the rule is still wired to a field a real person can type into —
    /// the two failure modes are different, and only this one involves a
    /// keyboard.
    @MainActor
    func testTypingAWholeCategoryPathKeepsEveryCharacter() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Items"].tap()

        let addButton = app.buttons["Add item"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let categoryField = app.textFields["Category"]
        XCTAssertTrue(categoryField.waitForExistence(timeout: 5))
        categoryField.tap()
        categoryField.typeText("Photography/Cameras")

        XCTAssertEqual(
            categoryField.value as? String,
            "Photography/Cameras",
            "The category field dropped characters while being typed into"
        )
    }
}

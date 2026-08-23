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

    /// Every text field on both forms is named.
    ///
    /// Supplying a `prompt:` to a SwiftUI `TextField` moves the title into the
    /// placeholder slot and leaves the field with no accessibility label — so
    /// VoiceOver reads the example value as though it were the field's name.
    /// "Leica M6" is not what that field is called, and "If it has one" says
    /// nothing at all about serial numbers. The `value:`/`format:` initialiser
    /// does the same thing with its title.
    ///
    /// Nine of the app's twelve text fields had this. Three were fixed at T050
    /// only because the smoke test needed to find them, which is the reason
    /// this test exists: the defect is invisible on screen, and the next field
    /// anyone adds will have it too unless something checks.
    ///
    /// **Asserted against the live accessibility hierarchy, not the source.** A
    /// regex looking for `prompt:` near `.accessibilityLabel` would pass on
    /// code that pairs them in the wrong order or in different views, and fail
    /// on anything that gets its name a different way. This asks the same
    /// question VoiceOver does.
    @MainActor
    func testEveryFormFieldIsNamedForVoiceOver() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Items"].tap()
        app.buttons["Add item"].tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 5))
        // The optional fields live behind the disclosure, so they aren't in the
        // hierarchy until it's open — and they're the worst offenders.
        app.buttons["Show more details"].tap()
        assertEveryTextFieldIsNamed(in: app, screen: "the item form")

        app.buttons["Cancel"].tap()
        app.buttons["Wishlist"].tap()
        app.buttons["Add wanted item"].tap()
        XCTAssertTrue(app.textFields["What do you want"].waitForExistence(timeout: 5))
        assertEveryTextFieldIsNamed(in: app, screen: "the wishlist form")
    }

    @MainActor
    private func assertEveryTextFieldIsNamed(
        in app: XCUIApplication,
        screen: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let fields = app.textFields.allElementsBoundByIndex
        XCTAssertFalse(
            fields.isEmpty,
            "Found no text fields on \(screen) — this assertion would pass over nothing.",
            file: file,
            line: line
        )

        let unnamed = fields
            .filter { $0.label.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { "placeholder \"\($0.placeholderValue ?? "")\"" }

        XCTAssertTrue(
            unnamed.isEmpty,
            """
            \(unnamed.count) field(s) on \(screen) have no accessibility label, \
            so VoiceOver reads their placeholder as the field's name: \
            \(unnamed.joined(separator: ", "))
            """,
            file: file,
            line: line
        )
    }

    /// The save bar's caption reflects the store the app is actually running
    /// on, rather than the environment default.
    ///
    /// `SaveCaptionTests` pins what each mode says and `SaveCaptionWiringTests`
    /// pins that the views ask — and both stay green if `TroveApp` never
    /// injects the mode, because `EnvironmentValues` would just hand back its
    /// `.cloudKit` default and the syncing copy would look correct.
    ///
    /// This is the one test that can tell the difference: `-uiTesting` runs on
    /// the in-memory store, so the *right* answer here is the device-only
    /// wording. Seeing the iCloud line means the wiring is missing.
    @MainActor
    func testTheSaveCaptionReflectsTheStoreTheAppIsActuallyUsing() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Items"].tap()
        app.buttons["Add item"].tap()
        XCTAssertTrue(app.textFields["Name"].waitForExistence(timeout: 5))

        let deviceOnly = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] 'on this device'"))
            .firstMatch
        XCTAssertTrue(
            deviceOnly.waitForExistence(timeout: 5),
            "The save caption doesn't match the in-memory store this run uses"
        )

        let mentionsICloud = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] 'iCloud'"))
            .firstMatch
        XCTAssertFalse(
            mentionsICloud.exists,
            "A UI-test run promised iCloud sync — TroveApp isn't injecting the storage mode"
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

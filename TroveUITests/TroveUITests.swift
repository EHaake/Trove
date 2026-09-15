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
    /// 012 criterion 1's behavioral half, as 013 criterion 2 restated it: a
    /// fresh install — empty collection, in-memory store — reaches Import
    /// and Settings through the "…" badge, with the export actions
    /// disabled and the template gone from the menu (it lives in Settings
    /// now). This is the guard the structural brace-span scan
    /// (`ImportWiringTests`) can't provide: proof a person can actually
    /// get there. Re-nesting the overflow control inside the
    /// `totalCount > 0` gate must turn this red.
    @MainActor
    func testEmptyCollectionOffersImportAndSettingsButNotExport() {
        let app = launchApp()
        app.buttons["Items"].tap()

        // By identifier: the Dashboard has a "More actions" badge too since
        // 013 Amendment A, and a label query could match the wrong tab.
        let badge = app.buttons["moreActions.items"]
        XCTAssertTrue(
            badge.waitForExistence(timeout: 5),
            "the overflow badge must exist on an empty collection"
        )
        badge.tap()

        let importButton = app.buttons["Import from CSV…"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5), "the menu should open")
        XCTAssertTrue(importButton.isEnabled, "Import must be enabled on an empty collection")
        XCTAssertTrue(app.buttons["Settings"].isEnabled, "Settings must be enabled on an empty collection")
        XCTAssertFalse(app.buttons["Get Blank Template…"].exists, "the template left the menu for Settings")
        // `isEnabled` on a missing element is false, so existence comes
        // first or a deleted menu item would pass as "disabled".
        for title in ["Export as CSV…", "Export as PDF…"] {
            XCTAssertTrue(app.buttons[title].exists, "\(title) should still be in the menu")
            XCTAssertFalse(app.buttons[title].isEnabled, "\(title) should disable when empty")
        }
    }

    /// 013 Amendment A, criterion 20 on a fresh install: the root Dashboard's
    /// "…" — present on the empty state — opens a one-row menu holding
    /// Settings and nothing else, Settings presents as the same sheet, and
    /// Done returns to the Dashboard. Its own mutation: gating the badge on
    /// a non-empty collection must turn this red, since the store is empty.
    @MainActor
    func testDashboardOffersSettingsAndNothingElse() {
        let app = launchApp()
        XCTAssertTrue(
            app.staticTexts["Nothing tracked yet"].waitForExistence(timeout: 5),
            "Expected the first-run dashboard."
        )

        let badge = app.buttons["moreActions.dashboard"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "the Dashboard's badge must exist on the empty state")
        badge.tap()

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "the menu should open")
        XCTAssertTrue(settings.isEnabled, "Settings must be enabled")
        XCTAssertFalse(app.buttons["Import from CSV…"].exists, "the Dashboard's menu holds Settings alone")
        XCTAssertFalse(app.buttons["Export as CSV…"].exists, "the Dashboard's menu holds Settings alone")
        settings.tap()

        let sheet = app.navigationBars["Settings"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Settings should present as a sheet from the Dashboard")
        app.buttons["Done"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "Done should dismiss Settings")
        XCTAssertTrue(badge.isHittable, "Done should return to the Dashboard")
    }

    /// 013 Amendment A, criterion 24 as Decision 19 fixed it: while a
    /// dropdown is open, a tap anywhere outside it — the other badge
    /// included — only closes it; the next tap opens. One item is added
    /// through the quick-add path so the sort badge exists at all. Its own
    /// mutation: a tap-outside layer that no longer closes must turn the
    /// first pair red.
    @MainActor
    func testAnOpenMenuClosesOnAnyOutsideTapIncludingTheOtherBadge() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Nothing tracked yet"].waitForExistence(timeout: 5), "Expected the first-run dashboard.")
        app.buttons["Items"].tap()

        let addButton = app.buttons["Add item"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The add-item sheet didn't present")
        nameField.tap()
        nameField.typeText("Rolleiflex")
        let categoryField = app.textFields["Category"]
        categoryField.tap()
        categoryField.typeText("Photography/Cameras")
        let priceField = app.textFields["Price paid"]
        priceField.tap()
        priceField.typeText("1850")
        app.buttons["Save item"].tap()
        XCTAssertTrue(app.buttons["Save item"].waitForNonExistence(timeout: 5), "The sheet stayed up")

        let sortBadge = app.buttons["sortOptions.items"]
        XCTAssertTrue(sortBadge.waitForExistence(timeout: 5), "one item is enough for the sort badge to show")
        let overflowBadge = app.buttons["moreActions.items"]
        XCTAssertTrue(overflowBadge.waitForExistence(timeout: 5))
        // Captured before anything opens: while a dropdown is open the badge
        // sits under the tap-outside layer, and a coordinate tap is how a
        // person's finger lands there regardless.
        let overflowCentre = overflowBadge.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        sortBadge.tap()
        let sortHeader = app.staticTexts["SORT BY"]
        XCTAssertTrue(sortHeader.waitForExistence(timeout: 5), "Sort By should open")

        // The other badge, while Sort By is open: closes, opens nothing.
        overflowCentre.tap()
        XCTAssertTrue(sortHeader.waitForNonExistence(timeout: 5), "the tap on the other badge must close Sort By")
        XCTAssertFalse(app.buttons["Import from CSV…"].exists, "…and must not open the overflow in the same tap (Decision 19)")

        // The next tap opens.
        overflowCentre.tap()
        XCTAssertTrue(app.buttons["Import from CSV…"].waitForExistence(timeout: 5), "the second tap opens the overflow")
        app.buttons["Dismiss more actions"].tap()
        XCTAssertTrue(app.buttons["Import from CSV…"].waitForNonExistence(timeout: 5), "the labelled catcher closes it")
    }

    /// 013's behavioral half for criteria 3, 7, 8 and 11 on a fresh
    /// install: Settings presents as a sheet from the menu; with nothing in
    /// the store the two templates are enabled and export-everything and
    /// both Delete All rows are not; the iCloud row tells the truth about
    /// the in-memory store; Done returns to the list. Its own mutation:
    /// dropping the `canExportEverything` gate on the export rows must
    /// turn this red — re-nesting the badge would fail it for an unrelated
    /// reason.
    @MainActor
    func testSettingsFromAnEmptyCollectionOffersTemplatesAndNothingElse() {
        let app = launchApp()
        app.buttons["Items"].tap()

        let badge = app.buttons["moreActions.items"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "the overflow badge must exist")
        badge.tap()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "the menu should open")
        settings.tap()

        let sheet = app.navigationBars["Settings"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Settings should present as a sheet")
        XCTAssertTrue(app.buttons["Items Template…"].isEnabled, "the items template must be enabled on an empty collection")
        XCTAssertTrue(app.buttons["Wishlist Template…"].isEnabled, "the wishlist template must be enabled on an empty collection")
        // Existence before `isEnabled`, which is false for a missing row.
        for title in ["Export All as CSV…", "Export All as PDF…", "Delete All Items…", "Delete All Wishlist Items…"] {
            XCTAssertTrue(app.buttons[title].exists, "\(title) should be on the screen")
            XCTAssertFalse(app.buttons[title].isEnabled, "\(title) should disable with nothing to act on")
        }
        let localOnly = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "On this device only"))
        XCTAssertTrue(localOnly.firstMatch.exists, "the in-memory store is local-only and the row must say so")

        app.buttons["Done"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "Done should dismiss Settings")
        XCTAssertTrue(badge.isHittable, "Done should return to the list")
    }

    // MARK: - 004 Appearance

    /// 004 criteria 2 and 6, the UI halves: Settings carries an Appearance
    /// segmented control with three segments — System / Light / Dark — and it
    /// opens on Dark, the default a fresh or upgrading install gets without
    /// choosing. Tapping Light leaves Light selected, proving the control is
    /// wired and settable.
    ///
    /// It launches with `-uiTesting` alone, which under T003's isolation gate
    /// starts every run from Dark — so the "Dark selected" assertion is the
    /// mutation guard (G12): defaulting `AppearanceStore` to `.system` or
    /// `.light` turns it red. Selection state, not rendered pixels: the light
    /// palette's visual correctness is the person's device pass and the
    /// perceptual suites, never a fragile screenshot.
    @MainActor
    func testAppearanceControlDefaultsToDarkAndOffersThreeChoices() {
        let app = launchApp()
        app.buttons["Items"].tap()

        let badge = app.buttons["moreActions.items"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "the overflow badge must exist")
        badge.tap()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "the menu should open")
        settings.tap()
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 5),
            "Settings should present as a sheet"
        )

        // A segmented Picker surfaces as a segmentedControl whose segments are
        // buttons read by their displayName; selection is `.isSelected`.
        let control = app.segmentedControls.firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 5), "the Appearance segmented control must be on the screen")

        let system = control.buttons["System"]
        let light = control.buttons["Light"]
        let dark = control.buttons["Dark"]
        for segment in [system, light, dark] {
            XCTAssertTrue(segment.exists, "the Appearance control must offer System / Light / Dark")
        }

        XCTAssertTrue(dark.isSelected, "a fresh install opens on Dark")
        XCTAssertFalse(light.isSelected, "Dark, not Light, is the default")
        XCTAssertFalse(system.isSelected, "Dark, not System, is the default")

        light.tap()
        XCTAssertTrue(light.isSelected, "tapping Light must leave Light selected — the control is wired and settable")
        XCTAssertFalse(dark.isSelected, "picking Light must deselect Dark")
    }

    // MARK: - 002 Market (offline states only)

    /// 002 criterion 1's behavioral half: an item with nothing matched to it
    /// offers Find on Reverb… and *no* other market action — no Refresh, no
    /// adopt, no link out, neither match action — on the item screen, and on
    /// the wishlist screen the pre-002 placeholder block ("Not tracked yet")
    /// is gone from where it used to sit.
    ///
    /// `MarketSectionRenderTests` pins what each state draws from a state
    /// value handed straight to the view; this pins that a real item, added
    /// through the real form, actually arrives in the unmatched state on
    /// both screens. Its mutation: rendering the section's action rows
    /// unconditionally must turn this red.
    @MainActor
    func testAnUnmatchedItemOffersFindOnReverbAndNothingElse() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let name = "Rolleiflex \(UUID().uuidString.prefix(6))"
        addItem(to: app, named: name)
        openDetail(in: app, named: name)

        XCTAssertTrue(
            app.buttons["market.find"].waitForExistence(timeout: 5),
            "an unmatched item must offer Find on Reverb…"
        )
        assertNoMarketActionsBeyondFind(in: app, screen: "an unmatched item")

        let wanted = "Summicron \(UUID().uuidString.prefix(6))"
        addWantedItem(to: app, named: wanted)
        openDetail(in: app, named: wanted)

        XCTAssertTrue(
            app.buttons["market.find"].waitForExistence(timeout: 5),
            "an unmatched wanted item must offer Find on Reverb… too"
        )
        assertNoMarketActionsBeyondFind(in: app, screen: "an unmatched wanted item")
        let ghost = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] 'Not tracked yet'"))
            .firstMatch
        XCTAssertFalse(ghost.exists, "010's reserved placeholder is still on the wishlist screen")
    }

    /// 002 criterion 2's Not-now half, and Decision 14's ordering: the first
    /// Find on Reverb… on this device puts the notice in front of the picker
    /// — the picker's search field is not on screen yet — and Not now closes
    /// the sheet without acknowledging anything, so the very next Find on
    /// Reverb… shows the notice again (Q5).
    ///
    /// **Continue is never tapped here, and that is deliberate** (plan Q13):
    /// tapping it would acknowledge the notice and hand the sheet to the
    /// picker, which searches Reverb on appear. Nothing in this target may
    /// reach the network, so the flag's persistence is the unit suites' claim
    /// and the device pass's, not this test's — this covers the half that
    /// needs no network and no writes.
    ///
    /// Its mutation: acknowledging on Not now (calling `acknowledgeNotice`
    /// from `declineNotice`) must turn this red at the second showing.
    @MainActor
    func testTheFirstFindOnReverbShowsTheNoticeAndNotNowClosesIt() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let name = "Rolleiflex \(UUID().uuidString.prefix(6))"
        addItem(to: app, named: name)
        openDetail(in: app, named: name)

        let find = app.buttons["market.find"]
        XCTAssertTrue(find.waitForExistence(timeout: 5))
        scrollUntilHittable(find, in: app)
        find.tap()

        let notNow = app.buttons["market.notice.notNow"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 5), "the first find must present the notice")
        XCTAssertTrue(app.buttons["market.notice.continue"].exists, "the notice must offer Continue")
        XCTAssertFalse(
            element(in: app, identifiedBy: "market.search").exists,
            "the picker stands behind the notice, not beside it — its search field must not be on screen"
        )

        notNow.tap()
        XCTAssertTrue(notNow.waitForNonExistence(timeout: 5), "Not now must close the sheet")

        // The whole point of Q5: Not now acknowledges nothing, so the notice
        // is back the next time. If this find opened the picker instead, the
        // app would be searching Reverb — which is why the assertion is on
        // the notice returning rather than on the picker staying away.
        scrollUntilHittable(find, in: app)
        find.tap()
        XCTAssertTrue(
            notNow.waitForExistence(timeout: 5),
            "Not now acknowledged the notice — the second find should have shown it again"
        )
        // Left closed, so the run ends with no sheet up.
        notNow.tap()
        XCTAssertTrue(notNow.waitForNonExistence(timeout: 5))
    }

    /// 002 criterion 14's reachable half: both list screens offer the two
    /// market sort rows in the Sort By dropdown. The view-model suites pin
    /// what each order sorts by; this pins that a person can pick them.
    ///
    /// Its mutation: removing the `.marketFigure` case from either list's
    /// `SortOrder` must turn this red.
    @MainActor
    func testTheSortMenuOffersMarketRows() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        addItem(to: app, named: "Rolleiflex \(UUID().uuidString.prefix(6))")
        assertMarketSortRows(in: app, badge: "sortOptions.items", screen: "the items list")

        addWantedItem(to: app, named: "Summicron \(UUID().uuidString.prefix(6))")
        assertMarketSortRows(in: app, badge: "sortOptions.wishlist", screen: "the wishlist")
    }

    /// 002 criterion 17's About half and the Settings row, on a fresh
    /// install: Refresh market values is on the screen and disabled, because
    /// an empty store has nothing matched to refresh; Reverb's attribution is
    /// there verbatim; and the two destinations the terms and the notice
    /// promise — the contact address and the privacy policy — are both real
    /// links.
    ///
    /// Its mutation: dropping the `canRefreshMarketValues` gate, so the row
    /// is always enabled, must turn this red.
    @MainActor
    func testSettingsCarriesTheMarketRowAndAttribution() {
        let app = launchApp()
        app.buttons["Items"].tap()

        let badge = app.buttons["moreActions.items"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "the overflow badge must exist")
        badge.tap()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "the menu should open")
        settings.tap()
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 5),
            "Settings should present as a sheet"
        )

        // Existence before `isEnabled`, which is false for a missing row.
        let refresh = app.buttons["settings.refreshMarket"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 5), "the market row must be on the screen")
        XCTAssertFalse(refresh.isEnabled, "nothing is matched on an empty store, so the row must be disabled")

        let attribution = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] 'not endorsed'"))
            .firstMatch
        scrollUntilFound(attribution, in: app)
        XCTAssertTrue(attribution.exists, "Reverb's attribution must be in About")

        let contact = element(in: app, identifiedBy: "about.contact")
        XCTAssertTrue(contact.exists, "About must carry the contact address")
        let privacy = element(in: app, identifiedBy: "about.privacy")
        XCTAssertTrue(privacy.exists, "About must link to the privacy policy")
    }

    // MARK: - 003 Sell Plan (the seeded collection)

    /// 003 criteria 10 and 12, on a collection no real device can have yet:
    /// the Sell Plan ranks the rising candidate above the flat and neutral
    /// ones and the falling one last, and each row says why in the label
    /// VoiceOver actually reads.
    ///
    /// **The only test in this target that launches with `-seedSellPlan`.**
    /// Every other test keeps `launchApp()` and its empty collection — which
    /// is what makes `testEmptyCollectionOffersImportAndSettingsButNotExport`
    /// the mutation for "`-uiTesting` alone seeds nothing".
    ///
    /// The rows are `.combine`d, so this reads each row button's combined
    /// label rather than children whose identifiers may not survive the
    /// combine — and reading the whole label is what turns criterion 10's
    /// "read by VoiceOver in full" into an automated check. Whether
    /// `sellPlan.market` and `sellPlan.reason` stay reachable inside a
    /// combined row is instrumented at the end and recorded; nothing above
    /// depends on the answer.
    ///
    /// Its mutation: dropping the group key from `SellPlanViewModel.rank`, so
    /// value alone decides, must turn the order assertion red — the seed's
    /// own values read Blues Junior, Telecaster, NT1-A, Squier that way.
    @MainActor
    func testTheSeededSellPlanRanksRisingFirstAndSaysWhy() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSellPlan"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Wishlist"].tap()
        openDetail(in: app, named: "Summicron 35mm f/2")

        // The entry point carries no accessibility identifier and isn't being
        // given one for a test's sake, so it's matched on the first thing it
        // says — the subtitle follows in the same combined label.
        let findItemsToSell = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Find items to sell"))
            .firstMatch
        XCTAssertTrue(
            findItemsToSell.waitForExistence(timeout: 5),
            "the wishlist detail must offer a way into the Sell Plan"
        )
        scrollUntilHittable(findItemsToSell, in: app)
        findItemsToSell.tap()

        // Declared in the order the ranking should put them: rising, flat,
        // neutral, falling.
        let expected = ["Telecaster", "Blues Junior", "Squier Classic Vibe", "NT1-A"]
        let rows = expected.map { name in
            (
                name: name,
                element: app.buttons
                    .matching(NSPredicate(format: "label CONTAINS %@", name))
                    .firstMatch
            )
        }
        for row in rows {
            XCTAssertTrue(
                row.element.waitForExistence(timeout: 5),
                "the seeded Sell Plan has no candidate row for \(row.name)"
            )
        }

        // Ranking, read off the screen rather than off the view model: each
        // row sits below the one before it.
        for (earlier, later) in zip(rows, rows.dropFirst()) {
            XCTAssertLessThan(
                earlier.element.frame.minY,
                later.element.frame.minY,
                "\(earlier.name) should be ranked above \(later.name)"
            )
        }

        // Criterion 10: the reason line is on the rising row and nowhere else.
        // The copy is repeated here because a UI-test target can't import the
        // app; `MarketCopyTests` pins the source of the sentence. Matched
        // short of the "%" so the narrow no-break space between figure and
        // sign doesn't have to be spelled twice.
        let saysWhy = rows.filter { $0.element.label.contains("Asking prices on Reverb are up 12") }
        XCTAssertEqual(
            saysWhy.map(\.name),
            ["Telecaster"],
            "only the rising row explains itself, and it must be the rising one"
        )

        // And the market line is on the three matched rows — the unmatched
        // Squier has no figure to show, so it says nothing.
        let saysMarket = rows.filter { $0.element.label.contains("Median asking price") }
        XCTAssertEqual(
            saysMarket.map(\.name),
            ["Telecaster", "Blues Junior", "NT1-A"],
            "every matched candidate carries the market line, and the unmatched one doesn't"
        )

        // The arrow's half of the same sentence — the reason the figure's
        // label sits on the `Text` and not on the stack around it: combined,
        // the rising row reads "Median asking price $1,400, trending up".
        // The flat Blues Junior draws no arrow and so says neither.
        let trendingUp = rows.filter { $0.element.label.contains("trending up") }
        XCTAssertEqual(trendingUp.map(\.name), ["Telecaster"], "the rising row's label should carry the arrow's spoken half, and only that row's")
        let trendingDown = rows.filter { $0.element.label.contains("trending down") }
        XCTAssertEqual(trendingDown.map(\.name), ["NT1-A"], "the falling row's label should carry the arrow's spoken half, and only that row's")

        // Instrumented once at T005 and recorded in tasks.md, then removed:
        // inside the `.combine`d row, `sellPlan.reason` resolved to exactly
        // one element and `sellPlan.market` to *two per matched row* (six),
        // so both stay addressable but the market identifier is no count of
        // market lines. Nothing above depends on either.
    }

    // MARK: - 005 Stock photos (offline states only)

    /// 005 criterion 1's behavioral half: an item with no photo offers
    /// Find a photo… on the item screen, and a blank wanted item offers it
    /// too. Both are added through the real form and arrive with no photo,
    /// so the action is the one this run can reach without a photo library.
    ///
    /// The complementary case — an item that *has* an owned photo hides the
    /// action — is not UI-testable here: the only way to give an item a
    /// `.device` photo is the system PhotosPicker (no library in the harness)
    /// or a seed, which Q10 declines. That invariant is unit-tested and
    /// mutation-verified in `PhotoSelection.canFindPhoto` (T005) and both
    /// view models' `canFindPhoto` (T009/T010), and is seen for real in the
    /// T015 device pass — the same "offline states only" scope 002's UI tests
    /// kept.
    ///
    /// Its mutation: hiding the action (gating `canFindPhoto` off) must turn
    /// this red at the `stockphoto.find` existence assertion.
    @MainActor
    func testAnItemWithNoPhotoOffersFindAPhoto() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let name = "Rolleiflex \(UUID().uuidString.prefix(6))"
        addItem(to: app, named: name)
        openDetail(in: app, named: name)

        let find = app.buttons["stockphoto.find"]
        XCTAssertTrue(
            find.waitForExistence(timeout: 5),
            "an item with no photo must offer Find a photo…"
        )

        let wanted = "Summicron \(UUID().uuidString.prefix(6))"
        addWantedItem(to: app, named: wanted)
        openDetail(in: app, named: wanted)

        XCTAssertTrue(
            app.buttons["stockphoto.find"].waitForExistence(timeout: 5),
            "a blank wanted item must offer Find a photo… too"
        )
    }

    /// 005's Not-now half: the first Find a photo… on this device puts the
    /// notice in front of the picker — the picker's search field is not on
    /// screen yet — and Not now closes the sheet without acknowledging
    /// anything, so the very next Find a photo… shows the notice again (Q10).
    ///
    /// **Continue is never tapped here, and that is deliberate** (Q10):
    /// tapping it would acknowledge the notice and hand the sheet to the
    /// picker, which searches Wikimedia on appear. Nothing in this target may
    /// reach the network, so the flag's persistence is the unit suites' claim
    /// and the device pass's, not this test's — this covers the half that
    /// needs no network and no writes.
    ///
    /// Its mutation: acknowledging on Not now (calling `noticeStore.acknowledge()`
    /// from `declinePhotoNotice`) must turn this red at the second showing.
    @MainActor
    func testTheFirstFindAPhotoShowsTheNoticeAndNotNowClosesIt() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let name = "Rolleiflex \(UUID().uuidString.prefix(6))"
        addItem(to: app, named: name)
        openDetail(in: app, named: name)

        let find = app.buttons["stockphoto.find"]
        XCTAssertTrue(find.waitForExistence(timeout: 5))
        scrollUntilHittable(find, in: app)
        find.tap()

        let notNow = app.buttons["stockphoto.notice.notNow"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 5), "the first find must present the notice")
        XCTAssertTrue(app.buttons["stockphoto.notice.continue"].exists, "the notice must offer Continue")
        XCTAssertFalse(
            element(in: app, identifiedBy: "stockphoto.search").exists,
            "the picker stands behind the notice, not beside it — its search field must not be on screen"
        )

        notNow.tap()
        XCTAssertTrue(notNow.waitForNonExistence(timeout: 5), "Not now must close the sheet")

        // The whole point of Q10: Not now acknowledges nothing, so the notice
        // is back the next time. If this find opened the picker instead, the
        // app would be searching Wikimedia — which is why the assertion is on
        // the notice returning rather than on the picker staying away.
        scrollUntilHittable(find, in: app)
        find.tap()
        XCTAssertTrue(
            notNow.waitForExistence(timeout: 5),
            "Not now acknowledged the notice — the second find should have shown it again"
        )
        // Left closed, so the run ends with no sheet up.
        notNow.tap()
        XCTAssertTrue(notNow.waitForNonExistence(timeout: 5))
    }

    // MARK: - Market helpers

    /// Any element with this identifier, whatever it is drawn as. The market
    /// targets are a mix of buttons, links and a search field, and querying
    /// `app.buttons[...]` for one of the others would report "doesn't exist"
    /// for a thing that plainly does — which is the wrong answer in both
    /// directions here, since half these assertions are negative.
    @MainActor
    private func element(in app: XCUIApplication, identifiedBy identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func assertNoMarketActionsBeyondFind(
        in app: XCUIApplication,
        screen: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for identifier in [
            "market.refresh", "market.adopt", "market.link",
            "market.changeMatch", "market.removeMatch",
        ] {
            XCTAssertFalse(
                element(in: app, identifiedBy: identifier).exists,
                "\(screen) draws \(identifier) — nothing is matched, so Find on Reverb… is the only action",
                file: file,
                line: line
            )
        }
    }

    @MainActor
    private func assertMarketSortRows(
        in app: XCUIApplication,
        badge identifier: String,
        screen: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let badge = app.buttons[identifier]
        XCTAssertTrue(
            badge.waitForExistence(timeout: 5),
            "one row is enough for \(screen)'s sort badge to show",
            file: file,
            line: line
        )
        badge.tap()
        XCTAssertTrue(
            app.staticTexts["SORT BY"].waitForExistence(timeout: 5),
            "\(screen)'s Sort By should open",
            file: file,
            line: line
        )
        // The dropdown row's title, as `MarketCopy.sortDescending` and
        // `sortAscending` spell it — a UI-test target can't import the app,
        // so the copy is repeated here and `MarketCopyTests` pins the source.
        for title in ["Market \u{2193}", "Market \u{2191}"] {
            XCTAssertTrue(
                app.buttons[title].exists,
                "\(screen)'s Sort By is missing \(title)",
                file: file,
                line: line
            )
        }
        app.buttons["Dismiss sort options"].tap()
        XCTAssertTrue(
            app.staticTexts["SORT BY"].waitForNonExistence(timeout: 5),
            "\(screen)'s Sort By should close",
            file: file,
            line: line
        )
    }

    /// Adds one item through the real form — the same steps
    /// `testAddingAnItemThroughQuickAddPutsItInTheList` walks, which is the
    /// only way to get a market section to look at.
    @MainActor
    private func addItem(to app: XCUIApplication, named name: String) {
        app.buttons["Items"].tap()

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
        XCTAssertTrue(
            app.buttons["Save item"].waitForNonExistence(timeout: 5),
            "The sheet stayed up — the save was probably rejected by validation"
        )
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "no row for \"\(name)\" appeared")
    }

    /// The wishlist's equivalent: name, category and estimated cost are all
    /// required, the same three the item form asks for under other names.
    @MainActor
    private func addWantedItem(to app: XCUIApplication, named name: String) {
        app.buttons["Wishlist"].tap()

        let addButton = app.buttons["Add wanted item"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["What do you want"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "The wishlist sheet didn't present")
        nameField.tap()
        nameField.typeText(name)

        let categoryField = app.textFields["Category"]
        categoryField.tap()
        categoryField.typeText("Photography/Lenses")

        let costField = app.textFields["Estimated cost"]
        costField.tap()
        costField.typeText("2400")

        app.buttons["Save to wishlist"].tap()
        XCTAssertTrue(
            app.buttons["Save to wishlist"].waitForNonExistence(timeout: 5),
            "The sheet stayed up — the save was probably rejected by validation"
        )
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "no row for \"\(name)\" appeared")
    }

    /// Both lists push their detail screen from a tap on the row itself, so
    /// the row's title is the target.
    @MainActor
    private func openDetail(in app: XCUIApplication, named name: String) {
        let row = app.staticTexts[name]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
    }

    /// The market section sits below the fold on both detail screens. Its
    /// elements are in the accessibility tree either way — the content is a
    /// plain `VStack` — so existence needs no scrolling and only a *tap*
    /// does.
    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 6) {
        for _ in 0..<attempts where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "couldn't scroll \(element) into reach")
    }

    /// The same for a query that may resolve to nothing until the screen has
    /// been scrolled — Settings' About block is the long way down.
    @MainActor
    private func scrollUntilFound(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 6) {
        for _ in 0..<attempts where !element.exists {
            app.swipeUp()
        }
    }

    // MARK: - 006 Mark as sold

    /// `006` criteria 6 and 7 on the seeded sold collection (`-seedSold`):
    /// the Dashboard's Sold card says what it says, it lands on the Items
    /// tab's Sold side, the sales are listed most recent first with each
    /// row's gain or loss in the label VoiceOver actually reads, the summary
    /// under the title matches the card, Sort By is gone from that side and
    /// the "…" is not, and the switch goes back to Owned in one tap.
    ///
    /// **The only test in this target that launches with `-seedSold`.** Like
    /// `-seedSellPlan`, the argument is its own: every other test here keeps
    /// `launchApp()` and its empty collection, which is what makes
    /// `testEmptyCollectionOffersImportAndSettingsButNotExport` the mutation
    /// for "`-uiTesting` alone seeds nothing".
    ///
    /// The rows are `.combine`d, so each is read as one label — which is what
    /// turns criterion 7's "unmistakable whether it sold at a gain or at a
    /// loss" into an automated check rather than a look at the colour.
    ///
    /// Its mutation: reversing `ItemListViewModel.areInSoldOrder`'s date
    /// comparison must turn the order assertion red — the seed's two sales
    /// are nine days apart.
    @MainActor
    func testTheSoldCardLandsOnTheSoldSideWhichListsSalesMostRecentFirst() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSold"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // The card, composed by `DashboardViewModel` out of `SaleCopy` — the
        // count and the proceeds, then the realised line. Read off the
        // combined label, which is the announcement as well as the plate.
        let card = app.buttons["dashboard.soldCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the seeded collection has two sales, so the Sold card must show")
        XCTAssertTrue(card.label.contains("2 items \u{00B7} $1,800"), "the Sold card reads \"\(card.label)\"")
        XCTAssertTrue(card.label.contains("+$200 vs paid"), "the Sold card reads \"\(card.label)\"")

        card.tap()

        // Criterion 6's last clause: the card is a way through to the Sold
        // side, not just a figure.
        let switchControl = element(in: app, identifiedBy: "items.sideSwitch")
        XCTAssertTrue(switchControl.waitForExistence(timeout: 5), "the card should land on the Items tab")
        XCTAssertEqual(switchControl.value as? String, "Sold", "the card should land on the Sold side, not on Owned")

        let telecaster = soldRow(in: app, named: "Telecaster")
        let bluesJunior = soldRow(in: app, named: "Blues Junior")
        XCTAssertTrue(telecaster.waitForExistence(timeout: 5), "no Sold-side row for the Telecaster")
        XCTAssertTrue(bluesJunior.exists, "no Sold-side row for the Blues Junior")

        // Most recent first, read off the screen: the Telecaster sold three
        // days ago, the Blues Junior twelve.
        XCTAssertLessThan(
            telecaster.frame.minY,
            bluesJunior.frame.minY,
            "the Sold side must list the most recent sale first"
        )

        // Criterion 7's "unmistakable ... and by how much", in words, in the
        // label. The copy is repeated here because a UI-test target can't
        // import the app; `SaleCopyTests` pins the source of the sentence.
        XCTAssertTrue(telecaster.label.contains("Gain $350"), "the Telecaster's row reads \"\(telecaster.label)\"")
        XCTAssertTrue(bluesJunior.label.contains("Loss $150"), "the Blues Junior's row reads \"\(bluesJunior.label)\"")

        // The summary under the title, which is the card's own sum — matched
        // case-insensitively because `monoLabel` raises this line on screen.
        let summary = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "2 sold \u{00B7} $1,800 \u{00B7} +$200 vs paid"))
            .firstMatch
        XCTAssertTrue(summary.exists, "the Sold side's summary must match the card")

        // Criterion 7: Sort By is hidden on this side and the "…" is not.
        XCTAssertFalse(app.buttons["sortOptions.items"].exists, "Sort By must not show on the Sold side")
        XCTAssertTrue(app.buttons["moreActions.items"].exists, "the overflow badge stays on the Sold side (criterion 7a)")

        // One tap back to Owned, which is a different list and gets its
        // narrowing controls back.
        switchControl.buttons["Owned"].tap()
        XCTAssertTrue(
            app.staticTexts["Leica M6"].waitForExistence(timeout: 5),
            "the Owned side should list the item that wasn't sold"
        )
        XCTAssertFalse(soldRow(in: app, named: "Telecaster").exists, "a sold item must not appear on the Owned side")
        XCTAssertTrue(app.buttons["sortOptions.items"].waitForExistence(timeout: 5), "Sort By returns on the Owned side")
    }

    /// Criteria 1, 2, 3, 8 and 9 end to end on an item this test adds itself
    /// (`-uiTesting`, so the collection starts empty): the menu's **Mark as
    /// sold…**, the sheet with the price blank because the item has no
    /// current value, the sold page's mark and its three actions, the item
    /// gone from the Owned side and present on the Sold one, and **Return to
    /// collection…** putting it back.
    ///
    /// The Owned side it leaves behind says "Everything's sold." rather than
    /// the first-launch "No gear yet" — spec Decision 12 and `T015a`, which
    /// shipped after `plan.md` §8 was written.
    ///
    /// Its mutation: `ItemSaleStore.returnToCollection` keeping `soldDate`
    /// (setting the four fields back by hand instead of `sale = nil`) must
    /// turn the last half red.
    @MainActor
    func testMarkingAnItemSoldMovesItToTheSoldSideAndReturnRestoresIt() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        let name = "Rolleiflex \(UUID().uuidString.prefix(6))"
        addItem(to: app, named: name)
        openDetail(in: app, named: name)

        let menu = app.buttons["More actions for this item"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "the item page must offer its overflow menu")
        menu.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5), "an owned item's menu still offers Edit")
        let markAsSold = app.buttons["Mark as sold\u{2026}"]
        XCTAssertTrue(markAsSold.exists, "criterion 1: an owned item's menu offers Mark as sold…")
        markAsSold.tap()

        // Criterion 2: pre-filled with the current value *when the item has
        // one*. This one was added through the form with a price paid and no
        // value, so the field is empty and the sale price is typed.
        let price = app.textFields["sale.sheet.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5), "the sale sheet didn't present")
        // An empty `TextField` reports its *placeholder* as its value, and
        // this field's placeholder is "0" — so a blank price reads as "0"
        // here. What must not appear is a figure: the item's paid price is
        // 1,850, and a sheet seeded from the wrong source would show it
        // (G19, unit-tested; this is the same claim on screen).
        XCTAssertEqual(price.value as? String, "0", "an item with no current value must open the sheet with the price blank")
        price.tap()
        price.typeText("500")
        app.buttons["sale.sheet.confirm"].tap()

        // Criterion 8: the page says sold, and offers exactly the three
        // actions a sold item has.
        XCTAssertTrue(
            element(in: app, identifiedBy: "sold.mark").waitForExistence(timeout: 5),
            "the sold item's page must carry the Sold mark"
        )
        app.buttons["Back"].tap()

        // Criterion 4: gone from the Owned side, which this person has just
        // emptied by selling — Decision 12's state, not the first-launch one.
        XCTAssertTrue(
            app.staticTexts["Everything's sold."].waitForExistence(timeout: 5),
            "the Owned side should be empty, and say so in Decision 12's words"
        )

        let switchControl = element(in: app, identifiedBy: "items.sideSwitch")
        switchControl.buttons["Sold"].tap()
        let row = soldRow(in: app, named: name)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the sold item must be on the Sold side")
        XCTAssertTrue(row.label.contains("$500"), "the row reads \"\(row.label)\"")

        app.staticTexts[name].tap()

        // Criterion 8: the sold page's menu offers exactly these three, and
        // not the owned page's Edit — checked from the open menu that
        // criterion 9's Return is then taken from, so nothing has to dismiss
        // a system menu without choosing anything.
        menu.tap()
        XCTAssertTrue(app.buttons["Edit sale\u{2026}"].waitForExistence(timeout: 5), "criterion 8: a sold item offers Edit sale…")
        XCTAssertTrue(app.buttons["Delete"].exists, "criterion 8: a sold item still offers Delete")
        XCTAssertFalse(app.buttons["Edit"].exists, "a sold item's content is read-only — Edit belongs to the owned page")

        // Criterion 9: Return asks first, then restores it.
        let returnRow = app.buttons["Return to collection\u{2026}"]
        XCTAssertTrue(returnRow.exists, "criterion 8: a sold item offers Return to collection…")
        returnRow.tap()
        let confirm = app.buttons["Return"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Return to collection… must ask first")
        confirm.tap()

        XCTAssertTrue(
            element(in: app, identifiedBy: "sold.mark").waitForNonExistence(timeout: 5),
            "the Sold mark should go with the sale"
        )
        app.buttons["Back"].tap()

        XCTAssertTrue(
            app.staticTexts["Nothing sold yet."].waitForExistence(timeout: 5),
            "the last sale was returned, so the Sold side is empty again"
        )
        switchControl.buttons["Owned"].tap()
        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: 5),
            "the returned item should be back in the collection"
        )
    }

    /// Criterion 10 on the seeded Sell Plan (`-seedSellPlan`): a row's **Mark
    /// as sold…**, the price already filled in with that item's current
    /// value, and afterwards a **Sold** figure in the header with the count
    /// beneath it, the item gone from the candidates, and the sale listed in
    /// the Sold section below them.
    ///
    /// The figure is read by `sellPlan.soldFigure`, the identifier `plan.md`
    /// §3 and §8 name, which `T017a` shipped: the cell is one `.combine`d
    /// element now, so its label carries the header, the money and the count
    /// in one string — "Sold", "$640" and "1 item" are no longer three loose
    /// static texts to hunt above the candidates header, and no position is
    /// needed to tell them from the Sold *section*'s identical words below.
    ///
    /// Its mutation: `SellPlanViewModel.markSold` passing `toward: nil` must
    /// turn this red — a sale that points at no plan leaves `hasSales` false,
    /// and the header goes back to two figures with no Sold section under
    /// them.
    @MainActor
    func testASellPlanRowSoldFromThePlanShowsTheSoldFigure() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSellPlan"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Wishlist"].tap()
        openDetail(in: app, named: "Summicron 35mm f/2")
        let findItemsToSell = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Find items to sell"))
            .firstMatch
        XCTAssertTrue(findItemsToSell.waitForExistence(timeout: 5), "the wishlist detail must offer a way into the Sell Plan")
        scrollUntilHittable(findItemsToSell, in: app)
        findItemsToSell.tap()

        // The strip belongs to the card above it: each row draws its own, so
        // the one to tap is the first that starts below the Blues Junior's
        // card.
        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Blues Junior"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the seeded plan must offer the Blues Junior as a candidate")
        let strip = app.buttons
            .matching(identifier: "sellPlan.row.markAsSold")
            .allElementsBoundByIndex
            .filter { $0.frame.minY > card.frame.minY }
            .min { $0.frame.minY < $1.frame.minY }
        guard let markAsSold = strip else {
            return XCTFail("the Blues Junior's row must offer Mark as sold…")
        }
        scrollUntilHittable(markAsSold, in: app)
        markAsSold.tap()

        // Criterion 2's pre-fill, from the plan: the Blues Junior is valued
        // at $640, so the sheet opens on it and this test confirms it
        // unchanged.
        let price = app.textFields["sale.sheet.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5), "the sale sheet didn't present")
        XCTAssertEqual(price.value as? String, "640", "the sheet must pre-fill with the item's current value")
        app.buttons["sale.sheet.confirm"].tap()

        // Everything above the candidates header is the figures card.
        // Matched case-insensitively, as every `monoLabel` line here is: the
        // accessibility label comes back raised on some snapshots and in the
        // source's own case on others, and which one is nothing this test is
        // about.
        let candidatesHeader = app.staticTexts
            .matching(NSPredicate(format: "label ==[c] %@", "Sell candidates"))
            .firstMatch
        XCTAssertTrue(candidatesHeader.waitForExistence(timeout: 5))
        let headerBand = candidatesHeader.frame.minY
        let soldFigure = element(in: app, identifiedBy: "sellPlan.soldFigure")
        XCTAssertTrue(
            soldFigure.waitForExistence(timeout: 5),
            "the plan's header should carry a Sold figure once something has been sold toward it"
        )
        // One element, one label: the header, the money and the count in the
        // order the cell stacks them. Matched case-insensitively, as every
        // `monoLabel` line here is.
        let announced = soldFigure.label.lowercased()
        for text in ["sold", "$640", "1 item"] {
            XCTAssertTrue(
                announced.contains(text),
                "the Sold figure should read $640 for 1 item — its label is \"\(soldFigure.label)\""
            )
        }

        // Nothing is subtracted from the cost: it still reads the estimate.
        XCTAssertTrue(
            staticText(in: app, labelled: "$2,400", above: headerBand),
            "the estimated cost must be untouched by the sale"
        )

        // Criterion 4: a sold item is no candidate. The card is a button; the
        // Sold section's row below is not, so this can't match it.
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Blues Junior")).firstMatch.exists,
            "a sold item must leave the candidate list"
        )

        // And the Sold section under the candidates lists the sale.
        let soldEntry = soldRow(in: app, named: "Blues Junior")
        XCTAssertTrue(soldEntry.waitForExistence(timeout: 5), "the plan's Sold section should list the sale")
        XCTAssertGreaterThan(soldEntry.frame.minY, headerBand, "the Sold section sits under the candidates")
        XCTAssertTrue(soldEntry.label.contains("$640"), "the Sold section's row reads \"\(soldEntry.label)\"")
    }

    /// The Sold side's row for one item — the `.combine`d element whose label
    /// is the whole announcement ("Telecaster, Sold Sep 11, 2026, $1,250,
    /// Gain $350 vs paid"), not the plain name inside it. The comma is what
    /// tells the two apart.
    @MainActor
    private func soldRow(in app: XCUIApplication, named name: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    /// Whether some text with exactly this label sits above `y` on screen —
    /// the way the Sell Plan's header is told from the list beneath it, since
    /// the same words appear in both.
    @MainActor
    private func staticText(in app: XCUIApplication, labelled label: String, above y: CGFloat) -> Bool {
        app.staticTexts
            .matching(NSPredicate(format: "label ==[c] %@", label))
            .allElementsBoundByIndex
            .contains { $0.frame.minY < y }
    }
}

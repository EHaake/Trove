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

        // Instrumented once at T005 and recorded in tasks.md, then removed:
        // inside the `.combine`d row, `sellPlan.reason` resolved to exactly
        // one element and `sellPlan.market` to *two per matched row* (six),
        // so both stay addressable but the market identifier is no count of
        // market lines. Nothing above depends on either.
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
}

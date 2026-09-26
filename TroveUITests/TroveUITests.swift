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
    @MainActor
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
    ///
    /// Since `018` (criteria 2 and 3) the "…" is a system menu on both
    /// lists: the Items list's export rows are submenus titled without the
    /// ellipsis (spec P2), the Wishlist's export directly and keep theirs.
    @MainActor
    func testEmptyCollectionOffersImportAndSettingsButNotExport() {
        let app = launchApp()

        for (tab, identifier, exports, notExports) in [
            ("Items", "moreActions.items", ["Export as CSV", "Export as PDF"], ["Export as CSV…", "Export as PDF…"]),
            ("Wishlist", "moreActions.wishlist", ["Export as CSV…", "Export as PDF…"], ["Export as CSV", "Export as PDF"]),
        ] {
            app.buttons[tab].tap()

            // By identifier: the Dashboard has a "More actions" badge too since
            // 013 Amendment A, and a label query could match the wrong tab.
            let badge = app.buttons[identifier]
            XCTAssertTrue(
                badge.waitForExistence(timeout: 5),
                "the \(tab) tab's overflow badge must exist on an empty collection"
            )
            badge.tap()

            let importButton = app.buttons["Import from CSV…"]
            XCTAssertTrue(importButton.waitForExistence(timeout: 5), "the \(tab) tab's menu should open")
            XCTAssertTrue(importButton.isEnabled, "Import must be enabled on an empty collection (\(tab))")
            XCTAssertTrue(app.buttons["Settings"].isEnabled, "Settings must be enabled on an empty collection (\(tab))")
            XCTAssertFalse(app.buttons["Get Blank Template…"].exists, "the template left the \(tab) tab's menu for Settings")
            // `isEnabled` on a missing element is false, so existence comes
            // first or a deleted menu item would pass as "disabled".
            for title in exports {
                XCTAssertTrue(app.buttons[title].exists, "\(title) should still be in the \(tab) tab's menu")
                XCTAssertFalse(app.buttons[title].isEnabled, "\(title) should disable when empty (\(tab))")
            }
            for title in notExports {
                XCTAssertFalse(app.buttons[title].exists, "the \(tab) tab's menu titles an export row \"\(title)\" (spec P2)")
            }

            tapOutsideMenu(in: app)
            XCTAssertTrue(importButton.waitForNonExistence(timeout: 5), "the \(tab) tab's menu should close")
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
    ///
    /// `018`: both legs drive the system menu — the Items sort from T001, the
    /// Wishlist's from T004.
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
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Create a sell plan"))
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

        // 009 P9: the tap on "Create a sell plan" created the plan, so the
        // page it came from now offers to view it. Read on the way back, not
        // off the view model — the view's action is what's under test: if it
        // navigated without calling `openSellPlan()`, the Sell Plan above
        // would still open and rank, and only this line would notice that no
        // plan was ever stored.
        app.buttons["Back"].tap()
        let viewPlan = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "View your sell plan"))
            .firstMatch
        XCTAssertTrue(
            viewPlan.waitForExistence(timeout: 5),
            "back on the wanted item's page, the entry point must read View your sell plan — the tap creates the plan"
        )
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

    /// Waits until `element` reads `label` — the gate the frame readings in
    /// G39 stand behind. A frame read while the badge still names the other
    /// side's order is a frame from before the header relaid out, so the two
    /// sides would not be comparable; the assertion that follows each wait
    /// then reports *what* it reads if the wait ran out.
    @MainActor
    private func waitForLabel(
        _ element: XCUIElement,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let reads = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [reads], timeout: 5),
            .completed,
            "the element still reads \"\(element.label)\" rather than \"\(label)\"",
            file: file,
            line: line
        )
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
        // `018`: a system menu under one header, in the system's casing
        // (`SortMenuCopy.header`) — exactly one: one section header, not two
        // (plan Q8).
        let header = app.staticTexts["Sort by"]
        XCTAssertTrue(
            header.waitForExistence(timeout: 5),
            "\(screen)'s Sort By should open",
            file: file,
            line: line
        )
        XCTAssertEqual(
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Sort by")).count,
            1,
            "\(screen)'s Sort By should carry exactly one \"Sort by\" header",
            file: file,
            line: line
        )
        // The menu row's title, as `MarketCopy.sortDescending` and
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
        tapOutsideMenu(in: app)
        XCTAssertTrue(
            header.waitForNonExistence(timeout: 5),
            "\(screen)'s Sort By should close",
            file: file,
            line: line
        )
    }

    /// Closes an open system menu the way a person does: one tap outside it.
    /// iOS consumes that tap rather than passing it through, and the point is
    /// fixed — over the screen's title, top left, clear of a menu opening
    /// down from a trailing header badge — so every caller closes a menu the
    /// same way (`018` plan §9).
    @MainActor
    private func tapOutsideMenu(in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.1)).tap()
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
    /// under the title matches the card, and the switch goes back to Owned in
    /// one tap.
    ///
    /// Its Sort By half is `014` criterion 3's now, not `006` criterion 7's:
    /// the Sold side *has* the search field, the chips and Sort By, in the
    /// Owned side's positions, and the badge names that side's own default
    /// ("Date sold"). What `006` asserted here — Sort By absent — is
    /// superseded, and the Owned side's "Date" is checked on the way back so
    /// the two selections can't be one.
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

        // 014 criterion 3, which supersedes `006`'s criterion 7 here: the
        // Sold side carries the Owned side's narrowing controls rather than
        // hiding them. The badge is present and names *this* side's order —
        // "Date sold", not "Date" — the search field is there, and the chips
        // are the sold half's categories only.
        let soldSortBadge = app.buttons["sortOptions.items"]
        XCTAssertTrue(soldSortBadge.waitForExistence(timeout: 5), "Sort By must show on the Sold side (014 criterion 3)")
        waitForLabel(soldSortBadge, "Sort by Date sold")
        XCTAssertEqual(
            soldSortBadge.label,
            "Sort by Date sold",
            "the badge must name the Sold side's own default order — it reads \"\(soldSortBadge.label)\""
        )

        // 014 criterion 3's measured half (G39, plan Q18): the switch's top
        // edge is at the same point on both sides. T010's device pass
        // row-profiled it 13.67 pt lower here — 168.00 pt against Owned's
        // 154.33 — because the Sold summary wrapped in the width the sort
        // badge left it. The wait above is the gate on both readings: the
        // header has to have relaid out under this side's order before its
        // frame means anything. `ItemListHeaderLayoutTests` measures the
        // same claim off-device, in points, on the ingredients.
        let soldSwitchTop = switchControl.frame.minY
        XCTAssertTrue(app.buttons["moreActions.items"].exists, "the overflow badge stays on the Sold side (criterion 7a)")
        XCTAssertTrue(
            app.textFields["Search name or serial"].exists,
            "the Sold side must offer the search field (014 criterion 3)"
        )
        // The chips come from the sold half alone: the two sold items sit in
        // Music/Guitars and Music/Amps, and the Leica's Photography/Cameras
        // is the owned half's category — offering it here would narrow to
        // nothing.
        XCTAssertTrue(app.buttons["Guitars"].exists, "the Sold side must offer the Telecaster's category chip")
        XCTAssertTrue(app.buttons["Amps"].exists, "the Sold side must offer the Blues Junior's category chip")
        XCTAssertFalse(app.buttons["Cameras"].exists, "nothing sold sits in Cameras — the chip belongs to the Owned side")
        // The un-valued chip is Owned-only by construction (plan Q2). Both
        // spellings, since the chip's text and its accessibility label
        // differ and either appearing here would be the defect.
        XCTAssertFalse(app.buttons["Not yet valued"].exists, "the un-valued chip has no place on the Sold side")
        XCTAssertFalse(
            app.buttons["Clear the not-yet-valued filter"].exists,
            "the un-valued chip has no place on the Sold side"
        )

        // One tap back to Owned, which is a different list with its own
        // selection under the same controls.
        switchControl.buttons["Owned"].tap()
        XCTAssertTrue(
            app.staticTexts["Leica M6"].waitForExistence(timeout: 5),
            "the Owned side should list the item that wasn't sold"
        )
        XCTAssertFalse(soldRow(in: app, named: "Telecaster").exists, "a sold item must not appear on the Owned side")
        let ownedSortBadge = app.buttons["sortOptions.items"]
        XCTAssertTrue(ownedSortBadge.waitForExistence(timeout: 5), "Sort By stays on the Owned side")
        waitForLabel(ownedSortBadge, "Sort by Date")
        XCTAssertEqual(
            ownedSortBadge.label,
            "Sort by Date",
            "the Owned side's Sort By is unchanged (criterion 7) — it reads \"\(ownedSortBadge.label)\""
        )

        let ownedSwitchTop = switchControl.frame.minY
        XCTAssertEqual(
            soldSwitchTop,
            ownedSwitchTop,
            accuracy: 1,
            "the side switch sits \(abs(soldSwitchTop - ownedSwitchTop)) pt apart between the sides — Sold at \(soldSwitchTop), Owned at \(ownedSwitchTop). Something in the header changes height with the side (criterion 3)"
        )
        XCTAssertTrue(app.buttons["Cameras"].exists, "the Owned side's chips are the owned half's categories")
    }

    // MARK: - 014 Sold-side parity

    /// `014` criteria 4, 6, 7 and 9 on the seeded sold collection: each side
    /// keeps its own search, chip and sort while the other is visited, in both
    /// directions, and a Sold side narrowed to nothing says so in the
    /// no-matches words rather than "Nothing sold yet."
    ///
    /// Everything here is driven **through the controls on screen** — the sort
    /// row is tapped, the query is typed into the field and read back out of
    /// it — never through view-model state. Per-side keeping is proven below
    /// the view, so a `@State` mirror of the query in `ItemListView` would
    /// satisfy every unit test and still lose the Sold side's "tele" on the
    /// way back; typing and reading the field is what would catch it.
    ///
    /// Its mutation: the old `006` Q15 clearing put back in
    /// `ItemListViewModel.show(_:)` (reset `ownedNarrowing`/`soldNarrowing` on
    /// a side change) must turn the round trip red.
    @MainActor
    func testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSold"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Items"].tap()
        let switchControl = element(in: app, identifiedBy: "items.sideSwitch")
        XCTAssertTrue(switchControl.waitForExistence(timeout: 5), "the Items tab must offer the side switch")
        switchControl.buttons["Sold"].tap()

        // Criterion 6, from the control rather than from the model: the Sold
        // side's Sort By offers its own orders, and Price ↑ puts the
        // Blues Junior's $550 above the Telecaster's $1,250 — the reverse of
        // the default date order this side arrives in.
        let badge = app.buttons["sortOptions.items"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "the Sold side must offer Sort By")
        badge.tap()
        XCTAssertTrue(app.staticTexts["Sort by"].waitForExistence(timeout: 5), "the Sold side's Sort By should open")
        app.buttons["Price \u{2191}"].tap()

        let telecaster = soldRow(in: app, named: "Telecaster")
        let bluesJunior = soldRow(in: app, named: "Blues Junior")
        XCTAssertTrue(bluesJunior.waitForExistence(timeout: 5), "no Sold-side row for the Blues Junior")
        XCTAssertTrue(telecaster.exists, "no Sold-side row for the Telecaster")
        XCTAssertLessThan(
            bluesJunior.frame.minY,
            telecaster.frame.minY,
            "Price \u{2191} must put the cheaper sale first"
        )

        // Criterion 4: typed, not set. The rows narrow and the summary line
        // follows them down to the one sale left.
        let field = app.textFields["Search name or serial"]
        XCTAssertTrue(field.exists, "the Sold side must offer the search field")
        field.tap()
        field.typeText("tele")
        XCTAssertTrue(telecaster.waitForExistence(timeout: 5), "the query matches the Telecaster")
        XCTAssertFalse(bluesJunior.exists, "\"tele\" must not match the Blues Junior")
        XCTAssertTrue(
            summaryLine(in: app, reading: "1 sold \u{00B7} $1,250 \u{00B7} +$350 vs paid").waitForExistence(timeout: 5),
            "the Sold summary must follow the narrowing (P4)"
        )

        // Criterion 7, the first direction: the Owned side is untouched by
        // any of it — empty field, its own row, its own sort.
        switchControl.buttons["Owned"].tap()
        XCTAssertTrue(
            app.staticTexts["Leica M6"].waitForExistence(timeout: 5),
            "the Owned side's own row must show — the Sold side's query is not this side's"
        )
        // An empty `TextField` reports its placeholder as its value, which is
        // how "nothing typed here" reads to XCUITest.
        XCTAssertEqual(
            field.value as? String,
            "Search name or serial",
            "the Owned side's search field must be empty"
        )
        XCTAssertEqual(
            app.buttons["sortOptions.items"].label,
            "Sort by Date",
            "the Owned side's sort is its own (criterion 7)"
        )

        // Criterion 7, the other direction: the Sold side comes back exactly
        // as it was left — the typed query still in the field, the rows still
        // narrowed by it, the badge still on the order that was picked.
        switchControl.buttons["Sold"].tap()
        XCTAssertTrue(telecaster.waitForExistence(timeout: 5), "the Sold side's narrowing must survive the round trip")
        XCTAssertEqual(field.value as? String, "tele", "the Sold side's query must survive the round trip")
        XCTAssertFalse(bluesJunior.exists, "the Sold side must come back narrowed, not whole")
        XCTAssertEqual(
            app.buttons["sortOptions.items"].label,
            "Sort by Price \u{2191}",
            "the Sold side's sort must survive the round trip"
        )

        // Criterion 9: narrowed to nothing, this side says what the Owned
        // side says — the shared no-matches state (P5), not its own
        // "Nothing sold yet.", which belongs to a side with no sales at all.
        app.buttons["Clear search"].tap()
        XCTAssertTrue(bluesJunior.waitForExistence(timeout: 5), "clearing the query must bring both sales back")
        field.tap()
        field.typeText("zzz")
        XCTAssertTrue(
            app.staticTexts["No matches for \u{201C}zzz\u{201D}"].waitForExistence(timeout: 5),
            "a Sold side narrowed to nothing shows the no-matches state"
        )
        XCTAssertFalse(
            app.staticTexts["Nothing sold yet."].exists,
            "criterion 9: \"Nothing sold yet.\" is for a side with nothing sold, not for a query that matched nothing"
        )

        // The state's own action, not the field's X: both carry this label
        // while the empty state is up, and the lower one is the button the
        // no-matches screen offers.
        let clearActions = app.buttons
            .matching(NSPredicate(format: "label == %@", "Clear search"))
            .allElementsBoundByIndex
        guard let emptyStateClear = clearActions.max(by: { $0.frame.minY < $1.frame.minY }) else {
            return XCTFail("the no-matches state must offer Clear search")
        }
        emptyStateClear.tap()
        XCTAssertTrue(bluesJunior.waitForExistence(timeout: 5), "Clear search must bring the sales back")
        XCTAssertTrue(telecaster.exists, "Clear search must bring both sales back")
    }

    /// `014` criterion 1 on the seeded collection's one owned row: the leading
    /// swipe's three actions in the order spec Decision 2 fixes — Edit nearest
    /// the edge so a full swipe still edits, then Mark as sold…, then Copy —
    /// and the middle one opening the sale sheet for *that* row's item, with
    /// cancelling it changing nothing (P3).
    ///
    /// The swipe is opened with a **partial** drag rather than `swipeRight()`:
    /// a full-velocity swipe on a leading edge fires the edge action itself
    /// (Edit), which would open the item form and never show the three
    /// buttons this test is about.
    ///
    /// Its mutation: the middle button wired to `itemBeingEdited` instead of
    /// `itemBeingSold` must turn the sheet half red — the item form has no
    /// `sale.sheet.price`.
    @MainActor
    func testTheLeadingSwipeOffersMarkAsSoldBetweenEditAndCopyAndOpensTheSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSold"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Items"].tap()
        let leica = app.staticTexts["Leica M6"]
        XCTAssertTrue(leica.waitForExistence(timeout: 5), "the Owned side must list the seed's one owned item")

        // About 40 % of the row's width, pressed first so the gesture reads as
        // a drag rather than a flick. The row spans the window, so the
        // window's width is the row's.
        let start = leica.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: app.frame.width * 0.4, dy: 0))
        )

        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "the leading swipe didn't open")
        // "Sell" is the visible word and `SaleCopy.markAsSold` the
        // accessibility label the button carries. Which of the two a
        // VoiceOver user hears is a platform question no unit test in this
        // project can answer — whether `.accessibilityLabel` overrides a
        // `Label`'s text is only visible in the live accessibility tree —
        // so this is the one place criterion 12's spoken name is checked.
        // It matched *either* spelling while the answer was unknown (T009's
        // instrumented read); the answer has been "Mark as sold\u{2026}" in
        // every run since, so the close-out pins that alone. Matching "Sell"
        // too would have let the modifier silently stop working.
        //
        // Mutation: drop `.accessibilityLabel(SaleCopy.markAsSold)` from the
        // Sell button in `ItemListView` → the button reads "Sell" and this
        // assertion goes red.
        let sell = app.buttons
            .matching(NSPredicate(format: "label == %@", "Mark as sold\u{2026}"))
            .firstMatch
        XCTAssertTrue(
            sell.exists,
            "criteria 1 and 12: the leading swipe's middle action must exist and be announced as \"Mark as sold…\" (the visible word is \"Sell\")"
        )
        let copy = app.buttons["Copy"]
        XCTAssertTrue(copy.exists, "the leading swipe still offers Copy")

        // Decision 2's order, left to right: Edit is what a full swipe fires,
        // so it stays nearest the edge.
        XCTAssertLessThan(edit.frame.minX, sell.frame.minX, "Edit must stay nearest the leading edge")
        XCTAssertLessThan(sell.frame.minX, copy.frame.minX, "Mark as sold… sits between Edit and Copy")

        sell.tap()

        // P3: the sheet *is* the confirmation, and it opens on this row's
        // item — the Leica is valued at $2,600, so that is what the price
        // field is seeded with. Read with the grouping separator stripped:
        // the figure is the claim, not how the formatter groups it.
        let price = app.textFields["sale.sheet.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5), "Mark as sold… must open the sale sheet")
        let typed = (price.value as? String ?? "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
        XCTAssertEqual(typed, "2600", "the sheet must open on the swiped row's item — its value reads \"\(price.value as? String ?? "")\"")

        // Cancelling changes nothing: no sale, so the item is still owned and
        // its page would carry no Sold mark.
        app.buttons["Cancel"].tap()
        XCTAssertTrue(price.waitForNonExistence(timeout: 5), "Cancel must close the sale sheet")
        XCTAssertTrue(leica.waitForExistence(timeout: 5), "a cancelled sale leaves the item on the Owned side")
        XCTAssertFalse(
            element(in: app, identifiedBy: "sold.mark").exists,
            "a cancelled sale marks nothing sold"
        )
    }

    /// `014` criterion 14's behavioral half on the seeded sold collection, as
    /// `018` criterion 3 rewrote it: the "…" menu's two export rows are
    /// submenus (plan Q9) — three rows each, each enabled exactly when it has
    /// rows under the narrowing *on screen*.
    ///
    /// The gate is read where only the device can show it: the Sold side under
    /// the Guitars chip has a sold guitar and no owned one, so "Owned items"
    /// must come back present-and-disabled rather than missing. `isEnabled` is
    /// false for an element that doesn't exist, so existence is asserted first
    /// in every case here — a submenu that drew two rows would otherwise read
    /// as one correctly disabled.
    ///
    /// Its mutation (T005): the scope rows gated on `viewModel.canExportCSV`
    /// (the submenu's widest-scope gate) instead of `canExport(scope)` must
    /// turn "Owned items" red under the Guitars chip.
    @MainActor
    func testTheExportRowsAreSubmenusGatedByWhatIsOnScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSold"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Items"].tap()

        // By identifier: the Dashboard carries a "More actions" badge of its
        // own, and a label query could match the wrong tab.
        let badge = app.buttons["moreActions.items"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "the Items list must offer its overflow badge")
        badge.tap()

        let exportPDF = app.buttons["Export as PDF"]
        XCTAssertTrue(exportPDF.waitForExistence(timeout: 5), "the overflow should open")
        exportPDF.tap()

        // The submenu's three rows, all enabled: the whole seed is in scope,
        // unnarrowed.
        let owned = app.buttons["Owned items"]
        XCTAssertTrue(owned.waitForExistence(timeout: 5), "Export as PDF must open its submenu")
        for title in ["Owned items", "Sold items", "Owned and sold"] {
            XCTAssertTrue(app.buttons[title].exists, "the PDF submenu must offer \(title)")
            XCTAssertTrue(app.buttons[title].isEnabled, "\(title) has rows in the unnarrowed seed, so it must be enabled")
        }

        tapOutsideMenu(in: app)
        XCTAssertTrue(owned.waitForNonExistence(timeout: 5), "the outside tap must close the menu")

        // The Sold side, narrowed to guitars: the seed's one guitar is sold,
        // so the owned scope has nothing to write under what's on screen.
        let switchControl = element(in: app, identifiedBy: "items.sideSwitch")
        XCTAssertTrue(switchControl.waitForExistence(timeout: 5), "the Items tab must offer the side switch")
        switchControl.buttons["Sold"].tap()
        let guitars = app.buttons["Guitars"]
        XCTAssertTrue(guitars.waitForExistence(timeout: 5), "the Sold side's chips are the sold half's categories")
        guitars.tap()
        XCTAssertTrue(
            soldRow(in: app, named: "Telecaster").waitForExistence(timeout: 5),
            "the Guitars chip must leave the sold guitar on screen"
        )

        badge.tap()
        let exportCSV = app.buttons["Export as CSV"]
        XCTAssertTrue(exportCSV.waitForExistence(timeout: 5), "the overflow should open on the Sold side")
        XCTAssertTrue(exportCSV.isEnabled, "the submenu is enabled while any scope has rows")
        exportCSV.tap()

        XCTAssertTrue(owned.waitForExistence(timeout: 5), "a scope with no rows stays in the submenu, disabled — it must not vanish")
        XCTAssertFalse(
            owned.isEnabled,
            "no owned guitar is on screen, so Owned items must be disabled (criterion 3)"
        )
        for title in ["Sold items", "Owned and sold"] {
            XCTAssertTrue(app.buttons[title].exists, "the CSV submenu must offer \(title)")
            XCTAssertTrue(app.buttons[title].isEnabled, "\(title) carries the sold guitar, so it must be enabled")
        }

        // Picking a scope closes the menu and hands off to the share sheet,
        // which is the device pass's to look at — no existing UI test
        // asserts one.
        app.buttons["Sold items"].tap()
        XCTAssertTrue(
            owned.waitForNonExistence(timeout: 5),
            "picking a scope must close the menu"
        )
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
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Create a sell plan"))
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
        let soldEntry = soldRow(in: app, named: "Blues Junior", precededBy: "Sold")
        XCTAssertTrue(soldEntry.waitForExistence(timeout: 5), "the plan's Sold section should list the sale")
        XCTAssertGreaterThan(soldEntry.frame.minY, headerBand, "the Sold section sits under the candidates")
        XCTAssertTrue(soldEntry.label.contains("$640"), "the Sold section's row reads \"\(soldEntry.label)\"")
    }

    /// `009` T009c, the person's walkthrough: tapping *anywhere* on a Sell
    /// Plan candidate's card toggles it, not only its checkbox or its text —
    /// and the Mark as sold… strip under it stays a target of its own (`006`
    /// spec Decision 4).
    ///
    /// Hit-testing is only visible here: the unit suite can't see which view
    /// a tap lands on. The card is tapped in its bottom padding band, which is
    /// empty whatever the row says: the point is read off the *strip's* frame
    /// — its horizontal middle, half of `cardPadding` (16 pt, `ThemeMetrics`)
    /// above its top edge, which is where the card ends. Not off the card
    /// button's own frame: that one follows the fix under test (without the
    /// content shape it shrinks to what the card draws, measured 348 pt wide
    /// against 380), and a point derived from it would move with the thing it
    /// is checking. The strip's frame doesn't depend on the card at all. The
    /// strip itself is tapped at its leading tenth, where the right-aligned
    /// label never reaches. Selection is read from the card's `isSelected`
    /// trait, which the row adds from the same `isSelected` it draws.
    ///
    /// Its mutation: removing the card's `.contentShape(Rectangle())` in
    /// `SellPlanRow` must turn the first toggle assertion red — a `.plain`
    /// button hit-tests only what it draws.
    @MainActor
    func testTappingAnEmptyPartOfASellPlanCardTogglesItAndTheStripStaysApart() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSellPlan"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Wishlist"].tap()
        openDetail(in: app, named: "Summicron 35mm f/2")
        let findItemsToSell = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Create a sell plan"))
            .firstMatch
        XCTAssertTrue(findItemsToSell.waitForExistence(timeout: 5), "the wishlist detail must offer a way into the Sell Plan")
        scrollUntilHittable(findItemsToSell, in: app)
        findItemsToSell.tap()

        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Blues Junior"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the seeded plan must offer the Blues Junior as a candidate")

        // The strip under this card: the first that starts below its top.
        let strip = app.buttons
            .matching(identifier: "sellPlan.row.markAsSold")
            .allElementsBoundByIndex
            .filter { $0.frame.minY > card.frame.minY }
            .min { $0.frame.minY < $1.frame.minY }
        guard let markAsSold = strip else {
            return XCTFail("the Blues Junior's row must offer Mark as sold…")
        }
        scrollUntilHittable(markAsSold, in: app)

        let startedSelected = card.isSelected
        let paddingBand = markAsSold.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: markAsSold.frame.width / 2, dy: -8))
        let price = app.textFields["sale.sheet.price"]

        // First tap on empty card: the selection flips, and no sheet opens.
        paddingBand.tap()
        let flipped = expectation(
            for: NSPredicate(format: "isSelected == %@", NSNumber(value: !startedSelected)),
            evaluatedWith: card
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [flipped], timeout: 5),
            .completed,
            "tapping the card's empty padding must toggle it — it still reads isSelected \(card.isSelected)"
        )
        XCTAssertFalse(price.exists, "a tap on the card must not open the sale sheet")

        // Second tap at the same point: back to where it started.
        paddingBand.tap()
        let restored = expectation(
            for: NSPredicate(format: "isSelected == %@", NSNumber(value: startedSelected)),
            evaluatedWith: card
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [restored], timeout: 5),
            .completed,
            "a second tap at the same empty point must toggle it back — it reads isSelected \(card.isSelected)"
        )

        // The strip's own empty space opens the sheet and leaves the card be.
        markAsSold.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: markAsSold.frame.width / 10, dy: markAsSold.frame.height / 2))
            .tap()
        XCTAssertTrue(price.waitForExistence(timeout: 5), "tapping the strip's empty space must open the sale sheet")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(price.waitForNonExistence(timeout: 5), "Cancel should close the sale sheet")
        XCTAssertEqual(
            card.isSelected,
            startedSelected,
            "a tap on the Mark as sold… strip must not toggle the card above it"
        )
    }

    /// `009` T014a, the person's instruction after T009c ("Fix it now"): the
    /// Overview's not-yet-valued callout follows its link from a tap anywhere
    /// inside its box, not only on its words or its arrow.
    ///
    /// Two items are added with no current value, so the callout reads
    /// "2 items" and leads to the Items list narrowed to them — whose own
    /// clear-chip is an unambiguous sign the link was followed (one item would
    /// open that item, whose name the list also shows). The tap lands at a
    /// fixed fraction of the callout's own frame, (0.8, 0.75): below "VALUE"
    /// and right of the second line, about 18 pt from anything drawn at the
    /// default text size (frame 354 × 73 pt). Before tapping, the point is
    /// checked against the frame of every text and image inside the callout,
    /// so a layout change can't quietly move the tap onto a label.
    ///
    /// Its mutation: delete the callout's `.contentShape` and add
    /// `.allowsHitTesting(false)` to its hairline outline — the outline still
    /// draws, so the frame doesn't move, but it stops catching the tap (today
    /// it would, which `tokens.md`'s tap-target rule says not to rely on). The
    /// navigation assertion goes red.
    @MainActor
    func testTappingAnEmptyPartOfTheUnvaluedCalloutFollowsIt() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Items"].tap()
        for name in ["Rolleiflex 2.8F", "Hasselblad 500C/M"] {
            let addButton = app.buttons["Add item"]
            XCTAssertTrue(addButton.waitForExistence(timeout: 5), "the Items tab must offer quick add")
            addButton.tap()
            let nameField = app.textFields["Name"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5), "the add-item sheet didn't present")
            nameField.tap()
            nameField.typeText(name)
            let categoryField = app.textFields["Category"]
            categoryField.tap()
            categoryField.typeText("Photography/Cameras")
            let priceField = app.textFields["Price paid"]
            priceField.tap()
            priceField.typeText("900")
            app.buttons["Save item"].tap()
            XCTAssertTrue(
                app.buttons["Save item"].waitForNonExistence(timeout: 5),
                "saving \(name) with no current value should close the sheet"
            )
        }

        app.buttons["Overview"].tap()
        let callout = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "2 items not yet valued"))
            .firstMatch
        XCTAssertTrue(callout.waitForExistence(timeout: 5), "two items without a value must raise the callout")
        scrollUntilHittable(callout, in: app)

        let offset = CGVector(dx: 0.8, dy: 0.75)
        let frame = callout.frame
        let point = CGPoint(x: frame.minX + frame.width * offset.dx, y: frame.minY + frame.height * offset.dy)
        let drawn = callout.staticTexts.allElementsBoundByIndex + callout.images.allElementsBoundByIndex
        XCTAssertFalse(drawn.isEmpty, "the callout's texts must be readable, or the anchor below checks nothing")
        for element in drawn {
            XCTAssertFalse(
                element.frame.contains(point),
                "the tap point \(point) must miss \"\(element.label)\" (\(element.frame)) — it is meant to land on empty space"
            )
        }

        callout.coordinate(withNormalizedOffset: offset).tap()
        XCTAssertTrue(
            app.buttons["Clear the not-yet-valued filter"].waitForExistence(timeout: 5),
            "a tap on the callout's empty space at \(point) did not follow it to the narrowed list"
        )
    }

    /// The Sold side's row for one item — the `.combine`d element whose label
    /// is the whole announcement ("Telecaster, Sold Sep 11, 2026, $1,250,
    /// Gain $350 vs paid"), not the plain name inside it. The comma is what
    /// tells the two apart.
    ///
    /// `precededBy` is for the Sell Plan's own Sold section, whose row draws
    /// the mark *before* the name (spec Decision 14), so its combined label
    /// opens "Sold, Blues Junior, …" where the Items tab's opens with the
    /// name. Matched case-insensitively because that mark is a `monoLabel`,
    /// which comes back raised on some snapshots and in the source's own case
    /// on others — the same reason every other `monoLabel` line here is.
    @MainActor
    private func soldRow(in app: XCUIApplication, named name: String, precededBy mark: String? = nil) -> XCUIElement {
        let opening = mark.map { "\($0), \(name)," } ?? "\(name),"
        return app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", opening)).firstMatch
    }

    /// The Sold side's summary line, matched on the words it must contain —
    /// case-insensitively, because `monoLabel` raises this line on screen and
    /// which case comes back is nothing these tests are about.
    @MainActor
    private func summaryLine(in app: XCUIApplication, reading text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
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

    // MARK: - 015 Mark as bought

    /// `015` criteria 1 and 5 on the seeded Sell Plan collection
    /// (`-seedSellPlan`, unchanged: it already carries the one wanted item,
    /// "Summicron 35mm f/2" at an estimated $2,400): the wishlist row's
    /// leading swipe offers **Mark as bought…** between Edit and Copy, and
    /// tapping it opens the purchase sheet pre-filled from that estimate.
    ///
    /// The `014` twin of this test on the Items list
    /// (`testTheLeadingSwipeOffersMarkAsSoldBetweenEditAndCopyAndOpensTheSheet`)
    /// is the pattern, including the partial drag: `swipeRight()` fires the
    /// edge action instead of opening the tray (`014` T009's finding).
    ///
    /// Its mutations: wiring the middle swipe button to `itemBeingEdited`
    /// instead of `itemBeingBought` must turn the price field's existence red
    /// (the edit form opens instead of the sheet); dropping
    /// `.accessibilityLabel(PurchaseCopy.markAsBought)` from that button must
    /// turn the button's existence red, because it then reads "Buy" — which
    /// is why this matches `"Mark as bought\u{2026}"` alone and never `OR
    /// "Buy"` (the `014` close-out lesson: the hedge lets the modifier stop
    /// working in silence).
    @MainActor
    func testTheWishlistsLeadingSwipeOffersMarkAsBoughtAndTheSheetSeedsFromTheEstimate() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSellPlan"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Wishlist"].tap()
        let summicron = app.staticTexts["Summicron 35mm f/2"]
        XCTAssertTrue(summicron.waitForExistence(timeout: 5), "the seed's one wanted item must be on the Wishlist")

        openLeadingSwipe(on: summicron, in: app)

        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "the leading swipe didn't open")
        // "Buy" is the visible word and `PurchaseCopy.markAsBought` the
        // accessibility label the button carries — the Items list's Sell
        // swipe, on the wanted side. Matched on the spoken name alone.
        let buy = app.buttons
            .matching(NSPredicate(format: "label == %@", "Mark as bought\u{2026}"))
            .firstMatch
        XCTAssertTrue(
            buy.exists,
            "criterion 1: the wishlist's leading swipe must offer an action announced as \"Mark as bought…\" (the visible word is \"Buy\")"
        )
        let copy = app.buttons["Copy"]
        XCTAssertTrue(copy.exists, "the wishlist's leading swipe still offers Copy")

        // Criterion 1's order, left to right: Edit is what a full swipe
        // fires, so it stays nearest the edge.
        XCTAssertLessThan(edit.frame.minX, buy.frame.minX, "Edit must stay nearest the leading edge")
        XCTAssertLessThan(buy.frame.minX, copy.frame.minX, "Mark as bought… sits between Edit and Copy")

        buy.tap()

        // Criterion 5's pre-fill: the Summicron is wanted at an estimated
        // $2,400, so that is what the price field opens with. Read with the
        // grouping separator stripped — the figure is the claim, not how the
        // formatter groups it.
        let price = app.textFields["purchase.sheet.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5), "Mark as bought… must open the purchase sheet")
        let typed = (price.value as? String ?? "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
        XCTAssertEqual(typed, "2400", "the sheet must pre-fill from the estimate — it reads \"\(price.value as? String ?? "")\"")

        // Cancelling buys nothing: the entry is still wanted, and nothing was
        // added to the collection.
        app.buttons["Cancel"].tap()
        XCTAssertTrue(price.waitForNonExistence(timeout: 5), "Cancel must close the purchase sheet")
        XCTAssertTrue(summicron.waitForExistence(timeout: 5), "a cancelled purchase leaves the entry on the Wishlist")

        app.buttons["Items"].tap()
        XCTAssertTrue(
            app.staticTexts["Telecaster"].waitForExistence(timeout: 5),
            "the Items tab should list the seed's owned gear"
        )
        XCTAssertFalse(
            app.staticTexts["Summicron 35mm f/2"].exists,
            "a cancelled purchase adds nothing to the collection"
        )
    }

    /// `015` criteria 8 and 11, the whole move: the same swipe, a condition
    /// chosen, **Mark as bought** — and the entry is gone from the Wishlist,
    /// which falls back to its existing empty state, while the Items tab
    /// lists it at what was paid.
    ///
    /// Its mutation: dropping `WishlistViewModel.load`'s `!$0.isBought`
    /// filter must turn the empty state red — the bought row is still listed.
    @MainActor
    func testMarkingAWantedItemBoughtMovesItToTheCollection() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSellPlan"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        app.buttons["Wishlist"].tap()
        let summicron = app.staticTexts["Summicron 35mm f/2"]
        XCTAssertTrue(summicron.waitForExistence(timeout: 5), "the seed's one wanted item must be on the Wishlist")

        openLeadingSwipe(on: summicron, in: app)

        let buy = app.buttons
            .matching(NSPredicate(format: "label == %@", "Mark as bought\u{2026}"))
            .firstMatch
        XCTAssertTrue(buy.waitForExistence(timeout: 5), "the leading swipe must offer Mark as bought…")
        buy.tap()

        let price = app.textFields["purchase.sheet.price"]
        XCTAssertTrue(price.waitForExistence(timeout: 5), "Mark as bought… must open the purchase sheet")

        // Criterion 5's condition, which is a row of capsule chips rather
        // than a picker (a system menu inside page content is what
        // `MenuPolicyTests` forbids). The chip carries the selected trait,
        // which is both how VoiceOver says which one is chosen and how this
        // reads the selection back.
        let good = app.buttons["Good"]
        XCTAssertTrue(good.exists, "criterion 5: the sheet must ask for a condition")
        good.tap()
        XCTAssertTrue(good.isSelected, "the tapped condition chip must come back selected")

        app.buttons["purchase.sheet.confirm"].tap()
        XCTAssertTrue(price.waitForNonExistence(timeout: 5), "Mark as bought must close the sheet")

        // Criteria 8 and 11: the last wanted entry is bought, so the Wishlist
        // is empty — and lands on the empty state it already had, in its own
        // words.
        XCTAssertTrue(
            app.staticTexts["Nothing on the list yet"].waitForExistence(timeout: 5),
            "criterion 11: buying the last wishlist item leaves the Wishlist in its existing empty state"
        )
        XCTAssertFalse(
            summicron.exists,
            "criterion 8: the bought entry leaves the Wishlist"
        )

        // And criterion 8's other half: it is in the collection now, at what
        // was paid — the row is one `.combine`d element, so the name and the
        // figure are in the one label.
        app.buttons["Items"].tap()
        // Matched across every type rather than `app.staticTexts`: an owned
        // row's `.combine`d element comes back as a plain container, not a
        // static text (the Sold side's row does come back as one, which is
        // why `soldRow` can query `staticTexts` — read off the hierarchy,
        // not assumed). The comma is what tells the combined row from the
        // plain name inside it.
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Summicron 35mm f/2,"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "criterion 8: the bought entry must appear in the collection")
        XCTAssertTrue(row.label.contains("$2,400"), "the row reads \"\(row.label)\"")
    }

    // MARK: - 009 Plans (the seeded collection)

    /// `009` criteria 4, 5 and 2 on the seeded Plans collection
    /// (`-seedPlans`, plan §13): the tab sits fourth, opens on Active, lists
    /// the three active plans — the Fuji among them — and keeps the planless
    /// and the bought ones off; Completed lists the bought plan; and a
    /// relaunch comes back to Active after being left on Completed.
    ///
    /// **The Fuji row is the launch wiring's only automated coverage.** The
    /// seed leaves it unchecked, the shape only an app from before `009`
    /// writes, so it is a plan only if the carry-over actually ran at launch.
    /// Its mutations: dropping the `onSettled` closure from `TroveApp.init`,
    /// or moving the seeds below the monitor's construction, must turn the
    /// Fuji assertion red.
    @MainActor
    func testThePlansTabSitsFourthAndOpensOnActiveEveryLaunch() {
        let app = launchPlans()

        // Criterion 5: fourth in the tab bar, read off the screen.
        let tabs = ["Overview", "Items", "Wishlist", "Plans"].map { app.buttons[$0] }
        for tab in tabs {
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "the tab bar has no \(tab.label) button")
        }
        for (earlier, later) in zip(tabs, tabs.dropFirst()) {
            XCTAssertLessThan(earlier.frame.minX, later.frame.minX, "\(earlier.label) should sit left of \(later.label)")
        }

        app.buttons["Plans"].tap()
        let switchControl = element(in: app, identifiedBy: "plans.sideSwitch")
        XCTAssertTrue(switchControl.waitForExistence(timeout: 5), "the Plans tab must offer the side switch")
        XCTAssertEqual(switchControl.value as? String, "Active", "the Plans tab must open on Active")

        XCTAssertTrue(
            app.staticTexts["Fuji X100V"].waitForExistence(timeout: 5),
            "the Fuji X100V's plan exists only if the launch ran the carry-over — its absence means the launch wiring is broken"
        )
        XCTAssertTrue(app.staticTexts["Vox AC15"].exists, "the Vox AC15's plan must be Active")
        XCTAssertTrue(app.staticTexts["Summicron 35mm f/2"].exists, "the Summicron's plan must be Active")

        // Criterion 2: every candidate sold, and still a plan — covered.
        let vox = planRow(in: app, named: "Vox AC15")
        XCTAssertTrue(vox.waitForExistence(timeout: 5), "no combined row for the Vox AC15")
        XCTAssertTrue(vox.label.contains("1 sold toward it"), "the Vox AC15's row reads \"\(vox.label)\"")
        XCTAssertTrue(vox.label.contains("Covered"), "the Vox AC15's row reads \"\(vox.label)\"")

        XCTAssertFalse(app.staticTexts["Rode NT5"].exists, "a wanted item with no plan is on neither side")
        XCTAssertFalse(app.staticTexts["Nikon FM2"].exists, "a bought item with no plan is on neither side")
        XCTAssertFalse(app.staticTexts["Hasselblad 80mm"].exists, "a bought plan belongs to Completed")

        switchControl.buttons["Completed"].tap()
        let hasselblad = planRow(in: app, named: "Hasselblad 80mm")
        XCTAssertTrue(hasselblad.waitForExistence(timeout: 5), "Completed must list the bought plan")
        XCTAssertTrue(hasselblad.label.contains("Bought"), "the Hasselblad's row reads \"\(hasselblad.label)\"")
        XCTAssertFalse(
            hasselblad.label.contains("Covered"),
            "$300 sold toward a $950 estimate is not covered — the row reads \"\(hasselblad.label)\""
        )
        XCTAssertFalse(app.staticTexts["Nikon FM2"].exists, "a bought item with no plan is not a completed plan")
        XCTAssertFalse(app.staticTexts["Vox AC15"].exists, "an active plan is not on Completed")

        // Left on Completed; the next launch opens on Active again.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        app.buttons["Plans"].tap()
        let relaunchedSwitch = element(in: app, identifiedBy: "plans.sideSwitch")
        XCTAssertTrue(relaunchedSwitch.waitForExistence(timeout: 5))
        XCTAssertEqual(relaunchedSwitch.value as? String, "Active", "every launch must open the Plans tab on Active")
    }

    /// Criteria 5 and 6 on the Active side: the default is the newest plan
    /// first (the Vox, two days old, above the Summicron, three), **Name**
    /// reverses that pair, and the selection survives a visit to Completed.
    /// Driven through the badge and its system menu on screen (`018`): the
    /// row is a button titled with its order, and choosing it closes the
    /// menu.
    @MainActor
    func testSortingEachSideReordersTheRowsAndIsKeptAcrossASwitch() {
        let app = launchPlans()
        app.buttons["Plans"].tap()

        let summicron = app.staticTexts["Summicron 35mm f/2"]
        let vox = app.staticTexts["Vox AC15"]
        XCTAssertTrue(summicron.waitForExistence(timeout: 5))
        XCTAssertTrue(vox.exists)
        XCTAssertLessThan(vox.frame.minY, summicron.frame.minY, "by default the newer plan (Vox) comes first")

        let badge = app.buttons["sortOptions.plans"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "the Active side must offer Sort By")
        XCTAssertEqual(badge.label, "Sort by Newest")
        badge.tap()
        XCTAssertTrue(app.staticTexts["Sort by"].waitForExistence(timeout: 5), "the Plans Sort By should open")
        app.buttons["Name"].tap()
        waitForLabel(badge, "Sort by Name")
        XCTAssertLessThan(summicron.frame.minY, vox.frame.minY, "Name must put the Summicron above the Vox")

        let switchControl = element(in: app, identifiedBy: "plans.sideSwitch")
        switchControl.buttons["Completed"].tap()
        XCTAssertTrue(planRow(in: app, named: "Hasselblad 80mm").waitForExistence(timeout: 5))
        waitForLabel(badge, "Sort by Newest")
        switchControl.buttons["Active"].tap()
        XCTAssertTrue(summicron.waitForExistence(timeout: 5))
        waitForLabel(badge, "Sort by Name")
        XCTAssertLessThan(summicron.frame.minY, vox.frame.minY, "the Active side must come back sorted by Name")
    }

    /// `018` criterion 5 on every sort menu in the app, over the seeded Plans
    /// collection (`-seedPlans` leaves rows on all five): Items' Owned and
    /// Sold sides, the Wishlist, and both Plans sides. Each opens under
    /// exactly one "Sort by" header, offers one row per order, and checks the
    /// default and nothing else; the Custom row carries "Drag rows to
    /// reorder" on the two lists with a manual order, and no row does on the
    /// other three.
    ///
    /// What XCUITest exposes, found here (plan §9's open question): the
    /// checked row is `isSelected` (the `Toggle` row's Selected trait), and on
    /// the iOS 27.0 runtime the subtitle is joined into the row's label —
    /// "Custom, Drag rows to reorder" — rather than exposed as a static text
    /// of its own. On iOS 26.5 the subtitle is drawn but absent from the tree
    /// (T002), so this test's subtitle legs speak for the 27.0 runtime the UI
    /// suite runs on. The header is counted by an exact label, so the badge's
    /// own "Sort by Date" never matches.
    ///
    /// Mutations (T004): `manualOrder: .newest` on a Plans menu → red (the
    /// Newest row's label); the subtitle `Text` removed from `SortMenu` → red
    /// (the Custom row's label).
    @MainActor
    func testEverySortMenuOffersItsOrdersUnderSortByWithTheCurrentOneChecked() {
        let app = launchPlans()

        app.buttons["Items"].tap()
        assertSortMenu(
            in: app, badge: "sortOptions.items", screen: "Items' Owned side",
            options: ["Custom", "Date", "Value \u{2193}", "Value \u{2191}", "Market \u{2193}", "Market \u{2191}", "Desire"],
            current: "Date", manualOrder: "Custom"
        )
        let itemsSwitch = element(in: app, identifiedBy: "items.sideSwitch")
        XCTAssertTrue(itemsSwitch.waitForExistence(timeout: 5), "the Items tab must offer the side switch")
        itemsSwitch.buttons["Sold"].tap()
        assertSortMenu(
            in: app, badge: "sortOptions.items", screen: "Items' Sold side",
            options: ["Date sold", "Price \u{2193}", "Price \u{2191}", "Paid \u{2193}", "Paid \u{2191}", "Gain \u{2193}", "Gain \u{2191}", "Name"],
            current: "Date sold", manualOrder: nil
        )

        app.buttons["Wishlist"].tap()
        assertSortMenu(
            in: app, badge: "sortOptions.wishlist", screen: "the Wishlist",
            options: ["Custom", "Cost \u{2191}", "Cost \u{2193}", "Market \u{2193}", "Market \u{2191}", "Desire", "Alphabetical"],
            current: "Custom", manualOrder: "Custom"
        )

        app.buttons["Plans"].tap()
        assertSortMenu(
            in: app, badge: "sortOptions.plans", screen: "Plans' Active side",
            options: ["Newest", "Oldest", "Name", "Wishlist order"],
            current: "Newest", manualOrder: nil
        )
        let plansSwitch = element(in: app, identifiedBy: "plans.sideSwitch")
        XCTAssertTrue(plansSwitch.waitForExistence(timeout: 5), "the Plans tab must offer the side switch")
        plansSwitch.buttons["Completed"].tap()
        XCTAssertTrue(planRow(in: app, named: "Hasselblad 80mm").waitForExistence(timeout: 5), "Completed must list the bought plan")
        assertSortMenu(
            in: app, badge: "sortOptions.plans", screen: "Plans' Completed side",
            options: ["Newest", "Oldest", "Name"],
            current: "Newest", manualOrder: nil
        )
    }

    /// Opens one sort menu and reads it whole: one "Sort by", exactly one
    /// row per order and no other row, each labelled exactly its name (the manual order's with its subtitle
    /// joined, as iOS 27.0 exposes it), exactly `current` selected, and no
    /// subtitle anywhere when the list has no manual order. Closed by the
    /// outside tap.
    @MainActor
    private func assertSortMenu(
        in app: XCUIApplication,
        badge identifier: String,
        screen: String,
        options: [String],
        current: String,
        manualOrder: String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let subtitle = "Drag rows to reorder"
        let badge = app.buttons[identifier]
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "\(screen) must offer Sort By", file: file, line: line)
        badge.tap()
        let header = app.staticTexts["Sort by"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "\(screen)'s Sort By should open", file: file, line: line)
        XCTAssertEqual(
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Sort by")).count,
            1,
            "\(screen)'s Sort By should carry exactly one \"Sort by\" header",
            file: file,
            line: line
        )

        // The menu's rows are the cells of the one collection view holding the
        // header (iOS 27.0 draws a system menu as a collection view of cells,
        // each wrapping its row's button), so a row nobody listed, or a row
        // drawn twice, changes the count.
        let menus = app.collectionViews.containing(NSPredicate(format: "label == %@", "Sort by"))
        XCTAssertEqual(menus.count, 1, "\(screen)'s Sort By should be one menu", file: file, line: line)
        XCTAssertEqual(
            menus.firstMatch.cells.count,
            options.count,
            "\(screen)'s Sort By should carry exactly one row per order",
            file: file,
            line: line
        )

        var selected: [String] = []
        for option in options {
            let rows = app.buttons
                .matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", option, "\(option), "))
            XCTAssertEqual(rows.count, 1, "\(screen)'s Sort By should carry exactly one \(option) row", file: file, line: line)
            let row = rows.firstMatch
            guard row.exists else {
                XCTFail("\(screen)'s Sort By has no \(option) row", file: file, line: line)
                continue
            }
            let expected = option == manualOrder ? "\(option), \(subtitle)" : option
            XCTAssertEqual(row.label, expected, "\(screen)'s \(option) row", file: file, line: line)
            if row.isSelected { selected.append(option) }
        }
        XCTAssertEqual(selected, [current], "\(screen)'s Sort By should check its default and nothing else", file: file, line: line)

        if manualOrder == nil {
            XCTAssertEqual(
                app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", subtitle)).count,
                0,
                "\(screen) has no manual order, so no row carries \"\(subtitle)\"",
                file: file,
                line: line
            )
        }

        tapOutsideMenu(in: app)
        XCTAssertTrue(header.waitForNonExistence(timeout: 5), "\(screen)'s Sort By should close", file: file, line: line)
    }

    /// Criterion 14: an Active row's leading swipe offers **Mark as bought…**
    /// (matched alone, never `OR "Buy"` — `015`'s close-out lesson), opening
    /// the purchase sheet seeded from the estimate; Cancel changes nothing,
    /// and confirming moves the plan to Completed. Opened with the partial
    /// drag, never `swipeRight()`, which fires the edge action instead.
    ///
    /// Its mutation: the Buy swipe wired to `pendingDeletion` instead of
    /// `planBeingBought` must turn the price field's existence red.
    @MainActor
    func testAnActiveRowsBuySwipeMovesThePlanToCompleted() {
        let app = launchPlans()
        app.buttons["Plans"].tap()

        let summicron = app.staticTexts["Summicron 35mm f/2"]
        XCTAssertTrue(summicron.waitForExistence(timeout: 5))
        let buy = app.buttons.matching(NSPredicate(format: "label == %@", "Mark as bought\u{2026}")).firstMatch
        let price = app.textFields["purchase.sheet.price"]

        openLeadingSwipe(on: summicron, in: app)
        XCTAssertTrue(buy.waitForExistence(timeout: 5), "an Active row's leading swipe must offer Mark as bought…")
        buy.tap()
        XCTAssertTrue(price.waitForExistence(timeout: 5), "Mark as bought… must open the purchase sheet")
        XCTAssertEqual(plainFigure(price), "2400", "the sheet must pre-fill from the estimate — it reads \"\(price.value as? String ?? "")\"")

        app.buttons["Cancel"].tap()
        XCTAssertTrue(price.waitForNonExistence(timeout: 5), "Cancel must close the purchase sheet")
        XCTAssertTrue(summicron.waitForExistence(timeout: 5), "a cancelled purchase leaves the plan on Active")

        openLeadingSwipe(on: summicron, in: app)
        XCTAssertTrue(buy.waitForExistence(timeout: 5), "the swipe must open a second time")
        buy.tap()
        XCTAssertTrue(price.waitForExistence(timeout: 5))
        app.buttons["Good"].tap()
        app.buttons["purchase.sheet.confirm"].tap()
        XCTAssertTrue(price.waitForNonExistence(timeout: 5), "Mark as bought must close the sheet")
        XCTAssertTrue(summicron.waitForNonExistence(timeout: 5), "a bought plan leaves Active")

        element(in: app, identifiedBy: "plans.sideSwitch").buttons["Completed"].tap()
        XCTAssertTrue(
            planRow(in: app, named: "Summicron 35mm f/2").waitForExistence(timeout: 5),
            "a bought plan lands on Completed"
        )
    }

    /// Decision 9: deleting a plan from its row's trailing swipe asks first,
    /// then removes the plan and nothing else — the wanted item stays on the
    /// Wishlist, offering a new plan, and the sale toward it stays on the
    /// Items tab's Sold side.
    @MainActor
    func testDeletingAPlanLeavesTheWantedItemAndTheSale() {
        let app = launchPlans()
        app.buttons["Plans"].tap()

        let vox = planRow(in: app, named: "Vox AC15")
        XCTAssertTrue(vox.waitForExistence(timeout: 5))
        openTrailingSwipe(on: vox, in: app)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "the trailing swipe must offer Delete")
        delete.tap()

        let alert = app.alerts["Delete the sell plan for Vox AC15?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Delete must ask first, naming the plan")
        alert.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Vox AC15"].waitForNonExistence(timeout: 5), "the deleted plan must leave the list")

        app.buttons["Wishlist"].tap()
        openDetail(in: app, named: "Vox AC15")
        let createPlan = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Create a sell plan")).firstMatch
        XCTAssertTrue(createPlan.waitForExistence(timeout: 5), "the wanted item stays, with no plan, so it offers a new one")

        app.buttons["Items"].tap()
        let switchControl = element(in: app, identifiedBy: "items.sideSwitch")
        XCTAssertTrue(switchControl.waitForExistence(timeout: 5))
        switchControl.buttons["Sold"].tap()
        XCTAssertTrue(
            soldRow(in: app, named: "Blues Junior").waitForExistence(timeout: 5),
            "deleting the plan must leave the sale toward it standing"
        )
    }

    /// Criterion 9's second half: a completed row opens the plan as a
    /// record — what sold toward it and when it was bought — with no
    /// purchase, no candidates, and Delete the one thing left to do.
    @MainActor
    func testACompletedPlanOpensAsARecord() {
        let app = launchPlans()
        app.buttons["Plans"].tap()

        let switchControl = element(in: app, identifiedBy: "plans.sideSwitch")
        XCTAssertTrue(switchControl.waitForExistence(timeout: 5))
        switchControl.buttons["Completed"].tap()
        openDetail(in: app, named: "Hasselblad 80mm")

        let soldEntry = soldRow(in: app, named: "NT1-A", precededBy: "Sold")
        XCTAssertTrue(soldEntry.waitForExistence(timeout: 5), "the record must list what sold toward it")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Bought ")).firstMatch.exists,
            "the record must say when it was bought"
        )
        XCTAssertFalse(element(in: app, identifiedBy: "purchase.sellPlan").exists, "a bought plan offers no purchase")
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Sell candidates")).firstMatch.exists,
            "a bought plan offers no candidates"
        )
        // The bar holds Back and Delete and nothing else — no Buy on a plan
        // whose item is already bought (plan §13 as amended; Q12).
        let bar = app.navigationBars["Sell plan"]
        XCTAssertTrue(bar.exists, "the record keeps the Sell plan bar")
        let barButtons = bar.buttons.allElementsBoundByIndex.map(\.label).sorted()
        XCTAssertEqual(barButtons, ["Back", "Delete"], "the record's bar must offer only Back and Delete — it offers \(barButtons)")
    }

    /// Criterion 15: the Dashboard's card counts the active plans and opens
    /// the Plans tab on Active, even when it was left on Completed.
    ///
    /// Its mutation: the card calling `router.showSoldItems()` must turn the
    /// switch assertion red.
    @MainActor
    func testTheDashboardCardOpensThePlansTabOnActive() {
        let app = launchPlans()
        app.buttons["Plans"].tap()
        let switchControl = element(in: app, identifiedBy: "plans.sideSwitch")
        XCTAssertTrue(switchControl.waitForExistence(timeout: 5))
        switchControl.buttons["Completed"].tap()
        XCTAssertTrue(planRow(in: app, named: "Hasselblad 80mm").waitForExistence(timeout: 5))

        app.buttons["Overview"].tap()
        let card = app.buttons["dashboard.plansCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "three active plans, so the card must show")
        XCTAssertTrue(card.label.contains("3 active sell plans"), "the Plans card reads \"\(card.label)\"")
        scrollUntilHittable(card, in: app)
        card.tap()

        XCTAssertTrue(switchControl.waitForExistence(timeout: 5), "the card should land on the Plans tab")
        let onActive = expectation(for: NSPredicate(format: "value == %@", "Active"), evaluatedWith: switchControl)
        XCTAssertEqual(
            XCTWaiter.wait(for: [onActive], timeout: 5),
            .completed,
            "the card must open Plans on Active — the switch reads \(switchControl.value as? String ?? "nil")"
        )
    }

    /// Creating a plan from a wanted item with none: the Sell Plan opens,
    /// the page comes back offering to view it with nothing set aside, and
    /// the Plans tab lists it.
    @MainActor
    func testCreatingASellPlanFromAWantedItem() {
        let app = launchPlans()
        app.buttons["Wishlist"].tap()
        openDetail(in: app, named: "Rode NT5")

        let createPlan = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Create a sell plan")).firstMatch
        XCTAssertTrue(createPlan.waitForExistence(timeout: 5), "a wanted item with no plan offers to create one")
        scrollUntilHittable(createPlan, in: app)
        createPlan.tap()
        XCTAssertTrue(app.navigationBars["Sell plan"].waitForExistence(timeout: 5), "the tap must open the Sell Plan")

        app.buttons["Back"].tap()
        let viewPlan = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "View your sell plan")).firstMatch
        XCTAssertTrue(viewPlan.waitForExistence(timeout: 5), "the page must now offer to view the plan")
        XCTAssertTrue(viewPlan.label.contains("Nothing set aside yet"), "the entry point reads \"\(viewPlan.label)\"")

        app.buttons["Plans"].tap()
        XCTAssertTrue(app.staticTexts["Rode NT5"].waitForExistence(timeout: 5), "the new plan must be listed on Plans")
    }

    // MARK: - 009 Amendment A

    /// Criterion 21's behavioural half (plan QA6): on a fresh install, every
    /// tab's root screen has a "…" that opens Settings, and Done closes it —
    /// `testDashboardOffersSettingsAndNothingElse`'s legs, once per tab. On
    /// the Plans tab, with nothing stored, Delete All Sell Plans is there and
    /// dimmed (criterion 22).
    ///
    /// Its mutation: removing the Plans tab's `OverflowBadge` must turn the
    /// Plans leg's badge assertion red.
    @MainActor
    func testEveryTabsRootReachesSettings() {
        let app = launchApp()
        XCTAssertTrue(
            app.staticTexts["Nothing tracked yet"].waitForExistence(timeout: 5),
            "Expected the first-run dashboard."
        )

        let tabs = [
            ("Overview", "moreActions.dashboard"),
            ("Items", "moreActions.items"),
            ("Wishlist", "moreActions.wishlist"),
            ("Plans", "moreActions.plans"),
        ]
        for (tab, identifier) in tabs {
            app.buttons[tab].tap()

            let badge = app.buttons[identifier]
            XCTAssertTrue(badge.waitForExistence(timeout: 5), "the \(tab) tab's root must have a \"…\"")
            badge.tap()
            let settings = app.buttons["Settings"]
            XCTAssertTrue(settings.waitForExistence(timeout: 5), "the \(tab) tab's \"…\" must offer Settings")
            settings.tap()

            let sheet = app.navigationBars["Settings"]
            XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Settings should present as a sheet from the \(tab) tab")
            if tab == "Plans" {
                // Existence before `isEnabled`, which is false for a missing row.
                let deletePlans = app.buttons["Delete All Sell Plans…"]
                XCTAssertTrue(deletePlans.exists, "Settings must offer Delete All Sell Plans")
                XCTAssertFalse(deletePlans.isEnabled, "Delete All Sell Plans must be dimmed with no plans")
            }
            app.buttons["Done"].tap()
            XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "Done should dismiss Settings on the \(tab) tab")
            XCTAssertTrue(badge.isHittable, "Done should return to the \(tab) tab's root")
        }
    }

    /// Criterion 22 on the seeded Plans collection (plan QA6): the Plans
    /// tab's "…" reaches Settings, whose Delete All Sell Plans asks first,
    /// naming all four plans — the three Active, the carried-over Fuji among
    /// them, and the one Completed. Keep changes nothing; Delete All empties
    /// both sides of the tab at once, and leaves everything else where a
    /// single delete leaves it — the wanted entries on the Wishlist, offering
    /// a new plan, the sales on the Sold side, the bought item owned — and
    /// the row dimmed.
    ///
    /// Its mutations: the Settings sheet's `onDismiss` reload dropped from
    /// `PlansView` must turn the empty-state leg red; `confirmDeleteAll`
    /// deleting the wanted entries instead of their plans must turn the
    /// Wishlist leg red.
    @MainActor
    func testDeletingAllSellPlansLeavesEverythingElse() {
        let app = launchPlans()
        app.buttons["Plans"].tap()

        let summicron = app.staticTexts["Summicron 35mm f/2"]
        XCTAssertTrue(summicron.waitForExistence(timeout: 5), "the seeded plans must be listed")

        let badge = app.buttons["moreActions.plans"]
        let sheet = app.navigationBars["Settings"]
        let deletePlans = app.buttons["Delete All Sell Plans…"]
        let alert = app.alerts["Delete all 4 sell plans?"]

        // Keep changes nothing.
        openSettings(from: badge, in: app)
        XCTAssertTrue(deletePlans.exists, "Settings must offer Delete All Sell Plans")
        XCTAssertTrue(deletePlans.isEnabled, "with plans stored, Delete All Sell Plans must be enabled")
        scrollUntilHittable(deletePlans, in: app)
        deletePlans.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Delete All Sell Plans must ask first, naming all four plans")
        alert.buttons["Keep"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "Keep must close the alert")
        app.buttons["Done"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "Done should dismiss Settings")
        XCTAssertTrue(summicron.waitForExistence(timeout: 5), "Keep must leave the plans listed")

        // Delete All empties both sides.
        openSettings(from: badge, in: app)
        scrollUntilHittable(deletePlans, in: app)
        deletePlans.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "the alert must ask again")
        alert.buttons["Delete All"].tap()
        // The delete commits in a task, and the busy gate dims the row as
        // soon as it starts — before the delete runs, so the dimming doesn't
        // prove it landed. Done can't race it anyway: the delete and the
        // Plans tab's reload run on the same main context.
        let dimmed = expectation(for: NSPredicate(format: "isEnabled == false"), evaluatedWith: deletePlans)
        XCTAssertEqual(XCTWaiter.wait(for: [dimmed], timeout: 5), .completed, "the row must dim once every plan is gone")
        app.buttons["Done"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "Done should dismiss Settings")

        XCTAssertTrue(
            app.staticTexts["No sell plans yet"].waitForExistence(timeout: 5),
            "the Active side must be empty as soon as Settings closes"
        )
        XCTAssertFalse(summicron.exists, "no plan may stay on Active")
        let switchControl = element(in: app, identifiedBy: "plans.sideSwitch")
        switchControl.buttons["Completed"].tap()
        XCTAssertTrue(
            app.staticTexts["Nothing completed yet"].waitForExistence(timeout: 5),
            "the Completed side must be empty too"
        )

        // The wanted entries stay, and offer a new plan.
        app.buttons["Wishlist"].tap()
        for name in ["Summicron 35mm f/2", "Vox AC15", "Fuji X100V"] {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), "\(name) must stay on the Wishlist")
        }
        openDetail(in: app, named: "Vox AC15")
        let createPlan = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Create a sell plan")).firstMatch
        XCTAssertTrue(createPlan.waitForExistence(timeout: 5), "the Vox AC15 has no plan now, so it offers a new one")

        // The sales and the bought item stay.
        app.buttons["Items"].tap()
        let itemsSwitch = element(in: app, identifiedBy: "items.sideSwitch")
        XCTAssertTrue(itemsSwitch.waitForExistence(timeout: 5))
        itemsSwitch.buttons["Sold"].tap()
        for name in ["Blues Junior", "NT1-A"] {
            XCTAssertTrue(soldRow(in: app, named: name).waitForExistence(timeout: 5), "the sale of the \(name) must stay")
        }
        itemsSwitch.buttons["Owned"].tap()
        // An owned row's `.combine`d element — see
        // `testMarkingAWantedItemBoughtMovesItToTheCollection`.
        let hasselblad = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Hasselblad 80mm,"))
            .firstMatch
        XCTAssertTrue(hasselblad.waitForExistence(timeout: 5), "the item the completed plan bought must stay owned")

        // And the row reads dimmed on a fresh visit.
        app.buttons["Plans"].tap()
        openSettings(from: badge, in: app)
        XCTAssertTrue(deletePlans.exists, "Settings must still offer Delete All Sell Plans")
        XCTAssertFalse(deletePlans.isEnabled, "with no plans left, Delete All Sell Plans must be dimmed")
        app.buttons["Done"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "Done should dismiss Settings")
    }

    /// The Plans tab's "…" → Settings, waiting for the sheet.
    @MainActor
    private func openSettings(from badge: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "the Plans tab must have a \"…\"")
        badge.tap()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "the \"…\" must offer Settings")
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), "Settings should present as a sheet")
    }

    /// Launches on the seeded Plans collection.
    @MainActor
    private func launchPlans() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedPlans"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        return app
    }

    /// A Plans row's `.combine`d element — its label is the name, the
    /// category and the count lines. Matched across every type, as the
    /// owned row is in `testMarkingAWantedItemBoughtMovesItToTheCollection`;
    /// the comma tells it from the plain name inside it.
    @MainActor
    private func planRow(in app: XCUIApplication, named name: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),"))
            .firstMatch
    }

    /// A price field's figure with any grouping separator stripped.
    @MainActor
    private func plainFigure(_ field: XCUIElement) -> String {
        (field.value as? String ?? "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
    }

    /// `openLeadingSwipe`'s mirror: a partial drag leftward from near the
    /// row's trailing edge, so the tray opens without the full swipe that
    /// would fire its edge action.
    @MainActor
    private func openTrailingSwipe(on row: XCUIElement, in app: XCUIApplication) {
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: -app.frame.width * 0.4, dy: 0))
        )
    }

    /// Opens a row's leading swipe tray with a **partial** drag across about
    /// 40 % of the row, pressed first so the gesture reads as a drag rather
    /// than a flick. Never `swipeRight()`, which travels far enough to fire
    /// the edge action instead of leaving the tray open — `014` T009's
    /// finding, and the reason the Items list's twin test drags this way too.
    /// The row spans the window, so the window's width is the row's.
    @MainActor
    private func openLeadingSwipe(on row: XCUIElement, in app: XCUIApplication) {
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        start.press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: app.frame.width * 0.4, dy: 0))
        )
    }
}

import Testing
@testable import Trove

/// 013's source scans — the shape `ExportWiringTests` and
/// `ImportWiringTests` established: what a unit test on a view model can't
/// see (that a view is wired to it, that the app forwards a value) is
/// pinned against the production source with comments stripped.
@Suite("Settings wiring")
struct SettingsWiringTests {
    private nonisolated static let settingsView = "Trove/Views/Settings/SettingsView.swift"
    private nonisolated static let settingsViewModel = "Trove/ViewModels/SettingsViewModel.swift"

    // MARK: - T012: the screen

    @Test func theShareSheetTakesTheWholeSetOffTheStagedExport() throws {
        let code = try SourceScan.production(Self.settingsView)
        #expect(code.contains(".sheet(item: $viewModel.stagedExport)"), "share sheet not wired to stagedExport")
        #expect(code.contains("ShareSheet(urls: staged.urls)"), "the share sheet must carry the whole set")
    }

    /// One alert modifier, off the single optional, with the view model's
    /// title and message — not three alerts on three booleans.
    @Test func exactlyOneAlertPresentsOffTheSinglePresentation() throws {
        let code = try SourceScan.production(Self.settingsView)
        #expect(code.ranges(of: ".alert(").count == 1, "Settings should present exactly one alert")
        #expect(code.contains("presenting: viewModel.alert"))
        #expect(code.contains("viewModel.alertTitle"))
        #expect(code.contains("viewModel.alertMessage"))
    }

    /// The T017 rule: the confirm button calls the intent plainly, with
    /// the target from the alert's presenting closure — never wrapped in a
    /// Task whose body would run after the dismissal write.
    @Test func theConfirmButtonCallsTheIntentPlainly() throws {
        let code = try SourceScan.production(Self.settingsView)
        #expect(code.contains("viewModel.confirmDeleteAll(target)"), "confirm doesn't hand the presented target to the intent")
        #expect(!code.contains("await viewModel.confirmDeleteAll"), "confirm is wrapped in a Task — the dismissal write will race it")
        #expect(code.contains("viewModel.cancelDeleteAll()"))
        #expect(code.contains("DeleteAllCopy.confirm"))
        #expect(code.contains("DeleteAllCopy.cancel"))
    }

    /// Spec P4: Done stays available while an action runs.
    @Test func doneIsNeverDisabled() throws {
        let code = try SourceScan.production(Self.settingsView)
        let toolbars = SourceScan.closureBodies(after: ".toolbar", in: code)
        try #require(toolbars.count == 1, "expected one toolbar block")
        #expect(toolbars[0].contains("Button(\"Done\")"), "the toolbar should carry Done")
        #expect(!toolbars[0].contains(".disabled("), "Done must never be disabled")
    }

    /// Checked where the sections are *composed* — the body's stack — not
    /// where their properties happen to be declared: the first version of
    /// this scan read declaration order and stayed green when the body's
    /// composition was swapped, the exact false-passing shape the
    /// constitution records. Caught by running the mutation, not by
    /// reading the test.
    @Test func theSectionsAppearInSpecOrder() throws {
        let code = try SourceScan.production(Self.settingsView)
        let stacks = SourceScan.closureBodies(
            after: "VStack(alignment: .leading, spacing: theme.metrics.sectionGap)",
            in: code
        )
        let body = try #require(stacks.first, "body's section stack not found")
        let sections = ["exportSection", "templatesSection", "marketSection", "iCloudSection", "deleteSection", "aboutSection"]
        let positions = try sections.map { name in
            try #require(body.range(of: name)?.lowerBound, "body doesn't compose \(name)")
        }
        #expect(positions == positions.sorted(), "sections composed out of spec order")
        for title in ["Export", "Templates", "iCloud", "Delete", "About"] {
            #expect(code.contains("DetailSection(title: \"\(title)\")"), "missing section \(title)")
        }
        // 002/Q12: the Market section sits between Templates and iCloud, and
        // its title is the copy constant, not a sixth typed literal.
        #expect(
            code.contains("DetailSection(title: MarketCopy.settingsSectionTitle)"),
            "the Market section doesn't read its title from MarketCopy"
        )
    }

    /// Criterion 18 rests on explicit hints — the role alone announces
    /// nothing outside alerts and menus. Pinned at both ends: the two
    /// call sites pass a hint, *and* the row applies it — the
    /// declaration-vs-composition family the section-order scan fell
    /// into, caught here by the pre-merge sweep instead.
    @Test func bothDeleteRowsCarryAnAccessibilityHintAndTheRowAppliesIt() throws {
        let code = try SourceScan.production(Self.settingsView)
        #expect(code.ranges(of: "isDestructive: true").count == 2, "expected exactly two destructive rows")
        #expect(code.ranges(of: "accessibilityHint: \"").count == 2, "both destructive rows must pass a hint")
        #expect(
            code.contains(".accessibilityHint(accessibilityHint"),
            "SettingsActionRow no longer applies the hint it's given"
        )
        #expect(
            code.contains(".accessibilityElement(children: .combine)"),
            "the iCloud block must read as one element"
        )
    }

    /// Criterion 14's view half: every action row disables while anything
    /// is busy, and each reads its own activity for the spinner. The view
    /// model's guard refuses a reentrant call regardless, so no unit test
    /// would notice these bindings going missing (the sweep's B1).
    @Test func everyActionRowGatesOnBusyAndReadsItsOwnActivity() throws {
        let code = try SourceScan.production(Self.settingsView)
        let rows = SourceScan.argumentLists(of: "SettingsActionRow", in: code)
        #expect(rows.count == 7, "expected seven action rows, found \(rows.count)")
        for row in rows {
            #expect(row.contains("!viewModel.isBusy"), "a row doesn't disable while busy: \(row.prefix(48))")
            #expect(
                row.contains("isActing: viewModel.activity == ."),
                "a row doesn't read its own activity: \(row.prefix(48))"
            )
        }
    }

    /// Criterion 17's "never typed": no literal that looks like a version
    /// in either Settings file — the About row reads the bundle.
    @Test func noVersionLiteralInTheSettingsFiles() throws {
        let looksLikeAVersion = try Regex(#"\d+\.\d+"#)
        for path in [Self.settingsView, Self.settingsViewModel] {
            let literals = SourceScan.stringLiterals(in: try SourceScan.production(path))
            let offenders = literals.filter { $0.firstMatch(of: looksLikeAVersion) != nil }
            #expect(offenders.isEmpty, "\(path) carries a version-shaped literal: \(offenders)")
        }
    }

    /// The third delete route reads the shared copy like the first two,
    /// and the failure alerts read 011's export copy rather than new words.
    @Test func theViewModelReadsTheSharedCopy() throws {
        let code = try SourceScan.production(Self.settingsViewModel)
        #expect(code.contains("DeleteAllCopy."))
        #expect(code.contains("ExportCopy.failureTitle"))
        #expect(code.contains("ExportCopy.failureMessage"))
        #expect(code.contains("SyncStatusCopy.status("))
    }

    // MARK: - 002/T014: the Market row and About

    /// The walk's row reads every string from `MarketCopy`, shows the
    /// progress through the row's new `detail:`, and reports its outcome as
    /// an inline status line — never a second alert (Q12; the single-alert
    /// scan above is the other half of that rule).
    @Test func theMarketRowIsWiredToTheWalkAndItsStatusLine() throws {
        let code = try SourceScan.production(Self.settingsView)
        let rows = SourceScan.argumentLists(of: "SettingsActionRow", in: code)
        let market = rows.filter { $0.contains("MarketCopy.refreshAll") }
        try #require(market.count == 1, "expected exactly one Refresh market values row")
        #expect(market[0].contains("MarketCopy.progress(done:"), "the row doesn't show the walk's progress")
        #expect(code.contains("await viewModel.refreshMarketValues()"), "the row doesn't run the walk")
        #expect(code.contains("viewModel.marketRefreshStatus"), "no status line under the row")
        #expect(code.contains("theme.colors.accentRustText"), "the status line isn't in the failure colour")
        #expect(code.contains("viewModel.marketRefreshNote"), "no nothing-due line under the row (Decision 38)")
        #expect(code.contains("theme.colors.textQuiet"), "the nothing-due line isn't in the quiet colour")
        #expect(code.contains("settings.refreshMarket"), "the row carries no identifier")
        #expect(
            code.contains("Text(detail)"),
            "SettingsActionRow no longer draws the detail it's given"
        )
    }

    /// Criterion 17's About half: Reverb's attribution and exactly two
    /// links — the contact address and the privacy policy. Counted with a
    /// non-identifier boundary so `NavigationLink(` could never stand in
    /// for one (the `MenuPolicyTests` regex).
    @Test func aboutCarriesTheAttributionAndExactlyTwoLinks() throws {
        let code = try SourceScan.production(Self.settingsView)
        let link = try Regex(#"(?:^|[^A-Za-z0-9_])Link\("#)
        let links = code.ranges(of: link).count
        #expect(links == 2, "expected two links in Settings, found \(links)")
        for symbol in [
            "MarketCopy.attribution",
            "MarketCopy.contactAddress",
            "MarketCopy.contactURL",
            "MarketCopy.privacyPolicyTitle",
            "MarketCopy.privacyPolicyURL",
        ] {
            #expect(code.contains(symbol), "About doesn't read \(symbol)")
        }
        #expect(code.contains("about.contact"))
        #expect(code.contains("about.privacy"))
    }

    /// Decisions 12, 18 and 25 keep the address, the policy URL and the
    /// source's name in `MarketCopy` — one place each. So the screen may
    /// carry no literal naming Reverb, and no URL or mailto of its own.
    @Test func theScreenTypesNoAddressURLOrSourceName() throws {
        let code = try SourceScan.production(Self.settingsView)
        let forbidden = ["reverb", "mailto", "http"]
        let offenders = SourceScan.stringLiterals(in: code).filter { literal in
            let lowered = literal.lowercased()
            return forbidden.contains { lowered.contains($0) }
        }
        #expect(offenders.isEmpty, "SettingsView types what MarketCopy owns: \(offenders)")
    }

    // MARK: - T013: the entry point

    private nonisolated static let lists = [
        "Trove/Views/Items/ItemListView.swift",
        "Trove/Views/Wishlist/WishlistView.swift",
    ]

    /// The three screens that reach Settings — both lists and, since 013
    /// Amendment A, the root Dashboard.
    private nonisolated static let settingsHosts = lists + ["Trove/Views/Dashboard/DashboardView.swift"]

    /// Every screen that opens Settings owns the sheet the way the lists
    /// own their form sheets — refetching on dismiss, so a Delete All
    /// behind it shows at once — and constructs the screen with everything
    /// it needs threaded in.
    @Test(arguments: settingsHosts)
    func theScreenAttachesTheSettingsSheetAndReloadsOnDismiss(path: String) throws {
        let code = try SourceScan.production(path)
        #expect(
            code.contains(".sheet(isPresented: $isShowingSettings, onDismiss: viewModel.load)"),
            "\(path) doesn't present Settings as a sheet that reloads on dismiss"
        )
        let calls = SourceScan.argumentLists(of: "SettingsView", in: code)
        #expect(calls.count == 1, "\(path) builds \(calls.count) SettingsViews, expected exactly 1")
        for call in calls {
            for argument in [
                "modelContext: modelContext",
                "syncMonitor: syncMonitor",
                "storageMode: storageMode",
                "storageFallbackReason: storageFallbackReason",
            ] {
                #expect(call.contains(argument), "\(path) doesn't pass \(argument) to Settings")
            }
        }
    }

    // MARK: - T005, T011
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
        #expect(
            bodies[0].ranges(of: "modelContext.save()").count == 1,
            "confirmDeleteAll must save exactly once — one save is what makes it all-or-nothing"
        )
        // The rollback belongs to the failure path and only there: pinned
        // by extracting the catch block rather than searching the whole
        // body (the sweep's S4 — `contains` alone would pass a rollback on
        // the success path, or two saves).
        let catches = SourceScan.closureBodies(after: "} catch", in: bodies[0])
        try #require(catches.count == 1, "expected exactly one catch block")
        #expect(catches[0].contains("modelContext.rollback()"), "the failure path must roll back the context")
        let outsideCatch = bodies[0].replacingOccurrences(of: catches[0], with: "")
        #expect(!outsideCatch.contains("rollback()"), "rollback belongs to the failure path only")
    }
}

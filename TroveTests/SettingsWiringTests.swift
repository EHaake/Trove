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
    /// nothing outside alerts and menus. Pinned at both ends: the three
    /// call sites pass a hint (the third, sell plans, from 009 Amendment A's
    /// G36 — an exact count, never `>=`), *and* the row applies it — the
    /// declaration-vs-composition family the section-order scan fell
    /// into, caught here by the pre-merge sweep instead.
    @Test func everyDeleteRowCarriesAnAccessibilityHintAndTheRowAppliesIt() throws {
        let code = try SourceScan.production(Self.settingsView)
        #expect(code.ranges(of: "isDestructive: true").count == 3, "expected exactly three destructive rows")
        #expect(code.ranges(of: "accessibilityHint: \"").count == 3, "every destructive row must pass a hint")
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
        #expect(rows.count == 8, "expected eight action rows, found \(rows.count)")
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

    /// The screens that reach Settings — both lists, since 013 Amendment A
    /// the root Dashboard, and since 009 Amendment A the Plans tab (G32).
    /// `everyTabsRootReachesSettings` holds every tab's root to membership.
    private nonisolated static let settingsHosts = lists + [
        "Trove/Views/Dashboard/DashboardView.swift",
        "Trove/Views/Plans/PlansView.swift",
    ]

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

    /// G32, criterion 21 (009 Amendment A, plan QA3): every tab's root screen
    /// has a way to Settings. The roots are derived from `ContentView`'s
    /// `Tab(` closures — the first `…View(` inside each — never from a list
    /// someone has to remember to extend, and there must be as many as
    /// `AppRouter.Tab.allCases`. Each root's file is found by its
    /// `struct <Name>: View` declaration, and must be a Settings host (so the
    /// sheet and threading tests above run over it), draw exactly one
    /// `OverflowBadge(` anchored as the `.overflow` dropdown, and host a
    /// dropdown that writes `isShowingSettings = true`. Which screen composes
    /// what is a view-body fact no view model can observe — the
    /// `MenuPolicyTests` shape; the behavioural half is the UI test that opens
    /// Settings from all four tabs.
    /// Mutations (T019): Plans' `OverflowBadge` removed → red; `PlansView`
    /// taken out of `settingsHosts` → red; the Plans tab's root swapped for
    /// `SellPlanView(…)` in `ContentView` → red.
    @Test func everyTabsRootReachesSettings() throws {
        let content = try SourceScan.production("Trove/App/ContentView.swift")
        let tabs = SourceScan.closureBodies(after: "Tab(", in: content)
        let rootCall = try Regex(#"(?:^|[^A-Za-z0-9_.])([A-Z][A-Za-z0-9_]*View)\("#, as: (Substring, Substring).self)
        let roots = tabs.compactMap { tab in tab.firstMatch(of: rootCall).map { String($0.output.1) } }
        try #require(
            roots.count == AppRouter.Tab.allCases.count,
            "found \(roots.count) tab roots in ContentView (\(roots)), expected \(AppRouter.Tab.allCases.count)"
        )

        let files = try SourceScan.swiftFiles(under: "Trove/Views", minimum: 40)
        for root in roots {
            let declaration = "struct \(root): View"
            let matches = try files.filter { try SourceScan.production($0).contains(declaration) }
            try #require(matches.count == 1, "expected one file declaring `\(declaration)`, found \(matches)")
            let path = matches[0]
            let code = try SourceScan.production(path)

            #expect(Self.settingsHosts.contains(path), "\(root) is a tab's root but not a Settings host (\(path))")
            #expect(
                code.ranges(of: "OverflowBadge(").count == 1,
                "\(root) draws \(code.ranges(of: "OverflowBadge(").count) \"…\" badges, expected exactly 1"
            )
            // The Items badge carries its export choosers' anchors too, so
            // the `.overflow` one is looked for among them.
            let overflow = SourceScan.closureBodies(after: "private var overflowControl: some View", in: code)
            #expect(overflow.first?.contains("OverflowBadge(") == true, "\(root)'s overflowControl draws no \"…\" badge")
            let anchors = overflow.first.map { SourceScan.argumentLists(of: ".dropdownAnchor", in: $0) } ?? []
            #expect(
                anchors.contains { $0.hasSuffix("Dropdown.overflow") },
                "\(root)'s \"…\" isn't anchored as its `.overflow` dropdown: \(anchors)"
            )
            let hosts = SourceScan.closureBodies(after: ".dropdownHost(", in: code)
            #expect(hosts.count == 1, "\(root) has \(hosts.count) dropdown hosts, expected exactly 1")
            #expect(
                hosts.first?.contains("isShowingSettings = true") == true,
                "\(root)'s dropdown host never opens Settings"
            )
        }
    }

    // MARK: - 004/T004: the appearance control and its threading

    /// G10a: every host reads the appearance store from the environment and
    /// threads it into `SettingsView` — the `syncMonitor` delivery shape, so
    /// the sheet never reads an observable it might not have.
    /// Mutation: drop `appearanceStore: appearanceStore` from a host's
    /// `SettingsView(...)` → the arg expectation fires; drop the
    /// `@Environment(AppearanceStore.self)` read → the read expectation fires.
    @Test(arguments: settingsHosts)
    func eachHostThreadsTheAppearanceStoreIntoSettings(path: String) throws {
        let code = try SourceScan.production(path)
        #expect(
            code.contains("@Environment(AppearanceStore.self)"),
            "\(path) doesn't read the appearance store from the environment"
        )
        let calls = SourceScan.argumentLists(of: "SettingsView", in: code)
        #expect(calls.count == 1, "\(path) builds \(calls.count) SettingsViews, expected exactly 1")
        for call in calls {
            #expect(
                call.contains("appearanceStore: appearanceStore"),
                "\(path) doesn't pass appearanceStore to Settings"
            )
        }
    }

    /// G10b: the Appearance section is composed **first** in the body's
    /// section stack — checked at composition, not declaration (the
    /// `theSectionsAppearInSpecOrder` shape) — and its control is a
    /// `.segmented` `Picker` bound to `$appearanceStore.choice` over
    /// `AppearanceChoice.allCases`, labelled from `displayName`. The copy
    /// lives on the model: no typed "System"/"Light"/"Dark" in the view.
    /// Mutation: move `appearanceSection` out of first position → the order
    /// expectation fires; `.pickerStyle(.menu)` → `MenuPolicyTests` red.
    @Test func theAppearanceSectionLeadsAsASegmentedPickerOverTheChoice() throws {
        let code = try SourceScan.production(Self.settingsView)
        let stacks = SourceScan.closureBodies(
            after: "VStack(alignment: .leading, spacing: theme.metrics.sectionGap)",
            in: code
        )
        let body = try #require(stacks.first, "body's section stack not found")
        let sections = ["appearanceSection", "exportSection", "templatesSection", "marketSection", "iCloudSection", "deleteSection", "aboutSection"]
        let positions = try sections.map { name in
            try #require(body.range(of: name)?.lowerBound, "body doesn't compose \(name)")
        }
        #expect(positions == positions.sorted(), "sections composed out of spec order — Appearance must lead")
        #expect(code.contains("DetailSection(title: \"Appearance\")"), "missing the Appearance section")

        let pickers = SourceScan.argumentLists(of: "Picker", in: code)
        #expect(pickers.count == 1, "expected exactly one Picker in Settings, found \(pickers.count)")
        #expect(code.contains("selection: $appearanceStore.choice"), "the picker isn't bound to the store's choice")
        #expect(code.contains("AppearanceChoice.allCases"), "the picker doesn't iterate every case")
        #expect(code.contains(".pickerStyle(.segmented)"), "the appearance picker isn't segmented")
        #expect(code.contains(".displayName"), "the picker labels don't read displayName")

        let literals = SourceScan.stringLiterals(in: code)
        for word in ["System", "Light", "Dark"] {
            #expect(
                !literals.contains { $0.contains(word) },
                "SettingsView types the appearance copy \"\(word)\" — it belongs on AppearanceChoice.displayName"
            )
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

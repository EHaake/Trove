# 018 — System Design Language: Tasks

**Status**: **Signed off** (2026-09-24) — drafted by the `sdd-planner`, reviewed by the `skeptical-reviewer` (two blocking findings, B1 and B2, fixed and re-reviewed the same day: signed off). Final for the implementation session.

Drafted against the approved `spec.md` (Approved 2026-09-24) and the draft
`plan.md` in this directory, for branch `018-system-design-language` off
`main` (`0d6c28a`). No new technical decisions are made here — every call
below traces to a plan section; where a task says "per plan," that section is
the authority. Runs under `CLAUDE.md`'s model policy, **Opus profile**
(reconciled 2026-09-24): the `sdd-planner`, the `skeptical-reviewer` (sign-off,
per-phase, per-task, decision reviews, pre-merge sweep), the `sdd-implementer`
(tasks and close-out) and the `general-purpose` device-pass agent all run at
`opus`, their definitions' default, so **no dispatch carries a model
override**; the session runs at `claude-opus-5-5` medium; the plan-and-tasks
draft ran at the implementation tier, no override (trial from 2026-09-24,
started with this spec). Involvement level: **product owner** — the person
attests by using the app at the pauses and decides escalations; technical
sign-off is the `skeptical-reviewer`'s.

**Foundational phase**: **Phase 1** (T001–T004) — `SortMenu`, the shared
control three screens' Sort By is built on, and the measurement the whole
spec is gated on (criterion 1: the tear filmed before any other surface is
converted, P4's fallback if it shows, a stop for the person if it survives
that). Phases 2 and 3 convert the remaining controls over it; Phase 4 deletes
what nothing calls and rewrites the policy; Phase 5 is verification.
**Tasks marked `review: per-task`**: **T001** only — `SortMenu` is inherited
by three screens and is the thing T002 films; a wrong component (not a real
system `Menu` over a `Picker`, a colour of its own, the wrong control size)
reviewed only at the phase end would have been measured and copied twice
first. Every other task gets the default one review per phase.

**Walkthrough marks and the pause cadence.** Phases 1, 2 and 3 are marked
`walkthrough: yes` — each changes controls the person uses — so each ends in a
pause. Phase 4 is `walkthrough: none` (it deletes code nothing calls, rewords one
`CLAUDE.md` example in its own commit, rewrites a test and edits two
documents; nothing on screen changes) and runs on after
its review. Phase 5 pauses only for the person's own steps and the merge.
**Phase 1 can also stop early**: if T003's re-film still shows the tear, the
work pauses on a product question with the films (spec, Inherited caveats),
not a walkthrough.

Ordering note: criterion 1 puts the Items sort first and alone, filmed before
anything else moves; the other two Sort Bys follow in the same phase, so the
phase ends with one sort control everywhere. Then every "…" (one component,
four screens, one task — the guards that span the tab roots can only be
rewritten once all four move) and the Dashboard's order menu, which frees the
last dropdown host. Then the two switches and the add button, filmed. Only
then is the bespoke code deleted and the policy inverted, so the inverted
guard's positive half is green the moment it lands.

House rules carried over: one commit per completed task, referencing its ID;
every guard **mutation-verified** before it lands, the Done note recording
what was broken and what went red; a task is not done until
`scripts/verify.sh` is green and its actual output is reported (suite-level
selectors, count checked — per-function Swift Testing selectors run zero
tests; XCTest per-function selectors **do** work for single UI tests); every
new or rewritten source scan **`#require`s its anchor** and compares whole
literals; never write the literal `#Preview` inside a doc comment in a
scanned file (`SourceScan.production` truncates there); never revert a
mutation with `git checkout --` on a file carrying uncommitted work. **UI
tests move with their controls**: a task that changes what a UI test drives
rewrites that test and runs it alone; the whole UI suite runs at each phase's
final commit. New files land in synchronized folders — **no `.pbxproj`
edit**; if the build cannot see one, stop and flag. **No test opens a network
connection.** **Tests retired** are listed below by name (criterion 13) — a
task deletes only what the table assigns it.

Cadence: each dispatch gets a **task bundle** assembled with shell — task line,
plan section, acceptance criteria, files, pattern file — and the implementer
is told not to read `plan.md`/`spec.md`/`tasks.md` in full; verification is
`scripts/verify.sh` and nothing more verbose, re-run by the orchestrator for
T001 and taken from the implementer's verbatim output otherwise; reviews on a
bundle cut after `git add -A`, one review and at most one re-review; **one
implementation session for the whole spec**; films and the device pass in a
`general-purpose` agent (the `sdd-implementer` has no simulator tools), one
dispatch per checklist section; never start a verification run while an
agent holds the simulator. Everything the person reads is plain language.

### Tests retired (criteria 9, 12, 13)

| Test | The control whose removal made it moot | Task |
|---|---|---|
| `TroveUITests.testAnOpenMenuClosesOnAnyOutsideTapIncludingTheOtherBadge` | the dropdown host's tap-outside layer and its two-tap rule (P5) | T001 |
| `DropdownWiringTests.eachListHostsItsDropdownsOffOneOptional` | each list's dropdown host and `openDropdown` state (its sort legs narrowed at T001/T004 as each sort leaves the host) | T005 |
| `DropdownWiringTests.theDashboardAnchorsItsBadgeOnTheRootAloneAndComposesSettings` | the Dashboard's host and anchor — the root-only rule survives as G5 | T005 |
| `ExportWiringTests.theScopeChooserHeadersReadAsTheSpecWritesThem` | the export chooser's "EXPORT AS CSV/PDF" headers (`ExportCopy.scopeTitleCSV/PDF`, plan Q12) | T005 |
| `DropdownWiringTests.theDashboardOrderControlOpensTheSharedSurfaceUnderOrderBy` | the Dashboard's order dropdown — the order control's wiring survives as G5 | T006 |
| `ItemListSidesWiringTests.theSwitchesSlideIsAtOrUnderTwoTenthsOfASecond` | the bespoke switch's own slide animation (the system's slide is filmed, G14b) | T007 |
| `ItemListSidesWiringTests.theSwitchesFillIsOneMovingRectangle` | the bespoke switch's brass fill | T007 |
| `PlansWiringTests.everyLabelOfBothSwitchesFitsItsHalf` (`009` G18) | the switch's fixed halves (P7) | T007 |
| `DropdownWiringTests` — the file, with what remains: `everyRowDismissesBeforeItActs`, `aDisabledRowIsInertAndDimmed`, `theSurfaceMarksItsFirstRowWhichTakesFocusAndClosesOnEscape`, `everyBadgeCarriesItsHintAndIdentifier` (its `OverflowBadge.swift` legs; the per-screen identifier legs move to G3 at T001–T006), `theBadgeShowsTheSpinnerAndDisablesWhileBusy` (→ G4 at T005), `sortByComposesTheSharedSurface`, `theOverflowDropdownIsHeaderlessOnTheSharedSurface`, `theHostInjectsDismissAndContainsVoiceOver` | `DropdownSurface`, `DropdownRow`, `OverflowBadge`, `SortDropdown`, `OverflowDropdown`, `DropdownHost` | T010 |
| `DropdownAnchorTests` — `threeTagsOnOneViewAllReachTheReader`, `aSiblingBadgesTagMergesWithTheStackedThree` | `dropdownAnchor` | T010 |
| `DropdownPlacementTests` — `hangsBelowTheBadgeAtTheTrailingGutterWhenThereIsRoom`, `theTrailingEdgeIsTheGuttersNotTheBadges`, `flipsAboveWhenBelowWouldRunPastTheBottom`, `touchingTheBottomStillHangsBelow`, `pinsToTheTopWhenNeitherDirectionFits`, `neverPastTheLeadingGutter`, `theSortBySurfaceIsTheSizeThisSuiteMeasuresAgainst`, `growsFromTheBadgesTrailingEdge`, `measuresFromTheRegionsOwnOrigin` | `DropdownPlacement` and the grow-from-badge animation | T010 |
| `OverflowDropdownRenderTests` — `theTwoGroupBreaksReadStrongerThanTheRowSeparator`, `theExportRowsDimWhenThereIsNothingToExport`, `eachExportRowDimsOnItsOwnGate` | the overflow dropdown's drawn hairlines and dimming | T010 |

**Rewritten, not retired** (each Done note records the mutation the rewrite
catches): `MenuPolicyTests.theOnlySystemMenuIsTheDetailScreensNavBarOverflow`
(→ G12, T011); `ItemListHeaderLayoutTests` (G1, T001/T005);
`ItemListSidesWiringTests.oneNarrowingGateCoversBothSidesAndEachSideBringsItsOwnSort`
(G6, T001), `theSwitchReportsThroughShowAndBindsToNothing`,
`theSwitchStandsOutsideTheEmptyState`, `theSwitchIsLabelledAndMarksItsActiveHalfSelected`
(G10, T007); `PlansWiringTests.noSortDropdownOffersAManualOrder` (G7, T004),
`theSideSwitchReportsThroughShow` (G10, T007);
`ExportWiringTests.theBadgeOpensTheDropdownWhichFiresEveryIntentAndOpensSettings`,
`theMenuCarriesFiveItemsInThreeGroups`,
`theItemsListComposesTheScopeChooserOverEveryScope` (G8, T005);
`SettingsWiringTests.everyTabsRootReachesSettings` (G9, T005); the UI tests
plan §9 lists.

Handoff notes for the pause reports:

- **Phase 1 — what can be tried**: on the Items tab, the Wishlist and the
  Plans tab, Sort By is a frosted glass capsule. Tapping it opens the iPhone's
  own menu: "Sort by" at the top, the current order ticked. On Items (the
  Owned side) and on the Wishlist, the Custom row reads "Drag rows to reorder"
  underneath — visible now whether or not Custom is chosen. Choosing a row
  re-sorts the list and renames the capsule. Say plainly what the film found
  (whether the capsule stayed whole through a switch from the shortest label
  to the longest, on both iOS versions) and whether the fallback was needed —
  if it was, the capsule is now as wide as its longest option all the time.
  The "…" beside it is still the old one until the next phase. Put as a
  question, not a fact: the capsule's words and bars are drawn in whatever
  colour the system gives a glass button (brass only if the system applies
  the app's tint), and the device check says which it is.
- **Phase 2 — what can be tried**: every tab's "…" opens the iPhone's own
  menu. Overview and Plans: Settings alone. Wishlist: Export as CSV…, Export
  as PDF…, Import from CSV…, Settings, with separators between the three
  groups, the exports greyed with nothing on the list. Items: the same, but
  Export as CSV and Export as PDF (no "…" on those two now) each open a
  second level offering Owned items, Sold items, Owned and sold — on the Sold
  side with a category chip on, the scopes with nothing to export are greyed.
  An export shows a spinner in the "…" and then the share sheet, as before.
  On the Overview, "BY VALUE" opens the same kind of menu headed "Order by".
  Opening Sort By while the "…" is open now takes one tap, which is the
  iPhone's own rule. Put as a question: the order label stays plain text,
  with no glass, because it sits inside the category card.
- **Phase 3 — what can be tried**: Owned/Sold on Items and Active/Completed on
  Plans are the iPhone's own segmented control — the selection is a glass
  pill that slides; the film says whether the header above held still. The
  add button on Items and the Wishlist is a brass glass disc in the same
  corner, the same size, opening the same form. **Every screen, in both Light
  and Dark, should now read as one language** — a "…" in a header, a "…" on
  an item's page and the tab bar all open the same glass. Say too that the
  Sort By capsule was filmed again on this finished header and whether it
  stayed whole. Put as questions: the switch is only as wide as its two
  words, not the full width; tapping the side already showing no longer
  refreshes it (pull down to refresh still does); the Wishlist's add button
  still says "Add wanted item" to VoiceOver.

## Phase 1 — Sort By, measured first (**foundational**) · walkthrough: yes — on the Items tab (both sides), the Wishlist and the Plans tab (both sides), Sort By is a glass capsule opening the system menu under "Sort by" with the current order ticked; on Items' Owned side and the Wishlist the Custom row reads "Drag rows to reorder"; choosing a row re-sorts and renames the capsule; the film of the capsule through a width-changing sort is in the report

- [ ] **T001 — `SortMenu`, and Items' Sort By on it. `review: per-task`.**
  Per plan §1, Q1, Q6, Q8, Q11. New `Trove/Views/Shared/SortMenu.swift`:
  `SortMenuCopy` (`header`, `reorderSubtitle`) and `SortMenu<Option:
  Hashable>` exactly as plan §1 declares it — a system `Menu` over an inline
  `Picker` bound through `select`, one "Sort by" header (Q8's mechanism),
  the `manualOrder` option's row carrying the subtitle, the glyph and mono
  label with **no colour of their own**, `.buttonStyle(.glass)`. **Control
  size per Q6**: a scratch render (`TroveTests/ZZScratch…`, deleted before
  the commit) of the badge at `.regular` and `.small` beside the Items
  title; ship the largest that keeps G38's no-badges proviso; record both
  heights in the Done note. `ItemListView`: `sortControl` becomes plan §1's
  per-side pair, keeping its `accessibilityLabel` and identifier and losing
  its hint; `HeaderDropdown.sort`, the host's `case .sort:` and
  `.dropdownAnchor(HeaderDropdown.sort)` go (the host keeps `.overflow` and
  `.exportScope` until T005). `MenuPolicyTests`' allowlist gains
  `"SortMenu.swift"` (Q11). Pattern: `SortPicker.swift` (the glyph's token
  widths, the label's font); `DetailOverflowMenu.swift` (the app's existing
  system `Menu`); `SettingsView.swift:124–132` (a `Picker` over a
  selection); `ItemListHeaderLayoutTests.headerHeight` (the scratch render).
  Tests: new `TroveTests/HeaderControlsWiringTests.swift` — **G2** (mutations:
  the `Picker` replaced by a `ForEach` of `Button`s → red;
  `.foregroundStyle(theme.colors.accentBrass)` on the label → red) and **G3**'s
  first leg (`sortOptions.items` present on `sortControl`, no
  `.accessibilityHint` there; mutation: the identifier dropped → red). **G6**:
  rewrite `ItemListSidesWiringTests.oneNarrowingGateCoversBothSidesAndEachSideBringsItsOwnSort`'s
  host legs onto `sortControl` per plan §11 (mutations: `manualOrder:` on the
  Sold menu → red; the Sold menu writing `viewModel.sortOrder` → red; the
  gate mutations it already records, re-run). **G1**: `ItemListHeaderLayoutTests`
  renders `SortMenu` in the trailing slot beside the still-current
  `OverflowBadge`, and `widestLabel(of:)` renders a one-option `SortMenu` per
  label; its three recorded mutations re-run. `DropdownWiringTests`:
  `everyBadgeCarriesItsHintAndIdentifier` loses the Items sort legs;
  `eachListHostsItsDropdownsOffOneOptional`'s two sort legs apply to the
  Wishlist only (T004 removes them). `TroveUITests`: `assertMarketSortRows`
  rewritten to the system menu (one "Sort by", closed by one outside-tap
  helper, plan §9) — the Wishlist leg of `testTheSortMenuOffersMarketRows` is
  red until T004, **said in the Done note**;
  `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch` reads "Sort by";
  `testAnOpenMenuClosesOnAnyOutsideTapIncludingTheOtherBadge` deleted (the
  retirement table).
  Files: `Trove/Views/Shared/SortMenu.swift` (new),
  `Trove/Views/Items/ItemListView.swift`,
  `TroveTests/HeaderControlsWiringTests.swift` (new),
  `TroveTests/ItemListSidesWiringTests.swift`,
  `TroveTests/ItemListHeaderLayoutTests.swift`,
  `TroveTests/DropdownWiringTests.swift`, `TroveTests/MenuPolicyTests.swift`
  (allowlist only), `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs);
  `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch` and
  `testTheSoldCardLandsOnTheSoldSideWhichListsSalesMostRecentFirst` green run
  alone; both control-size heights and every mutation recorded.

- [ ] **T002 — The tear, filmed. [`general-purpose` agent with simulator tools]**
  Per plan §1 (the definition of "whole on every frame"), R7, Q8, Q14;
  criterion 1's first measurement. At T001's commit, the build path from
  `-showBuildSettings` and the installed binary's mtime checked; iOS 27.0 and
  26.5 simulators, `-uiTesting -seedSold` (if no 26.5 runtime is installed,
  record that and film on 27.0 alone). Extend
  `scripts/motion-probe/profile.swift` with a background-difference mode
  (plan Q14) and document it in the README. Drive with a **temporary**
  XCUITest (never committed) while `simctl io recordVideo` runs: Items, Owned
  — Date → the widest Owned label (G1 measures which) → Date; Sold — Name →
  Date sold; the test also prints `sortOptions.items`' frame. For every frame
  from each tap to the settled label, report whether the capsule's span at
  the mid-line is one contiguous run containing every label column, with Δt.
  Also, in Light and Dark: a screenshot of the open menu — exactly one "Sort
  by", Date ticked, "Drag rows to reorder" under Custom (Q8) — and the badge's
  frame height against T001's recorded render height (plan §1's claim).
  Remove the temporary test; the tree byte-identical to T001's but for the
  probe script and README. **If the menu has no subtitle under Custom or two
  headers, report it — the orchestrator takes Q8's stop to a decision review
  before T003/T004.** **If the device's badge height is more than a point off
  T001's render, report it — the orchestrator sends T001's control-size choice
  back to T001's implementer to be re-made from the device's height before
  T004 and T005 copy it (plan Q6).** The probe extension is this agent's
  because it can only be tested against film (tier log).
  Files: `scripts/motion-probe/profile.swift`, `scripts/motion-probe/README.md`.
  **Verify:** the frame table per runtime and per switch in the Done note, a
  verdict for each (whole on every frame, or the frames that tear), the
  screenshots' findings, the two heights. If every switch is whole, T003 is
  ticked "not needed" with the film's numbers.

- [ ] **T003 — (Only if T002 shows the tear) P4's constant footprint, re-filmed.**
  Per plan §1, P4. `SortMenu`'s label reserves the widest of its menu's
  options (the hidden-labels `ZStack` of plan §1). Tests: **G1** gains "one
  width for every selection" — a `SortMenu` rendered once per selected option
  over one option set, every width equal (mutation: the hidden labels
  removed → red). Then a `general-purpose` re-film exactly as T002's. **If
  the tear survives, stop**: the orchestrator takes both films to the person
  as a product question (spec, Inherited caveats) and nothing else is
  dispatched until they answer.
  Files: `Trove/Views/Shared/SortMenu.swift`,
  `TroveTests/ItemListHeaderLayoutTests.swift`.
  Pattern: T029c's interim constant-footprint label
  (`specs/010-item-management-enhancements/tasks.md`, T029c).
  **Verify:** `scripts/verify.sh` green; the mutation recorded; the re-film's
  frame table whole on every frame, both runtimes.

- [ ] **T004 — Sort By on the Wishlist and Plans; the sort menus' UI test.**
  Per plan §1, §9. `WishlistView.sortControl`: one `SortMenu` over
  `WishlistViewModel.SortOrder.allCases`, `manualOrder: .custom`, `select`
  writing as the dropdown row did. `PlansView.sortControl`: one per side, no
  `manualOrder`, `select` calling `setActiveSort` / `setCompletedSort`. Both
  keep their labels and identifiers and lose their hints; each screen's
  `HeaderDropdown.sort`, host `case .sort:` and sort anchor go (the hosts keep
  `.overflow` until T005). Pattern: T001's `ItemListView.sortControl`;
  `PlansView`'s current host `case .sort:` for which intent each side calls.
  Tests: **G7** — `PlansWiringTests.noSortDropdownOffersAManualOrder` →
  `noSortMenuOffersAManualOrder` (mutation: `manualOrder: .newest` on one →
  red); **G3** legs for `sortOptions.wishlist` and `sortOptions.plans`;
  `DropdownWiringTests.everyBadgeCarriesItsHintAndIdentifier` loses the
  Wishlist and Plans sort legs, `eachListHostsItsDropdownsOffOneOptional` its
  remaining sort legs. `TroveUITests`:
  `testSortingEachSideReordersTheRowsAndIsKeptAcrossASwitch` reads "Sort by";
  `testTheSortMenuOffersMarketRows` green on both legs; new
  `testEverySortMenuOffersItsOrdersUnderSortByWithTheCurrentOneChecked`
  (`-uiTesting -seedPlans`, plan §9 — records whether XCUITest exposes the
  tick as `isSelected` and how it exposes the subtitle; mutations:
  `manualOrder: .newest` on a Plans menu → red; the subtitle `Text` removed
  from `SortMenu` → red).
  Files: `Trove/Views/Wishlist/WishlistView.swift`,
  `Trove/Views/Plans/PlansView.swift`, `TroveTests/PlansWiringTests.swift`,
  `TroveTests/HeaderControlsWiringTests.swift`,
  `TroveTests/DropdownWiringTests.swift`, `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green at the
  phase's final commit, count recorded; mutations recorded.
  **Phase 1 closes here — pause for the person** (what to try is in the
  handoff note above).

## Phase 2 — Every header menu is the system's · walkthrough: yes — each tab's "…" opens the system menu: Settings alone on the Overview and Plans; Export as CSV…, Export as PDF…, Import from CSV…, Settings in three groups on the Wishlist; on Items the two exports (no ellipsis) open submenus of Owned items, Sold items, Owned and sold, greyed where a scope has nothing on screen; an export shows the spinner then the share sheet; the Overview's "BY VALUE" opens a menu headed "Order by"

- [ ] **T005 — `OverflowMenu`, and every "…" on it.**
  Per plan §2, Q2, Q9, Q11, Q12. New `Trove/Views/Shared/OverflowMenu.swift`
  exactly as plan §2 declares it, at `SortMenu`'s control size. The four
  `overflowControl`s become `OverflowMenu(isBusy: …) { rows }` with plan §2's
  table of rows and their unchanged `moreActions.*` identifiers; Items gains
  `exportMenu(_:)` (Q9). **Items, Wishlist and Plans lose their dropdown
  host**: `HeaderDropdown`, `@State openDropdown`, `.dropdownHost(…)`, every
  `.dropdownAnchor(…)`. The Dashboard's host loses its `.overflow` case (it
  keeps `.order` until T006). `ExportCopy.scopeTitleCSV`/`scopeTitlePDF`
  deleted (Q12). `MenuPolicyTests`' allowlist gains `"OverflowMenu.swift"`
  and `"ItemListView.swift"` (its submenus are `Menu(`). Pattern: T001's
  `SortMenu` (the glass `Menu`, the control size); `OverflowBadge.swift` (the
  busy branch, the label's two states, the glyph's frame); the pre-`013`
  system menu's `Divider()` groups as `ExportWiringTests`' comment records.
  Tests: **G4** in `HeaderControlsWiringTests` (mutations: `.disabled(isBusy)`
  removed → red; `isBusy: false` on Items → red); **G3** legs for the four
  `moreActions.*`; **G5**'s first leg — the Dashboard's "…" inside exactly
  one `if isRoot` span (mutation: moved outside → red). **G1** renders
  `OverflowMenu` and gains "the two badges render at one height" (mutation:
  `OverflowMenu` at another control size → red). **G8** — rewrite
  `ExportWiringTests`' three tests per plan §11 (mutations: the PDF row gated
  on the CSV flag → red; a submenu exporting `.both` directly → red; Import
  gated → red; "Export as CSV…" on Items → red). **G9** — rewrite
  `SettingsWiringTests.everyTabsRootReachesSettings` (mutations: Plans'
  `OverflowMenu` replaced by a `Button` → red; Plans' Settings row removed →
  red). Retire per the table: `DropdownWiringTests.eachListHostsItsDropdownsOffOneOptional`,
  `theDashboardAnchorsItsBadgeOnTheRootAloneAndComposesSettings`,
  `ExportWiringTests.theScopeChooserHeadersReadAsTheSpecWritesThem`;
  `everyBadgeCarriesItsHintAndIdentifier` loses its per-screen overflow legs.
  `TroveUITests`: `testEmptyCollectionOffersImportAndSettingsButNotExport`
  (Items' two rows without the ellipsis; a Wishlist leg added, its rows
  keeping theirs); `testTheExportRowsOpenAScopeChooserGatedByWhatIsOnScreen` →
  `testTheExportRowsAreSubmenusGatedByWhatIsOnScreen` (mutation: scope rows
  gated on `canExportCSV` → the Owned items leg red).
  Files: `Trove/Views/Shared/OverflowMenu.swift` (new),
  `Trove/Views/Items/ItemListView.swift`, `Trove/Views/Wishlist/WishlistView.swift`,
  `Trove/Views/Plans/PlansView.swift`, `Trove/Views/Dashboard/DashboardView.swift`,
  `Trove/Export/ExportService.swift` (two strings out),
  `TroveTests/HeaderControlsWiringTests.swift`,
  `TroveTests/ItemListHeaderLayoutTests.swift`, `TroveTests/ExportWiringTests.swift`,
  `TroveTests/SettingsWiringTests.swift`, `TroveTests/DropdownWiringTests.swift`,
  `TroveTests/MenuPolicyTests.swift` (allowlist only), `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; the two rewritten UI tests,
  `testDashboardOffersSettingsAndNothingElse` and
  `testEveryTabsRootReachesSettings` green run alone; mutations recorded.

- [ ] **T006 — The Dashboard's order menu.**
  Per plan §3, R5. `orderControl` per plan §3 — a system `Menu` over an inline
  `Picker` under "Order by" (T001's header mechanism), the mono label in
  `textQuiet`, no glass, the label and identifier kept, the hint gone. The
  Dashboard's host goes: `DashboardDropdown`, `openDropdown`, `.dropdownHost`.
  `MenuPolicyTests`' allowlist gains `"DashboardView.swift"`. Pattern: T001's
  `SortMenu` body (the picker and its header); the current `orderControl`
  (label, spoken label, identifier). Tests: **G5**'s order legs (mutations:
  `viewModel.load()` dropped from the setter → red; `.buttonStyle(.glass)` on
  the label → red) and **G3**'s `orderOptions.dashboard` leg. Retire
  `DropdownWiringTests.theDashboardOrderControlOpensTheSharedSurfaceUnderOrderBy`;
  `everyBadgeCarriesItsHintAndIdentifier` loses its Dashboard legs.
  `TroveUITests`: new `testTheOverviewsOrderMenuOffersValueAndCountUnderOrderBy`
  (`-uiTesting -seedPlans`: one "Order by", By value selected, By count
  chosen → the control reads "Order categories By count"; mutation: the
  setter not writing → red).
  Files: `Trove/Views/Dashboard/DashboardView.swift`,
  `TroveTests/HeaderControlsWiringTests.swift`, `TroveTests/DropdownWiringTests.swift`,
  `TroveTests/MenuPolicyTests.swift` (allowlist only), `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green at the
  phase's final commit, count recorded; mutations recorded.
  **Phase 2 closes here — pause for the person.**

## Phase 3 — The two switches and the add button · walkthrough: yes — Owned/Sold and Active/Completed are the system segmented control whose glass selection slides while the header holds still, and Sort By's capsule stays whole through a width-changing sort on the finished header (both films are in the report); the add button on Items and the Wishlist is a brass glass disc in the same corner and size, opening the same form; every screen in Light and Dark reads as one language (criterion 15)

- [ ] **T007 — `SidePicker`, and both switches on it.**
  Per plan §4, Q3, R1, R2. New `Trove/Views/Shared/SidePicker.swift` exactly
  as plan §4 declares it, with the two constrained `init(side:select:)`s
  carrying `SideSwitch`'s words, labels and identifiers unchanged;
  `Trove/Views/Items/SideSwitch.swift` deleted. The two call sites change one
  word. Comments naming `SideSwitch` corrected (`ItemListView.swift` ~122–129
  and ~646, `PlansView.swift` ~79–83, `SaleCopyTests.swift` ~110). Pattern:
  `SideSwitch.swift` (the constrained initializers, the doc comment's "never
  writes the side"); `SettingsView.swift:124–132` (the one segmented
  `Picker`). Tests: **G10** — rewrite `ItemListSidesWiringTests.theSwitchReportsThroughShowAndBindsToNothing`,
  `theSwitchStandsOutsideTheEmptyState`, and `theSwitchIsLabelledAndMarksItsActiveHalfSelected`
  → `theSwitchIsTheSystemSegmentedControlReportingThroughSelect`, and
  `PlansWiringTests.theSideSwitchReportsThroughShow` (mutations:
  `.pickerStyle(.menu)` → red; the binding's setter `{ _ in }` → red;
  `$viewModel.side` at a call site → red; the call moved into the empty-state
  branch → red). Retire per the table: `theSwitchesSlideIsAtOrUnderTwoTenthsOfASecond`,
  `theSwitchesFillIsOneMovingRectangle`, `everyLabelOfBothSwitchesFitsItsHalf`.
  `TroveUITests`: the four switch reads (~1058, ~2073, ~2110, ~2285) from
  `.value` to `.buttons[…].isSelected`; `testAppearanceControlDefaultsToDarkAndOffersThreeChoices`
  finds the control containing a "System" segment (plan §9).
  Files: `Trove/Views/Shared/SidePicker.swift` (new),
  `Trove/Views/Items/SideSwitch.swift` (deleted), `Trove/Views/Items/ItemListView.swift`,
  `Trove/Views/Plans/PlansView.swift`, `TroveTests/ItemListSidesWiringTests.swift`,
  `TroveTests/PlansWiringTests.swift`, `TroveTests/SaleCopyTests.swift` (comment),
  `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; the five changed UI tests green run
  alone; mutations recorded.

- [ ] **T008 — The add button in prominent glass.**
  Per plan §5, Q4, R4. **The UI test first, on the drawn disc**: new
  `testTheAddButtonKeepsItsSizeAndPlace` — on Items ("Add item") and the
  Wishlist ("Add wanted item"): the frame 56 × 56 within a point, the
  trailing edge at the window's less the gutter, the bottom edge's position
  recorded from the tree; run it green against HEAD and record both frames.
  Then `AddButton` per Q4 — `.glassProminent`, `.buttonBorderShape(.circle)`,
  `.tint(theme.colors.accentBrass)`, the glyph taking the style's foreground,
  sized so the test stays green; the drawn `Circle().fill` gone; the doc
  comment says what `018` made it (Decision 14). Pattern: `SortMenu`'s glass
  button style; the current `AddButton` (glyph, label, size). Tests: **G11**
  in `HeaderControlsWiringTests` (mutations: `.glassProminent` removed → red;
  `Circle().fill` put back → red) and the UI test (mutation:
  `.frame(width: 60, height: 60)` → red).
  Files: `Trove/Views/Shared/AddButton.swift`,
  `TroveTests/HeaderControlsWiringTests.swift`, `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; the new UI test green before and
  after the restyle, both frames in the Done note; `scripts/verify.sh ui`
  green at this commit (the phase's last code change), count recorded;
  mutations recorded.

- [ ] **T009 — The switch's slide and the finished header's sort, filmed. [`general-purpose` agent with simulator tools]**
  Per plan §1 and §9 (G14a, G14b), criteria 1 and 7. At T008's commit (build
  path and mtime checked), iOS 27.0 and 26.5 (27.0 alone, recorded, if no
  26.5 runtime is installed), with the probe's background-difference mode
  (T002). **The sort, again (criterion 1's "absent at the end")**: on
  `-uiTesting -seedSold`, Items Owned from Date to the widest Owned label and
  back, and Sold from Name to Date sold — exactly T002's switches, on the
  header as it now stands, with the glass "…" beside the badge and no
  dropdown host — each frame judged by plan §1's "whole on every frame".
  **The switches (criterion 7)**: on `-uiTesting -seedPlans`, Items Owned →
  Sold → Owned and Plans Active → Completed: the frames the selection's edge
  takes to cross, with Δt (a slide, not a cut); the title, meta line, the
  switch's top edge and the list's top edge held within a pixel on every
  frame. Also Light and Dark screenshots of both switches and of the add
  button over scrolled rows, for the pause. **If the sort film shows the
  tear**, the orchestrator treats it as T003's case on the finished header
  (P4's fallback if not yet applied; a product question with the films if
  it was).
  Files: none (the Done note is the record).
  **Verify:** the frame tables and verdicts in the Done note — the sort's
  per runtime and per switch, the switches' per control.
  **Phase 3 closes here — pause for the person.**

## Phase 4 — Retire the bespoke code; the policy and the documents · walkthrough: none — deletes files nothing calls since Phase 3, rewords one example in `CLAUDE.md`, rewrites the policy guard and edits the two design documents; nothing on screen changes

- [ ] **T010 — Delete the bespoke controls and the tests that guarded only them.**
  Per plan §6, Q13. Delete `Trove/Views/Shared/Dropdown.swift`,
  `DropdownHost.swift`, `OverflowBadge.swift`, `OverflowDropdown.swift`,
  `SortPicker.swift`; `ThemeMetrics.dropdownGap` (declaration and value).
  Delete `DropdownWiringTests.swift`, `DropdownAnchorTests.swift`,
  `DropdownPlacementTests.swift`, `OverflowDropdownRenderTests.swift` — every
  test the retirement table assigns to T010. **G3**'s last leg: no
  `.accessibilityHint("Opens` anywhere under `Trove/Views` (mutation: the
  hint put back on `SortMenu` → red). Then a grep across `Trove/`,
  `TroveTests/`, `TroveUITests/` for `DropdownSurface`, `DropdownRow`,
  `dropdownHost`, `dropdownAnchor`, `dismissDropdown`, `DropdownPlacement`,
  `OverflowBadge`, `OverflowDropdown`, `SortBadge`, `SortDropdown`,
  `SideSwitch`, `dropdownGap` — zero, comments included (a comment naming a
  deleted type is corrected to what replaced it). Pattern: `009` T018's
  deletion with a grep before and after.
  Files: the five production files and four test files (deleted),
  `Trove/Views/Shared/Theme/ThemeMetrics.swift`,
  `TroveTests/HeaderControlsWiringTests.swift`, any file the grep finds.
  **Verify:** `scripts/verify.sh` green (the build is the proof nothing still
  calls them); the grep's zero recorded; `DestructiveColourPolicyTests`
  unedited, its site counts recorded.

- [ ] **T011 — The policy guard, inverted.**
  Per plan §7, R6 (criteria 8, 10), and plan Context's constitution
  amendment. **First step, committed on its own before anything else in this
  task** (`CLAUDE.md`'s amendment rule — the constitution changes first,
  explicitly): in `CLAUDE.md`'s Testing section, the paragraph on source
  scans that gives `MenuPolicyTests` as the legitimate shape — "'no system
  menu inside page content' is a fact about view bodies that no view-model
  test can observe" — is reworded to the new guard: "'every header control
  opens a system menu and no view floats a surface of its own' is a fact
  about view bodies that no view-model test can observe", with a
  parenthesis that until `018` the example quoted `013`'s opposite rule. No
  other word of `CLAUDE.md` changes; the orchestrator commits this step
  alone, its message naming the amendment, then dispatches the rest.
  Then: rewrite `TroveTests/MenuPolicyTests.swift`
  as the four tests of plan §7 (G12a–d), the allowlist and the old test gone,
  the suite's doc comment stating the new rule and naming `013` Amendment A
  as what it replaces. Correct the doc comments plan Context lists
  (`DetailOverflowMenu.swift` ~16–21, `ItemDetailView.swift` ~116,
  `PurchaseFormView.swift` ~254, `SellPlanView.swift` ~796,
  `MarketSection.swift` ~260, and the `SettingsWiringTests.theAppearanceSection…`
  comment) — words only. Pattern: the current `MenuPolicyTests` (the walk, the
  word-boundary regex); `SettingsWiringTests.everyTabsRootReachesSettings`
  (deriving the roots from `ContentView`); `DestructiveColourPolicyTests`
  (a policy suite's doc comment). Mutations, each red and recorded (plan
  §7): the Wishlist's `sortControl` made a `Button` showing an `.overlay` of
  drawn rows (**criterion 10's "a bespoke row put back"**); `DropdownHost.swift`
  restored from `main` with one host re-attached; `.glassEffect()` on
  `PlansCard`; `UISegmentedControl.appearance().selectedSegmentTintColor =
  .brown` in `TroveApp.init`; a `.confirmationDialog` on a Delete.
  G12a requires `sortControl` by name in `ItemListView`, `WishlistView` and
  `PlansView` and `orderControl` in `DashboardView`; G12b carries no
  picker-style leg; every `Picker(` match is on a word boundary so
  `DatePicker(` and `PhotosPicker(` never fire (plan §7).
  Files: `CLAUDE.md` (the one example, its own commit),
  `TroveTests/MenuPolicyTests.swift`, the five doc-comment files,
  `TroveTests/SettingsWiringTests.swift` (comment).
  **Verify:** the `CLAUDE.md` commit precedes the guard's, and
  `git show --stat` of it lists `CLAUDE.md` alone; `scripts/verify.sh` green;
  all five mutations recorded with the failing assertion's message.

- [ ] **T012 — The design documents say what the app now does.**
  Per plan §8 (criterion 14). `design/brief.md`: "Menus and chrome" rewritten
  to **System controls, Trove content**, recording that it supersedes `013`
  Amendment A's rule and quoting that rule as history; the "no rendered
  materials" section gains the one exception. `design/tokens.md`: the Sort
  picker and Export badge sections cut to what stays Trove's, with one line
  each for what the control opens; the `006` switch rows and the Plans
  switch row replaced; the Plans "Trailing" row and the row-treatment line
  corrected; a short **Add button (`018`)** entry. `design/elements/` left
  as history. Pattern: `design/tokens.md`'s "Mark as bought (`015`)" section
  (a no-Design-pass entry recording what was put together).
  Files: `design/brief.md`, `design/tokens.md`.
  **Verify:** `grep -c` recorded: `brief.md` names "System controls, Trove
  content" and "superseded"; `tokens.md` names no `DropdownSurface`,
  `OverflowBadge`, "232px" or "Dismiss catcher"; `scripts/verify.sh` green.
  **Phase 4 closes here — `walkthrough: none`; after its review, run on.**

## Phase 5 — Verification and close-out · walkthrough: none — the device pass and the documents; the person's own checks (the Accessibility Inspector, Reduce Transparency if the simulator can't switch it, the one-language attestation) are named in T013 as their steps, and nothing new is built

- [ ] **T013 — Device pass. [`general-purpose` agent with simulator tools, one dispatch per section; person: Accessibility Inspector, attestation]**
  Per plan §9 and criteria 2, 3, 4, 8, 11, 15, 16. At the final code commit
  (build path and mtime checked), iOS 27.0, said so. Sections, each its own
  dispatch returning a short pass/fail list: **(1)** every screen in Light
  and Dark — the four headers, each open menu, both switches, the add button
  over scrolled rows — screenshots for the person, **the appearance changed
  with the app's own Appearance control while the app runs** (Dark → Light
  → Dark), with the Items and Plans screens behind the Settings sheet and
  looked at after it closes — never by relaunching into each appearance,
  since `004`'s defect showed only on an in-app switch; **(2)** once each under
  Increase Contrast (`xcrun simctl ui … increase_contrast enabled`) and Reduce
  Transparency (the person's step if `simctl` has no switch for it): every
  glass control's label legible; **(3)** a PDF export from the Items submenu
  and from the Wishlist: the spinner on the "…", then the share sheet; and
  **Import from CSV… from each list's system menu opens the file importer**
  (criterion 2 — no UI test reaches the system's document picker), cancelled
  with the list unchanged; **(4)** the Items "…" on the Sold side under a chip: the scope rows' gates.
  Findings fixed in place if routine and inside the footprint, else returned
  for a decision review; each fix a sub-lettered task. **[person]** The
  Accessibility Inspector over the two badges (pop-up button, no hint), a
  sort menu's rows (the current one selected — and if T004 found XCUITest
  doesn't expose it, this is its only check), both switches (the selected
  segment) and the add button (criterion 11); the attestation that every
  screen reads as one language (criterion 15).
  **Verify:** each section's list in the Done note; `scripts/verify.sh all`
  green **twice back to back** at the final commit (criterion 12), both count
  lines recorded.

- [ ] **T014 — Close-out. [`sdd-implementer` on an evidence bundle]**
  Per plan §10 and `CLAUDE.md`'s close-out rule: the orchestrator assembles
  the bundle with shell (each criterion with the tests or Done notes that
  satisfied it, the walkthrough list and what the person said at each pause,
  the tier log, the spec's summary and decided lines, the `ROADMAP.md`
  entries this spec touches, `009`'s `DECISIONS.md` section as the shape);
  **the dispatch forbids full reads of `spec.md`, `plan.md` and `tasks.md`**.
  The bundle's evidence for **criterion 1 is both films** — T002's (and
  T003's if it ran), the measurement taken first, and **T009's**, the one on
  the finished header that "absent at the end" rests on.
  Criteria 1–16 ticked in `spec.md` with citations; P-items → decisions; this
  plan's **As built** (the tear's result and whether P4 shipped, the control
  size, the header and subtitle mechanisms, the `isSelected` finding, G1's
  render-vs-device heights); the pointers of plan Context appended in place
  (`grep -c` each); `README.md` if its words describe the old controls; the
  post-merge draft `specs/018-system-design-language/main-docs-draft.md` with
  the `ROADMAP.md` text (`018`'s entry and status row, and the follow-up
  Decision 11 defers — the system navigation bar and toolbar on the tab
  roots, **before `019`**) and the `DECISIONS.md` text (plan §10's list).
  Then the pre-merge `skeptical-reviewer` sweep over `git diff main...HEAD`,
  bundle cut after `git add -A`, and the PR marked ready.
  Files: `specs/018-system-design-language/spec.md`, `plan.md`, this file,
  `main-docs-draft.md` (new), `README.md`, `specs/013-settings-menu/spec.md`,
  `specs/010-item-management-enhancements/tasks.md`,
  `specs/014-sold-side-parity/spec.md`, `specs/009-sell-plan-list/plan.md`
  (pointers).
  **Verify:** everything committed and pushed; `scripts/verify.sh all` green,
  both count lines recorded here.

## Tier log

`CLAUDE.md`'s model policy, **Opus profile** (reconciled 2026-09-24): every
role runs at `opus`, each definition's own default, so **no dispatch carries a
model override**; the orchestrating session runs at `claude-opus-5-5` medium.
Every Tier entry is the resolved name, never "default." Token usage from each
subagent return is filled in as the spec runs; escape-hatch misses are
recorded here too.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| Policy: plan-and-tasks draft at the implementation tier, no override, trial from 2026-09-24, started with this spec | — | — | `CLAUDE.md` role table, trial row; persists until the person says otherwise |
| Spec session (this spec's `spec.md`, three rounds and approval) | `claude-fable-5-1` at high effort | orchestrating seat, not measured separately | Spec session ran on claude-fable-5-1 at high effort by the person's per-session pick from the app's picker, 2026-09-24; not a role-table change; the Opus profile stands. Draft 2026-09-24, approved the same day with Decisions 1–14; nothing left open |
| Note: T002's device agent extends `scripts/motion-probe/profile.swift` | — | — | Implementation work in a `general-purpose` dispatch, planned deliberately rather than the device agent quietly doing a task: the probe's new background-difference mode can only be tested against film, which only the simulator agent can take. The orchestrator commits it with T002 and the phase review reads it |
| `sdd-planner` — plan.md and tasks.md (draft) | `opus` | ~375k (budget counter, cache re-reads included) | 14 tasks, 5 phases, 15 guards; no product question returned; one spec/code inconsistency stated as a reading (plan R4: the Wishlist add button says "Add wanted item", not the spec's "Add to wishlist", and has no identifier) |
| `sdd-planner` — sign-off fix pass (B1, B2, seven second-looks) | `opus` | ~15k (~390k cumulative for the planner) | Same agent resumed with the findings; the diff is the re-review's bundle |
| `skeptical-reviewer` — plan/tasks sign-off | `opus` | ~107k (subagent total) | fix and re-review: B1 (CLAUDE.md's Testing example quotes the rule 018 reverses; T011 now rewords it first, in its own commit), B2 (criterion 1's "absent at the end" had no film on the finished header; T009 now re-films the sort). Seven second-looks applied. The planner's six deviations accepted as flagged; R2 (tapping the showing side no longer reloads) to be recorded in spec.md once the person answers; R4 corrected in spec.md the same day |
| `skeptical-reviewer` — sign-off re-review | `opus` | ~125k (subagent total, includes the first review's context) | **signed off**. Two non-blocking notes for the orchestrator: dispatch T011's CLAUDE.md edit alone and commit it before the rest of T011; tell the person about the CLAUDE.md rewording in plain words in the next report (Phase 4 has no pause) |

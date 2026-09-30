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
| `ItemListHeaderLayoutTests.theSortBadgeIsOneWidthForEverySelection` (T003's G1 leg) | P4's constant footprint, withdrawn by Decision 18 | T006a |
| `OverflowDropdownRenderTests` — `theTwoGroupBreaksReadStrongerThanTheRowSeparator`, `theExportRowsDimWhenThereIsNothingToExport`, `eachExportRowDimsOnItsOwnGate` | the overflow dropdown's drawn hairlines and dimming | T010 |

**Rewritten, not retired** (each Done note records the mutation the rewrite
catches): `MenuPolicyTests.theOnlySystemMenuIsTheDetailScreensNavBarOverflow`
(→ G12, T011); `ItemListHeaderLayoutTests` (G1, T001/T005);
`ItemListSidesWiringTests.oneNarrowingGateCoversBothSidesAndEachSideBringsItsOwnSort`
(G6, T001), `theSwitchReportsThroughShowAndBindsToNothing`,
`theSwitchStandsOutsideTheEmptyState`, `theSwitchIsLabelledAndMarksItsActiveHalfSelected`
(G10, T007); `PlansWiringTests.noSortDropdownOffersAManualOrder` (G7, T004),
`theSideToggleReportsThroughShow` (G10, T007);
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

- [x] **T001 — `SortMenu`, and Items' Sort By on it. `review: per-task`.**
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
  **Decided at T001's decision review (2026-09-24, plan Q8):** the menu's
  content is a `Section(SortMenuCopy.header)` of `Toggle(` checkmark rows in
  a `ForEach`, the setter `{ _ in select(option) }`, the subtitle a second
  `Text` on the `manualOrder` row — an inline `Picker` draws neither header
  nor subtitle inside a `Menu`. **G1** renders the header with a stand-in
  in the trailing slot sized from a render of the badge row alone (a glass
  `Menu` in the header's `VStack` crashes `ImageRenderer`); no leg compares
  the stand-in to the render it came from; new mutation: `SortMenu` at
  `.large` → the proviso red.
  Tests: new `TroveTests/HeaderControlsWiringTests.swift` — **G2** (mutations:
  the `Toggle` rows replaced by `Button` rows → red;
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
  **Done (2026-09-24, commit follows).** Stopped once on plan Q8's stop and a
  second finding (a glass `Menu` in the header's `VStack` crashes
  `ImageRenderer`); both went to a decision review (tier log) and were
  transcribed into plan §1, Q8, §3, §11 before the task resumed. Shipped:
  `SortMenu` as a `Menu` over `Section(SortMenuCopy.header)` of `Toggle`
  checkmark rows, `.glass`, `.controlSize(.regular)`. Control size (Q6):
  sort badge alone `.regular` 102×29, `.small` 98×25, `.large` 118×45; badge
  row (with `OverflowBadge`, 42×30) 152×30 / 148×30; header 53 at both,
  equal to the no-badges header 53 (title line box 33 + 6 + meta 14), so
  the proviso holds and `.regular` ships; `.large` breaks it (header 65).
  Simulator frame of `sortOptions.items` 28.33 pt against 29 rendered.
  Mutations, all red: G2 Toggle rows → Button rows
  (`HeaderControlsWiringTests.swift:47`), `theme.colors` foreground (`:52`);
  G1 new `.large` (`ItemListHeaderLayoutTests.swift:117`), meta beside the
  badges (`:121–133`), 200-pt baseline (`:117–133`), `OverflowBadge` padding
  8→14 (`:117`); G3 identifier dropped (`:58`); G6 `manualOrder:` on Sold
  (`ItemListSidesWiringTests.swift:145`), Sold writing `sortOrder` (`:150`),
  gate `&& side == .owned` (`:76`), search clear moved (`:161`).
  `scripts/verify.sh`: green, 1748 tests in 235 suites (implementer and
  orchestrator re-run). UI: the two named tests green alone;
  `testTheSortMenuOffersMarketRows` Items leg green, Wishlist leg red until
  T004 (line 501, count 0 of "Sort by"). **Carried notes** from the review:
  G6's Sold leg gains `!soldSelect.contains("viewModel.sortOrder")` and the
  UI comment at ~837 stops naming a picker (T004); "the two badges one
  height" is T005's leg; `MenuPolicyTests`' old test name is renamed at
  T011; `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch` ran 209 s
  with three 60 s "animations complete notification not received" stalls —
  timed again at the phase-end UI run, and T002 looks at whether the glass
  button keeps the app from idling.

- [x] **T002 — The tear, filmed. [`general-purpose` agent with simulator tools]**
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
  frame height against T001's recorded render height of `SortMenu` alone
  (plan §1's claim). **Added at T001's decision review, on both runtimes:**
  exactly one checkmark in the open menu; tapping the current row closes
  the menu with the label unchanged and no frame of the close showing two
  checks or none; an accessibility-tree dump showing Selected on the
  current row. If iOS 26.5 draws the rows as switches or drops the header,
  stop and report — a second decision review follows.
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
  **Done (2026-09-24, at T001's commit 930c90b, binary mtime checked).**
  Four films: iOS 27.0 Dark/Light, iOS 26.5 Dark/Light; `-uiTesting
  -seedSold`; widest Owned label "Market ↓" (mono 11 pt, 8 characters);
  switches Date → Date (current row), Date → Market ↓, Market ↓ → Date,
  Sold Date sold → Name, Name → Date sold; Δt 5–23 ms; badge box
  (220, 81, 112 × 41). Probe `bg` mode: label = brass (R−B > 40), capsule =
  differing and not brass, extent over the box's full height; calibrated
  against XCUITest's frame (27.0 within 0.7 pt on every state).
  **iOS 27.0: whole on every frame**, all five switches, both appearances —
  the dismiss is a glass morph (panel → droplet, box bare 0.11–0.16 s, the
  capsule scales in over ~12 frames with the label clipped inside, settled
  by +0.35 s); settled extents match the true frame within 0.7 pt.
  **iOS 26.5: the tear, in a settled form** — after a narrow-to-wide relabel
  the capsule keeps the previous label's width until the next tap:
  Date → Market ↓ settles at 25.0–95.0 against a true 13.0–108.0 (label
  26.3–94.7, zero padding, bars and arrow at or over the rim, frames 819–864
  Dark / 918–945 Light); Name → Date sold 22.3–92.0 against 6.3–108.0;
  wide-to-narrow leaves a stale wider shadow behind the right pill (Light,
  frame 1183). The probe's TEAR verdict cannot fire there (the label's
  fringe is the outermost non-brass pixel); the finding rests on the
  calibration column and the viewed frames. **P4 applies → T003.**
  Menu checks, all four runs: exactly one "Sort by", Date ticked, one
  checkmark, "Drag rows to reorder" under Custom, no switches; tapping the
  current row closes the menu with the label unchanged and no frame with
  two checks or none. Accessibility: 7 buttons, Date `isSelected == true`,
  one selected; the subtitle is joined into the button's label on 27.0
  ("Custom, Drag rows to reorder") and absent from the tree on 26.5 though
  drawn — T004's UI test matches Custom by prefix and never counts the
  subtitle as a static text. Heights: device 28.33 pt on both runtimes
  against 29 rendered (within a point; Q6's choice stands). Idle: no
  "animations complete" stalls in any log; the glass menu does not keep the
  app from idling (T001's 209 s run is not the menu's doing).

- [x] **T003 — (Only if T002 shows the tear) P4's constant footprint, re-filmed.**
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
  **Done (2026-09-24, code at 07459bb; re-film at that commit, app rebuilt,
  binary mtime checked).** `SortMenu`'s label is a `ZStack` of every
  option's label hidden under the selected one, mono 11, no colour of its
  own. G1 gains `theSortBadgeIsOneWidthForEverySelection`: every Items
  Owned option renders at 95 pt (under the mutation — hidden labels
  removed — the widths were Date 69, Custom/Desire 82, Value 89, Market 95,
  red at `ItemListHeaderLayoutTests.swift:158`, `Set(widths.values).count
  == 1`). Header height still 53 in every case; Owned badge row 145 × 30,
  Sold 152 × 30. `scripts/verify.sh`: green, 1749 tests in 235 suites;
  `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch` alone 31 s (no
  stalls; T001's 209 s does not reproduce). **Re-film**: four films (27.0
  Dark/Light, 26.5 Dark/Light), the same five switches, same probe and
  thresholds; device badge frame 95 × 28.33 on Owned for every selection,
  101.67 × 28.33 on Sold, both runtimes. **Whole on every frame, all
  switches, both runtimes, both appearances**: the settled extent matches
  XCUITest's frame within 0.7 pt on every row, including 26.5's Date →
  Market ↓ (13.0–108.0, was 25.0–95.0) and Name → Date sold (6.3–108.0,
  was 22.3–92.0); the Light ghost after Market ↓ → Date is gone. Frames
  viewed by eye on 26.5 (Dark f690/f725, f905/f945, f1410/f1445; Light
  f830/f870, f1030/f1070, f1485/f1525): full capsule with padding, no
  stale shadow. **What this rests on (Phase 1 review):** the probe's TEAR
  verdict cannot fire on either runtime — a label's anti-aliased fringe is
  differing-and-not-brass, so a protruding label widens the measured
  capsule and `out=` stays 0 — and the capsule is measured over the box's
  full height, not the mid-line run plan §1 first named. The evidence is
  the settled extent against XCUITest's frame on every switch (the check
  that found the 26.5 tear at T002) and the frames viewed by eye. On that
  evidence criterion 1's first measurement is met; T009 repeats it on the
  finished header with a probe first shown able to fail (plan §1 As built).

- [x] **T004 — Sort By on the Wishlist and Plans; the sort menus' UI test.**
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
  tick as `isSelected` and how it exposes the subtitle; per T001's decision
  review: count elements whose label is **exactly** "Sort by" so the badge's
  own "Sort by Date" never matches, assert the current row `isSelected`,
  the Custom row's label "Custom, Drag rows to reorder" and every other
  row's label exactly its option name; mutations:
  `manualOrder: .newest` on a Plans menu → red; the subtitle `Text` removed
  from `SortMenu` → red).
  Files: `Trove/Views/Wishlist/WishlistView.swift`,
  `Trove/Views/Plans/PlansView.swift`, `TroveTests/PlansWiringTests.swift`,
  `TroveTests/HeaderControlsWiringTests.swift`,
  `TroveTests/DropdownWiringTests.swift`, `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green at the
  phase's final commit, count recorded; mutations recorded.
  **Done (2026-09-24).** Wishlist: one `SortMenu`, `manualOrder: .custom`;
  Plans: a `@ViewBuilder` `Group` over the side, one `SortMenu` per side, no
  `manualOrder`, `setActiveSort`/`setCompletedSort`; both keep label and
  identifier, lose the hint; `HeaderDropdown.sort`, host `case .sort:` and
  the sort anchors gone (`.overflow` stays). G7 renamed and rewritten; G3
  is one test over Items, Wishlist and Plans; the two carried notes from
  T001's review done (G6's Sold leg, the UI comment). Mutations, all red:
  G7 `manualOrder: .newest` on Plans Active (`PlansWiringTests.swift:231`);
  G3 `sortOptions.plans` dropped (`HeaderControlsWiringTests.swift:76`),
  the Wishlist hint put back (`:80`); G6 Sold writing both orders
  (`ItemListSidesWiringTests.swift:151`); UI: `manualOrder: .newest` on
  Plans → "Newest, Drag rows to reorder" ≠ "Newest" and the subtitle count
  1 ≠ 0; the subtitle `Text` removed → "Custom" ≠ "Custom, Drag rows to
  reorder" on Items Owned and the Wishlist. **XCUITest exposure (27.0)**:
  the ticked row is `isSelected` and the only selected row; the subtitle
  is joined into the button's label; exactly one element is labelled
  exactly "Sort by". (On 26.5 the subtitle is absent from the tree, per
  T002; the suite runs on 27.0.) `-seedPlans` populates all five sides.
  `scripts/verify.sh`: green, 1749 tests in 235 suites. The three named UI
  tests green alone (42 s, 20 s, 49 s). **`scripts/verify.sh ui` at the
  phase's final commit: 36 tests, 0 failures, 873 s.** Note for the
  record: verify.sh's failures section matches only Swift Testing's ✘
  lines; an XCTest failure shows only in the count line, and its message
  must be pulled from the log path with `grep "error: -\["`.
  **Phase 1 closes here — pause for the person** (what to try is in the
  handoff note above).

- [x] **T004a — The person's Phase 1 findings: the badges in the system's colour and at the system's size.**
  Per spec Decisions 15 and 16 (2026-09-25), plan R3 and Q6 as overtaken.
  (a) `SortMenu`'s label `HStack` (glyph and text) takes
  `.foregroundStyle(.primary)` — the system's label colour, never a theme
  colour — so the root brass tint no longer reaches it; G2 gains a leg that
  the label sets `.primary` and keeps "names no `theme.colors`" (mutation:
  the `.foregroundStyle(.primary)` removed → red). **Decision review at this
  task:** `NoHardcodedColorsTests` gains a per-file, per-line
  `systemLabelExemptions` allowlist (`"SortMenu.swift":
  ".foregroundStyle(.primary)"`) with a stale-entry check; mutations: the
  line put in `ItemListHeader.swift` → red (per file); `.tint(.red)` in
  `SortMenu.swift` → red (per line); the modifier removed from `SortMenu`
  → red (stale entry, and G2). (b) `.controlSize(.large)`
  on `SortMenu` (T005's `OverflowMenu` copies it); G1's proviso case is
  rewritten per Q6 to pin header = badge row + 6 + one meta line, the
  no-badges render now shorter than the header, and every other G1 case
  re-run (the two badges still one row; one width for every selection);
  record the new badge height, row height and header height on both
  sides, and confirm G39's equality (header height and switch `minY` equal
  on both sides) still holds on the UI run. The mono type stays 11 pt.
  Tests: `HeaderControlsWiringTests` (G2), `ItemListHeaderLayoutTests`
  (G1); the UI test `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch`
  and G39's test run alone. Files: `Trove/Views/Shared/SortMenu.swift`,
  `TroveTests/HeaderControlsWiringTests.swift`,
  `TroveTests/ItemListHeaderLayoutTests.swift`.
  **Verify:** `scripts/verify.sh` green; the named UI tests green alone;
  mutations recorded; the person looks again before Phase 2 starts.
  **Done (2026-09-25).** (a) `.foregroundStyle(.primary)` on the label
  `HStack`; `NoHardcodedColorsTests.systemLabelExemptions` holds
  `"SortMenu.swift": ".foregroundStyle(.primary)"` with a stale-entry check;
  G2's leg requires exactly one `} label:` closure carrying the line.
  (b) `.controlSize(.large)`; G1's proviso rewritten: header = badge row +
  6 + meta line on both sides, no-badges render shorter than the header.
  Measured at width 354: badge row Sold 168×45, Owned 161×45; meta 14;
  header 65 both sides (no badges 53); Owned badge 111 wide for every
  selection; mono 11 pt unchanged. `ItemListHeader.swift`'s body comment
  corrected (comment only, outside the footprint). Mutations, all red:
  meta beside the badges (7 failures, headers 67); `.regular` (both sums
  and `withoutBadges < baseline`, 53 = 53); the line put in
  `ItemListHeader.swift` (`ThemeTests.swift:274`, per file); `.tint(.red)`
  in `SortMenu.swift` (`:274`, per line); the modifier removed
  (`:279` stale entry, and `HeaderControlsWiringTests.swift:58`).
  `scripts/verify.sh`: green, 1749 tests in 235 suites. UI alone:
  `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch` 30 s green,
  G39's `testTheSoldCardLandsOnTheSoldSideWhichListsSalesMostRecentFirst`
  19 s green (switch `minY` equal both sides at `.large`). **Findings
  carried:** the colour scan reads comment lines, so an exempted spelling
  in a doc comment would satisfy the stale-entry check — T005 keeps
  `OverflowMenu.swift`'s comments free of the literal, and T011 may teach
  the scan to skip comments; the two badges differ in height (45 vs 30)
  until T005's `OverflowMenu` copies `.large`. Reviewed with Phase 2.

- [x] **T004b — The person's second re-look: the colour that actually takes, and the chosen size.**
  Per spec Decision 17, plan R3 and Q6 as overtaken (2026-09-26). In
  `SortMenu.swift`: `.tint(.primary)` on the `Menu` directly after
  `.buttonStyle(.glass)`; the glyph bars `Color.primary.frame(width:height:
  1.5)` instead of `Rectangle()`; the `.foregroundStyle(.primary)` line
  removed (it is ignored by the glass style); `.controlSize(.regular)` with
  `.padding(.vertical, 4)` on the label `HStack`; the `ZStack` stays
  `.leading`. `NoHardcodedColorsTests.systemLabelExemptions` becomes
  `[String: [String]]`, `"SortMenu.swift": [".tint(.primary)",
  "Color.primary"]`, each entry checked for staleness, and the
  `Color.primary` scan (the suite's other test) honours the same list; G2's
  leg pins `.tint(.primary)` after `.buttonStyle(.glass)` and no
  `.foregroundStyle(`; G1 re-measured (badge, row, header on both sides;
  one width per selection). Mutations: `.tint(.primary)` removed → G2 and
  the stale-entry check red; `.tint(.blue)` in `SortMenu.swift` → red;
  `Color.primary` used in `ItemListHeader.swift` → red; the vertical
  padding removed → G1's proviso numbers change (record) — if no G1
  assertion goes red on that, say so, since the proviso is a relation, not
  a number. Files: `Trove/Views/Shared/SortMenu.swift`,
  `TroveTests/ThemeTests.swift`, `TroveTests/HeaderControlsWiringTests.swift`,
  `TroveTests/ItemListHeaderLayoutTests.swift`.
  **Verify:** `scripts/verify.sh` green; `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch`
  and G39's test green alone; a pixel read of the label on the device in
  both appearances is the orchestrator's install-and-look step with the
  person.
  **Done (2026-09-26).** `.tint(.primary)` after `.buttonStyle(.glass)`;
  bars as `Color.primary` views; `.foregroundStyle` gone; `.regular` with
  4 pt vertical label padding; ZStack `.leading`. `NoHardcodedColorsTests`:
  `systemLabelExemptions: [String: [String]]`, both scans through one
  `scan(flags:)`, a flagged line passes only when clean with its file's
  exempted texts removed, staleness per entry by the scan its text trips.
  G2 pins `.buttonStyle(.glass)` immediately followed by `.tint(.primary)`
  and no `.foregroundStyle(` in the comment-stripped file. Measured at
  width 354: badge Owned 95 × 37, Sold 102 × 37; rows 145 × 37 / 152 × 37;
  header 57 both sides (no badges 53, meta 14); 95 wide under every Owned
  selection. Mutations, all red: `.tint(.primary)` removed (G2
  `HeaderControlsWiringTests.swift:61` and the stale entry); `.tint(.blue)`
  in `SortMenu.swift` (`SortMenu.swift:99`); `.background(Color.primary)`
  in `ItemListHeader.swift` (`noViewConstructsAColorDirectly`); the
  padding removed (rows 30, headers 53: both sums and `withoutBadges <
  baseline` red). `scripts/verify.sh`: green, 1749 in 235. UI alone:
  `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch` 31 s,
  G39's test 17 s, both green. **Finding carried to T011:** both colour
  scans miss a system colour followed by a member (`Color.primary.opacity(0)`
  stayed green) — Swift `Regex`'s default `\b` is a Unicode word boundary
  that does not break inside `primary.opacity`; `.wordBoundaryKind(.simple)`
  fixes it; nothing in `Trove/Views` has that shape today. Pre-existing
  gap, the false-passing shape `CLAUDE.md` asks to audit for — T011 (the
  policy-guard task) fixes it and re-runs the mutation.

**Phase 1 pause (2026-09-24 → 26).** The person tried the app three times: found the brass label and the squashed capsule (→ T004a), then the label still brass and the capsule oversized with blank space on the right (→ T004b, size C chosen from rendered candidates), then: "Looks good, continue."

## Phase 2 — Every header menu is the system's · walkthrough: yes — each tab's "…" opens the system menu: Settings alone on the Overview and Plans; Export as CSV…, Export as PDF…, Import from CSV…, Settings in three groups on the Wishlist; on Items the two exports (no ellipsis) open submenus of Owned items, Sold items, Owned and sold, greyed where a scope has nothing on screen; an export shows the spinner then the share sheet; the Overview's "BY VALUE" opens a menu headed "Order by"

- [x] **T005 — `OverflowMenu`, and every "…" on it.**
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
  **Done (2026-09-26).** `OverflowMenu` with `SortMenu`'s modifiers in order
  (`.glass`, `.tint(.primary)`, `.regular`), the glyph row a hidden
  mono-11 line box (`SortMenuCopy.labelFont`, shared) with the spinner or
  ellipsis overlaid, 4 pt vertical padding; both badges 109 px at 3×
  (36.33 pt; the badge row 37 at 1×, header 57). Items' `exportMenu` is
  `@ViewBuilder`: the format's own flag chooses a `Menu` of scope rows or
  a `Button(title) {}.disabled(true)` (a nested `Menu`'s `.disabled` is
  ignored inside a system menu on 27.0). Items, Wishlist and Plans have no
  dropdown host; the Dashboard keeps `.order`. `ExportCopy.scopeTitleCSV/
  PDF` gone. Allowlists: `MenuPolicyTests` + `OverflowMenu.swift`,
  `ItemListView.swift`; `ThemeTests` + `"OverflowMenu.swift":
  [".tint(.primary)"]`. **Retired by name:**
  `DropdownWiringTests.eachListHostsItsDropdownsOffOneOptional` (and its
  `lists` static), `DropdownWiringTests.theDashboardAnchorsItsBadgeOnTheRootAloneAndComposesSettings`,
  `ExportWiringTests.theScopeChooserHeadersReadAsTheSpecWritesThem`. G8's
  three tests renamed to describe a menu. Carried notes done: G1's
  `badgeRowSize` renders the side's real options; `assertSortMenu` counts
  each row once and the cell count; both sort helpers use the same exact
  "Sort by" query. Mutations, all red: G4 `.disabled(isBusy)` removed
  (`HeaderControlsWiringTests.swift:138`), `isBusy: false` on Items (`:153`),
  tint removed (`:144` + the stale entry); G3 `moreActions.dashboard`
  dropped (`:98`); G5 "…" outside `if isRoot` (`:174`); G1 `.frame(height:
  14)` put back (108 vs 109 px, `ItemListHeaderLayoutTests.swift:243/247`),
  `.small` (97 px), hidden font 12 (113 px); G8 PDF on the CSV flag
  (`ExportWiringTests.swift:209`), `.both` exported directly (`:229/:232`),
  Import gated (`:172`), "Export as CSV…" on Items (`:202/:208`),
  `.disabled(true)` dropped (`:221`); G9 Plans' menu a `Button`
  (`SettingsWiringTests.swift:274/281/282`), Settings row removed (`:282`);
  UI: scope rows on `canExportCSV` (`TroveUITests.swift:1425`),
  `.disabled(true)` dropped (`:270`, both formats). `scripts/verify.sh`:
  green, 1749 in 235. UI alone, all green: the two rewritten tests (22 s,
  30 s), `testDashboardOffersSettingsAndNothingElse` (15 s),
  `testEveryTabsRootReachesSettings` (46 s), and the two sort tests. **For
  the pause:** an empty format's export row on Items has no chevron.
  **For the device pass:** `ImageRenderer` draws a glass button as an
  opaque white placeholder, so the ellipsis's brightness under the tint is
  the device pass's to look at (T013).

- [x] **T006 — The Dashboard's order menu.**
  Per plan §3, R5. `orderControl` per plan §3 — a system `Menu` whose content
  is a `Section("Order by")` of `Toggle(` checkmark rows (T001's header
  mechanism as decided at its review; the UI test's checks mirror T004's for
  "Order by"), the mono label in
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
  **Done (2026-09-26).** `orderControl` per plan §3 (Section("Order by") of
  Toggle rows, setter writes and reloads, mono label in `textQuiet`, no
  glass, no button style); label and identifier kept, hint gone; the
  Dashboard's host, `DashboardDropdown`, `openDropdown` and anchor gone.
  `MenuPolicyTests` allowlist + `DashboardView.swift`. G5 order test and
  G3's `orderOptions.dashboard` row added. **Retired by name:**
  `DropdownWiringTests.theDashboardOrderControlOpensTheSharedSurfaceUnderOrderBy`;
  `everyBadgeCarriesItsHintAndIdentifier` loses its Dashboard legs. New UI
  test `testTheOverviewsOrderMenuOffersValueAndCountUnderOrderBy`
  (`-seedPlans` suffices). Mutations, all red: `load()` dropped
  (`HeaderControlsWiringTests.swift:220`); `.glass` on the label (`:225`);
  identifier dropped (`:100`); the setter not writing (UI,
  `TroveUITests.swift:2295`). `scripts/verify.sh`: green, 1749 in 235. UI
  alone: the new test 16 s, `testDashboardOffersSettingsAndNothingElse`
  16 s. **`scripts/verify.sh ui` at the phase's final commit: 37 tests,
  0 failures, 920 s.** For the device pass: R5's `textQuiet` winning over
  the tint on a `Menu` label with no button style is unverified off-device.
  `MenuPolicyTests`' doc comment and `Dropdown.swift:7` still name the old
  rule — T010/T011.
  T005 also touched `SortMenu.swift` (the shared `labelFont`, per the
  decision review) and `ThemeTests.swift` (the `OverflowMenu.swift` entry,
  per R3) — outside its file list, authorised.
  **Phase 2 closes here — pause for the person.**

- [x] **T006a — The person's Phase 2 findings: the "…" a circle, Sort By sized to its text (Decision 18).**
  Per spec Decision 18, plan §1's Decision 18 paragraph. `OverflowMenu`:
  `.buttonBorderShape(.circle)` directly after `.buttonStyle(.glass)`; the
  hidden glyph row `.frame(width: 22)`; comments say why 22. `SortMenu`:
  the hidden-labels `ZStack` replaced by the bare `Text(label(selection))`
  (same font); the P4 paragraph in its doc comment replaced by Decision
  18's record (the 26.5 transient accepted, the morph kept). Tests: G1 —
  `theSortBadgeIsOneWidthForEverySelection` **retired** (P4 withdrawn;
  list it in the retirement table under this task); `theTwoBadgesRenderAtOneHeight`
  still exact at 3× (mutation: the glyph row back to 18 → red, the circle
  shorter); `badgeRowSize` and the proviso cases re-measured and recorded
  (the Owned row is now narrower under "Date" than under "Market ↓" — the
  header height must not change with it: add a case that the header is
  equal under the narrowest and the widest Owned label, mutation: a
  fixed-height frame keyed to the label → red, or say why no mutation is
  possible). G2 gains a leg that `OverflowMenu.swift` carries
  `.buttonBorderShape(.circle)` and `SortMenu.swift` does not (mutation:
  the shape removed → red). UI: `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch`
  and G39's test green alone. The tried diff is in the scratchpad
  (`phase2-diagnosis-tried.diff`) — copy the two production changes, not
  `.id(selection)`. Files: `Trove/Views/Shared/OverflowMenu.swift`,
  `Trove/Views/Shared/SortMenu.swift`, `TroveTests/ItemListHeaderLayoutTests.swift`,
  `TroveTests/HeaderControlsWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; the two UI tests green alone;
  mutations recorded; the person looks before Phase 3.
  **Done (2026-09-26).** `OverflowMenu`: `.buttonBorderShape(.circle)`
  after `.buttonStyle(.glass)`, glyph row 22 wide; `SortMenu`: bare
  `Text(label(selection))`, Decision 18 recorded in its doc. **Retired by
  name:** `ItemListHeaderLayoutTests.theSortBadgeIsOneWidthForEverySelection`.
  New `theHeaderIsOneHeightUnderTheNarrowestAndTheWidestOwnedLabel`.
  G2 pins the circle on `OverflowMenu.swift` and none on `SortMenu.swift`;
  G4's tint regex now reads glass → circle → tint. Measured (27.0 render):
  Owned badge row per selection Date 113 … Market 139, all 37 tall; Sold
  146 × 37; header 57 everywhere (53 without badges); at 3× "…" 108 × 109
  px, sort 245/305 × 109. Mutations: a label-keyed fixed height → red
  (`ItemListHeaderLayoutTests.swift:217`, 62 vs 82, and `:252/:256`); the
  circle removed → red (`HeaderControlsWiringTests.swift:84` and `:166`).
  **The glyph row back to 18 stays green**: `ImageRenderer` draws the glass
  circle as width × label-height (96 × 109 px at 18, 108 × 109 at 22), so
  the circle's diameter is untestable off-device; by T005's ruling (no
  tolerance in G1) it is verified on device — T009's film and T013's
  measurement — and the test's doc says so. `scripts/verify.sh`: green,
  1749 in 235. UI alone: the two named tests green (30 s, 17 s).

**Phase 2 pause (2026-09-26 → 27).** The person tried the app twice: the "…" should be a full circle and Sort By narrower with equal insets (→ Decision 18, T006a, with the morph kept and the 26.5 transient accepted), then: "Looks good. Continue."

## Phase 3 — The two switches and the add button · walkthrough: yes — Owned/Sold and Active/Completed are the system segmented control whose glass selection slides while the header holds still, and Sort By's capsule stays whole through a width-changing sort on the finished header (both films are in the report); the add button on Items and the Wishlist is a brass glass disc in the same corner and size, opening the same form; every screen in Light and Dark reads as one language (criterion 15)

- [x] **T007 — `SidePicker`, and both switches on it.**
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
  `PlansWiringTests.theSideToggleReportsThroughShow` (mutations:
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
  **Done (2026-09-27).** `SidePicker.swift` exactly per plan §4, the two
  constrained inits keeping words, labels and identifiers; `SideSwitch.swift`
  deleted with `SideSwitchMetrics`, `halfWidth` and the brass fill; the
  call sites change one word; comments naming `SideSwitch` corrected
  (`ItemListViewModel.swift:272`, `ItemListHeader.swift:7`,
  `ItemListHeaderLayoutTests.swift:9`, `ItemListSidesWiringTests.swift:378`,
  `SaleCopyTests.swift:110`; "above it" → "below it" where the switch's
  position was described). G10: the three Items tests and the Plans test
  rewritten (words, labels and identifiers checked as values through the
  inits, not scanned); G18, `labelWidth` and unused imports removed.
  **Retired by name:** `ItemListSidesWiringTests.theSwitchesSlideIsAtOrUnderTwoTenthsOfASecond`,
  `theSwitchesFillIsOneMovingRectangle`,
  `PlansWiringTests.everyLabelOfBothSwitchesFitsItsHalf`. Mutations, all
  red: `.pickerStyle(.menu)` (`ItemListSidesWiringTests.swift:459`); setter
  `{ _ in }` (`:455`); `$viewModel.wrappedValue.side` at a call site (a
  literal `$viewModel.side` cannot compile against `private(set)`) —
  Items `:309`, Plans `PlansWiringTests.swift:181`; the call moved into the
  empty-state branch — Items `:323`, Plans `:190`. UI: the four switch
  reads (at lines 1045, 2043, 2080, 2432 — the task line's numbers were
  stale) now `.buttons[…].isSelected`; the Appearance test finds the
  control containing a "System" segment. `scripts/verify.sh`: green, 1746
  tests in 235 suites (three retired). UI alone: the four changed tests
  green (87 s) and the nine other switch-driving tests green (328 s).
  XCUITest reads a segmented `Picker`'s segments as `buttons[…]` with a
  working `isSelected`. R1 (`.fixedSize()`, hugging) and R2 (tapping the
  showing side no longer reloads) shipped as read — for the pause.

- [x] **T008 — The add button in prominent glass.**
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
  **Done (2026-09-27).** UI test first, green on the drawn disc: Items
  "Add item" (322, 711, 56, 56), Wishlist "Add wanted item" the same,
  window 402 × 874, gutter 24 read from the header's "…" (`window.maxX −
  moreActions.maxX`), bottom edge 24 above the tab bar (791). Then
  `AddButton`: `.glassProminent` → `.buttonBorderShape(.circle)` →
  `.tint(theme.colors.accentBrass)`, the label framed 42 × 42 (a prominent
  glass circle is its label + 14), the plus taking the style's foreground,
  no drawn `Circle()` (there was no shadow to remove); the same frames
  after, twice. G11 `theAddButtonIsABrassProminentGlassCircleWithNoDrawnDisc`
  (three modifiers in order, no `Circle(`, no `.foregroundStyle(` — one
  extra leg for Q4's "the glyph taking the style's foreground").
  Mutations, all red: `.glassProminent` removed (`HeaderControlsWiringTests.swift:272`);
  `Circle().fill` put back (`:276`); `.foregroundStyle` put back (`:280`);
  `.frame(60)` → the UI test red (74 × 74 at (304, 693), `TroveUITests.swift:2337/2338`).
  `scripts/verify.sh`: green, 1747 tests in 235 suites. The new UI test
  alone 15 s green. **`scripts/verify.sh ui` at the phase's final code
  commit: 38 tests, 0 failures, 979 s.** The brass on the glass is the
  device pass's to see (`ImageRenderer` draws glass as a placeholder).

- [x] **T009 — The switch's slide and the finished header's sort, filmed. [`general-purpose` agent with simulator tools]**
  Per plan §1 and §9 (G14a, G14b), criteria 1 and 7. At T008's commit (build
  path and mtime checked), iOS 27.0 and 26.5 (27.0 alone, recorded, if no
  26.5 runtime is installed), with the probe's background-difference mode
  (T002). **The sort, again (criterion 1's "absent at the end")**: on
  `-uiTesting -seedSold`, Items Owned from Date to the widest Owned label and
  back, and Sold from Name to Date sold — exactly T002's switches, on the
  header as it now stands, with the glass "…" beside the badge and no
  dropdown host — each frame judged by plan §1's "whole on every frame".
  **Decision 18:** on iOS 27.0 the verdict stands as written; on iOS 26.5
  the narrow-to-wide transient is expected — record its width, its
  duration to the snap, and that the wide-to-narrow morph is clean; it is
  a failure only if it does not self-correct within about 1.5 s or shows
  on 27.0.
  **The switches (criterion 7)**: on `-uiTesting -seedPlans`, Items Owned →
  Sold → Owned and Plans Active → Completed: the frames the selection's edge
  takes to cross, with Δt (a slide, not a cut); the title, meta line, the
  switch's top edge and the list's top edge held within a pixel on every
  frame. Also Light and Dark screenshots of both switches and of the add
  button over scrolled rows, for the pause. **If the sort film shows the
  tear**, the orchestrator treats it as T003's case on the finished header
  (P4's fallback if not yet applied; a product question with the films if
  it was). **Added at the Phase 1 review:** before the final film, make the
  probe able to fail — exclude pixels adjacent to a brass pixel from the
  capsule so a protruding label no longer widens it — and show TEAR firing
  on T002's iOS 26.5 Dark film, frames 819–864 (the film file is in the
  scratchpad if it survives; otherwise re-film T002's Date → Market ↓ on
  26.5 at commit 930c90b to reproduce it); drop the unused
  `labelThreshold` argument. Only then film the finished header.
  Files: `scripts/motion-probe/profile.swift`, `scripts/motion-probe/README.md`
  (the Done note is the record for the films).
  **Verify:** the frame tables and verdicts in the Done note — the sort's
  per runtime and per switch, the switches' per control.
  **Done (2026-09-27, at 3eb39ce, app relinked after the commit).**
  **Probe made able to fail first:** `bg` mode excludes any pixel within 1
  px of a label pixel from the capsule; `labelThreshold` dropped; a new
  last argument `brass|light|dark` selects the label's colour class, since
  the finished header's label is the system's (white/near-black), not
  brass. Proof: on T002's 26.5 Light film frames 918–945 the changed probe
  fires TEAR 6 of 28 at thr 4 (20 of 28 at thr 8; e.g. f936 extent
  25.0–95.0, label 25.3–95.3, out 2 px) where the old probe read whole 28;
  on T003's clean 26.5 films TEAR 0 in 111 and 92 frames. On T002's 26.5
  **Dark** frames 819–864 it still reads whole: there the label ends *on*
  the rim column (26.3–94.7 in a 24.7–94.7 capsule) and nothing is past
  it — that finding was the extent (25–95) against the frame (13–108), the
  calibration column, never `out=`. README records all of it.
  **The sort on the finished header** (`-seedSold`, boxes 27.0 (226, 81,
  112 × 46), 26.5 (216, 81, 112 × 46); thr 27.0 Dark 10 / Light 20, 26.5
  Dark 4 / Light 24). **iOS 27.0: whole on every frame, 0 TEAR, all four
  switches, both appearances**; settled extents within 0.7 pt of XCUITest's
  frame; bare gap 87–100 ms. **iOS 26.5, Decision 18's transient on both
  narrow-to-wide switches, both appearances:** Date → Market ↓ the capsule
  holds Date's ≈69 pt under the 95 pt label from +0.38 s and snaps right at
  **+1.70 s** (Dark) / **+1.54 s** (Light); Name → Date sold holds Name's
  width and is right at **+1.78 s** (Dark) / +1.59 s (Light); every case
  self-corrects. Wide-to-narrow (Market ↓ → Date, Date sold → Name) clean
  on Dark; on **26.5 Light the wider capsule's shadow stays behind the
  narrow badge until the next tap** (left edge 34–36 against 39.3;
  `t009-26l-f41s.png`) — a second 26.5-only artefact the amendment does
  not name. **Both for the person at the pause:** the durations run a
  little past the "about 1.5 s" written into criterion 1's amendment.
  **The switches** (`-seedPlans`): a slide, not a cut, on all six —
  27.0 Items Owned → Sold 24 distinct pill positions over 0.40 s, Sold →
  Owned 26 / 0.43 s, Plans Active → Completed 25 / 0.43 s; 26.5 28 /
  0.62 s, 22 / 0.35 s, 24 / 0.43 s. Title, meta line, track top and list
  top: **0 px drift on every frame** on both runtimes (criterion 7). 24
  screenshots (`t009-{27,26}-{dark,light}-*.png`) and `t009-composite.png`
  in the scratchpad for the pause. Films `t009-film-*.mp4`.
  **Phase 3 closes here — pause for the person.**

**Phase 3 pause (2026-09-27).** The person: the switches look better but must use the app's colours and font — measured impossible on the system segmented control — and should leave their own row. Three homes rendered; the person chose the icon + word toggle (Decision 19), with the "Show" group in the "…" menu as the recorded fallback. The 26.5 Sort By artefacts passed without objection. Header margins to revisit after the toggle lands.

- [x] **T009a — The side toggle: a glass button in the header's control row (Decision 19).**
  New `Trove/Views/Shared/SideToggle.swift` replacing `SidePicker.swift`
  (deleted): a `Button` whose label is `HStack(spacing: 8) { Image(systemName:
  icon(side)).font(.system(size: 11, weight: .semibold)); Text(word(side))
  .font(SortMenuCopy.labelFont) }` in a hidden mono-11 line box like
  `OverflowMenu`'s so all three controls are one height; modifiers exactly
  `OverflowMenu`'s minus the circle: `.buttonStyle(.glass)`, `.tint(.primary)`,
  `.controlSize(.regular)`, 4 pt vertical label padding; action
  `select(other)`; `.accessibilityLabel` the existing "Owned or sold" /
  `SellPlanCopy.sideSwitchLabel`, `.accessibilityValue(word(side))`,
  identifiers `items.sideSwitch` / `plans.sideSwitch` kept; the two
  constrained inits carry words and icons (Owned `shippingbox`, Sold `tag`,
  Active `clock`, Completed `checkmark.circle`). Placement: leading of the
  sort control in the header's trailing `HStack` on Items and Plans (side,
  sort, "…"), the switch's own row and its spacing removed on both screens;
  the trailing `HStack` gets `.fixedSize(horizontal: true, vertical: false)`,
  `Spacer(minLength: 8)` before it and `.lineLimit(1)` on the title (the
  render pass found glass labels wrap otherwise). `ThemeTests` exemptions:
  `"SideToggle.swift": [".tint(.primary)"]`; `MenuPolicyTests` unchanged (no
  Menu). Tests: G10 rewritten onto `SideToggle` (a `Button`, `select(other)`
  as its action, no `@Binding`, `.glass`, no theme colour; one call per
  screen with `viewModel.show`, no `$`, outside the empty-state branch;
  words/labels/identifiers/icons checked as values through the inits;
  mutations: the action calling `select(side)` → red; `$viewModel.wrappedValue.side`
  → red; the call moved into the empty branch → red; a theme colour named →
  red). G1: `badgeRowSize` renders side + sort + "…"; three badges one
  height at 3× (mutation: the toggle's line box removed → red); the header
  relation re-pinned (title row now holds the controls; record the new
  numbers on both sides). G3 legs for the two identifiers. UI: every test
  that taps a segment (`buttons["Sold"/"Owned"/"Active"/"Completed"]`
  inside the switch) taps the toggle by identifier instead and reads the
  side from the toggle's `value` (record how XCUITest exposes it); the four
  `isSelected` reads become `value == "Sold"` etc.; `testAppearanceControl…`
  can return to `segmentedControls.firstMatch` (the Items switch is gone)
  or stay — say which. Files: `Trove/Views/Shared/SideToggle.swift` (new),
  `Trove/Views/Shared/SidePicker.swift` (deleted), `Trove/Views/Items/ItemListHeader.swift`,
  `Trove/Views/Items/ItemListView.swift`, `Trove/Views/Plans/PlansView.swift`,
  `TroveTests/ItemListSidesWiringTests.swift`, `TroveTests/PlansWiringTests.swift`,
  `TroveTests/ItemListHeaderLayoutTests.swift`, `TroveTests/HeaderControlsWiringTests.swift`,
  `TroveTests/ThemeTests.swift`, `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green (count
  recorded); mutations recorded; header heights on both sides; the person
  looks.
  **Done (2026-09-27).** `SideToggle<Side: Hashable>`: a `Button` acting
  `select(other)`, label = hidden mono-11 line box with the SF Symbol +
  word overlaid (`.frame(height: 0)`), `.glass` → `.tint(.primary)` →
  `.regular`, label/value/identifier; `SidePicker.swift` deleted. Items and
  Plans: the toggle leads the trailing `HStack`, the switch row gone, the
  wrap fix (`lineLimit(1)`, `Spacer(minLength: 8)`, `.fixedSize(horizontal:
  true, vertical: false)`). ThemeTests + `"SideToggle.swift":
  [".tint(.primary)"]`. G10 → `theSwitchIsAGlassToggleAskingForTheOtherSide`
  (values through the inits); G3 toggle legs; G1 `badgeRowSize(side:)`
  renders all three, `theTwoBadgesRenderAtOneHeight` →
  `theThreeBadgesRenderAtOneHeight` (four toggles vs "…" at 3×: all 109 px;
  Owned 79.0, Sold 73.7, Active 85.0, Completed 105.0 wide). Items header
  57 both sides (control row 200–228 × 37); Plans title row 37. UI: a
  `showSide(_:on:)` helper taps the toggle by identifier and waits on
  `value == side`; 19 taps and the four reads converted; the Appearance test
  keeps its "System" predicate. XCUITest exposes `.accessibilityValue` as
  the button's `value` string. Mutations, all red: `select(side)`
  (`ItemListSidesWiringTests.swift:465`); `$…wrappedValue.side` Items
  (`:311`) / Plans (`PlansWiringTests.swift:185`); the call into the empty
  branch Items (`:325`, and `ItemListHeaderLayoutTests.swift:342`) / Plans
  (`:194`); a theme colour (`:483`); the line box removed
  (`ItemListHeaderLayoutTests.swift:299`, all four; a plain `HStack` variant
  red for Sold only — the `tag` glyph is 1 px taller than the mono line);
  identifier dropped (`HeaderControlsWiringTests.swift:140`, `:479`); a hint
  added (`:144`). `scripts/verify.sh`: green, 1747 in 235. **`scripts/verify.sh
  ui`: 38 tests, 0 failures, 1002 s.** Notes: the search field keeps its
  section gap under the header; G39's UI check now measures the title row.

- [x] **T009b — The toggle between Sort By and the "…", brass on the primary side (Decision 20).**
  `ItemListView` and `PlansView`: the trailing `HStack` order becomes sort
  control · `SideToggle` · `overflowControl` (the sort control still inside
  its narrowing gate, so with an empty side the row is toggle · "…" and the
  toggle never moves relative to the "…"). `SideToggle`: `.tint(side ==
  leading ? theme.colors.accentBrass : Color.primary)` in place of
  `.tint(.primary)` — the file gains `@Environment(\.theme)` (copy
  `AddButton`'s way of reading it) and may name `theme.colors.accentBrass`
  for this one modifier; G10's "no theme colour" leg becomes "the tint is
  the ternary over `leading` with `accentBrass` and `.primary`, and no other
  colour is named" (mutations: the ternary inverted → red; a second theme
  colour named → red). `ThemeTests`' `SideToggle.swift` exemption entry
  updated to the new tint line's exempted text (`Color.primary` or
  `.primary` as spelled) — verify the stale-entry check still binds. G1's
  `badgeRowSize` renders the new order (heights unchanged: record). UI: the
  `showSide` helper is unaffected; run `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch`,
  G39's test and `testEmptyCollectionOffersImportAndSettingsButNotExport`
  alone. Files: `Trove/Views/Shared/SideToggle.swift`, `Trove/Views/Items/ItemListView.swift`,
  `Trove/Views/Plans/PlansView.swift`, `TroveTests/ItemListSidesWiringTests.swift`,
  `TroveTests/PlansWiringTests.swift`, `TroveTests/ItemListHeaderLayoutTests.swift`,
  `TroveTests/ThemeTests.swift`.
  **Verify:** `scripts/verify.sh` green; the three UI tests green alone;
  mutations recorded; the person looks. (Colour on the device is the
  person's look: `ImageRenderer` draws glass as a placeholder.)
  **Done (2026-09-27).** Row order sort · toggle · "…" on both screens;
  `SideToggle` reads the theme and tints `side == leading ?
  theme.colors.accentBrass : Color.primary`; G10 pins the whole ternary and
  exactly one `theme.colors`; the ThemeTests entry is `["Color.primary"]`
  and its stale check binds. New `theControlRowIsSortThenToggleThenOverflow`
  on Items and Plans (a view-body fact). `badgeRowSize` keeps the
  renderable order with an honest comment: `ImageRenderer` crashes on a
  glass `Menu` before a glass `Button` in an `HStack`, and an `HStack`'s
  size is order-invariant, so the numbers hold (rows 200–228 × 37, header
  57, all badges 109 px at 3×, unchanged). Mutations, all red: ternary
  inverted (`ItemListSidesWiringTests.swift:478`); a second theme colour
  (`:489`); the exempted text removed (`ThemeTests.swift:253`); toggle and
  sort swapped (`:335`, `PlansWiringTests.swift:231`). `scripts/verify.sh`:
  green, 1749 in 235. UI alone: the three named tests green (40 s, 22 s,
  23 s). Finding: `xcodebuild` sometimes hangs after a failing run — read
  the red from the log rather than wait for exit.

- [x] **T009c — The toggle's label swaps in one frame (the person's finding, 2026-09-27).**
  Filmed on 27.0 at 3f36b27: Owned → Sold crossfades the label — for 10
  frames (~0.10 s) "Owned" (brass) and "Sold" (primary) are drawn
  superimposed, the glyphs likewise, while the capsule's width slides; Sold
  → Owned is already a one-frame swap. Candidates filmed:
  `.contentTransition(.identity)` leaves a glyph overlap and a blank
  moment; `.id(side)` on the label is worse (0.44 s superimposed);
  `.animation(nil, value: side)` and `.transaction { $0.animation = nil }`
  both give a one-frame swap of glyph, word, tint and width with the glass
  capsule intact. Fix: `.animation(nil, value: side)` on the label `HStack`
  directly after `.frame(height: 0)` in `SideToggle.swift` — the narrowest
  of the two. G10 gains a leg pinning that line on the label row (an
  injection point only film can otherwise reach; mutation: the line
  removed → red). The diagnosis film of candidate (b) is the evidence
  (`tog-b.mp4`, f0249 → f0250); T013's device pass looks once more.
  Files: `Trove/Views/Shared/SideToggle.swift`, `TroveTests/ItemListSidesWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch` green alone; the mutation recorded.
  **Done (2026-09-27).** The line added with its comment; G10's new leg
  (`.frame(height: 0)` immediately followed by `.animation(nil, value:
  side)`); mutation: the line removed → red ("the toggle's label row isn't
  followed by …"). `scripts/verify.sh`: green, 1749 in 235. The UI test
  alone 40 s green.

- [x] **T009d — One width per toggle, and the swap animates (Decision 21; the person's findings, 2026-09-28).**
  Findings: on Plans, Active → Completed clips "Completed" ~0.17 s while
  the glass capsule grows (filmed at 61e7ca2; the capsule's resize runs
  outside SwiftUI transactions — `.animation(nil)`, `.transaction`,
  `.clipShape` all fail; only a constant width is clean), and the person
  sees no animation at all on tapping the toggle. Fix: the label's `ZStack`
  also lays out the other side's icon and word, hidden, so the capsule is
  the wider side's width on both sides, the visible row centred; T009c's
  `.animation(nil, value: side)` is replaced by the transition the film
  picked (2026-09-29, thirteen candidates on 27.0, the winner on 26.5
  too): the visible row carries its own `.foregroundStyle` (brass on the
  leading side, `Color.primary` on the trailing), `.id(side)` and
  `.transition(.blurReplace)`, under `.animation(.smooth(duration: 0.3),
  value: side)` on an inner `ZStack` — no two legible words superimposed,
  no clipping, the glass press intact on both runtimes; the person tried
  the installed build: "Ok looks great!". The film also settled that
  HEAD's press effect was never lost (a quick tap swells ~2 pt), so only
  the label changes. G1/G10 gain legs pinning one width per side
  on each screen and the hidden other-side row; the T009c leg is
  rewritten for the new transition. Mutations recorded.
  Files: `Trove/Views/Shared/SideToggle.swift`, `TroveTests/ItemListSidesWiringTests.swift`, `TroveTests/ItemListHeaderLayoutTests.swift`, `TroveTests/PlansWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; the film of the chosen transition on 27.0 and 26.5 both directions on both screens; the mutations recorded.
  **Done (2026-09-29).** A `row(_:)` helper; both rows hidden at height 0
  under the mono line; the showing row with its own `.foregroundStyle`
  ternary, `.id(side)`, `.transition(.blurReplace)`, in an inner `ZStack`
  at height 0 under `.animation(.smooth(duration: 0.3), value: side)`.
  The Button's `.tint` dropped: a probe rendered each toggle byte-identical
  with and without a foreign tint (the renderer does honour a glass tint —
  rust vs moss differ), so it reached nothing drawn; whether it ever
  coloured the press highlight is for T013 on the device. New G1
  `theSideToggleIsOneWidthOnBothSidesOfEachScreen` (each toggle alone at
  3×, exact): Owned = Sold = 237 px (79 pt), Active = Completed = 315 px
  (105 pt; Sold was 221); heights unchanged (109 px badges, 57 pt header).
  G10's toggle legs rewritten: `.buttonStyle(.glass)` directly followed by
  `.controlSize(.regular)`, no `.tint(`; both hidden rows; one ordered
  regex over row → ternary → `.id` → `.blurReplace` → `}` →
  `.frame(height: 0)` → the smooth animation; `animation(nil` absent.
  Mutations, all red: hidden leading row removed
  (`ItemListHeaderLayoutTests.swift:345` Items, `ItemListSidesWiringTests.swift:516`);
  hidden trailing row removed (`:345` Plans, `:516`); `.blurReplace` →
  `.opacity` (`:524`); `.id(side)` removed (`:524`); `animation(nil` put
  back (`:524`, `:528`); the smooth animation removed (`:524`); the ternary
  moved back onto `.tint` (`:508`, `:512`, `:524`). Each hidden-row
  mutation reds only the screen whose wider word is on that side, so the
  leg covers both screens. `scripts/verify.sh`: green, 1750 in 235.
  Finding: a full verify run is 5–7 min here; seven mutations ≈ 45 min.

- [x] **T009e — The header's title on the controls' bottom edge; the meta line centred (Decision 22; the person's finding, 2026-09-29).**
  Finding: with three glass controls in the row the meta line ("4 SOLD ·
  $3,200 · +$600 VS PAID") runs 6 pt under the buttons' bottom edge and
  reads as crowding them, while 24 pt sits between it and the search
  field; and the title is top-aligned with taller controls, so its
  baseline floats above their bottom. Fix, in `ItemListHeader.swift` and
  the three screens: the title row aligns the title's baseline to the
  controls' bottom edge (an alignment guide, not `.bottom`, which would
  put the descender there); the meta line gets equal space above and
  below — the space between the title row and the search field (Items,
  Wishlist) or the first row (Plans; Items' Sold side with nothing to
  narrow) is redistributed, its total unchanged so the search field and
  first row do not move by a point. Horizontal spacing untouched. G38's
  literal 6 and the 57 pt doc numbers follow the new geometry; G1's
  height legs are re-measured, not loosened; a leg pins that the search
  field's and the first row's y are unchanged (measured before and
  after at 3×, exact). Mutations recorded.
  Decision review (2026-09-29, after the implementer stopped): the
  alignment guide grows the row to 44 (a 7 pt descent) and moves Plans'
  first card, so the title row is a custom `Layout`; Plans has no meta
  line and uses the `Layout` directly; the Wishlist composes
  `ItemsListHeader` (its old stacked header goes) and its search field
  moves 4 pt to 81, level with Items' — put to the person; the empty
  Sold side splits 8/8; the split is one static function off a named
  constant. Plan §4's T009e paragraph has the geometry and the guards.
  Files: `Trove/Views/Items/ItemListHeader.swift`, `Trove/Views/Items/ItemListView.swift`, `Trove/Views/Plans/PlansView.swift`, `Trove/Views/Wishlist/WishlistView.swift`, `TroveTests/ItemListHeaderLayoutTests.swift`, the `private var header` scans in `ItemListSidesWiringTests.swift` and `PlansWiringTests.swift`, any Wishlist header scan in `HeaderControlsWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; the person's look at Items (both sides), Plans and Wishlist.
  **Done (2026-09-29).** `TitleRowLayout` (controls at ideal size, title
  in the remainder less 8 pt, height = max(controls, title first baseline)
  read at runtime, the descent hanging under the row); `enum
  MetaLineSpacing` (`titleRowToMeta = 6`, `split(before:)`) — a caseless
  enum because a generic type can't hold the static; `ItemsListHeader`
  gains `gapBelow`. Items and the Wishlist compose it, with
  `headerGapBelow` = `sectionGap` above a search field, `listRowGap`
  otherwise; the header carries the lower half as padding and the
  `listRowGap` bottom padding moved onto the inner search-and-chips
  stack (the outer one would have made the empty side 8/10). Plans uses
  the `Layout` directly. At 3×: row 111 px before and after; title
  baseline 79 → 111 px (on the controls' bottom); Items meta gaps 18/72 →
  45/45; Items search field 242 px unchanged; Wishlist search field →
  242; empty Sold side 24/24, empty state 200 unchanged; Plans first card
  156 unchanged; header 57 → 66 pt (37 + 15 + 14), no badges 53 → 55.
  New tests `theTitleRowIsTheControlsHeightWithTheTitleOnTheirBottomEdge`,
  `theMetaLineSitsMidwayAndWhatFollowsDoesNotMove`; G38's 6 is the split.
  Mutations, all red: the row reporting the title's full box
  (`ItemListHeader.swift:142` → `ItemListHeaderLayoutTests.swift:438`,
  `:509`, `:533`, `:210`, `:214`); the title top-aligned (`:104` → `:442`);
  the split + 1 (`:72` → `:509`, all three stacks); gaps 14/16 (`:44` →
  `:505`, `:210`, `:214`). `scripts/verify.sh`: green, 1752 in 235.
  Carried to T013: the empty Wishlist's empty state moves up ~4 pt
  (derived, not measured); the real controls are 36.33 pt, so device
  numbers sit ~1 px off the 37 pt stand-in's.

- [x] **T009f — The page title bigger, centred on the controls (Decision 23; the person's finding, 2026-09-29).**
  Finding: on the controls' bottom edge the title (line box 33 pt, caps
  ~20 pt) reads too small beside 36 pt glass controls. Fix:
  `TitleRowLayout` centres the title's line box on the controls' middle
  (the row still reports the controls' height, the title overhanging
  equally above and below, so nothing under the row moves); the screen
  title grows to 34 pt, or the largest whole size at which "Plans" is
  not truncated beside its three controls under the widest sort label
  at 402 pt width — measured, and the 375 pt behaviour reported. The
  ink (cap-height) centre's offset from the controls' middle is measured
  and recorded; over 1 pt returns to the orchestrator. Where the title's
  type is a shared token, every screen using it is listed in the report
  before it is changed. T009e's baseline leg becomes a centre leg; its
  row-height, equal-gaps and no-move legs stay green unchanged.
  Mutations recorded.
  First dispatch stopped (2026-09-29): the size rule as written gave
  20 pt — "Plans" already truncates at 30 under "Wishlist order" at 402
  (53 pt left, 78 needed); 34 truncates Items' Sold side and Plans on
  375 pt phones; the Dashboard's drill-down paths overflow at 34; and at
  34 the title's line box is exactly 37, so G38's "no badges is shorter"
  leg goes red. The person accepted three recommendations (Decision 23's
  amendment): Plans' capsule reads "Wishlist" for that order, the menu
  row unchanged; 34 pt with shrink-to-fit (`minimumScaleFactor`, one
  line, no ellipsis); the Dashboard keeps `screenTitle` at 30 and the
  list screens take a new token. G38's proviso leg is restated as the
  measured equality (no-badges header = title line box + split + meta),
  since "shorter" is no longer the geometry. The centring patch is at
  `scratchpad/T009f-centring.patch`.
  Files: `Trove/Views/Items/ItemListHeader.swift`, `Trove/Views/Shared/Theme/ThemeTypography.swift`, `Trove/Views/Plans/PlansView.swift`, `Trove/Views/Shared/SortMenu.swift` (a badge label distinct from the row label, if needed), `TroveTests/ItemListHeaderLayoutTests.swift`, tests and UI tests reading Plans' sort capsule label.
  **Verify:** `scripts/verify.sh` green; the person's look at Items, Plans and Wishlist.
  **Done (2026-09-29).** `TitleRowLayout` centres the title's line box
  and proposes it the remaining width; a shared `ListTitle` view (the new
  `listTitle` token, display semibold 34; one line;
  `minimumScaleFactor` 0.7 — the smallest scale needed is 0.744, Plans
  under "Wishlist" at 375) used by `ItemsListHeader` and Plans;
  `screenTitle` stays 30 for the Dashboard. `SortMenu.badgeLabel`
  (optional, defaulting to `label`) and `ActiveSortOrder.badgeLabel`
  ("Wishlist" for the wishlist order); VoiceOver still says "Sort by
  Wishlist order". At 402 every title is full size (Plans' rows 253 /
  240 / 227 / 150 leave 93–196 for 88.67); at 375 Plans under "Wishlist"
  draws at ~25 pt, Items' Sold side at ~33.4, none truncated. Header 66
  with or without badges (37 + 15 + 14); search field 81, Plans' first
  card 52, unchanged. G38's proviso is the measured equality. New:
  `theTitleRowIsTheControlsHeightWithTheTitleCentredOnThem` (a stand-in
  8 pt taller, since at 34 the line box equals the row),
  `everyListTitleIsFullSizeOnA402PointPhone`,
  `theTitleShrinksToFitRatherThanTruncatingOnA375PointPhone` (a recording
  `TextRenderer` reading `Text.Layout.isTruncated`, plus ink-before-controls),
  `theCapsuleShortensOnlyTheWishlistOrder` (pure),
  `theActiveCapsuleReadsTheShortLabel` (scan: which menu gets it).
  Mutations red: title bottom- or top-aligned (`ItemListHeader.swift:135`
  → `ItemListHeaderLayoutTests.swift:493`); the row reporting the title's
  height (`:173` → `:489`); `minimumScaleFactor` removed (`:81` → `:682`,
  `:691`); the badge label reverted three ways (`PlansViewModel.swift:53`
  → `PlansViewModelTests.swift:496`; `SortMenu.swift:91` → `:623`, `:627`,
  `:683`; `PlansView.swift:218` → `PlansWiringTests.swift:275`). **Not
  red: the token back to 30** — nothing honestly pins 34; carried to T011
  as a relation leg (`listTitle` renders taller than `screenTitle`).
  `scripts/verify.sh`: green, 1756 in 235. Ink centre (the Verify gate):
  measured in the first dispatch from the pixels of "I" at 34 pt, ink
  rows 80…149 against the controls' 60…170 at 3× — 0.5 px (0.17 pt)
  above the controls' middle, within the 1 pt gate; the same at every
  size tried (30–36: 0.5–1.5 px). Carried to T013: the real controls are
  36.33 pt, so the 37 pt line box overhangs a third of a point each
  side; the recorder's odd case at a 26 pt proposal.

**Phase 3 pause (2026-09-27 → 30).** The person tried the app seven times: the switches monochrome, in the wrong font, and taking a whole row (→ Decision 19, T009a, after the segmented control proved unstyleable); the toggle's place and brass (→ Decision 20, T009b); the label crossfade overlap (→ T009c); "Completed" clipping on Plans, and "removing the animations entirely isn't a good choice" (→ Decision 21, T009d: "Ok looks great!"); the meta line crowding the controls (→ Decision 22, T009e, the Wishlist search field's move accepted: "That's fine"); the title too small beside the controls (→ Decision 23, T009f, the three measured recommendations accepted); then: "continue". R2 (tapping the showing side no longer reloads it) is moot: the toggle always flips. Phase-end UI run at c1f3d4e (the code as of T009f): `scripts/verify.sh ui` 38/38 in 1017 s.

## Phase 4 — Retire the bespoke code; the policy and the documents · walkthrough: none — deletes files nothing calls since Phase 3, rewords one example in `CLAUDE.md`, rewrites the policy guard and edits the two design documents; nothing on screen changes

- [x] **T010 — Delete the bespoke controls and the tests that guarded only them.**
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
  **Done (2026-09-30).** Nine files deleted (no `.pbxproj` edit: the
  project uses file-system-synchronized groups); `dropdownGap` gone with
  its stale "60 = …" comment; eleven files' comments and names corrected
  (history kept as "the bespoke '…' badge", live sentences as
  `OverflowMenu`). Grep: 130 lines in 20 files before → 0 after; one
  remaining substring hit is `AppRouterTests.showingTheSoldSideSwitchesTabsAndAsksForIt`,
  a `006` name whose "Switches" is the verb — kept. G3's last leg walks
  `Trove/Views` for `.accessibilityHint("Opens`; mutation: the hint put
  back on `SortMenu.swift:108` → red (`HeaderControlsWiringTests.swift:165`).
  `DestructiveColourPolicyTests` unedited: 15 sites in 9 files before and
  after — exactly at its floors. Carried notes done: the T005 paragraph
  (36 vs 37 at 1× is a rounding; 109 px at 3×), the "system's control
  size" phrase (it was in the test file's proviso comment). Left:
  `design/tokens.md` still names the retired types (→ T012);
  `DetailOverflowMenu.swift`'s "the app's one system menu" (→ T011).
  `scripts/verify.sh`: green, 1734 in 231 (the four suites gone).

- [x] **T011 — The policy guard, inverted.**
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
  **Added at T004b:** `NoHardcodedColorsTests`' two scans use
  `.wordBoundaryKind(.simple)` (or an explicit `[^A-Za-z0-9_]` boundary) so
  `Color.primary.opacity(0)` and `.foregroundStyle(.red.opacity(0.5))` are
  caught; mutation: `.background(Color.primary.opacity(0))` in a view → red.
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
  **Done (2026-09-30).** The `CLAUDE.md` step committed alone first
  (`git show --stat`: `CLAUDE.md` only). `MenuPolicyTests` is G12a–d: roots
  derived from `ContentView`, each root's `overflowControl` composing
  `OverflowMenu(` and its `sortControl`/`orderControl` composing `SortMenu(`
  or a system `Menu`; `SideToggle` a `Button` with no `Menu`; no anchor
  preferences under Views/App; glass in exactly the four files once each;
  no appearance proxy, no `.confirmationDialog`. Plan §7's "Menu { Picker("
  for the Dashboard is stale — the shipped `orderControl` is Toggle rows
  (Q8), so no `Picker(` match exists there. Six doc comments corrected,
  plus two more the implementer found (`SoldStateWiringTests`,
  `TroveUITests:2008`, by the orchestrator). Carried items done: colour
  scans on `.wordBoundaryKind(.simple)`; exemptions as exact per-line
  counts with comments cut; `ExportWiringTests` counts every
  Button/Menu/Toggle against the listed rows; `listTitle` taller than
  `screenTitle` (111 vs 98 px); the screens' `split(before:
  headerGapBelow)` padding scanned; G38's equality mutated; the toggle's
  brass by side rendered (Owned 901 / Sold 0 / Active 809 / Completed 0
  px); the Wishlist-empty midway case (24/24, 200 px). Not added: an
  `XCTAssertFalse` on the toggle reads — they are `value` equalities, so
  a second assert could never fail alone. Report only: Plans' capsule
  speaks "Sort by Wishlist order" while showing "Wishlist" (→ T013 Voice
  Control). Thirteen mutations, all red, messages in the implementer's
  report (tier log). `scripts/verify.sh`: green, 1740 in 231. Findings:
  an exempted line can still hide `Color.primary.opacity(0.5)` (the
  count stays 1); the colour scans now share `SourceScan`'s
  `//`-in-a-string blind spot.

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
| Implementation session (this spec, from T001) | `claude-fable-5-1` at medium effort | orchestrating seat, not measured separately | Opened 2026-09-24 at the person's instruction on Fable 5.1 at medium, a per-session pick from the app's picker (the Opus profile names `claude-opus-5-5` for the seat); not a role-table change. Every dispatch runs with no model override, per the table |
| `sdd-implementer` — T001 (first pass) | `opus` | ~148k (subagent total) | Built SortMenu, Items' sortControl, G2/G3/G6, the narrowed legs and the UI test rewrites; unit suite green (1748). **Stopped on a judgment call**, correctly: plan Q8's pre-authorised stop (an inline `Picker` in a `Menu` draws no header and no subtitle on iOS 27.0) and a second finding (a glass `Menu` in the header's `VStack` crashes `ImageRenderer`, so G1 could not be rewritten). G1's three mutations not re-run; control size `.regular` shipped on separate badge and title renders (`.regular` 102×29, `.small` 98×25, title line box 33) |
| `skeptical-reviewer` — decision review at T001 | `opus` | ~52k (subagent total) | Q8: `Section` of `Toggle` checkmark rows (header, subtitle and Selected trait all present on the probe; three device checks added to T002). G1: a stand-in sized from a render of the badge row alone, no self-satisfying leg, a `.large` mutation added. Both blocking as things stood; transcribed into plan §1, Q8, §3, §11 and here before T001 resumed |
| `sdd-implementer` — T001 (resumed on the decisions) | `opus` | ~162k (subagent total, includes the first pass) | Done; unit suite green (1748); the named UI tests green alone; mutations recorded in the Done note |
| `skeptical-reviewer` — T001 per-task review | `opus` | ~84k (subagent total) | **approved**, eight notes, none blocking, carried in the Done note. One on the orchestrator: the bundle pasted the implementer's whole transcript file (~990 KB) instead of its final message — future bundles carry the final report only |
| `general-purpose` — T002 film (probe extension, four films, menu checks) | `opus` | ~307k (subagent total; three probe drafts before the mode could fail) | Tear absent on 27.0, present on 26.5 as a stale-width capsule → T003 runs (P4). Probe `bg` mode and README committed with T002 |
| `sdd-implementer` — T003 | `opus` | ~54k (subagent total) | Done; G1 one-width leg red under mutation; unit suite green (1749) |
| `general-purpose` — T003 re-film (same agent as T002, resumed) | `opus` | ~289k (subagent cumulative, includes T002) | Whole on every frame on 27.0 and 26.5, both appearances; P4 shipped |
| `sdd-implementer` — T004 | `opus` | ~101k (subagent total) | Done; unit 1749 green; UI suite 36/36 at the phase's final commit; mutations recorded |
| `skeptical-reviewer` — Phase 1 review | `opus` | ~104k (subagent total) | **fix and re-review, documents only**: the probe's TEAR verdict cannot fire (a protruding label widens the measured capsule), so the films' claim is restated onto the settled-extent check and the viewed frames (plan §1 As built, T003's Done note) and T009 gains a make-the-probe-fail step. Notes carried: G1's `badgeRowSize` should render the side's real options (T005); G2's no-colour check also bans `.foregroundStyle(`/`.tint(` in the file (T005); the UI sort helper counts each row exactly once and both helpers use the same "Sort by" query (T005); the 26.5 subtitle exposure told to the person |
| `skeptical-reviewer` — Phase 1 re-review | `opus` | ~108k (cumulative) | **approved**; one wording note applied ("the named frames viewed by eye") |
| `sdd-implementer` — T004a (first pass) | `opus` | ~65k (subagent total) | Part (b) done and verified; stopped on a judgment call, correctly: Decision 15's `.foregroundStyle(.primary)` trips `NoHardcodedColorsTests` |
| `skeptical-reviewer` — decision review at T004a | `opus` | ~33k (subagent total) | A named per-file, per-line exemption with a stale-entry check (a recorded exception to `004`'s rule); dodging the scan's wording and `.tint(nil)` rejected. Transcribed into plan R3 and T004a |
| `sdd-implementer` — T004a (resumed) | `opus` | ~65k + resumed pass (subagent cumulative not reported) | Done; unit 1749 green; the two UI tests green alone; five mutations recorded |
| `general-purpose` — diagnosis on device (T004a's colour not taking; size candidates rendered) | `opus` | ~115k (subagent total) | `.foregroundStyle` ignored by the glass style; `.tint(.primary)` + `Color.primary` bars verified by pixel in both appearances; four size crops for the person, who chose C → T004b |
| `sdd-implementer` — T004b | `opus` | ~87k (subagent total) | Done; unit 1749 green; both UI tests green alone; four mutations recorded; one pre-existing guard gap found and carried to T011 |
| `sdd-implementer` — T005 (first pass) | `opus` | ~206k (subagent total) | Built everything; stopped on two judgment calls, correctly: the "…" renders ⅓ pt shorter than the sort badge (a literal 14 vs the mono line box), and iOS 27.0 ignores `.disabled` on a nested `Menu` (criterion 2 red on Items) |
| `skeptical-reviewer` — decision review at T005 | `opus` | ~52k (subagent total) | (1) a hidden mono-11 line box sets the glyph row (overlay, so the spinner can't grow it); G1 compares at 3× exactly, tolerance rejected. (2) a disabled `Button` stands in for an empty format's submenu — routine, inside the footprint; the missing chevron noted for the pause. Transcribed into plan §2, Q9, §11 |
| `sdd-implementer` — T005 (resumed) | `opus` | ~206k + resumed pass | Done; unit 1749 green; six UI tests green alone; every mutation recorded |
| `sdd-implementer` — T006 | `opus` | ~72k (subagent total) | Done; unit 1749 green; UI suite 37/37 at the phase's final commit; four mutations recorded |
| `skeptical-reviewer` — Phase 2 review (T004a, T004b, T005, T006) | `opus` | ~122k (subagent total) | **approved**, seven notes, none blocking. Carried: (T010) `ItemListHeaderLayoutTests`' T005 doc paragraph re-measured to the 109 px equality, `ItemListHeader.swift`'s "system's control size" phrase, T005's Done note names `SortMenu.swift` and `ThemeTests.swift` as touched (authorised by the decision review and R3); (T011) the theme-colour exemption matches an exact count of code lines with comments skipped, and `ExportWiringTests.rowStart` also asserts no `Button`/`Menu`/`Toggle` other than the listed rows; (T013) the ten device checks the review lists — the "…" glyph and spinner colour, the busy capsule's size and inertness, the share sheet after a scope row, Import from the menu, one badge height and a 57 pt header that holds across a switch, the order label's quiet colour and tap area (`.contentShape` went with `.buttonStyle(.plain)`), checkmark colour consistency between the sort and order menus, the chevron-less disabled row, VoiceOver traits, and the sort tests' collection-view shape on 26.x |
| `general-purpose` — Phase 2 diagnosis on device (circle, text-sized capsule, 26.5 behaviour, `.id` mitigation filmed) | `opus` | ~169k (subagent total) | The look measured; the 26.5 transient (41 pt for 1.1 s, then a snap) filmed; `.id(selection)` removes it but kills the morph on both runtimes. The person kept the morph and accepted the transient → Decision 18, T006a |
| `sdd-implementer` — T006a | `opus` | ~75k + resumed pass | Done; stopped once on the untestable circle diameter, settled by T005's no-tolerance ruling (verified on device instead); unit 1749 green |
| `sdd-implementer` — T007 | `opus` | ~93k (subagent total) | Done; unit 1746 green; thirteen switch-driving UI tests green alone; six mutations recorded |
| `sdd-implementer` — T008 | `opus` | ~83k (subagent total) | Done; unit 1747 green; UI suite 38/38 at the phase's final code commit; four mutations recorded |
| `general-purpose` — T009 films (probe made falsifiable, four sort films, two switch films) | `opus` | ~266k (subagent total) | 27.0 whole on every frame; 26.5 transient 1.54–1.78 s and a stale shadow on Light — both to the person; switches slide with 0 px header drift on both runtimes |
| `skeptical-reviewer` — Phase 3 review (T006a, T007, T008, T009) | `opus` | ~100k (subagent total) | **approved**, nine notes, none blocking. To the person at this pause: the 26.5 transient's 1.54–1.78 s against "about 1.5 s", and the stale shadow on 26.5 Light (not transient, not named by Decision 18); R2 in plain words. Carried: (after the person answers) `SortMenu.swift`'s doc and plan §1 restated from T009's numbers, the amendment widened if accepted; (T010) plan §1 names Light 918–945 as the probe's proof and says a mid-transient wrong width with the label inside the rim is caught by the extent-vs-frame read, not TEAR; the README records the TEAR count on the 26.5 transient frames at the classes/thresholds actually used; the no-`$` legs' docs say the compiler is the guard and plan §11's G10 mutation column is corrected; the circle leg kept in G4 only; (T011 or T010) the four `isSelected` UI reads gain an `XCTAssertFalse` on the other segment; (T013) the circle's diameter on 27.0 and 26.5 (the README saw 46 wide on 26.5), the add button's frame on 26.5, the brass disc and plus contrast, rows under the button, the root tint on the segmented control, the switches at the largest text size, Reduce Motion on the slide; (close-out) the spec's "Add to wishlist" prose corrected to "Add wanted item" |
| `general-purpose` — Phase 3 diagnosis (segmented control colour/font probes; four placements) | `opus` | ~170k | The system segmented control takes no font, colour or tint from SwiftUI; placements C/D rendered |
| `general-purpose` — three homes for the switch rendered | `opus` | ~135k | Icon toggle, "…" menu group, "Show" capsule; the person chose the icon + word toggle (Decision 19) |
| `sdd-implementer` — T009a | `opus` | ~142k (subagent total) | Done; unit 1747 green; UI 38/38; ten mutations recorded |
| `sdd-implementer` — T009b | `opus` | ~89k + resumed pass | Done; stopped once on the render instrument's order (settled by the standing stand-in ruling; an order scan added); unit 1749 green |
| `general-purpose` — toggle transition filmed, four fixes tried | `opus` | ~135k | The overlap confirmed (10 frames); `.animation(nil, value: side)` recommended → T009c |
| `sdd-implementer` — T009c | `opus` | ~35k | Done; unit 1749 green |
| `general-purpose` — Plans clipping filmed, five fixes tried | `opus` | ~165k | Only a constant width is clean; the capsule resize runs outside SwiftUI transactions → Decision 21 |
| `general-purpose` — T009d films (HEAD's press effect; thirteen swap candidates; 26.5) | `opus` | ~183k | The press was never lost; per-row colour + `.blurReplace` at `.smooth(0.3)` recommended and installed; the person: "Ok looks great!" |
| `sdd-implementer` — T009d | `opus` | ~70k | Done; unit 1750 green; seven mutations recorded; tint dropped on a render probe |
| `general-purpose` — three header tightenings rendered | `opus` | ~88k | The person kept the horizontal spacing and asked for the title on the controls' bottom edge and the meta line centred → Decision 22 |
| `sdd-implementer` — T009e, first dispatch | `opus` | ~82k | **Stopped on a judgment call**: the 7 pt descent under baseline alignment; Plans has no meta line; the Wishlist's old header shape. Tier miss: the bundle's premises were the orchestrator's arithmetic, not read from the code |
| `skeptical-reviewer` — decision review, T009e | `opus` | ~46k | A custom `Layout`; Plans uses it directly; 8/8 on the empty side; one split function; the Wishlist search field's 4 pt move put to the person (accepted) |
| `sdd-implementer` — T009e, re-dispatch | `opus` | ~110k | Done; unit 1752 green; four mutations recorded |
| `sdd-implementer` — T009f, first dispatch | `opus` | ~92k | **Stopped on a judgment call**: the fit rule gave 20 pt; small-phone truncation; the Dashboard paths; G38's proviso at 34. Three product questions to the person, all accepted as recommended |
| `sdd-implementer` — T009f, re-dispatch | `opus` | ~190k | Done; unit 1756 green; mutations recorded, one (the token at 30) not red and carried to T011 |
| `skeptical-reviewer` — Phase 3 re-review (T009a–T009f) | `opus` | ~115k | **fix and re-review**: plan §4 still the segmented design; no phase-end UI run recorded. Both fixed (plan rewritten by `sdd-implementer`, ~90k; UI 38/38 at c1f3d4e). Second look and carried notes in the re-review row |
| `skeptical-reviewer` — Phase 3 re-review, second pass | `opus` | ~40k | **signed off**. Fixed directly: G15's "ThemeTests unedited" and G12c's body (four files). Second look, carried: (T011) the `listTitle` > `screenTitle` relation leg; a leg for the screens' `split(before: headerGapBelow)` padding (the no-move test renders a copy of the stacking); a mutation against G38's restated equality; a pixel leg for the toggle's brass-by-side; a Wishlist-empty render case; `SortMenu`'s spoken label reads `label` (Voice Control label-in-name: visible "Wishlist" vs spoken "Wishlist order"); plan G13's `showSide` reads have no recorded mutation. (T012) `listTitle`/`screenTitle`, the toggle's colour, width and blur, `TitleRowLayout`, the split rule, the short capsule label. (T013) the ink centre on device, the press highlight without `.tint`, 36.33 vs 37, the empty Wishlist's position, 375 pt at larger Dynamic Type (`TitleRowLayout` can propose zero width), the recorder's 26 pt case, the blur on both runtimes |
| `sdd-implementer` — T010 | `opus` | ~70k | Done; unit 1734 in 231 green; grep 130 → 0; G3 mutation red |
| `sdd-implementer` — T011 | `opus` | ~200k | Done; unit 1740 in 231 green; thirteen mutations red (plan §7's five and eight for the carried legs) |

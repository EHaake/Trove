# 014 — Sold-Side Parity and Mark as Sold on the Swipe: Tasks

**Status**: **Signed off** (2026-09-16) — drafted by the `sdd-planner` at the top tier, reviewed by the `skeptical-reviewer` at the top tier: three blocking findings (a hidden-narrowing leak into the Owned empty state, by-eye simulator steps in three tasks, a tie-break guard that could not reliably go red) fixed and re-reviewed in one round, verdict sign off. Awaiting the person's approval of the spec-conformance summary.

Drafted against the approved `spec.md` (Approved 2026-09-16) and the draft
`plan.md` in this directory, for branch `014-sold-side-parity` off `main`
(`1aeb741`). No new technical decisions are made here — every call below
traces to a plan section; where a task says "per plan," that section is the
authority. Runs under **experiment 1**: the planner and the sign-off at
`fable`, the `skeptical-reviewer` on phase and marked-task reviews and the
`sdd-implementer` at `opus`, the session at `fable` medium; the tier log
records what actually ran.

**Foundational phase**: **Phase 1** (T001–T005) — the `006` pointers, the
Sold sort, the per-side state every control and both exports read, the export
rule, and the list's sale intent the swipe needs. **Tasks marked `review:
per-task`**: **T003** (per-side state on `ItemListViewModel` — every view
task, both empty states and both exports inherit its property semantics) and
**T004** (the CSV/PDF rule from either side — `013`'s byte identity and the
coverage label's truth rest on it, and a wrong order here reaches files the
person keeps). Every other task gets the default one review per phase. An
orchestrator left to guess guesses "all of them" — these two are the ones
marked.

Ordering note, recorded up front: the `006` documents are pointed at this
spec first, so the superseded rules are marked before any code reverses
them; then the view model, bottom-up — the sort (self-contained), the state
it is applied to, the exports over that state, the sale intent — with every
test that pinned a `006` rule rewritten in the task that reverses it, never
in a later one. Views come after the view model (Phase 2 after Phase 1): the
header first, since the swipe task and the UI tests read its gate; the sold
page's mark is independent and lands before the UI tests so they run against
the final layout. No design pass (spec Decision 5): the tint, glyph and
labels are settled in `plan.md` Q4/Q9 and the device pass checks them.

House rules carried over: one commit per completed task, referencing the task
ID; every guard test is **mutation-verified** (break the rule deliberately,
confirm red) before it lands, and the Done note records what was broken and
what went red; a task is not done until `scripts/verify.sh` is green and its
actual output is reported (suite-level `-only-testing`, test count checked —
per-function selectors run zero tests and report success); persisted-state
assertions refetch on a **second `ModelContext`**; **every new or rewritten
source scan asserts its anchor was found** before asserting anything about it
(`#require` on the anchor's count, the `ItemListSidesWiringTests` shape), so
no scan can pass over a file that lacks the thing it guards; **a test that
changes meaning is rewritten to pin the new rule, never loosened** — the plan
names each one (Q12). The one new asset lands inside the existing catalogue —
**no `.pbxproj` edit** anywhere in this spec; if the build cannot see the
image, stop and flag. **No test opens a network connection** (nothing here
needs one).

Cadence (per `CLAUDE.md`'s model policy, experiment 1): each dispatch gets a
**task bundle** assembled with shell — task line, plan section, acceptance
criteria, files, pattern file — and the implementer is told not to read
`plan.md`/`spec.md`/`tasks.md` in full; verification is `scripts/verify.sh`
and nothing more verbose, re-run by the orchestrator for the two `review:
per-task` tasks and taken from the implementer's verbatim output otherwise;
the `skeptical-reviewer` reviews per phase (and the two marked tasks), one
review and at most one re-review each, on a bundle cut after `git add -A`;
**one implementation session for the whole spec** — a phase pause is a pause
in it, the person attests and says continue, and only a session-ending pause
gets a continuation prompt; the device pass runs in a `general-purpose`
agent at the implementation tier (the `sdd-implementer` has no simulator
tools). Everything the person reads is plain language.

Handoff notes for the pause reports, so the orchestrator doesn't have to
rediscover them: **Phase 1 has nothing to try** — the report may say so and
offer to run straight on to the screens. **The Phase 2 report lists what can
be tried** (swipe an owned row to the right and tap Sell; search, filter and
sort the Sold side; leave a search on one side, visit the other and come
back; open a sold item's page) and says three things the person will feel
before they read them: the swipe's button reads **"Sell"** while VoiceOver
calls it "Mark as sold…" (the fuller name does not fit the button); a CSV
exported from a Sold side narrowed by a chip **also narrows the owned rows**
to that category (the spec's own rule, P11 — the file follows whatever is on
screen); and the Sold side's summary line **counts only the rows on screen**
while the Dashboard's card keeps counting everything sold. **One thing the
spec did not say, which the person decides at that pause**: the PDF exported
from a narrowed Sold side follows that narrowing too, owned items only, with
the same label (plan R2) — the report puts it as a question, not a fact.

## Phase 1 — Foundations, view model only (**foundational**)

- [x] **T001 — The `006` pointers (docs only).**
  Per plan §9 and the spec's Inherited caveats. In
  `specs/006-mark-as-sold/spec.md`, append a one-line pointer — *"Superseded
  by `014-sold-side-parity` (its spec, Decision N / P-item): …"* — at
  Decision 4 (Mark as sold… not on the swipe), criterion 1 (the swipe does
  not offer it), P16 (Sort By hidden on the Sold side) and the Non-goals
  bullet "Sorting, filtering or searching the Sold side". In
  `specs/006-mark-as-sold/plan.md`, the same at Q15 (changing side clears
  every narrowing), G33's table row, §4's sentence "on the Sold side
  `narrowed` is the identity, because `show(.sold)` cleared the three
  fields", and Q5's clause "Because changing side clears every narrowing
  (Q15)". Appended after the existing text, nothing above edited; `006`'s
  Decision 16 already records the deferral and stays. Pattern: the italic
  pointer `006`'s T007 appended to `specs/011-data-export/plan.md`.
  Files: `specs/006-mark-as-sold/spec.md`, `specs/006-mark-as-sold/plan.md`.
  **Verify:** `grep -c "Superseded by \`014-sold-side-parity\`" specs/006-mark-as-sold/spec.md`
  prints 4 and the same over `plan.md` prints 4 — the pointer's own phrase,
  so Decision 16's existing mention (which cites `NEXT-sold-side-parity.md`,
  not this directory) is not counted; `git diff --stat` touches only those
  two files.

- [x] **T002 — `SoldSortOrder` and its comparators.**
  Per plan §2 and Q4. `ItemListViewModel.SoldSortOrder` (eight cases in menu
  order, `label`, `id`), `soldSortOrder: SoldSortOrder = .soldDate`, the
  **static** `areInSoldOrder(_:_:under:)` = `soldAttributeOrder(_:_:under:)
  ?? areInSoldOrder(_:_:)` with the private instance `isInSoldOrder(_:_:)`
  calling it under `soldSortOrder`; the attribute comparators nil-on-tie and
  nil-last for the two optionals; `load()` sorts `soldItems` with
  `isInSoldOrder` (the rest of `load()` is T003's). The two-argument
  `areInSoldOrder` untouched. Pattern: `SortOrder` and `attributeOrder(_:_:)`
  in the same file; `WishlistViewModel.SortOrder` for the labelled-pair
  convention. Tests: new `TroveTests/SoldSortOrderTests.swift` — it joins the
  target through the synchronized `TroveTests` folder as every new test file
  since `010` has; **stop and flag if the suite is not in the run's count**
  — G1 (labels, case order, default by literal), G2 (plan §2's four-row
  fixture, one `@Test(arguments:)` over the eight cases with the expected
  name order per case, through `load()` — mutations: delete the price
  comparator (fall to standing) → the Price cases red; reverse it → red;
  read `purchasePriceCents` in the gain case → the Gain cases red), G3
  (**the static comparator asked about Drum and Bass directly, in both
  argument orders**, under `.salePriceDescending` — `true` then `false` —
  never through a fetch, whose order the test does not control; mutations:
  `?? false` in place of the standing order → red; tie-break by name → red);
  the nil-last arm recorded as defensive. `insertSold`'s existing helper
  takes paid, sale price and date.
  Files: `Trove/ViewModels/ItemListViewModel.swift`,
  `TroveTests/SoldSortOrderTests.swift` (new).
  **Verify:** `scripts/verify.sh` green; the G2 and G3 mutations recorded.

- [x] **T003 — Per-side state: `Narrowing` ×2, the computed narrowing properties, `show` without clearing, chips, summary, gate, empty reason. `review: per-task`.**
  Per plan §1, §3 and Q1–Q3, Q5–Q7. `struct Narrowing`, private
  `ownedNarrowing`/`soldNarrowing`, the side-switched `narrowing`
  accessor; `categoryFilter`/`searchText`/`showsOnlyUnvalued` as computed
  get/set over it (the un-valued setter refusing on Sold, Q2); `show(_:)` =
  set side + `load()`; private `owned`/`sold` halves kept; `soldTotalCount`;
  `ownedCategoryOptions/Labels` + `soldCategoryOptions/Labels` built in
  `load()` with `categoryOptions`/`categoryLabels` computed over the side;
  `offersNarrowingControls`; `visibleSortLabel`; `narrowed(_:by:)` taking
  the narrowing; `items` under `ownedNarrowing`, `soldItems` under
  `soldNarrowing`, `soldTotals` over the narrowed `soldItems` (P4);
  `ownedEmptyReason` reading `ownedNarrowing` by name **and its
  Everything-sold guard reading `soldTotalCount > 0`, not
  `!soldItems.isEmpty`** (plan §1 — `soldItems` is narrowed now, and a
  no-match query left on Sold must not turn an emptied Owned side into a
  first launch); `soldEmptyReason` through `reason(...)` with
  `.nothingAdded` → `.nothingSold`;
  `ListEmptyReason.nothingSold`'s comment corrected (the case *is* chosen
  after `reason(...)` now). Doc comments on the class and on `show` updated
  — they describe Q15. Pattern: `ownedEmptyReason` (the mapping shape);
  `WishlistViewModel` for the mirror. Tests (`ItemListViewModelTests`):
  **rewrite** `switchingToSoldClearsEveryNarrowing` and
  `switchingBackToOwnedClearsEveryNarrowingToo` into G4's round trip (both
  directions, four Owned values and three Sold values kept, `items` /
  `soldItems` narrowed by their own side's — mutations: the old clears back
  in `show` → red; one shared `Narrowing` → red); extend
  `aFreshViewModelOpensOnOwned` with G5; G6 (the refused un-valued write);
  G7 (Sold chips from the sold half; Owned's unchanged; the getter follows
  the side — mutation: build both from `all` → red); G8 (the gate's three
  cases); G9 (**extend** `theSoldSidesEmptyStateIsNothingSoldOrStillSyncing`
  with the query, chip, importing-with-query and stale-query cases —
  mutation: pick the case without `reason(...)` → red); G10 (the summary
  over a narrowing matching one, then none → "0 sold · $0" — mutation: sum
  over `sold` → red); **G25** (one sold, none owned: `show(.sold)`,
  `searchText = "zzz"`, `show(.owned)` → `.everythingSold`; a never-sold
  collection → `.nothingAdded` — mutation: the guard reading
  `soldItems.isEmpty` → red). `askingForTheSideAlreadyOnScreenLeavesTheFilterAlone`,
  `reorderingIsRefusedOnTheSoldSide` and `006`'s G13/G14 tests (the split
  and the standing order) stay green as written — confirm, don't edit.
  Files: `Trove/ViewModels/ItemListViewModel.swift`,
  `Trove/Models/ListEmptyReason.swift` (comment), `TroveTests/ItemListViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every
  mutation recorded; the two rewritten tests named in the Done note with
  what they now pin.

- [x] **T004 — Exports from either side: `exportableOwnedItems`, `exportableSoldItems`, the two gates, the PDF. `review: per-task`.**
  Per plan §4, Q8 and R1/R2. The two exportable sets under the on-screen
  narrowing (owned: `items` itself on Owned — one computation, `exportCSV`'s
  "built from `items` as-is" stays literally true — and the Custom-sorted
  narrowed owned half from Sold; sold always `areInSoldOrder`);
  `canExportCSV`/`canExportPDF` over them;
  `exportCSV` writes the first then the second; `exportPDF` builds entries
  and cover over `exportableOwnedItems` through one private `figures(over:)`
  the header's three figures also read; `exportCoverageLabel` unchanged in
  spelling. Pattern: today's `exportableSoldItems` and `exportCSV`;
  `SettingsViewModel.everythingInCustomOrder` for the Custom sort. Tests:
  `ItemListViewModelTests` "the CSV's two halves" gains G11 (from Sold under
  Sold's chip, Owned's chip and query set and inert — mutation: read
  `ownedNarrowing` → red), G12 (from Owned with a query left on Sold),
  G13 (`soldSortOrder = .salePriceAscending`, the CSV still date-desc —
  mutation: write `soldItems` → red), G15 (the PDF from a narrowed Sold
  side — mutation: read `items` → red), G16 (a Sold chip excluding every
  owned row: CSV yes, PDF no); `SettingsViewModelTests` G14 (bytes from the
  Sold side with Owned on `Date` and Sold on `Price ↑` == Settings'; from
  Owned under Custom with Sold on `Gain ↓` == Settings' — mutation: owned
  rows in `isOrderedBefore` from the Sold side → red). `006`'s G15/G16/G28
  tests stay green unchanged — confirm.
  Files: `Trove/ViewModels/ItemListViewModel.swift`,
  `TroveTests/ItemListViewModelTests.swift`, `TroveTests/SettingsViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every
  mutation recorded.

- [x] **T005 — The list's sale intent: `markSold(_:sale:)`, `makeSaleFormViewModel(for:)`, `SaleCopy.swipeSell`.**
  Per plan §5 and Q9. On `ItemListViewModel`: `makeSaleFormViewModel(for:)`
  (mode `.mark`, price from the item's current value, `now`) and
  `markSold(_:sale:)` (`ItemSaleStore.markSold(toward: nil, at: now(), in:
  modelContext)`, save, `rollback()` + `loadFailureMessage` + `load()` on
  refusal, `load()` on success, returns the outcome). `SaleCopy.swipeSell =
  "Sell"` with a doc line naming `markAsSold` as the spoken label. Pattern:
  `SellPlanViewModel.markSold(_:sale:)` and `makeSaleFormViewModel(for:)`;
  `ItemDetailViewModel.store(_:)` for the refusal shape. No structural test
  allow-lists `ItemSaleStore.markSold`'s callers (checked at planning:
  `ItemSaleStoreTests` documents the "callers save" contract, and the only
  scans naming the store are `SaleFormWiringTests` and `SellPlanWiringTests`
  asserting a *view file* never names it) — this task adds a view-model
  caller, so both scans stay true; T007 must keep `ItemListView` free of the
  word `ItemSaleStore` for the same reason. Tests:
  `ItemListViewModelTests` G17 (the seed equals the detail's and the plan's
  for the same item, with and without a value — extend the existing
  cross-host equality test — mutation: `?? 0` → red), G18 (second context:
  four fields, no link, plan selections emptied, the item in `soldItems`
  and out of `items`; the structural `catch` scan in
  `ItemDetailViewModelTests` extended to this method — mutation: drop
  `rollback()` → red); `SaleCopyTests` G23's copy half (pinned whole).
  Files: `Trove/ViewModels/ItemListViewModel.swift`, `Trove/Models/SaleCopy.swift`,
  `TroveTests/ItemListViewModelTests.swift`, `TroveTests/ItemDetailViewModelTests.swift`,
  `TroveTests/SaleCopyTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded; `scripts/verify.sh ui`
  once at the phase end, count recorded (added at the Phase 1 review: 20 UI
  tests, 0 failures at `41d6dd7`). **Phase 1
  closes here — pause for the person** (nothing to try yet; the pause is the
  review gate — the report may offer to run straight on).

## Phase 2 — Screens

- [x] **T006 — The header on both sides: one gate, the side-aware sort badge, two dropdowns, `apply`.**
  Per plan §6, Q3 and Q10. Both gated spans open on
  `viewModel.offersNarrowingControls`; `sortControl` reads
  `viewModel.visibleSortLabel` for the badge and its accessibility label;
  the host's `case .sort:` switches on `viewModel.side` — Owned's
  `SortDropdown` as today, Sold's over `SoldSortOrder.allCases` with
  `isManualOrder: { _ in false }` selecting into `soldSortOrder` then
  `load()`; `apply` moves `viewModel.searchText = ""` after `show(.owned)`
  inside `.category` and `.unvalued`, and `.sold` stays one call. The header
  comments that describe P16/Q15 rewritten. Pattern: `header`, `sortControl`
  and the `dropdownHost` switch in `ItemListView`. Tests
  (`ItemListSidesWiringTests`): **rewrite**
  `theSoldSideRendersNoSortControlAndNoSearchField` as G20 (the gate spelled
  exactly twice, both `offersNarrowingControls`; no `side == .owned` in the
  file's header; `sortControl` and `SearchField(` once each, inside a gate;
  `case .sort:` composes exactly two `SortDropdown(`, one naming
  `SortOrder.allCases` and one `SoldSortOrder.allCases`, the latter writing
  `soldSortOrder`; `apply`'s body before `switch request` names no
  `viewModel.` — mutations: a `side == .owned` gate back → red; the search
  clear moved above `show` → red); `theSoldRequestIsExactlyOneShowCall` stays.
  `ImportWiringTests.theOverflowControlSitsOutsideEveryEmptyCollectionGate`
  takes a `(path, gate)` pair per screen — the Items screen's anchor is the
  new literal, the wishlist's stays; its assertions unchanged (mutation:
  nest `overflowControl` inside the Items gate → red). `DropdownWiringTests`
  stays green — confirm.
  Files: `Trove/Views/Items/ItemListView.swift`, `TroveTests/ItemListSidesWiringTests.swift`,
  `TroveTests/ImportWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded. No simulator
  check here — the implementer has none; T010's device pass covers both
  sides' header (the field, chips and badge in the same slots; a chip and a
  query on Sold narrowing the rows; the badge reading "Date sold" then
  "Price ↑").

- [ ] **T007 — The leading swipe's Sell, the sheet on the list, the `ActionSell` icon.**
  Per plan §5 and Q9. `@State private var itemBeingSold: Item?`; the leading
  swipe Edit / **Sell** (`Image("ActionSell")`, `.tint(theme.colors.accentBrassMid)`,
  `.accessibilityLabel(SaleCopy.markAsSold)` — whether a swipe-action
  `Button` honours the modifier is T010's to read from the accessibility
  tree; if it does not, "Sell" is the spoken name, which criterion 12
  accepts, and T011's `DECISIONS.md` entry says which shipped — **do not
  stop on it**) / Copy; `.sheet(item:
  $itemBeingSold, onDismiss: viewModel.load)` composing `SaleFormView` over
  `viewModel.makeSaleFormViewModel(for:)`, confirm → `viewModel.markSold`,
  both closures nil-ing `itemBeingSold`; trailing swipe and `soldRows`
  untouched. New `design/icons/action-sell.svg` (a price-tag outline in
  `action-edit.svg`'s style: 24 viewBox, 1.5 stroke, `#000`) copied into
  `Trove/Assets.xcassets/ActionSell.imageset/` with `ActionEdit`'s
  `Contents.json` shape (template, vector preserved). **Flag if** the build
  does not pick the imageset up — no `.pbxproj` edit. Pattern: the existing
  leading swipe block; `ItemDetailView`'s `.sheet(item: $viewModel.saleSheet)`
  for the host shape. Tests (`ItemListSidesWiringTests`): **rewrite**
  `theOwnedRowsSwipesDoNotOfferMarkAsSold` as G19 (the one leading block's
  three `Button`s name, in order, `"Edit"`, `SaleCopy.swipeSell`, `"Copy"`;
  the middle one writes `itemBeingSold` and carries
  `.accessibilityLabel(SaleCopy.markAsSold)` and `"ActionSell"`; the trailing
  block still names no `SaleCopy`; one `.sheet(item: $itemBeingSold` over
  `SaleFormView(` and `makeSaleFormViewModel(for:` — mutations: swap Sell
  and Copy → red; the middle button writing `itemBeingEdited` → red);
  `theSoldRowsCarryOnlyTheTrailingDelete` stays; `TabIconTests` (or a sibling
  suite over the action icons, if its list is tab-only) gains `ActionSell`
  for G22 (mutation: `"template-rendering-intent"` removed → red);
  `MenuPolicyTests` re-confirmed (a second `Menu` in `ItemListView` → red,
  reverted).
  Files: `Trove/Views/Items/ItemListView.swift`, `design/icons/action-sell.svg` (new),
  `Trove/Assets.xcassets/ActionSell.imageset/Contents.json` + `action-sell.svg` (new),
  `TroveTests/ItemListSidesWiringTests.swift`, `TroveTests/TabIconTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded; `ItemListView`
  still never names `ItemSaleStore` (T005's note). No simulator check here —
  T010's device pass covers the swipe on both appearances (three buttons,
  Edit at the edge, the sheet prefilled from the Leica's value, Cancel
  inert, the spoken name).

- [ ] **T008 — The sold page's mark under the name.**
  Per plan §7, Q11 and spec Decision 6. In `ItemDetailView.content(for:)`'s
  sold branch: `photoHero`, `titleBlock(for: item)`, `SoldMark(…)`,
  `statPair`, the rest unchanged; `SoldMark.swift`'s header comment says
  where it now sits. Pattern: the branch itself. Tests
  (`SoldStateWiringTests`): extend `theSoldBranchStampsTheMark` with G21
  (offsets in the sold branch: `photoHero` < `titleBlock(for: item)` <
  `SoldMark(` < `statPair(for: item)` — mutation: the mark back above the
  hero → red); every other scan in the file stays green — confirm.
  Files: `Trove/Views/Items/ItemDetailView.swift`, `Trove/Views/Items/SoldMark.swift`
  (comment), `TroveTests/SoldStateWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutation recorded. No simulator
  check here — T010's device pass measures the mark's place and gaps on the
  Telecaster's page.

- [ ] **T009 — The UI tests, run twice.**
  Per plan §8 and Q13 (no seed change). Rewrite the Sort By assertion in
  `testTheSoldCardLandsOnTheSoldSideWhichListsSalesMostRecentFirst` (the
  badge *present* on Sold, "Sort by Date sold"; the field present; chips
  "Guitars"/"Amps" present, "Cameras" and "Not yet valued" absent; back on
  Owned "Sort by Date" and "Cameras"); new
  `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch` and
  `testTheLeadingSwipeOffersMarkAsSoldBetweenEditAndCopyAndOpensTheSheet`
  exactly as §8 lists their steps (the swipe opened with a partial
  `press(forDuration:thenDragTo:)`, never `swipeRight()`; the price read with
  grouping stripped). Pattern: the two `-seedSold` tests and `soldRow(in:named:)`,
  `element(in:identifiedBy:)`. Mutations (each reverted, recorded): the old
  clearing back in `show` → the round-trip test red; the middle swipe button
  wired to `itemBeingEdited` → the sheet test red. Then `scripts/verify.sh ui`
  **twice back to back** (criterion 13). If XCUITest cannot open the leading
  actions with a partial drag, record it as a finding for T010 to instrument
  — do not drop the assertion.
  Files: `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green twice,
  both counts in the Done note (the phase-end UI run, per the Phase 1 review);
  mutations recorded. **Phase 2 closes here —
  pause for the person** (what can be tried: swipe an owned row right and
  tap Sell — the sheet opens, Cancel changes nothing; search, filter and
  sort the Sold side; leave a search or a filter on one side, visit the
  other and come back; export a CSV from a narrowed Sold side; open a sold
  item's page and see the Sold mark under its name).

## Phase 3 — Verification and close-out

- [ ] **T010 — Device pass. [general-purpose agent with simulator tools; person: VoiceOver]**
  Per plan §8 and every criterion, on the iPhone simulator with `-uiTesting`
  and `-seedSold`. **Measure**, don't eyeball: the switch's top edge on both
  sides at zero sales and with the seed (criterion 3 — `006`'s 7a
  measurement re-taken with the controls present; report the two numbers);
  the sold page's mark with `sectionGap` above and below (criterion 11).
  **Instrument the sheet**: a temporary file probe in
  `ItemSaleStore.markSold` through the swipe's sheet — Cancel 0, swipe-down
  0, a list re-render (background/foreground, appearance change) 0, confirm
  1 — removed before the suites run. Walk: the three swipe buttons on both
  appearances (the white label on brass legible — if not, that is a finding
  for a decision review, plan Q9); the swipe action's spoken name read from
  the accessibility tree ("Mark as sold…" if the modifier took, else "Sell"
  — record which, for T011); Edit still on a full swipe; the sheet prefilled
  from the value;
  a narrowing on each side surviving a round trip in both directions; the
  Sold side's no-matches state and its Clear search; Sort By's eight rows on
  Sold and the Owned side's unchanged; the Dashboard's Sold card landing on
  a narrowed Sold side as it stands (criterion 8) and a category route
  landing on Owned with that chip; a CSV from a Sold side narrowed to "Amps"
  read from the container (owned and sold amps only, the coverage label
  true) and an unnarrowed one from Sold with Sold on `Price ↑` byte-equal to
  Settings' export-everything file; the PDF from that narrowed Sold side
  owned-only under the same label; nothing sold at all → "Nothing sold yet"
  and no controls (criterion 9). Both suites twice. Findings fixed in place
  if routine and inside the footprint, else returned as a diagnosis for a
  decision review; each fix a sub-lettered task.
  **[person]** Accessibility Inspector (criterion 12): the swipe action
  announces "Mark as sold…"; the Sold side's field, chips and sort badge
  have labels.
  **Verify:** the record in the Done note with both measurements, the probe's
  count per action and the byte comparison; `scripts/verify.sh all` green
  twice.

- [ ] **T011 — Close-out.**
  Per plan §9. Criteria 1–13 ticked in `spec.md` with citations — criterion
  2's evidence is the existing `SoldStateWiringTests` (both menus, rows
  swapped by `isSold`) and `MenuPolicyTests` staying green with no edit, not
  the diff's silence; criterion 10 ticked as "from the Sold side — the Owned
  side's own export is `011`'s, unchanged, and its byte identity holds under
  Custom as before"; criterion 12 an honest partial until the person's step,
  naming the spoken name T010 read; the Copy section gains "Sell"
  and the eight sort labels (P-items → decisions); `plan.md` gains "As
  built" (deviations, R1/R2 as confirmed or overturned at sign-off, Q1–Q13 as
  shipped); this file's status flipped; `design/tokens.md`'s `006` rows
  ("Placement", "Header on Sold", the Sold mark's "Position") get their "As
  implemented" cells and the Swipe-action table names the third leading
  action and `accentBrassMid`; `README.md`'s sold bullet; `specs/ROADMAP.md`'s
  014 entry and status row; `DECISIONS.md` (per-side state behind one set of
  names; the file's order rule from the hidden side; "Sell" on the button and
  "Mark as sold…" to VoiceOver) — on this branch, the `006` precedent; the
  pre-merge `skeptical-reviewer` sweep over `git diff main...HEAD` (bundle
  cut after `git add -A`); PR marked ready for review.
  **Verify:** everything above committed and pushed; `scripts/verify.sh all`
  green with the final counts recorded here (unit and UI lines both captured
  — `006`'s T020 lost the unit line to a short `tail`).

## Tier log

Experiment 1 (`CLAUDE.md`'s model policy, adopted 2026-09-11): the
`sdd-planner` and the plan/tasks sign-off at **`fable`** (the top tier, with
an explicit per-call override); the `skeptical-reviewer` on each phase and
marked-task review, the pre-merge sweep, and the `sdd-implementer` at
**`opus`**; the device pass in a `general-purpose` agent at `opus`; the
orchestrating session at `fable` medium. Every Tier entry below is the
resolved name, never "default." Token usage from each subagent return is
filled in as the spec runs; escape-hatch misses (a task the orchestrator had
to redo, and why) are recorded here too. The allowance reading at the start
row and at the merge is recorded for the experiment's coordinator, not
interpreted here.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| Spec session (this spec's `spec.md`, drafting and revision) | `fable` medium (raised to high for the spec conversation) | orchestrating seat, not measured separately | Draft, revised at the person's reading, approved 2026-09-16 |
| `sdd-planner` — plan.md and tasks.md, plus the fix round | `fable` | ~314k (≈290k first draft, ≈20k fixes) | Drafted; three blocking findings fixed in place |
| `skeptical-reviewer` — plan/tasks sign-off and re-review | `fable` | ~170k (≈156k review, ≈14k re-review) | Three blocking, nine second-look findings; re-review: all resolved, sign off |
| T001 — `sdd-implementer` | `opus` | ~39k | Done; 4+4 pointers, counts verified by the orchestrator. Note for T011: `006` spec line 69 ("from two places") left as is, not in T001's scope |
| T002 — `sdd-implementer` | `opus` | ~76k | Done; 1506 unit tests green. Mutations: price comparator deleted → Price cases red; reversed → red; gain reading paid → Gain cases red; `?? false` → tie test red; tie by name → tie test red both orders. Note: parameterised `@Test` counts as one test in the count line |
| T003 — `sdd-implementer` | `opus` | ~136k | Done; 1511 unit tests green (orchestrator re-ran: same count). Rewrites: `switchingToSoldClearsEveryNarrowing` → `theOwnedSideKeepsItsNarrowingWhileTheSoldSideIsVisited`; `switchingBackToOwnedClearsEveryNarrowingToo` → `theSoldSideKeepsItsNarrowingWhileTheOwnedSideIsVisited`. Ten mutations recorded (G4 ×2, G6 ×2, G7 ×2, G8, G9, G10, G25), each red then reverted. One forced edit in `exportableSoldItems` (`narrowed(sold, by: narrowing).sorted(by: isInSoldOrder)` — the textual rename would have made an Owned export follow a Sold query) |
| T003 — `skeptical-reviewer` per-task review | `opus` | ~63k | Sign off, no blocking. Second-look: (1) Q3's view half (`apply` clear after `show`) not in this diff — owned by T006/G20; (2) export behaviour from the Sold side untested until T004 — G11/G12 cover both directions; (3) `exportableSoldItems`' first doc paragraph ("under the Owned side's visible narrowing") now false — carried to T004's bundle; (4) sort-after-filter tie stability — void, `areInSoldOrder` is total (date, name, id); (5) G4's sort assertions not mutation-covered (no mutation touches sorts); (6) one restating assertion in G10, the literals beside it carry the guard |
| T004 — `sdd-implementer` (incl. one fix round) | `opus` | ~88k + ~98k | Done; 1518 unit tests green (orchestrator re-ran twice: 1517 before the fix, 1518 after). New tests G11–G16 in `ItemListViewModelTests`, G14 in `SettingsViewModelTests`, plus `aSoldChipMatchingNeitherHalfDisablesTheCSVFromTheSoldSide` from the review. Mutations: owned half by `ownedNarrowing` → G11/G15/G16 red; sold half by `soldNarrowing` → G12 + three `006` tests red; CSV writes `soldItems` → G13 red; owned-from-Sold in `isOrderedBefore` → G14 red; PDF from `items` → G15 red; `canExportPDF` reads `items` → G16 red; `canExportCSV` reads `items` → the new test red; coverage label from `ownedNarrowing` → G11/G15 red. Note: G14's fixture needs explicit purchase dates or Date and Custom order coincide |
| T004 — `skeptical-reviewer` per-task review + re-review | `opus` | ~55k + ~57k | One blocking (the CSV gate's owned term had no red mutation) — fixed, re-review sign off. Second-look kept open by design: (2) criterion 10 read literally ("whatever sort either side is showing") is untrue from the Owned side under Date — plan R1's Owned-side exception; goes to the person at the Phase 2 pause with R2, and criterion 10's wording at close-out; (4) the two gates sort a full array to answer isEmpty, and the header's three figures each compute all three — negligible, no value changes; (5) G14's sold tie-break is covered by one tie shape only — the sweep confirms both paths share `areInSoldOrder` |
| T005 — `sdd-implementer` | `opus` | ~75k | Done; 1519 unit tests in 205 suites green. New suite `ItemListViewModelSwipeSaleTests` (G18 on a second context); the refusal scan gains the list's `markSold`; `bothHostsSeedTheMarkSheetIdentically` → `everyHostSeedsTheMarkSheetIdentically` (three hosts). Mutations: `?? 0` in the seed → G17 red; `rollback()` dropped → scan red; `toward:` a fetched plan → G18 red; `swipeSell` → "Sold" → G23 red. Deviation: `loadFailureMessage` set after `load()` in the catch, since `load()` clears it first. Finding (pre-existing, out of scope): `duplicate(id:)`'s catch sets the message then `load()` clears it — a refused duplicate reports nothing; flagged for a `fix/` branch |
| T001 fix — `sdd-implementer` (phase-review round) | `opus` | ~44k | P16 pointer rewritten with the eight labels and glyphs; both plan.md pointers cite "its spec" for P11 |
| Phase 1 — `skeptical-reviewer` review + re-review | `opus` | ~130k + ~2k | Two blocking: the P16 pointer named five options (fixed), and the UI suite not run at the phase end (run: 20 tests, 0 failures; cadence written into T005/T009 Verify lines). Re-review: sign off. Second-look kept open: S1 `markSold`'s message-after-`load()` ordering has no red mutation (the scan is order-blind); S3 G11/G12 don't `#require` their hidden-side premise (would go vacuous, not red, if per-side keeping regressed — G4 is the backstop); S4 T009's round-trip test must type into the field, not drive state (view-side @State mirror would be invisible to unit guards) — carried to T009's bundle; S5 `SortDropdown` genericity — void, it is generic; S6 a CSV from Owned with the Un-valued chip on also drops sold rows carrying a value (006's inherited behaviour, label stays true) — a sentence for T011's "As built" |
| T006 — `sdd-implementer` | `opus` | ~80k | Done; 1519 unit tests green. `theSoldSideRendersNoSortControlAndNoSearchField` → `oneNarrowingGateCoversBothSidesAndEachSideBringsItsOwnSort` (G20, plus the badge reading `visibleSortLabel`). Mutations: `side == .owned` back on the gate → red; the search clear above `switch` → red; Sold dropdown arm removed → red; `overflowControl` inside the Items gate → `ImportWiringTests` red (Items case only). Note: the two list screens no longer share a gate literal |
| _rows added per dispatch as the spec runs_ | | | |

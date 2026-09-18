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

- [x] **T007 — The leading swipe's Sell, the sheet on the list, the `ActionSell` icon.**
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

- [x] **T008 — The sold page's mark under the name.**
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

- [x] **T009 — The UI tests, run twice.**
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

## Phase 2b — Export scope (spec Decision 7, added 2026-09-18 at the Phase 2 pause)

Added after the person's Phase 2 walkthrough: exports from the Items list
choose owned, sold or both, for the CSV and the PDF (spec Decision 7, P12–P15,
criterion 14; plan §4a Q14–Q17). Shaped by a decision review at the top tier
and approved by the person the same day. **T009b is marked `review:
per-task`** (the bytes of a file the person keeps); the rest get the Phase 2b
review. Pause at the end of this phase — there is something to try.

- [x] **T009a — The `006` and `011` pointers for Decision 7 (docs only).**
  Per spec Inherited caveats and T001's pattern. `specs/006-mark-as-sold/spec.md`:
  *"Superseded by `014-sold-side-parity` (its spec, Decision 7): …"* at
  Decision 7's PDF sentence ("the PDF stays a document of what you own"), at
  P17, and at the non-goal "A sold-items PDF"; `specs/006-mark-as-sold/plan.md`
  at Q5's "`canExportPDF` (owned non-empty)" clause. `specs/011-data-export/spec.md`:
  a pointer under "## The PDF" (a sold document since `014`) and at the PDF
  filename line (`Trove-Sold-Items-YYYY-MM-DD.pdf` joins it). Appended,
  nothing above edited.
  Files: `specs/006-mark-as-sold/spec.md`, `specs/006-mark-as-sold/plan.md`,
  `specs/011-data-export/spec.md`.
  **Verify:** `grep -c "Superseded by \`014-sold-side-parity\`"` prints 7 over
  `006` spec (4 + 3), 5 over `006` plan (4 + 1), 2 over `011` spec; `git diff
  --stat` touches only those three files.

- [x] **T009b — `ExportScope`, `canExport(_:)`, `exportCSV(scope:)`, `ExportFilename.soldItems`. `review: per-task`.**
  Per plan §4a Q14 and Q15's filename. `canExportPDF` **unchanged in this
  task** (owned-only until T009d, so no empty owned PDF is ever offered
  between commits). Every caller of `exportCSV()` in tests → `exportCSV(scope:
  .both)`. Pattern: `SoldSortOrder` (enum + literal-pinned labels), today's
  `exportCSV`, `ExportFilename.items` and its test. Tests
  (`ItemListViewModelSoldExportTests`): **G26** labels/order by literal;
  **G27** from a Sold side under a chip (G11's fixture): `.owned` rows == the
  owned rows in it in Custom order, `.sold` rows == the sold rows in it
  date-desc under `soldSortOrder = .salePriceAscending`, `.both` == `.owned` +
  `.sold` (mutations: `.owned` reading `items` from Sold → red; `.sold` reading
  `soldItems` → red; `.both` sold-first → red); **G28** `canExport` per scope:
  all-sold (false, true, true), all-owned (true, false, true), a Sold chip
  matching neither (false, false, false) and `canExportCSV` false, and
  `exportCSV(scope: .owned)` on an all-sold collection stages nothing (extend
  `aSoldChipMatchingNeitherHalfDisablesTheCSVFromTheSoldSide`; mutations:
  `canExport(.owned)` reading `items` from Sold → red; `canExportCSV` reading
  `items` → red); **G29** filenames via the spy: `.sold` ==
  `ExportFilename.soldItems(fileExtension: "csv")` == `"Trove-Sold-Items-<day>.csv"`,
  `.owned` and `.both` == `items` (mutation: swap → red). `ExportTempFileTests`
  / `ExportSchemaTests`: `soldItems` day-serialised like `items`.
  `SettingsViewModelTests` G14 and `theListsUnfilteredCSVStillMatchesSettingsByteForByteWithASalePresent`
  re-pointed at `.both` — confirm green with no other edit.
  Files: `Trove/ViewModels/ItemListViewModel.swift`, `Trove/Export/ExportService.swift`,
  `TroveTests/ItemListViewModelTests.swift`, `TroveTests/SettingsViewModelTests.swift`,
  any test calling `exportCSV()` on the items list.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded.

- [x] **T009c — The sold document in the export layer.**
  Per plan §4a Q15. `CoverSummary.Totals.sold`, the `drawCover` / `countLine`
  arms, the text-taking `drawTotal` sibling, `PDFEntry.init(record:)`'s five
  prepended fields. Pattern: the `.wishlist` arm and `countLine`; the entry
  init's optional-field skips. Tests: `PDFComposerTests` **G30** a rendered
  sold cover's page-0 text contains "Sold Items", "2 sold" (and "1 sold"
  singular), "TOTAL SOLD FOR", "TOTAL PAID", "REALISED", "+$350 vs paid", and
  not "not yet valued" (mutations: the `.sold` arm drawing the `.items` labels
  → red; the floor note drawn → red; count line "items" → red);
  `ExportSchemaTests` **G31** a sold record's entry fields begin `Sold`, `Sold
  for`, `Sold at`, `Outcome`, `Sale note` with the expected values, `Sold at` /
  `Sale note` absent when nil or empty, then `Paid` first of the owned grid; an
  owned record's entry carries none of the five (mutations: fields appended
  instead of prepended → red; outcome from `currentValueCents` → red; an empty
  `Sold at` emitted → red); **G32** `ExportFilename.soldItems` ==
  `"Trove-Sold-Items-YYYY-MM-DD.pdf"` under a fixed date and zone (the `items`
  test's shape).
  Files: `Trove/Export/ExportSchema.swift`, `Trove/Export/PDFComposer.swift`,
  `TroveTests/PDFComposerTests.swift`, `TroveTests/ExportSchemaTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [x] **T009d — `exportPDF(scope:)` and the PDF gate.**
  Per plan §4a Q16. `soldDocumentTitle`; the set through one `exportFiles`;
  `canExportPDF = canExport(.both)` (Q14's "both gates read `canExport(.both)`"
  lands here — T009b left the PDF gate owned-only on purpose); every caller of `exportPDF()` in tests →
  `exportPDF(scope: .owned)`. **Rewrite** `anAllSoldCollectionCanExportACSVButNotAPDF`
  → `anAllSoldCollectionOffersBothFormatsWithTheOwnedScopeDisabled` and
  `aSoldChipNoOwnedRowIsInKeepsTheCSVAndDisablesThePDF` → `…DisablesTheOwnedScopeAlone`
  (Q12). Pattern: `SettingsViewModel.exportEverythingAsPDF` and `stage(_:)`;
  G15's test. Tests: **G33** `.sold` from a Sold side under a chip with
  `soldSortOrder = .salePriceAscending`: entries the sold rows in it date-desc,
  title "Sold Items", label "Category: …", `itemCount == entries.count`, totals
  `.sold` == `SaleOutcome.totals(over:)` of those rows and their paid sum
  (mutations: entries from `soldItems` → order red; cover over `sold` → red;
  paid from `salePriceCents` → red); **G34** unnarrowed Sold side: the sold
  cover's (count, proceeds, realised) == `viewModel.soldTotals` (mutation:
  proceeds over `purchasePriceCents` → red); **G35** `.both`:
  `spy.fileSets.count == 1`, `documents` owned-then-sold, `filenames ==
  [items(pdf), soldItems(pdf)]`, `stagedExport?.filenames` the same; nothing
  sold → one document, the owned; nothing owned → one, the sold (mutations:
  two single calls → red; the empty half staged → red; order swapped → red);
  **G36** all-sold: `canExportPDF` true, `canExport(.owned)` false (mutation:
  `canExportPDF` reading the owned half → red). G15,
  `pdfCoverFiguresAreTheViewModelsOwnArithmetic`, `thePDFLeavesSoldItemsOutOfItsEntriesAndItsCover`
  and Settings' `thePDFPairMatchesTheListsUnfilteredDocuments` re-pointed at
  `.owned` — confirm green with no other edit.
  Files: `Trove/ViewModels/ItemListViewModel.swift`, `TroveTests/ItemListViewModelTests.swift`,
  `TroveTests/SettingsViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [x] **T009e — The chooser on the Items list.**
  Per plan §4a Q17. `ExportCopy.scopeTitleCSV = "EXPORT AS CSV"`,
  `scopeTitlePDF = "EXPORT AS PDF"`; `HeaderDropdown.exportScope(ExportFormat)`
  with `dismissLabel` "Dismiss export options"; the three `.dropdownAnchor`s on
  `overflowControl`; the host's case; `OverflowDropdown.swift` comment only.
  Pattern: `SortDropdown`'s body and the Dashboard's `case .order:` (a titled
  surface over `ForEach(allCases)`); `overflowControl`. Tests
  (`ExportWiringTests`) **G37** — `DropdownGates` gains per-screen `csvAction`
  / `pdfAction` (Items: `openDropdown = .exportScope(.csv)` / `.pdf`;
  Wishlist: `viewModel.exportCSV()` / `exportPDF()`, unchanged); the Items
  host's `case .exportScope` composes exactly one `DropdownSurface(title:`,
  one `ForEach(ItemListViewModel.ExportScope.allCases`, a row gated
  `isEnabled: viewModel.canExport(scope)`, an action naming both
  `exportCSV(scope: scope)` and `exportPDF(scope: scope)` and no literal
  `.both` / `.owned` / `.sold`; `overflowControl` carries the three
  `.dropdownAnchor(` literals (`#require` each) (mutations: the row gated on
  `canExportCSV` → red; the action passing `.both` → red; an anchor dropped →
  red); `ExportCopy` titles pinned by literal; `theMenuCarriesFiveItemsInThreeGroups`,
  `OverflowDropdownRenderTests`, `DropdownWiringTests`, `MenuPolicyTests`
  green with no edit — confirm (a `confirmationDialog` in the host →
  `MenuPolicyTests` red, reverted).
  Files: `Trove/Views/Items/ItemListView.swift`, `Trove/Export/ExportService.swift`,
  `Trove/Views/Shared/OverflowDropdown.swift` (comment), `TroveTests/ExportWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded. No simulator check
  here — T010 covers the menu-to-chooser swap.

- [x] **T009f — The UI test for the chooser, run twice.**
  `-seedSold`: Items → `moreActions.items` → "Export as PDF…" → buttons "Owned
  items", "Sold items", "Owned and sold" exist and are enabled, "Import from
  CSV…" gone; "Dismiss export options" closes it; switch to Sold, tap chip
  "Guitars", "…" → "Export as CSV…" → "Owned items" **not** enabled (no owned
  guitar in the seed), the other two enabled; tap "Sold items" → the chooser
  gone (the share sheet itself is the device pass's — no existing UI test
  asserts one). `testEmptyCollectionOffersImportAndSettingsButNotExport`
  unchanged. Mutations: rows gated on `canExportCSV` → "Owned items" enabled →
  red; the menu row firing the export directly → the rows never appear → red.
  Files: `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green twice,
  both counts in the Done note; mutations recorded. **Phase 2b closes here —
  pause for the person** (what to try: each of the six choices from both
  sides, narrowed and not; open the sold PDF; the "Owned and sold" PDF share
  sheet showing two files).

- [x] **T009g — Fix the stacked dropdown anchors (the shared helper becomes a transform). `review: per-task`.**
  Added 2026-09-18 after T009f found the Items "…" badge opening nothing at
  `cf3e1ee` (plan Q17 as corrected; decision review at the top tier — option
  D over the three the implementer named). In `Trove/Views/Shared/DropdownHost.swift`
  make `dropdownAnchor(_:)` a `transformAnchorPreference` that inserts its id
  into the current dictionary, and rewrite its doc comment and
  `DropdownAnchorKey`'s to say why (a stacked set-modifier keeps only the
  last tag; the transform adds; `reduce` still merges across siblings). In
  `Trove/Views/Items/ItemListView.swift` correct the `overflowControl`
  comment — "merged by the anchor key's `reduce`" is the false sentence. No
  other call site changes; G37's three `.dropdownAnchor(` literals and
  `DropdownWiringTests` stay as written. New `TroveTests/DropdownAnchorTests.swift`
  (joins the target through the synchronized folder): render, via
  `renderBitmap` (the `DropdownPlacementTests` shape), a small fixed-size view
  carrying `.dropdownAnchor("a").dropdownAnchor("b").dropdownAnchor("c")`
  inside `.overlayPreferenceValue(DropdownAnchorKey.self)` whose closure
  records `anchors.keys` into a main-actor probe box and returns
  `Color.clear`; assert the keys equal {"a","b","c"}; a second case with a
  one-tag sibling beside the three-tag view records four keys (the `reduce`
  half). Mutations: the helper reverted to `anchorPreference` → the first
  case records one key → red; `reduce` changed to `value = nextValue()` →
  the sibling case drops a key → red; both restored. If the reader closure
  does not run under `ImageRenderer`, stop and report — do not weaken to a
  source scan. Pattern: `TroveTests/DropdownPlacementTests.swift`.
  Files: `Trove/Views/Shared/DropdownHost.swift`, `Trove/Views/Items/ItemListView.swift`
  (comment), `TroveTests/DropdownAnchorTests.swift` (new).
  **Verify:** `scripts/verify.sh all` green (orchestrator re-runs) — the six
  UI tests that failed at `cf3e1ee` are the acceptance evidence, not the one
  chooser test option A was checked against; mutations recorded.

- [x] **T009h — `MenuPolicyTests` names `confirmationDialog`.**
  Added 2026-09-18 (decision review): `013` Decision 17's "no
  `confirmationDialog`" half was unguarded — T009e's mutation stayed green.
  In `TroveTests/MenuPolicyTests.swift` add `|| code.contains(".confirmationDialog(")`
  to `hostsOne` and extend the header comment's last sentence to name it,
  citing `013` Decision 17; `.alert(` stays allowed; add nothing else.
  Mutation: a `.confirmationDialog("x", isPresented: .constant(false)) {}` on
  any view in `Trove/Views` → red naming that file; restored. Pattern: the
  file itself. Files: `TroveTests/MenuPolicyTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutation recorded.

- [x] **T009i — The gated export spy gates once across methods; the Items reentry probe goes falsifiable.**
  Added 2026-09-18 (decision review; T009d's returned item). In
  `TroveTests/TestSupport.swift`, `GatedExportServiceSpy` gates only the
  first call across `exportCSV` and `exportFiles` (one `gateTaken` flag in
  its state; counters stay per method; `exportPDF` stays ungated and counted
  — `WishlistViewModel` still calls it); rewrite its two comments to state
  the cross-method rule and why (a reentrant call of either kind that leaks
  must fail a count, not hang). In `TroveTests/ItemListViewModelTests.swift`
  `isExportingIsObservableMidFlightAndBlocksReentry`: replace
  `#expect(spy.pdfCalls == 0)` with `#expect(spy.fileSetCalls == 0, "a
  reentrant PDF reached the service")`. Mutations: `!isBusy` dropped from
  `ItemListViewModel.exportPDF(scope:)` → red in normal run time, no hang;
  `!isBusy` dropped from `exportCSV(scope:)` → `csvCalls == 1` red; both
  restored. Confirm the Settings and Wishlist reentry tests are in the count
  and green. Pattern: `SettingsViewModelTests.activityIsObservableMidFlightAndBlocksReentry`.
  Files: `TroveTests/TestSupport.swift`, `TroveTests/ItemListViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded. T009f's two
  back-to-back UI runs then complete on top of T009g–T009i, and Phase 2b
  closes.

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
  **Added for Decision 7 (Phase 2b):** the menu-to-chooser swap (a recording
  if it steps — the plate re-sizes in place, anchored at the badge); the
  chooser drawn at all (the anchor claim, plan Q17); the six files read from
  the container — the `.sold` PDF opened (cover words and three figures
  against the Sold summary), the `.both` share sheet showing two files, the
  three CSVs' sale columns marking the side; **open a sold entry page** in the
  `.sold` PDF for an item with all five sale fields and a long sale note — the
  composer has never drawn an eleven-field entry and no test renders one
  (Phase 2b review S1); the `.both` share sheet's second file opened too.
  **[person]** Accessibility Inspector (criterion 12): the swipe action
  announces "Mark as sold…"; the Sold side's field, chips and sort badge
  have labels; the chooser's first row takes focus and the catcher reads
  "Dismiss export options".
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
  cut after `git add -A`); PR marked ready for review. **Added for Decision
  7:** criterion 14 ticked; criterion 10's corrected wording noted as the
  person's; `README.md`'s sold bullet ("The PDF stays a document of what you
  own … and no PDF") rewritten; `design/tokens.md`'s "Export badge and menu"
  row and its print section gain a sentence each; `docs/csv-reference.md` a
  line on the three files; `ROADMAP.md`'s 014 entry; `DECISIONS.md` (a chooser,
  not six rows; two documents for "both"; `Trove-Sold-Items`; Settings' PDF
  pair no longer "the complete record"); plan "As built": the Context's "no
  export format" corrected, R2 confirmed-and-extended, Q14–Q17 as shipped;
  "As built" sentences for `ActionIconTests`' three extra icons and the
  Un-valued chip narrowing the sold half of a CSV (Phase 1 S6) and, since
  Phase 2b, stamping the sold PDF's cover with an un-valued label beside a
  cover that has nothing to caveat (Phase 2b S5); a `DECISIONS.md` clause that
  "Owned and sold" on an all-sold collection writes a sold-only file under
  `Trove-Items-<date>` by P15, not by mistake (S6). Sweep items from Phase 2b:
  S2 a fixture with `soldDate` set and `salePriceCents` nil asserting the
  entry begins at `Paid` (the pair-unwrap claim in plan Q15 has no red);
  S3 `ExportWiringTests`' comment claims a swapped-closure guard the scan
  can't give (the UI test does) — soften or pin the labelled pair; S4 a
  `realised == proceeds - paid` expectation in G33.
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
| T006 — `sdd-implementer` | `opus` | ~80k | Done; 1519 unit tests green. `theSoldSideRendersNoSortControlAndNoSearchField` → `oneNarrowingGateCoversBothSidesAndEachSideBringsItsOwnSort` (G20, plus the badge reading `visibleSortLabel`). Mutations: `side == .owned` back on the gate → red; the search clear above `switch` → red; Sold dropdown arm removed → red; `overflowControl` inside the Items gate → `ImportWiringTests` red (Items case only); (added at the Phase 2 review) `sortControl` back to `sortOrder.label` → the badge leg red at :104. Note: the two list screens no longer share a gate literal |
| T007 — `sdd-implementer` | `opus` | ~79k | Done; 1523 unit tests in 206 suites green; `ItemListView` names `ItemSaleStore` 0 times; the imageset resolved with no `.pbxproj` edit. `theOwnedRowsSwipesDoNotOfferMarkAsSold` → `theOwnedRowsLeadingSwipeOffersEditThenSellThenCopy` + `theSaleSheetIsHostedOnceOverTheStagedRow` (G19, incl. G23's label half); new `ActionIconTests` over the four action icons (G22). Mutations: Sell/Copy swapped → red; middle button → `itemBeingEdited` → red; template intent removed → red; second `Menu` → `MenuPolicyTests` red; (added at the Phase 2 review, ~88k) confirm → `load()` → sheet test red at :241; inline `SaleFormViewModel` → red at :237; `itemBeingSold = nil` dropped → red at :245. Note: the glyph has had no visual inspection — T010 |
| T008 — `sdd-implementer` | `opus` | ~47k | Done; 1523 unit tests green. `theSoldBranchStampsTheMark` extended with G21; mutation: mark back above the hero → red on `title < mark` only (the other two legs are structural controls). Note for T011: `design/tokens.md`:657's Position row describes the pre-014 placement — correct the row, not just the cell |
| T009 — `sdd-implementer` | `opus` | ~105k | Done; unit 1523 green; UI twice back to back: 22 tests, 0 failures / 22 tests, 0 failures. Mutations: the 006 clearing back in `show` → the round-trip test red (3 failures at the round-trip assertions); the middle swipe button → `itemBeingEdited` → the sheet test red. The leading actions open with a partial press-drag (0.1 s, 40 % of the width); XCUITest reports the middle button as "Mark as sold…" (the accessibility label took — for `DECISIONS.md`, T011). Notes: per-side *sort* keeping has no UI mutation of its own (the old clearing never touched sorts); XCTest per-function selectors do work through verify.sh (Swift Testing's don't); the un-valued chip's accessibility label is "Clear the not-yet-valued filter" |
| Phase 2 — `skeptical-reviewer` review + re-review | `opus` | ~87k + ~1k | One blocking: the sheet-hosting guard and G20's badge leg landed with no recorded red — four mutations run (all red, no code or test change), recorded on T006/T007's rows; re-review: sign off. S4 (the `show(.owned)`-before-write assertion) and S6 (`lists` still used) checked by the orchestrator, both present. Open second-look for the sweep/T010/T011: S1 the no-matches "Clear search" UI assertion can pass on the field's X alone (assert two buttons or give the empty-state action an identifier); S2 the swipe test matches "Sell" or "Mark as sold…" — after T010 reads the tree, pin the one that shipped; S3 `!code.contains("viewModel.side == .owned")` is file-wide where the plan scoped it to the header; S5 the three-`Button` count is comment-sensitive (spurious red, not false green); S7 `ActionIconTests` covers three icons beyond the task line — a sentence for "As built"; S8 T010: type into the price field, background/foreground, confirm the typed value survives (the closure re-seeds on every body evaluation) |
| Phase 2 pause — decision review (export scope, Decision 7) — `skeptical-reviewer` | `fable` (explicit override) | ~226k | Recommended option B (a second dropdown surface under the two export rows), the sold PDF as its own document, "both" as two PDFs in one share sheet, all inside 014 as Phase 2b; approved by the person 2026-09-18. Second-look for the record: Settings' PDF pair is no longer the complete record; `.owned` and `.both` CSVs share `Trove-Items`; the Un-valued chip reaches the sold cover label (S6); `SaleOutcome` lives in `Sale.swift` |
| T009a — `sdd-implementer` | `opus` | ~34k | Done; counts 7 / 5 / 2 verified by the orchestrator; six pointers, nothing above edited |
| T009b — `sdd-implementer` | `opus` | ~94k | Done; 1527 unit tests green (orchestrator re-ran: same). G26–G29 plus `filenamesCarryTheLocalDay` extended; `ExportWiringTests` gains a per-screen `csvAction` literal. Mutations: `.owned` → `items` (one edit covers G27 and G28's `canExport(.owned)`); `.sold` → `soldItems` → G27 red; `.both` sold-first → G27 + G11–G13 red; `canExportCSV` → `items` → three red; filename arms swapped → G29 red; the view literal → `.owned` → wiring red. Deviation: `ExportScope: String, Identifiable` (Q17's `ForEach`) |
| T009b — `skeptical-reviewer` per-task review | `opus` | ~50k | Sign off, no blocking. Second-look: (1) plan Q14 says both gates read `canExport(.both)` while the PDF gate waits for T009d — T009d's line now says so; (2) `ExportScope: String` adds unpinned raw values that look persistable (`id: Self` would do) — sweep; (3) T009e must re-point the Items `csvAction` literal at the chooser-open intent, not broaden it — its line names the literal; (4) `onlyTheSoldOnlyCSVTakesTheSoldFilename` builds two `.now`s (midnight flake window) — pass a fixed date at the sweep; (5) `eachScopeIsGatedOnTheRowsItWouldCarry` alone can't see narrowed vs unnarrowed; the sibling test carries that mutation |
| T009c — `sdd-implementer` | `opus` | ~86k | Done; 1531 unit tests green. G30 (`soldCoverCarriesTheSaleTotalsAndNoFloorNote`, `soldCoverCountLineIsSingularForOneSale`), G31 (`soldEntryLeadsWithTheSaleThenTheOwnedGrid`, `ownedEntryCarriesNoSaleFields`); G32 already pinned by T009b's `filenamesCarryTheLocalDay`. Six mutations red and reverted. Outside the footprint, mechanical: three exhaustive `switch cover.totals` in two view-model test files gained `.sold` in their non-items arm. Judgment call resolved as routine and noted in plan Q15: the sale block unwraps `soldDate` and `salePriceCents` as a pair |
| T009d — `sdd-implementer` | `opus` | ~121k | Done; 1534 unit tests green. Rewrites: `anAllSoldCollectionCanExportACSVButNotAPDF` → `anAllSoldCollectionOffersBothFormatsWithTheOwnedScopeDisabled` (carries G36); `aSoldChipNoOwnedRowIsInKeepsTheCSVAndDisablesThePDF` → `aSoldChipNoOwnedRowIsInDisablesTheOwnedScopeAlone`. New G33 `theSoldPDFCoversTheSoldRowsThatPassTheChipInDateSoldOrder`, G34 `theSoldCoverIsTheSoldSidesOwnTotals`, G35 `theBothPDFStagesOwnedThenSoldInOneFileSet`; `ExportWiringTests` gains a per-screen `pdfAction`. Ten mutations red and reverted. Returned, not decided: `isExportingIsObservableMidFlightAndBlocksReentry`'s `pdfCalls == 0` is now vacuous for the Items list (the PDF stages a set through `exportFiles`), and the obvious `fileSetCalls == 0` cannot go red — the gated spy deadlocks on a reentrant first `exportFiles` call (mutation hung 20 min). Needs a cross-method gate rule in `TestSupport.swift`, outside the footprint — to the Phase 2b review |
| T009e — `sdd-implementer` | `opus` | ~85k | Done; 1536 unit tests green. G37 `theItemsListComposesTheScopeChooserOverEveryScope` + `theScopeChooserHeadersReadAsTheSpecWritesThem`; Items `csvAction`/`pdfAction` re-pointed at the chooser-open intents. Mutations: row gated on `canExportCSV` → red; action passing `.both` → red; an anchor dropped → red; a `confirmationDialog` in the host → `MenuPolicyTests` **stayed green** — the scan matches `Menu(`/`.pickerStyle(.menu)`/`.contextMenu` only, so 013 Decision 17's "no confirmationDialog" half is unguarded anywhere (no file uses one today). To the Phase 2b review: broaden the regex (`.confirmationDialog(`) as a sub-lettered task? Also: verify.sh's no-count guard fires on a passing one-test Swift Testing suite — read `## failures`, not the exit code |
| Phase 2b decision review (anchors, menu scan, reentry) — `skeptical-reviewer` | `fable` (explicit override) | ~77k | Option D (the shared helper becomes a `transformAnchorPreference`) with a render guard `DropdownAnchorTests` (T009g, per-task); broaden `MenuPolicyTests` now (T009h); the gated spy gates once across methods so the reentry probe can go red (T009i). Plan Q17 corrected |
| T009g — `sdd-implementer` | `opus` | ~50k | Done; `scripts/verify.sh all`: unit 1538 tests in 207 suites, UI 23 tests 0 failures (orchestrator re-ran: same — that run is also T009f's second UI pass). `dropdownAnchor` is a `transformAnchorPreference`; new `DropdownAnchorTests` (three stacked tags → three keys; a sibling → four). Mutations: helper back to `anchorPreference` → both cases red; `reduce` → `value = nextValue()` → sibling case red only. The reader runs under `ImageRenderer` (`#require(probe.runs > 0)`) |
| T009g (+T009f test) — `skeptical-reviewer` per-task review | `opus` | ~43k | Sign off, no blocking. Second-look: (2) the transform also lets a descendant's tag propagate through a tagged ancestor (no such nesting known; sweep to confirm, Q17 clause if intentional); (3) the anchor tests use string ids, not `HeaderDropdown` cases (the UI test covers the real ids); (4) the UI test's last assertion (chooser gone after picking a scope) can be satisfied by the share sheet covering it — message softened at close-out or left to T010; (5) the header literal duplicates `ExportCopy` plus `DropdownSurface`'s casing; (6) three taps without an existence check (fail loudly, not vacuously) |
| T009h — `sdd-implementer` | `opus` | ~34k | Done; 1538 unit tests green. Mutation: a `.confirmationDialog` on `AddButton` → `MenuPolicyTests` red naming the file; restored byte-for-byte. Note: the summary truncates `#expect` messages — the offender list is only in the raw log |
| T009i — `sdd-implementer` | `opus` | ~48k | Done; 1538 unit tests green; the three reentry tests (Items, Wishlist, Settings) in the count and green. `GatedExportServiceSpy` gates once across `exportCSV`/`exportFiles`. Mutations: `!isBusy` dropped from `exportPDF(scope:)` → `fileSetCalls == 0` red in 0.13 s (was a 20-min hang); dropped from `exportCSV(scope:)` → `csvCalls == 1` red (plus `fileSetCalls`, since the ungated CSV's `defer` clears `isBusy` — expected collateral) |
| T009f — `sdd-implementer` | `opus` | ~72k | Done (stopped on the anchor defect, resumed after T009g). `testTheExportRowsOpenAScopeChooserGatedByWhatIsOnScreen`. Mutations (on top of the fix): rows gated on `canExportCSV` → red at "Owned items must be disabled"; the menu row exporting directly → red at "must open the scope chooser". UI suite twice, consecutive full runs: 23 tests 0 failures (implementer, T009g's all) and 23 tests 0 failures (orchestrator's re-run). At `cf3e1ee` the same suite was 23 tests 12 failures — the finding that produced T009g |
| Phase 2b — `skeptical-reviewer` review | `opus` | ~118k | One blocking: the two back-to-back UI runs were taken at `063ea58`, before T009h/T009i — re-run `scripts/verify.sh all` twice at HEAD (`a1f5acf`): run 1 unit 1538/207 green, UI 23 tests 0 failures; run 2 unit 1538/207 green, UI 23 tests 0 failures (both at `a1f5acf`, back to back). Second-look S1–S6 written into T010/T011 above. Re-review: sign off (~1k) |
| _rows added per dispatch as the spec runs_ | | | |

# 009 — Sell Plan List: Tasks

**Status**: Draft — pending sign-off

Drafted against the approved `spec.md` (Approved 2026-09-22) and the draft
`plan.md` in this directory, for branch `009-sell-plan-list` off `main`
(`8124f12`). No new technical decisions are made here — every call below
traces to a plan section; where a task says "per plan," that section is the
authority. Runs under `CLAUDE.md`'s model policy **as amended 2026-09-19**:
the `sdd-planner`, the `skeptical-reviewer` (sign-off, per-phase, per-task,
decision reviews, pre-merge sweep), the `sdd-implementer` and the
`general-purpose` device-pass agent all run at `opus`, their definitions'
default, so **no dispatch carries a model override**; the session runs at
`opus` medium. Involvement level: **product owner** — the person attests by
using the app at the pauses and decides escalations; technical sign-off is the
`skeptical-reviewer`'s.

**Foundational phase**: **Phase 1** (T001–T004) — the two stored dates every
screen reads, the copy table and the summary three readers share, the one
writer of plan state and the carry-over, and the hook that runs it. Phases
2–4 are view models and screens over that; Phase 5 is verification.
**Tasks marked `review: per-task`**: **T003** (`SellPlanStore` — every host's
create and delete and the one-time carry-over go through it; a wrong delete
touches sold history, a wrong carry-over resurrects deleted plans or carries
none) and **T004** (`SyncMonitor.onSettled` — `SyncMonitor` feeds every empty
state in the app, and the hook's ordering is what makes the carry-over
sync-safe). Every other task gets the default one review per phase.

**Walkthrough marks and the pause cadence.** Phases 1 and 2 are marked
`walkthrough: none` — nothing a person can see changes — so under the default
cadence they run on after their phase reviews without stopping, unless
something unexpected bears on spec adherence. **The first pause is Phase 3's
end**, then Phase 4's; Phase 5 pauses only for the person's own steps and the
merge.

Ordering note: the model first, since every test writes or reads the plan;
then the copy and summary the store and the rows both need; then the store,
so the view models have something real to call; then the hook, so the
carry-over runs before any screen reads a plan. Phase 2 is view models only.
Phase 3 lands the two existing screens a plan changes (the wanted item's page,
the Sell Plan screen), which is the smallest thing the person can try; Phase 4
the new tab and card, with the UI tests last so they run against the final
layout.

House rules carried over: one commit per completed task, referencing its ID;
every guard **mutation-verified** before it lands, the Done note recording
what was broken and what went red; a task is not done until
`scripts/verify.sh` is green and its actual output is reported (suite-level
selectors, count checked — per-function Swift Testing selectors run zero
tests); **persisted-state assertions refetch on a second `ModelContext`**;
every new or rewritten source scan **`#require`s its anchor**, and compares
whole literals rather than substrings (`015` T007); **fixture values differ
from what a broken implementation would produce** (`015` As built — a date
distinct from `createdAt`, a sale price distinct from a current value);
never write the literal `#Preview` inside a doc comment in a scanned file
(`015` T009's landmine: `SourceScan.production` truncates there). Seven new
production files land in synchronized folders — **no `.pbxproj` edit**; if
the build cannot see a new file, the new `Views/Plans/` folder or the new
imageset, stop and flag. **No test opens a network connection.**

Cadence: each dispatch gets a **task bundle** assembled with shell — task
line, plan section, acceptance criteria, files, pattern file — and the
implementer is told not to read `plan.md`/`spec.md`/`tasks.md` in full;
verification is `scripts/verify.sh` and nothing more verbose, re-run by the
orchestrator for T003 and T004 and taken from the implementer's verbatim
output otherwise; reviews on a bundle cut after `git add -A`, one review and
at most one re-review; **one implementation session for the whole spec**; the
device pass in a `general-purpose` agent (the `sdd-implementer` has no
simulator tools). Everything the person reads is plain language.

Handoff notes for the pause reports:

- **Phase 3 — what can be tried**: open a wanted item with no plan — it
  offers **Create a sell plan**; tap it, back out without ticking anything,
  and it reads **View your sell plan / Nothing set aside yet**. Tick two
  candidates, back out: "2 items set aside". Sell both from the plan: the page
  still says View your sell plan, now "2 sold toward it" — the plan did not
  vanish when it succeeded. Delete the plan from the "…" on the Sell Plan
  screen: read the alert, confirm; the page offers Create again, the two sales
  are still on the Items tab's Sold side, and creating a new plan shows them
  in its Sold section. **If the walkthrough store still holds `015`'s
  dataset**, its saved plan should read View your sell plan without having
  been re-made — on its page even before the carry-over runs, since a row
  awaiting it already counts (plan Q2). The carry-over itself runs only after
  a successful iCloud sync or on a signed-out device, never when iCloud
  failed to load (plan Q3), so on a simulator without iCloud the orchestrator
  should say which case it is in before the person looks. Readings to put as questions: the Sell
  Plan's Delete sits behind a "…" next to Buy (plan Q12); the fallback line
  "Nothing set aside yet" and the "<n> sold toward it" wording.
- **Phase 4 — what can be tried**: the fourth tab, its two sides, sorting
  each side, a Buy swipe moving a plan to Completed, a delete swipe, opening a
  completed plan as a record, the Dashboard card taking you to Active. Put as
  questions, not facts: **R1** (the record has no figures card), **R2** (a
  completed row's picture is always the empty slot — the photo moved to the
  bought item in `015`, and the spec's "every row carries the thumbnail"
  can't be met there without changing what buying does), **R3** (carried-over
  plans are dated at the update, so they sort together), **R4** (no card on an
  empty Dashboard), **R5** (Delete all wanted items leaves completed plans),
  **R6** (no search, chips or summary line), **R7** (on iCloud, plans carry
  over only after the first successful sync of the launch — "Catching up"
  until then, and for as long as a device stays offline), the sort labels
  ("Newest" on Completed means date bought), the past-tense line on completed
  rows, and the tab icon (Decision 8 — drawn to match, revisitable).

## Phase 1 — Foundations: the plan, its writer, its carry-over (**foundational**) · walkthrough: none — adds two stored dates, a copy table, a summary type, the plan writer and a launch hook; no screen reads any of them yet

- [ ] **T001 — `WishlistItem.sellPlanCreatedAt`, `sellPlanCheckedAt`, `hasSellPlan`, and the CloudKit claim.**
  Per plan §1, Q1, Q2. Both fields declared **without an initializer** (the
  `boughtDate` precedent) with plan §1's doc comments; `hasSellPlan` beside
  `isBought`; `init` gains `self.sellPlanCheckedAt = .now` and no parameter.
  Add a sentence to `CloudKitSchemaTests`' doc comment naming these as the
  third thing it guards. Also `awaitsCarryOver`, plan §1's computed
  predicate, read-only (tested at T003, its first reader). Pattern:
  `boughtDate` and `isBought` in
  `Trove/Models/WishlistItem.swift`. Tests (`ModelTests`): **G2** — a fresh
  entry reads `hasSellPlan == false` and a `sellPlanCheckedAt` at or after a
  clock read taken before `init`; one with a date reads true (mutations: drop
  the init stamp → red; invert the predicate → red). **G1** — make
  `sellPlanCreatedAt` `@Attribute(.unique)`, confirm
  `CloudKitSchemaTests.schemaMeetsCloudKitRequirements` (and
  `TwoStoreContainerTests`) red, revert, record both outputs. Confirm
  `ExportSchemaTests` and `ImportSchemaTests` green unedited (criterion 18).
  Files: `Trove/Models/WishlistItem.swift`, `TroveTests/ModelTests.swift`,
  `TroveTests/CloudKitSchemaTests.swift` (comment).
  **Verify:** `scripts/verify.sh` green; both mutations recorded verbatim.

- [ ] **T002 — `SellPlanCopy` and `SellPlanSummary`.**
  Per plan §2, §3, Q5–Q7. New `Trove/Models/SellPlanCopy.swift`
  (`nonisolated enum`, no SwiftUI, every string in plan §3's table) and
  `Trove/Models/SellPlanSummary.swift` (`setAsideCount`, `soldTowardCount`,
  `isCovered`, `rowLines(boughtDate:)`, `entrySubtitle`, and the statics
  `soldCents(of:)` and `isCovered(soldCents:estimatedCostCents:)`, per plan
  §2). `SellPlanViewModel.soldValueCents` becomes
  `SellPlanSummary.soldCents(of: soldItems)` in this task — one sum, two
  readers (sign-off finding 7). Pattern: `Trove/Models/PurchaseCopy.swift`
  for the table and its test; `SellPlanViewModel.soldItems`/`soldValueCents`
  for the sold-toward reading.
  Tests: new `TroveTests/SellPlanCopyTests.swift` — **G3**: every string by
  literal, both plural forms of each counted string, and the two delete
  messages split into sentences with **exactly one** differing (mutation:
  reword a shared sentence in one branch → red). New
  `TroveTests/SellPlanSummaryTests.swift` — **G4**: the five covered cases of
  plan §2, including the fixture where `SellPlanViewModel.selectedValueMeetsCost`
  is true and `isCovered` false, and the item whose `currentValueCents` exceeds
  the estimate while its sale price doesn't; `soldTowardCount ==
  SellPlanViewModel.soldCount` and `soldCents == soldValueCents` over one
  entry; `rowLines` on both sides with each count at 0 and non-zero — no
  line for a zero (criterion 7) — the bought date first on Completed, Covered
  last and only when covered; `entrySubtitle`'s three readings (mutations:
  `>` for `>=`; drop the zero-estimate guard; add the selection's value;
  read `currentValueCents`; emit `setAside(0)`; swap the subtitle's
  fallbacks — each red).
  Files: the two new production files, the two new test files,
  `Trove/ViewModels/SellPlanViewModel.swift` (`soldValueCents` only).
  **Verify:** `scripts/verify.sh` green, both new suites **in the count**;
  mutations recorded.

- [ ] **T003 — `SellPlanStore` — create, delete, carry-over. `review: per-task`.**
  Per plan §4, Q2, Q4. New `Trove/Models/SellPlanStore.swift` with the four
  functions plan Q4 declares, callers save except `runCarryOver`
  (`carryOver`, then one save **only if `context.hasChanges`**, `rollback()`
  on refusal, its doc comment saying the rollback discards every pending
  change on the main context). `create` refuses a bought
  entry and keeps an existing date; `delete` clears `sellPlanCreatedAt` and
  `plannedSaleItems` **and nothing else**; both stamp `sellPlanCheckedAt` when
  nil; `carryOver` over `#Predicate<WishlistItem> { $0.sellPlanCheckedAt == nil }`
  planning each row that `awaitsCarryOver`, exactly as plan §4 says. Pattern: `Trove/Models/ItemSaleStore.swift` and
  `WishlistPurchaseStore.swift` (the enum, the contract, "callers save" in
  their words); no view ever names `SellPlanStore`. Tests: new
  `TroveTests/SellPlanStoreTests.swift`, every
  persisted assertion on a **second `ModelContext`** —
  **G5** `create`: `sellPlanCreatedAt == now` with `now` distinct from the
  entry's `createdAt`; a second call keeps the first date; a bought entry
  returns false and gains nothing (mutations: rewrite the date → red; drop
  the bought guard → red);
  **G6** `delete`, on an active plan and on a completed one (criteria 10–12):
  plan and selection gone; the entry still present; `itemsSoldToward` the
  same ids in the same number; every `Item` in the store with identical
  `soldDate`, `salePriceCents`, `currentValueCents`, `desireToKeep` and
  count; a delete on an **unchecked** row leaves it checked, so a following
  `carryOver` makes no plan of it (mutations: clear `itemsSoldToward` → red;
  keep the selection → red; clear one item's sale → red; delete the entry →
  red; drop delete's nil-stamp → the unchecked leg red);
  **G7** `carryOver`, the six rows of plan §4 in one store: the first three
  get a plan dated `now`, the last three stay planless, all six end checked;
  a second run returns 0 and changes nothing; **the checked, planless row
  with sold-toward history is never given a plan** (criterion 12's "does not
  come back") (mutations: drop the checked predicate → the resurrection leg
  red; count only the selection → the sold-toward-only and bought legs red;
  stamp only rows given a plan → **the all-six-checked leg** red — the
  idempotency leg stays green under it, since a second run makes no plan
  either way (sign-off finding 5); write the row's `createdAt` → the date
  leg red). Plus `awaitsCarryOver`'s own cases on `WishlistItem` (selection;
  sold-toward; neither; checked) — the one predicate `carryOver` and the
  pending displays share.
  Files: `Trove/Models/SellPlanStore.swift` (new),
  `TroveTests/SellPlanStoreTests.swift` (new).
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every
  mutation recorded; the new suite in the count.

- [ ] **T004 — `SyncMonitor.onSettled` and the carry-over at launch. `review: per-task`.**
  Per plan §4 and Q3 (revised at sign-off, finding B1). `SyncMonitor.init(mode:onSettled:)`
  (default nil) and `private(set) var settledCount`; `settle()` (hook, then
  the count) called at the end of `init` **for `.ephemeral` only** — never
  `.localOnly` — and in `record(_:)` exactly as plan §4's snippet: on a
  successful import, or a finished **failed setup event**, **never** on a
  failed import, and **before** `completedImports` moves. The trigger is
  those two events, not the `.unavailable` edge — `phase(after:from:)` maps
  a failed import to `.unavailable` too. `TroveApp.init`: the two `UITestSeed` blocks move **above** the
  `SyncMonitor` construction (they need only the store), and the monitor is built with
  `{ SellPlanStore.runCarryOver(in: context, now: .now) }` over a local
  `context = store.container.mainContext`. Doc comments say why the seeds
  moved. Pattern: `SyncMonitor.record` itself; `TroveApp.init`'s existing
  structure. Tests (`SyncMonitorTests`): **G8** — an `.ephemeral` monitor
  calls its hook once at init; `.localOnly` and `.cloudKit` ones don't;
  recording a successful import-finished event calls it once **and the hook
  reads `completedImports` at its old value**; a finished failed setup calls
  it once; **a successful setup followed by a finished failed import calls it
  never** (the phase reads `.unavailable`); an export event and an in-flight
  import call it never; `settledCount` rises by one after each call and not
  otherwise (mutations: call the hook after the bump → the ordering leg red;
  trigger on the `wasWaiting && !mayStillBeImporting` edge → **the
  failed-import leg red**; fire at init in `.localOnly` → red; drop the
  `.ephemeral` init call → red; fire on exports → red). The launch wiring itself is covered end to end by T014's
  first UI test, not by a scan — say so in the Done note.
  Files: `Trove/App/SyncMonitor.swift`, `Trove/App/TroveApp.swift`,
  `TroveTests/SyncMonitorTests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs);
  `scripts/verify.sh ui` once, green with the same count as before the task
  (the seeds moved; every existing UI test must still start from its own
  state); mutations recorded.
  **Phase 1 closes here — `walkthrough: none`; after its review, run on.**

## Phase 2 — View models · walkthrough: none — the view models the screens will read; no view calls any new member yet, and the router's new tab has no entry in the tab bar until Phase 4

- [ ] **T005 — `PlansViewModel`.**
  Per plan §5, Q8–Q10, Q13. New `Trove/ViewModels/PlansViewModel.swift`
  exactly as plan §5 declares it: one fetch split into active/completed rows
  and the unbought count; `show(_:)` sets and reloads and clears nothing;
  the two static comparators with `ManualOrderHelper.areInCustomOrder` as
  the fallback; the four empty reasons with `stillSyncing` first — chosen
  while importing **or while any row `awaitsCarryOver`** (plan Q10); each
  row's `lines` from `SellPlanSummary.rowLines`; `settledCount` passed
  through from the monitor; `markBought` (`WishlistViewModel.markBought`'s body over the looked-up
  entry, into its own `purchaseFailureMessage`); `deletePlan(id:)`. No
  SwiftUI import. Pattern: `ItemListViewModel` (sides, per-side sort,
  `show`, `areInSoldOrder`), `WishlistViewModel` (`markBought`,
  `makePurchaseFormViewModel(for:)`). Tests: new
  `TroveTests/PlansViewModelTests.swift` — **G10** membership per plan §5
  (criteria 2, 3, 13); **G11** the two sort fixtures of plan §5, the tie
  asked of the static comparator in both argument orders, per-side
  persistence across `show`, a fresh view model on Active with both defaults
  Newest (criteria 5, 6); **G12** the four empty reasons and the precedence,
  including a not-importing monitor over a store with one row awaiting the
  carry-over → `stillSyncing` (criterion 16); rows' `lines` equal
  `rowLines` for their entries, with no zero-count line (criterion 7).
  **G13** in `WishlistDetailViewModelTests`: extend
  `everyHostSeedsThePurchaseSheetIdentically`,
  `everyHostRefusesToBuyAnEntryTwice` **and the one-landing comparison** (the
  `Landing` struct near line 1597, which catches a host whose `markBought`
  drifts from the others) to the fourth host — its fixture entry needs a
  plan, since the Plans host takes its subject from its rows — and add that
  a confirmed purchase moves the row from `activeRows` to `completedRows`
  while a purchase from each of the four hosts leaves a planless entry
  planless (criteria 3, 14). Mutations: `active` read from the selection; a
  comparator reversed; bought date read as plan date; tie by name; one
  shared sort for both sides; `stillSyncing` below `noPlans`; the awaiting
  check dropped; `?? 0` in the fourth seed; the fourth host skipping its
  save → the landing leg — each red.
  Files: `Trove/ViewModels/PlansViewModel.swift` (new),
  `TroveTests/PlansViewModelTests.swift` (new),
  `TroveTests/WishlistDetailViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green, the new suite in the count;
  mutations recorded.

- [ ] **T006 — `SellPlanViewModel`: the completed record and `deletePlan`.**
  Per plan §6 and Q11. `isCompleted`, `offersPurchase`, `offersDelete`,
  `boughtDate`, `deletePlan()`; `toggle` and `markSold` write nothing on a
  completed plan; `load()` builds no pool for one. Nothing else in the file
  changes — the ranking, the figures and `markBought` are the spec's
  Non-goals. Keep every new identifier clear of `SellPlanFramingTests`'
  terms. Pattern: the file's own `markSold`/`markBought` for the intent
  shape. Tests (`SellPlanViewModelTests`): **G14** per plan §6, on a second
  context (mutations: drop the `toggle` guard → red; build the pool for a
  bought entry → the `candidates` leg red; `deletePlan` clearing
  `itemsSoldToward` → red).
  Files: `Trove/ViewModels/SellPlanViewModel.swift`,
  `TroveTests/SellPlanViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T007 — `DashboardViewModel`'s active count, and the router's fourth tab.**
  Per plan §8 and Q17. `activePlanCount`, `showsPlansCard`, `plansLine`,
  `settledCount` passed through from the monitor (a test: recording a failed
  setup on the view model's monitor moves it);
  `AppRouter.Tab.plans` (fourth), `plansPath: [UUID]`, `wantsActivePlans`,
  `showActivePlans()`, `clearPlansRequest()`. Pattern: `hasSales`/`soldLine`
  in `DashboardViewModel`; `showSoldItems`/`wantsAddItemForm` in
  `AppRouter`. Tests: **G15** in `DashboardViewModelTests` (completed and
  planless excluded; false at 0; false in a scope while plans exist — P6) and
  `AppRouterTests` (tab, popped path, raised and cleared flag, `.plans` last
  in `allCases`). Mutations: drop `boughtDate == nil` from the predicate →
  red; drop `scope.isEmpty` → red.
  Files: `Trove/ViewModels/DashboardViewModel.swift`,
  `Trove/ViewModels/AppRouter.swift`, `TroveTests/DashboardViewModelTests.swift`,
  `TroveTests/AppRouterTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.
  **Phase 2 closes here — `walkthrough: none`; after its review, run on.**

## Phase 3 — The wanted item's page and the Sell Plan screen · walkthrough: yes — on a wanted item, Create a sell plan makes the plan at the tap; backing out reads View your sell plan / Nothing set aside yet; selling everything set aside leaves it View your sell plan with "<n> sold toward it"; the plan's "…" deletes it after an alert, the page offers Create again, and the sales stay on the Items tab's Sold side

- [ ] **T008 — The wanted item's entry point (P9), created at the tap.**
  Per plan §7 and Q7, Q19. `WishlistDetailViewModel`: `hasSellPlan` from the
  stored plan **or** `awaitsCarryOver`, `sellPlanSummary` replacing
  `plannedSaleCount`, the title from `SellPlanCopy` and the subtitle from
  `sellPlanSummary.entrySubtitle`, and `openSellPlan()` (which stores an
  awaiting row's plan). The type's header comment ("No ranking or Sell Plan
  logic lives here") is rewritten to say the page now creates a plan through
  `SellPlanStore` and still computes no candidates. `WishlistDetailView.findItemsToSell`'s action becomes
  `if viewModel.openSellPlan() { sellPlanRoute = … }` and nothing else in the
  view changes. `PurchaseCopy`'s doc comment stops saying the entry-point
  strings live inline. **Rewrite, don't loosen**, the four T012c tests
  (`WishlistDetailViewModelTests.swift:~320–400`) to the new rule; record the
  mutation the old ones would have passed (a plan with nothing set aside
  reading "Find items to sell"). In `TroveUITests`, the two `-seedSellPlan`
  tests tap "Create a sell plan" instead of "Find items to sell" — the label
  is the only change. Pattern: the existing T012c members. Tests: **G16** per
  plan §7 (mutations: swap the set-aside and sold fallbacks → red; return
  "0 items set aside" → red; re-create on a second `openSellPlan` → the
  date leg red; drop `awaitsCarryOver` from `hasSellPlan` → the awaiting row
  reads "Create a sell plan" → red).
  Files: `Trove/ViewModels/WishlistDetailViewModel.swift`,
  `Trove/Views/Wishlist/WishlistDetailView.swift`,
  `Trove/Models/PurchaseCopy.swift` (comment), `TroveTests/WishlistDetailViewModelTests.swift`,
  `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T009 — The Sell Plan screen: the completed record, the "…" delete, and `DetailOverflowMenu`'s delete-only form.**
  Per plan §9, Q11, Q12, Q19. `DetailOverflowMenu`: `edit` becomes `Row?`, a
  new `init(noun:delete:)`, `if let edit` in the body; its doc comment gains
  why (Q12) beside `015`'s paragraph, which stays. `SellPlanView`: the body's
  `isCompleted` branch, `record(for:)`, the two gated toolbar items, the
  delete alert and `@State isConfirmingDelete`, exactly as plan §9. Pattern:
  `WishlistDetailView`'s delete alert; `content(for:)`'s heading. Tests —
  **rewrite `015`'s G18**
  (`WishlistPurchaseWiringTests.theSellPlanOffersMarkAsBoughtOnlyWhileItsEntryIsStillThere`)
  to the `offersPurchase` gate and re-run the mutation that proves the
  rewrite matters: gate Buy on `wishlistItem != nil` → the **old** guard green,
  the new one red — record both, as `015` T009 did. **Update**
  `SellPlanWiringTests.theSoldSectionIsHostedUnderTheEmptyStateToo` to three
  hosts (count 4) with a leg that the record hosts it inside
  `if viewModel.hasSales`. **G17** new legs in `SellPlanWiringTests` per plan
  §9 (mutations: `viewModel.toggle` or `SellPlanRow(` put into `record(for:)`
  → red; `dismiss()` outside the `deletePlan()` branch → red; the "…" given a
  `Button` → red). `MenuPolicyTests` green unedited (`DetailOverflowMenu(` is
  not a system menu); confirm with a real `Menu` added **in page content,
  inside `record(for:)`** — not the toolbar — → red, reverted. `SellPlanFramingTests` green unedited.
  Files: `Trove/Views/Wishlist/SellPlanView.swift`,
  `Trove/Views/Shared/DetailOverflowMenu.swift`,
  `TroveTests/SellPlanWiringTests.swift`,
  `TroveTests/WishlistPurchaseWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` once at the
  phase end, count recorded; mutations recorded.
  **Phase 3 closes here — pause for the person** (what to try is in the
  handoff note above).

## Phase 4 — The Plans tab and the Dashboard card · walkthrough: yes — a fourth tab, Plans, opening on Active: rows with picture, name, category, what is set aside, what sold toward it and a quiet "Covered"; its own sort on each side; swipe right on an Active row to Buy and watch it move to Completed; swipe left to delete; a Completed row opens as a record with the date bought and no actions but Delete; the Overview's "<n> active sell plans" card lands on Active

- [ ] **T010 — `SideSwitch` for two screens.**
  Per plan §10 and Q14. Generic over `Side`, the constants into
  `SideSwitchMetrics`, the Items constrained `init(side:select:)` keeping
  every word, identifier and measurement it has today, and the Plans one with
  `SellPlanCopy` labels, `plans.sideSwitch`, and the half width **set from the
  measurement**, not guessed. `ItemListView.swift` does not change.
  `ItemListSidesWiringTests`' `SideSwitch.slideDuration` reference follows the
  constant — a rename, not a change to what it asserts. Pattern: the file
  itself; `ItemListHeaderLayoutTests` for a scratch render. Tests: **G18** —
  each label of both switches, rendered at the switch's own font and weight,
  is narrower than its half less 4 pt each side (mutation: Plans' half at
  50 pt → red); `ItemListSidesWiringTests` green.
  Files: `Trove/Views/Items/SideSwitch.swift`,
  `TroveTests/ItemListSidesWiringTests.swift`, `TroveTests/PlansWiringTests.swift`
  (new here, holding G18; T011 extends it).
  **Verify:** `scripts/verify.sh` green; the measured width in the Done note.

- [ ] **T011 — `PlansView`.**
  Per plan §11, Q8, Q12, Q13. New `Trove/Views/Plans/PlansView.swift` with its
  private `PlanRowView`, exactly as plan §11 describes. Not yet in the tab bar
  (T012). Pattern: `Trove/Views/Wishlist/WishlistView.swift` for the file
  whole — header, `dropdownHost`, the `List` and its row insets and
  background, both swipe blocks, the sheet, the alerts, `.refreshable`; its
  `WishlistRow` for the row's head; `ItemListView` for `router.itemsPath`
  and the request applied on appear. Tests:
  `TroveTests/PlansWiringTests.swift` (T010 made it) — **G19** per plan §11 (mutations: the
  leading block outside the Active gate → red; the cancel closure emptied →
  red; a `formattedAsWholeCurrency` or a `.currency(` format added to the
  row → red; a `SellPlanCopy.setAside(` composed in `PlanRowView` instead of
  drawing `row.lines` → red; a `SortDropdown` with
  `isManualOrder: { _ in true }` → red; the `settledCount` reload dropped →
  red); `.onChange(of: viewModel.settledCount)` beside the
  `completedImports` reload; add
  `"Trove/Views/Plans/PlansView.swift"` to `purchaseHosts` in
  `WishlistPurchaseWiringTests` (the refusal alert); `MenuPolicyTests` green
  unedited. **Flag if** the new folder is not in the build. Say in the Done
  note that which clause each host passes to `deleteMessage(isCompleted:)`
  is guarded by no automated test and is read at T015 (plan §11).
  Files: `Trove/Views/Plans/PlansView.swift` (new),
  `TroveTests/PlansWiringTests.swift`, `TroveTests/WishlistPurchaseWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T012 — The fourth tab and its icon.**
  Per plan §11, Q15, Q17. `design/icons/tab-plans.svg` as plan Q15 draws it,
  copied into `Trove/Assets.xcassets/TabPlans.imageset/` with
  `TabWishlist`'s `Contents.json` (template, vector preserved);
  `ContentView`'s fourth `Tab` bound to `$router.plansPath`, and its doc
  comment's "Three, not four" replaced with what `009` does. Pattern:
  `TabWishlist.imageset`; `ContentView`'s Items tab. Tests: **G20** —
  `TabIconTests.assetNames` gains `TabPlans`, the distinctness test becomes
  four (mutations: drop `template-rendering-intent` → red; copy
  `tab-wishlist.svg`'s bytes → the distinctness leg alone red). Note `015`
  T008: an asset change makes `xcodebuild test` much slower — budget for it.
  Files: `design/icons/tab-plans.svg` (new), the imageset (new),
  `Trove/App/ContentView.swift`, `TroveTests/TabIconTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T013 — The Dashboard card.**
  Per plan §12 and Q16. New `Trove/Views/Dashboard/PlansCard.swift`;
  `DashboardView` composes it below the Sold card inside
  `if viewModel.showsPlansCard`, action `router.showActivePlans()`, and
  reloads on `viewModel.settledCount` beside `completedImports` (plan Q3 —
  sign-off finding 3: the launch tab must pick up a carry-over that landed
  on a failed setup, which moves no import count). Pattern:
  `Trove/Views/Dashboard/SoldCard.swift` for the chrome; the Sold card's
  host block for placement. Tests: **G21** in `DashboardWiringTests` (one
  composition, inside the gate, the right action — mutations: move it out of
  the gate → red; call `showSoldItems()` → red; drop the `settledCount`
  reload → red).
  Files: `Trove/Views/Dashboard/PlansCard.swift` (new),
  `Trove/Views/Dashboard/DashboardView.swift`, `TroveTests/DashboardWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T014 — The `-seedPlans` seed and the UI tests, run twice.**
  Per plan §13 and Q18. `UITestSeed.plansArgument = "-seedPlans"`,
  `shouldSeedPlans(mode:arguments:)` gated on `.ephemeral`, and
  `plans(into:now:)` with plan §13's collection, written through
  `SellPlanStore.create`, `ItemSaleStore.markSold` and
  `WishlistPurchaseStore.markBought` — the Fuji row's `sellPlanCheckedAt` set
  to nil, with a comment saying why it is the one row no writer made; its
  block in `TroveApp.init` beside the other seeds (above the monitor, T004).
  Tests: **G9** in `UITestSeedTests` (refuses a persistent store with every
  flag set; the seed's rows; one `carryOver` over it leaves three active,
  one completed, two planless); **G22** — plan §13's seven UI tests (the
  partial drag, never `swipeRight()`; "Mark as bought…" matched alone). UI
  mutations: drop the `onSettled` argument in `TroveApp.init` → the Fuji leg
  red (the launch wiring's only automated coverage); wire the Active swipe to
  `pendingDeletion` → red; the Dashboard card calling `showSoldItems()` →
  red. Then `scripts/verify.sh ui` **twice back to back**.
  Files: `Trove/App/UITestSeed.swift`, `Trove/App/TroveApp.swift`,
  `TroveTests/UITestSeedTests.swift`, `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green twice,
  both counts in the Done note; mutations recorded.
  **Phase 4 closes here — pause for the person** (what to try, and the
  readings to put as questions, are in the handoff note above).

## Phase 5 — Verification and close-out · walkthrough: none — the device pass and the documents; the person's own checks (VoiceOver, two devices) are named in T015 as their steps rather than a phase walkthrough, and nothing new is built

- [ ] **T015 — Device pass. [general-purpose agent with simulator tools; person: VoiceOver, two devices]**
  Per plan §13 and every criterion. **Upgrade in place first**: build and
  install `main`, create wanted items with a selection, with a sale toward
  them, one bought with a sale, one bought with neither, one with nothing;
  build and install this branch over it; record which appear on Active and
  Completed and which on neither — criterion 4 and plan §1's migration claim
  on a real migrated store. Then on the persistent store: a **file probe**
  in `SellPlanStore.delete` and `carryOver` (swipe opened and closed 0,
  alert Keep 0, Delete 1; a relaunch's carry-over making 0 plans), removed and
  the tree confirmed byte-identical; every Plans screen, card and the Sell
  Plan record in **both appearances**; the tab icon beside the other three;
  "Completed" whole in its half; the header's switch `minY` identical on both
  sides, empty and populated, read from the tree; the Sell Plan's Buy and "…"
  side by side; both delete alerts' text; the spoken names of a row, the
  switch, the card and the "…" read from the accessibility tree; relaunch
  (criterion 17's persistence). Findings fixed in place if routine and inside
  the footprint, else returned for a decision review; each fix a
  sub-lettered task. **[person]** Accessibility Inspector over the same
  elements; with two devices, a plan created, sold through, deleted and
  carried over on one, seen correctly on the other (criterion 17's sync
  half) — and plan Q2's three windows, each recorded as observed or not
  reached: a signed-in device launched **offline** (does setup finish
  failed and run the carry-over on an old copy?), a device returning after a
  long absence (a multi-pass import), and which write survives when a carried
  row meets a deletion made elsewhere. Also on one device, offline: an empty
  Plans side says "Catching up with iCloud" while a plan awaits the
  carry-over, not "No sell plans yet".
  **Verify:** the record in the Done note — the upgrade's result per entry,
  the probe counts, the measurements; `scripts/verify.sh all` green twice.

- [ ] **T016 — Close-out.**
  Per plan §14. Criteria 1–19 ticked in `spec.md` with per-criterion
  citations — criterion 19 **by inspection**, saying why no test can catch
  it without being the broad-scan shape `CLAUDE.md` names; criterion 17 an
  honest partial until the person's two-device step, **left unticked** as
  `014` and `015` left theirs. The Copy section's shapes replaced by the
  shipped strings; P-items → decisions; `plan.md` gains **As built**;
  `design/tokens.md`, `README.md`, `specs/ROADMAP.md` (`009` entry and
  status row; the `015` seeded-plan follow-up closed), `DECISIONS.md` (plan
  §14's list, including "once, per row" **with its limits** as T015's
  two-device step left them, and derive-on-read weighed and rejected); the
  pointers of plan Context appended in place (`grep -c` each, the `014`
  T001 shape). Re-run G7's resurrection mutation against the finished tree
  (T003 wrote it before any host existed). Then the pre-merge
  `skeptical-reviewer` sweep over `git diff main...HEAD`, bundle cut after
  `git add -A`, and the PR marked ready.
  Files: `specs/009-sell-plan-list/spec.md`, `plan.md`, this file,
  `design/tokens.md`, `README.md`, `specs/ROADMAP.md`, `DECISIONS.md`,
  `specs/015-mark-as-bought/plan.md` (pointers), `specs/001-core-inventory/plan.md`
  (pointer, if it carries the "three tabs" rule).
  **Verify:** everything committed and pushed; `scripts/verify.sh all` green
  with both count lines recorded here.

## Tier log

`CLAUDE.md`'s model policy **as amended 2026-09-19**: every role runs at
`opus`, each definition's own default, so **no dispatch carries a model
override**; the orchestrating session runs at `opus` medium. Every Tier entry
is the resolved name, never "default." Token usage from each subagent return
is filled in as the spec runs; escape-hatch misses are recorded here too.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| Spec session (this spec's `spec.md`, drafting, review pass and approval) | `opus` (raised to high; moved to Opus 5.5 on 2026-09-22) | orchestrating seat, not measured separately | Draft 2026-09-21, approved 2026-09-22 with Decisions 1–10; nothing left open |
| `sdd-planner` — plan.md and tasks.md (draft) | `opus` | ~380k (budget counter, cache re-reads included) | 16 tasks, 5 phases, 23 guards; no product question returned; one spec/code inconsistency reported (plan R2) |
| `skeptical-reviewer` — plan/tasks sign-off | `opus` | _to fill_ | B1 (carry-over fired on a failed import and in `.localOnly`); finding 2 (R2, R4) a product question, sent to the person; 10 non-blocking |
| `sdd-planner` — sign-off fix pass (same agent resumed) | `opus` | ~65k (budget counter) | B1 fixed: event-based trigger, `.localOnly` skipped, `settledCount`, `awaitsCarryOver` read-only for the pending window; derive-on-read weighed and rejected in Q2; findings 3–12 applied, none declined; R2/R4 and `spec.md` untouched |

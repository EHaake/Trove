# 009 — Sell Plan List: Tasks

**Status**: Signed off (2026-09-22) by the `skeptical-reviewer`; the spec-conformance summary approved by the person on 2026-09-22

**Status (Phase 4A — Amendment A, and its changes to T015/T016)**: Signed off (2026-09-23) by the `skeptical-reviewer` after one re-review; RA2 answered (b) by the person on 2026-09-23

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
**Amendment A (Phase 4A, T017–T021)**: Phase 4A is **not** foundational as
a phase; its one schema change, **T017** (the purchase's record of the item
it became — a synced relationship pair and `WishlistPurchaseStore`, whose
delete rules decide whether deleting a row can take owned gear with it), is
marked `review: per-task`. T018–T021 get the phase review. Numbered T017 on,
not sub-lettered: sub-letters in this file mark walkthrough fixes logged
against a task, and these are planned work; they sit before T015 by
dependency.

**Walkthrough marks and the pause cadence.** Phases 1 and 2 are marked
`walkthrough: none` — nothing a person can see changes — so under the default
cadence they run on after their phase reviews without stopping, unless
something unexpected bears on spec adherence. **The first pause is Phase 3's
end**, then Phase 4's, then **Phase 4A's** (Amendment A, `walkthrough: yes`);
Phase 5 pauses only for the person's own steps and the merge.

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
  been re-made once the carry-over has run *(superseded: after the sign-off
  re-review a row awaiting the carry-over reads "Create a sell plan" — plan
  Q2, §7)*. The carry-over itself runs only after
  a successful iCloud sync or on a signed-out device, never when iCloud
  failed to load (plan Q3), so on a simulator without iCloud the orchestrator
  should say which case it is in before the person looks. Readings to put as questions: the Sell
  Plan's Delete sits behind a "…" next to Buy (plan Q12); the fallback line
  "Nothing set aside yet" and the "<n> sold toward it" wording.
- **Phase 4 — what can be tried**: the fourth tab, its two sides, sorting
  each side, a Buy swipe moving a plan to Completed, a delete swipe, opening a
  completed plan as a record, the Dashboard card taking you to Active. Put as
  questions, not facts: **R1** (the record has no figures card), **R2** is no
  longer a question — the person decided it (spec Decision 11): say that
  completed rows show no picture and no slot, and check it reads right, **R3** (carried-over
  plans are dated at the update, so they sort together), **R4** (decided, Decision 12: no card on an
  empty Dashboard), **R5** (Delete all wanted items leaves completed plans),
  **R6** (no search, chips or summary line), **R7** (on iCloud, plans carry
  over only after the first successful sync of the launch — "Catching up"
  until then, and for as long as a device stays offline), the sort labels
  ("Newest" on Completed means date bought), the past-tense line on completed
  rows, and the tab icon (Decision 8 — drawn to match, revisitable).
- **Phase 4A (Amendment A) — what can be tried**: on the Plans
  tab, a "…" beside Sort (there over an empty side too) opens Settings, and
  every tab's "…" does. Put a picture on a wanted item, make a plan, buy it:
  its Completed row shows that picture; sell the item it became and the
  picture stays; delete that item and the row keeps its slot with the grey
  placeholder. A plan completed before this update shows the placeholder too
  — every row on both sides now has the same picture slot. In Settings,
  under Delete, **Delete All Sell Plans…** is in rust and dimmed when there
  are none; with plans it asks "Delete all <n> sell plans?", and afterwards
  both Plans sides are empty while every wanted item, owned item and sale is
  where it was, and each wanted item's page offers "Create a sell plan"
  again. Put as questions, not facts: the confirmation's wording (plan QA4)
  — read it out whole: "Nothing you own or sold is touched, and everything
  on your wishlist stays there. What sold toward them stays on the record.
  If you're signed in to iCloud, the plans are removed from your other
  devices as well. This can't be undone.";
  **RA2** — answered (b) by the person on 2026-09-23: a wanted item whose old
  plan is still waiting for iCloud to catch up *is* counted and removed;
  **RA3** (the "Export first if you want a copy." line stays under the new
  row, though plans are in no export); **RA4** (Delete All Items now also
  turns completed plans' pictures into placeholders).

## Phase 1 — Foundations: the plan, its writer, its carry-over (**foundational**) · walkthrough: none — adds two stored dates, a copy table, a summary type, the plan writer and a launch hook; no screen reads any of them yet

- [x] **T001 — `WishlistItem.sellPlanCreatedAt`, `sellPlanCheckedAt`, `hasSellPlan`, and the CloudKit claim.**
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

  **Done:** 2026-09-22. Both fields and `hasSellPlan`/`awaitsCarryOver` on `WishlistItem`; new suite `WishlistSellPlanFieldTests` (2). Mutations: init stamp dropped → `aFreshEntryIsPlanlessAndChecked` red (2 tests, 1 issue); predicate inverted → both red; `@Attribute(.unique)` on `sellPlanCreatedAt` → `CloudKitSchemaTests.schemaMeetsCloudKitRequirements` and `TwoStoreContainerTests.theProductionPairingLoadsAndSplits` red (134060). `ExportSchemaTests`/`ImportSchemaTests` green unedited. `scripts/verify.sh`: 1624 tests in 225 suites passed. Implementer found red xcodebuild runs hang after the count line.
- [x] **T002 — `SellPlanCopy` and `SellPlanSummary`.**
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

  **Done:** 2026-09-22. `SellPlanCopy` (9 tests) and `SellPlanSummary` (11 tests); `soldValueCents` now `SellPlanSummary.soldCents(of:)`. Mutations, each red: `>` for `>=` (2 issues); zero-estimate guard dropped (1); selection's value added (1); `currentValueCents` summed (3); `setAside(0)` emitted (2); subtitle fallbacks swapped both ways (1, 2); a shared delete sentence reworded in one branch (2 — and with the literal test also edited to match, the one-sentence-differs test alone still red). `scripts/verify.sh`: 1644 tests in 227 suites passed. The inline entry-point strings in `WishlistDetailViewModel` stay until T008, which rewires them.
- [x] **T003 — `SellPlanStore` — create, delete, carry-over. `review: per-task`.**
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

  **Done:** 2026-09-22. `SellPlanStore` (create, delete, carryOver, runCarryOver) and `SellPlanStoreTests` (16, every persisted read on a second context). Mutations, each red: second create rewrites the date; bought guard dropped; `itemsSoldToward` cleared; selection kept (active leg — the completed leg can't see it, the purchase already emptied the selection); one item's sale cleared; entry deleted; delete's nil-stamp dropped (unchecked leg only); checked filter dropped from the fetch (resurrection leg's checked-date line, idempotency, unchecked-delete — its plan-nil line stays green because `awaitsCarryOver` re-checks, and goes red when both layers go); count only the selection; stamp only planned rows (all-six-checked leg only, idempotency green as predicted); `createdAt` written; `runCarryOver`'s save removed. After the per-task review: create/delete stamping unconditionally → red (the "only when nil" legs). Untested: `runCarryOver`'s `hasChanges` condition and its rollback branch — left for the sweep. Orchestrator re-run of `scripts/verify.sh`: 1660 tests in 228 suites passed.
- [x] **T004 — `SyncMonitor.onSettled` and the carry-over at launch. `review: per-task`.**
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
  **Done:** 2026-09-22. `SyncMonitor.init(mode:onSettled:)`, `settledCount`, `settle()` at init for `.ephemeral` only and in `record(_:)` per plan §4; `TroveApp.init` moves both seeds above the monitor and passes `SellPlanStore.runCarryOver` over the main context. Seven G8 tests plus one in `UITestSeedTests`. Mutations, each red: hook after the `completedImports` bump (ordering leg); trigger on the `wasWaiting && !mayStillBeImporting` edge (failed-import leg, and the second-import leg); fire at init in `.localOnly` (both parameterized cases); `.ephemeral` init call dropped; fire on exports; after review, bump `settledCount` before the hook (failed-setup and import legs); `WishlistItem.init` not stamping → `theExistingSeedsLeaveTheCarryOverNothingToDo` red (today's seeds leave the launch carry-over nothing to do). The launch wiring — the seeds above the monitor, and the monitor running `SellPlanStore.runCarryOver` over the main context — has no test in this task; T014's first UI test covers it end to end by launching with a seeded pre-009 row and seeing it arrive as a plan, not by a source scan. Orchestrator re-run of `scripts/verify.sh`: 1667 tests in 228 suites passed; `scripts/verify.sh ui`: 25 tests, 0 failures (baseline 25).
  **Phase 1 closes here — `walkthrough: none`; after its review, run on.**

## Phase 2 — View models · walkthrough: none — the view models the screens will read; no view calls any new member yet, and the router's new tab has no entry in the tab bar until Phase 4

- [x] **T005 — `PlansViewModel`.**
  Per plan §5, Q8–Q10, Q13. New `Trove/ViewModels/PlansViewModel.swift`
  exactly as plan §5 declares it: one fetch split into active/completed rows
  and the unbought count; `show(_:)` sets and reloads and clears nothing;
  the two static comparators with `ManualOrderHelper.areInCustomOrder` as
  the fallback; the four empty reasons with `stillSyncing` first — chosen
  while importing **or while any row `awaitsCarryOver`** (plan Q10); each
  row's `lines` from `SellPlanSummary.rowLines` and its `showsThumbnail`
  (true on Active, false on Completed — spec Decision 11, plan R2);
  `settledCount` passed
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

  **Done:** 2026-09-22. `PlansViewModel` per plan §5; `PlansViewModelTests` (18); the four-host seed, landing and refusal tests extend to the Plans host, plus `aPurchaseThroughAnyHostLeavesAPlanlessEntryPlanless`. Mutations, each red: `active` from the selection (12 issues); date comparator reversed; bought date as plan date; tie by name; one shared sort; `stillSyncing` below `noPlans`; awaiting check dropped; `?? 0` in the fourth seed; the fourth host skipping its save (landing leg); `rowLines(boughtDate: nil)` (the Phase 1 review's Bought leg); completed read as `isBought` alone (planless and orphan legs); `showsThumbnail` true on Completed. After the Phase 2 review (fixture fixes): the Completed fixture's wishlist positions no longer match its name order — Completed Name comparator dropped → red; Active rows inserted out of plan-date order — Active sort reading `createdAt` → red; `completedImports` hardcoded 0 → red; the Plans host's message-clear-on-entry dropped → red; duplicate ids no longer trap (`uniquingKeysWith:`). Choices the plan left open, for the phase review: a row whose entry is gone refuses `markBought` with `PurchaseCopy.failureMessage`; `deletePlan` returns false silently; a fetch failure empties the rows (no message property in §5); `stillSyncing` applies on both sides. `scripts/verify.sh`: 1686 tests in 229 suites passed.
- [x] **T006 — `SellPlanViewModel`: the completed record and `deletePlan`.**
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

  **Done:** 2026-09-22. `isCompleted`, `offersPurchase`, `offersDelete`, `boughtDate`, `deletePlan()`; `toggle`/`markSold` write nothing on a completed plan; `load()` builds no pool for one. New suite `SellPlanRecordTests` (8), second-context reads. Mutations, each red: `toggle` guard dropped; pool built for a bought entry (`candidates` leg); `deletePlan` clearing `itemsSoldToward` (both delete legs, 5 issues). A refused delete rolls back and reloads and is silent on screen, as plan §5 says every delete is (no view reads `saveFailureMessage`; doc comment corrected after the Phase 2 review); `deletePlan` reloads on success like `markSold`. After the Phase 2 review: `markSold`'s completed guard dropped → `markSoldOnACompletedPlanWritesNothing` red (4 issues). `scripts/verify.sh`: 1694 tests in 230 suites passed.
- [x] **T007 — `DashboardViewModel`'s active count, and the router's fourth tab.**
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
  **Done:** 2026-09-22. `DashboardViewModel.activePlanCount` (whole store, per §8), `showsPlansCard`, `plansLine`, `settledCount`; `AppRouter.Tab.plans` (fourth), `plansPath`, `wantsActivePlans`, `showActivePlans()`, `clearPlansRequest()`. New suite `DashboardPlansCardTests` (4) and 4 `AppRouterTests`. Mutations, each red: `boughtDate == nil` dropped (5 issues); `scope.isEmpty` dropped (the scope leg); and `wantsActivePlans = true` dropped (the flag leg). No switch over `AppRouter.Tab` needed a case. R4's no-card-on-an-empty-Dashboard is the view's to apply at T013, as the Sold card's is. `scripts/verify.sh`: 1702 tests in 231 suites passed.
  **Phase 2 closes here — `walkthrough: none`; after its review, run on.**

## Phase 3 — The wanted item's page and the Sell Plan screen · walkthrough: yes — on a wanted item, Create a sell plan makes the plan at the tap; backing out reads View your sell plan / Nothing set aside yet; selling everything set aside leaves it View your sell plan with "<n> sold toward it"; the plan's "…" deletes it after an alert, the page offers Create again, and the sales stay on the Items tab's Sold side

- [x] **T008 — The wanted item's entry point (P9), created at the tap.**
  Per plan §7 and Q7, Q19. `WishlistDetailViewModel`: `hasSellPlan` from the
  stored plan **only** — never `awaitsCarryOver` (plan Q2, the orchestrator's
  fix after the sign-off re-review), `sellPlanSummary` replacing
  `plannedSaleCount`, the title from `SellPlanCopy` and the subtitle from
  `sellPlanSummary.entrySubtitle`, and `openSellPlan()` (which creates the plan on
  any row without a stored one — an explicit create, awaiting or not). The type's header comment ("No ranking or Sell Plan
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
  date leg red; add `|| awaitsCarryOver` to `hasSellPlan` → the awaiting row
  reads "View your sell plan" → red).
  Files: `Trove/ViewModels/WishlistDetailViewModel.swift`,
  `Trove/Views/Wishlist/WishlistDetailView.swift`,
  `Trove/Models/PurchaseCopy.swift` (comment), `TroveTests/WishlistDetailViewModelTests.swift`,
  `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

  **Done:** 2026-09-22. `WishlistDetailViewModel`: `hasSellPlan` from the stored plan only; `sellPlanSummary` replaces `plannedSaleCount`; title from `SellPlanCopy`, subtitle from `entrySubtitle` (inline strings gone); `openSellPlan()` creates at the tap, saves once, reloads. The view's action is the one-line change; `PurchaseCopy`/`PurchaseCopyTests` and `findItemsToSell` comments corrected. The four T012c tests rewritten, three added. Old-test mutation — a plan with nothing set aside reading as no plan, which the old four passed — now red (8 issues). G16 mutations, each red: fallbacks swapped; "0 items set aside"; re-create on a second tap (date leg); `|| awaitsCarryOver` in `hasSellPlan`. `openSellPlan`'s save-failure rollback untested. `scripts/verify.sh`: 1705 tests in 231 suites passed; the two `-seedSellPlan` UI tests, run alone, pass with "Create a sell plan".
- [x] **T009 — The Sell Plan screen: the completed record, the "…" delete, and `DetailOverflowMenu`'s delete-only form.**
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
  **Done:** 2026-09-22. `DetailOverflowMenu` gains the delete-only `init(noun:delete:)` (`edit` optional); `SellPlanView` branches on `isCompleted` to `record(for:)` (heading "Completed", Bought date, the Sold section or its empty line, no figures card), Buy gated on `offersPurchase`, the "…" on `offersDelete`, a Delete/Keep alert whose Delete pops only when `deletePlan()` took. `heading(_:for:)` now takes the state word (one heading shape for both). 015's G18 rewritten: Buy gated on `wishlistItem != nil` → old guard green, new guard red. Three-host test now 4 with the record's `hasSales` leg. G17 mutations, each red: `viewModel.toggle` or `SellPlanRow(` in `record(for:)`; `dismiss()` outside the `deletePlan()` branch; a `Button` in the delete gate; `soldSection` dropped from the record. `MenuPolicyTests` unedited: a real `Menu` in `record(for:)` → red, reverted. `SellPlanFramingTests` unedited, green. `scripts/verify.sh`: 1708 tests in 231 suites passed.
  **Phase 3 closes here — pause for the person** (what to try is in the
  handoff note above).

- [x] **T009a — Walkthrough finding: taps on the Sell Plan are ignored for a moment after it opens.**
  Reported at the Phase 3 walkthrough (2026-09-23): arriving on a Sell Plan
  and immediately tapping a candidate to set it aside or release it does
  nothing for a short while; after that, taps work. Diagnosis bundle to the
  `sdd-implementer` — find the cause (instrumented, not inferred), whether
  it predates `009`, and fix it if routine and inside the footprint; else
  return options for a decision review.
- [x] **T009b — Walkthrough decision: Delete is its own button, separate from Buy.**
  Per plan Q12 as amended 2026-09-23. The Sell Plan's toolbar shows Buy and
  a red Delete as two separate buttons (Delete alone on a completed plan);
  no "…" on this screen; `DetailOverflowMenu`'s delete-only initializer
  withdrawn. The G17 delete-gate leg is rewritten to the new shape and
  mutation-checked; the alert and `dismiss()`-only-when-it-took are
  unchanged.
  **Done:** 2026-09-23. Inside the `offersDelete` gate, a `ToolbarSpacer(.fixed)` then a `Button(role: .destructive)` labelled `SellPlanCopy.deleteConfirm` raising `isConfirmingDelete`; alert and `dismiss()` unchanged. `DetailOverflowMenu` restored to its pre-T009 content; `SellPlanCopy.overflowNoun` removed with its check; plan §3 table and §9 sketch updated. Guard rewritten as `theDeleteIsARedButtonOfItsOwnApartFromBuyOfferedOnlyWhileThereIsAPlan`. Mutations, each red: Delete wrapped in a planted `Menu`; Delete in a `DetailOverflowMenu` (via the Edit initializer); spacer removed; spacer after Delete; Delete ungated (`wishlistItem != nil`); `role: .destructive` dropped. `MenuPolicyTests` unedited, green. For the device pass: that the role alone draws it red in the bar, and no stray gap before a lone Delete on a completed plan. `scripts/verify.sh`: 1708 tests in 231 suites passed.
  **Done:** 2026-09-23 — not a delay. The person's second walkthrough (on the right build; the first two installs put a stale 17 September build on the simulator — an orchestrator error, see the device-pass memory) found the real cause: taps on the empty parts of a candidate's card do nothing; only the checkbox and the drawn text, figure and dial toggle. The diagnosis's injected taps all landed on drawn content, which is why it could not reproduce. Carried into T009c.

- [x] **T009c — Walkthrough finding: tapping anywhere on a candidate's card toggles it.**
  The person, 2026-09-23: only the checkbox and the text, price and desire
  gauge toggle; tapping an empty part of the card does nothing — make it
  consistent. The card's upper half (everything above 006's Mark as sold…
  strip, which stays its own target — 006 Decision 4) toggles wherever it
  is tapped. Predates `009` (`SellPlanRow`, 003/006). Guard: a UI test that
  taps an empty point of the card and sees the selection change.
  **Done:** 2026-09-23. Cause as suspected: a `.plain` button hit-tests only what it draws, and `SellPlanRow.card` had no content shape. `.contentShape(Rectangle())` added last on `card` (covers its padding and full width, stops at the strip's hairline). New UI test `testTappingAnEmptyPartOfASellPlanCardTogglesItAndTheStripStaysApart`: a tap in the card's bottom padding, placed from the strip's frame (the card's own frame shrinks without the fix, so measuring from it would have agreed with itself), flips `isSelected` and back and opens no sheet; a tap on the strip opens the sale sheet and leaves the selection. Mutation: shape removed → red (2 failures — and the tap near the strip opened the *sale sheet*: without a shape, SwiftUI gave the empty-space touch to the neighbouring button). Audit for the person, not fixed: the Dashboard's "N items not yet valued" callout has the same shape (`DashboardView.swift:382–416`); the unselected category chips (`WishlistView.swift:521`, `ItemListView.swift:877`) may not take taps in their padding. `scripts/verify.sh`: 1708 tests passed; the new UI test green alone.
- [x] **T009d — The person's standard: a destructive action is always drawn red.**
  The person, 2026-09-23: "the Delete button needs to be red to indicate a
  destructive action. This needs to be implemented as standards across the
  app so that I don't have to manually point it out every time." The
  Sell Plan's toolbar Delete draws in the app's brass tint (ContentView's
  `.tint` overrides the role's red), unlike every other Delete. Fix it, make
  the rule a written standard (`design/tokens.md`, and `CLAUDE.md` in its own
  commit), and guard it so a new destructive control that isn't red goes
  red in the suite. Shape by decision review.

  **Done:** 2026-09-23. Per plan §9a (decision review, plus a follow-up ruling on the balance anchor). The Sell Plan's toolbar Delete gets `.tint(theme.colors.accentRustText)`; `design/tokens.md` gains **Destructive actions**; `SourceScan.stripComments`' stale comment corrected (behaviour unchanged); new `DestructiveColourPolicyTests` classifies every `.destructive` by its enclosing call — 13 sites, 8 system-drawn, 5 app-drawn, 8 of 8 site-holding files balance-checked. Mutations, each red with the failure naming what was broken: the tree before the fix (SellPlanView:124 only); the Items owned-row swipe's `.tint` removed (ItemListView:475); the fix moved onto Buy; the fix commented out; Delete re-spelled in the title form uncoloured; `ButtonRole.destructive` on an uncoloured Buy (14 sites, 6 app-drawn); Settings' destructive colour brass (the exemption's pin); a URL literal in SellPlanView (balance anchor, naming the file). `scripts/verify.sh`: 1709 tests in 232 suites passed. The rendering half — does `.tint` beat the brass cascade on the glass toolbar — is the device check that follows.
## Phase 4 — The Plans tab and the Dashboard card · walkthrough: yes — a fourth tab, Plans, opening on Active: rows with picture, name, category, what is set aside, what sold toward it and a quiet "Covered"; its own sort on each side; swipe right on an Active row to Buy and watch it move to Completed; swipe left to delete; a Completed row opens as a record with the date bought and no actions but Delete; the Overview's "<n> active sell plans" card lands on Active

- [x] **T010 — `SideSwitch` for two screens.**
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

  **Done:** 2026-09-23. `SideSwitch<Side: Hashable>` with `SideSwitchMetrics` (halfWidth 62, height 32, slideDuration 0.2, `labelFont(isActive:)`); the Items `init(side:select:)` keeps every word, identifier and measurement; the Plans one uses `SellPlanCopy` labels, `plans.sideSwitch`, and a **69 pt** half — measured: at 11 pt mono Owned 33, Sold 27, Active 40, Completed 60 pt (regular and medium equal); 62 pt cannot hold Completed with 4 pt each side, 69 is the narrowest whole point that can. `ItemListView.swift` unchanged; `ItemListSidesWiringTests` follows the constant (value and scan text). New `PlansWiringTests.everyLabelOfBothSwitchesFitsItsHalf` (G18). Mutation: Plans' half at 50 pt → red (Completed, both weights). `scripts/verify.sh`: 1710 tests in 233 suites passed.
- [x] **T011 — `PlansView`.**
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
  drawing `row.lines` → red; `RowThumbnail` drawn outside the
  `row.showsThumbnail` gate → red; a `SortDropdown` with
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

  **Done:** 2026-09-23. `Trove/Views/Plans/PlansView.swift` (built from the new folder with no `.pbxproj` edit) and its private `PlanRowView`, per plan §11: header with the Plans `SideSwitch` and a per-side sort badge, the `List` with Buy as the leading swipe on Active rows only and a rust delete swipe on both sides, the purchase sheet, the refusal and delete alerts, `.refreshable`, reloads on `completedImports` and `settledCount`, the router request applied on appear; whole-row tap target (`.contentShape`). Eight G19 legs in `PlansWiringTests`; the Plans host added to `purchaseHosts`; `findItemsToSell`'s "only route" comment corrected. Mutations, each red: Buy outside the Active gate; cancel closure emptied; `formattedAsWholeCurrency` and `.currency(` in the row; `SellPlanCopy.setAside(` in place of `row.lines`; `RowThumbnail` outside its gate; `isManualOrder: { _ in true }`; the `settledCount` reload dropped; plus the delete swipe's rust tint removed → `DestructiveColourPolicyTests` red naming `PlansView.swift:251` (now 15 sites, 9 system-drawn, 6 app-drawn). Which clause each host passes to `SellPlanCopy.deleteMessage(isCompleted:)` is guarded by no automated test and is read at T015 (plan §11); this screen passes `row.isCompleted`. The sort-change reload has no unit test. `scripts/verify.sh`: 1718 tests in 233 suites passed.
- [x] **T012 — The fourth tab and its icon.**
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

  **Done:** 2026-09-23. `design/icons/tab-plans.svg` per Q15 — a faint square, an arrow (0.7 opacity, the wishlist mark's middle step) and a solid square, in the house style — copied into `TabPlans.imageset` with `TabWishlist`'s `Contents.json` (template, vector preserved; built without a `.pbxproj` edit). `ContentView`'s fourth `Tab` bound to `$router.plansPath`; its "Three, not four" paragraph replaced. G20: `TabIconTests.assetNames` gains `TabPlans`; `theFourIconsAreFourDifferentMarks`. Mutations, each red: template intent dropped (the TabPlans case); `tab-wishlist.svg`'s bytes copied in (the distinctness leg alone). `scripts/verify.sh`: 1718 tests passed; `scripts/verify.sh ui`: 26 tests, 0 failures.
- [x] **T013 — The Dashboard card.**
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

  **Done:** 2026-09-23. New `PlansCard` (SoldCard's chrome: `.extrudedPlate()` inside the button, so the whole card acts); `DashboardView` composes it below the Sold card inside `if viewModel.showsPlansCard`, action `router.showActivePlans()`, and reloads on `settledCount` beside `completedImports`. R4 (no card on an empty Dashboard) holds the way the Sold card's does: both live in the scrolling branch `body` builds only when `!viewModel.isEmpty`. G21, three tests in `DashboardWiringTests`. Mutations, each red: card out of the gate; `showSoldItems()`; the `settledCount` reload dropped; the card moved above the empty/scroll split; a second card in the empty branch. `scripts/verify.sh`: 1721 tests in 233 suites passed.
- [x] **T014 — The `-seedPlans` seed and the UI tests, run twice.**
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
  **Done:** 2026-09-23. `UITestSeed.plansArgument` / `shouldSeedPlans(mode:arguments:)` (`.ephemeral` only) / `plans(into:now:)` with plan §13's collection, written through the three stores — the Fuji row's `sellPlanCheckedAt` set nil (the one row no writer made); its block in `TroveApp.init` above the monitor. G9: three tests in `UITestSeedTests`. G22: plan §13's seven UI tests (partial-drag swipes; the completed record's Delete asserted as the bar button T009b made it). Mutations, each red on a named assertion: seed gated on the argument only; Fuji's nil line removed; a seed row missing; **the `onSettled` closure dropped, and the seeds moved below the monitor — both turn the Fuji leg red (the launch wiring's only automated coverage)**; the Active swipe wired to `pendingDeletion`; the card calling `showSoldItems()`; plus the Active sort's `load()` removed → the sort test red. The Completed side's sort-change reload has no test (one completed row in the seed). `scripts/verify.sh`: 1724 tests in 233 suites passed; `scripts/verify.sh ui` twice back to back: 33 tests, 0 failures, both runs.
  **Phase 4 closes here — pause for the person** (what to try, and the
  readings to put as questions, are in the handoff note above).

- [x] **T014a — The person, Phase 4 walkthrough: every card and chip responds anywhere in its box.**
  The person, 2026-09-23, on T009c's audit (the Overview's "N items not yet
  valued" callout, `DashboardView.swift` ~382–416; the unselected category
  chips, `WishlistView.swift` ~521 and `ItemListView.swift` ~877, whose fill is
  `Color.clear`): "Fix it now." Merged code outside `009`'s footprint, riding
  this branch at the person's instruction rather than a `fix/` branch — a
  deliberate deviation from `CLAUDE.md`'s git conventions, recorded here. Each
  gets a content shape; each gets a UI test that taps an empty point; the rule
  is written into `design/tokens.md`.

  **Done:** 2026-09-23. The eight content shapes — the Overview's unvalued callout, the Items and Wishlist category chips, the two condition chips, the category picker chip, the wishlist form's preset-amount buttons, the empty state's outlined button — each placed last on the label, landed early in `6f1b591` (an orchestrator miss, logged). Measured: at the two tested sites the hairline outline already caught taps, so the audit's gap did not reproduce; ruled at a decision review (A): keep the shapes (restyles remove outlines), guard the shape alone. `testTappingAnEmptyPartOfTheUnvaluedCalloutFollowsIt` taps a fixed point of the callout's own frame, anchored outside every text/image frame; mutation — shape deleted and `.allowsHitTesting(false)` on the outline, frame unchanged — red ("a tap on the callout's empty space … did not follow it"). The chip test was deleted: a 69 × 34 pt chip is within the label's tap reach everywhere, so no mutation could turn it red (CLAUDE.md: a test that cannot fail is deleted). `design/tokens.md` gains **Tap targets**. Rides this branch at the person's instruction ("Fix it now"), not a `fix/` branch. `scripts/verify.sh`: 1726 tests passed; the callout test green alone.
## Phase 4A — Amendment A · walkthrough: yes — the Plans tab has a "…" beside Sort (over an empty side too) that opens Settings, as every tab's does; a plan bought after this update shows the bought item's picture on its Completed row, kept when that item is sold and a grey placeholder once it is deleted, and older completed plans show the placeholder in the same slot; Settings' Delete section has a rust "Delete All Sell Plans…", dimmed with no plans, that asks "Delete all <n> sell plans?" and afterwards leaves both Plans sides empty and every wanted item, owned item and sale where it was

Per plan **Amendment A** (QA1–QA6, RA1–RA4, G24–G39). Decisions 13–15 are
built (T009b, T009d, T009c/T014a) and are not replanned here. Ordering: the
schema and its one writer first, since the row's picture reads the record;
then the row; then the Plans "…" (independent of the record); then the
Settings row it leads to; the UI tests last, against the final layout.

- [x] **T017 — The purchase records the item it became. `review: per-task`.**
  Per plan QA1. `WishlistItem.boughtItem: Item?` with
  `@Relationship(deleteRule: .nullify)` and `Item.boughtFromWishlistItem:
  WishlistItem?` with `@Relationship(deleteRule: .nullify, inverse:
  \WishlistItem.boughtItem)`, each with QA1's doc comment; neither an `init`
  parameter. `WishlistPurchaseStore.markBought` sets `wanted.boughtItem =
  item` beside `boughtDate`, after the guard and the insert; its doc
  comment's contract gains "records the item". `CloudKitSchemaTests`' doc
  comment gains the pair as the fourth thing it guards. Pattern:
  `Item.soldTowardWishlistItem` / `WishlistItem.itemsSoldToward` (the
  declared-on-`Item` pair, `.nullify`); T001's CloudKit mutation record.
  Tests, every persisted read on a **second `ModelContext`**:
  **G24** — `deleteRule: .deny` on `WishlistItem.boughtItem`, then on
  `Item.boughtFromWishlistItem`: `CloudKitSchemaTests.schemaMeetsCloudKitRequirements`
  and `TwoStoreContainerTests.theProductionPairingLoadsAndSplits` red each
  time, reverted; also remove `inverse:` from `Item`'s declaration and record
  the result either way — `Item` has two to-one relationships into
  `WishlistItem`, so green here may mean SwiftData paired `boughtItem` with
  `soldTowardWishlistItem`, which `.deny` cannot see; run G25 against the
  same mutation. **G25** (`WishlistPurchaseStoreTests`) — both ends read
  back (`wanted.boughtItem` and `item.boughtFromWishlistItem`), the bought
  item's `soldTowardWishlistItem` still nil; a refused second purchase
  leaves the record on the first item and no second `Item` (mutations: drop
  the assignment → red; the `inverse:` removal above → red if it
  mis-pairs, recorded either way). **G26** (same file) — the bought
  item deleted → the entry present, bought, planned, `boughtItem == nil`; the
  bought item sold through `ItemSaleStore.markSold` → link intact; the bought
  entry deleted → the item and its photos present (mutations: `.cascade` on
  `Item`'s end → the entry-present leg red; `.cascade` on `WishlistItem`'s
  end → the item-present leg red). **G27** (`SellPlanStoreTests`, G6's
  completed leg) — `delete` leaves `boughtItem` identical (mutation:
  `wanted.boughtItem = nil` in `delete` → red). **G28**
  (`WishlistDetailViewModelTests`) — `Landing` gains whether the entry
  records the created item, **and each host gets an absolute expectation
  that it does**: the equality leg alone stays green when every host fails
  alike (mutation: drop the store's assignment → the absolute leg red for
  all four hosts, the equality leg green — record both). **G29**
  (`UITestSeedTests`) — the seeded Hasselblad records the seeded
  "Hasselblad 80mm" item (mutation: the same → red). **G39**
  (`ItemDuplicationTests.sellPlanMembershipIsNotInherited`, one added
  assertion) — the original also recorded as a bought entry's `boughtItem`;
  after `duplicate(id:)`, on a second context, the entry's record is still
  the original and the copy's `boughtFromWishlistItem` is nil (mutation:
  `duplicate` copying `boughtFromWishlistItem` onto the copy → red).
  `ExportSchemaTests`, `ImportSchemaTests`, `PurchaseUndoTests`,
  `PhotoOwnershipTests` green **unedited** (criterion 23, G38).
  Files: `Trove/Models/WishlistItem.swift`, `Trove/Models/Item.swift`,
  `Trove/Models/WishlistPurchaseStore.swift`,
  `TroveTests/CloudKitSchemaTests.swift` (comment),
  `TroveTests/WishlistPurchaseStoreTests.swift`,
  `TroveTests/SellPlanStoreTests.swift`,
  `TroveTests/WishlistDetailViewModelTests.swift`,
  `TroveTests/UITestSeedTests.swift`, `TroveTests/ItemDuplicationTests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every
  mutation recorded verbatim; `scripts/verify.sh ui` once, green at the
  count before the task (the schema change must disturb no seed).

  **Done:** 2026-09-23. `WishlistItem.boughtItem` ↔ `Item.boughtFromWishlistItem`, `.nullify` both ends, inverse on `Item`, neither an `init` parameter; `markBought` sets `wanted.boughtItem = item` after the guard and the insert. Guards and mutations, each red on a named assertion: G24 — `.deny` on either end → `CloudKitSchemaTests.schemaMeetsCloudKitRequirements` and `TwoStoreContainerTests.theProductionPairingLoadsAndSplits` (134060, "unsupported delete rules"); `inverse:` removed → both schema tests red and G25's `boughtFromWishlistItem` leg (SwiftData made two one-way links, not a mis-pairing — plan QA1 corrected as built). G25 — the assignment dropped → 5 issues; the purchase also writing `soldTowardWishlistItem` → `bought.soldTowardWishlistItem == nil` (:274). G26 — `.cascade` on the item's end (entry present) and on the entry's end (item present). G27 — `delete` clearing the record. G28 — the assignment dropped → the per-host `recordsTheCreatedItem` leg red once per host while the equality legs stayed green (why the per-host leg exists). G29 — the seeded Hasselblad's record. G39 — the duplicate taking the back-link → both halves red (:120, :121). G38 unedited and green. `scripts/verify.sh` (orchestrator re-run): 1731 tests passed; `scripts/verify.sh ui`: 34 tests, 0 failures.
- [x] **T018 — Completed rows draw the bought item's picture.**
  Per plan QA2, RA1. `PlansViewModel`: `PlanRow.showsThumbnail` **deleted**;
  `row(for:)` sets `photos` to `wanted.photos ?? []` on an active row and
  `wanted.boughtItem?.photos ?? []` on a completed one; `PlanRow`'s doc
  comments say so and that the row carries photos, never the `Item` (Q8).
  `PlansView`'s `PlanRowView`: `RowThumbnail(photos: row.photos)` on every
  row, no gate; the accessibility value reads
  `PhotoSelection.leadsWithStock(row.photos)` alone; the R2 comments
  replaced. Pattern: `WishlistView`'s `WishlistRow` (the unconditional
  thumbnail and its accessibility value). Tests: **G30**
  (`PlansViewModelTests`, replacing the `showsThumbnail` leg — rewritten,
  not loosened) — fixture built through the stores, photos with distinct
  ids: an active row's photos are its entry's; a completed row's are its
  bought item's; unchanged after that item is sold; empty after it is
  deleted, the row still in `completedRows`; empty on the pre-amendment
  shape (a purchase whose `boughtItem` the test sets nil) — in these last two
  legs a photo is attached to the **wanted entry after the purchase** (plan
  RA1's sync-race shape) and the row must still be empty (mutations:
  completed rows reading `wanted.photos` → red, **and the deleted
  `showsThumbnail` leg would have passed it — record that**; a fallback
  `boughtItem?.photos ?? wanted.photos ?? []` → the two attached-photo legs
  red; active rows
  reading `boughtItem` → red; completed photos read only while unsold → the
  sold leg red). **G31** (`PlansWiringTests`, rewriting
  `theRowDrawsItsLinesAndGatesItsThumbnail`) — `RowThumbnail(photos:
  row.photos)` exactly once in the file, inside `PlanRowView`'s body, in no
  `if` span of it; no `showsThumbnail` anywhere in the file; the `row.lines`
  legs kept (mutations: gate the thumbnail on `!row.isCompleted` → red;
  `RowThumbnail(photos: [])` → red). `theScreenDrawsNoMoneyAndReachesNoStore`
  green unedited — it, not the row's type, is what keeps money off the row
  (plan QA2). In `WishlistDetailViewModelTests.swift` (~1903–1911), drop the
  `showsThumbnail:` argument from the stray `PlanRow` the stray-row refusal
  test builds — nothing else in that test changes. (Grepped at the fix pass:
  `PlanRow(` and `showsThumbnail` appear in `TroveTests` only there, in
  `PlansViewModelTests` and in `PlansWiringTests`; re-grep before
  dispatch.)
  Files: `Trove/ViewModels/PlansViewModel.swift`,
  `Trove/Views/Plans/PlansView.swift`, `TroveTests/PlansViewModelTests.swift`,
  `TroveTests/PlansWiringTests.swift`,
  `TroveTests/WishlistDetailViewModelTests.swift` (the stray `PlanRow` only).
  **Verify:** `scripts/verify.sh` green; mutations recorded.

  **Done:** 2026-09-23. `PlanRow.showsThumbnail` deleted; `row(for:)` takes `wanted.isBought ? (wanted.boughtItem?.photos ?? []) : (wanted.photos ?? [])`; `PlansView` draws `RowThumbnail(photos: row.photos)` on every row, ungated; the stray `PlanRow` in `WishlistDetailViewModelTests` drops the argument. G30 — three tests replacing the `showsThumbnail` leg (active/completed/sold; bought item deleted; no record), each with a late photo on the entry. G31 — `theRowDrawsItsLinesAndAThumbnailOnEveryRow`. Mutations, each red: completed rows reading `wanted.photos` — **the old `showsThumbnail` guard passes this one** (it is HEAD's own line, green at `930f2ea`); the `?? wanted.photos` fallback (the two late-photo legs); active rows reading `boughtItem`; photos only while unsold (the sold leg); the thumbnail under `if !row.isCompleted`; `RowThumbnail(photos: [])`. `scripts/verify.sh`: 1733 tests in 233 suites passed.
- [x] **T019 — The Plans tab's "…", and Settings from every tab's root.**
  Per plan QA3. `PlansView`: `HeaderDropdown.overflow` ("Dismiss more
  actions"); the header's trailing `HStack(spacing: 8) { if
  !viewModel.rows.isEmpty { sortControl }; overflowControl }`;
  `overflowControl` = `OverflowBadge(isBusy: false) { openDropdown =
  .overflow }`, `.dropdownAnchor(HeaderDropdown.overflow)`,
  `.accessibilityIdentifier("moreActions.plans")`; the host's `.overflow`
  case `DropdownSurface { DropdownRow(title: "Settings") { isShowingSettings
  = true } }`; `@State isShowingSettings`; the environment reads for
  `storageMode`, `storageFallbackReason`, `AppearanceStore` and
  `colorScheme`; the Settings sheet block with `onDismiss: viewModel.load`.
  The file's doc comments (the enum's "Sort By its only case", the type's
  "no '…'") say what QA3 does. Pattern: `DashboardView.swift` (the one-row
  Settings menu, the sheet block, the environment reads);
  `WishlistView.swift`'s header `HStack`. Tests: **G32**
  (`SettingsWiringTests`) — `"Trove/Views/Plans/PlansView.swift"` joins
  `settingsHosts`; new `everyTabsRootReachesSettings` per plan QA3, deriving
  the roots from `ContentView`'s `Tab(` closures, `#require`-ing as many as
  `AppRouter.Tab.allCases` and each root's file found by its `struct <Name>:
  View` (mutations: Plans' `OverflowBadge` removed → red; its sheet's
  `onDismiss` dropped → the existing sheet test red; `PlansView` taken out of
  `settingsHosts` → the new test red; the Plans tab's root swapped in
  `ContentView` for `SellPlanView(…)` → red). **G33**
  (`DropdownWiringTests.everyBadgeCarriesItsHintAndIdentifier`) — Plans'
  `sortControl` hint and `sortOptions.plans`, and `overflowControl`'s
  `moreActions.plans` (mutation: the identifier dropped → red).
  `MenuPolicyTests` and `PlansWiringTests` green unedited.
  Files: `Trove/Views/Plans/PlansView.swift`,
  `TroveTests/SettingsWiringTests.swift`, `TroveTests/DropdownWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

  **Done:** 2026-09-23. `PlansView`'s header holds the sort badge (when the side has rows) and an `OverflowBadge` always, anchored `.overflow`, identifier `moreActions.plans`, whose dropdown's one row opens Settings; the Settings sheet copied from `DashboardView` with `onDismiss: viewModel.load`. G32 — `PlansView.swift` in `settingsHosts`; new `everyTabsRootReachesSettings` derives each tab's root from `ContentView`, requires as many as `AppRouter.Tab.allCases`, and requires each to host the badge and a dropdown that raises the sheet. G33 — Plans' badges' identifiers and hints. Mutations, each red: the badge replaced by a `Button`; the sheet without its reload; Plans out of `settingsHosts`; the Plans root swapped for `SellPlanView` (6 issues); the row toggling instead of raising; the identifier removed. The preview injects `AppearanceStore`. `scripts/verify.sh`: 1734 tests in 233 suites passed.
- [x] **T020 — "Delete All Sell Plans…" in Settings.**
  Per plan QA4, RA2 (**build to RA2 as written unless the person has
  answered otherwise by dispatch** — if they have, the orchestrator
  transcribes the answer into plan RA2 first). `DeleteAllCopy`:
  `DeleteTarget.sellPlans` ("sell plan" / "sell plans") and `CaseIterable`;
  the two `.sellPlans` consequence sentences of QA4's table, and its iCloud
  sentence naming **the plans** ("…the plans are removed…" / "…the plan is
  removed…"), `.items`/`.wishlist` unchanged byte for byte. Stale doc
  comments corrected (plan QA4): the type's "the two Delete All rows",
  `footer`'s "Under the two rows", `message`'s singular-consequences
  sentence (not true of `.sellPlans`). `SettingsViewModel`:
  `Activity.deleteSellPlans`, `planCount` (in `load()`),
  `canDeleteSellPlans`, `requestDeleteAll`'s count and `confirmDeleteAll`'s
  activity as `switch`es, and the `.sellPlans` case through
  `SellPlanStore.delete` inside the existing one-save envelope, exactly as
  QA4's sketch; the type's and `confirmDeleteAll`'s doc comments name the
  third target, and under RA2(b) the counts' "`fetchCount`, never a loaded
  array" comment is corrected (plan RA2's (b) path: fetch
  `sellPlanCreatedAt != nil || sellPlanCheckedAt == nil`, filter by
  `hasSellPlan || awaitsCarryOver`, `planCount` from that fetch).
  `SettingsView`: the third row in `deleteSection`'s rows, above
  the footer — title `Delete All Sell Plans…`, `isActing:
  viewModel.activity == .deleteSellPlans`, `isEnabled:
  viewModel.canDeleteSellPlans && !viewModel.isBusy`, `isDestructive: true`,
  hint `Permanently deletes every sell plan, active and completed.`, action
  `viewModel.requestDeleteAll(.sellPlans)`; "the two destructive rows" in
  the doc comments becomes three. Pattern: the `.wishlist` target
  throughout; `SettingsViewModelTests.confirmDeletesEveryWishlistItemAndOnlyThose`
  for the test; `SellPlanStoreTests`' G6 for the criteria 10–12 assertions.
  Tests: **G34** (`DeleteAllCopyTests`) — the `.sellPlans` titles and both
  messages by literal in `.cloudKit` and `.localOnly`; the two loops over
  `[DeleteTarget.items, .wishlist]` become `DeleteTarget.allCases`
  (mutation: reword a sell-plans sentence → red). **G35**
  (`SettingsViewModelTests`, second context) — plan G35's fixture and legs,
  including the stored plan whose `sellPlanCheckedAt` the test sets nil, and
  the no-carry-over leg asserted per removed row so it holds under either
  RA2 answer (mutations: `modelContext.delete(wanted)` instead of the plan →
  red; `&& $0.boughtDate == nil` in the fetch → the completed leg red;
  `itemsSoldToward = []` added → red; the save dropped → red; `planCount`
  over every entry → red; **`SellPlanStore.delete`'s nil-stamp dropped → the
  unchecked plan's no-carry-over leg red**). **G36** (`SettingsWiringTests`) — rewrite the
  exact counts, never to `>=`: destructive rows 3, hints 3, action rows 8
  (mutations: the new row without `isDestructive: true` → red; without its
  hint → red). `DestructiveColourPolicyTests` green **unedited** — record
  its counts (expected 15 / 9 / 6: the new row adds no `.destructive`
  site). The refused-save rollback is untested, as every Delete All's is —
  say so in the Done note.
  Files: `Trove/Models/DeleteAllCopy.swift`,
  `Trove/ViewModels/SettingsViewModel.swift`,
  `Trove/Views/Settings/SettingsView.swift`,
  `TroveTests/DeleteAllCopyTests.swift`,
  `TroveTests/SettingsViewModelTests.swift`,
  `TroveTests/SettingsWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

  **Done:** 2026-09-23. `DeleteTarget.sellPlans` (with `CaseIterable`) and its copy — "Delete your only sell plan?" / "Delete all 4 sell plans?", the message naming the plans in its iCloud sentence; `SettingsViewModel.planCount`, `canDeleteSellPlans`, `Activity.deleteSellPlans`, the `.sellPlans` delete through `SellPlanStore.delete` in the existing one-save/rollback envelope, counted and deleted by one `plannedRows()` on RA2(b)'s path (stored plans plus rows awaiting the carry-over); a third rust row under Delete. Stale comments corrected. G34 (three copy tests), G35 (new suite `SettingsDeleteAllSellPlansTests`, 5, second context, count 4), G36 (exact counts 3/3/8). Mutations, each red: entries deleted instead of plans; completed plans skipped; `itemsSoldToward` cleared; the save dropped; `planCount` counting every entry; `SellPlanStore.delete`'s nil-stamp dropped (the unchecked plan re-planned); a copy sentence reworded; the iCloud sentence in `.localOnly`; `isDestructive`, the hint, and the busy gate each removed. The refused-save rollback is untested, as for every Delete All. `scripts/verify.sh`: 1742 tests in 234 suites passed.
- [x] **T021 — Amendment A's UI tests, and the suite twice.**
  Per plan QA6. `testEveryTabsRootReachesSettings` (`-uiTesting`) and
  `testDeletingAllSellPlansLeavesEverythingElse` (`-uiTesting -seedPlans`),
  exactly as QA6 lists their steps. Pattern:
  `testDashboardOffersSettingsAndNothingElse` (badge → Settings → the bar →
  Done); `testDeletingAPlanLeavesTheWantedItemAndTheSale` (the cross-tab
  checks). UI mutations: Plans' `OverflowBadge` removed → the every-tab test
  red; the Settings sheet's `onDismiss: viewModel.load` dropped from
  `PlansView` → the empty-state leg red; `confirmDeleteAll(.sellPlans)`
  deleting the entries → the Wishlist leg red. Then `scripts/verify.sh ui`
  **twice back to back**.
  Files: `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green twice,
  both counts in the Done note (expected: the count before plus 2);
  mutations recorded.
  **Done:** 2026-09-23. `testEveryTabsRootReachesSettings` and `testDeletingAllSellPlansLeavesEverythingElse` with an `openSettings(from:in:)` helper. Mutations, each red on a named assertion: the Plans `overflowControl` removed ("the Plans tab's root must have a '…'"); the Settings sheet's `onDismiss` reload dropped ("the Active side must be empty as soon as Settings closes"); entries deleted instead of their plans ("… must stay on the Wishlist"). The delete test waits for the row to dim before Done (the delete is async). `scripts/verify.sh`: 1742 tests passed; `scripts/verify.sh ui` twice back to back: 36 tests, 0 failures, both runs (~14 min each).
  **Phase 4A closes here — pause for the person** (what to try, and the
  readings to put as questions, are in the handoff note above).

- [x] **T021a — Walkthrough finding: Delete All Items says completed plans lose their pictures.**
  The person, Phase 4A walkthrough (2026-09-23), on RA4: the warning "should
  probably mention it." `DeleteAllCopy`'s `.items` consequences gain that
  completed sell plans lose the pictures that came from the deleted items;
  `.wishlist` and `.sellPlans` unchanged; `DeleteAllCopyTests` by literal.
  RA3 (the footer) stays, and sell plans in the exports go to
  `specs/ROADMAP.md` as a follow-up — the person's answer.

  **Done:** 2026-09-23. Delete All Items (several): "Their photos go too. Every sell plan loses its items, and completed plans lose their pictures." The person chose (a) for a single item: `ItemDeleteCopy.message(isSold:picturesACompletedPlan:)` adds "…and the completed plan it was bought for loses its picture" (owned) / "Its photos go too, and the completed plan it was bought for loses its picture." (sold) only when `item.boughtFromWishlistItem != nil`; flag off reads byte for byte as before. `DeleteAllCopy`'s one-item text takes the same flag, so `aListOfOneReadsLikeTheSingleItemAlert` keeps its exact equality over both values. The item page, the Items list and Settings' only-item case each take the flag from their view model. Mutations, each red: the clause removed (owned; sold); Delete All ignoring the flag; each of the three view models hardcoding false. No UI test goes through an item's delete alert (the wording has no on-screen check). `scripts/verify.sh`: 1746 tests in 234 suites passed.
- [ ] **T021b — The Plans tab icon redrawn as the tipped scale (spec Amendment A, Decision 19).**
  `design/icons/tab-plans.svg` and `TabPlans.imageset/tab-plans.svg` become
  candidate H (the drawing is in the bundle); `TabIconTests` green unedited —
  G20's template and four-distinct legs re-run as mutations; `design/tokens.md`'s
  tab-icon line describes the new mark.

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
  sides, empty and populated, read from the tree; the Sell Plan's Buy and
  Delete as two separate bar buttons, and a completed plan's lone Delete with
  no stray gap before it (spec Decision 13, T009b); an active Plans row tapped
  into the live Sell Plan (carried from Phase 4's review); both delete
  alerts' text; the spoken names of a row, the switch, the card, the Sell
  Plan's Delete and the Plans "…" read from the accessibility tree; relaunch
  (criterion 17's persistence).
  **Amendment A** (plan, Close-out additions): a **second upgrade in place**,
  from this branch's Phase 4 build (its store with a completed plan) to the
  finished tree — it launches, and that plan's row shows the placeholder;
  on the persistent store, a wanted item given a photo from the simulator's
  library, planned and bought → its Completed row shows the photo; the item
  it became sold → still shown; that item deleted → the placeholder, the row
  still on Completed (criterion 20's four states); the Plans "…" in both
  appearances over an empty and a full side, the switch's `minY` unchanged by
  it; Settings reached from each tab's "…" (criterion 21); the Delete All
  Sell Plans row sampled against `accentRustText` (#B8674F dark, #8E3A24
  light) in both appearances, dimmed with no plans, its alert's text; the
  probe in `SellPlanStore.delete` firing once per plan on Delete All and 0
  on Keep (criterion 22). Findings fixed in place if routine and inside
  the footprint, else returned for a decision review; each fix a
  sub-lettered task. **[person]** Accessibility Inspector over the same
  elements, and VoiceOver over Delete All Sell Plans… (announced with its
  hint) and the Plans "…"; with two devices, a plan created, sold through, deleted and
  carried over on one, seen correctly on the other (criterion 17's sync
  half); a purchase on one showing its picture on the other's Completed row,
  and Delete All Sell Plans on one clearing the other (criteria 20, 22's
  sync halves); plan RA2's window — a plan made on one device, Delete All
  Sell Plans run on the other before it arrives (it is neither counted nor
  deleted, and appears after the import) — recorded as observed or not
  reached; and plan Q2's three windows, each recorded as observed or not
  reached: a signed-in device launched **offline** (does setup finish
  failed and run the carry-over on an old copy?), a device returning after a
  long absence (a multi-pass import), and which write survives when a carried
  row meets a deletion made elsewhere. Also on one device, offline: an empty
  Plans side says "Catching up with iCloud" while a plan awaits the
  carry-over, not "No sell plans yet".
  **Verify:** the record in the Done note — both upgrades' results per entry,
  the probe counts, the measurements, the picture's four states, the rust
  samples; `scripts/verify.sh all` green twice.

  **Device pass (agent), 2026-09-23 — the person's steps pending.** Spares only (C5329D37 iOS 27, F0A13FFC iOS 26.5), neither signed into iCloud, so every carry-over ran the signed-out path. **Upgrade from `main`** (F0A13FFC): a selection → Active "1 item set aside"; a sale toward it → Active "1 sold toward it"; bought with a sale → Completed, "Bought … · 1 was sold toward it", placeholder; bought with neither → neither; nothing → neither; card "2 active sell plans". **Upgrade from the Phase 4 build** (`9f95b0f`, C5329D37): a completed plan bought before the link shows the placeholder in its new slot. **Probe** (in the hook, `carryOver`, `delete`): the upgrade launch made 3 plans of 5 unchecked rows; every relaunch 0, including after Delete all; swipe opened/closed 0, alert Keep 0, Delete 1; Sell Plan Keep 0; Delete all Keep 0, Delete All 4; deleting the bought item 0. Probes removed, tree byte-identical. **Checks passed**: every Plans screen, the card and the record in both appearances; the switch's top at 134.67 pt in every state, both devices (read from pixels — `inspect` unavailable); "Completed" whole in its 69 pt half (5.3 / 6.0 pt either side); Buy and Delete separate, Delete exactly `accentRustText`; the lone Delete on a record has no stray gap; an active row opens the live Sell Plan; both delete alerts' text; the wanted item and its sales survive a plan's delete; Covered appears with no money on the row; relaunch persistence; the card lands on Active; the picture's four states (older → placeholder, bought → photo, sold → photo, deleted → placeholder and the row stays); the Plans "…" with one Settings row over full and empty sides; Settings from all four tabs; the Delete-all-sell-plans row rust and dimmed with none, its alert text, and the outcome; T021a's two single-item texts and Delete All Items' plural; tap targets (card padding, the callout, a chip's padding); the swipe's rust fill. **Observation for the person**: the Plans tab icon carries about half the visual weight of the other three (18.5 × 6.7 pt mark; drawn as planned). Screenshots in the session scratchpad `devpass/`.
- [ ] **T016 — Close-out.**
  Per plan §14 and Amendment A's close-out additions. Criteria **1–23**
  ticked in `spec.md` with per-criterion citations — criterion 7 as
  criterion 20 revised it, criterion 23 by G24 and G38, criteria 20 and 22's
  sync halves partial until the person's two-device step as 17's is —
  criterion 19 **by inspection**, saying why no test can catch
  it without being the broad-scan shape `CLAUDE.md` names; criterion 17 an
  honest partial until the person's two-device step, **left unticked** as
  `014` and `015` left theirs. The Copy section's shapes replaced by the
  shipped strings, the Delete All Sell Plans strings among them; P-items →
  decisions; `plan.md` gains **As built**, covering Amendment A;
  `design/tokens.md` (the Plans entry gains the "…" and the completed row's
  picture), `README.md`, `specs/ROADMAP.md` (`009` entry and
  status row; the `015` seeded-plan follow-up closed; the Settings-sheet
  extraction line, plan QA3), `DECISIONS.md` (plan
  §14's list, including "once, per row" **with its limits** as T015's
  two-device step left them, and derive-on-read weighed and rejected; and
  Amendment A's three — the purchase record, Settings from every tab,
  Delete all sell plans with RA2 as the person answered it); the
  pointers of plan Context and of Amendment A appended in place (`015`
  Decision 2 in `specs/015-mark-as-bought/plan.md`; the spec's "Deleting a
  plan" orphan paragraph) (`grep -c` each, the `014`
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
| `skeptical-reviewer` — plan/tasks sign-off | `opus` | ~153k (harness) | B1 (carry-over fired on a failed import and in `.localOnly`); finding 2 (R2, R4) a product question, sent to the person; 10 non-blocking |
| `sdd-planner` — sign-off fix pass (same agent resumed) | `opus` | ~65k (budget counter) | B1 fixed: event-based trigger, `.localOnly` skipped, `settledCount`, `awaitsCarryOver` read-only for the pending window; derive-on-read weighed and rejected in Q2; findings 3–12 applied, none declined; R2/R4 and `spec.md` untouched |
| `skeptical-reviewer` — sign-off re-review | `opus` | ~61k (harness) | Findings 1, 3–12 all FIXED; one NEW blocking: the page's `hasSellPlan` reading `awaitsCarryOver` let a tap on **View** write a plan from a stale copy (B1's path moved from launch to a tap); one non-blocking (`.localOnly` shows "Catching up with iCloud") |
| Orchestrator — direct fix (loop cap reached) | `claude-opus-5-5` session | — | Took the reviewer's option (b): the page reads the stored plan only, a waiting row reads "Create a sell plan"; plan Q2, R7, §7 and T008/G16 amended; the `.localOnly` wrinkle noted beside R7 as accepted |
| T001 — `sdd-implementer` | `opus` | ~51k (harness) | Done first pass; no miss. Found: a red run hangs after its count line; verify.sh takes one selector |
| T002 — `sdd-implementer` | `opus` | ~71k (harness) | Done first pass; no miss |
| T003 — `sdd-implementer` | `opus` | ~80k + ~86k follow-up (harness) | Done first pass; review follow-ups applied by the same agent |
| T003 — `skeptical-reviewer` per-task | `opus` | ~48k (harness) | Signed off; 0 blocking, 5 non-blocking (4 applied: only-when-nil stamps tested, two vacuous `!= createdAt` asserts made fixture checks, two doc comments); `runCarryOver`'s untested branches carried to the sweep |
| T004 — `sdd-implementer` | `opus` | ~64k + ~75k follow-up (harness) | Done first pass; review follow-ups applied by the same agent. Red-run helper widened for parameterized test names |
| T004 — `skeptical-reviewer` per-task | `opus` | ~47k (harness) | Signed off; 0 blocking, 3 non-blocking: 2 applied (hook-before-`settledCount` pinned; seeds-leave-nothing test); 3rd — does a signed-in device launched offline finish setup *failed* and so run the carry-over on a stale copy? — already T015's person step; carried to the sweep |
| Phase 1 — `skeptical-reviewer` phase review | `opus` | ~91k (harness) | Signed off; 0 blocking, 5 non-blocking, carried forward: T005 (a completed row's lines begin with Bought), T008 (inline strings out, `PurchaseCopy` comment), T014 (Fuji test red for both launch-wiring mutations), T015 (probe in the hook on an upgrade launch), sweep (`runCarryOver` saves/rolls back the whole main context on every import — plan Q4 as written). UI suite at `851b210`: 25 tests, 0 failures |
| T005 — `sdd-implementer` | `opus` | ~140k (harness) | Done first pass; no miss. Noted: the `aRefusedPurchaseRollsBackAndReportsInItsHostsOwnProperty` scan still names three hosts |
| T006 — `sdd-implementer` | `opus` | ~83k (harness) | Done first pass; no miss |
| T007 — `sdd-implementer` | `opus` | ~63k (harness) | Done first pass; no miss |
| Phase 2 — `skeptical-reviewer` phase review | `opus` | ~111k (harness) | 1 BLOCKING: the Completed fixture's wishlist order matched its name order, so dropping the Name comparator stayed green; 9 non-blocking (2, 3, 4, 5, 8, 9 applied; 7 ruled by plan §5 — deletes are silent, doc comment corrected; 6 — a failed Plans fetch reads "Nothing on your wishlist" — and 10 carried to the sweep and the view tasks). UI suite at `6a9d101`: 25 tests, 0 failures |
| Phase 2 — fixes (`sdd-implementer`, T005's agent resumed) | `opus` | ~160k (harness, cumulative) | All applied; every new mutation red; the Plans host's `rollback()` on a real save failure (markBought, deletePlan) recorded untested |
| Phase 2 — `skeptical-reviewer` re-review | `opus` | ~120k (harness, cumulative) | Signed off; all FIXED. NEW non-blocking, to the sweep: the test file header overstates the Completed fixture's insert order; the scan's doc says "one save" where the tests show "a save", and should name `deletePlan`'s rollback as untested too; optional: run tie-by-name on `areInCompletedOrder` |
| T008 — `sdd-implementer` | `opus` | ~77k (harness, incl. a comment follow-up) | Done first pass; no miss |
| T009 — `sdd-implementer` | `opus` | ~95k (harness) | Done first pass; no miss |
| Phase 3 — `skeptical-reviewer` phase review | `opus` | ~73k (harness) | Signed off; 0 blocking, 7 non-blocking: 1, 2, 3, 5, 6 applied (a UI leg proves the page's tap creates the plan — red when the view skips `openSellPlan()`; the record's "nothing that acts" list widened to generic controls and to `soldSection`/`soldRow`; the page's title and subtitle read one source; the alert's fallback name into `SellPlanCopy`; a comment); 4 transcribed into plan §7 (an explicit create on a waiting row keeps its selection); 7 — `openSellPlan`'s save-failure rollback untested — to the sweep |
| Phase 3 — follow-ups (`sdd-implementer`, T009's agent resumed) | `opus` | ~122k (harness, cumulative) | All applied; each new guard mutation red; 1708 unit tests green | UI suite at `fa3b501`: 25 tests, 0 failures |
| T009a — `sdd-implementer` diagnosis | `opus` | ~164k (harness) | Not reproduced: 15 injected-touch trials on two runtimes, 4 and 12 candidates — every tap registers from ~0.07 s; `load()` 2–14 ms; no rebuild under the finger. Suspect: the iCloud export/import after Create's save (new with 009, Create path only), untestable on a signed-out simulator. Probe patch kept in the session scratchpad; next step a hand pass on the person's signed-in simulator. Noted: `SellPlanViewModel.init` runs ~7 times per push (discarded by `State(initialValue:)`) |
| T009b — `sdd-implementer` | `opus` | ~93k (harness, incl. a follow-up) | Done first pass; no miss |
| T009c — `sdd-implementer` | `opus` | ~75k (harness) | Done first pass; no miss |
| T009d — `skeptical-reviewer` decision review | `opus` | ~71k (harness) | Option A tightened: colour on the control where the app draws it, role alone where the system does; rust; no shared modifier; `DestructiveColourPolicyTests` classified by enclosing call; device check for the rendering half. Transcribed as plan §9a |
| T009d — `sdd-implementer` | `opus` | ~85k (harness, incl. the ruling round) | Stopped once on a judgement (the balance anchor vs `stripComments` cutting URL literals) — ruled C at a follow-up decision review (~80k, cumulative); then done |
| T009d — device check (`general-purpose`, simulator tools) | `opus` | ~141k (harness) | The Delete word samples exactly `accentRustText` (#B8674F dark, #8E3A24 light) and Buy exactly brass, on iOS 27.0 and 26.5 — `.tint` wins over the cascade; Buy and Delete are separate capsules (~11 pt gap). The lone Delete on a completed plan (stray gap?) unreachable before the Plans tab — carried to T015 |
| Phase 3 — the person's walkthrough | — | — | Attested 2026-09-23 on the right build ("Looks good. Continue"), after two findings (T009a→T009c, T009b) and one standard (T009d). UI suite at `756edc7`: 26 tests, 0 failures (T009c's test added). T009b–T009d had no phase review of their own; they ride in Phase 4's review bundle |
| T010 — `sdd-implementer` | `opus` | ~58k (harness) | Done first pass; no miss |
| T011 — `sdd-implementer` | `opus` | ~124k (harness) | Done first pass; no miss. Chose the empty states' marks (TabPlans, TabWishlist, iCloud) — for the phase review |
| T012 — `sdd-implementer` | `opus` | ~45k (harness) | Done first pass; no miss |
| T013 — `sdd-implementer` | `opus` | ~61k (harness) | Done first pass; no miss |
| T014 — `sdd-implementer` | `opus` | ~136k (harness) | Done first pass; no miss. A full UI run now ~11.7 min (33 tests) — run it in the background |
| Phase 4 — `skeptical-reviewer` phase review (T010–T014 plus T009b–T009d) | `opus` | ~125k (harness) | Signed off; 0 blocking, 11 non-blocking. Applied: plan §13's record test and VoiceOver step read the bar's Delete (T009b left them saying "…"); sort orders became intents that reload (plan §5), so the Completed reorder is unit-tested; `DestructiveColourPolicyTests` counts sites exactly per file and its balance check's dead store is fixed; the Hasselblad row asserted not Covered; the record's bar asserted Back and Delete only; two stale comments. To T015: an active Plans row tapped into the live Sell Plan; the lone Delete's spacer on a completed plan; pause-report readings. Verified: the CLAUDE.md amendment is its own commit (`b42c70c`) |
| Phase 4 — follow-ups (`sdd-implementer`, T014's agent resumed) | `opus` | ~174k (harness, cumulative) | All applied; each mutation red on a named assertion (a crossed-bracket plant passes under the old dead store — the control); 1726 unit tests; the three changed UI tests green alone | UI suite at `9f95b0f`: 33 tests, 0 failures |
| Orchestrator miss — `6f1b591` | `claude-opus-5-5` session | — | The spec Amendment A commit, made with `git commit -a` while T014a's implementer was mid-task, swept its unfinished code (eight content shapes, two UI tests, two debug prints) into a commit about prose. Not rewritten (no force-push); T014a's own commit carries the corrections and names this one. Rule recorded: commit named paths while an agent works |
| `sdd-planner` — Amendment A plan and tasks (Draft) | `opus` | ~265k (budget counter) | Phase 4A, T017–T021, 15 guards (G24–G38); T015/T016 updated; one product question returned (RA2: does Delete all sell plans include rows still awaiting the carry-over?) |
| T014a — `sdd-implementer` | `opus` | ~123k (harness, cumulative over three rounds) | Stopped twice on judgements (the gap didn't reproduce; the chip test couldn't fail) — ruled A at a decision review, then the chip test deleted per CLAUDE.md |
| `skeptical-reviewer` — Amendment A sign-off | `opus` | ~170k (harness) | 1 BLOCKING: T018 deletes `showsThumbnail` while a test outside its file list builds a `PlanRow` with it; 9 non-blocking. Recommends RA2(b) |
| `sdd-planner` — Amendment A fix pass (resumed) | `opus` | ~28k (budget counter) | All nine applied; G39 added; RA2 left for the person |
| `skeptical-reviewer` — Amendment A re-review | `opus` | ~188k (harness, cumulative) | Signed off; all FIXED. Notes: G35's count reads 4 under RA2(b); G39 would read cleaner on a second wanted item with no selection |
| T017 — `sdd-implementer` | `opus` | ~116k (harness, incl. a follow-up round) | Done first pass; review follow-ups applied |
| T017 — `skeptical-reviewer` per-task | `opus` | ~73k (harness) | Signed off; 0 blocking, 6 non-blocking: the never-red `soldTowardWishlistItem` leg mutation-proved; QA1's mis-pairing premise corrected in plan.md; G39 split; "three hosts" → four; the doc naming `PlansViewModel` as reader confirmed at T018 |
| T018 — `sdd-implementer` | `opus` | ~75k (harness) | Done first pass; no miss |
| T019 — `sdd-implementer` | `opus` | ~81k (harness) | Done first pass; no miss |
| T020 — `sdd-implementer` | `opus` | ~122k (harness) | Done first pass; no miss. Noted: `DestructiveColourPolicyTests` checks its counts as floors — plan wording saying "exact" there is inaccurate |
| T021 — `sdd-implementer` | `opus` | ~82k (harness) | Done first pass; no miss |
| Phase 4A — `skeptical-reviewer` phase review (T017–T021) | `opus` | ~109k (harness) | Signed off; 0 blocking, 7 non-blocking, to the sweep: T021's dim-wait comment misstates why ordering holds; a stale "no figure" comment in `PlansView`; G31 blind to non-`if` gates; the every-tab guard's `isShowingSettings` match not scoped to `.overflow`. `DestructiveColourPolicyTests` unedited and green at T020 (T011 read 15 / 9 / 6; T020 added no site). Pause report: the walkthrough is the new link's first migration on a real store; one plan reads "Delete your only sell plan?"; under RA2(b) the count can exceed the listed rows while Plans reads "Catching up" |
| T021a — `sdd-implementer` | `opus` | ~85k (harness, two rounds) | Stopped once on a product question (the single-item wording is pinned equal to the item page's) — the person chose (a), conditional; then done |
| Phase 4A — the person's walkthrough | — | — | Attested 2026-09-23 ("Everything else looks good"); RA3 kept (exports follow-up on the roadmap); RA4 → T021a |
| T015 — device pass (`general-purpose`, simulator tools) | `opus` | ~350k (harness) | Every reachable check passed; no finding blocks; spoken names and iCloud steps to the person |
| T015 — `scripts/verify.sh all` twice at `6fdfa97` | — | — | Both runs: 1746 unit tests, 36 UI tests, 0 failures |

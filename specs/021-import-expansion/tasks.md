# 021 — Import Expansion: Tasks

**Status**: **Final** (2026-10-09) — signed off by the `skeptical-reviewer` after fixes (three blocking findings, B1–B3, fixed and re-reviewed); the re-review's two further findings (N1, N2) were fixed by the orchestrator directly under `CLAUDE.md`'s review-loop cap and are logged in `tasks.md`'s tier log, not re-reviewed

Drafted against the approved `spec.md` and the draft `plan.md` in this
directory, for branch `021-import-expansion` off `main` (`028747f`). **Revised
2026-10-08** after the sign-off review and the spec's amendment of the same day
(commit `38883a8`, Decisions 17–23, criteria 41–46), and **again 2026-10-09**
for the person's two answers (Decision 19 reworded, Decision 24; criteria 43
and 47). Task IDs are unchanged, with **T001a** and **T001b** added; criteria
43 and 47 are folded into the tasks that already build what they need — the
words in T006, the count and the re-confirm in T010, mirrored in T011 — rather
than given a task of their own. No new technical decisions are made here —
every call traces to a plan section, and where a task says "per plan", that
section is the authority. Line numbers in `plan.md` are as read at `028747f`;
every implementer re-reads the file it edits.

**Foundational phase**: **Phase 1** (T001–T003) — the claims the Trove ID rests
on, the app made safe for two rows sharing one, the reader's grammar for a
price, a date, an empty cell and a code, and the column matcher. Every later
task reads through these, and T001 is where the plan's choice of identifier is
shown to hold or stops the spec.
**Tasks marked `review: per-task`**: **T004** — the row types and the row
pipeline (what is a row, a totals row, a skip, a default) are what T005–T012 and
every fixture inherit; **T009** — the update rule, whose plausible-looking
simpler version (reuse the new-row path) writes defaults over existing values;
and **T010** — the function that actually overwrites real items, where an
unconditional or crossed assignment passes every pure test and cannot be undone
by the person it happens to. Every other task gets the default one review per
phase. An orchestrator left to guess guesses "all of them"; these three are the
ones marked.

Ordering note: the identifier's claims first, since nothing else is worth
building if one fails; then the trap that two rows with one code would spring,
fixed **before** any task can create that state; then the pure grammar and the
column matcher. Phase 2 builds the new reader **beside** the old one
(T004–T006 are additive) and switches over in one task (T007), so the tree is
green at every commit. Phase 3 writes the Trove ID out before anything reads it
back, proves the update rule as a pure function before a store calls it, and
leaves the docs for last so they describe what was built. The recorded
spreadsheet re-save needs a file only the person can make, so it follows the
Phase 3 pause.

House rules carried over: one commit per completed task, referencing its ID;
every guard is **mutation-verified** (break the rule, confirm red) before it
lands, and the Done note records what was broken and what went red; a task is
done when `scripts/verify.sh` is green and its actual output is reported
(suite-level selection, count checked — per-function Swift Testing selectors run
zero tests); **persisted-state assertions refetch on a second `ModelContext`**;
**no new source scan in this spec** — every rule here is reachable by a
pure-function, store, view-model or UI test (`CLAUDE.md`, 2026-09-19), and an
existing scan that goes red is re-read before it is touched; **a fixture's value
must differ from what a broken path produces** — for an update that means
different from the field's default *and* from the item's current value. A test
that pins a rule this spec changes is **rewritten to the new rule and named in
the Done note**, never deleted or loosened to get to green. New files land in
synchronized folders — **no `.pbxproj` edit**; if the build cannot see one, stop
and flag. No test opens a network connection. The person's real spreadsheet is
never committed (spec P12): every row in every fixture is invented.

Cadence (per `CLAUDE.md`'s model policy): each dispatch gets a task bundle
assembled with shell — task line, plan section, acceptance criteria, files,
pattern file — and the implementer does not read `plan.md`/`spec.md`/`tasks.md`
in full; verification is `scripts/verify.sh` and nothing more verbose, re-run by
the orchestrator for T004, T009 and T010 and taken from the implementer's
verbatim output otherwise; the `skeptical-reviewer` reviews per phase and T004,
T009 and T010, one review and at most one re-review each, on a bundle cut after
`git add -A`; one implementation session for the whole spec; the device pass
runs in `general-purpose` agents, one per section. Everything the person reads
is plain language.

---

## Phase 1 — Foundations: the code, the grammar, the columns (**foundational**) · walkthrough: none — tests over fields that already exist, a crash removed from a state no phone is in yet (two items with one identifier — only this spec's later phases can make one), a seed only the UI tests launch with, and pure functions nothing calls yet. One reading does move: a price written `$1,250.00` in a file that already matches the template now reads instead of falling back to a default; nobody would go looking for it, and Phase 2's pause covers it

- [x] **T001 — The Trove ID is `id`: every claim it rests on, tested.**
  Per plan §1, R1 and Q1. No behaviour changes. `Item.id` and `WishlistItem.id`
  gain doc comments saying `021` exports them as the Trove ID and what that
  relies on (stored, never reassigned by an edit, new on a Copy and on a
  purchase, assignable before insert for a kept code, **not guaranteed unique**).
  Pattern: `020` T001's persisted legs in `TroveTests/ModelTests.swift`;
  `ItemDuplicationTests.theCopyCarriesBought`;
  `ItemSaleStoreTests.markThenReturnLeavesBoughtUnchanged`.
  Tests (**G1**): new `TroveTests/TroveIDTests.swift` — an `Item` and a
  `WishlistItem` each given a known `UUID` **before insert**, saved, and read
  back on a second context with that `id` (mutation: the `save()` dropped → the
  second context finds nothing → red); two rows inserted with the **same** `id`
  both persist (the store does not refuse it — the fact plan R2 and T001a are
  built on; if this leg fails, say so: the store is stricter than the plan
  assumes). `ItemFormViewModelTests` / `WishlistFormViewModelTests`: an edit
  saved through the form leaves `id` as it was, on a second context (mutation:
  `item.id = UUID()` in the form's save → red). `ItemSaleStoreTests`: `markSold`
  then `returnToCollection` leave `id` as it was. `ItemDuplicationTests` /
  `WishlistDuplicationTests`: the copy's `id` differs from the original's
  (criterion 19) (mutation: `copy.id = original.id` → red, on each list).
  `WishlistPurchaseStoreTests`: the bought item's `id` differs from the entry's
  (mutation: `item.id = wanted.id` → red).
  **If any leg fails as written — not through a mistake in the test — stop and
  report**: the plan has no second design for the code.
  Files: `Trove/Models/Item.swift`, `Trove/Models/WishlistItem.swift` (comments),
  `TroveTests/TroveIDTests.swift` (new), `TroveTests/ItemFormViewModelTests.swift`,
  `TroveTests/WishlistFormViewModelTests.swift`, `TroveTests/ItemSaleStoreTests.swift`,
  `TroveTests/ItemDuplicationTests.swift`, `TroveTests/WishlistDuplicationTests.swift`,
  `TroveTests/WishlistPurchaseStoreTests.swift`.
  **Verify:** `scripts/verify.sh` green, the new suite in the count; each
  mutation recorded verbatim.
  **Done (2026-10-18):** every G1 leg passed as written — the store keeps two rows with one `id` (R2 holds). New `TroveIDTests` (kept code read on a second context; two rows sharing a code both persist); legs added to `ItemFormViewModelEditTests`, `WishlistFormSaveTests`, `ItemSaleStoreTests`, `ItemDuplicationTests`, `WishlistDuplicationTests`, `WishlistPurchaseStoreTests`. Mutations, each red: `save()` dropped → both read-back expectations; `@Attribute(.unique)` on `Item.id` (extra) → the shared-id leg; `item.id = UUID()` in each form's save → that leg; `item.id = UUID()` in `markSold` (extra) → both sale legs; `copy.id = original.id` in each `duplicate` → the new leg plus four existing duplication tests; `item.id = wanted.id` in `markBought` → the bought leg. Unit suite 1,813 tests in 237 suites, green.

- [x] **T001a — Two rows sharing one `id` no longer trap; every list loads and the copy acted on deletes.**
  *(Added 2026-10-08 — sign-off B1, spec Decision 18, criterion 42.)* Per plan
  §1's audit and R2. `MarketSummary.summaries(forSubjects:in:now:)` in
  `Trove/Market/MarketIndex.swift` builds its dictionary with
  `Dictionary(_:uniquingKeysWith:)`, keeping the first, with a comment naming
  the rule `PlansViewModel` already records. **Before editing, repeat the
  audit**: grep production for `uniqueKeysWithValues`, for dictionaries built
  from `\.id`, and for `first(where:` / `firstIndex(where:` on `id`, and record
  in the Done note any site plan §1 does not list — a new trapping site is
  fixed here; anything else is reported, not changed.
  Pattern: `PlansViewModel.swift:224`–`226` (the rule and its comment); the
  figure-row helpers in `ItemListViewModelTests` (`record(` beside
  `theMarketSortLeadsWithTheDearestCurrentMedianAndSinksTheRest`).
  Tests (**G20**): `MarketIndexTests` — `summaries` handed the same id twice,
  with one figure row filed under it, returns that one entry. With two stored
  `Item`s sharing an `id` and one figure row under it: `ItemListViewModel.load()`
  returns and `items` holds both; `DashboardViewModel.load()` returns with both
  in its count; `SellPlanViewModel`'s load returns with both among its
  candidates. **Delete removes the copy acted on** *(re-review N1,
  2026-10-09, plan §1 "Deletes the wrong copy — fixed")*:
  `ItemListViewModel.delete` and `WishlistViewModel.delete` gain
  `row: PersistentIdentifier? = nil` and resolve by `persistentModelID` when it
  is given; `ItemListView.swift:252` and `WishlistView.swift:194` pass
  `item.persistentModelID`. The twins have different names; deleting the twin
  loaded **second** leaves, on a second context, one row with that `id` and it
  is the first twin's name; deleting the first leaves the second's. With two
  `WishlistItem`s sharing an `id`, one figure row and a sell plan on each:
  `WishlistViewModel.load()` and `PlansViewModel`'s load return and list both;
  the same two delete legs (mutations: `uniqueKeysWithValues` restored → the
  run **crashes**; record the crash output as the red, then restore; `delete`
  resolving by `id` as today → the delete-the-second leg red; `delete`
  deleting every row with the id → both delete legs red). `DeletionGuardTests`
  is re-read before it is touched if it goes red.
  Files: `Trove/Market/MarketIndex.swift`,
  `Trove/ViewModels/ItemListViewModel.swift`,
  `Trove/ViewModels/WishlistViewModel.swift` (`delete` only),
  `Trove/Views/Items/ItemListView.swift`, `Trove/Views/Wishlist/WishlistView.swift`
  (the one delete call each), `TroveTests/MarketIndexTests.swift`,
  `TroveTests/ItemListViewModelTests.swift`, `TroveTests/WishlistViewModelTests.swift`,
  `TroveTests/DashboardViewModelTests.swift`, `TroveTests/SellPlanViewModelTests.swift`,
  `TroveTests/PlansViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; the crash and the second mutation
  recorded; the audit's grep output summarised in the Done note.
  **Done (2026-10-18):** `MarketSummary.summaries` keeps the first via `uniquingKeysWith`; both list deletes take `row: PersistentIdentifier? = nil` and resolve by it, and both views pass `item.persistentModelID`. G20 legs in `MarketIndexTests`, `ItemListViewModelSharedIDTests`, `WishlistViewModelSharedIDTests`, `DashboardSharedIDTests`, `SellPlanSharedIDTests`, `PlansViewModelTests.twoEntriesSharingOneIDBothList`. Mutations: `uniqueKeysWithValues` restored → the run crashed (`Fatal error: Duplicate values for key`, raw log only; the summary shows a relaunch count and exit 65); delete by `id` → the delete-the-second leg red on both lists; delete every twin → both delete legs red on both lists. **Audit**: no trapping site beyond `MarketIndex.swift:92`. Not in plan §1, reported not changed: `SellPlanViewModel` toggle (`:418`) and `selectedIDs` work by `id`, so selecting or deselecting one twin moves both — a further "works, with a stated limit" for the Phase 3 pause; `risesForRisingCandidates` subscript-assigns (last wins, same value); `PlansView.swift:235` rows repeat ids (T001b's case). **Rewritten to the new rule**: `ItemListViewModelRefusalTests.aRefusedSaveReportsItselfAfterTheReload`, a source scan pinning the old `delete` signature — its two signature strings updated, its rule unchanged. Unit suite 1,823 tests in 241 suites, green.

- [x] **T001b — The screens with twins present: a seed and a UI test.**
  *(Added 2026-10-08 — sign-off B1.3.)* Per plan §1 (the `ForEach` sites) and
  §11. `UITestSeed` gains `sharedIDArgument = "-seedSharedID"`,
  `shouldSeedSharedID(mode:arguments:)` and `sharedID(into:now:)`: two owned
  items with different names and one `id`, one figure row filed under it; two
  wanted entries with different names sharing another `id`, one of them with a
  sell plan holding both owned twins. `TroveApp` reads the argument exactly as
  it reads `-seedSold`. New UI test `testTwoRowsSharingOneIDListAndOneDeletes`,
  launching with `-uiTesting -seedSharedID`: the Items tab shows both owned
  names; the Dashboard opens; the Wishlist shows both wanted names; the Plans
  tab opens and lists the plan; the sell plan lists both twins; back on Items,
  deleting the twin listed second removes that name and leaves the first
  twin's on screen.
  **If both twins do not draw, or a screen misbehaves**, the routine fix — no
  new decision — is `id: \.persistentModelID` at the `ForEach` sites plan §1
  names (`ItemListView.swift:336`, `:470`, `WishlistView.swift:336`,
  `SellPlanView.swift:450`, `:520`, and `PlansView`'s rows if they repeat);
  apply it only where the test shows the need and say which in the Done note.
  Pattern: `UITestSeed.sold(into:now:)`, `shouldSeedSold`, and its
  `UITestSeedTests`; the `-seedSold` UI tests for the launch and the delete
  swipe.
  Tests (**G20**): `UITestSeedTests` — with every flag set, the seed refuses a
  store that is not the in-memory one; `-uiTesting` alone seeds nothing; the
  seeded twins share an `id` and the wanted twins share another (mutation: the
  mode gate removed → red). The UI test above (mutation: one twin dropped from
  the seed → the both-names legs red).
  Files: `Trove/App/UITestSeed.swift`, `Trove/App/TroveApp.swift`,
  `TroveTests/UITestSeedTests.swift`, `TroveUITests/TroveUITests.swift`, and —
  only under the routine fix — `Trove/Views/Items/ItemListView.swift`,
  `Trove/Views/Wishlist/WishlistView.swift`, `Trove/Views/Wishlist/SellPlanView.swift`,
  `Trove/Views/Plans/PlansView.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green **twice
  back to back**, both counts recorded (a new seed must not leak into any other
  test's starting state); mutations recorded; the Done note says what SwiftUI
  did with the repeated ids and whether the fix was needed.
  **Done (2026-10-18):** `-seedSharedID` seed (owned twins "Rickenbacker 330" / "Rick 330 Jetglo" with one figure row; wanted twins "Mamiya 7 II" / "Mamiya Seven", only the first planned, its plan holding both owned twins), gated like `-seedSold`; `UITestSeedTests` legs (refuses CloudKit and local-only stores with every flag set; `-uiTesting` alone seeds nothing; the twins share their ids, read on a second context); `testTwoRowsSharingOneIDListAndOneDeletes`. **What SwiftUI did with repeated ids**: no crash, the right number of rows, but every row sharing an id drew the first twin's content, so the other name never appeared. **Routine fix applied** at `ItemListView.swift:336`, `WishlistView.swift:336`, `SellPlanView.swift:450` (each shown failing first). Not exercised by the seed (no sold twins): `ItemListView:470`, `SellPlanView:520`. `PlansView.swift:235` shows the same bug when both wanted twins have plans (seen on a variant seed), but `PlanRow` carries no `persistentModelID`, so the routine fix cannot be written there — sent to a decision review (below). Mutations: mode gate removed → the two refuse-a-persistent-store expectations red; one twin dropped from the seed → the both-names legs red (4 failures); delete by `id` again (extra) → the deleted/kept legs red. Unit 1,825 tests in 241 suites green; `scripts/verify.sh ui` twice back to back, 43 tests each, 0 failures.

- [ ] **T001c — Plans rows and the Sold lists with twins: each draws its own row and acts on it.**
  *(Added 2026-10-18 — decision review after T001b.)* Per plan §1 "Plans rows —
  fixed". `PlansViewModel.PlanRow` gains `rowID: PersistentIdentifier` (from
  `wanted.persistentModelID`), `PlanRow.id` unchanged; `PlansView` keys its
  `ForEach` on `\.rowID`; `entries` keyed by `PersistentIdentifier`, the
  `uniquingKeysWith` and its comment removed; `makePurchaseFormViewModel(for:)`
  and `markBought(_:purchase:)` look up by `rowID`; `deletePlan` takes the row
  or its `rowID`. `ItemListView.swift:470` and `SellPlanView.swift:520` take
  `id: \.persistentModelID`, each shown failing first.
  Seed: the second wanted twin gets a plan of its own (with its own candidate,
  so the existing sell-plan leg keeps its two-twin assertion); a sold twin pair
  in the Items Sold list; a sold twin pair in one plan's Sold section (the
  second wanted twin's plan can carry it). `UITestSeedTests` updated to match.
  Tests (**G20**): `PlansViewModelTests`, two wanted twins sharing an `id`, both
  planned — `rows` lists both names with different `rowID`s; `deletePlan` on the
  second row leaves, on a second context, the first twin's plan and not the
  second's, and the reverse; `markBought` on the second row marks the second
  twin and leaves the first unchanged (mutation: `entries` keyed by `id` again →
  the delete and mark-bought legs red). UI: `testTwoRowsSharingOneIDListAndOneDeletes`
  (or a sibling) — the Plans tab shows both wanted names; the Items Sold list
  shows both sold names; the plan's Sold section shows both (mutation per site:
  back to `\.id` → that site's both-names leg red, and each shown red before
  its fix). `WishlistDetailViewModelTests.swift:1943` gains the new argument.
  Files: `Trove/ViewModels/PlansViewModel.swift`, `Trove/Views/Plans/PlansView.swift`,
  `Trove/Views/Items/ItemListView.swift`, `Trove/Views/Wishlist/SellPlanView.swift`,
  `Trove/App/UITestSeed.swift`, `TroveTests/PlansViewModelTests.swift`,
  `TroveTests/UITestSeedTests.swift`, `TroveTests/WishlistDetailViewModelTests.swift`,
  `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green twice back
  to back, both counts recorded; mutations recorded.

- [ ] **T002 — The reader's grammar: prices, slash dates, `N/A`, the code.**
  Per plan §2, Q7, Q8, P4, P6, spec Decision 22. New
  `Trove/Import/ImportRows.swift` opening with `Cell<Value>` and
  `SlashDateOrder` (with `regional(for:)`). In `ImportSchema`: `isBlank(_:)`;
  `cents(from:)` **widened in place** to the grammar plan §2 gives — spaces
  after a currency symbol are skipped; `day(from:timeZone:order:)` with
  `order: SlashDateOrder? = nil` (nil keeps today's ISO-only behaviour for
  every existing caller); `slashDateOrder(in:region:)` returning the order and
  whether the region decided it; `troveID(from:) -> Cell<UUID>`. Doc comments
  on `cents` and `day` say what `021` widened and point at spec Decisions 6, 16
  and 22.
  Pattern: `ImportSchema.cents(from:)` and `day(from:)`, and their tests in
  `TroveTests/ImportSchemaTests.swift` (`canonicalMoneyFormsParseCentExact`,
  `impossibleDatesAreRejected`).
  Tests: new `TroveTests/ImportGrammarTests.swift`. **G2** — `$3,179.95`,
  `€1,250`, `£99.5`, `¥500`, `1,250.00`, `500`, `$0.00`, **`$ 3,179.95`,
  `€ 1,250`, `$  5`** to the exact cent (criteria 11, 46); `1.250,00`, `-5`,
  `(5.00)`, `1,25`, `500 USD`, `12,34,567`, `$`, `5$`, `5 $`, `1 250` nil;
  `ExportSchema.money` output still reads back (mutations: grouping as
  `d{1,3}(,d+)*` → `1,25` reads → red; commas stripped before parsing →
  `12,34,567` reads → red; the space-skip removed → criterion 46's two red;
  spaces skipped with no symbol before them → `1 250` reads → red). **G3** — ISO
  reads as before with and without an order; `12/28/2025` beside `5/1/2025`
  settles month-first for both; `28/12/2025` beside `1/5/2025` settles
  day-first; a file with only `5/1/2025` takes the region's order and reports
  that the region decided, under `en_US` and `en_GB`; a file holding
  `12/28/2025` and `28/12/2025` takes the region's order and the one that does
  not fit is nil; `3/9/26` nil; `2/30/2025` nil; a file of ISO dates reports no
  region decision; `regional(for:)` for `en_US`, `en_GB`, `de_DE`, `ja_JP`
  (mutations: order decided per cell → the settles-both legs red; the region
  reported for an ISO-only file → red). **G4** — `N/A`, `n/a`, ` #N/A ` blank;
  `NA`, `none`, `-` not; an upper-case, a lower-case and a space-padded code
  read to the same `UUID`; `abc` and a 35-character code are `unreadable`;
  blank is `empty` (mutation: `NA` accepted → red).
  **Rewritten, not loosened**: `ImportSchemaTests.nonCanonicalMoneyIsRejected`
  lists `"$5"` and `"1,250.00"` as rejected — those two move to an accepted
  test, the other eleven arguments stay rejected. That the symbol never sets
  the currency is a fact about the row reader, not this function — T004's leg.
  Files: `Trove/Import/ImportRows.swift` (new), `Trove/Import/ImportSchema.swift`,
  `TroveTests/ImportGrammarTests.swift` (new), `TroveTests/ImportSchemaTests.swift`.
  **Verify:** `scripts/verify.sh` green, the new suite in the count; mutations
  recorded; the Done note names every existing test that changed.

- [ ] **T003 — Finding columns by name.**
  Per plan §3, P1–P3. `ImportColumns` (in `ImportRows.swift`) with
  `match(header:known:required:otherRequired:)`, `position(of:)`, `width`,
  `unused`, and `HeaderError` (`wrongList`, `missing`, `duplicate`).
  `ExportSchema` gains `itemRequiredHeaders`, `wishlistRequiredHeaders` and
  `troveIDHeader = "Trove ID"`. Nothing calls the matcher yet.
  Pattern: `ImportSchema.requireHeader` (what it replaces) and the header-gate
  tests in `TroveTests/ImportSchemaTests.swift` (`exactHeadersPassBothGates`
  onward).
  Tests (**G5**): new `TroveTests/ImportColumnsTests.swift` — `purchase price`,
  ` Purchase Price `, `Purchase Price *`, `PURCHASE PRICE*` are one column
  (criterion 4); the items header shuffled gives each name its new position
  (3); a header missing `Purchase Price` and `Purchase Date` reports **both**,
  in schema order (5); `Name` twice → `.duplicate("Name")` (8); `Mount`,
  `Insured`, `Purchse Price` land in `unused` in file order, a blank header cell
  and a repeated unknown name do not appear twice (7); a wishlist header given
  to the items matcher is `.wrongList`, and the reverse, at the 7-, 9- and
  10-column and the 12-, 14-, 18- and 19-column layouts (10); an empty header is
  `.missing` all required names (mutations: only the first missing name
  reported → red; the star not dropped → red; an unknown column throwing → red;
  wrong-list decided by cell count → red).
  Files: `Trove/Import/ImportRows.swift`, `Trove/Export/ExportSchema.swift`,
  `TroveTests/ImportColumnsTests.swift` (new).
  **Verify:** `scripts/verify.sh` green, the new suite in the count; mutations
  recorded.

  **Phase 1 closes here — `walkthrough: none`; after its review, run on.**

## Phase 2 — Reading a sheet as it is · walkthrough: yes — Items › ⋯ › Import from CSV: your own `My-Gear.csv` imports as it is — the confirmation says 90 items will be added and that row 108 looks like a totals row and was left out, with nothing skipped and no defaults; after Import the 13 items whose serial number said N/A have none, the one written 0185654 keeps its zero, and the Alienware monitor is worth $500 (do this on a simulator, or anywhere you are happy to add 90 items — Settings › Delete All clears them); `docs/samples/items-hand-kept.csv` does the same with invented rows; move the columns around in a sheet, or add a column of your own, and it still imports, with the confirmation naming the column it did not use; delete the Condition column and it still imports, the confirmation saying once that new items will be Excellent rather than counting every row; delete the Purchase Date column and the file is refused, the alert naming what is missing; a price written `$ 3,179.95`, with a space, reads; a file an older Trove exported still imports; the Wishlist does all of this with its own columns. Not yet, by design: exports are unchanged and importing a file twice still adds copies — that is Phase 3

- [ ] **T004 — The items rows and the items sheet. `review: per-task`.**
  Per plan §4, Q2, P5, P7, P8, R8, spec Decisions 17 and 23. In
  `ImportRows.swift`: `ItemImportRow`, `ImportSheet<Row>` (with
  `missingDefaultColumns`), and `ItemImportRow.asNew(now:missingColumns:)`
  returning `ValidatedRow<ItemExportRecord>?` with **exactly today's field
  policy and counts** (copy the policy from `ImportSchema.itemsPreview`, do not
  re-derive it), plus one count for an unreadable Trove ID, **minus** the count
  for a default taken because its column is in `missingColumns` (the default is
  still taken). In `ImportSchema`: `itemsSheet(from:timeZone:locale:)` — shape,
  match columns, record which of `Desire to Keep` and `Condition` are absent,
  settle the slash order over `Purchase Date` and `Sold Date`, then the five
  row steps of plan §4 **in that order, looking only at recognised columns**.
  The known names are `ExportSchema.itemHeaders + [ExportSchema.troveIDHeader]`
  for now — a stated, temporary seam that T008 removes when the array itself
  gains the name. **Additive**: `itemsPreview` and the header gate stay,
  untouched, until T007.
  New `docs/samples/items-hand-kept.csv` exactly as plan §4 specifies. Its
  header row is, literally:
  `Name,Category,Purchase Price,Currency,Purchase Date,Purchase Location,Current Value,Desire to Keep,Condition,Serial Number`
  — then 24 invented rows in four groups, the separator rows, three blank rows,
  and a totals row whose two amounts are the true sums. Every feature in plan
  §4's list present; LF endings, no BOM, no trailing newline.
  Pattern: `ImportSchema.itemsPreview` (the field policy, the padding, the row
  numbering) and `ImportSchemaTests.aFullyValidRowValidatesWithNoDefaults`
  onward.
  Tests (**G6**, **G21**): new `TroveTests/ImportSheetTests.swift` — the
  hand-kept fixture (criterion 1): its first line equals the literal above; 24
  rows, no skips, `asNew` over every row totals zero defaults,
  `totalsRowNumbers` is the one literal row number, `regionDateOrder == nil`,
  `missingDefaultColumns` empty; from it by name: a `$0.00` price is 0 and
  uncounted, the bare `500` is 50 000, the leading-zero serial is kept as text,
  an `N/A` serial is `empty`, the trailing-space name is trimmed, the
  doubled-quote name reads, a date with a day above 12 lands on that day. The
  fixture's columns shuffled, in memory, give `rows` equal to the original's
  (3). A file of only `Name`, `Purchase Price`, `Purchase Date`: every other
  field takes what a blank cell gives today, `missingDefaultColumns ==
  ["Desire to Keep", "Condition"]`, and its rows count **zero** defaults; the
  same file with a `Condition` column whose cells are blank names only `Desire
  to Keep` and counts one default per row (6, 41). A `€1,250` price beside a
  blank `Currency` gives `USD`, and beside `GBP` gives `GBP` (criterion 11's
  "the symbol does not change the item's currency"). `N/A` in each of Serial
  Number, Current Value, Year, Purchase Price and Name: empty, empty, empty, the
  counted default, the row skipped as nameless (14). A totals row unlabelled
  and labelled `Total`, `totals`, `Subtotal`, `SUM`, in the middle and at the
  end, is left out and not skipped; **a totals row with a sum under an unknown
  column is still a totals row** (Decision 23); a nameless row with a date is
  skipped "no name"; a row named `Total` with a date is an item; a
  totals-shaped row with a Trove ID is not a totals row; a row of `N/A`s, and a
  row filled only under an unknown column, are dropped silently (15). A
  nameless row with a readable code is kept. A row with more cells than **the
  header** is skipped "more columns than the header"; a short row pads
  (mutations: `N/A` blanked only for Serial Number → the other four legs red; a
  totals row with a filled Category left out → red; an unknown column's cell
  stopping a totals row → red; a totals row appended to `skipped` → red; the
  slash order taken from the first date → red; a missing column's default
  counted per row → the criterion-41 leg red; a blank cell in a *present*
  column going uncounted → red; the currency taken from the symbol → red).
  Files: `Trove/Import/ImportRows.swift`, `Trove/Import/ImportSchema.swift`,
  `docs/samples/items-hand-kept.csv` (new), `TroveTests/ImportSheetTests.swift`
  (new).
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded verbatim; the fixture's row count, totals row number and the two
  sums stated in the Done note.

- [ ] **T005 — The wishlist rows and the wishlist sheet.**
  Per plan §4, Q4. `WishlistImportRow`, its `asNew(now:missingColumns:)`
  (today's wishlist policy: cost and desire and `Added` default and count;
  currency, product, year and `Looking For` count only when unreadable; a
  missing column's default uncounted), and
  `ImportSchema.wishlistSheet(from:timeZone:locale:)` — the money column for the
  totals rule is `Estimated Cost`, the date column for the order scan is
  `Added`, and `missingDefaultColumns` reports `Desire to Own` and `Added`.
  Same temporary known-names seam as T004. Additive.
  Pattern: T004's `itemsSheet`, and `ImportSchema.wishlistPreview` for the
  policy.
  Tests (**G7**, **G21**, `ImportSheetTests`): criterion 16 — a hand-written
  wishlist sheet with columns out of order, `$` costs with commas, slash `Added`
  dates that settle their order, an `N/A`, an unknown column, a blank row and a
  totals row imports with every row kept and no defaults; required-only (`Name`,
  `Estimated Cost`) names both missing columns and counts zero defaults; the
  same totals and nameless legs as T004, once each (mutations: `Estimated Cost`
  missing from the totals rule → red; `Added` not offered to the order scan →
  red; a missing `Added` counted per row → red).
  Files: `Trove/Import/ImportRows.swift`, `Trove/Import/ImportSchema.swift`,
  `TroveTests/ImportSheetTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T006 — The summary, the words, and the two stores' add path.**
  Per plan §5, §8, Q11, R7. New `Trove/Import/ImportStore.swift`:
  `ImportSummary` (every field plan §5 lists, `missingDefaultColumns` and
  `keptCodeAdds` included — the latter stays 0 until T010 and T011 count it),
  and `ItemImportStore` / `WishlistImportStore` with
  `plan(for:in:timeZone:now:)` and `apply(_:in:now:)` — **adds only in this
  task**: every row goes through `asNew` with the sheet's
  `missingDefaultColumns`, the Trove ID cell is ignored, and `Plan` has no
  `updates` yet (T010 and T011 add them). `apply` is today's commit loop
  **moved, not rewritten**, from `ItemListViewModel.confirmImport` and
  `WishlistViewModel.confirmImport`: placement after every stored position
  computed here, category casing resolved in file order, a readable sale pair
  arriving sold, `Added` restoring `createdAt`. `ImportError` gains `wrongList`,
  `missingColumns`, `duplicateColumn` (the old case stays until T007).
  `ImportCopy` gains `confirmationTitle(summary:)`,
  `confirmationLines(summary:target:recounted:)` and the three failure
  sentences, every string as plan §5 gives it; `ImportSchema.SkipReason` gains
  the reasons plan §5 lists, `alreadyBought` among them. The lines include the
  unknown-codes warning (plan R10, spec Decision 19) — worded here, and placed
  second to last, just above "Updates can't be undone." The view models are
  **not** touched. Additive.
  Pattern: `ItemSaleStore` / `WishlistPurchaseStore` (one writer, callers
  save); `ImportCopy.confirmationMessage(preview:)` and `ImportCopyTests`.
  Tests: **G8** (`ImportCopyTests`) — the title both ways; each line by literal
  with its singular; the order of lines for a summary with everything set; the
  shared-code hint only when a skip carries that reason, including when that
  skip falls past the first five; the four missing-column sentences, shown only
  when `added > 0` (**G21**); the recounted line only when `recounted`, and
  first when it is; the unknown-codes warning by literal for `keptCodeAdds` of
  90 and of 1 — "90 rows have a Trove ID this iPhone doesn't have yet. If
  iCloud is still bringing your collection down, wait — importing now adds them
  a second time." / "1 row has … adds it a second time." — and absent at 0
  (**G22**'s words); "Updates can't be undone." only when `updated > 0`; "No
  problems found." only when nothing else is said; the three failure sentences
  for one, two and three names; every skip reason's string (mutations: the undo
  line shown for adds → red; the hint shown always → red; a missing-column line
  shown for a summary that only updates → red; the unknown-codes line shown at
  0 → red). **G9** — new `TroveTests/ItemImportStoreTests.swift`
  and `WishlistImportStoreTests.swift`, every assertion on a second context
  after the caller's `save()`: rows land after an existing collection in file
  order; a sale pair arrives sold with all four fields and no plan; a casing
  variant takes the existing path's casing; `Added` is the row's date; the
  summary's `added`, `skipped`, `defaultedOnNew`, `unusedColumns`, `totalsRows`,
  `regionDateOrder` and `missingDefaultColumns` equal the sheet's (mutations:
  placement from `0` → red; `createdAt` left at now → red).
  Files: `Trove/Import/ImportStore.swift` (new), `Trove/Import/ImportService.swift`,
  `Trove/Import/ImportSchema.swift`, `TroveTests/ItemImportStoreTests.swift`
  (new), `TroveTests/WishlistImportStoreTests.swift` (new),
  `TroveTests/ImportServiceTests.swift`.
  **Verify:** `scripts/verify.sh` green, both new suites in the count; mutations
  recorded.

- [ ] **T007 — The switch: the service, the view models, and the old gate retired.**
  Per plan §3, §5, §8, Q3, Q6. `ImportService`'s two requirements take
  `locale:` and return sheets (`@concurrent` kept on requirement and
  implementation); `FileImportService` maps `ImportColumns.HeaderError` onto
  the three new `ImportError` cases; `ImportPresentation<Row>` carries `sheet`,
  `summary` and `recounted` (always false until T010). Both view models:
  `importCSV(from:)` parses with `timeZone: .current, locale: .current`, then
  stages `plan(…).summary`; the three alert accessors read the summary through
  `ImportCopy`; `confirmImport()` **keeps its synchronous capture** (read the
  doc comment — the `012` T017 finding), returns early unless
  `summary.writesAnything`, and in its task calls `plan` again, `apply`,
  `save()`, with `rollback()` and the save-failure copy on any throw. Deleted,
  with nothing left to call them: `itemsPreview`, `wishlistPreview`,
  `requireItemsHeader`, `requireWishlistHeader`, `requireHeader`, the old
  `ImportSchema.HeaderError`, `ImportPreview` and its two typealiases,
  `ImportError.headerMismatch`, `ImportCopy.confirmationTitle(importCount:target:)`
  and `confirmationMessage(preview:)`, `ExportSchema.itemSchemaBoundaries` and
  `wishlistSchemaBoundaries`. **Comments count**: `ExportSchema.swift:50`–`53`
  names `ImportSchema.itemsPreview` and is corrected. Neither list view
  changes; if `ImportWiringTests` goes red, re-read it before touching it.
  Before anything else, **byte-copy** today's `docs/samples/items-full.csv` and
  `docs/samples/wishlist.csv` to `TroveTests/Fixtures/Import/items-020-layout.csv`
  and `wishlist-020-layout.csv` (`cp`, checked with `cmp`), with a short
  `README.md` saying they are the layout `020` shipped and must never be edited.
  Pattern: the existing import sections of the two view models; `TestSupport`'s
  `ImportServiceSpy` and `GatedImportServiceSpy`.
  Tests (**G10**, **G16**). **Re-pointed, assertions unedited**: `TestSupport`
  gains one helper, `asAllNew` on each sheet type, returning `validated`,
  `skipped` and `defaultedFieldCount` built from the production `asNew` — every
  existing field-policy test in `ImportSchemaTests`, `DocsSampleTests` and the
  two view-model import suites calls the sheet function and that helper, and
  its expectations stay as they are; those tests staying green **is** the
  evidence that a new row is read as it was. **Rewritten to the new rule, each
  named in the Done note**: `missingExtraRenamedAndReorderedColumnsAllMismatch`
  (missing required → refused and named; extra → imported and listed; renamed
  optional → unused; reordered → identical rows);
  `theTwoLegacyItemWidthsPassAndTheWidthsBetweenThemDoNot` (the widths between
  now import — renamed for what it pins); `anEmptyFileFailsTheGateNotTheRowPolicy`
  (an empty file is missing every required column);
  `extraContentCellsSkipTheRow` and `aLegacyFilesOverlongRowIsStillExtraColumns`
  (the new reason, judged against the header's width); the boundary literals in
  `ExportSchemaTests` (replaced by the layout fixtures below); `ImportCopyTests`'
  pins of the retired title, message and header-mismatch sentence; the spies.
  **New**: every shipped layout imports with zero skips and zero defaults
  through the live `FileImportService` — items at 12 (`items-partial.csv`'s
  header over clean rows), 14 (`items-resaved.csv`), 18 (the inline file
  `anEighteenColumnItemsFileImportsWithNothingRecorded` already builds) and 19
  (`items-020-layout.csv`); wishlist at 7, 9 and 10 (`wishlist-020-layout.csv`)
  (criterion 9); each whole-file failure — unreadable, not UTF-8, unclosed
  quote, too large, missing column, duplicated column — leaves a second
  context's fetch empty (37); `ImportConcurrencyTests`' probe still reports off
  the main thread; `locale` reaches the schema (an ambiguous slash file through
  the service under `en_GB` reads day-first); view models — the confirmation is
  staged with nothing written, Cancel leaves the store untouched, a summary
  that writes nothing offers no import action and `confirmImport()` returns nil
  (36); a required-columns-only file staged through the view model shows the
  two missing-column lines and no defaults line (41) (mutations: one layout's
  column lookup misspelled → that layout shows a default → red; `locale`
  dropped in `FileImportService` → red; `importOffersConfirmation` on
  `!rows.isEmpty` → red for a sheet whose only row is nameless).
  `docs/samples/README.md`: the `bad-headers.csv` row says it now fails as
  missing `Name`; `items-partial.csv`'s row keeps its numbers (5 import, rows 5
  and 7 skipped, 6 defaults — confirm, do not assume).
  Files: `Trove/Import/ImportService.swift`, `Trove/Import/ImportSchema.swift`,
  `Trove/Import/ImportRows.swift`, `Trove/Export/ExportSchema.swift`,
  `Trove/ViewModels/ItemListViewModel.swift`, `Trove/ViewModels/WishlistViewModel.swift`,
  `TroveTests/TestSupport.swift`, `TroveTests/ImportSchemaTests.swift`,
  `TroveTests/ImportServiceTests.swift`, `TroveTests/ItemListViewModelTests.swift`,
  `TroveTests/WishlistViewModelTests.swift`, `TroveTests/ExportSchemaTests.swift`,
  `TroveTests/DocsSampleTests.swift`, `TroveTests/Fixtures/Import/` (new: two
  CSVs and a README), `docs/samples/README.md`.
  **Verify:** `scripts/verify.sh` green; mutations recorded; the Done note lists
  the tests re-pointed (by suite) and the tests rewritten (by name), and
  confirms by a grep **that includes comments** that no deleted symbol is still
  named anywhere under `Trove/` or `TroveTests/`. Then `scripts/verify.sh ui`
  once at the phase end, count recorded. **For the phase review, the
  orchestrator's bundle shows each rewritten shipped test before and after**
  (`git show main:<file>` for the old body beside the diff), so the reviewer
  judges a rule being re-pinned, not a test disappearing.

  **Phase 2 closes here — pause for the person** (walkthrough above; the phase
  review first). The report says, as a statement the person can overturn: the
  alert's wording was fitted to an alert, which draws no bold, and three
  missing-column sentences were worded after theirs (plan R7). It also records
  what the person saw for criterion 2 — their own file — in their words, for
  the close-out.

## Phase 3 — The Trove ID, and updating by re-import · walkthrough: yes — Settings › Templates and every CSV export: the header reads `Name *`, `Purchase Price *`, `Purchase Date *` (on the wishlist `Name *`, `Estimated Cost *`) and the last column is `Trove ID`, with a code on every row and none in the templates; export the collection, open it in Google Sheets, change a price and a category, fill in Bought down the column, add one row of your own with no Trove ID, download it as CSV and import it: the confirmation counts what will be updated, added and left unchanged and says updates can't be undone, and after Import exactly those items changed — photos, sell plans and your custom order as they were, the new row at the end; import an untouched export and it says nothing to import, every row unchanged; empty a cell in the sheet and import: that value stays; fill the sale columns for something you still own: it stays owned and the confirmation says so; a sold item's sale price can be corrected from the sheet; paste a wishlist row, Trove ID and all, into the items sheet: that row is left out and the confirmation says its Trove ID belongs to the other list; export the wishlist, mark one entry bought, import the old file: that row is left out as already bought; import `docs/samples/items-full.csv`: the confirmation warns "12 rows have a Trove ID this iPhone doesn't have yet. If iCloud is still bringing your collection down, wait — importing now adds them a second time." (go ahead — they are the sample's rows), and importing it a second time carries no such warning, nor does your own untouched export; then `docs/samples/items-edited.csv` shows every line the confirmation can carry at once, the warning now counting 1 row — is that readable as an alert?; the PDF is as it was; the Wishlist does the same with its own columns; and `docs/csv-reference.md` now opens with this loop. **One thing only you can do**: open `docs/samples/items-full.csv` in Google Sheets, change nothing, File › Download › Comma-separated values, and hand that file back — it becomes the recorded proof that the codes survive a spreadsheet

- [ ] **T008 — Export writes the star and the Trove ID; the templates follow.**
  Per plan §6, Q10, P2, P10. `ExportSchema.itemHeaders` and `wishlistHeaders`
  gain `troveIDHeader` as their last element; `headerRow(_:required:)`,
  `itemHeaderRow`, `wishlistHeaderRow`; `itemsTable` / `wishlistTable` write the
  header row; both records gain `var troveID: UUID? = nil`, filled from
  `item.id` in each `init(item:)`; both row functions append the code. The doc
  comment on `itemHeaders` records why append-only is still the rule.
  `SettingsViewModel`'s two templates pass the header rows. In
  `ImportRows.swift`: both `asNew` functions carry `troveID` when the cell held
  a code, and **T004's temporary known-names seam is removed** — the reader's
  known names are the two arrays again. The stores still ignore the code until
  T010.
  Pattern: `020` T011's `Bought` column through `ExportSchema` and its tests.
  Tests (**G11**): `ExportSchemaTests` — both header rows by literal, 20 and 11
  cells, stars on exactly the required names, `Trove ID` last; a record's row
  ends in its `uuidString`, and in an empty cell when nil; the existing row
  literals updated for the trailing cell and otherwise untouched (P10: money
  and dates as they were). `ItemListViewModelTests` (owned, sold, both),
  `WishlistViewModelTests`, `SettingsViewModelTests` (Export All's two files):
  the staged table's header is the starred row and every row's last cell is
  that item's `id` — non-empty, all different (criterion 18).
  `SettingsViewModelTests`: both templates are the header row and no rows — the
  pins at the two places that assert `ExportSchema.itemHeaders` /
  `wishlistHeaders` are **rewritten** to the header rows.
  `ImportSchemaTests.theTemplatesEndInBoughtAndLookingFor` **rewritten and
  renamed**: each template ends in `Trove ID` and imports as zero rows with no
  failure. The two export round-trip tests still pass with the new header.
  `PDFComposerTests` and `PDFComposerStockTests` green **unedited**, plus one
  assertion that no `PDFField` label or value of an entry built from a record
  with a code contains it (criterion 21) (mutations: `init(item:)` dropping
  `troveID` → red in all five export paths; `itemsTable` on `itemHeaders` → the
  star legs red; a template on the unstarred names → red; a `Trove ID`
  `PDFField` added → red).
  Files: `Trove/Export/ExportSchema.swift`, `Trove/Import/ImportRows.swift`,
  `Trove/Import/ImportSchema.swift`, `Trove/ViewModels/SettingsViewModel.swift`,
  `TroveTests/ExportSchemaTests.swift`, `TroveTests/ImportSchemaTests.swift`,
  `TroveTests/ItemListViewModelTests.swift`, `TroveTests/WishlistViewModelTests.swift`,
  `TroveTests/SettingsViewModelTests.swift`, `TroveTests/DocsSampleTests.swift`
  (only if a sample test pins a header width).
  **Verify:** `scripts/verify.sh` green; mutations recorded; the rewritten pins
  named.

- [ ] **T009 — The update rule and the matching rule, as pure functions. `review: per-task`.**
  Per plan §7, P8, R2 and spec Decisions 10, 12, 14, 15, 18, 20, 21. In
  `ImportRows.swift`: `ItemChanges` and `WishlistChanges` (a field is non-nil
  only when it is to be written — the type cannot express a clear);
  `ItemImportRow.changes(against:category:timeZone:)` and the wishlist twin,
  exactly by plan §7's per-cell rule — **never calling `asNew`**, dates compared
  by calendar day through `ExportSchema.day`, text against trimmed text with
  CRLF and CR read as LF, the sale's two cases; and
  `ImportMatching.outcomes(ids:storedCounts:refused:)` with the precedence plan
  §7 gives. No store, no view model, nothing calls them yet.
  Pattern: `Item.storage(for:)` / `condition(raw:refinement:)` (a pure rule
  with its tests beside it, `020` T001); `ImportSchemaTests`' record-building
  helpers for the fixtures.
  Tests (**G12**, **G13**): new `TroveTests/ImportUpdateTests.swift`, no
  container. Against a record whose every value differs from its field's
  default: each of name, category, purchase price, currency, purchase date,
  place, current value, desire, condition, condition notes, serial number,
  notes, Reverb product, year and Bought, changed alone, yields exactly that one
  field (criterion 23); an empty cell and an `N/A` yield nothing, for serial
  number, purchase date and current value (24 — **at this level a missing
  column is the same `empty` cell, and the store-level missing-column legs are
  T010's; "missing column × purchase date" does not exist, because criterion 5
  refuses that file — do not write a test that claims it**); `abc` for a price,
  `9` for desire, `someday` for a date yield nothing and count one each (25);
  an empty name yields no name change and still carries the row's other changes
  (26); a cell equal to the item yields nothing — including a date on the same
  calendar day as a stored mid-afternoon instant, text equal after trimming,
  and a multi-line note that differs only in `\r\n` for `\n`; the sale: a sold
  record takes a corrected date, price, place and note, each alone; emptied
  sale cells on a sold record yield nothing; filled sale cells on an owned
  record set `hasUnusedSaleCells`, write nothing and count nothing, while the
  row's other changes stand (34). The wishlist twin over its ten fields,
  `Added` by day. `ImportMatching`: empty → `new(keeping: nil)`; unreadable →
  the same; one stored match → `update`; none → `new(keeping:)` that code; the
  same code on two and on three rows → `sharedInFile` for each, naming the
  others, even when it matches a stored row; two stored rows with the code →
  `ambiguousInStore` (42); a code in `refused` → `refused` with **its own**
  reason, for both an other-list code (44) and an already-bought one (45), and
  never `update` or `new` (mutations: `changes` built from `asNew`'s record →
  the unreadable and empty legs red — **this is the mutation that matters, run
  it first**; dates compared by instant → the same-day leg red; line endings
  compared raw → the multi-line leg red; sale cells written onto an owned
  record → red; an empty cell writing nil → red at the type or the test, say
  which; the first of two sharing rows returned as `update` → red; an unmatched
  code returned as `new(keeping: nil)` → red; `refused` consulted after the
  store match → the already-bought leg red).
  Files: `Trove/Import/ImportRows.swift`, `TroveTests/ImportUpdateTests.swift`
  (new).
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded verbatim; the new suite in the count.

- [ ] **T010 — Items: matching and updates through the store and the view model. `review: per-task`.**
  *(Marked per-task 2026-10-08 — sign-off B2.)* **Owns criteria 43 and 47 for
  the collection** (T011 mirrors both for the wishlist). Per plan §8, Q3, Q5,
  P11, R2, R9, R10, spec Decisions 18, 19, 20 and 24.
  `ItemExportRecord.init(item:includingPhoto:)`
  gains its defaulted parameter (`true`; `false` reads no photo).
  `ItemImportStore.plan` fetches every `Item` and every `WishlistItem.id`
  (`refused`, "its Trove ID belongs to the other list"), runs `ImportMatching`,
  and per outcome builds an add (`asNew`; nil → skipped "no name"), an update
  (canonicalised category, the photo-less snapshot, `changes`), an unchanged
  count, or a skip with its reason; `Plan` gains `updates`; the summary gains
  `updated`, `unchanged`, `unreadableOnUpdates` (matched rows, updated **or**
  unchanged), `unusedSaleRows`, the new skips, kept in row order, and
  **`keptCodeAdds`** — one for each add built from a `new(keeping:)` outcome
  whose code is non-nil, so never a matched row, a row with no code, or a
  kept-code row that was skipped (Decision 19; T006's line then shows itself).
  `apply`:
  for a kept code, `MarketLocalStore.clear(subjectID:)` for that code and then
  `item.id` set **before** insert; each change written **inside its own
  `if let`** (condition through `item.condition`, the sale through
  `item.sale`); the item's market rows cleared first when its Reverb product
  changes; `updatedAt` stamped on updated items only; nothing touched on an
  unchanged row. `ItemListViewModel.confirmImport()`: after the second `plan`,
  **if its summary differs from the staged one — compared whole, `==` on
  `ImportSummary`, not on its counts — write nothing and present the
  confirmation again over the new summary with `recounted: true`** (Decision
  24); otherwise apply and save. Confirming the re-presented one runs the same
  method, so it applies if nothing moved again.
  Pattern: T006's add path; `ItemDetailViewModel.setMatch` for the market
  clear; `ItemListViewModelCommitTests.commitRestoresBoughtAndVeryGoodThroughTheCSV`
  for an export → CSV → parse → commit → second-context test.
  Tests (**G14**; `ItemImportStoreTests` and `ItemListViewModelCommitTests`,
  every persisted assertion on a second context). **The four store-level
  guards, first**: (i) an item with **every optional field filled** and a row
  changing only its notes — every other stored field is what it was, asserted
  field by field, a text, a money and a date field among them; (ii) a matched
  row with an empty price, `abc` for the date and `N/A` for the serial — the
  three stored values unchanged and `unreadableOnUpdates == 1` (25); (iii) a
  file with no `Serial Number` and no `Current Value` column — both stored
  values unchanged (24); (iv) a matched row with an empty Name — updated, the
  name kept, the row not skipped (26). The round trip (criterion 22): a
  collection of awkward values — a mid-afternoon purchase date, a sold item
  with a note, Very Good, a nil current value, notes with padding, **a note
  with line breaks**, a name that needs quoting — exported as owned-and-sold,
  written by `CSVWriter`, parsed, planned: zero added, zero updated, every row
  unchanged, and after `confirmImport()` (which must return nil) every item's
  `updatedAt` and stored dates are what they were. Updates: the fifteen fields
  changed through a file land on a second context, Very Good as the stored pair
  `("good", "very good")`, the confirmation counting the row (23); an ID-less
  file twice makes two copies (27 — `committingTheSameFileTwiceDuplicatesEveryRow`,
  kept); a row whose code matches nothing arrives carrying it, **market rows
  left under that code by a deleted item are gone**, and the same file again
  updates nothing and adds nothing (28); two rows sharing a stored item's code
  leave it untouched and are both listed with the hint (29); `abc` in the code
  cell adds a row with a fresh code, counted (30); two stored items sharing a
  code are both untouched and the row is listed with its reason (42); a
  wishlist entry's code in an items file is listed, nothing is added and the
  entry is unchanged (44); a five-item collection and a one-row file leave the
  other four as they were (31); an updated item keeps its photos, its
  `plannedForWishlistItems`, its `sortOrder` and its market figure row, new
  rows append after everything in file order, and a changed Reverb product
  clears that item's market rows and nobody else's (32); Bought filled on every
  row of an export sets each item (33); the sold rules end to end, including a
  new row with a readable pair arriving sold (34). **G22 (criterion 43)**: a
  five-row file over a two-item store — two rows whose codes match, two whose
  codes match nothing, one with no code — stages a summary with `added == 3`
  and `keptCodeAdds == 2`, and the staged confirmation's lines include the
  warning's literal for 2; the same file with every code matching gives 0 and
  no such line; an ID-less file gives 0 and no such line though every row is
  added; a nameless row with an unknown code is skipped and not counted.
  **G23 (criterion 47)**: a one-row file whose code matches nothing is staged
  (`added == 1`); an item carrying that code is then inserted and saved through
  a second context, as iCloud would deliver it; `confirmImport()` returns
  without writing — a third context shows one item with that code, its fields
  as the insert left them — and the presentation is a confirmation again with
  `recounted` true, "Your collection changed while this was open. Check the
  numbers again." as its first line, `updated == 1` and `added == 0`; a second
  `confirmImport()` applies that update, the re-presented confirmation having
  offered Import (`importOffersConfirmation` true); and with the store
  untouched between stage and confirm, the first confirm applies. One more leg
  for the whole-summary comparison, a change that moves no count: a two-row
  file — one row with no code, one whose code a wishlist entry holds (skipped,
  "its Trove ID belongs to the other list") — is staged; the entry is then
  deleted and two items sharing that code inserted, so the same row is skipped
  for Decision 18's reason instead and every count holds; `confirmImport()`
  still writes nothing and re-presents. And
  `rollbackClearsUnsavedInsertsFromTheContext`'s
  shape extended to updates — changes written by `apply` and then rolled back
  leave the stored values on a second context and on a refetch of the same one
  (a failing `save()` cannot be forced in memory, so *that* `confirmImport`
  calls `rollback()` stays with `ImportWiringTests`' existing scan and is
  listed as untested in plan §9 — say so in the Done note) (mutations: **one
  optional assigned unconditionally in `apply` — `item.serialNumber =
  changes.serialNumber` → guard (i) red; run this one first**; two assignments
  crossed (`purchaseLocation` ↔ `saleLocation`) → red; `updatedAt` stamped on
  unchanged rows → the round trip red; `id` assigned after insert, or not at
  all → 28 red; the kept-code clear skipped → red; **G22**: `keptCodeAdds`
  counting every code-carrying row → 4, red; counting every add → 3, and the
  ID-less leg red; counting a skipped kept-code row → red; **G23**: the
  summaries not compared at confirm → the write happens, red; `recounted` left
  false → the first-line assertion red; the re-presented confirmation built
  over the staged summary rather than the new one → `updated == 1` red; the
  re-presented confirmation not offering Import → red; the comparison on counts
  alone → the no-count-moves leg red; the product clear run on every update →
  32 red, and skipped → red;
  `sortOrder` rewritten on update → red).
  Files: `Trove/Import/ImportStore.swift`, `Trove/Export/ExportSchema.swift`
  (`includingPhoto:`), `Trove/ViewModels/ItemListViewModel.swift`,
  `TroveTests/ItemImportStoreTests.swift`, `TroveTests/ItemListViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded verbatim; the Done note gives the criterion each new test carries,
  **43 and 47 by test name**.

- [ ] **T011 — Wishlist: matching and updates through the store and the view model.**
  Per plan §8, spec Decisions 20 and 21 (R4 as first drafted is overturned).
  `WishlistExportRecord.init(item:includingPhoto:)`. `WishlistImportStore.plan`
  and `apply`, T010's shape over `WishlistImportRow` / `WishlistChanges`: the
  matchable set is the entries **still wanted**; `refused` holds every
  `Item.id` ("its Trove ID belongs to the other list") and every **bought**
  entry's `id` ("already bought"); `Added` written to `createdAt`; the kept-code
  market clear; the market clear on a changed Reverb product; no sale rules;
  `keptCodeAdds` counted as T010 counts it (criterion 43).
  `WishlistViewModel.confirmImport()` takes T010's compare-and-re-present
  (Decision 24, criterion 47).
  Pattern: T010; `WishlistViewModelCommitTests.commitRestoresLookingForThroughTheCSV`.
  Tests (**G15**; `WishlistImportStoreTests`, `WishlistViewModelCommitTests`,
  second context). **T010's four store-level guards, mirrored**: one field
  changed on an entry with every optional field filled leaves every other
  stored field; an empty cost, `abc` for `Added` and `N/A` for the notes leave
  all three and count one; a file with no `Notes` or `Year` column leaves both;
  a matched row with an empty Name updates and keeps the name. Criterion 35 —
  the round trip over entries whose `createdAt` is a mid-afternoon instant
  reports every row unchanged and leaves `createdAt` untouched; each of name,
  category, estimated cost, currency, desire, `Added`, notes, Reverb product,
  year and `Looking For` updated; an unmatched code is kept and the second
  import updates; shared codes are not applied; an absent entry is untouched;
  photos, the sell plan's selection and `sortOrder` survive; an item's code in
  a wishlist file is listed and nothing on either list changes (44); **a row
  whose code belongs to a bought entry is listed "already bought", no entry is
  added, and the bought entry's every field — a changed cost in the row
  included — is what it was** (45); **G22 mirrored (43)** — a file with one
  matching code, one unknown code and one row with no code stages
  `keptCodeAdds == 1` with the warning's singular literal among the lines, and
  a row whose code belongs to a bought entry is **not** counted (it is skipped,
  not added); **G23 mirrored (47)** — an entry carrying a staged row's code
  inserted and saved through a second context after staging: `confirmImport()`
  writes nothing, the confirmation is presented again with `recounted` true and
  `updated == 1`, and a second confirm applies it (mutations: **one optional
  assigned unconditionally in `apply` → the one-field leg red**; `createdAt`
  compared by instant → the round trip red; bought ids left out of `refused` →
  the row is added as a second entry with that code → the 45 leg red; a bought
  entry matched and updated → red; `keptCodeAdds` counting skipped rows → the
  bought-entry leg red; the summaries not compared at confirm → the write
  happens, red).
  Files: `Trove/Import/ImportStore.swift`, `Trove/Export/ExportSchema.swift`
  (`includingPhoto:`), `Trove/ViewModels/WishlistViewModel.swift`,
  `TroveTests/WishlistImportStoreTests.swift`, `TroveTests/WishlistViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded; the Done note
  names the wishlist tests carrying 43 and 47.

- [ ] **T012 — The CSV reference, the samples, and their tests.**
  Per plan §10, P13, R2. `docs/csv-reference.md` rewritten as plan §10 lays it
  out, **opening with the hand-kept-sheet loop**, and carrying the rows that
  are left out and why, the missing-column line, and the one-device caveat (a
  backup imported onto a phone still filling from iCloud) **with the
  confirmation's unknown-codes warning explained beside it**: what "a Trove ID
  this iPhone doesn't have yet" means, that it also appears on an ordinary
  restore where you simply go ahead, and that the app cannot tell you when
  iCloud has finished (plan R10). `docs/samples/items-full.csv` and
  `wishlist.csv` rewritten in the layout the app now writes — the starred header row, 20 and 11 columns, BOM,
  CRLF, a fixed invented Trove ID on every row, every other value as it is
  today, at least one note with a line break kept. New
  `docs/samples/items-edited.csv` exactly as plan §10 specifies — **one new row
  carrying an invented code `items-full.csv` does not have among them**, so the
  warning has a sample that counts 1 — to be imported after `items-full.csv`.
  `docs/samples/README.md`: a row for each new file,
  the two rewritten rows, and "import it twice" replaced by what now happens.
  `items-partial.csv`, `items-resaved.csv` and the three `bad-*` files are
  **not** edited.
  Pattern: `020` T013's additions to the same files and to
  `DocsSampleTests.itemsFullImportsCleanly`.
  Tests (**G17**, **G19**; `DocsSampleTests`): `items-full.csv`'s header is
  `ExportSchema.itemHeaderRow` and `wishlist.csv`'s the wishlist row; each
  imported into an empty store adds every row carrying its code **with the
  unknown-codes warning counting every row (12 for `items-full.csv`)**, and
  imported **again** reports every row unchanged **with no warning** (G22's
  sample leg); `items-full.csv` then `items-edited.csv` gives a summary **equal
  to a literal** — its updated, added and unchanged counts, each skip with its
  reason, both unreadable counts, the unused column, the totals row, the
  unused-sale count, the missing `Condition` column, the region's date order
  and `keptCodeAdds == 1` for its one row with an unknown code;
  `items-hand-kept.csv` as the README says **and with no warning — it has no
  codes**; every existing sample claim still green. Criterion 38: the
  existing off-main probe, and one test that plans and applies a generated
  450-row file over a 300-item in-memory collection — 150 rows editing an item,
  150 identical to one, 150 new — **asserting 150 updated, 150 unchanged and
  150 added**, and recording the elapsed time in the Done note without
  asserting on it (mutations: one cell of `items-edited.csv` changed → the
  literal red; a Trove ID blanked in `items-full.csv` → the second-import leg
  and the count of 12 red; the generator's edit dropped → the 150-updated count
  red).
  Files: `docs/csv-reference.md`, `docs/samples/README.md`,
  `docs/samples/items-full.csv`, `docs/samples/wishlist.csv`,
  `docs/samples/items-edited.csv` (new), `TroveTests/DocsSampleTests.swift`,
  `TroveTests/ItemImportStoreTests.swift` (the 300-item test).
  **Verify:** `scripts/verify.sh` green; mutations recorded; the elapsed time
  stated; `cmp` shows the five untouched samples byte-identical to `main`. Then
  `scripts/verify.sh ui` once at the phase end, count recorded.

  **Phase 3 closes here — pause for the person** (walkthrough above; the phase
  review first). The report says, as a statement the person can overturn, in
  plain words: the confirmation is still an alert — and asks whether the
  everything-at-once one was readable (R6). It restates, as already decided by
  them and now built: two items sharing one code both show and neither is
  updated by an import (Decision 18); the warning about Trove IDs this iPhone
  doesn't have appears whenever such rows would be added, a restore included
  (Decision 19); and if the collection changes while the confirmation is open,
  nothing is written and it comes back with new numbers (Decision 24) — which
  cannot be tried by hand, since it needs iCloud to deliver something in those
  seconds, so the report says it is tested, and the device pass will force it
  once to see it on screen. It also says plainly, as overturnable, plan §1's
  remaining limits while two items share a code (the page and Copy act on
  whichever copy the app finds first).
  **It asks for the re-saved file.** If the person would rather not record one,
  that is a question about criterion 20 for them to answer, not a task to skip.

## Phase 4 — Verification and close-out · walkthrough: none — a recorded file pinned by a test, the device pass and the documents; nothing new is built. The two-device steps wait in `specs/SYNC-CHECKS.md`

- [ ] **T013 — The spreadsheet re-save, pinned. [needs the person's file from the Phase 3 pause]**
  Per plan Q1, G18, criterion 20. The orchestrator commits the file the person
  handed back as `docs/samples/items-full-resaved-sheets.csv`, **byte for byte
  as received** — it is a recording, and an edited recording is a guess. The
  implementer then reads it and writes down what Google Sheets actually changed
  (line endings, the BOM, quoting, trailing columns, number and date formats,
  leading zeros, **the line breaks inside the multi-line note**) in a new
  `docs/samples/README.md` row, and pins it. **The recording is Google Sheets
  only. That a Trove ID survives Excel or Numbers is untested**, and the README
  row, the reference doc's caveat and the close-out's record for criterion 20
  each say so in those words.
  Pattern: `DocsSampleTests`' `items-resaved.csv` test.
  Tests (**G18**, `DocsSampleTests`): every Trove ID cell in the recorded file
  parses, and row for row equals `items-full.csv`'s; imported over a store built
  from `items-full.csv`, the summary is a literal that matches the README's
  account — unchanged for every row Sheets left alone, updated for exactly the
  rows it altered, with the altered field named (mutation: one code in a
  scratch copy of the recording altered by a character → red; restore).
  **If a code does not survive, or the file does not import: stop.** That is
  Q1 failing on a fact about Google Sheets, and it goes to a decision review
  with the recorded bytes — it is not patched in the test.
  Files: `docs/samples/items-full-resaved-sheets.csv` (new, the recording),
  `docs/samples/README.md`, `TroveTests/DocsSampleTests.swift`.
  **Verify:** `scripts/verify.sh` green; the Done note lists what Sheets
  changed; `git log` shows the recording committed unmodified before the test.

- [ ] **T014 — Device pass. [general-purpose agents with simulator tools, one per section]**
  Per plan §11, criteria 17, 36, 38. Dispatched as **four separate
  `general-purpose` sections, each given only its own section below** (never
  the whole task line), each returning a short **pass/fail list**. **Any
  failure goes to the `sdd-implementer` as a diagnosis bundle** (the finding,
  the criterion, the plan section, the files) and is logged as a sub-lettered
  task; no section fixes anything itself. Files reach the simulator's Files app
  by being placed in its local file-provider storage; **a section that cannot
  drive the system file picker returns "could not perform" for the checks that
  need it**, and those fall to the person and are named in the close-out — they
  are never reported as passed.
  **(a) The code on a store the shipped build wrote** (persistent store, no
  launch arguments). **`main` is built in a separate git worktree** (`git
  worktree add`), never by switching this checkout, and the section's report
  says which commit it built. Install it, add two items and a wanted entry,
  mark one item sold; install this branch over it; export owned-and-sold as CSV
  and the wishlist as CSV and read the staged files from the app's container —
  every row has a well-formed code and all are different; terminate, relaunch,
  export again — each row has the code it had before (criterion 17). **What
  this can and cannot show**: there is no schema change in this spec, so it is
  not a migration check; it shows that rows the shipped build wrote export a
  code under this one and that the code is read from disk unchanged. It shows
  nothing about a second device (criterion 40).
  **(b) The confirmation, by eye** — iPhone SE (3rd generation) and the pinned
  phone, light and dark: import `docs/samples/items-full.csv`, then
  `docs/samples/items-edited.csv`. Every line readable; nothing truncated; both
  buttons reachable; and the failure alert for `docs/samples/bad-headers.csv`.
  Layout and legibility only — what the lines say is `ImportCopyTests`'.
  **(c) 300 rows** — generate a 300-row items file with a script, import it;
  export the collection, edit one cell in every other row, append 150 rows with
  no Trove ID, import that: the busy badge draws, the list answers a scroll
  while the import runs, and the confirmation reads 150 updated, 150 added, 150
  unchanged (criterion 38).
  **(d) Relaunch** — terminate and relaunch: what (b) and (c) wrote is still
  there.
  **(e) The confirmation coming back (criterion 47, on screen)** *(re-review
  N2, 2026-10-09)* — in the separate worktree, at this branch's head, with one
  **uncommitted** line changed so the first confirm takes the re-present path
  (in `confirmImport()`, the summaries treated as unequal once). Import
  `docs/samples/items-full.csv`, tap Import: the alert returns with "Your
  collection changed while this was open. Check the numbers again." first;
  Import on the returned alert writes the twelve rows; repeat and Cancel writes
  nothing. Once on Items, once on the Wishlist. The report shows the worktree's
  `git status` before and after; nothing is committed. If the alert does not
  return, that is a failure: diagnosis bundle, sub-lettered task. If the
  section cannot drive the file picker, it returns "could not perform".
  The sections run **one after another** on the simulator, never
  together, and the orchestrator passes (a)–(c)'s returned lists into (d)'s
  bundle. **Then the orchestrator — not a section — runs `scripts/verify.sh
  all` twice back to back**, after (e) has returned and released the simulator.
  Not in this pass, because they are deterministic and automated: the screens
  with two items sharing a code (T001b's UI test).
  **[person]** the two new `SYNC-CHECKS.md` steps if two devices are to hand —
  otherwise they wait in that file (criterion 40).
  **Verify:** each section's pass/fail list recorded in the Done note — the
  commit built for (a), the codes before and after, the screenshots' verdicts,
  the 300-row counts — every failure a sub-lettered task, every "could not
  perform" named, and the orchestrator's two `scripts/verify.sh all` runs
  green, both count lines recorded.

- [ ] **T015 — Close-out.**
  Dispatched to the implementer the model policy's close-out row names, on a
  **close-out bundle** the orchestrator assembles with shell: each acceptance
  criterion with the test names or Done notes that satisfied it, the
  walkthrough list below and what the person said at each pause, the tier log,
  the spec's summary and its decided lines, the `ROADMAP.md` entries this spec
  touches, `020`'s `DECISIONS.md` section as the shape to copy, plan §11's two
  drafted `SYNC-CHECKS.md` steps, and the exact lines to be pointed at (below),
  cut with `sed`. **The dispatch forbids full reads of `spec.md`, `plan.md` and
  `tasks.md`.** The close-out: ticks criteria 1–39 and 41–47 in
  `spec.md` with per-criterion citations — **2 from the person's words at the
  Phase 2 pause; 20 only on T013's Done note, with "Google Sheets only — Excel
  and Numbers untested" in its record; 40 an honest partial and unticked** until
  the two-device pass; **43 on T010's and T011's Done notes; 47 is ticked only if T014(e) passed —
  otherwise it is an honest partial and unticked, like 40** — and says plainly what is untested (plan §9's list; anything T014 returned as
  "could not perform"); appends a "Superseded in part by `021`" pointer
  **beside**, never in place of, `specs/011-data-export/plan.md:113`
  (byte-for-byte header), `:132` (no `id` column) and `:150` (boundaries);
  `specs/012-data-import/spec.md:45` (never modifies), `:60` (exact columns)
  and `:94` (rigid template), and its money and date rules under "Parsing
  tolerance"; `specs/012-data-import/plan.md`'s "Row pipeline" and "Money and
  date parsing" sections; `specs/002-live-market-value/plan.md` where it
  introduces the boundary widths (its §7 and Amendment A) and
  `specs/006-mark-as-sold/plan.md` where it grows them (its §7);
  `specs/020-purchase-provenance/plan.md`'s Q7; and
  `specs/011-data-export/spec.md` wherever it states the header match or the
  reason for append-only (the bundle carries a `grep` of it — none was found at
  planning, so "none" is an acceptable answer if the grep says so); adds steps
  3.13 and 3.14 to `specs/SYNC-CHECKS.md` (Part 3 and "Steps per spec");
  updates `README.md`'s import and export bullets; drafts the `ROADMAP.md`
  entry and status row and the `DECISIONS.md` section (the Trove ID is `id`,
  and why; two rows with one code — the trap fixed, the limits left, R2; dates
  compared by day; resolve at stage and again at confirm, and re-confirm on a
  difference, R9 and Decision 24; the boundaries retired; the alert kept or
  replaced, as the person said; R10 — why the unknown-codes warning reads the
  import and not `SyncMonitor`) into a file on the branch, to be
  applied to `main` after the merge; and runs `scripts/verify.sh all`.
  `plan.md` gains **As built** from the same bundle. Only then the pre-merge
  `skeptical-reviewer` sweep over `git diff main...HEAD` (bundle cut after
  `git add -A`), and the PR marked ready.
  Files: `specs/021-import-expansion/spec.md`, `specs/021-import-expansion/plan.md`,
  `specs/011-data-export/plan.md`, `specs/011-data-export/spec.md` (only if the
  grep finds a sentence), `specs/012-data-import/spec.md`,
  `specs/012-data-import/plan.md`, `specs/002-live-market-value/plan.md`,
  `specs/006-mark-as-sold/plan.md`, `specs/020-purchase-provenance/plan.md`
  (pointers), `specs/SYNC-CHECKS.md`, `README.md`, the drafted
  `ROADMAP.md`/`DECISIONS.md` text file.
  **Verify:** `grep -c "Superseded in part by \`021\`"` returns at least 3 for
  `specs/011-data-export/plan.md`, at least 4 for `specs/012-data-import/spec.md`,
  at least 2 for `specs/012-data-import/plan.md`, and at least 1 each for
  `specs/002-live-market-value/plan.md`, `specs/006-mark-as-sold/plan.md` and
  `specs/020-purchase-provenance/plan.md`, and in each of those files the diff
  against `main` adds text only — every shipped sentence still reads as it
  did; `scripts/verify.sh all` green with both count lines recorded here; the
  sweep signed off or its findings resolved.

---

## Walkthrough list (for the close-out)

| Phase | Paused? | What to try |
|---|---|---|
| Phase 1 | no — `walkthrough: none` | nothing observable; tests over the existing identifier, a crash removed from a state no phone is in yet, and pure functions nothing calls yet |
| Phase 2 | yes | the person's own sheet imports as it is (criterion 2); columns in any order, an extra column named, a missing optional column said once, a missing required column refused; older exports still import; both lists |
| Phase 3 | yes | the starred header and the Trove ID in every export and template; export → edit in Google Sheets → import updates, adds and leaves unchanged; an empty cell changes nothing; sold status stays in the app; other-list and already-bought rows left out; the warning that 12 rows have a Trove ID this iPhone doesn't have yet on `items-full.csv`'s first import, and none on its second; the everything-at-once confirmation as an alert; the reference doc; **the person records the re-saved file** |
| Phase 4 | no — `walkthrough: none` | the recorded file's test, the device pass, the documents; the two-device steps wait in `SYNC-CHECKS.md` |

## Handoff note

Involvement level: **product owner** (`CLAUDE.md`). Model policy: as
`CLAUDE.md`'s role table resolves it — no dispatch carries a model override, the
session runs at the session tier at medium effort; the plan-and-tasks draft ran
at the implementation tier under the trial continuing from `018`. Foundational
phase: **Phase 1**; `review: per-task`: **T004**, **T009** and **T010**. Pause
cadence: after each phase marked `walkthrough: yes` (Phases 2 and 3) once its
review is signed off; Phases 1 and 4 run on after their review, their reasons
added to the walkthrough list. Pause also whenever something unexpected bears on
spec adherence — and **T001 and T013 each name a stop of their own**: a failed
claim about the identifier, and a code that does not survive the spreadsheet.
No product question is open: criteria 43 and 47 are owned by T006 (the words),
T010 and T011.

> Read `CLAUDE.md` and `specs/021-import-expansion/{spec,plan,tasks}.md`.
> Confirm the branch is `021-import-expansion` and run `scripts/verify.sh`.
> Begin at the first unchecked task. Involvement is product owner. Dispatch each
> task to the implementer the role table names, on a task bundle; verify with
> `scripts/verify.sh`, then commit. One review and at most one re-review per
> invocation. The `skeptical-reviewer` reviews after each phase with a phase
> bundle, and T004, T009 and T010 get their own reviews as well. Pause for me
> after Phases 2 and 3; run straight on after Phases 1 and 4's reviews. At the
> Phase 3 pause, ask me for the re-saved sample file — T013 cannot start without
> it.

Every pause report is plain language, in this order: why this pause; what can
now be tried; where execution deviated from the spec and why; what needs a
decision (product questions only). A phase pause never ends with a continuation
prompt. What the person reports from a walkthrough is a finding against a
criterion — restated, diagnosed by the implementer, and logged as a sub-lettered
task under the task it corrects.

## Tier log

`CLAUDE.md`'s model policy: every role at the tier its role-table row names, no
override; the session at the session tier, medium effort. Each row's Tier is
the resolved model name. Token usage from each subagent return is filled in as
the spec runs, with escape-hatch misses recorded here too.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| Plan and tasks draft (`sdd-planner`) | `opus` | 335,316 (64 tool uses, 20.9 min) | Plan-and-tasks draft at the implementation tier, no override (trial continuing from `018`). 15 tasks, 4 phases, 19 guards |
| Sign-off (`skeptical-reviewer`) | `opus` | 196,844 (43 tool uses, 9.1 min) | Sign off after fixes: 3 blocking (B1 two items sharing an `id` trap `MarketSummary.summaries`; B2 the store-level update writer under-guarded; B3 the criterion-1 fixture header specified nowhere), 16 second-look notes, 7 product questions |
| Sign-off fixes (`sdd-planner`, resumed) | `opus` | 439,317 as returned (26 tool uses, 10.8 min) | All three blocking and the second-look notes applied; the person's answers transcribed by the orchestrator into `spec.md` (Decisions 17–23). **Stopped on a product question**: Decision 19 as first worded cannot be built — `SyncMonitor` reads caught-up after the first import pass |
| Sign-off fixes, second pass (`sdd-planner`, resumed) | `opus` | 65,322 as returned (68 tool uses, 5.8 min) | Decision 19 reworded by the person (warn on kept-code adds; R10, G22) and Decision 24 (re-confirm; R9, G23) applied. 17 tasks, 4 phases, 23 guards |
| Sign-off re-review (`skeptical-reviewer`) | `opus` | 167,777 (19 tool uses, 6.2 min) | B1–B3 fixed; criteria 41–47 all owned. **2 new blocking, both from the fix round**: N1 delete removed "the first" twin, not the one acted on (contradicts spec, Sync); N2 criterion 47's on-screen half declared untriggerable and then ticked. Review-loop cap reached |
| N1 and N2 (orchestrator, direct) | session | — | Fixed by the orchestrator in `plan.md` and `tasks.md` per the cap, with the reviewer's literal edits: delete resolves the row acted on (T001a, T001b, G20, plan §1); T014 gains section (e) forcing the re-present path once on the device, and 47 is ticked only if it passes (plan §9, §11, T015). Not re-reviewed — for T001a's phase review and the sweep |
| T001 (`sdd-implementer`) | `opus` | 86,026 (32 tool uses, 33.8 min) | Done first pass; all G1 legs held; two extra mutations added |
| T001a (`sdd-implementer`) | `opus` | 86,739 (26 tool uses, 42.0 min) | Done first pass; one existing scan re-pointed to the new signature; one non-trapping limit found (Sell Plan toggle moves both twins) |
| T001b (`sdd-implementer`) | `opus` | 124,722 (48 tool uses, 66.5 min) | Done; routine `ForEach` fix needed at three sites; Plans rows question returned for a decision review |
| Decision review after T001b (`skeptical-reviewer`) | `opus` | ~39,951 (3 tool uses, 1.2 min) | Plans rows: fix drawing **and** the entry lookup (else a wrong-target delete/purchase) — plan change, T001c; sold-row sites: routine fix with a UI leg each; no product question |

**Open after the re-review — non-blocking, for the phase reviews and the
pre-merge sweep** (the reviewer's notes, not applied at sign-off):

- T010 guards (ii) and (iii) may never reach `apply`: a matched row with only
  an empty price, an unreadable date and an `N/A` serial is "unchanged". Give
  each row one real change (notes) and assert `updated == 1`; same in T011.
  **The T010 dispatch carries this.**
- T011 has no leg for two wanted entries sharing a code (criterion 42's import
  half is tested for items only). **The T011 dispatch carries this.**
- G22's last "Red when" entry ("read from `SyncMonitor`") is not a mutation;
  it is prose.
- R6's worst-case alert has grown: the unknown-codes warning alone is three
  lines, and `items-edited.csv` cannot produce the recounted line, so T014(b)
  shows one line short of the worst case; (e) shows the other.
- The three wishlist missing-column sentences say "new items" — check the
  wording at the Phase 2 pause.
- `includingPhoto: false` "reads no photo" is untested; one leg pins it.
- G23's no-count-moves leg leans on a cross-context delete; if flaky,
  restructure the leg, don't weaken it.
- T001b runs the UI suite mid-phase: nothing else may hold the simulator.
- `ImportMatching` precedence: with `refused` before `ambiguousInStore`, a
  wanted-plus-bought twin pair reads "already bought" — worth one sentence in
  plan §7.

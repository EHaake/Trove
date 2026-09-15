# 006 — Mark as Sold: Tasks

**Status**: **Signed off** (2026-09-13) — skeptical-reviewer at `fable` (experiment
1's top tier); one blocking finding at the first review (B1, the Sold side's
CSV export inheriting the Owned side's narrowing — fixed as Q15/G33) and
eleven second-look notes, all folded in; the re-review signed off with
nothing open. Ready for implementation once the person approves the
spec-conformance summary.

Drafted against the approved `spec.md` (Approved 2026-09-13) and the draft
`plan.md` in this directory, for branch `006-mark-as-sold` off `main`
(`465e733`). No new technical decisions are made here — every call below
traces to a plan section; where a task says "per plan," that section is the
authority. Runs under **experiment 1**: the planner and the sign-off at
`fable`, the `skeptical-reviewer` on phase and marked-task reviews and the
`sdd-implementer` at `opus`, the session at `fable` medium; the tier log
records what actually ran.

**Foundational phases**: **Phase 1** (T001–T005) — the schema change, the one
writer, the copy, the sale form's logic and the router request that every
screen builds on; and **Phase 2** (T006–T007) — the CSV contract, which
import, both exports and the docs inherit. **Tasks marked `review:
per-task`**: **T001** (the `Item` schema change — every reader inherits the
sold predicate and the relationship), **T003** (`ItemSaleStore` — the one
writer every entry point, the Sell Plan and the market exclusion depend on)
and **T006** (the append-only CSV schema and the import pair rule — a mistake
here corrupts files the person keeps). Every other task gets the default one
review per phase. An orchestrator left to guess guesses "all of them" — these
three are the ones marked.

Ordering note, recorded up front: the schema lands first and is proven
CloudKit-compatible before any code reads the new fields; the writer, the
copy, the form logic and the router follow bottom-up, then the CSV contract —
data-layer only, so import round-trips a sale before a single screen shows
one. Nothing user-visible lands until the Design pass (T008) has approved
visuals for the six new surfaces. View models come before the views that read
them (Phase 4 before Phase 5); the shared sale sheet (T013) lands before the
two screens that host it; the seed and UI tests close the screens phase.
Tasks marked **[person]** block on something only the person has.

House rules carried over: one commit per completed task, referencing the task
ID; every guard test is **mutation-verified** (break the rule deliberately,
confirm red) before it lands, and the Done note records what was broken and
what went red; a task is not done until `scripts/verify.sh` is green and its
actual output is reported (suite-level `-only-testing`, test count checked —
per-function selectors run zero tests and report success); persisted-state
assertions refetch on a **second `ModelContext`**; **every new source scan
asserts its anchor was found** before asserting anything about it —
`#require` on the anchor's count for a brace-span scan, `#expect(!literals.isEmpty, …)`
for a literal scan, the `SellPlanFramingTests` shape — so no scan can pass
over a file that lacks the thing it guards. Every new file lands
through the synchronized root groups — **no `.pbxproj` edit** anywhere in
this spec; if one is ever needed, stop and flag. **No test opens a network
connection** (nothing here needs one).

Cadence (per `CLAUDE.md`'s model policy, as amended for experiment 1): each
dispatch gets a **task bundle** assembled with shell — task line, plan
section, acceptance criteria, files, pattern file — and the implementer is
told not to read `plan.md`/`spec.md`/`tasks.md` in full; verification is
`scripts/verify.sh` and nothing more verbose, re-run by the orchestrator for
the three `review: per-task` tasks and taken from the implementer's verbatim
output otherwise; the `skeptical-reviewer` reviews per phase (and the three
marked tasks), one review and at most one re-review each, on a bundle cut
after `git add -A`; **one implementation session for the whole spec** — a
phase pause is a pause in it, the person attests and says continue, and only
a session-ending pause gets a continuation prompt; the device pass runs in a
`general-purpose` agent at the implementation tier (the `sdd-implementer` has
no simulator tools). Everything the person reads is plain language.

Handoff notes for the pause reports, so the orchestrator doesn't have to
rediscover them: **Phases 1 and 2 have nothing to try** — the report may say
so and offer to run straight through to the Design pass; if the person does
try the Phase 2 export, the report must say **leave the four new columns
blank on re-import**, since import can create a sold item from a filled row
but nothing shows or undoes a sale until Phase 5. **The Phase 5 report says
that a Sold card inside a category lands on the whole Sold side** (plan R1),
because the person will feel it before they read it.

## Phase 1 — Foundations, no UI (**foundational**)

- [x] **T001 — The sale on `Item`: four fields, the relationship, `Sale`. `review: per-task`.**
  Per plan §1 and Q1–Q2. Add `soldDate`, `salePriceCents`, `saleLocation`,
  `saleNote` and `soldTowardWishlistItem` to `Item` (after `year`, every one
  optional; the relationship `.nullify` with `inverse:` on the `Item` side)
  and `itemsSoldToward: [Item]? = []` to `WishlistItem`; new
  `Trove/Models/Sale.swift` with `Sale`, `SaleOutcome` (`deltaCents`,
  `isLoss` — the colour rule lives here, on the model), `SaleTotals`,
  `SaleOutcome.totals(over:)` (the one sum the list, the dashboard and the
  seed's expectations read), `Item.isSold`, `Item.sale` (get/set; set nil
  clears the four and the link), `Item.saleOutcome`.
  Pattern: `Photo`'s 005 fields and `Item.plannedForWishlistItems`. Tests:
  `ModelTests` (an owned item's `sale` is nil; a built sale round-trips all
  four through a second context; `sale = nil` clears the link — G2; the
  date-without-price branch reads price 0, recorded as defensive);
  `WishlistDeletionTests` (deleting the wanted item leaves the sale, link nil
  — G3); new `SaleOutcomeTests` (`isLoss` at −1, 0, +1; `totals` over a gain,
  a loss, an at-cost sale and an owned item → count 3, the summed proceeds,
  the summed delta — mutation: count the owned item, or sum proceeds as
  delta → red; the half of G32 that lives here). **CloudKit red run**:
  `soldDate` declared non-optional without a default → `CloudKitSchemaTests`
  names it → revert (G1).
  Files: `Trove/Models/Item.swift`, `WishlistItem.swift`, `Sale.swift` (new),
  `TroveTests/ModelTests.swift`, `WishlistDeletionTests.swift`,
  `SaleOutcomeTests.swift` (new).
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); the red run and
  the G2/G3/G32 mutations recorded in the Done note.
  **Done (2026-09-13):** six files, no `.pbxproj` edit. Mutations, each
  reverted and red: G2 (setter leaving the link → `ModelTests` 367/370), G3
  (`itemsSoldToward` `.nullify` → `.cascade` → `WishlistDeletionTests:139`),
  G32 (count the owned item → `SaleOutcomeTests` 59/71; sum proceeds as
  delta → line 61), plus `isLoss` `<` → `<=` → line 25. **CloudKit red run**:
  `soldDate` non-optional without a default → `CloudKitSchemaTests` names
  `Item: soldDate` ("CloudKit integration requires that all attributes be
  optional, or have a default value set"). Trap recorded: the first attempt
  crashed the test *host* migrating the simulator's real store (a migration
  error naming the same field, not the guard) — the store had to be moved
  aside to see the guard fire, then was restored, and the final green run
  migrated that pre-006 store under the five new fields. Verify (orchestrator
  re-run): 1332 tests in 187 suites passed. Per-task review signed off,
  nothing blocking; notes carried: S1 "set a sale leaves the link alone" is
  untested here (T003's G21 covers it through `editSale`); S2 the Item-side
  delete rule is asserted by comment only (sweep); S3 the device pass should
  confirm an existing collection opens (T019); S4 G32's scan half lands at
  T009/T010.

- [x] **T002 — `SaleCopy`, and the sold delete message.**
  Per plan Q11 and §5 (`ItemDeleteCopy`). New `Trove/Models/SaleCopy.swift`
  (`nonisolated enum`): every string in the spec's Copy section — the action
  labels (`markAsSold`, `editSale`, `returnToCollection`), the sheet titles
  and buttons by mode, field labels and the "Sold at" placeholder, the
  return alert's title/message/buttons, the switch's two words, the empty
  state, the card header, the Sell Plan headers — and the composed lines:
  `dashboardSummary(_ totals: SaleTotals)`, `realised(deltaCents:)`,
  `soldSideSummary(_ totals: SaleTotals)`, `rowOutcome(deltaCents:)`,
  `pageOutcome(deltaCents:)`, `saleLine(_ sale: Sale)` (place omitted when
  nil; date `.abbreviated`). Strings only — it is a `Trove/Models/` file, so
  no `import SwiftUI` and no colour; the moss/rust choice is
  `SaleOutcome.isLoss` mapped by each view (plan Q11). `ItemDeleteCopy.message` → `message(isSold:)`
  (owned = today's string verbatim; sold omits the sell-plan sentence, P13);
  the two call sites updated mechanically. Pattern: `StockPhotoCopy` and
  `StockPhotoCopyTests` (every string pinned whole). Tests: `SaleCopyTests`
  (each composed line at a gain, a loss and zero — "Gain $350", "Loss $150",
  "Sold at cost", "+$0 vs paid"; the sale line with and without a place —
  the two outcome strings are placeholders T008 may reshape, plan Q11);
  `ItemDeleteCopyTests` gains the sold case (G17; mutation: reuse the owned
  message → red). `DeletionGuardTests`' two item scans stay green on the
  `ItemDeleteCopy.message(isSold:` call.
  Files: `Trove/Models/SaleCopy.swift` (new), `ItemDeleteCopy.swift`,
  `Trove/Views/Items/ItemListView.swift` + `ItemDetailView.swift` (call sites
  only), `TroveTests/SaleCopyTests.swift` (new), `ItemDeleteCopyTests.swift`.
  **Verify:** `scripts/verify.sh` green; the G17 mutation recorded.
  **Done (2026-09-13):** `SaleCopy` (Foundation only) with every fixed
  string and the six composed lines, plus `sellPlanSoldCaption(count:)`
  (the "2 items" caption can't be a constant), `separator` and `atCost`
  shared by both outcome lines; `saleLine` also omits an empty place.
  `ItemDeleteCopy.message(isSold:)` had three readers, not two —
  `DeleteAllCopyTests` pins the owned message word for word and was updated
  mechanically. G17 mutation (sold branch returning the owned message) →
  `ItemDeleteCopyTests` 44/45 red, reverted. The `WishlistDeletionTests`
  scan on `ItemDeleteCopy.message` stayed green on the new spelling. Verify
  (implementer's verbatim output): 1348 tests in 188 suites passed. Bundle
  correction for later dispatches: the currency formatters live in
  `Trove/Extensions/Int+Currency.swift`, not `Money.swift`.

- [x] **T002a — Phase 1 review fix (B1): the Sold side's empty state split
  as plan §4 says.** `SaleCopy.emptyState` → `nothingSoldHeadline` /
  `nothingSoldDetail`, both pinned; T005's placeholder passes both; plan
  §5's `sheetTitle(mode:)` comment corrected to the shipped constants; the
  S4 comment word (T003 → T004). S1 folded: a test pins `rowOutcome` /
  `pageOutcome`'s word against `SaleOutcome.isLoss` at −1/0/+1 — the
  mutation had to shift to `<= 1`, since `<= 0` is equivalent behind the
  `!= 0` guard (record: a `< 0` → `<= 0` mutation on those two functions is
  a false green). Red at `SaleCopyTests:134`, reverted. Verify (implementer's
  verbatim output): 1379 tests in 191 suites passed. Re-review: signed off.
  Carried to the sweep: S3 (the delete-message wiring passes the item's own
  `isSold` — no scan), S5 (`dashboardSummary` duplicates the
  `sellPlanSoldCaption` pluralisation; `separator` claims to match
  `MarketCopy` untested), S6 (`acceptsADateYearsBeforeThePurchase` guards
  only against a lower bound being added).

- [x] **T003 — `ItemSaleStore`, and the refresher's exclusion. `review: per-task`.**
  Per plan §2 and Q3, Q8, Q13. New `Trove/Models/ItemSaleStore.swift` with
  `markSold(_:sale:toward:at:in:)` (sets `sale`, sets the link iff a plan is
  passed, empties `plannedForWishlistItems`, `MarketLocalStore.clear`,
  `updatedAt`; never touches `sortOrder` or the match), `editSale(_:sale:at:)`,
  `returnToCollection(_:at:)`. `MarketRefresher.targets(in:)` adds
  `soldDate == nil` to the owned predicate. Pattern: `MarketLocalStore`
  (callers save). New `ItemSaleStoreTests`, second-context throughout: G4
  (selection dropped, the wanted item survives — mutation: drop the
  emptying), G5 (this item's market rows gone, another's kept — mutation:
  drop the clear), G6 (link only with a plan), G7 (mark then return leaves
  `sortOrder` equal and the item in its Custom slot among three others —
  mutation: reset `sortOrder` on return), G9 (date and price always written
  together), G20 (name, category, paid, value, desire, condition, photos,
  notes and `reverbProductID` unchanged across mark — mutation: clear the
  match), G21 (edit keeps the link); `MarketRefresherTests` gains G8 (a sold
  matched item is not a target; `SettingsViewModelTests`' `matchedCount`
  follows — mutation: drop the clause).
  Files: `Trove/Models/ItemSaleStore.swift` (new), `Trove/Market/MarketRefresher.swift`,
  `TroveTests/ItemSaleStoreTests.swift` (new), `MarketRefresherTests.swift`,
  `SettingsViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded.
  **Done (2026-09-13):** `ItemSaleStore` in the `MarketLocalStore` shape
  (callers save); `markSold` runs the throwing market clear first so a
  failure leaves the item unwritten. Mutations, each red then reverted: G4
  (drop the emptying → `ItemSaleStoreTests:67`), G5 (drop the clear → :92),
  G6 (ignore `toward:` → :118), G7 (return resets `sortOrder` → :287, the
  Custom slot order wrong), G8 (drop the clause → `MarketRefresherTests:219`
  and `SettingsViewModelTests:979`, count 4 ≠ 3), G9 (date alone → :200),
  G20 (clear the match → :173), G21 (edit nils the link → :226), the
  T001-review setter test (value branch clearing the link → :248), Q13
  (drop the bump on return → :311). Verify (orchestrator re-run): 1358
  tests in 189 suites passed. Per-task review signed off, nothing blocking;
  notes carried: S1 the link assignment is unconditional (no reachable
  caller marks an already-linked item; a docstring word, sweep); S2/S3 the
  G7 and G9 tests lean on `ModelTests` for "all five cleared" and the pair
  round trip; S4 the reviewer's "criterion 11's second half has no guard"
  is already T001's G3 (`WishlistDeletionTests:123`); S5 `MarketLocalStore
  .clear`'s partial-throw window is pre-existing and unreachable.

- [x] **T004 — `SaleFormViewModel`.**
  Per plan §5 and Q12. New `Trove/ViewModels/SaleFormViewModel.swift`
  (`@Observable`, no SwiftUI): `Mode`, `price: Decimal?`, `date`, `location`,
  `note`, `validationErrors`, `title`/`confirmLabel` from `SaleCopy`,
  `latestDate`, `init(mode:prefill:currentValueCents:now:)`, `sale() -> Sale?`
  (`Money.cents(from:)`; blanks nil'd through `FieldNormalization`). Pattern:
  `ItemFormViewModel` (the price rules, `validate()`, `populate`). New
  `SaleFormViewModelTests`: G18 (blank → `.priceMissing`; negative →
  `.priceNegative`; zero accepted; `now + 1 s` → `.dateInFuture`; a date years
  before "purchase" accepted — mutation: `<` for `<=` in the date check, and
  the check dropped, both red), G19 (`.mark` prefills the current value and
  today; blank price without a value; `.edit` prefills every field of the
  sale — mutation: seed the price from the sale in `.mark` → red); `sale()`
  trims and nils blank location/note.
  Files: `Trove/ViewModels/SaleFormViewModel.swift` (new),
  `TroveTests/SaleFormViewModelTests.swift` (new).
  **Verify:** `scripts/verify.sh` green; mutations recorded.
  **Done (2026-09-13):** `SaleFormViewModel` (no SwiftUI), 16 tests in two
  suites. `title`/`confirmLabel` switch on `mode` over `SaleCopy`'s four
  constants — the plan's `sheetTitle(mode:)` spelling is not what T002
  shipped, by that file's own design (a string table, no view-model type).
  `.edit` with a nil prefill (unreachable from the app) falls back to the
  `.mark` seed, documented. Mutations, each red then reverted: `<` for `<=`
  → `SaleFormViewModelTests:73` (exactly-now refused); the date check
  dropped → :62/63; the `.mark` seed reading the sale → :156. Verify
  (implementer's verbatim output): 1374 tests in 191 suites passed.

- [x] **T005 — The router's sold request, and the Sold side's empty reason.**
  Per plan §4 and Q4, Q9. `AppRouter.ItemsRequest.sold`, `showSoldItems()`
  (request + `popToItemsRoot()`); `ListEmptyReason.nothingSold`. Pattern:
  `showItems(inCategory:)`, `ListEmptyReason.everythingIsValued`. Tests:
  `AppRouterTests` (`showSoldItems` sets `.sold`, selects Items, empties the
  path; `clearItemsRequest` clears it; `showItem` clears a pending `.sold`);
  `ListEmptyReasonTests` (an empty owned list with no narrowing still reads
  `.nothingAdded` from `reason(...)`, not `.nothingSold` — the Sold side's
  case is chosen by `ItemListViewModel.emptyReason` alone, T009).
  Files: `Trove/ViewModels/AppRouter.swift`, `Trove/Models/ListEmptyReason.swift`,
  `TroveTests/AppRouterTests.swift`, `ListEmptyReasonTests.swift`.
  **Verify:** `scripts/verify.sh` green. **Phase 1 closes here — pause for
  the person** (nothing to try yet; the pause is the review gate).
  **Done (2026-09-13):** `.sold` + `showSoldItems()`, `.nothingSold`; four
  tests, each mutation-checked (wrong request / no pop, `showItem` not
  clearing, `clearItemsRequest` a no-op, `reason` returning `.nothingSold`
  → each red). Two exhaustive switches in `ItemListView` and one in
  `WishlistView` gained placeholder cases to compile (unreachable today,
  each commented with the owning task T009/T015 — **T015's bundle must
  name both files** so the placeholders don't survive the spec). Bundle
  note for T015: plan §4 names `SaleCopy.nothingSoldHeadline`/`Detail`,
  but T002 shipped one `SaleCopy.emptyState` string — T015 maps or splits
  it, settled in its bundle. Verify (implementer's verbatim output): 1378
  tests in 191 suites passed.

## Phase 2 — The CSV contract and import (**foundational**)

- [x] **T006 — Four appended columns, the boundary, the pair rule, the commit. `review: per-task`.**
  Per plan §7 and Q5 (records/Settings split), Q6/R3. `ItemExportRecord`
  gains the four sale fields (from `item.sale` in `init(item:)`);
  `ExportSchema.itemHeaders` += `Sold Date`, `Sale Price`, `Sold At`, `Sale
  Note`; `itemSchemaBoundaries = [12, 14]`; `row(from:)` writes the four
  (blank when nil). `ImportSchema.itemsPreview`: the four columns, the pair
  rule, one counted default per dropped sale. `ItemListViewModel.confirmImport`
  sets `item.sale` when the record carries the pair (no plan).
  `SettingsViewModel.everythingInCustomOrder` → `(owned, sold, wanted)`;
  `exportEverythingAsCSV` writes owned then sold in Sold-side order
  (`ItemListViewModel.areInSoldOrder`, added here as a static beside
  `documentTitle`); `exportEverythingAsPDF` uses owned only. Pattern: 002's
  T016a (`Reverb Product ID`/`Year` — the last append) and its tests. Tests:
  `ExportSchemaTests` G24 (headers and `[12, 14]` by literal), G25 (owned
  blank, sold filled — mutation: write the price for owned); `ImportSchemaTests`
  G26 (18/14/12 accepted, 13 and 17 refused — mutation: accept any prefix),
  G27 (five cases, counts 0/1/1/0/1, plus a date-unreadable-with-price row
  counting 1 — mutation: count per cell → 2 → red; and a lone half accepted
  → the unsold assertion red; plus plan Q6's two stated edges: a **negative**
  `Sale Price` with a date → unsold, counted 1; a **future** `Sold Date` with
  a price → sold as written), a sold row round-trips to `Item.sale`;
  `ImportServiceTests`/`ItemListViewModelTests`: the commit sets the sale and
  no link; `SettingsViewModelTests` G28 (Settings CSV bytes == the unfiltered
  Custom list CSV with a sale present — the list half arrives at T009, so
  this half pins Settings' own order now and the equality test is completed
  at T009) and G16 (the everything-PDF's `itemCount`/totals exclude the sold
  item — mutation: pass all items → red).
  Files: `Trove/Export/ExportSchema.swift`, `Trove/Import/ImportSchema.swift`,
  `Trove/ViewModels/ItemListViewModel.swift` (`confirmImport` + the static
  comparator only), `Trove/ViewModels/SettingsViewModel.swift`,
  `TroveTests/ExportSchemaTests.swift`, `ImportSchemaTests.swift`,
  `ImportServiceTests.swift`, `SettingsViewModelTests.swift`,
  `ItemListViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded.
  **Done (2026-09-13):** four fields on `ItemExportRecord` (no defaults, the
  002 shape — twelve memberwise sites across six test files, including
  `PDFComposerTests`, outside the file list, mechanical); headers, `[12,
  14]`, blank-when-nil cells in the existing day/money formats; the pair
  rule with one default per dropped sale; `areInSoldOrder` (date desc, name
  case-insensitive, id; no sale last); the commit sets `sale`, no plan;
  Settings `(owned, sold, wanted)`. Mutations, each red then reverted:
  `[12, 13, 14]` → `ExportSchemaTests:56` + `ImportSchemaTests:711`; price
  written for owned → `ExportSchemaTests:221` + `SettingsViewModelTests:418`;
  any prefix accepted → `ImportSchemaTests:711/141`; one default per cell →
  :767 (2 ≠ 1) + :822; a lone half accepted → :768/805; the commit dropping
  `sale` → `ItemListViewModelTests:1447`; sold in Custom order →
  `SettingsViewModelTests:413`; PDF given owned + sold → :445/448; and, on
  the review's S1, the record reading `soldDate` alone →
  `ExportSchemaTests:436–438`, the commit setting a plan link →
  `ItemListViewModelTests:1451`. Verify (orchestrator re-run): 1391 tests in
  191 suites passed. Per-task review signed off, nothing blocking; carried:
  S2 two import assertions use `day(from:)` as their own oracle (rescued by
  the count assertion; sweep); S3 Settings' PDF is reachable with zero
  entries for an all-sold collection while the list's is gated (T009
  confirms deliberate); S4 G28's byte identity completes at T009; **S5 the
  sale date is day-granular on a round trip, like Purchase Date — the sheet
  task (T013) must be told, since a `Date.now` sale shifts to midnight on
  re-import and same-day sales then tie only by name**; S6 a stale blanket
  sentence in `everythingInCustomOrder`'s comment (sweep). G28's list half
  waits for T009.

- [x] **T007 — Docs, samples, the 011 schema section, `PRIVACY.md`.**
  Per plan §7 (docs) and §9. `docs/csv-reference.md` (18 columns, four new
  table rows, the legacy widths 12 and 14, the pair rule in "Field formats");
  `docs/samples/items-full.csv` gains the four columns with two rows sold
  (one gain, one loss) and `docs/samples/README.md` says which;
  `items-partial.csv` untouched at 12; `items-resaved.csv` **left at 14
  deliberately** and named in the README as the 14-boundary fixture;
  `specs/011-data-export/plan.md` §"The canonical CSV schema": the italic
  note under the heading names 006's columns, and one bullet appended to
  "Recorded schema decisions" (columns, pair rule, `[12, 14]`, and the one
  line that sold rows follow owned rows so a returned item lands at the end
  of Custom order after a round trip — inherent to "no `sortOrder` column",
  outside this spec) — nothing above it edited. `PRIVACY.md`'s first storage row gains the sale details
  (P9); README's feature list gains one sentence. Pattern: 002's T016a docs
  commit. Tests: `DocsSampleTests` G30 (`items-full.csv`: the two sold rows'
  `sale` fields and every other row unsold, `defaultedFieldCount == 0`;
  `items-resaved.csv` header width 14 == `itemHeaders.prefix(14)`, every row
  unsold, the 12-column pin unchanged — mutation: regenerate the resaved file
  at 18 → red); `PrivacyPolicyTests` G31 (mutation: remove the phrase → red).
  Files: the docs above, `PRIVACY.md`, `README.md`,
  `TroveTests/DocsSampleTests.swift`, `PrivacyPolicyTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded. **Phase 2 closes
  here — pause for the person** (what can be tried: export a CSV from the
  Items tab and re-import it — the four new columns are present and blank).
  **Done (2026-09-13):** csv-reference at 18 columns with a `‡` footnote for
  the sale set and the pair rule under "Field formats"; `items-full.csv` at
  18 with the Technics (gain) and HD 650 (loss) rows sold, in place rather
  than moved after the owned rows (a hand-built import fixture; export
  order is not asked for); README of the samples names the 14-boundary
  fixture; the 011 plan's italic note and one bullet appended at the end
  of the decisions list; `PRIVACY.md`'s first storage row; README's one
  sentence as its own bullet, worded from the commit log since the bundle
  carried no user-facing description. Mutations, each red then reverted:
  `items-resaved.csv` regenerated at 18 → `DocsSampleTests:129/130`; the
  privacy phrase removed → `PrivacyPolicyTests:174`, plus the Technics
  price blanked → `DocsSampleTests:18/56/72`. Note: the re-saved sample's
  header carries trailing empty cells, so its width pin goes through
  `ImportSchema.shaped` (a raw header reads 17). Verify (implementer's
  verbatim output): 1392 tests in 191 suites passed.

- [x] **T007a — Phase 2 review fix (B1): the README clause.** README's new
  bullet had promised a one-tap return; the spec's Return to collection
  asks first, so it now says the item is returned after a confirmation
  with its sale details removed. Folded from the same review: S1 a
  zero-price row imports as a $0 sale (mutation `parsedPrice > 0` in the
  pair rule → `ImportSchemaTests:784–786` red, reverted); S3 the
  csv-reference rows for Sold At / Sale Note point at the ‡ pair rule.
  Verify (implementer's verbatim output): 1393 tests in 191 suites passed.
  Re-review: signed off. Carried: S2 nothing in the suite reads
  `csv-reference.md` (a containment check on the column count and
  boundaries would close it; sweep); S4 the 011 plan's italic pointer names
  the old boundaries entry — name both at close-out (T020); S5 no sample
  shows owned-then-sold write order (G28's list half at T009); **S6
  README's Export bullet drifts at T009** ("filters and sort respected",
  no sale columns) — T009's bundle names it; **S7 the person's attestation
  at this pause covers criteria 12, 13 and the Settings half of 14, not
  7a** (T009); S8 the import date expectations use `day(from:)` as their
  own oracle, rescued by neighbours (sweep).

## Phase 3 — Design

- [x] **T008 — The Design pass. [person: invokes `/design`, approves]**
  Per spec's Design requirements (the `002`/`005` pattern). Claude Code writes
  the `/design` brief: the six surfaces — the **Owned / Sold switch** at the
  top of the Items page (bespoke, in the Sort By family; "two sides of the
  same view"; a flip or turn is fair to try, not a mandate), the **Sold card**
  on the Dashboard (apart from the totals, a separate ledger, never a fourth
  headline figure), the **Sold side's row and summary line**, the **sold
  state** of the item detail (the Sold mark and sale line over the familiar
  page, read-only), the **Sell Plan's third figure and Sold section**, and
  the **sale sheet** in the item form's field style — every string from
  `SaleCopy`, `design/brief.md`'s rules, `001`'s fixed type sizes, the
  moss/rust cue for gain/loss (never a new colour), the existing screen PNGs
  for context. One thing the pass must settle explicitly (spec Decision 10):
  the **form of a row's and the page's outcome** — the placeholder words
  "Gain $350" / "Loss $150" / "Sold at cost", a labelled signed figure, or a
  mark — with the rule that the gain or loss and its amount are unmistakable
  and colour alone never carries it. Replacing the placeholder strings is
  inside the spec, not new copy. The person runs it, iterates, drops the `.dc.html` artboards
  and PNGs under `design/elements/006-mark-as-sold/`, and `design/tokens.md`
  gains a "Mark as sold (`006`)" section with "as implemented" cells for the
  screen tasks. **If the pass proposes new copy, that is a spec question —
  escalate, don't absorb.**
  **Verify:** artboards and PNGs committed; the tokens section written; the
  person's approval recorded in the Done note. **Phase 3 closes here.**
  **Done (2026-09-13):** the brief written by the session
  (`design/elements/006-mark-as-sold/brief.md`); the person ran `/design`;
  twelve artboards + PNGs, `canvas.json` and `design-notes.md` committed;
  `design/tokens.md` gains "Mark as sold (`006`)" transcribed from the
  notes. **Approved by the person**, with Decision 10's form settled as
  words-first ("Gain $350 vs paid" / "Loss $150 vs paid" / "At cost", same
  strings on row and page) and the pass's six copy questions decided —
  recorded as spec Decision 11: summary line hidden at zero sales; the
  page's sale line drops "Sold"; the note as a quiet line under the sale
  line; Note placeholder "Anything worth remembering"; card arrow only; no
  desire hint on a sold page. The four drawing deviations (one example set,
  the summary in the meta slot, Selected at 26 in the three-figure layout,
  the desire hint dropped) accepted. The copy changes land as T008a.

- [x] **T008a — The settled strings in `SaleCopy` (Decision 11).**
  `rowOutcome` and `pageOutcome` become one form — "Gain $350 vs paid" /
  "Loss $150 vs paid" / "At cost" (`atCost` → "At cost"; keep both function
  names so the views' call sites in later tasks read as planned, or fold to
  one and keep the other as an alias — implementer's call, stated);
  `saleLine` drops the "Sold " prefix; new `notePlaceholder = "Anything
  worth remembering"`. `SaleCopyTests` updated whole; the S1 boundary test
  stays. Consumers for T009/T014 (not here): `soldSummaryLine` nil at zero
  sales; the note line on the page.
  Files: `Trove/Models/SaleCopy.swift`, `TroveTests/SaleCopyTests.swift`.
  **Verify:** `scripts/verify.sh` green.
  **Done (2026-09-13):** one body in `rowOutcome`, `pageOutcome` a forward
  to it (drift structurally impossible; the page test pins the three
  literals so a body of its own would go red); `saleLine` opens on the
  date; `notePlaceholder` added. Falsifiability: `atCost` → "At cost." →
  three failures in "Sale copy", reverted. Verify (implementer's verbatim
  output): 1393 tests in 191 suites passed. Reviewed with Phase 4 (a
  two-file copy change; no phase review of its own). **Phase 3 closes.**

## Phase 4 — View models

- [x] **T009 — `ItemListViewModel`: two sides, `show(_:)`, both exports.**
  Per plan §4, Q5 and Q15. `Side`, `private(set) side`, **`show(_ side:)`**
  (sets the side and clears `searchText`/`categoryFilter`/`showsOnlyUnvalued`
  whenever it changes, both directions, then `load()`), `soldItems`,
  `soldTotals` (through `SaleOutcome.totals` — no arithmetic in this file),
  `soldSummaryLine`; `load()`
  splits once and derives every existing member from `owned`; `emptyReason`
  by side; `canReorder` owned-only; `delete(id:)` over both arrays;
  `narrowed(_:)` shared by both sides; `canExport` → `canExportCSV` /
  `canExportPDF`; `exportCSV` appends the narrowed sold rows. The contract
  change lands whole: `OverflowDropdown(canExportCSV:canExportPDF:…)`, the
  two list views' calls (`WishlistView` passes its one `canExport` to both),
  `ExportWiringTests` and `OverflowDropdownRenderTests` updated — broadened
  (one gate per export row, still exactly two, Import and Settings ungated),
  not weakened. Pattern: `load()`'s existing filter chain; `WishlistViewModel`
  for the mirror. Tests (`ItemListViewModelTests`): G13 (mutation: drop the
  split), G14 (mutation: reverse the comparator), G15 (on the Owned side a
  category filter narrows the sold rows; unfiltered CSV is owned then sold —
  mutation: skip the narrowing), **G33** (set a category filter and a
  query, `show(.sold)` → `exportCSV` lists every owned and every sold row
  and the three narrowing fields read empty; the same from Sold back to
  Owned; `show(.owned)` while already on Owned leaves a filter alone —
  mutation: keep the filter across the switch → red), G32's scan half
  (this file and `DashboardViewModel` call `SaleOutcome.totals(` and contain
  no `salePriceCents -`), G16's list half (the PDF entries and cover exclude
  a sold item), G28 completed (the list's unfiltered Custom CSV bytes == Settings'),
  `delete` on a sold id, `canReorder` false on `.sold`, `emptyReason` on the
  Sold side (`nothingSold`; `stillSyncing` when the monitor says so),
  `canExportCSV` true with only sold items while `canExportPDF` is false;
  `ExportWiringTests` G29.
  Files: `Trove/ViewModels/ItemListViewModel.swift`, `Trove/Views/Shared/OverflowDropdown.swift`,
  `Trove/Views/Items/ItemListView.swift` + `Trove/Views/Wishlist/WishlistView.swift`
  (the dropdown call only), `TroveTests/ItemListViewModelTests.swift`,
  `ExportWiringTests.swift`, `OverflowDropdownRenderTests.swift`,
  `SettingsViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.
  **Done (2026-09-13):** three new suites; twenty-two mutations, each red
  then reverted (G13 `ItemListViewModelTests:1707`; G14 date and name
  reversals :1733; G15 :1990; G33 both directions :1893 and the
  same-side case :1946; G32 :1774/1775; G16 entries :2039 and cover
  :2043; G28 three ways `SettingsViewModelTests:458/462`; delete :1854;
  `canReorder` :1829; `emptyReason` :1788/1792; the two gates :2061/2062;
  G29 by scan `ExportWiringTests:115/61` and by pixels
  `OverflowDropdownRenderTests:103`; Decision 11's hidden summary :1747).
  Declared readings: `canExportCSV` counts the *narrowed* halves (a chip
  matching nothing on either side disables the row rather than staging a
  header-only file — 011's criterion 2); `show(_:)` always reloads, clears
  only on a change; G32's scan asserts this file only, T010 extends it.
  Verify (implementer's verbatim output): 1412 tests in 194 suites passed.
  For T015: branch the empty state on `emptyReason`, not `isEmpty`
  (owned-only); `soldSummaryLine` is `String?`. For close-out: README's
  Export bullet now gets three things wrong — "filters and sort respected"
  (the sold half rides along in Sold order), one gate for two formats (an
  all-sold collection has CSV but no PDF), and the column list is short by
  four.

- [x] **T010 — `DashboardViewModel`: the sold figures.**
  Per plan §6. `load()` splits `scoped` into owned and sold; `apply` unchanged
  in body; `soldTotals` through `SaleOutcome.totals` (no arithmetic here —
  G32's scan from T009 covers this file too), `hasSales`, `soldLine`,
  `soldDeltaLine`. Pattern: `apply` and
  `marketFigureCount`'s gating. Tests (`DashboardViewModelTests`): G22 (with a
  sold item among valued owned ones the three figures reconcile and the sold
  item is in none of value, spent, counts, breakdown, `unvaluedDestination`,
  market count — mutation: count sold in `apply` → red), G23 (scope: a sale
  in another category is absent from a scoped copy; `hasSales` false with
  none in scope — mutation: skip the scope filter for sold), the two lines
  equal `SaleCopy` over the same numbers.
  Files: `Trove/ViewModels/DashboardViewModel.swift`, `TroveTests/DashboardViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.
  **Done (2026-09-13):** `load()` splits `scoped` and hands `apply` the
  owned half (body untouched); market summaries asked for owned ids;
  `soldTotals`/`hasSales`/`soldLine`/`soldDeltaLine` beside the market
  gating. Five tests. Mutations, each red then reverted: G22 (`apply` over
  the whole scope → 13 issues, `DashboardViewModelTests:820/828/837`); G23
  (scope skipped for sold → :893/906); G32 (hand-sum → the scan's
  `SaleOutcome.totals(` half `ItemListViewModelTests:1782`; arithmetic
  alongside → the `salePriceCents -` half :1783); the gating and both
  lines swapped → :921/864/867. G32's scan now covers both view models.
  Verify (implementer's verbatim output): 1417 tests in 195 suites passed.
  Noted for the sweep: the scan's `salePriceCents -` clause is a literal —
  `($0.salePriceCents ?? 0) - x` would slip past it (the `totals(` clause
  still catches the realistic hand-sum). For T016: the root breakdown
  collapses to top-level categories.

- [x] **T011 — `SellPlanViewModel`: the Sold figure, the cue, `markSold`, the framing guard.**
  Per plan §3 and Q14. `soldItems`, `soldCount`, `soldValueCents`, `hasSales`
  read off `itemsSoldToward`; `selectedValueMeetsCost` reads Selected plus
  Sold; `load()` drops sold items from `owned`; `markSold(_:sale:)`
  (`ItemSaleStore.markSold(toward: wishlistItem)`, save, rollback on refusal,
  `load()`); `saleCandidate: Item?`; `makeSaleFormViewModel(for:)` (mode
  `.mark`, the price seeded from the item's current value — the same P1
  seeding as the detail's, and the test asserts the two hosts' seeds are
  equal for the same item). Pattern: `toggle(_:)`. Tests
  (`SellPlanViewModelTests`, `SellPlanFramingTests`): G6/G12 (sold from the
  plan links to it and leaves the candidates; a sold item never qualifies —
  mutation: drop the sold filter), G10 (`bothFiguresExistIndependently` gains
  the third figure: cost unchanged with a sale — mutation: subtract sold from
  the cost), G11 (sales alone meeting the cost read as met; sales short of it
  don't; an empty plan with no sales never does — mutation: read Selected
  alone), `soldItems` most recent first, a sale recorded from the detail is
  not in this plan's `soldItems`. The term scan already covers the new
  members; confirm by running it against a deliberately named `remainingCents`
  → red → remove.
  Files: `Trove/ViewModels/SellPlanViewModel.swift`, `TroveTests/SellPlanViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.
  **Done (2026-09-13):** the Sold figure off `itemsSoldToward` in
  `areInSoldOrder`; the cue reads Selected + Sold (Q14); `load()` drops
  sold items; `markSold` saves, rolls back and reloads on refusal;
  `saleCandidate`; `makeSaleFormViewModel(for:)`. Eleven tests. Mutations,
  each red then reverted: G12 (`SellPlanViewModelTests:908`), G10 (:592),
  G11 (:970), the term scan against `remainingCents` (:543), G6
  (`toward: nil` → :885), sold order reversed (:952), the relationship
  read replaced by a fetch (:926). Cross-host seed equality deferred to
  T012 by the bundle's instruction. The refused-save rollback is
  implemented but unguarded — an in-memory container can't make `save()`
  throw and the only throw in `markSold` is the market clear; the existing
  precedent is `ItemDetailViewModelTests`' structural scan of the `catch`
  block (T012 uses the same shape; sweep). Verify (implementer's verbatim
  output): 1428 tests in 196 suites passed.

- [x] **T012 — `ItemDetailViewModel`: mark, edit, return.**
  Per plan §5. `isSold`, `sale`, `saleOutcome`, `saleSheet: SaleSheet?`,
  `makeSaleFormViewModel()`, `markSold(_:)`, `editSale(_:)`,
  `returnToCollection()` — each through `ItemSaleStore`, one save, rollback
  + `load()` on refusal (the `store(_:)` shape). Pattern: `store(_:)` and
  `removeMatch()`. Tests (`ItemDetailViewModelTests`, second context): G20
  and G5 for the detail path (mutation: pass a plan → G6 red), `editSale`
  keeps an earlier plan link (G21), `returnToCollection` clears all five and
  the item is back in `ItemListViewModel.items` at its slot (G7 through the
  detail path), a refused save leaves the item owned (`SaveFailingContext`
  or the existing refusal shape), `makeSaleFormViewModel()` seeds per P1 for
  `.mark` and from the sale for `.edit`, `delete()` on a sold item removes it
  and its photos.
  Files: `Trove/ViewModels/ItemDetailViewModel.swift`, `TroveTests/ItemDetailViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded. **Phase 4 closes
  here — pause for the person** (nothing new to see; the review gate).
  **Done (2026-09-13):** `SaleSheet` (top-level, the `PhotoSheetStep`
  placement), the three intents through `ItemSaleStore` in the `store(_:)`
  shape, `makeSaleFormViewModel()`; eleven tests on a second context.
  Mutations, each red then reverted: G6 detail half (a plan passed →
  `ItemDetailViewModelTests:1466/1514`), G21 (:1542), return never saving
  (:1580–1592), G19 both modes (:1664/1701) and the cross-host equality
  (:1730/1731), the accessors hard-coded (:1459–1461), the catch losing
  `rollback()` (:1623 — the structural scan, since no in-memory save can
  throw), G5/G20 through the detail (:1485–1490), selections kept (:1513),
  G7 renumbering (:1586/1592), delete refusing a sold item (:1756–1761).
  Declared: no `isConfirmingReturn` on the view model (the task line omits
  it; the alert flag is view `@State`, T014); the intents don't clear
  `saleSheet` — the view does, as T011's `saleCandidate` — T013/T014's
  bundles say so. Verify (implementer's verbatim output): 1439 tests in
  197 suites passed. Mechanical note for the log: reverting a mutation
  with `git checkout <file>` destroys uncommitted work — snapshot first.

- [x] **T012a — Phase 4 review notes S3–S5 (test-only).** S3: the G10
  framing test's `difference` assertions were tautologies over the three
  pinned literals — dropped, the docstring now points at the term scan; the
  Dashboard's `value − spent == delta` line dropped too, since
  `valueDeltaCents` is *defined* as that difference (unfalsifiable by
  construction — the 002/T013 finding, met again). S4: the structural
  catch-block scan now covers `SellPlanViewModel.markSold` (mutation:
  `rollback()` removed → `ItemDetailViewModelTests:1636` red). S5: the
  cross-host seeding equality covers a value-less item (mutation: `?? 0`
  → :1763/1771 red). Verify (implementer's verbatim output): 1439 tests in
  197 suites passed. Plan §4's `soldSummaryLine` signature corrected to
  `String?` (S1). Carried: S2 Q5's "either side non-empty" reads as raw
  where the code narrows (close-out); **S6 an all-sold collection lands the
  Owned side on "Nothing added yet" — a product question, put to the
  person at the Phase 4 pause, and T015's bundle carries the answer**; S7
  `SellPlanViewModel.soldValueCents` sums prices itself by plan §3 (G32's
  name overstates its reach; sweep).

## Phase 5 — Screens

- [x] **T013 — The sale sheet (shared).**
  Per plan §5 (`SaleFormView`) and T008's artboard. New
  `Trove/Views/Items/SaleFormView.swift`: `NavigationStack`, the money field,
  the bounded date popover (`in: ...viewModel.latestDate`), Sold at, Note,
  Cancel / confirm, detents; `confirm` receives the `Sale`. Identifiers
  `sale.sheet.price`, `sale.sheet.confirm`. Pattern: `ItemFormView`'s
  `priceAndDate` and `dateField`; `PhotoPickerSheetView` for the host-closure
  shape. Tests (`SaleFormWiringTests`, scans, each `#require`ing its anchor
  — the `DatePicker(` call — found once): the date picker carries an
  upper bound `in:` ending at `latestDate` (mutation: drop the bound → red);
  confirm calls `viewModel.sale()` and nothing writes to a `modelContext`
  inside the file (`DeletionGuardTests`' no-store-in-views instinct); the
  strings come from `SaleCopy` (the T007-of-005 strings-from-copy scan).
  Files: `Trove/Views/Items/SaleFormView.swift` (new), `TroveTests/SaleFormWiringTests.swift` (new).
  **Verify:** `scripts/verify.sh` green; mutation recorded; the sheet seen by
  eye on the simulator against the artboard (named in the Done note).
  **Done (2026-09-14).** `SaleFormView` in `PhotoPickerSheetView`'s
  host-closure shape over `ItemFormView`'s field chrome; five scans in
  `SaleFormWiringTests`. 1444 tests green. Mutations red as named: the
  bound dropped → `theDatePickerIsBoundedAtLatestDate` red; a placeholder
  typed inline and the sale swallowed → three issues in the owning tests.
  Design-free choices: the Note placeholder from `SaleCopy` (Decision 11
  pins it); no rust border on the date field (`.dateInFuture` is unreachable
  once bounded); `.scrollBounceBehavior(.basedOnSize)`. **The eye check is
  deferred to T014** — the sheet had no host yet, so it could not be reached
  in the running app; T014's device pass compares it to `SheetFilled.png` /
  `SheetInvalid.png`. Also found: the machine moved to Xcode 27 mid-spec
  and HEAD did not build under it; three one-line fixes outside the
  footprint went in as their own commit ahead of this one.

- [ ] **T014 — The item detail: menu rows, the sold state, edit, return, delete.**
  Per plan §5 and Q8. `DetailOverflowMenu` gains `Row`, `middle`, the second
  initializer (the first kept; `WishlistDetailView` untouched;
  `MenuPolicyTests` green). `ItemDetailView`: the owned menu (Edit, Mark as
  sold…, Delete) and the sold menu (Edit sale…, Return to collection…,
  Delete); `.sheet(item: $viewModel.saleSheet)` hosting `SaleFormView`; new
  `SoldMark` (`Trove/Views/Items/SoldMark.swift`, `sold.mark`,
  `.accessibilityElement(children: .combine)` reading "Sold", the sale line
  and the outcome — criterion 16) above the category/name when `isSold`;
  the Market section and Find a photo… omitted and the dial
  `isInteractive: false` in the sold state; the return alert; the delete
  alert's `message(isSold:)`. Pattern: the existing `.sheet`/`.alert` chain
  in `ItemDetailView`. Tests (`SoldStateWiringTests`, scans): both middle
  rows and the edit label read `SaleCopy`; `WishlistDetailView` names no
  `SaleCopy` member; the sold branch composes no `MarketSection(` and no
  `findPhotoAction` (brace-span scan that first `#require`s the
  `if viewModel.isSold` anchor found exactly once — mutation: rename the
  anchor → the `#require` fails, never a vacuous pass); `SoldItemRow`,
  `SoldMark` map `isLoss` to the rust/moss tokens; `DetailOverflowMenu` still hosts one
  `Menu` (mutation: a second `Menu` in `ItemDetailView` → `MenuPolicyTests`
  red — the existing guard, re-confirmed).
  Files: `Trove/Views/Shared/DetailOverflowMenu.swift`, `Trove/Views/Items/ItemDetailView.swift`,
  `SoldMark.swift` (new), `TroveTests/SoldStateWiringTests.swift` (new).
  **Verify:** `scripts/verify.sh` green; mutations recorded; both menus and
  the sold state seen by eye against the artboards.

- [ ] **T015 — The Items tab: the switch, the Sold side, its row, its delete.**
  Per plan §4 and T008's artboards. New `Trove/Views/Items/SideSwitch.swift`
  (bespoke, `items.sideSwitch`, label "Owned or sold", value = the side,
  `.isSelected` on the active half) and `SoldItemRow.swift` (thumbnail, name,
  sold date, price, outcome coloured off `SaleOutcome.isLoss`, combined a11y).
  `ItemListView`: the switch in the **header** (both `body` branches compose
  it, so it stands over an empty Owned side — plan §4), calling
  `viewModel.show(_:)`, never bound to `side`; on Sold no search/chips/sort,
  the `soldSummaryLine`, `SoldItemRow`s with tap and trailing-swipe delete
  only, the `.nothingSold` empty state; `apply(_:)` turns `.sold` into one
  `viewModel.show(.sold)` call and the other two into `show(.owned)` plus
  today's writes. Pattern: `rows` and `header` in `ItemListView`;
  `ItemRow` for the row; `SortBadge` for the control's drawing. Tests
  (`ItemListSidesWiringTests`, scans — each `#require`ing its anchor (the
  Sold branch's `case .sold:` / the `.swipeActions(edge: .trailing)` span /
  the `SideSwitch(` call) found once — + a `SoldItemRow` render/label test in
  the `ItemRow` tests' shape): no `sortControl`/`SearchField` in the Sold
  branch; the Owned rows' swipe block contains no `SaleCopy.markAsSold`
  (criterion 1); the Sold rows compose `SoldItemRow` and no leading swipe; a
  row built over a loss reads "Loss $150" and over equal figures "Sold at
  cost" (mutation: the outcome gated on `> 0` only → "Sold at cost" for a
  loss → red); the `.sold` case of `apply` is exactly one
  `viewModel.show(.sold)` call and the `SideSwitch` call site names
  `viewModel.show` and no `$viewModel.side` (mutation: bind the switch to a
  `side` setter → red) — the clearing itself is T009's G33 unit test, not a
  scan; the switch sits outside the `if let reason = viewModel.emptyReason`
  span.
  Files: `Trove/Views/Items/SideSwitch.swift` (new), `SoldItemRow.swift` (new),
  `ItemListView.swift` (**both** the `apply` switch's `.sold` placeholder and
  the `emptyState` switch's `.nothingSold` placeholder left by T005 are
  replaced here), `Trove/Views/Wishlist/WishlistView.swift` (its
  `.nothingSold` fold from T005, re-checked), `TroveTests/ItemListSidesWiringTests.swift` (new),
  `SoldItemRowTests.swift` (new).
  **Verify:** `scripts/verify.sh` green; mutations recorded; both sides seen
  by eye against the artboards.

- [ ] **T015a — The emptied Owned side's empty state (spec Decision 12).**
  Per plan §4's "The emptied Owned side" paragraph. `ListEmptyReason` gains
  `.everythingSold`; `SaleCopy` gains `everythingSoldHeadline` /
  `everythingSoldDetail`; `ItemListViewModel.emptyReason`'s `.owned` branch
  maps `reason(...)`'s `.nothingAdded` to `.everythingSold` iff `soldItems`
  is non-empty (`reason(...)` itself untouched); `ItemListView.emptyState`
  and `WishlistView`'s reason switch handle the case. Pattern: the
  `.nothingSold` case and its `nothingSold*` copy (T002/T005/T015). Tests:
  `ItemListViewModelTests` — one sold, none owned → `.everythingSold`;
  neither → `.nothingAdded`; one sold, none owned, import in flight →
  `.stillSyncing` (mutation: drop the `soldItems` check → the first goes
  red; map before `stillSyncing` → the third goes red); a scan that the
  `.everythingSold` case of `emptyState` reads both `SaleCopy` members.
  Files: `Trove/Models/ListEmptyReason.swift`, `Trove/Models/SaleCopy.swift`,
  `Trove/ViewModels/ItemListViewModel.swift`, `Trove/Views/Items/ItemListView.swift`,
  `Trove/Views/Wishlist/WishlistView.swift`, `TroveTests/ItemListViewModelTests.swift`,
  `TroveTests/ItemListSidesWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded; the state seen
  by eye after selling the last owned item.

- [ ] **T016 — The Dashboard's Sold card.**
  Per plan §6 and T008's artboard. New `Trove/Views/Dashboard/SoldCard.swift`
  (header, `soldLine`, `soldDeltaLine` in the Q11 colour, `dashboard.soldCard`,
  combined a11y + hint); placed in `DashboardView` after the callout, before
  the breakdown, iff `hasSales`, action `router.showSoldItems()`. Pattern:
  `unvaluedCallout` (a card that is a `Button` through the router). Tests
  (`DashboardWiringTests`, scan): `#require` the `if viewModel.hasSales`
  anchor found exactly once, then `SoldCard(` once inside that span, its
  closure calling `router.showSoldItems()` (mutations: render it
  unconditionally → red; rename the anchor → the `#require` fails); the
  card's strings come from the view model's two lines, not literals; the
  delta's colour reads `isLoss`.
  Files: `Trove/Views/Dashboard/SoldCard.swift` (new), `DashboardView.swift`,
  `TroveTests/DashboardWiringTests.swift` (new or extended).
  **Verify:** `scripts/verify.sh` green; mutation recorded; the card seen by
  eye at the root and drilled into a category.

- [ ] **T017 — The Sell Plan: the row action, the third figure, the Sold section.**
  Per plan §3 and T008's artboard. `SellPlanRow` gains the bespoke **Mark as
  sold…** control (`sellPlan.row.markAsSold`; the toggle's hit area and the
  control's separated per the artboard); `SellPlanView` hosts
  `.sheet(item: $viewModel.saleCandidate)` → `SaleFormView` over
  `viewModel.makeSaleFormViewModel(for:)` → `markSold`; the
  figures row grows the **Sold** cell (`sellPlan.soldFigure`, "N items") iff
  `hasSales`; the Sold section under the candidates. Pattern: `figures(for:)`
  and `candidateList`. Tests: `SellPlanFramingTests`' literal scan over the
  new copy (already in place — confirm by adding "remaining" to a caption →
  red → remove); `SellPlanWiringTests` (scan, `#require`ing the
  `if viewModel.hasSales` anchor found before reading its span): the third
  cell is inside that span; the row control calls into `saleCandidate`; the
  sheet composes `SaleFormView` over `makeSaleFormViewModel(for:` (one
  component, one seeding rule, not a second form).
  Files: `Trove/Views/Wishlist/SellPlanView.swift`, `TroveTests/SellPlanWiringTests.swift` (new).
  **Verify:** `scripts/verify.sh` green; mutations recorded; the header at
  two and three figures seen by eye against the artboard.

- [ ] **T018 — The `-seedSold` seed, and the UI tests, run twice.**
  Per plan §8 and Q10. `UITestSeed.soldArgument`, `shouldSeedSold(mode:arguments:)`,
  `sold(into:now:)` (through `ItemSaleStore.markSold`); the second guard in
  `TroveApp.init`. `UITestSeedTests` mirrored (the gate's four refusals; the
  seed called once under its own guard; the argument spelled only in
  `UITestSeed`; the seeded figures — 2 sold, $1,800, +$200, the plan's one
  sale — read back on a second context through `TroveStore.make(isUITesting:
  true)` and compared to `SaleOutcome.totals(over:)`, not to a third
  hand-written sum); the existing `theAppCallsTheSeedOnceUnderTheGuardAndReadsTheFlagOnce`
  stays green. The three UI tests in plan §8, then `scripts/verify.sh ui`
  **twice back to back**. Pattern: `UITestSeed.sellPlan` and
  `testTheSeededSellPlanRanksRisingFirstAndSaysWhy`. Mutations (each
  reverted, recorded): reverse the sold comparator → the order assertion
  red; `returnToCollection` keeping `soldDate` → the return test red;
  `SellPlanViewModel.markSold` passing `toward: nil` → the figure test red.
  Files: `Trove/App/UITestSeed.swift`, `Trove/App/TroveApp.swift`,
  `TroveTests/UITestSeedTests.swift`, `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green twice;
  mutations recorded. **Phase 5 closes here — pause for the person** (what
  can be tried: mark an item sold from its page and from a sell plan, the
  Sold side, the card, edit and return, export and re-import).

## Phase 6 — Verification and close-out

- [ ] **T019 — Device pass. [general-purpose agent with simulator tools; person: sync + VoiceOver]**
  Per every criterion, on the iPhone simulator with the `-uiTesting` store
  (and `-seedSold` where a history helps). Walk: Mark as sold… from the
  detail (price prefilled from the value; a future date refused **on the
  picker itself** — instrument with a screenshot of the disabled days, and
  confirm the view model refuses a typed-past-midnight edge by the unit
  suite, not by eye); the Sold mark, the outcome words at a gain, a loss and
  at cost; the Owned side empty and the Sold side listing it; the card at the
  root and inside a category (hidden where nothing in scope sold); the jump
  landing on Sold; Sort By hidden there, "…" present, CSV from the Sold side
  including both sides, PDF owned-only; Edit sale…; Return to collection… →
  back at its Custom slot, on no plan; Delete on a sold row with the shorter
  message; a plan row's Mark as sold… → the third figure, the Sold section,
  the row gone; deleting that wishlist item → the sale stands, no plan;
  Delete All items (Settings) removes sold too; a matched item marked sold
  → Settings' matched count drops, Refresh skips it, its Market section is
  gone, Return brings the match back as never-refreshed-here. **Instrument
  the sheet, don't eyeball it**: a temporary file probe in
  `ItemSaleStore.markSold` confirms exactly one write per confirm and none
  on Cancel, swipe-down or a re-render of the `.sheet(item:)` — removed
  before the suites run. Both suites twice. Findings fixed in place if
  routine and inside the footprint, else returned as a diagnosis for a
  decision review; each fix a sub-lettered task.
  **[person]** Sync (criterion 15): a sale appearing on a second device, or
  recorded as an honest partial as `005` did. VoiceOver (criterion 16):
  Accessibility Inspector over the menu rows, the switch, the card, a Sold
  row, the Sold mark, the plan's Sold figure.
  **Verify:** the record in the Done note with what was seen and the probe's
  count per action; `scripts/verify.sh all` green twice.

- [ ] **T020 — Close-out.**
  Criteria 1–16 ticked in `spec.md` with citations, honest partials named;
  the Copy section gains the strings settled at T002/T008 (P8); `plan.md`
  gains "As built" (deviations, the readings R1–R3 as confirmed or
  overturned at sign-off, Q-items as shipped); this file's status flipped;
  `specs/ROADMAP.md`'s 006 entry and status row, README's Status/tree,
  `DECISIONS.md` (the sale as fields on the item and why; the side as
  view-model state; the pair rule; the second seed) — on this branch, the
  `005` precedent; the pre-merge `skeptical-reviewer` sweep over
  `git diff main...HEAD` (bundle cut after `git add -A`); the notes carried
  from `005`'s sweep re-review that touch files this spec edits (the
  `README` placeholder, the cadence sentence) closed here; PR marked ready
  for review.
  **Verify:** everything above committed and pushed; `scripts/verify.sh all`
  green with the final counts recorded here.

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
| Plan + tasks draft | fable (`sdd-planner`, high effort) | 354,690 (measured from the dispatch return; 62 tool uses, 14 min) | this document; no product question surfaced; three spec readings (R1–R3) flagged for sign-off |
| Plan sign-off | fable (`skeptical-reviewer`, high effort) | 101,841 (measured; 6 tool uses — three targeted looks beyond the bundle, stated) | **one blocking** (B1: a CSV from the Sold side inherited the Owned side's category/search narrowing with no chip on screen) + 11 second-look notes (S1–S11); R1–R3 and Q1–Q14 confirmed |
| Plan fix round | fable (`sdd-planner`, resumed with its context) | 420,045 (as reported by the resumed dispatch; includes the carried first-run context) | B1 fixed as Q15 + G33 (`show(_ side:)` clears the narrowing, both directions); S1–S11 all folded — `SaleTotals`/G32, `isLoss` on the model, cross-references, the Sell Plan sale-form factory, the pause-report handoff notes, Q6's import edges, the anchor-found house rule, `.nothingAdded` pin, the switch in the header, the 011 order line |
| Plan re-review | fable (`skeptical-reviewer`, resumed) | 126,038 (as reported by the resumed dispatch; ~14k of it this round) | **signed off, nothing open**; one non-blocking observation for the log: T015's "`SideSwitch` names `viewModel.show`, no `$viewModel.side`" scan is mostly enforced by the compiler once `side` is `private(set)` — it can still go red, but the clearing's coverage is G33, not that scan |
| Spec session (orchestration) | fable, high effort (the person raised it for the spec conversation) | not visible to the session — read with `ccusage` at the merge | spec written with the person (Decisions 1–10), planning dispatched, sign-off loop: one review, one re-review |
| T001 implement | opus (`sdd-implementer`, high effort) | 94,964 (42 tool uses, 12 min) | done first pass; five mutations + the CloudKit red run reported red; read beyond the bundle: `TestSupport.swift`, `verify.sh`, `WishlistViewModel.delete(id:)`, `Money.swift`, `PhotoSelection.swift` |
| T001 per-task review | opus (`skeptical-reviewer`) | 42,123 (1 tool use — bundle only) | signed off, nothing blocking; S1–S4 recorded in the Done note |
| T002 implement | opus (`sdd-implementer`, high effort) | 66,901 (20 tool uses, 6 min) | done first pass; G17 red as reported; one mechanical edit outside the named files (`DeleteAllCopyTests`); bundle miss: named `Money.swift` for formatters that live in `Int+Currency.swift` |
| T003 implement | opus (`sdd-implementer`, high effort) | 85,496 (40 tool uses, 13 min) | done first pass; ten mutations red as reported; bundle miss (orchestrator): the task-line excerpt was cut by line number after T001's Done note shifted the file, so it quoted T002 — extraction is anchor-based from here on |
| T003 per-task review | opus (`skeptical-reviewer`) | 49,906 (5 tool uses — four targeted looks, stated) | signed off, nothing blocking; S1–S5 in the Done note |
| T004 implement | opus (`sdd-implementer`, high effort) | 54,854 (14 tool uses, 5 min) | done first pass; three mutations red as reported; one plan-vs-shipped spelling reconciled inside the contract (`SaleCopy` constants, not a mode function) |
| T005 implement | opus (`sdd-implementer`, high effort) | 61,715 (24 tool uses, 5 min) | done first pass; three placeholder switch cases outside the named files (mechanical, required to compile), declared |
| Phase 1 review | opus (`skeptical-reviewer`) | 105,930 (5 tool uses — one targeted look, stated) | **one blocking** (B1: plan §4/§5 named three `SaleCopy` members T002 shipped differently, and the empty state was one string where the plan calls for headline + detail) + S1–S6 |
| T002a fix (B1, S1, S4) | opus (`sdd-implementer`, high effort) | 50,574 (15 tool uses, 3 min) | done; the bundle's mutation was equivalent and the implementer shifted it to a reachable boundary, stated |
| Phase 1 re-review | opus (`skeptical-reviewer`, resumed) | 111,499 cumulative (~5.5k this round; 1 tool use) | **signed off**, no new blocking |
| T006 implement | opus (`sdd-implementer`, high effort) | 166,658 (64 tool uses, 19 min) | done first pass; eight mutations red; bundle miss (orchestrator): `areInSoldOrder`'s rule (plan Q9) was not in the bundle and `PDFComposerTests` was not named — the implementer grepped two plan windows, stated |
| T006 per-task review | opus (`skeptical-reviewer`) | 80,532 (9 tool uses — five targeted looks, stated) | signed off, nothing blocking; S1–S6 in the Done note |
| T006 follow-up (S1) | opus (`sdd-implementer`, resumed) | 172,513 cumulative (~6k this round) | two comment-claimed mutations run and red |
| T007 implement | opus (`sdd-implementer`, high effort) | 96,006 (31 tool uses, 7 min) | done first pass; both mutations red; README wording drawn from commit messages (bundle carried no user-facing description — a bundle gap, stated) |
| Phase 2 review | opus (`skeptical-reviewer`) | 95,410 (15 tool uses — seven targeted looks, stated) | **one blocking** (B1: README's new sentence promised a one-tap return the spec forbids — the bundle carried no user-facing description, so the implementer worded it from commit messages) + S1–S8 |
| T007a fix (B1, S1, S3) | opus (`sdd-implementer`, resumed) | 107,802 cumulative (~12k this round; 9 tool uses) | done; mutation red as reported |
| Phase 2 re-review | opus (`skeptical-reviewer`, resumed) | 98,879 cumulative (~3.5k this round; 1 tool use) | **signed off**, no new blocking |
| T008 brief | fable, medium (the session — transcription from spec, plan, `SaleCopy`, tokens) | — | `design/elements/006-mark-as-sold/brief.md` written; awaits the person's `/design` run |
| T008 design pass | — (person + `/design`) | — | brief written (session); 12 artboards approved + saved; tokens section written (session, transcription); six copy questions decided by the person → spec Decision 11; no allowance draw |
| T008a implement | opus (`sdd-implementer`, high effort) | 46,454 (10 tool uses, 4 min) | done first pass; one design-free choice (alias) stated |
| T009 implement | opus (`sdd-implementer`, high effort) | 169,080 (70 tool uses, 25 min) | done first pass; twenty-two mutations red; one wording gap resolved by a declared default (narrowed `canExportCSV`) — to the Phase 4 review |
| T010 implement | opus (`sdd-implementer`, high effort) | 72,844 (27 tool uses, 11 min) | done first pass; five mutation runs red |
| T011 implement | opus (`sdd-implementer`, high effort) | 102,615 (40 tool uses, 11 min) | done first pass; seven mutations red (two beyond the task's list, stated) |
| T012 implement | opus (`sdd-implementer`, high effort) | 120,241 (34 tool uses, 12 min) | done first pass; eleven mutation runs red; one self-inflicted revert recovered from a snapshot |
| Phase 4 review | opus (`skeptical-reviewer`) | 136,144 (8 tool uses — two targeted looks, stated) | **signed off, nothing blocking**; S1–S7 |
| T012a fix (S3–S5) | opus (`sdd-implementer`, high effort) | 60,317 (29 tool uses, 6 min) | done; both mutations red |
| T013 implement | opus (`sdd-implementer`, high effort) | 133,052 (43 tool uses, 12 min) | done first pass; both mutation runs red; eye check deferred to T014 (no host yet); found HEAD broken under Xcode 27 — three toolchain fixes committed separately ahead of the task |
| _rows added per dispatch as the spec runs_ | | | |

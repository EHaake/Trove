# 021 — Import Expansion — Technical Plan

**Status**: **Final** (2026-10-09) — signed off by the `skeptical-reviewer` after fixes (three blocking findings, B1–B3, fixed and re-reviewed); the re-review's two further findings (N1, N2) were fixed by the orchestrator directly under `CLAUDE.md`'s review-loop cap and are logged in `tasks.md`'s tier log, not re-reviewed

Drafted by the `sdd-planner` (per `CLAUDE.md`'s model policy: the
plan-and-tasks draft row at the implementation tier with no override, the trial
continuing from `018`) against the approved `spec.md` and `main` at `028747f`.
**Revised 2026-10-08** after the sign-off review and the spec's amendment of the
same day (commit `38883a8`, Decisions 17–23, criteria 41–46), and **again
2026-10-09** for the person's two answers (Decision 19 reworded, Decision 24
added; criteria 43 and 47). The spec's P-items are already decisions; the
planning choices below (Q1–Q11) become decisions on plan approval. Line numbers
are as read at `028747f`; every task re-reads the file it edits.

## Context

Spec 021 replaces the importer's positional header gate with **name matching**,
widens what a price and a date may look like, reads `N/A` as empty, leaves
totals rows out, and — the half that writes onto existing data — gives every
export a **Trove ID** column so a re-imported row **updates** its item instead
of adding a copy.

The footprint: **no new stored field** (the Trove ID is the `id` every row has
carried since `001`, §1), two new production files (`ImportRows.swift`,
`ImportStore.swift`), a rewritten `ImportSchema` row pipeline, one more column
and a starred header row in `ExportSchema`, the import half of the two list
view models (the commit moves out of them into two small stores), the import
copy, the Settings templates, one line of `MarketIndex.swift` (a trap, below),
one UI-test seed, `docs/csv-reference.md` and its samples. No new service, no
network call, no new screen, no `.pbxproj` edit, no constitution amendment.

**A code kept from a file makes a state the app has never had to survive: two
rows with one `id`.** It takes one device (spec, Sync, amended): a freshly
installed phone looks empty until iCloud finishes, and a backup imported then
is present twice once sync catches up. Today that state **traps on load** —
`MarketSummary.summaries(forSubjects:)` builds
`Dictionary(uniqueKeysWithValues:)` from the ids it is handed
(`MarketIndex.swift:92`), and the Items list, the Wishlist, the Dashboard and
the Sell Plan all call it. §1 fixes the trap and audits every other id-keyed
site before any task can create the state.

**Earlier rules change, and each takes a pointer, never a silent edit.** `011`'s
plan pins "Header row present, matched byte-for-byte by `012`" and "**No `id`
column**" (`specs/011-data-export/plan.md:113`, `:132`) and records the shipped
widths as boundaries (`:150`); `012`'s spec pins the rigid template, strict
money and dates, and "Import never modifies or deletes" (`spec.md:45`, `:60`,
`:94`); `002` and `006` introduced and grew the boundary widths. The tests that
guard those rules are **rewritten to pin the new rule** (named in §13 and in
each task) and each superseded sentence gains a "Superseded in part by `021`"
pointer beside it at the close-out. Nothing is deleted to get to green.

## Readings for sign-off (not open questions — the plan builds to each)

- **R1 — The Trove ID is the identifier every item already has.** `Item.id` and
  `WishlistItem.id` (`UUID`, in the schema since `001`) are stored, synced like
  any attribute, and already the key the app navigates by and the device's
  market rows are filed under. So nothing is added to the store, nothing is
  backfilled, and everything that existed before the update has its code
  already (criterion 17). §1 lists each claim this rests on and its test.
- **R2 — Two items can share one code, on one device, and the app must work.**
  *(Rewritten 2026-10-08; decided by the person, spec Decision 18.)* How it
  happens is in Context. What is built: the load-time trap is removed and every
  list and summary screen is shown to load with twins present (§1, G20,
  criterion 42); an import row whose code more than one stored item carries is
  left out and listed ("its Trove ID matches more than one item") and neither
  copy changes (G13, G14); a row that keeps a code first clears any market rows
  the device still holds under it (§8). What is **not** built: any repair that
  gives one twin a new code — two devices could not agree on it. Deleting one
  copy clears the state. The limits that remain while twins exist are listed in
  §1 and §9.
- **R3 — A code that belongs to something on the other list is not used.**
  *Decided by the person, spec Decision 20; criterion 44.* The row is left out
  and listed ("its Trove ID belongs to the other list").
- **R4 — A wishlist row for an entry already bought is left out.** *As drafted
  (update the entry) this was overturned by the person — spec Decision 21,
  criterion 45.* The row is listed "already bought" and the entry is untouched.
- **R5 — A wholly missing `Desire to Keep` or `Condition` column is said once.**
  *As drafted (two counted defaults per row) this was overturned — spec
  Decision 17, criterion 41.* The new rows still take the default; the
  confirmation carries one line per missing column and those cells are not in
  the count. The same on the wishlist for `Desire to Own` and `Added`, the two
  optional columns that count a default there.
- **R6 — The confirmation stays an alert.** The spec allows a sheet "if an alert
  can't hold it legibly"; legibility is a judgment for eyes, not for a plan. The
  ordinary confirmation is two or three lines. The worst case is put in front
  of the person at the Phase 3 pause with a sample pair built to produce it
  (§10) and seen on the narrowest phone in T014. If it is rejected, the sheet is
  a decision review and a sub-lettered task; `ImportCopy` hands back **lines**,
  not one string, so a sheet reuses them unchanged.
- **R7 — Copy adjusted for fit, not meaning.** An alert draws no bold, so the
  spec's sentences are used plain. The title is "Import this file?" (or "Nothing
  to import") and the counts are the message's first line, in the spec's words.
  The unreadable-cells line splits in two — new rows "will use defaults", rows
  for items already here "will be left as they are". `012`'s skip reason "more
  columns than the template" becomes "more columns than the header". `012`'s
  "The columns don't match the template" failure is retired. Three
  missing-column lines the spec does not word are worded after its one ("No
  Condition column — new items will be Excellent."): "No Desire to Keep column —
  new items will be 3 of 5.", "No Desire to Own column — new items will be 2 of
  3.", "No Added column — new items will be dated today."
- **R8 — The committed fixture is 24 invented rows, not 90.** It carries every
  feature of the person's sheet at least once (§4); the count of 90 belongs to
  their own file, which is not committed (P12) and is tried by them at the
  Phase 2 pause (criterion 2).
- **R9 — If the collection changes between the confirmation and the tap on
  Import, nothing is written and the confirmation is shown again.** *Decided by
  the person, 2026-10-09 — spec Decision 24, criterion 47.* The plan is
  recomputed at confirm (Q3). If its summary differs in any way from the one
  the person was shown — a sync arrival turning an add into an update is the
  case that matters, since they were never shown "Updates can't be undone" —
  the app writes nothing and re-presents the confirmation with the current
  numbers and one line first: "Your collection changed while this was open.
  Check the numbers again." Confirming that one applies it. G23.
- **R10 — The warning is about the import, never about sync state.** *Decided
  by the person, 2026-10-09 — spec Decision 19 as reworded, criterion 43.* As
  first decided it was to show "when iCloud has not finished syncing". The app
  cannot know that: `SyncMonitor` reads caught-up once the **first** import
  pass lands, and a long first import arrives in several
  (`specs/001-core-inventory/tasks.md:909`,
  `specs/009-sell-plan-list/plan.md:152`); and a phone that is offline is
  indistinguishable from one that is signed out (`SyncStatusCopy`). So the
  confirmation says how many rows would be **added keeping a code this iPhone
  doesn't have** — the only rows that can become twins — whenever there is at
  least one, restore or not. **Nothing reads `SyncMonitor` for it**, and nobody
  should add that back as a refinement: it would silence the warning in exactly
  the window it is for. G22.

## Proposed at planning — approved on plan approval unless overturned

### The spec's P-items, resolved

- **P1 — Trove's own names only, header first.** `ImportColumns.match` (§3)
  compares against `ExportSchema.itemHeaders` / `wishlistHeaders`, never a
  synonym table. G5.
- **P2 — `Name *`.** `ExportSchema.headerRow(_:required:)` appends `" *"` (§6);
  the reader drops one trailing star. G5, G11.
- **P3 — the same column twice refuses the file.** `HeaderError.duplicate`. G5.
- **P4 — four-digit years, one order per file.** §2. G3.
- **P5 — labelled totals rows, anywhere.** §4. G6.
- **P6 — `#N/A` counts, `NA` / `none` / `-` do not.** `ImportSchema.isBlank`
  (§2). G4.
- **P7 — not-a-code makes a new row, counted.** `Cell.unreadable` on the Trove
  ID; `asNew` counts it (§4). G13.
- **P8 — a matching row with no name updates the rest.** Nameless rows that
  carry a readable code survive parsing; the store decides (§4, §8). G12, G14.
- **P9 — counts, and "Updates can't be undone."** §5. G8, G16. Alert, per R6.
- **P10 — export keeps plain numbers and `yyyy-MM-dd`.** `ExportSchema.money`
  and `day` are untouched. G11's row literals.
- **P11 — a changed Reverb product is an ordinary update.** `apply` clears the
  device's market rows for the item first, exactly as *Change match* does
  (`ItemDetailViewModel.setMatch`), because the refresher's freshness check does
  not compare products (`MarketRefresher.swift:53`) and would otherwise show the
  old product's figure for up to an hour. A changed year or Looking For clears
  nothing, as the forms do. G14.
- **P12 — the real sheet is not committed.** R8.
- **P13 — no leading-zero protection.** A serial number is text compared as
  text; the reference doc carries the warning (§10).

### Planning choices (Q1–Q11)

- **Q1. The Trove ID is `id`, written as `UUID.uuidString`** — 36 characters,
  hyphens at fixed places, so no spreadsheet can read the whole cell as a
  number, a date or a formula. Read back with `UUID(uuidString:)` after
  trimming, which accepts either letter case. The simpler of two shapes (the
  other: a new stored code), chosen because the existing field already is one
  code per row on every device. That a spreadsheet leaves it alone is a claim
  about other people's software: **needing verification**, T013 — Google Sheets
  only; **Excel and Numbers are untested**.
- **Q2. Parse to cells, decide later.** A row is parsed once into tri-state
  cells (`empty` / `unreadable` / `value`) and read two ways by pure functions:
  `asNew` applies `012`'s defaults, `changes(against:)` applies none. Today's
  pipeline bakes defaults in at parse time, which an update must never see.
- **Q3. Parsing stays store-free and off the main actor; matching runs on the
  main actor, twice.** `plan(for:in:)` is called when the confirmation is
  staged and again at confirm, the rule the current commit already follows for
  placement (`ItemListViewModel.swift:1194`). **The second plan is applied only
  if its summary equals the staged one** (R9); otherwise nothing is written.
  The alternative, handing the service a snapshot of the store, moves model
  data across isolation to save a dictionary lookup per row.
- **Q4. Items and wishlist stay parallel implementations**, as `ImportSchema`
  already records ("each function reads as its spec table"). Shared, because
  each has two real callers with identical rules: `Cell`, `ImportColumns`,
  `ImportMatching`, `ImportSummary`, `ImportCopy`.
- **Q5. The comparison snapshot is the existing export record**, built for
  matched rows only, through `ItemExportRecord(item:includingPhoto:)` /
  `WishlistExportRecord(item:includingPhoto:)` — a new defaulted parameter
  (`true`, today's behaviour, for every export); the compare path passes
  `false`, which leaves `firstPhotoID` and the attribution nil **without
  reading `item.photos`**, so matching 300 rows faults no photo relationship on
  the main actor. No second snapshot type.
- **Q6. The shipped-width boundaries are deleted, not kept.**
  `itemSchemaBoundaries` and `wishlistSchemaBoundaries` have no reader once
  columns are found by name. What they guaranteed — every layout an earlier
  Trove wrote still imports — is pinned by fixtures of those layouts instead
  (G10).
- **Q7. `ImportSchema.cents(from:)` is widened in place.** One money grammar for
  every money column on both lists.
- **Q8. The region's date order travels like the time zone**: the service takes
  `locale:` beside `timeZone:`, the view models pass `.current` for both, and
  tests pass `en_US` and `en_GB`.
- **Q9. The confirmation stays an alert** (R6).
- **Q10. `troveID` on the two export records is `var … = nil`**, `020` Q8's
  reasoning: the many fixtures that build a record compile unchanged, both
  production builders pass it explicitly, and G11 and G14 catch either dropping
  it.
- **Q11. The commit moves out of the view models into `ItemImportStore` and
  `WishlistImportStore`** — `ItemSaleStore`'s shape (one writer, callers save).
  The commit grows from "insert" to "match, compare, insert or update, clear
  market rows"; the list view model is already 1,300 lines, and a store is
  testable without a view model.

---

## Layout and files

New production files (synchronized folders — no `.pbxproj` edit; if the build
cannot see one, stop and flag): `Trove/Import/ImportRows.swift` (`Cell`,
`SlashDateOrder`, the two row types, `ImportSheet`, `ImportColumns`, `asNew`,
the two `…Changes` types, `ImportMatching`), `Trove/Import/ImportStore.swift`
(`ImportSummary`, the two stores).

Changed: `Import/ImportSchema.swift` (grammar, the two sheet functions; the
header gate and the two `…Preview` functions deleted), `Import/ImportService.swift`
(protocol, `ImportError`, `ImportPresentation`, `ImportCopy`),
`Export/ExportSchema.swift` (the Trove ID column, the starred header row, the
record field and `includingPhoto:`; the boundaries deleted),
`Market/MarketIndex.swift` (the trap, §1), `App/UITestSeed.swift` and
`App/TroveApp.swift` (the `-seedSharedID` seed, §11),
`ViewModels/ItemListViewModel.swift`, `ViewModels/WishlistViewModel.swift`
(import section only), `ViewModels/SettingsViewModel.swift` (the two template
header rows), `Models/Item.swift`, `Models/WishlistItem.swift` (doc comments on
`id` only), `docs/csv-reference.md`, `docs/samples/README.md`,
`docs/samples/items-full.csv`, `docs/samples/wishlist.csv`.

Unchanged and must stay so: `CSVParser.swift`, `CSVWriter.swift`,
`PDFComposer.swift`, `ExportService.swift`, and both list views — the alert is
fed the same three accessors — **except one line each** (`ItemListView.swift:252`,
`WishlistView.swift:194`: the delete call passes the row's
`persistentModelID`, re-review N1, §1; with `ItemListViewModel.swift` and
`WishlistViewModel.swift`'s `delete` gaining the parameter), and **unless
T001b's UI test shows twins do not both draw**, in which case the named routine fix touches the `ForEach` identity in
`ItemListView`, `WishlistView` and `SellPlanView` (§1).

New test files: `TroveIDTests`, `ImportGrammarTests`, `ImportColumnsTests`,
`ImportSheetTests`, `ImportUpdateTests`, `ItemImportStoreTests`,
`WishlistImportStoreTests`. Extended or re-pointed: `ImportSchemaTests`,
`ImportServiceTests` (with `ImportCopyTests`, `ImportConcurrencyTests`),
`ItemListViewModelTests`, `WishlistViewModelTests`, `DashboardViewModelTests`,
`SellPlanViewModelTests`, `PlansViewModelTests`, `MarketIndexTests`,
`SettingsViewModelTests`, `ExportSchemaTests`, `DocsSampleTests`,
`ItemDuplicationTests`, `WishlistDuplicationTests`, `WishlistPurchaseStoreTests`,
`ItemSaleStoreTests`, `ItemFormViewModelTests`, `WishlistFormViewModelTests`,
`UITestSeedTests`, `TroveUITests`, `TestSupport` (the two import spies).

New fixtures and samples: `docs/samples/items-hand-kept.csv`,
`docs/samples/items-edited.csv`, `docs/samples/items-full-resaved-sheets.csv`
(recorded by the person, T013), `TroveTests/Fixtures/Import/items-020-layout.csv`
and `wishlist-020-layout.csv` (byte copies of the samples `020` shipped) with a
`README.md`. All are read by `#filePath`, as `DocsSampleTests` and
`reverbFixture` do.

---

## 1. The Trove ID is `id`, and the app with two rows sharing one (foundational)

No model change beyond doc comments on `Item.id` and `WishlistItem.id` saying
what `021` now relies on. The plan's whole second half rests on these claims;
each has the test that would catch it false, or is marked as unreachable.

| Claim | Test |
|---|---|
| `id` is a stored attribute: a value assigned before insert (the kept-code path) is what a second context reads back | `TroveIDTests`, second `ModelContext` (G1) |
| An edit through either form, a sale, and a return to the collection leave `id` as it was | `ItemFormViewModelTests`, `WishlistFormViewModelTests`, `ItemSaleStoreTests` (G1) |
| A Copy has a new `id` on both lists (criterion 19) | `ItemDuplicationTests`, `WishlistDuplicationTests` (G1) |
| An item made by Mark as bought has an `id` that is neither the entry's nor reused (criterion 19) | `WishlistPurchaseStoreTests` (G1) |
| Rows the shipped build wrote export a code under this build, distinct, and the same after a relaunch (criterion 17) | T014(a), on a persistent store. **There is no schema change, so this is not a migration check** — it shows an unchanged stored attribute being read from disk, and nothing about a second device |
| The code is the same on a second device (criterion 40) | **Needing verification** — no test in `TroveTests` reaches CloudKit; `SYNC-CHECKS.md` step 3.13 |
| The store does not guarantee one row per code (CloudKit forbids `@Attribute(.unique)`; `CloudKitSchemaTests` is the standing guard), **and the app works when two rows share one** (criterion 42) | The audit below; G20 |
| An `Item` and a `WishlistItem` must never share a code — `MarketFigureRecord.subjectID` is unique and `MarketLocalStore.figure(for:)` does not filter by kind | Decision 20's rule, G13 |

If any G1 leg fails as written, T001 stops and the question goes to a decision
review: the plan has no second design for the code.

**The audit of id-keyed sites** (every `Dictionary` built from ids, every
`first(where:)` / `firstIndex(where:)` on `id`, every `#Predicate` on `id`,
every `ForEach` identified by it), with two rows sharing an `id`:

- **Traps — fixed.** `MarketSummary.summaries(forSubjects:)`
  (`MarketIndex.swift:92`) becomes `Dictionary(_:uniquingKeysWith:)`, keeping
  the first; both twins then read the one figure filed under their code. It is
  the only `uniqueKeysWithValues` in production. Callers:
  `ItemListViewModel.load()`, `WishlistViewModel.load()`,
  `DashboardViewModel.load()`, `SellPlanViewModel`'s load.
  `PlansViewModel.swift:226` already uses `uniquingKeysWith` and says why.
- **Deletes the wrong copy — fixed** *(re-review N1, 2026-10-09; applied by
  the orchestrator under the review-loop cap)*. A list's delete removes the
  copy the person acted on (spec, Sync: "deleting one copy removes exactly that
  one"). Twins are **not** identical — the copy an import made has no photos,
  plan links or market rows, the synced original has all of them — so removing
  the other one loses photos on every device, and the reference doc tells the
  person to clear twins by deleting one. Today `ItemListViewModel.delete`
  (`:570`) and `WishlistViewModel.delete` (`:263`) resolve
  `items.first(where: { $0.id == id })`, which is "the first", not "the one
  swiped". Both gain `row: PersistentIdentifier? = nil` and, when it is given,
  resolve the row by `persistentModelID` instead of by `id`;
  `ItemListView.swift:252` and `WishlistView.swift:194` pass
  `item.persistentModelID`. (An equivalent shape is fine; the requirement is
  that the row deleted is the row acted on.) The market rows under the shared
  code are still cleared, so the survivor has no figure until its next
  refresh.
- **Safe as written.** `MarketIndex.load` (`uniquingKeysWith`); the fetches by
  `id` with `fetchLimit = 1` (`ItemDetailViewModel:58`,
  `WishlistDetailViewModel:81`, `SellPlanViewModel:281`,
  `MarketRefresher:109`/`:114`) return one of the two; the view models'
  `first(where:)` sites act on the first in the loaded array.
- **Works, with a stated limit while twins exist** — each clears when one copy
  is deleted, none is fixed here, and each is this plan's reading of the
  spec's "work normally", said plainly at the Phase 3 pause as overturnable:
  the page opened from either row is whichever copy the fetch returns, so an
  edit made there lands on that copy, which may not be the row tapped; the
  reorder buttons and Copy act on the first copy; the Sell Plan's toggle and
  selection work by `id`, so selecting or deselecting one twin moves both
  (found by T001a's audit).
- **Plans rows — fixed** *(decision review after T001b, 2026-10-18)*. T001b's
  UI test showed SwiftUI drawing the first twin's content in every row that
  shares an id. `PlanRow` gains `rowID: PersistentIdentifier`, set from
  `wanted.persistentModelID`; `PlanRow.id` stays the wanted entry's `UUID`, so
  the router push and the `.sheet(item:)` / alert state are unchanged.
  `PlansView` keys `ForEach(viewModel.rows, id: \.rowID)`. `entries` is keyed
  by `PersistentIdentifier` (the `uniquingKeysWith` and its comment go — the
  key cannot repeat); `makePurchaseFormViewModel(for:)` and
  `markBought(_:purchase:)` look up `entries[row.rowID]`; `deletePlan` takes the
  row or its `rowID` instead of the `UUID`. Fixing the drawing alone would turn
  a visible bug into a wrong-target delete or purchase. Opening the page from a
  Plans row (push by `UUID`, `fetchLimit = 1`) stays a stated limit, as on every
  screen. The two sold-row sites (`ItemListView.swift:470`,
  `SellPlanView.swift:520`) take the routine fix too, each shown needed by a UI
  leg first — sold twins are reachable by a restore of sold items, and by
  marking both owned twins sold from one plan. T001c.
- **Not settled by a unit test: the five `ForEach(…, id: \.id)` over items**
  (`ItemListView.swift:336`, `:470`, `WishlistView.swift:336`,
  `SellPlanView.swift:450`, `:520`) and `PlansView`'s rows. SwiftUI's behaviour
  with repeated ids is not specified. **T001b's UI test observes it** on a seed
  holding twins. If both twins do not draw, or the screen misbehaves, the
  routine fix inside T001b — no new decision — is `id: \.persistentModelID` at
  those sites: the store's own row identity, which cannot repeat.

**Testable claims** (G20): with two stored rows sharing an `id` and one figure
row filed under it, each of the four `load()`s — and `PlansViewModel`'s —
returns and lists both; deleting the twin loaded **second** leaves, on a
second context, one row with that `id` and it is the first twin's — and the
reverse; the same for two `WishlistItem`s; the UI test above. The
named mutation, `uniqueKeysWithValues` restored, crashes the run — recorded as
the red it is.

## 2. The reader's grammar

The parsers live in `ImportSchema`; the two small types below open
`ImportRows.swift`. All pure and `nonisolated`.

```swift
/// One cell, read. `empty` covers a blank cell, an N/A, and a column the file
/// does not have — the spec's three ways of saying nothing.
nonisolated enum Cell<Value: Sendable & Equatable>: Sendable, Equatable {
    case empty, unreadable, value(Value)
}

nonisolated enum SlashDateOrder: Sendable, Equatable {
    case monthFirst, dayFirst
    /// The phone's region: day-first iff "d" comes before "M" in the locale's
    /// own "yMd" pattern (en_US M/d/y, en_GB dd/MM/y, ja_JP y/M/d → month-first).
    static func regional(for locale: Locale) -> SlashDateOrder
}
```

- **`isBlank(_:)`** — after `FieldNormalization.trimmed`: empty, or `n/a` /
  `#n/a` in any letter case (P6). Every cell goes through one accessor that
  applies it, so "in any column" is structural.
- **Money, `cents(from:)` widened** (Q7): an optional single leading `$`, `€`,
  `£` or `¥`, **then any number of spaces** (spec Decision 22: `$ 3,179.95`);
  then either digits with no commas (as today) or groups — one to three digits,
  then one or more `,ddd`; then an optional `.` and one or two digits. Nothing
  else: no sign, no brackets, no trailing text, no space without a symbol
  before it. `1,25`, `1.250,00`, `12,34,567`, `$`, `-5`, `(5.00)`, `5 $` and
  `500 USD` are nil. The function returns cents and nothing else, so the symbol
  has no way to reach the currency; that the *row* reader does not look at it
  either is G6's leg (a `€` price beside a blank `Currency` is `USD`).
  Still overflow-checked integer arithmetic, no `Locale`, no `Decimal`.
- **Dates.** `day(from:timeZone:order:)` — `order: SlashDateOrder? = nil`.
  `yyyy-MM-dd` reads exactly as before. With an order, `d{1,2}/d{1,2}/d{4}` is
  also read in that order, through the same Gregorian round-trip check that
  rejects 2/30. A two-digit year, another separator, or a slash date with no
  order given is nil.
- **`slashDateOrder(in:region:)`** over every cell in the file's date columns:
  a cell is evidence for day-first when its first number is above 12 and its
  second is not, for month-first the other way round, and for nothing otherwise.
  One kind of evidence → that order, decided by the file. None, or both → the
  region's order, and the sheet records it (`regionDateOrder`) **only if the
  file has at least one slash-shaped date**, so a file of ISO dates says nothing
  about order. Under a contradiction the dates that do not fit the region's
  order are simply unreadable by the rule above.
- **`troveID(from:)`** → `Cell<UUID>`: blank → `empty`; `UUID(uuidString:)` of
  the trimmed text → `value`; anything else → `unreadable`.

**Testable claims** (G2–G4, `ImportGrammarTests`): criteria 11 and 46 to the
cent; `ExportSchema.money` output still round-trips; criteria 12 and 13 in both
orders with explicit locales; a lower-case and a space-padded code read.
`ImportSchemaTests.nonCanonicalMoneyIsRejected` currently lists `"$5"` and
`"1,250.00"` as rejected and is **rewritten** — those two move to the accepted
list, the rest stay.

## 3. Finding the columns

```swift
nonisolated struct ImportColumns: Sendable {
    let width: Int            // header cells, after shaping
    let unused: [String]      // unrecognised names as written, file order, no blanks, no repeats
    func position(of name: String) -> Int?   // `name` must be one of `known` — a typo traps in any test that parses
    enum HeaderError: Error, Equatable { case wrongList, missing([String]), duplicate(String) }
    static func match(header: [String], known: [String], required: [String],
                      otherRequired: [String]) throws(HeaderError) -> ImportColumns
}
```

A header cell is canonicalised — trimmed, one trailing `*` dropped, trimmed
again, lowercased — and compared with the lowercased `known` names, which are
read from `ExportSchema.itemHeaders` / `wishlistHeaders` and never copied (the
existing rule). In order: this list's required names missing **and** every one
of the other list's present → `.wrongList`; any required name missing →
`.missing`, in schema order; a recognised name twice → `.duplicate`. An empty
file is a header of no cells, so it is "missing" all of them — there is no
separate empty-file case. Required: `Name`, `Purchase Price`, `Purchase Date`;
on the wishlist `Name`, `Estimated Cost` — declared once, on `ExportSchema`
(§6), because the starred header is written from the same list.

`shaped(_:)` is unchanged: trailing empty cells stripped, wholly empty rows
dropped, so the first non-empty row is the header (P1).

**Testable claims** (G5, `ImportColumnsTests`): criteria 3, 4, 5, 7, 8, 10 at
the header level. `ImportSchemaTests.missingExtraRenamedAndReorderedColumnsAllMismatch`
pins the old rule and is **rewritten** (T007): missing required → named; extra
→ listed in `unused`; renamed required → missing; renamed optional → unused;
reordered → matched. The three wrong-list tests are re-pointed and must still
pass for every shipped layout of the other list.

## 4. Rows and sheets

```swift
nonisolated struct ItemImportRow: Sendable, Equatable {
    let rowNumber: Int
    let troveID: Cell<UUID>
    let name, category, purchaseLocation, conditionNotes, serialNumber, notes,
        saleLocation, saleNote: Cell<String>          // text is never unreadable
    let purchasePrice, currentValue, salePrice: Cell<Int>
    let currency: Cell<String>
    let purchaseDate, soldDate: Cell<Date>
    let desireToKeep, reverbProductID, year: Cell<Int>
    let condition: Cell<Condition>
    let bought: Cell<NewOrUsed>
}
// WishlistImportRow: troveID, name, category, notes; estimatedCost; currency;
// desireToOwn (1...3), reverbProductID, year; added: Cell<Date>; lookingFor.

nonisolated struct ImportSheet<Row: Sendable>: Sendable {
    let rows: [Row]                     // file order
    let skipped: [SkippedRow]
    let unusedColumns: [String]
    let totalsRowNumbers: [Int]
    let regionDateOrder: SlashDateOrder?
    /// Decision 17: optional columns the file does not have at all whose blank
    /// is a counted default for a new row — `Desire to Keep`, `Condition`; on
    /// the wishlist `Desire to Own`, `Added`. Schema names, schema order.
    let missingDefaultColumns: [String]
}
```

`ImportSchema.itemsSheet(from:timeZone:locale:)` and `wishlistSheet(…)` replace
`itemsPreview` / `wishlistPreview`. **Cells under a column the app does not
know are never looked at** — not by the blank test, not by the totals test, not
by anything (spec Decision 23). Per data row, in this order:

1. More cells than the header has → skipped, "more columns than the header"
   (R7). Fewer → padded, as today.
2. Every recognised cell blank by `isBlank` → dropped silently (so a row of
   `N/A`s, or one filled only under an unknown column, is a blank row).
3. **Totals row** — the name is blank or, lowercased, one of `total`, `totals`,
   `subtotal`, `sum`; the Trove ID cell is blank; at least one other recognised
   cell is filled; and every other filled recognised cell sits in a money
   column (`Purchase Price`, `Current Value`, `Sale Price`; `Estimated Cost`)
   and reads as an amount → its number joins `totalsRowNumbers`, and it is
   neither a row nor a skip.
4. No name and no readable Trove ID → skipped, "no name". A nameless row with
   a readable code is kept: only the store knows whether it matches (P8).
5. Otherwise a row, every cell read by §2.

**`asNew(now:missingColumns:)`** on each row type returns
`ValidatedRow<…ExportRecord>?` — nil only when the name is empty — applying
exactly today's field policy and counts (the spec's "the defaults of `012` are
for new rows only"): price, date, desire and condition default and count when
empty or unreadable; currency, current value, Reverb product, year and Bought
count only when unreadable; the sale is the pair rule, counted once; an
unreadable Trove ID counts once (P7). **One difference from today (Decision
17)**: a default taken because the column is in `missingColumns` is still
taken and is **not counted**. The currency comes from the `Currency` cell and
nowhere else. The record carries `troveID` when the cell held a code.

**The fixture** `docs/samples/items-hand-kept.csv` (R8). Its header is the
person's, exact names and order, confirmed against their file by the
orchestrator:

```
Name,Category,Purchase Price,Currency,Purchase Date,Purchase Location,Current Value,Desire to Keep,Condition,Serial Number
```

24 invented item rows in four groups with an all-comma row between groups; then
three all-comma rows and a totals row whose two amounts are the columns' true
sums, written `"$12,345.67"`-style. Among the rows: quoted prices with commas
and unquoted `$395.54`-style ones, two `$0.00` purchase prices, one bare `500`
in Current Value, every date `M/D/YYYY` with at least three days above 12,
conditions Excellent / Very Good / Good only, at least four serial cells `N/A`
and six blank, one serial with a leading zero and one with a `+`, one name with
a doubled quote (`"… 42"" TV"`), one name with a trailing space. LF endings, no
BOM, no trailing newline — what Sheets downloads, and how the person's file
ends.

**Testable claims** (G6, G7, G21, `ImportSheetTests`): criterion 1 over the
fixture (24 rows, no skips, no defaults through `asNew`, one totals row at its
exact number, `regionDateOrder == nil`, `missingDefaultColumns` empty);
criterion 3 — the fixture's columns shuffled give equal rows; criteria 6 and 41
— a required-only file names `Desire to Keep` and `Condition` as missing and
its rows count **zero** defaults, while a file that *has* the columns with
blank cells still counts them; criterion 14 per column; criterion 15 including
a labelled row mid-file, a nameless row with a date (still skipped), and a
totals row with a sum under an unknown column (still a totals row, Decision
23); criterion 16 for the wishlist. A typo in a column lookup reads that column
as empty for ever — G14's round trip, which asserts every column, is what
catches it.

## 5. The service, the summary and the words

```swift
nonisolated protocol ImportService: Sendable {
    @concurrent func parseItems(at url: URL, timeZone: TimeZone, locale: Locale) async throws -> ItemsImportSheet
    @concurrent func parseWishlist(at url: URL, timeZone: TimeZone, locale: Locale) async throws -> WishlistImportSheet
}
nonisolated enum ImportError: Error, Equatable {
    case unreadable, undecodable, malformedQuoting, tooLarge      // unchanged
    case wrongList, missingColumns([String]), duplicateColumn(String)   // replace headerMismatch(wrongList:)
}
nonisolated struct ImportSummary: Sendable, Equatable {
    var added = 0, updated = 0, unchanged = 0
    var skipped: [SkippedRow] = []
    var defaultedOnNew = 0
    /// Unreadable cells on every row that matched an item — updated or unchanged.
    var unreadableOnUpdates = 0
    var unusedColumns: [String] = []
    var totalsRows: [Int] = []
    var unusedSaleRows = 0
    var regionDateOrder: SlashDateOrder? = nil
    var missingDefaultColumns: [String] = []
    /// Decision 19: rows that will be added **keeping a code from the file** —
    /// a subset of `added`. Never includes a matched row, a row with no code,
    /// or a kept-code row that was skipped.
    var keptCodeAdds = 0
    var writesAnything: Bool { added + updated > 0 }
}
nonisolated enum ImportPresentation<Row: Sendable>: Sendable {
    /// `recounted`: shown again because the store changed under it (R9).
    case confirmation(sheet: ImportSheet<Row>, summary: ImportSummary, recounted: Bool)
    case failure(title: String, message: String)
}
```

`ImportCopy`, every string pinned by literal in `ImportCopyTests`:

- `confirmationTitle(summary:)` — "Import this file?", or "Nothing to import"
  when `!writesAnything`.
- `confirmationLines(summary:target:recounted:) -> [String]`, in this order,
  each only when it has something to say: when `recounted`, "Your collection
  changed while this was open. Check the numbers again."; the counts ("90 items
  will be added." / "12 items will be updated." / "12 items will be updated and
  3 added."); "75 rows are unchanged."; the skipped block as today ("Skipping 2
  rows:", "Row 7 — no name", "…and 3 more rows.") and, when any skip is a shared
  code, "Clear the Trove ID on the row that's a new item."; "4 missing or
  unreadable cells on new rows will use defaults."; "2 unreadable cells on rows
  for items you already have will be left as they are." — **this is the line
  that reports an unreadable cell on an unchanged row as well as on an updated
  one**; one line per `missingDefaultColumns` entry, **only when `added > 0`**
  (R7's four sentences); "Not used: Mount, Insured."; "Row 108 looks like a
  totals row and was left out." (several: "3 rows look like totals rows and
  were left out."); "3 rows have sale details for items you still own. Mark
  them sold in the app."; "Dates read as month/day/year, from this iPhone's
  region."; whenever `keptCodeAdds > 0`, the unknown-codes warning with that
  count (R10) — "90 rows have a Trove ID this iPhone doesn't have yet. If
  iCloud is still bringing your collection down, wait — importing now adds them
  a second time." (one: "1 row has a Trove ID this iPhone doesn't have yet. If
  iCloud is still bringing your collection down, wait — importing now adds it a
  second time."); and last, whenever `updated > 0`, "Updates can't be undone."
  The two warnings sit together at the foot, nearest the buttons. With no line
  at all, the one line is today's "No problems found." Singulars are spelled
  out in the tests.
- Skip reasons (`ImportSchema.SkipReason`): `noName`, `extraColumns` ("more
  columns than the header"), `sameTroveID(asRows:)` ("same Trove ID as row 15" /
  "…as rows 15 and 16"), `ambiguousTroveID` ("its Trove ID matches more than one
  item"), `otherListTroveID` ("its Trove ID belongs to the other list"),
  `alreadyBought` ("already bought").
- Failures: `.wrongList` keeps its sentence; `.missingColumns` — "This file is
  missing Purchase Price and Purchase Date. Trove needs the columns marked * in
  the template. Nothing was imported."; `.duplicateColumn` — "This file has more
  than one Purchase Price column. Remove one and try again. Nothing was
  imported."

The view models keep `importAlertTitle`, `importAlertMessage` (the lines joined
by newlines) and `importOffersConfirmation` (`summary.writesAnything`), so
**neither list view changes**. `importCSV(from:)` parses off the main actor,
then calls the store's `plan` for the summary; a throw there presents the
unexpected-failure copy.

## 6. Export, the star and the templates

`ExportSchema`:

- `itemHeaders` and `wishlistHeaders` gain `"Trove ID"` as the last element
  (20 and 11). They stay the canonical **names**, which the reader matches.
  **One temporary seam, stated so it is not mistaken for design**: the reader is
  built (T004) before export writes the column (T008), so `troveIDHeader` is
  declared on `ExportSchema` at T003 and the reader's known names are the array
  plus that constant until T008 puts it in the array and removes the addition.
- `itemRequiredHeaders = ["Name", "Purchase Price", "Purchase Date"]`,
  `wishlistRequiredHeaders = ["Name", "Estimated Cost"]`.
- `headerRow(_:required:)` → the names with `" *"` after each required one;
  `itemHeaderRow` / `wishlistHeaderRow` are what `itemsTable` /
  `wishlistTable` and the two Settings templates write.
- The two records gain `var troveID: UUID? = nil` (Q10), filled from `item.id`
  by each `init(item:includingPhoto:)` (Q5); the two row functions append
  `record.troveID?.uuidString ?? ""`.
- `itemSchemaBoundaries` and `wishlistSchemaBoundaries` are deleted (Q6), with
  the doc comment on `itemHeaders` saying why append-only is still the rule
  (files are read by eye) though the reader no longer needs it.

Every CSV path builds its rows through the record initialisers and its table
through the two table functions, so all five exports and both templates follow
by construction — and that is a claim, so G11 pins each path's output. The PDF
builds from the same records and must not show the code: `PDFEntry` does not
read `troveID`, and G11 asserts no field of any entry carries it. An app from
before this spec cannot read these files (its gate compares `Name *` with
`Name`): stated in the reference doc, not worked around.

## 7. What an update changes

```swift
nonisolated struct ItemChanges: Sendable, Equatable {
    var name, categoryPath, currencyCode, purchaseLocation, conditionNotes,
        serialNumber, notes, saleLocation, saleNote: String?
    var purchasePriceCents, currentValueCents, desireToKeep, reverbProductID, year,
        salePriceCents: Int?
    var purchaseDate, soldDate: Date?
    var condition: Condition?
    var bought: NewOrUsed?
    var unreadableCount = 0
    var hasUnusedSaleCells = false
    var writesNothing: Bool
}
extension ItemImportRow {
    func changes(against current: ItemExportRecord, category: String?, timeZone: TimeZone) -> ItemChanges
}
// WishlistChanges / WishlistImportRow.changes(against: WishlistExportRecord, …) likewise.
```

**A field is non-nil only when it is to be written; the type cannot express a
clear**, which is spec Decision 10 held by construction. The rule, per cell:

- `empty` → nothing. `unreadable` → nothing, `unreadableCount += 1`. No default
  is reachable from this function — it never calls `asNew`.
- `value` → written **only if it differs from what re-reading the item's own
  export would give**: text against the item's trimmed text, **with CRLF and CR
  read as LF on both sides** — a multi-line note is the cell a spreadsheet's
  re-save is likeliest to touch without the person changing it; money, desire,
  product, year, condition, Bought by equality; **dates by calendar day** in
  the import's time zone (`ExportSchema.day` of both), never by instant — an
  item's stored date carries a time of day the file does not, and comparing
  instants would report every row of an untouched export as updated and rewrite
  every date to midnight; the category after the store has canonicalised its
  casing (`category:` — nil when the cell is empty).
- **The sale.** When `current.soldDate != nil`, the four sale cells follow the
  rule above, each on its own — a correction, no pair rule. When the item is
  owned, any filled sale cell sets `hasUnusedSaleCells` and is otherwise
  ignored: not written, not counted as unreadable (criterion 34).

Criterion 24 asks for "empty, `N/A`, a missing column" over three fields. **One
of its nine cells cannot exist**: a file with no `Purchase Date` column is
refused whole (criterion 5), so "missing column × purchase date" is never read
by this function. No task claims it.

`ImportMatching.outcomes(ids:storedCounts:refused:)` — pure, shared by both
lists; `refused` maps a code to the skip reason that bars it (the other list's
codes; on the wishlist, bought entries' codes). Each row gets one of
`new(keeping: UUID?)`, `update(UUID)`, `sharedInFile(with: [Int])`,
`ambiguousInStore`, `refused(String)`, tested in this order: an `empty` or
`unreadable` code → `new(keeping: nil)`; a code on two or more rows of the file
→ `sharedInFile` for all of them, whatever the store holds; a code in `refused`
→ `refused` with its reason (Decisions 20, 21); a code on more than one stored
row → `ambiguousInStore` (Decision 18); on exactly one → `update`; on none →
`new(keeping:)`.

**Testable claims** (G12, G13, `ImportUpdateTests`, no container): criteria 23–26
and 34's four legs, one field at a time; every fixture value differs from the
field's default **and** from the item's current value, so a broken path cannot
pass by coincidence. This proves the rule on a struct; **what writes onto an
`Item` is `apply`, and §8's guards are what hold it**. Named mutations in §13.

## 8. The two stores and the commit

```swift
enum ItemImportStore {                      // MainActor by the project default
    struct Plan { let adds: [ValidatedRow<ItemExportRecord>]
                  let updates: [(item: Item, changes: ItemChanges)]
                  let summary: ImportSummary }
    static func plan(for sheet: ItemsImportSheet, in context: ModelContext,
                     timeZone: TimeZone, now: Date) throws -> Plan
    /// Callers save, and roll back on a throw. Throws only from a market clear.
    static func apply(_ plan: Plan, in context: ModelContext, now: Date) throws
}
// WishlistImportStore: the same two functions over WishlistImportSheet.
```

`plan` fetches every `Item` (owned and sold — matching is against the whole
table, which is what lets a row correct a sold item) and the other list's ids
for `refused`; on the wishlist, entries still wanted are the matchable set and
**bought entries' ids go into `refused` as "already bought"** (Decision 21). It
runs `ImportMatching`, then per row: `new` → `asNew` with the sheet's
`missingDefaultColumns` (nil → skipped, "no name"; otherwise an add, and one
more in `keptCodeAdds` when the outcome keeps a code); `update` → canonicalise the
category, snapshot the item without its photo (Q5), `changes`; an empty change
set counts as unchanged; every other outcome → a skip with its reason. It
writes nothing.

`apply` inserts the adds at the end of custom order in file order — today's
commit, moved: placement computed here, category casing resolved in file order,
a readable sale pair arriving sold, the wishlist's `Added` restoring
`createdAt`. For a row that **keeps a code** it first calls
`MarketLocalStore.clear(subjectID:)` for that code — an item deleted on another
device leaves its local market rows behind by design
(`MarketIndex.swift:99`), and a re-added item must not inherit them — then sets
`item.id` **before** insert. It then writes each change set **field by field,
each assignment inside its own `if let`** (condition through `item.condition`,
so Very Good keeps `020`'s stored pair; the sale through `item.sale`), clears
the device's market rows first when the Reverb product changes (P11), and
stamps `updatedAt` on updated items only. **An unchanged row writes nothing at
all** — not even `updatedAt` — so re-importing an untouched export dirties no
record and sends nothing to iCloud.

`confirmImport()` keeps its shape and its reason (the presentation is captured
in the button's synchronous window — the `012` T017 device finding): capture
the sheet and the staged summary, clear the presentation, return unless
`summary.writesAnything`; then in the task `plan` again. **If the new summary
is not equal to the staged one, write nothing and present
`.confirmation(sheet:, summary: new, recounted: true)`** (R9). Otherwise
`apply`, `save()`, and on any throw `rollback()` — which now also discards
half-applied updates — and the save-failure copy. Never touched by any path:
photos, sell-plan links, `sortOrder` of an existing row, and the market rows of
an item whose product did not change.

**Testable claims** (G14, G15; persisted assertions on a second `ModelContext`).
The store-level guards the pure tests cannot give, on both lists:

- an item with **every optional field filled** and a row that changes one
  field: every other stored field is what it was — at least one text, one money
  and one date field named in the assertion;
- a matched row with an empty price, `abc` for the date and `N/A` for the
  serial: the three stored values unchanged, `unreadableOnUpdates == 1`;
- a file with no `Serial Number` or `Current Value` column: both unchanged;
- a matched row with an empty Name: updated, name kept, not skipped.

And: criterion 22 over an export of awkward values (a mid-afternoon purchase
date, a sold item, Very Good, a nil value, padded notes, **a note with line
breaks**) — zero added, zero updated, every row unchanged, every `updatedAt` as
it was; criteria 27–33; 34 end to end; 42's import half and 44; the kept-code
market clear. Wishlist: criterion 35, `Added` and `Looking For` included, and
criterion 45. On both lists: criterion 43 (G22) — `keptCodeAdds` is the number
of rows added keeping a code, zero when every code-carrying row matches and
zero for a file with no codes; and criterion 47 (G23) — a store changed between
staging and confirm writes nothing and re-presents, and confirming that one
applies it.

## 9. What is deliberately not built, and what is untested

- No mapping screen, no synonyms, no per-item preview, no undo (spec non-goals).
- No repair of two rows sharing a code (R2), and no fix for the limits §1 lists
  while they exist.
- **No sync-state check behind the unknown-codes warning** (R10): it shows on a
  genuine restore too, by the person's decision.
- No test-only launch argument that stages an import. The system file picker
  has kept the import flow out of the UI suite since `012`; a seed that *stages
  a write* is a wider branch than the existing ones. (`-seedSharedID`, §11, is
  the ordinary kind: it adds rows to the in-memory store and nothing else.)
  **Stated plainly: the import alert on screen is covered by no automated
  test.**
- **`confirmImport()`'s rollback on a failed save is untested.** It now guards
  half-applied, irreversible updates, and a failing `save()` cannot be forced
  on an in-memory store. What exists is `ImportWiringTests`' scan that the call
  is there — which pins a spelling — and G14's test that `rollback()` after
  `apply` restores the stored values. The failure path itself has never run.
- **The confirmation coming back (R9) is seen once on a forced trigger
  (T014(e)), never under a real sync arrival, and by no automated test**
  *(re-review N2, 2026-10-09)*. The view model's behaviour is G23's. Whether
  SwiftUI re-presents an alert whose binding went false and true inside one
  dismissal is the mechanism at risk: `confirmImport()` nils
  `importPresentation` in the button's synchronous window, the alert's
  binding setter (`ItemListView.swift:298`–`301`) writes nil on dismissal, and
  R9 sets a new `.confirmation` from inside the task milliseconds later. This
  seam has broken before — the comment at `ItemListViewModel.swift:1172`–`1180`
  records `012`'s T017 finding, where the same ordering made Import silently
  do nothing and "the unit tests couldn't see it". If it fails, the person
  taps Import, the alert vanishes, and nothing is imported and nothing is
  said. So it is instrumented once on the device before the tests are trusted
  to speak for it (`CLAUDE.md`): one uncommitted line forcing the comparison
  unequal exercises the real path with no sync arrival needed.
- No `ImportPreview` compatibility shim: the type is deleted, and the existing
  field-policy tests are re-pointed through one test-side helper (§13, G10).

## 10. Docs and samples

`docs/csv-reference.md` is rewritten around the new rules and **opens with the
hand-kept-sheet loop**: import your sheet once, then work from Trove's export,
because only the export has the Trove IDs that make a re-import an update.
Then: columns found by name, the starred ones required, and what a missing
optional column does; the two tables with `Trove ID` as rows 20 and 11 and an
"on an update" column beside "if blank"; prices, dates and the order rule,
`N/A`, totals rows; added / updated / unchanged and what an update never
touches; rows that are left out and why (shared, other list, already bought,
more than one item); sold status; what fails the whole file; the caveats —
leading zeros (P13), files move forward not back, and **importing a backup onto
a phone that is still filling from iCloud leaves everything twice with one
code, what the confirmation's warning about Trove IDs "this iPhone doesn't have
yet" is telling you, why it also appears on an ordinary restore, and how to
clear twins** (R2, R10).

Samples (`docs/samples/`, each pinned by `DocsSampleTests`):

- `items-full.csv`, `wishlist.csv` — rewritten in the layout the app now writes
  (starred header, 20 / 11 columns, BOM, CRLF) with fixed invented Trove IDs;
  imported twice, the second import reports every row unchanged. **The first
  import of `items-full.csv` into an empty collection is the unknown-codes
  warning's sample**: all twelve rows are added keeping a code, so the
  confirmation carries the warning with 12; the second import carries none.
  `items-full.csv` keeps at least one note with a line break in it — T013's
  recording must show what a spreadsheet does to it.
- `items-edited.csv` — **new**, to import after `items-full.csv`: three rows
  edited, two rows sharing one code, one owned row with sale cells filled, one
  unreadable cell, one new row with no code, **one new row carrying a code
  `items-full.csv` does not have**, an unknown column, a totals row, slash
  dates that do not settle their order, and no `Condition` column. Its
  confirmation shows every line §5 can produce, which is what R6 needs in front
  of eyes.
- `items-hand-kept.csv` — §4's fixture.
- `items-partial.csv`, `items-resaved.csv` — untouched: the 12- and 14-column
  layouts, still importing.
- `bad-headers.csv` — untouched; it now fails as "missing Name", and the README
  says so.
- `items-full-resaved-sheets.csv` — T013.

`TroveTests/Fixtures/Import/` holds byte copies of the `items-full.csv` and
`wishlist.csv` that `020` shipped (19 and 10 columns), made before those
samples are rewritten — the evidence for criterion 9's last two layouts.

## 11. UI tests, the device pass and the sync checks

**One new UI test, one new seed** (T001b). `-seedSharedID`, its own argument,
gated on the store the app built being the in-memory one (the `-seedSold`
pattern; `UITestSeedTests` shows it refusing a persistent store): two owned
items sharing one `id` with different names and one figure row filed under it,
two wanted entries sharing another, one of them with a sell plan holding both
twins. `testTwoRowsSharingOneIDListAndOneDeletes` (criterion 42): the Items tab
shows both names; the Dashboard, the Wishlist (both wanted names) and the Plans
tab open; the seeded sell plan lists both twins; deleting the twin listed second removes that name and leaves the
first twin's. Every existing UI test keeps its starting state.
The import flow itself stays out of the UI suite (§9).

`scripts/verify.sh ui` runs at each phase end as regression, and twice back to
back after the device pass — **run by the orchestrator, after the last section
returns**, never by a section.

**Device pass** (T014, `general-purpose` agents, one dispatch per section, each
given only its own section and returning a pass/fail list; any failure goes to
the `sdd-implementer` as a diagnosis bundle and is logged as a sub-lettered
task). A section that cannot drive the system file picker returns "could not
perform" and its checks fall to the person, said so in the close-out:
(a) **the code on a store the shipped build wrote** — `main` is built **in a
separate git worktree**, never by switching this one, and installed; two items
(one sold) and a wanted entry are added; this branch is installed over it;
owned-and-sold and the wishlist are exported and the staged files read from the
app's container: every row has a well-formed code, all different; terminate,
relaunch, export again: the same codes. What this shows and does not is in §1's
table; (b) **the confirmation, by eye** — iPhone SE (3rd generation) and the
pinned phone, both appearances: `items-full.csv` then `items-edited.csv`; every
line readable, both buttons reachable, and the `bad-headers.csv` failure alert
(R6); (c) **300 rows** — a generated file of 300 new rows, then its export with
half the rows edited and 150 new rows appended: the busy badge draws, the list
answers a scroll while it runs, the counts read 150 updated / 150 unchanged /
150 added (criterion 38's feel); (d) **relaunch** — what (b) and (c) wrote is
still there; (e) **the confirmation coming back** (criterion 47, on screen) —
in the separate worktree, at this branch's head, with one **uncommitted** line
changed so the first confirm takes the re-present path: import
`items-full.csv`, tap Import, and the alert returns with "Your collection
changed while this was open. Check the numbers again." first; Import on the
returned alert writes the twelve rows; repeat and Cancel writes nothing; once
on Items, once on the Wishlist; `git status` shown before and after, nothing
committed (§9).

**`specs/SYNC-CHECKS.md` gains two steps** under Part 3 (both devices on the new
build), drafted here so the close-out copies them: *"3.13 — An item's Trove ID
is the same on both devices. Do: on A, export the collection as CSV; on B,
export it too, including something added before this update. You should see:
the same code beside the same item in both files."* and *"3.14 — An update made
by importing reaches the other device. Do: on A, change three items' notes in
the exported sheet and import it. You should see: on B, the three notes, and
nothing else changed. Known edge, not a failure: a backup imported onto a phone
that has not finished filling from iCloud leaves each item twice with one code
(`021` Decision 18) — the confirmation warned of it beforehand, both show, a
later import leaves them out and says why, and deleting one copy clears it."* Criterion 40 stays unticked until then.

## 12. Close-out

T015, on an evidence bundle: criteria ticked with citations — **40 an honest
partial**, **20 ticked only if T013's recorded file exists** and with "Excel
and Numbers untested" beside it, 43 and 47 on T010's and T011's Done notes, 2
from what the person said at the Phase 2 pause; "Superseded in part by `021`" pointers beside
`specs/011-data-export/plan.md:113`, `:132` and `:150`,
`specs/012-data-import/spec.md:45`, `:60` and `:94`, the header-gate and
money-and-dates paragraphs of `specs/012-data-import/plan.md` (§"Row pipeline",
§"Money and date parsing"), `specs/002-live-market-value/plan.md` and
`specs/006-mark-as-sold/plan.md` where each introduced or grew the boundary
widths, and `020`'s plan Q7 — never an edit to a shipped line; the two
SYNC-CHECKS steps; `README.md`'s import and export bullets; the drafted
`ROADMAP.md` and `DECISIONS.md` text (Q1 and R1; two rows with one code, what
was fixed and what is left, R2; the by-day comparison of §7; Q3 and R9; Q6's
retired boundaries; R10 — why the warning reads the import and not
`SyncMonitor`) in a file on the branch for
`main` after the merge; `plan.md` gains **As built**.

## 13. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `TroveIDTests` and the five extended suites: a kept `id` read on a second context; `id` unchanged by a form edit, a sale, a return; a Copy's and a bought item's `id` new | the `save()` dropped (second context finds nothing) · `copy.id = original.id` in either `duplicate` · `item.id = wanted.id` in `markBought` · `item.id = UUID()` in a form's save |
| G2 | `ImportGrammarTests`, money: criteria 11 and 46's accepted lists to the cent (`$ 3,179.95`, `€ 1,250` among them), the rejected list nil, `ExportSchema.money` round trip | grouping accepted as `d{1,3}(,d+)*` (`1,25` reads) · commas stripped before parsing (`1.250,00` or `12,34,567` reads) · spaces not skipped after the symbol · a space accepted with no symbol |
| G3 | dates: ISO unchanged; file-decided month-first and day-first; region fallback under `en_US` and `en_GB` with `regionDateOrder` set; contradiction; two-digit year; an all-ISO file sets no order; `regional(for:)` for four locales | order decided per cell · region consulted when the file decides · `regionDateOrder` set for an ISO-only file · `3/9/26` read |
| G4 | `N/A`, `n/a`, `#N/A` blank and `NA`, `none`, `-` not; a lower-case and a padded code read, `abc` unreadable | `NA` accepted · the code compared as text rather than parsed |
| G5 | `ImportColumnsTests`: case, spaces, star; any order; every missing required name reported; duplicate; unknown names listed once in file order; wrong list both ways and for each shipped layout | only the first missing name reported · the star not dropped · an unknown column refusing the file · wrong-list tested by column count |
| G6 | `ImportSheetTests`, items: the hand-kept fixture (criterion 1), shuffled columns equal, `N/A` per column, totals rows labelled and unlabelled anywhere, a totals row with a sum under an unknown column, a nameless dated row still skipped, extra cells against the header's width; **a `€` price beside a blank `Currency` is `USD`, and beside `GBP` is `GBP`** | `N/A` blanked only in Serial Number · a totals row with a filled non-money recognised cell left out · an unknown column's cell stopping a totals row · a totals row listed among the skips · the slash order taken from the first date · the row reader setting the currency from the symbol |
| G7 | the same for the wishlist (criterion 16) | the wishlist money column missing from its totals rule · `Added` not offered to the date-order scan |
| G8 | `ImportCopyTests`: title; every line and its singular by literal; the order; "can't be undone" iff `updated > 0`; the recounted line iff `recounted`; the unknown-codes warning and its singular iff `keptCodeAdds > 0`; the three failure sentences | any word drifts · the hint shown without a shared-code skip · the undo line shown for adds only · the unknown-codes line shown at zero |
| G9 | `ItemImportStoreTests` / `WishlistImportStoreTests`, add path: appended in file order after every stored position, a sale pair arrives sold, category casing, `Added` restored | placement from a stale base · the pair half-written · `createdAt` left at now |
| G10 | the switch: every shipped layout (items 12, 14, 18, 19; wishlist 7, 9, 10) imports with zero skips and zero defaults; each whole-file failure writes nothing; the re-pointed field-policy tests with their assertions unedited; `ImportConcurrencyTests`' probe still off the main thread | a layout's column unread (a default appears) · `locale` not reaching the schema · a `@concurrent` dropped |
| G11 | `ExportSchemaTests`: both header rows by literal (stars, `Trove ID` last); each row's last cell is its record's code; `ItemListViewModelTests` / `WishlistViewModelTests` / `SettingsViewModelTests`: owned, sold, both, wishlist and Export All each write a non-empty, distinct code per row and the starred header; both templates are the header row and no rows; no PDF field holds a code | `init(item:)` dropping `troveID` · a table built from `itemHeaders` instead of the header row · a template left on the unstarred names · a PDF field added |
| G12 | `ImportUpdateTests`: each of the fifteen item fields changes alone; empty and `N/A` change nothing (serial, purchase date, current value); unreadable changes nothing and counts; empty name keeps the name; a mid-afternoon date equal by day is no change; padded text and CRLF-for-LF text are no change; the sale's four legs | a default written for an unreadable or empty cell (`changes` falling back to `asNew`) · dates compared by instant · sale cells written onto an owned item · an empty cell clearing a field |
| G13 | `ImportMatching`: every outcome; a code shared in the file is never applied even when it matches; the other list's code and a bought entry's code refused with their reasons | the first of two sharing rows applied · an unmatched code dropped instead of kept · a refused code kept or updated |
| G14 | items store and view model, second context: **one field changed on a fully-filled item leaves every other stored field as it was; empty / unreadable / `N/A` cells and missing columns leave stored values; an empty Name updates the rest**; the round trip (criterion 22) with `updatedAt` untouched; updates persisted, Very Good as the literal pair `("good", "very good")`; an ID-less file imported twice makes two copies; an unmatched code is kept, its orphaned market rows cleared, and the second import updates; shared, ambiguous and other-list codes leave everything untouched; an absent item is untouched; photos, plan links, `sortOrder` and market rows survive an update, and market rows are cleared when the product changes; Bought set on many; the sold rules; `rollback()` after `apply` restores (the re-confirm rule is G23's, the warning's count G22's) | **one optional assigned unconditionally in `apply` (`item.serialNumber = changes.serialNumber`) → the one-field leg red** · two assignments crossed · `updatedAt` stamped on unchanged rows · `id` assigned after insert or not at all · the kept-code clear skipped · the product clear skipped, or run on every update · `sortOrder` rewritten on update |
| G15 | the wishlist twin (criterion 35), with `Added`, `Looking For`, the same four store-level legs, and a bought entry's row left out and the entry unchanged (criterion 45) | **one optional assigned unconditionally in the wishlist `apply`** · `createdAt` compared by instant · a bought entry updated, or its row added as new |
| G16 | view models: the confirmation is staged before any write; Cancel leaves a second context's fetch unchanged; a summary that writes nothing offers no import action | `importOffersConfirmation` on `rows.isEmpty` rather than `writesAnything` |
| G17 | `DocsSampleTests`: every README claim; `items-full` twice → all unchanged; `items-full` then `items-edited` → the summary equal to a literal | a sample and its README disagreeing |
| G18 | the re-saved file (criterion 20, Google Sheets): every code parses and matches its row in `items-full.csv`; imported over a store built from `items-full.csv`, the summary equals what the README says Sheets changed | Sheets damaging a code — **this is the guard that can fail on a fact the plan does not control**. Excel and Numbers: untested |
| G19 | criterion 38: the parse probe; a generated 450-row file planned and applied over a 300-item store **asserting 150 updated, 150 unchanged, 150 added**, its elapsed time recorded and not asserted | the probe red if parsing moves to the main actor · the counts red if matching or comparison breaks at size; the timing is evidence, not a gate |
| G20 | two rows sharing one `id` (criterion 42): `MarketIndexTests` — `summaries` over a repeated id returns; the four `load()`s and `PlansViewModel`'s list both twins; `delete` removes the copy acted on (delete the second twin → the first's name remains, and the reverse), on a second context, on both lists; `UITestSeedTests` — the seed refuses a persistent store; the UI test | `uniqueKeysWithValues` restored (the run crashes — recorded) · `delete` resolving by `id` (the delete-the-second leg red) · `delete` removing both · the seed ungated |
| G21 | the missing-column line (criterion 41): a file with no `Desire to Keep` / `Condition` counts zero defaults for them and names both; with the columns present and cells blank it counts them; the line is absent when nothing is added; the wishlist's two | the missing column counted per row · the line shown for a file that only updates · a blank cell in a present column going uncounted |
| G22 | the unknown-codes warning (criterion 43), store and view model, both lists: a file of five rows — two whose codes match, two whose codes match nothing, one with no code — gives `keptCodeAdds == 2` and the staged message carries the warning with 2; a file whose every code matches gives 0 and no warning; a file with no codes gives 0 and no warning though it adds every row; a nameless row with an unknown code is skipped and not counted; `DocsSampleTests` — `items-full.csv` into an empty store carries the warning with 12, and again carries none | every row with a code counted (matched ones too) → the mixed leg reads 4 · every add counted → the no-code leg red · a skipped kept-code row counted · the count read from `SyncMonitor` or gated on it in any way — there is no such parameter to pass, which is the point |
| G23 | re-confirm (criterion 47), both view models: with a confirmation staged for a row whose code matches nothing, an item carrying that code is inserted and saved (as a sync arrival would); `confirmImport()` then writes nothing — a second context shows the store exactly as the insert left it — and the presentation is a confirmation again with `recounted` true, the "collection changed" line first, `updated == 1` and `added == 0`; a second `confirmImport()` applies that update; and with the store untouched, the first confirm applies | the summaries not compared at confirm (the first confirm updates an item the person was shown as an add) · the comparison on counts alone when only the listed rows differ · the re-presented confirmation not offering Import · `recounted` left false |

Every guard is mutation-verified before it lands and the Done note records what
was broken and what went red; persisted assertions refetch on a second
`ModelContext`; no scan is added by this spec — every rule here is reachable by
a pure-function, store, view-model or UI test. What the suites cannot reach is
in §9, plus: the on-disk read and the alert's look (T014), the person's own
file (the Phase 2 pause), a real spreadsheet's re-save (T013 — Google Sheets
only), and a second device (`SYNC-CHECKS.md`).

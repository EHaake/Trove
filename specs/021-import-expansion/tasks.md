# 021 — Import Expansion: Tasks

**Status**: Draft — pending sign-off

Drafted against the approved `spec.md` (Approved 2026-10-07) and the draft
`plan.md` in this directory, for branch `021-import-expansion` off `main`
(`028747f`). No new technical decisions are made here — every call traces to a
plan section, and where a task says "per plan", that section is the authority.
Line numbers in `plan.md` are as read at `028747f`; every implementer re-reads
the file it edits.

**Foundational phase**: **Phase 1** (T001–T003) — the claims the Trove ID rests
on, the reader's grammar for a price, a date, an empty cell and a code, and the
column matcher. Every later task reads through these, and T001 is where the
plan's choice of identifier is shown to hold or stops the spec.
**Tasks marked `review: per-task`**: **T004** — the row types and the row
pipeline (what is a row, a totals row, a skip, a default) are what T005–T012 and
every fixture inherit; and **T009** — the update rule writes onto real items and
cannot be undone, and its plausible-looking simpler version (reuse the new-row
path) silently writes defaults over existing values. Every other task gets the
default one review per phase. An orchestrator left to guess guesses "all of
them"; these two are the ones marked.

Ordering note: the identifier's claims first, since nothing else is worth
building if one fails; then the pure grammar and the column matcher. Phase 2
builds the new reader **beside** the old one (T004–T006 are additive) and
switches over in one task (T007), so the tree is green at every commit. Phase 3
writes the Trove ID out before anything reads it back, proves the update rule
as a pure function before a store calls it, and leaves the docs for last so they
describe what was built. The recorded spreadsheet re-save needs a file only the
person can make, so it follows the Phase 3 pause.

House rules carried over: one commit per completed task, referencing its ID;
every guard is **mutation-verified** (break the rule, confirm red) before it
lands, and the Done note records what was broken and what went red; a task is
done when `scripts/verify.sh` is green and its actual output is reported
(suite-level selection, count checked — per-function Swift Testing selectors run
zero tests); **persisted-state assertions refetch on a second `ModelContext`**;
**no new source scan in this spec** — every rule here is reachable by a
pure-function, store or view-model test (`CLAUDE.md`, 2026-09-19), and an
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
the orchestrator for T004 and T009 and taken from the implementer's verbatim
output otherwise; the `skeptical-reviewer` reviews per phase and T004 and T009,
one review and at most one re-review each, on a bundle cut after `git add -A`;
one implementation session for the whole spec; the device pass runs in
`general-purpose` agents, one per section. Everything the person reads is plain
language.

---

## Phase 1 — Foundations: the code, the grammar, the columns (**foundational**) · walkthrough: none — tests over fields that already exist, and pure functions nothing calls yet. One reading does move: a price written `$1,250.00` in a file that already matches the template now reads instead of falling back to a default; nobody would go looking for it, and Phase 2's pause covers it

- [ ] **T001 — The Trove ID is `id`: every claim it rests on, tested.**
  Per plan §1, R1 and Q1. No behaviour changes. `Item.id` and `WishlistItem.id`
  gain doc comments saying `021` exports them as the Trove ID and what that
  relies on (stored, never reassigned by an edit, new on a Copy and on a
  purchase, assignable before insert for a kept code).
  Pattern: `020` T001's persisted legs in `TroveTests/ModelTests.swift`;
  `ItemDuplicationTests.theCopyCarriesBought`;
  `ItemSaleStoreTests.markThenReturnLeavesBoughtUnchanged`.
  Tests (**G1**): new `TroveTests/TroveIDTests.swift` — an `Item` and a
  `WishlistItem` each given a known `UUID` **before insert**, saved, and read
  back on a second context with that `id` (mutation: the `save()` dropped → the
  second context finds nothing → red); two rows inserted with the **same** `id`
  both persist (the store does not refuse it — the fact plan R2 designs around;
  if this leg fails, say so: the store is stricter than the plan assumes).
  `ItemFormViewModelTests` / `WishlistFormViewModelTests`: an edit saved through
  the form leaves `id` as it was, on a second context (mutation: `item.id =
  UUID()` in the form's save → red). `ItemSaleStoreTests`: `markSold` then
  `returnToCollection` leave `id` as it was. `ItemDuplicationTests` /
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

- [ ] **T002 — The reader's grammar: prices, slash dates, `N/A`, the code.**
  Per plan §2, Q7, Q8, P4, P6. New `Trove/Import/ImportRows.swift` opening with
  `Cell<Value>` and `SlashDateOrder` (with `regional(for:)`). In `ImportSchema`:
  `isBlank(_:)`; `cents(from:)` **widened in place** to the grammar plan §2
  gives; `day(from:timeZone:order:)` with `order: SlashDateOrder? = nil` (nil
  keeps today's ISO-only behaviour for every existing caller);
  `slashDateOrder(in:region:)` returning the order and whether the region
  decided it; `troveID(from:) -> Cell<UUID>`. Doc comments on `cents` and `day`
  say what `021` widened and point at spec Decisions 6 and 16.
  Pattern: `ImportSchema.cents(from:)` and `day(from:)`, and their tests in
  `TroveTests/ImportSchemaTests.swift` (`canonicalMoneyFormsParseCentExact`,
  `impossibleDatesAreRejected`).
  Tests: new `TroveTests/ImportGrammarTests.swift`. **G2** — `$3,179.95`,
  `€1,250`, `£99.5`, `¥500`, `1,250.00`, `500`, `$0.00` to the exact cent;
  `1.250,00`, `-5`, `(5.00)`, `1,25`, `500 USD`, `12,34,567`, `$`, `$ 5`, `5$`
  nil; `ExportSchema.money` output still reads back (mutations: grouping as
  `d{1,3}(,d+)*` → `1,25` reads → red; commas stripped before parsing →
  `12,34,567` reads → red). **G3** — ISO reads as before with and without an
  order; `12/28/2025` beside `5/1/2025` settles month-first for both;
  `28/12/2025` beside `1/5/2025` settles day-first; a file with only `5/1/2025`
  takes the region's order and reports that the region decided, under `en_US`
  and `en_GB`; a file holding `12/28/2025` and `28/12/2025` takes the region's
  order and the one that does not fit is nil; `3/9/26` nil; `2/30/2025` nil; a
  file of ISO dates reports no region decision; `regional(for:)` for `en_US`,
  `en_GB`, `de_DE`, `ja_JP` (mutations: order decided per cell → the
  settles-both legs red; the region reported for an ISO-only file → red).
  **G4** — `N/A`, `n/a`, ` #N/A ` blank; `NA`, `none`, `-` not; an upper-case, a
  lower-case and a space-padded code read to the same `UUID`; `abc` and a
  35-character code are `unreadable`; blank is `empty` (mutation: `NA` accepted
  → red).
  **Rewritten, not loosened**: `ImportSchemaTests.nonCanonicalMoneyIsRejected`
  lists `"$5"` and `"1,250.00"` as rejected — those two move to an accepted
  test, the other eleven arguments stay rejected.
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

## Phase 2 — Reading a sheet as it is · walkthrough: yes — Items › ⋯ › Import from CSV: your own `My-Gear.csv` imports as it is — the confirmation says 90 items will be added and that row 108 looks like a totals row and was left out, with nothing skipped and no defaults; after Import the 13 items whose serial number said N/A have none, the one written 0185654 keeps its zero, and the Alienware monitor is worth $500 (do this on a simulator, or anywhere you are happy to add 90 items — Settings › Delete All clears them); `docs/samples/items-hand-kept.csv` does the same with invented rows; move the columns around in a sheet, or add a column of your own, and it still imports, with the confirmation naming the column it did not use; delete the Purchase Date column and the file is refused, the alert naming what is missing; a file an older Trove exported still imports; the Wishlist does all of this with its own columns. Not yet, by design: exports are unchanged and importing a file twice still adds copies — that is Phase 3

- [ ] **T004 — The items rows and the items sheet. `review: per-task`.**
  Per plan §4, Q2, P5, P7, P8, R8. In `ImportRows.swift`: `ItemImportRow`,
  `ImportSheet<Row>`, and `ItemImportRow.asNew(now:)` returning
  `ValidatedRow<ItemExportRecord>?` with **exactly today's field policy and
  counts** (copy the policy from `ImportSchema.itemsPreview`, do not re-derive
  it), plus one count for an unreadable Trove ID. In `ImportSchema`:
  `itemsSheet(from:timeZone:locale:)` — shape, match columns, settle the slash
  order over `Purchase Date` and `Sold Date`, then the five row steps of plan §4
  **in that order**. The known names are `ExportSchema.itemHeaders +
  [ExportSchema.troveIDHeader]` for now — a stated, temporary seam that T008
  removes when the array itself gains the name. **Additive**: `itemsPreview` and
  the header gate stay, untouched, until T007.
  New `docs/samples/items-hand-kept.csv` exactly as plan §4 specifies: the
  ten-column header, 24 invented rows in four groups, the separator rows, three
  blank rows, and a totals row whose two amounts are the true sums. Every
  feature in plan §4's list present; LF endings, no BOM.
  Pattern: `ImportSchema.itemsPreview` (the field policy, the padding, the row
  numbering) and `ImportSchemaTests.aFullyValidRowValidatesWithNoDefaults`
  onward.
  Tests (**G6**): new `TroveTests/ImportSheetTests.swift` — the hand-kept
  fixture (criterion 1): 24 rows, no skips, `asNew` over every row totals zero
  defaults, `totalsRowNumbers` is the one literal row number,
  `regionDateOrder == nil`; from it by name: a `$0.00` price is 0 and uncounted,
  the bare `500` is 50 000, the leading-zero serial is kept as text, an `N/A`
  serial is `empty`, the trailing-space name is trimmed, the doubled-quote name
  reads, a date with a day above 12 lands on that day. The fixture's columns
  shuffled, in memory, give `rows` equal to the original's (3). A file of only
  `Name`, `Purchase Price`, `Purchase Date` gives, through `asNew`, what
  blank cells give today — including the two counted defaults per row, R5 (6).
  `N/A` in each of Serial Number, Current Value, Year, Purchase Price and Name:
  empty, empty, empty, the counted default, the row skipped as nameless (14). A
  totals row unlabelled and labelled `Total`, `totals`, `Subtotal`, `SUM`, in
  the middle and at the end, is left out and not skipped; a nameless row with a
  date is skipped "no name"; a row named `Total` with a date is an item; a
  totals-shaped row with a Trove ID is not a totals row; a row of `N/A`s is
  dropped silently (15). A nameless row with a readable code is kept. A row
  with more cells than **the header** is skipped "more columns than the header";
  a short row pads (mutations: `N/A` blanked only for Serial Number → the other
  four legs red; a totals row with a filled Category left out → red; a totals
  row appended to `skipped` → red; the slash order taken from the first date →
  red; `asNew` not counting an empty Desire → the required-only leg red).
  Files: `Trove/Import/ImportRows.swift`, `Trove/Import/ImportSchema.swift`,
  `docs/samples/items-hand-kept.csv` (new), `TroveTests/ImportSheetTests.swift`
  (new).
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded verbatim; the fixture's row count, totals row number and the two
  sums stated in the Done note.

- [ ] **T005 — The wishlist rows and the wishlist sheet.**
  Per plan §4, Q4. `WishlistImportRow`, its `asNew(now:)` (today's wishlist
  policy: cost and desire and `Added` default and count; currency, product,
  year and `Looking For` count only when unreadable), and
  `ImportSchema.wishlistSheet(from:timeZone:locale:)` — the money column for the
  totals rule is `Estimated Cost`, the date column for the order scan is
  `Added`. Same temporary known-names seam as T004. Additive.
  Pattern: T004's `itemsSheet`, and `ImportSchema.wishlistPreview` for the
  policy.
  Tests (**G7**, `ImportSheetTests`): criterion 16 — a hand-written wishlist
  sheet with columns out of order, `$` costs with commas, slash `Added` dates
  that settle their order, an `N/A`, an unknown column, a blank row and a totals
  row imports with every row kept and no defaults; required-only (`Name`,
  `Estimated Cost`) gives today's blanks; the same totals and nameless legs as
  T004, once each (mutations: `Estimated Cost` missing from the totals rule →
  red; `Added` not offered to the order scan → red).
  Files: `Trove/Import/ImportRows.swift`, `Trove/Import/ImportSchema.swift`,
  `TroveTests/ImportSheetTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T006 — The summary, the words, and the two stores' add path.**
  Per plan §5, §8, Q11, R7. New `Trove/Import/ImportStore.swift`:
  `ImportSummary`, and `ItemImportStore` / `WishlistImportStore` with
  `plan(for:in:timeZone:now:)` and `apply(_:in:now:)` — **adds only in this
  task**: every row goes through `asNew`, the Trove ID cell is ignored, and
  `Plan` has no `updates` yet (T010 and T011 add them). `apply` is today's
  commit loop **moved, not rewritten**, from `ItemListViewModel.confirmImport`
  and `WishlistViewModel.confirmImport`: placement after every stored position
  computed here, category casing resolved in file order, a readable sale pair
  arriving sold, `Added` restoring `createdAt`. `ImportError` gains `wrongList`,
  `missingColumns`, `duplicateColumn` (the old case stays until T007).
  `ImportCopy` gains `confirmationTitle(summary:)`,
  `confirmationLines(summary:target:)` and the three failure sentences, every
  string as plan §5 gives it; `ImportSchema.SkipReason` gains the reasons plan
  §5 lists. The view models are **not** touched. Additive.
  Pattern: `ItemSaleStore` / `WishlistPurchaseStore` (one writer, callers
  save); `ImportCopy.confirmationMessage(preview:)` and `ImportCopyTests`.
  Tests: **G8** (`ImportCopyTests`) — the title both ways; each line by literal
  with its singular; the order of lines for a summary with everything set; the
  shared-code hint only when a skip carries that reason, including when that
  skip falls past the first five; "Updates can't be undone." only when
  `updated > 0`; "No problems found." only when nothing else is said; the three
  failure sentences for one, two and three names (mutations: the undo line
  shown for adds → red; the hint shown always → red). **G9** — new
  `TroveTests/ItemImportStoreTests.swift` and `WishlistImportStoreTests.swift`,
  every assertion on a second context after the caller's `save()`: rows land
  after an existing collection in file order; a sale pair arrives sold with all
  four fields and no plan; a casing variant takes the existing path's casing;
  `Added` is the row's date; the summary's `added`, `skipped`, `defaultedOnNew`,
  `unusedColumns`, `totalsRows` and `regionDateOrder` equal the sheet's
  (mutations: placement from `0` → red; `createdAt` left at now → red).
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
  the three new `ImportError` cases; `ImportPresentation<Row>` carries
  `sheet` and `summary`. Both view models: `importCSV(from:)` parses with
  `timeZone: .current, locale: .current`, then stages
  `plan(…).summary`; the three alert accessors read the summary through
  `ImportCopy`; `confirmImport()` **keeps its synchronous capture** (read the
  doc comment — the `012` T017 finding), returns early unless
  `summary.writesAnything`, and in its task calls `plan` again, `apply`,
  `save()`, with `rollback()` and the save-failure copy on any throw. Deleted,
  with nothing left to call them: `itemsPreview`, `wishlistPreview`,
  `requireItemsHeader`, `requireWishlistHeader`, `requireHeader`, the old
  `ImportSchema.HeaderError`, `ImportPreview` and its two typealiases,
  `ImportError.headerMismatch`, `ImportCopy.confirmationTitle(importCount:target:)`
  and `confirmationMessage(preview:)`, `ExportSchema.itemSchemaBoundaries` and
  `wishlistSchemaBoundaries`. Neither list view changes; if
  `ImportWiringTests` goes red, re-read it before touching it.
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
  (36) (mutations: one layout's column lookup misspelled → that layout shows a
  default → red; `locale` dropped in `FileImportService` → red;
  `importOffersConfirmation` on `!rows.isEmpty` → red for a sheet whose only row
  is nameless).
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
  confirms by grep that no deleted symbol is still referenced. Then
  `scripts/verify.sh ui` once at the phase end, count recorded.

  **Phase 2 closes here — pause for the person** (walkthrough above; the phase
  review first). The report says, as statements the person can overturn: a
  sheet with no Desire to Keep or Condition column counts two defaults for
  every row, because a missing column is a column of blanks (plan R5); the
  alert's wording was fitted to an alert, which draws no bold (R7). It also
  records what the person saw for criterion 2 — their own file — in their
  words, for the close-out.

## Phase 3 — The Trove ID, and updating by re-import · walkthrough: yes — Settings › Templates and every CSV export: the header reads `Name *`, `Purchase Price *`, `Purchase Date *` (on the wishlist `Name *`, `Estimated Cost *`) and the last column is `Trove ID`, with a code on every row and none in the templates; export the collection, open it in Google Sheets, change a price and a category, fill in Bought down the column, add one row of your own with no Trove ID, download it as CSV and import it: the confirmation counts what will be updated, added and left unchanged and says updates can't be undone, and after Import exactly those items changed — photos, sell plans and your custom order as they were, the new row at the end; import an untouched export and it says nothing to import, every row unchanged; empty a cell in the sheet and import: that value stays; fill the sale columns for something you still own: it stays owned and the confirmation says so; a sold item's sale price can be corrected from the sheet; `docs/samples/items-full.csv` then `docs/samples/items-edited.csv` shows every line the confirmation can carry at once — is that readable as an alert?; the PDF is as it was; the Wishlist does the same with its own columns; and `docs/csv-reference.md` now opens with this loop. **One thing only you can do**: open `docs/samples/items-full.csv` in Google Sheets, change nothing, File › Download › Comma-separated values, and hand that file back — it becomes the recorded proof that the codes survive a spreadsheet

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
  Per plan §7, P8, R2, R3 and spec Decisions 10, 12, 14, 15. In
  `ImportRows.swift`: `ItemChanges` and `WishlistChanges` (a field is non-nil
  only when it is to be written — the type cannot express a clear);
  `ItemImportRow.changes(against:category:timeZone:)` and the wishlist twin,
  exactly by plan §7's per-cell rule — **never calling `asNew`**, dates compared
  by calendar day through `ExportSchema.day`, text against trimmed text, the
  sale's two cases; and `ImportMatching.outcomes(ids:storedCounts:otherListIDs:)`.
  No store, no view model, nothing calls them yet.
  Pattern: `Item.storage(for:)` / `condition(raw:refinement:)` (a pure rule
  with its tests beside it, `020` T001); `ImportSchemaTests`' record-building
  helpers for the fixtures.
  Tests (**G12**, **G13**): new `TroveTests/ImportUpdateTests.swift`, no
  container. Against a record whose every value differs from its field's
  default: each of name, category, purchase price, currency, purchase date,
  place, current value, desire, condition, condition notes, serial number,
  notes, Reverb product, year and Bought, changed alone, yields exactly that one
  field (criterion 23); an empty cell and an `N/A` (a missing column is the same
  `empty` — say so in the test) yield nothing, for serial number, purchase date
  and current value (24); `abc` for a price, `9` for desire, `someday` for a
  date yield nothing and count one each (25); an empty name yields no name
  change and still carries the row's other changes (26); a cell equal to the
  item yields nothing — including a date on the same calendar day as a stored
  mid-afternoon instant, and text equal after trimming; the sale: a sold
  record takes a corrected date, price, place and note, each alone; emptied
  sale cells on a sold record yield nothing; filled sale cells on an owned
  record set `hasUnusedSaleCells`, write nothing and count nothing, while the
  row's other changes stand (34). The wishlist twin over its ten fields,
  `Added` by day. `ImportMatching`: empty → `new(keeping: nil)`; unreadable →
  the same; one stored match → `update`; none → `new(keeping:)` that code; the
  same code on two and on three rows → `sharedInFile` for each, naming the
  others, even when it matches a stored row; two stored rows with the code →
  `ambiguousInStore`; a code in the other list → `otherList` (mutations:
  `changes` built from `asNew`'s record → the unreadable and empty legs red —
  **this is the mutation that matters, run it first**; dates compared by
  instant → the same-day leg red; sale cells written onto an owned record →
  red; an empty cell writing nil → red at the type or the test, say which; the
  first of two sharing rows returned as `update` → red; an unmatched code
  returned as `new(keeping: nil)` → red).
  Files: `Trove/Import/ImportRows.swift`, `TroveTests/ImportUpdateTests.swift`
  (new).
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded verbatim; the new suite in the count.

- [ ] **T010 — Items: matching and updates through the store and the view model.**
  Per plan §8, Q3, Q5, P11, R2, R3. `ItemImportStore.plan` fetches every `Item`
  and every `WishlistItem.id`, runs `ImportMatching`, and per outcome builds an
  add (`asNew`; nil → skipped "no name"), an update (canonicalised category,
  `ItemExportRecord(item:)`, `changes`), an unchanged count, or a skip with its
  reason; `Plan` gains `updates`; the summary gains `updated`, `unchanged`,
  `unreadableOnUpdates`, `unusedSaleRows` and the new skips, kept in row order.
  `apply` sets `item.id` from a kept code **before** insert; writes each change
  set (condition through `item.condition`, the sale through `item.sale`),
  clears the item's market rows first when its Reverb product changes, stamps
  `updatedAt` on updated items only, and touches nothing on an unchanged row.
  The view model needs no new surface; confirm `confirmImport()` re-plans in
  its task.
  Pattern: T006's add path; `ItemDetailViewModel.setMatch` for the market
  clear; `ItemListViewModelCommitTests.commitRestoresBoughtAndVeryGoodThroughTheCSV`
  for an export → CSV → parse → commit → second-context test.
  Tests (**G14**; `ItemImportStoreTests` and `ItemListViewModelCommitTests`,
  every persisted assertion on a second context). The round trip (criterion
  22): a collection of awkward values — a mid-afternoon purchase date, a sold
  item with a note, Very Good, a nil current value, notes with padding, a name
  that needs quoting — exported as owned-and-sold, written by `CSVWriter`,
  parsed, planned: zero added, zero updated, every row unchanged, and after
  `confirmImport()` (which must return nil) every item's `updatedAt` and stored
  dates are what they were. Updates: the fifteen fields changed through a file
  land on a second context, Very Good as the stored pair `("good", "very
  good")`, the confirmation counting the row (23); an ID-less file twice makes
  two copies (27 — `committingTheSameFileTwiceDuplicatesEveryRow`, kept); a row
  whose code matches nothing arrives carrying it, and the same file again
  updates nothing and adds nothing (28); two rows sharing a stored item's code
  leave it untouched and are both listed with the hint (29); `abc` in the code
  cell adds a row with a fresh code, counted (30); two stored items sharing a
  code are both untouched and the row is listed (R2); a wishlist entry's code
  in an items file is listed and nothing is added (R3); a five-item collection
  and a one-row file leave the other four as they were (31); an updated item
  keeps its photos, its `plannedForWishlistItems`, its `sortOrder` and its
  market figure row, new rows append after everything in file order, and a
  changed Reverb product clears that item's market rows and nobody else's (32);
  Bought filled on every row of an export sets each item (33); the sold rules
  end to end, including a new row with a readable pair arriving sold (34); an
  item deleted after the confirmation is staged and before Import arrives as a
  new item carrying its code (Q3); and
  `rollbackClearsUnsavedInsertsFromTheContext`'s shape extended to updates —
  changes written by `apply` and then rolled back leave the stored values on a
  second context and on a refetch of the same one (a failing `save()` cannot be
  forced in memory, so *that* `confirmImport` calls `rollback()` stays with
  `ImportWiringTests`' existing scan — say so in the Done note) (mutations: `updatedAt` stamped on unchanged
  rows → the round trip red; `id` assigned after insert, or not at all → 28
  red; the market clear run on every update → 32 red, and skipped → red;
  `sortOrder` rewritten on update → red; `changes` snapshot taken from a stale
  record → the deleted-between leg red or crashing — record which).
  Files: `Trove/Import/ImportStore.swift`, `Trove/ViewModels/ItemListViewModel.swift`
  (only if the re-plan is missing), `TroveTests/ItemImportStoreTests.swift`,
  `TroveTests/ItemListViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded; the Done note gives
  the criterion each new test carries.

- [ ] **T011 — Wishlist: matching and updates through the store and the view model.**
  Per plan §8, R4. `WishlistImportStore.plan` and `apply`, T010's shape over
  `WishlistImportRow` / `WishlistChanges`: matching against **every**
  `WishlistItem`, bought entries included; `Added` written to `createdAt`; the
  market clear on a changed Reverb product; no sale rules.
  Pattern: T010; `WishlistViewModelCommitTests.commitRestoresLookingForThroughTheCSV`.
  Tests (**G15**; `WishlistImportStoreTests`, `WishlistViewModelCommitTests`,
  second context): criterion 35 — the round trip over entries whose `createdAt`
  is a mid-afternoon instant reports every row unchanged and leaves `createdAt`
  untouched; each of name, category, estimated cost, currency, desire, `Added`,
  notes, Reverb product, year and `Looking For` updated; empty, `N/A` and a
  missing column leave the value; an unmatched code is kept and the second
  import updates; shared codes are not applied; an absent entry is untouched;
  photos, the sell plan's selection and `sortOrder` survive; an item's code in
  a wishlist file is listed (R3); a row whose code belongs to a **bought** entry
  updates it and it is still bought (R4) (mutations: `createdAt` compared by
  instant → the round trip red; bought entries left out of the fetch → the R4
  leg adds a duplicate → red).
  Files: `Trove/Import/ImportStore.swift`, `Trove/ViewModels/WishlistViewModel.swift`
  (only if the re-plan is missing), `TroveTests/WishlistImportStoreTests.swift`,
  `TroveTests/WishlistViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T012 — The CSV reference, the samples, and their tests.**
  Per plan §10, P13, R2. `docs/csv-reference.md` rewritten as plan §10 lays it
  out, **opening with the hand-kept-sheet loop**. `docs/samples/items-full.csv`
  and `wishlist.csv` rewritten in the layout the app now writes — the starred
  header row, 20 and 11 columns, BOM, CRLF, a fixed invented Trove ID on every
  row, every other value as it is today. New `docs/samples/items-edited.csv`
  exactly as plan §10 specifies, to be imported after `items-full.csv`.
  `docs/samples/README.md`: a row for each new file, the two rewritten rows, and
  "import it twice" replaced by what now happens. `items-partial.csv`,
  `items-resaved.csv` and the three `bad-*` files are **not** edited.
  Pattern: `020` T013's additions to the same files and to
  `DocsSampleTests.itemsFullImportsCleanly`.
  Tests (**G17**, **G19**; `DocsSampleTests`): `items-full.csv`'s header is
  `ExportSchema.itemHeaderRow` and `wishlist.csv`'s the wishlist row; each
  imported into an empty store adds every row carrying its code, and imported
  **again** reports every row unchanged; `items-full.csv` then
  `items-edited.csv` gives a summary **equal to a literal** — its updated,
  added and unchanged counts, each skip with its reason, both unreadable
  counts, the unused column, the totals row, the unused-sale count and the
  region's date order; `items-hand-kept.csv` as the README says; every
  existing sample claim still green. Criterion 38: the existing off-main probe,
  and one test that plans and applies a generated 300-row file — half matching
  a 300-item in-memory collection, half new — and **records** the elapsed time
  in the Done note without asserting on it (mutation: one cell of
  `items-edited.csv` changed → the literal red; a Trove ID blanked in
  `items-full.csv` → the second-import leg red).
  Files: `docs/csv-reference.md`, `docs/samples/README.md`,
  `docs/samples/items-full.csv`, `docs/samples/wishlist.csv`,
  `docs/samples/items-edited.csv` (new), `TroveTests/DocsSampleTests.swift`,
  `TroveTests/ItemImportStoreTests.swift` (the 300-row timing).
  **Verify:** `scripts/verify.sh` green; mutations recorded; the 300-row time
  stated; `cmp` shows the five untouched samples byte-identical to `main`. Then
  `scripts/verify.sh ui` once at the phase end, count recorded.

  **Phase 3 closes here — pause for the person** (walkthrough above; the phase
  review first). The report says, as statements the person can overturn, in
  plain words: importing the same exported file on two devices before they have
  synced can leave two copies of an item with one code, and what the app does
  about it (plan R2); a code that belongs to something on the other list is not
  used (R3); a wishlist row for something already bought updates that entry and
  leaves it bought (R4); the confirmation is still an alert — and asks whether
  the everything-at-once one was readable (R6). **It asks for the re-saved
  file.** If the person would rather not record one, that is a question about
  criterion 20 for them to answer, not a task to skip.

## Phase 4 — Verification and close-out · walkthrough: none — a recorded file pinned by a test, the device pass and the documents; nothing new is built. The two-device steps wait in `specs/SYNC-CHECKS.md`

- [ ] **T013 — The spreadsheet re-save, pinned. [needs the person's file from the Phase 3 pause]**
  Per plan Q1, G18, criterion 20. The orchestrator commits the file the person
  handed back as `docs/samples/items-full-resaved-sheets.csv`, **byte for byte
  as received** — it is a recording, and an edited recording is a guess. The
  implementer then reads it and writes down what Google Sheets actually changed
  (line endings, the BOM, quoting, trailing columns, number and date formats,
  leading zeros) in a new `docs/samples/README.md` row, and pins it.
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
  **(a) The code on a store that predates this build** (persistent store, no
  launch arguments): build and install `main`, add two items and a wanted
  entry, mark one item sold; build and install this branch over it; export
  owned-and-sold as CSV and the wishlist as CSV and read the staged files from
  the app's container — every row has a well-formed code and all are different;
  terminate, relaunch, export again — each row has the code it had before
  (criterion 17: the on-disk half no in-memory test observes).
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
  there. Then both suites twice. The sections run **one after another** on the
  simulator, never together, and the orchestrator passes (a)–(c)'s returned
  lists into (d)'s bundle.
  **[person]** the two new `SYNC-CHECKS.md` steps if two devices are to hand —
  otherwise they wait in that file (criterion 40).
  **Verify:** each section's pass/fail list recorded in the Done note — the
  codes before and after, the screenshots' verdicts, the 300-row counts — every
  failure a sub-lettered task, every "could not perform" named, and
  `scripts/verify.sh all` green twice back to back.

- [ ] **T015 — Close-out.**
  Dispatched to the implementer the model policy's close-out row names
  (`sdd-implementer`), on a **close-out bundle** the orchestrator assembles with
  shell: each acceptance criterion with the test names or Done notes that
  satisfied it, the walkthrough list below and what the person said at each
  pause, the tier log, the spec's summary and its decided lines, the
  `ROADMAP.md` entries this spec touches, `020`'s `DECISIONS.md` section as the
  shape to copy, plan §11's two drafted `SYNC-CHECKS.md` steps, and the exact
  lines to be pointed at (below), cut with `sed`. **The dispatch forbids full
  reads of `spec.md`, `plan.md` and `tasks.md`.** The close-out: ticks criteria
  1–39 in `spec.md` with per-criterion citations — **2 from the person's words
  at the Phase 2 pause, 20 only on T013's Done note, 40 an honest partial and
  unticked** until the two-device pass — and says plainly what is untested
  (Excel and Numbers; the alert on screen under automation; anything T014
  returned as "could not perform"); appends a "Superseded in part by `021`"
  pointer **beside**, never in place of, `specs/011-data-export/plan.md:113`
  (byte-for-byte header), `:132` (no `id` column) and `:150` (boundaries);
  `specs/012-data-import/spec.md:45` (never modifies), `:60` (exact columns)
  and `:94` (rigid template), and its money and date rules under "Parsing
  tolerance"; `specs/012-data-import/plan.md`'s "Row pipeline" and "Money and
  date parsing" sections; `specs/020-purchase-provenance/plan.md`'s Q7; and
  `specs/011-data-export/spec.md` wherever it states the header match or the
  reason for append-only (the bundle carries a `grep` of it — none was found at
  planning, so "none" is an acceptable answer if the grep says so); adds steps 3.13 and 3.14 to `specs/SYNC-CHECKS.md` (Part 3 and "Steps per
  spec"); updates `README.md`'s import and export bullets; drafts the
  `ROADMAP.md` entry and status row and the `DECISIONS.md` section (the Trove
  ID is `id`, and why; two copies with one code, R2; dates compared by day;
  resolve at stage and again at confirm; the boundaries retired; the alert kept
  or replaced, as the person said) into a file on the branch, to be applied to
  `main` after the merge; and runs `scripts/verify.sh all`. `plan.md` gains
  **As built** from the same bundle. Only then the pre-merge `skeptical-reviewer`
  sweep over `git diff main...HEAD` (bundle cut after `git add -A`), and the PR
  marked ready.
  Files: `specs/021-import-expansion/spec.md`, `specs/021-import-expansion/plan.md`,
  `specs/011-data-export/plan.md`, `specs/011-data-export/spec.md` (only if the
  grep finds a sentence), `specs/012-data-import/spec.md`,
  `specs/012-data-import/plan.md`, `specs/020-purchase-provenance/plan.md`
  (pointers), `specs/SYNC-CHECKS.md`, `README.md`, the drafted
  `ROADMAP.md`/`DECISIONS.md` text file.
  **Verify:** `grep -c "Superseded in part by \`021\`"` returns at least 3 for
  `specs/011-data-export/plan.md`, at least 4 for `specs/012-data-import/spec.md`,
  at least 2 for `specs/012-data-import/plan.md` and 1 for
  `specs/020-purchase-provenance/plan.md`, and in each of those four files the
  diff against `main` adds text only — every shipped sentence still reads as it
  did; `scripts/verify.sh all` green with
  both count lines recorded here; the sweep signed off or its findings
  resolved.

---

## Walkthrough list (for the close-out)

| Phase | Paused? | What to try |
|---|---|---|
| Phase 1 | no — `walkthrough: none` | nothing observable; tests over the existing identifier, and pure functions nothing calls yet |
| Phase 2 | yes | the person's own sheet imports as it is (criterion 2); columns in any order, an extra column named, a missing required column refused; older exports still import; both lists |
| Phase 3 | yes | the starred header and the Trove ID in every export and template; export → edit in Google Sheets → import updates, adds and leaves unchanged; an empty cell changes nothing; sold status stays in the app; the everything-at-once confirmation as an alert; the reference doc; **the person records the re-saved file** |
| Phase 4 | no — `walkthrough: none` | the recorded file's test, the device pass, the documents; the two-device steps wait in `SYNC-CHECKS.md` |

## Handoff note

Involvement level: **product owner** (`CLAUDE.md`). Model policy: **Opus
profile** — every role at `opus`, no dispatch carries a model override, the
session at `claude-opus-5-5` medium; the plan-and-tasks draft ran at the
implementation tier under the trial continuing from `018`. Foundational phase:
**Phase 1**; `review: per-task`: **T004** and **T009**. Pause cadence: after
each phase marked `walkthrough: yes` (Phases 2 and 3) once its review is signed
off; Phases 1 and 4 run on after their review, their reasons added to the
walkthrough list. Pause also whenever something unexpected bears on spec
adherence — and **T001 and T013 each name a stop of their own**: a failed claim
about the identifier, and a code that does not survive the spreadsheet.

> Read `CLAUDE.md` and `specs/021-import-expansion/{spec,plan,tasks}.md`.
> Confirm the branch is `021-import-expansion` and run `scripts/verify.sh`.
> Begin at the first unchecked task. Involvement is product owner. Dispatch each
> task to the implementer the role table names, on a task bundle; verify with
> `scripts/verify.sh`, then commit. One review and at most one re-review per
> invocation. The `skeptical-reviewer` reviews after each phase with a phase
> bundle, and T004 and T009 get their own reviews as well. Pause for me after
> Phases 2 and 3; run straight on after Phases 1 and 4's reviews. At the Phase 3
> pause, ask me for the re-saved sample file — T013 cannot start without it.

Every pause report is plain language, in this order: why this pause; what can
now be tried; where execution deviated from the spec and why; what needs a
decision (product questions only). A phase pause never ends with a continuation
prompt. What the person reports from a walkthrough is a finding against a
criterion — restated, diagnosed by the implementer, and logged as a sub-lettered
task under the task it corrects.

## Tier log

`CLAUDE.md`'s model policy, Opus profile: every role at `opus`, no override;
the session at `claude-opus-5-5`, medium. Each row's Tier is the resolved model
name. Token usage from each subagent return is filled in as the spec runs, with
escape-hatch misses recorded here too.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| Plan and tasks draft (`sdd-planner`) | `opus` | — | Plan-and-tasks draft at the implementation tier, no override (trial continuing from `018`). 15 tasks, 4 phases, 19 guards |

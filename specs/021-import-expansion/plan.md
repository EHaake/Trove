# 021 — Import Expansion — Technical Plan

**Status**: Draft — pending sign-off

Drafted by the `sdd-planner` (Opus 5.5, high effort — per `CLAUDE.md`'s model
policy, Opus profile, the plan-and-tasks draft row at the implementation tier
with no override, the trial continuing from `018`) against the approved
`spec.md` (Approved 2026-10-07) and `main` at `028747f`. The spec's P-items are
already decisions; the planning choices below (Q1–Q11) become decisions on plan
approval. Eight readings are under **Readings for sign-off** — none is a product
fork the plan decides, each is stated so the reviewer can overturn it, and each
goes to the person in plain words at the pause named. Line numbers are as read
at `028747f`; every task re-reads the file it edits.

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
copy, the Settings templates, `docs/csv-reference.md` and its samples. No new
service, no network call, no new screen, no `.pbxproj` edit, no constitution
amendment.

**Earlier rules change, and each takes a pointer, never a silent edit.** `011`'s
plan pins "Header row present, matched byte-for-byte by `012`" and "**No `id`
column**" (`specs/011-data-export/plan.md:113`, `:132`) and records the shipped
widths as boundaries (`:150`); `012`'s spec pins the rigid template, strict
money and dates, and "Import never modifies or deletes" (`spec.md:45`, `:60`,
`:94`). The tests that guard those rules are **rewritten to pin the new rule**
(named in §13 and in each task) and each superseded sentence gains a
"Superseded in part by `021`" pointer beside it at the close-out. Nothing is
deleted to get to green.

## Readings for sign-off (not open questions — the plan builds to each)

- **R1 — The Trove ID is the identifier every item already has.** `Item.id` and
  `WishlistItem.id` (`UUID`, in the schema since `001`) are stored, synced like
  any attribute, and already the key the app navigates by and the device's
  market rows are filed under. So nothing is added to the store, nothing is
  backfilled, and everything that existed before the update has its code
  already (criterion 17). §1 lists each claim this rests on and its test.
- **R2 — Importing the same ID-carrying file on two devices before they have
  synced gives two items one code.** Spec Decision 14 keeps the file's code when
  nothing matches; the spec states the unsynced-import caveat and does not solve
  it. What is new is the consequence: until now such duplicates had different
  identifiers, and the app assumes identifiers are distinct (list rows, the item
  page, the device's market rows). The store cannot enforce it — CloudKit
  forbids unique constraints. The plan does two things and no more: an import
  row whose code matches **more than one** stored item is **not applied** and is
  listed ("its Trove ID matches more than one item"), and the edge is written
  into `SYNC-CHECKS.md` and the reference doc. Deleting one of the two copies in
  the app clears it. **Phase 3 pause, in plain words** — and flagged in the
  planner's report now, because the person accepted the caveat without this
  consequence in front of them.
- **R3 — A code that belongs to something on the other list is not used.** An
  Items row carrying a wishlist entry's Trove ID (a row pasted across sheets)
  would otherwise become an item sharing that entry's identifier. The row is not
  applied and is listed ("its Trove ID belongs to the other list"). The spec's
  "one code of its own" is the rule; this is its edge.
- **R4 — A wishlist row whose code belongs to an entry already bought updates
  that entry.** The spec says a row updating a sold item corrects it; the bought
  entry is the wishlist's equivalent. It stays bought — no column says
  otherwise. Phase 3 pause.
- **R5 — A file with no `Desire to Keep` or `Condition` column counts two
  defaults per new row.** The spec: a missing column behaves exactly like a
  column of empty cells, and an empty cell in those two columns is a counted
  default today (`3`, `excellent`). The person's own sheet has both columns, so
  theirs counts none. Phase 2 pause.
- **R6 — The confirmation stays an alert.** The spec allows a sheet "if an alert
  can't hold it legibly"; legibility is a judgment for eyes, not for a plan. The
  ordinary confirmation is two or three lines. The worst case (every line at
  once, about fourteen) is put in front of the person at the Phase 3 pause with
  a sample pair built to produce it (§10) and seen on the narrowest phone in
  T014. If it is rejected, the sheet is a decision review and a sub-lettered
  task; `ImportCopy` hands back **lines**, not one string, so a sheet reuses
  them unchanged.
- **R7 — Copy adjusted for fit, not meaning.** An alert draws no bold, so the
  spec's sentences are used plain. The title is "Import this file?" (or "Nothing
  to import") and the counts are the message's first line, in the spec's words.
  The unreadable-cells line splits in two — new rows "will use defaults",
  updated rows "will be left as they are". `012`'s skip reason "more columns
  than the template" becomes "more columns than the header", since a hand-kept
  sheet is not the template. `012`'s "The columns don't match the template"
  failure is retired: every file it described now either imports or is missing
  a named column.
- **R8 — The committed fixture is 24 invented rows, not 90.** It carries every
  feature of the person's sheet at least once (§4); the count of 90 belongs to
  their own file, which is not committed (P12) and is tried by them at the
  Phase 2 pause (criterion 2).

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
  about other people's software: **needing verification**, T013.
- **Q2. Parse to cells, decide later.** A row is parsed once into tri-state
  cells (`empty` / `unreadable` / `value`) and read two ways by pure functions:
  `asNew` applies `012`'s defaults, `changes(against:)` applies none. Today's
  pipeline bakes defaults in at parse time, which an update must never see.
- **Q3. Parsing stays store-free and off the main actor; matching runs on the
  main actor, twice.** `plan(for:in:)` is called when the confirmation is
  staged (for the counts) and again at confirm (for what is written), so a sync
  arrival or an edit between the two is honoured — the rule the current commit
  already follows for placement (`ItemListViewModel.swift:1194`). The
  alternative, handing the service a snapshot of the store, moves model data
  across isolation to save a dictionary lookup per row.
- **Q4. Items and wishlist stay parallel implementations**, as `ImportSchema`
  already records ("each function reads as its spec table"). Shared, because
  each has two real callers with identical rules: `Cell`, `ImportColumns`,
  `ImportMatching`, `ImportSummary`, `ImportCopy`.
- **Q5. The comparison snapshot is the existing `ItemExportRecord(item:)`** /
  `WishlistExportRecord(item:)`, built for matched rows only. It already holds
  exactly the columns, so no second snapshot type is added.
- **Q6. The shipped-width boundaries are deleted, not kept.**
  `itemSchemaBoundaries` and `wishlistSchemaBoundaries` have no reader once
  columns are found by name. What they guaranteed — every layout an earlier
  Trove wrote still imports — is pinned by fixtures of those layouts instead
  (G10).
- **Q7. `ImportSchema.cents(from:)` is widened in place.** One money grammar for
  every money column on both lists; a second lenient function beside a strict
  one would need a rule for which column uses which.
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
cannot see one, stop and flag): `Trove/Import/ImportRows.swift` (`Cell`, the two
row types, `ImportSheet`, `ImportColumns`, `asNew`, the two `…Changes` types,
`ImportMatching`), `Trove/Import/ImportStore.swift` (`ImportSummary`, the two
stores).

Changed: `Import/ImportSchema.swift` (grammar, the two sheet functions; the
header gate and the two `…Preview` functions deleted), `Import/ImportService.swift`
(protocol, `ImportError`, `ImportPresentation`, `ImportCopy`),
`Export/ExportSchema.swift` (the Trove ID column, the starred header row, the
record field; the boundaries deleted), `ViewModels/ItemListViewModel.swift`,
`ViewModels/WishlistViewModel.swift` (import section only),
`ViewModels/SettingsViewModel.swift` (the two template header rows),
`Models/Item.swift`, `Models/WishlistItem.swift` (doc comments on `id` only),
`docs/csv-reference.md`, `docs/samples/README.md`, `docs/samples/items-full.csv`,
`docs/samples/wishlist.csv`.

Unchanged and must stay so: `CSVParser.swift`, `CSVWriter.swift`,
`PDFComposer.swift`, both list views (the alert is fed the same three
accessors), `ExportService.swift`.

New test files: `TroveIDTests`, `ImportGrammarTests`, `ImportColumnsTests`,
`ImportSheetTests`, `ImportUpdateTests`, `ItemImportStoreTests`,
`WishlistImportStoreTests`. Extended or re-pointed: `ImportSchemaTests`,
`ImportServiceTests` (with `ImportCopyTests`, `ImportConcurrencyTests`),
`ItemListViewModelTests`, `WishlistViewModelTests`, `SettingsViewModelTests`,
`ExportSchemaTests`, `DocsSampleTests`, `ItemDuplicationTests`,
`WishlistDuplicationTests`, `WishlistPurchaseStoreTests`, `ItemSaleStoreTests`,
`ItemFormViewModelTests`, `WishlistFormViewModelTests`, `TestSupport` (the two
import spies).

New fixtures and samples: `docs/samples/items-hand-kept.csv`,
`docs/samples/items-edited.csv`, `docs/samples/items-full-resaved-sheets.csv`
(recorded by the person, T013), `TroveTests/Fixtures/Import/items-020-layout.csv`
and `wishlist-020-layout.csv` (byte copies of the samples `020` shipped) with a
`README.md`. All are read by `#filePath`, as `DocsSampleTests` and
`reverbFixture` do.

---

## 1. The Trove ID is `id` (foundational)

No model change beyond doc comments on `Item.id` and `WishlistItem.id` saying
what `021` now relies on. The plan's whole second half rests on these claims;
each has the test that would catch it false, or is marked as unreachable.

| Claim | Test |
|---|---|
| `id` is a stored attribute: a value assigned before insert (the kept-code path) is what a second context reads back | `TroveIDTests`, second `ModelContext` (G1) |
| An edit through either form, a sale, and a return to the collection leave `id` as it was | `ItemFormViewModelTests`, `WishlistFormViewModelTests`, `ItemSaleStoreTests` (G1) |
| A Copy has a new `id` on both lists (criterion 19) | `ItemDuplicationTests`, `WishlistDuplicationTests` (G1) |
| An item made by Mark as bought has an `id` that is neither the entry's nor reused (criterion 19) | `WishlistPurchaseStoreTests` (G1) |
| Rows that existed before this build keep distinct codes across an upgrade and a relaunch (criterion 17) | **No in-memory test observes an on-disk upgrade** (`020`'s lesson) — T014(a), on a persistent store |
| The code is the same on a second device (criterion 40) | **Needing verification** — no test in `TroveTests` reaches CloudKit; `SYNC-CHECKS.md` step 3.13 |
| The store does not guarantee one row per code (CloudKit forbids `@Attribute(.unique)`; `CloudKitSchemaTests` is the standing guard) | The importer's own handling is tested instead: two stored rows sharing a code → the row is not applied (G13, G14) |
| An `Item` and a `WishlistItem` must never share a code — `MarketFigureRecord.subjectID` is unique and `MarketLocalStore.figure(for:)` does not filter by kind | R3's rule, G13 |

If any G1 leg fails as written, T001 stops and the question goes to a decision
review: the plan has no second design for the code.

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
  `£` or `¥`; then either digits with no commas (as today) or groups — one to
  three digits, then one or more `,ddd`; then an optional `.` and one or two
  digits. Nothing else: no sign, no brackets, no space after the symbol, no
  trailing text. `1,25`, `1.250,00`, `12,34,567`, `$`, `-5`, `(5.00)` and
  `500 USD` are nil. The symbol is discarded and never touches the currency.
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

**Testable claims** (G2–G4, `ImportGrammarTests`): criterion 11's two lists to
the cent; `ExportSchema.money` output still round-trips; criteria 12 and 13 in
both orders with explicit locales; a lower-case and a space-padded code read.
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
pins the old rule and is **rewritten**: missing required → named; extra →
listed in `unused`; renamed required → missing; renamed optional → unused;
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
}
```

`ImportSchema.itemsSheet(from:timeZone:locale:)` and `wishlistSheet(…)` replace
`itemsPreview` / `wishlistPreview`. Per data row, in this order:

1. More cells than the header has → skipped, "more columns than the header"
   (R7). Fewer → padded, as today.
2. Every cell blank by `isBlank` → dropped silently (so a row of `N/A`s is a
   blank row).
3. **Totals row** — the name is blank or, lowercased, one of `total`, `totals`,
   `subtotal`, `sum`; the Trove ID cell is blank; at least one other cell is
   filled; and every other filled cell, **unknown columns included**, sits in a
   money column (`Purchase Price`, `Current Value`, `Sale Price`; `Estimated
   Cost`) and reads as an amount → its number joins `totalsRowNumbers`, and it
   is neither a row nor a skip.
4. No name and no readable Trove ID → skipped, "no name". A nameless row with
   a readable code is kept: only the store knows whether it matches (P8).
5. Otherwise a row, every cell read by §2.

**`asNew(now:)`** on each row type returns `ValidatedRow<…ExportRecord>?` — nil
only when the name is empty — applying exactly today's field policy and counts
(the spec's "the defaults of `012` are for new rows only"): price, date, desire
and condition default and count when empty or unreadable; currency, current
value, Reverb product, year and Bought count only when unreadable; the sale is
the pair rule, counted once; an unreadable Trove ID counts once (P7). The
record carries `troveID` when the cell held a code.

**The fixture** `docs/samples/items-hand-kept.csv` (R8): the person's ten-column
header in their order; 24 invented item rows in four groups with an all-comma
row between groups; then three all-comma rows and a totals row whose two
amounts are the columns' true sums, written `"$12,345.67"`-style. Among the
rows: quoted prices with commas and unquoted `$395.54`-style ones, two `$0.00`
purchase prices, one bare `500` in Current Value, every date `M/D/YYYY` with at
least three days above 12, conditions Excellent / Very Good / Good only, at
least four serial cells `N/A` and six blank, one serial with a leading zero and
one with a `+`, one name with a doubled quote (`"… 42"" TV"`), one name with a
trailing space. LF endings, no BOM — what Sheets downloads.

**Testable claims** (G6, G7, `ImportSheetTests`): criterion 1 over the fixture
(24 rows, no skips, no defaults through `asNew`, one totals row at its exact
number, `regionDateOrder == nil`); criterion 3 — the fixture's columns shuffled
give equal rows; criterion 6; criterion 14 per column; criterion 15 including a
labelled row mid-file and a nameless row with a date, which is still skipped;
criterion 16 for the wishlist. A typo in a column lookup reads that column as
empty for ever — G14's round trip, which asserts every column, is what catches
it.

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
    var defaultedOnNew = 0, unreadableOnUpdates = 0
    var unusedColumns: [String] = []
    var totalsRows: [Int] = []
    var unusedSaleRows = 0
    var regionDateOrder: SlashDateOrder? = nil
    var writesAnything: Bool { added + updated > 0 }
}
nonisolated enum ImportPresentation<Row: Sendable>: Sendable {
    case confirmation(sheet: ImportSheet<Row>, summary: ImportSummary)
    case failure(title: String, message: String)
}
```

`ImportCopy`, every string pinned by literal in `ImportCopyTests`:

- `confirmationTitle(summary:)` — "Import this file?", or "Nothing to import"
  when `!writesAnything`.
- `confirmationLines(summary:target:) -> [String]`, in this order, each only
  when it has something to say: the counts ("90 items will be added." / "12
  items will be updated." / "12 items will be updated and 3 added."); "75 rows
  are unchanged."; the skipped block as today ("Skipping 2 rows:", "Row 7 — no
  name", "…and 3 more rows.") and, when any skip is a shared code, "Clear the
  Trove ID on the row that's a new item."; "4 missing or unreadable cells on new
  rows will use defaults."; "2 unreadable cells on updated rows will be left as
  they are."; "Not used: Mount, Insured."; "Row 108 looks like a totals row and
  was left out." (several: "3 rows look like totals rows and were left out.");
  "3 rows have sale details for items you still own. Mark them sold in the
  app."; "Dates read as month/day/year, from this iPhone's region."; and last,
  whenever `updated > 0`, "Updates can't be undone." With no line at all, the
  one line is today's "No problems found." Singulars are spelled out in the
  tests.
- Skip reasons (`ImportSchema.SkipReason`): `noName`, `extraColumns` ("more
  columns than the header"), `sameTroveID(asRows:)` ("same Trove ID as row 15" /
  "…as rows 15 and 16"), `ambiguousTroveID` ("its Trove ID matches more than one
  item"), `otherListTroveID` ("its Trove ID belongs to the other list").
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
  by each `init(item:)`; the two row functions append
  `record.troveID?.uuidString ?? ""`.
- `itemSchemaBoundaries` and `wishlistSchemaBoundaries` are deleted (Q6), with
  the doc comment on `itemHeaders` saying why append-only is still the rule
  (files are read by eye) though the reader no longer needs it.

Every CSV path builds its rows through `ItemExportRecord(item:)` /
`WishlistExportRecord(item:)` and its table through the two table functions, so
all five exports and both templates follow by construction — and that is a
claim, so G11 pins each path's output. The PDF builds from the same records and
must not show the code: `PDFEntry` does not read `troveID`, and G11 asserts no
field of any entry carries it. An app from before this spec cannot read these
files (its gate compares `Name *` with `Name`): stated in the reference doc, not
worked around.

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
  export would give**: text against the item's trimmed text; money, desire,
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

`ImportMatching.outcomes(ids:storedCounts:otherListIDs:)` — pure, shared by both
lists — gives each row one of `new(keeping: UUID?)`, `update(UUID)`,
`sharedInFile(with: [Int])`, `ambiguousInStore`, `otherList`: an `empty` or
`unreadable` code → `new(keeping: nil)`; a code on two or more rows of the file
→ `sharedInFile` for all of them, whatever the store holds; a code on more than
one stored row → `ambiguousInStore` (R2); a code in the other list → `otherList`
(R3); on exactly one stored row → `update`; on none → `new(keeping:)`.

**Testable claims** (G12, G13, `ImportUpdateTests`, no container): criteria 23–26
and 34's four legs, one field at a time; every fixture value differs from the
field's default **and** from the item's current value, so a broken path cannot
pass by coincidence. Named mutations in §13.

## 8. The two stores and the commit

```swift
enum ItemImportStore {                      // MainActor by the project default
    struct Plan { let adds: [ValidatedRow<ItemExportRecord>]
                  let updates: [(item: Item, changes: ItemChanges)]
                  let summary: ImportSummary }
    static func plan(for sheet: ItemsImportSheet, in context: ModelContext,
                     timeZone: TimeZone, now: Date) throws -> Plan
    /// Callers save, and roll back on a throw. Throws only from the market clear.
    static func apply(_ plan: Plan, in context: ModelContext, now: Date) throws
}
// WishlistImportStore: the same two functions over WishlistImportSheet.
```

`plan` fetches every `Item` (owned and sold — matching is against the whole
table, which is what lets a row correct a sold item) and the other list's ids,
runs `ImportMatching`, then per row: `new` → `asNew` (nil → skipped, "no name");
`update` → canonicalise the category, snapshot the item, `changes`; an empty
change set counts as unchanged. It writes nothing. `apply` inserts the adds at
the end of custom order in file order — today's commit, moved: placement
computed here, category casing resolved in file order, a readable sale pair
arriving sold, the wishlist's `Added` restoring `createdAt` — setting
`item.id = record.troveID` **before** insert when a code is kept; then writes
each change set field by field (condition through `item.condition`, so Very
Good keeps `020`'s stored pair; the sale through `item.sale`), clears the
device's market rows first when the Reverb product changes (P11), and stamps
`updatedAt` on updated items only. **An unchanged row writes nothing at all** —
not even `updatedAt` — so re-importing an untouched export dirties no record
and sends nothing to iCloud.

`confirmImport()` keeps its shape and its reason (the preview is captured in
the button's synchronous window — the `012` T017 device finding): capture the
sheet, clear the presentation, return unless `summary.writesAnything`, then in
the task `plan` again (Q3), `apply`, `save()`, and on any throw `rollback()` —
which now also discards half-applied updates — and the save-failure copy. Never
touched by any path: photos, sell-plan links, `sortOrder` of an existing row,
and the market rows of an item whose product did not change.

**Testable claims** (G14, G15; persisted assertions on a second `ModelContext`):
criterion 22 over an export of awkward values (a mid-afternoon purchase date, a
sold item, Very Good, a nil value, padded notes) — zero added, zero updated,
every row unchanged, and every `updatedAt` as it was; criteria 27–33; 34 end to
end; the resolve-at-confirm rule (an item deleted between staging and confirm
arrives as a new item carrying its code). Wishlist: criterion 35, `Added` and
`Looking For` included, and R4.

## 9. What is deliberately not built

- No mapping screen, no synonyms, no per-item preview, no undo (spec non-goals).
- No repair of two rows sharing a code (R2): detected at import, stated, left.
- No test-only launch argument to stage an import. The system file picker has
  kept the import flow out of the UI suite since `012`; a seed that *stages a
  write* is a wider branch than `-seedSellPlan`, and what it would buy — the
  alert's wiring — is `ImportWiringTests`' existing scans plus the walkthroughs.
  **Stated plainly: the alert on screen is covered by no automated test.**
- No `ImportPreview` compatibility shim: the type is deleted, and the existing
  field-policy tests are re-pointed through one test-side helper (§13, G10).

## 10. Docs and samples

`docs/csv-reference.md` is rewritten around the new rules and **opens with the
hand-kept-sheet loop**: import your sheet once, then work from Trove's export,
because only the export has the Trove IDs that make a re-import an update.
Then: columns found by name, the starred ones required; the two tables with
`Trove ID` as rows 20 and 11 and a "on an update" column beside "if blank";
prices, dates and the order rule, `N/A`, totals rows; added / updated /
unchanged and what an update never touches; sold status; what fails the whole
file; the caveats — leading zeros (P13), files move forward not back, importing
before sync has finished and what two copies with one code look like (R2).

Samples (`docs/samples/`, each pinned by `DocsSampleTests`):

- `items-full.csv`, `wishlist.csv` — rewritten in the layout the app now writes
  (starred header, 20 / 11 columns, BOM, CRLF) with fixed invented Trove IDs;
  imported twice, the second import reports every row unchanged.
- `items-edited.csv` — **new**, to import after `items-full.csv`: three rows
  edited, two rows sharing one code, one owned row with sale cells filled, one
  unreadable cell, one new row with no code, an unknown column, a totals row,
  slash dates that do not settle their order. Its confirmation shows every line
  §5 can produce, which is what R6 needs in front of eyes.
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

**No new UI test** (§9). `scripts/verify.sh ui` runs at each phase end as
regression — the templates rows, the menus and every seed are untouched — and
twice back to back after the device pass.

**Device pass** (T014, `general-purpose` agents, one dispatch per section, each
given only its own section and returning a pass/fail list; any failure goes to
the `sdd-implementer` as a diagnosis bundle and is logged as a sub-lettered
task). A section that cannot drive the system file picker returns "could not
perform" and its checks fall to the person, said so in the close-out:
(a) **the code on a store that predates this build** — install `main`, add two
items (sell one) and a wanted entry, install this branch over it, export
owned-and-sold and the wishlist, read the staged files from the app's
container: every row has a well-formed code, all different; terminate,
relaunch, export again: the same codes (criterion 17, the on-disk half);
(b) **the confirmation, by eye** — iPhone SE (3rd generation) and the pinned
phone, both appearances: `items-full.csv` then `items-edited.csv`; every line
readable, both buttons reachable, and the `bad-headers.csv` failure alert (R6);
(c) **300 rows** — a generated file of 300 new rows, then its export with half
the rows edited and 150 new rows appended: the busy badge draws, the list
answers a scroll while it runs, the counts read 150 updated / 150 unchanged /
150 added (criterion 38's feel); (d) **relaunch** — what (b) and (c) wrote is
still there.

**`specs/SYNC-CHECKS.md` gains two steps** under Part 3 (both devices on the new
build), drafted here so the close-out copies them: *"3.13 — An item's Trove ID
is the same on both devices. Do: on A, export the collection as CSV; on B,
export it too, including something added before this update. You should see:
the same code beside the same item in both files."* and *"3.14 — An update made
by importing reaches the other device. Do: on A, change three items' notes in
the exported sheet and import it. You should see: on B, the three notes, and
nothing else changed. Known edge, not a failure: importing the same exported
file on both devices while one is offline, for an item neither has, leaves two
copies with one code (`021` plan R2) — delete one."* Criterion 40 stays
unticked until then.

## 12. Close-out

T015, on an evidence bundle: criteria ticked with citations — **40 an honest
partial**, **20 ticked only if T013's recorded file exists**, 2 from what the
person said at the Phase 2 pause; "Superseded in part by `021`" pointers beside
`specs/011-data-export/plan.md:113`, `:132` and `:150`,
`specs/012-data-import/spec.md:45`, `:60` and `:94`, the header-gate and
money-and-dates paragraphs of `specs/012-data-import/plan.md` (§"Row pipeline",
§"Money and date parsing"), and `020`'s plan Q7 — never an edit to a shipped
line; the two SYNC-CHECKS steps; `README.md`'s import and export bullets; the
drafted `ROADMAP.md` and `DECISIONS.md` text (Q1 and R1, R2 with its edge, the
by-day comparison of §7, Q3's resolve-twice, Q6's retired boundaries) in a file
on the branch for `main` after the merge; `plan.md` gains **As built**.

## 13. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `TroveIDTests` and the five extended suites: a kept `id` read on a second context; `id` unchanged by a form edit, a sale, a return; a Copy's and a bought item's `id` new | the `save()` dropped (second context finds nothing) · `copy.id = original.id` in either `duplicate` · `item.id = wanted.id` in `markBought` · `item.id = UUID()` in a form's save |
| G2 | `ImportGrammarTests`, money: criterion 11's accepted list to the cent, its rejected list nil, `ExportSchema.money` round trip | the symbol setting anything · grouping accepted as `d{1,3}(,d+)*` (`1,25` reads) · commas stripped before parsing (`1.250,00` or `12,34,567` reads) |
| G3 | dates: ISO unchanged; file-decided month-first and day-first; region fallback under `en_US` and `en_GB` with `regionDateOrder` set; contradiction; two-digit year; an all-ISO file sets no order; `regional(for:)` for four locales | order decided per cell · region consulted when the file decides · `regionDateOrder` set for an ISO-only file · `3/9/26` read |
| G4 | `N/A`, `n/a`, `#N/A` blank and `NA`, `none`, `-` not; a lower-case and a padded code read, `abc` unreadable | `NA` accepted · the code compared as text rather than parsed |
| G5 | `ImportColumnsTests`: case, spaces, star; any order; every missing required name reported; duplicate; unknown names listed once in file order; wrong list both ways and for each shipped layout | only the first missing name reported · the star not dropped · an unknown column refusing the file · wrong-list tested by column count |
| G6 | `ImportSheetTests`, items: the hand-kept fixture (criterion 1), shuffled columns equal, required-only file, `N/A` per column, totals rows labelled and unlabelled anywhere, a nameless dated row still skipped, extra cells against the header's width | `N/A` blanked only in Serial Number · a totals row with a filled non-money cell left out · a totals row listed among the skips · the slash order taken from the first date |
| G7 | the same for the wishlist (criterion 16) | the wishlist money column missing from its totals rule · `Added` not offered to the date-order scan |
| G8 | `ImportCopyTests`: title; every line and its singular by literal; the order; "can't be undone" iff `updated > 0`; the three failure sentences | any word drifts · the hint shown without a shared-code skip · the undo line shown for adds only |
| G9 | `ItemImportStoreTests` / `WishlistImportStoreTests`, add path: appended in file order after every stored position, a sale pair arrives sold, category casing, `Added` restored | placement from a stale base · the pair half-written · `createdAt` left at now |
| G10 | the switch: every shipped layout (items 12, 14, 18, 19; wishlist 7, 9, 10) imports with zero skips and zero defaults; each whole-file failure writes nothing; the re-pointed field-policy tests with their assertions unedited; `ImportConcurrencyTests`' probe still off the main thread | a layout's column unread (a default appears) · `locale` not reaching the schema · a `@concurrent` dropped |
| G11 | `ExportSchemaTests`: both header rows by literal (stars, `Trove ID` last); each row's last cell is its record's code; `ItemListViewModelTests` / `WishlistViewModelTests` / `SettingsViewModelTests`: owned, sold, both, wishlist and Export All each write a non-empty, distinct code per row and the starred header; both templates are the header row and no rows; no PDF field holds a code | `init(item:)` dropping `troveID` · a table built from `itemHeaders` instead of the header row · a template left on the unstarred names · a PDF field added |
| G12 | `ImportUpdateTests`: each of the fifteen item fields changes alone; empty, `N/A` and a missing column each change nothing (serial, purchase date, current value); unreadable changes nothing and counts; empty name keeps the name; a mid-afternoon date equal by day is no change; padded text is no change; the sale's four legs | a default written for an unreadable or empty cell (`changes` falling back to `asNew`) · dates compared by instant · sale cells written onto an owned item · an empty cell clearing a field |
| G13 | `ImportMatching`: the six outcomes; a code shared in the file is never applied even when it matches | the first of two sharing rows applied · an unmatched code dropped instead of kept · a foreign-list code kept |
| G14 | items store and view model, second context: the round trip (criterion 22) with `updatedAt` untouched; updates persisted, Very Good as the literal pair `("good", "very good")`; an ID-less file imported twice makes two copies; an unmatched code is kept and the second import updates; shared and ambiguous codes leave the item untouched; an absent item is untouched; photos, plan links, `sortOrder` and market rows survive an update, and market rows are cleared when the product changes; Bought set on many; the sold rules; an item deleted between staging and confirm; rollback discards half-applied updates | `updatedAt` stamped on unchanged rows · `id` assigned after insert or not at all · the stage-time plan applied at confirm · the market clear skipped, or run on every update · `sortOrder` rewritten on update |
| G15 | the wishlist twin (criterion 35), with `Added`, `Looking For`, and a bought entry updated and still bought (R4) | `createdAt` compared by instant · a bought entry treated as unmatched |
| G16 | view models: the confirmation is staged before any write; Cancel leaves a second context's fetch unchanged; a summary that writes nothing offers no import action | `importOffersConfirmation` on `rows.isEmpty` rather than `writesAnything` |
| G17 | `DocsSampleTests`: every README claim; `items-full` twice → all unchanged; `items-full` then `items-edited` → the summary equal to a literal | a sample and its README disagreeing |
| G18 | the re-saved file (criterion 20): every code parses and matches its row in `items-full.csv`; imported over a store built from `items-full.csv`, the summary equals what the README says Sheets changed | Sheets damaging a code — **this is the guard that can fail on a fact the plan does not control** |
| G19 | criterion 38: the parse probe; a 300-row mixed plan-and-apply timed in memory, **recorded, not asserted** | the probe red if parsing moves to the main actor; the timing is evidence, not a gate |

Every guard is mutation-verified before it lands and the Done note records what
was broken and what went red; persisted assertions refetch on a second
`ModelContext`; no scan is added by this spec — every rule here is reachable by
a pure-function, store or view-model test. What the suites cannot reach: the
on-disk upgrade and the alert's look (T014), the person's own file (the Phase 2
pause), a real spreadsheet's re-save (T013, the person's recording — and Excel
and Numbers are **stated untested** unless a recording of each is added), and a
second device (`SYNC-CHECKS.md`).

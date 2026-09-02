# 012 — Data Import

Status: **Approved** (2026-08-31, same day as drafting; the
transport-damage rules, the second row-fatal condition, the skip-list
cap, and the trimming rule were amended the same day during planning
— see the amendment notes inline and Decisions record 9–12. Authored
in-session at the person's direction — the venue decision is recorded
in `DECISIONS.md` and the constitution's authorship-split section was
amended first, in its own commit. Every product decision below was
made by the person in that conversation; the Decisions record section
lists them.)

## What and why

Get a collection *into* Trove without typing every item by hand. Two
people need this: the new user arriving with the spreadsheet of gear
they already keep (the migration case — the app's core audience by
definition already tracks this stuff somewhere), and the existing user
restoring or moving data via a previous Trove export (the round-trip
case that `011` deliberately designed its CSV schema for).

Import is the read half of the contract `011` shipped: it parses the
canonical CSV schema, defined once in `specs/011-data-export/plan.md`
§"The canonical CSV schema" and pinned in code. This spec adds no new
schema — the columns, order, and formats are inherited, and the
append-only growth rule recorded there binds both features together.

Decisions carried in from the roadmap, made ahead of this spec:

- **Rigid Trove-defined template.** The file must use Trove's own
  column layout — the same one export produces. No column-mapping UI;
  mapping is recorded as a likely later enhancement once real-world
  friction with the rigid template is observed, not part of v1.
- **CSV only.** No `.xlsx`/Numbers native formats — every spreadsheet
  app can export CSV.
- **Photos are not imported.** They belong to Trove's own capture flow;
  CSV has no photo representation.

## Core behavior: import is view-independent

Unlike export, which acts on the filtered, sorted view, import always
adds to the **full collection**. The active filter and search are
irrelevant to what gets imported — and if a filter is active when an
import completes, some imported items may legitimately not be visible
until it's cleared. Import never modifies or deletes anything that
already exists: every accepted row becomes a **new** item. The schema
has no `id` column by design (`011`'s recorded decision), so there is
nothing to match against and no update-in-place path.

## Entry point

The "…" menu on both list screens — the overflow affordance `011`
introduced and expected to accumulate actions — gains two:

- **Import from CSV…** — opens the system document picker for a CSV
  file, then runs the flow below.
- **Get Blank Template…** — stages a header-only canonical CSV through
  the share sheet (`Trove-Items-Template.csv` /
  `Trove-Wishlist-Template.csv`), so a spreadsheet of gear can be
  built against the exact expected columns.

**The badge becomes always visible.** `011` hid the "…" with the rest
of the header controls on an empty collection, which was right when
every action in it was an export of nothing — but it would lock out
exactly the person import serves most: the new user with an empty
collection and a spreadsheet in hand. From this spec on, the badge
shows regardless of collection size; the two export actions keep their
existing disabled state (nothing to export), and the two import
actions are always enabled. This supersedes the visibility half of
`011`'s criteria 1–2; a cross-reference note is added to `011`'s
`spec.md` as part of this spec's implementation.

Each screen imports its own kind: the Items list imports the 12-column
items schema, the Wishlist the 7-column wishlist schema. A file whose
header row belongs to the other list fails the header gate like any
other wrong file (the alert should recognize this case and say so —
it's the most likely wrong-file mistake).

## The import flow

Parse first, commit second. The whole file is read and validated in
memory before anything touches the store:

1. **Header gate.** After skipping an optional BOM, the header row must
   contain exactly the canonical column names in the canonical order
   (each header cell compared after trimming surrounding whitespace).
   Extra, missing, renamed, or reordered columns fail the whole file —
   a plain alert names the problem and nothing is imported. This is
   what "rigid template" means; it is also what keeps `011`'s
   append-only schema-growth rule enforceable.
2. **Row validation.** Every data row is parsed against the field
   policy below. Rows are never silently altered: every skipped row
   and every defaulted field is counted for the confirmation.
3. **Confirmation.** One alert before anything is written:
   - how many items will be imported;
   - which rows will be skipped, by number, with a brief reason
     ("row 7 — no name"). Row numbers are **as a spreadsheet displays
     them** — header is row 1, first data row is row 2 — because
     that's where the user will go look;
   - how many fields will be filled with defaults.
   **Cancel leaves the collection untouched.** If zero rows are
   importable, the alert is informational only — no import action to
   confirm.
4. **Commit.** On confirm, the accepted rows are inserted. The batch
   appends to the **end of custom order, preserving the file's row
   order within the batch** — exactly where a hand-added item lands
   today. On the wishlist, the same rule against its custom order.
5. **Progress.** While parsing or committing, the "…" badge shows the
   same progress affordance export uses, and the UI stays responsive.

There is no undo beyond the confirmation step — which is why the
confirmation exists. Backing out after commit means deleting items by
hand, and the spec accepts that because the gate is in front.

## Parsing tolerance

The writer is strict; the reader is tolerant, because files come back
after passing through other software:

- BOM optional (Trove writes one; not every editor preserves it).
- CRLF, LF, and CR row endings all accepted; trailing newline optional.
- Any RFC 4180-valid quoting accepted — not just Trove's minimal
  quoting. Fields containing commas, quotes, and newlines survive
  exactly. A file exported by Trove and re-saved by Numbers, Excel, or
  Google Sheets must still import.
- Trailing empty cells are stripped from the header row and every
  data row before any other rule applies — spreadsheet apps emit
  `...,Notes,,,` whenever the sheet's used range outgrew the data,
  and the rigid header gate must not reject a re-saved file for it.
  *(Amended 2026-08-31 during planning.)*
- Wholly blank lines are skipped silently, never reported — a
  trailing blank line must not produce a phantom skip on a clean
  file. *(Same amendment.)*
- What stays strict: the header gate above, and the field formats
  below. Tolerance is about transport, not about guessing at data.
  One structural corruption fails the whole file rather than a row:
  an unclosed quote, which swallows the remainder of the file into a
  single field — "skipping" it would silently import garbage. *(Same
  amendment; criterion 14 lists it.)*

## Field policy (skip vs. default)

The rule, applied per field: a field the data model treats as
**optional** imports as empty, silently — empty is a legitimate value
there. A field the model **requires** gets its model default when the
cell is blank or unparseable, and each such default is **counted in
the confirmation**. Two conditions are row-fatal *(the second added
2026-08-31 during planning)*: a row with no **Name** is skipped
(reported with its row number) — a nameless item is not an item — and
a row with **more content cells than the schema** (after
trailing-empty stripping) is skipped and reported, because a stray
comma shifts every later column one place and no guess about which
field it belongs to is safe. Rows with *fewer* cells are padded with
empty cells (transport damage), which then follow the ordinary
blank-cell policy.

"Blank" throughout means **empty after trimming**, and imported cells
normalize through exactly the rules the app's own forms apply —
trimmed names, whitespace-only optional cells stored as empty — so an
imported item is indistinguishable from a hand-typed one, and a
whitespace-only Name skips its row. *(Amended 2026-08-31 during
planning.)*

**Items:**

| Column | Blank cell | Unparseable | Counted? |
|---|---|---|---|
| Name | **skip row** | — | row reported |
| Category | uncategorized (empty path) | — any text is a valid path; `/` nests | no |
| Purchase Price | `0.00` | `0.00` | yes |
| Currency | `USD` | `USD` | blank: no; malformed: yes |
| Purchase Date | today | today | yes |
| Purchase Location | empty | — | no |
| Current Value | **unvalued** (`011`'s empty-cell-≠-zero rule, in reverse) | unvalued | blank: no; unparseable: yes |
| Desire to Keep | `3` | non-integer or outside 1–5: `3` | yes |
| Condition | `excellent` (model default) | unknown value: `excellent` | yes |
| Condition Notes / Serial Number / Notes | empty | — | no |

**Wishlist:**

| Column | Blank cell | Unparseable | Counted? |
|---|---|---|---|
| Name | **skip row** | — | row reported |
| Category | uncategorized | — | no |
| Estimated Cost | `0.00` | `0.00` | yes |
| Currency | `USD` | `USD` | blank: no; malformed: yes |
| Desire to Own | `2` | non-integer or outside 1–3: `2` | yes |
| Added | now | now | yes |
| Notes | empty | — | no |

Format specifics:

- **Money**: a plain decimal number with a dot separator, per the
  canonical schema — `1250.00`, and bare integers (`1250`) are
  accepted as whole amounts. Currency symbols, thousands separators,
  and locale decimal commas are *not* accepted (no locale guessing —
  the same stance the writer takes); such cells take the default and
  are counted. An imported amount must round-trip to the exact cent
  value the canonical schema would export for it.
- **Dates**: `yyyy-MM-dd` only, read as a device-local Gregorian
  calendar day, mirroring the writer. This inherits `011`'s recorded
  timezone caveat: a round trip is day-stable within one timezone.
  (Beware Excel: it likes to rewrite date cells into locale formats
  on save — the template docs must warn about it.)
- **Condition**: matched case-insensitively against the five known
  values (`new`/`excellent`/`good`/`fair`/`broken`), so a hand-typed
  `Excellent` works.
- **Currency**: a three-letter alphabetic code is stored uppercased,
  verbatim (the model's ISO 4217 field takes it; v1's display remains
  USD-centric, which is the existing multi-currency groundwork's
  known limit, not this spec's problem).
- **Wishlist `Added`** restores `createdAt` — the round trip preserves
  when a wish was added. Items have no `Added` column (`011`'s
  recorded asymmetry), so imported items get the import moment as
  their creation time.

## Duplicates

None detected, by decision: the person curating the file is the one
deciding what the data should be. Importing the same file twice
produces two copies of every row — stated behavior, not a bug. The
confirmation step's count is the guard against doing it by accident.

## Template and reference docs

"Get Blank Template…" is the in-app half. The repo half is a
README-style column reference (exact location decided at plan time)
documenting each column's format, the blank-vs-default behavior above,
and the Excel caveats (date rewriting, long serial numbers) — the
"export a template, fill it in, import" loop is the documented
recommended path for migration.

## Decisions record

All made by the person, 2026-08-31, in the design conversation:

1. Malformed input: **report and skip, never abort** — per-field
   defaults where the field allows it, row-skip only when unusable.
2. Duplicate detection: **none** — the user decides what the data is.
3. Confirmation: **parse fully first, confirm before commit** — the
   report comes as a pre-commit alert (counts, skipped rows, defaults),
   not a post-hoc one, since full validation precedes insertion anyway.
   (Refined from an initial import-then-report lean once it was clear
   the confirm step costs no extra UI.)
4. Entry point: **the "…" menu's third action** (plus the template as
   the fourth).
5. Scope: **both lists** — items first, wishlist as a follow-on phase
   in the same spec.
6. Ordering: **positional, batch appended to the end of custom order,
   no Order column** — the file's row order is the order, exactly as
   the export schema encodes it; an Order column would break the
   byte-for-byte header contract and export would never produce one.
7. Currency: **column honored, blank defaults to USD.**
8. Empty-collection access: **the "…" badge becomes always visible**,
   export actions stay disabled when there's nothing to export, and
   the menu gains **Get Blank Template…** — superseding `011`'s
   hide-when-empty rule, recorded there.

Added 2026-08-31, during planning (escalated as spec-level, decided
by the person):

9. Transport damage: trailing empty cells stripped before all rules;
   wholly blank lines skipped silently; an unclosed quote fails the
   whole file (it swallows the remainder into one field — skipping
   would import garbage).
10. A row with extra content cells is the second row-fatal condition
    — a stray comma shifts every later column; no safe guess exists.
11. The confirmation's skip listing is capped: first five rows with
    reasons, then "and N more rows"; counts always complete.
12. Imported cells normalize through the forms' own trimming rules;
    "blank" means empty after trimming.

## Acceptance criteria

1. [x] The "…" badge shows on both list screens even when the
   collection is empty. Export as CSV/PDF keep exactly their existing
   disabled behavior; Import from CSV… and Get Blank Template… are
   always enabled. `011` `spec.md` criteria 1–2 carry a superseded-by
   note pointing here.
2. [x] **Round trip**: a file exported by `011` from a populated
   collection imports into an empty collection with zero skips and
   zero defaults, and the resulting list in custom order shows the
   same items, same field values, same order as the file.
3. [x] Transport tolerance: the same file imports identically with BOM
   removed, with LF-only endings, without the trailing newline, with
   trailing empty columns on every line (header included), with blank
   lines interleaved, and with maximal RFC 4180 quoting — including
   fields containing commas, quotes, and embedded newlines. *(Amended
   2026-08-31: trailing-column and blank-line cases added.)*
4. [x] Header gate: a file with a missing, extra, renamed, or
   reordered column imports nothing and shows a plain alert naming
   the problem. A wishlist file offered to the items list (and vice
   versa) is recognized as the other list's format in the alert.
5. [x] The confirmation alert precedes any write: it states the
   import count, lists skipped rows by spreadsheet-style row number
   with reasons — the first five, then "and N more rows" *(cap added
   2026-08-31 during planning)* — and states the defaulted-field
   count. Cancel leaves the store byte-identical. Zero importable
   rows produces an informational alert with no import action.
6. [x] Field policy holds as tabled: a row with no Name (after
   trimming) or with extra content cells is skipped and reported;
   blank model-optional fields import as empty silently; blank or
   unparseable required fields take the tabled default and are
   counted; blank Current Value imports as unvalued, not zero.
   *(Amended 2026-08-31: second row-fatal condition, after-trim
   blankness.)*
7. [x] Money: canonical-format amounts import to the exact cent value
   export would write for them; bare integers are whole amounts;
   symbols, thousands separators, and decimal commas are rejected to
   the default and counted.
8. [x] Dates parse `yyyy-MM-dd` as the device-local Gregorian day and
   nothing else; condition matches case-insensitively; a three-letter
   currency code is stored uppercased, blank becomes USD.
9. [x] The imported batch lands at the end of custom order with the
   file's row order preserved within it, on both lists; switching to
   custom sort immediately after import shows the batch there.
10. [x] Import is view-independent: with a category filter active, the
    full file still imports; imported items outside the filter appear
    once the filter is cleared.
11. [x] Importing the same file twice yields two copies of every
    accepted row — stated no-dedupe behavior, verified.
12. [x] Get Blank Template… stages a header-only canonical CSV
    (correct name per list) through the share sheet, and that
    template — filled with one valid row in a spreadsheet app and
    re-saved — imports cleanly.
13. [x] Wishlist parity: criteria 2–12 hold on the wishlist against
    its 7-column schema, with `Added` restoring the wish's creation
    date.
14. [x] A failed import (unreadable file, undecodable text, header
    mismatch, an unclosed quote, a file beyond the defensive size
    cap) shows a plain alert in `011`'s failure style and imports
    nothing — never a partial batch. *(Amended 2026-08-31: the last
    two causes added during planning.)*
15. [x] The UI stays responsive while a 300-row file parses and
    commits, with the badge showing the progress affordance
    throughout — same bar `011`'s criterion 11 set for export.
16. [x] The column-reference doc exists, covers every column's format
    and default, and carries the Excel caveats.

### Verification record (T018, 2026-09-01)

Citations per criterion; every named guard is mutation-verified per
the constitution (each task's Done note in tasks.md records what was
broken and what went red). "Device" means the T017 simulator pass.

1. Header restructure in both list views;
   `ImportWiringTests.theOverflowControlSitsOutsideEveryEmptyCollectionGate`
   (brace-span scan, both views) + the empty-collection UI test — one
   re-nest mutation turned both red;
   `ExportWiringTests.theMenuCarriesFourActionsWithOnlyExportsGated`
   (gating count pinned at exactly 2); 011 spec.md criteria 1–2 carry
   the superseded-by note; device.
2. `aTroveExportRoundTripsLosslessly` / `aWishlistExportRoundTripsLosslessly`
   (serialization equality via `ExportSchema.row(from:)`, zero skips,
   zero defaults); order by `commitAppendsAtTheEndPreservingFileOrder`
   + the device Custom-sort check. The empty-collection restore is the
   append-to-nothing case of the same commit path.
3. `CSVParserTests` (all endings incl. lone-CR tail, BOM optional,
   minimal-vs-maximal quoting, embedded comma/quote/newline/CRLF);
   `aResavedFileWithTrailingColumnsAndBlankLinesShapesClean`.
4. `missingExtraRenamedAndReorderedColumnsAllMismatch`;
   `theOtherListsHeadersAreRecognizedAsWrongList` (+ the preview-level
   twins); `theOtherListsFileMapsToTheFlaggedMismatch`;
   `theWrongListMessageNamesTheOtherList`; device (the alert, verbatim).
5. `cancelClearsThePresentationWithoutStoreWrites`;
   `aZeroImportableConfirmationClearsWithoutWrites` +
   `importOffersConfirmation` accessors; `theSkipListingCapsAtFive`
   (boundary pinned); `skipReportsUseSpreadsheetNumbersPastEmbeddedNewlines`;
   device (counts, rows 4/6, Cancel leaving 1 item).
6. The `ImportSchemaTests` field-policy block (13 items tests + the
   wishlist table tests): both row-fatals, after-trim blankness,
   silent optionals, counted defaults, zero-vs-blank Current Value.
7. `canonicalMoneyFormsParseCentExact`, `bareIntegers…`,
   `nonCanonicalMoneyIsRejected` (13 forms),
   `moneyOverflowRejectsWithoutTrapping`,
   `writerMoneyRoundTripsThroughTheParser` (+ `Money.cents`
   equivalence — 011's preserved invariant).
8. Date shape/impossible/DST/Gregorian-pin tests;
   `conditionMatchesCaseInsensitively`;
   `currencyIsThreeLettersUppercased`; device ("Good"/"usd"/leap day).
9. `commitAppendsAtTheEndPreservingFileOrder` (second-context
   verification — see the T018 audit note),
   `thePlacementBaseIsComputedAtCommitTimeNotParseTime`,
   `aLegacyAllZeroStoreStillLandsTheBatchAfterTheLegacyBlock`; device.
10. `importIsViewIndependentOfTheActiveFilter`.
11. `committingTheSameFileTwiceDuplicatesEveryRow`.
12. Template twins in both VM test files (byte-exact BOM+header+CRLF,
    pinned filenames, `canExport` ignored); the closed-loop tests
    (template + one hand row → exactly one record); device (68-byte
    share sheet). Honest partial: the fill-in-a-real-spreadsheet
    re-save needs Numbers/Excel hands — the transport fixtures cover
    the file shapes those apps produce.
13. The wishlist halves of everything above +
    `commitAppendsAndRestoresCreatedAtFromAdded` and
    `oldAddedDatesCannotStealAnExistingPathsCasing`; device
    ("ADDED MAY 10, 2024").
14. `ImportServiceTests` error mappings (all five);
    `failureMessagesAreActionableAndAllEndWithTheGuarantee` (every
    error × target); rollback mechanism test + per-VM catch scan +
    the T018 deleted-`save()` mutation now caught by second-context
    fetches; device (wrong-list alert).
15. `ImportConcurrencyTests` (off-main parse, through the
    existential); `isImportingFileIsObservableMidFlightAndBlocksReentry`
    (both VMs); the yield in `confirmImport`; ~85 ms measured commit
    (plan §The commit path); device (300 rows, instant, responsive).
    Honest partial: at these speeds no spinner is visible — the
    affordance is guarded by state tests, not eyeballs.
16. `docs/csv-reference.md`, checked line-by-line against the field
    tables this pass: all 19 columns with format/blank/unreadable,
    both row-fatals, the whole-file list, all three Excel caveats,
    linked from README.

## Non-goals (explicit)

- **Column mapping UI** — recorded as the likely next enhancement to
  import once rigid-template friction is real, not speculative.
- **Photo import**, in any form.
- **Updating or merging existing items** — import only creates; no
  `id` column exists to match on.
- **Duplicate detection** of any kind (decision 2).
- **Non-canonical field formats** beyond the stated tolerance — no
  locale date/number guessing, no currency-symbol parsing.
- **`.xlsx` / Numbers native import.**
- **Sell-plan, dashboard, or settings import** — follows the same
  deferrals as `011`'s export side.
- **A dedicated preview screen** — the confirmation alert is the
  gate (decision 3); a richer preview belongs with the mapping UI if
  that day comes.

## Inherited caveats

From `011`, unchanged and binding here: the timezone day-stability
caveat on dates; the Excel serial-number mangling caveat (long digit
strings coerced on default open — the text-import path and the
template docs are the mitigation); and the append-only schema growth
rule — a new column lands in `011`'s plan tables, the shared schema
constants, the writer, *and this parser* in the same change, never a
subset.

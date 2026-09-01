# 012 — Data Import — Tasks

Status: **Draft** (2026-08-31, drafted in-session against the approved
plan; awaiting human review — no implementation before approval)

Ordering note, recorded up front: spec decision 5 ("items first, then
wishlist as a simple addition") is honored at the layer where the risk
lives — the validation pipeline is built and proven for items (T005)
before the wishlist variant exists (T006). From the service layer up,
tasks follow 011's twins pattern (both lists per layer) rather than a
strictly sequential wishlist phase, because the shared `OverflowBadge`
and the shared service protocol would otherwise force interim no-op
menu items onto the wishlist screen mid-branch — dead UI that survives
until a later phase deletes it. The novel work is still items-first;
the twins layers are shipped 011 machinery being extended
symmetrically.

Standing rules (constitution): every guard is mutation-verified before
its task closes — break the rule, watch the named test go red, note it
in the Done note. A task is done only when `xcodebuild build` and
`xcodebuild test` are green with actual output reported (suite-level
`-only-testing` selectors, test count checked — per-function selectors
run zero tests and report success). One commit per task, referencing
the task ID.

---

## Phase 1 — Transport: the parser

### T001 — `CSVParser`

Build `Trove/Import/CSVParser.swift`: the Unicode-scalar state machine
per plan §The parser. BOM strip; CRLF/LF/CR row endings with explicit
CR-then-optional-LF consumption; any RFC 4180 quoting (embedded
doubled quotes, embedded newlines); trailing newline optional;
unclosed quote at end of input throws `CSVParseError.unclosedQuote`
(the transport-level error — `ImportError` wraps it at T007);
output rows tagged with spreadsheet row numbers (counted per parsed
record; header = 1).

Tests (`TroveTests/CSVParserTests.swift`), golden fixtures — not the
test-only `RFC4180`, which may only cross-check writer-produced files:
minimal vs maximal quoting; comma/quote/newline/CRLF-inside-field;
lone LF file, lone CR file, CRLF file, CR as final byte; BOM
present/absent; trailing newline present/absent; unclosed quote
throws; the embedded-newline row is numbered as one spreadsheet row.

Red checks: break the CR-peek (treat CR and LF independently) →
ending fixtures red; strip quote handling → embedded-newline fixture
red; increment the row counter per physical line → row-number fixture
red.

### T002 — Row shaping

In `Trove/Import/ImportSchema.swift` (first slice): trailing-empty-
cell stripping over header and data rows; wholly-blank-row dropping
(silent — the shaped output carries no trace of them). Amended
criterion 3's transport fixture: a canonical items file with four
trailing commas on every line (header included) plus interleaved blank
lines shapes to exactly the clean file's rows.

Red checks: remove stripping → transport fixture red; report blank
rows instead of dropping → fixture asserting no phantom skips red.

---

## Phase 2 — Meaning: schema and field policy

### T003 — Header gate and wrong-list detection

Header gate comparing trimmed cells against
`ExportSchema.itemHeaders`/`wishlistHeaders` read directly (column
indices derived from array positions, no hand-numbered constants).
Errors introduced here as the schema-level error type: mismatch, and
the wrong-list variant (exact match against the *other* schema's
headers, checked first).

Tests (`TroveTests/ImportSchemaTests.swift`): exact header passes;
missing / extra / renamed / reordered columns fail with mismatch; a
wishlist header row offered to the items gate (and vice versa) yields
the wrong-list variant; trailing-empty-stripped headers pass (ties to
T002).

Red checks: reorder two entries in a *copied* header list inside the
gate (simulating drift from a hand copy) → the pass-fixture built from
`ExportSchema.itemHeaders` goes red — which is the point of reading
the array directly; drop the wrong-list check → its test red.

### T004 — Field parsers

Money, date, desire, condition, currency parsers per plan §Money and
date parsing — all pure, no `Locale`/`DateFormatter`/`Decimal`
anywhere in the path.

Tests: money — canonical forms parse cent-exact; equivalence with
`ExportSchema.money(cents:)` across a cent spread (0, 1, 999,
100_00, 999_999_999_99) and with `Money.cents(from: Decimal(string:))`
on canonical forms (011's preserved invariant); rejects `1250.`,
`.50`, `1250.000`, `+5.00`, `-5.00`, `$5`, `1,250.00`; accepts `007`,
bare integers; overflow-checked (a 25-digit string rejects, no trap).
Date — strict 4-2-2 (`2026-1-5` rejects); `2026-02-30` rejects via
components round-trip; DST fixture (`America/Santiago` spring-forward
day resolves); a Gregorian pin mirroring
`dayIsAlwaysGregorianRegardlessOfDeviceCalendar` (Buddhist-calendar
device cannot leak in — the parser builds its own calendar over the
injected `TimeZone`). Desire in-range/out-of-range/non-integer;
condition case-insensitive over the five raw values; currency
three-letter uppercased, blank → USD silent, malformed → USD counted.

Red checks: let the money scan accept a comma → rejection test red;
swap the parser's calendar to `Calendar.current` → Gregorian pin red;
skip the components round-trip → `2026-02-30` test red.

### T005 — Items row validation

`ValidatedRow` (wrapping `ItemExportRecord`, `firstPhotoID: nil`) +
`ItemsImportPreview` + the items field-policy table wired end-to-end,
normalizing through the form's own `trimmed`/`nilIfBlank` statics.
Row-fatal: empty Name after trim; extra content cells. Defaults
counted per the spec's table (silent vs counted per its Counted?
column). `ExportSchema.firstPhotoID` gets its doc-comment note (import
constructs records photo-free).

Tests: one per table row class (blank vs unparseable vs silent-empty,
Current Value blank = unvalued not zero); whitespace-only Name skips;
extra-cells row skips with reason; under-length row pads then follows
blank policy; the embedded-newline-then-nameless fixture pins
spreadsheet numbering of skips; per-row and total defaulted counts.
**Round trip**: seeded records → `ExportSchema.itemsTable` →
`CSVWriter` → parse → validate → `ExportSchema.row(from:)` equality
per record, zero skips, zero defaults. **Closed loop** (the plan's
highest-value test): header-only template bytes + one hand-appended
canonical row → exactly one validated record with the appended
values.

Red checks: make blank Name default instead of skip → policy test
red; drop trimming → whitespace-Name test red; remove a column from
the round trip's row builder → serialization equality red.

### T006 — Wishlist row validation

The wishlist variant: gate (from T003), 7-column policy table,
`Added` parsed with the date parser into the record's `createdAt`,
desire 1–3 defaulting to 2. `WishlistImportPreview`.

Tests: the wishlist policy table per class; wishlist round trip and
closed loop mirroring T005's.

Red checks: same shapes as T005, wishlist side; point `Added` at
today instead of the parsed date → round trip red.

---

## Phase 3 — Service and concurrency (walking skeleton)

### T007 — `ImportService` and `ImportCopy`

`Trove/Import/ImportService.swift`: the protocol (both `@concurrent`
requirements), `FileImportService` (security-scoped read tolerating a
false start-access, conditional stop in defer; 10 MB pre-read size
cap; UTF-8 decode; parse; validate), `ImportError` (unreadable /
undecodable / malformedQuoting / tooLarge / headerMismatch with
wrong-list flag), `ImportCopy` (per-error titles and messages — the
undecodable copy names Excel's "CSV UTF-8" save; the unreadable copy
mentions downloading the file — the confirmation title, and
`confirmationMessage(preview:)` with the first-5-plus-"and N more"
cap and the informational zero-importable variant).

Tests (`TroveTests/ImportServiceTests.swift` — real temp-file I/O, the
same narrow disk exception `ExportTempFileTests` records): a written
canonical file parses through the service; each error case maps
(garbage bytes → undecodable; oversized file → tooLarge; wrong-list
header file → the flagged mismatch); `ImportCopy` message tests pin
the cap boundary (5 skips = no "more" line, 6 skips = "and 1 more"),
the zero-importable copy, and the actionable strings.

Red checks: raise the cap boundary off-by-one → cap test red; swallow
the wrong-list flag → its copy test red.

### T008 — Concurrency probe

`ExportConcurrencyTests`' shape verbatim for import: an injected probe
samples `Thread.isMainThread` through the synchronous helper inside
`FileImportService`'s generation body; the test calls through
`any ImportService` and asserts off-main.

Red check (the SE-0461 doctrine's guard): remove `@concurrent` from
the protocol requirement → probe records main-thread → red.

---

## Phase 4 — View models (twins)

### T009 — `CategoryPathHelper.canonicalize(_:against:)`

The flagged production change to a shipped file: extract the
case-insensitive match rule as a pure static; the existing instance
method delegates to it. No behavior change.

Tests: pure-function cases (match returns existing casing, no match
returns input); the existing `CategoryPathHelperTests` stay green
untouched — that *is* the no-behavior-change evidence.

Red check: make the static case-sensitive → delegation keeps the
existing canonicalize tests red.

### T010 — Import surface on both view models

`TestSupport`: `ImportServiceSpy` + `GatedImportServiceSpy` (gates
only the first call — the T019/S1 lesson, so a wrongly-leaked
reentrant call fails the count assertion fast instead of
deadlocking). Both VMs: `importPresentation` enum (view-settable),
`isImportingFile` (named against the CloudKit-sync collision, comment
says why), `isBusy`, `importCSV(from:)`, `cancelImport()`; every
export and import intent guards on `!isBusy`.

Tests (import suites in both VM test files): mid-flight observability
and reentry block via the gated spy; a thrown `ImportError` maps to
`.failure` with the exact `ImportCopy` strings; cancel clears the
presentation with zero store writes; `isBusy` serialization — an
in-flight import refuses `exportCSV` and vice versa.

Red checks: drop the `isImportingFile` set → mid-flight test red
(both VMs); route the failure copy through a literal → string test
red.

### T011 — `confirmImport` (the commit path), both view models

Per plan §The commit path, exactly: leading `await Task.yield()`;
canonical path set fetched once, batch casing first-occurrence-wins
via T009's static, resolved paths joining the against-set; fetch-all
once, `base = ManualOrderHelper.nextPosition(after:)`, `base + i` in
file order, computed at commit; items get `createdAt`/`updatedAt` =
now; wishlist restores `createdAt` from the record after construction
(commented — the init hard-sets `.now` deliberately); insert all,
save once; catch → `modelContext.rollback()` → `.failure`; then
`load()`.

Tests: batch appends at end preserving file order; the legacy fixture
(every existing item at `sortOrder` 0) still lands the batch after
the legacy block; view-independence (category filter active →
`totalCount` grows by batch size); importing the same preview twice
duplicates every row (criterion 11); casing — existing
`Photography/Cameras` survives an import of `photography/cameras`,
including the wishlist file with `Added` 2015 (the
earliest-`createdAt` theft the canonicalization prevents); intra-batch
`guitars` + `Guitars` collapse to the first occurrence; wishlist
`createdAt` equals the parsed `Added` day; rollback mechanism test
(insert, roll back, fetch empty) + `SourceScan` on `confirmImport`'s
catch calling `rollback()` (the falsifiable wiring guard — forcing a
real SwiftData save failure deterministically is not practical, and
the plan records that honestly).

Also here: **measure** a 300-row commit on the simulator and record
the number in plan.md §The commit path (chunk across yields only if
it exceeds ~100 ms).

Red checks: compute the base at parse time (cache it) → a test that
inserts an item between parse and confirm goes red; skip
canonicalization → casing tests red; remove `rollback()` → the scan
red.

### T012 — Blank template intents

`ExportFilename.itemsTemplate`/`wishlistTemplate` (the enum stays the
only namer of share-sheet files); `exportBlankTemplate()` on both VMs
— guarded on `isBusy` only, **not** `canExport` — staging the
zero-row table through the existing `exportCSV(_:filename:)` path.

Tests: with an empty list, the intent stages a file whose bytes are
exactly BOM + header row + CRLF, named per the pinned template
filename; `canExport` false does not block it; the spy sees the
existing export method (no new protocol surface).

Red checks: gate the intent on `canExport` → empty-list test red;
inline the filename → the pinned-name test red.

---

## Phase 5 — UI (twins)

### T013 — `OverflowBadge`

`git mv` `ExportBadge.swift` → `OverflowBadge.swift` + type rename
(no `.pbxproj` edit — synchronized groups; verify the build proves
it). Props `isBusy`/`canExport` + four closures; menu: both export
actions (pinned strings, each `.disabled(!canExport)`), `Divider`,
"Import from CSV…", "Get Blank Template…" always enabled;
accessibility label "Working" while busy / "More actions" otherwise;
preview updated. `ExportWiringTests` updated to the new name and
props and extended: all four intents fired, menu strings pinned,
export gating count still exactly 2.

Red checks: gate a new action on `canExport` → the always-enabled
assertion red; drop the Divider or a string → pinned-strings red.

### T014 — Headers, fileImporter, and the import alert

Both list views: overflow control moves outside the
`if viewModel.totalCount > 0` gate (sort badge stays inside);
`.fileImporter` with `[.commaSeparatedText, .plainText]`, cancel a
no-op (verify the actual iOS 26 callback behavior here and note it);
one import alert presenting off `importPresentation` — confirmation
variant with Import/Cancel (info-only when zero importable), failure
variant with OK.

`TroveTests/ImportWiringTests.swift` (SourceScan): overflow call
outside the `totalCount` brace-span on both views; fileImporter
attached with both content types on both views; the alert wired to
`importPresentation` on both; badge fed `isBusy`/`canExport`.

Red checks: re-nest the overflow inside the gate → brace-span scan
red (T015's UI test must also go red — run both); drop `.plainText` →
scan red.

### T015 — Empty-collection UI test

`TroveUITests`: `-uiTesting` in-memory launch, empty store → "More
actions" exists on the Items screen; its menu shows Import from CSV
enabled and both export actions disabled. Run the UI suite twice
back-to-back to confirm isolation still holds (the T050 rule).

Red check: re-nest the overflow control (shared with T014's
mutation) → this test red — the pair is what makes criterion 1
falsifiable from both directions.

---

## Phase 6 — Docs, device pass, close-out

### T016 — `docs/csv-reference.md`

New top-level `docs/` directory; the column reference per plan §Docs:
both tables, per-column formats, blank-vs-default policy, both
row-fatal conditions, Excel caveats (date rewriting, serial coercion,
plain "CSV" vs "CSV UTF-8"). `README.md` links it. Criterion 16's
completeness is checked against the spec's tables line by line at
T018.

### T017 — Full verification and manual device pass

Full `xcodebuild build` + `xcodebuild test`, output reported. Then on
the simulator (or device): import a real Trove export from Files; the
same file re-saved by Numbers (and Excel if available); a wrong-list
file (alert names the other list); a file with skips and defaults
(confirmation counts and row numbers match the file); cancel at the
confirmation (collection untouched); the worst-case capped alert at
largest Dynamic Type on the smallest simulator (the empirical check
the plan promised); the fresh-install path — empty collection → badge
→ Get Blank Template → fill one row → import; fileImporter cancel;
record the 300-row commit timing in plan.md if T011 hasn't. Note
every observation, including surprises, in the Done note.

### T018 — Close-out review

011's T019 pattern: sweep every Done note against what the code
actually does; check each spec criterion box with a verification
citation (honest partials stated as partials); audit for
false-passing test shapes matching this project's recorded three;
disposition anything found (blockers fixed on this branch, the rest
recorded); confirm plan.md matches as-built reality (amend in place
where it doesn't); then mark this file Complete.

---

After T018: PR #7 leaves draft, merges, docs catch-up (README,
ROADMAP, DECISIONS if warranted) on a `fix/` branch per convention.

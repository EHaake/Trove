# 012 — Data Import: Tasks

Status: **Approved** (2026-08-31, same day as drafting) — in
progress, Phase 1 started 2026-08-31

Drafted against the approved `plan.md` (commit `da433d3`). No new
technical decisions are made here — every call below traces to a plan
section; where a task says "per plan," that section is the authority.
The skeptical-reviewer ran on the plan's foundational calls and was
not re-run for this decomposition, which is routine translation.

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

House rules carried over: one commit per completed task, referencing
the task ID; every guard test is **mutation-verified** (break the rule
deliberately, confirm red) before it lands, and the task's Done note
records what was broken and what went red; a task is not done until
`xcodebuild build` and `xcodebuild test` pass and the actual output is
reported (suite-level `-only-testing` selectors, test count checked —
per-function selectors run zero tests and report success).

## Phase 1 — Transport: the parser

- [x] **T001 — `CSVParser.swift`: the scalar state machine.**
  *Done (2026-08-31)*: 12 tests in `CSVParserTests`, all golden
  fixtures hand-written; the writer cross-check runs the production
  parser over `CSVWriter`'s own hard cases (the one context the
  test-only `RFC4180` also covers, taken as an extra bar, not the
  oracle). The CRLF-inside-a-quoted-field test pins scalar count as
  well as equality, because `String ==` is canonical-equivalence and
  would call a mangled ending equal anyway. All three prescribed
  mutations ran red: dropped the CR-peek → 8 tests / 14 issues
  (phantom empty row after every CRLF row, including a
  writer-round-trip failure); removed the quote-open case → 7 tests /
  10 issues (every quoting fixture plus `unclosedQuoteThrowsWholeFile`,
  since quotes-as-literals never throws); bumped the row number on
  newlines inside quoted fields (physical-line counting) → 3 tests
  red, exactly the numbering fixtures. Each reverted; full suite
  612/94 green (12 new) + 5 UI tests.
  Per plan §The parser. `Trove/Import/CSVParser.swift` (new;
  synchronized group, no `.pbxproj` edit): BOM strip; CRLF/LF/CR row
  endings with explicit CR-then-optional-LF consumption (scalars
  don't fuse CRLF the way `Character`s do); any RFC 4180 quoting —
  embedded doubled quotes, embedded newlines kept inside quoted
  fields; trailing newline optional; an unclosed quote at end of
  input throws the transport-level error (`ImportError` wraps it at
  T007); output rows tagged with **spreadsheet row numbers**, counted
  per parsed record (header = 1).
  Tests (`TroveTests/CSVParserTests.swift`), golden fixtures — the
  test-only `RFC4180` may only cross-check writer-produced files,
  never serve as the standard: minimal vs maximal quoting;
  comma/quote/newline/CRLF-inside-field; lone-LF file, lone-CR file,
  CRLF file, CR as the final byte; BOM present/absent; trailing
  newline present/absent; unclosed quote throws; an embedded-newline
  field numbers as one spreadsheet row.
  *Done when*: tests green; mutation checks — break the CR-peek
  (treat CR and LF independently) → ending fixtures red; strip the
  quote handling → embedded-newline fixture red; count physical lines
  instead of records → row-number fixture red.

- [x] **T002 — Row shaping: trailing empties and blank lines.**
  *Done (2026-08-31)*: `ImportSchema.shaped(_:)` — strip trailing
  *empty* cells (whitespace-only cells deliberately survive to the
  field policy, pinned by its own test), then drop rows with nothing
  left, survivors keeping their parser-assigned spreadsheet numbers.
  The criterion-3 fixture builds a real canonical items file via
  `ExportSchema.itemsTable` + `CSVWriter`, damages it with `,,,,` on
  every line plus a blank line after each row, and requires the
  damaged file to shape to the clean file's rows — with the clean
  side also pinned to explicit expectations (row count, header row,
  exact surviving cell count) so two pipelines sharing a bug can't
  agree their way to green. One fixture-arithmetic fix during
  drafting: the second record's trailing empty run is three cells
  (Condition Notes / Serial / Notes all nil), not one — expectation
  corrected to the actual 9 surviving columns, with the interior
  empties (Location, Current Value) asserted in place. Both
  prescribed mutations ran red: stripping removed → 3 tests / 4
  issues; blank rows kept instead of dropped → 3 tests / 4 issues
  including the numbering guard. Reverted; full suite 618/95 green
  (6 new).
  Per plan §Row pipeline, steps 1–2, in
  `Trove/Import/ImportSchema.swift` (first slice): trailing-empty-cell
  stripping over header and data rows; wholly-blank-row dropping —
  silent, the shaped output carries no trace. The amended criterion-3
  transport fixture: a canonical items file with four trailing commas
  on every line (header included) plus interleaved blank lines shapes
  to exactly the clean file's rows.
  *Done when*: tests green; mutation checks — remove the stripping →
  transport fixture red; report blank rows instead of dropping →
  the no-phantom-skips assertion red.

## Phase 2 — Meaning: schema and field policy

- [x] **T003 — Header gate and wrong-list detection.**
  *Done (2026-08-31)*: `ImportSchema.requireItemsHeader` /
  `requireWishlistHeader` over a shared private gate;
  `ImportSchema.HeaderError` (`wrongList` checked first, `mismatch`
  otherwise). Five tests: exact pass both gates, whitespace-padded
  cells pass (header trimming), a re-saved header with trailing
  commas passes through the real parse→shape pipeline (T002 tie),
  missing/extra/renamed/reordered all mismatch, and both wrong-list
  directions recognized. Both mutations red: swapped the gate onto a
  hand-copied header list with two entries transposed → 3 tests red
  (the pass fixtures build from `ExportSchema.itemHeaders`, which is
  the point of reading the array directly); dropped the wrong-list
  check → its test red both directions. Reverted; full suite 623/95
  green (5 new).
  Per plan §Row pipeline, step 3: trimmed header cells compared
  against `ExportSchema.itemHeaders` / `wishlistHeaders` **read
  directly** — column indices derived from array positions, no
  hand-numbered constants. The schema-level error type lands here:
  mismatch, plus the wrong-list variant (exact match against the
  *other* schema's headers, checked first — the schemas diverge at
  column 3, so it's one array comparison).
  Tests (`TroveTests/ImportSchemaTests.swift`): exact headers pass;
  missing / extra / renamed / reordered columns fail with mismatch; a
  wishlist header row at the items gate (and vice versa) yields the
  wrong-list variant; trailing-empty-stripped headers pass (ties to
  T002).
  *Done when*: tests green; mutation checks — swap the gate onto a
  hand-copied header list and reorder two entries in it → the
  pass fixture built from `ExportSchema.itemHeaders` red (the point
  of reading the array directly); drop the wrong-list check → its
  test red.

- [x] **T004 — Field parsers: money, date, desire, condition,
  currency.**
  *Done (2026-08-31)*: `ImportSchema.cents(from:)` (strict scan,
  overflow-checked integer math), `day(from:timeZone:)` (strict
  4-2-2, own Gregorian calendar, components round-trip),
  `desire(from:in:)`, `condition(from:)`, `currencyCode(from:)`.
  13 tests incl. parameterized rejection sets; both preserved
  invariants pinned (writer→parser identity across a cent spread,
  and `Money.cents(from: Decimal(string:))` equivalence on canonical
  forms). Three mutations red: money scan skipping grouping commas →
  rejection set red on `1,250.00`; calendar swapped to `.buddhist`
  (the T019/B1 failure mode itself) → 3 tests red incl. the
  Gregorian pin — noted honestly, as 011 did: a swap to
  `Calendar.current` specifically is indistinguishable on a
  Gregorian-configured test host, so identifier-independence is
  carried structurally (the API takes only a `TimeZone`) with the
  buddhist-swap as the detectable proxy; components round-trip
  removed → all 5 impossible dates accepted, red. Reverted; full
  suite 636/95 green (13 new).
  Per plan §Money and date parsing — all pure, no
  `Locale`/`DateFormatter`/`Decimal` anywhere in the path. Money:
  strict shape scan (digits, optional dot + 1–2 fraction digits; bare
  integer = whole amount) then overflow-checked integer math. Date:
  strict 4-2-2 shape resolved through a Gregorian calendar built
  inside the parser over the injected `TimeZone` (the T019/B1
  doctrine), impossible dates rejected via components round-trip.
  Tests: money — canonical forms parse cent-exact; equivalence with
  `ExportSchema.money(cents:)` across a cent spread (0, 1, 999,
  100_00, 999_999_999_99) and with `Money.cents(from:
  Decimal(string:))` on canonical forms (011's preserved invariant);
  rejects `1250.`, `.50`, `1250.000`, `+5.00`, `-5.00`, `$5`,
  `1,250.00`; accepts `007` and bare integers; a 25-digit string
  rejects without trapping. Date — `2026-1-5` rejects; `2026-02-30`
  rejects; the `America/Santiago` spring-forward fixture resolves; a
  Gregorian pin mirroring
  `dayIsAlwaysGregorianRegardlessOfDeviceCalendar`. Desire
  in-range/out-of-range/non-integer; condition case-insensitive over
  the five raw values; currency three ASCII letters uppercased, blank
  → USD silent, malformed → USD counted.
  *Done when*: tests green; mutation checks — let the money scan
  accept a comma → rejection test red; swap the parser's calendar to
  `Calendar.current` → Gregorian pin red; skip the components
  round-trip → `2026-02-30` test red.

- [x] **T005 — Items row validation: `ValidatedRow` and the items
  policy table.**
  *Done (2026-08-31)*: `ImportSchema.itemsPreview(from:timeZone:)` —
  shape → gate → field policy end-to-end; `ValidatedRow<Record>` /
  `ImportPreview<Record>` generics with the `ItemsImportPreview`
  typealias; `SkipReason` strings pinned where the validator and
  `ImportCopy` will both read them. **One plan adjustment, recorded**:
  the form statics turned out to be `private` *and* MainActor-isolated
  (the project default), so "reused, not reimplemented" became
  extraction — new `FieldNormalization` (`nonisolated`), with both
  form view models' private statics now delegating to it; the same
  one-definition move the plan prescribes for `canonicalize`, and the
  header gate's trimming switched onto it too.
  `ExportSchema.firstPhotoID` carries the import-constructs-nil doc
  note. 13 tests: full-valid row; blank/whitespace Name skips; extra
  cells skip; under-length pad + blank policy; silent optionals +
  silent blank currency; six-way default-and-count row; zero-vs-blank
  Current Value distinctness; form-identical text normalization; the
  embedded-newline/nameless numbering fixture (skip reported as row
  3); empty file → gate mismatch; wishlist file → wrongList through
  the preview; the lossless round trip (serialization equality via
  `ExportSchema.row(from:)`, zero skips/defaults); and the
  template-plus-one-hand-row closed loop. All three mutations red:
  blank Name defaulting to "Untitled" → 2 tests / 8 issues; raw
  (untrimmed) name check → whitespace-only names slipped through, 2
  tests red; notes dropped from the record build → round trip red on
  serialization equality. Reverted; full suite 649/95 green (13 new).
  Per plan §Records and §Row pipeline: `ValidatedRow` wrapping
  `ItemExportRecord` (`firstPhotoID: nil`; the doc-comment note lands
  on `ExportSchema.firstPhotoID` in this task) +
  `ItemsImportPreview`; the items field-policy table wired
  end-to-end, normalizing through the form's own
  `trimmed`/`nilIfBlank` statics — reused, not reimplemented.
  Row-fatal: empty Name after trim; extra content cells. Silent vs
  counted defaults exactly per the spec table's Counted? column.
  Tests: one per table row class (blank vs unparseable vs
  silent-empty; blank Current Value = unvalued, not zero);
  whitespace-only Name skips; extra-cells row skips with reason;
  under-length row pads then follows blank policy; the
  embedded-newline-then-nameless fixture pins spreadsheet numbering
  of skips; per-row and total defaulted counts. **Round trip**:
  seeded records → `ExportSchema.itemsTable` → `CSVWriter` → parse →
  validate → `ExportSchema.row(from:)` equality per record, zero
  skips, zero defaults. **Closed loop** (the plan's highest-value
  test): header-only template bytes + one hand-appended canonical row
  → exactly one validated record carrying the appended values.
  *Done when*: tests green; mutation checks — make blank Name default
  instead of skip → policy test red; drop the trimming →
  whitespace-Name test red; remove a column from the round trip's row
  rebuild → serialization equality red.

- [x] **T006 — Wishlist row validation.**
  *Done (2026-08-31)*: `ImportSchema.wishlistPreview(from:timeZone:)`
  — a deliberately parallel implementation of the 7-column table
  (each function reads as its spec table; shared machinery would
  obscure that they genuinely differ). `Added` restores `createdAt`
  through the date parser; desire runs 1–3 defaulting to 2;
  `WishlistImportPreview` typealias. 6 tests: full-valid row with the
  `createdAt` pin, both row-fatals with spreadsheet numbers, the
  three-way default-count row with silent blank currency, items file
  → wrongList through the preview, the lossless round trip (`Added`
  preserved across the loop), and the wishlist template closed loop.
  Both mutations red: blank-name default instead of skip → the
  row-fatals test red; `Added` pointed at `.now` instead of the
  parsed day → 3 tests / 4 issues (direct pin, round trip, closed
  loop). One process note: a typo'd `-project` path made a mutation
  run produce *no* output — the memory-file trap in a new costume;
  caught by the missing failure lines, reran correctly. Reverted;
  full suite 655/95 green (6 new). **Phase 2 complete.**
  The wishlist variant, proven immediately after items per spec
  decision 5: the gate from T003 over `wishlistHeaders`; the 7-column
  policy table; `Added` parsed with T004's date parser into the
  record's `createdAt`; desire 1–3 defaulting to 2.
  `WishlistImportPreview`.
  Tests: the wishlist policy table per class; wishlist round trip and
  closed loop mirroring T005's.
  *Done when*: tests green; mutation checks — same shapes as T005 on
  the wishlist side; point `Added` at today instead of the parsed
  date → round trip red.

## Phase 3 — Service and concurrency (walking skeleton)

- [ ] **T007 — `ImportService.swift`: protocol, live service,
  `ImportError`, `ImportCopy`.**
  Per plan §Service and concurrency: the protocol (both `@concurrent`
  requirements); `FileImportService` — security-scoped read
  tolerating a false start-access with a conditional stop in a defer,
  the 10 MB pre-read size cap, UTF-8 decode, parse, validate;
  `ImportError` (unreadable / undecodable / malformedQuoting /
  tooLarge / headerMismatch with the wrong-list flag); `ImportCopy` —
  per-error titles and messages (the undecodable copy names Excel's
  "CSV UTF-8" save; the unreadable copy mentions downloading the
  file), the confirmation title, and `confirmationMessage(preview:)`
  with the first-5-plus-"and N more" cap and the informational
  zero-importable variant.
  Tests (`TroveTests/ImportServiceTests.swift` — real temp-file I/O,
  the same narrow disk exception `ExportTempFileTests` records): a
  written canonical file parses through the service; each error case
  maps (garbage bytes → undecodable; oversized file → tooLarge;
  wrong-list header file → the flagged mismatch); `ImportCopy` tests
  pin the cap boundary (5 skips = no "more" line, 6 = "and 1 more"),
  the zero-importable copy, and the actionable strings.
  *Done when*: tests green; mutation checks — shift the cap boundary
  off by one → cap test red; swallow the wrong-list flag → its copy
  test red.

- [ ] **T008 — Concurrency probe.**
  `ExportConcurrencyTests`' shape verbatim for import: an injected
  probe samples `Thread.isMainThread` through the synchronous helper
  inside `FileImportService`'s generation body; the test calls
  through `any ImportService` and asserts off-main.
  *Done when*: test green; mutation check (the SE-0461 doctrine's
  guard) — remove `@concurrent` from the protocol requirement → the
  probe records main-thread → red.

## Phase 4 — View models (twins)

- [ ] **T009 — `CategoryPathHelper.canonicalize(_:against:)`.**
  The flagged production change to a shipped file, per plan §The
  commit path: extract the case-insensitive match rule as a pure
  static; the existing instance method delegates to it. No behavior
  change.
  Tests: pure-function cases (match returns existing casing, no match
  returns input); the existing `CategoryPathHelperTests` stay green
  untouched — that *is* the no-behavior-change evidence.
  *Done when*: tests green; mutation check — make the static
  case-sensitive → the delegating instance method's existing tests
  red.

- [ ] **T010 — Import surface on both view models.**
  Per plan §View-model surface. `TestSupport`: `ImportServiceSpy` +
  `GatedImportServiceSpy` (gates only the first call — the T019/S1
  lesson, so a wrongly-leaked reentrant call fails the count
  assertion fast instead of deadlocking). Both VMs:
  `importPresentation` enum (view-settable), `isImportingFile`
  (named against the CloudKit-sync collision, comment says why),
  `isBusy`, `importCSV(from:)`, `cancelImport()`; every export and
  import intent guards on `!isBusy`.
  Tests (import suites in both VM test files): mid-flight
  observability and reentry block via the gated spy; a thrown
  `ImportError` maps to `.failure` with the exact `ImportCopy`
  strings; cancel clears the presentation with zero store writes;
  `isBusy` serialization — an in-flight import refuses `exportCSV`
  and vice versa.
  *Done when*: tests green in both suites; mutation checks — drop the
  `isImportingFile` set → mid-flight test red (both VMs); route the
  failure copy through a literal → string test red.

- [ ] **T011 — `confirmImport`: the commit path, both view models.**
  Per plan §The commit path, exactly: leading `await Task.yield()`;
  canonical path set fetched **once**, batch casing
  first-occurrence-wins via T009's static, resolved paths joining the
  against-set; fetch-all once, `base =
  ManualOrderHelper.nextPosition(after:)`, `base + i` in file order,
  computed **at commit**; items get `createdAt`/`updatedAt` = now;
  wishlist restores `createdAt` from the record by assignment after
  construction (commented — the init hard-sets `.now` deliberately);
  insert all, save once; catch → `modelContext.rollback()` →
  `.failure`; then `load()`. Also here: **measure** a 300-row commit
  on the simulator and record the number in plan.md §The commit path
  (chunk across yields only if it exceeds ~100 ms).
  Tests: batch appends at end preserving file order; the legacy
  fixture (every existing item at `sortOrder` 0) still lands the
  batch after the legacy block; view-independence (category filter
  active → `totalCount` grows by batch size); committing the same
  preview twice duplicates every row (criterion 11); casing —
  existing `Photography/Cameras` survives an import of
  `photography/cameras`, including a wishlist file with `Added` 2015
  (the earliest-`createdAt` theft canonicalization prevents);
  intra-batch `guitars` + `Guitars` collapse to the first occurrence;
  wishlist `createdAt` equals the parsed `Added` day; rollback
  mechanism test (insert, roll back, fetch empty) + a `SourceScan`
  check that `confirmImport`'s catch calls `rollback()` — the
  falsifiable wiring guard; forcing a real SwiftData save failure
  deterministically is not practical, and the plan records that
  honestly.
  *Done when*: tests green; timing recorded in plan.md; mutation
  checks — compute the base at parse time (cache it) → the
  insert-between-parse-and-confirm test red; skip canonicalization →
  casing tests red; remove `rollback()` → the scan red.

- [ ] **T012 — Blank template intents.**
  Per plan §View-model surface: `ExportFilename.itemsTemplate` /
  `wishlistTemplate` (the enum stays the only namer of share-sheet
  files); `exportBlankTemplate()` on both VMs — guarded on `isBusy`
  only, **not** `canExport` — staging the zero-row table through the
  existing `exportCSV(_:filename:)` path.
  Tests: with an empty list, the intent stages a file whose bytes are
  exactly BOM + header row + CRLF, named per the pinned template
  filename; `canExport` false does not block it; the spy sees the
  existing export method — no new protocol surface.
  *Done when*: tests green; mutation checks — gate the intent on
  `canExport` → empty-list test red; inline the filename → the
  pinned-name test red.

## Phase 5 — UI (twins)

- [ ] **T013 — `OverflowBadge`.**
  Per plan §Entry point UI: `git mv` `ExportBadge.swift` →
  `OverflowBadge.swift` + type rename (no `.pbxproj` edit —
  synchronized groups; the build proves it). Props
  `isBusy`/`canExport` + four closures; menu: both export actions
  (pinned strings, each `.disabled(!canExport)`), a `Divider`,
  "Import from CSV…", "Get Blank Template…" always enabled;
  accessibility label "Working" while busy / "More actions"
  otherwise; preview updated. `ExportWiringTests` updated to the new
  name and props and extended: all four intents fired, menu strings
  pinned, export gating count still exactly 2 — spec-sanctioned
  strengthening (criterion 1 supersedes 011's criteria 1–2), not a
  weakening.
  *Done when*: build + tests green; mutation checks — gate a new
  action on `canExport` → the always-enabled assertion red; drop the
  `Divider` or a menu string → pinned-strings red.

- [ ] **T014 — Headers, `.fileImporter`, and the import alert.**
  Per plan §Entry point UI, both list views: the overflow control
  moves outside the `if viewModel.totalCount > 0` gate (sort badge
  stays inside); `.fileImporter` with `[.commaSeparatedText,
  .plainText]`, cancellation a no-op (verify the actual iOS 26
  callback behavior here and note it); one import alert presenting
  off `importPresentation` — confirmation variant with Import/Cancel
  (info-only when zero importable), failure variant with OK.
  `TroveTests/ImportWiringTests.swift` (`SourceScan`): overflow call
  outside the `totalCount` brace-span on both views; fileImporter
  attached with both content types on both views; the alert wired to
  `importPresentation` on both; badge fed `isBusy`/`canExport`.
  *Done when*: build + tests green; mutation checks — re-nest the
  overflow inside the gate → brace-span scan red *and* T015's UI test
  red (run both); drop `.plainText` → scan red.

- [ ] **T015 — Empty-collection UI test.**
  `TroveUITests`: `-uiTesting` in-memory launch, empty store → "More
  actions" exists on the Items screen; its menu shows Import from CSV
  enabled and both export actions disabled. Run the UI suite twice
  back-to-back to confirm isolation still holds (the T050 rule).
  *Done when*: UI test green twice consecutively; mutation check —
  re-nest the overflow control (shared with T014's) → this test red;
  the scan/UI-test pair is what makes criterion 1 falsifiable from
  both directions.

## Phase 6 — Docs, device pass, close-out

- [ ] **T016 — `docs/csv-reference.md`.**
  Per plan §Docs: new top-level `docs/` directory; both column
  tables, per-column formats, the blank-vs-default policy, both
  row-fatal conditions, the Excel caveats (date rewriting, serial
  coercion, plain "CSV" vs "CSV UTF-8"). `README.md` links it.
  *Done when*: doc exists and README links it; criterion 16's
  line-by-line completeness against the spec's tables is checked at
  T018.

- [ ] **T017 — Full verification and manual device pass.**
  Full `xcodebuild build` + `xcodebuild test`, actual output
  reported. Then on the simulator (or device): import a real Trove
  export from Files; the same file re-saved by Numbers (and Excel if
  available); a wrong-list file (the alert names the other list); a
  file with skips and defaults (confirmation counts and row numbers
  match the file as a spreadsheet shows it); cancel at the
  confirmation (collection untouched); the worst-case capped alert at
  largest Dynamic Type on the smallest simulator (the empirical check
  the plan promised); the fresh-install path — empty collection →
  badge → Get Blank Template → fill one row → import; fileImporter
  cancel; record the 300-row commit timing in plan.md if T011 hasn't.
  *Done when*: every check performed and noted — surprises included —
  in the Done note.

- [ ] **T018 — Close-out review.**
  011's T019 pattern: sweep every Done note against what the code
  actually does; check each spec criterion box with a verification
  citation (honest partials stated as partials); audit for
  false-passing test shapes matching this project's recorded three;
  disposition anything found (blockers fixed on this branch, the rest
  recorded); confirm plan.md matches as-built reality (amend in place
  where it doesn't); then mark this file Complete.
  *Done when*: all criteria dispositioned, findings recorded, status
  flipped.

---

After T018: PR #7 leaves draft, merges, docs catch-up (README,
ROADMAP, DECISIONS.md if warranted) on a `fix/` branch per
convention.

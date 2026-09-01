# 012 — Data Import — Technical Plan

Status: **Approved** (2026-08-31, same day as drafting; drafted
in-session per the authorship split)

Grounded in the shipped 011 export module and the current view/VM code
— file references below are to what exists on this branch today. The
`skeptical-reviewer` subagent ran on the seven foundational calls
before this document was written; its record is first because two of
its findings reshaped the design and four spec-level contradictions it
surfaced were escalated and decided by the person (the spec.md
amendments section lists them).

## Skeptical-review record

- **Sustained, strengthened**: reusing the export record types as the
  import pipeline's validated records (with the round-trip assertion
  moved off record equality — see Records); the whole-file abort on an
  unclosed quote (it's what makes ragged-row tolerance safe, not just
  caution); the blank template through the existing export path; the
  `.alert` confirmation; the `ExportBadge` rename; the `Trove/Import/`
  layout and locale-free field parsers.
- **Overturned: the commit body as first proposed.**
  `CategoryPathHelper.canonicalize` performs a full two-entity fetch
  plus sort *per call* (`CategoryPathHelper.swift`, `canonicalPaths()`
  → `allRecords()`); calling it per imported row — the form's
  per-save pattern copied into a loop — would be ~300 full store
  fetches over a set growing as it's scanned. Hoisted to once per
  batch; see The commit path. The same review added the
  `rollback()`-on-save-failure requirement and the render-a-frame
  requirement on the progress affordance.
- **Escalated and decided** (all four by the person, 2026-08-31):
  trailing-empty stripping + silent blank lines + unclosed-quote
  whole-file failure; extra-content-cells as a second row-fatal
  condition; the capped skip listing; form-mirror trimming. Applied to
  spec.md in the same commit as this draft.

## Module layout

`Trove/Import/`, mirroring `Trove/Export/`:

- `CSVParser.swift` — transport: bytes-to-rows.
- `ImportSchema.swift` — meaning: header gate, field policy, field
  parsers, preview types.
- `ImportService.swift` — the injected boundary: protocol, live
  implementation, `ImportError`, `ImportCopy`.

Every type explicitly `nonisolated` (the project MainActor default
would otherwise capture them), same as the export module. Verified
against `project.pbxproj`: `Trove/` is a
`PBXFileSystemSynchronizedRootGroup`, so the new directory and the
badge rename need **no project-file edit** — the constitution's
project-file-safety rule is satisfied without an exception.

## The parser (`CSVParser.swift`)

A new production parser. The test-only `RFC4180` in
`CSVWriterTests.swift` stays confined there, per its own file comment
— the review sharpened why: it has no unclosed-quote detection, enters
quote mode only on an empty field, and encodes one specific
trailing-newline answer. It's a *weak cross-check oracle*, never the
standard; the production parser is validated against hand-written
golden fixtures and the writer→parser closed loop (Test plan).

- **Unicode-scalar state machine** with explicit CR-then-optional-LF
  consumption. This is deliberate and the opposite trap from the
  writer's: `Character`s fuse CRLF into one grapheme (which is why the
  test parser's `case "\r\n"` works), scalars see two — the machine
  must consume `\r` and peek for `\n`. Fixtures pin lone LF, lone CR,
  CRLF, and a CR as the file's final byte.
- Transport tolerance (spec §Parsing tolerance): BOM optional and
  stripped; CRLF/LF/CR row endings; trailing newline optional; any
  valid RFC 4180 quoting, embedded quotes doubled, embedded newlines
  kept inside quoted fields.
- **An unclosed quote at end of input throws
  `ImportError.malformedQuoting`** — whole-file, per the amended
  criterion 14. The reviewer's framing is the load-bearing one: a
  runaway quote swallows the remainder of the file into a single
  field, producing one giant under-length row — which the padding rule
  below would otherwise quietly accept as a single item named after
  the corruption. The abort is what makes the tolerance rules safe.
- Output rows are tagged with **spreadsheet row numbers** — counted
  per parsed record, not per physical line, because a quoted Notes
  field with an embedded newline spans two lines but one spreadsheet
  row, and the skip report must name the row the user will find in
  Numbers/Excel (header = row 1, first data row = 2). A dedicated
  fixture (embedded-newline row followed by a nameless row) pins the
  reported number.

## Row pipeline (`ImportSchema.swift`)

Order of operations, before any field is read:

1. **Trailing empty cells are stripped** from the header row and every
   data row (amended tolerance rule): spreadsheet apps emit
   `...,Notes,,,` whenever the sheet's used range outgrew the data,
   and the rigid header gate would otherwise reject every re-saved
   file — directly contradicting criterion 3. A hand-built fixture
   (all 12 columns plus four trailing commas on every line, header
   included) must import cleanly.
2. **Wholly blank rows are dropped silently** — a trailing blank line
   must not generate a phantom "row 43 — no name" report on a clean
   file.
3. **Header gate**: each remaining header cell, trimmed, compared
   against `ExportSchema.itemHeaders` / `wishlistHeaders` — **read
   directly from `ExportSchema`, never copied** — and column indices
   throughout the pipeline derive from positions in those arrays, not
   hand-numbered constants. Two ordered lists that must agree is
   exactly the drift the append-only growth rule exists to prevent.
   On mismatch, the gate first checks for an exact match against the
   *other* list's headers — the schemas diverge at column 3
   (`Purchase Price` vs `Estimated Cost`), so the check is one array
   comparison — and throws the wrong-list variant so criterion 4's
   alert can say "this looks like a Wishlist export."

Field policy per the spec's tables, with the amended trimming rule:
every cell normalizes through the same rules the form applies
(`ItemFormViewModel.trimmed` / `nilIfBlank` semantics — the statics
are reused, not reimplemented) — so "blank" means empty after
trimming, an imported item is indistinguishable from a hand-typed one,
and a whitespace-only Name skips the row. Row-fatal conditions, now
two (amended criterion 6): empty Name; **more content cells than the
schema** after trailing-empty stripping — a stray comma shifts every
later column one place and no guess about which field it belongs to is
safe. Rows with *fewer* cells are padded with empty cells (transport
damage — some apps trim trailing delimiters), and the padded cells
then follow the ordinary blank-cell policy.

Skips and defaults are counted per the spec's tables:
`SkippedRow { rowNumber, reason }` for fatal rows, a defaulted-field
count per surviving row.

## Money and date parsing

**Money**: a strict shape scan — one or more digits, then optionally a
dot and one or two fraction digits — followed by overflow-checked
integer arithmetic. No `Decimal`, no locale API. Rejected to
default-and-count: signs, currency symbols, grouping separators,
`1250.` (trailing dot), `.50` (no integer digit), `1250.000`
(sub-cent). `007` accepts (leading zeros are just digits). Bare
integers are whole amounts, per the spec.

This is deliberately **stricter than `Money.cents(from:
Decimal(string:))`**, which 011's plan named as the parse-side path:
`Decimal(string:)` stops parsing silently at the first character it
doesn't understand, so `"1,250.00"` would come back as `1` — a
locale-shaped leniency the spec forbids. 011's plan.md is corrected in
place (same commit as this draft) and the invariant it recorded is
preserved as tests: `ImportSchema` cents of `ExportSchema.money(cents:
n)` equals `n` across a spread of values, *and* equals
`Money.cents(from: Decimal(string:))` on canonical forms. The
codebase then carries three money implementations at three different
boundaries, deliberately: `Money.cents` converts what a user types
into a form field, `ExportSchema.money` writes the canonical format,
`ImportSchema` reads only the canonical format. Each pair is tied
together by a round-trip test rather than by sharing code that would
blur what each boundary accepts.

**Dates**: strict `yyyy-MM-dd` shape — exactly 4-2-2 digits, so
`2026-1-5` rejects — resolved through a **Gregorian calendar built
inside the parser over an injected `TimeZone`**, the exact T019/B1
doctrine `ExportSchema.day(from:timeZone:)` established: the API takes
only a `TimeZone`, so the user's preferred-calendar setting cannot
leak in from either direction. Impossible dates (`2026-02-30`) are
rejected by round-tripping the resolved date back to components and
comparing. A DST fixture (`America/Santiago`, where local midnight
does not exist on spring-forward day) proves such days still resolve —
`Calendar.date(from:)` answers 01:00, and the day round-trips.
Recorded, not fixed: imported `purchaseDate` values land at local
midnight where form-entered ones carry a time of day. Harmless — the
schema only ever shows the day — and stated so nobody "discovers" it.

**Desire / condition / currency** per the spec: integer-in-range or
default-and-count; condition matched case-insensitively against the
five `Condition` raw values; currency accepted as three ASCII letters,
stored uppercased, blank → `USD` silently, malformed → `USD` counted.

## Records: reuse, not parallel types

The validated row wraps the **existing export snapshot records**:

```swift
nonisolated struct ValidatedRow: Sendable {
    let record: ItemExportRecord   // firstPhotoID always nil on import
    let rowNumber: Int
    let defaultedFieldCount: Int
}
```

(and the wishlist twin). The reviewer strengthened the case for reuse
beyond convenience: it makes 011's append-only growth rule **a compile
error** — a new column means a new record field, and the parser stops
building until it handles it. A parallel `ItemImportRecord` would
reduce that rule to a convention someone has to remember.

Two consequences, both recorded at the type: `firstPhotoID` gets a
doc-comment addition saying import constructs records with `nil`
(CSV carries no photo representation), and **round-trip assertions
compare `ExportSchema.row(from:)` serializations, not records** —
`firstPhotoID` cannot round-trip through CSV, so record `Equatable`
would need an `==` that ignores a stored property, a footgun for a
type `PDFEntry` also consumes. Serialization equality is also simply
the stronger test: it asserts the byte contract itself.

Previews are what the service returns and the view model stages:

```swift
nonisolated struct ItemsImportPreview: Sendable {
    let validated: [ValidatedRow]
    let skipped: [SkippedRow]
    let defaultedFieldCount: Int   // sum across validated rows
}
```

## Service and concurrency

```swift
nonisolated protocol ImportService: Sendable {
    @concurrent func parseItems(at url: URL, timeZone: TimeZone) async throws -> ItemsImportPreview
    @concurrent func parseWishlist(at url: URL, timeZone: TimeZone) async throws -> WishlistImportPreview
}
```

`@concurrent` on the requirements **and** the implementations —
verbatim the `ExportService` doctrine (SE-0461: a plain nonisolated
async function runs on the *caller's* actor; calls through the
existential follow the requirement's convention). The probe test
copies `ExportConcurrencyTests`' shape: an injected generation probe
samples `Thread.isMainThread` through a synchronous helper, called
through `any ImportService`.

The whole read happens **inside the one `@concurrent` call**, so no
security scope crosses an actor hop: `startAccessingSecurityScopedResource()`
(tolerating `false`, so plain file URLs from tests work), a conditional
`stopAccessing` in a defer, `Data(contentsOf:)`, decode, parse,
validate, return. Sendability is clean by construction: `URL` and
`TimeZone` in, a preview of value types out, `@Model` objects never
cross.

- **Undecodable bytes** (`String(data:encoding:.utf8)` → nil) throw
  `ImportError.undecodable`. The copy is actionable: Windows Excel's
  plain "CSV" save writes the system code page, not UTF-8 — only "CSV
  UTF-8" is — so the message names that save option. A Latin-1
  fallback was considered and rejected: every byte sequence is valid
  Latin-1, so the app would never detect an encoding problem again, it
  would just import mojibake.
- **Defensive size cap**: 10 MB, checked via the file's size before
  reading, → `ImportError.tooLarge` → the criterion-14 alert. Orders
  of magnitude beyond any personal inventory; exists so a mis-picked
  video can't balloon memory.
- An iCloud file that isn't downloaded locally can fail the read →
  `unreadable`, whose copy suggests making sure the file is
  downloaded.
- `FileImportService` holds no `ModelContainer` — import parsing
  touches no store. Its only injectable is the concurrency probe.
- `ImportCopy` (the `ExportCopy` / `ItemDeleteCopy` pattern) owns
  every user-facing string: per-error titles/messages, the
  confirmation title, and `confirmationMessage(preview:)` — a pure
  function tests pin: counts always; the first **5** skipped rows with
  reasons, then "and N more rows" (amended criterion 5); the
  defaulted-field count when nonzero.

## The commit path

Parse runs off-main; **commit runs on the MainActor in the view
model's `confirmImport()`**, against the VM's own `modelContext` — and
the review reshaped its body:

1. `await Task.yield()` (a real suspension) before the work, so the
   badge's spinner renders a frame — criterion 15 covers commit, and
   setting `isBusy` without yielding never draws (the T056 lesson in
   reverse). The walking-skeleton task **measures** a 300-row commit
   and records the number here; if it exceeds ~100 ms, the insert loop
   chunks across yields. Main-actor commit stays the call regardless:
   `@ModelActor` plus cross-context refetch plumbing is real
   complexity for a bulk insert that `load()` on the same context sees
   for free.
2. **Canonical category paths are fetched once**, before the loop. New
   pure static `CategoryPathHelper.canonicalize(_:against:)` — the
   existing instance method delegates to it, so the rule has one
   definition. This is a small production change to a shipped file,
   authorized here by necessity (the instance method's full two-entity
   fetch per call is what the review overturned). Batch-internal
   casing resolves by **file row order, first occurrence wins**, each
   resolved path joining the against-set so later rows canonicalize
   against earlier batch rows too. Canonicalization is load-bearing
   beyond tidiness: chip casing follows the earliest `createdAt`
   across both entities, so a wishlist import restoring old `Added`
   dates could otherwise steal the casing of an existing path. A test
   pins it: existing `Photography/Cameras`, import
   `photography/cameras` with `Added` 2015 → chips still read the
   existing casing.
3. **`sortOrder` base computed here, never at parse time**: fetch-all
   once, `base = ManualOrderHelper.nextPosition(after:)`, each record
   `base + i` in file order — so a CloudKit arrival (or a hand-add)
   between alert and confirm can't stale the base. A legacy fixture —
   every existing item at `sortOrder` 0, the real state of a pre-010
   store — proves the batch (positions 1…N) still sorts after the
   legacy block, whose ties fall back to `createdAt`.
4. Items build through `Item(...)` (`createdAt`/`updatedAt` = now —
   the items schema deliberately has no `Added`). Wishlist rows
   restore `createdAt` from `Added` **by assignment after
   construction** — `WishlistItem.init` hard-sets `.now` and has no
   parameter; deliberate, noted so nobody "fixes" the init.
5. Insert all, **save once**. On throw: **`modelContext.rollback()`**,
   then the failure presentation. Without the rollback, `load()` on
   the same context would show the phantom batch — unsaved objects the
   context happily returns (the repo's recorded false-passing-
   persistence-test shape) — which would vanish on relaunch, violating
   criterion 14's "never a partial batch." Guarded two ways: a
   mechanism test (insert into a context, roll back, fetch shows
   nothing) and a `SourceScan` check that `confirmImport`'s catch
   calls `rollback()` — the scan is the falsifiable guard on the
   wiring (delete the call, it goes red); forcing a real SwiftData
   save failure deterministically is not practical, and pretending
   otherwise would be the unfalsifiable-test shape the constitution
   bans.
6. `load()`. Import is view-independent by construction — the commit
   never consults filters — and a test pins it: category filter
   active, import, `totalCount` grows by the batch size.

## View-model surface (both list VMs)

- **`isImportingFile`** — not `isImporting`, because "import" already
  means *CloudKit sync* in these view models (`mayStillBeImporting`,
  `completedImports`, `ListEmptyReason`'s "Catching up with iCloud"),
  and the empty-collection-while-syncing case is exactly where both
  meanings are live at once. A comment says so. The badge reads
  `var isBusy: Bool { isExporting || isImportingFile }`; every export
  and import intent guards on `!isBusy`, which serializes the
  operations and means their presentations can't race.
- **One new presentation state**, not two:
  `var importPresentation: ImportPresentation?` — an enum,
  `.confirmation(ItemsImportPreview)` / `.failure(title:message:)` —
  view-settable so dismissal writes nil back, exactly the
  `stagedExport` convention. The list views already carry three
  presentation modifiers; independent booleans that can go true
  together are how SwiftUI silently drops an alert. A zero-importable
  preview stays `.confirmation` and the view renders it with only a
  dismiss button (`preview.validated.isEmpty` — criterion 5's
  informational case). Export's shipped surfaces are untouched.
- Intents:
  - `importCSV(from url: URL) async` — guard `!isBusy`; set
    `isImportingFile`; call the service; stage `.confirmation` or map
    the thrown `ImportError` through `ImportCopy` into `.failure`.
  - `confirmImport() async` — the commit path above; on success clear
    the presentation, on save failure `.failure`.
  - `cancelImport()` — clear the presentation. Nothing was written;
    nothing to undo.
  - `exportBlankTemplate() async` — guard `!isBusy` only (**not**
    `canExport`: an empty collection is the template's whole
    audience); stages
    `exportService.exportCSV(CSVTable(headers: ExportSchema.itemHeaders, rows: []), filename: ExportFilename.itemsTemplate)`
    through the existing `StagedExport`/share-sheet path. Verified
    against `CSVWriter.write`: a zero-row table yields exactly
    BOM + header row + CRLF. No `ImportService` involvement, no
    protocol change — the template is an export.
- `ExportFilename` gains `itemsTemplate` / `wishlistTemplate`
  (`Trove-Items-Template.csv`, `Trove-Wishlist-Template.csv`) — that
  enum stays the only place share-sheet filenames are named.

## Entry point UI

- **`ExportBadge` → `OverflowBadge`** (`git mv` + type rename; no
  project-file edit — see Module layout). Props become `isBusy` /
  `canExport` plus four action closures. Menu: the two export actions
  (each `.disabled(!canExport)`, pinned strings unchanged), a
  `Divider`, then **Import from CSV…** and **Get Blank Template…**,
  always enabled. Accessibility label generalizes: "Working" while
  busy, "More actions" otherwise. The name change is honesty — a badge
  carrying import actions can't be `ExportBadge` — and
  `DetailOverflowMenu` already established the vocabulary.
  `ExportWiringTests` updates to the new name and grows import
  assertions: a spec-sanctioned strengthening (criterion 1 explicitly
  supersedes 011's criteria 1–2), not a weakening.
- **Header restructure, both lists**: the overflow control moves
  outside the `if viewModel.totalCount > 0` gate; the sort badge stays
  inside (nothing to sort when empty — 011's original rationale still
  holds for it):

  ```swift
  HStack(spacing: 8) {
      if viewModel.totalCount > 0 { sortControl }
      overflowControl
  }
  ```

  Guarded twice, because the whole point of criterion 1 is a control
  that exists on a fresh install: a `SourceScan` brace-span check that
  the overflow call sits outside the `totalCount` block, and a **new
  UI test** — `-uiTesting` in-memory launch, empty store — asserting
  "More actions" exists on the Items screen and its menu offers Import
  enabled with the export actions disabled. Mutation check: re-nest
  the control, both must go red.
- **`.fileImporter`**, attached to both list views, presented off a
  view-local boolean the menu action sets:
  `allowedContentTypes: [.commaSeparatedText, .plainText]` —
  `.plainText` deliberately, because CSVs that arrived by mail or were
  hand-written are routinely `.txt`, and the header gate is the real
  filter. **Cancellation is a no-op** — never the failure alert; the
  callback's actual cancel behavior on iOS 26 is verified at
  implementation, not assumed.
- The import alert presents off `importPresentation` (title, message,
  and button set from `ImportCopy` + the preview). The worst-case
  capped message gets an **empirical check at the device task** —
  smallest device, largest Dynamic Type — because no authoritative
  documentation on long-alert behavior exists; we look rather than
  assume.

## Wishlist parity

`CSVParser` and the transport rules are shared; the header gate, field
policy table, and preview/commit specifics differ per schema.
`WishlistViewModel` gets the same surface (`importPresentation`,
`isImportingFile`, the four intents) against its own list. Items phase
completes first — through tests — then the wishlist phase lands as
the near-mechanical twin (spec decision 5), including `Added` →
`createdAt` restoration and its casing-priority test.

## Docs (criterion 16)

New **`docs/csv-reference.md`** (new top-level `docs/` directory):
both column tables, per-column formats, the blank-vs-default policy,
the row-fatal conditions, and the Excel caveats — date-format
rewriting on save, long serial numbers coerced on default open, plain
"CSV" vs "CSV UTF-8" saves. `README.md` links it. This is the
"README-style reference" the roadmap promised and the template's
paper half.

## Spec amendments applied with this draft

All decided by the person, 2026-08-31, during planning; applied to
`spec.md` in the same commit and appended to its Decisions record:

1. **Transport damage** (§Parsing tolerance + criterion 14): trailing
   empty cells stripped before all rules; wholly blank lines skipped
   silently; an unclosed quote fails whole-file. The defensive 10 MB
   cap joins criterion 14's failure list.
2. **Extra content cells** (field policy + criterion 6): second
   row-fatal condition.
3. **Capped skip listing** (criterion 5): first 5 + "and N more".
4. **Form-mirror trimming** (field policy): blank = empty-after-trim;
   imported cells normalize exactly as hand-typed input does.

## Correction to 011 recorded

`specs/011-data-export/plan.md` §"Money and date serialization" named
`Money.cents(from: Decimal(string: field))` as the parse path 012
would use. Corrected in place (constitution: shipped plans get
corrected when a real understanding changes): 012 parses with a strict
integer parser because `Decimal(string:)` accepts locale-shaped input
the spec forbids, and the recorded invariant survives as test-side
equivalence on canonical forms. See Money and date parsing above.

## Test plan

Constitution norms: every guard mutation-verified before it lands; a
claim in this plan gets the test that would catch it false.

- **Parser golden fixtures**: quoting variants (minimal, maximal,
  embedded quotes/commas/newlines), all three row endings + CR as
  final byte, BOM present/absent, trailing newline present/absent,
  blank lines mid-file and trailing, trailing empty cells, unclosed
  quote (throws), under-length rows (padded), over-length rows
  (skipped). Red checks per rule (e.g. break the CR/LF consumption,
  drop the stripping).
- **Writer→parser closed loop** (the highest-value test): template
  bytes + one appended canonical row → production parse → exactly one
  validated record; ties writer and parser together with neither as
  the other's oracle. The test-only `RFC4180` may cross-check parser
  output on writer-produced files, but golden fixtures are the
  standard.
- **Round trip** (criterion 2): seeded items → export records →
  `CSVWriter` → parse → validate → `ExportSchema.row(from:)` equality
  per record, zero skips, zero defaults; plus the empty-collection
  restore asserting field values and custom order match the file.
- **Field policy**: one test per table row class; the
  spreadsheet-row-number fixture (embedded newline + nameless row);
  money edges (`1250.`, `.50`, `1250.000`, `007`, signs, grouping,
  overflow); date edges (`2026-1-5`, `2026-02-30`, DST Santiago); a
  Gregorian pin mirroring
  `dayIsAlwaysGregorianRegardlessOfDeviceCalendar`; money equivalence
  with `Money.cents(from: Decimal(string:))` on canonical forms and
  with `ExportSchema.money` across a cent spread.
- **Concurrency probe** through `any ImportService`
  (`ExportConcurrencyTests` shape). Red check: drop `@concurrent`.
- **VM suites** (both lists): mid-flight observability + reentry block
  for `isImportingFile` (the gated-spy pattern — spy gates only the
  first call, so a wrongly-leaked reentrant call fails fast rather
  than deadlocking); parse failure maps to `.failure` with
  `ImportCopy` strings; cancel clears without store writes; commit
  appends at `nextPosition` preserving file order (incl. the
  legacy all-zero fixture); view-independence; casing canonicalization
  (existing casing survives a 2015-`Added` wishlist import);
  twice-imported file yields duplicates (criterion 11); rollback
  mechanism + catch-wiring scan; template intent stages the header-only
  file with the pinned filename and ignores `canExport`.
- **Wiring** (`ImportWiringTests` + updated `ExportWiringTests`):
  badge renamed, fed `isBusy`/`canExport`, fires all four intents;
  menu strings pinned; export actions still individually gated;
  overflow outside the `totalCount` gate (brace-span scan);
  `.fileImporter` attached with both content types on both views;
  import alert wired to `importPresentation`; UIKit-confinement walk
  unchanged.
- **UI test**: `-uiTesting` empty store → "More actions" present,
  Import enabled, exports disabled. Mutation: re-nest the control.

## Files

**New**: `Trove/Import/CSVParser.swift`, `ImportSchema.swift`,
`ImportService.swift`; `docs/csv-reference.md`;
`TroveTests/CSVParserTests.swift`, `ImportSchemaTests.swift`,
`ImportServiceTests.swift`, `ImportWiringTests.swift`; import suites in
both list-VM test files; one `TroveUITests` case.
**Renamed**: `Trove/Views/Shared/ExportBadge.swift` →
`OverflowBadge.swift`.
**Modified**: `ItemListView.swift`, `WishlistView.swift` (header,
menu, fileImporter, import alert); `ItemListViewModel.swift`,
`WishlistViewModel.swift` (import surface); `ExportService.swift`
(`ExportFilename` template names); `ExportSchema.swift`
(`firstPhotoID` doc note); `CategoryPathHelper.swift` (static
`canonicalize(_:against:)`, instance method delegates);
`ExportWiringTests.swift`; `TestSupport.swift` (`ImportServiceSpy`,
gated variant); `README.md` (docs link);
`specs/011-data-export/plan.md` (correction above);
`specs/012-data-import/spec.md` (amendments above).

## Verification

Per task: `xcodebuild build` + `xcodebuild test` with actual output
(suite-level `-only-testing` selectors and a checked test count — the
per-function selector runs zero tests and reports success). Device
pass at the manual task: import a Trove export from Files; a
Numbers/Excel re-saved copy; a wrong-list file; the worst-case capped
alert at largest Dynamic Type on the smallest simulator; the
fresh-install empty-collection path (badge → template → fill → import);
commit timing for a ~300-row file measured and recorded in this
document.

## Not in this plan

tasks.md (drafted after plan approval); mapping UI, photo import,
non-CSV formats, merge/update semantics (spec non-goals).

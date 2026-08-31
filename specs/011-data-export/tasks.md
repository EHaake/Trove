# 011 — Data Export: Tasks

Status: **Approved** (2026-08-30) — implementation in progress, Phase 1

Drafted against the approved `plan.md` (commit `dbfc0a7`). No new
technical decisions are made here — every call below traces to a plan
section; where a task says "per plan," that section is the authority.
The skeptical-reviewer ran on the plan's foundational calls and was not
re-run for this decomposition, which is routine translation.

House rules carried over: one commit per completed task, referencing
the task ID; every guard test is **mutation-verified** (break the rule
deliberately, confirm red) before it lands, and the task's Done note
records what was broken and what went red; a task is not done until
`xcodebuild build` and `xcodebuild test` pass and the actual output is
reported.

## Phase 1 — Schema and CSV (pure logic, no UI)

- [ ] **T001 — `ExportSchema.swift`: records, headers, serializers.**
  `Trove/Export/ExportSchema.swift` (new; synchronized group, no
  `.pbxproj` edit): `ItemExportRecord`, `WishlistExportRecord`,
  `CoverSummary`, `CSVTable`, `PDFDocumentModel` as explicitly
  `nonisolated`, `Sendable` value structs; the two pinned header/column
  lists as shared constants; the money serializer (pure integer math,
  `cents/100` + `%02d`, no locale API) and date serializer
  (`Calendar` components → `String(format:)`, device-local day).
  Tests (`ExportSchemaTests`): exact-output cases for money (0, 1,
  999_999_999, values ending `.00`/`.05`) and dates (fixed
  `DateComponents` in an injected calendar/timezone); the money
  **round-trip** through `Money.cents(from:)` — the invariant 012
  depends on.
  *Done when*: tests green; mutation check — drop the `%02d` zero
  padding and confirm red.

- [ ] **T002 — Record-from-model mapping.**
  Initializers `ItemExportRecord(item:)` / (wishlist twin) mapping
  every schema column from the model, including: empty-vs-nil handling
  (`Current Value` nil ≠ `0.00`), raw lowercase condition, and the
  first-photo `PersistentIdentifier` chosen via
  `PhotoSelection.inDisplayOrder(_:).first` — the single existing
  definition of photo order, applied at snapshot time.
  Tests: field-fidelity per column against a fully-populated and a
  minimally-populated model; multi-photo item yields exactly the
  display-order first photo's identifier (reversed `sortOrder` fixture
  so relationship order can't accidentally pass).
  *Done when*: tests green; mutation check — swap the mapping to
  `photos.first` and confirm the photo test goes red.

- [ ] **T003 — `CSVWriter.swift`: RFC 4180 writer.**
  UTF-8 with BOM, CRLF, minimal quoting (quote iff comma/quote/CR/LF;
  embedded quotes doubled), header row from `ExportSchema`'s constants.
  Tests (`CSVWriterTests`): a small **test-only RFC 4180 parser** and
  round-trip assertions for fields containing commas, quotes, embedded
  newlines (criterion 5's hard cases); BOM present exactly once; CRLF
  endings.
  *Done when*: tests green; mutation check — strip the quoting branch
  and confirm the round-trip goes red.

## Phase 2 — Service, temp lifecycle, and the off-main proof

- [ ] **T004 — `ExportService.swift`: protocol, live service, temp
  store.**
  `ExportService` protocol (`exportCSV(_:filename:)`,
  `exportPDF(_:filename:)`, both `async throws -> URL`) and
  `FileExportService`: writes under `tmp/Exports/`, **purges that
  directory before every export**, exposes `purge()` for the launch
  hook. CSV path end-to-end: table → writer → file → URL, filenames
  `Trove-Items-YYYY-MM-DD.csv` / `Trove-Wishlist-YYYY-MM-DD.csv` from
  the local day.
  Tests (`ExportTempFileTests`): two exports back-to-back leave exactly
  one file set; filename shape. Real disk I/O by necessity — the same
  narrow exception shape as `CloudKitSchemaTests`, said in the test's
  doc comment.
  *Done when*: tests green; mutation check — remove the purge call and
  confirm the two-exports test goes red.

- [ ] **T005 — Walking skeleton: off-main CG/CT pipeline proof.**
  Minimal `PDFComposer` rendering a one-page cover-only PDF via
  `CGContext(consumer:mediaBox:)` + `CTFramesetter`, wired through
  `FileExportService.exportPDF` as an explicitly `nonisolated async`
  entry point with a synchronous body. An instrumented probe in the
  generation body records `Thread.isMainThread`.
  Tests (`ExportConcurrencyTests`): calling the entry point **from the
  main actor** sees the probe report `false` (the T056 lesson —
  instrument the mechanism, not a proxy); `PDFComposerTests`:
  `PDFKit.PDFDocument(data:)` non-nil, page count 1. This task is the
  compile-time proof that the module escapes
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; **no PDF layout work
  proceeds until it's green**.
  *Done when*: tests green; mutation check — force the body onto the
  main actor (`MainActor.run`) and confirm the probe test goes red.

## Phase 3 — PDF composition

- [ ] **T006 — Cover page layout.**
  Print palette and print type scale as constants in `PDFComposer`
  (values per plan's "The PDF document" section; faces via
  `FontFamily.postScriptName(for:)` → `CTFontCreateWithName`).
  Wordmark, rule, title, generated date, coverage line (same label
  strings the chips show), count, totals block — items: current value
  + paid + unvalued count; wishlist: estimated cost.
  Tests: cover page `.string` (PDFKit) contains title, count, coverage
  label, and the formatted totals for a seeded set.
  *Done when*: tests green against both document kinds.

- [ ] **T007 — Entry layout and pagination.**
  Per-item entry per plan: hairline rule, photo top-right 132×99 pt
  aspect-fit (text spans full width when absent), category eyebrow,
  name, two-column field grid (same field set as the CSV), notes
  paragraph. Pagination: keep-together when the entry fits the
  remaining space; otherwise new page; entries taller than a full page
  split mid-notes via `CTFrameGetVisibleStringRange` continuation.
  Tests: page count grows with entry count; a no-photo entry renders
  with fields present; an entry with page-length notes produces a
  continuation page whose `.string` carries the tail of the notes.
  *Done when*: tests green; mutation check — break keep-together (always
  same page) and confirm the pagination test goes red.

- [ ] **T008 — Photo pipeline: downsampling, batching, resilience.**
  `CGImageSourceCreateThumbnailAtIndex` with
  `kCGImageSourceThumbnailMaxPixelSize` = 2× the drawn box; photo
  fetches by `PersistentIdentifier` from a **fresh `ModelContext` per
  25 entries** off the shared container, per-entry work in
  `autoreleasepool`; an identifier that fails to resolve skips the
  photo and keeps the entry.
  Tests: multi-photo item draws exactly its display-order first (cover
  + entry render without error and entry page `.string` intact);
  unresolvable-identifier fixture keeps the entry; **size-bound test**
  — a seeded collection with deliberately large photos produces a file
  under the bound stated in the test.
  *Done when*: tests green; mutation check — bypass the thumbnail
  decode (draw full-size) and confirm the size-bound test goes red.

## Phase 4 — View-model intents

- [ ] **T009 — `ItemListViewModel` export intents.**
  `ExportService` injected (live default, same shape as
  `syncMonitor:`); `exportCSV()` / `exportPDF()` async intents building
  records **from the `items` array in its existing order** (never a
  refetch), `isExporting`, `stagedExport: StagedExport?`,
  `exportFailureMessage`, `canExport`. `CoverSummary` built from the
  VM's own `totalCurrentValueCents` / `unvaluedCount` arithmetic
  (criterion 8 by construction).
  Tests (in `ItemListViewModelTests`, fake service recording inputs):
  records match `items` exactly in content and order under an active
  filter + non-default sort; `canExport` false when the filter empties
  the view; a throwing fake sets `exportFailureMessage` and clears
  `isExporting`; cover arithmetic equals the VM's own totals.
  *Done when*: tests green; mutation check — build records from a fresh
  fetch instead of `items` and confirm the order test goes red.

- [ ] **T010 — `WishlistViewModel` export intents.**
  Same shape, wishlist records and `totalEstimatedCostCents` cover
  figure, tests in `WishlistViewModelTests` mirroring T009 including
  its mutation check.
  *Done when*: tests green; mutation-verified as above.

## Phase 5 — UI, wiring, and tokens

- [ ] **T011 — `ExportBadge.swift` + `ShareSheet.swift`.**
  `ExportBadge`: ellipsis glyph in a brass hairline-bordered badge
  matching `SortBadge`'s height, hosting the system `Menu` with the two
  actions ("Export as CSV…", "Export as PDF…"), a `ProgressView` swap
  while exporting, and a disabled binding — the T029c safety argument
  (constant-size label) goes in its doc comment per plan.
  `ShareSheet`: the `UIViewControllerRepresentable`-wrapped
  `UIActivityViewController` — **the spec's single flagged UIKit
  exception**, ~25 lines, zero logic, flagged in its doc comment per
  the constitution.
  *Done when*: builds; previews render; exception called out in code
  and in the task's commit message.

- [ ] **T012 — Wire the Items screen.**
  Badge after `sortControl` (visible exactly when the sort badge is,
  per amended criterion 1), menu items disabled on `!canExport`,
  `.sheet(item:)` on `stagedExport` presenting `ShareSheet`, failure
  alert off `exportFailureMessage`.
  *Done when*: builds; simulator spot-check — badge placement, menu,
  a real CSV export reaching the share sheet.

- [ ] **T013 — Wire the Wishlist screen.** Same wiring, same checks.

- [ ] **T014 — Launch purge hook.**
  `FileExportService.purge()` called once at app startup from the
  smallest sensible hook (`TroveApp`/`TroveStore` per plan).
  *Done when*: builds; a stale file seeded in `tmp/Exports/` is gone
  after a fresh launch (simulator check recorded in the Done note).

- [ ] **T015 — `ExportWiringTests` source-scan guards.**
  Per the `ReorderWiringTests` pattern: both list views gate both menu
  actions on `canExport`; both intents are wired in both views;
  `UIActivityViewController` appears **only** in `ShareSheet.swift`
  across the production tree.
  *Done when*: guards green, and the batch is mutation-verified —
  apply compile-clean breaks (drop a `disabled`, unwire an intent,
  reference the activity controller from a second file) and confirm
  each is caught before reverting.

- [ ] **T016 — `design/tokens.md`.**
  Add the print-only palette table and print type scale (recorded as a
  deliberate second scale), and the export badge + menu row entries.
  *Done when*: tokens.md states every value `PDFComposer` and
  `ExportBadge` use; any divergence discovered while implementing is
  recorded as a decision, never silent.

## Phase 6 — Verification and close-out

- [ ] **T017 — Full-suite run and criteria sweep.**
  `xcodebuild build` + `xcodebuild test` for the whole project, actual
  output reported. Walk all spec acceptance criteria (1, 2, 2a, 3–11)
  and check each off in `spec.md` with a citation to the test or task
  that carries it; the Excel side of criterion 5 is checked via the
  text-import path and recorded honestly per the plan's serial-number
  caveat.

- [ ] **T018 — Manual device pass (yours).**
  Export from filtered and sorted states, both formats, both screens;
  open the CSV in Numbers (and Excel if at hand); read the PDF end to
  end — **this is the design bounce point**; cancel the share sheet;
  export repeatedly and confirm nothing accumulates; try a large-ish
  collection for the progress affordance. Findings come back as tasks
  here, not silent fixes.

- [ ] **T019 — Skeptical-reviewer close-out.**
  The subagent reviews the implemented feature against spec and plan
  (the 010/T039 pattern); every finding resolved or explicitly
  recorded in this file's Done notes before the PR leaves draft.

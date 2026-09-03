# 013 — Settings Menu: Tasks

Status: **Complete** (2026-09-02) — T001–T017 (nineteen criteria) and
Amendment A's T018–T025 with T024a (criteria 20–27) all done, each
with a per-criterion record in `spec.md`; three false-passing guards
caught before merge across the two phases (T012, T017, and T021's dim
guard) and the T025 sweep's three blockers acted on; full suite at
close 790 tests in 116 suites + UI 9 tests, 0 failures twice; PR #9 ready for review.

Drafted against the approved `plan.md` (approved 2026-09-01; drafted
at `61c208b`). No new technical decisions are made here — every call
below traces to a plan section; where a task says "per plan," that
section is the authority. The skeptical-reviewer ran on the plan's
foundational calls and was not re-run for this decomposition, which is
routine translation.

Ordering note, recorded up front: the layers go bottom-up — the export
service's pair-level requirement and the shared comparator first
(everything above depends on them and each is falsifiable on its own),
then the pure copy/status/version pieces, then the view model, then
the screen, then the entry point *last* — because swapping the badge's
template action for Settings is the one change that removes shipped
behavior, and it should land only when the screen it points at exists
and is tested. Templates are therefore reachable from *both* places
for the span of T010–T012 on this branch; T013 closes that.

House rules carried over: one commit per completed task, referencing
the task ID; every guard test is **mutation-verified** (break the rule
deliberately, confirm red) before it lands, and the task's Done note
records what was broken and what went red; a task is not done until
`xcodebuild build` and `xcodebuild test` pass and the actual output is
reported (suite-level `-only-testing` selectors, test count checked —
per-function selectors run zero tests and report success). Every new
file lands through the synchronized root group — no `.pbxproj` edit
anywhere in this spec.

## Phase 1 — Foundations: export sets and the shared order

- [x] **T001 — `ExportFile` and `exportFiles`: one purge, many writes.**
  *Done (2026-09-01)*: `ExportFile` (with a `filename` accessor the
  spies use) and the `@concurrent exportFiles` requirement;
  `FileExportService.stage` split into `prepareStagingDirectory()` +
  `write(_:filename:)`, `exportFiles` rendering each member just
  before its own write with the purge hoisted to just before the
  *first* write — so a throwing render leaves the previous set, as the
  single-file path always has — and one `PhotoFetcher` per set. The
  invariant restated in the service's doc comment and 011 plan.md's
  delivery section. Both spies gained `exportFiles` (`fileSets` on the
  plain spy; first-call-only gating on the gated one, the continuation
  wait shared). Targeted run: 8 tests / 2 suites green. Mutations, all
  reverted: **M1** purge before every write → both set tests red (2
  issues — the first file "couldn't be opened", the second set left
  one file); **M2** the SE-0461 matrix, confirmed rather than assumed:
  requirement-only drop → green, implementation-only drop → green,
  **both dropped → red** with the probe reading `[false, false, true]`
  — exactly the third call on main. Full suite: 710 tests green
  (704 unit + 6 UI).
  Per plan §Export service. `Trove/Export/ExportService.swift`:
  `nonisolated enum ExportFile: Sendable { csv(CSVTable, filename:),
  pdf(PDFDocumentModel, filename:) }`; the new requirement
  `@concurrent func exportFiles(_ files: [ExportFile]) async throws -> [URL]`
  on the protocol **and** `@concurrent` on the implementation (the
  SE-0461 pair). `FileExportService`: split `stage` into
  `prepareStagingDirectory()` (purge + create) and
  `write(_:filename:)`; `exportFiles` fires the probe once, prepares
  once, then per file renders *then* writes (one document in memory
  at a time), sharing one `PhotoFetcher` across the set; the existing
  `stage(_:filename:)` becomes prepare + one write. Restate the
  invariant as "purged before every export **set**" in
  `FileExportService`'s doc comment and in
  `specs/011-data-export/plan.md` §Delivery and temp-file lifecycle.
  `TestSupport.swift`: `ExportServiceSpy.exportFiles` records `files`
  and appends tables/documents/filenames in order;
  `GatedExportServiceSpy` gates the **first** `exportFiles` call only.
  Tests (`ExportTempFileTests`): `exportFilesPreparesOnceAndWritesEveryFile`
  — two CSVs, both present, exact bytes, URLs in input order;
  `aSecondFileSetLeavesOnlyTheSecondSet`; `aSecondExportLeavesExactlyOneFileSet`
  unchanged. `ExportConcurrencyTests`: a third call through the
  existential records a third `false`.
  *Done when*: tests green; mutation checks — purge inside `write`
  → the first new test red (only the last file survives); drop
  `@concurrent` from **both** the requirement and the implementation
  → probe red (per 012's matrix, dropping either alone stays green —
  confirm and record rather than assume).

- [x] **T002 — `StagedExport` as a set; `ShareSheet(urls:)`.**
  *Done (2026-09-01)*: `StagedExport(urls:filenames:)` with the
  single-file initializer delegating to it; `ShareSheet.urls` →
  `activityItems`; both views pass `staged.urls`. The reader inventory
  was four test lines, not two — the plan's grep pattern missed
  `staged.filename` on a local (`ItemListViewModelTests:782`,
  `WishlistViewModelTests:657`) alongside the two
  `stagedExport?.filename` template assertions; all four now assert
  one-element `filenames`. `aSingleStagedFileIsAOneElementSet` pins
  the delegation. Full suite: 705 tests / 106 suites + 6 UI tests
  green; `ExportWiringTests`' sheet-literal and UIKit-confinement
  scans untouched and passing.
  Per plan §Export service. `StagedExport(urls:filenames:)`, keeping
  `init(url:filename:)` so neither list VM changes; the single-file
  accessors go. `ShareSheet` takes `urls` → `activityItems`. Update
  the two views (`ShareSheet(urls: staged.urls)`) and the four test
  assertions (`filenames == [...]`). No behavior change.
  *Done when*: build green; full suite green including
  `ExportWiringTests.theShareSheetAndFailureAlertAreWired` and
  `uiKitStaysInsideTheFlaggedExceptions` untouched; a one-line unit
  test pins `init(url:filename:)` → one-element arrays.

- [x] **T003 — `ManualOrderHelper.areInCustomOrder`.**
  *Done (2026-09-01)*: the generic `areInCustomOrder(_:_:tieBreak:)`
  is built *on* `areInOrder` — its primary abstains while positions
  differ and speaks only on a collision — so the `<` on `sortOrder` is
  written once in the file whose doc comment promises that; the two
  entity overloads carry the tails and the T039 history comment
  moved with them. Both `isOrderedBefore`s collapsed to
  `attributeOrder(lhs, rhs) ?? ManualOrderHelper.areInCustomOrder(lhs, rhs)`
  — the case analysis (attribute decides / positions differ /
  positions collide) matches the old three-step bodies line for line,
  and every existing sort test stayed green as the behavior-preservation
  proof. Five new helper tests (position wins; a shared position
  falls to the tail; items by creation then id, antisymmetric; position
  outranks creation; wanted items by case-insensitive name then id).
  Mutations, both reverted: **M-a** inverted the items tail → 3 tests
  red (the helper's creation test plus both list-VM legacy-store
  tests, `customSortOnAnUnbackfilledStoreFollowsCreationOrder` and
  `unvaluedItemsAtASharedPositionFollowCreationOrder`); **M-b**
  dropped the position step → red across the helper, both lists'
  tie-resolution tests, and every reorder-persistence test — position
  is load-bearing everywhere, which is the point of one function.
  Full suite: 710 tests / 106 suites + 6 UI tests green. (Selector
  trap hit once more: `-only-testing:TroveTests/ItemListViewModelTests`
  matched no suite — the structs are named per concern — and ran 14
  tests silently; re-run as the whole unit target.)
  Per plan §Custom order and totals. In `ManualOrderHelper.swift`:
  the generic `areInCustomOrder(_:_:tieBreak:)` (position first, the
  tail on a collision) and the two entity overloads — items:
  `createdAt` then `id.uuidString`; wishlist: case-insensitive name
  then `id` — with the T039 history comments moving with the code.
  Both list VMs' `isOrderedBefore` become
  `attributeOrder(lhs, rhs) ?? ManualOrderHelper.areInCustomOrder(lhs, rhs)`;
  `areInOrder(primary:)` stays.
  Tests (`ManualOrderHelperTests`): position wins over the tail; the
  tail decides a collision, for both entities; identical rows order
  deterministically by id. Every existing sort test in both VM suites
  stays green — that's the behavior-preservation claim.
  *Done when*: tests green; mutation checks — invert the items tail
  → helper tests **and** the list VM's legacy all-zero sort test red;
  drop the position step → red across both.

## Phase 2 — Pure pieces: copy, status, version

- [x] **T004 — `DeleteAllCopy`.**
  *Done (2026-09-01)*: `DeleteTarget` (its own type — copy, alert case
  and commit path say one word) and `DeleteAllCopy`; the message is
  **count-aware** as well as mode-aware: a list of one reads with the
  single-item alerts' own sentences ("Its photos go too. Any sell plan
  it's on drops it."), since deleting a list of one *is* a single
  delete — an extension of the person's singular-title correction, in
  the same spirit. Nine tests, whole-string pins. Mutations (batched
  with T005–T007's — disjoint functions, each red attributable):
  removing the mode branch → `theICloudSentenceFollowsTheStorageMode`
  (16 issues), `theLocalOnlyMessagesStillNameTheOtherConsequences`,
  and the singular local-only pin red; pluralizing the singular →
  `aListOfOneReadsAsYourOnlyItem` red.
  Per plan §Copy. `Trove/Models/DeleteAllCopy.swift`:
  `title(count:target:)` ("Delete all 309 items?", "Delete all 12
  wishlist items?", singular **"Delete your only item?" / "Delete your
  only wishlist item?"**); `message(for:mode:)` with the iCloud
  sentence for `.cloudKit` only (Decision 13); `confirm`, `cancel`,
  `footer`, `failureTitle`, `failureMessage` as pinned in the plan.
  Tests (`DeleteAllCopyTests`): plural and singular titles for both
  targets; each message names photos, the sell-plan consequence, and
  no undo; the iCloud sentence present for `.cloudKit` and absent
  for `.localOnly` and `.ephemeral`; buttons, footer, failure strings.
  *Done when*: tests green; mutation checks — remove the mode branch
  → the absent-sentence tests red; pluralize the singular → red.

- [x] **T005 — `SyncStatusCopy`, the fallback-reason environment
  entry, and its injection.**
  *Done (2026-09-01)*: the six-cell table pinned whole-string
  (parameterized — the table had to be `nonisolated static`, since
  `@Test(arguments:)` reads it off the suite's main-actor default);
  nil / short / long reasons; the criterion-10 sweep over every cell;
  the catching-up headline pinned to the empty states' words.
  `StorageEnvironment.swift` holds the `@Entry`; `TroveApp` forwards
  `store.cloudKitFailure?.localizedDescription` — the first reader
  that value has had. `SettingsWiringTests` starts with the forwarding
  scan. Mutations: caught-up reading as catching-up → the table cell
  red; claiming a fallback with a nil reason → the ephemeral cell and
  `theReasonOnlySpeaksForALocalModeThatRecordedOne` red; the
  forwarding line removed → the scan red.
  Per plan §The iCloud row. `Trove/Models/SyncStatusCopy.swift`:
  `SyncStatus { headline, detail }` and
  `status(mode:phase:fallbackReason:)` implementing the plan's table
  — the local-only detail depends on whether a reason was recorded,
  never on the mode. `Trove/Views/Shared/StorageEnvironment.swift`:
  `@Entry var storageFallbackReason: String? = nil`. `TroveApp`
  injects `store.cloudKitFailure?.localizedDescription`.
  Tests (`SyncStatusCopyTests`): a **full-string table** over every
  (mode, phase) cell, with a nil reason, a short reason, and a long
  reason; no output contains "other devices". Start
  `SettingsWiringTests.swift` with one scan: `TroveApp.swift` forwards
  `store.cloudKitFailure` into `\.storageFallbackReason`.
  *Done when*: tests green; mutation checks — return the catching-up
  copy for `.caughtUp` → red; make the local-only detail claim a
  fallback when the reason is nil → red; remove the injection line
  → scan red.

- [x] **T006 — `AppVersion`.**
  *Done (2026-09-01)*: `init(info:)`, `current`, `display`; five tests
  including one that `current` in the test host carries both keys
  (the app's bundle is the host, so neither half may be "?"). Mutation:
  keys swapped → three tests red.
  Per plan §About. `Trove/Models/AppVersion.swift`: `init(info:)`
  reading `CFBundleShortVersionString`/`CFBundleVersion` (`"?"` when
  absent), `static var current` from `Bundle.main`, a display line.
  Tests (`AppVersionTests`): both keys present; each missing; the
  display line.
  *Done when*: tests green; mutation check — swap the two keys → red.

- [x] **T007 — `ImportCopy`: the template moved.**
  *Done (2026-09-01)*: body reworded to "A blank template with the
  expected layout is in Settings › Templates."; the new whole-string
  test covers both targets. Mutation — the B6 shape, a body carrying
  its own "Nothing was imported." — went red in
  `theWrongLayoutMessagePointsAtSettingsTemplatesExactlyOnce` while
  `failureMessagesAreActionableAndAllEndWithTheGuarantee` **stayed
  green**: both outcomes observed, which is the whole reason the
  equality test exists. Phase-end full suite (this task's commit is
  the phase's last): 731 tests / 110 suites + 6 UI tests green.
  Per plan §Copy. `.headerMismatch(wrongList: false)` body becomes
  "The columns don't match the \(noun) template. A blank template with
  the expected layout is in Settings › Templates." — body only; the
  function still appends "Nothing was imported." itself.
  Tests (`ImportCopyTests` in `ImportServiceTests.swift`): **full-
  string equality** for both targets; the existing suffix loop stays.
  *Done when*: tests green; mutation check — append "Nothing was
  imported." inside the body (the B6 shape) → the equality red while
  the suffix test stays green, which is exactly why the new test
  exists; record that both outcomes were observed.

## Phase 3 — `SettingsViewModel`

- [x] **T008 — The view model's surface.**
  *Done (2026-09-01)*: `SettingsViewModel` with the six-parameter init,
  `fetchCount`-backed counts, `Activity`/`SettingsAlert`, the three
  `can…` flags, `syncStatus` (live — the test records a `SyncEvent` on
  the injected monitor and watches the headline flip), `alertTitle` /
  `alertMessage` composed from the shared copy with the storage-mode
  branch as a view-model fact, `versionLine`, `cancelDeleteAll`. Nine
  tests. Mutations, both reverted: `canExportEverything` from one
  count → `theFlagsAskThreeDifferentQuestions` red; the export failure
  title as a literal → `theFailureAlertsReadTheSharedCopy` red. Unit
  target: 740 tests / 111 suites green.
  Per plan §`SettingsViewModel`. `Trove/ViewModels/SettingsViewModel.swift`:
  the six-parameter init (live `FileExportService(container:)` default,
  `AppVersion.current` default); `load()` refreshing `itemCount` /
  `wishlistCount` via `fetchCount`; `Activity` and `activity` /
  `isBusy`; `SettingsAlert` and `alert`; `alertTitle` / `alertMessage`
  composed from `DeleteAllCopy` (with `storageMode`) and `ExportCopy`;
  `syncStatus` from `SyncStatusCopy` over `syncMonitor.phase`;
  `versionLine`; `canExportEverything`, `canDeleteItems`,
  `canDeleteWishlist`; `cancelDeleteAll()`. No SwiftUI import.
  Tests (`SettingsViewModelTests`, new file): counts follow the store;
  the three `can…` flags at every combination of empty/non-empty;
  `syncStatus` **changes live** when the injected monitor records a
  finished successful import (`SyncEvent`); `alertTitle`/`alertMessage`
  for each alert case, including the mode branch through a
  `.localOnly` VM; `versionLine` from an injected `AppVersion`.
  *Done when*: tests green; mutation checks — compute `canExportEverything`
  from one count → red; compose the failure title from a literal
  instead of `ExportCopy` → red.

- [x] **T009 — Export everything: the CSV pair and the PDF pair.**
  *Done (2026-09-01)*: both intents fetch whole, sort with
  `ManualOrderHelper.areInCustomOrder`, and stage one `exportFiles`
  set. The lists' document titles and unfiltered coverage labels
  became `static let`s on the list view models (`documentTitle`,
  `wholeCoverageLabel`), used by their own exports and by Settings —
  one definition, so criterion 5's byte-identity can't drift on a
  string. Seven tests: the tie fixture's **explicit expected order**
  (`["Charlie", "Bravo", "alpha", "Zulu"]` / `["alpha", "Bravo",
  "Charlie", "Zed"]`) with one-call/two-files pinned; byte-identity
  against both list VMs' `.custom` unfiltered exports; PDF covers and
  entries against the lists' documents, totals checked by value;
  both-empty no-op; one-empty two files with the template bytes and a
  cover-only document; the shared failure copy; mid-flight `activity`
  with reentry refused (gated spy). Mutations, all reverted (batched,
  disjoint): a position-only `FetchDescriptor` sort → the explicit-
  order test red (and, as it happens, the byte-identity test too — the
  fixture's ties are real); the emptiness gate dropped → the both-empty
  test red; one `exportFiles` call per file → the one-call, one-empty
  and PDF-pair tests red. Unit target: 747 tests / 112 suites green.
  Per plan §`SettingsViewModel` and §Custom order and totals.
  `exportEverythingAsCSV()` / `exportEverythingAsPDF()`: guard
  `canExportEverything, !isBusy`; set `activity`; fetch both entities;
  sort with `ManualOrderHelper.areInCustomOrder`; build both tables /
  both documents with the unfiltered strings (`"Owned Items"` /
  `"All items"`, `"Wishlist"` / `"Whole wishlist"`), the same total
  reductions the list VMs use, and `ExportFilename`'s dated names;
  one `exportFiles` call → `stagedExport`; throw → `.exportFailed`.
  Tests: the tie fixture (equal `sortOrder`, distinct `createdAt` /
  names) asserts an **explicitly written expected order** of names in
  the CSV rows, then a second assertion that the table equals
  `ItemListViewModel`'s `.custom`, unfiltered table (and the wishlist
  twin); filenames are exactly the dated pair; PDF covers equal the
  list VMs' unfiltered covers in everything but `generatedAt`, and
  entries match; both collections empty → intents no-op, spy
  untouched; one empty → still two files, the empty one header-only
  (CSV) / `entries.isEmpty` with `itemCount == 0` (PDF); throwing spy
  → `.exportFailed` with `alertTitle == ExportCopy.failureTitle` and
  `alertMessage == ExportCopy.failureMessage`; mid-flight `activity`
  observable and a reentrant call refused (gated spy, first
  `exportFiles` only).
  *Done when*: tests green; mutation checks — sort with
  `FetchDescriptor(sortBy: [SortDescriptor(\.sortOrder)])` → the
  explicit-order test red; drop the `canExportEverything` guard → the
  both-empty test red; call `exportFiles` twice instead of once → the
  filenames test red.

- [x] **T010 — Template intents, relocated.**
  *Done (2026-09-01)*: `exportItemsTemplate` / `exportWishlistTemplate`
  through one private `stageTemplate` — `!isBusy` only — staging a
  one-file set. Three tests: 012's two byte/name pins re-pointed at
  the Settings view model (the wishlist one now pins bytes too), plus
  the shared failure copy. Mutation: gating on `canExportEverything`
  → all three red. The list view models keep `exportBlankTemplate`
  until T013 removes it with the menu item. Unit target: 750 tests /
  113 suites green.
  Per plan §`SettingsViewModel`. `exportItemsTemplate()` /
  `exportWishlistTemplate()`: guard `!isBusy` only (never the counts —
  an empty collection is the template's audience);
  `exportFiles([.csv(CSVTable(headers:, rows: []), filename:
  ExportFilename.itemsTemplate)])` and the wishlist twin. The list
  VMs' `exportBlankTemplate()` stays until T013 removes it.
  Tests: 012's two template tests re-pointed at the Settings VM —
  BOM + header + CRLF byte-exact (items), headers/rows/filename
  (both) — from an empty collection.
  *Done when*: tests green; mutation check — gate the intent on
  `canExportEverything` → both red.

- [x] **T011 — Delete All: request, confirm, cancel — and the
  measurement.**
  *Done (2026-09-01)*: `requestDeleteAll` re-counts at request time;
  `confirmDeleteAll(_ target:)` is the synchronous capture / async
  commit with the target as a parameter, per-object `delete` and one
  `save`, `rollback()` in the catch, `load()` in the `defer`. Eight
  tests, every persistence claim through a second `ModelContext`,
  plus the rollback scan in `SettingsWiringTests`. **Measurement**:
  300 items each carrying a 50 KB photo — **~150 ms** on the main
  actor in isolation (0.153 s, 0.151 s), phases fetch 17 ms / loop
  3 ms / save 102 ms (32 ms in total without photos); under the plan's
  250 ms threshold, so **the main-actor branch ships** and the
  background-context fallback stays unbuilt. Two honest notes: the
  first measurement, taken inside the whole unit target, read 5.4 s
  because Swift Testing runs suites in parallel — measure in
  isolation, always; and one isolated run read 100 s, a stall that
  matches ~100 s outliers seen in two Phase 1 full runs before any
  delete code existed, so it's the test host (its real CloudKit
  container on a signed-out simulator), not the deletion — recorded
  for T016/T017 rather than explained away. Mutations, all reverted:
  `save()` deleted → all five second-context tests red (and a
  same-context refetch would not have caught it — the T018 shape);
  the confirm depending on `alert` still being staged → the race test
  and the synchronous-activity test red; `rollback()` removed → the
  scan red.
  Per plan §The delete-all commit path. `requestDeleteAll(_:)`
  re-counts at request time and stages `.confirmDelete(target,
  count:)`; `confirmDeleteAll(_ target:) -> Task<Void, Never>?` —
  target as a parameter, synchronous capture (`guard !isBusy`, clear
  the alert, set `activity`), the returned task yields, then
  fetch-all → per-object `delete` → one `save()`; `rollback()` and
  `.deleteFailed` on a throw; `load()` in the `defer`.
  **Measure**: an in-memory container with ~300 items each carrying
  one small photo, `confirmDeleteAll(.items)` timed across a few runs;
  record the figure in plan.md and take the plan's branch — ≤ 250 ms
  ships on the main actor; above it, the loop moves to a background
  `ModelContext` in one `@concurrent` body (still one save, still
  rollback on throw) with `load()` on main. Either way, no chunking.
  Tests: request carries the **live** count (insert through a second
  context after `load()`, then request); cancel leaves the store
  intact (second-context count); confirm deletes every item, verified
  **through a second `ModelContext`** (the T018 shape), the wishlist
  untouched, the surviving wishlist item's `plannedSaleItems` empty,
  the `Photo` count zero; the wishlist twin (items untouched, its
  photos gone, its sell plans gone with it); the race test — write
  `alert = nil` *before* `confirmDeleteAll(.items)`, await the task,
  store empty; counts reload to zero and `activity` clears; the
  `confirmDeleteAll` body contains `modelContext.rollback()`
  (`SettingsWiringTests` scan, the `confirmImport` template).
  *Done when*: tests green; the measurement and branch recorded in
  plan.md; mutation checks — delete `save()` → the second-context
  tests red (and confirm a same-context fetch would have stayed
  green, to show the shape matters); make confirm read `alert`
  instead of its parameter → the race test red; remove `rollback()`
  → scan red.

## Phase 4 — UI

- [x] **T012 — `SettingsView`.**
  *Done (2026-09-01)*: the screen and its private `SettingsActionRow`
  (brass / `accentRustText` / `textDisabled`, `DetailRow`'s hairline,
  the trailing compact spinner while acting, `role: .destructive` plus
  an explicit hint on both delete rows), the iCloud block as one
  accessibility element, the footer, About as name / subtitle / mono
  version line; one `.alert` off `viewModel.alert` switching on the
  case, the confirm calling `confirmDeleteAll(target)` plainly; the
  share sheet off `stagedExport` with `ShareSheet(urls:)`; three
  previews (populated/syncing, empty, local-only with a reason).
  Eight scans in `SettingsWiringTests` plus the third delete route in
  `DeletionGuardTests`. **One scan was false-passing and got caught by
  its own mutation**: the section-order scan read where the section
  properties were *declared*, so swapping two sections in the body's
  composition stayed green. Rewritten to read the body's stack; the
  swap then went red. Mutations, all reverted: the confirm wrapped in
  a `Task` → red; `.disabled(viewModel.isBusy)` on Done → red; a hint
  dropped → red; Delete swapped above iCloud → red (after the fix).
  Unit target: 768 tests / 114 suites green.
  Per plan §Entry point and the Settings sheet.
  `Trove/Views/Settings/SettingsView.swift`: the form sheets' chrome
  (`ZStack` background, `ScrollView`, inline "Settings" title, one
  never-disabled Done); five `DetailSection`s in spec order;
  `SettingsActionRow` (brass / `accentRustText` destructive /
  `textDisabled`, `DetailRow`'s hairline, the trailing compact brass
  spinner while acting, `role: .destructive` **plus** an
  `.accessibilityHint` on both delete rows); the iCloud row as one
  accessibility element in `theme.typography.body` / `.secondary`
  (typography tokens only); the Delete footer; About via `DetailRow`s;
  `.sheet(item: $viewModel.stagedExport)` with `ShareSheet(urls:)` and
  the medium/large detents; **one** `.alert` off `viewModel.alert`
  switching on the case, the confirm button calling
  `viewModel.confirmDeleteAll(target)` plainly. `#Preview`s: a
  populated store; an empty one; a `.localOnly` mode with a fallback
  reason (the only way to see that copy on demand).
  Tests (`SettingsWiringTests`): `ShareSheet(urls:` present; exactly
  one `.alert(`; `viewModel.confirmDeleteAll(` present and
  `await viewModel.confirmDeleteAll` absent; `Button("Done")` with no
  `.disabled`; the five section titles appear in spec order;
  `.accessibilityHint` count ≥ 2; no version literal in either
  Settings file; `SettingsViewModel.swift` reads `DeleteAllCopy`,
  `ExportCopy`, `SyncStatusCopy`. `DeletionGuardTests`: the
  shared-copy guard grows the third route (the Settings VM reads
  `DeleteAllCopy`); its view-scan passes for free.
  *Done when*: build green, previews render; scans green; mutation
  checks — wrap the confirm call in `Task { await … }` → red;
  `.disabled(viewModel.isBusy)` on Done → red; swap two sections →
  red; drop one hint → red.

- [x] **T013 — The entry point: badge, sheets, and the template's
  departure.**
  *Done (2026-09-01)*: `OverflowBadge` carries `openSettings` in place
  of `getTemplate` and the five-item, three-group menu; both lists
  read the two storage environment values, keep `syncMonitor`, and
  own the Settings sheet with `onDismiss: viewModel.load`;
  `exportBlankTemplate` and its two suites left the list view models
  (a comment marks where each went). `ExportWiringTests`' two badge
  tests became `…FiresEveryIntentAndOpensSettings` and
  `theMenuCarriesFiveItemsInThreeGroups` (Settings present, template
  absent, two dividers, two gates, Import before Settings);
  `SettingsWiringTests` pins both lists' sheet wiring and all four
  init arguments. **The fresh-install UI test was updated here rather
  than at T014** so this commit's full suite is green: it now asserts
  Settings enabled and the template absent. Full suite: 767 tests /
  112 suites (two suites moved into Settings) + 6 UI tests green.
  Mutations, all reverted (batched, disjoint): the template literal
  back in the menu → the menu test red; `onDismiss: viewModel.load`
  dropped on the Items sheet → the sheet-wiring test red; the badge
  re-nested inside the wishlist's `totalCount` gate → the existing
  outside-the-gate scan red.
  Per plan §Entry point and the Settings sheet. `OverflowBadge`:
  `getTemplate` → `openSettings`; menu = the two exports (gated),
  `Divider()`, Import, `Divider()`, **Settings**; doc comment and
  previews. Both list views: `@Environment(\.storageMode)` /
  `@Environment(\.storageFallbackReason)`, a stored `syncMonitor`,
  `@State isShowingSettings`, `openSettings: { isShowingSettings = true }`,
  `.sheet(isPresented: $isShowingSettings, onDismiss: viewModel.load)
  { NavigationStack { SettingsView(modelContext:, syncMonitor:,
  storageMode:, storageFallbackReason:) } }`. Remove
  `exportBlankTemplate()` from both list VMs and delete their old
  template suites (T010 carries the assertions now).
  Tests: `ExportWiringTests` — `theBadgeIsFedByTheViewModelAndFiresAllFourIntents`
  becomes `…FiresEveryIntentAndOpensSettings` (asserts
  `isShowingSettings = true`, no template intent, one badge per
  list); `theMenuCarriesFourActionsWithOnlyExportsGated` becomes
  `theMenuCarriesFiveItemsInThreeGroups` ("Settings" present, "Get
  Blank Template…" absent, `Divider()` count 2, `.disabled(!canExport)`
  count 2, Import's literal before Settings'). `SettingsWiringTests`:
  both list views attach the Settings sheet with `onDismiss:
  viewModel.load` and pass all four init arguments. The
  overflow-outside-the-gate scan is unchanged and stays green.
  *Done when*: build + full suite green; mutation checks — put "Get
  Blank Template…" back in the menu → literal scan red; drop
  `onDismiss: viewModel.load` on one list → scan red; nest the badge
  back inside the `totalCount` gate → the existing scan red.

- [x] **T014 — UI tests: the fresh install reaches Settings.**
  *Done (2026-09-01)*: `testEmptyCollectionOffersImportAndSettingsButNotExport`
  (updated at T013) and the new
  `testSettingsFromAnEmptyCollectionOffersTemplatesAndNothingElse` —
  sheet present, both templates enabled, both export-everything rows
  and both Delete All rows disabled, the iCloud row reading "On this
  device only" for the in-memory store, Done dismissing back to a
  hittable badge. The UI target ran **twice back to back**, 7/7 both
  times, so the `-uiTesting` isolation still holds. Mutations: the
  first attempt batched the two — re-nesting the badge and dropping
  the export rows' emptiness gate — and the re-nest failed *both*
  tests at the badge step, masking the gate check exactly as the
  review's S6 predicted; re-run with only the gate dropped → the new
  test red on precisely its two export assertions (lines 282–283),
  everything else green. Re-nesting alone → the fresh-install test
  red (and the new one, for the unrelated reason). Both reverted.
  Per plan §Test plan (UI). Rename and update
  `testEmptyCollectionOffersImportAndTemplateButNotExport` →
  `testEmptyCollectionOffersImportAndSettingsButNotExport` (Settings
  enabled, the template absent from the menu, exports disabled). New
  `testSettingsFromAnEmptyCollectionOffersTemplatesAndNothingElse`:
  tap Settings → the sheet's "Settings" title; "Items Template…"
  enabled; "Export All as CSV…" and "Delete All Items…" disabled;
  Done returns to the Items screen. Run the UI suite **twice back to
  back** to confirm the `-uiTesting` isolation still holds.
  *Done when*: both green twice; mutation checks — re-nest the badge
  → the first test red; drop the `canExportEverything` gate on the
  export rows → the second test red (its own break, since re-nesting
  would fail it for an unrelated reason).

## Phase 5 — Docs, device pass, close-out

- [x] **T015 — Docs and supersession notes.**
  *Done (2026-09-01)*: `docs/csv-reference.md` (the opening paragraph
  and the recommended loop now say **⋯ → Settings → Templates**);
  `README.md`'s Import bullet ("grab a blank template from Settings");
  `specs/012-data-import/spec.md` superseded-in-part notes on
  criterion 1, the entry-point bullet, the "Template and reference
  docs" paragraph, and Decision 8; `specs/011-data-export/spec.md`'s
  criterion-1 note gained its 013 clause. T001's 011 `plan.md`
  delivery-section restatement confirmed present. `DocsSampleTests`
  green throughout (the samples never named the template's home).
  Per plan §Docs and notes. `docs/csv-reference.md` lines 6–7 and
  132 (Settings → Templates); `README.md` line 39;
  `specs/012-data-import/spec.md`: superseded-in-part notes in the
  011 form on criterion 1, the entry-point "Get Blank Template…"
  bullet, the "Template and reference docs" section, and Decision 8;
  `specs/011-data-export/spec.md` 142–146: a one-clause addendum.
  Cross-check that T001's 011 `plan.md` delivery-section edit landed.
  *Done when*: every listed line changed; `DocsSampleTests` still
  green (the samples never mention the template's home).

- [x] **T016 — Full verification and manual device pass.**
  *Done (2026-09-02)*: full suite 774 tests green (767 unit / 112
  suites + 7 UI), then the pass on the iPhone 17 Pro simulator against
  the ~307-item dev store, every claim checked at the file level where
  a file was involved. Menu exactly as specced on both lists. Settings
  as designed: five sections, rust delete rows, "iCloud isn't
  available" on the signed-out simulator, "Version 1.0 (1)" from the
  bundle. **Export All as CSV…** — the share sheet's Files picker read
  "Save as 2 Items"; both landed (`Trove-Items-2026-09-02.csv`, 308
  lines, BOM, CRLF; `Trove-Wishlist-2026-09-02.csv`, 4 lines); the
  staging directory held exactly the pair. **Export All as PDF…** —
  "2 Documents, 195 KB", 116 + 2 pages saved to Files, and the staging
  listing showed the CSV pair purged by the set. **Wishlist Template…**
  staged at 68 bytes. **Delete All Wishlist Items** — "Delete all 3
  wishlist items?" with the full message (the iCloud sentence present:
  the store is configured for iCloud), Keep reopened at 3, Delete All
  disabled the row; the next PDF pair's wishlist document was **one
  cover-only page** (criterion 7). **Delete All Items** at the largest
  accessibility size — "Delete all 307 items?" with both buttons
  reachable and the message scrollable — completed within a
  screenshot's latency; every export and delete row disabled; Done
  returned to "No gear yet"; the Dashboard read "Nothing tracked yet".
  Then the round trip: **Import from CSV… of the exported items file
  read "Import 307 items? No problems found."** and restored 307 items
  · $545,750 · 5 unvalued, and the wishlist file restored its 3 — the
  dev store is back as found (sell-plan links excepted: the CSV never
  carried them, 011's recorded deferral). Honest residuals, recorded:
  no spinner was observable at these speeds; the caught-up and
  catching-up iCloud states need a signed-in device and the fallback
  copy lives only in a preview; AirDrop isn't exercisable on a
  simulator; "Done mid-export" can't be timed by hand at ~ms
  generation, so the abandon behavior rests on the sheet's state dying
  with the view and the purge listing; VoiceOver over the delete rows
  needs Accessibility Inspector or hands. No surprises — nothing to fix
  on this branch from the pass.
  Per plan §Verification. Build + full suite (count reported), then
  on the iPhone 17 Pro simulator: Export All as CSV… and …as PDF…
  from the dev store — two files land in Files via Save to Files and
  arrive by AirDrop; the cover-only PDF with one list emptied; both
  templates from Settings (68-byte wishlist template as in 012); the
  iCloud row signed out (`iCloud isn't available`), signed in and
  caught up, and during a catch-up if one can be provoked; the
  `.localOnly` copy via the T012 preview; **Delete All Items on the
  ~300-row dev store, timed on device**, the plan's branch confirmed
  or revisited and recorded; the confirmation and failure alerts at
  the largest accessibility size; VoiceOver over both delete rows
  (the hint is what criterion 18 rests on); Done mid-export, then the
  next export's purge confirmed by **listing the staging directory**,
  not by watching for a sheet. Note surprises as bugs on this branch.
  *Done when*: every check performed and noted — surprises included —
  in the Done note; timing recorded in plan.md.

- [x] **T017 — Close-out review.**
  *Done (2026-09-02)*: all nineteen criteria checked off with a
  per-criterion Verification record in spec.md, honest partials stated
  (the signed-in iCloud states, the fallback copy, VoiceOver by hand,
  AirDrop, the mid-export abandon, and the spinner). The pre-merge
  skeptical sweep ran over spec/plan/tasks, CLAUDE.md, README, the
  docs, and the 011/012 notes, and found **two blocking items and
  twelve second-looks, all acted on**: criterion 14's view half had no
  guard (the view model refuses a reentrant call whether or not the
  rows disable) → `everyActionRowGatesOnBusyAndReadsItsOwnActivity`,
  mutation-red on a dropped busy gate; the spec's §Delete still said
  "the role VoiceOver reads" after the plan had corrected it → amended
  inline, the Decisions-13/14 form; the rollback scan tightened to
  exactly one `save()` and `rollback()` inside the extracted `catch`
  only (mutation-red on a second save); the hint scan extended to the
  row's *application* of the hint and the iCloud block's combine
  (mutation-red on the application removed — the
  declaration-vs-composition shape, found a second time on this
  branch); the singular Delete All sentences pinned equal to
  `ItemDeleteCopy`/`WishlistDeleteCopy` in local-only mode instead of a
  magic-number prefix (mutation-red on a reword); the UI tests assert
  existence before `isEnabled` (false for a missing element); the
  `exportFiles` purge placement recorded as built (first write, not
  first render) with its mid-set caveat; three test citations this
  branch had staled in the 011/012 specs corrected and 012's criterion
  12 given its supersession note; 011 `plan.md`'s second statement of
  the purge invariant restated; criterion 15's abandon half carried up
  as a partial; the count-aware singular message noted in spec §Delete;
  the README Features list and a `README.md` routing line added to the
  post-merge list. The falsifiability audit over every 013 test found
  no same-context persistence check (all through a second context), a
  real tie-break guard, and — the two shapes above — nothing else.
  Final: build green; full suite 768 tests / 112 suites + 7 UI tests
  green (the ~100 s environmental stall hit one more full run, 205 s
  instead of 6, and passed). Status flipped to Complete.
  012's T018 pattern: sweep every Done note against what the code
  actually does; check each of the 19 spec criteria with a
  verification citation (honest partials stated as partials); audit
  for the project's recorded false-passing shapes — same-context
  persistence checks, tie-break tests that can't see their rule
  deleted, over-broad literal scans — and this spec's own near-miss,
  the suffix test that would pass a doubled sentence; disposition
  anything found (blockers fixed here, the rest recorded); confirm
  plan.md matches as-built reality — the measured delete timing and
  the branch taken above all — amending in place where it doesn't;
  invoke the skeptical-reviewer for the pre-merge whole-spec sweep
  over spec/plan/tasks; then mark this file Complete.
  *Done when*: all criteria dispositioned, findings recorded, status
  flipped.


## Phase 6 — Amendment A: the Dashboard "…" and bespoke in-page menus

Drafted 2026-09-02 against the approved plan addendum (approved the
same day; drafted at `298b1a8`). Same house rules as above; every
call traces to the addendum's sections. Ordering, recorded up front:
the render oracle lands **first**, while it is trivially green, so
the refactor it guards can't be committed without it; then the
surface and rows; then the host, migrating Sort By alone (the one
dropdown that already exists, so the mechanism is proven on
unchanged behavior before anything new rides on it); then the lists'
"…"; then the Dashboard, badge before order control, so the
Dashboard's first host has one menu; docs after every drawing
exists; the device pass last. Each commit leaves the app sound —
T019 injects the dismiss action into the lists' old overlay for the
one commit before T020 replaces it.

- [x] **T018 — The render oracle, before anything moves.**
  *Done (2026-09-02)*: `TroveTests/SortDropdownRenderTests.swift` —
  `LegacySortDropdown` (today's `SortDropdown` verbatim, its glyph and
  header included, marked as 010's drawing frozen at `99747d5`) and
  two parameterized tests over `.custom` and `.currentValue`: equal
  dimensions asserted first, then the first differing pixel reported
  with both values; and the same view rendered twice, compared the
  same way. Green: 2 tests (4 cases) in 1 suite. **Determinism
  recorded**: both states rendered identically twice — the oracle is
  usable as an exact comparison, no tolerance. **Mutations, one at a
  time, both reverted**: **A** the row's top padding 12 → 13 in the
  production view → red on the size guard first, "legacy 232×243,
  production 232×248" (five rows, one point each), the determinism
  test still green; **B** the header's tracking 1.6 → 1.7 (same size,
  different pixels) → red on the pixel walk at (22, 14), "legacy
  #31302E, production #242321" — the header text — so both halves of
  the guard fail on their own. The renders are 232×243 at 1×, the
  project's `renderBitmap` scale; a one-point shift is a whole pixel
  row at that scale. Full unit target: **770 tests in 113 suites
  passed** (768 + 2; one new suite). One compile fix on the way: the
  suite's `typealias` had to be non-private, since the parameterized
  test methods use it in their signatures.
  Per addendum §Test plan (render oracle). New
  `TroveTests/SortDropdownRenderTests.swift`: `LegacySortDropdown` —
  today's `SortDropdown` copied verbatim into the test target, private
  `CheckmarkGlyph` and header included, its doc comment saying it is
  010's drawing frozen as the oracle for T019 and deleted at T019's
  close-out. Render both through `renderBitmap` for two states — Custom
  selected with the REORDER tag; a non-manual selection — over
  `ItemListViewModel.SortOrder.allCases`; assert **equal dimensions
  first**, then exact pixel equality, no tolerance; render each twice
  and assert the two renders equal (determinism). Trivially green
  today. Mutation: one padding value changed in the production
  `SortDropdown` → red; revert. If the twice-render check fails, record
  it, drop the oracle to the structural scans of T019, and say so in
  this note — not silently.
  *Done when*: the suite is green, the mutation red-run is recorded,
  the determinism result is recorded, `xcodebuild test
  -only-testing:TroveTests` green with the count.

- [x] **T019 — `Dropdown.swift`: the surface and the row, and
  `SortDropdown` re-composed.**
  *Done (2026-09-02)*: `Dropdown.swift` (`DropdownSurface(title:)`,
  `DropdownRow` with `isEnabled`/`startsGroup`/`hasTopHairline`/`tag`
  and dismiss-before-action, `CheckmarkGlyph` moved), `DropdownHost.swift`
  holding `DismissDropdownAction` and its loud `@Entry` default,
  `ThemeMetrics.dropdownGap = 6`, `SortDropdown` re-composed on the pair,
  both lists' old overlay carrying the stopgap
  `.environment(\.dismissDropdown, …)` until T020, and
  `DropdownWiringTests` (four scans, bodies not declarations).
  **The oracle earned its keep on the first run**: the re-composed
  dropdown came back 232×211 against 232×243 — the *first row was
  gone*. A PNG dump showed the header and rows two to five, no
  "Custom"; removing only the focus modifier restored it, and putting
  the modifier on every row instead left 232×83. So a view carrying an
  `accessibilityFocused` binding renders as nothing under
  `ImageRenderer`, which has no focus system — not a `Subview` quirk,
  a renderer one. As built, therefore: the surface marks its first
  subview through `\.isFirstDropdownRow` (only `.environment` ever
  touches a subview), the row applies a `FirstRowFocus` modifier that
  acts on the first row alone, and a second entry,
  `\.dropdownFocusesFirstRow` (default on), lets the render tests turn
  the marking off — the one thing the oracle can't see, so the
  simulator was made to show it: with the marking on, Sort By on the
  Items list drew all five rows, "Custom" included, header, tint,
  checkmark and hairlines in place at the same position, and a row tap
  closed it through the environment action with no assertion. The
  plan's "`.accessibilityFocused` on the surface via `Group(subviews:)`"
  line is superseded by this; recorded for the close-out's as-built
  pass. Oracle green across the refactor (7 tests / 2 suites with the
  wiring scans); **its red-run on the new composition**: `DropdownRow`'s
  top padding 12 → 13 → "legacy 232×243, production 232×248"; then the
  oracle and its test deleted, as planned. **Wiring mutations**: A,
  `action()` before `dismiss()` → red on the order assertion
  ("34 < 13"); B, `.disabled(!isEnabled)` dropped → red on
  `aDisabledRowIsInertAndDimmed`. One process slip, recorded: the
  reverts used `git checkout --` on a file git didn't track yet, so the
  three mutations *stacked* silently until the state check caught it;
  each was reversed by hand with count-asserted edits, and B was rerun
  alone for a clean record. Full unit target: **772 tests in 113 suites
  passed** (770 − 2 oracle + 4 wiring).
  Per addendum §Components. New `Trove/Views/Shared/Dropdown.swift`:
  `DropdownSurface(title:)` (232 wide, `PlateSurface`, `buttonRadius`
  clip, `divider` border, `.accessibilityElement(children: .contain)`,
  `.accessibilityAction(.escape)` no-op-safe, the header row iff
  `title != nil`, and `Group(subviews:)` attaching
  `.accessibilityFocused` to the first subview, set one run-loop turn
  after appear); `DropdownRow(title:, isSelected:, isEnabled:,
  startsGroup:, hasTopHairline:, tag:, action:)` with `.disabled(!isEnabled)`,
  `textDisabled` when disabled, the top hairline in `divider` when
  `startsGroup`, none when `!hasTopHairline`, and **`dismiss()` before
  `action()`** reading `@Environment(\.dismissDropdown)`;
  `CheckmarkGlyph` moves here. New `Trove/Views/Shared/DropdownHost.swift`
  holding, for now, only `DismissDropdownAction` (a plain struct) and
  the `@Entry var dismissDropdown` whose default is
  `assertionFailure("DropdownRow used outside a dropdownHost")` —
  the host modifier arrives at T020. `ThemeMetrics.dropdownGap = 6`
  with the `60 = 24 + 30 + 6` derivation in its comment.
  `SortDropdown` re-composes on `DropdownSurface(title: "SORT BY")`
  and `DropdownRow` (tag `"REORDER"` iff `isManualOrder`); `SortBadge`
  untouched. **Both lists' existing overlay gets
  `.environment(\.dismissDropdown, DismissDropdownAction {
  isSortMenuOpen = false })` on the `SortDropdown`** so a tapped row
  doesn't hit the loud default before T020 — removed at T020.
  T018's oracle must stay green through this; then its own red-run:
  one padding in `DropdownRow` changed → red; revert; **then delete
  `LegacySortDropdown` and its test** with the red-run recorded here.
  New `TroveTests/DropdownWiringTests.swift`, first cases:
  `Dropdown.swift` — the `Button`'s body calls `dismiss()` before
  `action()` (body order, via `SourceScan.closureBodies`),
  `.disabled(!isEnabled)`, `textDisabled` read, `Group(subviews:` and
  `.accessibilityFocused(` in `DropdownSurface`; `SortPicker.swift` —
  `SortDropdown`'s body composes `DropdownSurface(title: "SORT BY"`
  and `DropdownRow(`. Mutations: swap `dismiss()`/`action()` → red;
  drop `.disabled` → red.
  *Done when*: oracle green across the refactor, its red-run and
  deletion recorded; new scans green and mutation-red; full unit
  target green with the count; the app runs (Sort By still works on
  both lists via the old overlay).

- [x] **T020 — `DropdownHost`: the mechanism, proven on Sort By.**
  *Done (2026-09-02)*: `DropdownHost.swift` grew the mechanism —
  `DropdownAnchorKey`, `.dropdownAnchor(_:)`, `.dropdownHost(open:
  dismissLabel:content:)` with the catcher, the `.contain` + `.isModal`
  + escape container, the one real `dismissDropdown` injection, and
  `DropdownPlacementLayout` over the pure `DropdownPlacement.origin`;
  both lists run Sort By on it off `openDropdown: HeaderDropdown?`, the
  boolean and T019's stopgap gone, the sort badge anchored with its
  hint and identifier; `DropdownPlacementTests` (seven cases) and two
  more `DropdownWiringTests`. **The probe earned its place** — three
  rounds, each on the real screen with Sort By open: (1) a reader that
  *ignored* the safe area reported `insets = 0` on iOS 26 and bounds
  of the full 402×874, so "read the ignored insets back" — the plan's
  mechanism for the flip — does not exist here; (2) with the reader
  kept inside the safe area it reported the real insets (top **62**,
  bottom **83** — the floating tab bar *is* in the inset; bounds 402×
  729) but adding them to bounds that already exclude them pinned the
  dropdown two points low (origin 124 vs the natural 122.33) — the
  T020 fix: the pure function takes only the **region** the dropdown
  may occupy, no insets, and the layout places relative to its own
  origin because the second layout pass hands it bounds at y = 62 in a
  different space; (3) final: region (0, 0, 402, 729), badge (259.3,
  24, 68.7, 30.3), size 232×241.3, origin (146, 60.33) → 122.33 on
  screen, the old `60`'s 122 plus the badge's real third of a point,
  and the screenshot's plate edge at the same pixel row as T019's.
  The placement table was rewritten to the region shape (safe region
  729 tall; flip past its bottom; pin to its top; a region with a
  non-zero origin measures from itself). **Decision 18's check**:
  SwiftUICore's `AccessibilityTraits` exposes seventeen static members
  (`allowsDirectInteraction causesPageTurn isButton isHeader isImage
  isKeyboardKey isLink isModal isSearchField isSelected isStaticText
  isSummaryElement isTabBar isToggle playsSound startsMediaSession
  updatesFrequently`) — nothing pop-up, and "popup" appears nowhere in
  its interface; SwiftUI's own carries only the macOS
  `PopUpButtonPickerStyle`. Two toolchain traps on the way, both
  recorded: `Layout` methods are nonisolated, so the pure function
  had to be `nonisolated` under the project's `MainActor` default; and
  `#expect(x == 83 + 30 + 6)` types the literal arithmetic as `Int`
  and never equals a `CGFloat` (a lone literal does) — the table
  compares against explicit `CGFloat` constants. Live checks: Sort By
  on both lists opens at the old position, all rows drawn, closes on
  an outside tap and on a row tap. **Mutations, one at a time, each
  reversed by count-asserted edits** (the files carry uncommitted work
  a `git checkout` would have wiped — T019's lesson applied): the flip
  dropped → three placement cases red (flip, pin, offset region); the
  dismiss injection dropped → `theHostInjectsDismissAndContainsVoiceOver`
  red; the host moved above the add button's overlay → the Items
  list's ordering assertion red. UI target: 7 tests, 0 failures. Full
  unit target: **781 tests in 114 suites passed** (772 + 7 + 2). The
  plan's "reader ignores the safe area and reads the insets" line is
  superseded by (1)–(3); recorded for the close-out's as-built pass.
  Per addendum §The host and §Screens (lists, sort half). Fill in
  `DropdownHost.swift`: `DropdownAnchorKey`, `.dropdownAnchor(_:)`,
  `.dropdownHost(open:dismissLabel:content:)` — the `GeometryReader`
  (`.ignoresSafeArea()`) resolving `proxy[anchor]`, the catcher
  (`Color.clear`, `.contentShape(Rectangle())`, `.onTapGesture`,
  `dismissLabel(id)`, `.isButton`, explicit `.accessibilityAction`,
  `.accessibilitySortPriority(-1)`), `DropdownPlacementLayout` with the
  pure `DropdownPlacement.origin(badge:container:insets:size:gutter:gap:)`,
  the `.environment(\.dismissDropdown, …)` injection on the content,
  the `ZStack`'s `.accessibilityElement(children: .contain)` +
  `.isModal` + `.accessibilityAction(.escape)`, `.transaction {
  $0.animation = nil }`. Both lists: `isSortMenuOpen` →
  `@State private var openDropdown: HeaderDropdown?` (`private enum
  HeaderDropdown: Hashable { case sort, overflow; var dismissLabel }`);
  `sortControl` → `.dropdownAnchor(HeaderDropdown.sort)` + hint "Opens
  sort options" + identifier `sortOptions.items` / `sortOptions.wishlist`;
  the old overlay block (and T019's temporary injection) replaced by
  `.dropdownHost` placed **after** `.overlay(alignment: .bottomTrailing)`,
  its `.overflow` case a `fatalError`-free placeholder (`EmptyView`) until
  T021 — `overflowControl` still builds the system-`Menu` badge for one
  more commit. New `TroveTests/DropdownPlacementTests.swift`: the
  origin table — below with room; flipped above when below crosses the
  bottom inset; pinned to the top inset when neither fits; trailing edge
  at `container.maxX - insets.trailing - gutter`; never past the leading
  gutter. `DropdownWiringTests` gains: per list exactly one `openDropdown`,
  no `isSortMenuOpen`, `.dropdownHost(open: $openDropdown` once and after
  the add-button overlay, `.dropdownAnchor(HeaderDropdown.sort)` once;
  `DropdownHost.swift` — the environment injection,
  `.accessibilityAction(.escape)`, `.isModal`, the catcher's `.isButton`.
  **The inset probe**: a temporary `print` of `proxy.safeAreaInsets.bottom`
  as the ignoring reader resolves it and the computed origin, run once on
  the simulator with Sort By open on the Items list, the numbers recorded
  here, the print removed before commit. **Decision 18's check**: confirm
  by autocompletion that `AccessibilityTraits` has no pop-up/menu member;
  record. Mutations: drop the flip in `origin` → placement test red; drop
  the environment injection → scan red; move the host above the add-button
  overlay → scan red.
  *Done when*: placement and wiring tests green and mutation-red; full unit
  target green with the count; UI target green (7 tests); Sort By opens
  and closes on both lists exactly as before by eye, the probe's numbers
  recorded.

- [x] **T021 — `OverflowDropdown`, the badge as a pill, and the lists'
  "…".**
  *Done (2026-09-02)*: `OverflowDropdown.swift` (five closures, four
  rows on the headerless surface, the two group breaks as `startsGroup`
  on Import and Settings); `OverflowBadge` reduced to the pill —
  `isBusy` and an action, label "More actions"/"Working", hint "Opens
  more actions", its doc comment now arguing the page/bars rule rather
  than for the system menu, and `DetailOverflowMenu`'s naming itself
  the app's one system menu; both lists anchor the badge
  (`HeaderDropdown.overflow`, identifiers `moreActions.items` /
  `moreActions.wishlist`) and compose `OverflowDropdown` in the host's
  `.overflow` case with the four intents exactly as the old badge's
  arguments; `ExportWiringTests`' two badge tests rewritten to the
  badge/dropdown split (the rows scanned as `DropdownRow(` argument
  lists, so `startsGroup` and the gate are pinned *to the rows they
  belong on*); `OverflowDropdownRenderTests`; `DropdownWiringTests`
  gained the overflow anchor, the host's two-case composition, and the
  headerless check; the two UI tests query the badge by identifier.
  **Three things the instruments settled, against the plan**: (1) the
  plan's `hasTopHairline: false` first-row rule (review B4, "a doubled
  line") **does not materialize** — the surface's border overlay draws
  over the first row's hairline; a byte comparison of the two renders
  found exactly four corner pixels differing, `#252526` vs `#2C2C2F`,
  ΔE ≈ 0.03 against the project's 0.06 floor — so the parameter was
  removed rather than shipped as a rule nobody can see; (2) a disabled
  `.plain` button's label is dimmed by SwiftUI itself, measured as a
  further **0.5 on the text's alpha, composited in sRGB** (predicted
  `#45` from 32 + 0.175 × 210, measured `#454340`) — the `textDisabled`
  token applies *under* it, the compound `SettingsActionRow` already
  ships, recorded as-built; and my first dim guard ("closer to the
  disabled token than the body one") was **false-passing** for exactly
  that reason — dropping the token left the title at the token's own
  brightness — caught by mutation C and rewritten to measure each
  title's ink fraction over the surface against the token's alpha (and
  the 0.5); (3) my headerless scan tripped on the rows' own `title:`
  arguments — fixed to `DropdownSurface(title:`. **Mutations, one at a
  time, hand-reverted where the file carried uncommitted work**: A,
  `startsGroup` wired to nothing → the break test red on both
  assertions (ΔE 0.0 to the separator); C, the disabled token dropped →
  the ink-fraction guard red by 0.20; D, the export gate dropped
  (`isEnabled: true`) → the UI target red with the two export rows'
  enabled assertions failing. Live on the simulator: the Items "…"
  opens the four rows at the gutter with the two breaks reading as
  stronger rules; under an empty search the export rows dim while
  Import and Settings stay bright; the Wishlist "…" the same. **UI
  target green twice back to back**: 7 tests, 0 failures, both runs.
  Full unit target: **784 tests in 115 suites passed** (781 + 2 render
  + 1 wiring).
  Per addendum §Components and §Screens (lists, overflow half). New
  `Trove/Views/Shared/OverflowDropdown.swift`:
  `OverflowDropdown(canExport:, exportCSV:, exportPDF:, importCSV:,
  openSettings:)` — Export as CSV… (`isEnabled: canExport`,
  `hasTopHairline: false`) / Export as PDF… (`isEnabled: canExport`) /
  Import from CSV… (`startsGroup: true`) / Settings (`startsGroup: true`);
  doc comment carrying the organizing rule. `OverflowBadge` becomes the
  pill alone — `OverflowBadge(isBusy:, action:)`, glyph/spinner/border
  unchanged, label "More actions"/"Working", hint "Opens more actions" —
  its doc comment rewritten for the page/bars rule; `DetailOverflowMenu`'s
  doc comment gets the same rule. Both lists: `overflowControl` →
  `OverflowBadge(isBusy: viewModel.isBusy) { openDropdown = .overflow
  }.dropdownAnchor(HeaderDropdown.overflow)` + identifier
  `moreActions.items` / `moreActions.wishlist`; the host's `.overflow`
  case → `OverflowDropdown(…)` with the four intents exactly as today's
  badge arguments. Tests: `ExportWiringTests.theBadgeIsFedByTheViewModel…`
  → `OverflowBadge(` ×1 with `isBusy: viewModel.isBusy`, `OverflowDropdown(`
  ×1 carrying `canExport: viewModel.canExport`, `viewModel.exportCSV()`,
  `viewModel.exportPDF()`, `isPickingImportFile = true`, `isShowingSettings
  = true`; `theMenuCarriesFiveItemsInThreeGroups` → scans
  `OverflowDropdown.swift` (five literals in order, `startsGroup: true` ×2
  on Import and Settings, `isEnabled: canExport` ×2, template absent).
  New `TroveTests/OverflowDropdownRenderTests.swift`: `OverflowDropdown`
  rendered on both `canExport` states through `renderBitmap`; sampled
  pixels assert the two group-break hairlines are perceptually farther
  from `surface` than a row separator (the Oklab helper's floor), the
  first row draws no top hairline, and a disabled row's title pixels match
  `textDisabled` not `textBody`. `DropdownWiringTests`:
  `.dropdownAnchor(HeaderDropdown.overflow)` once per list. UI tests: the
  badge queries in `testEmptyCollectionOffersImportAndSettingsButNotExport`
  and `testSettingsFromAnEmptyCollectionOffersTemplatesAndNothingElse`
  move to `moreActions.items`; everything else in them unchanged — they
  are the behavioral proof that bespoke rows publish as buttons with the
  right `isEnabled`. Mutations, **one at a time** (T014's lesson):
  `startsGroup` wired to nothing → render red; `hasTopHairline` ignored
  → render red; disabled color dropped → render red; the export rows'
  gate dropped → the fresh-install UI test red.
  *Done when*: unit target green with the count; **UI target green twice
  back to back**; the "…" on both lists opens the new dropdown by eye,
  group breaks visible, export rows dimmed under an empty search.

- [x] **T022 — The Dashboard's "…" and its Settings sheet.**
  *Done (2026-09-02)*: `DashboardView` — `header` is an
  `HStack(alignment: .top)` with the badge on the root alone (`if
  isRoot { overflowControl }`), the lists' pill (P8) anchored as
  `DashboardDropdown.overflow` with identifier `moreActions.dashboard`,
  never busy; `openDropdown: DashboardDropdown?` (`.overflow` only —
  `.order` joins at T023), `isShowingSettings`, the two storage
  environment values, the lists' byte-identical Settings sheet line
  after `.refreshable`, and the host last with the one-row
  `DropdownSurface { DropdownRow(title: "Settings") … }` (P13).
  `SettingsWiringTests`' sheet test now runs over three screens
  (`settingsHosts`); `DropdownWiringTests` gained the Dashboard scan —
  anchor once, gated in exactly one `if isRoot` span, the control's own
  body carrying the anchor and the open, one optional, one host
  composing the Settings row; the scan's first draft forbade any
  `Menu {` on the Dashboard and was red on the order control the plan
  converts at T023 — scoped to the host's body, where `MenuPolicyTests`
  takes over at T023. Two UI tests:
  `testDashboardOffersSettingsAndNothingElse` (empty state → badge →
  Settings alone, no Import, no Export → the sheet → Done → the badge
  hittable) and `testAnOpenMenuClosesOnAnyOutsideTapIncludingTheOtherBadge`
  (Decision 19: one item through quick-add so the sort badge exists;
  Sort By open → a coordinate tap on the "…" — captured before anything
  opens, since the badge sits under the tap-outside layer once a
  dropdown is up — closes Sort By and opens nothing; the next tap
  opens; "Dismiss more actions" closes). **Mutations, one at a time**:
  A, the badge gated behind `!viewModel.isEmpty` → the Dashboard UI
  test red ("No matches found for moreActions.dashboard"); B, the
  anchor moved out of the `isRoot` gate → the wiring scan red (zero
  gated spans carry the control); C, the tap-outside layer's close
  removed (`.onTapGesture { }`) → the switching test red, the overflow
  never opening past a Sort By that never closed. A and B hand-reverted
  (uncommitted work in those files); C via `git checkout` on the host,
  which carried none. Live: the root Dashboard shows the pill beside
  the wordmark on the 307-item store; its menu is the one Settings row
  at the gutter; Settings presents from it, the identical sheet; a
  category drill-down shows the back chevron and no badge. **UI target
  green twice back to back**: 9 tests, 0 failures, both runs (~107 s
  each — the quick-add path is the long one). Full unit target: **785
  tests in 115 suites passed** (784 + 1).
  Per addendum §Screens (Dashboard, badge half) and spec §The
  Dashboard's "…". `DashboardView`: `header` → `HStack(alignment: .top)
  { VStack(…); Spacer(); if isRoot { overflowControl } }`;
  `overflowControl` = `OverflowBadge(isBusy: false) { openDropdown =
  .overflow }.dropdownAnchor(DashboardDropdown.overflow)` + identifier
  `moreActions.dashboard`; `private enum DashboardDropdown: Hashable {
  case overflow; var dismissLabel }` (`.order` joins at T023); `@State
  openDropdown`, `@State isShowingSettings`, `@Environment(\.storageMode)`
  / `\.storageFallbackReason`; the lists' byte-identical Settings sheet
  line wrapping `SettingsView(` with all four init arguments; the host
  after `.refreshable` with `.overflow` → `DropdownSurface {
  DropdownRow(title: "Settings", hasTopHairline: false) {
  isShowingSettings = true } }`. Tests:
  `SettingsWiringTests.theListAttachesTheSettingsSheetAndReloadsOnDismiss`'s
  arguments gain `DashboardView.swift`; `DropdownWiringTests`:
  `.dropdownAnchor(DashboardDropdown.overflow)` inside the `if isRoot`
  brace span and nowhere else, `.dropdownHost(` once. New UI tests:
  `testDashboardOffersSettingsAndNothingElse` (Overview →
  `moreActions.dashboard` → "Settings" enabled, "Import from CSV…" absent
  → tap → `navigationBars["Settings"]` → Done → badge hittable) and
  `testAnOpenMenuClosesOnAnyOutsideTapIncludingTheOtherBadge` (add one
  item through the quick-add form so the sort badge shows; `sortOptions.items`
  → "SORT BY" exists; `moreActions.items` → "SORT BY" gone **and**
  "Import from CSV…" does not exist; `moreActions.items` again → it
  exists; "Dismiss more actions" → gone). Mutations, one at a time: the
  badge gated behind `!viewModel.isEmpty` → Dashboard UI test red; the
  anchor moved out of `if isRoot` → scan red; the overflow given its own
  boolean so both can be open → the switching test's first pair red.
  *Done when*: unit target green with the count; **UI target green twice
  back to back** (9 tests); the badge shows on the root Dashboard, empty
  and populated, and not on a drill-down, by eye.

- [x] **T023 — The Dashboard's order control, and the menu policy
  guard.**
  *Done (2026-09-02)*: `orderControl` is a `.plain` `Button` around the
  mock's mono label (P12 — no pill), anchored as `DashboardDropdown.order`
  with the existing "Order categories …" label, hint "Opens order
  options", identifier `orderOptions.dashboard`; the host's `.order`
  case composes `DropdownSurface(title: "ORDER BY")` with a
  `DropdownRow` per `BreakdownOrder`, the current one selected, choosing
  setting the order and reloading exactly as the `Menu` did. That was
  the app's last in-page system menu, so `MenuPolicyTests` lands here:
  a walk over every file under `Trove/Views` through
  `SourceScan.production`, a word-boundary match for `Menu {`/`Menu(`
  spelled as "start of text or a non-identifier character" — Swift's
  `Regex` has no lookbehind, the first draft's `(?<!…)` threw at
  runtime — plus `.pickerStyle(.menu)` and `.contextMenu`, allowlist
  exactly `DetailOverflowMenu.swift`, which must still host one (a
  stale allowlist fails too), more than ten files scanned.
  `DropdownWiringTests` gained the order scan: anchor once, the
  control's body opening `.order` with a `monoLabel` and no `Badge(`,
  the host's `.order` case composing the ORDER BY surface and the
  selected-row `DropdownRow` with the reorder-and-reload. **Mutations,
  one at a time**: A, a `Menu {` added to a page view → the policy red
  naming `Shared/AddButton.swift` — **on the second try**: the first
  appended the menu *after* the file's `#Preview`, where every
  `SourceScan` deliberately stops reading, and the guard stayed green
  for a reason that was the mutation's, not the guard's; recorded
  because a production `Menu` written after a preview would evade the
  scan the same way, an accepted edge of the instrument; B, `title:
  "ORDER BY"` dropped → the wiring scan red. Live: the root control
  opens the ORDER BY surface under its label at the gutter, By value
  tinted and checked; choosing By count closes it, reorders, and the
  label reads BY COUNT; on a drill-down the control opens under the
  visible nav bar. **The flip-above branch could not be provoked**: at
  fixed type sizes the control never sits within a dropdown's height of
  the tab bar on this screen (drill-down: 566 + 20 + 6 + 117 = 709 of a
  729-point region), so that branch rests on `DropdownPlacementTests`,
  stated here rather than claimed seen. Full unit target: **787 tests
  in 116 suites passed** (785 + 1 + 1).
  Per addendum §Screens (Dashboard, order half) and spec §What the
  Dashboard's order dropdown looks like. `orderControl` → a `.plain`
  `Button { openDropdown = .order }` around today's `monoLabel`, with
  `.contentShape(Rectangle())`, `.dropdownAnchor(DashboardDropdown.order)`,
  the existing "Order categories …" label and hint "Opens order
  options"; `DashboardDropdown` gains `.order` ("Dismiss order options");
  the host's `.order` case → `DropdownSurface(title: "ORDER BY") {
  ForEach(BreakdownOrder.allCases) { DropdownRow(title: $0.label,
  isSelected: $0 == viewModel.breakdownOrder) { viewModel.breakdownOrder
  = $0; viewModel.load() } } }`. The last in-page `Menu` is gone with
  this, so new `TroveTests/MenuPolicyTests.swift` lands here: over every
  file under `Trove/Views`, the word-boundary pattern
  `(?<![A-Za-z0-9_])Menu\s*[({]` plus `.pickerStyle(.menu)` and
  `.contextMenu`, allowlist exactly `DetailOverflowMenu.swift`, more than
  ten files scanned. `DropdownWiringTests`: `DropdownSurface(title:
  "ORDER BY")` and `.dropdownAnchor(DashboardDropdown.order)` in
  `DashboardView.swift`. Mutations: a `Menu {` added to a view → policy
  red, and `DetailOverflowMenu(` alone confirmed green; `title: "ORDER
  BY"` dropped → scan red.
  *Done when*: unit target green with the count; the order dropdown
  opens under its label at the top and after scrolling, and flips above
  when near the tab bar, by eye, on the root and on a drill-down.

- [x] **T024 — Docs: tokens, the brief's rule, and the three specs'
  notes.**
  *Done (2026-09-02)*: `design/tokens.md` — the Sort picker section
  reframed as the shared surface (header row SORT BY / ORDER BY / none
  on the "…" menus) with three rows added for the group break, the
  disabled row (the token *under* the button's measured 0.5 dimming,
  stated as measured, not designed) and the placement (`dropdownGap`,
  gutter, flip, no animation); the "Export badge and menu (`011`)"
  section's stale "hidden on an empty collection" sentence corrected to
  `012`'s always-visible rule, its Menu row rewritten as bespoke with
  the history and the page/bars rule, and rows added for the hint
  (Decision 18) and the Dashboard order control (P12) — plus the
  Dashboard's own pill (P8). `design/brief.md` — a new "Menus and
  chrome" section stating the rule, before Voice. `specs/011-data-
  export/plan.md` — a dated note under the original "system `Menu`"
  bullet: the fallback taken for homogenization, not a tear, the state
  machine now one shared host, the scans' new names; `spec.md` —
  criteria 1 and 2's two dead test citations replaced
  (`…FiresBothIntents` → `theBadgeOpensTheDropdownWhichFiresEveryIntentAndOpensSettings`,
  `bothMenuActionsGateOnCanExport` → `theMenuCarriesFiveItemsInThreeGroups`).
  `specs/012-data-import/spec.md` — the verification citation amended
  to the `OverflowDropdown.swift` scan. The grep the task asked for
  leaves exactly one "system `Menu`" outside the `013` files and the
  task histories: `011` plan.md's original decision sentence, kept as
  written with the supersession note directly beneath it — this repo
  records reversals, it doesn't rewrite shipped plans. `DocsSampleTests`
  green: 5 tests in 1 suite (count checked; the samples never named a
  menu).
  Per addendum §Docs. `design/tokens.md`: the "Export badge and menu
  (`011`)" table — the Menu row rewritten (bespoke, the Sort picker's
  surface, 013 Amendment A), the stale "hidden on an empty collection"
  sentence corrected, rows for the group break (`divider` hairline), the
  disabled row (`textDisabled`), the hint, and `dropdownGap`; the "Sort
  picker (`010`)" section reframed as the shared surface (header row
  SORT BY / ORDER BY, the first-row rule); a line for the Dashboard's
  badge and order dropdown. `design/brief.md`: a short new section —
  menus inside the page are Trove's own, chrome in the bars is the
  system's. `specs/011-data-export/plan.md` 320–328: the note that
  Amendment A takes the recorded fallback for homogenization, not
  because the border tore; `specs/011-data-export/spec.md` lines 152
  and 159: the dead test names replaced by
  `theBadgeIsFedByTheViewModelFiresEveryIntentAndOpensSettings` and
  `theMenuCarriesFiveItemsInThreeGroups`. `specs/012-data-import/spec.md`
  362–364: the citation amended to the `startsGroup`/`isEnabled` counts.
  *Done when*: every listed line changed; `DocsSampleTests` still green;
  no doc still calls the lists' "…" a system menu (grep).

- [x] **T024a — The dropdowns animate (spec Decision 20).**
  *Added and done (2026-09-02)*: raised by the person after T024's
  device look — the three dropdowns read as stiff beside the system
  menus they replaced — and decided as Decision 20; the flip anchor
  left to Claude Code. `DropdownHost`: the dropdown grows out of the
  badge — a `.scale(0.92)` anchored at `DropdownPlacement.growthAnchor`
  (the badge's trailing edge at its vertical centre, as a point of the
  region, so below and flipped-above alike need no flip knowledge)
  combined with `.opacity`; the fade alone under Reduce Motion; on
  `.snappy(duration: 0.25)` opening and `.easeOut(duration: 0.15)`
  closing, scoped to the overlay with `.animation(_:value: open)` and
  never `withAnimation` around a screen's write — the sort badge's
  label still snaps, and its border with it (T029c). The `.transaction
  { $0.animation = nil }` line is gone. **The first build didn't
  animate, and only a recording said so**: a `simctl` screen recording
  analysed frame by frame (`AVAssetImageGenerator` + `CIAreaAverage`
  over three strips of the dropdown's area — the T029c instrument)
  showed the open at one frame, +20 in a strip, and the close the
  same. The transition sat on a view *nested inside* the one the
  conditional inserts, with `.identity` on the inserted root, and a
  nested transition never runs. Restructured: the reader is always
  present (empty at rest, nothing to hit), the conditional's own root
  carries the transition, and the second recording shows the open as
  a ramp across six sampled frames and the close as a shorter one.
  `growthAnchor` table-tested (the gutter pill at 378/402; a badge
  scrolled off the top clamps to 0). The wiring scan now reads the
  modifier's body for the scoped animation and the inserted view for
  the transition, and still forbids `withAnimation`; mutation: the
  `.animation` line dropped → red. Spec: Decision 20, the shared-
  behavior bullet, criterion 24's "unchanged to the eye" → "drawing
  unchanged; animates as every in-page dropdown does"; tokens.md's
  placement row; the plan addendum's "no animation" line superseded.
  Full unit target: **788 tests in 116 suites passed** (787 + 1; the
  ~100 s environmental stall hit twice, 206 s). UI target: 9 tests, 0
  failures — the 150 ms close sits well inside the tests' waits.

- [x] **T025 — Device pass, criteria 20–27, close-out.**
  *Done (2026-09-02)*: criteria 20–27 checked off with a per-criterion
  verification record in spec.md, two honest partials stated (23's
  spinner not re-exercised live, a synchronous export being
  unobservable by screenshot; 26's focus, escape, `.isModal` and dimmed
  announcement composed and scanned but not exercised — no VoiceOver
  from here). Live at this pass: two-tap switching by hand on Items;
  Delete All's reflection on the **`-uiTesting` store only** — one
  item added, Settings › Delete All Items… → "Delete your only item?"
  → Delete All → Done → "0 ITEMS", "Nothing tracked yet", the badge
  still there; the empty-state badge; the root Dashboard scrolling and
  pulling to refresh under the always-present reader. The plan
  addendum gained its "As built" section (focus via the row under a
  switch; the reader inside the safe area with a region and no insets;
  `hasTopHairline` gone; the disabled compound; no `title:` on
  `SortDropdown`; the animation; the unreachable flip; the identifiers;
  the toolchain facts) with inline pointers at the four superseded
  lines. **The pre-merge skeptical sweep found three blockers and nine
  second-looks, all acted on**: B1, the badge hints were claimed
  scanned and weren't → `everyBadgeCarriesItsHintAndIdentifier` reads
  all three hints and all six identifiers from the controls' bodies
  (mutation: a hint dropped → red); B2, the rewritten pill's body was
  scanned by nothing → `theBadgeShowsTheSpinnerAndDisablesWhileBusy`
  (mutation: `.disabled(isBusy)` dropped → red) and criterion 23's
  record reworded; B3, 013's own T017 record cited the sheet test by
  its old name → corrected; S1, the injection scan now asserts the
  dismiss action is attached directly to the dropdown content, not
  merely present; S2, `MenuPolicyTests` walks `Trove/App` too; S3, the
  catcher moved from "not exercised" to exercised (the switching UI
  test taps it) and `orderOptions.dashboard` joined the plan's
  identifiers; S4, the focus switch's default is asserted on
  (mutation: flipped → red); S5, four stale doc comments fixed and the
  three screens' docs re-attached to their structs; S6, the spec's
  header caught up with Decision 20 and the verified state; S7, "the
  app's snappy spring" reworded (0.25 s against the app's 0.2 s idiom)
  and the host's numbers pinned by scan; S8, the scroll check above;
  S9, Decision 15's roadmap claim moved to the post-merge list, which
  gained the sweep's full list. **Full suite at close: unit target
  790 tests in 116 suites passed; UI target 9 tests, 0 failures, twice back to back.** Status flipped
  to Complete; PR #9 marked ready for review.
  Per addendum §Verification. On the simulator: both lists' dropdowns
  at both badges against the pre-T020 placement (a screenshot of
  `99747d5`'s Sort By beside today's), group breaks, disabled rows via
  an empty search; the Dashboard badge at root, empty and populated,
  absent on a drill-down; the order dropdown at scroll offsets and under
  a drill-down's nav bar, the flip near the tab bar with T020's probe
  numbers in hand; two-tap switching; Settings from the Dashboard, and
  Delete All's reflection on the Dashboard **on the `-uiTesting` store
  only**. Accessibility Inspector on the badges' labels, hints and
  identifiers, the rows' dimmed state, the catchers' labels; VoiceOver
  focus-on-open, escape and `.isModal` containment by hand, recorded as
  such. Then: criteria 20–27 checked off with a per-criterion
  verification record in spec.md, honest partials stated; the addendum
  amended in place where as-built differs (the probe numbers above all);
  the skeptical-reviewer's pre-merge sweep over the amendment's
  spec/plan/tasks and the docs; full suite (unit + UI twice) with the
  actual output; this file flipped to Complete and PR #9 marked ready
  for review.
  *Done when*: all eight criteria dispositioned, findings recorded,
  status flipped.

---

After T025: PR #9 leaves draft and merges; then the repo-wide docs
catch-up on a `fix/` branch per `DECISIONS.md`'s git routing — the
ROADMAP lines the plan names (221–223, the badge "so a fresh install
can reach Import and Get Blank Template"; 261–265, the entry point
"open design question", now decided twice over — the lists' menu and
the Dashboard's — and "four always-visible actions", now five), the
status rows, the README status, tree, **and Features list** (no entry
yet for Settings, export-everything, the iCloud row or Delete All),
and a `README.md` line in `DECISIONS.md`'s git-routing entry.
Amendment A adds (the T025 sweep's list): `ROADMAP.md`'s status table
has no row at all for `013`; its "Dashboard export" (~176–180) and
"Full export" (~199–205) entries still read as though the Dashboard
has no entry point to hang an export on — it has one now; the
submenu-restructuring deferral (spec Decision 15) needs its roadmap
entry; `README.md`'s tree lacks `Views/Settings/` and its specs
listing lacks `012` and `013`, and nothing there describes the
"…"/bespoke-menu surface; and `DECISIONS.md`'s routing entry names
neither `design/` nor `docs/`, both edited on this branch — fix all
three buckets, not `README.md` alone.

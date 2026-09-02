# 013 — Settings Menu: Tasks

Status: **Approved** (2026-09-01, same day as drafting) — Phase 1 in
progress

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

- [ ] **T013 — The entry point: badge, sheets, and the template's
  departure.**
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

- [ ] **T014 — UI tests: the fresh install reaches Settings.**
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

- [ ] **T015 — Docs and supersession notes.**
  Per plan §Docs and notes. `docs/csv-reference.md` lines 6–7 and
  132 (Settings → Templates); `README.md` line 39;
  `specs/012-data-import/spec.md`: superseded-in-part notes in the
  011 form on criterion 1, the entry-point "Get Blank Template…"
  bullet, the "Template and reference docs" section, and Decision 8;
  `specs/011-data-export/spec.md` 142–146: a one-clause addendum.
  Cross-check that T001's 011 `plan.md` delivery-section edit landed.
  *Done when*: every listed line changed; `DocsSampleTests` still
  green (the samples never mention the template's home).

- [ ] **T016 — Full verification and manual device pass.**
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

- [ ] **T017 — Close-out review.**
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

---

After T017: PR #9 leaves draft and merges; then the repo-wide docs
catch-up on a `fix/` branch per `DECISIONS.md`'s git routing — the
ROADMAP lines the plan names (221–223, the badge "so a fresh install
can reach Import and Get Blank Template"; 261–265, the entry point
"open design question", now decided), the status rows, and the README
status and tree.

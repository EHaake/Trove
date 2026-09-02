# 013 — Settings Menu — Technical Plan

Status: **Approved** (2026-09-01, same day as drafting; drafted
in-session per the authorship split. One copy correction at review —
the singular Delete All title — recorded under Copy.)
**Amendment A addendum: Approved** (2026-09-02, same day as drafting)
— the final section, "Amendment A — the Dashboard "…" and bespoke
in-page menus".

Grounded in the shipped 011 export module, 012's import surface, and
the view/VM code as it is on this branch — file references below are
to what exists today. The `skeptical-reviewer` subagent ran on seven
foundational calls before this document was written; its record is
first because it reshaped four of them, corrected two claims this
plan would otherwise have carried as fact, and surfaced two spec-level
contradictions that were escalated and decided by the person (spec.md
Decisions 13–14).

## Skeptical-review record

- **Sustained**: the additive pair-level `exportFiles` requirement on
  `ExportService`; `StagedExport` growing `urls`/`filenames` while
  keeping its single-file initializer; per-object deletion in the
  context with one save and a rollback (for a reason the review
  corrected — see The delete-all commit path); removing
  `exportBlankTemplate()` from both list view models rather than
  leaving an unreachable intent.
- **Overturned or reshaped**:
  - *The custom-order extraction* as first proposed — a `static` on
    each list VM restating `sortOrder <` — duplicated the rule
    `ManualOrderHelper` exists to hold once, and its byte-identity test
    could not fail: after the extraction both sides of the equality
    called the same function, so mutating it moved both outputs
    together. Moved to `ManualOrderHelper`; the test asserts an
    independently written expected order (see Custom order).
  - *Reading `SyncMonitor` from the environment inside the sheet* had
    no precedent (`ContentView` is the app's only
    `@Environment(SyncMonitor.self)` reader and constructor-injects it
    everywhere) and a failure mode — a runtime trap, or a silently
    stale row — nothing automated could catch. Constructor-injected,
    like every other screen.
  - *The `.ephemeral` status copy* stated an iCloud fallback that never
    happened (the UI-test store never attempts iCloud, and its recorded
    reason is nil) — and the plan's own new UI test would have rendered
    it. Reworded (see The iCloud row).
  - *"The yield guarantees the spinner frame"* restated 012's finding
    backwards: 012 recorded the commit spinner as *unobservable* at
    ~85 ms, not verified. The real risk is the main-thread block
    behind it. The plan now attaches a measured threshold and a named
    fallback (see The delete-all commit path).
  - *The reworded `ImportCopy` string* would have shipped "Nothing was
    imported." twice — the function appends the sentence itself — past
    a green `hasSuffix` test. Body only, and the new guard is a
    full-string equality.
  - *Staging both PDFs as `Data` before writing* would have doubled
    011's peak memory; the purge is now separated from the writes so
    each document renders just before its own write.
- **Escalated and decided** (both by the person, 2026-09-01): the
  delete alerts' iCloud sentence branches on storage mode (spec
  Decision 13 — the draft's "true in every storage state" was false
  in the local-only fallback); the abandoned-export sentence is
  corrected to 011's purge rule (Decision 14 — "nothing is left
  staged" was unachievable without a cancellation path no other screen
  has). Applied to spec.md in the same commit as this draft.
- **Corrections to my own claims, recorded so they don't recur**: the
  reason to avoid `ModelContext.delete(model:where:)` is *not* that it
  bypasses delete rules (contested) but that it commits outside the
  `save()`/`rollback()` envelope all-or-nothing needs; and
  `ButtonRole.destructive` is not documented to announce anything to
  VoiceOver outside alerts and menus, so criterion 18 is met with an
  explicit hint, not assumed from the role.

## Grounding

Load-bearing facts from the branch, each checked rather than recalled:

- `FileExportService.stage` (`Trove/Export/ExportService.swift`)
  purges the **whole staging directory** before every write, and
  `ExportTempFileTests.aSecondExportLeavesExactlyOneFileSet` pins it.
  Two sequential single-file exports leave one file. A two-file share
  sheet therefore needs a service requirement that purges once.
- `PDFComposer.render` already produces a valid one-page cover-only
  document for zero entries (`PDFComposerTests.rendersAValidOnePageCoverOnlyPDF`)
  — criterion 7's empty-collection half needs no composer change.
- Custom order is an in-memory sort: `load()` fetches unsorted and
  sorts with a private `isOrderedBefore` whose tie-breaks differ per
  entity (items: `createdAt` then `id`; wishlist: case-insensitive
  name then `id`). No `FetchDescriptor` reproduces it.
- `TroveStore.cloudKitFailure` is read by nothing in `Trove/`; the
  only reader is a test asserting it isn't thrown away.
- `DeletionGuardTests.noViewDeletesFromTheStoreDirectly` scans every
  file under `Trove/Views` for `modelContext.delete(`; the bulk delete
  must be a view-model intent, and that guard then covers the new
  view for free.
- Nothing asserts on the import alert's "Get Blank Template… in the …
  menu" sentence; `ImportCopyTests` checks only the universal suffix
  and the wrong-list branch.
- `ContentView` reads `SyncMonitor` from the environment exactly once
  and constructor-injects it into all three screens; the form sheets
  read `EnvironmentValues` keys (`storageMode`) but no presented sheet
  reads an `@Observable` object from the environment.
- `Trove/` is a `PBXFileSystemSynchronizedRootGroup`: new files need
  no project-file edit.

## Layout and files

- **New**: `Trove/ViewModels/SettingsViewModel.swift`;
  `Trove/Views/Settings/SettingsView.swift` (the screen and its two
  row components); `Trove/Views/Shared/StorageEnvironment.swift` (the
  new `@Entry` — named for what it holds; `storageMode` stays in
  `SaveCaption.swift`); `Trove/Models/DeleteAllCopy.swift`,
  `SyncStatusCopy.swift`, `AppVersion.swift`. Tests:
  `SettingsViewModelTests`, `SettingsWiringTests`,
  `SyncStatusCopyTests`, `DeleteAllCopyTests`, `AppVersionTests`, one
  new `TroveUITests` case.
- **Modified**: `ExportService.swift`, `ShareSheet.swift`,
  `ManualOrderHelper.swift`, `OverflowBadge.swift`, `ItemListView.swift`,
  `WishlistView.swift`, `ItemListViewModel.swift`,
  `WishlistViewModel.swift`, `TroveApp.swift`, `ImportService.swift`,
  `TestSupport.swift`, `ExportWiringTests`, `ExportTempFileTests`,
  `ExportConcurrencyTests`, `ManualOrderHelperTests`,
  `ImportServiceTests`, both list-VM test files (template suites move
  out), `WishlistDeletionTests` (the shared-copy guard grows a third
  route), `TroveUITests`, `docs/csv-reference.md`, `README.md`,
  `specs/012-data-import/spec.md`, `specs/011-data-export/spec.md`
  and `plan.md`.

## Export service: the pair-level requirement

```swift
nonisolated enum ExportFile: Sendable {
    case csv(CSVTable, filename: String)
    case pdf(PDFDocumentModel, filename: String)
}

// Added to ExportService. The two existing requirements stay exactly
// as they are — 011's single-file paths and tests are untouched.
@concurrent func exportFiles(_ files: [ExportFile]) async throws -> [URL]
```

- `FileExportService.exportFiles`: fire the generation probe once, then
  for each file in order: render → (before the **first** write only)
  `prepareStagingDirectory()` → `write(_:filename:)` → next. Each PDF
  renders just before its own write, so 011's one-document-in-memory
  profile holds for a set. *As built (T001, restated at T017 after the
  sweep):* the purge sits just before the first write rather than
  before the first render, so a first-file render that throws leaves
  the previous set intact — the single-file path's behavior. A
  later-file render throwing would leave the new set partially staged;
  accepted rather than tested, because `PDFComposer.render` throws only
  when no graphics context can be made at all, and rendering the whole
  set first would double peak memory. One `PhotoFetcher` is shared across
  the set: its context rotation is per 25 *fetches*, not per document,
  so the ≤25-photos bound is unchanged. Returns URLs in input order.
- The existing `stage(_:filename:)` becomes prepare + one write — a
  single purge implementation. 011's invariant reads, from here on,
  "purged before every export **set**": restated in `FileExportService`'s
  doc comment and in 011 `plan.md`'s "Delivery and temp-file
  lifecycle" section, both of which state the per-export form today.
  `aSecondExportLeavesExactlyOneFileSet` still holds as written (two
  separate calls, two purges).
- `@concurrent` on the requirement **and** the implementation — the
  SE-0461 pair per 012's corrected matrix; `ExportConcurrencyTests`
  grows a third call through the `any ExportService` existential.
- Both spies in `TestSupport.swift` conform directly, so both gain
  `exportFiles` in the same change: `ExportServiceSpy` records the
  `files` and appends each table/document/filename in order (the
  ordered `filenames` array already lets a pair be asserted as
  `["Trove-Items-….csv", "Trove-Wishlist-….csv"]`);
  `GatedExportServiceSpy` gates the first `exportFiles` call the way it
  gates the first `exportCSV`, never a later one, so a leaked reentrant
  call fails as a count rather than a deadlock.
- **`StagedExport` becomes a set**: `urls: [URL]`, `filenames:
  [String]`, `init(urls:filenames:)`, keeping `init(url:filename:)` so
  neither list VM changes. The single-file accessors go — `filename`
  has zero production readers; four test assertions become
  `filenames == [...]`, and the two views' `ShareSheet(url: staged.url)`
  become `ShareSheet(urls: staged.urls)`. `ShareSheet` takes `urls`
  and passes them as `activityItems`; UIKit stays confined to that one
  file and `ExportWiringTests.uiKitStaysInsideTheFlaggedExceptions`
  covers `SettingsView` automatically. The literal
  `.sheet(item: $viewModel.stagedExport)` that
  `theShareSheetAndFailureAlertAreWired` pins is unchanged.

## Custom order and totals

Export-everything follows no view, so it needs an order rule: Custom
(spec P3). The comparator lives in private VM code today. It moves to
**`ManualOrderHelper`** — the type whose doc comment promises manual-
order logic "lives once, here, rather than twice in two view models
that could quietly drift apart":

```swift
extension ManualOrderHelper {
    /// The user's own order, fully determined: manual position first,
    /// the entity's tie-break where positions collide (a pre-`010`
    /// store, every legacy row at 0).
    static func areInCustomOrder<T: ManuallyOrdered>(
        _ lhs: T, _ rhs: T, tieBreak: (T, T) -> Bool
    ) -> Bool {
        lhs.sortOrder != rhs.sortOrder ? lhs.sortOrder < rhs.sortOrder : tieBreak(lhs, rhs)
    }

    /// Items: creation order, then id — the order the removed backfill
    /// used to write (T039 close-out). The history comment moves here.
    static func areInCustomOrder(_ lhs: Item, _ rhs: Item) -> Bool
    /// Wishlist: case-insensitive name, then id.
    static func areInCustomOrder(_ lhs: WishlistItem, _ rhs: WishlistItem) -> Bool
}
```

Each list VM's `isOrderedBefore` becomes
`attributeOrder(lhs, rhs) ?? ManualOrderHelper.areInCustomOrder(lhs, rhs)`.
Behavior-preserving for every `SortOrder` case — attribute decides →
attribute; else position; else the entity tail — the same three steps
in the same order as today's body. For `.custom` the attribute
abstains, so the list literally sorts with the function Settings
sorts with. `areInOrder(primary:)` stays, with its tests. Rejected:
building list view models inside the Settings view model to borrow
their sort (heavy, constructs live services, no precedent for a VM
owning VMs); a `FetchDescriptor(sortBy:)` (can't express the
localized name compare or the `uuidString` tail, and would silently
diverge on exactly the ties that matter).

**The guard (the review's B1).** The tie fixture — several rows at the
same `sortOrder` with distinct `createdAt`/names — asserts an
**independently written expected order** (explicit names) against the
Settings VM's CSV rows. The equality with the list VM's `.custom`
table is a second assertion, not the guard, because after the
extraction both sides share the function. Red-run: replace the
Settings sort with `FetchDescriptor(sortBy: [SortDescriptor(\.sortOrder)])`
— the explicit expectation goes red. (Dropping the tail from the
helper reddens the list VMs' sort tests too; that's real, shared
coverage.)

Cover totals — `totalPaidCents`, `totalCurrentValueCents`,
`unvaluedCount`, `totalEstimatedCostCents` — are one-line reductions in
the list VMs; Settings computes them over its own fetched arrays with
the same expressions, and a test pins Settings' covers equal to the
list VMs' unfiltered covers in everything but `generatedAt`. Coverage
labels and titles are **shared constants, not repeated literals** (as
built at T009): `ItemListViewModel.documentTitle` / `wholeCoverageLabel`
and the `WishlistViewModel` pair, read by each list's own export and by
Settings, so byte-identity can't drift on a string; filenames from
`ExportFilename.items/wishlist(fileExtension:)`. Criterion 5's
byte-identity is by construction — `CategoryPathHelper.path(_:isWithin: "")`
and `SearchMatching.matches(query: "")` both admit everything, and the
comparator is a strict total order down to `id` — and proven against
the fixture.

## `SettingsViewModel` — owns everything the view shows

`@Observable`, `Foundation` and `SwiftData` only.

```swift
init(
    modelContext: ModelContext,
    syncMonitor: SyncMonitor = .notSyncing,
    storageMode: StorageMode = .cloudKit,
    storageFallbackReason: String? = nil,
    exportService: (any ExportService)? = nil,   // FileExportService(container:) — the lists' shape
    appVersion: AppVersion = .current
)
```

The presenting list views read `@Environment(\.storageMode)` and the
new `@Environment(\.storageFallbackReason)`, and — like `ContentView` —
constructor-inject `syncMonitor` (each list view stores it in a
`private let`, as `DashboardView` does today; the list VMs already
receive it). No `@Environment(SyncMonitor.self)` inside the sheet: the
app has one delivery mechanism for that object, and this keeps it.

- **State**: `private(set) var itemCount`, `wishlistCount`
  (`fetchCount`, refreshed by `load()` on appear and after every
  action); `private(set) var activity: Activity?` — `enum Activity {
  exportCSV, exportPDF, itemsTemplate, wishlistTemplate, deleteItems,
  deleteWishlist }`, one optional so the acting row can show the
  spinner and `var isBusy: Bool { activity != nil }` gates everything;
  `var stagedExport: StagedExport?` (view-settable, the sheet
  convention); `var alert: SettingsAlert?` — `enum SettingsAlert:
  Equatable { confirmDelete(DeleteTarget, count: Int), deleteFailed,
  exportFailed }`, **one** alert modifier off one optional (012's
  lesson: independent booleans that can go true together are how
  SwiftUI drops an alert).
- **Derived**, following 012's `importAlertTitle` precedent so the copy
  path stays testable without UI: `alertTitle`, `alertMessage`
  (compose `DeleteAllCopy` with `storageMode`, or `ExportCopy`);
  `syncStatus: SyncStatus` (`SyncStatusCopy.status(mode:phase:
  syncMonitor.phase, fallbackReason:)` — live, because the monitor is
  `@Observable` and the getter reads it); `versionLine`;
  `canExportEverything` (either count > 0), `canDeleteItems`,
  `canDeleteWishlist`.
- **Intents**:
  - `exportEverythingAsCSV() async` / `exportEverythingAsPDF() async`
    — guard `canExportEverything, !isBusy`; fetch all of both
    entities; sort with `areInCustomOrder`; build both tables (or both
    documents) with the strings above; one `exportFiles` call →
    `stagedExport`; a throw → `.exportFailed`.
  - `exportItemsTemplate() async` / `exportWishlistTemplate() async` —
    012's `exportBlankTemplate` bodies relocated: guard `!isBusy` only,
    `exportFiles([.csv(CSVTable(headers:…, rows: []), filename:
    ExportFilename.itemsTemplate)])`. Same bytes, same names.
  - `requestDeleteAll(_ target: DeleteTarget)` — re-counts at request
    time, so the alert title carries the *current* count rather than
    the on-appear one; stages `.confirmDelete(target, count:)`.
  - `confirmDeleteAll(_ target: DeleteTarget) -> Task<Void, Never>?` —
    the commit path below. **Target is a parameter**, handed in by the
    alert's `presenting` closure, never re-read from `alert` — the
    review's S4: re-reading mutable state the dismissal write races is
    the coupling T017 was about.
  - `cancelDeleteAll()` — clears the alert. Nothing written.
- Both list VMs lose `exportBlankTemplate()` and the `isBusy` case it
  contributed nothing new to; their template suites
  (`ItemListViewModelTemplateTests`, `WishlistViewModelTemplateTests`)
  move to `SettingsViewModelTests` with their assertions intact.

## The delete-all commit path

The T017 shape, because the confirm button lives in an alert whose
`isPresented` binding writes the presentation nil on any tap:
**synchronous capture, async commit.**

```swift
@discardableResult
func confirmDeleteAll(_ target: DeleteTarget) -> Task<Void, Never>? {
    guard !isBusy else { return nil }
    alert = nil
    activity = target == .items ? .deleteItems : .deleteWishlist
    return Task { @MainActor in
        defer { activity = nil; load() }
        // Lets the presentation write land before the work — ordering
        // hygiene, not a promise of a rendered frame (see below).
        await Task.yield()
        do {
            switch target {
            case .items:
                for item in try modelContext.fetch(FetchDescriptor<Item>()) { modelContext.delete(item) }
            case .wishlist:
                for item in try modelContext.fetch(FetchDescriptor<WishlistItem>()) { modelContext.delete(item) }
            }
            try modelContext.save()
        } catch {
            // Without this, load() on the same context would show the
            // phantom deletion — the import commit's finding, reversed.
            modelContext.rollback()
            alert = .deleteFailed
        }
    }
}
```

- **Per-object `delete` in the context, one `save`, `rollback` on a
  throw.** The reason is the save/rollback envelope:
  `ModelContext.delete(model:where:)` commits outside it, so all-or-
  nothing (criterion 13) is unexpressible with it. (The draft's other
  reason — that batch delete bypasses delete rules — is contested and
  not the point; recorded in the review record.) Photos cascade and
  sell plans nullify by the schema's rules, exactly as the single
  deletes in both list VMs already do; nothing is unlinked by hand.
  Several hundred per-object deletes in one save are nothing CloudKit
  minds — the mirror batches its own records.
- **Honest about the frame.** 012 recorded its commit spinner as
  unobservable at ~85 ms; it never verified that the yield produces a
  frame, and this plan doesn't claim it. What matters here is the
  block *after* the yield: fetch, N deletes each cascading to a
  `Photo` row, one save — all on the main actor, during which the
  spinner can't animate and a Done tap queues. So the walking-skeleton
  task **measures** Delete All on a ~300-item store with photos, and
  the measurement carries a decision:
  - **≤ 250 ms → ship on the main actor.** A queued tap during a
    quarter second is criterion 14 in practice.
  - **> 250 ms → the loop moves to a background `ModelContext` over
    the container**: fetch, delete, save off-main inside one
    `@concurrent` body — still one save, still all-or-nothing, still
    a rollback on throw — with `load()` on the main actor afterwards.
    (`PhotoFetcher` already establishes the fresh-context-off-the-
    container pattern.)
  - **No chunking either way**: chunks break all-or-nothing.
  **Measured at T011 (2026-09-01)**: 300 items, each carrying a 50 KB
  photo, on an in-memory container — **~150 ms** on the main actor
  (0.153 s, 0.151 s across isolated runs; phases: fetch 17 ms, the
  delete loop 3 ms, `save()` 102 ms; ~32 ms in total without photos).
  Under the threshold, so **the main-actor branch shipped**; the
  background-context fallback stays documented, not built. Two things
  the measurement taught: Swift Testing runs suites in parallel, so a
  timing probe inside the whole unit target read 5.4 s — measure in
  isolation; and one isolated run stalled for ~100 s, matching ~100 s
  outliers seen in two Phase 1 full-suite runs before any delete code
  existed — attributed to the test host's real CloudKit container on a
  signed-out simulator, and carried to T016's device pass as a thing
  to watch rather than a thing explained.
- **Refresh**: the presenting list's `.sheet(isPresented:onDismiss:
  viewModel.load)` — the form-sheet precedent; the Dashboard and the
  other list reload on appear; sell plans on their own appear
  (`SellPlanViewModel` reads `plannedSaleItems ?? []`, so a nullified
  plan is simply empty). Settings' own counts reload in the `defer`,
  which disables the row.

## The iCloud row

`SyncStatusCopy.status(mode: StorageMode, phase: SyncPhase,
fallbackReason: String?) -> SyncStatus { headline, detail }` — pure,
Foundation-only, in `Trove/Models/`. The view model exposes it as
`syncStatus`; the view renders two lines and combines them into one
accessibility element. Copy:

| Mode | Phase | Headline | Detail |
|---|---|---|---|
| `.cloudKit` | `.caughtUp` | Syncing with iCloud | This device has your collection. |
| `.cloudKit` | `.unknown`, `.working` | Catching up with iCloud | Your collection is on its way to this device. |
| `.cloudKit` | `.unavailable` | iCloud isn't available | No iCloud account is signed in, or iCloud can't be reached. Your collection stays on this device. |
| `.localOnly`, `.ephemeral` | any | On this device only | With a recorded reason: "iCloud couldn't be set up when Trove launched: *reason*". Without one: "Nothing syncs from here." |

"Catching up with iCloud" is the empty states' headline verbatim, so
the two surfaces describe the same condition in the same words. The
`.unavailable` row cannot tell signed-out from unreachable and says
so (spec §iCloud). The local-only detail depends on *whether* a reason
was recorded, not on the mode: `.localOnly` always has one
(`TroveStore.make` sets `cloudKitFailure` on the fallback); `.ephemeral`
never does, because iCloud was never attempted — the review's B4, the
state the new UI test actually renders. Pinned by a **full-string
table** over every (mode, phase, reason) cell, including a nil reason
and a long one; that table is criterion 10's guard (no state's text
claims other devices have the collection), not a substring check.

`@Entry var storageFallbackReason: String? = nil` lives in
`Trove/Views/Shared/StorageEnvironment.swift`; `TroveApp` injects
`store.cloudKitFailure?.localizedDescription` — the first reader that
value has had since 001. A wiring scan pins the forwarding.
`SettingsView` lays the detail out with
`.fixedSize(horizontal: false, vertical: true)` so a long
developer-facing reason wraps rather than truncates.

## About

`AppVersion { version: String, build: String }` with
`init(info: [String: Any])` reading `CFBundleShortVersionString` and
`CFBundleVersion` (`"?"` when absent) and `static var current` from
`Bundle.main.infoDictionary` — the app's first bundle read. Unit-tested
on the dictionary; a scan pins that neither Settings file carries a
version literal (criterion 17's "never typed").

## Copy

- **`DeleteAllCopy`** (`Trove/Models/`, the `ItemDeleteCopy` shape,
  pinned by `DeleteAllCopyTests`):
  - `title(count:target:)` → "Delete all 309 items?" / "Delete all 12
    wishlist items?". **The singular reads "Delete your only item?" /
    "Delete your only wishlist item?"** — decided by the person at plan
    review (2026-09-01): the draft's "Delete all 1 item?" was exact by
    the spec's letter and not how anyone says it. `DeleteAllCopyTests`
    pins both forms.
  - `message(for target:, count:, mode:)` — *as built at T004, count-
    aware as well as mode-aware*: a list of one reads with the
    single-item alerts' own sentences ("Its photos go too. Any sell plan
    it's on drops it."), extending the person's singular-title
    correction; the plural forms are — items: "Their photos go too. Every
    sell plan loses its items. [iCloud] This can't be undone.";
    wishlist: "Their photos go too. Their sell plans go with them; the
    gear on those plans stays. [iCloud] This can't be undone."; where
    [iCloud] = "If you're signed in to iCloud, they're removed from
    your other devices as well." **for `.cloudKit` only** (Decision
    13) and nothing for `.localOnly`/`.ephemeral`.
  - `confirm = "Delete All"`, `cancel = "Keep"`; `footer = "Export first
    if you want a copy."`; `failureTitle = "Couldn't delete"`,
    `failureMessage = "Deleting failed. Nothing was deleted."`.
  - `DeletionGuardTests`' shared-copy guard grows the third route:
    `SettingsViewModel.swift` must read `DeleteAllCopy`.
  - The singular sentences are shared with `ItemDeleteCopy` /
    `WishlistDeleteCopy` **by pin, not by construction** (T017, after
    the sweep's S6): in a local-only mode a list of one is the
    single-item alert word for word, and `DeleteAllCopyTests` asserts
    equality with both constants — so rewording either single-item
    alert turns red here. Composing the strings from those constants was
    rejected because they end in the undo sentence that Delete All has
    to place *after* its iCloud sentence.
- **`ImportCopy`** `.headerMismatch(wrongList: false)` body → "The
  columns don't match the \(noun) template. A blank template with the
  expected layout is in Settings › Templates." — **body only**: the
  function appends "Nothing was imported." itself (the review's B6;
  the draft's string would have doubled it past the suffix test). The
  new guard in `ImportCopyTests` is a **full-string equality** for
  both targets.

## Entry point and the Settings sheet

*Superseded in part by Amendment A (final section, 2026-09-02): the
"…" is no longer a system `Menu` — its rows moved to
`OverflowDropdown` on the Sort By surface, and the root Dashboard has
its own "…". The rows, their order and their gating are as below.*

- **`OverflowBadge`**: `getTemplate` → `openSettings`. Menu: Export as
  CSV… / Export as PDF… (each `.disabled(!canExport)`) / `Divider()` /
  Import from CSV… / `Divider()` / **Settings** — no ellipsis (it opens
  a screen, not a flow needing input). Doc comment and previews follow.
- **Both list views**: `@State private var isShowingSettings = false`;
  `openSettings: { isShowingSettings = true }`;
  `.sheet(isPresented: $isShowingSettings, onDismiss: viewModel.load) {
  NavigationStack { SettingsView(modelContext:, syncMonitor:,
  storageMode:, storageFallbackReason:) } }`. Each view gains
  `@Environment(\.storageMode)` / `@Environment(\.storageFallbackReason)`
  and a stored `syncMonitor`.
- **`SettingsView`**: the form sheets' chrome — outermost
  `ZStack { theme.colors.background.ignoresSafeArea(); ScrollView {
  VStack(spacing: sectionGap) { … } } }`, `.navigationTitle("Settings")`,
  `.navigationBarTitleDisplayMode(.inline)`, one
  `ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }`
  that is **never disabled** (P4). Five `DetailSection`s in spec
  order: Export, Templates, iCloud, Delete, About.
  - `SettingsActionRow(title:isBusy:isEnabled:isDestructive:action:)`
    — a `Button` row: brass text, `accentRustText` when destructive,
    `textDisabled` when disabled, `DetailRow`'s hairline beneath, a
    trailing `ProgressView().controlSize(.small).tint(accentBrass)`
    while it is the acting row; `.buttonStyle(.plain)`. Destructive
    rows carry `role: .destructive` **and an explicit
    `.accessibilityHint`** ("Permanently deletes every item in your
    library." / "…every item on your wishlist.") — the role alone is
    not documented to announce anything outside alerts and menus, so
    criterion 18 is met explicitly and checked with VoiceOver at the
    device pass.
  - iCloud: headline in `theme.typography.body` / `textPrimary`,
    detail in `theme.typography.secondary` / `textQuiet` (typography
    tokens — never `.secondary`, which `NoHardcodedColorsTests`
    forbids), `.accessibilityElement(children: .combine)`.
  - Delete footer: `DeleteAllCopy.footer` in `secondary` / `textQuiet`.
    About: *as built, a block rather than `DetailRow`s* — name in
    `body`/`textPrimary`, the subtitle in `secondary`/`textQuiet`, and
    the version line in `monoMeta`/`textMonoMeta` ("Version 1.0 (1)"),
    since a "Version | Version 1.0 (1)" row would say the word twice.
  - `.sheet(item: $viewModel.stagedExport) { ShareSheet(urls:
    $0.urls).presentationDetents([.medium, .large]) }` — presents over
    Settings, returns to it.
  - **One** `.alert(viewModel.alertTitle, isPresented: …, presenting:
    viewModel.alert)`, switching on the case: `.confirmDelete(target,
    _)` → `Button(DeleteAllCopy.confirm, role: .destructive) {
    viewModel.confirmDeleteAll(target) }` (a plain call — no `Task`
    wrapper, scan-guarded, the T017 rule) and `Button(DeleteAllCopy.cancel,
    role: .cancel) { viewModel.cancelDeleteAll() }`; the two failures →
    OK. Message from `viewModel.alertMessage`.
  - No `modelContext.delete(` in the view — the existing guard.
- **Abandoned export** (Decision 14): dismissing mid-export drops the
  sheet's state with the view; the generated file lands in staging and
  011's next-export/launch purge clears it. No cancellation path.

## Docs and notes

- `docs/csv-reference.md` lines 6–7 and 132: the template is now
  "Settings → Templates"; `README.md` line 39 likewise.
- `specs/012-data-import/spec.md`: superseded-in-part notes (the 011
  precedent's form) on criterion 1, the entry-point "Get Blank
  Template…" bullet, the "Template and reference docs" section, and
  Decision 8. `specs/011-data-export/spec.md` 142–146 gets a
  one-clause addendum (the template has since moved to Settings).
  011 `plan.md`'s delivery section: per-export-*set*.
- **Close-out edits, named now so they aren't missed**: `ROADMAP.md`
  221–223 ("so a fresh install can reach Import and Get Blank
  Template") and 261–265 (the entry point, "an open design question
  for this spec" — now decided); the status rows; README status and
  tree (which already lacks `012`) **and the README's Features list**,
  which has no entry for Settings, export-everything, the iCloud row
  or Delete All (the sweep's S10); and `DECISIONS.md`'s git-routing
  entry, which names neither bucket for `README.md` — this branch
  changed a behavior sentence there at T015 while the status and tree
  wait for the post-merge pass.

## Test plan

Constitution norms: every guard mutation-verified before it lands;
every claim above gets the test that would catch it false.

- **Service** (`ExportTempFileTests`, `ExportConcurrencyTests`):
  `exportFilesPreparesOnceAndWritesEveryFile` — two CSVs, both present,
  exact bytes, URLs in input order (red: purge per write);
  `aSecondFileSetLeavesOnlyTheSecondSet` — the generalization of
  `aSecondExportLeavesExactlyOneFileSet`, which stays as written; the
  concurrency probe records a third `false` through the existential
  (red: drop `@concurrent` from both the requirement and the
  implementation).
- **Helper** (`ManualOrderHelperTests`): `areInCustomOrder` for both
  entities — position wins; the tail decides ties; identical rows
  order deterministically by id.
- **VM — export** (`SettingsViewModelTests`): the tie fixture →
  explicit expected row order, then equality with the list VM's
  `.custom` table (red: `FetchDescriptor(sortBy:)` in Settings);
  filenames are the dated pair; PDF covers equal the unfiltered list
  covers in everything but `generatedAt`; both empty → intents no-op,
  spy untouched, `canExportEverything == false`; one empty → two files,
  the empty one header-only / `entries.isEmpty` with `itemCount == 0`;
  throwing spy → `.exportFailed` with `alertTitle ==
  ExportCopy.failureTitle` and `alertMessage == ExportCopy.failureMessage`
  (criterion 16's guard); mid-flight `activity` observable and reentry
  blocked (gated spy); the two moved template tests.
- **VM — delete**: `requestDeleteAll` carries the live count (insert
  through a second context after `load()`, then request); cancel
  leaves the store intact (second-context count); confirm deletes
  every item **verified through a second `ModelContext`** (the T018
  shape; red: delete `save()`), the wishlist untouched, the surviving
  wishlist item's `plannedSaleItems` empty, the `Photo` count zero;
  the wishlist twin (items untouched, its photos gone); the race test —
  write `alert = nil` *before* calling `confirmDeleteAll(.items)`,
  await the task, store empty (red: make confirm read `alert`); counts
  reload to zero; `confirmDeleteAll`'s body contains
  `modelContext.rollback()` (scan, the `confirmImport` template).
- **Copy and status**: `DeleteAllCopyTests` (count and plural, every
  consequence named, the **mode branch**, buttons, footer, failure
  strings); `SyncStatusCopyTests` full-string table including nil and
  long reasons; `AppVersionTests` (present, missing keys);
  `ImportCopyTests` full-string equality for the reworded case.
- **Wiring** (`SettingsWiringTests` + updated `ExportWiringTests`):
  badge fed `openSettings`, no template intent, exactly one badge per
  list; `OverflowBadge.swift` literals — "Settings" present, "Get
  Blank Template…" absent, `Divider()` count 2, `.disabled(!canExport)`
  count 2, Import's literal precedes Settings' *(the two counts are
  superseded by Amendment A's test plan — `startsGroup: true` and
  `isEnabled: canExport` on `OverflowDropdown.swift`)*; both lists attach
  `.sheet(isPresented: $isShowingSettings, onDismiss: viewModel.load)`
  wrapping `SettingsView(` with all four init arguments;
  `SettingsView.swift`: `ShareSheet(urls:`, exactly one `.alert(`,
  `viewModel.confirmDeleteAll(` present and `await
  viewModel.confirmDeleteAll` absent, `Button("Done")` without
  `.disabled`, the five sections in order — *read from the body's
  composition, not the properties' declaration order: the first
  version of that scan stayed green when two sections were swapped in
  the body, its own mutation caught it at T012, and it was rewritten*
  — `.accessibilityHint` on both delete rows *and applied by the row*,
  the iCloud block combined into one element, every one of the six
  action rows gating on `isBusy` and reading its own `activity` (the
  last three added at T017 from the sweep: nothing else could notice
  the view's busy bindings going missing, and the hint scan had been
  reading arguments rather than application), no version literal;
  `SettingsViewModel.swift` reads `DeleteAllCopy`, `ExportCopy`,
  `SyncStatusCopy`;
  `TroveApp.swift` forwards `store.cloudKitFailure`; the existing
  overflow-outside-the-gate scan unchanged.
- **UI** (`TroveUITests`): the fresh-install test becomes
  `testEmptyCollectionOffersImportAndSettingsButNotExport` — Settings
  enabled, the template absent from the menu (mutation: re-nest the
  overflow control); new
  `testSettingsFromAnEmptyCollectionOffersTemplatesAndNothingElse` —
  tap Settings, "Items Template…" enabled, "Export All as CSV…" and
  "Delete All Items…" disabled, Done returns to the list — with **its
  own mutation** (drop the `canExportEverything` gate → red), since
  re-nesting the badge would fail it for a reason unrelated to its
  claims.

## Files

**New**: `Trove/ViewModels/SettingsViewModel.swift`,
`Trove/Views/Settings/SettingsView.swift`,
`Trove/Views/Shared/StorageEnvironment.swift`,
`Trove/Models/DeleteAllCopy.swift`, `SyncStatusCopy.swift`,
`AppVersion.swift`; `TroveTests/SettingsViewModelTests.swift`,
`SettingsWiringTests.swift`, `SyncStatusCopyTests.swift`,
`DeleteAllCopyTests.swift`, `AppVersionTests.swift`; one
`TroveUITests` case.
**Modified**: `ExportService.swift` (`ExportFile`, `exportFiles`,
staging split, `StagedExport`), `ShareSheet.swift`,
`ManualOrderHelper.swift`, `OverflowBadge.swift`, `ItemListView.swift`,
`WishlistView.swift`, `ItemListViewModel.swift`,
`WishlistViewModel.swift` (`isOrderedBefore`; `exportBlankTemplate`
removed), `TroveApp.swift`, `ImportService.swift`, `TestSupport.swift`,
`ExportWiringTests`, `ExportTempFileTests`, `ExportConcurrencyTests`,
`ManualOrderHelperTests`, `ImportServiceTests`,
`ItemListViewModelTests`, `WishlistViewModelTests`,
`WishlistDeletionTests`, `TroveUITests`, `docs/csv-reference.md`,
`README.md`, `specs/012-data-import/spec.md`,
`specs/011-data-export/spec.md`, `specs/011-data-export/plan.md`.

## Verification

Per task: `xcodebuild build` + `xcodebuild test` with actual output
(suite-level `-only-testing` selectors and a checked test count — the
per-function selector runs zero tests and reports success). Device
pass at the manual task: both export-all actions from the dev store —
two files land in Files and arrive by AirDrop; the cover-only PDF with
one list empty; the templates from Settings; the iCloud row signed-out,
signed-in, and while catching up (the fallback copy via a preview, since
the fallback can't be provoked on demand); **Delete All on the ~300-row
dev store, timed, with the commit-path branch recorded above**; the
confirmation and failure alerts at the largest accessibility size;
VoiceOver over the delete rows; Done mid-export, then the next export's
purge confirmed by listing the staging directory rather than by
watching for a sheet.

## Not in this plan

tasks.md (drafted after plan approval); any implementation; theme
selection, default currency, account-status queries, an iCloud toggle
(spec non-goals). A Dashboard entry point was a non-goal until
Amendment A — see the final section.

## Amendment A — the Dashboard "…" and bespoke in-page menus

Status: **Approved** (2026-09-02, same day as drafting) — drafted in
Plan Mode against the approved amendment (spec Decisions 15–19,
P8–P13, criteria 20–27). Two
explorations, an independent design pass on the host mechanism, and
the `skeptical-reviewer` ran on this section before it was written.

### Skeptical-review record

Seven blockers and twelve second-looks, all acted on. **Sustained**:
the anchor-preference host with a custom `Layout`; the environment
dismiss action; `startsGroup` as the group break; the render oracle
as an instrument; the criterion-26 fact. **Reshaped**: focus-on-open
targets the first row, not the container (S6); `DismissDropdownAction`
is a plain struct under the project's `MainActor` default (S7); the
ORDER BY dropdown composes inline and `SortDropdown` stays sort-only
with no dead argument (S8); the placement math is a pure function with
a table test (S1); the tab-bar inset is probed at T020, not eyeballed
at T025 (S2); the legacy render oracle is deleted after T019 (S3),
asserts equal dimensions first (S4), and is scoped to drawing, not
position (S11); accessibility identifiers replace `.firstMatch` (S5);
the host is asserted after the add-button overlay rather than "last"
(S10); the 011 note says homogenization, not a tear (S9). **Blockers
fixed**: the catcher's two-tap consequence for switching was escalated
and decided (spec Decision 19) and the UI test inverted (B1);
`MenuPolicyTests`' pattern would have matched `DetailOverflowMenu(` —
word-bounded and widened to `.pickerStyle(.menu)`/`.contextMenu` (B2);
the dismiss action's environment default was a silent no-op with no
named injection point — now loud, injected by the host, scanned (B3);
`DropdownRow` "verbatim" would draw a doubled hairline at the top of a
headerless surface — a first-row rule (B4); "exactly one existing test
goes red" was wrong (two do) and "tap Sort by Custom" named a label
the fresh install never shows (the default sort is Date) (B5); the new
drawing — group break, disabled row — had only argument scans, so the
render instrument now covers `OverflowDropdown` too (B6); the
criterion-26 correction named a human gate it never posed — posed and
decided (spec Decision 18) (B7).

### Grounding

- The lists' sort overlay is one duplicated block differing by a
  single token (`ItemListView.swift:266–292` /
  `WishlistView.swift:217–243`), anchored by `.padding(.top, 60)`,
  which decomposes as `sectionGap 24 + badge 30 + gap 6` — exact for
  the overflow badge's fixed 18×14 + 8/8 frame, a fraction off for the
  text-driven sort badge — and works only because the lists' headers
  are pinned outside the `List`.
- **The Dashboard's header scrolls** (`DashboardView.swift:43–66`) and
  `orderControl` sits deep in the content at an arbitrary offset, on
  the root (nav bar hidden) and the drill-down (nav bar shown) alike.
  The fixed offset can't be reused; the dropdown must position itself
  against the badge that opened it. None of the four badges is inside
  a `List`.
- `SortDropdown` hardcodes "SORT BY" (`SortPicker.swift:69`) and has
  zero test coverage; `DashboardView.orderControl` likewise — nothing
  pins its strings, its checkmark, or its options.
- **Two existing tests go red by construction**, both rewritten below:
  `ExportWiringTests.theMenuCarriesFiveItemsInThreeGroups` (the
  `Divider()` count) and
  `theBadgeIsFedByTheViewModelFiresEveryIntentAndOpensSettings` (the
  four intents leave the `OverflowBadge(` argument list).
- Both UI tests locate menu items as `app.buttons["<title>"]` and
  assert `exists` before `isEnabled == false` on the disabled export
  rows. `SettingsActionRow` — a `.plain` `Button` with `.disabled` —
  already satisfies exactly that shape (`TroveUITests.swift:287–290`).
- `ImportWiringTests` pins the identifiers `overflowControl` and
  `sortControl` and the literal `if viewModel.totalCount > 0`; all
  three are kept.
- 011's plan (`plan.md:320–328`) names the custom dropdown as the
  fallback **conditionally** — "if the badge's border ever tears". It
  didn't; this amendment's reason is homogenization, and the note
  added there says so.
- Precedents to reuse: the custom-`Layout` shape (`FlowLayout.swift`);
  `renderBitmap` (`TestSupport.swift:352–360`, `ImageRenderer` under
  the dark theme, used by `DesireGaugeTests` and `RowThumbnailTests`);
  the Oklab perceptual-distance helper (`TestSupport.swift:300–338`);
  a UI test that drives the quick-add form
  (`testAddingAnItemThroughQuickAddPutsItInTheList`). The Items list's
  default sort is `.purchaseDate`, badge label "Date".

### Components — `Trove/Views/Shared/`

- **`Dropdown.swift` (new)** — the surface and its rows, extracted
  from `SortDropdown` so the drawing lives once.
  - `DropdownSurface<Content>(title: String? = nil)`: 232 wide,
    `PlateSurface`, `buttonRadius` clip, `divider` hairline border,
    `.accessibilityElement(children: .contain)`,
    `.accessibilityAction(.escape)`; the mono-10 / tracking-1.6 /
    `textQuiet` header row iff `title != nil` — `SortDropdown`'s exact
    header. Uses `Group(subviews:)` to attach `.accessibilityFocused`
    to its **first** subview and sets it one run-loop turn after
    appear, so VoiceOver focus lands on the first row, never on the
    container.
  - `DropdownRow(title:, isSelected = false, isEnabled = true,
    startsGroup = false, hasTopHairline = true, tag: String? = nil,
    action)`: `SortDropdown.row(for:)`'s body — body font,
    `textBody`/`accentBrass`, `accentBrassTint` fill, tag and
    checkmark when selected, `isButton`/`isSelected` traits — with
    four additions: `.disabled(!isEnabled)` and `textDisabled` text
    (P11: inert, "dimmed" to VoiceOver, `isEnabled == false` to
    XCUITest); the top hairline in `divider` instead of
    `surfaceInset` when `startsGroup` (P10 — one hairline, spec-exact;
    a standalone break view would stack a second under the next row's
    own); **no top hairline on the first row of a headerless surface**
    (`hasTopHairline: false` — otherwise its `surfaceInset` line sits
    flush under the surface's `divider` border, a doubled line nobody
    designed; the sort dropdown keeps its header seam); and it reads
    `@Environment(\.dismissDropdown)` and **calls it before
    `action()`**, so criterion 23 holds by construction for every row
    on every screen.
  - `CheckmarkGlyph` moves here from `SortPicker.swift`.
- **`SortPicker.swift`** — `SortDropdown` re-composes as
  `DropdownSurface(title: "SORT BY") { ForEach(options) {
  DropdownRow(title:, isSelected:, tag: isManualOrder(o) ? "REORDER"
  : nil) { onSelect(o) } } }` — sort-only, signature unchanged. Same
  pixels (guarded below). `SortBadge` unchanged.
- **`OverflowDropdown.swift` (new)** — the lists' five rows, no title
  (P9): `OverflowDropdown(canExport:, exportCSV:, exportPDF:,
  importCSV:, openSettings:)` → Export as CSV… (`isEnabled: canExport`,
  `hasTopHairline: false`) / Export as PDF… (`isEnabled: canExport`) /
  Import from CSV… (`startsGroup: true`) / Settings (`startsGroup:
  true`). Five closures as today, so the argument scan carries over.
  The Dashboard's one-row menu and its ORDER BY dropdown are composed
  inline from `DropdownSurface` + `DropdownRow`.
- **`OverflowBadge.swift`** — the pill alone: `OverflowBadge(isBusy:,
  action:)`; glyph, spinner and border exactly as today, the `Menu`
  gone; label "More actions"/"Working" plus
  `.accessibilityHint("Opens more actions")`. Doc comment rewritten
  (today's argues *for* the system Menu); `DetailOverflowMenu`'s doc
  comment gets the page/bars rule.
- **`ThemeMetrics.dropdownGap = 6`** — what the `60` resolves to, with
  the derivation in its comment; documented in `tokens.md`.

### The host — `DropdownHost.swift` (new)

```swift
struct DropdownAnchorKey: PreferenceKey        // [AnyHashable: Anchor<CGRect>], reduce = merge
struct DismissDropdownAction { let run: () -> Void; func callAsFunction() { run() } }
extension EnvironmentValues {
    @Entry var dismissDropdown = DismissDropdownAction { assertionFailure("DropdownRow used outside a dropdownHost") }
}
extension View {
    func dropdownAnchor<ID: Hashable>(_ id: ID) -> some View
    func dropdownHost<ID: Hashable, Menu: View>(
        open: Binding<ID?>, dismissLabel: @escaping (ID) -> String,
        @ViewBuilder content: @escaping (ID) -> Menu) -> some View
}
```

- `.overlayPreferenceValue(DropdownAnchorKey.self, alignment:
  .topLeading)`: when `open` is non-nil and its anchor is known, a
  `GeometryReader` (`.ignoresSafeArea()`) resolves `proxy[anchor]` and
  lays a `ZStack` — the catcher (today's exact `Color.clear` /
  `.contentShape(Rectangle())` / `.onTapGesture { open = nil }`,
  labelled by `dismissLabel(id)`, `.isButton`, an explicit
  `.accessibilityAction` so activation doesn't synthesize a centre tap,
  `.accessibilitySortPriority(-1)`) under a `DropdownPlacement` layout
  holding `content(id)` **with `.environment(\.dismissDropdown,
  DismissDropdownAction { open = nil })` on it** — the one injection
  point, scanned. `.transaction { $0.animation = nil }`: no animation,
  as today. Nothing at rest when `open == nil`.
- **`DropdownPlacementLayout: Layout`** measures the dropdown
  synchronously (`subviews.first.sizeThatFits(.unspecified)` — the
  `FlowLayout` shape; no `@State`, no one-frame jump, no layout cycle)
  and places it by a **pure static function**
  `DropdownPlacement.origin(badge:container:insets:size:gutter:gap:)`:
  trailing edge at the screen's trailing gutter (the spec's rule for
  every in-page dropdown; the anchor supplies only the vertical);
  never past the leading gutter; top = `badge.maxY + gap`, **flipped
  above** the badge when the bottom would fall below
  `container.maxY - insets.bottom`, pinned to the top safe edge if
  neither fits. Considered and not taken: `.alignmentGuide` (gets the
  height synchronously too, but the math can't be extracted and
  tested).
- **The tab-bar inset is probed, not eyeballed**: T020 prints
  `proxy.safeAreaInsets.bottom` as the ignoring reader resolves it and
  the computed origin, and records the numbers.
  `ItemListView.swift:401–403` already records that the tab bar sits
  *over* the last rows, so whether iOS 26's floating bar contributes
  to the inset is an open fact — settled by a probe on the mechanism
  at the task that depends on it, the T056 lesson.
- **Switching** — the catcher covers the badges, so while a dropdown
  is open a tap on the other badge closes the open one and does not
  open the other: two taps, as Sort By behaves today (spec Decision
  19). The one-tap alternative — an even-odd cut-out over the badge
  anchors — was declined: a hole over a badge inside the Dashboard's
  `ScrollView` lets a drag scroll the content under an open dropdown,
  which then needs a close-on-scroll as well.
- **Accessibility**: the `ZStack` is `.accessibilityElement(children:
  .contain)` + `.accessibilityAddTraits(.isModal)` (VoiceOver stops
  reaching what's behind; the catcher is inside the container and
  stays reachable and labelled; the UIKit tab bar is outside the
  hosting view and may remain reachable — noted, verified by hand) +
  `.accessibilityAction(.escape) { close() }`. Focus-on-open is the
  surface's own doing, on the first row. Badge hints: "Opens sort
  options" / "Opens more actions" / "Opens order options". Badges also
  carry **accessibility identifiers** (`moreActions.items`,
  `moreActions.wishlist`, `moreActions.dashboard`,
  `sortOptions.items`, `sortOptions.wishlist`), VoiceOver labels
  unchanged — the UI tests query by identifier, so two "More actions"
  badges app-wide can never multi-match or, worse, silently match the
  wrong tab under `.firstMatch`.
- Not built: an `onPreferenceChange` auto-close when an anchor
  vanishes while its dropdown is open — the one place the host would
  write state from a preference, guarding an edge the catcher makes
  nearly unreachable.
- Rejected: keeping the fixed-offset overlay on the lists plus a
  second mechanism for the Dashboard (two state machines for one
  behavior); an `.overlay` on the badge itself (drawn beneath the
  UIKit-backed `List`, clipped by `ScrollView`, and still needing a
  screen-level catcher — the T035 finding); `.popover` with compact
  adaptation (a system container, arrow and presentation animation,
  with UIKit-only knobs to change them — not bespoke); a named
  coordinate space with geometry written into `@State` (per-scroll-
  frame writes on the Dashboard, the multiple-updates-per-frame
  shape).

### Screens

- **Both lists**: `isSortMenuOpen` → `@State private var
  openDropdown: HeaderDropdown?` with `private enum HeaderDropdown:
  Hashable { case sort, overflow; var dismissLabel }` ("Dismiss sort
  options" as today / "Dismiss more actions") — one optional per
  screen is what makes "one open at a time" true by type.
  `sortControl` → `SortBadge { openDropdown = .sort
  }.dropdownAnchor(HeaderDropdown.sort)` plus hint and identifier;
  `overflowControl` → `OverflowBadge(isBusy:) { openDropdown =
  .overflow }.dropdownAnchor(HeaderDropdown.overflow)` plus
  identifier. **Identifier names and the `if viewModel.totalCount >
  0` gate unchanged.** The host replaces the sort overlay block,
  **after the `AddButton` overlay** so it draws above the add button
  (presentations don't participate in z-order, so "after the sheets"
  buys nothing and isn't asserted). Content: `.sort` →
  `SortDropdown(…) { viewModel.sortOrder = $0; viewModel.load() }`
  (the row dismissed already); `.overflow` →
  `OverflowDropdown(canExport: viewModel.canExport, exportCSV: { Task
  { await viewModel.exportCSV() } }, exportPDF: …, importCSV: {
  isPickingImportFile = true }, openSettings: { isShowingSettings =
  true })`.
- **Dashboard**: `header` becomes `HStack(alignment: .top) {
  VStack(…); Spacer(); if isRoot { overflowControl } }` — both
  branches of `body` compose `header`, so the empty state gets the
  badge for free (criterion 20). `overflowControl` =
  `OverflowBadge(isBusy: false) { openDropdown = .overflow }` plus
  anchor and identifier; `orderControl` = a `.plain` `Button` around
  today's mono label with `.contentShape(Rectangle())`,
  `.dropdownAnchor(DashboardDropdown.order)`, the existing "Order
  categories …" label plus the hint. New: `@State openDropdown:
  DashboardDropdown?`, `@State isShowingSettings`,
  `@Environment(\.storageMode)` / `\.storageFallbackReason`, and the
  lists' byte-identical Settings sheet line — `.sheet(isPresented:
  $isShowingSettings, onDismiss: viewModel.load) { NavigationStack {
  SettingsView(modelContext:, syncMonitor:, storageMode:,
  storageFallbackReason:) } }` (`syncMonitor` is already stored).
  Content: `.overflow` → `DropdownSurface { DropdownRow(title:
  "Settings", hasTopHairline: false) { isShowingSettings = true } }`;
  `.order` → `DropdownSurface(title: "ORDER BY") {
  ForEach(BreakdownOrder.allCases) { DropdownRow(title: $0.label,
  isSelected: $0 == viewModel.breakdownOrder) {
  viewModel.breakdownOrder = $0; viewModel.load() } } }` (P12: the
  same surface and rows Sort By is made of). The drill-down shows no
  "…" but hosts the order dropdown under its visible nav bar.
  `.refreshable`, `.onChange(of: viewModel.completedImports)`, and the
  `DashboardView(` handoffs — all scanned by existing tests — are
  untouched.
- **Detail screens**: untouched.

### Docs

- `design/tokens.md`: the "Export badge and menu (`011`)" table — the
  Menu row rewritten (bespoke, the Sort picker's surface — 013
  Amendment A), the stale "hidden on an empty collection" sentence
  corrected (012 overturned it), rows added for the group break
  (`divider` hairline), the disabled row (`textDisabled`), the hint,
  and `dropdownGap`; the "Sort picker (`010`)" section reframed as the
  shared surface (header row SORT BY / ORDER BY, the first-row rule);
  a line for the Dashboard's badge and order dropdown.
- `design/brief.md`: a short new section — menus inside the page are
  Trove's own; chrome in the bars (tab bar, nav-bar buttons and menus,
  sheet buttons) is the system's. The brief has no such paragraph
  today.
- `specs/011-data-export/plan.md:320–328`: a note that Amendment A
  takes the recorded fallback for homogenization, not because the
  border tore; `spec.md` lines 152 and 159 cite two test names that no
  longer exist (`theBadgeIsFedByTheViewModelAndFiresBothIntents`,
  `bothMenuActionsGateOnCanExport`) — corrected.
  `specs/012-data-import/spec.md:362–364`'s citation of
  `theMenuCarriesFiveItemsInThreeGroups` and its "gating count still
  pinned at exactly 2" — amended to the new proof of grouping.
- This document: the Entry-point section and the wiring bullet of the
  test plan carry "superseded in part by Amendment A" notes.
  `tasks.md`: status back to In progress; Phase 6.
- ROADMAP and README stay on the post-merge list; ROADMAP 261–265 is
  now doubly stale ("an open design question", "four actions", "a
  Dashboard entry point") and is absorbed there.

### Test plan (every guard mutation-verified; red-runs in Done notes)

- **Render oracle for the refactor** (`SortDropdownRenderTests`,
  T018): today's `SortDropdown` copied verbatim into the test target
  as `LegacySortDropdown` (private glyph and header included), both
  rendered through `renderBitmap` for two states (Custom with REORDER;
  a non-manual selection), **dimensions asserted equal first**, then
  exact pixel equality — no tolerance: old and new render in the same
  process and run, so renderer, OS and font drift cancel, and a
  tolerance would erase the one-point shift the test exists to catch.
  Rendered twice for determinism. Mutation: change one padding in the
  production view → red. **Lifetime**: deleted at T019's close-out
  with its red-run recorded — after T019 the drawing lives once, and a
  frozen copy would be a second encoding of it. **Scope**: the
  surface's drawing, not its position; position is the device pass's.
- **Render guard for the new drawing** (`OverflowDropdownRenderTests`,
  T021): `OverflowDropdown` rendered on both `canExport` states;
  sampled pixels assert (a) the two group-break hairlines are
  perceptually farther from `surface` than a row separator is — the
  Oklab floor, the desire-dial instrument (the arithmetic puts
  `divider` at roughly three times `surfaceInset`'s contrast on
  `surface`, and this makes it a test rather than a sentence); (b) the
  first row draws no top hairline; (c) a disabled row's title pixels
  match `textDisabled`, not `textBody`. Mutations: wire `startsGroup`
  to nothing → red; drop `hasTopHairline` → red; drop the disabled
  color → red.
- **Placement math** (`DropdownPlacementTests`, T020):
  `DropdownPlacement.origin(...)` table-tested — below with room;
  flipped above when below would cross the bottom inset; pinned to the
  top inset when neither fits; trailing edge at `container.maxX -
  insets.trailing - gutter`; never past the leading gutter. Mutation:
  drop the flip → red.
- **`MenuPolicyTests`** (T023, criterion 27): a word-boundary pattern
  `(?<![A-Za-z0-9_])Menu\s*[({]` — so `DetailOverflowMenu(` does not
  match — plus `.pickerStyle(.menu)` and `.contextMenu`, over every
  file under `Trove/Views`, allowlist exactly `DetailOverflowMenu.swift`;
  more than ten files scanned. Mutation: add a `Menu {` to a view →
  red; and confirm `DetailOverflowMenu(` alone stays green.
- **`DropdownWiringTests`** (new): per list — exactly one `@State
  private var openDropdown:`, no `isSortMenuOpen`, `.dropdownHost(open:
  $openDropdown` once and after `.overlay(alignment: .bottomTrailing)`,
  `.dropdownAnchor(HeaderDropdown.sort)` and `(HeaderDropdown.overflow)`
  once each; Dashboard — `.dropdownAnchor(DashboardDropdown.overflow)`
  inside the `if isRoot` brace span and nowhere else (mutation: move it
  out → red), `DropdownSurface(title: "ORDER BY")`, the inline Settings
  row; `OverflowDropdown.swift` — the five literals in order,
  `startsGroup: true` ×2 on Import and Settings, `isEnabled: canExport`
  ×2, "Get Blank Template…" absent; `Dropdown.swift` — `DropdownRow`'s
  button body calls `dismiss()` before `action()` (body order),
  `.disabled(!isEnabled)`, `Group(subviews:` and `.accessibilityFocused(`
  in `DropdownSurface`; `DropdownHost.swift` —
  `.environment(\.dismissDropdown,` injected on the content,
  `.accessibilityAction(.escape)`, `.isModal`, the catcher's `.isButton`;
  `SortPicker.swift` — `SortDropdown`'s body composes
  `DropdownSurface(title: "SORT BY"` and `DropdownRow(`. Each scan reads
  the body that composes, never a declaration.
- **Rewritten**: `ExportWiringTests.theBadgeIsFedByTheViewModel…` →
  `OverflowBadge(` ×1 with `isBusy: viewModel.isBusy`,
  `OverflowDropdown(` ×1 carrying `canExport: viewModel.canExport`,
  `viewModel.exportCSV()`, `viewModel.exportPDF()`, `isPickingImportFile
  = true`, `isShowingSettings = true`; `theMenuCarriesFiveItemsInThreeGroups`
  → scans `OverflowDropdown.swift`.
  `SettingsWiringTests.theListAttachesTheSettingsSheetAndReloadsOnDismiss`
  → arguments gain `DashboardView.swift`.
- **UI**: the two existing tests pass with the badge query moved to
  the identifier (UI suite at T021, twice). New
  `testDashboardOffersSettingsAndNothingElse`: Overview tab →
  `moreActions.dashboard` → "Settings" enabled, "Import from CSV…"
  absent → tap → `navigationBars["Settings"]` → Done → badge hittable;
  mutation: gate the badge behind `!viewModel.isEmpty` → red on the
  empty store. New `testAnOpenMenuClosesOnAnyOutsideTapIncludingTheOtherBadge`
  (Decision 19): add one item through the quick-add form so the sort
  badge shows; tap `sortOptions.items` → the "SORT BY" text exists;
  tap `moreActions.items` → "SORT BY" is gone **and "Import from CSV…"
  does not exist**; tap `moreActions.items` again → it exists; tap
  "Dismiss more actions" → gone. Mutation: give the overflow its own
  boolean so both can be open → the first pair of assertions goes red.
- Accessibility *behavior* — focus actually moving, escape, `.isModal`
  containment — is verified by hand at T025, and criterion 26's
  verification record says its focus half rests on that, not on the
  scan.

### Tasks — the shape (Phase 6, drafted after this addendum is approved)

T018 render oracle → T019 `Dropdown.swift` + `SortDropdown`
re-composed (oracle green, then deleted) + `dropdownGap` → T020
`DropdownHost` + placement tests + Sort By migrated on both lists +
the inset probe → T021 `OverflowDropdown` / badge rewrite + the lists'
"…" + render guard + identifiers (UI suite twice) → T022 Dashboard
badge + Settings sheet + UI tests → T023 Dashboard order control +
`MenuPolicyTests` → T024 docs → T025 device pass, criteria 20–27
record, close-out.

### Verification

Per task: `xcodebuild build` and `xcodebuild test` with
`-only-testing:TroveTests` (count checked); the UI target at T021,
T022 and T025, twice back to back. Device pass: both lists' dropdowns
at both badges (placement against today's, group breaks, disabled rows
via an empty search result), the Dashboard badge at root and its
absence on a drill-down, the order dropdown at scroll offsets and
under a drill-down's nav bar (flip-above near the tab bar, with the
T020 probe's numbers in hand), two-tap switching, Settings from the
Dashboard; VoiceOver on the badges, focus-on-open, escape, dimmed
rows, `.isModal` containment — by hand, recorded as such. Delete All
reflection on the Dashboard is verified on the `-uiTesting` store,
never the dev store.

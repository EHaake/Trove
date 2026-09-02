# 013 — Settings Menu — Technical Plan

Status: **Approved** (2026-09-01, same day as drafting; drafted
in-session per the authorship split. One copy correction at review —
the singular Delete All title — recorded under Copy.)

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

- `FileExportService.exportFiles`: fire the generation probe once,
  **`prepareStagingDirectory()` once** (the purge plus create), then
  for each file in order: render → `write(_:filename:)` → next. Each
  PDF renders just before its own write, so 011's one-document-in-
  memory profile holds for a set. One `PhotoFetcher` is shared across
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
labels reuse the unfiltered strings verbatim (`"All items"`,
`"Whole wishlist"`), titles `"Owned Items"` / `"Wishlist"`, filenames
from `ExportFilename.items/wishlist(fileExtension:)`. Criterion 5's
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
  The measurement and the branch taken get recorded here.
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
  - `message(for target:, mode:)` — items: "Their photos go too. Every
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
- **`ImportCopy`** `.headerMismatch(wrongList: false)` body → "The
  columns don't match the \(noun) template. A blank template with the
  expected layout is in Settings › Templates." — **body only**: the
  function appends "Nothing was imported." itself (the review's B6;
  the draft's string would have doubled it past the suffix test). The
  new guard in `ImportCopyTests` is a **full-string equality** for
  both targets.

## Entry point and the Settings sheet

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
    About: `DetailRow`s for name/subtitle and Version (mono).
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
  tree (which already lacks `012`).

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
  count 2, Import's literal precedes Settings'; both lists attach
  `.sheet(isPresented: $isShowingSettings, onDismiss: viewModel.load)`
  wrapping `SettingsView(` with all four init arguments;
  `SettingsView.swift`: `ShareSheet(urls:`, exactly one `.alert(`,
  `viewModel.confirmDeleteAll(` present and `await
  viewModel.confirmDeleteAll` absent, `Button("Done")` without
  `.disabled`, the five section titles in order, `.accessibilityHint`
  on both delete rows, no version literal; `SettingsViewModel.swift`
  reads `DeleteAllCopy`, `ExportCopy`, `SyncStatusCopy`;
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
selection, default currency, account-status queries, an iCloud toggle,
a Dashboard entry point (spec non-goals).

# Tasks: Core Inventory (v1)

**App**: Trove — *Your Gear, Valued*
**Status**: Draft — pending review
**Implements**: plan.md in this directory

Ordered, small, independently verifiable. Each task should be completable
(and testable) on its own — resist the urge to bundle several into one
commit. If a session ends mid-list, resume by finding the first unchecked
task; don't re-verify everything above it unless something looks off.

Per CLAUDE.md: every implementation task ends with an actual build and,
where tests exist for what changed, an actual test run — reported, not
summarized.

---

## Phase 0 — Project scaffolding (one-time)

- [ ] **T001** — Create the Xcode project: App target `Trove`, SwiftUI
      lifecycle, iOS 26.0 minimum deployment, plain `.xcodeproj` (no
      XcodeGen/Tuist). *Verify: project opens and builds an empty app in
      the simulator.*
- [ ] **T002** — Add iCloud capability and a CloudKit container to the
      target's Signing & Capabilities. *Verify: capability appears in
      Xcode's signing pane; no build errors.*
- [ ] **T003** — Add a `TroveTests` target (Swift Testing) and a
      `TroveUITests` target (XCTest). *Verify: an empty placeholder test
      in each target runs green via `xcodebuild test`.*
- [ ] **T004** — Create the folder structure from plan.md
      (`App/`, `Models/`, `ViewModels/`, `Views/{Dashboard,Items,
      Wishlist,Shared}/`, `Extensions/`). *Verify: folders exist and are
      reflected as groups in Xcode.*

## Phase 1 — Data models

- [ ] **T005** — `Condition` enum (`new/excellent/good/fair/broken`,
      `String`-backed, `Codable`, `CaseIterable`).
- [ ] **T006** — `Photo` model (`id`, `imageData` with
      `.externalStorage`, `sortOrder`, inverse `item` relationship).
- [ ] **T007** — `Item` model per plan.md's table, including
      `currencyCode` (default `"USD"`) and the computed `condition`
      property wrapping the `Condition` enum.
- [ ] **T008** — `WishlistItem` model per plan.md's table, including
      `currencyCode`.
- [ ] **T009** — Configure `ModelContainer` in `TroveApp` with a CloudKit
      database, registering all three model types. Handle "user not
      signed into iCloud" without erroring — app still works locally.
      *Verify: app launches in the simulator without a CloudKit-related
      crash, signed in or not.*
- [ ] **T010** — Unit tests: creating each model type via an in-memory
      `ModelContainer` produces the expected defaults (`desireToKeep ==
      3`, `currencyCode == "USD"`, etc). *Verify: `xcodebuild test`
      green.*

## Phase 2 — Shared utilities

- [ ] **T011** — `Int+Currency` extension: cents → formatted currency
      string, given a `currencyCode`.
- [ ] **T012** — Unit tests for currency formatting (zero, negative if
      applicable, typical values).
- [ ] **T013** — Category-path helper: given a `ModelContext`, fetch
      distinct `categoryPath` values across `Item` and `WishlistItem`;
      a filter function that matches by prefix, case-insensitively,
      against user-typed input; a canonicalization function that, given
      a newly-typed path, returns the existing casing if a
      case-insensitive match exists among current paths, or the
      as-typed string otherwise. Called on save, not on every keystroke.
- [ ] **T014** — Unit tests for the category-path helper: dedup,
      case-insensitive prefix filtering, empty input, and
      canonicalization specifically (typing an existing path with
      different casing reuses the stored casing; a genuinely new path is
      stored as typed).

## Phase 3 — Item CRUD: view models

- [ ] **T015** — `ItemFormViewModel`: create/edit an `Item`; validates
      required fields (name, category, price, date) and clamps
      `desireToKeep` to 1–5.
- [ ] **T016** — Unit tests for `ItemFormViewModel` (valid create, invalid
      create rejected, edit updates `updatedAt`, defaults applied).
- [ ] **T017** — `ItemListViewModel`: fetch all items; filter by category
      prefix; sort by desire-to-keep, current value, or purchase date.
- [ ] **T018** — Unit tests for `ItemListViewModel` (each sort order,
      filter behavior, empty state).
- [ ] **T019** — `ItemDetailViewModel`: load a single item, delete it.
- [ ] **T020** — Unit tests for `ItemDetailViewModel`.

## Phase 4 — Item CRUD: views

- [ ] **T021** — `CategoryPickerField`: text field + autocomplete
      suggestions, backed by the Phase 2 helper. *Verify: manual check in
      a SwiftUI preview.*
- [ ] **T022** — `PhotoPickerField`: wraps `PhotosUI.PhotosPicker` for
      multi-photo selection, returns `[Photo]`.
- [ ] **T023** — `ItemFormView`: required fields up front, optional
      fields behind a "more details" disclosure. Used for both add and
      edit.
- [ ] **T024** — `ItemListView`: list with filter and sort controls, using
      `ItemListViewModel`.
- [ ] **T025** — `ItemDetailView`: displays an item, links to edit
      (reuses `ItemFormView`), delete with confirmation.
- [ ] **T026** — Manual verification: add an item end-to-end in the
      simulator (quick-add path and full-detail path), edit it, delete
      it.

## Phase 5 — Dashboard

- [ ] **T027** — `DashboardViewModel`: total current value (excluding
      un-valued items), count of un-valued items, total spent, delta,
      category breakdown.
- [ ] **T028** — Unit tests for `DashboardViewModel`, including the
      un-valued-exclusion behavior specifically.
- [ ] **T029** — `DashboardView`.
- [ ] **T030** — Manual verification: dashboard numbers match a small set
      of manually-entered test items.

## Phase 6 — Wishlist CRUD

- [ ] **T031** — `WishlistFormViewModel`: create/edit a `WishlistItem`.
- [ ] **T032** — Unit tests for `WishlistFormViewModel`.
- [ ] **T033** — `WishlistViewModel`: fetch/list wishlist items, manual
      reordering via `sortOrder`.
- [ ] **T034** — Unit tests for `WishlistViewModel`.
- [ ] **T035** — `WishlistFormView`.
- [ ] **T036** — `WishlistView`: list with reordering.

## Phase 7 — Sell-candidate ranking

This is the piece most worth over-testing — it's the feature the rest of
the app exists to support, and it's the thing a future trend-aware version
will build on top of directly.

- [ ] **T037** — `WishlistDetailViewModel`: given a `WishlistItem`, fetch
      owned items with `desireToKeep ≤ 3` and a non-nil `currentValueCents`,
      sort ascending by `desireToKeep` (tie-break: higher current value
      first), compute running cumulative value total.
- [ ] **T038** — Unit tests for the ranking: empty candidate set, a tie
      resolved correctly, un-valued items excluded, ordering correct
      across a realistic mixed set, cumulative total is right at each
      step.
- [ ] **T039** — `WishlistDetailView`: ranked list with running total,
      visually distinguishing "this is enough to cover it" once the
      cumulative total crosses the estimated cost.

## Phase 8 — Navigation and app shell

- [ ] **T040** — Root `TabView` (Dashboard / Items / Wishlist), each tab
      a `NavigationStack`.
- [ ] **T041** — Add-item and add-wishlist-item entry points in the
      toolbar of their respective tabs (not buried in a menu).
- [ ] **T042** — Manual full click-through: launch → dashboard → add item
      → items list → item detail → wishlist → add wishlist item →
      wishlist detail ranking.

## Phase 9 — Empty and loading states

- [ ] **T043** — Empty state for the items list (no items yet — should
      point at the add action, not just say "no items").
- [ ] **T044** — Empty state for the wishlist.
- [ ] **T045** — Empty/zero state for the dashboard when there's no data
      yet.

## Phase 10 — Sync and device verification (manual)

- [ ] **T046** — Manual: run the app on two simulators (or a simulator
      and a device) signed into the same iCloud account; confirm an item
      added on one appears on the other. Not automated — see plan.md's
      testing strategy.
- [ ] **T047** — Manual: confirm the app behaves reasonably when the
      simulator/device is not signed into iCloud at all.

## Phase 11 — UI smoke test

- [ ] **T048** — One `XCUIApplication` test: launch the app, add an item
      through the quick-add flow, confirm it appears in the items list.

---

## Handoff note

Once this file is reviewed and approved (flip the Status field above),
hand it to Claude Code with something like:

> Read CLAUDE.md and specs/001-core-inventory/{spec,plan,tasks}.md, then
> begin implementing starting at T001. For Phase 0 and Phase 1, stop for
> review after each individual task. From Phase 2 onward, stop after each
> phase instead of after each task.

The tighter cadence for Phases 0–1 is deliberate: mistakes in project
scaffolding or the data model (a wrong deployment target, a schema that
isn't actually CloudKit-compatible) are cheap to catch immediately and
expensive to unwind once other work is layered on top. Everything from
Phase 2 on is comparatively cheap to fix after the fact, so batching
review by phase is fine there — and from T021 onward you'll be watching
it happen live in the iOS Simulator pane anyway.

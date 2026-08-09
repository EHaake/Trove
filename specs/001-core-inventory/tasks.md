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

- [x] **T001** — Create the Xcode project: App target `Trove`, SwiftUI
      lifecycle, iOS 26.0 minimum deployment, plain `.xcodeproj` (no
      XcodeGen/Tuist). *Verify: project opens and builds an empty app in
      the simulator.*
- [ ] ~~T002~~ — **Deferred, not skipped.** Add iCloud capability and a
      CloudKit container to the target's Signing & Capabilities. Blocked:
      creating a new CloudKit container requires Certificates,
      Identifiers & Profiles access, which needs an active paid Apple
      Developer Program membership (a Personal Team can build/run
      locally, but can't provision a new container) — see plan.md's
      CloudKit section. Not a scope change; picking this back up once the
      membership is renewed, ideally before Phase 10 or before actual
      App Store prep, whichever comes first. T009 below proceeds without
      it for now.
- [x] **T003** — Add a `TroveTests` target (Swift Testing) and a
      `TroveUITests` target (XCTest). *Verify: an empty placeholder test
      in each target runs green via `xcodebuild test`.*
- [x] **T004** — Create the folder structure from plan.md
      (`App/`, `Models/`, `ViewModels/`, `Views/{Dashboard,Items,
      Wishlist,Shared}/`, `Extensions/`). *Verify: folders exist and are
      reflected as groups in Xcode.*

## Phase 1 — Data models

- [x] **T005** — `Condition` enum (`new/excellent/good/fair/broken`,
      `String`-backed, `Codable`, `CaseIterable`).
- [x] **T006** — `Photo` model (`id`, `imageData` with
      `.externalStorage`, `source` — always `"device"` in v1, `sortOrder`,
      inverse `item` relationship).
- [ ] **T007** — `Item` model per plan.md's table, including
      `currencyCode` (default `"USD"`), the computed `condition`
      property wrapping the `Condition` enum, and the
      `plannedForWishlistItems` inverse relationship.
- [ ] **T008** — `WishlistItem` model per plan.md's table, including
      `currencyCode` and the `plannedSaleItems` relationship to `Item`.
- [ ] **T009** — Configure `ModelContainer` in `TroveApp`, registering
      all three model types. **Local-only for now** (no CloudKit
      database) since T002 is deferred — the schema was built
      CloudKit-compatible from the start specifically so this is a small,
      contained swap later (add the CloudKit database configuration and
      the "not signed into iCloud" handling) rather than a migration.
      *Verify: app launches in the simulator without errors.*
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
- [ ] **T033** — `WishlistViewModel`: fetch/list wishlist items, filter by
      category (same prefix/case-insensitive matching as
      `ItemListViewModel`), manual reordering via `sortOrder`.
- [ ] **T034** — Unit tests for `WishlistViewModel`, including the
      category filter.
- [ ] **T035** — `WishlistFormView`.
- [ ] **T036** — `WishlistView`: list with category filter control and
      reordering; each row includes a "See sell plan" shortcut that
      navigates directly to that item's `SellPlanView`.

## Phase 7 — Wishlist detail and the Sell Plan

`WishlistDetailView` and `SellPlanView` are deliberately separate
screens, not one combined view: the wishlist item's own details lead, and
the Sell Plan — a v1 approximation of a feature that's meant to grow into
something bigger once market data exists — is one tap away via a button,
not shown automatically. See spec.md and plan.md for the reasoning. The
Sell Plan logic itself (T039–T040) is the piece most worth over-testing
regardless of which screen shows it — it's the thing a future
trend-aware version builds on top of directly, and it's also the one
place in the app with real persisted, user-editable state beyond simple
CRUD.

- [ ] **T037** — `WishlistDetailViewModel`: load a `WishlistItem`'s own
      fields for display (name, category, estimated cost, notes). No
      ranking or plan logic here.
- [ ] **T038** — `WishlistDetailView`: plain display of the wishlist
      item's fields, with space reserved in the layout for future
      pricing/trend info, and a single "Find items to sell" button/nav
      link to `SellPlanView`.
- [ ] **T039** — `SellPlanViewModel`: given a `WishlistItem`,
      - compute the candidate pool (owned items, `desireToKeep ≤ 3`,
        non-nil `currentValueCents`, sorted ascending by `desireToKeep`,
        tie-break higher current value first);
      - load the existing selection from `plannedSaleItems` — starts
        empty on first visit, **no auto-selection**;
      - expose toggle methods that add/remove a candidate from
        `plannedSaleItems` and persist on every change;
      - expose the selected items' combined current value and the
        wishlist item's `estimatedCostCents` as two separate figures for
        the view to compare, rather than a single pre-computed
        surplus/shortfall value with baked-in framing.
- [ ] **T040** — Unit tests for `SellPlanViewModel`: empty candidate pool,
      a tie resolved correctly, un-valued items excluded from the pool,
      the plan starts with nothing selected on first load, toggling a
      candidate updates the persisted selection and the selected-value
      figure, and re-loading after a toggle reflects the persisted
      selection rather than resetting.
- [ ] **T041** — `SellPlanView`: selectable candidate list (visually
      distinguishing selected from unselected), the selected total shown
      alongside the estimated cost as two comparable figures. A quiet
      color distinction between "meets or exceeds" and "doesn't" is fine;
      no copy nudging the user to select more ("keep going," "check
      another item," or similar) — this is advisory, not a target to
      complete. Reached only via `WishlistDetailView`'s button or
      `WishlistView`'s per-row shortcut — no other entry point.

## Phase 8 — Navigation and app shell

- [ ] **T042** — Root `TabView` (Dashboard / Items / Wishlist), each tab
      a `NavigationStack`.
- [ ] **T043** — Add-item and add-wishlist-item entry points in the
      toolbar of their respective tabs (not buried in a menu).
- [ ] **T044** — Manual full click-through: launch → dashboard → add item
      → items list → item detail → wishlist → filter wishlist by
      category → add wishlist item → wishlist detail → "Find items to
      sell" → Sell Plan → toggle a candidate → back to wishlist list →
      "See sell plan" shortcut reaches the same, updated plan.

## Phase 9 — Empty and loading states

- [ ] **T045** — Empty state for the items list (no items yet — should
      point at the add action, not just say "no items").
- [ ] **T046** — Empty state for the wishlist.
- [ ] **T047** — Empty/zero state for the dashboard when there's no data
      yet.

## Phase 10 — Sync and device verification (manual)

**Blocked pending Developer Program renewal**, same as T002 — nothing
here is verifiable until CloudKit is actually turned on. Revisit T002
first (swap `TroveApp`'s `ModelContainer` back to a CloudKit
configuration), then come back to this phase.

- [ ] **T048** — Manual: run the app on two simulators (or a simulator
      and a device) signed into the same iCloud account; confirm an item
      added on one appears on the other. Not automated — see plan.md's
      testing strategy.
- [ ] **T049** — Manual: confirm the app behaves reasonably when the
      simulator/device is not signed into iCloud at all.

## Phase 11 — UI smoke test

- [ ] **T050** — One `XCUIApplication` test: launch the app, add an item
      through the quick-add flow, confirm it appears in the items list.

---

## Handoff note

Once this file is reviewed and approved (flip the Status field above),
hand it to Claude Code with something like:

> Read CLAUDE.md and specs/001-core-inventory/{spec,plan,tasks}.md, then
> begin implementing starting at T001. For Phase 0 and Phase 1, stop for
> review after each individual task. From Phase 2 onward, stop after each
> phase instead of after each task. When building views from Phase 4
> onward, match the screens in design/screens/ and use the exact values
> in design/tokens.md — implement colors via a semantic Theme abstraction
> (see plan.md's "Future: theming" section), never hardcoded per-view.

The tighter cadence for Phases 0–1 is deliberate: mistakes in project
scaffolding or the data model (a wrong deployment target, a schema that
isn't actually CloudKit-compatible) are cheap to catch immediately and
expensive to unwind once other work is layered on top. Everything from
Phase 2 on is comparatively cheap to fix after the fact, so batching
review by phase is fine there — and from T021 onward you'll be watching
it happen live in the iOS Simulator pane anyway.

## Model and effort per phase

Model/effort isn't something Claude Code sets from reading this file —
it's a manual switch (`/model` or `/effort`) you make yourself at each
phase-boundary checkpoint, since that's already a natural pause point.
This table is the reference for what to switch to at each one:

| Phase | Model / effort | Why |
|---|---|---|
| 0 — Project scaffolding | Opus 5, xhigh | Foundational; a wrong deployment target or project setup mistake is expensive to unwind later. |
| 1 — Data models | Opus 5, xhigh | CloudKit schema constraints are exactly the "gotcha you only know from experience" category — worth the extra effort. |
| 2 — Shared utilities | Sonnet 5, high | Well-specified, mechanical. |
| 3 — Item CRUD: view models | Sonnet 5, high | Well-specified, mechanical. |
| 4 — Item CRUD: views | Sonnet 5, high | Building against a provided screenshot and detailed task description — little for extra "expertise" to add. |
| 5 — Dashboard | Sonnet 5, high | Same as above. |
| 6 — Wishlist CRUD | Sonnet 5, high | Same as above. |
| 7 — Wishlist detail and the Sell Plan | Opus 5, xhigh | The densest logic in the app — persistence, ranking, toggle semantics — and the piece most worth over-testing. |
| 8 — Navigation and app shell | Sonnet 5, high | Mechanical wiring. |
| 9 — Empty and loading states | Sonnet 5, high | Mechanical. |
| 10 — Sync and device verification | Sonnet 5, high | Manual verification steps, not code generation. |
| 11 — UI smoke test | Sonnet 5, high | One straightforward `XCUIApplication` test. |

You're on Pro and a light user otherwise, so there's real headroom for
this — but Claude Code sessions can burn a weekly cap faster than normal
chat, especially at xhigh across a multi-day build. Watch the usage
indicator in Claude Code as you go; if it's tightening faster than
expected partway through, lean harder toward Sonnet for anything short
of Phase 1/Phase 7-level risk rather than treating this table as fixed.

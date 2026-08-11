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
- [x] **T007** — `Item` model per plan.md's table, including
      `currencyCode` (default `"USD"`), the computed `condition`
      property wrapping the `Condition` enum, and the
      `plannedForWishlistItems` inverse relationship.
- [x] **T008** — `WishlistItem` model per plan.md's table, including
      `currencyCode` and the `plannedSaleItems` relationship to `Item`.
- [x] **T009** — Configure `ModelContainer` in `TroveApp`, registering
      all three model types. **Local-only for now** (no CloudKit
      database) since T002 is deferred — the schema was built
      CloudKit-compatible from the start specifically so this is a small,
      contained swap later (add the CloudKit database configuration and
      the "not signed into iCloud" handling) rather than a migration.
      *Verify: app launches in the simulator without errors.*
- [x] **T010** — Unit tests: creating each model type via an in-memory
      `ModelContainer` produces the expected defaults (`desireToKeep ==
      3`, `currencyCode == "USD"`, etc). *Verify: `xcodebuild test`
      green.*

**Not a numbered task, added during T007, worth being on the record**:
`CloudKitSchemaTests.swift` — asserts the schema actually validates
against a CloudKit `ModelConfiguration`, rather than plan.md just
asserting it in prose. This is what caught the `[Photo]` vs `[Photo]?`
bug (see plan.md's Data model intro). Runs as part of `xcodebuild test`
going forward with no entitlement or network needed; every future model
change gets checked immediately rather than at T002-resumption time.

## Phase 2 — Shared utilities

- [x] **T011** — `Int+Currency` extension: cents → formatted currency
      string, given a `currencyCode`.
- [x] **T012** — Unit tests for currency formatting (zero, negative if
      applicable, typical values).
- [x] **T013** — Category-path helper: given a `ModelContext`, fetch
      distinct `categoryPath` values across `Item` and `WishlistItem`;
      a filter function that matches by prefix, case-insensitively,
      against user-typed input; a canonicalization function that, given
      a newly-typed path, returns the existing casing if a
      case-insensitive match exists among current paths, or the
      as-typed string otherwise. Called on save, not on every keystroke.
- [x] **T014** — Unit tests for the category-path helper: dedup,
      case-insensitive prefix filtering, empty input, and
      canonicalization specifically (typing an existing path with
      different casing reuses the stored casing; a genuinely new path is
      stored as typed).

## Phase 3 — Item CRUD: view models

- [x] **T015** — `ItemFormViewModel`: create/edit an `Item`; validates
      required fields (name, category, price, date) and clamps
      `desireToKeep` to 1–5.
- [x] **T016** — Unit tests for `ItemFormViewModel` (valid create, invalid
      create rejected, edit updates `updatedAt`, defaults applied).
- [x] **T017** — `ItemListViewModel`: fetch all items; filter by category
      prefix; sort by desire-to-keep, current value, or purchase date.
- [x] **T018** — Unit tests for `ItemListViewModel` (each sort order,
      filter behavior, empty state).
- [x] **T019** — `ItemDetailViewModel`: load a single item, delete it.
- [x] **T020** — Unit tests for `ItemDetailViewModel`.

## Phase 4 — Item CRUD: views

**Not a separate numbered task, but genuinely foundational**: the
`Theme` abstraction (plan.md's "Future: theming" section — semantic
color/type tokens from `design/tokens.md`, never hardcoded per-view)
lands here, inside T021, since it's the first view built. Worth the same
weight as `TroveSchema.swift` in Phase 1 — every subsequent view in every
later phase depends on this being right, and a wrong shape here is
expensive to unwind once a dozen views are already reading from it
directly rather than through the abstraction.

- [x] **T021** — `CategoryPickerField`: text field + autocomplete
      suggestions, backed by the Phase 2 helper. *Verify: manual check in
      a SwiftUI preview.*

**Pending action item, not blocking, discovered during T021**: Archivo
and IBM Plex (Sans + Mono) aren't in the repo yet, so every screen is
currently rendering on system-font fallback —
`ThemeTypography.customFontsInstalled = false`. Correct size, weight, and
rhythm; wrong character. Both are free (SIL OFL, already license-checked
in design/brief.md), available from Google Fonts. Download the weights
tokens.md specifies (Archivo 600; IBM Plex Sans 400/500/600; IBM Plex
Mono 400/500), get the `.ttf` files into the repo, then have Claude Code
wire up `UIAppFonts` and flip the constant. Worth doing before judging
any Phase 4 screen visually — until then, "looks a little off" may just
be this, not a real design deviation.

- [x] **T022** — `PhotoPickerField`: wraps `PhotosUI.PhotosPicker` for
      multi-photo selection, returns `[Photo]`.
- [x] **T023** — `ItemFormView`: required fields up front, optional
      fields behind a "more details" disclosure. Used for both add and
      edit.
- [x] **T024** — `ItemListView`: list with filter and sort controls, using
      `ItemListViewModel`.
- [x] **T025** — `ItemDetailView`: displays an item, links to edit
      (reuses `ItemFormView`), delete with confirmation.
- [x] **T026** — Manual verification: add an item end-to-end in the
      simulator (quick-add path and full-detail path), edit it, delete
      it.

## Phase 5 — Dashboard

- [x] **T027** — `DashboardViewModel`: total current value (excluding
      un-valued items), count of un-valued items, total spent, delta,
      category breakdown. Scopable, so spec.md's "drill into a category to
      see the same numbers scoped to it" is this same type with a
      `scope`, not a second screen that could drift from it.
- [x] **T028** — Unit tests for `DashboardViewModel`, including the
      un-valued-exclusion behavior specifically. Note that exclusion
      applies to **spend as well as value**: counting what un-valued items
      cost while leaving their worth out understates the gain by exactly
      their purchase price, which can flip a collection that's up into
      reading as a loss. Mutation-verified.
- [x] **T029** — `DashboardView`.
- [x] **T030** — Manual verification: dashboard numbers match a small set
      of manually-entered test items. Every figure checked against an
      independent calculation of the seed data — total, spend, gain,
      un-valued count, and all four category rows with their shares — at
      both the root scope and drilled into Photography.

## Phase 6 — Wishlist CRUD

- [x] **T031** — `WishlistFormViewModel`: create/edit a `WishlistItem`.
      Blank estimated cost is rejected rather than saved as $0, matching
      the item form's purchase price. New entries append to the manual
      order by taking the highest `sortOrder` in use, not by counting
      rows — counting reuses a position after a deletion.
- [x] **T032** — Unit tests for `WishlistFormViewModel`.
- [x] **T033** — `WishlistViewModel`: fetch/list wishlist items, filter by
      category (same matching as `ItemListViewModel`), search by name,
      manual reordering via `sortOrder`. Reordering is offered only
      against the whole list in its own order — a drag on a filtered or
      cost-sorted list would renumber the visible rows and silently
      reshuffle the rest.
- [x] **T034** — Unit tests for `WishlistViewModel`, including the
      category filter, search, and the dense/unique `sortOrder`
      invariant across many moves.
- [x] **T035** — `WishlistFormView`.
- [x] **T036** — `WishlistView`: list with category filter control and
      reordering. The "See sell plan" row shortcut is deferred to T041
      — it would otherwise point at a screen that doesn't exist yet
      (same reasoning as the T042 deep-links).
- [x] **T036a** — Wishlist photos, added to scope after Phase 6 and
      before Phase 7. `Photo` gains a second optional inverse
      (`wishlistItem`) alongside `item`, `WishlistItem` gains
      `photos: [Photo]?` (`.cascade`, deliberately unlike
      `plannedSaleItems`' `.nullify`), and `WishlistFormView` reuses the
      same `PhotoPickerField` the item form already uses rather than
      growing a second one. Nothing enforces "one parent, never both" at
      the schema level — SwiftData can't express it — so
      `PhotoOwnershipTests` is what holds the line instead of a comment.
- [x] **T036b** — `RowThumbnail`: the reserved photo slot both list
      screens now use, replacing `ItemRow`'s inline version so the two
      can't drift. Empty rows draw a flat placeholder rather than
      collapsing, per plan.md's standing rule. The claim is checked by
      rendering the view and measuring it, not by eye —
      `RowThumbnailTests` also pins that the thumbnail is the user's
      first photo by `sortOrder`, which a row reading `photos.first`
      would get wrong only intermittently.
- [x] **T036c** — `desireToOwn` and `DesireGauge`, added to scope after
      Phase 6 and before Phase 7, same handling as T036a/T036b above.
      `WishlistItem` gains `desireToOwn` (`Int`, default `2`, clamped
      1–3 in the view model), rendered by a new `DesireGauge` — three
      sheared-parallelogram segments, empty tracks left visible,
      brightness ramping across the filled ones, labeled
      "Someday"/"Soon"/"Next" in the form and detail view and unlabeled
      in list rows. Not a recolored `DesireDial`: see plan.md's
      `DesireGauge` entry for why two distinct controls beat two
      near-identical ones meaning different things. Doing this before
      Phase 7 rather than after means `WishlistDetailView` (T038) gets
      built against the final `WishlistItem` shape instead of being
      revisited.

      Display-only, and `DesireToOwnOrderingTests` pins that from both
      sides: neither sort order consults the rating, and no sort option
      is named for it. Adding a rating to a list and deliberately not
      sorting by it is the unusual choice, so it's the one a later
      change is most likely to "fix".

      The three fill tones are `accentBrassDim`, a perceptual half-mix
      of it with `accentBrass`, and `accentBrass` — held between the
      existing tokens rather than reaching for `accentBrassHover`, which
      is a state token rather than a brightness step. Chosen by
      searching the Oklab model, not by eye. Per CLAUDE.md's
      design-correctness rule they're then measured off pixels sampled
      from the gauge rendered at its 14×10pt row size, not off the
      palette: adjacent tones land 0.109 and 0.108 apart and the dimmest
      sits 0.162 from the empty track, against the 0.06 floor
      `DesireDialColorTests` holds the dial's stops to. A separate guard
      distinguishes "sampled the card instead of the fill" from a
      genuine collapse, since both otherwise report zero. The Oklab
      model now lives once in `TestSupport` and serves both the dial
      (palette tokens) and the gauge (sampled pixels), so their
      thresholds stay comparable rather than drifting as two copies.

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

- [x] **T037** — `WishlistDetailViewModel`: load a `WishlistItem`'s own
      fields for display (name, category, estimated cost, notes,
      photos). No ranking or plan logic here.

      Holds the id and re-fetches, like `ItemDetailViewModel` — an entry
      deleted on another device then reads as absent rather than as a
      stale reference, which is the case the guard actually pins. Photo
      ordering, category splitting and the desire-level clamp live here
      rather than in the view: they're correctness rules, not layout.
      Phase 7 lists no separate unit-test task for this view model, but
      CLAUDE.md requires one regardless, so the tests land here — four
      guards mutation-verified (cached load, unsorted photos, unclamped
      level, empty-string notes).
- [x] **T038** — `WishlistDetailView`: plain display of the wishlist
      item's fields, with space reserved in the layout for future
      pricing/trend info, and a single "Find items to sell" button/nav
      link to `SellPlanView`. Photos follow `ItemDetailView`'s
      shrink-the-hero rule, not the list rows' reserved-slot rule — see
      plan.md on why those are two answers to different questions.

      **The "Find items to sell" button is deferred to T041**, the same
      call as `WishlistView`'s row shortcut and T042's deep-links: it
      would otherwise be a control that looks tappable and isn't. Its
      space sits at the end of the scroll, after the market-price block.
      Everything else on the screen is built.

      Three things Design's mock predates, resolved against the newer
      documents rather than the drawing. Its "Priority · Next up" row
      becomes the labeled `DesireGauge` (the brief asks for the gauge
      labeled in the detail view, and a plain row saying the same thing
      in different words invites the two to disagree); it has no photo
      area, so the shrink-the-hero carousel is added; and its Edit and
      Delete toolbar buttons are kept, which is what `delete()` on the
      view model is for — plan.md's "a single button" is about the route
      to the Sell Plan, not the screen's total button count.

      `PhotoCarousel` moved from inside `ItemDetailView` to `Views/
      Shared/` rather than being copied, and tapping a wishlist row now
      opens the item instead of jumping straight to the edit form — the
      same shape as the item list, and what makes this screen reachable
      at all.
- [x] **T039** — `SellPlanViewModel`: given a `WishlistItem`,
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
- [x] **T040** — Unit tests for `SellPlanViewModel`: empty candidate pool,
      a tie resolved correctly, un-valued items excluded from the pool,
      the plan starts with nothing selected on first load, toggling a
      candidate updates the persisted selection and the selected-value
      figure, and re-loading after a toggle reflects the persisted
      selection rather than resetting.
      Two decisions the plan didn't cover, both flagged rather than
      folded in silently. A selected item can drift out of the pool —
      raise its desire-to-keep, or clear its value — so the list carries
      anything currently selected even once it stops qualifying;
      otherwise it's stranded, still counted with no row to switch it
      off from. And the colour cue spec.md permits is exposed as a
      boolean (`selectedValueMeetsCost`), not a figure: a tone needs a
      side, not a distance.

      `SellPlanFramingTests` scans the source for surplus/shortfall/
      remaining-style names, the same technique as
      `NoHardcodedColorsTests`. A behavioural test can show what the type
      does; only a scan shows what it declines to offer, and the way that
      framing comes back is someone adding a computed property because it
      reads tidier at the call site.

      **Mutation testing found a false-passing test here**: the
      "persists on every change" checks refetched on the same
      `ModelContext`, which returns objects carrying unsaved changes, so
      they passed with `save()` removed. Now checked through a second
      context over the same container, plus `hasChanges`.
      `makeInMemoryContainer()` in `TestSupport` exists for that.
      `ModelTests`' `itemsSurviveASaveAndRefetch` had the same flaw and
      is fixed alongside — its name made the claim its body didn't test.

- [ ] **T041** — `SellPlanView`: selectable candidate list (visually
      distinguishing selected from unselected), the selected total shown
      alongside the estimated cost as two comparable figures. A quiet
      color distinction between "meets or exceeds" and "doesn't" is fine;
      no copy nudging the user to select more ("keep going," "check
      another item," or similar) — this is advisory, not a target to
      complete. Reached only via `WishlistDetailView`'s button or
      `WishlistView`'s per-row shortcut — no other entry point. Add the
      row shortcut to `WishlistView` here, deferred from T036 since it
      had nowhere to point until this task exists.

## Phase 8 — Navigation and app shell

- [ ] **T042** — Root `TabView` (Dashboard / Items / Wishlist), each tab
      a `NavigationStack`. Once this exists, wire the two deep-links
      deferred from Phase 5: tapping a leaf category in the dashboard's
      breakdown jumps to the Items tab pre-filtered to that category, and
      the "Value →" callout jumps to Items pre-filtered to un-valued
      items. Both need `ItemListViewModel`'s existing `categoryFilter`
      (or an equivalent un-valued flag) set from outside the view itself
      — a cross-tab navigation concern that couldn't exist before this
      task, not new filtering logic.
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

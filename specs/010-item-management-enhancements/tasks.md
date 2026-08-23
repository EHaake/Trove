# Tasks: Item Management Enhancements

**Status**: Draft — pending review
**Implements**: plan.md in this directory

Ordered, small, independently verifiable. Each task should be
completable (and testable) on its own. If a session ends mid-list,
resume by finding the first unchecked task — don't re-verify everything
above it unless something looks off.

Per `CLAUDE.md`: every implementation task ends with an actual build
and, where tests exist for what changed, an actual test run — reported,
not summarized.

---

## Phase 0 — Verify assumptions against the real source (one-time)

`plan.md` flagged two things it couldn't determine from documents
alone. Both gate later tasks' exact shape, so they come first, before
anything gets built against a guess.

- [ ] **T001** — Check `WishlistView`'s current swipe-to-delete
      implementation: built on `.onDelete`, or already
      `.swipeActions(edge: .trailing)`. *Verify: documented finding.
      Determines whether T016 is needed or skipped.*
- [ ] **T002** — Check `ItemDetailView`'s current delete-confirmation
      alert: does it already name the Sell Plan consequence, or is it
      generic ("are you sure")? *Verify: documented finding. Determines
      whether T010 extracts existing copy or writes new copy from
      `plan.md`'s proposal.*

## Phase 1 — Data model: `Item.sortOrder` (foundational — review every task)

The one schema-touching, hard-to-reverse piece of this spec. Same
review cadence `CLAUDE.md` calls for on data-model work generally.

- [ ] **T003** — Add `sortOrder: Int` (default `0`) to `Item`. *Verify:
      `xcodebuild build` succeeds.*
- [ ] **T004** — Confirm `CloudKitSchemaTests` still validates against
      the updated schema. *Verify: `xcodebuild test` green — this is an
      existing test, not a new one; it should just keep passing.*
- [ ] **T005** — Backfill routine: on launch, if `hasBackfilledItemSortOrder`
      (`UserDefaults`) is unset, fetch all `Item`s ordered by `createdAt`
      ascending, assign sequential `sortOrder` values, save, set the
      flag. Never re-runs once set, regardless of what the stored
      values look like. *Verify: manual — fresh install with existing
      items gets sequential, `createdAt`-ordered `sortOrder` on first
      launch.*
- [ ] **T006** — Unit tests for the backfill routine: the fresh-install
      case (sequential, correctly ordered); the already-flagged case —
      including a version that seeds an already-user-customized order
      *first*, then confirms a second run leaves it completely
      untouched. This second test is the one that matters most: a bug
      here means silently destroying real user data, not just a wrong
      UI state. *Verify: `xcodebuild test` green, including the
      idempotency case specifically, not just the happy path.*

## Phase 2 — Shared utilities (review every phase from here)

- [ ] **T007** — `ManualOrderHelper`: shared logic for computing the
      next-append position, performing a reorder while preserving the
      dense/unique `sortOrder` invariant, and combining any attribute
      comparator with manual order as a tie-break — generic over
      anything exposing `sortOrder: Int`. *Verify: compiles; not yet
      wired to a call site.*
- [ ] **T008** — Refactor `WishlistViewModel`'s existing reorder logic
      to route through `ManualOrderHelper`, rather than keeping a
      separate implementation alongside the new shared one — the whole
      point of T007 is one source of truth, not two. *Verify:
      `WishlistViewModelTests`' existing dense/unique invariant tests
      (`T034`-era) still pass unchanged, now exercising the shared
      helper underneath.*
- [ ] **T009** — Unit tests for `ManualOrderHelper` directly, not just
      indirectly through `WishlistViewModelTests`: next-append
      position, the reorder invariant, tie-break combination logic in
      isolation. *Verify: `xcodebuild test` green.*
- [ ] **T010** — `ItemDeleteCopy`: shared delete-confirmation copy for
      `Item`, to be read by both `ItemListView`'s swipe path (T015) and
      `ItemDetailView`'s overflow-menu path (T017). Shape depends on
      T002's finding: extract existing copy if `ItemDetailView` already
      names the Sell Plan consequence, or use `plan.md`'s proposed copy
      ("This item will be removed, along with its photos. If it's part
      of a Sell Plan, it'll no longer be included there.") if not.
      *Verify: single source exists; not yet wired to either call site.*
- [ ] **T011** — Test confirming `ItemDeleteCopy`'s content actually
      names the Sell Plan consequence, mirroring however
      `WishlistDeleteCopy`'s content is already asserted today.
      *Verify: `xcodebuild test` green.*

## Phase 3 — Item delete parity

- [ ] **T012** — Convert `ItemListView` from `ScrollView`/`LazyVStack`
      to `List`, matching `WishlistView`'s existing styling exactly:
      plain list style, hidden separators, clear row backgrounds,
      custom insets, tap-gesture navigation instead of `NavigationLink`.
      No swipe actions wired yet — container conversion only, kept
      separate from T015/T023 so a regression here is easy to isolate.
      *Verify: app builds; `ItemListView` renders visually identical to
      before in the simulator; existing filter/sort/search still work.*
- [ ] **T013** — `ItemListViewModel.delete(id:)`. Must not be inline in
      a view — `DeletionGuardTests`' existing structural rule ("no view
      deletes from the store directly") extends to this new path from
      day one. *Verify: `xcodebuild build` succeeds; `DeletionGuardTests`
      still passes with the new path included.*
- [ ] **T014** — Unit tests for `delete(id:)`, through a second
      `ModelContext` over the same container — measures the store, not
      the context, per the pattern `SellPlanViewModelTests` already
      established in `001` for exactly this reason. *Verify: `xcodebuild
      test` green.*
- [ ] **T015** — Wire `.swipeActions(edge: .trailing)` on `ItemListView`
      rows: Delete, behind `ItemDeleteCopy`'s confirmation alert.
      *Verify: manual — swipe left on an item row, confirm the alert
      appears with the correct copy, confirming deletes the item.*
- [ ] **T016** — *Conditional on T001.* If `WishlistView`'s swipe-delete
      isn't already `.swipeActions`-based, convert it to be, unifying
      both lists onto one mechanism. Skip entirely if T001 found it
      already is. *Verify (if not skipped): `WishlistViewModelTests`'
      existing delete tests still pass; manual swipe-delete on
      `WishlistView` shows the same alert and deletes correctly as
      before the conversion.*
- [ ] **T017** — Update `ItemDetailView`'s delete confirmation to read
      from `ItemDeleteCopy` instead of whatever it currently has.
      *Verify: manual — delete via the detail screen's overflow menu,
      confirm the alert matches the swipe path's alert exactly, word
      for word.*
- [ ] **T018** — Manual verification: delete an item (via both swipe and
      detail-menu) that's currently selected in an active Sell Plan.
      Confirm it silently drops from that plan — existing cascade
      behavior, unchanged — and that the alert named this consequence
      before the delete happened, on both entry points.

## Phase 4 — Edit/Duplicate swipe actions

- [ ] **T019** — `ItemListViewModel.duplicate(id:)`: copy every field
      except serial number (cleared); include photos; don't inherit
      Sell Plan membership; place adjacent to the original in manual
      order via `ManualOrderHelper`. *Verify: `xcodebuild build`
      succeeds.*
- [ ] **T020** — Unit tests for `duplicate(id:)`: field-copy correctness;
      serial number cleared; photos actually copied as new `Photo` rows
      with duplicated `.externalStorage` data (confirms the
      storage-duplication behavior `plan.md` flagged, rather than
      assuming it); Sell Plan non-inheritance; manual-order placement.
      *Verify: `xcodebuild test` green.*
- [ ] **T021** — `WishlistViewModel.duplicate(id:)`, mirroring T019 for
      wishlist items (no serial number to clear; otherwise identical
      shape). *Verify: `xcodebuild build` succeeds.*
- [ ] **T022** — Unit tests for `WishlistViewModel.duplicate(id:)`,
      mirroring T020. *Verify: `xcodebuild test` green.*
- [ ] **T023** — Wire `.swipeActions(edge: .leading)` on `ItemListView`:
      Edit (opens `ItemFormView` pre-filled) and Duplicate. *Verify:
      manual — swipe right, tap Edit, confirm the form opens correctly
      pre-filled; tap Duplicate, confirm a correct copy appears in the
      list with no navigation and no confirmation step.*
- [ ] **T024** — Wire `.swipeActions(edge: .leading)` on `WishlistView`:
      Edit and Duplicate, same shape as T023 for wishlist items.
      *Verify: manual, same checks as T023 against `WishlistFormView`.*

## Phase 5 — Manual reorder parity

- [ ] **T025** — Add a "Yours" case to `ItemListViewModel`'s
      sort-option type; a reorder method routing through
      `ManualOrderHelper`. *Verify: `xcodebuild build` succeeds.*
- [ ] **T026** — Unit tests: dense/unique invariant on
      `ItemListViewModel`'s new reorder method (mirroring
      `WishlistViewModelTests`'s existing shape via the shared helper);
      confirms drag-reorder is only meaningful while sort is "Yours."
      *Verify: `xcodebuild test` green.*
- [ ] **T027** — Wire `.onMove` on `ItemListView`, attached only when
      the active sort is "Yours" — hidden, not just disabled,
      otherwise. *Verify: manual — select "Yours," drag to reorder,
      confirm it persists across a relaunch; select any other sort,
      confirm dragging is unavailable.*
- [ ] **T028** — Remove `WishlistView`'s "Reorder" button from the
      header entirely. *Verify: manual — button no longer appears
      anywhere in the UI; press-and-hold-drag still works on
      `WishlistView` exactly as before, with no separate entry point
      needed.*
- [ ] **T029** — Manual verification, both screens: switching away from
      "Yours" and back preserves the manual order exactly as last
      arranged; dragging is unavailable while filtered or searched.

## Phase 6 — Wishlist sort expansion

- [ ] **T030** — Remove `WishlistViewModelTests.theSortControlOffersNoRatingOption`.
      Commit message states plainly that this reverses a `001` decision
      and why (see `spec.md`'s Resolved decisions) — an honest reversal,
      not a silent deletion. *Verify: test suite no longer contains it;
      commit message reviewed for the explanation before merging.*
- [ ] **T031** — Add "Desire" and "Alphabetical" sort cases to
      `WishlistViewModel`, each combined with manual order as tie-break
      via `ManualOrderHelper`. Sort directions per `plan.md`'s proposed
      defaults (Cost ascending, Desire highest-first, Alphabetical A→Z)
      unless overridden before this task starts. *Verify: `xcodebuild
      build` succeeds.*
- [ ] **T032** — Unit tests: correctness of both new sorts; their
      tie-break specifically (construct same-tier items, confirm manual
      order resolves them consistently); composability with category
      filtering, mirroring `ItemListViewModel`'s existing
      `filteringAndSortingApplyTogether` pattern. *Verify: `xcodebuild
      test` green.*
- [ ] **T033** — Manual verification: both new sort options appear and
      produce correct order; ties resolve by manual order visibly;
      filtering to a category while sorted by Desire or Alphabetical
      narrows correctly without losing the sort.

## Phase 7 — Visual refinement (blocked on the design-brief addendum)

**Do not start this phase until `design/brief-addendum-010.md` has
actually been through Claude Design and produced real screens/tokens.**
Everything below assumes that output exists — building against a guess
here means redoing it once real output arrives.

- [ ] **T034** — Row treatment (both lists), per Design's output.
      *Verify: manual, checked against Design's actual output **and**
      against `brief.md`'s no-bevel/no-drop-shadow constraint directly
      — Design's session may not perfectly reflect current reality (see
      the addendum's own note on this), so don't treat its output as
      automatically correct. Flag and resolve toward correctness, not
      silently, if the two disagree.*
- [ ] **T035** — Sort picker visual treatment (both screens, four
      options each), per Design's output. *Verify: manual, both
      screens.*
- [ ] **T036** — Swipe-action iconography (Edit, Duplicate, Delete), per
      Design's output. *Verify: manual, both screens.*
- [ ] **T037** — `DesireGauge` legibility fix, per Design's output.
      *Verify: manual — check the unlabeled in-row version specifically
      (the one the fix targets), confirm it reads as a desire indicator
      without prior context.*

## Phase 8 — Full regression and close-out

- [ ] **T038** — Full manual click-through: swipe-delete and
      detail-menu delete on both entities (confirm identical alert copy
      per entity); swipe-edit and swipe-duplicate on both lists; manual
      reorder on both lists via "Yours," including switching sorts away
      and back; all four wishlist sort options, including a tie case;
      the Phase 7 visual treatment, on a real device.
- [ ] **T039** — Invoke the `skeptical-reviewer` subagent against the
      whole spec, per this project's established close-out convention.
      *Verify: findings resolved or explicitly recorded, per `001`'s own
      pre-merge-review pattern — not silently dropped either way.*

---

## Handoff note

Once this file is reviewed and approved, hand it to Claude Code with
something like:

> Read `CLAUDE.md` and `specs/010-item-management-enhancements/
> {spec,plan,tasks}.md`, then begin implementing starting at T001. For
> Phases 0–1, stop for review after each individual task — this is
> verification and schema-touching work. From Phase 2 onward, stop
> after each phase instead. Phase 7 needs the design-brief addendum's
> real output first; if that isn't ready yet, do Phase 8's regression
> pass against everything through Phase 6, and come back to Phase 7
> once Design's output exists.

## Model and effort per phase

Skipped deliberately, per this project's own established practice
(see `DECISIONS.md`): phase-tiered model/effort assignment was tried on
`001` and abandoned partway through — several tasks assumed to be
safely mechanical benefited from the top tier in ways that weren't
obvious in advance. Current practice is the best available model at
maximum effort throughout. Review *cadence* (above, per phase) is a
separate axis from model tier and still applies.

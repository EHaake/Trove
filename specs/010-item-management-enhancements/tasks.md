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

- [x] **T001** — Check `WishlistView`'s current swipe-to-delete
      implementation: built on `.onDelete`, or already
      `.swipeActions(edge: .trailing)`. *Verify: documented finding.
      Determines whether T016 is needed or skipped.*
      **Finding: `.onDelete`-based — T016 is needed.** The trailing
      swipe comes from `.onDelete { requestDeletion(at:) }` attached to
      the row `ForEach` (`WishlistView.swift`, `rows`), not from
      `.swipeActions`. The staging/confirm layer is already the right
      shape and carries over unchanged: the closure resolves the offset
      to an item, stages it in `pendingDeletion`, and the shared
      `WishlistDeleteCopy` alert commits via `viewModel.delete(id:)` —
      only the reveal mechanism differs between the lists. Two details
      T016 should carry: (1) `.onDelete` currently serves a *second*
      entry point — the edit-mode minus button, driven by the "Reorder"
      toggle's `editMode` binding. T028 removes that toggle, so nothing
      is lost by the conversion, but T016 and T028's ordering matters if
      the minus button is meant to keep working in between. (2) T016
      isn't just mechanism-unification: T036 wires custom iconography
      into the swipe buttons, which `.onDelete`'s system-provided button
      can't host — `.swipeActions` is a prerequisite for it on this
      screen.
- [x] **T002** — Check `ItemDetailView`'s current delete-confirmation
      alert: does it already name the Sell Plan consequence, or is it
      generic ("are you sure")? *Verify: documented finding. Determines
      whether T010 extracts existing copy or writes new copy from
      `plan.md`'s proposal.*
      **Finding: halfway — T010 writes the missing half rather than
      extracting or starting over.** The alert is hardcoded inline
      (`ItemDetailView.swift`, the `.alert` in `body`), no shared
      constant: title "Delete \(name)?", message "Its photos go too.
      This can't be undone.", buttons Delete (destructive) / Keep
      (cancel). So it names the photo cascade and permanence, but not
      the Sell Plan consequence spec.md requires — neither generic nor
      sufficient. Reusable: "Its photos go too." is word-for-word the
      sentence `WishlistDeleteCopy.message` opens with, so the voice is
      already converged; T010's natural shape is extending the existing
      copy with a sell-plan sentence, not adopting `plan.md`'s
      from-scratch proposal wholesale. Two details for T010/T017:
      (1) verb asymmetry on screen today — the item alert says
      Delete/Delete where the wishlist says Remove/Remove ("Keep" is
      shared); T017 makes the two *item* entry points match word for
      word, but whether the two entities should share one verb is a
      conscious T010 call, not an accident to preserve. (2) "This can't
      be undone." exists only on the item side — keep/drop is T010's
      call, worth making deliberately since `011-recycle-bin` would
      eventually make the sentence false.
      Both calls settled in review (2026-08-23): the verb unifies on
      "Delete" across both entities, and the undo sentence stays — and
      is added to the wishlist side too. Recorded at T010/T010a.

## Phase 1 — Data model: `Item.sortOrder` (foundational — review every task)

The one schema-touching, hard-to-reverse piece of this spec. Same
review cadence `CLAUDE.md` calls for on data-model work generally.

Cadence refined in review (2026-08-23), after T003's individual stop:
T004 batches with T005 rather than getting its own stop — it's purely
confirmatory, no new logic, nothing independent to review. T005 and
T006 keep their individual stops. T005 specifically is the one task in
this whole spec where a bug means silently destroying real user data —
which is the actual reason this phase warranted tight review in the
first place, not T003 or T004 on their own merits.

- [x] **T003** — Add `sortOrder: Int` (default `0`) to `Item`. *Verify:
      `xcodebuild build` succeeds.*
      Done 2026-08-23: stored property plus an `init` parameter,
      mirroring `WishlistItem.sortOrder`'s exact shape (scalar with a
      default, no optionality needed for CloudKit). Placed with the
      other user-facing scalars; doc comment notes pre-`010` rows sit
      at 0 until T005's backfill. `** BUILD SUCCEEDED **`.
- [x] **T004** — Confirm `CloudKitSchemaTests` still validates against
      the updated schema. *Verify: `xcodebuild test` green — this is an
      existing test, not a new one; it should just keep passing.*
      Done 2026-08-23, batched with T005 per the cadence note above:
      `-only-testing:TroveTests/CloudKitSchemaTests` against the schema
      with `Item.sortOrder` — "✔ Test schemaMeetsCloudKitRequirements()
      passed", `** TEST SUCCEEDED **`. The account-unavailable CloudKit
      log noise in the run is the simulator's (no iCloud account), not
      the validator's — the test needs no account, per its own doc
      comment.
- [x] **T005** — Backfill routine: on launch, if `hasBackfilledItemSortOrder`
      (`UserDefaults`) is unset, fetch all `Item`s ordered by `createdAt`
      ascending, assign sequential `sortOrder` values, save, set the
      flag. Never re-runs once set, regardless of what the stored
      values look like. *Verify: manual — fresh install with existing
      items gets sequential, `createdAt`-ordered `sortOrder` on first
      launch.*
      Done 2026-08-23. `ItemSortOrderBackfill` lives in
      `TroveStore.swift` (plan.md's file structure says no new files
      beyond the two named), called from `TroveApp.init` with `try?` —
      the flag flips only *after* a successful save, so a failed
      backfill stays unclaimed and the next launch retries. One
      decision plan.md didn't anticipate: the ephemeral (`-uiTesting`)
      store is skipped entirely and never sets the flag — a UI-test
      launch that burned the flag against its throwaway store would
      stop the device's real store from ever being backfilled.
      Verified on the simulator against the real persistent store, all
      three legs: (1) first launch on the empty store ran it and set
      the flag; (2) with the flag set and three seeded items sitting
      at 0/0/0, a relaunch left them untouched — no re-run, even
      though the values don't "look backfilled"; (3) with the flag
      removed (sim shut down, plist edited, rebooted — the
      fresh-install-with-existing-items simulation), the next launch
      assigned Alpha=0, Bravo=1, Charlie=2 in `createdAt` order and
      set the flag again. Read from the store file with sqlite3, not
      inferred from the UI.
- [x] **T006** — Unit tests for the backfill routine: the fresh-install
      case (sequential, correctly ordered); the already-flagged case —
      including a version that seeds an already-user-customized order
      *first*, then confirms a second run leaves it completely
      untouched. This second test is the one that matters most: a bug
      here means silently destroying real user data, not just a wrong
      UI state. *Verify: `xcodebuild test` green, including the
      idempotency case specifically, not just the happy path.*
      Done 2026-08-23: `ItemSortOrderBackfillTests`, 7 tests. Beyond
      the named cases: both persistent modes run (a fallen-back
      `.localOnly` device still backfills), the ephemeral store never
      runs and never burns the flag (T005's finding, now pinned; also
      recorded in plan.md's Backfill section in this commit), and the
      flag key string is asserted as a persisted contract — renaming
      it re-runs the backfill on every real device. Every persisted-
      state assertion reads through a second `ModelContext` so a
      deleted `save()` can't false-pass (001's same-context lesson),
      and the fresh-install test inserts items in a different order
      than their `createdAt`s so a dropped sort descriptor can't pass
      by luck (001's tie-break lesson). Mutation-verified per plan.md's
      testing strategy — seven mutations (save deleted, flag-set
      deleted, short-circuit deleted, ephemeral guard deleted, sort
      descriptor dropped, index→0, sort reversed), each `TEST FAILED`
      with zero compile errors, caught by the test designed for it.
      Honestly recorded gap: the failed-save-leaves-flag-unset leg is
      untested — SwiftData offers no way to make an in-memory save
      throw without faking `ModelContext`, which it doesn't allow; the
      suite's doc comment says so. Full suite after: 487 tests in 78
      suites + 5 UI tests, `** TEST SUCCEEDED **`.

## Phase 2 — Shared utilities (review every phase from here)

Cadence, clarified in review (2026-08-23): the per-phase stop is the
default from here on — but escalation-worthy findings (CLAUDE.md's
triggers: infeasibility/rework risk, or a direction-changing unknown
that Plan Mode and the skeptical-reviewer can't resolve) surface
immediately, not at phase-end. Routine ambiguity resolves the normal
way and gets reported at the end.

- [x] **T007** — `ManualOrderHelper`: shared logic for computing the
      next-append position, performing a reorder while preserving the
      dense/unique `sortOrder` invariant, and combining any attribute
      comparator with manual order as a tie-break — generic over
      anything exposing `sortOrder: Int`. *Verify: compiles; not yet
      wired to a call site.*
      Done 2026-08-23: `Extensions/ManualOrderHelper.swift` — a
      `ManuallyOrdered` protocol (class-bound; positions are assigned
      in place on `@Model` objects), `nextPosition` (max + 1),
      `reorder`, `renumber` exposed on its own (duplication will need
      it without a move), and `areInOrder` with a nil-means-tie
      primary. `Item` and `WishlistItem` conform. Build succeeded.
- [x] **T008** — Refactor `WishlistViewModel`'s existing reorder logic
      to route through `ManualOrderHelper`, rather than keeping a
      separate implementation alongside the new shared one — the whole
      point of T007 is one source of truth, not two. *Verify:
      `WishlistViewModelTests`' existing dense/unique invariant tests
      (`T034`-era) still pass unchanged, now exercising the shared
      helper underneath.*
      Done 2026-08-23, with one scope note: the task names
      `WishlistViewModel`'s reorder, but next-append lived in
      `WishlistFormViewModel.nextSortOrder` — leaving it inline would
      have kept two implementations of a job T007 exists to own once,
      so both call sites moved. All 487 unit tests passed unchanged.
- [x] **T009** — Unit tests for `ManualOrderHelper` directly, not just
      indirectly through `WishlistViewModelTests`: next-append
      position, the reorder invariant, tie-break combination logic in
      isolation. *Verify: `xcodebuild test` green.*
      Done 2026-08-23: 8 tests against a plain class through the
      protocol, no SwiftData — including the deletion-gap fixture
      ([0, 5] → 6) that fails a count-based next-position. Mutations
      run against the *full* unit target doubled as proof of T008's
      wiring: count-based nextPosition reddened these tests and
      `WishlistFormViewModel`'s saving suite; gutting renumber
      reddened these and the T034-era ordering suite; inverting the
      tie-break reddened only these — correct, nothing wires
      `areInOrder` until Phases 5–6. Zero compile errors across all
      three.
- [x] **T010** — `ItemDeleteCopy`: shared delete-confirmation copy for
      `Item`, to be read by both `ItemListView`'s swipe path (T015) and
      `ItemDetailView`'s overflow-menu path (T017). Shape depends on
      T002's finding: extract existing copy if `ItemDetailView` already
      names the Sell Plan consequence, or use `plan.md`'s proposed copy
      ("This item will be removed, along with its photos. If it's part
      of a Sell Plan, it'll no longer be included there.") if not.
      *Verify: single source exists; not yet wired to either call site.*
      Settled (2026-08-23), superseding the two branches above: T002
      found the alert halfway, so T010 extends the existing inline copy
      (title "Delete \(name)?", buttons "Delete"/"Keep", message "Its
      photos go too. This can't be undone.") with the Sell Plan
      consequence sentence spec.md requires — rather than extracting
      as-is or writing plan.md's proposal from scratch. Item side only;
      the wishlist-side copy changes settled in the same review are
      T010a's, not folded in here.
      Done 2026-08-23 (commit e7721dd; record added late — the commit
      staged only the new file and this entry was never updated at
      execution): `Trove/Models/ItemDeleteCopy.swift`, beside
      `WishlistDeleteCopy` per plan.md's "mirrors wherever it already
      lives". Message: "Its photos go too. Any sell plan it's on drops
      it. This can't be undone." — the settled extension, T011 pins
      it. Wired at T015/T017.
- [x] **T010a** — Apply the two settled delete-copy decisions to
      `WishlistDeleteCopy` — a change to already-shipped, tested
      content, split out from T010 the same way T025a is split from
      T025: the title verb and confirm button change from "Remove" to
      "Delete" ("Keep" stays), matching `ItemDetailView`'s existing
      alert, and "This can't be undone." is added to the message —
      already true there today. Includes updating any existing tests
      that assert on the current "Remove" strings or on the message
      without the undo sentence (001's copy assertions —
      `DeletionGuardTests`' shared-copy checks and
      `WishlistDeletionTests` — are the known suspects; grep for the
      old strings to catch any others). Note: spec.md currently says
      the wishlist alert is unchanged in two places — the delete flow's
      "What the alert says is unchanged by this spec on the wishlist
      side" paragraph, and the criterion beginning "Deleting a wishlist
      item continues to show its existing confirmation alert" — both
      predate this decision and need amending when this task executes,
      so the docs don't contradict what ships. *Verify: `xcodebuild
      test` green; grep afterward confirms no live assertion or
      delete-confirmation string still reads "Remove" (unrelated uses
      of the word are fine); the wishlist alert on both entry points
      shows the new verb and the undo sentence.*
      Done 2026-08-23. Copy changed as settled; both doc-comment
      references updated (including a stale pointer to
      "WishlistDeleteCopyTests" — the real home of the content
      assertions is `DeletionGuardTests`). Finding worth keeping: the
      anticipated test updates didn't exist — all 495 tests stayed
      green while "Remove" became "Delete", because nothing pinned the
      verb, title, or exact message; only the two consequence halves
      were asserted. The copy was under-pinned, so T010a *added* the
      missing guards instead: `theMessageKeepsAllThreePromises` (photos,
      sell plan, undone) and `theConfirmButtonAndTitleSayDelete`, both
      mutation-verified red (verb reverted to "Remove" → red;
      undo-sentence dropped → red; zero compile errors). Grep confirms
      the only remaining "Remove" string is `PhotoPickerField`'s
      "Remove photo" accessibility label — unrelated, allowed. Both
      entry points verified on the simulator showing the new alert
      word for word: the list swipe and the detail overflow both
      present "Delete Strymon Flint?" / "Its photos go too. Anything
      on its sell plan stays where it is. This can't be undone." /
      Keep + Delete. The spec.md amendment this note anticipated had
      already landed in review (commit 759c523: flow paragraph,
      criterion, and a Resolved decision) — nothing further needed.
- [x] **T011** — Test confirming `ItemDeleteCopy`'s content actually
      names the Sell Plan consequence, mirroring however
      `WishlistDeleteCopy`'s content is already asserted today.
      *Verify: `xcodebuild test` green.*
      Done 2026-08-23: `ItemDeleteCopyTests`, three tests mirroring
      `DeletionGuardTests`' promise-by-promise shape, plus one guard
      the mirror alone can't provide: the two entities' sell-plan
      lines run in opposite directions and both contain "sell plan",
      so a wishlist-message paste would pass every contains-check
      while telling the user the opposite of the truth —
      `theSellPlanLineStatesTheDropNotTheSpare` pins the direction and
      asserts the two messages differ. Mutation-verified: pasting the
      wishlist message in → red on all three direction assertions;
      deleting the sell-plan sentence → red on the promise check. Full
      suite: 499 tests in 80 suites + 5 UI tests, `** TEST SUCCEEDED **`.

## Phase 3 — Item delete parity

- [x] **T012** — Convert `ItemListView` from `ScrollView`/`LazyVStack`
      to `List`, matching `WishlistView`'s existing styling exactly:
      plain list style, hidden separators, clear row backgrounds,
      custom insets, tap-gesture navigation instead of `NavigationLink`.
      No swipe actions wired yet — container conversion only, kept
      separate from T015/T023 so a regression here is easy to isolate.
      *Verify: app builds; `ItemListView` renders visually identical to
      before in the simulator; existing filter/sort/search still work.*
      Done 2026-08-24: rows block mirrors `WishlistView.rows` line for
      line; navigation swapped to the wishlist's tap-gesture +
      item-binding shape (a List row's `NavigationLink` brings its own
      styling). Verified against a pre-conversion screenshot: identical
      rows, spacing, insets — the stack sits ~4pt lower from the List's
      half-gap top inset, the same accepted trade the wishlist made at
      its own conversion. Tap-through, search, chips confirmed working.
- [x] **T013** — `ItemListViewModel.delete(id:)`. Must not be inline in
      a view — `DeletionGuardTests`' existing structural rule ("no view
      deletes from the store directly") extends to this new path from
      day one. *Verify: `xcodebuild build` succeeds; `DeletionGuardTests`
      still passes with the new path included.*
      Done 2026-08-24: mirrors `WishlistViewModel.delete(id:)` exactly
      (guard by id, delete, save with failure surfaced, reload).
      `DeletionGuardTests` green with the new path in place.
- [x] **T014** — Unit tests for `delete(id:)`, through a second
      `ModelContext` over the same container — measures the store, not
      the context, per the pattern `SellPlanViewModelTests` already
      established in `001` for exactly this reason. *Verify: `xcodebuild
      test` green.*
      Done 2026-08-24: `ItemDeletionTests`, 4 tests on
      `WishlistDeletionTests`' shape. The cascade test points the
      nullify the other way — photos cascade, the planning wishlist
      entry survives with its selection shrunk. Mutation-verified:
      removing `save()` reddened both second-context tests while the
      same-context ones stayed green — the false-pass shape the
      pattern exists to prevent, demonstrated live.
- [x] **T015** — Wire `.swipeActions(edge: .trailing)` on `ItemListView`
      rows: Delete, behind `ItemDeleteCopy`'s confirmation alert.
      *Verify: manual — swipe left on an item row, confirm the alert
      appears with the correct copy, confirming deletes the item.*
      Done 2026-08-24: `.swipeActions(edge: .trailing)` stages
      `pendingDeletion`; the alert commits through the view model. A
      full swipe stages the same way, so no gesture skips the
      consequence line. Manual: swipe on Alpha showed the
      `ItemDeleteCopy` alert word for word; confirming deleted it.
      Addendum (2026-08-24 review): the button had shipped brass — the
      root tint cascade, see the Phase 4 header note — and now carries
      `.tint(theme.colors.accentRust)` explicitly; pixel-sampled
      `#9C4A34` exact against tokens.md.
- [x] **T016** — *Conditional on T001.* If `WishlistView`'s swipe-delete
      isn't already `.swipeActions`-based, convert it to be, unifying
      both lists onto one mechanism. Skip entirely if T001 found it
      already is. *Verify (if not skipped): `WishlistViewModelTests`'
      existing delete tests still pass; manual swipe-delete on
      `WishlistView` shows the same alert and deletes correctly as
      before the conversion.*
      Considered and declined in review (2026-08-23): a VoiceOver
      spot-check in this verify step. Raised because the conversion
      trades `.onDelete`'s system-synthesized "Delete" custom action
      for hand-built buttons (per Apple's `swipeActions` doc); declined
      on record, not overlooked.
      Executed (not skipped), 2026-08-24, per T001's finding. Both
      lists now share one mechanism, and T036 gets a button it can
      restyle. Recorded consequence from T001 carried forward: the
      edit-mode minus button rode on `.onDelete`, so between T016 and
      T028 edit mode offers reordering only. Manual: swipe on a
      throwaway entry showed the same alert as before the conversion
      and deleted correctly; existing delete tests unchanged and
      green.
      Addendum (2026-08-24 review): same brass-button fix and
      pixel-verification as T015's — see the Phase 4 header note.
- [x] **T017** — Update `ItemDetailView`'s delete confirmation to read
      from `ItemDeleteCopy` instead of whatever it currently has.
      *Verify: manual — delete via the detail screen's overflow menu,
      confirm the alert matches the swipe path's alert exactly, word
      for word.*
      Done 2026-08-24: inline strings replaced by `ItemDeleteCopy`
      reads. `DeletionGuardTests` gains the item-side
      `bothItemDeleteRoutesReadTheSharedCopy` mirror (plan.md's named
      extension), mutation-verified by reverting the detail title to
      an inline string — red on exactly that path. Honesty note: the
      first mutation run filtered to the wrong suite via
      `-only-testing` and proved nothing; rerun against
      `DeletionGuardTests` before trusting it. Manual: detail alert
      matches the swipe path word for word (Bravo).
- [x] **T018** — Manual verification: delete an item (via both swipe and
      detail-menu) that's currently selected in an active Sell Plan.
      Confirm it silently drops from that plan — existing cascade
      behavior, unchanged — and that the alert named this consequence
      before the delete happened, on both entry points.

      Done 2026-08-24, full transcript: Alpha ($150) and Bravo ($200)
      valued and selected into Strymon Flint's plan ($350, 2 of 2).
      Deleted Alpha via the list swipe — alert named the sell-plan
      drop before committing; the plan silently read $200, 1 of 1.
      Deleted Bravo via the detail overflow — same alert word for
      word; the plan silently read $0, 0 of 0 with the candidates
      empty state. No errors, no residue, cascade behavior unchanged —
      exactly what the alert promises on both entry points.
## Phase 4 — Edit/Duplicate swipe actions

Carried forward from the Phase 3 review (2026-08-24): `ContentView`'s
root brass `.tint` cascades into every `.swipeActions` button and
overrides role-default styling — it turned both Delete buttons brass
until each got an explicit `.tint(theme.colors.accentRust)`. T023/T024
inherit the same behavior: every new swipe button must carry its own
explicit tint from tokens.md's "Swipe-action rows" table (Edit =
`divider` #3A3B3E, Duplicate = `surfaceInset` #26272A), or it ships
brass.

- [x] **T019** — `ItemListViewModel.duplicate(id:)`: copy every field
      except serial number (cleared); include photos; don't inherit
      Sell Plan membership; place adjacent to the original in manual
      order via `ManualOrderHelper`. *Verify: `xcodebuild build`
      succeeds.*
      Done 2026-08-24: spec.md's field rules exactly — serial cleared,
      photos as genuinely new `Photo` rows, no plan inheritance,
      adjacency via `ManualOrderHelper.insert(after:in:)`, added to the
      helper (T019's own text sanctions it) so T021 shares the
      placement instead of re-implementing it. Placement operates on
      the whole collection in manual order, never the filtered slice.
      Build succeeded.
- [x] **T020** — Unit tests for `duplicate(id:)`: field-copy correctness;
      serial number cleared; photos actually copied as new `Photo` rows
      with duplicated `.externalStorage` data (confirms the
      storage-duplication behavior `plan.md` flagged, rather than
      assuming it); Sell Plan non-inheritance; manual-order placement.
      *Verify: `xcodebuild test` green.*
      Done 2026-08-24: `ItemDuplicationTests`, 5 tests, each rule
      measured separately, plus a direct `insert(after:)` test in
      `ManualOrderHelperTests`. Sharing a photo reference isn't
      aliasing under one-photo-one-parent — it reparents the
      original's photo onto the copy — and the photo test is built to
      catch exactly that. Four mutations, each red on its designed
      test with zero compile errors: serial carried over, photos
      shared, plan membership inherited, placement appended at end.
- [x] **T021** — `WishlistViewModel.duplicate(id:)`, mirroring T019 for
      wishlist items (no serial number to clear; otherwise identical
      shape). *Verify: `xcodebuild build` succeeds.*
      Done 2026-08-24: the mirror through the same helper — no serial
      exists to clear; the copy's own `plannedSaleItems` starts empty.
      Build succeeded.
- [x] **T022** — Unit tests for `WishlistViewModel.duplicate(id:)`,
      mirroring T020. *Verify: `xcodebuild test` green.*
      Done 2026-08-24: `WishlistDuplicationTests`, 5 tests, the
      non-inheritance pointed the other way — the copy's own selection
      empty, the original's surviving — so duplicating a wishlist
      entry can't double-count the gear its original planned to sell.
      Spot-mutation (photos shared) red, zero compile errors.
- [x] **T023** — Wire `.swipeActions(edge: .leading)` on `ItemListView`:
      Edit (opens `ItemFormView` pre-filled) and Duplicate. On-screen
      button text is "Copy," not "Duplicate" — "Duplicate" stays the
      name used in code and docs (`duplicate(id:)`, this file), "Copy"
      is Design's chosen on-screen string specifically, per `plan.md`'s
      Resolved decisions. *Verify: manual — swipe right, tap Edit,
      confirm the form opens correctly pre-filled; tap Copy, confirm a
      correct duplicate appears in the list with no navigation and no
      confirmation step.*
      Done 2026-08-24: Edit nearest the edge, Copy second (the mock's
      order; full swipe triggers Edit — verified live, form opened
      pre-filled with the real item). Tints pixel-sampled byte-exact:
      Edit #3A3B3E (`divider`), Copy #26272A (`surfaceInset`), per the
      Phase 4 header note. Copy produced a duplicate in place, no
      navigation, no confirmation.
- [x] **T024** — Wire `.swipeActions(edge: .leading)` on `WishlistView`:
      Edit and Duplicate, same shape and same "Copy" button-text note as
      T023, for wishlist items. *Verify: manual, same checks as T023
      against `WishlistFormView`.*

      Done 2026-08-24: same wiring, verified live against
      `WishlistFormView` — Edit pre-filled with the real entry; Copy
      landed the duplicate directly below its original in manual
      order ("Yours"), visibly adjacent, no navigation. Full suite
      after the phase: 515 tests in 83 suites + 5 UI tests,
      `** TEST SUCCEEDED **`.
## Phase 5 — Manual reorder parity

- [x] **T025** — Add a "Custom" case to `ItemListViewModel`'s
      sort-option type; a reorder method routing through
      `ManualOrderHelper`. *Verify: `xcodebuild build` succeeds.*
      Done 2026-08-24: `.custom` case leads the menu (wishlist's
      convention; default stays Date), `canReorder` with this screen's
      third narrowing (un-valued filter), `move` through the helper.
      Scope note: `ItemFormViewModel` never assigned `sortOrder` — every
      new item landed at 0, so Custom would pile new purchases at the
      top; plan.md's helper section covers next-append for both
      entities, the task list just never named the item form. Wired
      like the wishlist form's: max + 1 on create, untouched on edit.
- [x] **T025a** — Rename `WishlistViewModel`'s *existing*, already-shipped
      "Yours" sort case/display string to "Custom" — a rename, not an
      addition, since this case already exists and ships in production
      today. Confirmed directly by the person steering this project: the
      name "Yours" was unclear even to them in early use of the real app,
      which is why "Custom" was proposed to Design in the first place.
      Includes updating any existing `WishlistViewModelTests` that
      reference the old case name or assert on the string "Yours"
      anywhere (sort-option tests, snapshot-style assertions, etc.) — a
      rename that leaves a stale test still passing on the old string is
      a false negative waiting to happen. *Verify: `xcodebuild build`
      succeeds; `xcodebuild test` green; grep the test target for
      "Yours" afterward and confirm nothing real remains (a historical
      comment explaining the rename is fine, a live assertion is not).*
      Done 2026-08-24, with a correction on the record: the case and
      label renamed (`manual`→`custom`, "Yours"→"Custom"), two `.manual`
      test references updated — and the first commit claimed no
      assertion pinned the old name and landed before its own test run
      reported. The suite then failed:
      `theSortControlOffersNoRatingOption` pins the case set by
      *rawValue strings*, invisible to the case-name grep. True finding:
      the label was unpinned, the rawValues were pinned. That test
      updates to ["custom", "cost"] (a rename doesn't reverse its
      no-rating rule — T030's reversal keeps its own commit), and
      `theManualOptionReadsCustomOnBothLists` now pins the label on
      both lists. Grep: the only surviving "Yours" is the historical
      comment the verify explicitly permits. rawValue persisted
      nowhere.
- [x] **T026** — Unit tests: dense/unique invariant on
      `ItemListViewModel`'s new reorder method (mirroring
      `WishlistViewModelTests`'s existing shape via the shared helper);
      confirms drag-reorder is only meaningful while sort is "Custom."
      *Verify: `xcodebuild test` green.*
      Done 2026-08-24: `ItemReorderTests` mirrors the wishlist's
      ordering suite; `ItemFormManualOrderTests` covers the append
      scope note. The mutation pass caught two false-passers in the
      new tests themselves — a `.sorted()` assertion that verified
      nothing, and a persistence check reloading through the same
      `ModelContext` — the second inherited faithfully from the
      T034-era wishlist original, which had the same latent defect.
      Both fixed, wishlist's original fixed too (audit-the-same-shape),
      and proven: deleting the wishlist move's save now reddens its
      persistence test for the first time. Final tally, all red, zero
      compile errors: guard gutted, item save dropped, append dropped,
      wishlist save dropped. One survived check also repeated the
      -only-testing file-vs-struct trap (zero tests ran, verdict
      green); mutation checks now print the ran= count.
- [x] **T027** — Wire `.onMove` on `ItemListView`, attached only when
      the active sort is "Custom" — hidden, not just disabled,
      otherwise. *Verify: manual — select "Custom," drag to reorder,
      confirm it persists across a relaunch; select any other sort,
      confirm dragging is unavailable.*
      Done 2026-08-24: nil-perform detaches the gesture wherever
      Custom isn't the active unnarrowed view. Live: long-press drag
      moved Echo bottom→top under Custom; sqlite shows
      Echo=0/Charlie=1/Charlie=2 across a relaunch; the identical
      touch path under Date changed nothing on screen or in the
      store. Bonus live proof of T025's append: newly added Echo
      sorted first under Date, last under Custom.
- [x] **T027a** — Before the Reorder button goes: check whether
      `WishlistView`'s edit mode — reachable today only via that
      button — actually exposes VoiceOver custom actions (or any other
      accessible mechanism) for reordering rows. An empirical check
      against the running app with VoiceOver / Accessibility Inspector,
      not an API-docs guess. Nothing earlier in this list touches the
      mechanism in question (`editMode` + `.onMove` on `WishlistView`),
      so the check stays faithful to today's shipped behavior anywhere
      before T028 — but not after. *Verify: documented finding,
      recorded inline here the way T001's was, before T028 executes.
      Determines whether the docs need correcting: if edit mode does
      expose an accessible reorder path, spec.md's Non-goals entry, its
      acceptance criterion beginning "Neither list's drag-to-reorder
      gesture has a VoiceOver-accessible equivalent," and plan.md's
      known-limitations section mustn't read as "a known gap, never
      existed" — they need to say an accessible path existed via edit
      mode and `010` removed it deliberately alongside the button. If
      VoiceOver exposes nothing useful there today, the current framing
      already holds and no doc change is needed.*
      Interim record (2026-08-24) — instruments exhausted, human check
      requested, T028 held: (1) An in-app probe walking the UIKit
      hierarchy and `accessibilityElements` (T051/T056 precedent,
      temporary code, never committed) found the edit-mode rows as
      combined elements with zero custom actions — but it failed its
      own pre-registered positive control, seeing none of the swipe
      actions VoiceOver demonstrably gets, so its silence proves
      nothing about reorder. (2) The iOS Simulator cannot run
      VoiceOver at all — no VoiceOver row exists under Settings >
      Accessibility > Vision, and the `com.apple.Accessibility`
      defaults keys are inert — so no on-simulator check can be
      VoiceOver-faithful. (3) The macOS AX bridge (what Accessibility
      Inspector uses) is scriptable but gated on an Accessibility
      permission this environment doesn't hold (`AXIsProcessTrusted =
      false`), grantable only by hand in System Settings. Remaining
      evidence is exactly the API-docs/forum-post guesswork this task
      forbids as a sole basis (Apple forums thread 743351 reports no
      move actions, unanswered, dated). The check that remains is the
      task's own named tool in human hands: Accessibility Inspector
      against the booted simulator, ~2 minutes — steps in the Phase 5
      report. T028 stays gated per its own text.
      **Finding (2026-08-25, recorded verbatim from the person steering
      this project): "WishlistView's edit mode does expose
      VoiceOver-accessible Move Up / Move Down actions, confirmed via
      Accessibility Inspector against a live device."** This reverses
      the premise T028 was scoped under — removing the Reorder button
      would remove a working accessible path, not a redundant one. T028
      and T029 remain held; not cleared to proceed. Follow-on question
      opened in the same review, answered from source: the accessible
      path just confirmed is the *formal edit-mode* path specifically —
      `WishlistView` binds `\.editMode` to the Reorder toggle alone and
      attaches `.onMove` unconditionally, while `ItemListView`'s new
      T027 mechanism never touches edit mode at all (nil/non-nil
      `perform` plus long-press drag, no `EditButton`, no `editMode`
      anywhere in the file, nor anywhere else in the app target). So
      the item list's entire new reorder mechanism, and the wishlist's
      post-T028 long-press-only mode, are both outside anything this
      device check measured — their accessibility is UNVERIFIED, and a
      second empirical check (Inspector against a row with Custom
      selected, no edit mode involved, on both screens) is required
      before a real decision about T028.
      **Second check (2026-08-29, recorded verbatim from the same
      review): "the row itself, not just the drag handle, was checked
      in three matched states (Wishlist/edit-mode-on,
      Wishlist/Custom-sort/edit-mode-off, Items/Custom-sort). Move
      Up/Move Down appear only in the edit-mode-on state. The
      accessible actions are tied to formal editMode specifically, not
      to .onMove or to either screen's Custom sort selection."**
      Consequence, stated explicitly (also verbatim): ItemListView's
      reorder capability has no accessible path today, on any screen,
      under any state. WishlistView's only accessible reorder path is
      the one T028 would remove. T028/T029 remain held — this is
      bigger than what T027a was scoped to decide, and needs a real
      product call, not a docs update.
      Decision (2026-08-29, closing this task): `ItemListView` wires
      "Custom" to formal edit mode, mirroring `WishlistView`'s
      existing environment binding; `WishlistView`'s Reorder button
      is KEPT — T028 as originally written does not execute (see its
      rewritten entry below). Doc corrections applied per this
      task's own rule, as real reversals: spec.md's Summary, Goal 5,
      the "Reorder either list" flow, the Non-goals entry, three
      acceptance criteria, and three Resolved-decisions entries;
      plan.md's known-limitations section.
- [ ] **T028** — Rewritten after T027a reversed its premise; the
      original task ("remove `WishlistView`'s Reorder button from the
      header entirely") does NOT execute — the button stays. T027a
      measured that formal edit mode is what exposes VoiceOver's
      Move Up/Move Down actions, and the button's toggle is the only
      way into that mode the app had — so removing it would remove a
      working accessible path, not a redundancy. Actual work:
      `ItemListView` wires "Custom" to formal edit mode — add
      `.environment(\.editMode, .constant(viewModel.canReorder ?
      .active : .inactive))` at the end of `rows`, mirroring
      `WishlistView`'s existing binding. Safe there because Items
      defaults to Date, so edit mode (which deadens both swipe-action
      edges — measured live with a positive control) applies only in
      an opt-in arranging state; unsafe on the wishlist, where
      "Custom" is the default sort and the same wiring would park the
      screen in edit mode at rest. `WishlistView` is untouched.
      *Verify: build; full test suite; manual — Items under Date
      shows no handles and swipes work, Items under Custom shows
      handles, wishlist's Reorder button still present and working.
      Plus one Accessibility Inspector check: Move Up/Move Down
      appear on an Items row with "Custom" selected — closing the
      strong-but-unconfirmed inference from T027a's second check.*
- [ ] **T029** — Manual verification, both screens, updated for T028's
      rewrite: switching away from "Custom" and back preserves the
      manual order exactly as last arranged; dragging is unavailable
      while filtered or searched; `ItemListView` enters edit mode only
      under an unnarrowed "Custom" — never under Date/Value/Desire,
      never while filtered or searched; `WishlistView`'s Reorder
      button still toggles edit mode exactly as before, and its
      resting state (Custom selected, button not pressed) still has
      live swipe actions.

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

## Phase 7 — Visual refinement

**No longer blocked** — `design/elements/010-item-management/` has real
output from an approved Design pass, and the real values are already
extracted into `tokens.md` and `design/brief.md` (which was itself
amended to permit the chosen row treatment — see below). Each task
references the actual token table now, not a placeholder pointer to
"Design's output."

- [ ] **T034** — Row treatment (both lists), per `tokens.md`'s "Row
      treatment" table (box-shadow, radius, padding, thumbnail size).
      Applies uniformly whether a row is resting or swiped open — the
      swipe-reveal mockup showed a plain-bordered row, but that was
      illustrating the gesture, not final row chrome (see `plan.md`).
      *Verify: manual, checked against `tokens.md`'s exact values, and
      against `design/brief.md`'s current skeuomorphism section — which
      now permits restrained alpha-based depth like this treatment,
      following its `010` amendment, but still rules out literal
      materiality (metallic gradients, wood/leather texture, screws,
      stitching, photorealism). The old "no bevels, no drop shadows"
      reading of `brief.md` no longer applies; don't check against it.*
- [ ] **T035** — Sort picker visual treatment (both screens), per
      `tokens.md`. Compact badge showing the current sort, opening a
      dropdown of options on tap — confirmed not to have a crowding
      problem at four options, since the badge's footprint doesn't grow
      with option count. *Verify: manual, both screens, all four options
      each.*
- [ ] **T036** — Swipe-action iconography (Edit, Duplicate, Delete) —
      already added to `design/icons/`; this task is wiring them into
      the actual swipe-action buttons from T023/T024/T015, not designing
      them. Remember the button-text note from T023: "Copy," not
      "Duplicate," on screen. *Verify: manual, both screens, icons
      render at the sizes/strokes in `tokens.md`'s "Swipe-action rows"
      table.*
      Considered and declined in review (2026-08-23): a
      label-preservation note here (VoiceOver names swipe actions by
      their button labels; icon-only buttons fall back to the symbol's
      default description). Declined on record, not overlooked.
- [ ] **T037** — `DesireGauge` legibility fix, per `tokens.md`'s "The
      desire gauge's stepped ramp" table — ascending segment heights,
      the per-row "DESIRE" legend, the new `accentBrassMid` fill tone.
      The legend is a deliberate reversal of `001`'s "unlabeled in list
      rows" decision, not an oversight — see `spec.md`'s Resolved
      decisions. *Verify: manual — check the unlabeled-but-now-legended
      in-row version specifically (the one the fix targets), confirm it
      reads as a desire indicator without prior context, confirm the
      legend text is genuinely dimmed (not full-weight) per the token
      values.*

## Phase 8 — Full regression and close-out

- [ ] **T038** — Full manual click-through: swipe-delete and
      detail-menu delete on both entities (confirm identical alert copy
      per entity); swipe-edit and swipe-duplicate on both lists; manual
      reorder on both lists via "Custom," including switching sorts away
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
> verification and schema-touching work — with one refinement decided
> in review (2026-08-23): T004 batches with T005 instead of getting its
> own stop, per the cadence note under Phase 1's header. T005 and T006
> keep individual stops. From Phase 2 onward, the per-phase stop is
> the default — but don't wait for phase-end if something meets
> CLAUDE.md's own escalation triggers (infeasibility/rework risk, or a
> direction-changing unknown) that Plan Mode and the skeptical-reviewer
> subagent can't resolve on their own. Surface those immediately.
> Routine ambiguity within a phase should get resolved the normal way
> (Plan Mode, the subagent) and reported at the end, not escalated
> just because it came up mid-phase.

## Model and effort per phase

Skipped deliberately, per this project's own established practice
(see `DECISIONS.md`): phase-tiered model/effort assignment was tried on
`001` and abandoned partway through — several tasks assumed to be
safely mechanical benefited from the top tier in ways that weren't
obvious in advance. Current practice is the best available model at
maximum effort throughout. Review *cadence* (above, per phase) is a
separate axis from model tier and still applies.

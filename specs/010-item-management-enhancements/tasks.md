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
- [x] **T028** — Rewritten after T027a reversed its premise; the
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
      Done (2026-08-29) except the Inspector item: one environment
      line at the end of `ItemListView.rows` (19dd93d),
      `WishlistView` untouched (diff shows only ItemListView). Build
      green; full suite green — 524 tests in 85 suites + 5 UI tests.
      Manual, all on the fresh binary: Items under Date shows no
      handles and its trailing swipe pops the rust Delete; picking
      Custom flips both rows to drag handles; a category chip and a
      live search each drop edit mode while active; the handle-drag
      moved a row and sqlite shows the arranged order persisted
      (Leica=0, Another=1); the wishlist's Reorder button still
      toggles edit mode and its resting-state swipe still works.
      The Inspector check is the one open item — the same
      environment blocker as T027a's interim record
      (`AXIsProcessTrusted` still false, grantable only by hand), so
      it needs the same ~2-minute human pass: the simulator is
      parked on the Items tab with Custom selected and edit mode
      active; point Inspector at either row and look for Move
      Up/Move Down.
      Inspector check done (2026-08-29, by the person steering this
      project): selecting the first item with Accessibility
      Inspector shows "Move down" in the Actions list. That closes
      the inference — and closes it well: the top row offering only
      Move down (no Move up, nowhere to go) is the position-aware
      behavior of the genuine reorder mechanism, not a generic
      action label. `ItemListView`'s Custom-wired edit mode exposes
      the accessible reorder path. T028 complete.
      Clarified (2026-08-29, same review, superseding the decision
      above): the intended product behavior was narrower than what
      shipped — "Custom" should only ALLOW press-and-hold drag,
      never force edit mode. Handles should never be visible, no
      Reorder button should exist, the two screens must behave
      identically, and swipe actions must stay live. The editMode
      wiring this task added is therefore reverted and the button
      the earlier decision kept is removed after all — safely this
      time, because the accessible path both prior decisions were
      protecting moves to explicit VoiceOver row actions instead of
      edit mode. Split into T028a / T028b / T029a below.
- [x] **T029** — Manual verification, both screens, updated for T028's
      rewrite: switching away from "Custom" and back preserves the
      manual order exactly as last arranged; dragging is unavailable
      while filtered or searched; `ItemListView` enters edit mode only
      under an unnarrowed "Custom" — never under Date/Value/Desire,
      never while filtered or searched; `WishlistView`'s Reorder
      button still toggles edit mode exactly as before, and its
      resting state (Custom selected, button not pressed) still has
      live swipe actions.
      Done (2026-08-29), live transcript: arranged Leica above
      Another Item under Custom (store: Leica=0/Another=1), switched
      to Date (order inverted to Another/Leica, handles gone,
      resting swipe live), back to Custom — arranged order intact
      with handles restored. Cameras chip and a "le" search each
      removed the handles under Custom; clearing each brought them
      back. Wishlist on the same binary: Reorder → handles + DONE,
      Done → resting swipe pops Delete. Every check on the current
      build, not carried over from the pre-T028 binary.
- [x] **T028a** — Unify both screens on the clarified minimal
      behavior: remove `ItemListView`'s editMode environment line
      (reverting 19dd93d's wiring); remove `WishlistView`'s Reorder
      button, its `isReordering` state, and its editMode binding
      entirely; and switch `WishlistView`'s `.onMove` to the same
      conditional-nil pattern `ItemListView` uses, so the drag
      gesture is detached — not merely no-opped by the VM guard —
      outside an unnarrowed "Custom". No formal edit mode anywhere
      in the app; swipe actions live in every state. *Verify: build;
      full suite; manual — no handles or button on either screen in
      any state; long-press drag reorders under Custom on both;
      swipes work while Custom is active.*
      Done (2026-08-29): editMode line gone from ItemListView;
      WishlistView loses `isReordering`, the toggle, its editMode
      binding, and both `isReordering = false` resets, and its
      header/sortControl now match ItemListView's line for line;
      its `.onMove` adopts the conditional-nil pattern. A grep for
      isReordering/editMode/EditButton across the app target finds
      only `canReorder` and one explanatory comment. Build green;
      full suite green (524 tests in 85 suites + 5 UI tests). The
      manual pass runs at T029a, after T028b restores the
      accessible path.
- [x] **T028b** — Replace the edit-mode accessible path with explicit
      VoiceOver actions, both screens: position-aware "Move up" /
      "Move down" accessibility actions on rows, present only while
      reordering is meaningful (unnarrowed Custom), backed by new
      `moveUp(id:)` / `moveDown(id:)` / `canMoveUp(id:)` /
      `canMoveDown(id:)` intent methods on both view models. This is
      what lets the button go without reopening the gap T027a found
      — spec.md's corrected criterion (reordering VoiceOver-reachable
      on both lists) still holds, now with zero edit-mode UI.
      *Verify: unit tests on both VMs (moves, boundary no-ops,
      canReorder gate), mutation-checked per the standing rule;
      build; full suite; Accessibility Inspector check by hand on
      both screens (same ~2-minute pass as before) confirming Move
      up / Move down appear under Custom with no edit mode involved.*
      Done (2026-08-29) except the Inspector item: both VMs gain
      `canMoveUp/Down(id:)` and `moveUp/Down(id:)` routed through the
      existing `move(fromOffsets:toOffset:)`; both views attach
      position-aware "Move up"/"Move down" via `.accessibilityActions`
      on the rows. Six new tests (four in ItemReorderTests, two in
      WishlistOrderingTests); full suite 530 tests in 85 suites + 5
      UI tests, green. Four mutations, all red with ran=20 confirmed
      per run: item moveDown `+2`→`+1` (caught by
      moveDownStepsOneRowAndPersists), canMoveDown's canReorder guard
      removed (accessibleMovesRespectTheReorderGate), canMoveUp
      `>`→`>=` (theEndsOfferNoAccessibleMove), wishlist moveDown
      `+2`→`+1` (aVoiceOverMoveStepsOneRowAndPersists — the
      per-entity spot-check, T020/T022 precedent). All reverted;
      restored suite green. Inspector pass pending, same
      AXIsProcessTrusted blocker as before.
      Inspector check done (2026-08-29, by the person steering the
      project): "Move up/Move down appears in actions on each row in
      both screens." T028b closes green — the named actions are the
      accessible reorder path on both lists, with no edit mode
      anywhere.
- [x] **T029a** — Re-run T029's manual verification against the
      unified behavior (its earlier record verified the edit-mode
      variant): order round-trip preserved; drag detached while
      filtered or searched on both screens; no button, no handles
      anywhere; swipes live under Custom on both screens.
      Interim record (2026-08-29) — most checks green, one finding
      needs a human hand. Green, all on the clean final binary:
      no Reorder button and no handles anywhere on either screen;
      trailing swipe pops the rust Delete *while Custom is active*
      on both lists (the clarified requirement); long-press drag
      reorders and persists on both (item store round-tripped
      Leica=0/Another=1; wishlist swaps confirmed by sqlite);
      Custom→Date→Custom preserved the arranged order; the same
      drag recipe does nothing while a category filter is active.
      The finding: with SYNTHETIC touches, a drag that completes
      without the row visibly lifting still fires `.onMove` — the
      model and store update correctly — while the List keeps
      painting the pre-drag order until the next load() (tab away
      and back fixes it). Reproduced 4/4 on the wishlist;
      instrumented per the T056 rule (temp prints, reverted): move()
      fires with correct indices AND the view's own onChange sees
      the new array, yet the rendered rows don't change. When the
      pickup visibly engages (observed on the item list), rendering
      is correct. Undetermined whether a real finger can reach the
      silent-commit state at all — the visible lift is the normal
      human experience, and this long-press reorder is 001-shipped
      behavior on the wishlist. Needs a human drag on each screen:
      if the row lifts, lands, and stays where dropped, this is a
      robot-gesture artifact and T029a closes green; if a real
      drag can also land stale, it's a real defect to fix before
      the spec ships.
      Human check (2026-08-29): it's a real defect. Recorded
      near-verbatim: "I can press and drag to move the physical
      item but then after switching the order of items and
      releasing the gesture, the item snaps back to where it was in
      the list and I can't reorder it again, suggesting that the
      underlying order has changed but it's not being reflected in
      the UI." So a real finger reaches the same end state the
      synthetic drags did — model and store move, the rendered rows
      don't — *with* the visible lift, and the broken view-to-data
      mapping then defeats follow-up drags. T029a stays open until
      T029b lands the fix and this checklist re-runs against it.
      Closed (2026-08-29): every checklist item verified on the fix
      build — round-trip, filtered/searched drags detached, no
      button or handles anywhere, swipes live under Custom — and
      the drag itself confirmed by the person steering the project
      on an actual device: rows land and stay where dropped. The
      one item still open from that same human pass is T029c's
      border transient, tracked there.
- [x] **T029b** — Diagnose, then fix, the reorder render desync on
      both screens: after `.onMove` fires, the List must show the
      new order immediately — no snap-back, no stale arrangement,
      no dead follow-up drags. Diagnose before fixing, per the
      standing rule: instrument to find which link breaks (the VM
      mutation, the save timing, a competing row gesture, or
      List-internal teardown), and fix the actual cause rather than
      forcing a whole-List identity rebuild. *Verify: build; full
      suite; robot-drag repro recipe (the one that hit 4/4 stale on
      the wishlist) now renders correctly, repeatedly, on both
      screens, with store round-trips confirming persistence; then
      a human finger-drag confirms lift-land-stay.*
      Done (2026-08-29), diagnosed by elimination then bisection,
      every configuration measured with the repro recipe plus store
      reads: deferring the save — still desynced; deferring the
      whole mutation a runloop turn — 1/2; removing the row tap
      gesture — 1/2; bare `Text` rows with only `.onMove` — 4/4
      clean; full styled rows minus ONLY the T028b
      `.accessibilityActions` block — 4/4 clean. Culprit: that
      block's position-conditional buttons (`canMoveUp/Down`)
      restructure each row's accessibility content at the exact
      moment the reorder settles — positions are what just changed —
      and the List answers by painting the pre-drag order over the
      committed move. Fix: the block's structure now depends only on
      `canReorder`, which cannot change mid-drag; both "Move up" and
      "Move down" are present on every row while reordering is
      available, and the ends of the list no-op inside
      `moveUp`/`moveDown` (the guards the mutation tests already
      cover). Trade-off accepted and recorded: boundary rows expose
      an action that does nothing, in exchange for reorder rendering
      that survives its own settle. Verified: wishlist 4/4 and items
      2/2 robot drags render-and-persist consistent on the fix
      build; full suite green (530 in 85 + 5 UI). Human
      finger-drag confirmation pending, alongside a quick Inspector
      re-check (both actions now appear on every row under Custom,
      none under other sorts).
      Confirmed (2026-08-29, on an actual device): "items remain
      where you put them in order." Inspector re-check also
      confirmed: actions appear only under Custom, both on every
      row. The reviewer flagged the every-row presence as possibly
      an issue — it is the deliberate trade this task records above:
      position-conditional presence was the desync's cause, so the
      inert boundary action is the price of stable reorder
      rendering. T029b closed.
- [x] **T029c** — Fix the sort control's transient border glitch:
      switching to "Custom" from any other sort makes one or both
      sides of the button's surrounding rectangle vanish for about
      half a second, and the label text sometimes jumps — every
      time, both screens (reported 2026-08-29 during T029a's human
      pass). The label grows to its widest string while the
      stroke-border overlay animates on its own schedule; they need
      to move as one unit. *Verify: build; full suite; human
      confirmation that the transient is gone on both screens,
      since a half-second animation artifact outlives any
      screenshot this environment can time.*
      Implemented (2026-08-29): `.geometryGroup()` on both sort
      controls' labels, after the border overlay, so the text and
      its stroked rectangle resize atomically. Build + full suite
      green (530 in 85 + 5 UI). Awaiting the human eyeball pass; if
      the transient survives geometryGroup, the fallback is
      disabling the implicit animation on the label
      (`.animation(nil, value:)`) so the size change snaps instead
      of tweening.
      Eyeball pass (2026-08-29): geometryGroup alone was NOT enough
      — the transient survived, still only when switching *to*
      Custom, with the text hop varying by which sort was switched
      from (i.e., by the width delta being animated). Fallback
      applied: `.animation(nil, value: viewModel.sortOrder)` on
      both labels, after geometryGroup, so the label's size change
      snaps — a sort change is a content swap, not motion. Suite
      green again. Second eyeball pass pending; if any trace still
      survives (which would mean the animation lives in the Menu's
      UIKit layer beyond SwiftUI's transaction), the next
      escalation is reserving the control's width at the widest
      label so nothing ever resizes — a small design change that
      would need a call, since post-T030 the wishlist's widest
      label becomes "Alphabetical."
      Second eyeball pass (2026-08-29): still there, and on more
      transitions — Date→Value and Value→Desire too, i.e. any
      width-growing swap; the reviewer's diagnosis: the border
      draws slower than the text changes. Root cause finally
      *seen*, not inferred: a screen recording with per-frame
      extraction (AVAssetImageGenerator, no ffmpeg on this machine)
      caught the defect in a single frame — label "Custom" fully
      landed while the border rendered as two horizontal lines with
      both vertical sides missing, recovering ~400ms later. That
      also explains both failed fixes: the width tween is imposed
      by the menu-dismiss transaction from OUTSIDE the label, where
      neither geometryGroup nor a value-scoped animation(nil) can
      reach — text is an uninterpolable content swap (lands
      instantly), the border honestly tracks the animating bounds.
      Escalation applied without waiting for a Phase 6 call, since
      today's design cost is nil: both sort controls reserve the
      width of their widest label (every option's label measured
      hidden in a ZStack, one shown), so switching sorts changes no
      geometry at all — nothing to tween on any transition, current
      or future. Frame-verified on the fix build: the full dismiss
      sequence shows an intact four-sided border in every frame,
      and the Date-state control occupies the identical rectangle
      as the Custom-state one. Suite green (530 in 85 + 5 UI).
      Design note carried to Phase 6, unchanged: T030's
      "Alphabetical" will widen the wishlist control's resting
      width by construction — flag at that review. Final human
      eyeball pass pending.
      Third pass (2026-08-29): the reviewer confirmed the
      constant-width build glitch-free but didn't love the resting
      slack on short labels, and asked for hug-width without the
      tear if reachable without significant rework. Two more
      oracle-verified rounds: (1) de-animating the change at its
      source (withTransaction, disablesAnimations) — tear
      unchanged on film, proving the tween is the Menu's UIKit
      bounds animation, beyond any SwiftUI transaction; (2) the
      shipped shape: the Menu label keeps a constant invisible
      footprint (every option's pill measured hidden — which the
      constant-width oracle proved silences UIKit), while the
      visible bordered pill hugs the current text inside it,
      anchored trailing. Hug look restored (frame-verified: "Date"
      wraps snugly); no text hop (the label never moves); the tear
      shrank from ~400ms at full opacity to at most ~2 frames
      (~70–100ms) *inside the system menu's dismiss dissolve* —
      it lives in UIKit's overlay compositing, not in anything
      this app draws, and the real control is correct the moment
      it is visible. Eliminating that trace would mean replacing
      the system Menu with a custom control — the significant
      rework the reviewer ruled out; recorded as the
      revisit-later boundary. Only cost: the tap target on short
      labels is invisibly wider (post-T030, "Alphabetical" widens
      only that, not the visible pill — the earlier Phase 6
      design concern dissolves). Suite green (530 in 85 + 5 UI).
      Final eyeball pass pending.
      Closed (2026-08-29): "the sort control looks and behaves
      correctly now on both screens" — confirmed by the person
      steering the project. Phase 5 complete in full.

## Phase 6 — Wishlist sort expansion

- [x] **T030** — Remove `WishlistViewModelTests.theSortControlOffersNoRatingOption`.
      Commit message states plainly that this reverses a `001` decision
      and why (see `spec.md`'s Resolved decisions) — an honest reversal,
      not a silent deletion. *Verify: test suite no longer contains it;
      commit message reviewed for the explanation before merging.*
      Done (2026-08-29, 1d95c8e): grep finds zero occurrences; the
      commit message carries the reversal's why. Beyond the one test,
      the suite housing it was reframed in the same commit — "Desire
      to own never reorders the wishlist" became "Desire to own
      reorders nothing but its own sort" — since T031 makes the old
      name false on its face while the three surviving tests (Custom
      ignores the rating, Cost ignores it, rewriting ratings moves
      nothing) still pin what 001 got right.
- [x] **T031** — Add "Desire" and "Alphabetical" sort cases to
      `WishlistViewModel`, each combined with manual order as tie-break
      via `ManualOrderHelper`. Sort directions per `plan.md`'s proposed
      defaults (Cost ascending, Desire highest-first, Alphabetical A→Z)
      unless overridden before this task starts. *Verify: `xcodebuild
      build` succeeds.*
      Done (2026-08-29, 775ed54): two new cases; directions exactly
      plan.md's, no override having arrived — which made Cost
      ascending a deliberate flip of 001's shipped dearest-first, so
      the three tests pinning the old direction changed in the same
      commit (the cheapest-first rename; the move-ignored-under-cost
      expectations; and the rating-independence fixture inverted, its
      old wanted-and-cheap pairing having agreed with a desire sort
      once cost flipped — it would have stopped detecting the leak
      it exists to catch). `isOrderedBefore` restructured around
      `ManualOrderHelper.areInOrder` (its first production caller):
      attribute first, manual order on any tie, name-then-id kept
      for rows tying on both. Full suite green.
- [x] **T032** — Unit tests: correctness of both new sorts; their
      tie-break specifically (construct same-tier items, confirm manual
      order resolves them consistently); composability with category
      filtering, mirroring `ItemListViewModel`'s existing
      `filteringAndSortingApplyTogether` pattern. *Verify: `xcodebuild
      test` green.*
      Done (2026-08-29, 93a2978): six tests, every fixture built so
      manual order opposes the sorted order (a wrong field, wrong
      direction, or name-first tie-break shows); tie coverage on
      Desire (the common case), Cost (where 001's name fallback used
      to rule), and spec.md's identical-names Alphabetical example;
      filter+sort composability across both new sorts. Four
      mutations all red with ran-counts confirmed — desire flipped
      (2 catchers), tie-break bypassed (4, including the Custom
      suite: the branch serves both), alphabet reversed (2), cost
      re-flipped (3+) — all reverted, production diff empty, full
      suite 535 in 85 + 5 UI green.
- [x] **T033** — Manual verification: both new sort options appear and
      produce correct order; ties resolve by manual order visibly;
      filtering to a category while sorted by Desire or Alphabetical
      narrows correctly without losing the sort.
      Done (2026-08-29), live transcript: the menu offers all four
      options; Desire put the tier-3 Hasselblad over the tier-2
      Something; raising Something to tier 3 (detail-screen gauge)
      produced a tie that showed in manual order — then, the visible
      proof, rearranging under Custom (Something to top,
      store-confirmed S=0/H=1) flipped the Desire order to match;
      Alphabetical showed H-before-S *against* the manual order;
      Cost showed $200 before $7,000 — cheapest first, the flipped
      direction, on screen; with Desire active, the Cameras chip and
      a "some" search each narrowed correctly with the sort control
      still reading Desire. Fixture restored afterward
      (H=0/desire 3, S=1/desire 2, store-confirmed).

- [x] **T033a** — Both money sorts gain their second direction, requested
      by the person steering the project at the Phase 6 review ("Both
      the Value and Cost orderings... only allow the ascending option.
      I'd like to add a descending option for each"): the item list's
      Value and the wishlist's Cost each become a labeled pair in the
      picker rather than a re-tap toggle — "Value ↓"/"Value ↑" (the
      shipped high-first stays the lead option) and "Cost ↑"/"Cost ↓"
      (cheapest-first stays the lead, per plan.md's direction call).
      This reverses the SortOrder enums' original one-direction-each
      rule; both enum docs say so. Un-valued items stay last under
      Value ↑ too — unknown isn't a low value any more than it was a
      zero. Done (2026-08-29): two new cases, two new tests (ascending
      Value with the unvalued-last rule; descending Cost), both
      mutation-verified red on direction flips with ran-counts
      confirmed; full suite 537 in 85 + 5 UI green; verified live on
      both screens (Value ↑ put $2,500 above the un-valued item;
      Cost ↓ put $7,000 above $200; the width-reserving pill absorbed
      the new labels by construction).

## Phase 7 — Visual refinement

**No longer blocked** — `design/elements/010-item-management/` has real
output from an approved Design pass, and the real values are already
extracted into `tokens.md` and `design/brief.md` (which was itself
amended to permit the chosen row treatment — see below). Each task
references the actual token table now, not a placeholder pointer to
"Design's output."

**Design refresh reviewed 2026-08-29** with the person steering the
project — the exports in `design/elements/010-item-management/` were
refined (three PNGs, the Approved canvas) and two new detail-screen
designs added. Decisions, all theirs, recorded before execution:
1. The swipe label stays **"Copy"** — the refreshed exports' DUPLICATE
   is outdated text, not a reversal ("The Duplicate text is outdated.
   Please keep Copy."). T036 must not follow the export on this one
   string.
2. The two detail screens join Phase 7's scope as T037a/T037b.
3. Detail headers keep the existing "…" overflow menu; the mocks'
   separate Edit/Delete header buttons are not adopted.
4. Schema unchanged: the item mock's "Stored", split "Brand / model",
   and "Valued" date are stale artifacts of the initial design
   ("Let's keep the app as it is for now") — render existing fields
   only.
5. The wishlist detail keeps its tap-to-set desire gauge; its absence
   from the mock is accidental ("I don't know why it is missing").
6. The item dial's per-level hint copy is **reworded to be true
   today** (option 2 of the review) — the mock's hints describe
   target-shortfall escalation and per-level exclusion overrides that
   don't exist yet. What DOES exist and the reworded hints lean on:
   `DesireLevel.isSellCandidate` (desire ≤ 3 joins the candidate
   pool) and `SellPlanViewModel`'s lowest-desire-first candidate
   ranking. **Revisit note, per the same instruction: when the more
   sophisticated sell-plan logic ships (shortfall escalation, opt-in
   overrides — 009-adjacent), re-differentiate the level-4/5 hints
   and restore the richer copy.** Recorded here and beside the
   strings in code.
7. Adopted from the mock's copy: level 3 reads "On the fence"
   (was "Undecided") — the design pass owns these words, same as
   levels 4/5 always were.
8. The wishlist mock's "Priority" DETAILS row was standing in for the
   missing gauge; with the gauge kept (decision 5), the row would
   show desire twice — omitted.

- [x] **T034** — Row treatment (both lists), per `tokens.md`'s "Row
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
      Done (2026-08-29): shared `.extrudedPlate()` modifier (new
      `ExtrudedPlate.swift` — one treatment for rows now and the
      detail cards at T037a/b), three new theme alphas
      (plateHighlight/plateEdgeShadow/plateCastShadow), row padding
      and content gap to 13 as their own metrics with `listRowInset`
      re-derived, thumbnail slot 72→52 (its two size-pinning tests
      updated with the token note). Pixel-verified byte-exact at 3×:
      surface #201F1D; top edge (44,42,40) vs computed
      ivory-5.5%-over-surface (43.6,42.3,39.9); bottom edge
      (19,19,17) vs black-40%-over-surface (19.2,18.6,17.4); cast
      shadow visible under the card, fading with distance. Suite 537
      in 85 + 5 UI green.
- [x] **T035** — Sort picker visual treatment (both screens), per
      `tokens.md`. Compact badge showing the current sort, opening a
      dropdown of options on tap — confirmed not to have a crowding
      problem at four options, since the badge's footprint doesn't grow
      with option count. *Verify: manual, both screens, all four options
      each.*
      Done (2026-08-30): new shared `SortPicker.swift` — `SortBadge`
      (brass border/text, custom three-bar glyph at the 10/7/4 token
      widths) and `SortDropdown` (232px, SORT BY header, hairline
      row separators, selected row tinted with a drawn 12×12/1.6
      checkmark, REORDER tag on the Custom row alone). The system
      `Menu` is gone entirely, and with it T029c's whole workaround
      class — the badge hugs its label again because no UIKit
      machinery animates it; the constant-footprint pill and its
      helpers were deleted from both screens. Screens own the open
      state, a full-screen clear catcher dismisses on outside tap,
      and the dropdown floats via a screen-level overlay. One
      rendering call recorded: the checkmark shows on ANY selected
      row (the mock only draws the Custom case; tint alone marking
      selection elsewhere would be odd), REORDER stays Custom-only
      per the tokens table. Verified live on both screens: options
      render (5 each, post-T033a), selection re-sorts and closes,
      outside tap dismisses without leaking the tap to rows beneath,
      badge tracks the label. Suite 537 in 85 + 5 UI green. (Also
      noted: the wishlist fixture's manual order arrived swapped
      from the reviewer's own Inspector pass performing a Move
      action — the store and screen agree, which is the feature
      working, not a defect.)
- [x] **T036** — Swipe-action iconography (Edit, Duplicate, Delete) —
      already added to `design/icons/`; this task is wiring them into
      the actual swipe-action buttons from T023/T024/T015, not designing
      them. Remember the button-text note from T023: "Copy," not
      "Duplicate," on screen. *Verify: manual, both screens, icons
      render at the sizes/strokes in `tokens.md`'s "Swipe-action rows"
      table.*
      Done (2026-08-30): three template-rendered imagesets
      (ActionEdit/ActionDuplicate/ActionDelete) created inside the
      asset catalog from `design/icons/`'s SVGs — no .pbxproj edits,
      the catalog absorbs new sets — and wired into all six swipe
      buttons via `Label { } icon: { }`. "Copy" kept per the
      design-refresh decision (the export's DUPLICATE is outdated).
      Verified live on both screens: Design's pencil,
      overlapping-rects, and trash glyphs render at their drawn
      20px/1.5-stroke geometry with the correct per-button tints,
      and the full-leading-swipe still triggers Edit. One divergence
      flagged, not fixed: iOS 26 presents icon-bearing swipe actions
      as tinted circular chips with the label beneath — at any
      reveal depth (tested shallow and full) — rather than the
      mock's 76px full-height rectangles. That presentation belongs
      to the system, not to anything `.swipeActions` exposes;
      matching the mock exactly would mean abandoning the system
      swipe machinery. Suite 537 in 85 + 5 UI green.
      Considered and declined in review (2026-08-23): a
      label-preservation note here (VoiceOver names swipe actions by
      their button labels; icon-only buttons fall back to the symbol's
      default description). Declined on record, not overlooked.
- [x] **T037** — `DesireGauge` legibility fix, per `tokens.md`'s "The
      desire gauge's stepped ramp" table — ascending segment heights,
      the per-row "DESIRE" legend, the new `accentBrassMid` fill tone.
      The legend is a deliberate reversal of `001`'s "unlabeled in list
      rows" decision, not an oversight — see `spec.md`'s Resolved
      decisions. *Verify: manual — check the unlabeled-but-now-legended
      in-row version specifically (the one the fix targets), confirm it
      reads as a desire indicator without prior context, confirm the
      legend text is genuinely dimmed (not full-weight) per the token
      values.*
      Done (2026-08-30): the gauge's geometry rebuilt around the
      token table — bottom-aligned segments at the 8/11/14 ratio
      (scaling for the form and detail sizes), gap and shear derived
      from the same base (shear is now `tan(12°)` of each segment's
      own height, so all three share the mock's angle), unfilled
      segments became hairline outlines (`Parallelogram` turned
      `InsettableShape` for a true border-box stroke; new
      `gaugeTrack` theme color), and the mid tone became the named
      `accentBrassMid` token instead of a runtime mix — same
      Oklab-searched value. The per-row "DESIRE" legend (mono 8.5,
      `textDisabled`, baseline nudged flush) ships on the row gauge
      only; the form and detail keep their own headings. All four
      gauge test suites updated to the new API/geometry, and the
      pixel-measuring perceptual floors re-passed against the
      *rendered stepped ramp* at the new row size — the
      distinguishability claim is still measured, not assumed.
      Verified live: rows match the redesign PNG (legend, stairs,
      ghost outline, brightest-at-top). Suite 537 in 85 + 5 UI
      green.

- [x] **T037a** — Item detail refresh per `Trove Item Detail.dc.html`,
      scoped by the design-refresh decisions above: keep the "…"
      overflow (no header Edit/Delete buttons); existing schema fields
      only in the DETAILS table; photo hero with pager dots and
      caption plus thumbnail strip with add tile; WORTH NOW / PAID
      stat pair with the gain/loss delta; desire block with the dial,
      per-level summary, and the new true-today hint line
      (`DesireLevel.detail`); NOTES and the "Add to a sell plan" row
      per `tokens.md`'s new "Item detail" table. *Verify: build; full
      suite; manual against tokens.md's exact values.*
      Done (2026-08-30): WORTH NOW / PAID became two bevelled cells
      split by a hairline seam, clipped and shadowed once as a unit
      (new `.plateBevel()` alongside `.extrudedPlate()` — rounding
      and shadowing each cell would draw a shadow through the seam);
      the desire block became a plate; DETAILS gained its header with
      right-aligned values over hairline rules; NOTES moved out to
      its own section. `DesireLevel` grew `detail(isValued:)` and
      level 3 became "On the fence" — five new tests pin the copy
      (nothing had, and the last two unpinned strings both drifted),
      two of them mutation-verified red: restoring the mock's
      "unless you say otherwise" tripped the unbuilt-mechanics
      guard, collapsing the unvalued branch tripped the
      unvalued-differs guard.
      Three deliberate divergences from the refreshed mock, beyond
      the review's own list:
      (1) **No "Add to a sell plan" row.** It has no destination —
      `SellPlanView` takes a `wishlistItemID`, because a plan
      belongs to a wishlist item and owned items are picked *into*
      it from there. Building the row would mean either a button to
      nowhere or a new item→plan picker flow, which is a feature,
      not visual refinement. Flagged for the phase review.
      (2) **Section headings stay `monoLabel`** rather than the
      mock's sans-semibold: every all-caps label on every other
      screen is mono, and one screen breaking that reads as a
      mistake. Recorded in `tokens.md`'s table too.
      (3) **No duplicate money rows in DETAILS.** The mock lists
      Purchase price and Current value there *and* in the stat pair;
      the screen would state each figure twice, so the existing row
      set stands. Suite 542 in 85 + 5 UI green.
- [x] **T037b** — Wishlist detail refresh per
      `Trove Wishlist Detail.dc.html`, same scoping: ESTIMATED COST
      card, DETAILS table (Category / Estimated cost / Added — no
      Priority row, decision 8), NOTES, MARKET PRICE ghost restyle,
      and the sell-plan CTA ("Find items to sell" with the
      lowest-desire-first subtitle, which is accurate to
      `SellPlanViewModel`'s real ranking); the tap-to-set desire
      gauge stays (decision 5); the "…" overflow stays. *Verify:
      build; full suite; manual against tokens.md.*
      Done (2026-08-30): cost and desire cards became plates; the
      market-price ghost's bars moved to `divider` at 35% and its
      note to `textQuiet` per the table; the sell-plan CTA became
      the mock's outlined treatment with its subtitle — a
      de-emphasis that matches plan.md's own restraint about not
      overstating what the plan does. Two things the screen already
      got right stood: no Priority row (the gauge says it — the
      code had made decision 8's call independently at `001`), and
      the gauge itself.
      Both detail screens now share `DetailSection` / `DetailRow` /
      `DetailProse` (new `DetailSection.swift`) rather than each
      drawing its own field table — the same instinct that pulled
      `PhotoCarousel` out of the item screen; `ItemDetailView` was
      moved onto them in the same commit.
      **One real defect caught on the simulator, not in review:**
      the outlined CTA's interior is transparent and therefore not
      hit-testable, so the button stopped responding except on its
      glyphs — the solid fill it replaced had been doing that job
      silently. Fixed with an explicit `contentShape`, re-verified
      by tapping through to the Sell Plan, and recorded in
      tokens.md so the next outlined control doesn't repeat it.
      (The Sell Plan screen's own "LOWEST DESIRE TO KEEP FIRST"
      header incidentally confirms the CTA subtitle is accurate.)
      Suite 542 in 85 + 5 UI green.

- [x] **T037c** — Extend the plate to every card in the app, plus three
      fixes, all from the 2026-08-30 design review. The rule as stated:
      *any rectangle whose background differs from the screen's* gets the
      treatment — so the dashboard's Spent/Gain figures, the search field
      on both list screens, the photo hero on both detail screens, every
      field on both forms, and (following the same rule rather than the
      list) the sell plan's cards and both dropdowns. *Verify: build;
      full suite; manual on every surface named.*
      Done (2026-08-30): the plate's drawing moved into a reusable
      `PlateSurface` view so the form screens — which hand their chrome
      to `.background(_:)` and compose a validity border on top — could
      use it without a wrapper. On form fields the border changed job
      rather than vanishing: the bevel separates, so `fieldBorder` now
      draws only when a field is invalid, where rust is a signal.
      Two surfaces deliberately left alone, both for the same reason —
      they have no fill to plate: capsule chips (category, condition,
      cost presets) are outlined pills, and the dashboard's un-valued
      callout is unfilled by design, the mock distinguishing it from the
      figures card by outlining rather than raising it. The code already
      said so; the rule as stated agrees.
      The three fixes:
      (1) **Price paid / Date bought now match heights.** A `TextField`
      sits a couple of points taller than the plain `Text` the date
      field draws; both boxes now stretch to the taller of the two.
      (2) **A calendar glyph replaces the empty square**, which read as
      an unchecked checkbox. SF Symbol, like the search magnifier and
      the sell-plan arrow — the brief's custom-mark rule covers the
      signature elements, not every affordance.
      (3) **The desire cards' padding now looks even.** The cause wasn't
      the padding: `DesireDial`'s sweep stops at 4-and-8 o'clock, so a
      quarter of its own square is blank below it, while its knob
      overhangs the frame at 12 o'clock. Both are computable, so the
      arithmetic lives with the geometry (`emptyBottomInset`,
      `knobOverhang`) and the cards give it back rather than
      hand-tuning a number. Measured, not eyeballed: the form card went
      11.7/21.0pt to 15.0/16.3pt, the detail card to 22.0/21.7pt — in
      line with the plain fields around them (19.3/19.0, 18.0/18.3).
      Suite 542 in 85 + 5 UI green.

- [x] **T037d** — Four follow-ups from the same review round.
      *Verify: build; full suite; manual on each.*
      Done (2026-08-30):
      (1) **The category field takes the plate** on both forms — it
      was the last input still drawing the old flat surface, and
      sitting beside plated siblings it read as a mistake. Its border
      follows the rule the other fields now follow: state only, so
      brass on focus and rust on invalid survive while the resting
      divider outline goes.
      (2) **The "More details" ghost is gone.** Filmed before fixing,
      per the T029c lesson: animating the insert made SwiftUI lay the
      whole optional section out at the *scroll content's origin* for
      the transition's duration, so it faded in ghosted across the
      entire form from the top of the screen. Neither an explicit
      transition nor a nil-animation transaction on the inserted
      subtree stopped it; removing the animation did, confirmed on a
      second capture. **Trade-off stated plainly: the section now
      snaps rather than folds.** A true fold means measuring the
      section's height and animating that — a bigger change than this
      glitch warranted, and worth doing only if the motion is wanted
      for its own sake.
      (3) **The photo hero takes a swipe** on both detail screens —
      the gesture people try first, where the thumbnails had been the
      only way through a set. A drag rather than a paging `TabView`,
      since the caption and the plate belong to the hero and a
      TabView would page those too; it steps one photo and stops at
      each end rather than wrapping, so it agrees with the fixed
      strip below. Verified live: forward, back, and no wrap at the
      first photo. VoiceOver gets the same movement as an adjustable
      action.
      (4) **The thumbnail strips already scrolled horizontally in a
      single row** — both the detail carousel's and the form picker's
      — so nothing needed changing, and this is recorded as verified
      rather than done.
      Suite 542 in 85 + 5 UI green.

- [x] **T037e** — The hero swipe becomes a real pager, with dots.
      Review feedback on T037d's swipe: the photo changed on release but
      nothing moved with the finger, and there was no indicator of which
      photo of how many was showing.
      *Verify: build; full suite; filmed drag frames; manual.*
      Done (2026-08-30): the hero's discrete `DragGesture` is replaced
      by a paging `ScrollView` (`.scrollTargetBehavior(.paging)`) whose
      `.scrollPosition` is bridged both ways to the carousel's one
      `selectedIndex` — so a swipe, a thumbnail tap, and VoiceOver's
      adjustable action all drive and reflect the same state. The
      caption, plate, and new dots row (brass on the current photo,
      shown only when there's more than one, hidden from VoiceOver
      since the caption already announces the count) stay fixed as
      hero chrome while only the photos move — the property that ruled
      out `TabView` still holds, now without giving up tracking.
      Each page clips itself, since a filled landscape image is wider
      than its page and would lie over its neighbors mid-swipe.
      Verified by filming the drag and hashing the hero band per
      frame: twenty distinct intermediate states across ~1s of motion,
      with mid-drag frames showing both photos sliding together under
      a fixed caption, and rubber-banding at the ends in place of any
      wrap. (First hashing pass looked in the wrong 4s of a
      variable-frame-rate recording and saw a hard cut — the frame
      *timestamps*, not the extracted images, are what locate the
      gesture in a VFR film.) Empty-photo placeholder and the shared
      wishlist detail unchanged by construction. Suite 542 in 85 +
      5 UI green.

- [x] **T037f** — The reorder lift loses its black slab.
      Review feedback: picking up a row to reorder turned the whole
      cell background black to the edges; wanted subtler, ideally no
      background at all since the lift itself already signals pick-up.
      *Verify: build; full suite; filmed drags on both screens.*
      Done (2026-08-30): the slab was UIKit's lift plateau showing
      through the clear-backed cell — with `.listRowBackground(Color
      .clear)`, the reorder snapshot composites onto an opaque black
      backing. True transparency isn't reachable from SwiftUI, so the
      rows now paint `.listRowBackground(theme.colors.background)`:
      pixel-identical at rest (the screen showed through the clear
      background anyway), but the lift snapshot becomes opaque
      screen-color and the plate reads as picked up on its own.
      Verified on film on both screens — no slab at lift, mid-drag,
      or settle, and the reorder still commits.
      Also removed in the same pass: a `.contentShape(.dragPreview,
      RoundedRectangle(...))` modifier both screens carried, whose
      comment claimed it clipped the lift to the plate's rounded rect.
      It turned out to be an *uncommitted working-tree leftover* from
      the earlier reorder debugging — never in the repo's history, so
      this commit's diff shows no trace of it. The baseline film
      showed the full-width slab *with* the modifier present — it
      shapes `.onDrag`-family previews, which the List reorder lift
      never consults — so both the modifier and its false comment
      went, and a re-film without them shows the same clean lift.
      (The comment was written from intention, not from film; the
      same lesson as T029c and the T056 note in CLAUDE.md.)
      Suite 542 in 85 + 5 UI green.

- [x] **T037g** — The un-valued callout's single-item push finds its
      destination. Review bug: tapping the dashboard's "1 item not
      yet valued" callout showed a black screen with a yellow warning
      icon — SwiftUI's missing-destination placeholder. The router
      pushes the item's id into the Items tab's bound path, but the
      list only registered `navigationDestination(item:)` for its row
      taps, which a value pushed into the path never consults. Fixed
      with a typed `navigationDestination(for: UUID.self)` serving
      the same detail screen. The multi-item case (the `.unvalued`
      filter request) already worked and is untouched. Verified on
      the simulator: the callout lands on the un-valued item's
      detail. Suite 542 in 85 + 5 UI green.

- [x] **T037h** — Pull-to-refresh stops snapping the list up under
      the spinner. Review bug on both lists: the rows snapped back to
      the top before the spinner finished, so it briefly drew on top
      of the first row. Cause: `load()` completes within a frame (the
      T056 lesson), so the bare `.refreshable` action returned before
      the spinner had even settled and the retraction fought the
      still-animating spinner. Fixed with `RefreshPacing.hold()` — a
      500ms hold after `load()` at all three refresh sites (both
      lists and the dashboard, which shares the mechanism), kept in
      the view layer so view-model unit tests don't inherit the
      sleep. Verified on film: the spinner spins in clear space with
      the rows parked below it, then the system's own coordinated
      retraction runs. Stated plainly: that retraction still
      crossfades — a mostly-faded spinner ghost crosses the row's
      top edge for a frame or two, same as stock apps — what's gone
      is the full-strength spinner sitting on the row. Suite 542 in
      85 + 5 UI green.

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

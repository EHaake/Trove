# Plan: Item Management Enhancements

**Status**: Draft — pending review
**Implements**: spec.md in this directory

## Data model / core types

### `Item.sortOrder`

| Property | Type | Notes |
|---|---|---|
| `sortOrder` | `Int` | default `0`, user-adjustable manual ordering — same shape as `WishlistItem.sortOrder`, same CloudKit reasoning (a scalar with a default needs no optionality) |

This is the one schema change in `010`. `CloudKitSchemaTests` already
validates this shape for `WishlistItem`; adding the identical field to
`Item` should validate the same way, but that's a claim to actually
re-run, not assume — first thing to check once the field lands, per
`CLAUDE.md`'s rule that every schema change gets checked by
`xcodebuild test` immediately.

### Backfill migration

Unlike `WishlistItem`'s `sortOrder` — which never had a "before" state,
since every wishlist item has existed with a manual position since
`001` shipped — `Item` already holds real user data. A schema-level
default alone leaves every existing item at `sortOrder = 0`
simultaneously: not a manual order, a tie across the whole collection.

**Proposed approach: a one-time, app-launch-time backfill routine, not
a formal `SchemaMigrationPlan`.** On first launch after this ships:
fetch all existing items ordered by `createdAt` ascending, assign
sequential `sortOrder` values (`0, 1, 2, ...`), save. Guarded by a
persisted flag (`UserDefaults` bool, e.g. `hasBackfilledItemSortOrder`)
read once at launch — the same narrow, single-purpose shape as
`T050`'s `-uiTesting` argument. Once the flag is set, the routine never
runs again, and — this is the important part — it never re-derives or
re-checks whether the current values "look backfilled." A heuristic
that tries to detect "has the user already customized this" and
re-backfills when it guesses wrong is exactly the kind of quiet
data-loss this project has already been burned by once (the
photo-orphan defect, the false-passing persistence tests) — a flag
that flips once and is never consulted for its correctness again is
the safer shape.

One detail found at T005, not anticipated here: the ephemeral
`-uiTesting` store is deliberately skipped and never sets the flag.
`UserDefaults` isn't scoped to a store — a flag burned during a
UI-test launch, against a throwaway store with nothing in it, would
permanently block the real store's backfill on that device.

Why `createdAt` specifically, not one of `Item`'s other three sortable
attributes: none of desire-to-keep, value, or purchase date is more
"canonical" than the others — `ItemListView` has no single default sort
today, so backfilling from any one of them would be an arbitrary pick
wearing a principled-looking justification. `createdAt` is the one
attribute that isn't really a sort *mode* a user chooses between — it's
just the order things were added, a defensible neutral starting point
for a manual order the user is then free to rearrange from scratch.

A real `SchemaMigrationPlan`/`VersionedSchema` would be the more
"correct" SwiftData-native way to run a data-transforming migration,
but `Item` has never needed one before — `001` never changed the schema
after shipping, so there's no existing migration infrastructure to
extend. Introducing `VersionedSchema` formality for exactly one
one-time backfill is more machinery than the problem needs; the
launch-time routine is smaller, narrower, and easier to reason about,
in the same spirit as this project's existing preference for
`ModelContext`-based fetches over `@Query` and a hand-built `TroveStore`
over implicit container setup. Worth reconsidering if a second schema
migration ever comes up and a real pattern is worth establishing then.

**Needs its own tests, not just a manual check**: given a fresh
install with items and no backfill flag set, confirms sequential,
`createdAt`-ordered `sortOrder` values get assigned; given an install
where the flag is already set, confirms existing `sortOrder` values are
left completely untouched — including a version of this test that
seeds an *already-customized* order first, to prove the routine really
is a no-op the second time, not just untested the second time.

## Architecture / screens / components

### `ItemListView` — converts from `ScrollView`/`LazyVStack` to `List`

Following `WishlistView`'s already-proven pattern exactly, not
inventing a new one: plain list style, hidden separators, clear row
backgrounds, custom insets, tap-gesture navigation instead of
`NavigationLink` (avoids the disclosure chevron a naive conversion
shows). This is the lower-risk move — it's copying what's already
shipped, tested, and confirmed to host Trove's custom row styling on
the other screen, and it's what `ROADMAP.md`'s own `010` entry
predicted before this spec had a name.

Once it's a `List`:
- `.swipeActions(edge: .trailing)` — Delete, behind the shared
  confirmation alert (see `ItemDeleteCopy` below).
- `.swipeActions(edge: .leading)` — Edit, Duplicate.
- `.onMove` — attached only while the active sort is `.custom`; hidden
  (not just disabled) otherwise, mirroring how `WishlistView` already
  gates its own manual-order mode.

**Worth checking, not assuming: does `WishlistView`'s existing
trailing swipe already use `.swipeActions`, or is it still built on
`.onDelete`?** The docs describe *what* it does (presents the shared
alert) but not the exact modifier. If it's still `.onDelete`-based,
that's a second, different mechanism for "swipe reveals a destructive
action" living alongside the one `ItemListView` needs built fresh —
worth converging both lists onto one shared mechanism here rather than
carrying two independently-written implementations of the same idea,
per `CLAUDE.md`'s "one source of truth" instinct.

### `WishlistView` — loses its button, gains a leading swipe and two sorts

- The "Reorder" button is removed from the header entirely.
- `.swipeActions(edge: .leading)` — Edit, Duplicate (new; trailing
  delete swipe is unchanged in behavior, only possibly unified in
  mechanism per the note above).
- Sort picker gains "Desire" and "Alphabetical" alongside "Custom" and
  "Cost."

### `ItemListViewModel`

- New sort case for manual/"Custom" mode, added to whatever the existing
  sort-option type is actually called in source — not guessing a name
  here, reconcile against the real enum.
- `delete(id:)` — new. Must live here, not inline in a swipe button's
  closure — `DeletionGuardTests` already enforces "no view deletes from
  the store directly" as a structural rule, and this new path needs to
  honor it from day one, not get caught retroactively.
- `duplicate(id:)` — new, implementing the field-copy rules from
  `spec.md`'s "Key user flows" (copy everything but serial number;
  photos included; no Sell Plan inheritance; placed adjacent in manual
  order).
- A reorder method mirroring `WishlistViewModel`'s existing logic and
  its dense/unique `sortOrder` invariant (`T034`) closely enough that
  it's worth sharing the implementation rather than writing it twice —
  see `ManualOrderHelper` below.

### `WishlistViewModel`

- New sort cases: Desire, Alphabetical (naming pending reconciliation
  against the real source, same caveat as above).
- `duplicate(id:)` — new; wishlist didn't have this capability before
  `010` either.
- Comparator logic for the two new sorts, each combined with manual
  order as its tie-break (see Resolved decisions).

### `ManualOrderHelper` (proposed shared component)

Both view models now need near-identical manual-order logic: compute
the next append position for a new or duplicated row, perform a
reorder while preserving the dense/unique `sortOrder` invariant
`WishlistViewModelTests` already guards, and combine any attribute
comparator with manual order as a tie-break. Worth factoring into one
shared utility — in the same spirit as `CategoryPathHelper`, generic
enough to serve anything exposing a `sortOrder: Int` — rather than
writing the same logic twice now that two entities need it instead of
one. A real payoff beyond avoiding duplication: the *same* test suite
that already covers `WishlistViewModel`'s reorder invariant can cover
`ItemListViewModel`'s too, instead of two independently-written and
independently-maintained copies that could quietly drift apart.

### `ItemDeleteCopy` (proposed shared component)

Mirrors `WishlistDeleteCopy` exactly: one shared copy source read by
both `ItemListView`'s swipe-delete confirmation and `ItemDetailView`'s
overflow-menu delete confirmation, so the two entry points can't drift
the way `WishlistDeleteCopy` was built specifically to prevent on the
wishlist side.

**Genuinely can't tell from the documents available in this chat
whether `ItemDetailView` already has delete-confirmation copy that
names the Sell Plan consequence, or just a generic "are you sure."**
Flagging as the first thing to check against the real source, not
guessing either way — this determines whether the work here is "extract
existing copy into a shared constant" or "write new copy from
scratch." Proposed copy, to use if new copy turns out to be needed:

> "This item will be removed, along with its photos. If it's part of a
> Sell Plan, it'll no longer be included there."

Matches `WishlistDeleteCopy`'s plain, consequence-naming voice rather
than inventing a new tone for one screen.

### Visual specifics — fully resolved

Updated from the earlier placeholder now that
`design/elements/010-item-management/` contains real HTML, not just a
description of it. Real values were extracted, not estimated from
screenshots — corrected one of this document's own earlier guesses in
the process (row corner radius stayed `3px`, unchanged from `001`; an
eyeballed read of the screenshot alone had suggested otherwise).

- **Swipe-action iconography**: done. Real values in `tokens.md`'s
  "Swipe-action rows" table.
- **Sort pickers, both screens**: resolved. The earlier open
  verification — whether a four-option picker crowds `ItemListView`'s
  header — turned out to be moot: the actual pattern is a compact
  badge that opens a dropdown, so its footprint doesn't grow with
  option count. No layout risk to carry forward.
- **`DesireGauge`**: resolved and documented in full in `tokens.md`.
  The earlier open question (refinement vs. reshape of the control's
  underlying shape) is answered: same three sheared segments, same
  shear angle, extended with ascending height per segment plus a
  per-row legend. Stays inside `spec.md`'s stated bar.
- **Row treatment: accepted, and it's now `brief.md`'s standard, not
  just an exception for `010`.** Design's chosen treatment uses a real
  drop shadow plus an inset bevel — the thing `brief.md`'s original
  skeuomorphism section ruled out by name. Rather than let `010`
  quietly contradict a standing rule, `brief.md` itself was amended
  (see its own updated skeuomorphism section) to narrow, not remove,
  that constraint — restrained alpha-based depth is permitted now;
  literal materiality (metallic gradients, wood/leather texture,
  screws, stitching, photorealism) still isn't. Real values in
  `tokens.md`'s new "Row treatment" table.

**Naming, both resolved, asymmetrically.** The icon legend labels the
middle swipe action "Duplicate," but the actual swipe-reveal button
says "Copy" — kept as designed: "Duplicate" stays the name used in
`spec.md`, this document, and `tasks.md`; "Copy" is the on-screen
button text specifically, the same relationship `desireToKeep` already
has to whatever a user actually sees. The sort picker's manual-order
option is labeled "Custom," not "Yours" — but here the reasoning was
different: "Yours" was confusing as a *concept*, not just wordy as a
button, confirmed by the person who built the app finding it unclear
in their own early use. That's a reason to replace the term
everywhere, not just on screen — every "Yours" in this document has
been renamed to "Custom," including the internal `.custom` sort case,
and the same rename is still needed in `spec.md` and `tasks.md` (not
done here — see the note accompanying this file).

One more inconsistency inside Design's own output, minor and still
worth a look during implementation: the swipe-reveal mockup's row (in
the same HTML file, further down) uses a plain `1px solid #26272A`
border rather than the "extruded plate" treatment from the
row-treatment section above it — almost certainly because that mockup
was focused on illustrating the gesture, not re-rendering final row
chrome. The extruded-plate treatment applies uniformly, including to a
swiped-open row, not just the resting state.

## Sort direction (proposed, not locked)

`spec.md` left this open. Proposing defaults here since `plan.md` is
where that's supposed to get resolved — but these are modest-stakes
product calls, not technical constraints, so easy to override:

- **Cost**: ascending (cheapest first) — closer to "what could I
  realistically buy soon" than a ranked list of aspirations, and the
  more common convention for a wishlist/shopping context generally.
- **Desire**: descending by tier — Next → Soon → Someday, highest
  desire first. Matches the "highest-desire-first seems the more
  natural read" note already in `spec.md`.
- **Alphabetical**: A→Z. Standard convention, low stakes.

## Known limitations

### VoiceOver-accessible reordering — resolved, no longer a limitation

This section originally carried forward `spec.md`'s "no
VoiceOver-accessible entry point for manual reordering" non-goal as a
deliberate, documented gap. T027a's empirical check reversed the
premise, and `010` ships accessible reordering on both screens
instead: explicit "Move up"/"Move down" accessibility actions on the
rows of both lists, present while reordering is available — their
presence gated on reorderability rather than row position, because
position-conditional presence destabilized the List's reorder
rendering (spec.md's reorder flow records T029b's finding). (Formal
edit mode — what T027a measured as the native
carrier of those actions — is not used anywhere in the shipped
design; an interim build routed accessibility through it before the
intended minimal behavior was clarified.) The full account — what was
measured, the three-step Reorder-button story, and the
edit-mode/swipe-action trade that drove the final shape — lives in
`spec.md`'s corrected Non-goals entry and Resolved decisions, not
duplicated here.

## Testing strategy

- **`WishlistViewModelTests.theSortControlOffersNoRatingOption` gets
  explicitly removed, not left to bit-rot.** The test was written to
  assert a rule `010` deliberately overturns — its removal should say
  why in the commit that removes it, the same "honest reversal, not a
  quiet correction" treatment this spec's own docs have used
  throughout.
- New `ItemListViewModelTests`: `delete(id:)`, `duplicate(id:)` (field
  rules, Sell Plan non-inheritance, manual-order placement), reorder
  behavior mirroring `WishlistViewModelTests`'s existing shape,
  sort-by-"Custom" behavior.
- New `WishlistViewModelTests`: `duplicate(id:)`, Desire and
  Alphabetical sort correctness plus their manual-order tie-break.
- Backfill migration tests, including the idempotency case specifically
  (see Data model section) — this is the one piece of `010` where a
  bug means silently destroying a user's real data, so it gets the
  mutation-verified treatment `CLAUDE.md` reserves for claims that
  matter.
- `CloudKitSchemaTests` re-verified once `Item.sortOrder` exists.
- `DeletionGuardTests` extended to cover `ItemListView`'s new swipe
  path — confirms the structural rule holds on the new entry point, not
  just the ones that existed when the test was written.
- A test asserting `Item`'s delete confirmation actually contains the
  Sell Plan consequence language, mirroring however
  `WishlistDeleteCopy`'s content is already asserted.

## File structure

Two new files, locations proposed by analogy to where their closest
existing counterpart lives — worth confirming against the real repo
rather than assumed:

```
Trove/
  Extensions/
    ManualOrderHelper.swift   new — shared reorder/tie-break logic,
                               alongside Int+Currency.swift and other
                               cross-cutting utilities
  Views/
    Shared/
      ItemDeleteCopy.swift    new — mirrors wherever WishlistDeleteCopy
                               already lives
```

Everything else is a modification to existing files
(`ItemListView`/`ItemListViewModel`, `WishlistView`/`WishlistViewModel`,
`Item.swift` for the new field), not a new file.

### Design asset organization (new convention — first spec to extend `design/`)

`010` is the first spec since `001` to add anything to the shared,
repo-root `design/` folder, so this is a real decision worth recording
rather than re-deriving next time:

- **Swipe-action icons** (Edit, Duplicate, Delete) → `design/icons/`,
  alongside the existing tab-bar icons. Not a new category — `icons/`
  already established itself at `001`'s `T044` as where reusable,
  sub-screen graphic marks live.
- **Row treatment, sort picker, and `DesireGauge` element output** → a
  new `design/elements/010-item-management/` folder, sibling to
  `screens/` and `icons/`. `screens/` holds whole rendered views;
  these are close-ups of one changed piece of an existing screen, not
  a new screen — mixing the two in one flat folder would leave
  `screens/` ambiguous about what it actually shows. Scoped by spec
  from the start, since `elements/` is likely to accumulate more per
  spec than `icons/` does.
- Each element's exported HTML sits alongside its screenshot — real,
  inspectable values, not just a picture of them.
- **The full Claude Design zip export is deliberately not committed.**
  It re-bundles everything already in `design/` from `001` alongside
  the new element output, which duplicates rather than adds anything.

## Resolved decisions

1. **Backfill via a one-time launch-time routine, not a formal
   `SchemaMigrationPlan`.** Simpler, narrower, and consistent with this
   project's existing preference for small, testable, purpose-built
   code over general migration machinery it's never needed before.
2. **`ManualOrderHelper` as a shared utility** rather than writing
   near-identical reorder/tie-break logic twice now that both `Item`
   and `WishlistItem` need it.
3. **`ItemDeleteCopy` as a shared constant**, matching
   `WishlistDeleteCopy`'s existing pattern, pending confirmation of
   whether `ItemDetailView` already has usable copy to extract or needs
   new copy written.
4. **Sort directions proposed** (Cost ascending, Desire
   highest-first, Alphabetical A→Z) — open to override, not treated as
   settled by virtue of being written down here first.
5. **Decided at the T039 close-out review (2026-08-30): yes — `Item`'s
   existing sorts adopt manual order as their tie-break**, through the
   same `ManualOrderHelper.areInOrder` the wishlist reads. This
   question had sat unanswered while spec.md's "Tie-break, confirmed:
   manual order … within any non-'Custom' sort" already promised it,
   and the first implementation silently answered no (name, then id) —
   the review caught the three documents and the code telling two
   stories. The name-tie test that pinned the old behavior was
   replaced, not weakened: the new tie tests use fixtures whose names
   run against the manual order, and were mutation-verified red
   against the old comparator before landing.
6. **`DesireGauge` gains a per-row "desire" legend — reversing `001`'s
   explicit "unlabeled in list rows" decision, not just refining it.**
   `001`'s `spec.md` states this plainly: the gauge "renders as an
   unlabeled three-segment gauge in wishlist rows and a labeled one in
   the form and detail screen... unlabeled in list rows, where it sits
   in the row's lower-right" — a deliberate choice, not an oversight,
   made because a label repeating down every row of a scrolling list is
   noise. `010` reverses it on purpose, not by accident: the
   redesigned gauge (stepped slots, same shape family as before —
   confirmed against the real HTML, not just described) ships with a
   small, dimmed-font legend on every row, chosen specifically to close
   the legibility gap `001`'s own sign-off flagged, without repeating
   the earlier "full-weight repeated text is noise" mistake the dimmed
   treatment is meant to avoid. Explicitly provisional, in the person
   steering this spec's own words — easy to remove if it reads as
   noisier in the running app than it does in Design's mockup.
7. **Row treatment's drop shadow/bevel — accepted, and elevated into an
   amendment to `brief.md` itself, not treated as a one-off exception.**
   The person steering this spec was explicit that the original
   flat-only reading of `brief.md` reflected an assumption about the
   limits of flat design, not a permanent boundary, and that Trove's
   visual identity is expected to keep evolving. `brief.md`'s
   skeuomorphism section now reflects that — narrowed, not deleted:
   restrained alpha-based depth is fine, literal materiality (metallic
   gradients, wood/leather texture, screws, stitching, photorealism)
   still isn't. Real values in `tokens.md`'s new "Row treatment" table.
8. **Two copy mismatches inside Design's own output, resolved
   differently from each other on purpose.** "Duplicate" (icon legend)
   vs. "Copy" (actual swipe button): keep "Duplicate" as this spec's
   name throughout the docs, treat "Copy" as the on-screen string only
   — a display-layer difference, not a conceptual one. "Yours" (every
   doc in this spec, until now) vs. "Custom" (actual sort picker):
   different reasoning, different resolution — "Yours" was unclear as
   a concept, not just wordy as a button, so "Custom" replaces it
   everywhere, including this document's own internal `.custom` sort
   case. `spec.md` and `tasks.md` still need the same rename applied —
   not done as part of this pass, since neither was available as a
   confirmed-current copy when this edit was made.

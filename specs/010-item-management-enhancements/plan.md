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
- `.onMove` — attached only while the active sort is `.yours`; hidden
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
- Sort picker gains "Desire" and "Alphabetical" alongside "Yours" and
  "Cost."

### `ItemListViewModel`

- New sort case for manual/"Yours" mode, added to whatever the existing
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

### Visual specifics — deferred, not designed here

Row treatment, the now-four-option sort pickers on both screens,
`DesireGauge` legibility, and swipe-action iconography all stay pending
the design-brief addendum and a real Claude Design pass, per `spec.md`.
This plan covers the mechanism (SwiftUI APIs, view model shape), not
the polish — same split `001`'s `plan.md` kept with `design/brief.md`
throughout.

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

### No VoiceOver-accessible entry point for manual reordering

Carried forward from `spec.md`'s Non-goals, in the same spirit as
`001`'s "no Dynamic Type" and "pull-to-refresh unreachable on any empty
state" entries: a real, deliberate gap, not an oversight nobody
noticed. Neither list's press-and-hold-drag gesture has an accessible
equivalent today, on either screen, and this spec doesn't fix that —
it documents it. Revisit if this turns out to matter more in practice
than expected, the same trigger `001` used for its own deferred
limitations.

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
  sort-by-"Yours" behavior.
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
5. **Worth considering, not decided**: now that `Item` has a manual
   order to fall back on, should its three *existing* sorts
   (desire-to-keep, value, purchase date) also adopt manual order as
   their tie-break, the same way the two new wishlist sorts do? Cheap
   to add given `ManualOrderHelper` already exists for this reason, and
   consistent with treating manual order as the universal fallback —
   but it wasn't asked for, so raising it here as an option rather than
   folding it in unasked.

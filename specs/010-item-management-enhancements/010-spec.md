# Spec: Item Management Enhancements

**Status**: Draft — pending review
**Depends on**: `001-core-inventory` (shipped; this spec modifies its screens directly)

## Summary

Brings the owned-items list to interaction parity with the wishlist
(swipe-to-delete), adds swipe-revealed Edit and Duplicate actions to
both lists, extends the existing delete-confirmation model to every
delete path consistently (rather than removing it), and gives the list
rows, the wishlist's "Reorder" control, and the `DesireGauge` a real
visual refinement pass.
This is the first spec since `001` shipped that's substantially about
UI polish rather than new capability — both an interaction-parity fix
and Trove's first dedicated design-refinement pass.

## Goals

1. Let a user delete an owned item via a trailing swipe on
   `ItemListView`, matching the gesture already on `WishlistView`.
2. Extend delete confirmation to every delete path, consistently:
   `ItemListView`'s new swipe gesture shows the same confirmation
   `WishlistView`'s swipe and both detail screens' overflow-menu delete
   already show. Nothing loses its existing confirmation — this adds
   the one path that doesn't have it yet, rather than removing the ones
   that do.
3. Let a user reveal Edit and Duplicate via a leading swipe on rows in
   both `ItemListView` and `WishlistView`.
4. Let a user duplicate an owned item or wishlist item from the list:
   creates a new row with nearly every field copied — serial number is
   the one exception, cleared on owned items — inserted into the list
   with no forced navigation.
5. Make the wishlist's "Reorder" control read as an actual, discoverable
   button rather than plain text with a small, easy-to-miss tap target.
6. Give list rows on both screens a small amount of additional visual
   depth/character, without crossing into anything `design/brief.md`'s
   "explicitly not skeuomorphic" section already rules out.
7. Improve `DesireGauge`'s at-a-glance legibility as a *desire*
   indicator specifically — not just "three boxes" — via a real Claude
   Design pass.

## Non-goals (explicitly deferred)

- **Soft-delete / recycle bin.** Came up while scoping this spec's
  delete model and is real enough to want its own treatment — see the
  `011-recycle-bin` entry in `ROADMAP.md`. Deferred because it needs a
  settings/utility surface that doesn't exist yet in Trove's three-tab
  shell. Directly relevant to this spec's own delete decision, though:
  deletion is still permanent in `010`, which is exactly why every
  delete path keeps (or gains) a confirmation step rather than losing
  one — removing the confirmation is only safe once `011` makes
  deleting reversible.
- **A user-facing toggle for delete confirmation.** `010` ships
  confirmation as a fixed default on every path. Letting a user turn it
  off (paired with `011`'s recycle bin providing the safety net
  instead) is a real feature, deferred to the same future settings
  surface — see the new `012-settings-menu` entry in `ROADMAP.md`.
- **A user-facing toggle for whether photos carry over on duplicate.**
  `010` ships "copied" as the fixed default (see Resolved decisions).
  Making that user-configurable is deferred to `012-settings-menu` for
  the same reason as the confirmation toggle above.
- **Bulk / multi-select delete or actions.** Not raised as an actual
  need during scoping, and Trove's collections (tens to low hundreds of
  items) aren't at a scale where this earns its complexity yet.
- **Archiving, or any "this item left my collection" tracking.** That's
  `006-mark-as-sold`'s territory. A recycle bin (above) is about
  recovering an accidental delete, not about tracking a real-world sale
  — the two are easy to conflate but answer different questions.
- **Manual reorder / drag-to-reorder on the owned-items list.** The item
  list is attribute-sorted (desire, value, purchase date) by design; it
  doesn't have the wishlist's "curated personal order" concept, and
  nothing in scoping raised a need for one.
- **In-row editable desire dial** (dragging a rating directly on a list
  row). Tension with `brief.md`'s "small and quiet in list contexts" for
  the dial; not raised as a need here.

## Entities

No new entities and no new fields. Duplicate is a new *operation* on
the existing `Item` and `WishlistItem` types — conceptually "a new row
with nearly every field copied from the original, serial number the
one exception on owned items" — not a schema change. Exact
field-by-field behavior is in "Key user flows" below.

One thing worth flagging for `plan.md` specifically, not resolved here:
since photos now carry over on duplicate too, and the schema's
one-photo-one-parent rule (`PhotoOwnershipTests`) doesn't support a
`Photo` belonging to two items, duplicating means genuinely new `Photo`
rows with duplicated `.externalStorage` data — not a shared reference.
Duplicating an item with several photos duplicates that storage, both
locally and in CloudKit's sync payload. Not a reason to reverse the
decision, just a real cost worth being explicit about rather than
discovering mid-implementation.

## Key user flows

### Delete an owned item or wishlist item

From either list, swiping left on a row reveals a Delete action.
Tapping it shows the same confirmation alert every other delete path in
the app already uses — the wishlist's swipe and both entities' detail
screens all confirm before committing, and `ItemListView`'s new swipe
gesture now does too, rather than being the one path that doesn't.

What the alert says is unchanged by this spec on the wishlist side
(`WishlistDeleteCopy`, already explaining that a wishlist item's own
Sell Plan selection goes away without touching the owned items in it).
For owned items, the confirmation should name the equivalent
consequence — that deleting an item silently drops it out of any Sell
Plan it was selected in — with the same specificity the wishlist side
already has, not a generic "are you sure." Whether `ItemDetailView`'s
current alert already says this, or needs new copy to, is a
`plan.md`-level check, not a product decision — the requirement here is
that it does, by the time this ships.

Underlying cascade behavior itself is unchanged either way: photos are
still removed with a deleted item, and the Sell Plan
membership/nullify rules work exactly as they do today. Only
`ItemListView` gains a delete path it didn't have; nothing loses the
confirmation it already had.

### Edit an owned item or wishlist item, from the list

From either list, swiping right on a row reveals Edit and Duplicate.
Tapping Edit opens that row directly in the existing add/edit form —
the same form already reached from the detail screen. This is a
shortcut into an existing flow, not a new one.

### Duplicate an owned item, from the list

Tapping Duplicate (from the same leading-swipe reveal) immediately
creates a copy, with no intermediate screen or confirmation:

- **Copied as-is**: name, category path, purchase price, purchase date,
  purchase location, current value, desire-to-keep, condition and
  condition notes, notes, and photos. Photos carrying over is
  deliberate, not an oversight — a photo is often a stock/reference
  image applicable to both units rather than a photo of one specific
  physical item, and it's easy to swap out on the copy afterward if it
  isn't.
- **Reset**: serial number only, cleared — it's meant to identify one
  physical unit, so carrying it over would have two rows claiming the
  same one.
- **Not inherited**: membership in any Sell Plan. If the original was
  selected in a wishlist item's Sell Plan, the duplicate is not
  automatically added to it.

The new row appears in the list wherever it falls under the current
sort — no forced navigation to it, no confirmation step.

### Duplicate a wishlist item, from the list

Same shape as above, adjusted for the entity:

- **Copied as-is**: name, category path, estimated cost, notes,
  desire-to-own, and photos — same reasoning as owned items above, and
  arguably even more likely to be a stock/reference image here, since a
  wishlist item isn't owned yet.
- **Not inherited**: the duplicate's own Sell Plan selection starts
  empty — it does not inherit the original's `plannedSaleItems`.
- Manual order: the duplicate is placed immediately after the original
  in the wishlist's manual reorder sequence (exact mechanics — dense
  `sortOrder` renumbering, etc. — are a `plan.md` decision, not a
  product one).

### Reorder the wishlist

Unchanged in mechanism — drag to reorder, entered via a dedicated
control — but the control itself needs to read as a real, tappable
button with an adequate tap target, addressed in the design-brief
addendum rather than here.

### Browsing either list

Rows read with a bit more visual depth than the current flat rectangle;
exact treatment lives in the design-brief addendum.

## Design requirements

Visual specifics (row treatment, the reorder control's affordance,
`DesireGauge` legibility, and any new iconography for the swipe
actions) belong to a design-brief addendum and a real Claude Design
pass, not this spec — but each needs to clear a stated bar:

- **Row treatment**: more perceived depth/life than the current flat
  rectangle, without crossing into anything `brief.md`'s "explicitly
  not skeuomorphic" section already rules out by name (no bevels or
  embossing, no drop shadows simulating a raised physical control).
  Subtle is the target — "slightly nicer," not a redesign. `tokens.md`'s
  existing `surfaceInset` token is a plausible starting vehicle, not a
  locked answer.
- **Reorder control**: unambiguously reads as a button on sight, with a
  tap target that doesn't require trial and error to find.
- **`DesireGauge`**: reads as a *desire* indicator specifically to
  someone encountering it without prior context, while remaining the
  flat/graphic three-segment control already described in `brief.md`
  and `plan.md` — a legibility fix, not a request to redesign the
  control's underlying shape.
- **New swipe-action iconography** (Edit, Duplicate, Delete) should
  feel like it belongs to the same flat/graphic instrument language the
  tab icons and `AddButton` already established (`T044`).

## Acceptance criteria

Not yet signed off — listed here as the testable target, to be checked
off (with citations, matching `001`'s convention) once built.

- [ ] User can delete an owned item via a trailing swipe on
      `ItemListView`; the row and the underlying item are removed.
- [ ] Deleting an owned item shows the same confirmation alert on both
      entry points (list swipe and detail screen's overflow menu), and
      that alert names the sell-plan cascade consequence with the same
      specificity the wishlist's existing alert has.
- [ ] Deleting a wishlist item continues to show its existing
      confirmation alert on both entry points, unchanged by this spec.
- [ ] Underlying cascade behavior is unchanged by the above: a deleted
      item's photos are removed; a deleted owned item is silently
      dropped from any Sell Plan that had selected it; a deleted
      wishlist item's own Sell Plan selection disappears without
      affecting the owned items that were in it.
- [ ] User can reveal Edit and Duplicate via a leading swipe on rows in
      both `ItemListView` and `WishlistView`.
- [ ] Tapping Edit from the swipe reveal opens the existing add/edit
      form for that row, pre-filled, identical to reaching it from the
      detail screen.
- [ ] Tapping Duplicate creates a new row per the field rules in "Key
      user flows," inserted into the list with no forced navigation and
      no confirmation step.
- [ ] A duplicated owned item does not inherit membership in any Sell
      Plan the original was part of; a duplicated wishlist item's own
      Sell Plan selection starts empty.
- [ ] The wishlist's Reorder control is visually button-like and meets
      standard minimum touch-target sizing.
- [ ] List rows on both screens read with more visual depth than a flat
      rectangle, per the design-brief addendum, without introducing
      treatment `brief.md` rules out.
- [ ] `DesireGauge` reads as a desire-specific indicator to someone
      encountering it without prior context, per the design-brief
      addendum.

## Resolved decisions

- **Delete confirmation kept everywhere, and extended to the one path
  missing it — reversed from an earlier draft of this spec.** An
  earlier pass proposed removing confirmation app-wide for a leaner
  two-tap flow; reconsidered because deletion is still permanent in
  `010` (no recycle bin yet), so removing the app's one safety net
  wasn't actually the right trade, regardless of tap count. Landed
  instead: `WishlistView`'s swipe, both detail screens' overflow-menu
  delete, and now `ItemListView`'s new swipe gesture all confirm before
  committing, consistently. Once `011-recycle-bin` ships and deletion
  becomes reversible, removing the confirmation step becomes the right
  call — and a per-user toggle for it, rather than an app-wide flip, is
  deferred to `012-settings-menu` (see Non-goals).
- **Duplicate field rules** settled as above: everything copied except
  serial number, which clears — photos included, deliberately, since
  they're often a stock/reference image rather than a photo of one
  specific unit. Sell Plan membership/selection is never inherited. A
  per-user toggle for the photo behavior specifically is deferred to
  `012-settings-menu`. The storage cost of that choice (real duplicated
  `Photo` rows, not a shared reference — see Entities) is accepted
  knowingly, not an oversight.
- **Both swipe directions ship on both lists** — not owned items only.
- **Row visual treatment stays inside `brief.md`'s existing
  no-bevel/no-drop-shadow constraint**; the exact mechanism is a
  design-brief-addendum and Claude Design decision, not resolved in
  this spec.
- **`DesireGauge` legibility gets a real Design pass inside this spec**
  rather than splitting into its own spec — the reasoning being that
  `010` is already Trove's first dedicated post-v1 UI-refinement spec,
  so folding a related legibility fix in here beats a separate spec for
  one small piece.
- **Recycle bin captured as a new roadmap candidate** (`011-recycle-
  bin`), deferred — needs a settings/utility surface that doesn't exist
  yet, now tracked as its own candidate too (`012-settings-menu`, which
  also picks up the delete-confirmation and duplicate-photo toggles
  above, plus the sync-status indicator already deferred at `T049a`).

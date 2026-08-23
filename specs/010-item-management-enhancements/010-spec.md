# Spec: Item Management Enhancements

**Status**: Draft — pending review
**Depends on**: `001-core-inventory` (shipped; this spec modifies its screens directly)

## Summary

Brings the owned-items list to full behavioral parity with the
wishlist — swipe-to-delete, swipe-revealed Edit and Duplicate, and
manual drag-to-reorder via a "Yours" sort option matching wishlist's
own convention — extends the existing delete-confirmation model to
every delete path consistently (rather than removing it), removes the
wishlist's now-redundant "Reorder" button, expands the wishlist's own
sort options ("Desire" and "Alphabetical" alongside "Yours" and
"Cost"), and gives the list rows and the `DesireGauge` a real visual
refinement pass.
This started as an interaction-parity and design-refinement spec and
has grown to include a couple of genuinely foundational pieces along
the way — `Item`'s new `sortOrder` field, and revisiting one of `001`'s
shipped, tested sort decisions — worth knowing going into `plan.md`,
even though the spec's overall character is still mostly UI/UX
refinement rather than a new feature concept.

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
5. Give `ItemListView` the same manual drag-to-reorder capability
   `WishlistView` already has: a "Yours" option in the sort picker
   (alongside desire-to-keep, value, and purchase date) that shows the
   list in its manual order and enables press-and-hold-then-drag —
   matching exactly how `WishlistView` already exposes its own "Yours"
   mode. Full behavioral parity between the two lists, not just a
   shared gesture vocabulary. Neither list gets a separate "Reorder"
   entry-point button; the sort picker is the whole entry point on
   both.
6. Give list rows on both screens a small amount of additional visual
   depth/character, without crossing into anything `design/brief.md`'s
   "explicitly not skeuomorphic" section already rules out.
7. Improve `DesireGauge`'s at-a-glance legibility as a *desire*
   indicator specifically — not just "three boxes" — via a real Claude
   Design pass.
8. Expand `WishlistView`'s sort options beyond "Yours" and "Cost": add
   "Desire" (by desire-to-own) and "Alphabetical" (by name), plus
   whatever else makes sense for a personal wishlist. Reverses `001`'s
   deliberate decision not to offer a desire-based sort — see Resolved
   decisions for why that's a deliberate, confirmed choice for `010`,
   not `001`'s reasoning being treated as still-settled.

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
- **In-row editable desire dial** (dragging a rating directly on a list
  row). Tension with `brief.md`'s "small and quiet in list contexts" for
  the dial; not raised as a need here.
- **A VoiceOver-accessible entry point for manual reordering.** Neither
  list's drag-to-reorder gesture has one today — raised while scoping
  this spec and deliberately left unsolved rather than folded in as an
  extra requirement. Documented here as a known gap, to carry into
  `plan.md`'s known-limitations section (matching `001`'s convention for
  things like "no Dynamic Type" and "pull-to-refresh unreachable on any
  empty state") rather than going unrecorded.

## Entities

One new field: owned items gain a manual/custom order, the same
concept `WishlistItem`'s `sortOrder` already represents — a
user-adjustable position, independent of (and layered on top of) the
existing attribute-based sorts. This is a genuine schema addition to
`Item`, not just a UI change; the exact field shape, default value, and
how existing items get a sensible starting order when this ships
(rather than every item tying at the same default) are `plan.md`
decisions, not resolved here. Also worth a `plan.md`-level reminder,
not a new rule: any change to `Item`'s schema needs `CloudKitSchemaTests`
to still validate, per `CLAUDE.md`.

Duplicate is a new *operation* on the existing `Item` and
`WishlistItem` types — conceptually "a new row with nearly every field
copied from the original, serial number the one exception on owned
items" — not a schema change on its own. Exact field-by-field behavior
is in "Key user flows" below.

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
- **Manual order**: the duplicate is placed immediately after the
  original in the manual order — same treatment as wishlist duplicates
  below, now that owned items have a manual order too (see "Reorder
  either list"). Exact `sortOrder` mechanics are a `plan.md` decision.

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

### Reorder either list

Both `ItemListView` and `WishlistView` support manual drag-to-reorder
via the same native press-and-hold-then-drag gesture directly on a
row, entered the same way on both screens: a "Yours" option in the
sort picker, matching `WishlistView`'s existing convention (previously
"Yours" and "Cost"; now also "Desire" and "Alphabetical" — see below).
Selecting "Yours" shows the list in its manual order and enables the
drag gesture; selecting anything else hides it. This is new capability
for `ItemListView`, which had no manual order or "Yours" option at all
before this spec (see Resolved decisions for why that reverses an
earlier non-goal); `WishlistView` already has both, minus the
redundant "Reorder" button being removed alongside this change.

Switching to a different sort doesn't discard the manual order
underneath — selecting "Yours" again shows it exactly as last
arranged.

Existing owned items need a sensible starting manual order the first
time this ships, rather than every item tying at the same default value
— the concrete backfill strategy is a `plan.md` decision.

Neither list's reordering has a VoiceOver-accessible entry point today
— see Non-goals.

### Wishlist sort options, expanded

`WishlistView`'s sort picker gains two new options alongside "Yours"
and "Cost": "Desire" (by desire-to-own) and "Alphabetical" (by name,
case-insensitive, matching how the app already treats free-typed text
elsewhere). This reverses a decision `001` shipped and tested — see
Resolved decisions for why that's a deliberate, confirmed choice, not
an oversight.

Tie-break, confirmed: manual order breaks ties within any non-"Yours"
sort — a tier of same-desire wishlist items (there are only three
tiers, so ties are the common case, not an edge case) shows in
whatever relative order they currently hold manually; two
identically-named items under "Alphabetical" resolve the same way. One
rule for every sort mode rather than a different one each, and it gives
"Yours" a second job as the fallback ordering everything else falls
back on.

"Desire" and "Alphabetical" compose with category filtering exactly
like "Cost" already does — filter to a category and sort by Desire at
the same time, both active together, the same as every existing
attribute sort already allows. This is unlike "Yours": manual
drag-to-reorder remains filter-incompatible, per the existing guard —
dragging is only offered against the list's full, unfiltered manual
order, since reordering a filtered view would silently misorder items
that aren't currently visible.

Not decided here: which direction "Desire" sorts (highest-desire-first
seems the more natural read, but "Cost" and "Alphabetical"'s own
directions aren't explicitly documented anywhere either — worth
settling all three together in `plan.md`, not just this one). "Whatever
else makes sense" beyond these two is also still open — "Recently
added" (by creation date) is a plausible candidate, not decided.

### Browsing either list

Rows read with a bit more visual depth than the current flat rectangle;
exact treatment lives in the design-brief addendum.

## Design requirements

Visual specifics (row treatment, `DesireGauge` legibility, the sort
pickers on both screens, and any new iconography for the swipe
actions) belong to a design-brief addendum and a real Claude Design
pass, not this spec — but each needs to clear a stated bar:

- **Row treatment**: more perceived depth/life than the current flat
  rectangle, without crossing into anything `brief.md`'s "explicitly
  not skeuomorphic" section already rules out by name (no bevels or
  embossing, no drop shadows simulating a raised physical control).
  Subtle is the target — "slightly nicer," not a redesign. `tokens.md`'s
  existing `surfaceInset` token is a plausible starting vehicle, not a
  locked answer.
- **Sort picker on both screens**: `ItemListView` gains a fourth option
  ("Yours"), `WishlistView` gains a third and fourth ("Desire",
  "Alphabetical") — both pickers now need to read cleanly with more
  options than they were designed for, without becoming its own source
  of clutter. The entry-point *mechanism* is resolved (a sort option,
  not a separate control); how it reads with four options in it isn't.
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
- [ ] The wishlist's "Reorder" button no longer appears anywhere in the
      UI; press-and-hold-then-drag reordering on wishlist rows still
      works exactly as it does today.
- [ ] User can drag-to-reorder owned items in `ItemListView` via the
      same press-and-hold gesture `WishlistView` already uses; no
      separate "Reorder" button appears on either screen.
- [ ] Manual order on `ItemListView` persists across app launches and
      syncs across devices, the same as `WishlistView`'s `sortOrder`
      already does.
- [ ] Dragging to reorder is only available while "Yours" is selected
      on either screen — not while `ItemListView` is sorted by
      desire-to-keep, value, or purchase date, or `WishlistView` by
      Cost, Desire, or Alphabetical, and not while either list is
      filtered by category or search.
- [ ] Selecting a different sort and returning to "Yours" shows the
      manual order exactly as last arranged — it isn't discarded.
- [ ] Existing owned items have a sensible, non-tied starting manual
      order the first time this ships.
- [ ] `WishlistView`'s sort picker offers "Desire" and "Alphabetical"
      in addition to "Yours" and "Cost."
- [ ] Ties within a non-"Yours" sort (e.g., two wishlist items at the
      same desire tier) resolve by manual order — the confirmed
      tie-break, not left open.
- [ ] "Desire" and "Alphabetical" sorts on `WishlistView` compose with
      category filtering exactly like "Cost" already does — both active
      simultaneously. "Yours" remains the one mode that requires an
      unfiltered, unsearched view, per the existing guard.
- [ ] Neither list's drag-to-reorder gesture has a VoiceOver-accessible
      equivalent; this is documented as a known gap, not silently
      dropped from the record.
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
- **Wishlist's "Reorder" button removed rather than redesigned —
  reversed from Goal 5's earlier framing.** Turned out manual
  reordering already works via a native press-and-hold-then-drag
  gesture directly on rows, independent of the button; the button was
  a redundant second entry point into a capability that already didn't
  need one, not a real UI problem worth a Design pass. This also
  shrinks the design-brief addendum — no bespoke reorder-button
  treatment needed.
- **`ItemListView` gains manual reorder too — a second, bigger reversal
  of an earlier non-goal in the same spec.** The original draft
  explicitly ruled this out ("attribute-sorted by design... nothing in
  scoping raised a need for one"); walked back once the goal became
  full behavioral parity between the two lists, not just shared
  gestures for delete/edit/duplicate. This is a real schema addition —
  `Item` gains a `sortOrder` field `WishlistItem` already had, not
  present before — the one genuinely foundational piece of `010`, and
  worth the review scrutiny `CLAUDE.md`'s "foundational, hard-to-reverse
  work" tier calls for once this reaches `tasks.md`, unlike the rest of
  this spec's comparatively mechanical UI work.
- **The VoiceOver question raised while scoping this is deliberately
  left open, not solved.** Neither list's drag-to-reorder has an
  accessible entry point today, on either screen — documented as a
  known gap (see Non-goals), matching `001`'s convention for `plan.md`
  "known limitation" sections, rather than blocking this spec on fixing
  it or letting it go unrecorded.
- **`ItemListView`'s "Yours" sort option resolves what was previously
  an open design question** (how a user enters manual-order mode) —
  same convention `WishlistView` already established, a sort-picker
  option rather than a separate control. Confirms the earlier read on
  `WishlistView`'s own button, too: "Yours" was always the real entry
  point underneath it; the button was genuinely redundant with it, not
  a guess.
- **`WishlistView`'s sort options expand from two ("Yours"/"Cost") to
  at least four — reversing a decision `001` shipped and tested, not
  just an earlier draft of `010`.** `001`'s `spec.md` states plainly
  that desire-to-own "does not affect list ordering," backed by
  `WishlistViewModelTests.theSortControlOffersNoRatingOption` — a test
  written specifically to assert the sort control does *not* offer a
  desire-based mode. The reasoning on record: a 1–3 scale produces
  mostly-ties, and a rating silently competing with manual order is
  worse than one ordering system winning. Revisiting now because the
  mechanism has changed since that reasoning was written — every sort
  is an explicit picker choice today, not something that can silently
  override manual order, which resolves the "competing systems" half of
  the original concern. The "mostly-ties" half is real, weighed
  deliberately, and answered rather than left open — see the next
  entry. `001`'s own docs aren't being rewritten — they correctly
  describe what was true when `001` shipped — but `010` now supersedes
  that specific decision going forward, recorded here so the two specs
  don't read as contradicting each other by accident.
- **Tie-break for every non-"Yours" sort, confirmed: manual order.**
  Weighed and decided, not left as a `plan.md` open question — a
  desire-based sort is worth having despite the ties a 3-tier scale
  produces, and manual order is a good enough answer for what breaks
  them: it needs no new rule of its own, and it gives "Yours" a second
  job as the fallback underneath every other sort. Confirmed alongside
  this: "Desire" and "Alphabetical" compose with category filtering
  exactly like "Cost" already does — filter and attribute-sort both
  active at once, no special-casing. Only "Yours" keeps the existing
  filter-incompatibility guard, since dragging against a filtered view
  risks silently misordering items not currently on screen.
- **Scope note**: the sort-option expansion isn't required to give
  `ItemListView` reorder parity — it's a related but separable idea
  that happens to touch the same sort-picker UI already being changed.
  Kept inside `010` rather than split into its own spec, since it's the
  same screen and same control; worth revisiting that call if this
  keeps growing.

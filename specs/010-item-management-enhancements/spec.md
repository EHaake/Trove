# Spec: Item Management Enhancements

**Status**: Draft — pending review
**Depends on**: `001-core-inventory` (shipped; this spec modifies its screens directly)

## Summary

Brings the owned-items list to full behavioral parity with the
wishlist — swipe-to-delete, swipe-revealed Edit and Duplicate, and
manual drag-to-reorder via a "Custom" sort option matching wishlist's
own convention — extends the existing delete-confirmation model to
every delete path consistently (rather than removing it), removes the
wishlist's "Reorder" button and every other reorder-mode UI — "Custom"
simply allows press-and-hold drag, identically on both screens, with
reordering kept VoiceOver-reachable through explicit row actions
rather than edit mode (a two-step implementation story; see Resolved
decisions) — expands the wishlist's own sort options ("Desire" and
"Alphabetical" alongside "Custom" and "Cost"), and gives the list rows
and the `DesireGauge` a real visual refinement pass.
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
   `WishlistView` already has: a "Custom" option in the sort picker
   (alongside desire-to-keep, value, and purchase date) that shows the
   list in its manual order and *allows* press-and-hold-then-drag —
   and nothing else. No separate "Reorder" button on either screen,
   no drag handles, no formal edit mode, ever; swipe actions stay
   live in every state. Identical behavior on both lists. Reordering
   stays VoiceOver-reachable on both screens through explicit
   "Move up"/"Move down" row actions, offered wherever reordering
   itself is — the resolution
   of a two-step implementation story recorded in Resolved decisions
   (an edit-mode-based approach shipped briefly in between, and was
   pulled back once it turned out to force reorder UI and dead swipe
   actions into the very state it gated on).
6. Give list rows on both screens a small amount of additional visual
   depth/character. Ended up requiring an amendment to
   `design/brief.md`'s skeuomorphism section rather than fitting inside
   its original wording — see Resolved decisions.
7. Improve `DesireGauge`'s at-a-glance legibility as a *desire*
   indicator specifically — not just "three boxes" — via a real Claude
   Design pass.
8. Expand `WishlistView`'s sort options beyond "Custom" and "Cost": add
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
- **A VoiceOver-accessible entry point for manual reordering — written
  here as a deferred gap, resolved during implementation instead.**
  This entry originally deferred the problem outright, on the belief
  that neither list's drag-to-reorder had an accessible equivalent.
  T027a's empirical check reversed that: formal edit mode (then
  reachable via the wishlist's Reorder button) is what exposes
  VoiceOver's Move Up/Move Down actions — the drag gesture itself
  exposes nothing. Edit mode later left the design entirely when the
  clarified intent landed (no handles, no button, identical screens —
  see Resolved decisions), so what `010` actually ships is explicit
  "Move up"/"Move down" accessibility actions on the rows of both
  lists, present while reordering is available — the ends of the
  list no-op, and the reorder flow records why their presence
  deliberately isn't position-conditional (T029b).
  Reordering is VoiceOver-reachable on both screens; the bare
  long-press drag still has no accessible equivalent *of its own*,
  which is moot — the row actions reach the same capability
  everywhere the drag exists.

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

On the wishlist side, the alert continues to explain the same cascade
consequence it already does (`WishlistDeleteCopy`: a wishlist item's
own Sell Plan selection goes away without touching the owned items in
it) — but its wording isn't unchanged: the verb unifies with the item
side ("Delete," not "Remove"), and it gains the item alert's "This
can't be undone" sentence, since that's equally true on the wishlist
side. See Resolved decisions for the reasoning.
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
row, entered the same way on both screens: a "Custom" option in the
sort picker, matching `WishlistView`'s existing convention (previously
"Yours" and "Cost," "Yours" renamed to "Custom" as part of this spec —
see Resolved decisions; now also "Desire" and "Alphabetical" — see
below).
Selecting "Custom" shows the list in its manual order and enables the
drag gesture; selecting anything else hides it. This is new capability
for `ItemListView`, which had no manual order or "Custom" option at all
before this spec (see Resolved decisions for why that reverses an
earlier non-goal); `WishlistView` already has both, and loses its
"Reorder" button — restored to this spec's original intent after a
two-step detour recorded in Resolved decisions.

Neither screen uses formal edit mode, at all, in any state: "Custom"
allows the long-press drag and shows nothing for it — no drag
handles, no button — so swipe actions (Delete, Edit, Copy) stay live
everywhere, including while "Custom" is active. That last point is
why edit mode left the design: it silences both swipe edges while
active (measured during implementation, with a positive control), and
an interim build that wired "Custom" to edit mode on the item list
forced exactly that trade into the reorderable state. Outside an
unnarrowed "Custom" the drag gesture is detached entirely — hidden,
not merely disabled — identically on both screens. VoiceOver reaches
the same capability through explicit "Move up"/"Move down" actions on
each row, present exactly while reordering is available and inert at
the ends of the list. Their *presence* is deliberately not
position-conditional: an earlier version added and removed the
actions by row position, and restructuring a row's accessibility
content while a drag settles turned out to be precisely what broke
the List's reorder rendering (the T029b defect — the row snapped back
visually while the order changed underneath). They replace the
edit-mode path the interim design relied on.

Switching to a different sort doesn't discard the manual order
underneath — selecting "Custom" again shows it exactly as last
arranged.

Existing owned items need a sensible starting manual order the first
time this ships, rather than an arbitrary one — the concrete strategy
is a `plan.md` decision. (Resolved there, revised 2026-08-30: a
sort-time `createdAt` fallback beneath tied positions, not a stored
backfill — the launch-time write shipped first and was removed after
review showed it could race CloudKit sync on a second device.)

Both lists' reordering has a VoiceOver-accessible path — the same
explicit "Move up"/"Move down" row actions on both screens. See
Non-goals for how this stopped being a deferred gap.

### Wishlist sort options, expanded

`WishlistView`'s sort picker gains two new options alongside "Custom"
and "Cost": "Desire" (by desire-to-own) and "Alphabetical" (by name,
case-insensitive, matching how the app already treats free-typed text
elsewhere). This reverses a decision `001` shipped and tested — see
Resolved decisions for why that's a deliberate, confirmed choice, not
an oversight.

Tie-break, confirmed: manual order breaks ties within any non-"Custom"
sort — a tier of same-desire wishlist items (there are only three
tiers, so ties are the common case, not an edge case) shows in
whatever relative order they currently hold manually; two
identically-named items under "Alphabetical" resolve the same way. One
rule for every sort mode rather than a different one each, and it gives
"Custom" a second job as the fallback ordering everything else falls
back on.

"Desire" and "Alphabetical" compose with category filtering exactly
like "Cost" already does — filter to a category and sort by Desire at
the same time, both active together, the same as every existing
attribute sort already allows. This is unlike "Custom": manual
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
exact treatment in `tokens.md`'s "Row treatment" table.

## Design requirements

Visual specifics for all four items below have gone through a real
Claude Design pass and are resolved — real values live in `tokens.md`
and `design/icons/`, not restated here. What follows is the bar each
was held to, kept for context on why the chosen treatment looks the
way it does, not as still-open requirements.

- **Row treatment**: more perceived depth/life than the current flat
  rectangle. Chosen treatment (a cast shadow plus inset bevel) required
  amending `brief.md`'s skeuomorphism section, not just interpreting
  the original bar generously — see Resolved decisions. `brief.md`'s
  updated section is the current, accurate constraint; the original
  "no bevels, no drop shadows" framing this bullet used to state is no
  longer the rule.
- **Sort picker on both screens**: `ItemListView` gained a fourth
  option ("Custom"), `WishlistView` a third and fourth ("Desire",
  "Alphabetical"). Resolved cleanly — the actual pattern is a compact
  badge that opens a dropdown, so its footprint doesn't grow with
  option count; the "does four options crowd the header" concern this
  bullet used to flag turned out not to apply.
- **`DesireGauge`**: reads as a *desire* indicator specifically to
  someone encountering it without prior context, while remaining the
  flat/graphic three-segment control already described in `brief.md`
  and `plan.md`. Resolved by keeping the same sheared-segment shape and
  adding two things: ascending height per segment, and a per-row
  "DESIRE" legend in dimmed mono type. The legend is a deliberate
  reversal of `001`'s "unlabeled in list rows" decision, not a
  loophole around "a legibility fix, not a redesign" — see Resolved
  decisions.
- **New swipe-action iconography** (Edit, Duplicate, Delete): done,
  in `design/icons/`, matching the tab icons and `AddButton`'s
  flat/graphic language.

## Acceptance criteria

Not yet signed off — listed here as the testable target, to be checked
off (with citations, matching `001`'s convention) once built.

- [ ] User can delete an owned item via a trailing swipe on
      `ItemListView`; the row and the underlying item are removed.
- [ ] Deleting an owned item shows the same confirmation alert on both
      entry points (list swipe and detail screen's overflow menu), and
      that alert names the sell-plan cascade consequence with the same
      specificity the wishlist's existing alert has.
- [ ] Deleting a wishlist item continues to show its confirmation
      alert on both entry points, explaining the same consequence as
      before — with updated wording rather than unchanged wording: the
      verb unified with the item side ("Delete," not "Remove"), and the
      "This can't be undone" sentence added.
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
- [ ] The wishlist's "Reorder" button no longer appears anywhere in
      the UI, and no edit-mode UI (drag handles) ever appears on
      either list; press-and-hold-then-drag reordering under "Custom"
      still works exactly as before. (This criterion flipped twice:
      removal as originally written, then kept per T027a's edit-mode
      finding, then removed again once explicit VoiceOver row actions
      replaced the edit-mode path — see Resolved decisions.)
- [ ] User can drag-to-reorder owned items in `ItemListView` via the
      same press-and-hold gesture `WishlistView` uses — identical
      behavior on both screens, no separate button, no edit mode,
      and swipe actions live throughout, including under "Custom".
- [ ] Manual order on `ItemListView` persists across app launches and
      syncs across devices, the same as `WishlistView`'s `sortOrder`
      already does.
- [ ] Dragging to reorder is only available while "Custom" is selected
      on either screen — not while `ItemListView` is sorted by
      desire-to-keep, value, or purchase date, or `WishlistView` by
      Cost, Desire, or Alphabetical, and not while either list is
      filtered by category or search.
- [ ] Selecting a different sort and returning to "Custom" shows the
      manual order exactly as last arranged — it isn't discarded.
- [ ] Existing owned items have a sensible, non-tied starting manual
      order the first time this ships.
- [ ] `WishlistView`'s sort picker offers "Desire" and "Alphabetical"
      in addition to "Custom" and "Cost."
- [ ] Ties within a non-"Custom" sort (e.g., two wishlist items at the
      same desire tier) resolve by manual order — the confirmed
      tie-break, not left open.
- [ ] "Desire" and "Alphabetical" sorts on `WishlistView` compose with
      category filtering exactly like "Cost" already does — both active
      simultaneously. "Custom" remains the one mode that requires an
      unfiltered, unsearched view, per the existing guard.
- [ ] Reordering is VoiceOver-reachable on both lists via explicit
      "Move up"/"Move down" row actions, present while reordering is
      available; the ends of the list no-op rather than dropping the
      action, since position-conditional presence destabilized the
      List's reorder rendering (T029b). (This criterion originally
      documented the opposite as a known gap; T027a's measurements
      reversed it, an interim design satisfied it via edit mode, and
      the row actions are its final form — see Resolved decisions.)
- [ ] List rows on both screens read with more visual depth than a flat
      rectangle, per `tokens.md`'s "Row treatment" table, and stay
      inside `brief.md`'s current (post-`010`-amendment) skeuomorphism
      boundary — no metallic gradients, wood/leather texture, screws,
      stitching, or photorealism, though restrained depth cues like the
      chosen treatment are now permitted.
- [ ] `DesireGauge` reads as a desire-specific indicator to someone
      encountering it without prior context, per `tokens.md`'s "The
      desire gauge's stepped ramp" table.

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
- **Row treatment amends `brief.md` rather than staying inside it —
  reversed from an earlier draft of this spec.** This document
  originally stated row treatment would stay inside `brief.md`'s
  existing no-bevel/no-drop-shadow constraint. That held until Design
  produced a real, chosen treatment (a cast shadow plus inset bevel)
  and the person steering this project confirmed the original
  flat-only reading was an assumption about the limits of flat design,
  not a permanent boundary — Trove's visual identity is expected to
  keep evolving. `brief.md`'s skeuomorphism section was amended
  accordingly: narrowed, not deleted. Restrained alpha-based depth is
  now permitted; literal materiality (metallic gradients, wood/leather
  texture, screws, stitching, photorealism) still isn't. Real values in
  `tokens.md`'s "Row treatment" table.
- **`DesireGauge` gains a per-row "DESIRE" legend — reversing `001`'s
  explicit "unlabeled in list rows" decision, not just refining the
  control.** `001`'s own `spec.md` states this plainly: the gauge
  "renders as an unlabeled three-segment gauge in wishlist rows... where
  it sits in the row's lower-right" — a deliberate choice made because a
  label repeating down every row is noise. `010` reverses it on
  purpose: the redesigned gauge (same sheared-segment shape, extended
  with ascending height and the legend) ships with a small, dimmed-font
  legend on every row specifically to close the legibility gap `001`'s
  own sign-off flagged, without repeating the earlier "full-weight
  repeated text is noise" mistake the dimmed treatment is meant to
  avoid. Explicitly provisional, in the words of the person steering
  this spec — easy to remove if it reads as noisier in the running app
  than in Design's mockup.
- **Two naming mismatches inside Design's own approved output,
  resolved differently from each other on purpose.** The swipe-action
  icon set labels the middle action "Duplicate," but the actual
  swipe-reveal button says "Copy" — kept as designed: "Duplicate"
  stays this document's name for the action (matching `duplicate(id:)`
  in `plan.md`/`tasks.md`), "Copy" is the on-screen string only, the
  same relationship `desireToKeep` already has to its displayed form.
  "Yours" vs. "Custom" resolved the opposite way — see the dedicated
  entry above — because the reasoning behind it was different: a
  genuine concept-level confusion, not a button-length preference,
  confirmed by the person who built the app finding "Yours" unclear in
  their own early use of it.
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
- **Wishlist's "Reorder" button removed in the end — through a
  three-step story this entry keeps whole, because each step
  corrected a real error in the one before.** Step one (as
  originally written): remove the button as "a redundant second
  entry point into a capability that already didn't need one." Wrong
  — T027a's empirical check (Accessibility Inspector, three matched
  states, live device) found the button's edit-mode toggle was the
  *only* mechanism in the app exposing VoiceOver's Move Up/Move Down
  actions; the accessible actions belong to formal edit mode
  specifically, not to the drag gesture or the "Custom" selection,
  so "redundant" was false. Step two: keep the button and wire
  `ItemListView`'s "Custom" to edit mode instead — which protected
  the accessible path but shipped something broader than intended:
  forced edit-mode UI (drag handles) and silenced swipe actions in
  the item list's reorderable state, and two screens that behaved
  differently. The person steering the project clarified the actual
  intent: "Custom" should only *allow* press-and-hold drag — no
  handles, no button, identical screens, swipes always live. Step
  three, the shipped resolution: no formal edit mode anywhere; the
  button goes; both screens attach the drag gesture only under an
  unnarrowed "Custom" (detached otherwise); and the accessible path
  the first two steps fought over moves to explicit "Move up"/"Move
  down" VoiceOver actions on the rows (presence gated on
  reorderability, not row position — T029b found position-conditional
  presence broke the List's reorder rendering) — so the removal no
  longer costs what step one would have cost. No bespoke
  reorder-button Design treatment needed; the control no longer
  exists.
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
- **The VoiceOver question raised while scoping was NOT left open
  after all — implementation resolved it, and the resolution reversed
  a different decision than the one this entry originally described.**
  As first written, this entry recorded "neither list has an
  accessible entry point" as a documented, deliberately deferred gap.
  T027a's check showed that premise was already false on the wishlist
  side — the supposedly redundant button's edit mode was carrying a
  working accessible path all along. The gap this entry deferred is
  closed in the shipped design by explicit "Move up"/"Move down" row
  actions on both screens (an interim design closed it via edit mode
  instead — see the button entry above for the full three-step
  story). `plan.md`'s known-limitations entry is superseded the same
  way.
- **`ItemListView`'s "Custom" sort option resolves what was previously
  an open design question** (how a user enters manual-order mode) —
  same convention `WishlistView` already established, a sort-picker
  option rather than a separate control. (This entry originally added
  that it "confirmed" the wishlist's own button as genuinely redundant
  — T027a later disproved exactly that claim; see the corrected button
  entry above. The sort-picker-as-entry-point convention itself
  stands.)
- **`WishlistView`'s sort options expand from two ("Yours"/"Cost", as
  `001` actually shipped them — renamed to "Custom" later in `010`, see
  below) to at least four — reversing a decision `001` shipped and
  tested, not just an earlier draft of `010`.** `001`'s `spec.md` states
  plainly that desire-to-own "does not affect list ordering," backed by
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
- **"Yours" renamed to "Custom" throughout — a real product decision,
  not a cosmetic one.** Confirmed directly by the person steering this
  project: "Yours" was unclear as a *concept*, not just wordy as a
  button — confusing even to them in early use of the real, shipped
  app, which is why "Custom" was proposed to Claude Design in the first
  place. Every "Yours" in this document has been renamed accordingly,
  including the `WishlistView` sort option that's been live since `001`
  — this is a rename of existing, shipped behavior, not just new
  naming for `010`'s additions (see `tasks.md`'s `T025a`).
- **Tie-break for every non-"Custom" sort, confirmed: manual order.**
  Weighed and decided, not left as a `plan.md` open question — a
  desire-based sort is worth having despite the ties a 3-tier scale
  produces, and manual order is a good enough answer for what breaks
  them: it needs no new rule of its own, and it gives "Custom" a second
  job as the fallback underneath every other sort. Confirmed alongside
  this: "Desire" and "Alphabetical" compose with category filtering
  exactly like "Cost" already does — filter and attribute-sort both
  active at once, no special-casing. Only "Custom" keeps the existing
  filter-incompatibility guard, since dragging against a filtered view
  risks silently misordering items not currently on screen.
- **Both money sorts carry both directions — a Phase 6 review request,
  reversing the one-direction-each rule.** The item list's Value and
  the wishlist's Cost each appear as a labeled pair in the sort picker
  ("Value ↓"/"Value ↑", "Cost ↑"/"Cost ↓") rather than hiding a
  direction toggle behind re-selecting the active option. The shipped
  lead directions stand — Value high-first, Cost cheapest-first per
  plan.md — and un-valued items sort last under Value ↑ exactly as
  they do under Value ↓, since unknown isn't a low value any more
  than it was a zero. Every other sort keeps its single sensible
  direction. `tasks.md`'s T033a records the request and execution.
- **The detail screens joined Phase 7's visual scope at the design
  refresh review (2026-08-29), with the refreshed mocks adopted
  selectively rather than wholesale.** Two new detail-screen designs
  arrived with the refined exports and are implemented as
  `tasks.md`'s T037a/T037b — but four of their elements were
  identified in review as stale artifacts of the initial design and
  are deliberately not adopted: the header Edit/Delete buttons (the
  "…" overflow stays), the schema-less DETAILS fields (Stored, a
  split Brand/model, a Valued date — the schema is unchanged), the
  missing tap-to-set gauge on the wishlist detail (kept; its absence
  was accidental), and the swipe label DUPLICATE (outdated; "Copy"
  stands). The item dial's per-level hints were reworded to be true
  today — they now describe the real candidate mechanics
  (`DesireLevel.isSellCandidate`, lowest-desire-first ranking) rather
  than the mock's not-yet-built shortfall escalation — with a
  recorded revisit note to restore the richer copy when that logic
  ships. `tasks.md`'s Phase 7 header carries the full decision list.
- **Scope note**: the sort-option expansion isn't required to give
  `ItemListView` reorder parity — it's a related but separable idea
  that happens to touch the same sort-picker UI already being changed.
  Kept inside `010` rather than split into its own spec, since it's the
  same screen and same control; worth revisiting that call if this
  keeps growing.
- **The wishlist alert's wording changes after all — unified verb and
  an added undo-sentence — surfaced by implementation's T002 finding,
  not anticipated when this spec was drafted.** The earlier "wishlist
  side unchanged" framing was accurate when written: it rested on the
  then-correct assumption that only the item side needed new copy.
  T002's check of the real source complicated that — the item alert
  already says "This can't be undone." where the wishlist's doesn't,
  and the two entities confirmed with different verbs ("Delete" vs.
  "Remove"). Resolved: unify on "Delete" — matching `delete(id:)` in
  code, and not softening a permanent action — and add the
  undo-sentence to `WishlistDeleteCopy`, since it's equally true
  there. The wishlist-side edit is `tasks.md`'s `T010a`, split from
  `T010` the same way `T025a` split from `T025`: a change to shipped,
  tested content gets its own task rather than riding along inside new
  work.

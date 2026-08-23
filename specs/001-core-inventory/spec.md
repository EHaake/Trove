# Spec: Core Inventory (v1)

**App name**: Trove — *Your Gear, Valued*
**Status**: Draft — pending review
**Depends on**: nothing (first feature)

## Summary

Trove is a personal inventory app for gear-hobbyists (photography,
guitars/amps, audiophile equipment) to track what they own, what they
paid, what it's roughly worth now, and what they want to buy next — so
they can reason about selling underused gear to fund new purchases.

## Goals (v1)

1. Let a user record an owned item with enough detail to know what it is,
   what it cost, and what it's roughly worth today.
2. Let a user record a "desire to keep" rating per owned item, as a manual
   signal for how willing they'd be to sell it.
3. Let a user maintain a wishlist of items they want to buy, with an
   estimated cost.
4. Let a user build a **Sell Plan** for a wishlist item: an advisory,
   persisted shortlist of owned items with low desire-to-keep that
   they're weighing selling, reached via a single dedicated action (not
   shown by default). The point is to answer "is this a reasonable time
   to buy, and what would make the most sense to sell if I did" — not to
   pressure the user into covering the item's full cost. (v1 ranks
   candidates by desire-to-keep alone; ranking that also accounts for
   market-value trend is the eventual goal, but depends on the
   live-market-value non-goal below — see plan.md for how v1 is built to
   extend into that later without a rework.)
5. The app should feel fast and uncluttered: adding an item and checking
   your overall gear value should each take only a few taps.
6. Data syncs across the user's own devices via iCloud.

## Non-goals (v1 — explicitly deferred)

- **Live/estimated market value** pulled from eBay, Reverb, Facebook
  Marketplace, or any external source. All "current value" in v1 is
  manually entered and manually updated by the user.
- **Price-trend-based sell suggestions** ("sell now, value is trending
  up"). Depends on the above.
- **Auto-categorization** of items from a photo or description.
- Multi-user / sharing. This is a single-user (well, single iCloud
  account) app.
- Barcode/serial-number lookup against any external database.
- Insurance-document export or valuation reports (may be a natural
  future feature, not v1).
- **Light mode and additional color themes.** v1 ships as a single
  dark theme. A light mode toggle, plus a small set of additional
  curated color themes beyond the default, is a planned future
  enhancement — the design's color values are already built as named
  semantic tokens rather than hardcoded, specifically so this doesn't
  require a redesign when it happens (see design/brief.md and
  plan.md).
- **Fetching a stock photo automatically.** v1 photos come from the
  user's own device only. Auto-fetching a representative stock photo
  (most useful for wishlist items, which aren't owned yet) is a planned
  future enhancement — it needs a real third-party image API with its
  own licensing terms, which is worth doing deliberately rather than
  folding in casually. The `Photo` model already records where a photo
  came from (see plan.md) so this is additive later, not a migration.
- **Marking a Sell Plan item as actually sold**, or any transaction/sale
  tracking. The Sell Plan (see below) is a decision-support tool for
  v1 — it helps you decide what you'd sell, it doesn't track that you
  did. A real "mark as sold" workflow is a natural, meaningfully bigger
  future feature, deliberately excluded now to keep the Sell Plan
  screen simple.
- **Color-coded categories.** Top-level categories (`Photography`,
  `Music`, etc.) getting a distinct color, shown wherever that
  category's chips appear, is a real future enhancement — a curated
  palette that harmonizes with the existing theme, user-selectable or
  auto-assigned on first use of a new top-level category. Deferred
  because it's a real design decision (palette selection) as much as an
  engineering one, and deserves a deliberate pass rather than an
  incidental one.

## Entities (conceptual — see plan.md for the actual data model)

### Owned Item
- Name (e.g. "Fender Telecaster")
- Category path — hierarchical, user-defined, e.g. `Music/Guitars/Electric`
  (see "Categories" below)
- Serial number (optional — not everything has one)
- Purchase price
- Purchase date
- Purchase location (free text — e.g. "Reverb", "Guitar Center Portland",
  a person's name for private sales)
- Current estimated value (manually entered; user can update any time)
- Desire-to-keep rating, 1–5 (5 = absolutely keeping it, 1 = ready to
  sell); defaults to 3 on creation
- Condition — one of New / Excellent / Good / Fair / Broken, plus a
  free-text condition notes field for specifics
- Photo(s) — multiple photos supported
- Notes (free text)

### Wishlist Item
- Name
- Category path (same system as owned items)
- Estimated cost
- Notes
- Photo(s) — multiple photos supported, same treatment as owned items
- Desire-to-own rating, 1–3 (1 = "Someday", 2 = "Soon", 3 = "Next");
  defaults to 2 on creation. Deliberately coarser than owned items'
  1–5 desire-to-keep — three levels is about the resolution people
  actually have about their own wants, and it keeps the two ratings
  from reading as the same measurement pointed in opposite directions.
  Display-only: it does not sort or reorder the wishlist (see below).
- Priority or ranking (exact mechanism TBD in plan — at minimum the user
  can order the list)
- Sell Plan — a persisted selection of owned items the user is
  considering selling to fund this purchase (see "The Sell Plan" below)

### Category
- Not a separate entity the user manages directly in v1 — categories are
  free-typed hierarchical paths (see below), derived from what users type
  when entering items. The system should offer autocomplete/reuse of
  previously-used paths so a user doesn't retype `Photography/Cameras`
  with inconsistent capitalization every time.

## Categories

Hierarchical, user-defined, slash-delimited paths (e.g.
`Photography/Cameras`, `Photography/Lenses`, `Music/Guitars/Acoustic`).
No fixed taxonomy shipped with the app — the user builds their own
hierarchy by typing it when they add their first items. The app should
suggest previously-used paths/prefixes as the user types, to keep the
taxonomy consistent without forcing a rigid predefined list.

Auto-categorization from a photo is a plausible future enhancement — not
in scope now, but the category field being a plain string path (rather
than, say, a hardcoded enum) is intentional so that a future feature can
suggest or auto-fill it without a schema change.

Category matching (autocomplete, filtering) is case-insensitive —
`"photography"`, `"Photography"`, and `"PHOTOGRAPHY"` are the same
category to the app. This isn't user-configurable; it's just correct
behavior for a free-typed field nobody's going to capitalize consistently
on their own.

### Displaying a category path

Two rules, applied everywhere a category path is shown as a chip or a
compact label — the item list's filter chips, the add/edit form's
suggestion chips, and anywhere else a path appears as a short tag rather
than a full breadcrumb:

- **Leaf label, with disambiguation.** Show only the path's last segment
  (`Electric`, not `Music/Guitars/Electric`) when that segment is unique
  across the current category set. If two different paths would
  otherwise show the same leaf (`Music/Amps` and `Audio/Amps` both
  ending in "Amps"), both expand to their last two segments instead —
  just enough to disambiguate, not the whole path. If two segments still
  collide (a deeper hierarchy where even that isn't enough), fall back
  to the full path — showing two identical-looking chips is worse than
  one long one. This is a label-only rule: filtering and storage always
  use the full path underneath.
- **Arrow breadcrumb for an already-set value.** Where a *complete*
  category path is displayed as a navigable read-out — specifically the
  add/edit form's field once a category is chosen — render it as
  segments joined by a right-arrow icon (`Music › Guitars › Electric`)
  rather than literal slashes. This is display-only; the underlying
  value is still the slash-delimited string, and any text field the
  user actually types into still takes and shows literal `/` while
  being edited.

  **This does not apply to the item list row or item detail screen's
  meta line** (`MUSIC · GUITARS · HOLLOWBODY`). That's a different kind
  of display — a stylistic, all-caps mono tag deliberately echoing the
  brief's `LEICA · CAMERAS` convention, not a navigable breadcrumb — and
  keeps its middot separator, showing the last two segments per the
  truncation rule discussed elsewhere in this doc. Two different jobs:
  the form field is showing a hierarchy the user is choosing through;
  the meta line is a compact label matching Design's typographic
  language. Don't unify them just because both happen to touch category
  segments.

## Key user flows

### Add an owned item
User taps add, enters name + category (with autocomplete) + price + date
at minimum; everything else (serial, location, condition, photo, notes,
desire rating) is optional at creation time and can be filled in later.
This should be fast — the "quick add" path should not force the user
through fields they don't have handy right now.

### Check overall standing
User opens the app to a home/dashboard view showing, at a glance: total
current value of owned gear, total spent, and the delta between them.
Items with no current value entered are excluded from that total but
counted separately (e.g. "3 items not yet valued") so the total reads as
a floor, not a false completeness. Ability to drill into a category to
see the same numbers scoped to it (e.g. "what have I spent on guitars
specifically").

### Browse/sort owned items
List of owned items, filterable by category, sortable by desire-to-keep,
value, or purchase date, and searchable by name or serial number. Search
sits below the header and above the category filter chip row, matching
Design's layout. Category filter chips are a single horizontally
scrolling row, not a wrapping grid — vertical space above the list stays
fixed regardless of how many distinct categories are in use. The header
(title, summary line, search field, filter chips) stays fixed in place;
only the item rows beneath it scroll. Chip label text follows the leaf-
with-disambiguation rule in the Categories section above.

### Browse and manage the wishlist
List of wishlist items, filterable by category and searchable by name,
same treatment as the owned-items list.

Each row shows the item's desire-to-own rating as a small three-segment
gauge, unlabeled — the gauge alone, no "Someday"/"Soon"/"Next" text and
no legend, since repeating a static word down every row of a scrolling
list is noise. The words appear in the add/edit form and the wishlist
item's detail screen, which is where the user sets the value and learns
what the three levels mean.

The rating never reorders the list. Manual `sortOrder` (drag to reorder)
stays the only ordering — two competing ordering systems where one
silently overrides the other is worse than one the user controls, and
three coarse tiers would produce mostly-ties anyway. Consistent with the
Sell Plan's principle: show the information, let the user decide what to
do with it.

### Add and review a wishlist item
User adds a wishlist item with name, category, estimated cost. Viewing a
wishlist item shows that item plainly — name, category, estimated cost,
notes — with room reserved in the layout for live pricing/trend info once
that's a real feature, even though nothing populates it yet in v1. A
single action ("Find items to sell") leads to that item's Sell Plan.

### The Sell Plan
The Sell Plan is advisory, not a target to hit. The question it answers
isn't "do I have enough to fully cover this" — it's "is now a reasonable
time to buy, and if I did sell something toward it, what would make the
most sense." Framing it as a completion goal (full cost covered, or
explicitly falling short) implies the user is supposed to fund the whole
purchase from a sale, which was never the intent — someone might sell one
item they don't mind parting with and still pay for the rest themselves.

It's a real, persisted thing — not a list recomputed fresh every time
you look at it. Candidates are owned items with desire-to-keep of 3 or
lower and a current value entered (items with no current value are left
out, same as the dashboard total — there's nothing to rank them by),
ranked lowest desire-to-keep first, ties broken by higher current value.

The Sell Plan starts empty. It does not auto-select items or try to
reach the wishlist item's cost — that would be the completion-target
behavior this feature is explicitly not. The user adds or removes any
candidate freely, from a list that's just showing them their best
options; each change saves immediately. The screen shows the selected
items' combined value alongside the wishlist item's estimated cost, so
the user can see for themselves how they compare — a quiet color cue
(e.g. one tone once selected value meets or exceeds the cost, another
when it doesn't) is fine, but there's no accompanying text urging the
user toward covering the gap ("keep going," "check another item," or
similar). The comparison is information, not an instruction.

The Sell Plan is deliberately not shown by default on the wishlist
item's own screen. It's a v1 approximation of a feature meant to grow
into something bigger once live market data exists (see non-goals);
showing it automatically would overstate what it currently does. It's
one tap away, not hidden, but the wishlist item's own details are what
the screen leads with.

**Reached only from the wishlist item's detail screen — not from the
list rows.** A per-row shortcut was built and tried; removed after
review because a CTA repeated on every row is a stronger, more constant
push toward the Sell Plan than even the goal-completion framing that
got removed from the screen itself — the same over-prominence problem
in a different form. One extra tap versus a shortcut is the right
trade for a feature that's meant to stay quietly available, not
prominent. A future dashboard-level view of active plans
(`009-sell-plan-list` in `specs/ROADMAP.md`) is the intended way to
survey plans in bulk, once it exists.

The Sell Plan does not track whether anything was actually sold — no
"mark as sold," no removal from inventory, no transaction history (see
non-goals). It's for deciding, not for bookkeeping a completed sale.

## Design requirements

Visual and interaction polish is a first-class requirement, not
post-hoc styling. Concretely:

- Minimize taps for the two most frequent actions: adding an item, and
  checking current total value.
- The list/browse views should not feel like a spreadsheet — this is a
  collection the user is proud of, and the app should look like it treats
  it that way.
- Empty states, loading states, and the add-item flow all need real design
  attention, not placeholder treatment — these get exercised constantly.

(Actual visual design happens in Claude Design, separately from this
spec — this section states the bar the design and implementation both
need to clear.)

## Acceptance criteria

Signed off by Erik, 2026-08-22, against the pre-merge review. Each
criterion cites the tests that demonstrate it; where the evidence is a
human attestation rather than a test, it says whose and of what.

- [x] User can create an owned item with name, category path, purchase
      price, and purchase date; can optionally add serial number,
      purchase location, current value, desire rating, condition, photo,
      notes.
      *`ItemFormViewModelTests` (`savesAValidItem`,
      `appliesModelDefaultsToFieldsLeftAlone`,
      `storesBlankOptionalFieldsAsNil`); end to end,
      `TroveUITests.testAddingAnItemThroughQuickAddPutsItInTheList`.*
- [x] User can edit and delete an owned item.
      *`ItemDetailViewModelTests` (`deleteRemovesTheItemFromTheStore`,
      `deletingAnItemTakesItsPhotosWithIt`); edits via
      `ItemFormViewModelTests.canonicalizesTheCategoryPathOnSave` and
      `PhotoRemovalTests.removingAPhotoWhileEditingAnItemDeletesIt`.*
- [x] User can create, edit, and delete a wishlist item (name, category,
      estimated cost, notes, photos, desire-to-own rating).
      *`WishlistFormViewModelTests` (`createsAWishlistItem`,
      `editingUpdatesInPlaceRatherThanInserting`);
      `WishlistDetailViewModelTests.deleteRemovesTheItemFromTheStore`;
      the list's swipe route, `WishlistDeletionTests`.*
- [x] Desire-to-own defaults to 2 ("Soon") on creation, is settable 1–3
      in the add/edit form, and renders as an unlabeled three-segment
      gauge in wishlist rows and a labeled one in the form and detail
      screen. It does not affect list ordering.
      *Rule: `WishlistFormViewModelTests`
      (`newItemsDefaultToTheMiddleOfTheScale`,
      `clampsOnAssignmentRatherThanOnSave`) and `WishlistViewModelTests`
      (`theManualOrderWinsOverTheRating`,
      `theSortControlOffersNoRatingOption`). Presentation confirmed by
      Erik at sign-off — rows deliberately unlabeled; the first-encounter
      legibility observation is recorded under ROADMAP `010`, not
      changed here.*
- [x] Category paths autocomplete from previously-used paths across both
      owned items and wishlist items.
      *`CategoryPathHelperTests.dedupsAcrossItemsAndWishlistItems`;
      `WishlistFormViewModelTests.suggestsCategoriesFromOwnedItemsAndWishlistItemsAlike`.*
- [x] Dashboard shows total current value (excluding un-valued items,
      with a separate count of how many are un-valued), total spent, and
      the delta — all three scoped to the same valued items, so the
      delta is never silently wrong by an un-valued item's purchase
      price.
      *`DashboardViewModelTests` (`theThreeHeadlineFiguresAlwaysReconcile`,
      `excludesUnvaluedItemsFromTheTotalAndCountsThemInstead`,
      `spendExcludesUnvaluedItemsToo`).*
- [x] Owned items list can be filtered by category, sorted by
      desire-to-keep/current value/purchase date, and searched by name
      or serial number.
      *`ItemListViewModelTests` (`filtersByCategoryPrefix`,
      `matchesOnName`, `matchesOnSerialNumber`, the three sort tests,
      `filteringAndSortingApplyTogether`).*
- [x] Wishlist list can be filtered by category and searched by name.
      *`WishlistViewModelTests` (`aFilterStopsAtASegmentBoundary`,
      `matchesOnName`).*
- [x] The wishlist item's own detail screen offers a way to reach that
      item's Sell Plan. List rows do not carry their own shortcut — see
      the Sell Plan section for why.
      *Erik, at sign-off: confirmed on device — the detail screen offers
      the route and rows carry none. No automated guard exists for the
      absence; the comments describing it were themselves corrected in
      the pre-merge review, which is why this one is an attestation.*
- [x] Viewing a wishlist item shows the item's own details (name,
      category, cost, notes) by default, not its Sell Plan.
      *`WishlistDetailViewModelTests.loadingDoesNotTouchTheSellPlan`.*
- [x] A wishlist item's Sell Plan, opened for the first time, shows the
      ranked candidate pool (owned items, desire-to-keep ≤ 3, valued,
      ranked ascending by desire-to-keep, ties broken by higher current
      value) with nothing pre-selected — no automatic selection toward
      covering the estimated cost.
      *`SellPlanViewModelTests` (`ranksLeastWantedFirst`,
      `breaksTiesByHigherValueFirst`, `leavesOutItemsWithNoValueEntered`,
      `startsWithNothingSelected`,
      `doesNotPreselectEvenWhenOneItemWouldCoverTheCost`).*
- [x] The user can add or remove any eligible owned item from the Sell
      Plan; changes save immediately and persist across app launches.
      *`SellPlanViewModelTests`
      (`eachToggleIsPersistedWithoutASeparateSaveStep`,
      `reloadingReflectsThePersistedSelection`), both through a second
      `ModelContext` so they measure the store, not the context. A real
      quit-and-relaunch, and the selection syncing over iCloud, verified
      by Erik at sign-off.*
- [x] The Sell Plan shows the selected items' combined value alongside
      the wishlist item's estimated cost. A quiet color distinction
      between "meets or exceeds the cost" and "doesn't" is acceptable;
      no text prompts the user to select more or otherwise implies
      they're expected to cover the full cost. Un-valued items are
      excluded from the candidate pool entirely.
      *`SellPlanViewModelTests` (`theTwoFiguresAreReportedSeparately`,
      `theColourCueTurnsOverAtTheEstimate`,
      `anEmptySelectionNeverReadsAsMeetingTheCost`,
      `theViewModelOffersNoSurplusOrShortfallFigure`,
      `theScreenShowsNoCopyFramingItAsAGapToClose`,
      `leavesOutItemsWithNoValueEntered`).*
- [x] Data persists across app launches and syncs across the user's
      devices signed into the same iCloud account.
      *Local: `ModelTests.itemsSurviveASaveAndRefetch`. Cross-device:
      `T048` (an item added on one device appears on the other) and
      `T055` (first-import and empty-account behaviour), both run by
      Erik on real devices — results recorded in tasks.md — and
      re-confirmed at sign-off.*
- [x] Adding an item with only the required fields (name, category, price,
      date) takes no more than a few taps/screens from the dashboard.
      *Route documented by
      `TroveUITests.testAddingAnItemThroughQuickAddPutsItInTheList`:
      Items tab → floating add → three fields → save — three taps and
      two screens from the dashboard. Confirmed acceptable by Erik at
      sign-off.*

## Resolved decisions

- **Condition**: a fixed set (New / Excellent / Good / Fair / Broken) plus
  a free-text field for custom condition notes alongside it.
- **Photos**: multiple photos per item, v1.
- **Desire-to-keep**: defaults to 3 (neutral) when an item is created,
  rather than starting unset.
- **Currency**: USD only in v1 (no currency picker in the UI); the
  underlying model still records a currency code per item so international
  support later is additive, not a migration — see plan.md.

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
4. Let a user build a **Sell Plan** for a wishlist item: a persisted
   selection of owned items with low desire-to-keep that they're
   considering selling to fund it, reached via a single dedicated action
   (not shown by default), showing the surplus or shortfall against the
   item's cost. (v1 ranks candidates by desire-to-keep alone; ranking
   that also accounts for market-value trend is the eventual goal, but
   depends on the live-market-value non-goal below — see plan.md for how
   v1 is built to extend into that later without a rework.)
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
- Photo(s) — multiple photos supported, at least one
- Notes (free text)

### Wishlist Item
- Name
- Category path (same system as owned items)
- Estimated cost
- Notes
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
value, or purchase date.

### Browse and manage the wishlist
List of wishlist items, filterable by category, same as the owned-items
list. Each row has a "See sell plan" shortcut straight to that item's
Sell Plan, alongside opening the item itself for its own details.

### Add and review a wishlist item
User adds a wishlist item with name, category, estimated cost. Viewing a
wishlist item shows that item plainly — name, category, estimated cost,
notes — with room reserved in the layout for live pricing/trend info once
that's a real feature, even though nothing populates it yet in v1. A
single action ("Find items to sell") leads to that item's Sell Plan.

### The Sell Plan
A Sell Plan answers "what would I actually sell to afford this" for one
wishlist item, and it's a real, persisted thing — not a list recomputed
fresh every time you look at it. Candidates are owned items with
desire-to-keep of 3 or lower and a current value entered (items with no
current value are left out, same as the dashboard total — there's
nothing to rank them by), ranked lowest desire-to-keep first, ties broken
by higher current value.

The first time a wishlist item's Sell Plan is opened, it's empty, so the
app proposes a starting selection automatically — the top of the ranked
list, added up until it covers the estimated cost — and that becomes the
saved plan. From there, the user can add or remove any candidate freely;
each change saves immediately. Rather than just a running total, the
plan shows the **surplus or shortfall** against the wishlist item's
cost — "$120 more than you need" or "$340 short" — since that's the
number that's actually useful to look at.

The Sell Plan is deliberately not shown by default on the wishlist
item's own screen. It's a v1 approximation of a feature meant to grow
into something bigger once live market data exists (see non-goals);
showing it automatically would overstate what it currently does. It's
one tap away, not hidden, but the wishlist item's own details are what
the screen leads with.

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

- [ ] User can create an owned item with name, category path, purchase
      price, and purchase date; can optionally add serial number,
      purchase location, current value, desire rating, condition, photo,
      notes.
- [ ] User can edit and delete an owned item.
- [ ] User can create, edit, and delete a wishlist item (name, category,
      estimated cost, notes).
- [ ] Category paths autocomplete from previously-used paths across both
      owned items and wishlist items.
- [ ] Dashboard shows total current value (excluding un-valued items,
      with a separate count of how many are un-valued), total spent, and
      the delta, across all owned items.
- [ ] Owned items list can be filtered by category and sorted by
      desire-to-keep, current value, and purchase date.
- [ ] Wishlist list can be filtered by category.
- [ ] Each wishlist list row and the wishlist item's own detail screen
      both offer a way to reach that item's Sell Plan.
- [ ] Viewing a wishlist item shows the item's own details (name,
      category, cost, notes) by default, not its Sell Plan.
- [ ] A wishlist item's Sell Plan, opened for the first time, proposes a
      starting selection of owned items (desire-to-keep ≤ 3, ranked
      ascending by desire-to-keep, ties broken by higher current value)
      that together meet or exceed the estimated cost, and saves that as
      the plan.
- [ ] The user can add or remove any eligible owned item from the Sell
      Plan; changes save immediately and persist across app launches.
- [ ] The Sell Plan displays the surplus or shortfall against the
      wishlist item's estimated cost, not just a running total.
      Un-valued items are excluded from the candidate pool entirely.
- [ ] Data persists across app launches and syncs across the user's
      devices signed into the same iCloud account.
- [ ] Adding an item with only the required fields (name, category, price,
      date) takes no more than a few taps/screens from the dashboard.

## Resolved decisions

- **Condition**: a fixed set (New / Excellent / Good / Fair / Broken) plus
  a free-text field for custom condition notes alongside it.
- **Photos**: multiple photos per item, v1.
- **Desire-to-keep**: defaults to 3 (neutral) when an item is created,
  rather than starting unset.
- **Currency**: USD only in v1 (no currency picker in the UI); the
  underlying model still records a currency code per item so international
  support later is additive, not a migration — see plan.md.

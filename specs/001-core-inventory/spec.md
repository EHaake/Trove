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
4. Surface owned items as candidate "things you could sell" — ranked by low
   desire-to-keep — when the user is looking at what a wishlist item would
   cost to fund.
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
Ability to drill into a category to see the same numbers scoped to it
(e.g. "what have I spent on guitars specifically").

### Browse/sort owned items
List of owned items, filterable by category, sortable by desire-to-keep,
value, or purchase date.

### Add and review a wishlist item
User adds a wishlist item with name, category, estimated cost. When
viewing a wishlist item, the user can see a ranked list of owned items
(lowest desire-to-keep first) with a running total of estimated value, to
answer "what would I need to sell to afford this."

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
- [ ] Dashboard shows total current value, total spent, and the delta,
      across all owned items.
- [ ] Owned items list can be filtered by category and sorted by
      desire-to-keep, current value, and purchase date.
- [ ] From a wishlist item, user can see owned items ranked by ascending
      desire-to-keep with a running cumulative value total.
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

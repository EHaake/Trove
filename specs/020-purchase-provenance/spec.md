# 020 — Purchase Provenance

**Status**: **Approved** (2026-09-29) — written with the person in this
spec session; widened the same day, at their reading of the first Draft,
to a new/used preference on wishlist entries (Decision 8), and approved at
their reading of the second, which confirmed that leaving the preference
blank is the "no preference" choice (no separate "either" value). The Decisions record below holds every product decision made in
the conversation; the **P-items** are Claude Code's proposals and become
decisions on plan approval, as in earlier specs.

Authored in a Claude Code spec session of its own, per `CLAUDE.md`'s model
policy (Opus profile, the session raised to high effort for the spec
conversation).

**Depends on**: `001-core-inventory` (`Item`, its form and page, the
condition scale), `002-live-market-value` (the condition-to-Reverb mapping
the market figure filters by, and the wanted item's "used listings"
figure), `010-item-management-enhancements` (Copy,
which duplicates an item), `011-data-export` (the items CSV and the PDF),
`012-data-import` (the items template and its header gate),
`015-mark-as-bought` (the purchase sheet). It adds no outside service.

## Summary

Trove records what you paid, when and where — but never **whether you
bought the thing new or used**. For hobby gear that is most of the story of
a purchase: the same lens bought new from a dealer and used off eBay are
different buys, and a collector who trades within the hobby knows which
one they made. The only trace the app has today is the **New** condition,
which says what state an item is in, not how it arrived.

This spec adds one optional fact to every owned item — **bought new** or
**bought used** — its twin on every wishlist entry — **looking for new**
or **looking for used** — and one grade to the condition scale, **Very
Good**, between Excellent and Good. The wishlist half does real work:
a wanted item's market figure has always read used listings only, and
for something you mean to buy new that is the wrong price.

## What and why

The occasion is the person's own collection: ninety items compiled in a
spreadsheet ahead of importing them (`specs/ROADMAP.md`, "A collection at
real scale"). Compiling it surfaced two gaps. The sheet had nowhere to say
new or used, and ten of its items are graded **Very Good**, a grade the
app's scale does not have. Reverb's own scale has it, and so does most
secondhand selling.

This spec goes first of the five that conversation produced because it is
the smallest and because it should land **before** the import: ninety rows
that carry new/used in one pass beat ninety hand edits afterwards.

What it deliberately leaves to later specs: **reading** the new fact
anywhere beyond the item itself. Filtering or grouping the list by new or
used is `022-grouped-browsing`'s; charting it is `023-dashboard-charts`'s;
making the importer lenient about how a spreadsheet writes it is
`021-import-expansion`'s. This spec records the fact and shows it on the
item. The one thing that reads it is the wishlist half: a wanted item's
preference chooses which Reverb listings its market figure is drawn
from, and prefills the purchase sheet when it is bought.

## Core behavior

### Bought new or used

- Every owned item gains an optional **Bought** fact with two values,
  **New** and **Used**. It may also be **not recorded**, which is what
  every existing item is after updating, and what any item is until the
  person picks (Decision 3).
- **It is never inferred.** An item whose condition is New is not assumed
  to have been bought new: a used item can be in new condition, and a
  gift or a long-stored purchase breaks the link the other way (Decision
  4).
- **A gift is not a third value.** A gift can be new or used, so it isn't
  an alternative to either (Decision 2). A gift stays what it is today: an
  item with a purchase price of zero.
- It belongs to the item and survives everything the item survives:
  editing, selling, returning to the collection, syncing.

### Where it is set

- **The add/edit item form** gains a **Bought** field: two chips, **New**
  and **Used**, the same shape as the condition chips beside it. Neither is
  selected by default. **Tapping the selected chip again clears it**, back
  to not recorded — an optional field needs a way back to empty, which the
  always-set condition chips never did (P1).
- **The Mark as bought sheet** (`015`) gains the same field, also
  unselected by default. Whatever is picked there lands on the new item.
- **Copy** carries the fact across with the rest of the item, as it
  carries the condition (P2).
- **It is never required.** Saving an item or completing a purchase with
  it unset is allowed and silent (Decision 3).

### Where it is shown

- **The item's page** says **Bought new** or **Bought used** alongside the
  purchase details it already shows — as the label of the row that already
  reads **Bought** beside the purchase date (Decision 10). When not recorded, the page says
  nothing about it — no dash, no "not recorded" line (P3).
- **The list rows do not show it.** The rows are already dense, and a
  marker on every row belongs to the list redesign if it belongs anywhere
  (Decision 5).
- **The Dashboard does not use it.** No figure, card or breakdown changes.

### Looking for new or used (the wishlist)

- Every wishlist entry gains an optional **Looking for** preference with
  the same two values, **New** and **Used**, and the same not-recorded
  state, which is what every existing entry is after updating
  (Decision 8).
- **Set on the wishlist add/edit form** with the same two chips, neither
  selected by default, the selected one clearable by tapping it again.
  Never required.
- **Shown on the wanted item's page** as a **Looking for — New / Used** row
  in its details, like the page's other facts; nothing when not recorded
  (Decision 10).
- **Copy** on a wishlist entry carries it across.
- **It shapes the market figure** — see "The market figure" below.
- **Marking the entry bought prefills the purchase sheet's Bought field**
  from it: looking for used → Used selected, looking for new → New
  selected, not recorded → nothing selected. The person can change or
  clear it before saving; a preference is not a record of what happened
  (P6).
- Not shown on wishlist rows, and nothing filters or sorts by it, for the
  same reasons as Decision 5.

### Very Good

- The condition scale becomes **New, Excellent, Very Good, Good, Fair,
  Broken**, in that order everywhere the scale is listed. Every place a
  condition can be chosen offers it: the item form and the Mark as bought
  sheet.
- **It reads "Very Good"** wherever a condition is shown — the item's
  page, the chips, the PDF — with a space and both words capitalised.
- **No existing item changes grade.** An item graded Good stays Good.

### The market figure

- **Very Good compares against Reverb's "very good" listings.** **Good
  keeps comparing against Reverb's "very good" and "good" listings**, as it
  has since `002` (Decision 6). The two grades overlap on purpose: nothing
  already graded Good sees its figure move, which is worth more than the
  cleaner split.
- **Bought new or used does not affect an owned item's market figure.**
  The figure reads the item's condition, which is what a buyer prices;
  how the owner came by it is not.
- **A wanted item's figure follows its Looking for preference**
  (Decision 9):
  - **Used** — Reverb's used listings, which is everything that is not
    new stock. Exactly today's figure.
  - **New** — Reverb's new-stock listings only (brand new and B-stock).
  - **Not recorded** — used listings, as today, so **no existing wanted
    item's figure moves** until the person states a preference.
- The words follow the figure: wherever a wanted item's market line says
  "used listings" today, it says **"new listings"** when the preference
  is New.
- Changing the preference changes the figure the same way changing an
  owned item's condition does — no new fetch timing, no new trigger.

### Sync and privacy

- The new fact syncs with the item like any of its other fields. It is the
  person's own data; nothing about it leaves the device except through
  their own iCloud sync and their own exports.
- **An older copy of the app on another device** — before this update —
  keeps showing that device's view of the item without the new fact, and
  must not lose it for the updated device when it edits the item (P4).
  Very Good on such a device must not crash it or reset the grade.

### Exports and import

- **The items CSV gains one column at the end, "Bought"**, holding `new`,
  `used`, or nothing — appended after every existing column, as `006`'s
  sale columns were, so the template's existing order is untouched
  (Decision 7).
- **Import reads it back**, ignoring letter case. An empty cell imports as
  not recorded. An older file without the column still imports, every row
  not recorded.
- **Very Good round-trips.** The CSV writes it the way it writes the other
  grades (lower case, with its space: `very good`) and import reads it in
  any letter case (P5). Wider leniency — other spellings, other date and
  money formats — is `021`'s.
- **The downloadable template** gains the column too, so a file built from
  it today carries new/used from the start.
- **The PDF** says it the way the item's page does: the field that already
  holds the purchase date is labelled **Bought new** or **Bought used**,
  and plain **Bought** when not recorded — no second field labelled
  "Bought" (Decisions 7 and 10).
- **The wishlist CSV gains one column at the end, "Looking For"**,
  holding `new`, `used` or nothing, read back on import the same way,
  with older files importing as not recorded. The wishlist template gains
  it too.
- **The wishlist PDF** lists **Looking for: New** or **Used** where
  recorded, and omits it where not.

## Copy

| Where | Text |
|---|---|
| Form and purchase sheet field label | **BOUGHT** (the mono label style every field uses) |
| Chips | **New**, **Used** |
| Item page | **Bought new** / **Bought used** — the label of the existing purchase-date row |
| Condition chip and page | **Very Good** |
| CSV header | `Bought` |
| CSV values | `new`, `used`, empty; condition `very good` |
| PDF, items | the purchase-date field labelled **Bought new** / **Bought used** (plain **Bought** when not recorded) |
| Wishlist form field label | **LOOKING FOR** |
| Wanted item's page | a details row, **Looking for** — **New** / **Used** |
| Wanted market line, New preference | "new listings" wherever it says "used listings" today |
| Wishlist CSV header | `Looking For` |
| Wishlist PDF field | **Looking for** — **New** / **Used** |

## Design requirements

- The Bought chips **match the condition chips** exactly — size, stroke,
  selected tint — so the form reads as one system. Two chips need no
  wrapping.
- Six condition chips now **wrap onto a second row** on narrow phones
  where five might not have. Wrapping is fine; clipping or a chip squeezed
  narrower than its siblings is not. Check it at the narrowest supported
  width.
- The Looking for chips on the wishlist form match the same chips.
- On the item's page the Bought line sits **with the purchase details**
  (price, date, place), not with the condition, because it describes the
  purchase, not the state.
- VoiceOver reads the chips' selected state, as the condition chips do,
  and a cleared Bought field reads as nothing selected.

## Acceptance criteria

1. [ ] The add/edit item form shows a **Bought** field with **New** and
   **Used**, neither selected for a new item.
2. [ ] Picking New or Used and saving stores it; reopening the item's form
   shows it selected.
3. [ ] Tapping the selected Bought chip clears it; saving then stores the
   item as not recorded.
4. [ ] An item saves with Bought unset, with no prompt, warning or
   validation message.
5. [ ] Every item that existed before the update opens as not recorded,
   whatever its condition — including items graded New.
6. [ ] The item's page labels its purchase-date row **Bought new** or
   **Bought used**, and plain **Bought** when not recorded.
7. [ ] The Mark as bought sheet shows the same Bought field, unselected;
   the item it creates carries what was picked, or not recorded.
8. [ ] Copying an item carries its Bought value to the copy.
9. [ ] Selling an item and returning it to the collection leaves its Bought
   value unchanged.
10. [ ] The condition scale offers **New, Excellent, Very Good, Good, Fair,
    Broken** in that order on the item form and the purchase sheet; Very
    Good saves, reopens selected, and reads **Very Good** on the item's
    page.
11. [ ] No existing item's condition changes on update.
12. [ ] An item graded Very Good gets a market figure from Reverb's
    "very good" listings only; an item graded Good gets one from "very
    good" and "good", exactly as before this spec.
13. [ ] The items CSV export ends in a **Bought** column with `new`, `used`
    or empty, and writes Very Good as `very good`.
14. [ ] Importing that export restores every item's Bought value and every
    Very Good grade; `NEW`, `Used`, `Very Good` and `VERY GOOD` all import.
15. [ ] An items CSV in the previous layout, without the Bought column,
    still imports, every row not recorded.
16. [ ] The downloadable items template includes the Bought column.
17. [ ] The PDF labels an item's purchase date **Bought new** or **Bought
    used** where recorded and plain **Bought** where not, with no second
    "Bought" field, and prints Very Good as **Very Good**.
18. [ ] Six condition chips lay out without clipping at the narrowest
    supported width, on both the item form and the purchase sheet.
19. [ ] The wishlist add/edit form shows a **Looking for** field with
    **New** and **Used**, neither selected for a new entry; it saves,
    reopens selected, clears by tapping the selected chip, and saves
    unset without a prompt.
20. [ ] Every wishlist entry that existed before the update opens as not
    recorded.
21. [ ] The wanted item's page shows a **Looking for** row reading **New** or
    **Used**, and no row when not recorded.
22. [ ] A wanted item looking for new gets its market figure from Reverb's
    brand-new and B-stock listings only, and its market line says "new
    listings"; one looking for used, or not recorded, gets exactly the
    figure and wording it gets today.
23. [ ] Marking a wanted item bought preselects the purchase sheet's
    Bought chip from its preference (nothing when not recorded), and the
    person can change or clear it before saving.
24. [ ] Copying a wishlist entry carries its preference.
25. [ ] The wishlist CSV export ends in a **Looking For** column; importing
    it restores every preference; an older wishlist file without it still
    imports, every row not recorded; the wishlist template includes it.
26. [ ] The wishlist PDF shows **Looking for** where recorded and omits it
    where not.
27. [ ] The Bought value, the Looking for preference and Very Good sync to a second signed-in device.
    *(A two-device check; gathered in `specs/SYNC-CHECKS.md` if it cannot
    be run at the close-out.)*
28. [ ] The CloudKit schema test still validates with both new fields.

## Decisions record

1. **This spec first, before the import** (the person, 2026-09-29). Of the
   five specs from the collection-at-scale conversation, provenance is the
   smallest and the ninety-row import should carry it.
2. **No gift value** (the person, 2026-09-29). Offered as a third choice
   beside New and Used; declined because a gift can itself be new or used.
   A gift is an item with a zero purchase price, as today. Whether charts
   treat zero-price items specially is `023`'s question.
3. **Optional, no default** (the person, 2026-09-29). Not required on the
   form or the purchase sheet; not prefilled; existing items start not
   recorded. Chosen over "required for new items" and over "defaults to
   Used", which would save a wrong default silently.
4. **Never inferred from condition** (proposed in the conversation, not
   objected to). New condition is a state, not a history.
5. **Shown on forms, the item page, the CSV and the PDF — not on list
   rows** (the person, 2026-09-29).
6. **Very Good between Excellent and Good; Good's market comparison
   unchanged** (the person, 2026-09-29). Offered: split Good to Reverb's
   "good" only, for accuracy. Chosen: keep Good on "very good" + "good" so
   no existing figure moves, with Very Good on "very good" alone.
7. **One appended CSV column** and a PDF line — the PDF half refined by
   Decision 10 (follows from Decision 5 and
   `006`'s precedent for adding columns).

8. **A new/used preference on wishlist entries, in this spec** (the
   person, 2026-09-29, at their reading of the first Draft). Offered as
   the one natural widening of a narrow spec; accepted. Same two values,
   optional, no default, not inferred.
9. **Not recorded keeps today's used-listings figure** (proposed with
   Decision 8). Reading all listings when unstated would have been the
   more neutral default, but it would move every existing wanted item's
   figure on update — the same reasoning as Decision 6.

10. **How the words sit on the pages and the PDF** (the person, 2026-09-29,
    answering the plan's four readings before sign-off). The item page folds
    new/used into the existing purchase-date row's label ("Bought used ·
    Mar 3, 2024") rather than adding a row; the wanted page uses a details
    row ("Looking for · New") rather than a sentence; the PDF matches the
    item page rather than printing a second field labelled "Bought"; and a
    wanted item looking for new whose new listings are too few keeps the
    second sentence naming the lowest *used* asking price — it says "used"
    plainly and is a useful hint.

### Proposals (P-items, decided at plan approval)

- **P1** — tapping the selected Bought chip clears it.
- **P2** — Copy carries the Bought value.
- **P3** — the item's page is silent when not recorded, rather than
  showing a dash.
- **P4** — an older app version on another device must neither crash on
  nor erase the new data; the plan says how, and whether it can be tested.
- **P5** — Very Good is written `very good` in the CSV.
- **P6** — marking a wanted item bought prefills the sheet's Bought chip
  from its preference, still changeable.

## Non-goals (explicit)

- **A gift field or value** (Decision 2).
- **Inferring Bought from condition, price, place or date** (Decision 4) —
  including any one-time guess for existing items.
- **Filtering, grouping, sorting or searching by Bought** — `022`.
- **Any Dashboard figure or chart using it** — `023`.
- **A Bought marker on list rows** (Decision 5).
- **Setting Bought on many items at once.** The way to do that for an
  existing collection is `021`'s round-trip import.
- **Import leniency beyond the new column and the new grade** — `$`
  prices, other date formats, missing columns, blank rows — `021`.
- **An "either" preference** that reads new and used listings together.
  Not recorded already means "no preference stated", and it keeps
  today's used figure (Decision 9).
- **Re-grading existing items** or changing what New, Excellent, Good,
  Fair or Broken mean.

## Inherited caveats

- Every font is fixed-size (`017-dynamic-type`); the new field inherits
  that.
- Two-device sync checks are gathered in `specs/SYNC-CHECKS.md`; nobody
  has run that pass yet.

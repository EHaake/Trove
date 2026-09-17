# 014 — Sold-Side Parity and Mark as Sold on the Swipe

**Status**: **Draft** (2026-09-16) — written with the person in this spec
session from the requests carried out of `006` (`specs/NEXT-sold-side-parity.md`,
`006` Decision 16), and revised the same day at the person's reading of the
first Draft (Decisions 1–6). Every product decision below was made by the
person and is listed in the Decisions record; the P-items are Claude Code's
proposals and become decisions on plan approval, as `006`'s did.

Authored in a Claude Code spec session of its own, per `CLAUDE.md`'s model
policy (Fable 5.1, the session raised to high effort for the spec
conversation).

**Depends on**: `006-mark-as-sold` (the sale, the Sold side, the sale sheet,
the sold page's Sold mark this spec moves), `010-item-management-enhancements`
(the Items list's search, category chips, Sort By and leading swipe, which the
Sold side now shares), `011-data-export` (the CSV's narrowing rule, which the
Sold side's narrowing now feeds), `013-settings-menu` (the "…" menu stays
the one system `Menu`). It touches no network code, no schema and no export
format.

## Summary

`006` gave Trove a Sold side and a way to record a sale, and then the person
used it. Two things were harder than they should be. **Mark as sold…** was
hidden in the item page's "…" menu, where the person did not find it, and it
was not on the Items list's swipe at all — so the one action the feature
exists for took a hunt. And the Sold side was a flat list: no search, no
category chips, no sort, so once a few sales were in it there was no way to
find one. This spec fixes both: a **Mark as sold action on the Items list's
leading swipe**, opening the same sale sheet as before; and the **Sold side
gains the search bar, the category chips and Sort By**, matching the Owned
side, with sort options that make sense for things already sold — **Date
sold** first — and **each side keeps its own search, chip and sort while you
switch between them**. One more thing the person asked for on reading the
Draft: on a sold item's page the Sold mark — outcome, date, price, place —
moves from above the photo to **directly under the item's name**.

A visible Mark as sold button on the item page was in the first Draft and
was taken out at the person's reading (Decision 1): the page's bottom is not
to become a shelf for more and more actions. It is on the roadmap as a
consideration, not a plan.

## What and why

`006` Decision 4 put Mark as sold… in the detail's "…" menu and on Sell Plan
rows, and kept the Items swipe delete-only, on the reasoning that a sale is
a considered act. In use the opposite held: the person did not find the menu
row (recorded at `006`'s close-out and in the roadmap), and the swipe — the
lowest-friction gesture in the app, already carrying Edit and Copy — is
where a hobbyist who has just shipped a guitar reaches first. The sale sheet
that follows is still the considered step: nothing here makes a sale a
single tap. The menu row stays where it is; the swipe is the second way in,
not a replacement.

`006` P16 kept the Sold side without narrowing or sorting "in this version",
as a scoping call, not a design one. With sales accumulating the Sold side
needs what the Owned side has, and the reason `006`'s plan gave for sharing
one narrowing function across both halves — "a narrowing is about which
gear, and sold gear still has a category, a name and a value field" (`006`
plan Q5) — is the reason the same controls fit. The one place the sides
genuinely differ is what you would sort by: a sold item has no manual order,
no market figure and no desire to keep, and it has a sold date, a sale price
and an outcome the Owned side does not.

This spec reverses three things `006` fixed, and says so rather than
patching around them: Decision 4 and criterion 1 (the swipe stays
delete-only), P16 and Non-goals (no narrowing or sorting on the Sold side),
and Q15/G33 (switching sides clears the narrowing — replaced by each side
keeping its own). `006`'s
`spec.md` and `plan.md` are annotated in place at this spec's plan approval
to point here (Inherited caveats).

## Core behavior

### Mark as sold on the Items list's swipe

- The Owned side's rows gain **Mark as sold…** on the **leading** swipe,
  between Edit and Copy: Edit stays nearest the edge, so a full swipe still
  edits (Decision 2). It opens the sale sheet for that item, directly, with
  the same defaults as everywhere else, and the sale points at no plan
  (`006` P5); the swipe never records a sale by itself. Cancelling the sheet
  leaves the item exactly as it was.
- The item page's "…" menu is unchanged in both states. No visible button
  is added to the page (Decision 1).
- The trailing swipe stays delete-only on both sides. The Sold side's rows
  gain no leading swipe (a sale is edited and returned from the item's page,
  as today).
- The Sell Plan rows' Mark as sold… is unchanged.

### The Sold side gains the Owned side's controls

- The Sold side shows the **search field**, the **category chips** and the
  **Sort By** control in the same places, at the same sizes, as the Owned
  side — so switching sides moves nothing in the header (`006` Decision 13
  still holds: the switch never jumps). The controls appear once anything
  has been sold, under the same "controls need a list to narrow" rule the
  Owned side uses at zero items.
- **Search** matches name and serial number, as on Owned.
- **Category chips** are built from the categories of sold items, with the
  same "All" chip and the same reveal-on-select behaviour. The Owned side's
  **Un-valued** chip does not appear on the Sold side: a sold item's current
  value is no longer something the app has an opinion about (`006`,
  `SoldItemRow`'s reasoning), so "unvalued" is not a way to narrow it.
- The **summary line** under the title follows the narrowing on the Sold
  side as it does on Owned: "2 sold · $1,900 · Gain $350" over the rows on
  screen, "0 sold · $0" when a narrowing matches nothing — still always
  present, so the switch never moves (P4). The Dashboard's Sold card keeps
  showing the whole side.
- A Sold side narrowed to nothing shows the Owned side's **no-matches**
  empty state with its filter copy, not "Nothing sold yet" — the same
  precedence rule, both sides (P5).

### Sort By on the Sold side

- The Sold side's Sort By offers, in this order (Decision 3, P6):
  - **Date sold** — most recent sale first. The default, and the order the
    side has had since `006` (its P3).
  - **Price ↓** / **Price ↑** — by sale price.
  - **Paid ↓** / **Paid ↑** — by what was paid for it.
  - **Gain ↓** / **Gain ↑** — by the sale's outcome against what was paid:
    Gain ↓ puts the largest gain first and the largest loss last; Gain ↑ the
    reverse.
  - **Name** — alphabetical.
  The labels are placeholders settled at planning from the existing sort
  labels (Decision 5), with one fixed rule: a reader must be able to tell
  which end a loss sorts to.
- No **Custom** (a sold item has no manual order; "Date sold" is the order
  the CSV writes), no **Market** (a sold item's market figures are cleared
  on the device, `006` Decision 7), no **Desire** (a sold item has none).
- **Ties** fall back to the Sold side's existing order — sold date, then
  name, then id — so every sort is total and the same rows never swap
  between two loads (P7).
- The Owned side's Sort By is unchanged; "Date" there still means purchase
  date. Each side keeps its own sort selection, as it keeps its own
  narrowing (below).

### Switching sides

- **Each side keeps its own state** — its search text, its chip, its sort,
  and on Owned the Un-valued chip too — and switching sides shows the other
  side exactly as you left it (Decision 4). Searching "Fender" on Owned,
  going to Sold and coming back finds "Fender" still in the field and the
  rows still narrowed; the Sold side meanwhile shows whatever it was showing
  before. Neither side's state leaks into the other's, and nothing is
  remembered across launches: both sides start clean, Owned on "Date" and
  Sold on "Date sold" (P8). This replaces `006` Q15's clearing rule.
- What the controls show is always the side on screen, so a narrowing is
  never in force without its chip or query visible.
- The **Dashboard's Sold card** goes to the Sold side as it currently stands
  within the launch (P9); the Dashboard's category routes still set the
  Owned side's chip and land on Owned, as today.

### Exports

- The CSV's rule is unchanged in words and now bites on both sides: the
  file is the Owned rows that pass the **on-screen side's** narrowing, in
  visible order, then the sold rows that pass the same narrowing, in
  Sold-side order (`006` Q5). The other side's own, hidden narrowing plays
  no part (P11) — a file is never narrowed by something not on screen. A
  CSV exported from a Sold side narrowed to "Cameras" holds owned and sold
  cameras, and the coverage label says so. With no narrowing on the side on
  screen the file is the complete record.
- The Sold side's **sort choice does not change the CSV's sold order**: the
  file's sold rows are always in Date-sold order (P10), the way Settings'
  export-everything CSV writes them, so `013`'s byte-identity between the
  two paths still holds.
- The PDF stays owned-only. Import is untouched.

### The sold page's mark

- On a sold item's page the **Sold mark** — the SOLD tag with the outcome
  ("Loss $150 vs paid"), the sale line (date · price · place) and the note —
  moves from the top of the page, above the photo, to **directly under the
  item's name** (Decision 6): photo, then name, then the mark, then the
  paid/value stats and the rest of the read-only page as today. Its words,
  colours and VoiceOver reading are unchanged; only its place moves.

## Copy

- Leading swipe action: "Sell" or "Mark as sold" — settled at planning
  within the 76 pt action width (Design requirements); the placeholder is
  "Sell".
- Sort options: "Date sold", "Price ↓", "Price ↑", "Paid ↓", "Paid ↑",
  "Gain ↓", "Gain ↑", "Name" — placeholders (P6).
- The Sold side's no-matches state reuses the Owned side's copy.

## Design requirements

- **No design pass** (Decision 5): everything here is settled at planning
  from `design/tokens.md` and the components that exist.
- **The leading swipe keeps `010`'s swipe-row rules**: 76 pt per leading
  action, rust the only consequential colour on a swiped-open row. Mark as
  sold is not destructive and is followed by a sheet, so it takes a neutral
  or brass tint, never rust; planning picks the tint and the glyph (a
  template icon from `design/icons/`, like Edit's and Copy's, not an SF
  Symbol).
- **The sold page's mark keeps its own look** — unplated, a stamp on the
  page — in its new place under the name; the gap above and below it is the
  page's standing section gap.
- **Nothing in the header moves when the side changes.** Search, chips and
  Sort By occupy the same slots on both sides; `006` Decision 13's
  measurement (the switch's top edge at the same point on both sides) is
  re-taken with the controls present.
- **Colour never carries a sort direction alone**: the arrow glyphs in the
  labels do.
- Fixed type sizes (`001`) apply.

## Acceptance criteria

1. [ ] On the Owned side, a row's leading swipe offers Edit, Mark as sold…
   and Copy in that order; a full swipe still edits; Mark as sold… opens the
   sale sheet for that row's item, and cancelling it changes nothing. The
   trailing swipe is still delete-only on both sides, and Sold rows have no
   leading swipe.
2. [ ] The item page's "…" menu is unchanged in both states, and no new
   button appears on the page.
3. [ ] Once anything has been sold, the Sold side shows the search field, the
   category chips and Sort By in the Owned side's positions; the switch's
   top edge is at the same point on both sides (measured, as `006`
   criterion 7a was).
4. [ ] Searching on the Sold side narrows the rows by name or serial; the
   summary line follows the rows on screen and never disappears.
5. [ ] The Sold side's chips are the categories of sold items only; tapping
   one narrows the rows, and there is no Un-valued chip.
6. [ ] Sort By on the Sold side offers exactly Date sold, Price ↓, Price ↑,
   Paid ↓, Paid ↑, Gain ↓, Gain ↑ and Name, defaults to Date sold, and each
   order is correct on a fixture with a gain, a loss and an at-cost sale;
   ties resolve by the side's standing order.
7. [ ] Each side keeps its own search, chip and sort while the other side is
   visited, in both directions, and neither side's state changes the
   other's; at launch both sides are clean. The Owned side's Sort By is
   unchanged and reads "Date".
8. [ ] The Dashboard's Sold card lands on the Sold side as it stands; the
   Dashboard's category routes still land on Owned with that chip set.
9. [ ] A Sold side narrowed to nothing shows the no-matches state with its
   filter copy, not "Nothing sold yet"; with nothing sold at all it still
   shows "Nothing sold yet" and no controls.
10. [ ] A CSV exported from a narrowed Sold side holds the owned and sold
    rows that pass that narrowing, with a true coverage label, and the
    hidden side's own narrowing has no effect on it; exported with no
    narrowing on the side on screen it is byte-identical to Settings'
    export-everything CSV, whatever sort either side is showing.
11. [ ] On a sold item's page the Sold mark sits directly under the item's
    name, below the photo and above the stats, with its words and colours
    unchanged.
12. [ ] Every new control is reachable by VoiceOver with a label and, for the
    swipe action, a name — the person's step with Accessibility Inspector.
13. [ ] The existing UI suite still starts from the state each test was
    written against; the suite passes twice back to back.

## Decisions record

Made by the person, 2026-09-16, at their reading of the first Draft:

1. **No visible Mark as sold button on the item page.** The first Draft
   proposed one under the desire card, mirrored by a Return to collection…
   button on a sold page. Withdrawn: the person does not want the page's
   bottom to become a place where more and more things get added. The "…"
   menu row stays the page's way in; the swipe is the low-friction one. The
   button is recorded on the roadmap as a consideration, not a plan.
2. **Edit stays nearest the edge on the leading swipe**, so a full swipe
   still edits; Mark as sold… sits between Edit and Copy.
3. **The Sold side's sort offers Date sold, Price, Paid, Gain and Name** —
   "Paid" and "Name" added to the Draft's list at the person's answer.
4. **Each side keeps its own search, chip and sort across a switch.**
   Searching or filtering on one side, visiting the other and coming back
   finds the narrowing as it was. The person's call over the Draft's
   "switching clears", which `006` Q15 had settled.
5. **No design pass.** Placement, tint and labels are settled at planning
   from the existing tokens.
6. **The sold page's Sold mark moves from above the photo to directly under
   the item's name.**

Proposed at drafting, 2026-09-16, by Claude Code (these become decisions on
plan approval):

- **P3. The leading swipe's Mark as sold… opens the sheet directly**, with
  no intermediate confirmation; the sheet is the confirmation.
- **P4. The Sold summary line follows the narrowing**, as the Owned side's
  line does, and is never hidden (`006` Decision 13).
- **P5. The no-matches state is shared** between sides; "Nothing sold yet"
  is only for a Sold side with nothing sold at all.
- **P6. Sold-side sort options are Date sold, Price ↓, Price ↑, Paid ↓,
  Paid ↑, Gain ↓, Gain ↑, Name**; no Custom, Market or Desire.
- **P7. Ties fall back to the standing Sold order** (date, name, id).
- **P8. Both sides start clean at every launch** — Owned on "Date" with no
  narrowing, Sold on "Date sold" with none — and nothing about either side
  is remembered across launches, as nothing is today.
- **P9. The Dashboard's Sold card goes to the Sold side as it stands.** It
  means "show me the Sold side", and the side's own chip or query is
  visible when it arrives; the Dashboard's category routes keep setting the
  Owned side's chip.
- **P10. The CSV's sold rows are always in Date-sold order**, whatever the
  side is showing; the view's sort is a reading aid, the file's order is
  the record's.
- **P11. The CSV is narrowed by the on-screen side's narrowing only**, over
  both halves; the hidden side's state never touches the file.

## Non-goals (explicit)

- **A visible Mark as sold button on the item page** (Decision 1) — a
  roadmap consideration.
- **Editing or copying a sold item from its row** — the Sold side's rows
  gain no leading swipe.
- **Grouping or a year filter on the Sold side**, sales over time, charts —
  still a follow-up once there is history to show (`006` Non-goals).
- **Remembering the side, a sort or a narrowing across launches** — per
  side within a launch only (Decision 4).
- **A manual order for sold items.**
- **A one-tap sale** — every path opens the sale sheet.
- **Mark as sold on the Wishlist or Dashboard**, or a sell-plan picker from
  an owned item's page (`010`'s unbuilt row stays unbuilt).
- **Any change to the sale sheet** or to the sold page beyond the mark's
  place.
- **Any change to the sale's fields, the CSV columns, import, or sync.**

## Inherited caveats

- `006` Decision 4, criterion 1, P16, Q15/G33 and its Non-goals are
  superseded here; `006`'s `spec.md` and `plan.md` get a one-line pointer
  at each on this spec's plan approval.
- `001`'s fixed type sizes and USD-only rule apply.
- `013`'s rule stands: the "…" menu stays the one system `Menu`; the sort
  dropdown and the swipe are Trove's own.

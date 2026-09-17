# 014 — Sold-Side Parity and a Visible Mark as Sold

**Status**: **Draft** (2026-09-16) — written with the person in this spec
session from the requests carried out of `006` (`specs/NEXT-sold-side-parity.md`,
`006` Decision 16). The questions marked **Q** in "Questions for the person"
are open until the person answers them; the P-items are Claude Code's
proposals and become decisions on plan approval, as `006`'s did.

Authored in a Claude Code spec session of its own, per `CLAUDE.md`'s model
policy (Fable 5.1, the session raised to high effort for the spec
conversation).

**Depends on**: `006-mark-as-sold` (the sale, the Sold side, the sale sheet,
the "…" menu rows this spec adds a second way to reach), `010-item-management-enhancements`
(the Items list's search, category chips, Sort By and leading swipe, which the
Sold side now shares), `011-data-export` (the CSV's narrowing rule, which the
Sold side's narrowing now feeds), `013-settings-menu` (the "bespoke in the
page, system in the bars" rule the visible button follows). It touches no
network code, no schema and no export format.

## Summary

`006` gave Trove a Sold side and a way to record a sale, and then the person
used it. Two things were harder than they should be. **Mark as sold…** was
hidden in the item page's "…" menu, where the person did not find it, and it
was not on the Items list's swipe at all — so the one action the feature
exists for took a hunt. And the Sold side was a flat list: no search, no
category chips, no sort, so once a few sales were in it there was no way to
find one. This spec fixes both: a **visible Mark as sold button on the item
page** and a **Mark as sold action on the Items list's leading swipe**, both
opening the same sale sheet as before; and the **Sold side gains the search
bar, the category chips and Sort By**, matching the Owned side, with sort
options that make sense for things already sold — **Date sold** first.

## What and why

`006` Decision 4 put Mark as sold… in the detail's "…" menu and on Sell Plan
rows, and kept the Items swipe delete-only, on the reasoning that a sale is
a considered act. In use the opposite held: the person did not find the menu
row (recorded at `006`'s close-out and in the roadmap), and the swipe — the
lowest-friction gesture in the app, already carrying Edit and Copy — is
where a hobbyist who has just shipped a guitar reaches first. A visible
control is what a primary action of a feature deserves. The sale sheet that
follows is still the considered step: nothing here makes a sale a single
tap.

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
patching around them: Decision 4 and criterion 1 (placement of Mark as
sold), P16 and Non-goals (no narrowing or sorting on the Sold side), and the
part of Q15/G33 that made the Sold side's narrowing an identity. `006`'s
`spec.md` and `plan.md` are annotated in place at this spec's plan approval
to point here (Inherited caveats).

## Core behavior

### A visible Mark as sold on the item page

- An owned item's page shows a **visible Mark as sold… button** in the page
  itself, in addition to the "…" menu row, which stays (P1, **Q1**). Both
  open the same sale sheet with the same defaults, and a sale recorded from
  either points at no plan, exactly as the menu row does today (`006` P5).
- Where the button sits and what it looks like is the design pass's call,
  within the page's existing button chrome (Design requirements). The
  proposal at P1: directly under the desire card, full width, in the
  outlined brass style the Market section uses for actions that do not
  themselves write data — the sheet does the writing.
- A **sold** item's page shows a visible **Return to collection…** button in
  the same place (P2, **Q1**), so the two states of the page mirror each
  other; its confirmation is unchanged. The "…" menu's three rows in each
  state are unchanged.

### Mark as sold on the Items list's swipe

- The Owned side's rows gain **Mark as sold…** on the **leading** swipe,
  beside Edit and Copy (P3, **Q2**). It opens the sale sheet for that item,
  directly, with the same defaults as everywhere else; the swipe never
  records a sale by itself. Cancelling the sheet leaves the item exactly as
  it was.
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

- The Sold side's Sort By offers, in this order (P6, **Q3**):
  - **Date sold** — most recent sale first. The default, and the order the
    side has had since `006` (P3).
  - **Price ↓** / **Price ↑** — by sale price.
  - **Gain ↓** / **Gain ↑** — by the sale's outcome against what was paid:
    Gain ↓ puts the largest gain first and the largest loss last; Gain ↑ the
    reverse.
  The labels are placeholders for the design pass, with one fixed rule: a
  reader must be able to tell which end a loss sorts to.
- No **Custom** (a sold item has no manual order; "Date sold" is the order
  the CSV writes), no **Market** (a sold item's market figures are cleared
  on the device, `006` Decision 7), no **Desire** (a sold item has none).
- **Ties** fall back to the Sold side's existing order — sold date, then
  name, then id — so every sort is total and the same rows never swap
  between two loads (P7).
- The Owned side's Sort By is unchanged; "Date" there still means purchase
  date. **Each side keeps its own sort selection** for the life of the
  launch (P8): switching sides shows that side's choice, and neither is
  remembered across launches, as Owned's is not today.

### Switching sides

- **Switching sides clears the narrowing**, as `006` Q15 settled (P9,
  **Q4**): each side starts clean when you arrive, and a chip or query left
  behind on one side never silently narrows the other. The Dashboard's Sold
  card lands on a clean Sold side, as today.

### Exports

- The CSV's rule is unchanged in words and now bites on both sides: the
  file is the Owned rows that pass the visible narrowing, in visible order,
  then the sold rows that pass the same narrowing, in Sold-side order
  (`006` Q5). What changes is that from the Sold side the narrowing is no
  longer always the identity: a CSV exported from a Sold side narrowed to
  "Cameras" holds owned and sold cameras, and the coverage label says so.
  With no narrowing the file is the complete record, from either side.
- The Sold side's **sort choice does not change the CSV's sold order**: the
  file's sold rows are always in Date-sold order (P10), the way Settings'
  export-everything CSV writes them, so `013`'s byte-identity between the
  two paths still holds.
- The PDF stays owned-only. Import is untouched.

## Copy

- Button on the item page: "Mark as sold…" (owned) / "Return to
  collection…" (sold) — `SaleCopy`'s existing strings, so the button and the
  menu row cannot say different things.
- Leading swipe action: "Sell" or "Mark as sold" — the design pass's call
  within the 76 pt action width (Design requirements); the placeholder is
  "Sell".
- Sort options: "Date sold", "Price ↓", "Price ↑", "Gain ↓", "Gain ↑" —
  placeholders (P6).
- The Sold side's no-matches state reuses the Owned side's copy.

## Design requirements

- **The visible button uses the page's existing button chrome** (`002`'s
  filled / outlined / text rule in `design/tokens.md`), no new component.
  Which of the three, and where on the page, is the design pass's call
  (**Q5**); P1 proposes outlined, under the desire card.
- **The leading swipe keeps `010`'s swipe-row rules**: 76 pt per leading
  action, rust the only consequential colour on a swiped-open row. Mark as
  sold is not destructive and is followed by a sheet, so it takes a neutral
  or brass tint, never rust; the design pass picks it and the order of the
  three actions (**Q2**).
- **Nothing in the header moves when the side changes.** Search, chips and
  Sort By occupy the same slots on both sides; `006` Decision 13's
  measurement (the switch's top edge at the same point on both sides) is
  re-taken with the controls present.
- **Colour never carries a sort direction alone**: the arrow glyphs in the
  labels do.
- Fixed type sizes (`001`) apply.

## Acceptance criteria

1. [ ] An owned item's page shows a visible Mark as sold… button that opens
   the sale sheet; the "…" menu's Mark as sold… row is still there and opens
   the same sheet. A sale recorded from the button points at no plan.
2. [ ] A sold item's page shows a visible Return to collection… button that
   asks the same confirmation as the menu row and does the same thing.
3. [ ] On the Owned side, a row's leading swipe offers Mark as sold…, which
   opens the sale sheet for that row's item; cancelling the sheet changes
   nothing. The trailing swipe is still delete-only on both sides, and Sold
   rows have no leading swipe.
4. [ ] Once anything has been sold, the Sold side shows the search field, the
   category chips and Sort By in the Owned side's positions; the switch's
   top edge is at the same point on both sides (measured, as `006`
   criterion 7a was).
5. [ ] Searching on the Sold side narrows the rows by name or serial; the
   summary line follows the rows on screen and never disappears.
6. [ ] The Sold side's chips are the categories of sold items only; tapping
   one narrows the rows, and there is no Un-valued chip.
7. [ ] Sort By on the Sold side offers exactly Date sold, Price ↓, Price ↑,
   Gain ↓ and Gain ↑, defaults to Date sold, and each order is correct on a
   fixture with a gain, a loss and an at-cost sale; ties resolve by the
   side's standing order.
8. [ ] Each side keeps its own sort choice within a launch; the Owned side's
   Sort By is unchanged and reads "Date".
9. [ ] Switching sides clears any narrowing, in both directions, as `006`
   Q15 required; the Dashboard's Sold card still lands on a clean Sold
   side.
10. [ ] A Sold side narrowed to nothing shows the no-matches state with its
    filter copy, not "Nothing sold yet"; with nothing sold at all it still
    shows "Nothing sold yet" and no controls.
11. [ ] A CSV exported from a narrowed Sold side holds the owned and sold
    rows that pass that narrowing, with a true coverage label; exported
    with no narrowing from either side it is byte-identical to Settings'
    export-everything CSV, whatever sort either side is showing.
12. [ ] Every new control is reachable by VoiceOver with a label and, for the
    swipe action, a name — the person's step with Accessibility Inspector.
13. [ ] The existing UI suite still starts from the state each test was
    written against; the suite passes twice back to back.

## Questions for the person

- **Q1 — The page button.** Keep the "…" menu row as well as the button
  (proposed), or replace it? And should the sold page get a visible Return
  to collection… button too (proposed yes, for symmetry)?
- **Q2 — The swipe.** Order of the three leading actions. Proposed: Edit
  stays nearest the edge (a full swipe still edits, as today), then Mark as
  sold, then Copy. The alternative is Mark as sold nearest the edge, so a
  full swipe opens the sale sheet.
- **Q3 — The sort options.** Proposed: Date sold, Price ↓/↑, Gain ↓/↑, and
  nothing else. Is "Paid" (what you paid for it) or "Name" wanted?
- **Q4 — Switching sides.** Proposed: clears the narrowing, as today. The
  alternative is carrying the search and the chip across, so Owned → Sold
  under "Cameras" shows sold cameras — at the cost of a chip on the Sold
  side for a category nothing sold is in.
- **Q5 — A design pass.** The button's place and style and the swipe
  action's tint are small enough to settle from the existing tokens in
  `plan.md`; a Claude Design pass is not proposed. Say if one is wanted.

## Decisions record

To be recorded when the person answers Q1–Q5 and approves the Draft.

Proposed at drafting, 2026-09-16, by Claude Code (these become decisions on
plan approval):

- **P1. The item page's visible Mark as sold… is in addition to the menu
  row**, outlined brass, full width, directly under the desire card — the
  slot where `010`'s mock once placed a sell-plan row that was never built.
  Outlined rather than filled: the button opens a sheet; the sheet's confirm
  is what writes.
- **P2. The sold page mirrors it with Return to collection…** in the same
  slot, same chrome, same confirmation as the menu row.
- **P3. The leading swipe gains Mark as sold… as its middle action**, Edit
  still nearest the edge; the action opens the sheet directly.
- **P4. The Sold summary line follows the narrowing**, as the Owned side's
  line does, and is never hidden (`006` Decision 13).
- **P5. The no-matches state is shared** between sides; "Nothing sold yet"
  is only for a Sold side with nothing sold at all.
- **P6. Sold-side sort options are Date sold, Price ↓, Price ↑, Gain ↓,
  Gain ↑**; no Custom, Market or Desire.
- **P7. Ties fall back to the standing Sold order** (date, name, id).
- **P8. Sort selection is per side and per launch.**
- **P9. Switching sides clears the narrowing** — `006` Q15 stands.
- **P10. The CSV's sold rows are always in Date-sold order**, whatever the
  side is showing; the view's sort is a reading aid, the file's order is
  the record's.

## Non-goals (explicit)

- **Editing or copying a sold item from its row** — the Sold side's rows
  gain no leading swipe.
- **Grouping or a year filter on the Sold side**, sales over time, charts —
  still a follow-up once there is history to show (`006` Non-goals).
- **Remembering the side, a sort or a narrowing across launches.**
- **A manual order for sold items.**
- **A one-tap sale** — every path opens the sale sheet.
- **Mark as sold on the Wishlist or Dashboard**, or a sell-plan picker from
  an owned item's page (`010`'s unbuilt row stays unbuilt).
- **Any change to the sale's fields, the CSV columns, import, or sync.**

## Inherited caveats

- `006` Decision 4, criterion 1, P16 and its Non-goals are superseded here;
  `006`'s `spec.md` gets a one-line pointer at each on this spec's plan
  approval, and `006` plan Q15's "the narrowing is the identity on the Sold
  side" sentence is struck, since the clearing rule stays but the identity
  no longer follows from it.
- `001`'s fixed type sizes and USD-only rule apply.
- `013`'s "bespoke in the page, system in the bars" rule places the button
  in the page as a Trove control; the "…" menu stays the one system `Menu`.

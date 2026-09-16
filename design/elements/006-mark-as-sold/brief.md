# Trove `006` — Mark as sold: the Design pass brief

This is the prompt for the `/design` pass spec `006` asks for (spec's
"Design requirements", the `002`/`005` pattern). The person runs it;
Claude Code wrote it from the approved `spec.md`, `plan.md` §3–§6,
`SaleCopy.swift`, `design/brief.md` and `design/tokens.md`. Everything
below the line is the prompt. Paste it whole, attach the context files
it names, iterate in the canvas, and drop the exports back into this
folder as `.dc.html` plus a PNG per artboard — the `002`/`005` layout.

Three rules for the pass itself, from the plan (T008):

- **The copy is fixed, with one deliberate exception.** Every string is
  listed here and lives in `SaleCopy.swift`. If the design wants a word
  this list doesn't have, that is a spec question — flag it in the
  export, don't invent it; Claude Code escalates it, never absorbs it.
  The exception is the **outcome** on a Sold-side row and on the sold
  page (spec Decision 10): "Gain $350" / "Loss $150" / "Sold at cost"
  and "Sold at a gain of $350" / "Sold at a loss of $150" / "Sold at
  cost" are **placeholders**. The pass settles their *form* — words, a
  labelled signed figure, or a mark — under one rule: **the gain or loss
  and its amount are unmistakable at a glance, and colour alone never
  carries the meaning.** Replacing those placeholder strings is inside
  the spec, not new copy.
- **Values come back as tokens.** `design/tokens.md` gains a "Mark as
  sold (`006`)" section sourced from the artboards, one row per
  property, with "as implemented" cells for the screen tasks — so read
  the existing tables there as the vocabulary to design in.
- **Six surfaces, one language.** Nothing here restyles a shipped
  screen; every surface extends one.

---

## The prompt

You are designing six new surfaces for **Trove**, a personal gear
inventory app for hobbyists — cameras and lenses, guitars and amps,
audiophile gear. The person tracks what they own and what they paid,
what they want to buy next, and sells underused gear to fund the next
purchase. The app is shipped and has an established visual language;
this pass extends it, it does not restyle anything.

Read these first, in this order:

1. `design/brief.md` — the direction and the rules. Non-negotiable
   ones: dark-first; flat and graphic with **restrained alpha-based
   depth only** (the `010` "extruded plate"); **no rendered materials**
   — no metallic gradients, wood, leather, glass; **bespoke inside the
   page, system in the bars** — nothing drawn inside a page's content is
   a system control; plain, direct voice.
2. `design/tokens.md` — the exact palette, type and spacing. Design in
   these values; add tokens only where a property genuinely has no
   existing one. The tables you will lean on most: **"Row treatment —
   'extruded plate' (`010`)"** (every card; the four unplated
   exceptions, including the Dashboard's un-valued callout, which is
   *outlined and unfilled*); **"Sort picker (`010`)"** (the badge the
   new switch is a sibling of); **"Item detail (`010` refresh)"** (the
   stat pair, the delta line's moss/rust register, the DETAILS rhythm);
   **"Sell Plan candidate rows"**; the **"Market section, candidate
   picker, dashboard variant (`002`)"** table for the Dashboard's
   register; and the **"Stock photos (`005`)"** section for how the
   last pass recorded its values.
3. The shipped screens the surfaces join, for context:
   `design/screens/Trove Item List.png`, `Trove Item Detail.png`,
   `Trove Dashboard.png`, `Trove Sell Plan.png`, `Trove Item Form.png`
   (the form style the sale sheet copies); and, for the Dashboard's
   existing tap-through card shape, the un-valued callout on the
   Dashboard screen.

### The feature, in one paragraph

An owned item can be **marked as sold**: from its page's "…" menu
(**Mark as sold…**) or from a Sell Plan row. A small sheet takes the
sale price (pre-filled with the item's current value), the date
(today, never the future), an optional place ("eBay, Reverb, a friend…")
and a note. Sold, the item leaves the Owned list, every Dashboard
figure and every Sell Plan, and moves to a new **Sold side** of the
Items tab, reached by a one-tap **Owned / Sold** switch at the top of
the page. Its page becomes a **sold state** — a Sold mark and the sale
over the familiar detail, read-only, with three actions: Edit sale…,
Return to collection…, Delete. The Dashboard gains a **Sold card** — a
separate ledger of count, proceeds and realised gain or loss, never
added to the collection totals — that hides when nothing in scope is
sold and jumps to the Sold side. A Sell Plan whose rows were sold shows
a third **Sold** figure beside Selected and Estimated cost, and a short
Sold section under its candidates. Gain and loss use the same moss/rust
cue the app already uses for value against cost, and the words always
say which it is.

### Palette and type, restated

Colors: `background #17181A`, `surface #201F1D`, `surfaceInset #26272A`,
`divider #3A3B3E`; ivory text `#F2EDE4` at 100 / 75 / 60 / 55 / 45 /
40 / 35 / 30 % (`textPrimary`, `textBody`, `textLabel`,
`textLabelSecondary`, `textMonoMeta`, `textQuiet`, `textDisabled`,
`textInactive`); `accentBrass #C79A56` (money, CTAs, external links),
`accentBrassTint rgba(199,154,86,0.12)`, `accentBrassDim #746140`;
`accentMoss #52634F` shapes / `accentMossText #7E9679` text; `accentRust
#9C4A34` shapes / `accentRustText #B8674F` text. Rust and moss as *text*
must use the `Text` lifts — the base values fail contrast on `surface`.
**No new colour anywhere in this pass, and never red/green.**

Type: Archivo 600 for display and hero figures; IBM Plex Sans 400/500/
600 for body; IBM Plex Mono 400/500 for money, dates, counts and every
all-caps label (tracked 0.06–0.16em). Sizes are the fixed ones in
`tokens.md`'s "Sizes" table.

Cards: `surface`, `3px` radius, the plate shadow set. Capsule chips and
the un-valued callout are the outlined, unfilled exceptions.

### The copy (all of it — `SaleCopy.swift`)

- Actions: **Mark as sold…**, **Edit sale…**, **Return to
  collection…** (the detail's system menu rows; the Sell Plan row's
  bespoke control also reads "Mark as sold…").
- The sheet: title **Mark as sold** / **Edit sale**; confirm **Mark as
  sold** / **Save**; **Cancel**. Fields **Sale price**, **Sold on**,
  **Sold at** (placeholder "eBay, Reverb, a friend…"), **Note**.
- Return alert (a standard system alert — not drawn): "Return {name} to
  your collection?" / "Its sale details will be removed." / **Return** /
  **Keep as sold**.
- The switch: **Owned**, **Sold**.
- Headers: the page mark **Sold**; the Dashboard card **Sold**; the Sell
  Plan figure **Sold**; the Sell Plan section **Sold**.
- Sold side empty state: headline "Nothing sold yet." detail "Mark an
  item as sold from its page or from a sell plan."
- Composed lines, with real examples to set:
  - Dashboard card figures: `3 items · $2,400`; beneath it the realised
    line `+$350 vs paid` (moss) / `−$150 vs paid` (rust) / `+$0 vs paid`.
  - Sold side summary: `3 sold · $2,400 · +$350 vs paid`.
  - Sale line (page): `Sold Sep 12, 2026 · $1,200 · eBay` — the place
    omitted when there is none: `Sold Sep 12, 2026 · $1,200`.
  - Row outcome (**placeholder form, Decision 10**): `Gain $350` /
    `Loss $150` / `Sold at cost`.
  - Page outcome (**placeholder form, Decision 10**): `Sold at a gain of
    $350` / `Sold at a loss of $150` / `Sold at cost`.
  - Sell Plan figure caption: `2 items` / `1 item`.

## Surface 1 — the Owned / Sold switch (Items page header)

A **bespoke in-page control** at the top of the Items page, in the
family of the Sort By badge (`tokens.md` "Sort picker": `1px` brass
border, `3px` radius, IBM Plex Mono `11px`) — two halves, **Owned** and
**Sold**, one tap switches. The person's own phrase is "two sides of
the same view"; a flip or a turn is a fair thing to try, not a mandate.
Decide: its footprint and placement in the header (it must stand over an
*empty* Owned side too, so it lives in the header, not among the rows);
the active half's treatment (brass fill with `background` text? brass
tint? — pick from the tokens); the inactive half's; how it sits beside
the search field, the Sort By badge and the "…" badge on the Owned
side, and beside only the "…" badge on the Sold side (Sort By and
search are hidden there). It is **not** a system segmented control.

Draw: the Owned side header with the switch on Owned (today's chrome
otherwise unchanged); the Sold side header with the switch on Sold.

## Surface 2 — the Sold side (rows and summary line)

Under the switch on the Sold side: a **summary line** (`3 sold · $2,400
· +$350 vs paid` — the realised part in moss/rust text), then the rows,
most recent sale first, in the same `List` chrome and plate treatment
as the Owned rows (`52px` thumbnail, `13px` padding/gap). Each row:
thumbnail, name, sold date, sale price, and the **outcome** — the
placeholder is `Gain $350` / `Loss $150` / `Sold at cost` in the quiet
moss/rust register the Sell Plan and the detail already use for value
against cost (`accentMossText` / `accentRustText`, IBM Plex Mono `11px`
is the delta-line register). **Decision 10 lives here**: settle the
outcome's form so that a colour-blind reader, or a screenshot in
greyscale, still reads gain versus loss and the amount without
hesitation. Words are the placeholder; a labelled signed figure or a
mark are the alternatives. Whatever you pick, the same form goes on the
sold page (Surface 4), scaled.

Draw: a Sold side with three rows — one gain, one loss, one at cost —
and the summary; the Sold side's **empty state** (headline + detail, the
app's `EmptyStateView` shape, over the switch still showing). No sort
control, no search, no filter chips on this side; the "…" badge stays.

## Surface 3 — the Dashboard's Sold card

A card **apart from the collection totals** — a separate ledger, never a
fourth headline figure and never combined with them. Header **Sold**,
figures `3 items · $2,400`, the realised line `+$350 vs paid` in moss
(or rust). The whole card is a tap-through to the Sold side, exactly
as a category slice already jumps into Items — so give it the same
"leads somewhere" cue the Dashboard already has (a chevron, the
callout's own idiom). Placement: after the un-valued callout and before
the category breakdown; it **hides entirely** when nothing in scope is
sold, and it follows the category scope when drilled in. Decide: plated
card (the default for any filled rectangle) or the callout's outlined,
unfilled form — and say why; the header's register (`monoLabel`
all-caps, as every section header); the figures' register (the
Dashboard's Spent/Gain figures are the neighbours — do not out-weigh the
headline value); the tap cue.

Draw: the Dashboard root with the card present; the Dashboard drilled
into a category with the card present (its figures smaller); note in a
caption that the card is absent otherwise (draw nothing for "hidden").

## Surface 4 — the sold state of the item detail

The item's own detail page, unchanged beneath, read-only, with a **Sold
mark** above the category eyebrow and name: the word **Sold**, the sale
line (`Sold Sep 12, 2026 · $1,200 · eBay`) and the **page outcome**
(placeholder `Sold at a gain of $350` — same form as Surface 2's, per
Decision 10). Beneath: the familiar page — photos (a stock photo keeps
its badge and credit), the WORTH NOW / PAID pair, the desire dial (not
interactive), DETAILS, NOTES. **Omitted** in the sold state: the Market
section and Find a photo…. Decide the mark's form (a plated block? a
band? a chip plus lines?), its type roles (the word Sold is a label, the
price is money — mono; the outcome is the moss/rust register), and how
it sits against the `240px` photo hero that follows.

The page's "…" menu is the app's one system `Menu` and is not drawn;
its rows in the sold state are Edit sale…, Return to collection…,
Delete.

Draw: the sold detail at a gain; the same at a loss (one artboard each,
or one with a variant strip); at cost may be a caption.

## Surface 5 — the Sell Plan's third figure and Sold section

The plan's header today shows two figures side by side — **Selected**
and **Estimated cost** (`Trove Sell Plan.png`). With at least one sale
recorded toward the plan, a third figure **Sold** joins them, captioned
`2 items`, in the same cell shape — three figures, **nothing subtracted
from the cost**, no gap or shortfall figure anywhere. The existing
colour cue (the plan reads as met when Selected plus Sold covers the
cost) is unchanged in form. Under the candidate rows, a short **Sold**
section lists the sales made toward the plan: name, date, price (one
line each, the DETAILS rhythm rather than plated rows — or plated, your
call, stated).

Each candidate row also gains a bespoke **Mark as sold…** control, in
the row's own style, separated from the row's selection toggle so the
two hit areas can't be confused (`tokens.md` "Sell Plan candidate
rows": `15/14` padding, `66` min height, the reserved trend slot).
Decide its form — a small brass-outlined text button, an inline text
link, a trailing glyph — and where it sits.

Draw: the plan header at two figures and at three; a candidate row with
the control; the Sold section with two entries.

## Surface 6 — the sale sheet

A form in the app's existing form style (`Trove Item Form.png`; every
field plated, borders only for state — rust when invalid, brass when
focused): title **Mark as sold** (or **Edit sale**), **Cancel** leading
and **Mark as sold** (or **Save**) trailing in the bar; fields **Sale
price** (the money field, pre-filled `$1,200`), **Sold on** (the date
field the item form uses for the purchase date; today by default, future
days disabled in its popover), **Sold at** with the placeholder "eBay,
Reverb, a friend…", **Note**. A medium detent is the likely size; say
so. Draw: the sheet filled for a mark; the price field in its invalid
(blank) state.

### Not designed in this pass

- The **return** and **delete** confirmations — standard system alerts.
- The detail's "…" **system menu** — the rows are copy, not a surface.
- The **Owned side** itself, the Wishlist and the item form — unchanged.

## Accessibility to hold in mind (not drawn, but the design must allow it)

- The switch is one element labelled "Owned or sold" whose value is the
  side showing; leave room for the active half to read as selected.
- A Sold-side row reads as one element: name, sold date, price, outcome
  — "Sold Sep 12, 2026, $1,200, gain $350".
- The Sold mark on the page is one element: "Sold", the sale line, the
  outcome.
- The Dashboard card is a button with a hint that it shows the sold
  items; the Sell Plan's Sold figure is labelled with its count.

## Deliverables

- `.dc.html` artboards (one canvas holding all six surfaces is fine),
  each state on its own artboard, at iPhone width, dark:
  - switch: **Owned side header**, **Sold side header**;
  - Sold side: **three rows + summary** (gain, loss, at cost), **empty
    state**;
  - Dashboard: **root with card**, **category with card**;
  - detail: **sold at a gain**, **sold at a loss**;
  - Sell Plan: **two figures**, **three figures + row control + Sold
    section**;
  - sheet: **filled**, **price invalid**.
- A PNG per artboard.
- **The Decision 10 form, stated in one line** — which of words / a
  labelled signed figure / a mark the rows and the page use, and the
  exact strings if they differ from the placeholders (these replace the
  placeholder strings in `SaleCopy` at implementation).
- Any property this brief leaves open, stated as a value (size, weight,
  color token, spacing, the switch's active treatment, the card's
  plated-or-outlined choice, the row control's form) so it can be
  written straight into `design/tokens.md`'s new "Mark as sold (`006`)"
  section.
- Any copy you wanted and didn't have, listed separately. It goes to
  the spec, not into the artboards as final.

# Trove `002` — Market values: the Design pass brief

This is the prompt for the `/design` pass spec `002` asks for (spec
Decisions 10 and 17). The person runs it; Claude Code wrote it from the
approved `spec.md`, `plan.md` §6, `MarketCopy.swift`, `design/brief.md`
and `design/tokens.md`. Everything below the line is the prompt. Paste
it whole, attach the context files it names, iterate in the canvas,
and drop the exports back into this folder as `.dc.html` plus a PNG per
artboard — `010`'s layout (`design/elements/010-item-management/`).

Two rules for the pass itself, from the plan (Q19, T008):

- **The copy is fixed.** Every string is listed here and lives in
  `MarketCopy.swift`. If the design wants a word this list doesn't
  have, that is a spec question — flag it in the export, don't invent
  it; Claude Code escalates it, never absorbs it.
- **Values come back as tokens.** `design/tokens.md` gains a "Market
  section, candidate picker, dashboard variant (`002`)" section sourced
  from the artboards, one row per property, so read the existing
  tables there as the vocabulary to design in.

---

## The prompt

You are designing three new surfaces for **Trove**, a personal gear
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
   page, system in the bars** — nothing drawn inside a page's content
   is a system control; plain, direct voice.
2. `design/tokens.md` — the exact palette, type and spacing, and the
   tables for the two detail screens these surfaces sit on ("Item
   detail (`010` refresh)", "Wishlist detail (`010` refresh)"), the
   row treatment, and the shared dropdown surface. Design in these
   values; add tokens only where a property genuinely has no existing
   one.
3. The shipped screens the surfaces join, for context:
   `design/screens/Trove Item Detail.png`,
   `design/screens/Trove Wishlist Detail.png`,
   `design/screens/Trove Dashboard.png`, and the `010` refresh sources
   `design/elements/010-item-management/Trove Item Detail.dc.html` and
   `Trove Wishlist Detail.dc.html`. Note the wishlist detail's dashed
   "market-price ghost" — this pass **replaces it** with the real
   section.

### The feature, in one paragraph

An item can be matched, once, by the person, to a product in Reverb's
catalog (Reverb is a used-gear marketplace). Refreshing — on demand
only — fetches that product's current listings and shows the **median
asking price** for listings in the item's condition, with the
low–high spread, how many listings counted, and how old the figure is.
This figure sits **beside** the person's own value and never replaces
it; one tap can adopt it. It is an *asking price on Reverb* — the words
"value", "worth" and "price" (except in "asking price") are forbidden
for it, everywhere; the copy below is written to that rule. A small
trend arrow on list rows and a "Market" sort already exist in the
design language and are not part of this pass.

### Palette and type, restated

Colors: `background #17181A`, `surface #201F1D`, `surfaceInset #26272A`,
`divider #3A3B3E`; ivory text `#F2EDE4` at 100 / 75 / 60 / 55 / 45 /
40 / 35 / 30 % (`textPrimary`, `textBody`, `textLabel`,
`textLabelSecondary`, `textMonoMeta`, `textQuiet`, `textDisabled`,
`textInactive`); `accentBrass #C79A56` (money, CTAs), `accentBrassTint
rgba(199,154,86,0.12)`, `accentBrassDim #746140`; `accentMoss #52634F`
shapes / `accentMossText #7E9679` text; `accentRust #9C4A34` shapes /
`accentRustText #B8674F` text. Rust and moss as *text* must use the
`Text` lifts — the base values fail contrast on `surface`.

Type: Archivo 600 for display and hero figures; IBM Plex Sans 400/500/
600 for body; IBM Plex Mono 400/500 for money, dates, counts and every
all-caps label (tracked 0.06–0.16em). Money is whole currency,
`$1,450`, tabular numerals, mono unless it is a hero figure.

Cards: `surface`, `3px` radius, the plate shadow set (`inset 0 1px 0
rgba(242,237,228,0.055)`, `inset 0 -1px 0 rgba(0,0,0,0.4)`, `0 2px 6px
rgba(0,0,0,0.25)`); any rectangle whose background differs from the
screen's gets it. Outlined, unfilled surfaces (`1px` border, `3px`
radius) are the exception for calls-to-action and callouts. Screen
gutter `24px`; detail-screen section gap `24px` (item) / `28px`
(wishlist); section headers are `monoLabel` (IBM Plex Mono `10.5px`,
tracked) — every all-caps header in the app is mono.

Buttons in the page are Trove's own: a filled brass primary, an
outlined brass secondary, rust for destructive. Text buttons are fine
where the `010` screens use them.

---

## Surface 1 — the Market section (both detail screens)

One component, rendered on the item detail (after the DETAILS section,
before NOTES) and on the wishlist detail (where the market-price ghost
is today). Design it once and show it on both screens. It has **five
states** plus an overlay; every one must be drawn.

Section header: **Market** (a `monoLabel` like DETAILS and NOTES).

| State | What it shows, top to bottom |
|---|---|
| **Unmatched** | The header and one action, **Find on Reverb…** — nothing else. Quiet: this is most items, most of the time. |
| **Matched, never refreshed here** | Source line `On Reverb · Fender American Professional II Telecaster` (with a year when the item has one: `On Reverb · Martin D-18 · 1975`); the line `Not refreshed on this device.`; the link **View on Reverb**; actions **Refresh** · **Change match…** · **Remove match**. |
| **Matched, current** | Source line; the figure as three elements — `$1,450` · `12 listed` — the median is the section's main figure; the spread `$1,100–$2,000` (an en dash); the age `as of 2 hours ago` (also `as of 3 days ago`); **View on Reverb**; **Refresh** (disabled for an hour after a refresh — show the disabled look; and a refreshing look with a small spinner); **Use as my value** (item) / **Use as estimated cost** (wishlist); then **Change match…** · **Remove match**. |
| **Matched, withheld** | Source line; `Too few listings in this condition to say. The lowest used asking price on Reverb is $1,100.` (wishlist: `Too few used listings to say. …`; when Reverb has no lowest price the first sentence stands alone); the age; the link; Refresh; Change match · Remove match. **No adopt action, no figure.** |
| **Matched, stale** (older than thirty days) | Source line; `A refresh is due.` with `as of 34 days ago`; the link; Refresh; Change match · Remove match. No figure, no adopt. |
| **Narrowed to all years** (a variant of *current*) | The line `Too few 1975 listings in this condition — all years shown.` (wishlist: `Too few 1975 used listings — all years shown.`) sits above the figure, which is then the all-years figure; everything else as *current*. |
| **Failure overlay** (any matched state) | One quiet rust line above the actions, the reading beneath unchanged: `Couldn't reach Reverb. The figure below is from 2 hours ago.` — or, with no figure, `Couldn't reach Reverb.` — or `Reverb is asking us to slow down. Try again in a while.` — or `This product is no longer on Reverb. Change the match to keep refreshing.` Nothing is cleared by a failure. |

Design intent to hold:

- **The person's value stays the hero.** On the item detail the WORTH
  NOW / PAID stat pair above is the screen's headline; this section
  reads as a *reference figure beside it*, not a rival. The median
  should be clearly legible and clearly secondary to the hero — think
  the PAID cell's weight (IBM Plex Mono 500 `19px`) rather than the
  WORTH NOW cell's Archivo `25px` brass. On the wishlist detail the
  ESTIMATED COST card (Archivo `34px`) is the hero; same relationship.
- **Three elements, one line.** `$1,450` · `12 listed` are two facts
  with a separator; the spread and the age are meta lines beneath in
  the `textMonoMeta`/`textQuiet` registers.
- **The link leaves the app.** `View on Reverb` opens reverb.com in the
  browser — the app's first external link. Mark it as one (an outward
  glyph is fine; SF `arrow.up.right` is the app's convention for
  "leaves") in brass, and keep it visually distinct from the buttons
  that act in place.
- **Actions are single taps.** Remove match has no confirmation. Remove
  match is the one rust text button; Change match… and Refresh are
  brass; the adopt action is the section's primary control when it
  exists — it is the only thing here that changes the person's data.
- **Disabled Refresh must not read as broken**: the age line beside it
  says why.
- The section is one card or one unbroken block — your call — but it
  must sit comfortably in the existing rhythm of DETAILS rows above and
  NOTES prose below.

Sample data to draw with: Fender American Professional II Telecaster
(median `$1,450`, spread `$1,100–$2,000`, 12 listed); Martin D-18 1975
(withheld, lowest used `$2,850`); a wishlist Strymon Timeline
(`$349`, `$299–$429`, 31 listed).

## Surface 2 — the candidate picker (a sheet)

Opened by **Find on Reverb…** and by **Change match…**. It is one sheet
with two phases; draw both, on the item detail as the backdrop.

**Phase A — the one-time notice** (shown only the first time on a
device, before any search):

> Finding a match sends this item's name to Reverb — nothing else about
> it. Refreshing later sends only which product it is — your item's
> details stay on this device. See the privacy policy.

"See the privacy policy" is a link. Two buttons: **Continue** (filled
brass) and **Not now** (outlined). Swiping the sheet down is Not now.
This is a short, calm sheet — a medium detent — not a modal wall.

**Phase B — the picker**: title **Find on Reverb**; a **Cancel** action
in the sheet's bar; a search field (placeholder **Search Reverb**) seeded
with the item's name, searching on submit only; a status line
`Searching Reverb…` while it runs. Results are **candidate cards**, a
designed choice rather than table rows:

- a square thumbnail from Reverb (draw a real-looking product photo in
  a fixed square, `2px` radius; the placeholder pattern is
  `RowThumbnail`'s from the lists);
- the **whole product title, never truncated** — Reverb's variants
  differ by a suffix, so the design must let titles wrap: "Fender
  American Professional II Telecaster", "Fender American Professional
  II Telecaster Left-Handed", "Fender American Vintage II 1961
  Stratocaster", "Martin D-18 1970 - 1984";
- the brand as a quiet line (`Fender`);
- the reading `Lowest used asking price $1,100 · 34 listed`, or `No
  used listings`;
- a per-card **View on Reverb** link — a small outward link that opens
  the product page without picking it. The card itself picks (one tap
  → the sheet closes → the section shows the match). Make the two
  targets unmistakably separate.

Also draw: the empty result — `No matches for “Fender AV II ’61
Stratocaster” on Reverb` with the detail `Try a shorter name — the
brand and model are enough.` (Trove's `EmptyStateView` pattern — a
statement and a hint, no apology); and a failed search with
`Couldn't reach Reverb.` or `Reverb is asking us to slow down. Try
again in a while.` and a **Try again** action. Show four to five
candidates in the results state, in a scrolling list, so the exact
variant is visibly findable.

## Surface 3 — the dashboard's market variant

The dashboard's headline today is the person's total current value,
with SPENT and GAIN as plated figures and the un-valued callout below
(see the PNG). The market variant adds **one line**, shown only when at
least one owned item has a current figure:

> Market · $18,400 · 12 of 34 items

Its rule (spec P5, Decision 22): the **coverage qualifier is mandatory
and inseparable from the number** — "12 of 34 items" can never be
cropped, hidden or moved away from `$18,400`. Propose the form: a
second line under the current-value figure, or a toggle that swaps the
headline between the person's value and the market figure. Draw your
recommended form and, if you think the toggle earns it, the alternative
too, with a sentence on why. The market figure must never read as the
total — brass is the person's money color; consider what register the
market line takes so the two are not confusable at a glance. SPENT,
GAIN and the category breakdown stay on the person's values and do not
change.

## Not in this pass

The list rows' trend arrow (a `9pt` triangle, moss up / rust down,
already specified); the Market ↓ / Market ↑ sort rows (they join the
existing dropdown as two rows); the **Year** field on the forms (the
forms' existing field style); the Settings row **Refresh market values**
with its `3 of 12` progress and the About lines (existing Settings
components). Don't draw these.

## Deliverables

- One `.dc.html` per surface (or one canvas holding all three), with
  every state above on its own artboard, at iPhone width, dark.
- A PNG per artboard.
- Any property this brief leaves open, stated as a value (size, weight,
  color token, spacing) so it can be written straight into
  `design/tokens.md`.
- Any copy you wanted and didn't have, listed separately — it goes to
  the spec, not into the artboards.

# `006` Mark as sold — Design pass notes

The results of the `/design` pass for `brief.md` in this folder. Twelve
`.dc.html` artboards and a PNG per artboard sit beside this file;
`canvas.json` lays them out. The values below are written so they can be
lifted straight into `design/tokens.md`'s "Mark as sold (`006`)" section.

## Decision 10 — the outcome's form

**Words, then the amount, then what it's measured against.** Rows and the
page use the same strings. The page just sets them larger.

| Case | Row and page string | Colour |
|---|---|---|
| Gain | `Gain $350 vs paid` | `accentMossText` |
| Loss | `Loss $150 vs paid` | `accentRustText` |
| At cost | `At cost` | row `textLabelSecondary`, page `textBody` |

- The first word says gain or loss. The colour only repeats it.
- "vs paid" is the app's existing phrase. It names the basis, which matters
  on a page where WORTH NOW sits just below.
- "At cost" drops "Sold" because the row's date line and the page's tag
  already say it.
- `SaleCopy.rowOutcome` and `pageOutcome` become one form. `atCost` becomes
  "At cost".
- The totals (the Dashboard card, the Sold side summary) keep the spec's
  signed "+$200 vs paid" form.

## Values

| Property | Value |
|---|---|
| **Switch** | |
| Shape | Sort By badge family: `1px accentBrass` border, `3px` radius, `32` tall (the badges' height) |
| Halves | two, `62` wide each, no seam, IBM Plex Mono `11`, centred |
| Active half | `accentBrass` fill, `background` ink, weight 500 |
| Inactive half | no fill, `accentBrass` text, weight 400 |
| Placement | its own row under the title block, left-aligned; `controlRowGap` (16) below the meta line; `sectionGap` (24) above the search field on Owned; 15 above the first row on Sold |
| Header on Sold | Sort By and search hidden, "…" stays; the meta line is the sold summary, realised part in moss/rust |
| Motion | the fill slides to the tapped half, `.snappy(duration: 0.25)`, rows cross-fade; fade only under Reduce Motion |
| **Sold row** | |
| Shape | the Owned row (`List` chrome, plate, `52` thumbnail, `13` padding and gap) with no dial and no trend arrow |
| Lines | name `rowTitle`; date `monoLabel` "SOLD SEP 12, 2026"; value line `monoValue` price + outcome `monoMeta`, `8` apart |
| Stock photo | the `005` corner mark kept |
| **Sold side empty** | `EmptyStateView`, no action; mark SF `tag` (proposed, replaces `TabItems`) |
| **Dashboard Sold card** | |
| Chrome | plated (`extrudedPlate`), `cardPadding` 16 |
| Header | `monoLabel` "SOLD" in `textLabel` |
| Figures | IBM Plex Mono 15: count in `textBody` 400, proceeds lifted to 500 `textPrimary` (the market line's lift); `6` under the header |
| Realised line | `monoMeta` 11.5, moss/rust by sign; `4` under the figures |
| Tap cue | `arrow.right`, 11pt medium, `accentBrass`, trailing, vertically centred; the whole card is the button |
| **Sold mark (detail)** | |
| Position | first in the scroll content, above the photo hero; `sectionGap` 24 to the hero |
| Tag | "SOLD", `monoLabel` type, `textPrimary` fill, `background` ink, padding `3 6 3 7`, `2px` radius (`thumbnailRadius`) |
| Outcome | on the tag's line, `10` after it; IBM Plex Mono 500 15 (`monoValue`), moss/rust/`textBody` |
| Sale line | `8` below; `monoMeta` in `textBody`, the price lifted to 500 `textPrimary` |
| Chrome | unplated |
| Read-only page | desire card without "TAP OR DRAG" and without the level hint; no Market section; no Find a photo… |
| **Sell Plan** | |
| Figures | three cells when `hasSales`: Selected · Sold · Estimated cost; cells hug their content, `space-between` around the `1px` dividers with `6` minimum either side; plate padding `12` all round in this mode (16 → 12 horizontally); figures `lineLimit(1)` + `minimumScaleFactor(0.6)` |
| Figure sizes (three) | all `heroFigureSecondary` (Archivo 26); Selected drops from 34 |
| Sold figure | `textPrimary`; caption `monoLabel` `textQuiet` "2 ITEMS" |
| Row control | footer strip inside the candidate card: `1px surfaceInset` top hairline, `40` tall (`44` hit), `cardPadding` sides, "Mark as sold…" `buttonCompact` (Plex Sans 500 13) `accentBrass`, right-aligned; the body above stays the toggle |
| Sold section | unplated, after the candidates, `sectionGap` above; `monoLabel` "SOLD", `10` gap; rows `12 / 0` padding, `1px surfaceInset` bottom; name `body` 13 `textPrimary` (truncates), date `monoMeta` `textMonoMeta`, price IBM Plex Mono 500 13 `textPrimary`, `12` gaps |
| **Sale sheet** | |
| Size | `.medium` detent (content ≈ 340pt); `.large` when the keyboard rises |
| Bar | system: Cancel `textBody`, title, confirm `accentBrass` semibold; no bottom save bar |
| Fields | Sale price + Sold on paired (`listRowGap` 10), then Sold at, then Note; `sectionGap` 24 between; the item form's field chrome |
| Invalid | `1px accentRust` border on the blank price, no message |

No new colour. The one new token candidate is none: every value above maps
to an existing token, with the tag's `2px` radius reusing `thumbnailRadius`.

## Where the drawings differ from the brief

- **Example figures.** One consistent set runs through the canvas: three
  sales total $2,400 and **+$200**. So the summary and the Dashboard card read
  +$200, not the brief's +$350.
- **The summary line's place.** It stays in the title's meta slot (the
  plan's `soldSummaryLine`), not under the switch.
- **Sell Plan's Selected figure** drops from Archivo 34 to 26 in the
  three-figure layout. At 34 the three cells don't fit.
- **The desire card on a sold page** drops its level hint as well as "TAP OR
  DRAG". The hints talk about sell candidacy, which no longer applies.

## Copy wanted, not in `SaleCopy` (for the spec, not final)

1. **The Sold side's meta line with nothing sold.** Drawn as "0 SOLD · $0",
   with the realised part dropped. `soldSideSummary` today would give
   "0 sold · $0 · +$0 vs paid".
2. **"Sold" twice on the page.** The fixed sale line starts with "Sold",
   under a SOLD tag. On the page it could read "Sep 12, 2026 · $1,200 · eBay".
3. **The sale's Note has no home on the sold page.** The sheet collects it,
   but the mark shows only the sale line and the outcome. It could be a quiet
   line under the sale line, or a DETAILS row.
4. **The Note field's placeholder.** It has none, so a blank Note field reads
   empty.
5. **A word beside the Dashboard card's arrow.** The un-valued callout has
   "Value →". The card has only the arrow.
6. **The desire card's hint in the sold state.** Omitted here. The person may
   want a sold-specific line instead.

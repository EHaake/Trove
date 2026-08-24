# Trove — Design Tokens

Source of truth for colors, type, and spacing, pulled from Claude
Design's final build (project archive export, confirmed against the
brief). Implement as the `Theme`/semantic-color abstraction described in
plan.md's "Future: theming" section — every value below should be a named
property on that type, never a hardcoded literal in a view.

Two values from Design's output are deliberately omitted here: the
`#101113` outer backdrop and the `44px` "device" corner radius are
artifacts of Design's own canvas (it mocks up a phone frame around each
screen) — not part of the app itself.

## Colors

| Token | Value | Notes |
|---|---|---|
| `background` | `#17181A` | app background |
| `surface` | `#201F1D` | cards, list rows |
| `surfaceInset` | `#26272A` | inset hairline (Design's addition beyond the original brief) |
| `divider` | `#3A3B3E` | hairlines, borders |
| `textPrimary` | `#F2EDE4` | full opacity — headlines, primary values |
| `textBody` | `#F2EDE4` @ 75% | body text |
| `textLabel` | `#F2EDE4` @ 60% | primary field/row labels |
| `textLabelSecondary` | `#F2EDE4` @ 55% | secondary labels — close to `textLabel`; keep as a separate token in case they diverge visually once real content is in place |
| `textMonoMeta` | `#F2EDE4` @ 45% | secondary mono text (e.g. serial numbers) |
| `textQuiet` | `#F2EDE4` @ 40% | de-emphasized text |
| `textDisabled` | `#F2EDE4` @ 35% | disabled controls |
| `textInactive` | `#F2EDE4` @ 30% | inactive/placeholder |
| `accentBrass` | `#C79A56` | primary accent |
| `accentBrassHover` | `#DDB877` | pressed/hover state |
| `accentBrassTint` | `rgba(199,154,86,0.12)` | background tint (e.g. selected-row fill) |
| `accentMoss` | `#52634F` | secondary accent — strokes/borders/fills only |
| `accentMossText` | `#7E9679` | moss as *text* — the spec value fails contrast on `surface`, this lift value is text-safe |
| `accentRust` | `#9C4A34` | sell-candidate/low-desire accent — strokes/borders/fills only |
| `accentRustText` | `#B8674F` | rust as *text* — same contrast reasoning as `accentMossText` |
| `dialMidpoint` | `#8F8C38` | desire dial's middle-of-range color (between rust and moss) |
| `accentBrassDim` | `#746140` | held-back brass for repeated marks — the dashboard ruler's minor ticks |
| `accentBrassMid` | `#A07E48` | perceptual half-mix of `accentBrassDim` and `accentBrass` — the `DesireGauge` ramp's middle segment. Already in the shipped build (the Oklab-searched value `T036c` describes) but never actually named here until `010`'s Design pass surfaced the gap. |
| `categoryNeutral` | `#6B6C6F` | dashboard breakdown's "everything else" swatch, past the three accents |

The rust/moss "text-safe lift" pair is a real accessibility catch, not a
stylistic choice — worth preserving exactly, not simplifying to one
color per accent. Implement as two properties per accent (e.g.
`accentRust` for shapes, `accentRustText` for any place that color
renders as text) so it's not accidentally used the wrong way in a given
context. Measured on `surface`: `accentRust` 2.7:1 and `accentMoss`
2.6:1 both fail, while the lifts reach 4.0:1 and 5.1:1.
`DesireDialColorTests` computes these rather than trusting the names.

### The desire dial's ramp

The dial runs `accentRust` (1, "ready to sell") → `dialMidpoint` (3) →
`accentMoss` (5, "absolutely keeping it"), with 2 and 4 as perceptual
midpoints of the neighbouring pair. Brass held the "keep" end originally
and no longer appears on the dial at all — it's the app's money colour,
and spending it on a rating diluted that.

`dialMidpoint` was retuned twice as that change settled, both times by
searching an Oklab model of the ramp rather than picking a hex by eye.
The model reproduces SwiftUI's `.perceptual` mix exactly — it predicted
the rendered arc colours to the byte, checked against simulator pixels.

- `#A87C4A` was the midpoint of the old rust→brass ramp. Against moss it
  left stops 1–4 all in orange and put the whole hue change into one 68°
  jump between 4 and 5.
- `#75774A` fixed the cliff but sat too dark and grey (sat 0.38, val
  0.47) to read as anything but green's neighbour — 3, 4 and 5 bunched
  up. Measured in Oklab ΔE, adjacent stops were 0.062 / 0.063 / **0.043**
  / 0.042 apart: the top half of the scale separated barely two-thirds as
  well as the bottom.
- `#8F8C38` is a yellow-gold (sat 0.61, val 0.56). Adjacent stops now
  measure 0.088 / 0.086 / 0.084 / 0.082 — even, and roughly double the
  tightest gap before.

One constraint worth keeping if it's ever retuned again: pushing the
midpoint yellow walks it toward `accentBrass`, which is also a yellow.
A candidate measured 0.058 from brass while its own stops were 0.12
apart — a "3" that read as a price. The rule the search enforces, and
`DesireDialColorTests` checks, is that no stop may sit closer to the
money colour than to its own neighbours on the dial.

### The desire gauge's stepped ramp (`010`)

Redesigned in `010` to close the legibility gap flagged at `001`'s
sign-off — see `design/elements/010-item-management/` for the source.
Same underlying shape as before (three sheared segments, `skewX(-12deg)`
consistently), extended with two things: an ascending height per
segment, and a per-row legend.

| Property | Value |
|---|---|
| Segment width | `12px`, all three |
| Segment heights | `8px` / `11px` / `14px`, ascending |
| Gap between segments | `4px` |
| Shear | `skewX(-12deg)` |
| Unfilled segment | `1px solid rgba(242,237,228,0.16)`, `box-sizing: border-box` |
| Fill ramp | `accentBrassDim` (1) → `accentBrassMid` (2) → `accentBrass` (3) |
| Legend text | "DESIRE" — IBM Plex Mono, `8.5px`, letter-spacing `0.12em`, `rgba(242,237,228,0.35)`, line-height `1.7` |
| Legend position | left of the segments, `7px` gap |
| Total row-width cost | ~`42px` |

The ascending height is doing real work, not just decoration — it
carries the ramp's direction even where the brass-tone color
progression alone might not (someone with limited color perception, or
just glancing quickly). The legend is per-row and always visible,
which is a deliberate reversal of `001`'s "unlabeled in list rows"
decision — see `plan.md`'s Resolved decisions for the reasoning and the
explicitly provisional framing.

### Row treatment — "extruded plate" (`010`)

Added in `010`, amending `brief.md`'s skeuomorphism section rather than
quietly contradicting it — see `brief.md`'s own updated note and
`plan.md`'s Resolved decisions for the full reasoning. Replaces the
flat `surface` rectangle with a bordered plate that reads as having a
little more depth, built entirely from black/ivory alphas layered over
the existing `surface` color — no new hardcoded colors, which is part
of what keeps it a subtle depth cue rather than a rendered material.

| Property | Value |
|---|---|
| Background | `surface` (`#201F1D`), unchanged |
| Corner radius | `3px`, unchanged from the existing card radius |
| Border | none — removed; the shadow/bevel below does the separating |
| Box-shadow | `inset 0 1px 0 rgba(242,237,228,0.055)` (top highlight) + `inset 0 -1px 0 rgba(0,0,0,0.4)` (bottom shadow) + `0 2px 6px rgba(0,0,0,0.5)` (cast shadow) |
| Row internal padding | `13px` |
| Row internal gap | `13px` (thumbnail to text) |
| Thumbnail | `52px × 52px`, `2px` radius, existing placeholder pattern unchanged |

Applies uniformly on both `ItemListView` and `WishlistView`, resting or
swiped open — the swipe-reveal mockup showed a plain-bordered row, but
that was illustrating the gesture, not the final row chrome (see
`plan.md`).

### Sort picker (`010`)

Same component now used on both `ItemListView` and `WishlistView`,
extended to hold four options each rather than redesigned — a compact
badge showing the current selection, opening a dropdown on tap. Its
footprint doesn't grow with option count, which is what resolved the
earlier open question about whether four options would crowd either
header.

| Property | Value |
|---|---|
| Badge border | `1px solid accentBrass` (`#C79A56`), `3px` radius |
| Badge padding | `8px 12px` |
| Badge text | IBM Plex Mono, `11px`, `accentBrass` |
| Badge sort-icon | three horizontal bars, widths `10px`/`7px`/`4px`, `1.5px` tall, `2.5px` gap, `currentColor` |
| Dropdown width | `232px` |
| Dropdown background/border | `surface` (`#201F1D`) / `1px solid divider` (`#3A3B3E`), `3px` radius |
| "SORT BY" header | padding `11px 14px 9px`, IBM Plex Mono `10px`, letter-spacing `0.16em`, `textQuiet` |
| Row padding | `12px 14px`, `1px solid surfaceInset` top border between rows |
| Selected row | text `accentBrass`, `13.5px`, background `accentBrassTint` |
| Selected row, "Custom" specifically | adds a "REORDER" label (IBM Plex Mono `9.5px`, letter-spacing `0.12em`, `textQuiet`) and a `12×12` brass checkmark, `1.6px` stroke — the other three options show no such label |
| Unselected row | text `textBody` (`rgba(242,237,228,0.75)`), `13.5px` |

The "REORDER" label appearing only on the "Custom" row (not on every
row's selected state generically) is what replaces the old standalone
button — see `plan.md`'s Resolved decisions.

### Swipe-action rows (specific)

| Token | Value |
|---|---|
| Leading action button width | `76px` each (Edit, Duplicate) |
| Trailing delete button width | `88px` |
| Action row height | `78px` (matches full row height) |
| Edit background | `divider` (`#3A3B3E`) |
| Duplicate background | `surfaceInset` (`#26272A`) |
| Delete background | `accentRust` (`#9C4A34`) |
| Icon box | `20px`, `1.5px` stroke — matches the tab-bar icon convention |

Leading actions deliberately use neutral tones (`divider`, `surfaceInset`)
rather than accent colors, so rust stays the only consequential color on
a swiped-open row — nothing competes with Delete for attention.

## Typography

- **Display**: Archivo, weight 600. Screen titles, hero figures (the
  dashboard's total value, an item's price), dial numerals.
- **Body**: IBM Plex Sans, weights 400/500/600.
- **Utility/mono**: IBM Plex Mono, weights 400/500. Money, serial
  numbers, dates, and all-caps labels (tracking 0.06–0.16em).

Both are open-source (SIL Open Font License) — safe to embed directly in
the app bundle, no licensing step needed.

### Sizes

| Role | Size (pt) |
|---|---|
| Screen title | 30 |
| Hero figure | 26–34 (larger for the dashboard's primary total, smaller for secondary figures — exact mapping to be decided per-screen when building) |
| Form input | 19 |
| Row title | 14.5–15 |
| Body | 13–13.5 |
| Secondary | 11–12.5 |
| Mono label | 10–11 |

## Spacing

4px base grid.

| Token | Value |
|---|---|
| Screen gutter | 24 |
| Card padding | 14–18 |
| Section gap | 22–28 |
| List row gap | 10 |
| Field gap | 8 |

### Sell Plan candidate rows (specific)

| Token | Value |
|---|---|
| Row padding | 15 (vertical) / 14 (horizontal) |
| Internal gap | 12 |
| Min row height | 66 |
| Price column min width | 92 |
| Reserved trend-indicator slot | 12×14 |

That reserved slot is the future-proofing space asked for in the design
brief — confirms it made it into the actual build.

## Corner radii

| Element | Radius |
|---|---|
| Cards, buttons | 3 |
| Thumbnails | 2 |
| Chips | 999 (fully rounded) |

## Implementation note

Several sizes above are ranges rather than single values (hero figure,
row title, body, secondary, mono label) — this reads as Design using a
fluid/context-sensitive scale rather than fixed steps. When building each
screen, pick the specific value that matches what's on that screen in
Design's build rather than guessing from the range; where it's ambiguous,
default to the smaller end of the range and adjust once it's running in
the simulator next to the mock.

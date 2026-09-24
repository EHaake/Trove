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

### The light palette (spec `004`)

`ThemeColors.light` carries every token `.dark` does, derived for a
near-white ground while keeping the brass/moss/rust identity. Derived by
the same Oklab method the dark ramp was — no value picked by eye; the
person attested the whole palette visually at `004`'s device pass (T006,
2026-09-09 — criteria 1–4 and 8's visual halves signed off, every screen
walked in Light). The `Light` column below is the recorded derivation,
written **before** the pin test (`LightThemeColorTokenTests`), so the
pins are a genuine second transcription of these values, not a copy of
the source; these are the **shipped** values, finalised at close-out.

| Token | Light | Notes |
|---|---|---|
| `background` | `#ECE7DC` | app background — a warm light grey |
| `surface` | `#F7F2E9` | cards, list rows — near-white, one step lighter than `background` (cards read raised, mirroring the dark relationship) |
| `surfaceInset` | `#EDE7DA` | inset hairline — a touch darker than `surface`, recessed (the read flips from dark, where inset is lighter) |
| `divider` | `#D5CDBB` | hairlines, borders — visible on the light ground |
| `textPrimary` | `#23201B` | full opacity — a warm near-black ink; every text token is a percentage of it, the dark palette's structure with the ink inverted |
| `textBody` | `#23201B` @ 75% | body text |
| `textLabel` | `#23201B` @ 60% | primary field/row labels |
| `textLabelSecondary` | `#23201B` @ 55% | secondary labels |
| `textMonoMeta` | `#23201B` @ 45% | secondary mono text |
| `textQuiet` | `#23201B` @ 40% | de-emphasized text |
| `textDisabled` | `#23201B` @ 35% | disabled controls |
| `textInactive` | `#23201B` @ 30% | inactive/placeholder |
| `accentBrass` | `#804A00` | primary accent — a deep bronze-gold. On the near-white ground the money figure has to stay legible (6.5:1 on `surface`), which pulls brass dark; keeping it a light gold like the dark palette's would drop it near 2:1. The direction flips from dark, where brass is the lightest accent — here it is one of the darkest — but the hobby's warm-gold identity holds |
| `accentBrassHover` | `#9C5D0E` | pressed/hover — a lighter, brighter brass, the same "brightens on press" relationship dark uses |
| `accentBrassDim` | `#C6A97C` | held-back brass for repeated marks (ruler minor ticks) — a light tan, less prominent against the light ground |
| `accentBrassMid` | `#A37946` | perceptual (Oklab) half-mix of `accentBrassDim` and `accentBrass`, the `DesireGauge` ramp's middle segment — same construction as dark |
| `accentBrassTint` | `rgba(128,74,0,0.12)` | background tint (selected-row fill) — `accentBrass` at 12% |
| `accentMoss` | `#889979` | secondary accent — strokes/borders/fills only. A mid sage; it must stay *below* 3:1 as text on the light `surface` (2.7:1) so the text-safe lift stays non-vacuous, the same split the dark palette draws |
| `accentMossText` | `#3E5137` | moss as *text* — a dark green. On a light ground the lift **darkens** moss to clear contrast, the opposite direction to dark, where it lightens it |
| `accentRust` | `#D47D5B` | sell-candidate/low-desire accent — strokes/borders/fills only. A light terracotta, below 3:1 as text (2.7:1) for the same reason as `accentMoss` |
| `accentRustText` | `#8E3A24` | rust as *text* — a dark rust; the lift darkens on the light ground |
| `dialMidpoint` | `#446A22` | desire dial's middle-of-range colour. A dark olive-green rather than the dark palette's yellow-gold: it doubles as the numeral at level 3, so it must clear 3:1 as text (dark), and a dark *gold* midpoint would collide with the deep-bronze `accentBrass` on the dial. Pushing it green separates it from brass by hue while its neighbours stay distinct |
| `categoryNeutral` | `#7C7D80` | dashboard breakdown's "everything else" swatch — a mid grey visible on the light ground |
| `plateHighlight` | `rgba(255,255,255,0.70)` | extruded-plate top edge that catches the light — pure white at 70% over the near-white `surface`; the read flips from dark's ivory alpha. Confirmed at the T006 device pass |
| `plateEdgeShadow` | `rgba(0,0,0,0.12)` | plate bottom inner edge — black, softened from dark's 0.40 because the light surface needs a subtler bevel. Confirmed at the T006 device pass |
| `plateCastShadow` | `rgba(0,0,0,0.10)` | soft cast shadow on the background. Confirmed at the T006 device pass |
| `gaugeTrack` | `rgba(35,32,27,0.16)` | unfilled `DesireGauge` segment hairline — the dark ink at 16% over the light `surface`, the alpha's read flipped from dark's ivory |

Re-earned on the light ground the same way the dark ramp was
(`LightDesireDialColorTests`, `LightPaletteContrastTests`,
`LightDesireGaugeColorTests`, `LightTrendArrowRenderTests` — added
beside the dark suites rather than folded in, so the dark guarantees
stay pristine):

- Dial arc (`accentRust` → `dialMidpoint` → `accentMoss`, with 2 and 4
  the perceptual midpoints): adjacent stops measure Oklab ΔE ~0.128 /
  0.128 / 0.095 / 0.095 — even (ratio 1.34) and above the 0.06 floor.
- No dial stop is closer to `accentBrass` than its neighbours: the
  nearest stop sits ΔE 0.122 from brass, against the smallest 0.095
  neighbour gap — the price-figure guarantee, re-earned.
- Numeral (`accentRustText` → `dialMidpoint` → `accentMossText`): every
  level clears 3:1 on `surface` (5.6–7.7:1), while the raw shape accents
  stay below (2.7:1) — the split that keeps the lift real.
- Gauge tones (`accentBrassDim` / `accentBrassMid` / `accentBrass`)
  sampled at row size measure ΔE ~0.14 apart and each ≥0.22 from the
  light `surface` behind an empty track.

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
| Legend text | "DESIRE" — IBM Plex Mono, `8.5px`, letter-spacing `0.12em`, `rgba(242,237,228,0.35)`, line-height `1` |
| Legend position | left of the segments, `7px` gap, baseline flush with the segments' bottom edge (the source nudges `-1px`); the 2026-08-29 refresh replaced the earlier `1.7` line-height, which floated the legend off the baseline |
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
| Box-shadow | `inset 0 1px 0 rgba(242,237,228,0.055)` (top highlight) + `inset 0 -1px 0 rgba(0,0,0,0.4)` (bottom shadow) + `0 2px 6px rgba(0,0,0,0.25)` (cast shadow — softened from the mocks' `0.5` by review, 2026-08-30: the full-strength shadow read as too heavy once the treatment covered every card) |
| Row internal padding | `13px` |
| Row internal gap | `13px` (thumbnail to text) |
| Thumbnail | `52px × 52px`, `2px` radius, existing placeholder pattern unchanged |
| Dial-bearing cards | pad symmetrically, but trim the dial: `DesireDial`'s sweep stops at 4-and-8 o'clock, so a quarter of its square is blank below and its knob overhangs the top. `emptyBottomInset` / `knobOverhang` give those back, and only then does equal padding *look* equal (measured 15.0/16.3pt on the form, 22.0/21.7pt on the detail — it was 11.7/21.0 before) |

**Applies to every card in the app, not just list rows** — settled at the
2026-08-30 review, where the rule was stated plainly: *any rectangle whose
background differs from the screen's gets the plate.* That covers list rows
(resting or swiped open — the swipe-reveal mockup's plain border was
illustrating the gesture, not final chrome), the detail screens' cards, the
dashboard's Spent/Gain figures, the search field, photo heroes, the sell
plan's cards, both dropdowns, and every form field on both forms. A new
card gets it by default; *not* having it is what needs a reason.

Four surfaces are deliberately outside the rule, all because they have no
fill to plate: capsule chips (category, condition, cost presets) are
outlined pills; the dashboard's un-valued callout is unfilled by design —
the mock distinguishes it from the figures card above by outlining it
rather than raising it; and the wishlist detail's sell-plan CTA (and, until `002`
replaced it, its market-price ghost) are outlined, unfilled surfaces for the same reason (added
to this list at the T039 review — the rule as first written didn't cover
them, and a literal reading would have plated both).

On form fields the border changes job rather than disappearing: the plate's
bevel does the separating, so a border now draws **only** for state — rust
when a field is invalid, and brass when the category field is focused —
never as resting chrome.

### Sort picker (`010`) — and the shared dropdown surface (`013` Amendment A)

Same component now used on both `ItemListView` and `WishlistView`,
extended to hold four options each rather than redesigned — a compact
badge showing the current selection, opening a dropdown on tap. Its
footprint doesn't grow with option count, which is what resolved the
earlier open question about whether four options would crowd either
header.

Since `013` Amendment A the dropdown is the **shared surface every
in-page menu opens** — `DropdownSurface` and `DropdownRow` in code: the
lists' and the Dashboard's "…" and the Dashboard's category-order
control draw on it too, differing only in their rows and in whether
they carry a header. Sort By's rows are the selected/REORDER shape
below; the additions the other menus need — a group break, a disabled
row, the placement — follow the table.

| Property | Value |
|---|---|
| Badge border | `1px solid accentBrass` (`#C79A56`), `3px` radius |
| Badge padding | `8px 12px` |
| Badge text | IBM Plex Mono, `11px`, `accentBrass` |
| Badge sort-icon | three horizontal bars, widths `10px`/`7px`/`4px`, `1.5px` tall, `2.5px` gap, `currentColor` |
| Dropdown width | `232px` |
| Dropdown background/border | `surface` (`#201F1D`) / `1px solid divider` (`#3A3B3E`), `3px` radius |
| Header row — "SORT BY" here, "ORDER BY" on the Dashboard's order dropdown, none on the "…" menus | padding `11px 14px 9px`, IBM Plex Mono `10px`, letter-spacing `0.16em`, `textQuiet` |
| Row padding | `12px 14px`, `1px solid surfaceInset` top border between rows |
| Selected row | text `accentBrass`, `13.5px`, background `accentBrassTint` |
| Selected row, "Custom" specifically | adds a "REORDER" label (IBM Plex Mono `9.5px`, letter-spacing `0.12em`, `textQuiet`) and a `12×12` brass checkmark, `1.6px` stroke — the other three options show no such label |
| Unselected row | text `textBody` (`rgba(242,237,228,0.75)`), `13.5px` |
| Group break (`013` A, P10) | the row's own top border drawn in `divider` (`#3A3B3E`) instead of `surfaceInset` — one hairline, three times the separator's contrast on `surface`; the "…" menus' three groups |
| Disabled row (`013` A, P11) | text `textDisabled` (`rgba(242,237,228,0.35)`) *under* the button's own disabled dimming (a further `0.5` on the alpha, composited in sRGB — measured, not designed); the compound `SettingsActionRow` ships. Inert, dimmed to VoiceOver |
| Placement (`013` A) | trailing edge at the screen gutter (`24px`), whatever badge opened it; `6px` below the badge (`dropdownGap` — what the lists' old fixed `60px` offset resolved to), or above it when it would run past the tab bar. **Animation** (`013` Decision 20): grows out of the badge — a scale from `0.92` anchored at the badge's trailing edge, with a fade — on `.snappy(duration: 0.25)` opening and `.easeOut(duration: 0.15)` closing; the fade alone under Reduce Motion |

The "REORDER" label appearing only on the "Custom" row (not on every
row's selected state generically) is what replaces the old standalone
button — see `plan.md`'s Resolved decisions.

### Export badge and menu (`011`)

The "…" overflow control, sitting right of the sort badge on both list
screens and drawn to its proportions so the pair reads as one control
family. It shows regardless of collection size since `012` (criterion
1, superseding `011`'s hide-when-empty rule): its menu carries Import
and, since `013`, Settings, both always enabled. Since `013` Amendment
A the same pill sits at the root Dashboard's top-right (P8), holding
Settings alone.

| Property | Value |
|---|---|
| Badge border | `1px solid accentBrass`, `3px` radius — the sort badge's |
| Badge padding | `8px 12px` — the sort badge's |
| Badge glyph | SF `ellipsis`, `15px` semibold, `accentBrass`, in an `18×14` frame sized against the sort badge's text row |
| Exporting state | glyph swaps to a small `ProgressView` tinted brass; whole control disabled |
| Menu | **bespoke since `013` Amendment A** — `OverflowDropdown` on the Sort picker's surface above, opened on the screen's dropdown host: five rows in three groups (the two exports, disabled when the view is empty; Import; Settings), no header row (P9), the group breaks as above. From `011` to `013` it was a system `Menu`, safe from the T029c tear because its label is a constant-size glyph; the amendment's rule — **bespoke inside the page, system in the bars** — ended that, so the two badges side by side open one visual language. `DetailOverflowMenu`, in the navigation bar, is the app's one system menu. |
| Export rows, Items list (`014` Decision 7, P12) | the two export rows no longer export: each **opens a second dropdown on the same badge**, headed "EXPORT AS CSV" / "EXPORT AS PDF", offering Owned items · Sold items · Owned and sold, each row disabled when it has no rows under the on-screen narrowing. Same surface, same plate, same anchor — the plate stays put and its rows swap (measured at `014`'s device pass: plate top fixed at 115.33 pt across every frame). Dismiss catcher "Dismiss export options". No `Menu` and no `confirmationDialog` (`013` Decision 17); the Wishlist's two rows still export directly |
| Hint | "Opens more actions" — a button with a hint; SwiftUI has no pop-up trait to give it (`013` Decision 18). The sort badge's is "Opens sort options", the Dashboard order control's "Opens order options" |
| Dashboard order control (`013` A, P12) | Design's "BY VALUE" label as drawn — `monoLabel` in `textQuiet`, no pill — opening the shared surface under an "ORDER BY" header, the current order tinted and checked, no REORDER tag |

### Print palette and type scale — PDF export (`011`)

The exported PDF is print-first: light background, dark text — a
document for paper, not a screenshot of the dark UI. These are
**print-only tokens** (`PrintPalette`/`PrintType` in `PDFComposer`);
the dark-UI palette above is for screens and the two must not be
"unified". The brass is deliberately darker than the UI's `#C79A56`,
which fails contrast on white.

| Token | Value |
|---|---|
| Paper | `#FFFFFF` |
| Ink | `#1C1A17` |
| Secondary | `#6A645C` |
| Hairline rule | `#D8D3CA`, `0.75pt` |
| Print brass | `#8F6E3E` (≥4.5:1 on paper) — cover money figures |
| Page | US Letter `612×792pt`, `54pt` margins |
| Photo box | `132×99pt`, aspect-fit, top-right of the entry |

`014` adds a **second document, "Sold Items"**, on exactly these tokens and
no new ones: TOTAL SOLD FOR in print brass (the headline slot), TOTAL PAID
and REALISED in ink, the count line "N sold", no floor note, and each entry
led by Sold · Sold for · Sold at · Outcome · Sale note above the owned grid.
The sale's sign is carried by `SaleCopy`'s words, never by colour —
`PrintPalette` has no moss or rust and gains none.

Type scale — same three faces as the app via their PostScript names
(one source, so `FontRegistrationTests` keeps covering the PDF), at a
deliberately separate print scale: wordmark Archivo 600 `26pt` (tracked
`4pt`) · cover title Archivo `20pt` · entry name Archivo `14pt` ·
eyebrows/labels IBM Plex Mono `7.5pt` tracked caps · field values IBM
Plex Sans `10.5pt` · notes IBM Plex Sans `10pt` · money/dates/serials
IBM Plex Mono `10.5pt` · cover totals IBM Plex Mono 500 `15pt` · cover floor note IBM Plex Sans `9.5pt` *(missed in the first pass; added at T019/S2)*.

### Swipe-action rows (specific)

| Token | Value |
|---|---|
| Leading action button width | `76px` each — Edit and Copy on both lists, plus a third between them on each: **Sell** on the Items list's **owned** rows since `014`, and **Buy** on the Wishlist's rows since `015` (Edit stays nearest the edge on both, so a full swipe still edits). Sold rows carry no leading swipe; a **bought** wanted entry has no row at all — it has left the Wishlist |
| Trailing delete button width | `88px` |
| Action row height | `78px` (matches full row height) |
| Edit background | `divider` (`#3A3B3E`) |
| Duplicate background | `surfaceInset` (`#26272A`) |
| Sell background (`014`) | `accentBrassMid` — the one brass that is mid-tone in *both* palettes, so the white label reads the same on either appearance (white on it measured 3.61:1 dark / 3.74:1 light at `014`'s device pass) |
| Sell glyph (`014`) | `ActionSell` — a price-tag outline in `action-edit.svg`'s house style (24 viewBox, 1.5 stroke, template, vector preserved); the "…" menu row wears SF `tag`, so the swipe wears the same sign |
| Buy background (`015`) | `accentBrassMid` — the same tint as Sell, and for the same reason: one brass that reads mid-tone in both palettes (white on it measured 3.61:1 dark / 3.74:1 light at `014`'s device pass, so `015` owed no new measurement). The two lists' middle action is the same colour because it is the same *kind* of action — a sheet follows it, and the sheet is the confirmation |
| Buy glyph (`015`) | `ActionBuy` — a bag outline in `action-sell.svg`'s house style (24 viewBox, 1.5 stroke, `#000`, template, vector preserved); the wanted page's "…" menu row wears SF `bag`, so the swipe wears the same sign. The button's visible word is **Buy** and its spoken name is **Mark as bought…**, read back from the live accessibility tree at `015`'s device pass |
| Delete background | `accentRust` (`#9C4A34`) |
| Icon box | `20px`, `1.5px` stroke — matches the tab-bar icon convention |

Leading actions deliberately avoid rust, so it stays the only
**consequential** color on a swiped-open row — nothing competes with Delete
for attention. Edit and Copy take neutral tones (`divider`, `surfaceInset`);
`014`'s Sell takes `accentBrassMid` rather than a third neutral, because
three grey buttons in a row would be one gesture with no legible middle, and
because the action is not consequential — a sheet follows it, and the sheet
is the confirmation. `015`'s Buy is the same arrangement on the
Wishlist, so both lists read as one pattern: two neutrals with one brass
between them.

The 2026-08-29 export refresh relabels this button DUPLICATE — that text
is **outdated**, confirmed at review: the on-screen string stays "Copy"
per plan.md's Resolved decisions. The export was not edited; this note
is the flag.

### Destructive actions (`009`, 2026-09-23)

Any control with `role: .destructive` is drawn in rust, wherever it appears.

| Drawn by | How it gets rust |
|---|---|
| The app: toolbar buttons, swipe actions, rows | Coloured on the control itself: `accentRust` where rust fills or tints a shape (the swipe background), `accentRustText` where rust is the word. The role alone draws **brass** here, because `ContentView`'s brass `.tint` cascades over the role's red. |
| The system: alert buttons, the detail "…" menu's Delete | The role alone. The system draws its own red, and nothing is added. |

Guarded by `DestructiveColourPolicyTests`.

### Tap targets (`009`, 2026-09-23)

A card, chip or button drawn as a box responds to a tap anywhere inside
its box. Put `.contentShape(Rectangle())` last on the label, after its
padding (or the box's own shape when its corners are large:
`Capsule()` on a chip), whether or not the box has a fill or an
outline. A clear fill can't be relied on to catch taps. An outline
happens to catch them today, but don't rely on that, because restyles
remove outlines.

Guarded by UI tests that tap the padding, away from the label: the
Sell Plan card and the Overview's not-yet-valued callout.

### Item detail (`010` refresh, 2026-08-29)

Source: `Trove Item Detail.dc.html`. Adopted selectively — the mock's
header Edit/Delete buttons (the "…" overflow stays), its schema-less
DETAILS rows (Stored, split Brand/model, Valued date), and its
aspirational dial hints are all stale artifacts, per the review
decisions in `tasks.md`'s Phase 7 header.

| Property | Value |
|---|---|
| Screen padding / section gap | `18px 24px 48px` scroll padding, `24px` between sections |
| Photo hero | `240px` tall (raised from the mock's `210` when the pager landed — the swipe target earns the height), `3px` radius, no border (the Row-treatment plate rule above governs; this table used to contradict it), empty state `108px` with a "NO PHOTOS" mono label |
| Hero caption | **removed** (T038 device review, 2026-08-30) — the dots carry the position; VoiceOver reads it from the element's accessibility value instead |
| Hero pager dots | `6px` circles, `6px` gap; active `accentBrass`, rest `textPrimary @ 45%` (the mock's `5px`/`textInactive` read too faint over photos; deviation recorded 2026-08-30) |
| Thumbnail strip | **removed from both detail screens** (T038 device review, 2026-08-30) — redundant once the pager tracked the finger and carried dots, and it only ever appeared on item detail. The form screens' `PhotoPickerField` keeps its strip (80×56 tiles), where tiles are also the remove-photo affordance |
| Add-photo tile | detail screens have none — adding photos happens in the edit form (`PhotoPickerField`); the mock drew one here but the detail screens are read-only by design |
| Title eyebrow | IBM Plex Mono `10.5px`, letter-spacing `0.12em`, `textMonoMeta` |
| Title | Archivo 600, `27px`, line-height `1.1`, letter-spacing `-0.01em`, `textPrimary` |
| Stat pair container | two cells split by a `1px` `divider` seam (divider-colored gap), `3px` radius, cast shadow `0 2px 6px rgba(0,0,0,0.25)` (softened from the mocks' `0.5` — same review note as the row treatment) |
| Stat cell | `surface` background with the extruded-plate inner bevel, padding `15px 16px`, `7px` internal gap |
| Stat label | `10px` weight 600, letter-spacing `0.14em`, `#F2EDE4 @ 50%` — "WORTH NOW" / "PAID" |
| WORTH NOW value | Archivo 600 `25px`, `accentBrass`, tabular numerals |
| PAID value | IBM Plex Mono 500 `19px`, `textPrimary`, tabular numerals |
| Delta line | IBM Plex Mono `11px`, `accentMossText` gain / `accentRustText` loss — "+$550 · +19%" |
| Desire block | extruded-plate card, padding `20px 18px`, `14px` internal gap |
| Desire block header | "DESIRE TO KEEP" `11px` 600, letter-spacing `0.16em`, `textLabelSecondary`; right-aligned "TAP OR DRAG" IBM Plex Mono `11px`, `textQuiet` |
| Dial | `132px`, the existing `DesireDial`, `20px` gap to the text column |
| Level summary | `14px` weight 500, `textPrimary` |
| Level hint | `12px`, line-height `1.45`, `textLabelSecondary` — copy from the table below |
| DETAILS section header | **Diverges deliberately:** the app's `monoLabel` (IBM Plex Mono `10.5`, tracked) rather than the mock's sans-semibold `11px`/`0.16em`. Every all-caps label on every other screen is mono; one screen breaking that reads as a mistake, not a refinement. Same call on both detail screens (`DetailSection`). |
| DETAILS row | padding `12px 0`, bottom border `1px surfaceInset`; label `12.5px` `textLabelSecondary`; value `13px` `textPrimary`, right-aligned, tabular, mono for money/serial/dates and sans otherwise |
| NOTES body | `13px`, line-height `1.6`, `textBody` |
| Sell-plan row | **Not built.** The mock's "Add to a sell plan →" has no destination: `SellPlanView` takes a `wishlistItemID`, because a plan belongs to a wishlist item and owned items are picked *into* it from there. Building the row would mean a button to nowhere, or a new item→plan picker — a feature, not a refinement. Flagged at `T037a`. |

### Wishlist detail (`010` refresh, 2026-08-29)

Source: `Trove Wishlist Detail.dc.html`. Same selective adoption; two
additional review calls: the tap-to-set desire gauge **stays** (its
absence from the mock is accidental), and the mock's "Priority" DETAILS
row is omitted as redundant with it.

| Property | Value |
|---|---|
| Screen padding / section gap | `22px 24px 40px` scroll padding, `28px` between sections |
| Title eyebrow / title | same treatment as the item detail's ("WANTED · …"), title line-height `1.12` |
| Cost card | extruded-plate card, padding `18px`, `8px` internal gap |
| Sell-plan CTA hit area | the outline leaves the interior transparent, so the button needs an explicit `contentShape` — the solid fill it replaced was doing that silently, and without it the control only responds on its glyphs (caught on device at `T037b`) |
| Cost label | "ESTIMATED COST" `10px` 600, letter-spacing `0.14em`, `#F2EDE4 @ 50%` |
| Cost value | Archivo 600 `34px`, line-height `1`, `accentBrass`, tabular |
| Cost sub-line | IBM Plex Mono `11px`, letter-spacing `0.06em`, `textMonoMeta` — "YOUR ESTIMATE · ADDED …" |
| DETAILS / NOTES | identical treatment to the item detail's tables above (shared `DetailSection` / `DetailRow` / `DetailProse`), including its mono-heading divergence; rows Category and Added only — the estimated cost is the screen's headline figure already, and printing it again to the cent under a whole-dollar hero was removed at `T044` |
| Market-price ghost | **Retired in `002`** — replaced by the Market section (below); the dashed placeholder and its ghost bars are gone |
| Sell-plan CTA | `1px solid accentBrass`, `3px` radius, padding `16px 18px`; heading "Find items to sell" `14.5px` 600 `accentBrass`; subtitle `11.5px` `#F2EDE4 @ 50%`; trailing "→" mono `15px` `accentBrass` |
| CTA subtitle copy | "Browse your lowest desire-to-keep items" — accurate today: `SellPlanViewModel` ranks candidates lowest-desire-first |

### Desire dial copy (`010` refresh)

The level summaries are `DesireLevel.summary` (level 3 becomes "On the
fence" per the refreshed mock — the design pass owns these words). The
hints are the review's **true-today rewording**: the mock's originals
described shortfall escalation and exclusion overrides that don't exist
yet. These lean only on what ships — `DesireLevel.isSellCandidate`
(desire ≤ 3) and the candidate pool's lowest-desire-first ranking.
**Revisit when the richer sell-plan logic lands: re-differentiate
levels 4/5 and restore the mock's fuller copy.**

| Level | Summary | Hint |
|---|---|---|
| 1 | Ready to sell | First in line when a sell plan needs candidates. |
| 2 | Would let it go | Offered early among sell candidates. |
| 3 | On the fence | Still a sell candidate — the last in line. |
| 4 | Keeping for now | Left out of the sell-candidate pool. |
| 5 | Absolutely keeping it | Never offered up. This one stays. |

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
brief — confirms it made it into the actual build. `002` is what it was
reserved for: the market trend arrow below, which ships on the two list
rows (`002`/T012). The Sell Plan's own candidate rows keep the slot
empty for now.

### Market section, candidate picker, dashboard variant (`002`)

Source: `design/elements/002-market-values/` — seventeen `.dc.html`
artboards and their PNGs, approved 2026-09-05 (spec Decision 17; the
pass ran through `/design` in the implementing session against the `010`
artboard sources and this file). Every string is a `MarketCopy` string.
"As implemented" columns are filled by T010–T013 where the build departs.

**The Market section** (both detail screens; item: after DETAILS, before
NOTES; wishlist: after NOTES, before the sell-plan CTA, where the ghost
was). One unbroken block in the DETAILS/NOTES rhythm — not a card — so
the two plated cards above stay the screen's weight.

| Property | Value | As implemented |
|---|---|---|
| Header | `monoLabel` "MARKET", `10px` gap to the body (DETAILS' `fieldGap + 2`) | as designed — `DetailSection(title: MarketCopy.sectionTitle)`, so the block sits in the DETAILS/NOTES rhythm by construction |
| Body rhythm | `12px` between rows | as designed — `MarketSection.rowGap`, a file constant: 12 has no metrics token and this is the section's own rhythm |
| Source line | IBM Plex Sans `12.5px`, line-height `1.45`, `textLabelSecondary` (55 %); "On Reverb · {title} · {year}", wraps | as designed — `typography.secondary` (12.5) + `textLabelSecondary`; leading as `.lineSpacing(3)`, SwiftUI's nearest to a 1.45 line-height |
| All-years line | same register, `4px` under the source line, above the figure | as designed — `MarketSection.tightGap`; drawn only over a **current** figure (plan Amendment A's copy rule), never over a withheld one |
| Median | IBM Plex Mono 500 `19px`, `textPrimary`, tabular — the PAID cell's register, never Archivo or brass | `typography.monoValue` (mono 500 **15**) + `textPrimary`, `.monospacedDigit()` — the PAID cell's register *as built*: `ItemDetailView.statPair` has drawn PAID at `monoValue` since 010, so matching the artboard's 19 here would have made the market figure larger than the person's own |
| Separator and count | IBM Plex Mono `12.5px`, `textMonoMeta` (45 %), `8px` gaps, baseline-aligned with the median | `typography.monoMeta` (11.5) + `textMonoMeta`, `metrics.fieldGap` (8), `.firstTextBaseline` — no 12.5 mono role exists and one wasn't worth adding for a 1pt difference |
| Reading row | spread left — IBM Plex Mono `11.5px` `textMonoMeta`; age right — IBM Plex Mono `11px` `textQuiet` (40 %), `white-space: nowrap`; withheld and stale readings put their sentence (IBM Plex Sans `13.5px`, line-height `1.5`, `textBody`) on the left | as designed, with the age at `monoMeta` (11.5, no 11 role) + `textQuiet` and `.fixedSize()` for the nowrap; the sentence is `typography.body` + `textBody`. Withheld puts its sentence on its own line with the age right-aligned beneath (the `ItemWithheld` artboard); stale shares one baseline row |
| Never-refreshed line | IBM Plex Sans `13.5px`, `textLabelSecondary` | as designed — `typography.body` + `textLabelSecondary` |
| Link | "View on Reverb" + `arrow.up.right` glyph (`11px`, `1.6` stroke), IBM Plex Sans 500 `13px`, `accentBrass`, `5px` gap, `44pt` hit height — the app's first external link, visually distinct from the in-place buttons | as designed — `MarketReverbLink`: `typography.buttonCompact` (new role, sans 500 13), `accentBrass`, `linkGap` 5, `.frame(minHeight: 44)` with `-8` vertical padding so the target doesn't stretch the rhythm. **A SwiftUI `Link` takes the label's `foregroundStyle`** — measured, not assumed, in `MarketLinkRenderTests` (ΔE 4e-8 from the token); no `.buttonStyle(.plain)` needed. The glyph is the SF symbol, so the artboard's 1.6 stroke reads as `.font(.system(size: 11, weight: .medium))` |
| Failure line | IBM Plex Sans `12.5px`, line-height `1.45`, `accentRustText`, between the link and the actions; the reading beneath unchanged | as designed — `typography.secondary` + `accentRustText`, drawn after the link and before the action rows |
| Button rule | filled brass = writes the person's data (the adopt action only); outlined brass = fetches (Refresh); text = manages the match, rust for Remove | as designed — one filled button in the section, and it is the adopt action |
| Filled button | `accentBrass` fill, `background` ink, IBM Plex Sans 600 `13.5px`, `44pt` tall, `3px` radius, grows to fill the row | as designed — `typography.buttonProminent` (new role, sans 600 13.5), `metrics.buttonRadius` (3), `cardPadding` (16) horizontal, `.frame(maxWidth: .infinity, minHeight: 44)`. Disabled while a refresh is in flight (`canAdopt` is false there): the component sheet's three Refresh looks specify Refresh, not adopt, and a live button whose action the view model refuses would be a dead tap |
| Outlined button | `1px accentBrass` border, brass text 500 `13.5px`, `44pt`, `3px`, `0 16px` padding, hugs its label (grows when alone) | as designed — `typography.button` (new role, sans 500 13.5), `metrics.hairline` border, `buttonRadius`, `cardPadding`; the artboards' `flex` is `fills:` — it grows exactly when no adopt button sits beside it. `.contentShape(Rectangle())`, since an outline's interior isn't hit-testable |
| Refresh · disabled (within the hour) | border ivory 16 %, text `textDisabled` (35 %); the age line above says why | as designed — `textPrimary.opacity(0.16)` (no ivory-16 % token but `gaugeTrack`, which is a gauge's track) and `textDisabled`; carries `MarketCopy.refreshWithinHourHint` for VoiceOver (Q8) |
| Refresh · refreshing | border brass 50 %, text brass 60 %, a `12px` arc spinner before the label | as designed — `accentBrass.opacity(0.5)` / `.opacity(0.6)`, and `ProgressView().controlSize(.small).tint(…)` for the spinner, the `SettingsActionRow` pattern. Note for the device pass: `ImageRenderer` draws that spinner as an unavailable-symbol box in stills, which is a renderer artifact, not the running app |
| Text buttons | IBM Plex Sans 500 `13px`, brass / `accentRustText`, `44pt` hit height on a `32px` visual row (`-6px` margins), Change match… left, Remove match right | as designed — `typography.buttonCompact`, `.frame(minHeight: 44)` with `-6` vertical padding, `Spacer` between them |
| Find on Reverb… (unmatched) | the outlined button alone under the header, hugging its label | as designed — the same outlined chrome with `fills: false`, and nothing else in the section (criterion 1) |
| Adopt label | "Use as my value" (item) / "Use as estimated cost" (wishlist) | as designed — `MarketCopy.useAsMyValue` / `.useAsEstimatedCost`, chosen by the section's `isWanted` |

**The candidate picker** — one sheet, four phases since Amendment B (notice, pick, fetching, value), over a `rgba(0,0,0,0.45)`
scrim; the sheet's bar (Cancel, title) is system chrome.

| Property | Value | As implemented |
|---|---|---|
| Sheet | `background` fill, `12px` top radius, `36×5` grabber at ivory 30 %; notice at a medium detent (~`300px`), picker at large (~`780px`) | as designed — one `.sheet(isPresented: $viewModel.isFindingMatch, onDismiss: viewModel.load)` on each detail screen, its content branching on `sheetStep` (Q9; `noticeIsPending` until T022 replaced it), with `.presentationDetents([.medium, .large], selection:)` driven by that phase. The top radius, the grabber and the `0.45` scrim are the system sheet's own — nothing here draws them; each phase fills its own `theme.colors.background` |
| Notice body | IBM Plex Sans `15px`, line-height `1.55`, `textBody`; "See the privacy policy" inline in brass 500; `22px 24px 32px` padding, `24px` to the buttons | `typography.body` (13.5) + `textBody`, `.lineSpacing(4)` — no 15pt sans prose role exists, and adding one for a single paragraph would put a second prose size in the app. Padding `22` / `screenGutter` (24) / `32`, `sectionGap` (24) to the buttons, as designed. **The link sits under the paragraph, not inline**: a SwiftUI `Link` is a view and cannot flow inside a `Text`, and the markdown-in-`Text` alternative would move the copy's shape into `MarketCopy` and give up the real `Link` (criterion 20's `.isLink` trait, `MarketReverbLink`'s reasoning). `typography.button` (sans 500 13.5) in brass, 44pt target |
| Notice buttons | Continue filled brass, Not now outlined, each `48pt`, stacked with `8px` gap; swipe-down = Not now | as designed — `MarketButtons.noticeHeight` (48) and `fieldGap` (8), drawn with the section's own filled/outlined chrome, lifted at T011 into `Trove/Views/Market/MarketButtons.swift` (two `ViewModifier`s) so the two surfaces can't drift; `MarketSection`'s call sites are unchanged. Swipe-down is Not now by construction — only `continueFromNotice()` acknowledges anything |
| Search field | the plated card, `44pt`, `0 14px` padding, `10px` gaps; magnifier `15px` ivory 40 %; text IBM Plex Sans `13.5px` `textPrimary`, brass caret `1.5×18`; clear glyph ivory 40 % | the shared `SearchField` — so the plate, the magnifier, the caret and the clear glyph are as designed, but **40pt**, not 44 (`metrics.searchFieldHeight`, what both list screens already use): one search control in the app is worth more than a second one 4pt taller. `.onSubmit` is attached here rather than inside it, since the picker searches on submit only (Q10) |
| Status line | IBM Plex Mono `11.5px` `textQuiet` with the `12px` spinner, `8px` gap | as designed — `typography.monoMeta` (11.5) + `textQuiet`, `fieldGap` (8), and `ProgressView().controlSize(.small).tint(accentBrass)` for the arc, the same spinner the Refresh button uses |
| Candidate card | plated, `3px`; body `13px` padding and gap (the row treatment); the body picks | as designed — `.extrudedPlate()` (`cardRadius` 3), `rowPadding` / `rowContentGap` (13); the body is a `.plain` `Button` calling `setMatch`, identifier `market.candidate` |
| Thumbnail | `64×64`, `2px` radius, `surfaceInset`; `RowThumbnail`'s hairline placeholder when there is no image | as designed — 64pt square, `thumbnailRadius` (2), `AsyncImage` over Reverb's URL through the OS's shared cache (Q17), `accessibilityHidden`. The placeholder is `RowThumbnail`'s `surfaceInset` + `photo` glyph *redrawn* rather than reused: that component takes stored `Photo`s, not a URL. `MarketWiringTests` holds `AsyncImage(` to this one file under `Trove/Views` |
| Title | IBM Plex Sans 500 `14.5px`, line-height `1.3`, `textPrimary`, **wraps in full** | `typography.rowTitle` (sans 500 **15**, the list rows' title role — no 14.5 role exists and a 0.5pt one wasn't worth adding) + `textPrimary`, with `.fixedSize(horizontal: false, vertical: true)` so it wraps in full and can never truncate |
| Brand | IBM Plex Sans `12.5px`, `textLabelSecondary` | as designed — `typography.secondary` (12.5) + `textLabelSecondary`; drawn only when the candidate has one |
| Reading | IBM Plex Mono `11.5px`, `textMonoMeta`, `2px` above | as designed — `typography.monoMeta` (11.5) + `textMonoMeta`, `.padding(.top, 2)`, `.monospacedDigit()`; the words are `MarketCopy.candidateReading(usedLowCents:usedTotal:)` |
| Card footer | `1px surfaceInset` top hairline, `0 13px`, the link right-aligned at `40pt` — the only outward target on the card | as designed — a `surfaceInset` hairline, `rowPadding` (13) horizontal, and a real `Link` to `ReverbAPI.productURL(slug:)` at `minHeight: 40` with the `arrow.up.right` glyph, `buttonCompact` in brass, `MarketCopy.reverbLinkHint` and identifier `market.candidate.link` (Decision 28) |
| Empty / failed | `EmptyStateView`: `34px` light glyph ivory 30 %, Archivo 600 `19px` headline, IBM Plex Sans `13.5px` `textQuiet` detail, the outlined "Try again" at `44pt` | `EmptyStateView` for both, with the artboards' `magnifyingglass` mark — so the glyph, the `emptyStateTitle` headline and the `body` + `textQuiet` detail are as designed. Empty carries the detail and no action; failed carries the headline (`rateLimited` or `unreachableNoFigure`) and Try again. **Try again is that component's capsule outline, not the artboard's 3pt rect**: one empty-state button shape in the app beats a second one that differs only in its corners |

**The dashboard's market line** (recommended form; the toggle was drawn
beside it and rejected — it hides the person's total behind a state,
puts a second figure in the hero's slot, and splits the amount from its
coverage, which P5 forbids).

| Property | Value | As implemented |
|---|---|---|
| Position | one line directly under the ruler, `8px` gap (`4px` extra top), above SPENT / GAIN | as designed — last in `DashboardView.headline`'s `VStack` (`fieldGap` 8) with `.padding(.top, 4)`, so it sits inside the headline block and above the SPENT / GAIN plate by construction. Drawn under "Not yet valued" too, on the same gap: a matched, refreshed item's asking price exists whether or not the person has priced anything |
| Register | IBM Plex Mono `12.5px`, `textMonoMeta` (45 %), tabular, `white-space: nowrap`; the amount alone at 500 in `textBody` (75 %) — never brass, never Archivo, so it cannot read as the total | `typography.monoMeta` (mono **11.5**) + `textMonoMeta`, `.monospacedDigit()`; the amount's run gets `monoMeta.weight(.medium)` + `textBody`. The nearest existing role, not a new one: the alternatives are `monoValue` (15, the PAID cell's register — far too loud for a line that must not read as the total) and a twelfth mono size for one line. Colours are the designed tokens exactly |
| Inseparability | one string, one line; if it must shrink, the whole line scales — the coverage never wraps or clips away from the number | as designed — one `Text` over one `AttributedString` built from `viewModel.marketLine` (`MarketCopy.dashboardLine`), so it is one accessibility element and the view never composes the parts; `.lineLimit(1)` + `.minimumScaleFactor(0.6)`. The lift is a range search for `MarketCopy.median(cents:)` inside the line, falling back to the uniform line if it isn't found — legible rather than wrong |

### The value step and the slider (`002` Amendment B)

Source: `design/elements/002-market-values/ValueStep.dc.html` (drawn and
approved 2026-09-05, T020). The sheet's fourth phase at the
medium detent: the title, the figure as the section draws it with the
true spread, Trove's own slider between the trimmed bounds with the
median marked and defaulted, the guidance line, the filled button with
the live amount, Not now.

| Property | Value | As implemented |
|---|---|---|
| Sheet | medium detent (~`500px` drawn), `22px 24px 32px` padding, `20px` between blocks | `MarketValueStepView.topPadding` 22 / `.bottomPadding` 32 / `theme.metrics.screenGutter` 24 across — the notice sheet's own padding — and `blockGap` 20 between the five blocks. The detent belongs to the sheet, not the view: both detail screens map `.notice, .value` to `.medium`, pinned in `MarketWiringTests` |
| Title | Archivo 600 `19px` `textPrimary` — "Set your value" / "Set your estimated cost" | `typography.emptyStateTitle` (display 19 semibold — the role the theme already has at exactly that size and weight) + `textPrimary`; the words from `MarketCopy.valueStepTitle(wanted:)` |
| Figure block | the section's own registers: source line `12.5px` 55 %, median IBM Plex Mono 500 `19px`, separator and count `12.5px` mono 45 %, the **true** spread `11.5px` mono 45 % | literally the section's pieces: `MarketQuietLine`, `MarketFigureRow` and `MarketSpreadLine`, lifted out of `MarketSection` at T024 and kept in `MarketSection.swift`, so the two surfaces draw one composition and the copy scan still sees every symbol. The median therefore reads at `monoValue` (mono **15**) — the section's register as built, for the reason the Market table's Median row records — and the spread is the true low–high, not the slider's ends (Decision 36). `figureGap` 10 |
| Track | `2px`, `divider`, `1px` radius, full width; the filled portion from the left end to the knob in `accentBrass` | `MarketValueSlider.trackHeight` / `.trackRadius`, `theme.colors.divider`; the fill's extent and its ink are measured in `MarketValueSliderRenderTests` |
| Knob | `20px` circle, `accentBrass`, a `3px` `background` ring and `0 2px 6px rgba(0,0,0,0.4)`; centred on the chosen amount's fraction of the bounds | `MarketValueSlider.knobDiameter` / `.knobRing`; the ring is a `background` disc under the brass one, the shadow `plateEdgeShadow` (the frame's own 40 % black) at `radius: 3, y: 2` — `ExtrudedPlate`'s pair |
| Marks | the two ends `1px × 12px` `divider`; the median `1.5px × 18px` `accentBrassDim`, taller than the ends | `MarketValueSlider.marks(trackWidth:lower:upper:median:)` places all three by centre; a zero-width range returns the median's alone |
| Labels | the trimmed bounds' amounts under the ends, IBM Plex Mono `11px` 45 %; "median" under its mark, mono `10px` 40 % tracked `0.08em` | the amounts in `typography.monoMeta` (mono 11.5) + `colors.textMonoMeta` (45 %); the caption in `typography.monoLabel` (mono 10.5) + `colors.textQuiet` (40 %), tracked `0.8` — the nearest roles the theme has, rather than two new sizes for one row. The row is fixed at `labelRowHeight` 16, the mono line box being taller than the frame's `14px` |
| Default | the knob at the whole-currency median | `MarketValueStep.chosenCents`, drawn through `x(forCents:trackWidth:lower:upper:)`; the 30 % fraction is measured in `MarketValueSliderRenderTests` |
| Snap / step | snaps to the median within `6pt`; the accessibility step is 1 % of the range in whole currency, at least one unit | `MarketValueSlider.snapTolerance` and `.adjustableStep(lower:upper:)`, both pure statics the drag and the adjustable action call — `MarketWiringTests` scans that they do |
| Guidance line | IBM Plex Sans `12.5px`, line-height `1.45`, 55 % | `MarketQuietLine` again — `typography.secondary` (12.5) + `textLabelSecondary` (55 %), `lineSpacing` 3 (`MarketSection.proseLineSpacing`, the drawn line-height at that size); `MarketCopy.valueGuidance` |
| Buttons | filled brass "Use $1,450 as my value" and outlined "Not now", each `48pt`, stacked with `8px` gap (the notice's pair) | the notice's pair exactly: `.marketFilledChrome(minHeight:)` and `.marketOutlinedChrome(fills: true, minHeight:)` at `MarketButtons.noticeHeight` 48, stacked at `theme.metrics.fieldGap` 8; the filled label carries the live amount through `MarketCopy.useAmount(cents:wanted:)`, so it changes as the knob moves |
| Zero-width range | one mark, the drag inert, the button live at that amount | one median mark at the left end, the amount named once beneath it; `x(forCents:)` and `cents(atX:)` each guard the division. The button is live because nothing disables it: `chosenCents` is fixed at that amount, and the step is the only thing the button reads |

### Market trend arrow (`002`)

`TrendArrow` — the market's direction beside a row's own figure (spec
`002` criterion 13, Decision 8). One glyph, no label, nothing at all when
the trend is flat or not yet known.

| Token | Value | As implemented |
|---|---|---|
| Glyph, rising | `arrowtriangle.up.fill` | `TrendArrow.swift` |
| Glyph, falling | `arrowtriangle.down.fill` | `TrendArrow.swift` |
| Size | 9 pt | `.font(.system(size: 9))` |
| Rising tone | `accentMossText` | ΔE-checked against the token in `TrendArrowRenderTests` |
| Falling tone | `accentRustText` | ΔE-checked against the token in `TrendArrowRenderTests` |
| Flat / unknown | draws nothing, takes no width | measured in `TrendArrowRenderTests` |
| Accessibility label | "trending up" / "trending down" | `MarketCopy.trendUp` / `.trendDown`, joined into the row's combined label |
| Placement, owned row | last on the value line, in both its branches | `ItemRow.valueLine` |
| Placement, wanted row | after the estimated cost, so the cost's own label reads first | `WishlistRow` |

The tones are the `*Text` pair rather than the base accents — the arrow
sits on a row plate at 9 pt, which is what that pair exists for — and
they are the same two tones the owned row's "vs paid" delta already
wears, deliberately: one voice for "up" and one for "down" on the same
line.

### Stock photos (`005`)

Source: `design/elements/005-stock-photos/` — eleven `.dc.html` artboards
and their PNGs, approved 2026-09-09 (spec `005` Design requirements; the
pass ran through `/design` against `design/brief.md`, this file, and the
shipped detail/list screens). Every string is a `StockPhotoCopy` string.
The picker sheet **reuses `002`'s candidate-picker sheet shape** (the
`background` fill, `12px` top radius, `36×5` grabber at ivory 30 %,
medium/large detents, the system Cancel/title bar, the `rgba(0,0,0,0.45)`
scrim) and its notice phase is `002`'s notice exactly with `005`'s copy —
so the rows below cover only what is new: the **image-first results grid**,
the **stock-photo badge**, the **credit line**, and the **list-row mark**.
"As implemented" columns are filled by T007–T013 where the build departs.

**The candidate picker — the results grid** (`Main.dc.html`, large detent).
The genuinely new surface: the photo is the choice, the credit secondary.

| Property | Value | As implemented |
|---|---|---|
| Sheet bar | Cancel (`accentBrass` `17px`) left; title "Choose a photo" (Archivo 600 `20px`) centred; `52px` bar, `4px` top margin under the grabber | |
| Search field | the shared `SearchField` plate, `40px`, `0 14px` padding, `10px` gaps; magnifier `15px` ivory 40 %; text IBM Plex Sans `13.5px` `textPrimary`; clear glyph ivory 40 %. Seeded with the item's name; searches on submit only; placeholder (proposed) "Search Wikimedia Commons" when cleared | |
| Status line | IBM Plex Mono `11.5px` `textQuiet` + the `12px` brass arc spinner, `8px` gap; text (proposed) "Searching Wikimedia Commons…" | |
| Grid | 2 columns, column-gap `12px`, row-gap `16px`; content padding `16px 24px 24px` | |
| Cell image | square (`aspect-ratio 1/1`), **fill-cropped**, `2px` radius, `surfaceInset` ground with `RowThumbnail`'s hairline photo-glyph placeholder while loading; the whole cell is the tap target | |
| Cell credit | `7px` under the image, a baseline flex row, `11px` line-height `1.3`: **author** IBM Plex Sans `11px` `textLabelSecondary` (55 %), ellipsis-truncated, takes the slack; separator `·` ivory 35 % with `5px` side padding; **licence** IBM Plex Mono `10.5px` `textMonoMeta` (45 %), never shrinks. The *compact* credit (author · licence) — the full linked form is on the detail screen | |
| Downloading cell | the tapped cell dims under a `rgba(20,19,17,0.58)` overlay with a centred brass arc spinner; its credit dims to `0.5`; the rest of the grid is unchanged | |
| Empty / failed | `EmptyStateView` — `34px` light glyph ivory 30 %, Archivo 600 `19px` headline, the outlined **Search again** at the component's capsule. Empty headline `StockPhotoCopy.emptyState`; failed headline `StockPhotoCopy.failure`. No hint line (the design declined one) | |

**The stock-photo badge** (`ItemStockHeroDark/Light.dc.html`,
`ItemOwnedPlusStock.dc.html`). A capsule over the fetched photo, drawn to
hold over both a light and a dark image by carrying its own near-opaque
dark ground — never on an owned photo.

| Property | Value | As implemented |
|---|---|---|
| Chip | `top:12px left:12px` over the photo; inline-flex, gap `5px`, padding `5px 9px 5px 8px`, radius `999`; ground `rgba(23,24,26,0.9)` (≈ `background` at 90 %); `1px` border ivory 14 % | |
| Glyph | a small "photo-on-photo" mark, `12×12`, `1.4` stroke, ivory 72 % | |
| Label | IBM Plex Mono 500 `10px`, tracked `0.12em`, ivory 75 %, the app's all-caps label idiom — so `StockPhotoCopy.badge` "Stock photo" renders **"STOCK PHOTO"** (uppercased by style, not a copy change); a11y label "Representative stock image" | |
| Hero | the photo area is `240px`, `3px` radius, the plate shadow set; the badge is the only chrome over it | |

**The credit line** (beneath the hero; `ItemStockHero*`). The full,
linked form — distinct from the grid's compact credit.

| Property | Value | As implemented |
|---|---|---|
| Line | `12px` under the photo; IBM Plex Sans `12.5px`, line-height `1.5`, ivory 55 %; "Photo: {author} · {licence} · {Wikimedia Commons}" | |
| Licence run | IBM Plex Mono `11.5px` ivory 45 % | |
| Link | "Wikimedia Commons" in `accentBrass` 500, `white-space:nowrap`, with the `arrow.up.right` glyph (`11px`, `1.7` stroke) `2px` after — the app's "leaves the app" external-link convention; opens the Commons file page; hint "Opens Wikimedia Commons in your browser" | |

**The list-row stock mark** (`WishlistStockMarks.dc.html`,
`ItemListStockMarks.dc.html`). A tiny corner mark on the row thumbnail,
only when the leading photo is the fetched one (no owned photo); a row
with an owned photo leading shows no mark.

| Property | Value | As implemented |
|---|---|---|
| Mark | `top:4px left:4px` over the thumbnail; `16×16`, `3px` radius; ground `rgba(23,24,26,0.9)`, `1px` border ivory 16 %; the same photo-on-photo glyph, centred | |

### Mark as sold (`006`)

Source: `design/elements/006-mark-as-sold/` — twelve `.dc.html` artboards
and their PNGs plus `design-notes.md`, from the `/design` pass of
2026-09-13 against `brief.md` in that folder (spec `006` Design
requirements). Every string is a `SaleCopy` string; the outcome strings
were placeholders the pass was asked to settle (spec Decision 10) and the
settled form is recorded first. No new colour and no new token: every
value below maps to an existing one. "As implemented" columns are filled
by T013–T017 where the build departs. The person's approval and the six
copy questions the pass raised are recorded in `tasks.md` (T008).

**Decision 10 — the outcome's form.** Words first, then the amount, then
the basis; the same strings on a row and on the page, the page larger.
`Gain $350 vs paid` (`accentMossText`) / `Loss $150 vs paid`
(`accentRustText`) / `At cost` (row `textLabelSecondary`, page
`textBody`). The colour only repeats the word. Totals (the Dashboard card,
the Sold side summary) keep the signed `+$200 vs paid` form.

| Property | Value | As implemented |
|---|---|---|
| **Owned / Sold switch** | | |
| Shape | Sort By badge family: `1px accentBrass` border, `3px` radius, `32` tall | |
| Halves | two, `62` wide each, no seam, IBM Plex Mono `11`, centred | |
| Active half | `accentBrass` fill, `background` ink, weight 500 | |
| Inactive half | no fill, `accentBrass` text, weight 400 | |
| Placement | its own row under the title block, left-aligned; `controlRowGap` (16) below the meta line; `sectionGap` (24) above the search field on Owned; `15` above the first row on Sold | `014`: **the Owned spacing on both sides** — the Sold side now carries the same search field below the switch, so `sectionGap` (24) is the gap there too, **once anything has been sold** — with nothing sold `offersNarrowingControls` is false, no control sits between the switch and the content, and the `15`-to-the-first-row case no longer arises at all. The meta line above the switch spans the header's full content width with the badges on the title's row (`014` plan Q18), which is what holds the switch's top edge equal: **154.333 pt on both sides**, measured at T010 with zero sales, with `-seedSold` and on a 13-row collection |
| Header on Sold | Sort By and search hidden, "…" stays; the meta line is the sold summary, realised part in moss/rust | `014`: **nothing is hidden** — the search field, the category chips and Sort By render on the Sold side in the Owned side's slots, behind one gate (`offersNarrowingControls`, spelled twice), once anything has been sold; the badge reads that side's own sort ("Date sold" by default) and the chips are the sold categories only, with no Un-valued chip. The meta line is still the sold summary, now full-width under the title-and-badges row (Q18) |
| Motion | the fill slides to the tapped half, `.snappy(duration: 0.2)`, rows cross-fade; fade only under Reduce Motion (0.25 s at the Design pass, shortened at T018b under spec Decision 13's "fast and smooth") | rows do not cross-fade — the fill's animated `.offset` is the only motion (T015 left the row fade out; Phase 5 review S6; recorded at the sweep) |
| **Sold row** | | |
| Shape | the Owned row (`List` chrome, plate, `52` thumbnail, `13` padding and gap) with no dial and no trend arrow | |
| Lines | name `rowTitle`; date `monoLabel` "SOLD SEP 12, 2026"; value line `monoValue` price + outcome `monoMeta`, `8` apart | |
| Stock photo | the `005` corner mark kept | |
| **Sold side empty** | `EmptyStateView`, no action; mark SF `tag` (proposed, replaces `TabItems`) | |
| **Dashboard Sold card** | | |
| Chrome | plated (`extrudedPlate`), `cardPadding` 16 | |
| Header | `monoLabel` "SOLD" in `textLabel` | |
| Figures | IBM Plex Mono 15: count in `textBody` 400, proceeds lifted to 500 `textPrimary` (the market line's lift); `6` under the header | |
| Realised line | `monoMeta` 11.5, moss/rust by sign; `4` under the figures | |
| Tap cue | `arrow.right`, 11pt medium, `accentBrass`, trailing, vertically centred; the whole card is the button | |
| **Sold mark (detail)** | | |
| Position | directly under the title block — photo hero, name, then the mark, then the stats — inside the page's one `sectionGap` (24) stack, so the gap above and below it is the page's standing section gap (`014` Decision 6) | Until `014` it was first in the scroll content, *above* the photo hero, with `sectionGap` 24 to the hero; the person asked for it under the name at `014`'s reading. Only its place moved — words, colours, `sold.mark` identifier and combined accessibility element are unchanged |
| Tag | "SOLD", `monoLabel` type, `textPrimary` fill, `background` ink, padding `3 6 3 7`, `2px` radius (`thumbnailRadius`) | |
| Outcome | on the tag's line, `10` after it; IBM Plex Mono 500 15 (`monoValue`), moss/rust/`textBody` | |
| Sale line | `8` below; `monoMeta` in `textBody`, the price lifted to 500 `textPrimary` | |
| Chrome | unplated | |
| Read-only page | desire card without "TAP OR DRAG" and without the level hint; no Market section; no Find a photo… | |
| **Sell Plan** | | |
| Figures | three cells when `hasSales`: Selected · Sold · Estimated cost; cells hug their content, `space-between` around the `1px` dividers with `6` minimum either side; plate padding `12` all round in this mode (16 → 12 horizontally); figures `lineLimit(1)` + `minimumScaleFactor(0.6)` | |
| Figure sizes (three) | all `heroFigureSecondary` (Archivo 26); Selected drops from 34 | |
| Sold figure | `textPrimary`; caption `monoLabel` `textQuiet` "2 ITEMS" | |
| Row control | footer strip inside the candidate card: `1px surfaceInset` top hairline, `40` tall (`44` hit), `cardPadding` sides, "Mark as sold…" `buttonCompact` (Plex Sans 500 13) `accentBrass`, right-aligned; the body above stays the toggle | |
| Sold section | unplated, after the candidates, `sectionGap` above; `monoLabel` "SOLD", `10` gap; rows `12 / 0` padding, `1px surfaceInset` bottom; name `body` 13 `textPrimary` (truncates), date `monoMeta` `textMonoMeta`, price IBM Plex Mono 500 13 `textPrimary`, `12` gaps | |
| **Sale sheet** | | |
| Size | `.medium` detent (content ≈ 340pt); `.large` when the keyboard rises | |
| Bar | system: Cancel `textBody`, title, confirm `accentBrass` semibold; no bottom save bar | |
| Fields | Sale price + Sold on paired (`listRowGap` 10), then Sold at, then Note; `sectionGap` 24 between; the item form's field chrome | |
| Invalid | `1px accentRust` border on the blank price, no message | |

Where the drawings differ from the brief, recorded as the pass stated
them: one example set runs through the canvas (three sales, $2,400,
**+$200**); the summary line stays in the title's meta slot (the plan's
`soldSummaryLine`), not under the switch; the Sell Plan's Selected figure
drops from Archivo 34 to 26 in the three-figure layout; the sold page's
desire card drops its level hint as well as "TAP OR DRAG".

### Mark as bought (`015`)

**No design pass.** `015` added no colour, no component and no surface: the
purchase sheet is the sale sheet's twin, the swipe action is `014`'s
arrangement on the other list (see *Swipe-action rows* above), and the menu
row is a row in the app's one existing system menu. So there is nothing to
record here but the sheet's own measurements and the two places it departs
from its twin — both settled by the person at a pause, not by a pass.

| Property | Value |
|---|---|
| **Purchase sheet** | |
| Size | `[.medium, .large]` detents, the sale sheet's — `.large` when the keyboard rises |
| Bar | **no title** (`015` T012a — as the sale sheet's twin it carried one, and on the device it truncated to "Mark as bo…" beside a confirm button saying the same words, so the person had it removed; `.navigationBarTitleDisplayMode(.inline)` is kept, or the bar falls back to large-title layout with empty space where a title isn't). Cancel `textBody` left, "Mark as bought" `accentBrass` semibold right; no bottom save bar |
| Fields | Purchase price + Purchase date paired on one row (`listRowGap` 10), the comparison line directly beneath, then Bought from, then Condition; `sectionGap` 24 between; the item form's field chrome throughout |
| Date popover | **unbounded** — deliberately not the sale sheet's `in:` bound (plan Q9), because `ItemFormView`'s "Date bought" fills the same field and takes any date |
| Condition | `ItemFormView`'s label-plus-`FlowLayout` of capsules over `Condition.allCases`, each chip keeping its selected trait — not a picker, which would put a system menu inside page content |
| Comparison line | `theme.typography.secondary` on `textQuiet`, sentence case, no colour branch, no arrow, no figure treatment — "$120 less than you estimated". **Corrected at the Phase 2 pause** (`015` T011b): the plan specified `monoLabel`, which uppercases and tracks, so it shipped reading `$120 LESS THAN YOU ESTIMATED` in the identical treatment as the `PURCHASE PRICE` label above it. The app has no shared modifier for quiet prose — the explicit `secondary` + `textQuiet` pair is used at 28 call sites |
| Invalid | `1px accentRust` border on the blank price, no message — the sale sheet's |
| **Sell Plan bar button** | |
| Action | `Text(PurchaseCopy.swipeBuy)` — the word **Buy** — at `.topBarTrailing`, in the corner the wanted page's "…" occupies, gated on the plan still having an entry. A bar button rather than a menu: a one-row menu is a menu for nothing. **It was a bare SF `bag` glyph until the device pass** (`015` T012a), which read as *cart* on the one screen whose subject is selling |


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

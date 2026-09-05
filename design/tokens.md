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
rather than raising it; and the wishlist detail's market-price ghost and
sell-plan CTA are outlined, unfilled surfaces for the same reason (added
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

The 2026-08-29 export refresh relabels this button DUPLICATE — that text
is **outdated**, confirmed at review: the on-screen string stays "Copy"
per plan.md's Resolved decisions. The export was not edited; this note
is the flag.

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
| Market-price ghost | `1px dashed divider`, `3px` radius, padding `18px`, `12px` gap; header pair `10px` 600 `0.14em` `textQuiet` / mono `10px` `0.1em` `textInactive`; ghost bars `divider` at `35%` opacity, `40px` tall field; note `12px` line-height `1.5` `textQuiet` |
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

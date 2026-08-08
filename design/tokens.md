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
| `dialMidpoint` | `#A87C4A` | desire dial's middle-of-range color (between rust and brass) |

The rust/moss "text-safe lift" pair is a real accessibility catch, not a
stylistic choice — worth preserving exactly, not simplifying to one
color per accent. Implement as two properties per accent (e.g.
`accentRust` for shapes, `accentRustText` for any place that color
renders as text) so it's not accidentally used the wrong way in a given
context.

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

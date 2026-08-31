# Trove — Design Brief

For Claude Design. This is the visual/interaction direction to generate
screens against — the functional requirements live in
`specs/001-core-inventory/spec.md` if more detail is needed on what a
screen has to show or do.

## What this is

Trove is a personal gear inventory app for hobbyists (photography,
guitars/amps, audiophile equipment) who track what they own, what they
paid, what it's worth now, and what they want to buy next — with an eye
toward selling underused gear to fund the next purchase. The audience
already has a rich visual vocabulary from their hobbies: brass hardware,
aperture rings, VU meters, leather straps, brushed aluminum. This is
where the design should draw from — not generic "clean SaaS dashboard"
language, and explicitly not a cream-background/serif/terracotta look,
a near-black/neon-accent look, or a hairline-rule broadsheet look. Those
are the current AI-design defaults and none of them are actually about
this subject.

**Mostly not skeuomorphic — narrowed in `010`.** The brief below
references physical instruments (dials, gauges, meters) as a *shape and
metaphor* language — flat, graphic, minimal, with room for restrained
depth where it earns its place. This is not a request for rendered
materials: no metallic gradients, no wood-grain or leather-grain
textures, no fake screws or stitching, nothing photorealistic. A dial
in this app is a thin arc and a number, not a photorealistic knob.

**Amended in `010`** (see `specs/010-item-management-enhancements/plan.md`'s
Resolved decisions): this section originally also ruled out bevels,
embossing, and drop shadows outright. That reflected an assumption
about the limits of flat design, not a permanent boundary — Trove's
visual identity is expected to keep evolving as the app grows, not stay
fixed to what shipped in `001`. Subtle, alpha-based depth cues (a
restrained cast shadow, a light top edge and dark bottom edge
suggesting depth — built from black/ivory alphas layered over the
existing `surface` color, never new hardcoded colors) are permitted now,
used sparingly. `010`'s row treatment (`tokens.md`) is the reference
example. What still holds absolutely is the line above: nothing that
reads as a rendered physical material or a literal control — the
boundary moved from "no depth at all" to "depth without literal
materiality," not to "anything goes."

## Palette

Dark-first. Every color below should be treated as a semantic token
(`background`, `accentPrimary`, etc.) rather than a hardcoded value, so a
light variant can follow later without a redesign — but design the actual
screens against dark for now.

| Token | Hex | Use |
|---|---|---|
| `background` | `#17181A` | app background — warm graphite, not pure black |
| `surface` | `#201F1D` (approx, adjust as needed) | cards, list rows |
| `textPrimary` | `#F2EDE4` | warm ivory, primary text |
| `textSecondary` | ~60% opacity of `textPrimary` | secondary/meta text |
| `accentBrass` | `#C79A56` | primary accent — value figures, CTAs, the desire gauge's fill ramp. **Not** the desire dial's "keep" end — see the signature-element section below and `tokens.md` |
| `accentMoss` | `#52634F` | secondary accent — positive/upward movement, and the desire dial's "keep" end |
| `accentRust` | `#9C4A34` | the desire dial's "sell" end, low-desire flags |
| `divider` | `#3A3B3E` | hairlines, borders |

Treat these as a starting point Design can refine — exact values,
especially `surface`, should get tuned once real screens are in front of
us rather than locked in from a brief alone.

## Typography

Three roles:
- **Display** — used sparingly, for screen titles and big value figures
  (the dashboard's total value, an item's price). Should have real
  character — something with the presence of engraved instrument
  numerals — but used with restraint, not on every label.
- **Body** — a clean humanist sans for list text, labels, form fields.
  Needs to read well at small sizes since this is a data-dense app.
- **Utility/mono** — for serial numbers and monetary figures specifically.
  Monospace numerals read as "spec sheet," which is the right connotation
  for a gear-tracking app, and it keeps price columns visually aligned.

## Signature element: the desire dial

Replaces a plain 1–5 star rating everywhere it would otherwise appear
(item cards, item detail, the sell-candidate ranking list). A simple arc
gauge — thin stroke, flat fill, no gradient — sweeping from `accentRust`
(1, "ready to sell") through `dialMidpoint` to `accentMoss` (5,
"absolutely keeping it"). This is the one recurring, distinctive,
*functional* piece of visual identity for the app — it should show up
small and quiet in list contexts, larger and directly editable (drag or
tap-to-set) in the item form and detail view.

(The "keep" end shipped as moss rather than brass: brass sits next to the
dial as the price figure's color, and the two were confusable. See
`tokens.md` for the measured ramp and the guards that pin it.)

## Companion element: the desire gauge (wishlist)

Wishlist items carry their own rating — desire-to-*own*, 1–3, shown as a
three-segment gauge rather than a dial. Deliberately a different control,
not a recolored dial: the dial's rust→moss sweep encodes a keep/sell
axis that means nothing for something you don't own yet, and two
near-identical dials meaning structurally different things would read
worse than two clearly distinct ones.

Three parallelogram segments in a row — a slight, consistent shear so it
doesn't read as a plain progress bar — filled left to right. Flat fills,
hard edges, no gradient, same constraint as everything else here.
Unfilled segments remain visible as dim empty tracks so it reads as a
scale with a reading on it, not a count of marks. The filled tones ramp
within the gauge (segment 1 dimmest brass, 2 medium, 3 brightest), so
segment count and brightness reinforce each other and the brightest tone
appears only at the top level. Labeled "Someday" / "Soon" / "Next" in
the form and detail view; unlabeled in list rows, where it sits in the
row's lower-right.

## Screens to design

Mapped to the flows in spec.md — see that file for the exact fields each
screen needs, this is the visual/layout brief for each:

1. **Dashboard** — total current value, total spent, the delta between
   them, a count of items not yet valued, and a category breakdown. This
   is the "open the app and see how you're doing" screen — it should feel
   like the most considered screen in the app, since it's the one seen
   most often.
2. **Item list** — browsable, filterable by category, sortable. Should
   not feel like a spreadsheet row — this is a collection someone's proud
   of. Include the desire dial (small) per row.
3. **Item detail** — full view of a single item: photos, all fields,
   larger desire dial (editable), edit/delete actions.
4. **Add/edit item form** — the required fields (name, category, price,
   date) prominent and fast; everything else behind a "more details"
   disclosure. This is a frequently-used screen and needs to feel quick,
   not like filling out a form.
5. **Wishlist list** — wanted items with estimated cost, filterable by
   category (same treatment as the item list's filter). No per-row Sell
   Plan shortcut — an earlier version had one, but a control repeated
   identically on every row read as noise and overemphasized a feature
   meant to stay quietly available rather than prominent. Reachable only
   from the wishlist item's own detail screen.
6. **Wishlist detail** — a plain, quiet view of the wishlist item itself:
   name, category, estimated cost, notes. Reserve visual space for
   pricing/trend info that doesn't exist yet (a future feature) rather
   than designing as if this is the finished screen. One clear action
   ("Find items to sell") leads to the Sell Plan below — this should
   read as a single deliberate button, not a dominant module on the
   page.
7. **Sell Plan** — reached only via the button on Wishlist detail or the
   wishlist list's shortcut, not shown by default. This is the core
   feature screen in its v1 form: a ranked, *selectable* list of owned
   items (low desire-to-keep first) — items are checked in or out of the
   plan, not just displayed. Starts with nothing selected; the plan
   persists once the user starts choosing, so returning to this screen
   later shows the same selection, not a fresh computation.

   **This is advisory, not a goal to complete.** Show the selected
   items' combined value next to the wishlist item's cost as two
   figures the user can compare — a quiet color distinction between
   "meets or exceeds" and "doesn't" is fine, but no copy that nudges the
   user toward covering the gap. Specifically avoid anything like "keep
   going," "check another item," "you need $X more," or a celebratory
   treatment for crossing into surplus — that framing implies the user
   is supposed to fully fund the purchase from a sale, which isn't the
   point. The point is showing good sell candidates for a purchase that
   might make sense right now, nothing more prescriptive than that.

   **One future-proofing note**: v1 ranks candidates by desire-to-keep
   only, but a later version will likely add a per-item trend signal
   (roughly: "this item's resale value is currently trending up," shown
   as a small indicator on the row — an arrow or similar, not a chart).
   Nothing needs to be built now, but leave each candidate row with a
   little room — don't design it so tightly that adding one small
   indicator later means redoing the row layout.
8. **Add/edit wishlist item form** — simpler than the item form: name,
   category, estimated cost, notes.
9. **Empty states** — items list, wishlist, and dashboard with no data
   yet. Should point at the add action, not just say "nothing here."

## Voice

Plain, direct, no filler. Name things by what the person controls, not
how the system works — "Add item," not "Create record." Buttons and their
resulting confirmations share vocabulary (a "Save" button doesn't produce
a "Changes recorded" toast). Empty states are an invitation to act, not
an apology.

## Open for Design to refine

- Exact `surface` color and any additional tonal steps needed for
  elevation/hierarchy.
- Exact display typeface pairing — the brief states the *role* and
  character, not a specific font name.
- Icon language — hasn't been specified; should feel consistent with the
  flat/graphic instrument metaphor rather than generic SF Symbols defaults
  where a custom mark would serve better (though SF Symbols are fine
  where they're genuinely the right, unobtrusive choice).

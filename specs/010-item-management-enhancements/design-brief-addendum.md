# Design Brief Addendum: Item Management Enhancements (010)

For Claude Design. This is an **addendum** to `design/brief.md`, not a
replacement — everything in the original brief still governs (palette,
typography, the desire dial as signature element, the skeuomorphism
boundary) unless this document explicitly says otherwise. Functional
detail lives in `specs/010-item-management-enhancements/spec.md`.

## Why this is an addendum, not a fresh brief

`010` doesn't introduce a new screen or a new visual identity — it
extends four existing surfaces that `brief.md` and the original Design
session already covered. Re-deriving audience vocabulary, the
what-to-avoid list, or the signature element here would risk producing
something that reads as a second identity layered on the first, rather
than a continuation of it. Everything below assumes the reader already
has `brief.md`'s full context loaded.

## Important: the shipped app has diverged from the original mockups

The Design session that produced `brief.md`'s screens predates
implementation. Real build decisions since then changed things the
session has no way to know about on its own — tab bar icons that didn't
exist in the original mock, a wishlist detail screen with a row
removed, color values retuned twice after rendering against actual
pixels, and (specific to this addendum) a "Reorder" button and a
two-option sort control on the wishlist screen that may or may not
match whatever the session currently pictures.

**Concretely: before asking for any of the four items below, provide
current screenshots of the actual running app, not just this
document.** At minimum:

- `ItemListView` in its current state (a populated list, existing sort
  control visible).
- `WishlistView` in its current state — this one matters most, since
  it's the screen with the most drift: the current "Reorder" button and
  its two-option ("Yours"/"Cost") sort control are both being changed,
  and Design needs to see what's actually there today, not what the
  original five-tab mock showed.
- A wishlist row showing `DesireGauge` at its actual small, unlabeled,
  in-row size — the legibility problem being solved is specific to how
  it reads at that real size, not a description of it.
- The labeled `DesireGauge` from the wishlist form or detail screen, for
  contrast (that version already reads fine; the ask is only about the
  unlabeled row version).

Where a screenshot and this document disagree, the screenshot is
correct — per the project's own standing principle, correctness over
reference fidelity, stated plainly rather than silently picked.

## What's needed

### 1. Row treatment (both `ItemListView` and `WishlistView`)

Give rows a small amount of additional visual depth/character — they
currently read as flat rectangles. Explicitly **not** a request to
introduce anything `brief.md`'s skeuomorphism boundary already rules
out: no bevels or embossing, no drop shadows simulating a raised
physical control. Subtle is the actual target, not a starting position
to negotiate down from — think "slightly more considered," not
"visually distinct."

`tokens.md`'s existing `surfaceInset` token (an inset hairline, already
built beyond what the original brief specified) is a plausible starting
vehicle, but not a locked answer — if a different flat, non-skeuomorphic
treatment reads better, use it.

### 2. Sort pickers, both screens, now with more options

`ItemListView`'s sort control gains a fourth option ("Yours" — manual
order). `WishlistView`'s gains a third and fourth ("Desire" and
"Alphabetical," alongside its existing "Yours" and "Cost"). Both
controls were designed around fewer options than they'll now hold —
this needs a treatment that reads cleanly at four options, not a
minor tweak to whatever holds two or three today. Whatever pattern
works for one should probably work for the other, given they're
functionally the same control now.

### 3. Swipe-action iconography (Edit, Duplicate, Delete)

Both lists gain swipe-revealed actions: Delete (trailing/destructive),
Edit and Duplicate (leading). Icons for these three should read as part
of the same flat/graphic instrument language as the tab bar icons and
`AddButton` (`T044`) — not default system icons dropped in
unconsidered, but not a heavy new icon system either.

### 4. `DesireGauge` legibility

The unlabeled, in-row version of `DesireGauge` (three small segments)
doesn't read as a *desire* indicator on first encounter — this was
flagged at `001`'s sign-off and parked for this spec specifically. The
ask is legibility, not a redesign: it needs to stay the flat/graphic
three-segment control `brief.md` and `plan.md` already describe, ramping
brightness across the filled segments. Whatever changes — a subtle
label glyph, spacing, contrast — should make it recognizable as *this
app's* desire indicator at a glance, the same way the desire dial
already is.

## Open for Design to refine

All four items above are stated as problems to solve, not solutions to
execute — the specific mechanism for each (exact token, exact icon
set, exact picker layout) is genuinely open. The one hard constraint
across all four is `brief.md`'s skeuomorphism boundary, restated above
because it's the constraint most likely to get bent under "just a
little more life."

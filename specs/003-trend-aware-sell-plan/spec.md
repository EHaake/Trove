# Spec 003 — Trend-aware Sell Plan

**Status**: Draft — pending the person's approval
**Depends on**: `001-core-inventory` (the Sell Plan), `002-live-market-value` (the on-device history and its trend)
**Authored**: 2026-09-06, in the Claude Code session at the person's direction (the constitution's venue clause); every substantive call below is the person's, and the two marked *delegated* were left to Claude Code and can be overturned before approval.

## What and why

The Sell Plan ranks the owned gear a person is lukewarm about, so that
when they are eyeing a purchase they can see what would make the most
sense to sell toward it. Since `001` it has ranked by attachment alone:
least wanted first, ties to the more valuable. `002` gave every matched
item a market history on the device and a trend from it — asking prices
on Reverb rising, falling or flat over at least a week — but the Sell
Plan never looked at it. Its rows show nothing from the market at all.

This spec makes the ranking trend-aware: among the items a person feels
the same about, the ones whose asking prices are rising come first, and
the plan says so in one quiet line. The idea from the roadmap — surface
an item because it is *both* low-attachment and currently selling well
— lands here, without changing what the Sell Plan is: advisory, a list
of the person's best options, never a target and never an instruction.

The person's own attachment stays the first word. A trend reorders
items within a desire level and never lifts one across levels (Decision
1): a lukewarm item whose asking prices are falling is still a lukewarm
item, and a well-loved one that is rising is still well loved.

## Core behavior

### The ranking

- The candidate pool is unchanged: owned items with desire-to-keep of 3
  or lower and a current value entered, plus anything already on the
  plan that no longer qualifies (as `001` has it).
- Order: least wanted first. Within one desire level, items whose
  asking prices are **rising** come first, then items with **no trend
  or a flat one**, then items whose asking prices are **falling**.
  Within those groups, higher current value first, then name, so the
  order is fully determined by the data (Decision 1).
- "Rising", "falling" and "flat" are exactly `002`'s trend (its P12):
  the latest median against the most recent history point at least
  seven days older, up at +5 % or more, down at −5 % or less. One
  definition, shared with the list rows' arrows; this spec adds no
  threshold of its own (Decision 5).
- An unmatched item, a matched item with fewer than two qualifying
  points, or one whose figure is no longer current (older than thirty
  days, `002` P13) ranks in the middle group, as neutral. Nothing about
  it is guessed.

### What a row shows

- Each candidate row keeps its checkbox, name, category, desire dial
  and the person's current value. Beneath the person's value it gains a
  quiet **market line** when the item has a current figure: the Reverb
  median asking price with the trend arrow beside it, in the same up
  and down tones the list rows use (Decision 3). No figure, no line; no
  trend, no arrow.
- A row that is **rising** carries one **reason line** under its
  category: "Asking prices on Reverb are up 12 % since Aug 5." The
  percentage is the same comparison the arrow made, rounded to a whole
  number; the date is the earlier reading's (Decision 2). Falling and
  neutral rows carry no reason line — the arrow is the whole statement
  (Decision 2).
- The market line and the reason line are information. Nothing on the
  screen urges the person to sell, and nothing changes in the
  screen's combined-value comparison or its colour cue.

### What does not change

- The combined value of the selected items is the sum of the person's
  own values, as before. The market median sits beside a value and is
  never summed or substituted (Decision 4; `002` Decisions 2 and 8).
- Selecting and deselecting, immediate save, the empty states, the
  entry from the wishlist item's detail screen, and the absence of any
  per-row shortcut elsewhere are all as `001` left them.
- The trend is computed from the device's own history, which does not
  sync (`002` Decision 7). Two devices can therefore show the same
  plan in different orders until both have accrued history; the
  selection itself syncs and is the same on both (Decision 6).

### At launch

History began accruing on 2026-09-05, so on the day this ships no item
has a trend and every plan reads exactly as it does today, with the
market line added. The reason line appears the first time an item has
a reading at least a week older than its latest and the two differ by
5 % or more. The screen says nothing about the absence of trends
(Decision 7): the quiet lines arrive when there is something to say.

## Copy

- Market line: "$1,400 on Reverb" — the median in whole currency, then
  the arrow. The figure is an asking price, and the vocabulary rules of
  `002` (P10: never "value", "worth" or "price" alone for the fetched
  figure) apply to every string this spec adds.
- Reason line: "Asking prices on Reverb are up 12 % since Aug 5." — the
  month and day of the earlier reading; the year is added only when it
  is not the current one.
- Accessibility: the market line reads "Median asking price $1,400,
  trending up"; the reason line reads as written.

## Design requirements

- The two new lines use the row's existing quiet tones and type: the
  market line in the meta style beneath the person's value, the reason
  line in the secondary style under the category, the arrow in moss
  and rust as the list rows draw it. No Design pass, for the reason
  `002` Decision 8 gave the arrow: small additions in existing tones
  to an approved row (Decision 8, *delegated*).
- A row with both lines must not push the checkbox, dial or value out
  of alignment with rows that have neither; the lines wrap under their
  own column.
- Dynamic Type at the largest accessibility size keeps the reason line
  readable in full, wrapping rather than truncating.

## Decisions record

1. **Trend reorders within a desire level and never across.** Option B
   — letting a rising desire-3 item outrank a flat desire-1 item — was
   put to the person and declined. Attachment is the person's own
   judgement, the thing the app never overrides; the trend is context
   for ordering the items they feel the same about. Within a level:
   rising, then neutral, then falling, then value, then name.
2. **The reason line names the rising case only.** "Asking prices on
   Reverb are up 12 % since Aug 5." on rising rows; nothing beyond the
   arrow on falling or neutral rows. The Sell Plan's principle since
   `001` is "show the information, let the user decide": a falling
   item needs no sentence, and no line anywhere says "sell".
3. **Rows gain the median and the arrow.** The person chose the market
   line over the arrow alone so the reason for a row's position is
   visible without opening the item. This is the first row surface in
   the app to carry the median itself — the item list and wishlist rows
   carry only the arrow (`002` Decision 8) — which Claude Code
   misdescribed in the conversation as "the same shape the list rows
   use"; the person's choice was of the median line itself, and the
   correction is recorded here.
4. **The combined value stays the person's values.** Treated as settled
   from `002`'s Decisions 2 and 8; the person confirmed.
5. **No new thresholds.** The seven-day gap and the ±5 % bands are
   `002`'s, one source of truth. The percentage the reason line shows
   is that same comparison, rounded.
6. **Order may differ between devices** until each has its own
   history; the selection syncs. Accepted as a consequence of `002`
   Decision 7 rather than reopened.
7. **Nothing is said when no item has a trend.** At launch, every plan
   is trend-less; a line explaining that would be the kind of
   commentary the screen avoids. The lines appear when they have
   something to say.
8. ***Delegated* — no Design pass.** Two quiet lines in existing tones
   on an approved row, by the reasoning of `002` Decision 8.
9. ***Delegated* — a seeded history for verification.** No device will
   hold a week of history before this ships, so the ranking, the arrow
   and the reason line are verified against fixtures in the unit
   tests and, for the UI test and the device pass, against a history
   seeded only under the existing `-uiTesting` launch argument — the
   constitution's sanctioned test-only branch, whose only effect is on
   that launch's in-memory stores. The person's own device shows the
   feature as its history accrues.

## Acceptance criteria

Each is something a person can check on the built app, or a test can
check against fixtures. The plan will cite what verifies each.

1. [ ] Two candidates at the same desire level, one rising and one flat,
   list the rising one first regardless of their values.
2. [ ] Two candidates at the same desire level, one flat and one
   falling, list the falling one last regardless of their values.
3. [ ] A rising desire-3 candidate never lists above a desire-1
   candidate of any trend.
4. [ ] Within the same desire level and trend group, the higher value
   lists first, then name — the `001` order, unchanged.
5. [ ] A rising row shows the reason line with the rounded percentage
   and the earlier reading's date; a falling row and a neutral row
   show none.
6. [ ] A row whose item has a current figure shows the market line with
   the median; the arrow appears only with a trend; a row whose item
   is unmatched, withheld, or whose figure is older than thirty days
   shows no market line.
7. [ ] The combined selected value is the sum of the person's values;
   changing an item's market figure changes nothing in it.
8. [ ] A trend of exactly +5 % counts as rising and exactly −5 % as
   falling; +4.9 % and −4.9 % are neutral (the `002` bands, shared).
9. [ ] Two points fewer than seven days apart produce no trend and a
   neutral rank; a plan with no trends anywhere is ordered exactly as
   `001` orders it, with no extra text.
10. [ ] Every new string passes `002`'s vocabulary rule for the fetched
    figure, and the reason line is read by VoiceOver in full.
11. [ ] At the largest accessibility text size the reason line wraps
    and the row's checkbox, dial and value stay aligned with rows that
    have no such line.
12. [ ] Under `-uiTesting` the seeded history produces at least one
    rising, one falling and one neutral candidate, so the UI test and
    the device pass exercise all three; in a normal launch nothing is
    seeded.

## Non-goals (explicit)

- **Trend lifting an item across desire levels** — Decision 1.
- **Any text on falling items, or any "sell now" language** —
  Decision 2 and the Sell Plan's founding principle.
- **A "plans trending up" line on the dashboard or the wishlist**, or
  any survey of plans in bulk — `009-sell-plan-list`'s ground.
- **Notifications** ("your Telecaster is trending up") — `002`'s
  non-goal, still.
- **New trend parameters, a longer look-back, or a magnitude ranking**
  (an item up 20 % above one up 6 %) — Decision 5; the history is a
  day old, and a richer model is a later spec once there is data to
  design it against.
- **Using the market median in the combined value, or as a fallback
  for an item with no value entered** — Decision 4.
- **Changing who qualifies as a candidate** — still desire 3 or lower
  with a value entered.
- **Marking anything as sold** — `006-mark-as-sold`.
- **Syncing history so that two devices agree** — `002` Decision 7.

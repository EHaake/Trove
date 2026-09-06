# 002 — Market Values

**Amendment B — the adopt flow — Approved 2026-09-05** ("Signed off on all decisions as is", the guidance sentence kept). Decisions 33–36, the amended Adopting and Refresh sections, criteria 8, 9 and 23, the Copy block "The value step" and the Design line are marked *(B)*. Drafted by Claude Code from the person's direction at the Phase 3 pause the same day.

Status: **Approved** (2026-09-03, the day after drafting; one
proposal — the year's cap on history — overturned at review as Decision
16, and the seventeen drafting proposals P1–P17 became decisions on
approval, as the Decisions record says they would). Authored in-session
at the person's direction — the third use of the per-spec venue clause —
over two days of design conversation (2026-09-02/03) that began with a
research pass into what the marketplaces actually offer, because the
answer reshaped the feature before a single product question could be
asked. Every product decision below was made by the person and is
listed in the Decisions record.

Amended 2026-09-03 at the plan review: Decisions 17–28 (below) were
made by the person against `plan.md`'s escalations, and criteria 10,
12, 14, 15 and 18, proposals P6, P9 and P11, the retention table and
the Copy section are reworded to match. `plan.md`'s proposals Q1–Q20
become decisions on plan approval, as P1–P17 did on this spec's.

Amended again 2026-09-03, during implementation (after T002): the
person folded **year narrowing** into this spec as Decision 29 — an
optional year on both kinds of item narrows the listings a figure is
computed from — with the details proposed as P18–P22 and the plan's
Amendment A. Criteria 21–22 added; criterion 19 and P17 reworded.

Depends on: `001-core-inventory` (the `Item` and `WishlistItem` models,
the optional manual value whose `nil` means "unvalued", the Sell Plan's
ranking hook), `010-item-management-enhancements` (the sort picker both
lists share), `011-data-export` / `012-data-import` (the canonical CSV
schema, which grows append-only and only together with its parser), and
`013-settings-menu` (Settings › About, where this spec's attribution and
contact obligations live; the in-page dropdown surface the new sort
option joins).

## What and why

The roadmap's `002-live-market-value` imagined resale values pulled from
eBay, Reverb or Facebook Marketplace to *replace* the value the user
types. The research that opened this spec (record at the end) found
that no source gives a non-partner app real sold prices in 2026: eBay's
sold-history API is closed to new developers and its licence forbids
using eBay content to model prices; Reverb withdrew its sold-based,
condition-aware price guide from its public API on 2026-07-17; Facebook
Marketplace has no read API of any kind; the used-camera dealers have
none. What remains, cleanly, is **Reverb's catalog and its active
listings**: a free-text name matches a product, and the listings for it
carry an asking price and a condition. Free, keyed to a catalog,
condition-tagged, and inside terms that allow display with a link back
and attribution.

So the honest version of this feature is a **market indicator**, not a
valuation: for a matched item, the median of current *asking* prices on
Reverb for gear in a condition like yours, with the spread and the count
— shown beside the value you entered, which stays the number the app
trusts, with one tap to adopt the figure as your own. Music gear gets it
in this spec. Cameras and hi-fi wait for an eBay follow-up with
prerequisites of its own (Decision 1). The trend it accumulates over
time is the raw material `003-trend-aware-sell-plan` needs.

## Core behavior

An item — owned or wanted (Decision 5) — can be **matched** to a Reverb
catalog product, once, by the person: the app searches the catalog by
the item's name, shows the candidates, the person picks one, and the
match is remembered on the item (Decision 3). A matched item can be
**refreshed**, on demand only (Decision 4), which fetches Reverb's
current listings for that product and computes the indicator. The
indicator appears on the item's detail screen beside the person's own
value, on the list row as a trend mark, in a new sort option, and as a
market variant of the dashboard's current-value figure (Decision 11).
The person's own value never changes unless they **adopt** the figure
with one tap (Decision 2).

### The match

- Searching sends the item's name to Reverb and nothing else about it.
  The first time the person searches, a one-time notice says exactly
  that — what is sent, to whom, and that the privacy policy has the
  rest — and they continue or don't (Decision 14). Never shown again;
  Settings › About carries the same words permanently.
- Candidates show what Reverb knows: the product's title, brand, an
  image, its current lowest used asking price and how many are listed.
  Picking one stores the product on the item. An item can be re-matched
  or unmatched at any time from its market section (P11).
- The match is the person's own data — an identifier — and syncs with
  the item (P1). Nothing fetched from Reverb syncs.
- An unmatched item shows no indicator anywhere: no figure, no trend
  mark, no dashboard contribution, and it sorts last under the market
  sort.

### The figure

- For an owned item: the **median** asking price of Reverb's current
  listings for the matched product whose condition maps to the item's
  own (P2), with the **low–high spread** and the **count** of listings
  it was computed from — "$1,450 · 12 listed · $1,100–$2,000" (Decision
  6).
- For a wanted item, which has no condition: the same over all used
  listings for the product (P16).
- Fewer than three matching listings withholds the figure: the section
  says so and offers the catalog's overall lowest used asking price
  instead, labelled as such (Decision 6).
- Only listings priced in the app's currency count (P3).
- An item with a **year** — optional, on owned and wanted items alike —
  narrows the listings to those whose stated year covers it: a single
  year, a range ("1970 - 1984", "2020 - Present") or a decade ("1970s").
  A listing that states no year still counts; only a stated mismatch is
  excluded (Decision 29). If fewer than three listings remain after
  narrowing, the figure is computed over all years and the section says
  so (Decision 29; P19).
- The figure is always framed as **asking prices on Reverb** — never as
  the item's value, worth, or price (P10). It carries its age ("as of
  2 hours ago") and a link to the product on Reverb (P9).

### Where it appears

- **Detail screens** (both kinds): a "Market" section with the figure,
  its age, the Reverb link, the adopt action, and the match actions.
- **List rows**: for owned items the row keeps its "+$550 vs paid"
  reading of the person's own value, and gains a small **trend arrow**
  beside it once a trend exists (Decision 8); wanted items gain the same
  arrow beside their estimated cost (P4). No arrow without a trend.
- **Sorting**: one new option on both lists — by market figure,
  descending and ascending, with unmatched or withheld items last in
  their custom order (Decision 9).
- **Dashboard**: a market variant of the current-value figure — the sum
  of market medians over the owned items that have one — **with its
  coverage stated** ("12 of 34 items" — the items in the sum, Decision
  22), never presented as comparable to the total without that
  qualifier (Decision 15; form from the design pass, P5). Spent and
  gain stay on the person's values.

### Adopting

- *(B)* Adopting happens in the sheet's **value step** (Decision 34):
  after a pick's refresh lands with a figure — or when the section's
  "Use as my value" / "Use as estimated cost" is tapped later — the
  sheet shows the figure and a **slider** over the trimmed range of
  asking prices (Decision 36), defaulting to the median with the low,
  median and high marked. One filled button writes the chosen amount,
  rounded to whole currency, into the person's own value and marks the
  item edited (P6); **Not now** writes nothing. From then on it is
  simply their value — the app records no provenance, and every figure
  that reads the value (totals, the Sell Plan pool, the row's vs-paid)
  reads it as before.
- *(B)* The slider sets the person's value only (Decision 35): the market
  figure stays the median everywhere — the section, the history, the
  trend, the dashboard — whatever amount the person adopts.
- Adopting does not touch the history (P6), and does not refresh.

### Refresh and budget

- Refresh is a deliberate act: the market section's refresh on either
  detail screen, "Refresh market values" in Settings, which walks
  every matched item in turn with visible progress and stops cleanly
  when Reverb's rate limit answers (P7), and *(B)* **the pick of a
  match**, which refreshes that product at once in the same sheet
  (Decision 33). The app never fetches in the background, on launch, or
  on appear (Decision 4).
- An item refreshed within the last hour isn't fetched again; the
  section shows the age it has (P7).
- Offline or failed: the last figure stays, with its age, and the
  section says the refresh couldn't reach Reverb (P8).

### History and trend

- Every refresh that yields a median keeps its summary — median, low,
  high, count, and when — on the device, from the first refresh on
  (Decision 7; a withheld refresh adds no point, Decision 23). Nothing
  from the listings themselves (no listing, seller, title or image) is
  kept (P14).
- The **trend** exists once two points at least seven days apart exist,
  comparing the latest to the previous such point: up at 5 % or more,
  down at −5 % or less, flat between — and flat shows nothing (P12).
- History stays on the device and does not sync (Decision 7): a second
  device builds its own. It is kept for **as long as the item stays
  matched — no time limit** (Decision 16): the longer it runs, the more
  `003`'s trend analysis has to work with. Separately, a displayed
  figure older than thirty days is no longer shown as current — nor
  sorted or summed (Decision 21) — only its history point kept (P13).
  Unmatching an item, or changing its match to a different product,
  clears its history (P11, Decision 26).

### Retention, sync and privacy — what is stored where

| What | Where | Syncs? |
|---|---|---|
| The match (Reverb product identifier) | on the item | yes — the person's own data |
| The item's year, when the person gives one | on the item | yes — the person's own data |
| The last figure (median, low, high, count, fetched-at, the year it narrowed to; *(B)* the trimmed bounds the slider runs between — Decision 36) | on the device | no |
| The matched product's catalog slug and title, for the link-back (Decision 20) | on the device | no |
| The history of figures | on the device | no |
| Anything from a listing (title, seller, image, listing id) | nowhere | — |
| The person's value, adopted or typed | on the item, as today | yes, as today |

What leaves the device: an item's name (search) and a product
identifier (refresh), to Reverb, only when the person acts. Neither the
condition nor the year leaves the device: both are applied on the
listings after they arrive (Decisions 29, 31). The privacy policy says
exactly this (Decision 13).

### Settings › About, and the terms

Reverb's API terms put four things on the app, all of which land in
Settings › About and the market section (research record, below):

- the attribution line, verbatim: *"This application uses the Reverb
  API but is not endorsed, created by or certified by Reverb.com,
  LLC."* (P9);
- a displayed contact email — a dedicated address for the app
  (Decision 12; the address itself is fixed at planning);
- a privacy policy of the app's own — `PRIVACY.md` in the repository,
  published through GitHub Pages and linked from About (Decision 13;
  the GitHub blob URL first, Pages later — Decision 18);
- a link back to the product on Reverb wherever its data is shown, the
  candidate picker included (P9, Decision 28).

And two things the app must not do: keep Reverb's content beyond a
reasonable period (the retention rules above are the reading), and use
the API for analytics, machine learning or scraping — the per-item
figures shown to the person are the whole of what is computed, and
nothing crosses items (see Non-goals).

## Copy

- Section title **Market**; source line **On Reverb** — with the
  product's title and, when the item has a year, the year: "On Reverb ·
  Martin D-18 · 1975" (Decisions 20, 29); the figure as
  "$1,450 · 12 listed"; the spread as "$1,100–$2,000"; the age "as of 2
  hours ago" / "as of 3 days ago".
- Withheld: "Too few listings in this condition to say. The lowest used
  asking price on Reverb is $1,100."
- Narrowed to all years (Decision 29): "Too few 1975 listings in this
  condition — all years shown." above the figure, which is then the
  all-years figure.
- The year field, on both forms: label **Year**, optional, four digits.
- Actions: **Find on Reverb…** (unmatched), **Refresh**, **Use as my
  value** / **Use as estimated cost**, **Change match…**, **Remove
  match**.
- The one-time notice: "Finding a match sends this item's name to
  Reverb — nothing else about it. Refreshing later sends only which
  product it is — your item's details stay on this device. See the
  privacy policy." with **Continue** and **Not now** (P15; wording
  Decision 31).
- Failure: "Couldn't reach Reverb. The figure below is from {age}."
- Rate limit: "Reverb is asking us to slow down. Try again in a while."
- The Settings walk stopped by any other failure: "Couldn't reach
  Reverb. 3 of 12 refreshed." (Decision 27).
- The dashboard variant: "Market · $18,400 · 12 of 34 items" (Decision
  22).
- Copy this spec doesn't give — the never-refreshed line, the wanted
  item's withheld sentence, the picker's strings, the link label — is
  proposed in `plan.md` (Q7) and joins this section on plan approval.
- *(B)* **The value step** (Amendment B): the status line while a pick's
  refresh runs, "Fetching asking prices…"; the step's title **Set your
  value** (owned) / **Set your estimated cost** (wanted); the figure as
  the section shows it ("$1,450 · 12 listed", "$1,100–$2,000"); the
  slider's ends labelled with their amounts and its median mark
  "median"; the guidance line "Drag toward the high end if yours is in
  better shape than most."; the filled button **Use $1,450 as my value**
  / **Use $349 as estimated cost** (the amount live as the slider
  moves); the other button **Not now**. Accessibility: the slider is
  "Your value" / "Your estimated cost" with the amount as its value and
  the hint "Slides between the lowest and highest asking prices."; the
  marks read "lowest asking price $1,100", "median asking price $1,450",
  "highest asking price $2,000". *(Q22, plan Amendment B, pending the person's answer at T020: once there are enough listings the slider's ends are the trimmed bounds, not the lowest and highest — the high end from ten listings, the low end from eleven; the proposed wording is "typical low asking price $1,150" / "typical high asking price $1,900" and "Slides between the typical low and high asking prices." — the code carries the proposal, marked pending, until this block is amended.)*

## Design requirements

- A **Design pass, in-session with the `design` skill** (Decision 10;
  run through `/design` by the person with a prompt Claude Code writes
  at the design task — Decision 17),
  for the three new surfaces: the candidate picker (title, brand, image,
  price, count — a designed choice, not a list of rows), the detail
  screens' Market section (a figure, a spread, an age, an external
  link, an adopt action), and the dashboard's market variant (P5). The
  design brief's rules apply: bespoke inside the page, the app's own
  type and tokens, no rendered materials.
- The list rows' **trend arrow** needs no Design pass (Decision 8): a
  small glyph beside the existing delta, in the row's existing quiet
  tones — moss up, rust down, as the value delta already reads.
- The new sort option joins the existing dropdown as two rows in the
  vocabulary `010` set.
- The **Year** field joins both forms' Details in the forms' existing
  field style — no Design pass (Decision 29).
- The candidate picker shows each candidate's **whole title**, never
  truncated — Reverb's variants differ by a suffix ("Left-Handed",
  "FSR Limited Edition", "1970 - 1984") — and asks for enough
  candidates that the exact variant is on the list when Reverb has it.
- Every action is a single tap; the Reverb link opens the product page
  in the browser.
- *(B)* One frame for the sheet's value step (Amendment B): the figure,
  the slider with its three marks, the guidance line and the two
  buttons — a thin track and marks in the app's instrument language, no
  rendered materials; the slider is Trove's own control, not a system
  `Slider`, since it sits inside the page.

## Decisions record

Made by the person, 2026-09-02/03, in the design conversation:

1. **Reverb only; eBay deferred to its own spec.** No source offers
   sold prices to a non-partner. Reverb's catalog and listings are free,
   catalog-keyed, condition-tagged and inside their terms. eBay's active
   listings are reachable but its production access is documented as
   partner-only, its licence forbids modelling prices from its content
   and requires visual isolation and no persistence, and its token flow
   needs a secret that cannot ship in an iOS app — so an eBay follow-up
   spec has two prerequisites: a hosted proxy service, and a decision to
   accept that access. Building a crawler was declined: it breaches
   every relevant site's written terms and adds a server and a new
   privacy posture. Cameras and hi-fi wait.
2. **Indicator beside your value, one tap to adopt.** The person's
   value stays the persisted, synced number every total and the Sell
   Plan use; the fetched figure is a timestamped indicator with "Use
   this".
3. **Search, pick once, remember.** The app searches Reverb's catalog by
   name, the person confirms one candidate, the product is stored on the
   item; refreshes are lookups by product, never fuzzy searches.
4. **On demand only.** A refresh on the detail screens and a Settings
   action for every matched item; no launch, appear or background
   fetching. Reverb's limit is per app, not per user.
5. **Owned and wanted items** both get the indicator — the buy-side
   half `003` will need.
6. **Median with spread and count**, not the lowest asking price;
   withheld under three matching listings, with the catalog's lowest
   used price offered instead.
7. **History from day one, on device, unsynced**; the trend appears
   once two points at least a week apart exist.
8. **Rows keep "vs paid" on the person's value and gain a trend arrow**
   beside it; no Design pass for the arrow.
9. **One new sort**, by market figure, unmatched last.
10. **A Design pass, kept in Claude Code** with the `design` skill,
    for the picker, the Market section and the dashboard variant.
11. **Where**: detail screens, list rows, the sort, the dashboard
    variant.
12. **A dedicated contact address for the app**, shown in About; the
    address is fixed at planning.
13. **`PRIVACY.md` in the repository, published via GitHub Pages**,
    linked from About.
14. **A one-time notice before the first search**, with the policy
    link.
15. **A market variant of the dashboard's current-value figure**, with
    its coverage stated.

Added 2026-09-03, at the draft's review (the person):

16. **History has no time limit.** The draft proposed keeping a year;
    the person extended it: a matched item's history is kept for as
    long as the match exists, and only unmatching clears it. The
    thirty-day rule below is about how long the *last figure* shows as
    current, not about the history.

Added 2026-09-03, at the plan review (the person), against `plan.md`'s
escalations:

17. **The Design pass runs through `/design`, invoked by the person**
    with a prompt Claude Code writes at the design task; the exports
    land under `design/elements/002-market-values/` as 010's did, and
    `tokens.md` is sourced from them.
18. **The privacy policy links to the GitHub blob URL first**
    (`https://github.com/EHaake/Trove/blob/main/PRIVACY.md`), which
    works the moment the branch merges; GitHub Pages later, as one
    `fix/` commit swapping the URL. Decision 13's venue is deferred,
    not dropped.
19. **`CLAUDE.md` is amended now, in its own commit on the branch,
    before implementation** — the constitution's "amend first" rule
    wins over `DECISIONS.md`'s post-merge routing for an amendment a
    spec contradicts; `DECISIONS.md` records the reconciliation
    post-merge.
20. **The device stores the matched product's catalog slug and title**
    (with its lowest used price and when taken), unsynced, because the
    link-back is slug-based and Decision 4 forbids fetching on appear.
    Criterion 18 says so.
21. **Stale figures (over thirty days) drop out everywhere**: the sort,
    the dashboard sum and the section. Criteria 14 and 15 read
    "current".
22. **The dashboard's N counts the items in the sum**, and the copy
    reads "12 of 34 items", so the word and the number agree.
23. **A withheld refresh adds no history point**; it still updates the
    section's age and lowest-used figure and counts for the hour
    budget. Criterion 12 reads "each refresh that yields a median".
24. **P6 is scoped to owned items**: adopting bumps the edited time
    where the item has one; `WishlistItem` gains no field.
25. **The contact address is supplied by the person before the copy
    task**; a test fails on any placeholder, so it cannot ship unfilled.
    Supplied 2026-09-04 as a **provisional** personal address; the
    person will replace it with a dedicated one before the app is
    published (one constant, `MarketCopy.contactAddress`).
26. **Changing the match to a different product clears the history**;
    re-picking the same product keeps it. History belongs to the match.
27. **The Settings walk stops on the first failure of any kind**, with
    "Couldn't reach Reverb. 3 of 12 refreshed." for a failure that is
    not the rate limit. Criterion 10 says so.
28. **Candidates in the picker link back to Reverb**; P9 reads
    "wherever Reverb's data is shown". The Design pass decides the
    form.

Added 2026-09-03, during implementation (the person):

29. **Year narrowing, in this spec.** Reverb's catalog separates many
    variants (the D-18 alone is three products), so the pick carries
    most of the precision; where a catalog product lumps years, an
    optional **year** on the item narrows the listings a figure is
    computed from. Two rules the person chose against a live probe
    (Telecaster listings: about half state no year; the rest single
    years, ranges and decades; a vintage D-18: nearly all labelled):
    a listing with no stated year **still counts**, only a stated
    mismatch is excluded; and when fewer than three remain, the figure
    **falls back to all years and says so**, rather than withholding.
    The year is the person's own data and syncs; it never leaves the
    device. The field is optional on both kinds of item and gets no
    Design pass.

Added 2026-09-04, at the Phase 1 pause (the person, on two items the
skeptical-reviewer escalated):

30. **Delete All clears only what it deletes.** Emptying a list from
    Settings clears the device's market rows — figure, history,
    snapshot — for the items it deletes, and nothing more: the other
    list's rows and the one-time notice's acknowledgement stay. Delete
    All removes these items; it does not reset the device, and the
    notice was acknowledged once per device for terms that haven't
    changed. The alternative — every local table and the flag,
    whichever list is emptied — was what Phase 1 shipped and is
    reversed here.
31. **The notice's second sentence names what actually leaves.** A
    refresh sends Reverb the product identifier and nothing about the
    item: the condition, like the year, is applied on the device to the
    listings after they arrive (the product-scoped listings endpoint
    ignores condition parameters, so the client sends none — recorded
    in the fixtures' README at T002). The earlier wording, "sends only
    the product and your item's condition", overstated what leaves.
    The notice now reads: "Finding a match sends this item's name to
    Reverb — nothing else about it. Refreshing later sends only which
    product it is — your item's details stay on this device. See the
    privacy policy." The retention paragraph and `PRIVACY.md` (T018)
    say the same.

Added 2026-09-05, at the Phase 4 pause (the person):

32. **The year is the year the piece was made.** A 2023 reissue of a
    1961 model carries 2023; that it is a reissue of a '61 belongs in
    the item's name or notes, not the year. This is what the listing
    narrowing needs (Reverb's listing years are build years) and what
    `docs/csv-reference.md` already said at T016b; P18 now says it too.

Added 2026-09-05, Amendment B — the adopt flow (the person's direction at
the Phase 3 pause, drafted by Claude Code, **approved by the person the
same day**):

33. **A pick refreshes.** Choosing a candidate fetches that product's
    listings at once, in the same sheet, with a status line while it
    runs. This is the person's own tap: criterion 9's list of fetches
    the app never makes — launch, appear, background, within the hour —
    is unchanged, and the pick joins the section's Refresh and Settings'
    walk as the third deliberate act. A re-picked product whose figure
    is under an hour old is not fetched again (P7); the sheet goes
    straight to the value step. If the refresh fails, the sheet closes
    to the section, which shows the failure line as today; the match
    stands.
34. **Adopting happens in the sheet, with a slider.** With a figure in
    hand the sheet's third phase — the value step — shows the figure, a
    slider defaulting to the median with the low, median and high
    marked, a one-line guidance sentence, and two buttons: the filled
    one writes the chosen amount as the person's value and closes the
    sheet; **Not now** closes without writing. The section's "Use as my
    value" / "Use as estimated cost" opens the same step later, so there
    is one adopt control. A withheld or stale reading offers no value
    step, as it offers no adopt today. Three taps become one flow: pick,
    adjust, use.
35. **The slider sets the person's value only.** The market figure stays
    the median: the section shows it, the history records it, the trend
    compares it, the dashboard sums it. The chosen amount is written
    exactly as a typed value would be — no provenance, no history write
    — so trending is untouched by what anyone adopts (P6, Decision 7).
36. **The slider's bounds are trimmed.** One mispriced or bundled
    listing drags an extreme, so the slider runs from the 10th to the
    90th percentile of the counted listings' asking prices (nearest
    rank, whole currency), which for small counts coincide with the low
    and high; the text spread beside it stays the true low–high. The
    edit form still takes any amount by hand. A wrong *product* is not a
    range problem: Change match is the fix, and the picker's count and
    lowest price are there to make a doubtful candidate visible before
    the pick.

Proposed at drafting, 2026-09-03, by Claude Code, and decisions since
the spec's approval the same day (P13 as reworded under Decision 16):

- **P1. The match syncs; fetched figures and history don't.** The
  product identifier is the person's own data.
- **P2. Condition mapping**, Trove → Reverb: new → Brand New / Mint;
  excellent → Excellent; good → Very Good / Good; fair → Fair; broken →
  Poor / Non-functioning. Verified against Reverb's actual condition
  list at planning; refined there if it differs.
- **P3. Currency**: only listings priced in the app's currency (USD)
  count; the count is of what counted.
- **P4. Wanted items' rows** get the trend arrow beside the estimated
  cost and no other mark.
- **P5. The dashboard variant's form** is the design pass's — a second
  line under the current-value figure or a toggle — but the coverage
  qualifier is mandatory and inseparable from the number.
- **P6. Adopting** writes the whole-currency median *(B: the amount chosen on the slider, the median by default — Decisions 34–35)*, bumps the item's
  edited time where it has one (owned items — Decision 24), records no
  provenance, and leaves the history alone.
- **P7. Budget**: an item refreshed within the hour isn't re-fetched;
  the Settings action walks matched items in sequence, shows progress,
  and stops at the first rate-limit answer with the copy above.
- **P8. Failure** leaves the last figure with its age and says why.
- **P9. Attribution and link-back** as the terms state: the attribution
  line in About, a link to the product on Reverb wherever Reverb's data
  is shown — a figure, or a candidate in the picker (Decision 28).
- **P10. Vocabulary**: "Market", "On Reverb", "asking prices" — never
  "value", "worth" or "price" for the fetched figure; the sort reads
  "Market ↓" / "Market ↑".
- **P11. Re-match and unmatch** from the section; unmatching, or
  changing to a different product, clears the item's history (Decision
  26).
- **P12. Trend**: latest median against the previous point at least
  seven days older; up at +5 % or more, down at −5 % or less; flat shows
  nothing.
- **P13. Freshness**: a displayed figure no older than thirty days —
  after that the section shows only that a refresh is due, and the
  figure survives as a history point. (The draft also proposed a
  one-year cap on history; Decision 16 removed it.) The history holds
  the app's own summary numbers, not Reverb's content, which is the
  reading of "reasonable periods" in Reverb's terms that planning's
  skeptical review confirms or tightens.
- **P14. Nothing from a listing is stored** — only the app's own
  summary numbers and the product identifier.
- **P15. The notice's copy** as written above.
- **P16. Wanted items** use all used listings of the product, since
  they carry no condition.
- **P17. Export carries the match, not the figures.** The canonical CSV
  gains two columns, the Reverb product identifier and the year
  (Decision 29), so an export and re-import restores matches and years;
  adopted values are already there. Fetched
  figures and history are not exported, in either format — they are
  Reverb-derived and time-bound. `011`'s append-only rule applies:
  the column lands together with `012`'s parser.

Proposed 2026-09-03 with Decision 29, by Claude Code (approved with
the plan's Amendment A):

- **P18. The year** is a whole number of four digits, optional, on
  `Item` and `WishlistItem`; blank means "any year". The forms validate
  it as 1900 through next year. It is **the year the piece was made**
  (Decision 32): a 2023 reissue of a 1961 model is 2023 — that it is a
  reissue belongs in the name or the notes.
- **P19. Coverage**: a listing's stated year covers the item's year when
  it is that year, a range containing it ("1970 - 1984"; "2020 -
  Present" reaches the current year), or its decade ("1970s"). A stated
  year that cannot be read counts as a mismatch. Narrowing runs after
  the currency and condition filters.
- **P20. The fallback figure** is the same computation over all years,
  shown under the all-years copy; it sorts, sums and adopts as any
  figure does, and its history point is an ordinary point.
- **P21. Changing the year** does not clear the history — the match is
  the same product. The figure remembers the year it narrowed to, so the
  section can say so after the item's year changes.
- **P22. The picker** asks Reverb for fifteen candidates and shows each
  title whole.

## Acceptance criteria

1. [ ] On an owned item's detail screen and on a wanted item's, an
   unmatched item shows a Market section with **Find on Reverb…** and
   nothing else; the list row shows no arrow; the item sorts last
   under Market; it contributes nothing to the dashboard variant.
2. [ ] The first **Find on Reverb…** in the app shows the one-time
   notice; **Not now** searches nothing; **Continue** searches and the
   notice never shows again, on any item, on that device.
3. [ ] Searching sends the item's name and nothing else; candidates
   show title, brand, image, lowest used asking price and listed
   count, from Reverb; picking one stores the match, which appears on
   every device the item syncs to.
4. [ ] Refreshing a matched owned item shows the median of Reverb's
   current asking prices for listings in a condition mapped from the
   item's, the low–high spread, the count, the age, and a link that
   opens the product on Reverb.
5. [ ] With fewer than three matching listings the figure is withheld
   and the section shows the withheld copy with the catalog's lowest
   used asking price, labelled as such.
6. [ ] A wanted item's figure is computed over all used listings of
   the product.
7. [ ] Only listings in the app's currency count, and the count
   reflects that.
8. [ ] *(B)* **Use as my value** writes the amount chosen on the value
   step's slider — the whole-currency median by default — into the
   item's value; the dashboard total, the row's vs-paid and the Sell
   Plan pool then read it exactly as a typed value; **Use as estimated
   cost** does the same for a wanted item's cost. Adopting neither
   refreshes nor changes the history.
9. [ ] *(B)* No fetch happens on launch, on appear, in the background, or
   within an hour of an item's last refresh; refreshing is only the
   section's action, Settings' **Refresh market values**, or the pick
   of a match in the sheet (Decision 33).
10. [ ] Settings' refresh walks every matched item with visible
    progress and stops cleanly, with the rate-limit copy, when Reverb
    answers with its limit — and, with "Couldn't reach Reverb. N of M
    refreshed.", on the first failure of any other kind (Decision 27);
    items already refreshed stay refreshed.
11. [ ] Offline, the last figure stays with its age and the failure
    copy; nothing is cleared.
12. [ ] Each refresh that yields a median adds a history point on the
    device, and a withheld refresh adds none (Decision 23); a second
    device shows no history from the first; the history never appears
    in the CloudKit store.
13. [ ] With two points at least seven days apart, the row shows an up
    arrow at +5 % or more, a down arrow at −5 % or less, and nothing
    between; with one point, or two closer than a week, nothing.
14. [ ] The Market sort orders matched items by their current median
    (under thirty days old — Decision 21), descending and ascending,
    with unmatched, withheld and stale items last in custom order, on
    both lists.
15. [ ] The dashboard shows the market variant as the sum of current
    medians over matched owned items with one, always with "N of M
    items" where N is the items in the sum (Decisions 21–22); spent,
    gain and the category breakdown stay on the person's values.
16. [ ] A displayed figure older than thirty days is no longer shown
    as current; history is never trimmed by age; unmatching clears the
    item's history and figure.
17. [ ] Settings › About shows the attribution line verbatim, the
    contact address, and a link to the privacy policy; the policy
    exists in the repository, is published, and states what leaves the
    device and what is stored.
18. [ ] Nothing from a listing — title, seller, image, listing
    identifier — is stored anywhere; a scan of the persisted data after
    a refresh finds only the app's summary numbers, the product
    identifier, and the product's catalog slug and title (Decision 20).
19. [ ] The canonical CSV gains the product-identifier and year
    columns at the end; an export followed by an import restores the
    match and the year; the fetched figures appear in neither the CSV
    nor the PDF.
20. [ ] VoiceOver: the Market section reads as its parts — the figure,
    the spread, the count, the age — every action is labelled, the
    trend arrow reads "trending up" / "trending down", and the Reverb
    link says it leaves the app.
21. [ ] An item with a year computes its figure over the listings whose
    stated year covers it plus those stating none; a listing stating a
    year that does not cover it is excluded, and the count says how many
    counted. An item without a year is unchanged.
22. [ ] With fewer than three listings after narrowing, the section
    shows the all-years figure under the all-years copy; clearing the
    year restores the plain figure on the next refresh.
23. [ ] *(B)* Picking a candidate refreshes it in the sheet with the
    status line and, with a figure, shows the value step: the slider
    defaults to the median between trimmed bounds with the true spread
    beside it; the filled button writes the chosen amount and closes the
    sheet; **Not now** writes nothing; the section's adopt action opens
    the same step; the history point that refresh recorded is the
    median, whatever amount was chosen.

## Non-goals (explicit)

- **Sold prices, from any source** — none is available to this app;
  every figure here is an asking price and says so.
- **eBay** — its own follow-up spec, prerequisites: a hosted proxy
  service holding the credentials, and a decision to accept documented
  partner-only production access; and then only as an isolated,
  linked, unstored listings panel, never a computed figure.
- **Any crawler or scraper**, hosted or on-device.
- **Cameras, hi-fi, and every category Reverb doesn't carry** — no
  indicator in this spec.
- **Automatic matching** — the person always picks.
- **Background, launch or appear refresh** — Decision 4.
- **Syncing fetched figures or history** — Decision 7; and any
  cross-item analytics over Reverb's data, which its terms forbid.
- **Trend-aware Sell Plan ranking** — `003`, which this spec's history
  is built to feed.
- **Currency conversion** — USD-only, as the app is.
- **A market figure in the row's delta, or replacing the person's
  value** — Decisions 2 and 8.
- **Notifications** ("your Telecaster is trending up").
- **Provenance on adopted values** — once adopted, it's the person's.

## Inherited caveats

- `001`'s fixed type sizes apply to the new surfaces.
- The app is USD-only; P3 follows from it.
- `011`'s append-only schema rule governs P17's column.
- `013`'s in-page dropdown carries the new sort rows; its two-tap
  switching and animation apply unchanged.

## Research record (2026-09-02/03)

Two research passes preceded the product decisions; their findings are
what Decision 1 and the terms section rest on. Live probes were made on
2026-09-02 against the public endpoints; developer-site pages were read
the same day and the next.

- **Reverb.** The catalog search (`/api/csps`) answers unauthenticated
  and returns, per product, the identifier, title, brand, root category,
  the lowest used and lowest new asking prices and the counts, a web
  link, and pre-built listing queries. The listings search returns
  active listings with make, model, year, finish, a condition display
  name, and price, filterable by condition. The price-guide endpoint,
  which gave a sold-based, condition-aware range, answers 403 "This
  endpoint is no longer publicly available" — withdrawn 2026-07-17 per
  a third-party record; the API root still links it. Rate limit: about
  10,000 calls a day, 2,000 a minute, per app. Terms of use (effective
  2022-07-01): link directly back to the product on Reverb; a
  prominently displayed email address; the app's own terms and privacy
  policy; the attribution line verbatim; no caching or storing beyond
  "reasonable periods"; no collecting content for analytics, machine
  learning or licensing; no screen-scraping "even if such data is not
  available in the API"; no charging for the integrated part.
- **eBay.** The Browse search returns fixed-price ("Buy It Now")
  listings by default, with price, a numeric condition scale, a link,
  images and seller feedback; filters by condition, price and country;
  no sold data anywhere in it. Sold history is the Marketplace Insights
  API, "restricted and not open to new users at this time". The Buy
  APIs requirements page says production use is "intended for eBay
  partners only" through an affiliate application with "no guarantee";
  eBay's own affiliate questionnaire says the Browse API needs no
  additional approval; developers report production keys working. The
  API licence (revised 2025-06-24): eBay content in a public display
  "may not be co-mingled or combined with non-eBay content" and must be
  deleted "when the eBay Content is no longer publicly available"; only
  "limited intermediate copies" may be made; displayed listings may be
  no more than six hours old; and, verbatim, "Use eBay Content, either
  alone or in combination with third-party information, to suggest or
  model prices for items listed on eBay Site" is a restricted activity,
  with a 2025 consent regime for pricing tools. The token flow needs the
  client secret, and eBay's own guidance is that native apps cannot
  hold it and must use a backend; the budget is 5,000 calls a day per
  app. Product identifiers appear only on catalog-matched listings, and
  the catalog search needs the person's own eBay sign-in.
- **Facebook Marketplace**: no read API; the only Marketplace API lets
  approved partners upload their own listings.
- **Others**: KEH, MPB, Sweetwater's exchange and Guitar Center's used
  market have no public API; Discogs offers per-condition price
  suggestions for records only, through the person's own seller login,
  with a six-hour freshness rule — relevant only if records enter
  scope.
- **Building a crawler** was assessed and declined: every relevant
  site forbids it in writing, it adds a hosted server and moves item
  names off the device to a machine the app's author runs, and it
  still yields asking prices.

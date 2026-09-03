# 002 — Market Values

Status: **Draft** (2026-09-03). Authored in-session at the person's
direction — the third use of the per-spec venue clause — over two days
of design conversation (2026-09-02/03) that began with a research pass
into what the marketplaces actually offer, because the answer reshaped
the feature before a single product question could be asked. Every
product decision below was made by the person and is listed in the
Decisions record; a set of smaller calls was proposed at drafting and
is marked as such there, so the review can accept or overturn each one
explicitly rather than by omission.

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
  coverage stated** ("12 of 34 items matched"), never presented as
  comparable to the total without that qualifier (Decision 15; form
  from the design pass, P5). Spent and gain stay on the person's
  values.

### Adopting

- "Use as my value" (owned) / "Use as estimated cost" (wanted) writes
  the median, rounded to whole currency, into the person's own value and
  marks the item edited (P6). From then on it is simply their value —
  the app records no provenance, and every figure that reads the value
  (totals, the Sell Plan pool, the row's vs-paid) reads it as before.
- Adopting does not touch the history (P6), and does not refresh.

### Refresh and budget

- Refresh is a deliberate act: the market section's refresh on either
  detail screen, and "Refresh market values" in Settings, which walks
  every matched item in turn with visible progress and stops cleanly
  when Reverb's rate limit answers (P7). The app never fetches in the
  background, on launch, or on appear (Decision 4).
- An item refreshed within the last hour isn't fetched again; the
  section shows the age it has (P7).
- Offline or failed: the last figure stays, with its age, and the
  section says the refresh couldn't reach Reverb (P8).

### History and trend

- Every refresh keeps its summary — median, low, high, count, and when
  — on the device, from the first refresh on (Decision 7). Nothing from
  the listings themselves (no listing, seller, title or image) is kept
  (P14).
- The **trend** exists once two points at least seven days apart exist,
  comparing the latest to the previous such point: up at 5 % or more,
  down at −5 % or less, flat between — and flat shows nothing (P12).
- History stays on the device and does not sync (Decision 7): a second
  device builds its own. It is kept for **as long as the item stays
  matched — no time limit** (Decision 16): the longer it runs, the more
  `003`'s trend analysis has to work with. Separately, a displayed
  figure older than thirty days is no longer shown as current, only its
  history point kept (P13). Unmatching an item clears its history (P11).

### Retention, sync and privacy — what is stored where

| What | Where | Syncs? |
|---|---|---|
| The match (Reverb product identifier) | on the item | yes — the person's own data |
| The last figure (median, low, high, count, fetched-at) | on the device | no |
| The history of figures | on the device | no |
| Anything from a listing (title, seller, image, listing id) | nowhere | — |
| The person's value, adopted or typed | on the item, as today | yes, as today |

What leaves the device: an item's name (search) and a product
identifier plus a condition filter (refresh), to Reverb, only when the
person acts. The privacy policy says exactly this (Decision 13).

### Settings › About, and the terms

Reverb's API terms put four things on the app, all of which land in
Settings › About and the market section (research record, below):

- the attribution line, verbatim: *"This application uses the Reverb
  API but is not endorsed, created by or certified by Reverb.com,
  LLC."* (P9);
- a displayed contact email — a dedicated address for the app
  (Decision 12; the address itself is fixed at planning);
- a privacy policy of the app's own — `PRIVACY.md` in the repository,
  published through GitHub Pages and linked from About (Decision 13);
- a link back to the product on Reverb wherever its data is shown (P9).

And two things the app must not do: keep Reverb's content beyond a
reasonable period (the retention rules above are the reading), and use
the API for analytics, machine learning or scraping — the per-item
figures shown to the person are the whole of what is computed, and
nothing crosses items (see Non-goals).

## Copy

- Section title **Market**; source line **On Reverb**; the figure as
  "$1,450 · 12 listed"; the spread as "$1,100–$2,000"; the age "as of 2
  hours ago" / "as of 3 days ago".
- Withheld: "Too few listings in this condition to say. The lowest used
  asking price on Reverb is $1,100."
- Actions: **Find on Reverb…** (unmatched), **Refresh**, **Use as my
  value** / **Use as estimated cost**, **Change match…**, **Remove
  match**.
- The one-time notice: "Finding a match sends this item's name to
  Reverb — nothing else about it. Refreshing later sends only the
  product and your item's condition. See the privacy policy." with
  **Continue** and **Not now** (P15).
- Failure: "Couldn't reach Reverb. The figure below is from {age}."
- Rate limit: "Reverb is asking us to slow down. Try again in a while."
- The dashboard variant: "Market · $18,400 · 12 of 34 matched".

## Design requirements

- A **Design pass, in-session with the `design` skill** (Decision 10),
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
- Every action is a single tap; the Reverb link opens the product page
  in the browser.

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

Proposed at drafting, 2026-09-03, by Claude Code. These become decisions
on spec approval unless the person overturns them:

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
- **P6. Adopting** writes the whole-currency median, bumps the item's
  edited time, records no provenance, and leaves the history alone.
- **P7. Budget**: an item refreshed within the hour isn't re-fetched;
  the Settings action walks matched items in sequence, shows progress,
  and stops at the first rate-limit answer with the copy above.
- **P8. Failure** leaves the last figure with its age and says why.
- **P9. Attribution and link-back** as the terms state: the attribution
  line in About, a link to the product on Reverb wherever a figure is
  shown.
- **P10. Vocabulary**: "Market", "On Reverb", "asking prices" — never
  "value", "worth" or "price" for the fetched figure; the sort reads
  "Market ↓" / "Market ↑".
- **P11. Re-match and unmatch** from the section; unmatching clears the
  item's history.
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
  gains one column, the Reverb product identifier, so an export and
  re-import restores matches; adopted values are already there. Fetched
  figures and history are not exported, in either format — they are
  Reverb-derived and time-bound. `011`'s append-only rule applies:
  the column lands together with `012`'s parser.

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
8. [ ] **Use as my value** writes the whole-currency median into the
   item's value; the dashboard total, the row's vs-paid and the Sell
   Plan pool then read it exactly as a typed value; **Use as estimated
   cost** does the same for a wanted item's cost. Neither refreshes,
   neither changes the history.
9. [ ] No fetch happens on launch, on appear, in the background, or
   within an hour of an item's last refresh; refreshing is only the
   section's action or Settings' **Refresh market values**.
10. [ ] Settings' refresh walks every matched item with visible
    progress and stops cleanly, with the rate-limit copy, when Reverb
    answers with its limit; items already refreshed stay refreshed.
11. [ ] Offline, the last figure stays with its age and the failure
    copy; nothing is cleared.
12. [ ] Each refresh adds a history point on the device; a second
    device shows no history from the first; the history never appears
    in the CloudKit store.
13. [ ] With two points at least seven days apart, the row shows an up
    arrow at +5 % or more, a down arrow at −5 % or less, and nothing
    between; with one point, or two closer than a week, nothing.
14. [ ] The Market sort orders matched items by their latest median,
    descending and ascending, with unmatched and withheld items last in
    custom order, on both lists.
15. [ ] The dashboard shows the market variant as the sum of medians
    over matched owned items with a figure, always with "N of M
    matched"; spent, gain and the category breakdown stay on the
    person's values.
16. [ ] A displayed figure older than thirty days is no longer shown
    as current; history is never trimmed by age; unmatching clears the
    item's history and figure.
17. [ ] Settings › About shows the attribution line verbatim, the
    contact address, and a link to the privacy policy; the policy
    exists in the repository, is published, and states what leaves the
    device and what is stored.
18. [ ] Nothing from a listing — title, seller, image, listing
    identifier — is stored anywhere; a scan of the persisted data after
    a refresh finds only the app's summary numbers and the product
    identifier.
19. [ ] The canonical CSV gains the product-identifier column at the
    end; an export followed by an import restores the match; the
    fetched figures appear in neither the CSV nor the PDF.
20. [ ] VoiceOver: the Market section reads as its parts — the figure,
    the spread, the count, the age — every action is labelled, the
    trend arrow reads "trending up" / "trending down", and the Reverb
    link says it leaves the app.

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

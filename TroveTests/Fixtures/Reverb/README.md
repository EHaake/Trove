# Reverb fixtures

<!-- recorded:start -->
Recorded 2026-09-03 by `scripts/record-reverb-fixtures.sh` from the public
Reverb API, unauthenticated, trimmed to the fields the app reads. Read
by `TroveTests` through `#filePath`, the way `DocsSampleTests` reads
`docs/samples/`. Never fetched by a test or by the build; re-record by
hand and review the diff.

Listing **titles** are Reverb content kept only in this test target, on
purpose: they are what `MarketPersistedContentTests` reads the saved
store files for and must never find. Shop, seller and photo fields were
removed at recording.

## The oracle (`MarketFigureComputationTests` pins these)

```
listings fetched: 337 over 7 pages; USD (listing_currency and price.currency): 259
brand-new       n=182 median=183999 low=153900 high=256999
excellent       n=34 median=139999 low=115200 high=325000
very-good       n=14 median=141000 low=100000 high=159999
mint-inventory  n=14 median=154999 low=144319 high=164999
mint            n=7 median=149999 low=119800 high=169999
b-stock         n=5 median=156599 low=147599 high=184000
good            n=3 median=118900 low=114900 high=170000

owned(.new)          n=208 median=183999 low=119800 high=256999
owned(.excellent)    n=34 median=139999 low=115200 high=325000
owned(.good)         n=17 median=139999 low=100000 high=170000
owned(.fair)         n=0 (withheld)
owned(.broken)       n=0 (withheld)
wanted               n=72 median=149999 low=100000 high=325000   (product used_total = 108; used_low_price = 100000)
slugs outside the known set: none
```

## Candidate ids for `docs/samples/items-full.csv`'s music rows (T016a)

```
  Fender AV II '61 Stratocaster:

  Martin D-18:
    182769  Martin Standard Series D-18 (2018 - 2024)  (used from 192100 cents, 19 listed)
    116343  Martin D-18 1970 - 1984  (used from 165000 cents, 53 listed)
    89358  Martin Standard Series D-18  (used from 216900 cents, 12 listed)
  Fender Blues Junior IV:
    80684  Fender Blues Junior IV 15-Watt 1x12" Guitar Combo  (used from 44900 cents, 24 listed)
    121301  Fender Blues Junior IV FSR Limited Edition 15-Watt 1x12" Guitar Combo  (used from 44995 cents, 19 listed)
    183143  Fender Blues Junior IV 30th Anniversary 15-Watt 1x12" Guitar Combo  (used from 74999 cents, 2 listed)
  Strymon Timeline:
    17  Strymon Timeline Delay  (used from 25500 cents, 89 listed)
    189120  Strymon TimeLine MX Delay  (used from 59000 cents, 4 listed)
```
<!-- recorded:end -->

### Chosen for the four rows (by hand, after the run)

The script's own query for the Stratocaster row — the CSV's abbreviated
`Fender AV II '61 Stratocaster` — returned no candidates; the fuller
name did, re-queried by hand the same day:

```
  Fender American Vintage II '61 Stratocaster:
    160322  Fender American Vintage II '61 Stratocaster  (used from 150000 cents, 57 listed)
    160331  Fender American Vintage II '61 Stratocaster Left-Handed  (used from 193198 cents, 3 listed)
```

| CSV row | Reverb Product ID | Title on Reverb |
|---|---|---|
| Fender AV II '61 Stratocaster | 160322 | Fender American Vintage II '61 Stratocaster |
| Martin D-18 | 182769 | Martin Standard Series D-18 (2018 - 2024) |
| Fender Blues Junior IV | 80684 | Fender Blues Junior IV 15-Watt 1x12" Guitar Combo |
| Strymon Timeline | 17 | Strymon Timeline Delay |

Worth knowing for the picker: an abbreviation Reverb's catalog doesn't
use ("AV II") finds nothing, while the brand and model spelled out find
it first — the empty-state copy's "the brand and model are enough" is
the right advice.

### The `year` field, as recorded (Decision 29)

Free text. Across the seven Telecaster pages: 194 blank, then
`2020 - Present`, single years, `2020 - 2023`, `2020s`, and three
oddities worth a test each — `0`, `2003-04`, `LATE 2000’s` — which P19
reads as unreadable, so a mismatch. This recording is the second of the
day: the first dropped `year`, and in the minutes between one excellent
listing sold (34, not 35; `used_total` 108, not 109).

## Hand-built, not recorded

- `rate-limited-429.json` — the shape of Reverb's 429 body.
- `listings-mixed.json` — one page carrying a EUR listing, a listing whose
  `price.currency` disagrees with `listing_currency`, one with no
  `listing_currency` at all, an unknown condition slug, a listing with no
  price, and one with no condition.
- `listings-next-elsewhere.json` — a page whose `_links.next` points at
  another host, which the client must refuse to follow.

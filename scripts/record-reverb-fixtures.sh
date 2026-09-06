#!/usr/bin/env bash
# Records the Reverb API fixtures that TroveTests decodes and computes
# against (spec 002, plan §3 "Fixtures"; tasks T002).
#
# Run by hand, from the repo root, with the network up:
#
#     scripts/record-reverb-fixtures.sh
#
# Never run by the build or by a test — no test in TroveTests opens a
# network connection (CLAUDE.md, Networking). Re-recording is a deliberate
# act: the diff under TroveTests/Fixtures/Reverb/ is the review.
#
# What it writes (every response trimmed to the fields the app reads —
# shop, seller and photo fields removed from listings; `year` kept for
# Decision 29's narrowing; listing *titles*
# kept on purpose, as the tripwire the persisted-content byte scan looks
# for and must never find):
#
#   csps-search-telecaster.json   the catalog search, three candidates
#   csp-126161.json               the product by id
#   csp-404.json                  an unknown id's answer
#   listings-126161-pN.json       every page of the product's listings
#   README.md                     the date, the oracle block T005 pins,
#                                 and candidate ids for the sample CSV
#
# Pure python3 (urllib) under a bash shim so the file is a script and not
# a test target member; nothing here imports anything outside the
# standard library.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - "$@" <<'PY'
import json, statistics, sys, time, urllib.parse, urllib.request, urllib.error, datetime, pathlib

BASE = "https://api.reverb.com/api"
HEADERS = {
    "Accept": "application/hal+json",
    "Accept-Version": "3.0",
    "User-Agent": "Trove-fixture-recorder/1.0 (scripts/record-reverb-fixtures.sh)",
}
OUT = pathlib.Path("TroveTests/Fixtures/Reverb")
PRODUCT_ID = 126161          # Fender American Professional II Telecaster
SEARCH = "American Professional II Telecaster"
SAMPLE_NAMES = ["Fender AV II '61 Stratocaster", "Martin D-18", "Fender Blues Junior IV", "Strymon Timeline"]
PAUSE = 1.0

def get(url):
    time.sleep(PAUSE)
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, json.load(e)

def link(obj, name):
    return (obj.get("_links") or {}).get(name, {}).get("href")

def trim_csp(c):
    photo = None
    for p in c.get("photos") or []:
        href = link(p, "small_crop")
        if href:
            photo = {"_links": {"small_crop": {"href": href}}}
            break
    money = lambda m: {"amount_cents": m["amount_cents"], "currency": m["currency"]} if m else None
    out = {
        "id": c["id"], "slug": c["slug"], "title": c["title"],
        "brand": {"name": (c.get("brand") or {}).get("name")},
        "photos": [photo] if photo else [],
        "used_low_price": money(c.get("used_low_price")), "used_total": c.get("used_total"),
        "new_low_price": money(c.get("new_low_price")), "new_total": c.get("new_total"),
        "root_category_slug": c.get("root_category_slug"),
        "_links": {k: {"href": link(c, k)} for k in ("web", "self", "listings") if link(c, k)},
    }
    return out

def trim_listing(l):
    return {
        "id": l["id"], "title": l.get("title"),
        "price": {"amount_cents": l["price"]["amount_cents"], "currency": l["price"]["currency"]},
        "listing_currency": l.get("listing_currency"),
        "year": l.get("year"),
        "condition": {"slug": (l.get("condition") or {}).get("slug"), "display_name": (l.get("condition") or {}).get("display_name")},
        "state": {"slug": (l.get("state") or {}).get("slug")},
    }

def write(name, obj):
    (OUT / name).write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")
    print("wrote", OUT / name)

OUT.mkdir(parents=True, exist_ok=True)

# 1. Search
status, search = get(f"{BASE}/csps?" + urllib.parse.urlencode({"query": SEARCH, "per_page": 3}))
assert status == 200, status
write("csps-search-telecaster.json", {"comparison_shopping_pages": [trim_csp(c) for c in search["comparison_shopping_pages"]]})

# 2. Product by id, and an unknown id
status, product = get(f"{BASE}/comparison_shopping_pages/{PRODUCT_ID}")
assert status == 200, status
write(f"csp-{PRODUCT_ID}.json", trim_csp(product))
status, missing = get(f"{BASE}/comparison_shopping_pages/999999999")
assert status == 404, status
write("csp-404.json", missing)

# 3. Every page of the product's listings, from its own listings link
url = link(product, "listings")
assert url, "product carries no listings link"
parts = urllib.parse.urlsplit(url)
query = urllib.parse.parse_qsl(parts.query)
query = [(k, v) for k, v in query if k != "per_page"] + [("per_page", "50")]
url = urllib.parse.urlunsplit(parts._replace(query=urllib.parse.urlencode(query)))
pages, page_no = [], 0
while url and page_no < 50:
    status, page = get(url)
    assert status == 200, status
    page_no += 1
    trimmed = {
        "total": page.get("total"), "current_page": page.get("current_page"),
        "per_page": page.get("per_page"), "total_pages": page.get("total_pages"),
        "listings": [trim_listing(l) for l in page.get("listings", [])],
        "_links": {k: {"href": link(page, k)} for k in ("self", "next") if link(page, k)},
    }
    write(f"listings-{PRODUCT_ID}-p{page_no}.json", trimmed)
    pages.append(trimmed)
    url = link(page, "next")

# 4. The oracle, in the form T005 pins
usd = [l for p in pages for l in p["listings"] if l["listing_currency"] == "USD" and l["price"]["currency"] == "USD"]
by = {}
for l in usd:
    by.setdefault(l["condition"]["slug"], []).append(l["price"]["amount_cents"])
def block(cents):
    cents = sorted(cents)
    n = len(cents)
    median = cents[n // 2] if n % 2 else (cents[n // 2 - 1] + cents[n // 2] + 1) // 2
    # The trimmed bounds the value slider runs between (Decision 36): the
    # nearest-rank percentiles, ceil(P/100 * n)-th smallest, 1-based.
    rank = lambda p: cents[min(max(1, (p * n + 99) // 100), n) - 1]
    return f"n={n} median={median} low={cents[0]} high={cents[-1]} p10={rank(10)} p90={rank(90)}"
lines = [f"listings fetched: {sum(len(p['listings']) for p in pages)} over {len(pages)} pages; USD (listing_currency and price.currency): {len(usd)}"]
for slug, cents in sorted(by.items(), key=lambda kv: -len(kv[1])):
    lines.append(f"{slug:15s} {block(cents)}")
buckets = {
    "owned(.new)": ["brand-new", "mint", "mint-inventory", "b-stock"],
    "owned(.excellent)": ["excellent"],
    "owned(.good)": ["very-good", "good"],
    "owned(.fair)": ["fair"],
    "owned(.broken)": ["poor", "non-functioning"],
}
lines.append("")
for name, slugs in buckets.items():
    cents = [c for s in slugs for c in by.get(s, [])]
    lines.append(f"{name:20s} {block(cents) if cents else 'n=0 (withheld)'}")
wanted = [c for s, cents in by.items() if s not in ("brand-new", "b-stock") for c in cents]
lines.append(f"{'wanted':20s} {block(wanted)}   (product used_total = {product.get('used_total')}; used_low_price = {(product.get('used_low_price') or {}).get('amount_cents')})")
unknown = sorted(set(by) - {"brand-new", "b-stock", "mint", "mint-inventory", "excellent", "very-good", "good", "fair", "poor", "non-functioning"})
lines.append(f"slugs outside the known set: {unknown or 'none'}")
oracle = "\n".join(lines)
print("\n" + oracle + "\n")

# 5. Candidate ids for the sample CSV's music rows
cands = []
for name in SAMPLE_NAMES:
    status, r = get(f"{BASE}/csps?" + urllib.parse.urlencode({"query": name, "per_page": 3}))
    rows = [f"    {c['id']}  {c['title']}  (used from {(c.get('used_low_price') or {}).get('amount_cents')} cents, {c.get('used_total')} listed)" for c in r.get("comparison_shopping_pages", [])] if status == 200 else [f"    HTTP {status}"]
    cands.append(f"  {name}:\n" + "\n".join(rows))
candidates = "\n".join(cands)
print(candidates)

today = datetime.date.today().isoformat()
START, END = "<!-- recorded:start -->", "<!-- recorded:end -->"
generated = f"""{START}
Recorded {today} by `scripts/record-reverb-fixtures.sh` from the public
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
{oracle}
```

## Candidate ids for `docs/samples/items-full.csv`'s music rows (T016a)

```
{candidates}
```
{END}"""
readme = OUT / "README.md"
# Everything outside the markers is written by hand and survives a re-record.
if readme.exists() and START in readme.read_text() and END in readme.read_text():
    text = readme.read_text()
    before, rest = text.split(START, 1)
    _, after = rest.split(END, 1)
    readme.write_text(before + generated + after)
else:
    readme.write_text("# Reverb fixtures\n\n" + generated + "\n")
print("wrote", readme, "(hand-written sections outside the markers kept)")
PY

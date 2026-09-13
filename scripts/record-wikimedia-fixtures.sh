#!/usr/bin/env bash
# Records the Wikimedia Commons fixture that TroveTests decodes and
# classifies against (spec 005, plan §2 "the Wikimedia request and the
# fixture shape"; tasks T002).
#
# Run by hand, from the repo root, with the network up:
#
#     scripts/record-wikimedia-fixtures.sh
#
# Never run by the build or by a test — no test in TroveTests opens a
# network connection (CLAUDE.md, Networking). Re-recording is a
# deliberate act: the diff under TroveTests/Fixtures/Wikimedia/ is the
# review.
#
# What it writes (the one search response, each page trimmed to the
# fields the app reads — only imageinfo[0], and within it url,
# descriptionurl, thumburl, mime, the extmetadata licence/author
# fields the classifier and credit read, and each page's category
# titles the taken-with relevance filter reads):
#
#   search-camera.json   the gear query, up to 20 File-namespace results
#   wikimedia-fixtures.md   the date, the query, the licence note
#
# The hand-built fixtures (search-mixed-licences.json, search-no-author.json,
# search-empty.json, image-small.bin) are NOT written here — they are
# committed by hand alongside this script and describe cases the live
# query may not contain.
#
# Pure python3 (urllib) under a bash shim so the file is a script and not
# a test target member; nothing here imports anything outside the
# standard library.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - "$@" <<'PY'
import json, urllib.parse, urllib.request, urllib.error, datetime, pathlib

BASE = "https://commons.wikimedia.org/w/api.php"
# A well-covered gear model Commons organises systematically by model.
QUERY = "Nikon D750"
HEADERS = {
    "User-Agent": "Trove-fixture-recorder/1.0 (scripts/record-wikimedia-fixtures.sh)",
}
OUT = pathlib.Path("TroveTests/Fixtures/Wikimedia")

# formatversion=2 makes query.pages a JSON array (not a pageid-keyed
# dict), which is what the Swift Codable shape decodes.
PARAMS = {
    "action": "query",
    "format": "json",
    "formatversion": "2",
    "generator": "search",
    "gsrsearch": QUERY,
    "gsrnamespace": "6",        # the File namespace
    "gsrlimit": "20",
    "prop": "imageinfo|categories",
    "iiprop": "url|extmetadata|mime",
    "iiurlwidth": "1024",
    "cllimit": "500",
}

def get(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.status, json.load(r)

# Keep only the extmetadata fields the app reads, each in its
# {"value": ...} wrapper exactly as the API returns them.
EXT_KEYS = ("LicenseShortName", "License", "Artist", "LicenseUrl", "UsageTerms")

def trim_ext(ext):
    out = {}
    for k in EXT_KEYS:
        v = (ext or {}).get(k)
        if v is not None and "value" in v:
            out[k] = {"value": v["value"]}
    return out

def trim_imageinfo(ii):
    return {
        "url": ii.get("url"),
        "descriptionurl": ii.get("descriptionurl"),
        "thumburl": ii.get("thumburl"),
        "mime": ii.get("mime"),
        "extmetadata": trim_ext(ii.get("extmetadata")),
    }

def trim_categories(cats):
    # Keep only each category's title — the taken-with filter reads nothing else.
    return [{"title": c.get("title")} for c in (cats or []) if c.get("title")]

def trim_page(p):
    infos = p.get("imageinfo") or []
    out = {"pageid": p.get("pageid"), "title": p.get("title")}
    if infos:
        out["imageinfo"] = [trim_imageinfo(infos[0])]
    cats = trim_categories(p.get("categories"))
    if cats:
        out["categories"] = cats
    return out

def write(name, obj):
    (OUT / name).write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n")
    print("wrote", OUT / name)

OUT.mkdir(parents=True, exist_ok=True)

status, resp = get(f"{BASE}?" + urllib.parse.urlencode(PARAMS))
assert status == 200, status
pages = ((resp.get("query") or {}).get("pages")) or []
trimmed = {"batchcomplete": True, "query": {"pages": [trim_page(p) for p in pages]}}
write("search-camera.json", trimmed)

today = datetime.date.today().isoformat()
START, END = "<!-- recorded:start -->", "<!-- recorded:end -->"
generated = f"""{START}
Recorded {today} by `scripts/record-wikimedia-fixtures.sh` from the
public MediaWiki Action API on `commons.wikimedia.org`, unauthenticated,
trimmed to the fields the app reads. Read by `TroveTests` through
`#filePath`, the way the Reverb fixtures are. Never fetched by a test or
by the build; re-record by hand and review the diff.

Query: `{QUERY}` (generator=search, gsrnamespace=6 = File, gsrlimit=20,
formatversion=2). Written to `search-camera.json`, {len(pages)} page(s).

File **titles** and **authors** (`Artist`) are Wikimedia Commons content
kept only in this test target, on purpose. Each page is trimmed to
`imageinfo[0]` and, within it, `url`, `descriptionurl`, `thumburl`,
`mime`, and the `extmetadata` licence/author fields the classifier and
credit read.
{END}"""
# Not "README.md": the test target is a synchronized folder that copies every
# file flat into the test bundle's resources, so a second README.md would
# collide with Fixtures/Reverb/README.md at build time. A unique basename keeps
# the spec's "no .pbxproj edit" rule intact (T002 resolution).
readme = OUT / "wikimedia-fixtures.md"
# Everything outside the markers is written by hand and survives a re-record.
if readme.exists() and START in readme.read_text() and END in readme.read_text():
    text = readme.read_text()
    before, rest = text.split(START, 1)
    _, after = rest.split(END, 1)
    readme.write_text(before + generated + after)
else:
    readme.write_text("# Wikimedia Commons fixtures\n\n" + generated + "\n")
print("wrote", readme, "(hand-written sections outside the markers kept)")
PY

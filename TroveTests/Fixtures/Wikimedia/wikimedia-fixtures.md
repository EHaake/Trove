# Wikimedia Commons fixtures

These fixtures back the stock-photo decoding, licence classification, and
image byte-ceiling tests (spec 005, plan §2/§3). `TroveTests` reads them
through `#filePath`; no test opens a network connection.

## Hand-built fixtures (committed directly, not recorded)

- `search-mixed-licences.json` — the **classifier oracle**: one File page
  each of CC0, public-domain, CC-BY, CC-BY-SA (all reusable) and CC-BY-NC,
  CC-BY-ND, GFDL-only, no-licence (all rejected). Each has a distinct
  `pageid` and a distinct `title` (`File:Reusable-*` / `File:Nonfree-*`)
  so a filter test can assert the four non-free titles are absent from the
  survivors. Reusable = CC0 | public-domain | CC-BY | CC-BY-SA (any
  version), read from the `License` / `LicenseShortName` extmetadata.
- `search-no-author.json` — a single public-domain page with **no `Artist`
  key** in `extmetadata`. The credit falls back to "Wikimedia Commons" and
  the file is still offered.
- `search-placeholder-author.json` — a single CC-BY-SA page whose `Artist`
  carries Commons' **placeholder** for a file with no structured author
  ("No machine-readable author provided. <user> assumed (based on copyright
  claims).", with the username as a wiki link). The file is still offered
  and its credit falls back to "Wikimedia Commons" (T015 finding 2).
- `search-off-host.json` — three otherwise-identical CC-BY pages whose
  `thumburl` hosts differ: `thumb.wikimedia.org` (kept), `cdn.example.com`
  (dropped), and the look-alike `upload.wikimedia.org.evil.example`
  (dropped). Hand-built because the live API can only ever serve Wikimedia
  hosts, so the off-host case cannot be recorded — it guards the decode-time
  host filter (plan Q1) that keeps an off-host URL out of the picker's
  `AsyncImage`.
- `search-empty.json` — `{"batchcomplete": true}` with **no `query`** key,
  the empty state MediaWiki returns when the generator matches nothing.
- `image-small.bin` — a tiny (43-byte) valid GIF blob for the
  `imageData(from:)` happy path; downloaded whole and stored.

The **oversize** byte-ceiling case (`~8 MB` ceiling → `.imageTooLarge`) is
**synthesized in the T003 test** (bytes built in-memory), not stored as a
large fixture, so no multi-MB file is committed here.

## Fixture shape

Top level is `{"batchcomplete": true, "query": {"pages": [ …page… ]}}`
(and just `{"batchcomplete": true}` for the empty state). Each page is
trimmed to `pageid`, `title`, and `imageinfo` (only `imageinfo[0]`); each
`imageinfo` entry to `url`, `descriptionurl`, `thumburl`, `mime`, and an
`extmetadata` object whose values keep the API's `{"value": "..."}`
wrapper — `LicenseShortName`, `License`, `Artist`, `LicenseUrl`,
`UsageTerms` (any of which may be absent). `formatversion=2` is what makes
`query.pages` a JSON array rather than a pageid-keyed dict.

File **titles** and **authors** (`Artist`) are Wikimedia Commons content
kept only in this test target, on purpose.

<!-- recorded:start -->
Recorded 2026-09-09 by `scripts/record-wikimedia-fixtures.sh` from the
public MediaWiki Action API on `commons.wikimedia.org`, unauthenticated,
trimmed to the fields the app reads. Read by `TroveTests` through
`#filePath`, the way the Reverb fixtures are. Never fetched by a test or
by the build; re-record by hand and review the diff.

Query: `Nikon D750` (generator=search, gsrnamespace=6 = File, gsrlimit=20,
formatversion=2). Written to `search-camera.json`, 20 page(s).

File **titles** and **authors** (`Artist`) are Wikimedia Commons content
kept only in this test target, on purpose. Each page is trimmed to
`imageinfo[0]` and, within it, `url`, `descriptionurl`, `thumburl`,
`mime`, and the `extmetadata` licence/author fields the classifier and
credit read.
<!-- recorded:end -->

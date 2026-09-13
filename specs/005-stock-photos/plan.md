# 005 — Stock Photos — Technical Plan

**Status**: **Signed off** (2026-09-09) — skeptical-reviewer, at Opus under the
Fallback clause; nothing blocking, OQ1 (share-alike) confirmed against the
CC-BY-SA 4.0 legal text, three second-look notes folded in (OQ2 prose, the
Keep-both PDF case, the T015 `.task` probe). Ready for implementation once the
person approves the spec-conformance summary.

Drafted in-session against the approved `spec.md` (Approved 2026-09-09) and
the code as it stands on `004-themes` (from which `005-stock-photos` will
branch). Run at **Opus 4.8, high effort, under `CLAUDE.md`'s model-policy
Fallback clause** — Fable's budget is spent, so the planner and every review
this spec runs at `opus`; the tier log records it. Planning proposals
(Q1–Q12) become decisions on plan approval, the way `002`'s Q-items and this
spec's P-items did. Two open questions are carried out of the plan, not
settled in it — the share-alike reading (the spec flags it for this review)
and one criterion/decision reconciliation surfaced at drafting; both are in
**Open questions** below.

## Context

Spec 005 (Approved 2026-09-09) lets the person **fetch a representative photo**
for an item that has no photo of their own — emphasised on the wishlist,
allowed on any owned item without a photo — from **Wikimedia Commons**, on
demand, and store it like a photo they took. The picked image's **bytes and
its attribution** are stored as an ordinary `Photo` in the **main synced
store** and travel to the person's other devices (spec criterion 4); it is
marked as a **stock photo** and carries a **credit** (author · licence ·
Wikimedia link) everywhere it appears. The one datum that does *not* sync is
the **one-time-notice acknowledgement**.

This is the app's **second network dependency**, after `002`'s Reverb. It
reuses `002`'s posture — on-demand only, never in the background; a one-time
privacy notice; a candidate picker — and follows `CLAUDE.md`'s **Networking**
section (`nonisolated protocol …: Sendable`, `@concurrent` requirements,
constructor-injected `(any X)? = nil` → live impl; fixtures recorded by a
script under `scripts/`, trimmed, committed under `TroveTests/Fixtures/`; **no
test opens a network connection**). Unlike `002` it needs **no second store**
— a fetched photo is the person's data and syncs — so this plan is markedly
lighter than `002`'s: no two-store split, no trend, no adoption, no CSV column
(criterion 8: CSV is untouched).

**No constitution amendment is required.** `CLAUDE.md`'s Networking section
already governs "every remote service"; a second service that obeys it
contradicts nothing. The "What this project is" paragraph names only the
resale-value line, which this spec does not touch. So there is no Phase 0.

## Open questions

**OQ1 — Share-alike / the PDF (the spec flags this for sign-off; the plan
does NOT resolve it).** Spec "Attribution and licensing" reads: displaying an
**unmodified** CC-BY-SA image with its credit — in the app, and placed
alongside the person's own content in the PDF export — is a *collection*, not
an *adaptation*, so no share-alike obligation attaches to the person's
document. The app never modifies a fetched image (spec Non-goals), which is
what keeps it a collection. **The plan builds to this reading**: fetched
photos appear unmodified with their credit in the picker, on the detail
screen, and in the PDF (§7). The skeptical-reviewer is asked to confirm or
tighten it at sign-off, exactly as `002` deferred the reading of Reverb's
"reasonable periods." If it is tightened to "no CC-BY-SA image in the PDF,"
§7's mapping filters those photos out of the export and the rest of the plan
is unaffected.

**OQ2 — When does *Find a photo…* disappear? — RESOLVED by the person as
spec Decision 6 (2026-09-09).** The gate is **"no *owned* photo"**: the action
shows on a blank item or one whose only photo is a stock one (so a stock photo
is replaced by a fresh Find a photo…, per P8), and hides once an item has an
owned photo. The spec's criterion 1 was reworded to match ("no photo of the
person's own … whether it is blank or holds only a stock photo"); the earlier
"an item that already has a photo does not" wording is gone. The plan's
`canFindPhoto` predicate (§4, §6) already implements this reading (no `.device`
photo), so nothing changes — this note is retained only to record that the
question was raised and settled, not left open. The strict alternative
(`photos.isEmpty`) was declined by the person.

## Proposed at planning (Q1–Q12) — approved on plan approval unless overturned

- **Q1. The MediaWiki Action API on `commons.wikimedia.org`, unauthenticated.**
  One search request: `action=query&format=json&generator=search`
  `&gsrsearch=<name>&gsrnamespace=6&gsrlimit=<N>&prop=imageinfo`
  `&iiprop=url|extmetadata|mime&iiurlwidth=<thumb>`. `gsrnamespace=6` is the
  File namespace; `imageinfo` returns per file the `url`, `descriptionurl`
  (the Commons file page — the link-back), a `thumburl` at `iiurlwidth`, the
  `mime`, and `extmetadata` (`LicenseShortName`, `License`, `Artist`,
  `LicenseUrl`, `UsageTerms`). No API key, no server secret, no third-party
  package (`CLAUDE.md` Dependencies untouched). Image bytes are fetched only
  from a **Wikimedia host** — an exact `wikimedia.org` or any `.wikimedia.org`
  subdomain — and any URL outside that is not fetched. **Corrected at T002's
  recording (2026-09-09):** the earlier wording named just
  `upload.wikimedia.org`/`commons.wikimedia.org`, but the live API serves 18 of
  20 thumbnails from **`thumb.wikimedia.org`** (originals from
  `upload.wikimedia.org`), so a two-literal allowlist would refuse most
  thumbnails. The `.wikimedia.org` suffix check covers upload/thumb/commons and
  any future subdomain while still rejecting a foreign or look-alike host
  (`wikimedia.org.evil.com`, `notwikimedia.org`). Recorded URLs also carry
  `utm_*` query params and may return a slightly larger standard bucket than
  the requested `iiurlwidth` (1280 px for a 1024 request); both are harmless —
  the bytes stay bounded under the ceiling (Q2) and are stored as served.
- **Q2. The app stores a width-capped thumbnail, not the original.** The
  request asks Wikimedia for a thumbnail at a storage width (**1024 px**,
  `iiurlwidth`) and downloads *those* bytes — server-side resizing, so no
  local `ImageIO` downscale is needed and the stored blob is bounded. A second,
  smaller `thumburl` for the picker grid is requested in the same call
  (a `iiurlwidth` of ~320 through a second `prop=imageinfo` width is not
  available in one call, so the grid reuses the 1024 thumb via `AsyncImage`,
  which the OS URL cache down-samples for display — transport, not app storage,
  the `002` Q17 posture). A defensive byte ceiling (**~8 MB**) rejects a
  surprising response into `.imageTooLarge` rather than storing it.
- **Q3. A small candidate set.** `gsrlimit = 20` search hits, filtered to
  reusable licences (Q4), the first **≤ 12** shown. Tuned so a good match is
  usually on the list; "no usable photos" is a normal outcome (spec empty
  state).
- **Q4. Licence classification — only reusable files are offered (P3).** A
  file is offered iff its `extmetadata` names a **CC0**, **public-domain**
  (`License` beginning `pd`, or `PD-*`), **CC-BY**, or **CC-BY-SA** licence
  (any version). Everything else — `CC-BY-NC*`, `CC-BY-ND*`, no free licence,
  fair-use, **GFDL-only** — is filtered out before the picker. GFDL-only is
  filtered as the conservative call (its terms are awkward for a mobile app);
  a file dual-licensed GFDL **and** CC-BY-SA is offered and credited by its
  CC-BY-SA licence. The classifier reads `License`/`LicenseShortName` and is
  the correctness core (§3), tested over fixtures with a mutation that a
  filtered licence must not appear.
- **Q5. Author capture.** `Artist` extmetadata is HTML; it is reduced to plain
  text (tags stripped, entities decoded, whitespace collapsed) for the credit.
  If `Artist` is absent — common on public-domain files — the credit's author
  reads **"Wikimedia Commons"** and the file is still offered; the licence and
  file-page link are always present. The licence name is `LicenseShortName`
  (e.g. "CC BY-SA 4.0"); the link is `descriptionurl`.
- **Q6. The contact address lives in `StockPhotoCopy.contactAddress`.** Every
  Wikimedia request carries `User-Agent: Trove/<version> (iOS; <contact>)`
  (Wikimedia's API etiquette asks for a contact, exactly as `002`'s terms
  did). It is spelled in `StockPhotoCopy`, self-contained — 005 does not
  depend on 002's `MarketCopy`. This duplicates the one real address that
  `MarketCopy.contactAddress` also holds; a later `AppContact` unification is
  noted for the close-out, not done here. A placeholder guard (one `@`, no
  whitespace, no `TODO`/`example.com`) mirrors `002` Decision 25.
- **Q7. The one-time notice is stored in `UserDefaults`, unsynced, behind a
  protocol.** `PhotoNoticeStore` (`hasAcknowledged`, `acknowledge()`), live
  `UserDefaultsPhotoNoticeStore(defaults:)`, injected `(any PhotoNoticeStore)?
  = nil` into the hosting view models. This is a single per-device flag — the
  lighter pattern `004` used for the appearance choice — and it deliberately
  does **not** reuse `002`'s `MarketDeviceState` row: 005 doesn't depend on
  002, and a `UserDefaults` bool needs no store, no schema, no migration. A
  read that fails reads as *not acknowledged* (the notice shows once more — the
  safe direction, `002`'s rule).
- **Q8. An ephemeral `URLSession`, `waitsForConnectivity = false`.** No disk
  cache, no cookies; offline fails fast into `.unreachable`. Mirrors
  `ReverbMarketService.makeSession`.
- **Q9. The picker searches on appear (seeded with the item's name) and on
  submit.** Criterion 2's "Continue searches" is the seeded appear-search;
  re-search is submit-only (as-you-type would send name fragments, not "the
  item's name" — P1). Change/again re-seeds with the item's name.
- **Q10. `-uiTesting` stubs no live service (the `002` Q13 posture).** The
  flag's justification is "can only lose data"; a stub fabricates data. UI
  tests cover the action's presence, the notice, and the empty/failure states;
  the live search-and-pick is the device pass (T015). No new launch argument is
  added — the fetched photo is ordinary synced data, so no seeding is needed.
- **Q11. The PDF draws the fetched photo in the existing photo box with a
  credit line beneath it (§7).** CSV is untouched (criterion 8). Subject to
  OQ1.
- **Q12. Fetching does not touch owned photos, and syncs like any photo.**
  A picked photo is a `Photo(.fetched)` on `Item.photos`/`WishlistItem.photos`
  in the synced store; the one-fetched-per-item rule and the owned-leads
  ordering are pure `PhotoSelection` logic (§4). P8: a stored fetched photo is
  never re-fetched or refreshed; replacing it is a fresh Find a photo….

---

## Layout and files

New production files (all under synchronized groups — no `.pbxproj` edit; if a
fixture ever needs excluding from a target, that is a `.pbxproj` edit: stop and
flag, per `002` T002):

| File | Holds |
|---|---|
| `Trove/Photos/StockPhotoService.swift` | `StockPhotoService` protocol, `StockPhotoCandidate`, `StockPhotoLicence`, `StockPhotoAttribution`, `StockPhotoError` |
| `Trove/Photos/WikimediaPhotoService.swift` | `WikimediaAPI` constants, `WikimediaPhotoService` (URLSession), wire structs, `WikimediaDecoding`, the licence classifier |
| `Trove/Photos/PhotoNoticeStore.swift` | `PhotoNoticeStore` protocol, `UserDefaultsPhotoNoticeStore` |
| `Trove/Models/StockPhotoCopy.swift` | every string; `contactAddress`, `privacyPolicyURL`/`Filename` |
| `Trove/ViewModels/PhotoFetchViewModel.swift` | the picker's search/download state |
| `Trove/Views/Photos/PhotoNoticeView.swift`, `PhotoPickerSheetView.swift` | the two-phase sheet |
| `Trove/Views/Shared/StockPhotoBadge.swift`, `StockPhotoCredit.swift` | the shared badge and credit line |
| `scripts/record-wikimedia-fixtures.sh` | the by-hand fixture recorder (curl + python trim) |
| `TroveTests/Fixtures/Wikimedia/*.json` | recorded + hand-built fixtures, read by `#filePath` |

Changed: `Photo` (attribution fields + builder), `PhotoSelection` (the
fetched-photo rules), `ItemDetailViewModel`, `WishlistDetailViewModel`,
`ItemFormViewModel`, `WishlistFormViewModel`, `ItemDetailView`,
`WishlistDetailView`, `ItemFormView`, `WishlistFormView`, `PhotoPickerField`,
`PhotoCarousel`, `RowThumbnail`, `ItemRow`, `WishlistView` (row), `PDFEntry`
+ the two `init(record:)` mappings, `PDFComposer`, `PRIVACY.md`, README, docs.
`CloudKitSchemaTests` covers the schema change and stays green.

---

## 1. The `Photo` attribution fields (foundational, schema change)

Three optional fields on `Photo` (`Trove/Models/Photo.swift`), after
`sortOrder`, each with a default — CloudKit-additive, so `CloudKitSchemaTests`
continues to validate (red run: declare one non-optional without a default →
the validator names it):

```swift
/// The stock photo's author, for the credit (spec P4). Nil on a `.device`
/// photo, and on a `.fetched` photo whose Wikimedia file names no author,
/// where the credit reads "Wikimedia Commons" (Q5).
var attributionAuthor: String?
/// The Wikimedia licence's short name, e.g. "CC BY-SA 4.0" (spec P4).
var attributionLicense: String?
/// The Commons file page — the link the credit opens (spec P4). Stored as a
/// String (a URL round-trips through String and is CloudKit-safe as one).
var attributionSourceURL: String?
```

`.fetched` already exists on `PhotoSource` (unused since `001` — this spec is
what it was added for). A `Photo` is a stock photo iff `source == .fetched`;
the three fields are its stored credit and **sync with the bytes** (criterion
4). A read-side accessor and a builder keep the two-way mapping in one place:

```swift
extension Photo {
    /// The credit to show, when this is a stock photo. `nil` for `.device`.
    var attribution: StockPhotoAttribution? { … source == .fetched … }
    /// Builds a stored stock photo from a downloaded candidate (§4).
    static func fetched(imageData: Data, attribution: StockPhotoAttribution,
                        sortOrder: Int) -> Photo { … }
}
```

`StockPhotoAttribution { author: String; licenseName: String; sourceURL:
URL }` (a `Sendable` value in `StockPhotoService.swift`). **Testable claim**:
the schema stays CloudKit-compatible — owned by `CloudKitSchemaTests` (T001).

## 2. The service and the client

```swift
nonisolated protocol StockPhotoService: Sendable {
    /// Sends the item's name and nothing else (spec P1). Returns only files
    /// whose licence permits reuse with attribution (spec P3, §3).
    @concurrent func searchPhotos(named query: String) async throws -> [StockPhotoCandidate]
    /// Downloads the chosen candidate's storage-size image (Q2).
    @concurrent func imageData(from url: URL) async throws -> Data
}
nonisolated struct StockPhotoCandidate: Sendable, Equatable, Identifiable {
    let id: Int              // the file's pageid
    let title: String        // the Commons file title, for the a11y label
    let thumbnailURL: URL     // the picker grid image (AsyncImage; transport only)
    let storageURL: URL       // the 1024px thumb the app downloads and stores
    let attribution: StockPhotoAttribution   // author, licence, file page
}
nonisolated enum StockPhotoError: Error, Equatable, Sendable {
    case unreachable, serverError(status: Int), malformedResponse, imageTooLarge
}
```

`WikimediaPhotoService(session:userAgent:searchLimit:storageWidth:maxImageBytes:requestProbe:)`
with `static let sharedSession` (`.ephemeral`, timeouts 15 s/60 s,
`waitsForConnectivity = false`, Q8). `WikimediaAPI`: `host =
"commons.wikimedia.org"`, `endpoint` (the `/w/api.php` URL), `searchLimit =
20`, `storageWidth = 1024`, `userAgent(version:)` reading
`StockPhotoCopy.contactAddress` (Q6). Requests built with
`URLComponents.queryItems` (never interpolation — gear names carry `&`, `+`,
`#`), headers per request, no `Authorization` (a test pins its absence).
`imageData(from:)` follows a URL only while its host is a Wikimedia host and
enforces `maxImageBytes`. Error mapping in one `fetch`: `URLError` →
`.unreachable`, non-2xx → `.serverError`, undecodable → `.malformedResponse`.

`searchPhotos` decodes through `WikimediaDecoding` (§3), classifies each file's
licence, drops the non-reusable and the author-less-and-license-less, maps the
survivors to candidates, and returns the first ≤ 12 (Q3).

**Tests** (`WikimediaPhotoServiceTests`, `.serialized`, a `StubURLProtocol`
keyed by URL over an ephemeral configuration — **no sockets**): the search
request carries `gsrsearch` = the name and nothing that isn't a fixed param;
`Authorization` absent; a punctuation-heavy name (`"'65 SM7B + shield & pop"`)
round-trips through `gsrsearch=` exactly; `URLError(.notConnectedToInternet)`
→ `.unreachable`; a 500 → `.serverError(500)`; `imageData` over a byte-ceiling
fixture → `.imageTooLarge`; a `thumburl`/`storageURL` on a non-Wikimedia host
is not fetched (mutation: drop the host check → red); `requestProbe` records
off-main for both entry points called through the existential from the main
actor (the `ExportConcurrencyTests` / `002` shape; mutation: `@concurrent`
off both requirement and implementation → the probe reads on-main → red).

**Fixtures** — `scripts/record-wikimedia-fixtures.sh` (curl + a python trim)
writes `TroveTests/Fixtures/Wikimedia/`: `search-camera.json` (a real gear
query, each file trimmed to the fields the app reads — `pageid`, `title`,
`imageinfo[0]` with `url`, `descriptionurl`, `thumburl`, `mime`, and the
`extmetadata` keys `LicenseShortName`, `License`, `Artist`, `LicenseUrl`,
`UsageTerms`); hand-built `search-mixed-licences.json` (one file each of CC0,
PD, CC-BY, CC-BY-SA, **CC-BY-NC**, **CC-BY-ND**, GFDL-only, and no licence —
the classifier oracle), `search-no-author.json` (a PD file with no `Artist`),
`search-empty.json` (`query` absent — the empty state), and a tiny
`image-small.bin` + an oversize marker fixture for the byte ceiling. Read by
`#filePath` as `DocsSampleTests` does. Titles/authors are Wikimedia content
kept only in the test target; the recorder is run by hand, once, and its
output committed and reviewed as a diff — **no test opens a connection**.

## 3. Licence classification and attribution (the correctness core)

`StockPhotoLicence.classify(shortName:license:) -> StockPhotoLicence?` returns
a value carrying the reusable licence's display name, or `nil` for a
non-reusable/unknown file. Reusable = CC0 | public-domain | CC-BY | CC-BY-SA
(Q4). Author is `WikimediaDecoding.plainText(fromHTML:)` over `Artist` (tags
stripped, entities decoded), or "Wikimedia Commons" when absent (Q5). The
file-page URL is `descriptionurl`.

**Testable claims, each with the test that owns it** (`WikimediaDecodingTests`,
over the fixtures):
- *Non-reusable licences are filtered out (P3).* `search-mixed-licences.json`
  → exactly the CC0, PD, CC-BY, CC-BY-SA files survive; the NC, ND, GFDL-only
  and no-licence files do not. Mutation: make `classify` return a value for
  `CC-BY-NC` → the count rises and the NC title appears → red.
- *Author/licence/link are parsed correctly (P4).* Per surviving file, the
  candidate's `attribution` equals the expected author (HTML stripped),
  licence short name, and `descriptionurl`. Mutation: skip the HTML strip → the
  author carries a tag → red. `search-no-author.json` → author "Wikimedia
  Commons", still offered.
- *The whole search filters and caps.* A search of 20 hits with 8 reusable →
  8 candidates; a search of 20 with 15 reusable → 12 (Q3). Mutation: drop the
  cap → 15 → red.

## 3a. Search relevance — the "taken-with" filter (added 2026-09-10, spec Decision 7; task T012a)

Wikimedia's text search matches a gear model in the metadata of photos *taken
with* that gear, crowding out product shots (spec Decision 7). The picker drops
any candidate that is a photo **taken with the same make/model the person
searched**, using Wikimedia's structured **"Taken with …"** category — a
reliable signal (live-verified: a product shot of a Canon R5 is itself "Taken
with Canon EOS-1D X Mark II" — a *different* camera — so it survives, while a
portrait shot on a Hasselblad X2D sits in "Taken with Hasselblad X2D 100C" and
is dropped). **Filter-only (Decision 7):** the request is unchanged in what it
*sends* — `gsrsearch` still carries the item's name and nothing else (P1) — it
only asks for one more field back and prunes client-side. No query broadening.

**The request** (`WikimediaPhotoService`/`WikimediaAPI`, extending §2): add
`categories` to the search request's `prop` (`prop=imageinfo|categories`) with a
high `cllimit`. Categories can be paginated across a 20-page generator; a
candidate whose categories come back truncated (or absent) is **kept** — the
safe direction, since a missed drop only leaves a taken-with photo on screen
(no worse than today), whereas a wrong drop loses a real product shot.

**The decode** (`WikimediaDecoding`, extending §3): each wire page carries its
`categories[].title`; strip the `Category:` prefix.

**The match rule — `WikimediaDecoding.isTakenWithSearchedGear(categories:query:)`
(the correctness core; pressure-tested at T012a's per-task review).**
A candidate is dropped iff it has a category whose title, lowercased, begins
`"taken with "` **and** the camera name after that prefix shares an
**alphanumeric-fused token** with the query. Tokens are lowercased maximal
alphanumeric runs (`"eos-1d"` → `eos`,`1d`); an *alphanumeric-fused* token is
one containing **both a letter and a digit** (`x2d`, `r5`, `100c`, `1d`,
`50mm`, `f2`). Requiring a *fused* token — not merely a digit — is what
separates a model designator from both a brand word and a **bare number**:
- brand words (`canon`, `hasselblad`, `nikon`, `fender`) carry no digit, so
  **brand-only overlap never triggers a drop**; and
- **bare numeric tokens** (`24` and `8` from a `"24-70mm F2.8"` lens, `11` from
  `"GoPro Hero 11"`, `3` from `"DJI Air 3"`) are excluded, so a product shot of
  that gear taken with an unrelated device (`Taken with Apple iPhone 8`, sharing
  only the bare `8`) is **not** wrongly dropped — the false-drop class the
  per-task review caught (T012a review, 2026-09-10). Fusing only ever *reduces*
  drops, consistent with the keep-on-doubt safe direction. Anchor cases:
- `"Canon R5"` (fused `{r5}`) vs `"Taken with Canon EOS-1D X Mark II"` (fused
  `{1d}`): disjoint → **kept** (the R5 product shot survives).
- `"Hasselblad X2D 100C ii"` (fused `{x2d, 100c}`; `ii` is not fused) vs `"Taken
  with Hasselblad X2D 100C"`: shares `x2d`/`100c` → **dropped** (the X2D portrait).
- `"Sony FE 24-70mm F2.8"` (fused `{70mm, f2}`; `24` and `8` are bare, excluded)
  vs `"Taken with Apple iPhone 8"` (fused `{}`): disjoint → **kept**.
- A name with no fused token drops nothing — the filter simply doesn't engage,
  falling back to today's behaviour (safe: no false drops). This includes a
  purely word name (`"Leica Summicron"`) and a brand-plus-bare-number name
  (`"iPhone 15"` → `iphone` letter-only, `15` digit-only), whose own
  taken-with shots therefore survive — an accepted limit outside the
  camera/lens/instrument sweet spot the filter targets (T012a re-review note). A camera never photographs itself, so a genuine product shot of
  gear X is never in "Taken with X", and the R5 detail (shutter-module) shots
  that *are* taken with an R5 being pruned is an accepted, minor loss — the body
  shot (`Canon EOS R5.jpg`, not taken-with-R5) is exactly what stays.

The filter runs **after** the licence filter and **before** the ≤ 12 cap (§3,
Q3), so the cap counts kept, relevant candidates.

**Fixtures** — hand-built, the classifier-oracle pattern (§2; no live
re-record needed — the live behaviour is verified in the T015 device pass, as
the classifier's was): a `TroveTests/Fixtures/Wikimedia/search-taken-with.json`
carrying, with real category shapes seen in testing, a product shot (subject
categories, or "Taken with" a *different* model), a same-model taken-with junk
file, an R5-style product shot ("Taken with" a different Canon body), a
bare-number-collision product shot (an `f2.8` lens "Taken with Apple iPhone 8",
which must survive), and a categories-truncated/absent file. The T002 recorder
script is updated so a future re-record also captures `categories` (trimmed to
titles), but the tests do not depend on a re-record.

**Testable claims** (`WikimediaDecodingTests` / a new `WikimediaRelevanceTests`):
same-model taken-with is dropped; a *different*-model taken-with (the R5 case)
is kept; brand-only overlap keeps; a **bare-number** collision (an `f2.8` lens
vs `Taken with … iPhone 8`) keeps; a no-fused-token query drops nothing;
truncated/absent categories keep. **Mutations, each reverted:** match on any
shared token (not only fused) → the R5-keep test red; count a bare digit as
fused (`contains(isNumber)` instead of also `contains(isLetter)`) → the
bare-number-collision test red; drop the "taken with" prefix requirement → a
subject-category "…X2D…" file wrongly dropped → red; invert the
keep-on-truncation default → the truncated-file test red.

## 4. The fetch/store logic

`PhotoFetchViewModel(seed:service:)` (`@Observable`, no SwiftUI):
`query: String`; `phase: .idle | .searching | .results([StockPhotoCandidate])
| .empty(query) | .failed`; `isDownloading: Bool`; `search() async` (trimmed;
blank → `.idle`, no call; reentry-guarded; every non-`imageTooLarge`
`StockPhotoError` maps to `.failed`); `download(_ candidate:) async ->
StockPhotoDownload?` (fetches the bytes, returns bytes + attribution, or nil
on failure — the host decides what to do with it). Lives with the sheet
(T008).

The store rules are pure `PhotoSelection` (`Trove/Models/PhotoSelection.swift`)
so both the form and the detail path share them and tests need no store:
- `static func canFindPhoto(_ photos: [Photo]) -> Bool` — true iff no
  `.device` photo is present (OQ2's reading: a stock photo alone still offers
  Find a photo…, to replace it).
- `static func addingFetched(_ photo: Photo, to existing: [Photo]) -> [Photo]`
  — removes any existing `.fetched` photo (P5, at most one), appends the new
  one **after** all `.device` photos (owned leads, Decision 4a), renumbers.
- `orphaned(previous:current:)` already returns the dropped photos to delete;
  the replaced fetched photo flows through it, so no orphaned blob is left
  (the `PhotoSelection` invariant `011` established).

**Testable claims** (`PhotoSelectionStockTests`): `canFindPhoto` false once a
device photo exists, true for empty and stock-only; `addingFetched` twice
leaves exactly one `.fetched` (mutation: skip the removal → two → red);
`addingFetched` onto an item with a device photo puts the device photo first
(`inDisplayOrder(result).first?.source == .device` — mutation: append before
device photos → red); the replaced fetched photo is in `orphaned(...)`.

`StockPhotoServiceSpy` in `TestSupport` (scripted `Result`s per method behind a
`Mutex`; an exhausted script throws, so an unexpected extra call fails fast —
the `MarketServiceSpy` shape) backs T004's VM tests and the hosts'.

## 5. The one-time notice and its store

`PhotoNoticeStore` (Q7): `var hasAcknowledged: Bool { get }`, `func
acknowledge()`. `UserDefaultsPhotoNoticeStore(defaults: UserDefaults =
.standard)` reads/writes one bool key (`"stockPhotoNoticeAcknowledged"`). A
missing key reads false; the store is per-device and unsynced (criterion 9's
"stored on the device and does not sync"). Injected `(any PhotoNoticeStore)? =
nil` into the detail and form view models. Tests (`PhotoNoticeStoreTests` over
an in-memory `UserDefaults(suiteName:)`): fresh → false; acknowledge → true;
a second store over the same defaults → true (persistence); mutation: drop the
write in `acknowledge` → the second-store test red.

The notice's **words must match `PRIVACY.md`** (criterion 9): the notice body
is `StockPhotoCopy.noticeBody` and `PRIVACY.md` quotes it verbatim, guarded by
`PrivacyPolicyTests` (§8), the coupling `002`'s policy test established.

## 6. Screens

### The hosting view models (detail and form, both kinds)

Injection added to `ItemDetailViewModel`, `WishlistDetailViewModel`,
`ItemFormViewModel`, `WishlistFormViewModel`: `photoService: (any
StockPhotoService)? = nil` → `WikimediaPhotoService()`, `noticeStore: (any
PhotoNoticeStore)? = nil` → `UserDefaultsPhotoNoticeStore()`. Shared state
(mirrored, the derivation written once): `isFindingPhoto: Bool`,
`photoSheetStep: .notice | .pick` (decided when the sheet opens, so
continuing can't reshuffle it under the person — the `002` T017 race), a
`makePhotoFetchViewModel()` seeded with the item's name, and `canFindPhoto`
= `PhotoSelection.canFindPhoto(photos)`.

Intents (mirrored): `findPhoto()` (`photoSheetStep = noticeStore.hasAcknowledged
? .pick : .notice`; opens the sheet), `continueFromNotice()`
(`noticeStore.acknowledge()`; step → `.pick`), `declineNotice()` (closes;
flag untouched — the notice returns next time, spec "Not now searches
nothing"), and the pick's landing:

- **On a detail view model** (`store(_ download:)` async, called by the sheet
  on pick): build `Photo.fetched(...)`, `item.photos =
  PhotoSelection.addingFetched(photo, to: item.photos ?? [])`, delete any
  orphaned replaced fetched photo, `item.updatedAt = now()` (owned only —
  `WishlistItem` has no `updatedAt`, the `002` Decision 24 asymmetry), one
  `save()`; a refused save rolls back and re-loads (spec P8: a failed search
  stores nothing and leaves an existing stock photo untouched). Closes the
  sheet, reloads photos.
- **On a form view model**: the pick appends to the in-memory `photos` array
  via `addingFetched`; the form's existing `save()` writes it (and
  `orphaned(...)` already deletes the replaced fetched photo). No separate
  save path — the form owns one.

Tests (mirrored, spy-driven): `findPhoto` shows the notice the first time and
the picker after acknowledge; decline leaves the flag false and the sheet
closed; a stored pick lands one `.fetched` photo on a second context (detail
VMs) and in `photos` (form VMs); a failed download stores nothing;
`canFindPhoto` follows the owned-photo rule.

### The notice + candidate-picker sheet (T008)

One `.sheet(isPresented: $viewModel.isFindingPhoto, onDismiss:
viewModel.reloadOnDismiss)` whose content branches on `photoSheetStep`:
`PhotoNoticeView` (the notice body; `Link("See the privacy policy")`;
**Continue** filled / **Not now** outlined; swipe-down = Not now) then
`PhotoPickerSheetView`. `PhotoPickerSheetView`: `NavigationStack`, Cancel, a
`SearchField` with `.onSubmit`, the seeded search in `.task` (Q9), a status
line (the `PhotoPickerField` pattern), `EmptyStateView` for `.empty`/`.failed`
with **Search again**, and an image-first candidate grid — each cell an
`AsyncImage` (`thumbnailURL`) in a fixed square over `RowThumbnail`'s
placeholder, with a `StockPhotoCredit` beneath it; tapping the cell downloads
(`isDownloading` shows a spinner) and stores. Detents `[.medium, .large]`.
Presentation from the Design pass (T006).

### The stock badge and credit (shared, T007)

`StockPhotoBadge` — a short **Stock photo** capsule in the app's own type and
tokens (no rendered materials), `accessibilityLabel` "Representative stock
image". `StockPhotoCredit(attribution:)` — "Photo: {author} · {licence} ·
Wikimedia Commons". **`.full` style, amended at T015 finding 1 (decision
review, 2026-09-11):** one wrapping paragraph — a single `Text` over an
`AttributedString` built by a pure `StockPhotoCredit.attributedCredit(_:theme:)`,
whose characters are exactly `StockPhotoCopy.credit(author:licenseName:)`; the
licence run in mono, the trailing `StockPhotoCopy.creditSource` run in brass
carrying `.link = attribution.sourceURL` (set `.tint(accentBrass)` on the
`Text`; a `.link` run draws with the tint). No `lineLimit`, `truncationMode` or
`minimumScaleFactor` on the `.full` credit: a long author wraps whole and is
never cut (the licence's requirement). Tapping the source run opens the
Commons page through the environment's default `OpenURLAction` — no `Link`
view in the layout, no `Button`, no `openURL` call. The T007 form (leading
`Text` + sibling `Link` in an `HStack`) baseline-aligned the link to line 1
and garbled on wrap; a link can be a *view* (own identifier/label/hint,
cannot wrap inside a paragraph) or an *inline run* (wraps, no per-run
accessibility), and any link at the end of a sentence that may wrap faces
this choice. Accessibility (criterion 11): the paragraph is one element,
presented through `.accessibilityRepresentation { Link(destination:
attribution.sourceURL) { Text(plainCredit) } }` with
`.accessibilityHint(StockPhotoCopy.creditLinkHint)` and the
`stockphoto.credit.link` identifier on the representation — VoiceOver reads
the full credit, announces it as a link, says it leaves the app, and
double-tap opens the page. The `Text` carries no `accessibilityLabel` of its
own (an override strips the Links rotor from an inline-link `Text` on iOS
17+). The `arrow.up.right` glyph stays only as a `Text(Image(systemName:))`
appended after the link run, safe because the representation replaces the
spoken content. **Fallback, if the close-out device check finds double-tap
does not activate:** drop the representation, keep the bare `Text` (VoiceOver
then reads "… Wikimedia Commons, link" and the Links rotor activates it), drop
the glyph, and record in `DECISIONS.md` that criterion 11's "says it leaves
the app" is met by the "link" announcement plus Safari opening, not a hint.
`.compact` is unchanged (its `lineLimit(1)` tail-truncation of the author in
the grid is T008's deliberate call, outside this decision). Both from the
Design pass. Referenced by the picker (T008), the carousel (T009) and the rows
(T011) — one component, not rebuilt per screen. **Testable claims**
(`StockPhotoBadgeTests`): `theCreditLinksOnlyItsSourceRunAndKeepsTheWholeAuthor`
— build `attributedCredit` for a long author ("Rama, Wikimedia Commons,
Cc-by-sa-2.0-fr"); its characters equal the copy string (catches truncation or
inline strings), exactly one run carries `.link`, that link is `sourceURL`, and
that run's characters are exactly `creditSource` (catches linking the whole
line) — mutations that must go red: remove the `.link`; extend it to the
whole string; drop or shorten the author. Source scans, adjusted: `Link(`
count == 1 **and** `accessibilityRepresentation` present; no `openURL`; no
`Button(`. No file-wide `lineLimit` scan (`.compact` legitimately uses one —
the over-broad shape). The badge and credit read their strings from
`StockPhotoCopy`.

### Detail screens (T009)

`PhotoCarousel` gains the badge over the current page **when that page's photo
is `.fetched`**, and a `StockPhotoCredit` line beneath the hero for a fetched
current photo (Decision 4; the licence's requirement). The accessibility value
announces a stock photo as a representative image with its credit, not as the
person's own (criterion 11). `ItemDetailView`/`WishlistDetailView` gain the
**Find a photo…** action in the screens' existing action style, shown iff
`viewModel.canFindPhoto`, and attach the sheet. Wiring tests pin the action's
presence gate and that the badge/credit show only for `.fetched`.

### Forms (T010) and the replace/keep prompt

`ItemFormView`/`WishlistFormView` gain **Find a photo…** adjacent to
`PhotoPickerField`, shown iff `canFindPhoto`. `PhotoPickerField` gains the
**replace / keep** prompt (Decision 4a): when the person adds *their own*
photo (`PhotoSelection.appending`) to a `photos` set that already holds a
`.fetched` photo, a **standard system alert** — "This item has a stock photo.
Keep it, or replace it with your photo?" with **Keep both** / **Replace** —
asks before committing. **Replace** removes the fetched photo (through
`orphaned`); **Keep both** keeps both with the owned photo leading (the
`addingFetched` ordering already puts device photos first, so the newly added
device photo sorts ahead of the fetched one). A bespoke surface is not
warranted for a two-choice question (the app's "system in the bars, bespoke in
the page" rule). Tests (`PhotoPickerFieldTests` / the forms' suites): adding a
device photo with a stock photo present raises the prompt; Replace leaves one
`.device` photo; Keep both leaves two with the device photo leading.

### List rows (T011)

`RowThumbnail` shows the leading photo (`inDisplayOrder(photos).first` — owned
leads by construction), with a small `StockPhotoBadge` overlaid **only when
that leading photo is `.fetched`** (criterion 3: the fetched photo is the
thumbnail when the item has no owned photo; marked as a stock image).
`ItemRow`/`WishlistRow` accessibility labels announce a stock thumbnail as a
representative image. Tests: a stock-only item's row shows the badge; an item
with an owned photo shows no badge (the owned photo leads).

**As built (T011 + Phase 3 review).** The row uses a tiny **glyph-only corner
mark** (a `.mark` style on the one `StockPhotoBadge`), the approved artboard's
list-row treatment, not the labelled capsule this paragraph first named — one
shared component, two styles. The mark and the row's a11y value both gate on a
single `PhotoSelection.leadsWithStock` predicate. **Criterion 11's "with its
credit" reading:** the *credit* is announced where the photo is shown at size —
the detail carousel's `.full` credit line — while the compact row thumbnail
announces only "Representative stock image" (a full author·licence·source
announcement on every scrolled thumbnail would be needless VoiceOver verbosity).
This is the plan's reading of criterion 11 for the row; confirmed at the Phase 3
review.

### UI tests (offline, `-uiTesting`, run twice back to back — T012)

`testAnItemWithNoPhotoOffersFindAPhoto` (owned and wanted), `testAnItemWithAn
OwnedPhotoDoesNotOfferFindAPhoto`, `testTheFirstFindAPhotoShowsTheNoticeAndNot
NowClosesIt`, `testTheEmptyAndFailureStatesRead` (offline). What Q10 costs,
stated: no UI test taps Continue, searches live, or stores a photo — the
notice flag's persistence and every stored-photo state rest on the unit suites
and the device pass; the twice-run proves re-runnability. Identifiers:
`stockphoto.find`, `stockphoto.notice.continue`, `stockphoto.notice.notNow`,
`stockphoto.notice.privacy`, `stockphoto.search`, `stockphoto.badge`,
`stockphoto.credit.link`.

**As built (T012 + Phase 3 review) — this list named four tests but the same
Q10 rule forbids two of them.** "No UI test taps Continue" makes the picker
(and so `testTheEmptyAndFailureStatesRead`) unreachable — the empty/failure
states sit behind Continue, which searches Wikimedia on appear — and an owned
photo can't be added without the photo library or a seed Q10 declines, so
`testAnItemWithAnOwnedPhotoDoesNotOfferFindAPhoto` is equally unwritable. Only
two are feasible, exactly mirroring `002`'s "Market (offline states only)" UI
scope: `testAnItemWithNoPhotoOffersFindAPhoto` (owned + wanted) and
`testTheFirstFindAPhotoShowsTheNoticeAndNotNowClosesIt`. The other two criteria
stay covered: **owned-photo-hides** by `PhotoSelection.canFindPhoto`
(T005/T009/T010, mutation-verified); **empty/failure** by
`PhotoFetchViewModelTests` (T008) and the **T015** device pass.

**The notice flag's `-uiTesting` reset (Phase 3 review, blocking finding
fixed).** The photo notice's acknowledgement lives in `UserDefaults.standard`,
which `-uiTesting` does **not** reset the way it resets the SwiftData store — an
asymmetry with `002`'s notice, which rides the in-memory model store. Left
as-is, `testTheFirstFindAPhotoShowsTheNoticeAndNotNowClosesIt` would rest on
uncontrolled starting state (a prior Continue, e.g. the T015 device pass, would
suppress the notice and fail the test). Fixed by
`UserDefaultsPhotoNoticeStore.resetForUITesting(mode:)`, called from
`TroveApp.init`, which clears the flag on the in-memory launch — **structurally
bound** on the built store's mode being `.ephemeral` (the `UITestSeed` pattern),
never on re-reading the launch argument, so a persistent store keeps the
person's acknowledgement (a test shows it refusing). The generalizable rule — a
controlled UI-test starting state must be structural for **every** persisted
flag, not only the model store — goes to `DECISIONS.md` at close-out (T016).
Idiom note: a `nonisolated` type must pattern-match `StorageMode` (`if case
.ephemeral`) rather than use `==`, whose `Equatable` conformance is
MainActor-isolated under this project's `InferIsolatedConformances`.

## 7. PDF export (subject to OQ1)

`PDFEntry` gains `photoCredit: String?` — the leading photo's plain-text credit
("Photo: {author} · {licence} · Wikimedia Commons") when that photo is
`.fetched`, else nil. The two `init(record:)` mappings read it from the leading
photo's attribution, so the record snapshot (`ItemExportRecord`/
`WishlistExportRecord`) carries the leading photo's author + licence alongside
`firstPhotoID` (a `Sendable` snapshot; no live model crosses isolation).
`PDFComposer.drawEntry` draws `photoCredit`, when present, as a small
secondary line beneath the photo box (CoreText from the credit string — the
composer has no SwiftUI, so it composes the text itself). CSV export is
untouched (criterion 8). **Keep-both case (as built):** the export draws only
the leading photo (`firstPhotoID`), and the credit is set only when *that*
photo is `.fetched`. So on an item with an owned photo and a kept stock photo,
the PDF shows the owned photo with no stock credit and the stock photo does
not appear — consistent with `011`'s one-photo-per-entry export and with
"owned leads everywhere." Criterion 8 targets the case where the fetched photo
*is* the item's photo, which is satisfied; this is not a criterion-8 miss.
**As built (T013):** the record snapshot carries the leading photo's whole
`StockPhotoAttribution` (one optional, not two strings), and the composer
draws the credit only when the photo image actually resolved — a photo
deleted mid-export renders the entry photo-free *and* credit-free (spec P4:
never a credit without its image).
**Testable claim** (`PDFComposerStockTests` /
`ExportSchema` tests): an entry whose leading photo is `.fetched` carries the
credit and the composer draws it; a device-photo entry carries no credit
(mutation: always set `photoCredit` → the device-photo assertion red).

## 8. `PRIVACY.md`, docs

- **`PRIVACY.md`** (criterion 9, P6): Wikimedia Commons named as a **second**
  outside service the app talks to, only on the person's action; the "what
  leaves your device" section gains the photo search (the item's name, only on
  Find a photo…, only after the notice); a statement that a fetched photo —
  unlike `002`'s market figures — **does sync** to the person's private iCloud
  database; and the "No image ever leaves the app" line reworded so it cannot
  be misread now that the app *fetches* images and sends a search query (no
  image *leaves*; the app only fetches). `PrivacyPolicyTests` gains coverage:
  the file quotes `StockPhotoCopy.noticeBody` verbatim (mutation: one word of
  the notice changed → red), names Wikimedia Commons and the sync statement,
  carries `StockPhotoCopy.contactAddress`, and has no placeholder. Criterion
  9's "the notice's words match the policy" is exactly this verbatim coupling.
- **README** feature sentence on the branch (the stock-photo feature; the "a
  fetched photo syncs like your own" clause). Status/tree/specs listing move
  post-merge, the `002` split.
- **Post-merge** (`fix/docs-005-shipped`): `ROADMAP.md` (rewrite the
  `005-stock-photos` entry, add a status row, note Reverb's catalog image as
  the deferred later enhancement per Decision 1); README Status/tree;
  `DECISIONS.md` (the second network dependency; Wikimedia over the storing-
  forbidden sources; a fetched photo syncs while `002`'s figures don't; the
  notice flag in `UserDefaults` rather than the `002` store, and why 005 is
  self-contained from 002).

## 9. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `CloudKitSchemaTests` (existing) validates `Photo` with the three fields | a field is declared non-optional without a default |
| G2 | licence filter drops non-reusable files (§3) | `classify` returns a value for `CC-BY-NC`/`ND`/GFDL-only/none |
| G3 | attribution parsed (§3) | the HTML strip or a field mapping is dropped |
| G4 | the candidate cap (§3, Q3) | the ≤ 12 cap is removed |
| G5 | search sends only the name (§2, P1) | a non-name query item is added |
| G6 | the `@concurrent` hop (§2) | `@concurrent` dropped from requirement **and** implementation |
| G7 | the non-Wikimedia-host image URL is not fetched (§2) | the host check is dropped |
| G8 | one `.fetched` photo per item (§4, P5) | the removal in `addingFetched` is skipped |
| G9 | the owned photo leads (§4, Decision 4a) | `addingFetched` appends before device photos |
| G10 | the notice persists (§5) | the write in `acknowledge` is dropped |
| G11 | the PDF credit only on fetched photos (§7) | `photoCredit` is set for a device photo |
| G12 | the policy quotes the notice verbatim (§8) | one word of `noticeBody` changes |
| G13 | the taken-with filter keeps a *different*-model taken-with shot, drops a *same*-model one (§3a) | the match fires on any shared token (not only fused), dropping the R5 product shot; or a bare digit counts as fused, dropping the iPhone-8 lens shot |

Every guard is mutation-verified before it lands (`CLAUDE.md` Testing: a
passing test that cannot fail is a defect); the task's Done note records what
was broken and what went red.

## As built (2026-09-13, at T016's close-out)

Where the shipped code differs from the sections above, what the licence set
turned out to be, and the two questions this document is sometimes read as
leaving open (it doesn't — both were settled before implementation).

**The open questions are closed, and neither is a decision to re-make.** *OQ1*
(share-alike / the PDF) was **confirmed at sign-off against the CC-BY-SA 4.0
legal text**: an unmodified CC-BY-SA image placed beside the person's own
content in an export is a *collection*, not an *adaptation*, so no share-alike
obligation attaches to their document — and the app never modifies a fetched
image, which is what keeps it a collection. §7 shipped to that reading, credit
and all. *OQ2* (when *Find a photo…* disappears) was resolved by the person as
**spec Decision 6** before the plan was signed off: the gate is "no *owned*
photo". Both notes are retained above as a record that the questions were
raised and answered.

**The licence set as shipped.** `StockPhotoLicence.classify` decides from
Wikimedia's `License` code and shows `LicenseShortName`: **CC0** (code begins
`cc0`), **public domain** (code begins `pd`, covering `PD-*`), and **CC-BY /
CC-BY-SA of any version, ported or not** (code begins `cc-by` and contains
neither `-nc` nor `-nd`). Everything else — GFDL-only, NC, ND, missing or
unknown — is dropped before the candidate ever reaches the picker. The
classifier table (`WikimediaDecodingTests.theClassifierAcceptsReusableAndRejectsTheRest`,
added when T003's review found the ported-licence acceptance unguarded) is the
falsifiable form of that list. Live, the three device-pass searches returned
only CC BY-SA 2.0/3.0, CC BY 2.0/3.0 and public domain; **a file dual-licensed
GFDL *and* CC-BY-SA was never encountered**, so §3/Q4's "offered, credited by
its CC-BY-SA licence" path remains unexercised — no fixture can settle it,
since it turns on the code the live API returns.

**Deviations and additions, in the order they happened.**

- **§3a, the taken-with relevance filter, did not exist at sign-off.** It was
  added mid-spec from the person's Phase 3 device testing (spec Decision 7):
  Wikimedia's text search matches gear named in a photo's *capture metadata*,
  so portraits shot on an X2D came back for "Hasselblad X2D". The filter drops
  a candidate categorized as *taken with* the same make/model searched. Its
  first form matched on any shared token, which the per-task review caught as a
  false drop (a lens's bare "24" colliding with an "iPhone 8"); the shipped rule
  matches only **alphanumeric-fused** tokens — one carrying both a letter and a
  digit. Filter-only, per the person's explicit scope: broadening an
  over-specific name is deferred, so "Hasselblad X2D 100C ii" still shows the
  empty state.
- **§6's credit became one paragraph, not a `Text` beside a `Link`** (T015b,
  after a top-tier decision review; §6 carries the amendment). The device pass
  found the credit garbled on any credit long enough to wrap. It is now one
  `Text` over an `AttributedString` from the pure
  `StockPhotoCredit.attributedCredit(_:theme:)`, the source segment a `.link`
  run, with an `accessibilityRepresentation { Link … }` for VoiceOver — an
  `accessibilityLabel` would have stripped the Links rotor on iOS 17+.
  `DECISIONS.md` records the general rule.
- **The credit's arrow glyph takes the credit's own font and tint** (T015c).
  The appended `Text(Image(systemName:))` followed Dynamic Type while the
  credit's text does not, so at accessibility XXXL it grew to about five times
  the cap height, wrapped alone and drew primary instead of brass. A render
  test written for it was **probed, found false-passing — `ImageRenderer` draws
  an SF Symbol inside a `Text` as a constant placeholder — and deleted**; three
  scoped scan guards hold it instead. One `Text` `+` deprecation warning
  remains, from that plan-required glyph append; it is the only warning this
  spec leaves behind.
- **Commons' placeholder author counts as no author** (T015a). Commons emits
  "No machine-readable author provided. {user} assumed (based on copyright
  claims)." in `Artist`; the fallback only fired on an absent or empty field, so
  that sentence was credited verbatim. The leading phrase (case-insensitive) now
  reads as no author and the file is still offered. **No recorded fixture had
  the placeholder** — live data has shapes the sample lacks, which is worth
  remembering the next time a fixture set is trimmed.
- **The notice flag needed its own controlled-start reset** (Phase 3's one
  blocking finding). `UserDefaults.standard` is not reset by `-uiTesting`, so a
  UI test's starting state depended on whatever a previous run had
  acknowledged. `UserDefaultsPhotoNoticeStore.resetForUITesting(mode:)` clears
  it at startup, **gated on the store the app actually built being
  `.ephemeral`** — never on a second read of the launch argument — so a
  persistent store keeps the acknowledgement even with every flag set, and
  `PhotoNoticeStoreTests.theResetRefusesAPersistentStore` shows it refusing.
  The generalization is in `DECISIONS.md`.
- **`StockPhotoAttribution` is `nonisolated`** (T003), required for it to cross
  into the `nonisolated` service protocol.
- **The fixture script's basename** (T002): the first draft collided with the
  repo `README.md`; the fixtures' own notes live at
  `TroveTests/Fixtures/Wikimedia/wikimedia-fixtures.md`. That was the spec's one
  escape-hatch use — a well-specified fork returned rather than decided.
- **T016's carried cleanups.** `maxImageBytes` (8 MB) moved from two bare
  literals into `WikimediaAPI`, beside the other caps (Phase 1 note 1);
  `PhotoNoticeStore`'s doc comment no longer implies a failing read
  `UserDefaults.bool` can't have (note 3); `theStockPhotoLinkPointsAtTheSameExistingFile`
  **and** `002`'s `theLinkedURLEndsInTheFilename` now assert the linked name
  resolves to a file opening "# Trove — Privacy Policy", so repointing both
  constants at `README.md` goes red where it used to stay green (note 2 — the
  same shape audited across both, not patched in one place); §7's "photo
  deleted mid-export" sentence gained the test it never had (note 1); and
  `PRIVACY.md`'s "Two things ever leave" sentence now says the follow-up
  requests are listed below (note 4). Note 3 of Phase 4 (the "one direction
  only" sentence has no guard) stands as recorded — §8 asked for none.

**What was verified by hand rather than by a test**, and stays that way: the
live API itself (touched exactly twice, by the recording script and the device
pass), the offline failure copy (Network Link Conditioner, the person), the
VoiceOver reading of the credit (Accessibility Inspector, the person), and the
`.task`-inside-a-sheet firing count (a temporary file probe inside
`searchPhotos`, removed before the suites ran). **A fetched photo arriving on a
second device was not observed** — no second device — so criterion 4 rests on
`CloudKitSchemaTests` and on the owned-photo sync path a fetched photo shares.

**Docs on the spec branch.** `specs/ROADMAP.md`'s status row and entry, the
README and `DECISIONS.md` are written here, not on a post-merge branch
(`DECISIONS.md`, 2026-09-07), citing draft **PR #21**. Two things the merge
reconciles: `004-themes` merged to `main` while this branch was already cut
from an earlier `main`, so `specs/004-themes/` and 004's roadmap rows are not
in this diff; and the README's Status paragraph, which neither `003` nor `004`
updated, is brought up to date here for all three.

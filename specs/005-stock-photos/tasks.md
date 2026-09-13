# 005 — Stock Photos: Tasks

**Status**: **Signed off** (2026-09-09) — skeptical-reviewer, at Opus under the
Fallback clause; nothing blocking. T015 gained the picker-`.task` probe and
T016 records OQ1/OQ2 as already settled. Ready for implementation once the
person approves the spec-conformance summary.

Drafted against the approved `spec.md` (Approved 2026-09-09) and the draft
`plan.md` in this directory, for branch `005-stock-photos` off `004-themes`.
No new technical decisions are made here — every call below traces to a plan
section; where a task says "per plan," that section is the authority. Run at
**`opus`** throughout, under `CLAUDE.md`'s model-policy Fallback clause
(Fable's budget is spent); the tier log records it.

**Foundational phases**: **Phase 1** (T001–T005) — the schema change, the
service, the copy/store/notice foundations everything else builds on.
**Tasks marked `review: per-task`**: **T001** (the `Photo` schema change —
many files inherit the contract) and **T003** (the service, licence filter and
attribution parse — the correctness core the picker, the badge, the credit and
the PDF all depend on). Every other task gets the default one review per phase.
An orchestrator left to guess guesses "all of them" — these two are the ones
marked.

Ordering note, recorded up front: the schema change (T001) lands first and is
proven CloudKit-compatible before any code depends on the new fields; the
service and the pure store/copy/notice foundations follow bottom-up, with
nothing user-visible until the Design pass (T006) has approved visuals for the
two new surfaces (the candidate picker; the stock badge + credit). Screens
follow the pass — the shared badge/credit component before the surfaces that
use it, the notice and picker in **one** sheet so no commit leaves Continue
opening an empty sheet. The live network is touched by a person **twice, and
only twice**: the fixture script (T002) and the device pass (T015). Export and
policy come after the screens (the policy quotes the copy). Tasks marked
**[person]** block on something only the person has.

House rules carried over: one commit per completed task, referencing the task
ID; every guard test is **mutation-verified** (break the rule deliberately,
confirm red) before it lands, and the Done note records what was broken and
what went red; a task is not done until `scripts/verify.sh` is green and its
actual output is reported (suite-level `-only-testing`, test count checked —
per-function selectors run zero tests and report success). Every new file
lands through the synchronized root groups — **no `.pbxproj` edit** anywhere in
this spec; if a fixture needs excluding from a target, stop and flag. **No test
opens a network connection**, ever (`CLAUDE.md` Networking).

Cadence (per `CLAUDE.md`'s model policy): each dispatch gets a **task bundle**
assembled with shell — task line, plan section, acceptance criteria, files,
pattern file — and the implementer is told not to read `plan.md`/`spec.md`/
`tasks.md` in full; verification is `scripts/verify.sh` and nothing more
verbose, re-run by the orchestrator for the two `review: per-task` tasks and
taken from the implementer's verbatim output otherwise; the `skeptical-reviewer`
reviews per phase (and the two marked tasks), one review and at most one
re-review each; the orchestrator starts a **fresh session at each phase pause**,
resuming from the first unchecked task, and every session-ending pause ends
with a continuation prompt. Everything the person reads is plain language.

## Phase 1 — Foundations, no UI (**foundational**)

- [x] **T001 — The `Photo` attribution fields, the schema change. `review: per-task`.**
  Per plan §1. Add `attributionAuthor: String?`, `attributionLicense: String?`,
  `attributionSourceURL: String?` to `Photo` (after `sortOrder`, each
  defaulted), plus the `Photo.attribution` accessor, the `Photo.fetched(...)`
  builder, and `StockPhotoAttribution` (a `Sendable` value, in
  `StockPhotoService.swift` — created minimal here, the service in T003). New
  `PhotoAttributionTests`: a `.device` photo has nil attribution; a built
  `.fetched` photo round-trips author/licence/URL through a second context; the
  builder sets `source == .fetched`. **CloudKit red run**: declare one new
  field non-optional without a default → `CloudKitSchemaTests` names it → revert.
  **Verify:** `scripts/verify.sh` green with the new tests; `CloudKitSchemaTests`
  green; the red run recorded in the Done note.
  **Done (2026-09-09):** three optional-with-default fields added after
  `sortOrder`; `Photo.attribution` accessor (nil unless `.fetched`; defensive
  fallbacks — nil author → "Wikimedia Commons", nil licence → "", nil/unparseable
  URL → Commons main page) and `Photo.fetched(...)` builder in a `Photo`
  extension; minimal `StockPhotoAttribution` (`Sendable, Equatable`) in new
  `Trove/Photos/StockPhotoService.swift` (`Equatable` a flagged in-footprint
  add). New `Trove/Photos/` is auto-membered — `Trove` is a
  `PBXFileSystemSynchronizedRootGroup`, no `.pbxproj` edit (holds for later
  `Trove/Photos/` tasks). **Red run:** `attributionLicense` made
  non-optional-without-default → `CloudKitSchemaTests.schemaMeetsCloudKitRequirements()`
  red (`SwiftDataError.loadIssueModelContainer`, CloudKitSchemaTests.swift:23) →
  reverted → green. **Verify (orchestrator re-ran):** 1150 tests / 154 suites
  passed, exit 0. **Review:** skeptical-reviewer signed off, nothing blocking.
  Two non-blocking notes: red run demonstrates additive-ness directly for one
  field and by identical shape for the other two (low risk); the accessor's
  defensive fallback branches are untested here → **carried to T007/T009**, the
  credit-rendering tasks, which should test the no-author → "Wikimedia Commons"
  branch.

- [x] **T002 — The fixture script and the recorded fixtures. [person: runs it]**
  Per plan §2 (Fixtures). New `scripts/record-wikimedia-fixtures.sh` (curl + a
  python trim; the User-Agent header) writing `TroveTests/Fixtures/Wikimedia/`:
  `search-camera.json` (a real gear query, each file trimmed to `pageid`,
  `title`, `imageinfo[0].{url,descriptionurl,thumburl,mime}` and the five
  `extmetadata` keys the app reads) and, hand-built,
  `search-mixed-licences.json` (CC0, PD, CC-BY, CC-BY-SA, CC-BY-NC, CC-BY-ND,
  GFDL-only, no-licence — one file each), `search-no-author.json` (a PD file
  with no `Artist`), `search-empty.json` (no `query`), and the byte-ceiling
  fixtures. A `TroveTests/Fixtures/Wikimedia/README.md` records the date, the
  query used, and that titles/authors are Wikimedia content kept only in the
  test target. The script is run **by hand, once**, by or with the person; its
  output is committed and reviewed as a diff. Nothing under `Trove/` changes.
  **Verify:** every fixture parses (`python3 -m json.tool`); the README is
  written; `scripts/verify.sh` count unchanged (no `Trove/` change).
  **Done (2026-09-09):** recorder `scripts/record-wikimedia-fixtures.sh`
  (formatversion=2 so `query.pages` is an array; trims each page to
  `imageinfo[0]` + the five extmetadata keys; marker-preserving doc writer) and
  the hand-built fixtures written; the person ran the live recording → 20-page
  `search-camera.json` (Nikon D750), all 20 reusable-licensed (cc-by-2.0 ×8,
  cc-by-sa-4.0 ×6, cc0 ×2, cc-by-sa-3.0-de ×2, cc-by-sa-2.0 ×2). All fixtures
  parse; `bash -n` clean; `scripts/verify.sh` 1150 tests / 154 suites, unchanged.
  **Deviation 1 (escape hatch — implementer stopped on a well-specified fork,
  orchestrator resolved):** the test target is a synchronized folder that copies
  every file flat into the test bundle, so a second `README.md` collided with
  `Fixtures/Reverb/README.md`. Options A/C were `.pbxproj` exclusions, ruled out
  by this spec's hard "no `.pbxproj` edit" rule; resolved by option B — the
  Wikimedia doc is `wikimedia-fixtures.md`, a unique basename (plan §2 said
  `README.md`; the intent — a fixtures doc — is unchanged).
  **Deviation 2 (plan corrected in place):** the live thumbnails come from
  `thumb.wikimedia.org` (18/20), not the two literals plan Q1 named, so the
  image-host allowlist is corrected to a `.wikimedia.org` **suffix** check —
  updated in plan §2/Q1 and carried into **T003**. URLs also carry `utm_*`
  params and a 1280 px bucket for a 1024 request (both harmless; noted in plan).

- [x] **T003 — `StockPhotoService`, `WikimediaPhotoService`, decoding, the licence filter, attribution. `review: per-task`.**
  Per plan §2 and §3. New `Trove/Photos/StockPhotoService.swift` (protocol with
  two `@concurrent` requirements, `StockPhotoCandidate`, `StockPhotoLicence`,
  `StockPhotoError`) and `WikimediaPhotoService.swift` (`WikimediaAPI`
  constants incl. `userAgent(version:)` reading `StockPhotoCopy.contactAddress`
  — minimal `StockPhotoCopy` with just the address lands here, the rest at T004;
  ephemeral session, `waitsForConnectivity = false`; `URLComponents`
  everywhere; per-request headers, no `Authorization`; the Wikimedia-host check
  on the image URL; the byte ceiling; the error mapping; `requestProbe` seam),
  `WikimediaDecoding` (wire structs, the `plainText(fromHTML:)` author strip),
  and `StockPhotoLicence.classify`. `WikimediaDecodingTests` and
  `WikimediaPhotoServiceTests` (`.serialized`, `StubURLProtocol` keyed by URL,
  **no sockets**) per plan §2/§3: filtering (only reusable survive; the count
  and the absent NC/ND/GFDL/none titles), attribution parse (author HTML
  stripped, licence name, file page), the no-author fallback, the cap (Q3), the
  name-only request, the punctuation round-trip, `Authorization` absent, the
  offline/500 mapping, the byte ceiling, the foreign-host image URL not
  fetched, the `@concurrent` probe. Mutations, each reverted: a filtered
  licence classified reusable → red; the HTML strip dropped → red; the cap
  removed → red; a query item added → red; the host check dropped → red;
  `@concurrent` off both requirement and implementation → the probe red;
  a placeholder contact address → the address guard red.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs — `review:
  per-task`); every mutation recorded; no test opens a connection.
  **Done (2026-09-09):** `StockPhotoService` protocol (two `@concurrent` reqs),
  `StockPhotoCandidate`, `StockPhotoLicence` (`classify` reads reusability from
  the `License` code, display from `LicenseShortName`), `StockPhotoError`;
  `WikimediaPhotoService` (ephemeral session, `.wikimedia.org`-suffix host
  check before any image fetch, ~8 MB byte ceiling, one-place error mapping,
  `requestProbe`); `WikimediaDecoding` (formatversion=2 wire structs,
  session-free `candidates(from:cap:)`, a total hand-rolled
  `plainText(fromHTML:)`); minimal `StockPhotoCopy.contactAddress`. Tests over
  the T002 fixtures via a **dedicated** `WikimediaStubURLProtocol` (not the
  Reverb stub — Swift Testing runs suites in parallel and the stub's state is
  static). **Verify (orchestrator re-ran):** 1169 tests / 157 suites, exit 0
  (up from 1150). All 7 guards mutation-verified (G2 filter, G3 attr-parse, G4
  cap, G5 name-only, G6 `@concurrent`, G7 host-check, + address guard).
  **Review:** one blocking finding — ported-licence acceptance
  (`cc-by-sa-3.0-de`, real recorded data) was correct but unguarded; fixed by a
  falsifiable classifier-table assertion (mutation-verified), **re-review
  resolved**. Deviation: T001's `StockPhotoAttribution` marked `nonisolated`
  (required — a `nonisolated` candidate can't embed a MainActor-default value;
  one-token, no member change; noted for T004). Non-blocking notes carried
  forward: `fetch`'s `catch` maps every error to `.unreachable` (a
  `CancellationError` is swallowed) — consider narrowing to `URLError`; a
  nonstandard CC0/PD spelling (`cc-zero`) would be dropped (safe direction);
  G5's teeth are the stub-miss, matching the Reverb idiom (acceptable).

- [x] **T004 — `StockPhotoCopy` in full, and the notice store.**
  Per plan §5 and the Copy section. `StockPhotoCopy` (`nonisolated enum`,
  `Trove/Models/`): `findAPhoto`, `noticeBody`, `noticeContinue`,
  `noticeNotNow`, `pickerTitle`, `emptyState`, `searchAgain`, `badge`,
  `credit(author:licenseName:)`, the replace/keep alert strings, `failure`,
  the accessibility strings, `contactAddress` (filled by the person; the
  placeholder guard from T003 moves here), `privacyPolicyURL`/`Filename` (the
  blob URL). New `Trove/Photos/PhotoNoticeStore.swift` (`PhotoNoticeStore`
  protocol, `UserDefaultsPhotoNoticeStore(defaults:)`). `StockPhotoCopyTests`
  (every string pinned whole, the notice reassembly, the credit at a real and a
  no-author author, the address guard) and `PhotoNoticeStoreTests` (over an
  in-memory `UserDefaults(suiteName:)`: fresh false; acknowledge true; a second
  store sees it). Mutations: drop the write in `acknowledge` → the second-store
  test red; a placeholder address → the guard red.
  **Verify:** `scripts/verify.sh` green with the new suites; mutations recorded.
  **Done (2026-09-09):** `StockPhotoCopy` extended with every string pinned
  exactly (the spec's proposed copy, P7 settled here); `PhotoNoticeStore`
  protocol + `UserDefaultsPhotoNoticeStore` (one bool key, missing→false,
  per-device unsynced). `StockPhotoCopyTests` extended (whole-string pins,
  notice reassembly to the full spec sentence, credit at real + no-author
  authors) and new `PhotoNoticeStoreTests` (per-test UUID suite, never
  `.standard`). **Verify (implementer verbatim, not per-task):** 1182 tests /
  158 suites, exit 0. **Mutation:** `acknowledge()` write dropped → the
  second-store persistence test red → reverted. **Deviations/notes:** no
  separate `replaceKeepTitle` — the spec pins only the question, which serves
  as the alert's title in T010 (SwiftUI allows it), no separate message
  needed; the optional a11y credit value left for T009 to request with a
  pinned string; `UserDefaults` isn't `Sendable`, so the store holds it as
  `nonisolated(unsafe) let` (UserDefaults is thread-safe; the `SyncMonitor`
  precedent) — the sanctioned pattern for a `UserDefaults`-backed store here.

- [x] **T005 — The fetch/store logic and the service spy.**
  Per plan §4. Add to `PhotoSelection`: `canFindPhoto(_:)`,
  `addingFetched(_:to:)` (at most one `.fetched`, appended after `.device`
  photos, renumbered). `StockPhotoServiceSpy` in `TestSupport` (scripted
  results behind a `Mutex`, an exhausted script throws — the `MarketServiceSpy`
  shape). `PhotoSelectionStockTests`: `canFindPhoto` false with a device photo,
  true for empty and stock-only; `addingFetched` twice → one `.fetched`; a
  device photo leads after `addingFetched`; the replaced fetched photo is in
  `orphaned(...)`. Mutations: skip the removal → two fetched → red; append
  before device photos → the leads test red.
  **Verify:** `scripts/verify.sh` green; mutations recorded. **Phase 1 closes
  here — pause for the person.**
  **Done (2026-09-09):** `PhotoSelection.canFindPhoto(_:)` (no `.device` photo)
  and `addingFetched(_:to:)` (drops the existing `.fetched`, appends after
  `.device` photos, renumbers) — pure, store-free. `StockPhotoServiceSpy` added
  to `TestSupport` (the `MarketServiceSpy` scripted-`Result`/`Mutex` shape,
  exhausted script throws). New `PhotoSelectionStockTests`. **Verify:** 1190
  tests / 161 suites, exit 0. **Mutations:** removal skipped → two `.fetched`
  (and the orphan test) red; ordering reversed → owned-leads test red; both
  reverted. No deviations.

## Phase 2 — Design

- [x] **T006 — The Design pass. [person: invokes `/design`, approves]**
  Per spec's Design requirements (the `002` Decision 10 pattern). Claude Code
  writes the `/design` prompt: the two new surfaces — the **candidate picker**
  (an image-first grid/list with a credit under each) and the **stock-photo
  presentation** (the **Stock photo** badge and the credit line on the detail
  screen and the list row), every string from `StockPhotoCopy`,
  `design/brief.md`'s rules (bespoke in the page, the app's type and tokens, no
  rendered materials), `001`'s fixed type sizes, the existing detail/row PNGs
  for context. The person runs it, iterates in the canvas, drops the
  `.dc.html` artboards and PNGs under `design/elements/005-stock-photos/`, and
  `design/tokens.md` gains a "Stock photos (`005`)" section with "as
  implemented" cells for the screen tasks. **If the pass proposes new copy,
  that is a spec question — escalate, don't absorb.**
  **Verify:** artboards and PNGs committed; the tokens section written; the
  person's approval recorded in the Done note. **Phase 2 closes here.**
  **Done (2026-09-09):** Claude Code wrote the `/design` brief
  (`design/elements/005-stock-photos/brief.md`); the person ran `/design`,
  iterated, **approved** ("I like them"), and saved 11 `.dc.html` artboards +
  PNGs + `canvas.json` into the folder — picker (notice, searching, results
  grid `Main`, downloading, empty, failed) and presentation (stock hero over
  dark + light, owned-leading-plus-kept-stock, both lists' stock marks). The
  grid is image-first: a 2-column square-cropped grid with a compact
  author·licence credit under each. `design/tokens.md` gained the "Stock photos
  (`005`)" section from the artboards. **No new copy escalated** — every string
  matches `StockPhotoCopy`. Two notes carried to the screen tasks:
  - **T008:** the design uses two functional strings not yet in `StockPhotoCopy`
    — `searching` = "Searching Wikimedia Commons…" and a field placeholder
    "Search Wikimedia Commons" (Wikimedia analogs of `002`'s exact strings,
    adopted by the approved design, so settled, not a product escalation) — add
    them to `StockPhotoCopy` when the picker view lands.
  - **T007:** the badge renders "STOCK PHOTO" (uppercase) via the app's mono
    all-caps label style; keep `StockPhotoCopy.badge` = "Stock photo" and
    uppercase in the view (`.textCase(.uppercase)`), not in the string.

## Phase 3 — Screens

- [x] **T007 — The shared badge and credit component.**
  Per plan §6 (the shared component) and T006's artboards. New
  `Trove/Views/Shared/StockPhotoBadge.swift` (the **Stock photo** capsule, its
  a11y label) and `StockPhotoCredit.swift` (the credit line with a SwiftUI
  `Link` to the file page and its hint), both reading `StockPhotoCopy` and the
  theme tokens. `StockPhotoBadgeTests`: the credit composes a `Link` (the
  non-identifier-boundary regex); the strings come from `StockPhotoCopy`; the
  link's hint is present. Mutation: the `Link` made a `Button` → the scan red.
  **Verify:** `scripts/verify.sh` green; the mutation recorded.
  **Done (2026-09-09):** `StockPhotoBadge` (the "Stock photo" capsule,
  uppercased by `.textCase(.uppercase)` — stored `StockPhotoCopy.badge`
  unchanged; `monoLabel`/`monoLabelTracking`/`textBody`; near-opaque
  `background.opacity(0.9)` ground, ivory 14 %/72 % border+glyph as flagged
  local literal opacities on `textPrimary`, commented; a11y label from copy)
  and `StockPhotoCredit(attribution:)` (composed by splitting
  `StockPhotoCopy.credit(...)` on the padded separator so the plain-text and
  rendered forms share one source string; body `secondary`/`textLabelSecondary`,
  licence run `monoMeta`/`textMonoMeta`, source segment a real `Link` in
  `accentBrass` with `arrow.up.right` a11y-hidden, `creditLinkHint`, identifier
  `stockphoto.credit.link`). Five guards in `StockPhotoBadgeTests`.
  **Verify:** 1196 tests / 162 suites passed, exit 0. **Mutations:** `Link(` →
  `Button(` → Link-not-Button guard red (links → 0); badge string uppercased
  instead of `.textCase` → the uppercase-by-style guard red; both reverted.
  (Also caught in development: a `StockPhoto.credit(` call split across lines
  failed the strings-from-copy scan → fixed to one line — the guard can fail.)
  **T001 carry-forward:** the no-author fallback (`author == "Wikimedia
  Commons"`) credit is now tested. **Deviations:** badge glyph
  `photo.on.rectangle` and the link's `arrow.up.right` use SF Symbol
  weight as the nearest analog to the artboard's numeric stroke (SF Symbols
  expose no stroke width — the `MarketMatchView` glyph idiom).

- [x] **T008 — The notice + candidate-picker sheet, and the picker view model.**
  Per plan §4 (`PhotoFetchViewModel`) and §6 (the sheet). New
  `Trove/ViewModels/PhotoFetchViewModel.swift` (`query`, `phase`,
  `isDownloading`, `search()` seeded and submit-driven, `download(_:)`; reentry
  guarded; every non-`imageTooLarge` error → `.failed`) and
  `Trove/Views/Photos/PhotoNoticeView.swift`, `PhotoPickerSheetView.swift` (the
  two-phase sheet: notice with the privacy `Link` and Continue/Not now, then
  the `NavigationStack` picker — `SearchField`, `.onSubmit`, the seeded `.task`
  search, the status line, `EmptyStateView` for empty/failed with **Search
  again**, the candidate grid of `AsyncImage` cells with `StockPhotoCredit`
  beneath, a downloading spinner). `PhotoFetchViewModelTests` (spy-driven: the
  seed is the item's name — mutation appending the category → red; blank never
  calls; results/empty/failed phases; reentry; a download returning bytes +
  attribution). Wiring scans: the notice's `Link(` to the policy URL; the
  candidate composes `StockPhotoCredit`; `AsyncImage(` in exactly one photos
  view file; the identifiers.
  **Verify:** `scripts/verify.sh` green; mutations recorded.
  **Done (2026-09-09):** `PhotoFetchViewModel` (mirrors `MarketMatchViewModel`;
  `.failed` valueless — one stock failure message; `download(_:)` returns
  `StockPhotoDownload?`), `PhotoNoticeView` (002's notice shape, `StockPhotoCopy`
  copy, real privacy `Link`, generic word-free chrome reused per plan not
  duplicated) and `PhotoPickerSheetView` (`NavigationStack`, `SearchField`,
  seeded `.task` + `.onSubmit`, inline status line, 2-col `LazyVGrid` of
  `AsyncImage` cells with the **compact** `StockPhotoCredit` beneath,
  `EmptyStateView` empty/failed with **Search again**, grid-level downloading
  spinner). Settled up front: (A) `StockPhotoCopy.searching`/`searchPlaceholder`/
  `cancel` added + pinned; (B) `StockPhotoDownload` value type in
  `StockPhotoService.swift`; (C) `StockPhotoCredit` gained `Style{.full,.compact}`
  (`.full` unchanged, T007 tests green) so the grid composes the one component;
  (D) notice reuses `.marketFilledChrome`/`.marketOutlinedChrome`.
  **Verify:** 1211 tests / 164 suites passed, exit 0. **Mutations:** append to
  the query before the search → seed/trim/reentry tests red; notice `Link`→
  `Button` → notice-link scan red; `AsyncImage (` spaced → both the photos-dir
  scan and the 002 network-image guard red; all reverted.
  **Deviation (outside footprint, required consequence):** T008 legitimately
  adds a **second** sanctioned network-image surface, so
  `MarketWiringTests.onlyThePickerFetchesAnImageFromTheNetwork` (a 002 guard
  asserting exactly one `AsyncImage` file under `Trove/Views`) was **broadened**
  — not weakened — to the exact ordered pair `[MarketMatchView,
  PhotoPickerSheetView]`; a third fetcher or a dropped fetch still goes red
  (confirmed by the spaced-`AsyncImage` mutation). Orchestrator reviewed the
  edit: teeth intact. Carried to the phase review.

- [x] **T009 — Detail screens: Find a photo…, storing the pick, badge + credit.**
  Per plan §6 (the hosting view models, detail; the carousel). Both
  `ItemDetailViewModel` and `WishlistDetailViewModel` gain `photoService`/
  `noticeStore` injection, the shared state and intents (`findPhoto`,
  `continueFromNotice`, `declineNotice`, `store(_:)` — build `Photo.fetched`,
  `addingFetched`, delete the orphan, one save, `updatedAt` on owned only, a
  refused save rolls back), `canFindPhoto`, `makePhotoFetchViewModel()`.
  `ItemDetailView`/`WishlistDetailView` gain the **Find a photo…** action (in
  the existing action style, shown iff `canFindPhoto`) and attach the sheet;
  `PhotoCarousel` shows the badge over a `.fetched` current page and the credit
  line beneath the hero, and its a11y value announces a stock photo as a
  representative image (criterion 11). Tests (mirrored, spy-driven): the notice
  then picker sequence; a stored pick lands one `.fetched` photo on a second
  context; a failed download stores nothing; `canFindPhoto` follows the
  owned-photo rule; the carousel shows the badge/credit only for `.fetched`.
  Mutations: drop the orphan delete → a leaked blob (second-context) → red;
  store on a failed download → red; show the badge for a device photo → red.
  **Verify:** `scripts/verify.sh` green; mutations recorded; the states seen by
  eye on the simulator against the artboards (named in the Done note).
  **Done (2026-09-09):** both detail VMs gained `photoService`/`noticeStore`
  injection and the photo members (named `findPhoto`/`continuePhotoNotice`/
  `declinePhotoNotice`/`makePhotoFetchViewModel`/`isFindingPhoto`/`photoSheetStep`/
  `canFindPhoto`/`store(_:)`) to avoid colliding with the existing Market-sheet
  members; `store(_:)` builds `Photo.fetched`, `addingFetched`, deletes orphans
  (no leaked blob), one save, `updatedAt` **owned only** (Decision 24 — the sole
  divergence), rollback+reload on a refused save. Both detail views attach a
  second `.sheet` (notice/picker) and an outlined-brass **Find a photo…** action
  (id `stockphoto.find`) below the carousel, shown iff `canFindPhoto`.
  `PhotoPickerSheetView` refined: the cell downloads via its fetch VM (driving
  the spinner) and hands a `StockPhotoDownload` to a host `store` closure — so a
  nil (failed) download stores nothing (criterion 7). `PhotoCarousel` gained the
  badge overlay + full credit line beneath the hero for a `.fetched` current
  photo, and its a11y value announces the representative-image wording + credit.
  **Verify:** 1227 tests / 167 suites passed, exit 0; T007/T008 suites still
  green. **Mutations:** orphan-delete skipped → replaced-stock leaks a second
  row (2nd context) red; `download` returns bytes on `.failure` → failed-download
  stores-nothing tests red; badge gate `!= nil` → badge-only-for-fetched red;
  (bonus) credit gated off → credit-adds-height red; all reverted.
  **Deviations:** (1) the carousel badge render test detects the badge's **light
  "STOCK PHOTO" label pixels**, not the dark capsule — `ImageRenderer` doesn't
  render the paging-`ScrollView` hero image (no container size), so both photos
  render uniformly dark; the label is the reliable differentiator (the bundle's
  sanctioned fallback, mutation-verified). (2) kept the explicit
  `modelContext.insert(photo)` in `store` (the second-context test confirms one
  row lands). Artboards built to: `ItemStockHeroDark/Light`, `ItemOwnedPlusStock`
  — for the person's phase-pause eye check.

- [x] **T010 — Forms: Find a photo…, the in-memory append, the replace/keep prompt.**
  Per plan §6 (the hosting view models, form; the replace/keep prompt). Both
  form view models gain `photoService`/`noticeStore` injection, the notice
  intents, `canFindPhoto`, `makePhotoFetchViewModel()`, and the pick's
  in-memory `addingFetched` append (the existing `save()` writes it;
  `orphaned(...)` deletes the replaced fetched photo). `ItemFormView`/
  `WishlistFormView` gain **Find a photo…** adjacent to `PhotoPickerField`,
  shown iff `canFindPhoto`. `PhotoPickerField` gains the **replace / keep**
  system alert when a `.device` photo is added while a `.fetched` photo is
  present: **Replace** removes the fetched photo, **Keep both** keeps both with
  the owned photo leading. Tests: adding a device photo with a stock photo
  present raises the prompt; Replace → one `.device` photo; Keep both → two,
  the device photo leading; a stored fetched pick on the form lands in `photos`.
  Mutations: skip the prompt (append silently) → the prompt test red; Keep both
  ordering reversed → the leads test red.
  **Verify:** `scripts/verify.sh` green; mutations recorded; the prompt seen by
  eye on both forms.
  **Done (2026-09-09):** both form VMs gained the same photo members as the
  detail VMs (T009), with an in-memory `store(_:)` — `addingFetched` into the
  `photos` array, no save/insert/orphan here (the form's own `save()` persists
  and runs `orphaned(...)`). Three pure `PhotoSelection` helpers added:
  `shouldPromptReplaceOrKeep(addingCount:to:)`, `addingReplacingStock` (device
  only, stock dropped), `addingKeepingStock` (device leads, stock trails,
  renumbered). `PhotoPickerField` gained the two-button system `.alert` (Keep
  both, Replace destructive) raised from `load(_:)` when device photos are added
  over a `.fetched` photo, and its stale "device-only/deferred" doc comment was
  corrected. Both form views gained the outlined-brass **Find a photo…** action
  (id `stockphoto.find`) after `PhotoPickerField` and the two-phase photo sheet.
  **Verify:** 1246 tests / 171 suites passed, exit 0; T005/T007/T008/T009 green.
  **Mutations:** Keep-both ordering reversed → device-leads test red; Replace
  not filtering → one-device/no-stock + orphan tests red; prompt branch removed
  (append silently) → the field's consult-scan red; all reverted. No deviations.
  The alert's runtime rendering isn't unit-inspectable → verified two ways (pure
  predicate/helpers + a field source-scan); the actual alert on both forms is
  the person's phase-pause eye check.

- [x] **T011 — List rows: the leading rule and the stock badge.**
  Per plan §6 (list rows). `RowThumbnail` overlays a small `StockPhotoBadge`
  only when its leading photo (`inDisplayOrder(photos).first`) is `.fetched`;
  `ItemRow`/`WishlistRow` a11y labels announce a stock thumbnail as a
  representative image. Tests: a stock-only item's row shows the badge; an item
  with an owned photo shows none (the owned photo leads); the row's a11y label
  carries the stock wording for a fetched leading photo. Mutation: show the
  badge whenever any photo is fetched (not only the leading one) → the
  owned-photo row red.
  **Verify:** `scripts/verify.sh` green; mutation recorded; the badge seen by
  eye on both lists.
  **Done (2026-09-10):** design reconciliation (same shape as T008/T010) — the
  row uses a tiny **glyph-only corner mark** (the approved artboard), so
  `StockPhotoBadge` gained a `Style{.full,.mark}` (`.full` = T007's capsule,
  unchanged; `.mark` = 16×16 rounded square, `background.opacity(0.9)` ground,
  ivory-16 % border, glyph only, a11y-hidden). New shared predicate
  `PhotoSelection.leadsWithStock(_:)` (leading display-order photo is `.fetched`)
  gates both `RowThumbnail`'s `.topLeading` overlay and the two rows'
  `.accessibilityValue` (announcing `badgeAccessibilityLabel` for a stock-leading
  row) — so the mark and the spoken label can't drift. **Verify:** 1252 tests /
  173 suites passed; T007 badge tests and the `RowThumbnail` size tests still
  green (the mark is an overlay, slot size unchanged). **Mutations:**
  `leadsWithStock` → `contains{.fetched}` → predicate + render tests red; the
  overlay gate → `contains{.fetched}` → owned-leading corner goes dark (render)
  red while the predicate suite stays green (targets the overlay specifically);
  `ItemRow`'s a11y value line removed → the row a11y scan red; all reverted.
  Runtime `.accessibilityValue` isn't unit-inspectable → predicate test + source
  scan are the falsifiable decomposition; VoiceOver is the person's device check.

- [x] **T012 — UI tests, offline, run twice.**
  Per plan §6 (UI tests), Q10. The four tests with `-uiTesting`: an item with
  no photo (owned and wanted) shows `stockphoto.find` and one with an owned
  photo does not; the first Find a photo… shows the notice with Continue and
  Not now, Not now closes it and the next Find a photo… shows it again; the
  offline empty/failure states read. No UI test taps Continue, searches live or
  stores a photo (Q10) — the Done note says so; the suite is run **twice back
  to back** to confirm re-runnability. Mutations: render the action on an
  owned-photo item → the second test red; Not now acknowledging → the notice
  test red.
  **Verify:** `scripts/verify.sh ui` green twice; mutations recorded. **Phase 3
  closes here — pause for the person.**
  **Done (2026-09-10):** **scope reconciled to the 002 "offline states only"
  precedent** — two of the four named tests are infeasible under Q10 and are
  carried by the unit suites + T015 (no seed/stub added, Q10 honored): the
  **owned-photo-hides** case needs a `.device` photo (no library/seed available)
  → covered by `canFindPhoto` (T005/T009/T010, mutation-verified there); the
  **empty/failure states** live inside the picker, reachable only past Continue
  (forbidden) → covered by `PhotoFetchViewModelTests` (T008) + the T015 device
  pass. The two **feasible** tests were added, mirroring 002:
  `testAnItemWithNoPhotoOffersFindAPhoto` (owned + wanted show `stockphoto.find`)
  and `testTheFirstFindAPhotoShowsTheNoticeAndNotNowClosesIt` (notice with
  Continue/Not now, `stockphoto.search` stays behind it, Not now closes without
  acknowledging, next Find shows it again; **Continue never tapped**). **Verify:**
  `scripts/verify.sh ui` green **twice** back to back (16 tests, 0 failures each).
  **Mutations:** `declinePhotoNotice` acknowledging → the notice test red; forced
  `canFindPhoto = false` → the offers-the-action test red; both reverted.
  **Finding (carry to T015):** the notice flag lives in `UserDefaults.standard`,
  which `-uiTesting` does **not** reset (unlike the market notice, which rides
  the in-memory model store). Harmless in clean code (no UI test taps Continue),
  but T015's device pass — which does tap Continue — must reset it between the
  "notice shows once" and any relaunch check (the implementer used `simctl
  uninstall` to clear it after the acknowledging mutation). An asymmetry worth
  the phase review's eyes.
  **Phase 3 review (2026-09-10, `skeptical-reviewer` at opus):** one **blocking**
  finding — the `UserDefaults.standard` notice flag above breaks `-uiTesting`'s
  controlled-starting-state contract (CLAUDE.md; the 003 amendment's structural
  bound) — **fixed and re-reviewed** (see the fix row in the tier log). The
  reset now happens in `TroveApp.init` via
  `UserDefaultsPhotoNoticeStore.resetForUITesting(mode:)`, structurally gated on
  the built `.ephemeral` store. Non-blocking notes recorded in plan §6 (the
  4-vs-2 UI-test reconciliation; criterion 11's row-credit reading) and carried
  to T015 (the picker `.task` probe; the two stacked detail sheets both present;
  a silent failed download reads as a working button) and the pre-merge sweep
  (the `marketFilledChrome`/`marketOutlinedChrome` name reads coupled though the
  chrome is generic — a rename candidate; verify 005's self-containment wording).

## Phase 3b — Search relevance (added 2026-09-10, spec Decision 7)

Inserted after the person's Phase 3 device testing surfaced that Wikimedia's
text search returns photos *taken with* the searched gear alongside (and
sometimes instead of) photos *of* it. The person chose the **filter-only**
scope (drop taken-with-the-same-camera results; no query broadening) **in 005
before merge**. This one task modifies the T003 correctness core, so it is
**`review: per-task`**. It runs before the T015 device pass, so the device pass
exercises the filtered search.

- [x] **T012a — The taken-with relevance filter. `review: per-task`.**
  Per plan §3a and spec Decision 7. Extend the search request
  (`WikimediaPhotoService`/`WikimediaAPI`) to ask for `categories`
  (`prop=imageinfo|categories`, high `cllimit`; P1 unchanged — same `gsrsearch`,
  one extra field back). Extend `WikimediaDecoding` to decode each page's
  `categories[].title` and add
  `isTakenWithSearchedGear(categories:query:)` — drop a candidate iff a category
  title lowercased begins `"taken with "` **and** the camera name after shares a
  **digit-bearing** token with the query (so brand-only overlap never drops; a
  no-digit-token name drops nothing; truncated/absent categories → keep, the
  safe direction). Run the filter after the licence filter and before the ≤ 12
  cap. Update the T002 recorder to also capture `categories` (trimmed to titles)
  for future re-records; the tests use **hand-built** fixtures
  (`search-taken-with.json`, the classifier-oracle pattern), so **no live
  re-record is needed** — live behaviour is verified in the T015 device pass.
  New `WikimediaRelevanceTests` (or extend `WikimediaDecodingTests`): same-model
  taken-with dropped; different-model taken-with (the R5 case) kept; brand-only
  overlap kept; no-digit-token query drops nothing; truncated/absent categories
  kept. Mutations (each reverted, recorded): match on any shared token →
  R5-keep red; drop the `"taken with"` prefix requirement → a subject-category
  "…X2D…" file wrongly dropped → red; invert keep-on-truncation → the
  truncated-file test red.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs — `review:
  per-task`); every mutation recorded; no test opens a connection.
  **Done (2026-09-10):** request adds `prop=imageinfo|categories` + `cllimit=500`
  (P1 intact — `gsrsearch` still only the name); `Page` wire gains `categories`;
  `candidates(from:query:cap:)` drops taken-with-same-gear after the licence
  filter, before the cap; `isTakenWithSearchedGear` matches on **alphanumeric-
  fused** tokens (a letter AND a digit) so brand words and **bare numbers** never
  drop a product shot; absent/truncated categories → keep (safe). Hand-built
  `search-taken-with.json` + `WikimediaRelevanceTests`; recorder updated for
  future re-records (not run live). **Verify (orchestrator re-ran):** 1261 tests
  / 174 suites, exit 0. **Review:** per-task — **1 blocking** (bare-number false
  drop: a `24-70mm F2.8` lens shot taken with an iPhone 8 was wrongly dropped via
  the shared bare `8`) → fixed by the fused-token rule + a regression fixture/
  test, **re-review resolved, nothing open**. Also caught: the first review
  bundle omitted the new untracked test file (my `git diff` miss — CLAUDE.md's
  `git add -N` rule); re-review saw it in full and confirmed every relevance test
  falsifiable. Non-blocking: `aNoFusedTokenQueryDropsNothing` is a
  characterization test (the empty-set guard is a pure optimization, nothing to
  falsify); gear with no fused designator (`iPhone 15`) is un-droppable by design
  (plan §3a note). Anchors hold: R5 product shot kept, X2D portrait dropped.

## Phase 4 — Export and policy

- [x] **T013 — PDF export: the fetched photo with its credit (subject to OQ1).**
  Per plan §7. `PDFEntry` gains `photoCredit: String?`; the two `init(record:)`
  mappings read it from the leading photo's attribution (the export record
  snapshot carries the leading photo's author + licence beside `firstPhotoID`);
  `PDFComposer.drawEntry` draws the credit beneath the photo box for a
  `.fetched` leading photo. CSV untouched (criterion 8). Tests: a fetched-photo
  entry carries and draws the credit; a device-photo entry carries none.
  Mutation: always set `photoCredit` → the device-photo assertion red.
  **If the sign-off resolves OQ1 to exclude CC-BY-SA from the PDF**, this
  task's mapping filters those photos out — a contained change noted here.
  **Verify:** `scripts/verify.sh` green; mutation recorded.

- [x] **T014 — `PRIVACY.md`, its guard, and the README sentence.**
  Per plan §8. `PRIVACY.md`: Wikimedia Commons named as a second outside
  service; the photo search added to "what leaves your device" (the item's
  name, only on the person's action, only after the notice); the statement that
  a fetched photo **does sync**; the "No image ever leaves the app" line
  reworded. `PrivacyPolicyTests` gains: quotes `StockPhotoCopy.noticeBody`
  verbatim, names Wikimedia Commons and the sync statement, carries the contact
  address, no placeholder. README gains the stock-photo feature sentence.
  Mutations: one word of the quoted notice changed → red; the file renamed →
  the existence assertions red.
  **Verify:** `scripts/verify.sh` green; mutations recorded. **Phase 4 closes
  here.**

## Phase 5 — Verification and close-out

- [x] **T015 — Device pass with the live API. [person: watches the live half]**
  Per every criterion — the second and last time the network is touched.
  iPhone simulator, dev store: on a wishlist item with no photo, Find a photo…
  → the notice once (Not now first, then Continue, and no notice on a second
  item across a relaunch); the live search, the candidate grid with credits,
  the pick → the stored photo on the detail with its badge and credit, the
  credit's link opening the Commons file page; the thumbnail on the list row;
  the empty state on a name with no usable photos; offline (Link Conditioner
  100 % loss) → the failure copy, nothing stored; add an owned photo to the
  stock-photo item → the Keep/Replace prompt, both outcomes; remove a fetched
  photo; export → the PDF with the credit, the CSV without a photo column;
  VoiceOver over the action, a candidate, the badge and the credit; the sync
  half (a fetched photo appearing on a second device) recorded as an honest
  partial if a second device isn't available. `-uiTesting` store for anything
  destructive. Full suite twice; UI suite twice. Every finding fixed in place
  or listed for T016.
  **Instrument the picker's `.task`, don't eyeball it** (CLAUDE.md's Testing
  rule; the shape 002's sweep caught): a `.task` inside sheet content is
  invisible to the view-model suite, so add a temporary file/print probe inside
  `searchPhotos` and confirm on device that the live search fires **once per
  intended open** and does **not** fire on the notice's **Not now**, on a
  Keep/Replace prompt, or on any sheet re-render — settle "fired once" by the
  probe, never by inferring from the rendered grid.
  **Verify:** the record written into the Done note with what was seen,
  including the `searchPhotos` probe's firing count per action; both suites
  green twice. **Also (Phase 1 review note 2):** if a Wikimedia file dual-licensed
  GFDL **and** CC-BY-SA turns up in a live search, confirm it is offered and
  credited by its CC-BY-SA licence (plan §3/Q4 — no fixture covers this; it
  depends on the live `License` code); record what the API returned. An honest
  "not encountered in the device pass" is acceptable.
  *Done 2026-09-11* — iPhone 17 Pro simulator (iOS 26.0), the `-uiTesting`
  in-memory store for the whole walkthrough except the one relaunch step that
  needs the persistent store, the live Wikimedia API touched by hand: seven
  searches and five image downloads, the second and last time the network is
  touched in this spec. A temporary file probe inside
  `WikimediaPhotoService.searchPhotos` recorded every firing; it was removed
  before the suites ran and the working tree is clean of it. What was seen, in
  order:

  - **The action and the notice** (wanted item *Nikon F3*,
    Photography/Cameras, $500, no photo). The detail showed **Find a photo…**
    over a NO PHOTOS box. Tapping it showed the notice once — "Finding a photo
    sends this item's name to Wikimedia Commons — nothing else about it. The
    photo you pick is stored on your device and syncs with your other devices,
    like a photo you take.", a **See the privacy policy** link, **Continue**
    and **Not now**. **Not now** closed it and searched nothing — the probe was
    empty before and after, and the probe is not merely silent: the very next
    action wrote to it. Tapping **Find a photo…** again showed the notice again
    (Not now does not acknowledge); **Continue** fired the search **once**
    (probe line 1) and opened the picker.
  - **The picker** (query "Nikon F3"). Six candidates, every one an actual
    product shot of the camera, each credited beneath: Photopath… · CC BY-SA
    2.0; Arne List · CC BY-SA 3.0; Arne List · CC BY-SA 3.0; Paolo.bec… ·
    Public domain; Roberta F. · CC BY-SA 3.0; Martintoy · CC BY 3.0. Only
    CC-BY, CC-BY-SA and public-domain files were offered. Scrolling the grid
    and re-rendering the sheet fired nothing further (probe still 1) — the
    `.task`-inside-sheet worry `002`'s sweep raised does not reproduce here.
  - **Picking** the first candidate stored it: the detail hero showed the photo
    with the **STOCK PHOTO** badge top-left and the credit beneath it, and the
    wishlist row showed the photo as its thumbnail with the small stock glyph
    in the corner. The credit's **Wikimedia Commons ↗** link opened
    *File:Nikon F3.jpg* on Commons in Safari; coming back left the photo intact
    and fired no search (probe still 1).
  - **A second item, same launch** (wanted item *Zxqv Blorpanite 9000*, a name
    nothing matches). **Find a photo…** showed **no notice** — already
    acknowledged this launch — and searched once (probe 2): "No usable photos
    found for that name." with **Search again**, and nothing stored. **Search
    again** fired exactly one more search (probe 3). **Cancel** dismissed the
    sheet and fired nothing (probe still 3).
  - **Fetching again replaces** (criterion 6). On *Nikon F3*, **Find a photo…**
    opened straight into the picker (no notice) and searched once (probe 4);
    picking the second candidate replaced the first — the edit form's PHOTOS
    count read **1**, and the credit became "Photo: Arne List · CC BY-SA 3.0 ·
    Wikimedia Commons ↗".
  - **Keep both / Replace** (criterion 5). Adding a photo from the library to
    that item prompted "This item has a stock photo. Keep it, or replace it
    with your photo?" with **Keep both**, **Replace**, **Cancel**; the prompt
    fired no search (probe still 4). **Keep both** gave PHOTOS **2** with the
    owned photo leading; on the detail the owned photo was page 1 of 2 with no
    badge and no credit, the stock photo page 2 with both, and **Find a
    photo…** was gone — the item now has a photo of the person's own
    (Decision 6). Removing the fetched photo from the edit strip worked like
    any photo (PHOTOS 1). After clearing both photos and fetching a fresh stock
    photo (probe 5), adding a library photo again and choosing **Replace** left
    PHOTOS **1**, the owned one — the fetched photo gone.
  - **An owned item borrows a stock photo** (Decision 3). New owned item *Leica
    M6*, Photography/Cameras, paid $2,200, no photo: **Find a photo…** showed,
    searched once (probe 6), and offered Leica M6 product shots; picking one
    stored it with badge, credit and list-row thumbnail.
  - **Export** (criterion 8). **Export as PDF…** produced
    `Trove-Items-2026-09-11.pdf`, 128 KB, two pages: the summary, then the
    Leica M6 row with the stock photo drawn in the photo box and its full
    credit beneath it, in the right order and correctly wrapped — "Photo: No
    machine-readable author provided. Elya assumed (based on copyright
    claims). · CC BY-SA 3.0 · Wikimedia Commons". **Export as CSV…** produced a
    244-byte file whose header is
    `Name,Category,Purchase Price,Currency,Purchase Date,Purchase Location,Current Value,Desire to Keep,Condition,Condition Notes,Serial Number,Notes,Reverb Product ID,Year`
    — no photo column, unchanged by this spec.
  - **Nothing fetches on its own** (criterion 10). Across three launches and
    every screen visited, the probe recorded exactly seven firings, one per
    deliberate action: Continue, the empty-state search, Search again, three
    re-fetches, and the dev-store search below. No launch, appear, tab switch,
    sheet dismissal, return-from-Safari or Keep/Replace prompt fired anything.
  - **The notice across a relaunch**, on the persistent dev store (the
    `-uiTesting` launch resets the flag by design, so this step had to run
    without it; it only reads and sets the notice flag, nothing destructive).
    Relaunched without the flag: **Find a photo…** on the dev store's
    *Hasselblad X2D 100C ii* showed **no notice** — the acknowledgement set in
    the person's earlier Phase 3 session has survived every relaunch since,
    including a fresh install of the binary. (The Continue that set it happened
    before this session, so what this step shows is persistence, not the
    Continue-then-relaunch sequence in one sitting.) That search also confirmed
    Decision 7's accepted consequence live: "Hasselblad X2D 100C ii" returns
    the empty state, because no product shot comes back to filter (probe 7).

  **Probe firings per action** — Not now: 0. Continue: 1. Picker scroll /
  sheet re-render: 0. Return from Safari: 0. Second item's first open: 1.
  Search again: 1. Cancel: 0. Re-fetch on an item that already has a stock
  photo: 1 per open (three opens, three firings). Keep/Replace prompt: 0.
  Launch / appear / tab switch: 0. Total 7, matching the 7 intended opens
  exactly.

  **Dual-licensed GFDL + CC-BY-SA file**: not encountered. Every candidate the
  three live searches returned carried a single licence code (CC BY-SA 2.0/3.0,
  CC BY 2.0/3.0, or public domain), so the plan §3/Q4 path was not exercised.

  **Findings and what became of them.** (1) The detail credit garbled
  whenever it wrapped — the link was a sibling view beside a wrapping `Text`
  → a top-tier decision review (plan §6 amended) → **T015b**, then its
  device check found the arrow glyph following Dynamic Type while the credit
  text did not → **T015c**. (2) Commons' placeholder author ("No
  machine-readable author provided. … assumed …") credited verbatim →
  **T015a**. Two `Text` `+` deprecation warnings: one cleared by T015b, the
  other is the plan-required glyph append (recorded for T016's as-built).

  **T015b/T015c device check** (2026-09-12, `-uiTesting`, one live "Leica
  M6" search): a wrapping credit reads "Photo: Wikimedia Commons · CC BY-SA
  3.0 ·" / "Wikimedia Commons ↗" — author whole, licence intact in mono, no
  orphan separator, the link and glyph together on line 2; unchanged at
  accessibility XXXL after T015c, the arrow inline at the credit's cap height
  in brass. Tapping the author or licence does nothing; tapping "Wikimedia
  Commons" foregrounds Safari on `commons.wikimedia.org` /
  *File:Leica M6 img 1834.jpg* (URL bar, not the credit's appearance).
  UI suite twice, 16 tests, green both times.

  **Offline** (criterion 7) — the person, by hand, 2026-09-12: Network Link
  Conditioner at 100 % Loss on the Mac (which also cuts the session off, so
  the step can't be driven by a tool), dev store, wanted item *Canon R5*:
  **Find a photo…** → the sheet with "Couldn't reach Wikimedia Commons. Try
  again in a while." and **Search again**; NO PHOTOS still on the item,
  nothing stored (screenshot kept with the pass's shots).

  **VoiceOver** (criterion 11) — the person, Xcode's Accessibility Inspector
  against the simulator, 2026-09-13, on a stock photo with the fallback
  author: the credit is **one element**; Label "Photo: Wikimedia Commons · CC
  BY-SA 3.0 · Wikimedia Commons" (no arrow spoken); Traits **Button, Link**;
  Hint "Opens Wikimedia Commons in your browser"; **Activate** opened the
  Commons file page. The `accessibilityRepresentation` route works; plan §6's
  recorded fallback was not needed.

  **Not covered**: sync of a fetched photo to a second device (criterion 4)
  — no second device; an honest partial, resting on the CloudKit schema test
  and on `002`'s owned-photo sync path that the fetched photo shares.

- [x] **T015a — Commons' placeholder author falls back to "Wikimedia Commons".** Device-pass finding 2: Commons emits "No machine-readable author provided. {user} assumed (based on copyright claims)." in `Artist` for files with no structured author, and the fallback only fired on an absent or empty field. Now the leading phrase (case-insensitive) counts as no author; the file is still offered. Hand-built fixture `search-placeholder-author.json` + 2 tests; mutation verified. Recorded: no recorded fixture had the placeholder, so the live data has shapes the sample lacks.

- [x] **T015b — The `.full` credit as one wrapping paragraph.** Device-pass finding 1, decided at a top-tier decision review (plan §6, "The stock badge and credit", as amended): the credit becomes one `Text` over an `AttributedString` from a pure `StockPhotoCredit.attributedCredit(_:theme:)`, the source run a `.link`, an `accessibilityRepresentation` `Link` carrying the hint and the `stockphoto.credit.link` identifier, no `lineLimit`; the two `Text` `+` deprecation warnings go with it. Tests restated per plan §6 (the value test with its three mutations; the adjusted source scans). **Verify:** `scripts/verify.sh` green; three mutations recorded. The device check (wrap at AX5, sighted tap, VoiceOver focus/double-tap, the recorded fallback if it fails) runs with the pending offline step, below.

- [x] **T015c — The credit's arrow glyph at accessibility text sizes.**
  T015b device check: the credit's text is the theme's fixed size, but the
  appended `Text(Image(systemName: "arrow.up.right"))` follows Dynamic Type —
  at accessibility XXXL it grows to ~5× the cap height, wraps onto its own
  line, and draws primary instead of brass (a separate run the link tint
  doesn't reach). Fix inside the credit: the glyph takes the credit's own font
  and the brass tint; the `.full` credit stays one paragraph, the value test
  and scans hold. Test: a guard that can go red. **Verify:**
  `scripts/verify.sh` green; mutation recorded; a screenshot at accessibility
  XXXL, content size restored to medium.

- [ ] **T016 — Close-out.**
  Criteria 1–11 ticked in `spec.md` with citations, honest partials named (the
  second-device sync check; anything not exercised on the device);
  `plan.md` gains "As built" (deviations, the licence set as shipped, and a
  pointer to the already-settled OQ1 — confirmed at sign-off, CC-BY-SA image in
  a PDF is a collection not an adaptation — and OQ2 — spec Decision 6, gate on
  an owned photo; **neither is an open question to re-decide**); this file's
  status flipped; the pre-merge
  `skeptical-reviewer` sweep over `git diff main...HEAD` (bundle cut after `git
  add -A`); the post-merge list (`fix/docs-005-shipped`: `ROADMAP.md`'s 005
  entry + status row + the Reverb-catalog-image later enhancement note; **and,
  from the person's Phase 3 device testing (2026-09-10), a roadmap note that
  Wikimedia's coverage gap for brand-new premium gear (e.g. no standard
  Hasselblad X2D 100C body — only a CC0 "Earth Explorer" limited edition) is what
  the deferred eBay source would close: eBay carries current-market gear photos
  but needs the server proxy 002 Decision 19 flagged, so it stays a follow-up
  spec**; README
  Status/tree/specs listing; `DECISIONS.md` — the second network dependency,
  Wikimedia over the storing-forbidden sources, a fetched photo syncs while
  `002`'s figures don't, the notice flag in `UserDefaults`; **the generalization
  from the Phase 3 review — a controlled UI-test starting state must be
  structural for every persisted flag, not only the SwiftData store (the
  `UserDefaults` notice flag needed its own `-uiTesting` reset, gated on the
  built `.ephemeral` store)**; the `AppContact` unification candidate from Q6);
  PR marked ready for review.
  **Verify:** everything above committed and pushed; `scripts/verify.sh all`
  green with the final counts recorded here.

## Tier log

Every invocation this spec runs at **`opus`** — the `sdd-planner`, the
`skeptical-reviewer` on sign-off and each phase/marked-task review, and the
`sdd-implementer` — under `CLAUDE.md`'s model-policy **Fallback** clause, with
Fable's budget spent (as `004-themes` recorded for its whole run). Every Tier
entry below is the resolved name `opus`, never "default." Token usage from each
subagent return is filled in as the spec runs; escape-hatch misses (a task the
orchestrator had to redo, and why) are recorded here too. This spec's total is
compared against `002` and `003` before the amended policy is treated as
settled.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| Plan + tasks draft | opus (`sdd-planner`) | ~200k | this document; Fallback clause; surfaced OQ2 → person (Decision 6) |
| Plan sign-off | opus (`skeptical-reviewer`) | ~71k (55k in / 4k out) | **signed off, nothing blocking**; OQ1 confirmed against CC-BY-SA 4.0 text; 4 second-look notes (3 folded into plan/tasks now, note 4 optional below) |
| T001 implement | opus (`sdd-implementer`) | ~39k | `Photo` schema fields + accessor/builder + tests; red run recorded; no `.pbxproj` edit |
| T001 review (per-task) | opus (`skeptical-reviewer`) | ~30k | signed off, nothing blocking; 2 non-blocking notes (fallback-branch tests carried to T007/T009) |
| T002 implement (prep half) | opus (`sdd-implementer`) | ~46k | script + hand-built fixtures; **stopped** on README bundle collision (well-specified fork) → orchestrator resolved via unique basename (escape hatch) |
| T002 live recording | — (person) | — | `search-camera.json`, 20 reusable pages; surfaced host-allowlist correction → plan §2/Q1 + T003 |
| T003 implement | opus (`sdd-implementer`) | ~100k | service + decoding + licence filter + attribution + tests; 7 guards mutation-verified; `StockPhotoAttribution` made `nonisolated` (required) |
| T003 review (per-task) | opus (`skeptical-reviewer`) | ~57k | **1 blocking**: ported-licence acceptance unguarded (false-coverage) |
| T003 fix (ported test) | opus (`sdd-implementer`) | ~27k | added falsifiable classifier-table assertion, mutation-verified; classify unchanged |
| T003 re-review | opus (`skeptical-reviewer`) | ~25k | **resolved**; nothing open |
| T004 implement | opus (`sdd-implementer`) | ~58k | full copy + notice store; acknowledge() mutation verified; 1182 tests (phase review covers) |
| T005 implement | opus (`sdd-implementer`) | ~53k | PhotoSelection fetch/store rules + StockPhotoServiceSpy; both mutations verified; 1190 tests |
| Phase 1 review | opus (`skeptical-reviewer`) | ~86k | **signed off, nothing blocking**; foundation composes; 4 non-blocking notes (below) |

**Phase 1 review notes (non-blocking, carried forward):**
1. `maxImageBytes` (~8 MB) is a bare literal in `WikimediaPhotoService.init`'s
   default and again in the test helper's default, rather than a `WikimediaAPI`
   constant like the other caps → small "one home" cleanup, left for the
   pre-merge sweep (T016).
2. Plan §3/Q4's dual-licence claim (a file licensed GFDL **and** CC-BY-SA is
   offered, credited by CC-BY-SA) has no fixture and can't be settled by the
   unit suite — it depends on which `License` code the live API returns. **→
   added as a T015 device-pass check** (below); recorded against plan §3 as an
   untested claim until then.
3. `PhotoNoticeStore`'s "a read that fails reads as not acknowledged"
   doc-comment implies an error branch `UserDefaults.bool` can't take; the
   fail-safe direction is right by construction — doc-comment nit for the sweep.
4. `StockPhotoServiceSpy` has only its exhaustion path tested this phase (by
   design; the VM tests in T009/T010 exercise the rest).

| T006 design pass | — (person + `/design`) | — | brief written (Claude Code); 11 artboards approved + saved; tokens section written; no new copy escalated |
| T007 implement | opus (`sdd-implementer`) | ~49k | shared `StockPhotoBadge` + `StockPhotoCredit`; 5 guards, 2 mutations verified + 1 caught in dev; T001 no-author fallback covered; 1196 tests |
| T008 implement | opus (`sdd-implementer`) | ~107k | `PhotoFetchViewModel` + notice/picker sheet views; `StockPhotoCredit` `.compact`; `StockPhotoDownload`; 3 copy strings; 3 mutations verified; broadened (not weakened) the 002 AsyncImage guard for the second sanctioned picker; 1211 tests |
| T009 implement | opus (`sdd-implementer`) | ~198k | both detail VMs + views photo plumbing; `store(_:)` (owned-only `updatedAt`); `PhotoPickerSheetView` `store`-closure refinement; `PhotoCarousel` badge/credit/a11y; 4 mutations verified; carousel badge test keys off label pixels (ImageRenderer won't render the paging hero); 1227 tests |
| T010 implement | opus (`sdd-implementer`) | ~138k | both form VMs photo plumbing + in-memory `store`; 3 pure `PhotoSelection` helpers (replace/keep); `PhotoPickerField` replace/keep alert; both form views' action; 3 mutations verified; no deviations; 1246 tests |
| T011 implement | opus (`sdd-implementer`) | ~69k | `StockPhotoBadge` `.mark` style; `PhotoSelection.leadsWithStock`; `RowThumbnail` corner-mark overlay; both rows' a11y value; 3 mutations verified; row size tests intact; 1252 tests |
| T012 implement | opus (`sdd-implementer`) | ~62k | 2 feasible UI tests (002 "offline states only" mirror; 2 infeasible ones → unit suites + T015, no seed/stub); UI suite green twice (16 tests); 2 mutations verified; surfaced the UserDefaults.standard notice-flag persistence finding for T015 |
| Phase 3 review | opus (`skeptical-reviewer`) | ~124k | **1 blocking** — the `UserDefaults.standard` notice flag breaks `-uiTesting`'s controlled-start contract (CLAUDE.md / 003 amendment); 6 non-blocking notes (recorded in plan §6, carried to T015 + the sweep) |
| Phase 3 fix | opus (`sdd-implementer`) | ~41k | `resetForUITesting(mode:)` in `TroveApp.init`, structurally gated on the built `.ephemeral` store; 3 tests + mutation verified; `if case` idiom for nonisolated `StorageMode`; 1255 tests |
| Phase 3 re-review | opus (`skeptical-reviewer`) | ~23k | **resolved, nothing open**; DECISIONS generalization deferred to T016 |
| T012a implement | opus (`sdd-implementer`) | ~64k | taken-with relevance filter (categories request + digit-token match); 1260 tests; anchors verified |
| T012a review (per-task) | opus (`skeptical-reviewer`) | ~44k | **1 blocking**: bare-number false drop (lens aperture/focal collides with capture-camera model number); + flagged the orchestrator's untracked-test-file diff omission |
| T012a fix | opus (`sdd-implementer`) | ~34k | alphanumeric-fused-token rule (letter AND digit) + regression fixture/test; mutation-verified; R5-keep held; 1261 tests |
| T012a re-review | opus (`skeptical-reviewer`) | ~39k | **resolved, nothing open**; all relevance tests confirmed falsifiable; 2 non-blocking notes |
| **◆ Experiment 1 — 2026-09-11** | session `claude-fable-5-1` @ medium | Fable allowance 92% | The orchestrating session's seat moves to Fable from Phase 4 on, per the amended model policy (skill's experiment-1 branch). Rows above ran the session on `opus` under the prior policy's Fallback clause (Phases 1–3b), which the intro paragraph describes; that framing is superseded from here. Subagent/review rows below stay `opus` (implementation tier). The 92% reading is experiment 1's baseline allowance draw, to be compared against a later reading. |
| T013 implement | opus (`sdd-implementer`) | ~104k | `PDFEntry.photoCredit`; records snapshot `firstPhotoAttribution`; composer draws the credit under the photo box only when the image resolved; 4 tests, 2 mutations verified; 20 mechanical record-construction sites; 1265 tests |
| T014 implement | opus (`sdd-implementer`) | ~62k | `PRIVACY.md` (second service, photo notice quoted verbatim, two new table rows, one-direction images wording, sync statement), README feature bullet, 4 privacy tests; 3 mutations verified; 1269 tests |
| Phase 4 review | opus (`skeptical-reviewer`) | ~68k | **signed off, nothing blocking**; 5 non-blocking notes (below); orchestrator re-ran `scripts/verify.sh` at the reviewer's ask (1269 tests green) |
| T015 device pass | opus (general-purpose w/ simulator tools; `sdd-implementer` has none) | ~259k | live pass on the simulator, in-memory store; probe: 7 firings = 7 intended opens, 0 on Not now/prompt/re-render; 2 findings (credit wraps garbled; placeholder author); offline + VoiceOver + sync pending; both suites green twice (16 UI / 1269 unit) |
| T015 diagnosis | opus (`sdd-implementer`) | ~72k | finding 2 fixed (T015a, mutation verified, 1271 tests); finding 1 diagnosed as a view-vs-inline-run fork → decision review |
| Finding 1 decision review | fable (`skeptical-reviewer`, top tier) | ~45k | option 1 (one `Text(AttributedString)`, `.link` run) with an `accessibilityRepresentation` Link instead of the session's label/hint lean (a label strips the Links rotor on iOS 17+); plan §6 amended; fallback recorded; → T015b |
| T015b implement | opus (`sdd-implementer`) | ~63k | `.full` credit = one `Text(AttributedString)` via pure `attributedCredit(_:theme:)`, `.link` source run, `accessibilityRepresentation` Link; value test + adjusted scans; 4 mutations verified; 1 `Text +` warning remains (the plan-required glyph append) → T016 as-built; 1272 tests |
| T015b device check | opus (general-purpose w/ simulator tools) | ~144k | wrap at default + AX5 confirmed; sighted tap opens the Commons file page (URL bar); VoiceOver NOT verifiable on the simulator (`inspect` unavailable, no VO) → person; found the Dynamic-Type arrow glyph defect → T015c; UI suite green twice (16) |
| T015c implement | opus (general-purpose w/ simulator tools) | ~148k | glyph takes the credit's fixed font + brass; 3 scoped scan guards (a render test was built, probed, found false-passing — ImageRenderer draws an SF Symbol in a Text as a constant placeholder — and deleted); 3 mutations verified; AX5 screenshot confirms; 1275 tests |
| T015 offline + VoiceOver | — (person, by hand: Link Conditioner; Accessibility Inspector) | — | offline failure copy seen, nothing stored; credit one element, Button+Link, hint, Activate opens Commons — fallback not needed; T015 closed |
| _rows added per dispatch as the spec runs_ | opus (subagents) | | |

**Phase 4 review notes (non-blocking, carried to T016 / the sweep):**
1. Plan §7's new "photo deleted mid-export → no photo, no credit" sentence has
   no test (every `PDFComposerStockTests` entry has a resolvable photo). One
   construction closes it: a `PDFEntry` with `photoCredit` set and an
   unresolvable `photoID`, asserting neither "Photo:" nor the author renders.
   **→ T016 picks this up** (sub-lettered under T013 if it needs its own commit).
2. `theStockPhotoLinkPointsAtTheSameExistingFile` is half falsifiable: renaming
   `PRIVACY.md` goes red, but repointing both constants at `README.md` stays
   green. Same shape as 002's `theLinkedURLEndsInTheFilename` — audit the shape
   at the sweep (a containment check on the policy's title line closes both).
3. The reworded "Images travel in one direction only" sentence has no guard;
   reverting it to the old wording keeps every test green. Plan §8 asked for none.
4. "Two things ever leave" front-loads loosely (candidate images are fetched,
   the market refresh sends a product ID); the detail bullets are accurate.
5. Bundle hygiene: the review bundle's spec sections came out empty (the
   orchestrator's awk anchors missed the headings) and carried no verbatim
   verify output; the reviewer checked plan/tasks instead and asked for the
   re-run, which the row above records.

**Sign-off second-look note 4 (optional, non-blocking).** The credit links the
"Wikimedia Commons" segment to the file page (`descriptionurl`) — standard TASL
attribution, sound as-is. Optionally the licence short-name could also link to
`LicenseUrl` (already fetched, Q1). Left to the implementer's discretion at the
badge/credit task; not required.

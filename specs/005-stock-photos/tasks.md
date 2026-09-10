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

- [ ] **T008 — The notice + candidate-picker sheet, and the picker view model.**
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

- [ ] **T009 — Detail screens: Find a photo…, storing the pick, badge + credit.**
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

- [ ] **T010 — Forms: Find a photo…, the in-memory append, the replace/keep prompt.**
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

- [ ] **T011 — List rows: the leading rule and the stock badge.**
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

- [ ] **T012 — UI tests, offline, run twice.**
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

## Phase 4 — Export and policy

- [ ] **T013 — PDF export: the fetched photo with its credit (subject to OQ1).**
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

- [ ] **T014 — `PRIVACY.md`, its guard, and the README sentence.**
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

- [ ] **T015 — Device pass with the live API. [person: watches the live half]**
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
  entry + status row + the Reverb-catalog-image later enhancement note; README
  Status/tree/specs listing; `DECISIONS.md` — the second network dependency,
  Wikimedia over the storing-forbidden sources, a fetched photo syncs while
  `002`'s figures don't, the notice flag in `UserDefaults`; the `AppContact`
  unification candidate from Q6); PR marked ready for review.
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
| _rows added per dispatch as the spec runs_ | opus | | |

**Sign-off second-look note 4 (optional, non-blocking).** The credit links the
"Wikimedia Commons" segment to the file page (`descriptionurl`) — standard TASL
attribution, sound as-is. Optionally the licence short-name could also link to
`LicenseUrl` (already fetched, Q1). Left to the implementer's discretion at the
badge/credit task; not required.

# 002 — Market Values: Tasks

Status: **In progress** (approved 2026-09-03, same day as drafting; **Amendment A — year narrowing** folded in after T002 per spec Decision 29 and plan Amendment A — the tasks it touches say so)

Drafted against the approved `plan.md` (approved 2026-09-03; drafted
at `64d505b`) on branch `002-live-market-value`, based on `main` at
`2f32ed6` (013 merged). No new technical decisions are made here —
every call below traces to a plan section; where a task says "per
plan," that section is the authority. The skeptical-reviewer ran twice
on the plan's design and once on this decomposition; the decomposition
review's findings were folded in before this draft was committed, and
one of them corrected the plan (Q21 — a corrupt local store no longer
ends in `fatalError`). Record at the end.

Ordering note, recorded up front: the two-store container is the one
risk in this spec whose failure reshapes the architecture (plan §1,
risk R1 — the fallback puts a second context into five view models),
so **T001 builds it and proves it before anything else exists**, and
answers the `.automatic` question in the same file. Then the network
layer and the pure pieces bottom-up (client → computation → store and
refresher → copy), with nothing user-visible until the Design pass
(T008) has approved visuals for the three new surfaces. Screens follow
the pass, with the notice and the picker in one task so no commit
leaves Continue opening an empty sheet; the CSV contract (T016a) comes
after the screens because one large contract commit is easiest to
review alone; the policy (T017) waits for the copy it quotes. The live
network is touched by a person twice, and only twice: the fixture
script (T002) and the device pass (T018) — a task whose screen can only
be exercised against Reverb records that in its Done note and defers
the live check to T018. The contact address (Decision 25) is needed by
the client's user agent, so it lands with the client (T004), before the
rest of the copy.

House rules carried over: one commit per completed task, referencing
the task ID; every guard test is **mutation-verified** (break the rule
deliberately, confirm red) before it lands, and the task's Done note
records what was broken and what went red; a task is not done until
`xcodebuild build` and `xcodebuild test` pass and the actual output is
reported (suite-level `-only-testing` selectors, test count checked —
per-function selectors run zero tests and report success). Every new
file lands through the synchronized root groups — no `.pbxproj` edit
anywhere in this spec. **No test opens a network connection**, ever
(CLAUDE.md's Networking rule, T000). Tasks marked **[person]** block
on something only the person has.

## Phase 0 — The constitution

- [x] **T000 — `CLAUDE.md` amended, own commit (spec Decision 19).**
  *Done (2026-09-03, `2b338b1`)*: the "not in scope for v1" sentence
  replaced; the Networking architecture bullet added. Committed alone,
  before this document, per the constitution's amend-first rule — an
  authorized pre-tasks commit, not implementation.

## Phase 1 — Foundations, no UI

- [x] **T001a — The two-store pair, and the spike that proves it.**
  *Done (2026-09-03)*: `TroveSchema` (now `nonisolated`, so the
  nonisolated builder can read it) carries `models`, `localModels`,
  `schema`, `localSchema`, `combinedSchema`; `MarketLocalModels.swift`
  holds the four models as plan §1 declares them; `TroveStore` gained
  `localStoreName`, `configurations(for:directory:)` (the pair for the
  disk modes; `.ephemeral` already one in-memory configuration over the
  union — T001b keeps its guards), `localConfiguration(directory:)`,
  the `[ModelConfiguration]` build seam with `buildContainer` as its
  default, and Q21's `recreateLocalStore` third attempt with
  `removeLocalStoreFiles` (the two defaults `nonisolated`, since a
  MainActor static can't stand in for a plain closure). **The spike is
  green**: `TwoStoreContainerTests` builds the real pairing through the
  real builder into a scratch directory, saves an `Item` and a
  `MarketFigureRecord`, and finds the record in `MarketLocal.store`
  alone and the item — and no record — in `default.store` opened under
  the union schema. `MarketLocalSchemaTests` G1–G4 and G2b; three Q21
  tests in `TroveStoreTests`, the existing ones moved to
  `configurations(for:)[0]`, the two `== nil` tests' doc comments now
  saying what they can't see. Targeted run: **21 tests in 4 suites**
  green. Full unit suite: **799 tests in 118 suites passed** (790/116
  at 013's close, +9/+2). Dev-store launch on the simulator: both
  `default.store` (434 KB) and `MarketLocal.store` (139 KB) present in
  the app container. Mutations, each reverted: **M1** `MarketHistoryPoint`
  in the synced list → G1 red and *only* G1 — `CloudKitSchemaTests`
  green, as predicted; **M1b** `MarketFigureRecord` (unique-keyed) in
  the synced list → G1, `CloudKitSchemaTests` and G7 all red with
  "CloudKit integration does not support unique constraints" — the
  contrast that says why G1 is needed for the plain model; **M2**
  `cloudKitDatabase:` dropped from the app's local configuration → the
  test host itself died at launch in `TroveApp`'s `fatalError` (the
  store under `.automatic` refused the unique constraints through all
  three attempts), so no test ran — red by crash; **M2′** the same drop
  on the directory branch, leaving the host alone → G2b red *and* G7
  red, the scan seeing what the identifier can't; **M3** the name
  dropped → G3 red, and the Q21 test red too: with both configurations
  on `default.store` the recreate hook was handed the collection's URL
  — the second net the "never the collection" assertion was written for
  (it deleted the *test host's* `default.store`, nothing of the
  person's); **M4** `var listingTitle: String?` → G4 red; **M5** one
  configuration over the union → under `.private` the host crashed
  (unique constraints, then an index-out-of-range inside SwiftData's
  CloudKit recovery); scoped to the directory branch with sync off, G7
  died on an uncaught Core Data `NSInvalidArgumentException` ("Can't
  assign an object to a store that does not contain the object's
  entity") and xcodebuild reported **TEST FAILED** with the remaining
  tests unrun — red by crash, the split assertion itself never reached,
  recorded as such; **M6** recreate before the fallback pair → three
  tests red (`aCloudKitFailureLeavesAWorkingLocalStore`,
  `aBrokenLocalStore…`, `aLaunchThatFailsAllThreeTimes…`); **M7** the
  third attempt skipped → `aBrokenLocalStore…` red (the corrupt-file
  error reaches the test). One lesson for the record: Swift Testing
  prefixes some console lines with a zero-width space, so a `^✘` filter
  drops them — the first read of M2′ and M6 under-reported for that
  reason and both were re-run with a plain `✘` grep.
  Per plan §1, §9 (G1–G4, G7) and Q21. `TroveSchema` gains
  `localModels`, `localSchema`, `combinedSchema`; new
  `Trove/Market/MarketLocalModels.swift` with the four `@Model`s exactly
  as plan §1 declares them (`@Attribute(.unique)` on `subjectID`/`key`;
  defaults everywhere; **no relationships**).
  `TroveStore.configurations(for:directory:)` returns the pair for the
  two disk modes (synced **unnamed**, local `"MarketLocal"`,
  `cloudKitDatabase:` spelled out on every one) and, for now, the
  existing single configuration for `.ephemeral` (T001b widens it);
  `make(isUITesting:build:recreateLocalStore:)`'s seam becomes
  `([ModelConfiguration]) throws -> ModelContainer` over
  `combinedSchema`, with Q21's third attempt; the existing
  `TroveStoreTests` (`:87`, `:111–117`) move to `configurations(for:)[0]`.
  New `TroveTests/TwoStoreContainerTests.swift` (**G7**, disk I/O — the
  `CloudKitSchemaTests` exception, stated in its doc): build
  `configurations(for: .cloudKit, directory: tmp)` through the real
  `build`, save an `Item` and a `MarketFigureRecord`, reopen
  `MarketLocal.store` alone → the record; reopen `default.store` alone →
  the item and no record. New `MarketLocalSchemaTests`: G1 (disjoint),
  G2 (two configurations, entity names, the private id on `[0]`, nil on
  `[1]`), **G2b** (source scan: every `ModelConfiguration(` in
  `TroveStore.swift` carries `cloudKitDatabase:`), G3 (`default.store` /
  `MarketLocal.store`), G4 (per-entity property-name sets equal their
  allowlists). **Q21's test**: through the seam, two throwing builds
  then a success → `recreateLocalStore` called once with the local
  URL, mode `.localOnly`, `cloudKitFailure` set; a success on the first
  try → never called. **The audit** (plan's corrected fact):
  `uiTestsNeverReachICloud` and `theFallbackDoesNotAskForCloudKitAgain`
  keep their assertions; their doc comments now say the `== nil` half
  cannot see an inherited `.automatic` — G2b is the guard that can.
  Mutations: **`MarketHistoryPoint`** added to `models` → G1 red while
  `CloudKitSchemaTests` stays green (record it — and record that adding
  a unique-keyed model instead turns *both* red, which is why G1 is
  needed for the plain one); `cloudKitDatabase:` deleted from
  `localConfiguration` → G2b red; the name dropped → G3 red; `var
  listingTitle: String?` on the figure record → G4 red; one
  configuration over the union → G7 red; recreate before the fallback
  pair → Q21's test red; the third attempt skipped → the throw reaches
  the test.
  *Done when*: all green and mutation-red; full unit suite green with
  the count; the app launches on the dev store with both files present
  in the app container. **If G7 cannot be made green, stop and report —
  the plan's fallback (b) is a plan change, not a task.**

- [x] **T001b — The union everywhere.**
  *Done (2026-09-03)*: `makeInMemoryContainer()` on `combinedSchema`
  with `cloudKitDatabase: .none`; the eight preview files' sixteen
  `TroveSchema.schema` sites and `ContentView`'s `.modelContainer(for:
  inMemory:)` moved to the union — the latter through a new
  `TroveSchema.allModels`, since that modifier takes types, not a
  schema; G6 (`uiTestsKeepEveryModelInMemory`), G8
  (`theCombinedSchemaIsTheUnion`, both the schema and `allModels`) and
  G9 (`previewsAndContentViewUseTheCombinedSchema`) appended to
  `MarketLocalSchemaTests` — G9 reads the files raw, because
  `SourceScan.production` strips from the first `#Preview`, which is
  exactly where every construction site lives; it also requires at
  least eight files to build a container, so a moved preview can't
  make it pass over nothing. Targeted run: 24 tests in 4 suites green.
  Full unit suite: **802 tests in 118 suites passed** (+3). Under
  `-uiTesting` the app launched on the simulator and was still running
  five seconds later, no fatal line in its log. Every preview compiles;
  the canvas itself was not exercised. Mutations, each reverted: **M8**
  the ephemeral configuration over the synced schema → G6 red ("covered
  → [WishlistItem, Photo, Item]"); **M9** a local model dropped from
  `combinedSchema` → the test host died at launch with
  `configurationSchemaNotFoundInContainerSchema` (the local
  configuration names an entity the container doesn't have) — red by
  crash, and the runtime failure G8 exists to pre-empt, so **M9′** the
  same drop on `allModels` alone → G8 red by its assertion; **M10**
  one preview left on `TroveSchema.schema` → G9 red naming
  `SettingsView.swift`.
  Per plan §1 and §9 (G6, G8, G9). `.ephemeral` becomes one in-memory
  configuration over `combinedSchema`; `makeInMemoryContainer()` in
  `TestSupport` builds the union with `cloudKitDatabase: .none`; every
  `TroveSchema.schema`/`.models` construction site outside
  `TroveSchema`, `TroveStore` and the tests (the previews, incl.
  `SettingsView`'s shared `previewContainer`, and `ContentView.swift:51`)
  moves to `combinedSchema` — G9 is the count, not this sentence. G6
  (ephemeral covers everything in memory, no id), G8 (`combinedSchema`
  is the union), G9 (the scan). Mutations: a local model dropped from
  the ephemeral schema → G6 red; one missing from `combinedSchema` → G8
  red; one preview left on `.schema` → G9 red.
  *Done when*: green and mutation-red; full suite green with count; the
  app launches under `-uiTesting` and every preview renders.

- [x] **T002 — The fixture script and the recorded fixtures. [person: runs it]**
  *Done (2026-09-03, two commits)*: `scripts/record-reverb-fixtures.sh`
  (python's `urllib` under a bash shim, no third-party anything) and
  the three hand-built fixtures first (`73320dd`), so the person could
  pull it; then the recording, run on the Mac at the person's word
  while they followed remotely — their own connection wouldn't run it.
  Twelve files: the search (three candidates, 126161 first), the
  product (`used_total` 109, the fourteen-`cp_ids` listings link, the
  slug-based web link), the 404 body, and seven listing pages (50 × 6
  + 38 = 338; `next` present on p1–p6, absent on p7; every listing
  trimmed to `id`, `title`, `price`, `listing_currency`, `condition`,
  `state`). 168 KB. The README's oracle block, USD by both fields:
  excellent n=35 median 139999 low 115200 high 325000; very-good 14;
  mint-inventory 14; mint 7; b-stock 5; good 3; brand-new 182; owned
  buckets new 208 / excellent 35 / good 17 / fair 0 / broken 0; wanted
  **73** (median 149999) — the plan's 151 had ignored the currency
  filter and is corrected there with the date; no slug outside the
  known set. The four sample-row ids chosen and recorded (the Strat's
  abbreviated CSV name found nothing; the spelled-out name did — a
  note for the picker's empty-state copy). Nothing under `Trove/`
  changed; every file parses. **Amendment A**: re-recorded minutes
  later with `year` kept (the first trim had dropped it) — one
  excellent listing had sold in between (34, not 35; wanted 72;
  `used_total` 108); the README records both runs and the `year`
  values seen, three of them unreadable on purpose.
  Per plan §3 (Fixtures). New `scripts/record-reverb-fixtures.sh`
  (curl + a python trim; the three headers; `sleep` between calls):
  writes `TroveTests/Fixtures/Reverb/csps-search-telecaster.json`
  (three candidates, photos cut to `small_crop`), `csp-126161.json`,
  `csp-404.json`, `listings-126161-p1.json` … `p7.json` (every listing
  trimmed to `id`, `title`, `price`, `listing_currency`, `condition`;
  shop and seller fields removed — titles kept as the byte-scan
  tripwire), and prints the per-condition USD counts, medians, lows
  and highs in **exactly the form T005 pins** (`excellent n=35 median
  140000 low 115200 high 325000`, and the `.wanted` count under Q1's
  newStock set beside the product's `used_total`). Hand-built
  alongside: `rate-limited-429.json`, `listings-mixed.json` (a EUR
  listing, a listing whose `price.currency` disagrees with
  `listing_currency`, an unknown slug, a missing price, a missing
  condition), `listings-next-elsewhere.json` (a `_links.next` on another
  host). `TroveTests/Fixtures/Reverb/README.md` records the date, the
  printed oracle block verbatim, the Reverb ids of the four music rows
  in `docs/samples/items-full.csv` (for T016a), and that titles are
  Reverb content kept only in the test target. The files join the test
  bundle as resources through the synchronized group — if that ever
  needs excluding, that is a `.pbxproj` edit: stop and flag. The script
  is run by hand, once, by the person or with them watching; its output
  is committed and reviewed as a diff.
  *Done when*: the files exist and parse (`python3 -m json.tool`);
  the README's oracle block is written; nothing in `Trove/` changed;
  full suite count unchanged.

- [x] **T003 — The synced match field, and the records that mirror it.**
  *Done (2026-09-03)*: `reverbProductID: Int?` and `year: Int?` on
  `Item` and `WishlistItem` after `sortOrder`, each with its doc comment
  and a trailing defaulted init parameter; `ItemExportRecord` and
  `WishlistExportRecord` gained both as `let`s with their snapshots
  copying them; `ImportSchema`'s two production construction sites pass
  `nil` with a comment saying T016a replaces it; seventeen memberwise
  sites across six test files gained the two arguments (nine multi-line
  by a line insertion, eight inline by a second pass — the first regex
  missed the inline ones, and the build said so). New
  `MarketFieldsTests` (four tests: defaults nil on both kinds; the init
  parameters set both; a save-and-refetch on a second context; the
  records snapshot both). Targeted run: 81 tests in 6 suites green. Full
  unit suite: **806 tests in 119 suites passed** (+4, +1). **The
  CloudKit red run**: `reverbProductID` declared `Int` with no default →
  `CloudKitSchemaTests` red, the validator naming it — "CloudKit
  integration requires that all attributes be optional, or have a
  default value set … Item: reverbProductID" — reverted. Between here
  and T016a `aTroveExportRoundTripsLosslessly` keeps its name while the
  CSV drops both fields, as the task said it would.
  Per plan §2 and Amendment A. `var reverbProductID: Int?` **and `var
  year: Int?`** on `Item` and `WishlistItem` after `sortOrder`, doc
  comments per plan, trailing defaulted init parameters for both;
  `ItemExportRecord`/`WishlistExportRecord` gain `let reverbProductID:
  Int?` and `let year: Int?` (memberwise — no default, or `init(item:)`
  couldn't set them) and their `init(item:)` snapshots copy them — **not** the headers, `row(from:)` or the parser's reading of it
  (T016a, together or not at all). Two **production** construction
  sites must compile: `ImportSchema.itemsPreview` (`:326–340`) and
  `wishlistPreview` (`:434–443`) pass `reverbProductID: nil` — a
  hard-coded nil carries no CSV meaning, and T016a replaces it. The six
  test files that construct records gain the argument (compile-error
  sweep). Between here and T016a `aTroveExportRoundTripsLosslessly`
  keeps its name while the CSV drops the field — expected, noted.
  `ModelTests`: defaults nil on both; round-trips through a second
  context; the init parameter sets it. `CloudKitSchemaTests` red run:
  declare it `Int` with no default → the validator throws; revert.
  *Done when*: green, red run recorded, full suite count +3 or so.

- [ ] **T004 — `MarketService`, `ReverbMarketService`, decoding. [person: the contact address]**
  *Done except the address (2026-09-03, `partial`)*: `MarketService`
  (three `@concurrent` requirements), `MarketCandidate`, `MarketProduct`,
  `MarketListing` (four members: `priceCents`, `currency`,
  `conditionSlug`, `year` — `currency` becomes a two-currency marker like
  `GBP≠USD` when Reverb's display conversion makes `listing_currency`
  and `price.currency` disagree, so such a listing counts for no
  currency), `MarketListings`, `MarketError`; `ReverbAPI` (host, base
  URL, headers, `perPage` 50, `pageCap` 10, `searchCount` 15 per P22,
  timeouts, `userAgent(version:)` reading `MarketCopy.contactAddress`,
  `productURL(slug:)`, the one `request(for:)`); `ReverbMarketService`
  (`sharedSession` ephemeral with `waitsForConnectivity` off;
  `makeSession(protocolClasses:)` for the stub; `URLComponents` for every
  URL; `withPerPage`; the walk stopping at the cap or at a `next` off
  Reverb's host — both marked truncated; `fetch` mapping `URLError` →
  `.unreachable`, 429 → `.rateLimited`, 404 → the caller's meaning, else
  `.serverError`); `ReverbDecoding` (explicit keys, a `Lossy` wrapper
  per listing, a listing without a price or a slug dropped, the year
  trimmed with blank → nil). `AppVersion` became `nonisolated` — the
  user agent's default reads it from a nonisolated context — with its
  tests unchanged. Tests: `ReverbDecodingTests` (7: the search's three
  candidates with the Telecaster first and an image on `rvb-img`; the
  product's listings link on Reverb's host, `used_total` 108,
  `used_low_price` 100000; a product without a listings link is
  malformed; the seven pages link forward until the last, 50 × 6 + 37;
  the mixed page keeps four and marks `GBP≠USD`; a year trims; **G10**
  — four members by `Mirror`, and no string member but a currency, a
  slug or a year on a title-bearing page), `ReverbMarketServiceTests`
  (11, `.serialized`, `StubURLProtocol` keyed by host + path + sorted
  query with a `Mutex`-held table, an unregistered URL failing as
  `.unsupportedURL`: the three headers and the address in the user
  agent and no `Authorization`; the punctuation-heavy name round-trips
  and `query` + `per_page` are the only items; 404 → `.productNotFound`;
  429 → `.rateLimited`; 500 → `.serverError(500)`; offline →
  `.unreachable`; seven pages in order at `per_page=50` on Reverb's
  host, 337 listings, not truncated; `pageCap: 2` → 100 and truncated;
  the foreign `next` not followed, one request, truncated; the mixed
  page reaches the caller with four; the probe through the existential
  from the main actor reads `[false, false, false]`), `MarketCopyTests`
  (the placeholder guard — written without a closure inside `#expect`,
  which trips the macro's throwing inference; three tries to find that).
  Mutations, each reverted: **M1** host check dropped → the foreign-next
  test red (the stub refuses the unregistered example.com page:
  `.unreachable`); **M2a** `@concurrent` off the requirements only →
  green; **M2b** off the implementations only → green; **M2c** off both
  → the probe red with `[true, true, true]` — the SE-0461 matrix, as
  012 established; **M3** the search URL interpolated → the punctuation
  test red (`&` and `#` broke the query); **M4** an `Authorization`
  header added → red. Targeted: 24 tests in 4 suites, one red. Full
  unit suite: **825 tests in 122 suites, 824 passed** — the one red is
  `theContactAddressIsARealOne`, by design, until the person supplies
  the address (Decision 25; they chose to commit without it for now).
  **Open**: the address. When it lands: fill `MarketCopy.contactAddress`,
  rerun `MarketCopyTests` and `ReverbMarketServiceTests` green, tick
  this task.
  Per plan §3 and Decision 25. New `Trove/Models/MarketCopy.swift`
  **minimal** — `contactAddress` (from the person) and its placeholder
  test (one `@`, no whitespace, no `TODO`/`example.com`) — the rest of
  the copy waits for T007. New `Trove/Market/MarketService.swift`
  (protocol, DTOs, `MarketError`) and `ReverbMarketService.swift`
  (`ReverbAPI` constants incl. `productURL(slug:)` and
  `userAgent(version:)` reading `MarketCopy.contactAddress`;
  `sharedSession` ephemeral, 15 s / 60 s, `waitsForConnectivity =
  false`; `URLComponents` everywhere; per-request headers; `_links.next`
  followed only on `api.reverb.com`; page cap; lossy per-listing
  decoding; the error mapping; `requestProbe` seam). New
  `ReverbMarketServiceTests.swift` (`.serialized`, `StubURLProtocol`
  keyed by URL over an ephemeral configuration, no sockets) and
  `ReverbDecodingTests.swift` over every fixture; the concurrency probe
  in the `ExportConcurrencyTests` shape; **G10** (four members on
  `MarketListing` — price, currency, condition slug, year (Amendment
  A); a decoded title-bearing page retains no string but currencies,
  slugs and years). Cases per plan §3: headers present and the
  User-Agent **contains `MarketCopy.contactAddress`**, no
  `Authorization`, the punctuation-heavy name, `query` + `per_page`
  only, 404 / 429 / 500 / offline mapping, seven pages in order,
  `pageCap: 2` → truncated, the foreign `next` not followed, the
  condition-less listing dropped. Mutations: drop the host check → red;
  drop `@concurrent` from both requirement and implementation → probe
  red (requirement-only and implementation-only drops recorded green —
  the SE-0461 matrix); interpolate the query → the punctuation test red;
  add an `Authorization` header → red; a placeholder address → red.
  *Done when*: green, mutations recorded, full suite green with count.
  **Blocks until the address is supplied.**

- [ ] **T005 — Computation, trend, freshness, adoption.**
  Per plan §4. New `Trove/Market/MarketFigure.swift`
  (`MarketSubject`, `MarketConditionMap` per Q1 — `newStockSlugs`,
  failure-open `.wanted`; `MarketFigureComputation.compute`; `median`)
  and `MarketTrend.swift` (`MarketTrend` up/down/flat + `Optional`;
  `compute(history:)` with the most-recent-≥7-days rule and integer
  arithmetic; `MarketFreshness.isCurrent` + `currentMedianCents(of:now:)`
  — the **one** predicate; `MarketAdoption.wholeCurrencyCents(from:)`
  rounding as the display formatter does). Tests
  (`MarketFigureComputationTests`, `MarketTrendTests`,
  `MarketAdoptionTests`): the oracle over the seven decoded pages, **its
  numbers taken from T002's fixtures README**, not from the plan (the
  plan's 2026-09-02 probe: excellent 35 / 140_000 / 115_200 / 325_000;
  good 17; new 210; wanted 151 — if the recording differs, the README
  wins and the plan's Grounding gets a dated note); the `used_total`
  comparison recorded either way; synthetic withheld / three /
  even-median / EUR / disagreeing-currency / unknown-slug (excluded for
  owned, included for wanted); disjoint non-empty buckets; `knownSlugs
  ⊇` every fixture slug; the trend boundary table (7 d exactly, 7 d −
  1 s, ±5 % both sides, the 20/8/1-day pick, one point, previous ≤ 0);
  freshness at 30 d − 1 s / 30 d; the formatter-equality table for
  adoption (145_050, 145_150, 145_049, 145_151). **Amendment A**:
  `MarketYearCoverage` and its table (`MarketYearCoverageTests`,
  every recorded oddity), `compute(year:)` narrowing after currency
  and condition, the all-years fallback under three, the reading's
  `yearScope`; the D-18-shaped synthetic set and the no-year oracle
  unchanged (mutations: unreadable → `.unstated` → red; blank-counts
  rule dropped → red; withhold instead of fall back → red). Mutations: mean for
  median; currency filter dropped; `good` in two buckets; `.wanted`
  failure-closed; oldest point picked; `<` to `<=` at the 7-day
  boundary; adoption half-up → the equality table red.
  *Done when*: green, every mutation recorded, full suite green with
  count.

- [ ] **T006a — The local store helpers, the index, the spies.**
  Per plan §1 (helpers) and §5 (index). New `MarketLocalStore.swift`
  (the static helpers; `record` as the single writer of the cached
  trend, storing the reading's `yearFilter` and `isAllYearsFallback`
  (Amendment A; G4's allowlist grows by two); a point only when the
  reading has a median — Decision 23; the snapshot refreshed on every
  record and written by `recordMatch`;
  `hasAcknowledgedNotice` reading a swallowed error as false;
  `clear`/`clearAll` without saving) and `MarketIndex.swift`
  (`load(from:)`; `MarketSectionState.resolve` lives here too, for
  T009). `TestSupport` gains `MarketServiceSpy` (scripted results, an
  exhausted script throws) and `GatedMarketServiceSpy` (first
  `listings` call gates). `MarketLocalStoreTests`/`MarketIndexTests`:
  record → figure, point, trend, snapshot on a second context; a
  withheld reading → figure, no point; the notice flag (fresh → false;
  acknowledge → true on a second context; twice → one row); `clear`
  removes figure, points, snapshot; the index has an entry for exactly
  the subjects with a figure record. Mutations: append a point when
  withheld → red; skip storing the trend → the equality red; insert a
  second device row → red.
  *Done when*: green, mutations recorded, full suite green with count.

- [ ] **T006b — The refresher, and the byte scan of the store.**
  Per plan §5 and §9 (G5′). New `MarketRefresher.swift` (`refresh(_:)`
  in plan §5's seven steps; `targets(in:)`). `MarketRefresherTests`:
  the hour budget (59 min → `.stillFresh`, spy uncalled; 60 → fetches);
  success on a second context; `.unreachable` leaves the record
  field-by-field unchanged on a second context; `.productNotFound` →
  `.failed`, record untouched; unmatch during a gated refresh → no
  record. **G5′** (`MarketPersistedContentTests`, disk I/O — the
  exception stated): refresh through the stub against the seven-page
  fixture into a two-store container in a temp directory, save, close,
  read both SQLite files as bytes → no listing title, listing id or
  shop name present; the product title present in `MarketLocal.store`
  and absent from `default.store`. Mutations: drop the freshness guard
  → red; clear the record before fetching → the unreachable test red;
  persist a listing title (temporarily widen the DTO) → G5′ red.
  *Done when*: green, mutations recorded, full suite green with count.

- [ ] **T006c — Who clears: every local deletion path.**
  Per plan §1 (who clears). `ItemDetailViewModel.delete`,
  `WishlistDetailViewModel.delete`, both lists' `delete(id:)`,
  `SettingsViewModel.confirmDeleteAll` (→ `clearAll`) each call the
  store before their existing save; each existing deletion suite gains
  a second-context assertion that the item's local rows are gone.
  Mutation: drop the call from any one path → its suite red (all five
  recorded).
  *Done when*: green, five mutations recorded, full suite green.

- [ ] **T007 — `MarketCopy` in full, `MarketAge`, and the vocabulary scan.**
  Per plan §6 (Copy and vocabulary). `MarketCopy.swift` grows to every
  string in the spec's Copy section as amended, Q7's additions, the
  notice, sort labels, dashboard line, picker, Settings, About
  (`attribution` verbatim, `privacyPolicyURL` = the blob URL,
  `privacyPolicyFilename`), and the accessibility strings **including
  the trend arrow's "trending up"/"trending down"** (their single home;
  `TrendArrow` reads them at T012); `figure` composed from
  `median`/`separator`/`listed`. New `MarketAge.swift`. Tests:
  `MarketCopyTests` (every string whole; 1/2 listings; the en dash by
  code point; withheld with/without a price and the wanted variant; the
  notice reassembly; the dashboard line; the candidate reading both
  branches; progress; **Amendment A**: the source line with a year,
  `allYearsFallback(year:)` owned and wanted, the Year field's
  label and validation error), `MarketAgeTests` (the table incl. a
  future date), `MarketVocabularyTests` — allowlist-then-regex over a **named
  file list** (`MarketCopy.swift` now; `MarketSection.swift`,
  `MarketNoticeView.swift`, `MarketMatchView.swift`, `TrendArrow.swift`
  added to the list by the tasks that create them, with the
  `MenuPolicyTests` shape: every named file must exist and be scanned,
  `#require` on the count), plus the no-space structural rule over the
  Market view files. Mutations: "$1,450 value" → red; "lowest used
  price" → red; a file removed from the list → the count red.
  *Done when*: green, mutations recorded, full suite green with count.

## Phase 2 — Design

- [ ] **T008 — The Design pass. [person: invokes `/design`, approves]**
  Per plan Decision 17, Q19, and §6's content contracts. Claude Code
  writes the `/design` prompt into `design/elements/002-market-values/
  brief.md`: the three surfaces (the Market section in its five states
  on both detail screens; the candidate picker with per-card link-back;
  the dashboard variant — line under the figure vs a toggle, coverage
  inseparable), every string from `MarketCopy`, `design/brief.md`'s
  rules (bespoke inside the page, the app's type and tokens, no rendered
  materials), `tokens.md`'s values, `001`'s fixed type sizes, the
  existing detail-screen PNGs for context. The person runs it, iterates
  in the canvas, and drops the `.dc.html` artboards and PNGs into the
  same folder (010's layout). Then `design/tokens.md` gains a "Market
  section, candidate picker, dashboard variant (`002`)" section sourced
  from the artboards, a row per property, "as implemented" filled in by
  the UI tasks; the "market-price ghost" row **and its prose mention at
  `tokens.md:145`** are retired; `design/brief.md` gains the "Market
  figures" paragraph. **If the pass proposes new copy, that is a spec
  question — escalate, don't absorb.**
  *Done when*: artboards and PNGs committed, tokens section written, the
  person's approval recorded in this Done note.

## Phase 3 — Screens

- [ ] **T009a — The Year field on both forms (Amendment A).**
  Per plan Amendment A (Models, forms). `ItemFormViewModel` and
  `WishlistFormViewModel` gain `yearText`, validation (P18: four digits,
  1900 through next year, blank allowed) and the save into `year: Int?`;
  `ItemFormView`/`WishlistFormView` gain the **Year** field in Details
  in the forms' existing field style, numeric keyboard, label and error
  from `MarketCopy`. Tests in both form suites: the validation table;
  blank → nil; edit round-trip on a second context; the error string
  pinned. Wiring: both forms compose the field once, reading
  `MarketCopy.yearLabel`. Mutations: accept "75" → red; drop the save →
  the round-trip red; inline the label → the no-space rule red (the form
  files join the vocabulary scan's list for this field only — state the
  scope in the test).
  *Done when*: green, mutations recorded, full suite green with count;
  the field checked by eye on both forms.

- [ ] **T009 — The detail view models: state, intents, the notice sequence.**
  Per plan §6 (detail VMs). Both `ItemDetailViewModel` and
  `WishlistDetailViewModel`: injection (`marketService`, `now`), the
  state set, `loadMarket()` at the end of `load()` (never a fetch),
  `findMatch`, `continueFromNotice`, `declineNotice`, `setMatch`
  (a different product clears — Decision 26; one save), `refresh`,
  `adopt` (Q15; `updatedAt` on owned only — Decision 24; no history
  write, no fetch), `removeMatch` (one save after both mutations),
  `makeMatchViewModel()`. Tests mirrored across both suites per plan
  §6's list (the resolve table; `loadNeverFetches`; the hour skip; gated
  mid-flight state and reentry; unreachable / rate-limited / product-gone
  leave the figure; adopt on a second context with the formatter
  equality, history untouched, refresher uncalled; adopt refused when
  withheld or stale; remove in one save with `hasChanges == false`;
  change vs same product; the notice sequence incl. a new VM over the
  same container → not pending; `bothDetailViewModelsResolveTheSameState`).
  Mutations: drop `isCurrent` → stale row red; swap withheld/stale order
  → red; drop `save()` in adopt → red; append a point in adopt → red;
  call `refresh` from `load` → red; drop `clear` on a changed match →
  red; drop `acknowledgeNotice` → the new-VM test red.
  *Done when*: green, mutations recorded, full suite green with count.

- [ ] **T010 — `MarketSection` on both detail screens.**
  Per plan §6 (the section table) and T008's artboards. New
  `Trove/Views/Market/MarketSection.swift` taking one
  `MarketSectionActions` value. `ItemDetailView` composes it after
  `details`, before Notes; `WishlistDetailView` where
  `marketPricePlaceholder` was — the placeholder, `placeholderBarHeights`,
  their doc comment, **and the stale comment at `:128`** go. The `Link`
  labelled "View on Reverb" with the hint; `.contain` on the root with
  the explicit per-part labels; two plain buttons for the match actions;
  Refresh disabled within the hour with the hint (Q8); the source line
  carries the year and the all-years line sits above a fallback figure
  (Amendment A). New `MarketWiringTests`: both detail views compose `MarketSection(` once
  inside `content(for:)`; `WishlistDetailView.swift` contains none of
  `marketPricePlaceholder` / `"Market price"` / `"Not tracked yet"`;
  `MarketSection.swift` has `Link(` (non-identifier-boundary regex), no
  `openURL`, `.accessibilityElement(children: .contain)`, no `.combine`,
  the hint, every identifier from plan §6; `MarketSection.swift` added
  to the vocabulary scan's file list. A render check (`renderBitmap` +
  ΔE) that the link's ink is `accentBrass`. The `tokens.md` rows get
  "as implemented". Mutations: restore the ghost → red; drop the hint →
  red; make the link a `Button` → the `Link(` scan red; inline a
  `Text("Find on Reverb…")` → the no-space rule red.
  *Done when*: green, mutations recorded, full suite green; **the five
  states each named in this Done note with what was seen** against the
  artboard on the simulator (states forced through the `-uiTesting`
  store and a temporary preview, removed before commit).

- [ ] **T011 — The notice sheet and the candidate picker — one sheet, both phases.**
  Per plan §6 (notice, picker), Q5, Q9, Q10, Decision 28. New
  `MarketNoticeView.swift`, `Trove/ViewModels/MarketMatchViewModel.swift`,
  `Trove/Views/Market/MarketMatchView.swift` (SearchField, `.onSubmit`,
  the seeded `.task` search, the status line, `EmptyStateView`, the
  cards with `AsyncImage`, the reading, a **View on Reverb** link per
  card, pick → `setMatch`). Both detail views attach the one
  `.sheet(isPresented: $viewModel.isFindingMatch, onDismiss:
  viewModel.load)` whose content branches on `noticeIsPending`; detents
  `[.medium, .large]` with `selection:` driven by the phase. Tests:
  `MarketMatchViewModelTests` per plan (seed; `spy.queries == [name]`;
  blank never calls; phase mapping; reentry). Wiring: the sheet once per
  detail view, branching on `noticeIsPending`, composing both views; the
  notice's `Link(` to `MarketCopy.privacyPolicyURL`; `AsyncImage(` in
  exactly one file under `Trove/Views`; the card composes a `Link(`;
  both new view files added to the vocabulary scan's list; identifiers.
  Mutations: acknowledge on Not now → T009's test red; drop the sheet's
  `onDismiss` → scan red; append the category to the query → red; map
  `.rateLimited` to `.unreachable` → red; drop the per-card link → scan
  red.
  *Done when*: green, mutations recorded, full suite green with count;
  on the `-uiTesting` simulator the notice shows, Not now brings it back,
  Continue opens the picker seeded with the name (the search itself
  fails offline and says so — the live pick is **T018's**, by hand).

- [ ] **T012 — Rows, the trend arrow, and the Market sort.**
  Per plan §6 (rows and sort), Q11. New `TrendArrow.swift` reading its
  labels from `MarketCopy`; `ItemRow` gains `trend` with the arrow last
  in both branches; `WishlistRow` wraps its cost with the arrow
  **after** it; both list VMs gain `marketSummaries` + `trend(for:)`,
  the two `SortOrder` cases in the plan's positions, labels from
  `MarketCopy`, `attributeOrder`'s nil-last block.
  `DropdownPlacementTests`: the seven-row surface **measured** through
  `renderBitmap`, `size` and the two `243`-derived literals updated
  together, the comment corrected. `tokens.md` gains the `TrendArrow`
  row. Tests: `TrendArrowRenderTests` (ΔE on up/down; `.flat` measured
  by host width); both list suites' sort tests (descending/ascending
  with matched, withheld, stale, unmatched; the manual-order tie trick;
  `unmatchedItemsShowNoTrend`; **`aMatchedItemWithARisingHistoryReadsUp`
  through `trend(for:)`**; labels read `MarketCopy` — a scan over both
  VMs); `ItemRow.swift`'s `valueLine` body contains `TrendArrow(trend:`
  twice, `WishlistRow` once after the cost; `TrendArrow.swift` added to
  the vocabulary scan's list. Mutations: the fill token → ΔE red; drop
  `guard left != right` → red; `trend(for:)` returns nil always → the
  rising-history test red; drop one `valueLine` branch's arrow → scan
  red; `value` in a `TrendArrow.swift` literal → vocabulary red.
  *Done when*: green, mutations recorded; the seven-row Sort By still
  hangs below the badge on both lists by eye.

- [ ] **T013 — The dashboard's market variant.**
  Per plan §6 (dashboard), Decisions 21–22, T008's form.
  `DashboardViewModel.apply` gains `marketTotalCents`,
  `marketFigureCount`, `hasMarketFigures`, `marketLine`; the `load()`
  catch resets them. `DashboardView.headline` composes the line after
  the if/else, gated on `hasMarketFigures`. Tests: the sum over current
  medians only; the whole-string line; `marketFiguresLeaveEveryOther
  FigureAlone`; `hasMarketFiguresIsFalseWithNothingMatched`; the wiring
  scan for the gate. Mutations: make the **existing current-value
  total** read medians → red (and `theThreeHeadlineFiguresAlwaysReconcile`
  red — record both); drop the gate → scan red.
  *Done when*: green, mutations recorded; tokens rows filled.

- [ ] **T014 — Settings: Refresh market values, and About.**
  Per plan §6 (Settings and About), Decisions 25, 27, Q12.
  `SettingsViewModel`: `Activity.refreshMarket`, `matchedCount` from
  `MarketRefresher.targets(in:)`, `canRefreshMarketValues`, progress,
  status, `refreshMarketValues()` stopping on the rate limit or the
  first other failure. `SettingsView`: the Market section between
  Templates and iCloud, `SettingsActionRow` with `detail:`, the status
  line, About's attribution + two `Link`s — all strings via
  `MarketCopy`. `SettingsWiringTests` constants move with mutations:
  rows 7, the sections array + "Market", `Link(` count with the
  boundary regex, hint count stays 2, no "reverb"/"mailto"/"http"
  literal in the view. `SettingsViewModelTests`: the walk over both
  kinds in custom order skipping unmatched and within-the-hour; gated
  mid-flight progress and reentry; stop at the rate limit with earlier
  figures kept; stop on unreachable with the copy; `matchedCount`
  counts both kinds. Mutations: keep walking past the rate limit → red;
  fetch only items → red; inline the URL → the literal scan red.
  *Done when*: green, mutations recorded; About's three lines on the
  simulator; the progress row advancing is **T018's** live check.

- [ ] **T015 — UI tests, offline, run twice.**
  Per plan §6 (UI tests), Q13. The four tests in plan §6 with the
  identifiers; the suite run twice back to back **to confirm it is
  re-runnable** — no UI test taps Continue, matches an item or writes a
  local row, so the notice flag's persistence rests on T006a's unit
  tests and T018's dev-store pass, and this Done note says so.
  Mutations: render the section's actions unconditionally → the first
  test red; acknowledge on Not now → the second red; remove a sort case
  → the third red; drop the `canRefreshMarketValues` gate → the fourth
  red.
  *Done when*: UI target green twice, mutations recorded.

## Phase 4 — Contract and policy

- [ ] **T016a — The CSV column and the header tolerance — the atomic commit.**
  Per plan §7, Q16 and Amendment A. `ExportSchema`: the two headers
  appended on both lists (`Reverb Product ID`, `Year` — 14 and 9
  columns; boundaries stay `[12]`/`[7]`), `itemSchemaBoundaries`/`wishlistSchemaBoundaries`, `row(from:)`;
  `ImportSchema`: `requireHeader` accepting boundaries and returning the
  width, both previews using it for the extra-columns guard,
  `reverbProductID(from:)` replacing T003's `nil`, the field policy row;
  the commit paths in both list VMs; `PDFEntry`'s carve-out comment.
  Every test in plan §7's list rewritten or added (incl. the
  legacy-layout literal pin and the PDF carve-out); the samples
  regenerated at 14/9 with T002's ids and plausible years on the four
  music rows,
  **`items-partial.csv` untouched at 12** with its test gaining the two
  assertions; `DocsSampleTests.itemsFullImportsCleanly`'s field loop
  excludes `reverbProductID` and gains "exactly four rows carry an id".
  Mutations: remove the tolerance → the legacy sample red; widen to any
  prefix → the `prefix(11)` case red; read `headers.count` for the width
  guard → `DocsSampleTests.itemsPartial…` red; a `PDFField` for the id →
  red; rename a legacy header → the literal pin red; drop the ids from
  `items-full.csv` → the four-rows assertion red.
  *Done when*: green, all six mutations recorded; templates in Settings
  show the new column; export → re-import restoring the match is
  **T018's** by-hand check.

- [ ] **T016b — The contract's paper half.**
  Per plan §7 (docs). `docs/samples/README.md` (the regenerated rows;
  `items-partial.csv` "written at the 12-column width of Trove before
  `002` — the layout the import still accepts"), `docs/csv-reference.md`
  (counts 13/8, the two new rows, the "exactly these names — with one
  kept exception" sentence, "What fails the whole file", the
  positive-whole-number line, "Export carries an item's Reverb match,
  never the fetched figures"), the 011 plan note (the boundaries rule,
  dated) and the 012 spec's superseded-in-part notes and "68 bytes"
  citation.
  *Done when*: the docs describe what T016a shipped; nothing in the
  targets changed; full suite count unchanged.

- [ ] **T017 — `PRIVACY.md`, its guard, and the README's feature sentences.**
  Per plan §8, Decisions 18, 20, 25, Q20. The policy at the repo root
  quoting `MarketCopy.noticeBody` verbatim, the refresh sentence, the
  retention table as amended (the catalog slug and title row), iCloud,
  no accounts/analytics/SDKs, the contact address, changes. New
  `PrivacyPolicyTests`: the file named by `MarketCopy.privacyPolicyFilename`
  exists at the root (via `#filePath`), contains the notice body
  verbatim, the address, the retention nouns, no placeholder; the blob
  URL's last path component equals the filename. README on the branch:
  the market bullet, the dashboard bullet's coverage clause, the export
  bullet's "carries the match, never the figures", the sort clause, the
  Documentation link to `PRIVACY.md` (Status, tree and specs listing
  stay post-merge). Mutations: rename the file → red; edit one word of
  the quoted notice → red.
  *Done when*: green, mutations recorded. **"Is published" has no
  automated coverage** — a T018/post-merge line item.

## Phase 5 — Verification and close-out

- [ ] **T018 — Device pass with the live API. [person: watches the live half]**
  Per plan §11 and every criterion — the second and last time the
  network is touched. iPhone 17 Pro simulator. Dev store: match a real
  Telecaster (the notice once; Not now first, then Continue — and after
  Continue, a second item's Find on Reverb… shows no notice, across a
  relaunch); the picker's search, cards, per-card link, the pick; the
  section's title and link before any refresh; a year set on the
  Telecaster (2021) and on a vintage match — the count narrowing and
  the all-years fallback on a thin year (Amendment A); refresh — the
  figure
  against the oracle within reason, the spread, the count, the age, the
  link opening reverb.com; withheld on a sparse product (a rare pedal);
  the hour rule (Refresh disabled with the hint); Link Conditioner 100 %
  loss → the failure line with the figure kept; a second matched wanted
  item; the Settings walk with "n of m" advancing over several matched
  items and, if reachable, a real 429 (record whether one was seen);
  rows' arrows (a history point back-dated eight days through a
  temporary debug write, removed before commit — say so); Market sort
  both ways; the dashboard line and its absence at N = 0; adopt and the
  totals reading it; change match, observed on the dev store; export →
  Files → re-import restoring the match, the PDF without it; About's
  three lines, `mailto:` opening Mail if present; VoiceOver over the
  section, the picker, the arrow; the detent switch. `-uiTesting` store
  for anything destructive. Full suite twice; UI suite twice. Every
  finding fixed in place or listed for T019.
  *Done when*: the record is written into this Done note with the
  numbers seen.

- [ ] **T019 — Close-out.**
  Criteria 1–20 ticked in `spec.md` with citations, honest partials
  named (a real 429 if none was seen; the second-device history check;
  "is published" pending merge); the skeptical-reviewer sweep over the
  branch diff; `plan.md` gains "As built" (deviations from the plan,
  the measured Sort By height, the `.automatic` audit's outcome, the
  two-store spike's numbers, Q21 as shipped); this file's status
  flipped; the post-merge list written out (ROADMAP's 002 rewrite +
  status row + the 011 PDF override + the eBay follow-up entry + `003`'s
  input note; README Status/tree/specs listing; `DECISIONS.md`'s entries
  per plan §8 plus Q21 and the live-network-twice rule); PR #11 marked
  ready for review.
  *Done when*: everything above committed and pushed; full suite green
  with the final count recorded here.

## Skeptical-review record (this decomposition, 2026-09-03)

- **Blockers, all acted on**: the contact address was needed by the
  client's user agent three tasks before the task that supplied it —
  `MarketCopy.contactAddress` now lands with T004 as the address's
  single source; T011 claimed "Continue never again" across launches on
  the ephemeral store and T016 claimed the twice-run proved the flag
  ephemeral when no UI test ever sets it — both reworded, the coverage
  cost of Q13 stated in the plan; T003 could not compile without the
  two production `ImportSchema` construction sites it forbade itself to
  touch — named, with the reason a hard-coded nil is not a contract
  change; the picker's and Settings' live-API checks contradicted the
  constitution amended one commit earlier and the plan's "twice only" —
  moved to the device pass; README's four feature sentences and the
  `TrendArrow` tokens row had no task — T017 and T012; and the plan's
  sentence that a failing local store "still opens the collection" was
  false on the code as it stands (the fallback retries the same
  configuration and `TroveApp` ends in `fatalError`) — corrected as Q21
  with a test in T001a.
- **Reshaped**: T001, T006 and T017 split (T001a/b, T006a/b/c,
  T016a/b); the notice and the picker merged so no commit leaves
  Continue opening an empty sheet; G1's mutation names
  `MarketHistoryPoint` (a unique-keyed model would turn
  `CloudKitSchemaTests` red too, which is not the point being proven);
  the vocabulary scan takes a named file list with a `#require` on the
  count; T012 gained the positive trend test its "returns nil always"
  mutation needed; the oracle numbers are read from T002's README, not
  the plan; the index assertion restated at the index level; the arrow's
  labels given one home; the branch and base recorded; the
  `items-full.csv` four-ids assertion added; "byte-for-byte" →
  field-by-field; T010's Done note enumerates the five states; the
  T018 scratch-test duplicate dropped; the dashboard mutation reworded;
  the two stale ghost comments named for removal.
- **Sustained**: T001a before everything with its stop-and-report
  clause; complete guard coverage G1–G10; every T016a mutation traced
  live (the width-guard one fires on `items-partial.csv` row 7); Q15's
  premise (Foundation's `.fractionLength(0)` rounds half-to-even); the
  no-socket test design; no `.pbxproj` edit anywhere.

# 002 — Market Values: Tasks

Status: **Complete** (2026-09-05 — every task checked, the pre-merge sweep dispositioned, PR #11 marked ready; approved 2026-09-03, same day as drafting; **Amendment A — year narrowing** folded in after T002 per spec Decision 29 and plan Amendment A — the tasks it touches say so)

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

Cadence (amended 2026-09-03, when the constitution adopted the
product-owner involvement level): the `skeptical-reviewer` reviews after
each foundational task, scoped to that task's diff, the plan section it
implements, and the acceptance criteria it serves; its verdicts stay
between the implementer and the reviewer, and only "needs the person"
comes forward. Execution pauses for the person after each phase, and
whenever something unexpected bears on spec adherence — never after an
individual task. Every pause produces a report in this shape, in this
order: **why this pause** (a phase boundary, a spec-adherence question,
or an escalation trigger — one line); **what you can now do** (behavior
that exists, as a user would experience it, so attestation is
possible); **where execution deviated from the spec, and why** (every
place, never silently); **what needs your decision** (product questions
only — technical detail lives in `plan.md` and the commit log).

Cadence, amended again 2026-09-05 when the constitution adopted the
skill's tuned model policy (after this spec's tier log was measured;
this note is for the record and for the next spec, since every task
here is done): each dispatch gets a **task bundle** assembled with
shell — task line, plan section, acceptance criteria, files, pattern
file — and the implementer is told not to read `plan.md`, `spec.md`,
or `tasks.md` in full; verification is **`scripts/verify.sh`** and
nothing more verbose, re-run by the orchestrator only in foundational
phases; review bundles are cut after staging; every task gets **one
review and at most one re-review**, with anything still open logged
and left to the sweep; the sweep runs at the reviewer's default tier
on the documents plus `git diff main...HEAD`; and the orchestrator
starts a **fresh session at each phase pause**, resuming from the
first unchecked task.

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

  **Corrected at T006a**: the single in-memory configuration over the
  union cannot hold a local model once the app's two-store container
  exists in the process (SwiftData keeps the model → store assignment
  for the process); `.ephemeral` and `makeInMemoryContainer()` are now
  the pair, in memory — two in-memory stores coexist, the `/dev/null`
  worry was unfounded. The previews still build a single union
  configuration and are fine until one inserts a local model; the
  Market section's preview (T010) builds the pair.
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

- [x] **T004 — `MarketService`, `ReverbMarketService`, decoding. [person: the contact address]**
  *Done (2026-09-03; the address 2026-09-04)*: `MarketService`
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
  **Closed 2026-09-04**: the person supplied a provisional personal
  address, to be replaced with a dedicated one before the app is
  published (Decision 25's dated note); `MarketCopy.contactAddress`
  filled, `MarketCopyTests` and `ReverbMarketServiceTests` green (30
  tests in 2 suites) — the guard had been the one red of every full run
  since T004 landed, so its red run needs no separate mutation. The
  note as written while open: fill `MarketCopy.contactAddress`,
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

- [x] **T005 — Computation, trend, freshness, adoption.**
  *Done (2026-09-03)*: `MarketFigure.swift` — `MarketSubject`,
  `MarketConditionMap` (Q1's buckets; `newStockSlugs`; `.wanted` = not
  new stock, failure-open), `MarketYearCoverage` (a hand parser, no
  regex: four digits, `YYYY - YYYY`, `YYYY - Present` to the current
  year, `YYYYs`; anything else a mismatch; blank unstated), `YearScope`
  (`.any` / `.year` / `.allYears(fallbackFrom:)`), `MarketFigure`,
  `MarketReading` (withheld carries the scope it ended on),
  `MarketFigureComputation.compute(listings:subject:year:product:fetchedAt:now:)`
  and `median(sortedCents:)`; `MarketTrend.swift` — `MarketHistoryEntry`,
  `MarketTrend` (integer arithmetic, most-recent qualifying previous),
  `MarketFreshness` (`isCurrent`, `currentMedianCents` — the one
  predicate), `MarketAdoption` (`NSDecimalRound` `.bankers`). Tests: 34
  in 3 suites — the oracle from the README (excellent 34 / 139999 /
  115200 / 325000; good 17; new 208; wanted 72 with `used_total` 108
  recorded as larger, not equal; fair and broken withheld at 0 with
  100000), every recorded slug known, two vs three, the even median,
  dollars only, unknown slug out for owned and in for wanted, new stock
  never for wanted, disjoint non-empty buckets covering exactly the
  known set, truncation carried; the D-18-shaped set narrowed to 1975 →
  17 (twelve in range, three singles, two unstated; the six 1973s out)
  and to 1999 → the all-years fallback over 23; no year → the oracle
  untouched; the Telecaster narrowed to 2021 against an expected count
  derived from the raw fixture years by an independent list (24 of 34);
  a withheld reading carrying `.allYears`; the coverage table with the
  three recorded oddities plus `seventies`, `19750`, `197`, a backwards
  range; the trend at 7 d exactly and 7 d − 1 s, ±5 % on both sides
  (1050 up, 1049 flat, 950 down, 951 flat), the 20/8/1-day pick, order
  independence, one point / too close / zero previous; freshness at
  30 d − 1 s and 30 d; the predicate nil when withheld or stale;
  adoption's formatter-equality table over eight values and the
  half-to-even pair (145_050 → 145_000, 145_150 → 145_200). Mutations,
  each reverted: **M1** mean for median → five oracle tests red; **M2**
  currency filter dropped → seven red (excellent 45 not 34, wanted 103);
  **M3** `good` in two buckets → the disjointness test red and the fair
  withheld case red; **M4** `.wanted` failure-closed → the unknown-slug
  test red; **M5** oldest previous point → the 20/8/1 test red (`.up`
  not `.flat`); **M6** `>` at the seven-day boundary → three red; **M7**
  adoption half-up → the equality table red at 145_050 and 50, and the
  pair test; **M8** unreadable → `.unstated` → the six oddities and the
  backwards range red; **M9** unstated excluded → the D-18 count 15 not
  17, the Telecaster 14 not 24; **M10** withhold instead of fall back →
  the two fallback tests red. Full unit suite: **859 tests in 125
  suites, 858 passed** — the one red is still T004's address guard.
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

- [x] **T006a — The local store helpers, the index, the spies.**
  *Done (2026-09-03)*: `MarketLocalStore.swift` (`MarketSubjectKey`;
  reads `figure`/`snapshot`/`history`/`historyEntries`/
  `hasAcknowledgedNotice` (a failed fetch reads false); writes
  `recordMatch`, `record` — upsert the row, a point iff the reading has
  a median (Decision 23), the trend recomputed over the whole history
  incl. the pending insert, the snapshot refreshed, `yearFilter` and
  `isAllYearsFallback` from the scope — `clear`, `clearAll`,
  `acknowledgeNotice`; **no helper saves**); `MarketFigureRecord` gained
  `yearFilter: Int?` and `isAllYearsFallback: Bool` (G4's allowlist
  grew by two); `MarketIndex.swift` (`MarketSnapshotValue` with
  `currentMedianCents(now:)` through the one predicate, `MarketIndex.load`,
  `MarketSectionState.resolve` with `MarketMatchDisplay` and
  `MarketMatchSnapshotValue` — the web URL composed from the slug);
  `TestSupport` gained `MarketServiceSpy` (scripts per method, an
  exhausted script throws `ScriptExhausted(call:)`) and
  `GatedMarketServiceSpy` (first `listings` call gates). Tests:
  `MarketLocalStoreTests` (9) and `MarketIndexTests` (7), every
  persistence assertion on a second context. **The finding**: the first
  run died in the test host with "Can't assign an object to a store that
  does not contain the object's entity" on inserting a local model into
  `makeInMemoryContainer()`'s single union configuration — the same
  exception T001a's M5 mutation had shown. Bisected standalone on macOS
  with two throwaway models, eight variants each in its own process:
  every single-configuration shape works in a fresh process; after a
  two-configuration container has assigned a type to a store, a later
  single-configuration union container cannot hold that type, while a
  later two-configuration one (in memory too) can. So `.ephemeral` and
  `makeInMemoryContainer()` are now the pair in memory; plan §1 and R2
  corrected with the date, T001b's note amended. Targeted: 39 tests in 5
  suites green after the fix. Full unit suite: **875 tests in 127
  suites, 874 passed** (the address guard). Mutations, each reverted:
  **M1** a point appended when withheld → red; **M2** the trend not
  stored → both trend assertions red; **M3** acknowledge always inserts →
  red on "the first time is kept" — the count stayed 1 because the
  unique key turned the second insert into an overwrite, the structural
  guarantee doing its job, so the test's second assertion is the one
  that matters; **M4** clear leaves the snapshot → red.
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

- [x] **T006b — The refresher, and the byte scan of the store.**
  *Done (2026-09-03)*: `MarketRefresher.swift` — `MarketRefreshTarget`
  (key, product, subject, year), `MarketRefresher` (MainActor;
  `Outcome` = refreshed / stillFresh / failed / **superseded** / saveFailed;
  `refresh(_:)` in the plan's order with the item re-read after the
  awaits — its condition and year as they are *now* — and a rollback on a
  failed save; `targets(in:)` matched owned in custom order then matched
  wanted, the one definition of "matched"). Tests: `MarketRefresherTests`
  (10: within the hour nothing is sent; at the hour it fetches product
  then listings; a refresh writes figure, point, snapshot in one save
  with `hasChanges == false`; the item's year narrows; a withheld
  reading saved without a point; each of four failures leaves the record
  field by field on a second context; an unmatch and a re-match during a
  gated fetch both drop the result, leaving no row; targets in order
  with kinds, subjects and years) and `MarketPersistedContentTests`
  (**G5′**, disk I/O: a refresh against the seven fixture pages into a
  two-store scratch container, then the bytes of `default.store` and
  `MarketLocal.store` with their `-wal`/`-shm` — the catalog title in the
  local file and not the collection, the item's own name in the
  collection so the scan is known to read something, and none of 300+
  listing titles anywhere; titles the catalog title itself contains are
  skipped, since three listings are titled with the product's own name
  and the first run flagged exactly those). Targeted: 10 tests in 2
  suites green. Full unit suite: **885 tests in 129 suites, 884 passed**
  (the address guard). Mutations, each reverted: **M1** the freshness
  guard dropped → `withinTheHourNothingIsSent` red on both assertions;
  **M2** the record cleared before fetching → the four failure cases red
  (the row gone); **M3** a listing title smuggled — the decoder putting
  the title in `year` and the refresher naming the product after a
  listing — → G5′ red naming the leaked title, and two refresher tests
  red beside it. Not written: a foreign (non-`MarketError`) error from
  the service, which the spy's `Result` type can't produce; the mapping
  to `.malformedResponse` is a two-line catch, read rather than tested.
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

- [x] **T006c — Who clears: every local deletion path.**
  *Done (2026-09-03)*: `ItemDetailViewModel.delete`,
  `WishlistDetailViewModel.delete`, `ItemListViewModel.delete(id:)`,
  `WishlistViewModel.delete(id:)` call `MarketLocalStore.clear` inside
  their existing `do` before the save (a thrown clear takes the failure
  path the save already had); `SettingsViewModel.confirmDeleteAll` calls
  `clearAll` — figures, history, snapshots and the notice flag, whichever
  list is emptied, because Delete All is the one "start over" the app
  offers and the rows are keyed by items that are gone or about to be
  irrelevant. Each of the five suites gained one test (a private
  `seedMarketRows`/`marketRowsRemain` pair per file, reading back on a
  second context; the Settings one parameterised over both targets and
  asserting all four local tables empty). Targeted: 44 tests in 4
  suites green plus the Settings suite (`SettingsViewModelSurfaceTests`
  — its struct name differs from its file, so a file-named selector
  silently ran the whole suite; noted for the memory file). Full unit
  suite: **890 tests in 129 suites, 889 passed** (the address guard).
  Mutations, each reverted: dropping the clear from each of the five
  paths → that path's new test red on "the deleted item's market rows
  survived it" (the survivor assertion stayed green throughout, so the
  test can tell "cleared the wrong rows" from "cleared none").
  *Corrected 2026-09-04 (spec Decision 30)*: Delete All now clears per
  deleted item through `clear(subjectID:)` and leaves the other list's
  rows and the notice flag alone; `clearAll` and its store test are
  gone. The Settings test asserts the deleted rows gone **and** the
  survivor's rows and the flag intact (mutations: clear every table →
  the survivor and flag assertions red; drop the clear → the deleted
  rows red).
  Per plan §1 (who clears). `ItemDetailViewModel.delete`,
  `WishlistDetailViewModel.delete`, both lists' `delete(id:)`,
  `SettingsViewModel.confirmDeleteAll` (→ `clearAll`) each call the
  store before their existing save; each existing deletion suite gains
  a second-context assertion that the item's local rows are gone.
  Mutation: drop the call from any one path → its suite red (all five
  recorded).
  *Done when*: green, five mutations recorded, full suite green.

- [x] **T007 — `MarketCopy` in full, `MarketAge`, and the vocabulary scan.**
  *Done (2026-09-03)*: `MarketCopy` grew from the one address to every
  string — section (`sourceLine(title:year:)`, `median`, `listed`,
  `figure` composed from the parts, `spread` with U+2013, `age`,
  `withheld(usedLowCents:wanted:)` dropping its second sentence with no
  catalog price, `allYearsFallback(year:wanted:)`, `refreshDue`,
  `notRefreshedHere`), actions, the notice, failure
  (`unreachable(fetchedAt:at:)`, `unreachableNoFigure`, `rateLimited`,
  `productGone`), sort, `dashboardLine` ("12 of 34 items"), the picker,
  Settings, About (`attribution` verbatim, `contactURL`,
  `privacyPolicyTitle`/`Filename`/`URL` — the blob URL, Decision 18),
  the year field (`yearLabel`, `yearValidationError(nextYear:)`), and
  accessibility. `MarketAge.description(of:at:)` — just now / minutes /
  hours / days, a future date as now. Tests: `MarketCopyTests` (19 —
  every string whole, the composed forms at 1 and 2 listings, the en
  dash by scalar, the notice reassembly, both withheld and fallback
  variants, the address guard still red by design), `MarketAgeTests`
  (a fifteen-row table; the tuple table had to be typed and
  `nonisolated static` for the macro), `MarketVocabularyTests` (rule 1
  over a named file list with a `#require` it isn't empty — allowed
  phrases stripped, then `\b(value|values|valued|valuation|worth|price|prices|priced|sold)\b`;
  rule 2 the framing in use; rule 3 no spaced literal in the Market
  view files — the view list starts empty and T009a/T010–T012 grow it).
  Targeted: 23 tests in 3 suites, 22 green. Full unit suite: **912
  tests in 131 suites, 911 passed** (the address guard). Mutations, each
  reverted: **M1** "$1,450 value" → the scan red naming the literal;
  **M2** "lowest used price" → red; **M3** every "asking price" renamed
  → rule 2 red (and four whole-string pins); **M4** the copy file list
  emptied → the `#require` red; **M5** the age boundary `> 60` → the
  60-second row red. **Phase 1 closes here.** *The reviewer pass over the phase (2026-09-03)*:
  two blockers and five reshapes, all folded, plus two items for the
  person carried into the phase report (decided 2026-09-04 as spec
  Decisions 30 and 31: Delete All narrowed to the deleted items' rows;
  the notice's second sentence reworded — `noticeBody`, its test, the
  spec's Copy and retention paragraphs changed together). **B1** — G7's "no record in the
  collection" assertion had no red run, and its mutation (the record
  moved to the synced list, unique key dropped so the pair loads) showed
  a SwiftData reader over the collection's file returning nothing even
  for its own positive control — so the split half is now proven by
  **bytes**: a sentinel on the record found in `MarketLocal.store` and
  absent from `default.store`, red at that exact assertion under the
  mutation (the sentinel at offset 28608 of the collection). **B2** —
  criterion 16's "never trimmed by age" had no guard: a 400-day-old
  point now survives the next refresh (mutation: a thirty-day prune →
  red, both assertions). **S1** — a missing `listing_currency` now counts
  for no currency (`?≠USD`), a seventh listing in `listings-mixed.json`
  pins it, the mixed-page tests read five. **S2** — the recorder splices
  its block between `<!-- recorded:start/end -->` markers so the README's
  hand-written sections survive a re-record. **S3/S4** — Q21's two
  accepted costs and three as-built details recorded in the plan. **N3**
  — one `now()` after the awaits. **N6** — G6's comment. Full unit suite
  after the fold: **913 tests in 131 suites, 912 passed** (the address
  guard). Sent back for re-review.

## Phase 2 — Design

- [x] **T008 — The Design pass. [person: invokes `/design`, approves]**
  *Done (2026-09-05)* — **approved by the person 2026-09-05** ("I'm
  signing off on the designs"). PNGs rendered by the orchestrator from
  the artboards at 2× through a WebKit snapshot script (the canvas's own
  export runs through a save dialog), one per frame, named by the frame's
  stem, in the same folder. `tokens.md` gained the "Market section,
  candidate picker, dashboard variant (`002`)" section with "as
  implemented" columns for T010–T013; the market-price ghost row is
  retired and its prose mention reworded; `brief.md` gained the "Market
  figures" paragraph. Top tier, in session (the pass predates the model
  policy's first dispatch).
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
  *In progress (2026-09-04)*: the brief written (`brief.md`, commit
  `b9b2c63`); the person ran `/design` in this session and the pass was
  drafted here against the `010` artboard sources and the shipped
  tokens — seventeen `.dc.html` artboards plus `canvas.json` in the same
  folder: the Market section in every state on the item detail (matched
  current, unmatched, never refreshed, withheld, stale, narrowed to all
  years, just refreshed with Refresh disabled, the failure overlay), the
  wishlist detail with **Use as estimated cost**, a states sheet (the
  Refresh looks, the four failure lines, every reading without a figure,
  the all-years lines, the picker's status and failures), the notice and
  picker sheet (notice, results, searching, no matches, failed), and the
  dashboard's market line with the toggle drawn beside it as the
  rejected alternative. Design calls to record in `tokens.md` on
  approval: the section is an unbroken block, not a card; filled brass =
  writes the person's data (adopt only), outlined brass = fetches, text =
  match actions with rust for Remove; the median is IBM Plex Mono 500
  19px, the count and spread 12.5/11.5 mono at 45 %, the age 11px mono at
  40 % right-aligned on the reading's row; the dashboard line is 12.5px
  mono at 45 % with the amount at 500/75 %. No new copy was needed. The
  canvas: https://claude.ai/code/artifact/772b2eee-d238-4a56-8a63-faf17c1926ba
  — PNG export per artboard is the person's step from the canvas toolbar.
  *Done when*: artboards and PNGs committed, tokens section written, the
  person's approval recorded in this Done note.

## Phase 3 — Screens

- [x] **T009a — The Year field on both forms (Amendment A).**
  *Done (2026-09-04)* — the first task under the model policy: dispatched
  to `sdd-implementer`, verified by the orchestrator's own run. Both
  form VMs gained `yearText`, a `yearInvalid` validation case, a
  `parsedYear` (trimmed, exactly four ASCII digits, 1900…next year) and
  the `year` write/load; the item form's Year field sits after Serial
  number through `labelledField`/`plainTextField` (`labelledField` gained
  an `isInvalid` parameter so the year can wear the form's rust border);
  the wishlist form writes its field out in its `notesField` shape,
  between the photo picker and Notes; both append
  `MarketCopy.yearValidationError(nextYear:)` to the save caption (the
  caption's `monoLabel` style uppercases it on screen, as it does the
  existing "NEEDS …" line — a surface to look at on the device pass).
  Placeholder empty: the spec gives the field no placeholder copy.
  Tests: a shared `YearCase` table ("" and whitespace → nil; "1975" →
  1975; "75", "abc", "1899", next year + 1, **"01975"** → the error), the
  message pinned, the round-trip on a second context, and a targeted
  wiring scan in `MarketVocabularyTests` over the two form files
  (`MarketCopy.yearLabel`/`yearValidationError` present, no inlined
  `"Year"`) — the forms stay out of `viewFiles`, since the whole-file
  no-space rule would fail on their existing placeholders. Mutations,
  each red then reverted: accept "75" → the "75" rows red; **the task's
  "drop the four-digit check" mutation was not falsifiable as written**
  ("75" fails the 1900 bound regardless) — the "01975" row was added and
  goes red on it; drop the `year` write → the round-trip red; inline the
  label → the wiring scan red. Full unit suite (orchestrator's run):
  **919 tests in 131 suites, all passed**. Checked by eye on the
  simulator: the Year field on both forms in the field style.
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

- [x] **T009 — The detail view models: state, intents, the notice sequence.**
  *Done (2026-09-04)* — dispatched to `sdd-implementer`, verified by the
  orchestrator's own runs, reviewed three rounds by the
  `skeptical-reviewer` at its default tier. As built: injection
  (`marketService`, `now`) in the `SettingsViewModel` shape; the shared
  pieces plan §6 calls "the derivation written once" live beside
  `MarketSectionState` in `MarketIndex.swift` — `resolve(subjectID:
  productID:in:now:)`, `lastFetchedAt` (the hour gate's input),
  `currentFigureFetchedAt` (the notice's date, a `.current` reading
  only), `MarketActivity`, `MarketNotice` with `notice(for:lastFetchedAt:)`
  mapping every refresher outcome; every intent per plan §6, one save
  each; `WishlistItem` has no `updatedAt` (Decision 24), said at each
  wanted intent; `setMatch`/`removeMatch` also clear the notice; a
  refused save rolls back the shared context and re-derives with no
  message (plan §6 as-built paragraph — **for the Phase 3 report**: a
  failed Remove match looks like a no-op, by transcription, since the
  spec gives no copy for it). `makeMatchViewModel()` moved to T011.
  Tests: 31 across two new suites (`ItemDetailViewModelMarketTests`,
  `WishlistDetailViewModelMarketTests`) — the eight-row state table,
  `loadNeverFetches` with a yield pump and a third assertion that the
  hour gate wasn't what kept the spy quiet, the hour boundary proven on
  both sides (the button and the refresher agree at exactly 3600 s),
  the gated mid-flight state with a bounded spin, unreachable /
  rate-limited / product-gone leaving the figure, the stale-plus-failure
  notice carrying no date, adopt on a second context with the formatter
  equality and `updatedAt` on owned only, adopt refused when withheld
  or stale, remove in one save, change vs same product, the notice
  sequence with a new VM over the same container, the ten-row outcome
  table, `bothDetailViewModelsResolveTheSameState`. Mutations, each red
  then reverted: drop `isCurrent` → stale rows red (and `canAdopt`'s
  refusal with them); withheld before stale → row 8 red; drop `save()`
  in adopt → red; append a point in adopt → red; `refresh` from `load`
  → red; drop `clear` on a changed match → red; drop `acknowledgeNotice`
  → the new-VM test red; `.superseded` → `.rateLimited` → the table red;
  stop clearing the notice in `removeMatch` → red; refresher `<` → `<=`
  → the boundary red; pass the date for a stale reading → red. Review
  rounds: 1 — two blockers (wishlist `updatedAt` unrecorded; the notice
  table untested) and six should-fixes, all folded; 2 — the task line
  still named `makeMatchViewModel()` (moved to T011) and the stale-date
  bug (fixed); 3 — signed off; its one note (the `lastFetchedAt` doc comment's nil
  case) applied by the orchestrator with T012's commit. Findings recorded: plan §5 (the refresher's `subject`/
  `year` inputs never reach the computation), plan §6 (as-built
  paragraph). Full unit suite (orchestrator's run): **950 tests in 133
  suites, all passed**.
  Per plan §6 (detail VMs). Both `ItemDetailViewModel` and
  `WishlistDetailViewModel`: injection (`marketService`, `now`), the
  state set, `loadMarket()` at the end of `load()` (never a fetch),
  `findMatch`, `continueFromNotice`, `declineNotice`, `setMatch`
  (a different product clears — Decision 26; one save), `refresh`,
  `adopt` (Q15; `updatedAt` on owned only — Decision 24; no history
  write, no fetch), `removeMatch` (one save after both mutations). (`makeMatchViewModel()`
  moved to T011 at the 2026-09-04 review: the type it returns is created
  there.) Tests mirrored across both suites per plan
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

- [x] **T010 — `MarketSection` on both detail screens.**
  *Done (2026-09-05)* — dispatched to `sdd-implementer`, verified by the
  orchestrator's own run; not foundational, so no per-task review. As
  built: `Trove/Views/Market/MarketSection.swift` — `MarketSectionActions`
  (five closures, `refresh` async), the section as a `DetailSection`
  block with every reading, the notice line, Refresh's three looks, the
  six identifiers, `MarketReverbLink` as its own type so its ink can be
  sampled; three typography roles added (`buttonProminent` sans 600
  13.5, `button` sans 500 13.5, `buttonCompact` sans 500 13 — no
  existing role carried the design's weight hierarchy). Composed as
  `marketSection(for:)` after `details` on the item screen and where the
  ghost was on the wishlist screen; the ghost, `placeholderBarHeights`,
  their doc comment and the stale `:128` comment gone (the live half of
  that comment, on "Your estimate", reworded). Deviations from the
  artboards, recorded in `tokens.md`'s "As implemented" cells: the
  median at `monoValue` 15 pt, not 19 — tokens.md defines it as "the
  PAID cell's register" and PAID has shipped at `monoValue` since 010,
  so 19 would have set Reverb's figure larger than the person's own;
  count/separator at `monoMeta` 11.5 (12.5 drawn), age 11.5 (11 drawn);
  adopt dims while a refresh is in flight (`canAdopt`), where the states
  sheet drew it full. Tests: +9 — `MarketWiringTests` (both screens
  compose `marketSection(for: item)` inside `content(for:)` and
  `MarketSection(` once per file; the wishlist file free of the ghost's
  three tells; `Link(` by the boundary regex, no `openURL`, `.contain`
  present and `.combine` absent, the hint, all six identifiers) and
  `MarketLinkRenderTests` (the link's ink within ΔE 0.02 of
  `accentBrass` — a `Link` takes its label's `foregroundStyle`, measured
  4e-8; plan §6's open question answered). `MarketSection.swift` joined
  the vocabulary scan. Mutations, each red then reverted: the ghost
  restored → red; the hint dropped → red; the link a `Button` → the
  `Link(` scan red; an inline `Text("Find on Reverb…")` → the no-space
  rule red; the link's ink `textPrimary` → ΔE red. Full unit suite
  (orchestrator's run): **1006 tests in 141 suites, all passed**.
  **The eye check** (renders at 2× from a temporary harness, deleted
  before commit, seen by the orchestrator against the artboards):
  *unmatched* — MARKET and the outlined Find on Reverb… alone;
  *current* — source line, `$1,450 · 12 listed`, spread left and age
  right, the brass link with its glyph, outlined Refresh beside filled
  Use as my value, Change match… / Remove match in brass and rust;
  *withheld* — the two-sentence reading with $2,850, the age alone at
  right, Refresh full-width, no adopt; *all years* — the fallback line
  under "On Reverb · Martin D-18 · 1975" above the $2,950 figure;
  *failure* — the rust line between the link and the actions, the
  figure untouched above it; *wishlist current* — Use as estimated cost.
  `never`, `stale`, `justRefreshed` (disabled Refresh) and `refreshing`
  rendered too. Two things a render cannot show, carried to T018: the
  refreshing spinner (`ImageRenderer` draws `ProgressView` as a box),
  and — **for the Phase 3 report** — the failure copy says "The figure
  below is from …" while the approved layout puts the line below the
  figure.
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

- [x] **T011 — The notice sheet and the candidate picker — one sheet, both phases.**
  *Done (2026-09-05)* — dispatched to `sdd-implementer`, verified by the
  orchestrator's own run; not foundational, so no per-task review. As
  built: `MarketMatchViewModel` (`@Observable`, no SwiftUI; `query`,
  `phase`, `search()` trimmed, blank → `.idle` with no call,
  reentry-guarded; only `.rateLimited` is its own failure, every other
  error `.unreachable`); `MarketNoticeView` (the body, the privacy
  `Link` **under** the paragraph — a `Link` is a view and cannot flow
  inside `Text`, and markdown-in-`Text` would give up the `.isLink`
  trait; recorded in `tokens.md`), Continue filled / Not now outlined at
  48 pt; `MarketMatchView` (`NavigationStack`, Cancel, the shared
  `SearchField` at its 40 pt, the seeded `.task` search, `.onSubmit`,
  the status line, `EmptyStateView` for empty and failed, cards with
  `AsyncImage`, wrapping title, brand, the reading, a footer `Link` to
  `ReverbAPI.productURL(slug:)` — the body picks); `MarketButtons.swift`
  holds the filled/outlined chrome as `ViewModifier`s shared with
  `MarketSection`; both detail views attach the one `.sheet(isPresented:
  $viewModel.isFindingMatch, onDismiss: viewModel.load)` as `matchSheet`,
  branching on `noticeIsPending`, detents `[.medium, .large]` with
  `selection:` following the phase; `makeMatchViewModel()` on both VMs,
  seeded with the item's name. `GatedMarketServiceSpy` gained
  `gatesSearch:`. Tests: +16 in 1 suite (`MarketMatchViewModelTests`: the
  seed from both VMs and from Change match…; blank/cleared/trimmed
  queries; results and empty phases; the five-case error table; a
  non-`MarketError` → unreachable; reentry) plus five wiring scans (the
  sheet once per screen with `onDismiss` and the branch; the notice's
  `Link(` to the policy URL; the per-card `Link(`; `AsyncImage(` in
  exactly one file under `Trove/Views`, found by walking the directory;
  the identifiers). Mutations, each red then reverted: acknowledge on
  Not now → T009's notice-sequence test red; drop `onDismiss` → red;
  append the category to the seed → red; `.rateLimited` → `.unreachable`
  → red; the card's link a `Button` → red. Full unit suite
  (orchestrator's run): **1022 tests in 142 suites, all passed**. **On
  the `-uiTesting` simulator (orchestrator):** the notice showed at the
  medium detent on the first Find on Reverb…; Not now closed it and the
  next Find on Reverb… showed it again; Continue opened the picker at the
  large detent seeded with "Fender Telecaster" — and, the simulator being
  online, one live search returned real candidates with photos, brand,
  readings and per-card links (the live half T018 repeats by hand).
  Includes `makeMatchViewModel()` on both detail VMs — moved here from
  T009 at the 2026-09-04 review, since `MarketMatchViewModel` is created
  in this task.
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

- [x] **T012 — Rows, the trend arrow, and the Market sort.**
  *Done (2026-09-04)* — dispatched to `sdd-implementer`, verified by the
  orchestrator's own run; not foundational, so no per-task review. As
  built: `TrendArrow.swift` (new, through the synchronized group) reads
  `MarketCopy.trendUp/trendDown` and the theme's `*Text` lifts;
  `MarketSummary` beside `MarketSnapshotValue` in `MarketIndex.swift`,
  built through `MarketFreshness.currentMedianCents` so stale and
  withheld sort last; both list VMs gain `marketSummaries` (assigned
  right after the fetch, **before** the sort — assigned after, every
  pair tied and the Market sort silently became manual order; the sort
  tests caught it; plan §6 note for T013), `trend(for:)`, a `now` clock,
  the two `SortOrder` cases in Q11's positions with `MarketCopy` labels
  and the nil-last block; `ItemRow` draws the arrow last in both
  `valueLine` branches, `WishlistRow` after the cost; both lists pass
  the VM's trend (a defaulted parameter, so a scan pins the call sites).
  `DropdownPlacementTests`: the seven-row surface **measured at 232 ×
  327**, `size` and the two derived literals updated, plus a case that
  renders the real seven-row `SortDropdown` and pins `size` to it (243
  put back → red at 327 ≠ 243). `tokens.md` gains the trend-arrow table
  and the reserved-slot row now says what it was for.
  `MarketVocabularyTests.viewFiles` has its first file, so rule 3 stops
  being vacuous. Tests: +21 in 4 suites (`TrendArrowRenderTests`,
  `TrendArrowWiringTests`, `ItemListViewModelMarketSortTests`,
  `WishlistMarketSortTests`). Mutations, each red then reverted: the up
  fill → brass → ΔE red (and "neither is brass" red); drop the tie
  guard → the tie tests red in both suites; `trend(for:)` nil always →
  the rising-history test red in both; drop one `valueLine` arrow →
  the wiring scan red; `"market value"` in `TrendArrow.swift` → both
  vocabulary rules red. Full unit suite (orchestrator's run): **971
  tests in 137 suites, all passed**. By eye on the simulator: the
  seven-row Sort By hangs below the badge on both lists, Market ↓ /
  Market ↑ after Value / Cost.
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

- [x] **T013 — The dashboard's market variant.**
  *Done (2026-09-05)* — dispatched to `sdd-implementer`, verified by the
  orchestrator's own run; not foundational, so no per-task review. As
  built: `MarketSummary.summaries(forSubjects:in:now:)` in
  `MarketIndex.swift` is the one derivation (the item list VM delegates
  to it); `DashboardViewModel` gains `now`, `marketTotalCents`,
  `marketFigureCount`, `hasMarketFigures`, `marketLine` (whole string
  through `MarketCopy.dashboardLine`, M = `totalItemCount`), the
  summaries built over the scoped ids **before** `apply` (T012's
  ordering), the `catch` resetting both; `DashboardView.headline`
  composes `if viewModel.hasMarketFigures { marketLine }` after the
  if/else — one `Text` over an `AttributedString` at `monoMeta` /
  `textMonoMeta` with the amount's range lifted to medium / `textBody`,
  `.lineLimit(1)` + `.minimumScaleFactor(0.6)` so the coverage shrinks
  with the number and never leaves it (P5). Register 11.5 against the
  design's 12.5, recorded in `tokens.md`. Tests: +8 in 2 suites — the
  sum over current medians only (withheld, stale, unmatched and
  out-of-scope excluded), wishlist figures never reaching the total, the
  whole-string line, `marketFiguresLeaveEveryOtherFigureAlone`,
  `hasMarketFigures` false with nothing matched and false when every
  figure is withheld or stale; the gate scan and a no-"Market"-literal
  scan on the dashboard. Mutations, each red then reverted: the
  existing total made to read medians → the leave-alone test red plus
  two existing headline tests — **but `theThreeHeadlineFiguresAlwaysReconcile`
  stayed green: it asserts `total − spent == delta` where `delta` is
  defined as that subtraction, a tautology; the plan's claimed red run
  was wrong, and it is rewritten in the follow-up pass below**; stale
  and withheld included in the sum → red; the gate dropped → red;
  `Text("Market")` typed in the view → red. The `load()` catch's reset
  of the two figures is implemented but unreachable from tests (no
  dashboard test exercises the catch). Full unit suite (orchestrator's
  run): **1030 tests in 144 suites, all passed**. The line on the device
  with a real refreshed figure is T018's.
  *Follow-up (same day)*: `theThreeHeadlineFiguresAlwaysReconcile`
  restructured against hand-written literals (red under the T013
  mutation at two of its three assertions — the suite's four other
  headline tests had caught that mutation all along; the tautology was
  one named guard, not an unguarded total); `WishlistViewModel` folded
  onto `MarketSummary.summaries(forSubjects:in:now:)`, now the one
  derivation with all three callers. Count unchanged, 1030 in 144.
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

- [x] **T014 — Settings: Refresh market values, and About.**
  *Done (2026-09-04)* — dispatched to `sdd-implementer`, verified by the
  orchestrator's own run; not foundational, so no per-task review. As
  built: `Activity.refreshMarket`; `marketService`/`now` injected in the
  `exportService` shape; `matchedCount` from `MarketRefresher.targets`
  (every matched item — the row's gate) while the walk's `total` counts
  only the due ones (plan §6 as-built note: everything fresh → an
  enabled row whose walk visits nothing and says nothing; a T018 line);
  `refreshMarketValues()` sequential over the due targets with progress
  after each, stopping at the rate limit with `MarketCopy.rateLimited`
  and at any other failure with `refreshStoppedUnreachable(done:total:)`,
  `defer` clearing activity and progress and reloading. The view: the
  Market section between Templates and iCloud, `SettingsActionRow`'s new
  `detail:` in mono meta before the spinner, a rust status line under
  the row (both statuses are failures), About's attribution and two
  `Link`s with identifiers `about.contact`/`about.privacy`, no literal
  "reverb"/"mailto"/"http" in the view (a preview item was renamed off
  "Deluxe Reverb" so the scan stays honest). Wiring constants moved
  together: sections + `marketSection`, rows 6 → 7, `Link(` == 2 by the
  boundary regex, hint count still 2. Tests: +8 in 1 suite
  (`SettingsViewModelMarketRefreshTests`: the walk over both kinds in
  custom order skipping unmatched and within-the-hour; gated progress
  and refused reentry; the rate-limit stop keeping earlier figures and
  never calling the third; the unreachable stop with "1 of 3";
  `matchedCount` over both kinds) and the three wiring scans.
  Mutations, each red then reverted: walk past the rate limit → red
  (the third target's call observed, its figure absent); items only →
  red; inline the privacy URL → the literal scan red (and the two-links
  scan); rows back to 6 with seven present → red. Full unit suite
  (orchestrator's run): **979 tests in 138 suites, all passed**. By eye
  on the simulator: the Market section between Templates and iCloud,
  its row disabled with nothing matched; About's three lines. The
  progress row advancing is T018's live check.
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

- [x] **T015 — UI tests, offline, run twice.**
  *Done (2026-09-05)* — dispatched to `sdd-implementer`, verified by the
  orchestrator's own runs (the UI target once more, green: 13 tests, 0
  failures; the unit target unchanged at 1030 in 144). The four tests
  from plan §6 with their helpers: an unmatched owned item and an
  unmatched wanted item each show `market.find` and none of Refresh,
  adopt, the link, Change match… or Remove match, and "Not tracked yet"
  exists nowhere; the first Find on Reverb… shows the notice with
  Continue and Not now and no search field, Not now closes it, the next
  Find on Reverb… shows it again (Q5), Not now again leaves the app
  clean — **no UI test ever taps Continue, matches an item or writes a
  local row (Q13), so the notice flag's persistence and every
  figure-bearing state rest on the unit suites and T018's dev-store
  pass; the twice-run proves re-runnability, nothing more**; both lists'
  Sort By offers Market ↓ and Market ↑; Settings' Market row exists and
  is disabled on the empty store, "not endorsed" is on screen, and the
  About links exist. No shipping file changed — every identifier was
  already there. Run twice back to back by the implementer (13/13 both
  runs, ~209 s each) and twice again after the reverts. Mutations, each
  red then reverted: the actions rendered in the unmatched state → test
  1 red on both kinds; Not now acknowledging → test 2 red ("the second
  find should have shown it again" — under that mutation alone the
  picker appeared and made one live search, the only network the UI
  target has ever touched); the market pair removed from the sort menu
  (an explicit `allCases` without them — deleting the case is a compile
  failure in the unit target, which is red but proves nothing about the
  UI test) → test 3 red on both rows; the `canRefreshMarketValues` gate
  dropped → test 4 red. **Phase 3 closes here.**
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

## Phase 3b — Amendment B, the adopt flow (spec Decisions 33–36; plan Amendment B, signed off 2026-09-05) — **Signed off** (skeptical-reviewer, top tier, two rounds, 2026-09-05)

Folded in at the Phase 3 pause. The frame comes first and is the
person's gate; T021 and T022 need no frame and run while it waits; T023
and T024 wait for the frame's approval and Q22's answer. Reviewed by the
skeptical-reviewer at the top tier (2026-09-05): round 1 "fix and
re-review" — T024's Done-when had asked for a live pick against the
two-touches rule, plus seven should-fixes, all folded; round 2 signed
off with four small notes, folded below (the interim adopt closure, the
`cents(atX:` scan, two wordings).

- [x] **T020 — The value-step frame. [person: approves; answers Q22]**
  *Done (2026-09-05)* — the frame `ValueStep.dc.html` and its PNG
  committed with the tokens table (a59397a → 5a1061a); **approved by the
  person 2026-09-05** ("signed off on the designs"), who also reported
  the interim state exactly as recorded under T022 — the spinner that
  never finishes is the `.value` phase's placeholder, and the section's
  Use as my value works after a swipe-down. **Q22 answered 2026-09-05**: the person delegated the call to Claude
  Code; the proposed "typical" wording became spec Decision 37, the Copy
  block, Decision 34 and the Adopting bullet were amended, and the
  pending markers came off `MarketCopy` and its test — no pin moved.
  Per plan Amendment B (Design) and spec's *(B)* Design line. One
  artboard, `ValueStep.dc.html`, drawn in session as the Phase 2 frames
  were, joined to the existing canvas and rendered to PNG: the sheet at
  the medium detent over the item detail — the title, the figure as the
  section draws it with the true spread, the slider (a thin `divider`
  track, the brass fill to the knob, three marks with the median's
  taller, the trimmed-bound amounts beneath the ends), the guidance
  line, the filled button with the live amount, Not now. `tokens.md`
  gains "The value step and the slider" with empty "as implemented"
  cells. **Q22 goes to the person with the frame**: the spoken marks
  and hint once trimming bites, and Decision 34's "low, median and
  high" phrase.
  *Done when*: the frame and PNG committed, the person's approval and
  Q22's answer recorded here; the Copy block, Decision 34 and the
  Adopting bullet's "low, median and high marked" phrase amended on the
  answer (three places, one sentence each).

- [x] **T021 — The trimmed bounds: computation, record, copy, retention.**
  *Done (2026-09-05)* — dispatched to `sdd-implementer` (four passes),
  verified by the orchestrator's own runs, reviewed four rounds by the
  `skeptical-reviewer` at its default tier. As built: `MarketFigure.p10Cents`
  / `p90Cents` by nearest rank (`(p·n + 99) / 100`, 1-based — `p10 == low`
  for n ≤ 10, `p90 == high` for n ≤ 9; the oracle's excellent bucket
  gives 120,000 / 169,900, the 4th and 31st of 34, recorded in the
  fixtures README with a dated note that the columns came from the
  script's logic run offline over the committed fixtures); the two
  optional fields on `MarketFigureRecord` (G4 +2), written on a figure
  and nilled on a withheld reading, carried by `MarketSnapshotValue`;
  `MarketValueStep.swift` — `MarketValueBounds.bounds(for:)` as one
  decision over the pair with the low/high fallback, `MarketValueStep`
  rounding the default and both bounds once at construction and
  `setChosen` rounding then clamping, three `precondition`s (a median,
  low and high, ordered bounds — traps, unverifiable by Swift Testing,
  recorded in plan B4) naming the landing rule as the caller's
  obligation; `MarketCopy`'s value-step block, nine strings plus
  `medianAskingPriceLabel(cents:)` lowercase, the three Q22 strings
  marked pending in comments; `PRIVACY.md`'s Reverb sentence matching
  the retention row. Tests: +16 net across the run (B1 with n = 3, 9,
  10, 12 and the oracle; B2; B4 plus the half-populated pair; the step's
  whole-currency, clamp-and-round and zero-width tests; B7; the two
  fields round-tripping on a second context and nil after a withheld
  refresh; the vocabulary scan's strip made boundary-aware at both ends
  with an eight-row table). Mutations, each red then reverted: linear
  interpolation → B1 red; floor+1 → the n = 10 test red (the n = 9 row
  is the "still coincides" side and stays green there by design); a
  third record field → G4 red; the fallback dropped → B4 red; the
  per-field fallback restored → the pair test red; `setChosen` without
  rounding → red; the raw substring strip → the "Refresh your values"
  row red; the leading boundary forced → the "Trove has my value" row
  red; bounds swapped → the (since deleted) ordering test red. Review
  rounds: 1 — the bundle had omitted the two untracked files (built
  with `git add -N` from then on) and four should-fixes; 2 — the plan's
  Copy bullet contradicted the shipped median string, and a new test
  could not fail (deleted, per the constitution — the fourth instance
  of the shape, on the close-out list for `CLAUDE.md`); 3 — an off-by-
  one in three threshold comments and no boundary tests; 4 — signed
  off. Durable notes from the last round, recorded in plan Amendment B:
  the test shim's `p10 = low, p90 = high` defaults are a state the
  computation reaches only for n ≤ 9, so bounds tests must use the
  memberwise init; the recording script is a second implementation of
  the rank rule bound to the Swift only by the README's numbers; the
  PRIVACY field list is a sweep item. Full unit suite (orchestrator's
  run): **1046 tests in 146 suites, all passed**.
  Per plan Amendment B (the bounds; whole currency, once; copy) and
  Decision 36. `MarketFigure` gains `p10Cents`/`p90Cents` (nearest rank,
  `⌈P/100·n⌉`-th smallest); `MarketFigureRecord` gains the two optional
  fields (G4 +2); `MarketSnapshotValue` carries them; `MarketLocalStore.
  record` writes them; `MarketValueBounds.bounds(for:)` is the one
  fallback; `MarketValueStep` (the value type, `setChosen` rounding and
  clamping, the zero-width case) lives with it. `MarketCopy` gains the
  value step's strings — Q22's proposed wording for the marks and hint,
  marked pending in a comment. `PRIVACY.md`'s Reverb sentence ("keeps
  only the summary numbers … a median, a low, a high, a count, a
  timestamp") gains the trimmed range (the table row already has it).
  Tests: B1 (the oracle's 4th and 31st, recorded; `n = 3`; the twelve
  with an outlier asserting `sorted[1]`/`sorted[10]`), B2, B4, B7, the
  step's whole-currency and clamp-and-round tests, the zero-width step.
  Mutations: linear interpolation → B1 red; a third record field → G4
  red; the fallback dropped → B4 red; `setChosen` without rounding →
  red. Foundational: reviewer on the diff.
  *Done when*: green, mutations recorded, full suite green with count.

- [x] **T022 — The detail view models: the sheet's phases, the pick's refresh, `adopt(cents:)`.**
  *Done (2026-09-05)* — dispatched to `sdd-implementer` (five passes),
  verified by the orchestrator's own runs, reviewed five rounds by the
  `skeptical-reviewer` at its default tier. As built: `MarketSheetStep`
  (`.notice`, `.pick`, `.fetching(MarketCandidate, token: Int)`,
  `.value(MarketValueStep)`; `Equatable, Sendable`; a payload-free
  `phase` the detent observer keys off) replaces `noticeIsPending`, which
  appears nowhere under `Trove/` (a whole-app scan with a control);
  `setMatch(_:) async` guarded by `case .pick`, one save with the refused
  save rolling back, closing and fetching nothing (a structural test pins
  the `return` and the token's position after the catch), then the
  **fetch token** and the **generation rule** — every `setMatch` and
  `refresh()` start takes the next generation; `loadMarket()` first, then
  only the newest fetch's landing writes the notice (date from the
  re-derived state) and clears the activity flag; the landing moves the
  sheet only if it is still this fetch's presentation (token match) and,
  within that, `.value` over a current reading or close; a landing whose
  fetch is no longer the sheet's touches the sheet not at all;
  `openValueStep()`, `setChosen(_:)`, `dismissValueStep()`,
  `adopt(cents:)` (rounds once more for any caller, `updatedAt` on owned,
  one save, no history, no fetch, closes even when refused); the interim
  sheet body (a `ProgressView` for `.fetching`/`.value` until T024) and
  interim adopt closure (`adopt(cents: adoptableMedianCents)`, no
  rounding in views); `MarketMatchView.pick` async in a `Task`.
  `GatedMarketServiceSpy` gained keyed waiters, `release(listingsCall:)`,
  a per-call `listingsScript`, and a categorical precondition against
  unkeyed releases in every-call mode. Tests: +35 net across the run —
  B3 in both suites, mirrored, including the re-open, the second pick
  after a re-open, the same product re-picked, the older refresh landing
  before and after the pick, the second-pick guard, the refused-save
  scan, the token-position pin; the three phase-to-detent wiring pins.
  Mutations, each red then reverted: the median written instead of the
  chosen amount; the landing re-presenting after a dismissal; the
  candidate compared instead of the token (two directions); the
  generation guard deleted at each site; the second-pick guard dropped;
  Not now acknowledging (T009's test); `noticeIsPending` kept derived;
  the rounding removed from `adopt(cents:)`; the `return` deleted; the
  token moved above the `do`; the detents swapped in one view; an
  unkeyed release on an every-call spy (a deterministic trap). Review
  rounds: 1 — the bare presentation flag and an activity conjunct that
  regressed picks during a section refresh; 2 — the candidate conjunct
  unverified, a formatted-string comparison, the concurrent-refresh
  hole → the token and the generation rule (orchestrator's decisions,
  recorded); 3 — the guard correct but unguarded; 4 — the spy's
  precondition racy in one test; 5 — signed off. Recorded for later: the
  reverse quadrant is closed by the current call graph (one `refresh()`
  caller), not by construction; the value step's dismissal detent is a
  T018 line; the source-walker consolidation is T024's. Full unit suite
  (orchestrator's run): **1081 tests in 146 suites, all passed**.
  Per plan Amendment B (the detail view models; the picker) and
  Decisions 33–35. `sheetStep: MarketSheetStep` replaces `noticeIsPending`
  (removed, not derived); `setMatch(_:) async` guarded against a second
  pick, setting `.fetching(candidate, token:)` and `marketActivity`, awaiting the
  refresher, the notice's date read after the save, the landing rule
  stated once (a `.current` reading with the sheet still presented →
  `.value`, else close; a landing after dismissal never re-presents);
  `openValueStep()`; `adopt(cents:)` replacing `adopt()` with the
  refused-save behavior kept; `dismissValueStep()`. `MarketMatchView`'s
  `pick` becomes `async`, called in a `Task`; the wiring pins move
  (`noticeIsPending` → `sheetStep`; the detent `onChange`). **Interim
  sheet body**: until T024, the switch renders the notice and the picker
  as today and, for `.fetching` and `.value`, a bare `ProgressView`
  placeholder with a comment naming T024 — B5's "composes all four
  phases" is T024's; T022 takes B5's one line that is its own guard,
  `noticeIsPending` appears nowhere. **Interim adopt closure**: until
  T024 rewires it, the section's adopt action calls `adopt(cents:
  wholeCurrency(median))` — today's one-tap behavior — so no commit
  leaves Use as my value opening a placeholder sheet (the header's rule);
  `openValueStep()` exists and is tested but has no caller until T024.
  **Between T022 and T024 a successful pick shows the interim
  `ProgressView` sheet — at the large detent while `.fetching`, snapping
  to medium on `.value` — with no way out but a swipe-down**; the two
  phases render the same content until T024 draws them; the section's adopt stays live. Recorded so a run of the
  app in this window is not read as a defect. Tests: B3 in both suites, mirrored,
  **less the step's own tests** (`theChosenAmountIsClampedAndRounded`,
  `theStepIsWholeCurrencyFromANonWholeMedian` live on the value type in
  T021; T022 keeps the VM-level assertion that `adopt(cents:)` writes a
  whole amount); the existing adopt tests move to `adopt(cents:)` and
  `openValueStep`. Mutations: write the median instead of the chosen
  amount → red; re-present after dismissal → red; drop the second-pick
  guard → red; drop `acknowledgeNotice` still red from T009's test.
  Foundational: reviewer on the diff.
  *Done when*: green, mutations recorded, full suite green with count.

- [x] **T023 — `MarketValueSlider`.** *(after T020's approval)*
  *Done (2026-09-05)* — dispatched to `sdd-implementer`, verified by the
  orchestrator's own run; not foundational, so no per-task review. As
  built: `Trove/Views/Market/MarketValueSlider.swift` — Trove's own
  control (`divider` track, `accentBrass` fill to the knob, end marks
  and the taller `accentBrassDim` median mark, the ringed brass knob with
  the frame's shadow, the bound amounts and "median" beneath; input
  `(step:isWanted:onChange:)` for T024 to bind to the VM's `setChosen`);
  pure `nonisolated` seams `cents(atX:trackWidth:lower:upper:median:)`,
  `x(forCents:…)`, `marks(…)`, `adjustableStep(lower:upper:)`,
  `snapTolerance = 6`, the `DragGesture` closure and the adjustable
  action calling them; zero-width range → no NaN, one mark, drag inert;
  label / value / hint from `MarketCopy`, the mark labels one combined
  element (a hand join would need a space literal). Tests: +17 in 2
  suites (twelve seam tests at literals — the 0.3 fraction, the snap
  inside and outside the tolerance, the step and its floor, the
  zero-width cases; three render tests — the fill's extent at 30 %, the
  fill's ΔE, the zero-width render) plus two wiring scans (no `Slider(`
  by the boundary regex, `accessibilityAdjustableAction`; the gesture
  calls `cents(atX:` and the action `adjustableStep(`). Mutations, each
  red then reverted: the knob at the midpoint → red; the fill token →
  `accentBrassDim` → ΔE red; the snap removed → red; a literal step in
  the action → the seam scan red; the zero-width guard removed → `x` is
  NaN → red (an `ImageRenderer` treats a NaN offset as zero, so only the
  seam test sees it — recorded in the runner memory); a system `Slider(`
  → red; the knob fill → `divider` → the zero-width render red. `tokens.md`'s
  slider rows filled (the label row 16 pt for the mono line box; the
  knob's shadow the frame's 40 % black). Full unit suite (orchestrator's
  run): **1098 tests in 148 suites, all passed**. Seen rendered by the
  orchestrator against the frame through a temporary harness (deleted):
  the default with the knob on the median, a moved knob with the median
  mark reappearing under the fill, and the zero-width range as one knob
  and one amount. `market.value.slider` is T024's to attach at the call
  site.
  Per plan Amendment B (the views — the slider) and the frame. Trove's
  own control in `Trove/Views/Market/MarketValueSlider.swift`: the
  track, the fill, three marks, the end amounts, the drag mapping in
  whole-currency steps with `snapTolerance` (6 pt) to the median,
  `accessibilityAdjustableAction` by `adjustableStep` (1 % of the range,
  whole currency, at least one unit), label / value / hint from
  `MarketCopy`, the zero-width range drawn as one mark with the drag
  inert. **The x→cents mapping is a pure static seam**,
  `MarketValueSlider.cents(atX:trackWidth:step:)` (and its inverse for
  the knob), so the snap and drag tests drive it directly — the
  `DragGesture` closure only calls it. Tests: B6 in full (the 0.3
  fraction from literals, the ΔE, the adjustable step, the snap inside
  and outside the tolerance through the seam, the zero-width case); the
  file joins the vocabulary scan; B5's no-`Slider(` and
  `accessibilityAdjustableAction` scans, plus a scan that the file's
  gesture calls `cents(atX:` (so the pure seam is what the gesture uses). Mutations: default at the
  midpoint → red; the fill token swapped → red; the snap removed → red;
  `adjustableStep` unread (a literal in its place) → red; the zero-width
  range dividing by zero (a NaN fraction) → red; a system `Slider` → red.
  *Done when*: green, mutations recorded, full suite green with count;
  the slider seen rendered against the frame.

- [x] **T024 — `MarketValueStepView` and the sheet's four phases.** *(after T023)*
  *Done (2026-09-05)* — dispatched to `sdd-implementer`, verified by the
  orchestrator's own run; not foundational, so no per-task review. As
  built: `MarketValueStepView.swift` (new) — `MarketValueStepActions`
  (`choose`/`use`/`notNow`), the title at `emptyStateTitle` (the frame's
  Archivo 600 19), the figure block through pieces extracted from
  `MarketSection` (`MarketFigureRow`, `MarketSpreadLine`, `MarketQuietLine`,
  kept in that file so its copy pins stand), the slider bound to
  `setChosen`, the guidance line, the 48 pt filled/outlined pair, the
  three identifiers; `MarketFetchingView.swift` (new) — the picked
  candidate's card (`MarketCandidateCard`, extracted within
  `MarketMatchView.swift` so the `AsyncImage` scan still names one file)
  over the status line reading `fetchingAskingPrices`, in the picker's
  bar and padding; both detail views' sheets compose all four phases;
  the section's adopt action is `openValueStep()`; the interim
  `adoptableMedianCents` and comments are gone; `MarketSectionState.matchedTitle`
  added so the view derives nothing. The three source walkers in the
  wiring tests consolidated onto `SourceScan.swiftFiles(under:minimum:)`;
  the flag-gone scan names the two view models instead of a bare `>= 4`.
  `tokens.md`'s value-step rows filled. Tests: +5 wiring scans (the four
  phases in both screens; the section's actions calling `openValueStep`
  and not `adopt(cents:`; the step view composing the slider and its
  identifiers; the fetching branch reading its copy; the step's copy
  symbols). Mutations, each red then reverted: a phase back to a bare
  `ProgressView` → red; the section's adopt writing directly → red;
  `market.value.use` removed → red; `Text("Set your value")` inline →
  the no-space rule red. Full unit suite (orchestrator's run): **1103
  tests in 148 suites, all passed**. Seen rendered by the orchestrator
  against the frame (a temporary harness, deleted): the owned step
  ($1,450 · 12 listed, the true spread, the knob on the median between
  $1,150 and $1,900, the guidance, Use $1,450 as my value / Not now), the
  wanted step (Set your estimated cost / Use $349 as estimated cost),
  the year in the source line (Martin D-18 · 1975), and the fetching
  card with its status line (the spinner is a renderer placeholder;
  the sheet's bar cannot be rendered — T018's). Q22's constants and
  pins untouched, still pending. Left for close-out: a fourth identical
  walker in `ReorderWiringTests` (one line onto `SourceScan`).
  *Carried from T022's reviews*: consolidate the three hand-written
  source walkers in the wiring tests (`allAppSwiftFiles`, `filesUnderViews`,
  the one in `ExportWiringTests`) onto `SourceScan`; loosen or name the
  `>= 4` control in `theSheetsOldNoticeFlagIsGoneFromTheApp` if `sheetStep`
  moves; if the value step's dismissal flickers the detent (the resting
  step is `.pick` → large), a resting phase that leaves the detent alone.
  Per plan Amendment B (the views) and the frame. The sheet switches on
  `sheetStep`: notice, picker, the fetching card with the status line,
  the value step (title, the figure and true spread, the slider, the
  guidance line, the filled button with the live amount, Not now);
  detents `.medium` / `.large` by phase; the section's adopt action
  calls `openValueStep()`; identifiers `market.value.slider`,
  `market.value.use`, `market.value.notNow`. If Q22's answer reworded
  the marks or hint, this task retires T021's pending comment and moves
  the `MarketCopyTests` pins. Tests: B5's remainder (the four-phase
  composition, the detents by phase, the section's adopt action calling
  `openValueStep()`); the vocabulary scan gains the file; `MarketCopy`
  pins for any string the view composes. Mutations: a phase dropped →
  red; the adopt action calling `adopt` directly → the actions scan red.
  *Done when*: green, mutations recorded, full suite green with count;
  the four phases seen rendered — the value step from fixture-built
  steps — through a temporary harness (removed before commit) against the frame, with
  what was seen named here — **the live pick is T018's** (its B8 lines
  are already in place; the value step cannot be reached under
  `-uiTesting`, per Q13 and the two-touches rule); `tokens.md`'s "as
  implemented" cells for the value step and the slider filled.

## Phase 4 — Contract and policy

- [x] **T016a — The CSV column and the header tolerance — the atomic commit.**
  *Done (2026-09-05, one commit with T016b)* — dispatched to
  `sdd-implementer` (three passes), verified by the orchestrator's own
  runs, reviewed two rounds by the `skeptical-reviewer` at its default
  tier. As built: `itemHeaders` 14 / `wishlistHeaders` 9 (plan §7's 13/8
  carry a superseded note); `itemSchemaBoundaries = [12]` /
  `wishlistSchemaBoundaries = [7]`; `requireHeader` accepts the full
  header or a boundary prefix and nothing else, returns the width
  (`@discardableResult`), and reports `wrongList` for the other list's
  full and boundary widths; both previews guard extra columns by the
  matched width while padding to `headers.count`; `reverbProductID(from:)`
  (ASCII digits, overflow-checked, > 0, trimmed) and `year(from:
  timeZone:now:)` (four digits, `FieldNormalization.earliestYear`…next
  year of the given clock and zone) — blank silent, unreadable counted;
  both list VMs' commit paths set the two fields; `PDFEntry`'s carve-out
  comment. `FieldNormalization.earliestYear` is the one lower bound, read
  by both forms and the importer. Samples at 14/9 (`items-full.csv`: the
  four music rows 160322/2023, 182769/2018, 80684/2021, 17/2015;
  `wishlist.csv`: one matched, 232/2019 — the '65 Deluxe Reverb reissue,
  looked up by hand and recorded in the fixtures README; the three
  `bad-*` files); **`items-partial.csv` untouched at 12**. Tests: +11
  (the legacy literal pins for both lists; `theLegacyLayoutStillPasses`;
  legacy imports with no match and no year on both lists; the overlong
  legacy row; the other list's legacy headers as `wrongList`; the two
  parse tables — "01975", a Tokyo instant at the year's turn, past pins
  that can never come true; the round trips carrying both fields; the
  14/9-cell hand rows; the PDF carve-out; both commit paths on a second
  context; DocsSampleTests' four-ids / years-by-value / one-matched-wish
  assertions and items-partial's 12-cell header and all-nil rows).
  Mutations, each red then reverted: tolerance removed → the legacy
  sample red; any prefix → `prefix(11)` red; width guard on
  `headers.count` → items-partial's row-7 count red; a `PDFField` for
  the id → red; a legacy header renamed → the literal pin red; the ids
  blanked → the four-rows assertion red; pad to the matched width →
  index-out-of-range (attribution proven by disabling the new test);
  `.now` for `now` → the pinned table red; trim dropped → red; the bound
  → 1901 → red at all three call sites; the zone assignment dropped →
  the Tokyo row red. Review round 1: one blocker (the docs — resolved by
  landing T016b in the same commit) and four should-fixes, all folded;
  round 2: signed off, its second-look items folded in a third pass;
  two of them carried forward — **for the Phase 4 report**: the docs
  now say `Year` is the year the piece was made (a 2023 reissue of a
  1961 model is 2023), a semantic the spec leaves unstated (a P18
  clarification for the person), and the boundary tolerance supersedes
  012's "missing columns fail the file" in the one legacy case (Q16,
  recorded in the 012 spec). Full unit suite (orchestrator's run):
  **990 tests in 138 suites, all passed**. Templates in Settings read
  the header arrays directly (their byte-pinning tests held).
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

- [x] **T016b — The contract's paper half.**
  *Done (2026-09-05, one commit with T016a)* — dispatched to
  `sdd-implementer`; the docs describe what T016a shipped: 14/9 columns
  and their rows, the one kept exception (a header cut at 12 / 7 — the
  layout Trove wrote before 002 — still imports with the new columns
  blank; one column short still fails), the positive-whole-number and
  four-digit-year lines with what `Year` means, "Export carries an
  item's Reverb match, never the fetched figures"; the samples README's
  rows (`items-partial.csv` "written at the 12-column width of Trove
  before `002` — the layout the import still accepts"); the 011 plan's
  dated boundaries-rule entry; the 012 spec's superseded-in-part note on
  the header gate, its two width statements annotated, and the "68
  bytes" citation kept as the historical figure beside 91 (wishlist) and
  172 (items), computed as BOM + header + CRLF and checked by the
  reviewer to the byte. Suite count unchanged (990 in 138).
  Per plan §7 (docs). `docs/samples/README.md` (the regenerated rows;
  `items-partial.csv` "written at the 12-column width of Trove before
  `002` — the layout the import still accepts"), `docs/csv-reference.md`
  (counts **14/9** — the task text said 13/8 before Amendment A added
  `Year`; corrected 2026-09-05 — the two new rows, the "exactly these
  names — with one kept exception" sentence, "What fails the whole file", the
  positive-whole-number line, "Export carries an item's Reverb match,
  never the fetched figures"), the 011 plan note (the boundaries rule,
  dated) and the 012 spec's superseded-in-part notes and "68 bytes"
  citation.
  *Done when*: the docs describe what T016a shipped; nothing in the
  targets changed; full suite count unchanged.

- [x] **T017 — `PRIVACY.md`, its guard, and the README's feature sentences.**
  *Done (2026-09-05)* — dispatched to `sdd-implementer`, verified by the
  orchestrator's own run and a read of the policy itself (prose; the
  guard can't judge it). `PRIVACY.md` at the root: the lead (no
  accounts, nothing collected, one outside service beyond Apple's iCloud
  sync), one table of what is stored where — the person's own data
  synced to their private iCloud database, then the spec's retention
  rows including the catalog slug and title (Decision 20), the
  listing-content row as "nowhere" — the notice body quoted verbatim,
  what searching and refreshing send (the condition and year applied on
  the device), the User-Agent's contents, nothing on launch or in the
  background, Reverb's attribution verbatim, iCloud, nothing else,
  contact as a mailto link, changes. `PrivacyPolicyTests` (7): the file
  exists under `MarketCopy.privacyPolicyFilename`; quotes `noticeBody`,
  `contactAddress` and `attribution` verbatim; carries the retention
  nouns; no placeholder; a dated "Last updated" line; the blob URL's
  last path component is the filename. README: the Market values bullet,
  the dashboard's Market-line clause, the export bullet's "match and
  year, never the fetched figures", the Market sort clause, the
  Documentation line. Mutations, each red then reverted: the file
  renamed → six of seven red (only the URL test reads no file); one word
  of the quoted notice changed → exactly the verbatim test red. Full
  unit suite (orchestrator's run): **997 tests in 139 suites, all
  passed**. "Is published" is T018's post-merge line; the address swap
  is now a two-file edit and the README bullet gets a close-out re-read
  (both noted in T019).
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

- [x] **T018 — Device pass with the live API. [person: watches the live half]**
  *Amendment B (B8) adds*: pick → fetching card → the value step at the
  median → drag → Use → the item's value on the detail and the dashboard;
  Not now writes nothing; the section's Use as my value opens the same
  step; swipe-down mid-fetch leaves the section correct and never
  re-presents the sheet.
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
  *Done 2026-09-05* — iPhone 17 Pro simulator (iOS 26.0.1), the
  `-uiTesting` in-memory store, the live API touched by hand: two
  searches and two listings calls, the second and last time the network
  is touched in this spec. What was seen, in order:
  - **Owned path** (Fender Telecaster, Music/Guitars, paid $1,150, no
    year). The notice once, Continue. Live search: four cards (Player
    II, tuning heads, "American Professional II Telecaster · $1,000 ·
    112 listed", American Ultra II). Pick → the fetching card → the
    value step at the medium detent: "On Reverb · Fender American
    Professional II Telecaster", $1,400 · 34 listed, spread
    $1,152–$3,250, the slider $1,200 to $1,699 with the median mark.
    The trimmed bounds equal the recorded oracle fixture for the same
    product's excellent bucket (p10 120,000 / p90 169,900 cents) to the
    cent — the live computation and the fixture agree. Drag → the
    button followed ("Use $1,591 as my value"); Use → the sheet closed,
    WORTH NOW $1,591, +441 · +38%. The section: source line, $1,400 · 34
    listed, $1,152–$3,250, "as of 2 minutes ago", View on Reverb ↗,
    Refresh disabled, Use as my value, Change match…, Remove match. The
    section's Use as my value reopened the same step at the median
    default; Not now closed it and wrote nothing (WORTH NOW still
    $1,591). Dashboard: CURRENT VALUE $1,591, "Market · $1,400 · 1 of 1
    items" with the amount reading as a real medium weight beside the
    label text (T013 finding closed), SPENT $1,150, GAIN +$441. Items:
    "1 ITEM · $1,591"; Sort By offers Market ↓ / Market ↑, choosing
    Market ↓ relabels the button; the row keeps "+441 vs paid" and shows
    no arrow — one history point is no trend (spec line 124).
  - **Wanted path** (Shure SM7B, Music/Microphones, $500, Year 2020 —
    the form's Year field sits below Photos, as planned). Find on
    Reverb… showed no notice (accepted earlier this launch). Live cards:
    SM7B "Lowest used asking price $175 · 45 listed", RK345 windscreen
    "No used listings", A7WS windscreen "$20 · 4 listed", Gator case.
    Pick → "Set your estimated cost", "On Reverb · Shure SM7B Cardioid
    Dynamic Microphone · 2020", $292 · 35 listed (the year narrowed 45
    → 35; Amendment A), spread $175–$450, slider $259 to $398, "Use
    $292 as estimated cost"; Use → ESTIMATED COST $292, the section "as
    of just now". Change match… reopened the picker with the same query
    and cards (no current-match marker; none is specified); Cancel left
    the section intact. Remove match → Find on Reverb… again, the
    estimated cost still $292.
  - **Settings**: MARKET → Refresh market values, enabled with one
    matched row. Tapping it said nothing: the row was three minutes old,
    inside the freshness window, so nothing was due and a completed walk
    says nothing. The "n of m" line advancing needs hour-old rows and
    rests on `SettingsViewModelMarketRefreshTests`.
  - **Detents**: the picker at large, the value step at medium, the
    switch seen on both picks. A flicker on dismissal cannot be caught
    in stills — the person's item, below.
  - **Not exercised here**, carried as honest partials for T019 and the
    person: Not now first on the notice and the no-notice-across-relaunch
    check; a vintage year's thin fallback ("all years shown"); a sparse
    product withheld; Link Conditioner 100 % loss (the failure line with
    the figure kept); a real 429 (none seen in four calls); rows' arrows
    via a back-dated history point (no debug write was made — the arrow's
    thresholds and render rest on `TrendArrowRenderTests` and the list
    suites); the dashboard line's absence at N = 0 (not re-observed after
    seeding); export → Files → re-import (the simulator app exposes no
    Documents folder to Files; the round trip rests on the import/export
    suites); About's three lines and `mailto:`; VoiceOver over the
    section, picker and arrow; a physical device.
  - **Suites**: full unit suite twice back to back, **1103 tests in 148
    suites passed** both runs (10.8 s and 10.9 s of test time); UI suite
    twice back to back, **13 tests, 0 failures** both runs (211 s each).

- [x] **T019 — Close-out.**
  *Sweep list, added 2026-09-05 at T016a's review*: stale statements
  outside 002's own documents that the contract change left behind —
  `specs/012-data-import/plan.md` (~line 99: the re-save fixture as "12
  columns plus four trailing commas"; it is 14 now), `specs/013-settings-
  menu/spec.md` (~line 806: "the wishlist template staged at 68 bytes";
  91 since 002). Annotate them dated, alongside plan §8's post-merge
  ROADMAP/README/DECISIONS list.
  Also re-read the README's Market values bullet and dashboard clause
  (written at T017, before T010/T011/T013 built the screens) against the
  shipped behavior, and note that swapping the provisional contact
  address is a two-file edit (`MarketCopy.contactAddress`, `PRIVACY.md`).
  T018 also checks the dashboard line's lifted amount reads as a real
  medium weight on the device (T013 finding).
  `ReorderWiringTests.allAppSwiftFiles` onto `SourceScan.swiftFiles`
  (the fourth copy, T024 finding).
  T018 also watches the value step's dismissal for a detent flicker
  (the resting step's detent is large; T022's review, round 4).
  `CLAUDE.md`'s false-passing-test paragraph gains a fourth instance
  (post-merge, on `main`): a test asserting an invariant a `precondition`
  already guarantees — correct-looking, green, unfalsifiable (T021's
  review, round 2). And the review-bundle rule: build diffs after
  `git add -N` so new files appear.
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
  *Done 2026-09-05*:
  - **Criteria** 1–23 ticked in `spec.md`, each with the suites and the
    T018 observations that serve it; honest partials named: a real 429
    never seen; the second-device match and history checks; "is
    published" waits on the merge; VoiceOver, Link Conditioner, `mailto:`,
    a physical device and the arrow on a live row are the person's; the
    relaunch check of the notice needs the dev store (`-uiTesting` holds
    the acknowledgement in memory).
  - **`plan.md`** gains "As built" (the renumbering, the spike's
    numbers, the `.automatic` audit, Q21 as shipped, the Sort By surface
    232 × 327, the notice's home, the shared derivations, the suite
    counts, the N1 gap, the previews) and, in Amendment B, "The
    dismissal question, settled by instrumentation".
  - **The sweep list**: 012 plan ~99 and 013 spec ~806 annotated (14
    columns; 91 bytes — both derived by their tests); README's Market
    values bullet rewritten to Amendment B's flow and the Settings
    bullet given Refresh market values and About's three lines; the
    address swap is the two-file edit plan §8 records; the dashboard's
    lifted amount read as a real medium weight (T018); the dismissal
    flicker cannot be caught in stills and the instrumented run showed
    the sheet's content is not re-rendered on dismissal, so no resting
    phase — a real-device look stays the person's; `ReorderWiringTests`
    onto `SourceScan.swiftFiles` (minimum 500 → red at 102 files,
    reverted); PRIVACY's field list completed against
    `MarketFigureRecord`, `MarketMatchSnapshot` and `MarketDeviceState`,
    plus the notice-acknowledgement row; the year-parse extraction
    deferred (N6 below).
  - **The pre-merge sweep** (`skeptical-reviewer`, top tier, 532,178
    tokens, the three bundles cut with `git add -N`): one blocking
    finding, **B1** — every dismissal of the match sheet might re-render
    its content as the picker and run a live search from its `.task`,
    with nothing but view-model tests saying otherwise. Settled by a
    file probe in `searchProducts` on the simulator: 0 after the
    notice's Not now, 1 after Continue, 1 after the value step's Not
    now, 1 after adopt. Not a defect; recorded in plan Amendment B and
    criteria 2 and 9. Non-blocking, dispositioned: **N1** the
    second-device stale figure under a changed match → a known gap in
    plan "As built" for a `fix/` branch; **N2** previews inheriting
    `.automatic` → `cloudKitDatabase: .none` in all eight, compiled;
    **N3** `thePolicyNamesEveryRowOfTheRetentionTable` was the
    over-broad shape (the nouns survive the table's deletion) → the
    rows pinned by their opening phrases, mutation: table removed →
    red; **N4** stale statements → fixed (tokens.md's "two phases" and
    `noticeIsPending`, Decision 34's "third phase", the 012 annotation's
    column names, README's Settings bullet); **N5** the walk that says
    nothing when nothing is due → a product question in the Phase-5
    report; **N6** the year parse in three places and the hour
    predicate in four, plus no boundary test at exactly 3600 s on
    `SettingsViewModel.dueTargets` → recorded for a follow-up; **N7**
    `MarketCopy.figure(medianCents:count:)` deleted (no production
    caller; its test now pins `listed(count:)` alone),
    `privacyPolicyFilename` kept as the spec's named pin, the `?? nil`
    on `item?.year` kept (it flattens `Int??`), the triplicated doc
    comment left.
  - **Post-merge, on `main` via `fix/docs-002-shipped`** (plan §8):
    `specs/ROADMAP.md` — rewrite the 002 entry (it still says "replace
    `currentValueCents`" and names eBay and Facebook), add its status
    row, record the 011 deferral's PDF clause as overridden by P17, add
    the eBay follow-up with Decision 1's two prerequisites, note 002 as
    `003`'s input; `README.md` Status (six specs), tree (`Trove/Market/`,
    `Views/Market/`, `design/elements/`, `scripts/`, `PRIVACY.md`) and
    specs listing; `DECISIONS.md` — the first network dependency and the
    local store, Reverb over a crawler, the terms' four obligations and
    where each lives, the 010 line restated, the constitution-amendment
    reconciliation (Decision 19), the fifth routing bucket (Q20),
    blob-then-Pages (Decision 18), Q21, the live-network-twice rule, the
    model policy's first spec; `CLAUDE.md` — the fourth false-passing
    instance (asserting what a `precondition` already guarantees), the
    review-bundle rule (`git add -N` before the diff), and the sweep's
    lesson (a `.task` inside sheet content is a fetch trigger the
    view-model suite cannot see — instrument it once on the device).
  - **Suites** on the close-out build: unit **1103 tests in 148 suites
    passed** (the fourth run of the day; the first two are T018's pair),
    UI **13 tests, 0 failures** (the third run; T018's pair before it).
    Mutations this task: `ReorderWiringTests` minimum 500 → red;
    `PrivacyPolicyTests` with the retention table removed → red (10
    issues); both reverted.

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

## Tier log (the first spec under the model policy)

The constitution's model policy (amended 2026-09-04) decides which tier
runs each task at dispatch time. This table is the evidence: token
usage from each subagent return — implementer runs and reviewer
invocations alike — any escape-hatch miss (a task the orchestrator had
to redo at the top tier, and why). The third tier is off for this
spec. T001a through T008 predate the policy: they ran at the top tier
in the orchestrating session itself, with no per-task token figure to
record, so the log begins at T009a. Compare the spec's total against a
previous spec of similar size before treating the policy as settled.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| T009a | opus (`sdd-implementer`) | 102,544 | verified first try; one finding (the "75" mutation), recorded in plan Amendment A |
| T009 | opus (`sdd-implementer`) | 141,105 | verified first try; reviewer: fix and re-review |
| T009 review 1 | opus (`skeptical-reviewer`) | 62,672 | fix and re-review — B1, B2, S1–S6 |
| T009 fix pass 2 | opus (`sdd-implementer`) | 92,792 | verified first try; one finding (refresher inputs), recorded in plan §5 |
| T009 review 2 | opus (`skeptical-reviewer`) | 64,507 | fix and re-review — the task line (orchestrator's tasks.md gap) and the stale-date bug |
| T009 fix pass 3 | opus (`sdd-implementer`) | 49,214 | verified first try |
| T009 review 3 | opus (`skeptical-reviewer`) | 23,862 | signed off |
| T012 | opus (`sdd-implementer`) | 174,621 | verified first try; one finding (summaries before the sort), recorded in plan §6 |
| T014 | opus (`sdd-implementer`) | 144,577 | verified first try; two findings (matched vs due counts; the comment stripper), recorded in plan §6 |
| T016a | opus (`sdd-implementer`) | 160,964 | verified first try; reviewer: fix and re-review |
| T016a review 1 | opus (`skeptical-reviewer`) | 75,007 | fix and re-review — B1 (the docs: T016b's), S1–S4 |
| T016a fix pass 2 | opus (`sdd-implementer`) | 71,937 | verified first try; a false-passing pinned year caught and re-pinned |
| T016b | opus (`sdd-implementer`) | 70,898 | verified (count unchanged); two stale 012-spec widths left to the orchestrator |
| T016a review 2 | opus (`skeptical-reviewer`) | 83,464 | signed off; second-look items folded |
| T016a fix pass 3 | opus (`sdd-implementer`) | 59,318 | verified first try |
| T017 | opus (`sdd-implementer`) | 57,759 | verified first try; the policy read by the orchestrator |
| T010 | opus (`sdd-implementer`) | 206,241 | verified first try; renders seen by the orchestrator; one finding (Link ink), recorded in plan §6 |
| T011 | opus (`sdd-implementer`) | 161,355 | verified first try; the notice flow seen on the simulator |
| T013 | opus (`sdd-implementer`) | 105,112 | verified first try; one finding (a tautological existing test), fixed in the follow-up |
| T013 follow-up | opus (`sdd-implementer`) | 45,933 | verified first try; the reconcile test now red under the T013 mutation |
| T015 | opus (`sdd-implementer`) | 88,829 | verified first try; UI target green twice by the implementer, once more by the orchestrator |
| T021 | opus (`sdd-implementer`) | 155,350 | verified first try; reviewer: fix and re-review |
| T021 review 1 | opus (`skeptical-reviewer`) | 60,902 | fix and re-review — the bundle missed two untracked files; S1–S3 |
| T021 fix pass 2 | opus (`sdd-implementer`) | 59,693 | verified first try; corrected the reviewer's 'valuation' example |
| T021 review 2 | opus (`skeptical-reviewer`) | 67,431 | fix and re-review — a plan/code contradiction; an unfalsifiable new test |
| T021 fix pass 3 | opus (`sdd-implementer`) | 45,224 | verified first try; the test deleted |
| T021 review 3 | opus (`skeptical-reviewer`) | 54,554 | fix and re-review — an off-by-one in comments, no boundary tests |
| T021 fix pass 4 | opus (`sdd-implementer`) | 49,188 | verified first try |
| T021 review 4 | opus (`skeptical-reviewer`) | 39,081 | signed off |
| T022 | opus (`sdd-implementer`) | 204,262 | verified first try; reviewer: fix and re-review |
| T022 review 1 | opus (`skeptical-reviewer`) | 90,323 | fix and re-review — the presentation flag; the activity conjunct |
| T022 fix pass 2 | opus (`sdd-implementer`) | 88,588 | verified first try; found the flat landing rule would close a re-opened picker |
| T022 review 2 | opus (`skeptical-reviewer`) | 79,324 | fix and re-review — candidate ≠ fetch identity; the concurrent refresh |
| T022 fix pass 3 | opus (`sdd-implementer`) | 134,127 | verified first try; the token and the generation rule |
| T022 review 3 | opus (`skeptical-reviewer`) | 99,942 | fix and re-review — the guard correct but unguarded |
| T022 fix pass 4 | opus (`sdd-implementer`) | 88,471 | verified first try |
| T022 review 4 | opus (`skeptical-reviewer`) | 65,194 | fix and re-review — a racy precondition in one test |
| T022 fix pass 5 | opus (`sdd-implementer`) | 55,335 | verified first try |
| T022 review 5 | opus (`skeptical-reviewer`) | 35,750 | signed off |
| T023 | opus (`sdd-implementer`) | 165,356 | verified first try; renders seen by the orchestrator |
| T024 | opus (`sdd-implementer`) | 188,119 | verified first try; renders seen by the orchestrator |
| T018 | fable (orchestrator) | — | the device pass driven by hand on the simulator; no dispatch |
| Pre-merge sweep | fable (`skeptical-reviewer`) | 532,178 | 1 blocking → instrumented on the simulator, not a defect; 7 non-blocking dispositioned in T019's note |
| T019 | fable (orchestrator) | — | the close-out by hand; no dispatch |

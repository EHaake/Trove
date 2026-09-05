# 002 — Market Values — Technical Plan

Status: **Approved** (2026-09-03, same day as drafting — Q1–Q20 approved
with it, per the Proposed-at-planning section; **Amendment A — year
narrowing** added the same day during implementation, after T002, against
spec Decision 29; drafted
in-session per the authorship split, in Plan Mode, against the approved
spec and the code as it is on this branch). Two skeptical-review passes
ran on the three design reports before this document was written; their
record is below because it reshaped the local store, replaced one guard
that could not fail, corrected one fact this plan would otherwise have
carried, and surfaced twelve product decisions that were escalated and
decided by the person at this review (spec.md Decisions 17–28). Twenty
planning proposals (Q1–Q20) become decisions on plan approval, the way
P1–P17 did on the spec's.

## Context

Spec 002 (Approved 2026-09-03) adds a **market indicator** from Reverb's public catalog and listings: an owned or wanted item is matched once, by the person, to a Reverb product; a refresh, on demand only, fetches the product's current listings and computes the **median asking price** for listings in the item's condition, with the low–high spread and the count; the figure sits beside the person's own value (which never changes unless they adopt it with one tap), appears as a trend arrow on rows, as a Market sort, and as a coverage-qualified variant of the dashboard total. Every refresh with a median keeps a summary point on the device, unsynced, forever, for `003` to trend. Reverb's terms put an attribution line, a contact address, a privacy policy and a link-back on the app.

This is the app's **first network dependency** and its **first device-local, never-synced store**. Both are new architecture, and both are why this plan has more guards than screens.


## Decisions made by the person at this review (2026-09-03) — recorded in spec.md as Decisions 17–28

17. **The Design pass runs through `/design`, invoked by the person** with a prompt Claude Code writes at the design task; the exports land under `design/elements/002-market-values/` as 010's did, and `tokens.md` is sourced from them.
18. **The privacy policy links to the GitHub blob URL now** (`https://github.com/EHaake/Trove/blob/main/PRIVACY.md`); GitHub Pages later, as one `fix/` commit swapping the URL. Decision 13's "via GitHub Pages" is deferred, not dropped.
19. **`CLAUDE.md` is amended now, in its own commit on the branch, before T001** — the constitution's "amend first" rule wins over `DECISIONS.md`'s post-merge routing for amendments a spec contradicts; `DECISIONS.md` records the reconciliation post-merge.
20. **The device stores the matched product's slug and title** (plus its lowest used price and when taken), unsynced, as catalog data; criterion 18 reads "only the app's summary numbers, the product identifier, and the product's catalog slug and title".
21. **Stale figures (over thirty days) drop out everywhere**: the sort, the dashboard sum, and the section. Criteria 14 and 15 read "current median".
22. **The dashboard's N counts the items in the sum**, and the copy becomes "Market · $18,400 · 12 of 34 items". Copy section and criterion 15 amended.
23. **A withheld refresh adds no history point**; it still updates the section's age and lowest-used figure and counts for the hour budget. Criterion 12 reads "each refresh that yields a median".
24. **P6 is scoped to owned items**: adopt bumps the edited time where the item has one; `WishlistItem` gains no field.
25. **The contact address is supplied by the person before the copy task**; a test fails on any placeholder.
26. **Changing the match to a different product clears the history**; re-picking the same product keeps it. P11 reads "history belongs to the match".
27. **The Settings walk stops on the first failure of any kind**, with "Couldn't reach Reverb. 3 of 12 refreshed." for a non-rate-limit failure. Criterion 10 and the Copy section amended.
28. **Candidates in the picker link back to Reverb**; P9 reads "wherever Reverb's data is shown". The Design pass decides the form.

## Proposed at planning (Q1–Q20) — approved on plan approval unless overturned

- **Q1. Condition buckets** (P2, verified against the observed slugs): `new` → `brand-new`, `mint`, `mint-inventory`, **`b-stock`** (unused dealer stock with cosmetic flaws; its Telecaster median $1,566 sits with mint $1,500 and mint-inventory $1,550, not excellent $1,400); `excellent` → `excellent`; `good` → `very-good`, `good`; `fair` → `fair`; `broken` → `poor`, `non-functioning`. **"Used" for wanted items = every listing whose slug is not new stock** (`brand-new`, `b-stock`) — failure-open, so a slug Reverb adds later never silently shrinks a wanted item's count. For owned items an unknown slug matches no condition.
- **Q2. Page cap**: ten pages of fifty (500 listings, ≤ 11 requests per refresh). When hit, the figure is computed over what was fetched, the count reads what counted, and the record stores `isTruncated`; **no disclosure copy** in this spec — the count is the honest number and the device pass records whether any real product hits the cap.
- **Q3. A product gone from Reverb (404 on refresh)** shows "This product is no longer on Reverb. Change the match to keep refreshing." in the failure line; the last figure and the match stay. Never auto-unmatch.
- **Q4. Duplicate item** inherits the match (the identifier is the person's data); never the history.
- **Q5. "Not now"** leaves the notice unacknowledged — it returns on the next Find on Reverb…; only Continue is forever.
- **Q6. Trend "previous" point**: the most recent point at least seven days older than the latest, with **no maximum age** (P12 literally; a trend against a months-old point is still "the trend since then"). The rejected reading — the immediately preceding point, valid only if it happens to be a week older — would blank the arrow for anyone who refreshes twice in a week. Recorded so `003` can revisit.
- **Q7. Copy the spec doesn't give**: never refreshed here → "Not refreshed on this device."; withheld for a wanted item → "Too few used listings to say. The lowest used asking price on Reverb is $1,100."; withheld with no catalog price → the first sentence alone; unreachable with no figure → "Couldn't reach Reverb."; link label **View on Reverb**; picker: title "Find on Reverb", placeholder "Search Reverb", "Searching Reverb…", candidate reading **"Lowest used asking price $1,100 · 34 listed"** / "No used listings" (the word "asking" stays — P10), empty "No matches for “…” on Reverb" + "Try a shorter name — the brand and model are enough.", "Try again", "Cancel"; Settings progress "3 of 12"; About link "Privacy policy".
- **Q8. Refresh within the hour is a disabled button** with the VoiceOver hint "Refreshed less than an hour ago." — every state with a figure also draws the age line beside it, so it never reads as broken.
- **Q9. The notice is a sheet**, not an alert: an alert's message can't hold a tappable link and every alert button dismisses. One sheet with two phases (notice → picker) so no presentation binding is written mid-flight (the 012/T017 race).
- **Q10. The picker searches on submit only** (plus once on appear, seeded with the item's name — criterion 2's "Continue searches"): as-you-type would send name fragments, which is not "the item's name" (criterion 3, P15). "Change match…" seeds with the item's name too, not the matched title.
- **Q11. Sort rows** sit after the Value / Cost pair on both lists, "Market ↓" before "Market ↑" on both (P10), labels from `MarketCopy`.
- **Q12. Settings**: the Market section between Templates and iCloud; the outcome is an inline status line under the row, not an alert (the single-`.alert(` rule stands; "stops cleanly" is a state, not an interruption).
- **Q13. No stubbed Reverb service under `-uiTesting`**: the flag's justification is "can only lose data"; a stub fabricates data. UI tests cover the offline states only; criteria 2 (Continue), 3, 4 are unit-tested through spies and checked at the device pass, and the plan says so.
- **Q14. Match, change and unmatch bump `Item.updatedAt`** (they are edits); adopt does too (P6).
- **Q15. Adopt writes the figure the section showed**: `MarketAdoption.wholeCurrencyCents(from:)` rounds cents to whole currency with the same half-to-even rule the display formatter uses, and a table test asserts `formattedAsWholeCurrency(adopted) == formattedAsWholeCurrency(median)` for half-cases of both parities — so the person never taps "$1,450" and gets $1,451.
- **Q16. CSV**: column **`Reverb Product ID`**, last on both lists (headers are append-only, so the name is permanent — object now or never); import parses a positive integer, blank → unmatched silently, anything else → unmatched **counted** (012's `Current Value` policy); `items-partial.csv` stays at the legacy 12-column width forever as the backward-compat fixture; `items-full.csv`'s claim weakens to "every field filled; the music rows matched" (cameras have no Reverb product); no `item_region` filter (P3 is currency-only).
- **Q17. Candidate thumbnails go through `AsyncImage`** and the OS's shared URL cache — transport, not app storage; the API session itself is ephemeral (no disk cache, no cookies). One posture, stated once.
- **Q18. No launch-time orphan sweep** of local rows (the 010 lesson: a launch write whose input is data that arrives asynchronously). Rows for items deleted elsewhere are invisible by construction (every reader joins from the item) and cost seven scalars each; local deletion paths and Delete All clear them explicitly.
- **Q19. Design-pass output**: `.dc.html` + PNG under `design/elements/002-market-values/`, `tokens.md` sourced from them with "as implemented" values recorded per UI task (010's pattern). If the pass proposes new copy, that is a spec question — escalate, don't absorb.
- **Q20. `PRIVACY.md` and `scripts/` travel on the branch** (the branch makes them true); `DECISIONS.md` gains the fifth routing bucket post-merge.
- **Q21 (added 2026-09-03 at the tasks review). A corrupt or unopenable local store is recreated, never fatal.** `make` tries the intended pair, then the fallback pair, then — if the local store's file exists — removes `MarketLocal.store` (and its `-wal`/`-shm`) and tries the fallback pair once more; only then throws. The device-local figures and history are the app's own disposable summaries (never the collection), so losing them beats a launch that can never succeed again; the launch runs `.localOnly` for that session and tries CloudKit again next time. Tested through the `build:` seam with an injected `recreateLocalStore` hook: two throwing builds then a success → the hook called once, mode `.localOnly`; the synced store is never touched (mutation: recreate before the fallback pair → red; skip the third attempt → the throw reaches the test). The collection is never deleted by any path in this spec. Two costs, accepted and recorded (added at the Phase 1 review): the failure reported through `storageFallbackReason` is the *first* one, so a local-store fault reads as a CloudKit one; and a collection that is itself corrupt fails all three attempts and loses the local store on the way — the launch was lost regardless, and the local store holds only the app's own summaries.

---

## Skeptical-review record (two passes, 2026-09-03, on the three design reports)

- **Sustained**: the second, local-only `ModelConfiguration` in the same container (now corroborated by an Apple DTS forum answer: works when each configuration carries only its own models and the configurations are named distinctly — the crashes people hit come from the full schema on both, or unnamed pairs); keying local rows by the item's UUID with no relationship; the notice flag as a row in the local store (the `-uiTesting` argument); `@concurrent` on requirement and implementation; the DTO carrying only price/currency/condition (P14 by construction); freshness checked before any call and nothing written before compute (P7/P8 by construction); integer trend arithmetic and its boundary list; the header-tolerance-by-boundary shape over literal legacy arrays; the `items-partial.csv` row-7 argument; the two-phase notice sheet; two plain buttons for the match actions; submit-only search; the offline-only UI tests.
- **Overturned or reshaped**:
  - *A launch-time orphan prune* would delete unbounded, unsynced, unrecoverable history on any launch where the CloudKit mirror hadn't imported yet — the 010 lesson from the other direction. Dropped (Q18).
  - *G5, "walk every persisted value"*, could not fail: `@Model` reflection sees backing storage, and no listing string can reach the store without a three-file change G4 already catches. Replaced by a **byte scan of the saved store file** for the fixture's distinctive strings, plus a DTO-shape assertion.
  - *G7 built a hand-made container*, not the pairing `TroveStore` will build; nothing tested the production two-disk shape. `configurations(for:directory:)` gains a directory seam so the spike builds the real thing into a temp directory, and G3 pins the synced store's filename (`default.store` — renaming it would empty the collection).
  - *The link-back had no persisted source* (the URL is slug-based). Decision 20.
  - *Criteria 12, 14/15, 18 and P6 were being settled in the plan*; escalated → Decisions 20–24.
  - *`removeMatch` saved first and cleared after* — the deletions would never commit. One intent, one `save()` after both mutations. And a `save()` spanning two stores is **not** claimed atomic: the partial outcomes (an orphan row; or history cleared with the id kept) are both benign and named.
  - *Adopt rounded half-up while the display rounds half-to-even* → Q15.
  - *"Stale drops out" / "N of M" / walk-stop / change-match* were recommendations dressed as resolutions → Decisions 21, 22, 27, 26.
  - *The fixture recorder as a `.disabled` test* → a script in `scripts/` (keeps "no networking in tests" absolute; a test writing into the repo via `#filePath` is not the `DocsSampleTests` precedent, which reads).
  - *Unknown slugs excluded silently* could withhold a wanted item's figure with no signal → Q1's failure-open "used".
  - *Client gaps*: validate `_links.next`'s host before following it; build URLs with `URLComponents` (gear names carry `&`, `+`, `#`); require `price.currency == "USD"` as well as `listing_currency` (Reverb converts prices for display); serialize the stub-protocol suite against parallel test execution.
  - *`Link(` file scans* would false-fire on `NavigationLink(` — the non-identifier-boundary regex `MenuPolicyTests` uses; several wiring scans that duplicated `MenuPolicyTests`/`PullToRefreshTests` trimmed; "renders nothing" asserted as `nil` (also what a failed render returns) → measure a host view's width instead.
  - *The Sell Plan's "reserved trend slot"* does not exist — `SellPlanRow` is its own view; Decision 11 settles it.
  - *`WishlistRow`'s arrow before the cost* would reorder its existing accessibility label; after.
  - *`presentationDetents` swapped between phases* → the `selection:` overload, or one `.large`.
- **Corrected facts**: `ModelConfiguration.cloudKitContainerIdentifier` is **nil for `.automatic` as well as `.none`** (checked in a scratch `swift` run during planning: automatic → nil, none → nil, private → the identifier; the unnamed configuration's file is `default.store`, a named one `MarketLocal.store`). So `TroveStoreTests.uiTestsNeverReachICloud` (:51) and `theFallbackDoesNotAskForCloudKitAgain` (:74) **cannot see the mutation they name** (dropping `.none` to inherit `.automatic`). Per CLAUDE.md, that's an audit: T001 adds the source scan that can (every `ModelConfiguration(` in `TroveStore.swift` spells `cloudKitDatabase:`) and corrects both tests' mutation notes. Also: `Int+Currency` pins the *locale* on Foundation's formatter, it does not hand-roll numbers — the hand-written relative-age formatter is justified by whole-string copy tests, not by that precedent.

---

## Layout and files

New production files (all under synchronized groups — no `.pbxproj` edit):

| File | Holds |
|---|---|
| `Trove/Market/MarketService.swift` | `MarketService` protocol, DTOs (`MarketCandidate`, `MarketProduct`, `MarketListing`, `MarketListings`), `MarketError` |
| `Trove/Market/ReverbMarketService.swift` | `ReverbAPI` constants, `ReverbMarketService` (URLSession), wire structs |
| `Trove/Market/MarketLocalModels.swift` | `MarketFigureRecord`, `MarketHistoryPoint`, `MarketMatchSnapshot`, `MarketDeviceState` |
| `Trove/Market/MarketLocalStore.swift` | static helpers over a `ModelContext`; the single writer of the cached trend |
| `Trove/Market/MarketFigure.swift` | `MarketConditionMap`, `MarketFigureComputation`, `MarketReading`, `MarketFigure` |
| `Trove/Market/MarketTrend.swift` | `MarketTrend`, `MarketFreshness`, `MarketAdoption` |
| `Trove/Market/MarketRefresher.swift` | one item's refresh, the hour budget, `targets(in:)` |
| `Trove/Market/MarketIndex.swift` | one-fetch `[UUID: MarketSnapshot]` for lists and the dashboard; `MarketSectionState.resolve` |
| `Trove/Models/MarketCopy.swift` | every string; `contactAddress`, `privacyPolicyURL`, `attribution` |
| `Trove/Models/MarketAge.swift` | the hand relative-age formatter |
| `Trove/ViewModels/MarketMatchViewModel.swift` | the picker's search state |
| `Trove/Views/Market/MarketSection.swift`, `MarketNoticeView.swift`, `MarketMatchView.swift`, `Trove/Views/Shared/TrendArrow.swift` | the surfaces |
| `scripts/record-reverb-fixtures.sh` | the by-hand fixture recorder (curl + python trim) |
| `TroveTests/Fixtures/Reverb/*.json` | recorded fixtures, read by `#filePath` |
| `PRIVACY.md` | the policy |

Changed: `TroveSchema`, `TroveStore`, `TroveApp` (nothing but the schema/config seam), `Item`, `WishlistItem`, `ExportSchema`, `ImportSchema`, `ItemListViewModel`, `WishlistViewModel`, `DashboardViewModel`, `SettingsViewModel`, `ItemDetailViewModel`, `WishlistDetailViewModel`, `ItemDetailView`, `WishlistDetailView`, `ItemRow`, `WishlistView` (row), `DashboardView`, `SettingsView`, `ContentView` + nine previews (combined schema), `CLAUDE.md`, docs.

---

## 1. The local store — a second configuration in the one container

```swift
enum TroveSchema {
    static let models: [any PersistentModel.Type] = [Item.self, WishlistItem.self, Photo.self]   // synced; unchanged
    static let localModels: [any PersistentModel.Type] = [MarketFigureRecord.self, MarketHistoryPoint.self,
                                                          MarketMatchSnapshot.self, MarketDeviceState.self]
    static var schema: Schema { Schema(models) }                    // CloudKitSchemaTests validates exactly this
    static var localSchema: Schema { Schema(localModels) }
    static var combinedSchema: Schema { Schema(models + localModels) } // the container's
}
```

`TroveStore.configurations(for mode: StorageMode, directory: URL? = nil) -> [ModelConfiguration]`: `.cloudKit` → `[synced(.private(id)), local]`; `.localOnly` → `[synced(.none), local]`; `.ephemeral` → **the same pair, in memory** (corrected 2026-09-03 at T006a: the plan first proposed one in-memory configuration over the union, fearing two in-memory stores would share `/dev/null`; that fear was unfounded, and the single configuration is what fails — once a multi-configuration container has assigned a model type to a store in a process, SwiftData keeps routing that type by that assignment, and a later single-configuration container over the union crashes on inserting it: "Can't assign an object to a store that does not contain the object's entity". Reproduced standalone on macOS with two throwaway models; `makeInMemoryContainer()` builds the pair through `TroveStore` for the same reason). The synced configuration stays **unnamed** — its file is `Application Support/default.store`, the shipped collection; naming it moves the file. The local one is `ModelConfiguration("MarketLocal", schema: localSchema, cloudKitDatabase: .none)` → `MarketLocal.store`. `cloudKitDatabase` spelled out on every configuration. `make(isUITesting:build:)`'s `build:` seam takes `[ModelConfiguration]` and builds `ModelContainer(for: TroveSchema.combinedSchema, configurations:)`. A failing *local* store is not the CloudKit case and the existing fallback would retry the same configuration and end in `TroveApp`'s `fatalError` — the tasks review caught this; **Q21** below is the recovery.

Models (defaults everywhere for lightweight migration; `@Attribute(.unique)` is legal here — no CloudKit — and makes single-row-ness structural):

```swift
@Model final class MarketFigureRecord {           // the last figure for one matched item on THIS device
    @Attribute(.unique) var subjectID: UUID = UUID()
    var subjectKindRawValue: String = MarketSubjectKind.owned.rawValue   // owned | wanted
    var productID: Int = 0
    var fetchedAt: Date = Date.now
    var count: Int = 0                             // listings that counted (currency + condition)
    var medianCents: Int?                          // nil = withheld (count < 3)
    var lowCents: Int?; var highCents: Int?
    var usedLowCents: Int?                         // the catalog's lowest used asking price — the withheld fallback
    var isTruncated: Bool = false
    var trendRawValue: String?                     // denormalised from history by MarketLocalStore.record — its single writer
}
@Model final class MarketHistoryPoint { var subjectID: UUID = UUID(); var fetchedAt: Date = Date.now; var medianCents: Int = 0; var lowCents: Int = 0; var highCents: Int = 0; var count: Int = 0 }   // append-only; only refreshes with a median (Decision 23)
@Model final class MarketMatchSnapshot {          // Decision 20: catalog data for the link-back and the title
    @Attribute(.unique) var subjectID: UUID = UUID()
    var productID: Int = 0; var slug: String = ""; var title: String = ""; var usedLowCents: Int?; var takenAt: Date = Date.now
}
@Model final class MarketDeviceState { @Attribute(.unique) var key: String = "device"; var noticeAcknowledgedAt: Date? }
```

The web URL is composed, never stored: `ReverbAPI.productURL(slug:)` = `https://reverb.com/p/<slug>` (one source of truth; matches `_links.web.href`). `MarketLocalStore` (MainActor, static, over the caller's context; callers save): `figure(for:)`, `snapshot(for:)`, `history(for:)`, `index()` (one fetch → `[UUID: MarketSnapshotValue]`), `recordMatch(candidate, for:)`, `record(reading, product, for:)` (upsert figure, append a point iff median, recompute + store trend, refresh the snapshot), `clear(subjectID:)` (figure, points, snapshot — no save), `clearAll()`, `hasAcknowledgedNotice()` (a swallowed fetch error reads as *not* acknowledged — the safe direction), `acknowledgeNotice(now:)`.

**Who clears**: unmatch and change-match (the detail VM, one `save()` with the item write); every local deletion path (`ItemDetailViewModel.delete`, `WishlistDetailViewModel.delete`, both lists' `delete(id:)`, `SettingsViewModel.confirmDeleteAll`) calls `clear` before its existing save; each deletion suite gains a second-context assertion. No launch sweep (Q18). **Corrected 2026-09-04 (spec Decision 30):** T006c had `confirmDeleteAll` call `clearAll()` — every local table and the notice flag, whichever list was emptied. It now calls `clear(subjectID:)` per deleted item, as this paragraph always said, and `MarketDeviceState` is untouched; `clearAll()` had no other caller and was removed with its store test. The Settings test asserts both the deleted list's rows gone and the other list's rows plus the flag intact.

**The 010 contrast, stated**: 010's flag gated a write to synced data and raced sync. Nothing here writes synced data from a per-device fact: the notice flag decides whether a sheet shows; the local rows are read only by joining from the item. That is the line, and every local write in this spec is on the right side of it.

---

## 2. The synced match

`var reverbProductID: Int?` on `Item` and `WishlistItem` (after `sortOrder`), a trailing `reverbProductID: Int? = nil` init parameter on both; `Int` because Reverb's id is one and the product endpoint takes one. CloudKit-additive; `CloudKitSchemaTests` covers it (red run: declare it non-optional without a default). `ItemExportRecord`/`WishlistExportRecord` gain `reverbProductID: Int?` **with the model field** (T003), so the six test files that construct records churn once. `WishlistItem` gains nothing else (Decision 24).

---

## 3. The service and the client

```swift
nonisolated protocol MarketService: Sendable {
    @concurrent func searchProducts(named query: String) async throws -> [MarketCandidate]   // sends the name and nothing else
    @concurrent func product(id: Int) async throws -> MarketProduct
    @concurrent func listings(for product: MarketProduct) async throws -> MarketListings         // all pages up to the cap
}
nonisolated struct MarketCandidate: Sendable, Equatable, Identifiable { let id: Int; let slug: String; let title: String; let brand: String?; let imageURL: URL?; let usedLowCents: Int?; let usedTotal: Int }
nonisolated struct MarketProduct:   Sendable, Equatable { let id: Int; let slug: String; let title: String; let usedLowCents: Int?; let usedTotal: Int; let listingsURL: URL }
nonisolated struct MarketListing:   Sendable, Equatable { let priceCents: Int; let currency: String; let conditionSlug: String }   // the whole of what the app learns about a listing — P14 by construction
nonisolated struct MarketListings:  Sendable, Equatable { let listings: [MarketListing]; let reportedTotal: Int; let isTruncated: Bool }
nonisolated enum MarketError: Error, Equatable, Sendable { case rateLimited, productNotFound, unreachable, serverError(status: Int), malformedResponse }
```

`ReverbMarketService(session:userAgent:pageCap:requestProbe:)` with `static let sharedSession` (`.ephemeral` configuration: no disk cache, no cookies; `timeoutIntervalForRequest = 15`, `ForResource = 60`, `waitsForConnectivity = false` so offline fails fast into `.unreachable`). `ReverbAPI`: `baseURL`, `accept`, `acceptVersion`, `perPage = 50`, `pageCap = 10`, `userAgent(version:)` = `"Trove/<version> (iOS; <contact address>)"` — the address read from `MarketCopy.contactAddress`, its single source, so Decision 25's placeholder guard covers every copy — `productURL(slug:)`. Requests via `URLComponents.queryItems` (never interpolation); headers per request so the stub can assert them; no `Authorization` ever (a test pins its absence). Listings: start from `product.listingsURL` with `per_page=50`, follow `_links.next.href` **only if its host is `api.reverb.com`**, stop at the cap. Decoding through private wire structs with explicit `CodingKeys`; per-listing lossy decoding (one malformed listing dropped, not the page). Mapping: `URLError` → `.unreachable`; 429 anywhere → `.rateLimited`; 404 on the product → `.productNotFound`; other non-2xx → `.serverError`; undecodable → `.malformedResponse`. No `Retry-After` handling (the copy says "in a while"). Currency counted only when `listing_currency == "USD"` **and** `price.currency == "USD"` — the decoder writes a two-currency marker (`GBP≠USD`; `?≠USD` when `listing_currency` is missing) that never equals a currency code (as built, T004; Phase 1 review S1). Also as built: `searchCount = 15` (P22); `MarketRefresher.Outcome` gained `.superseded` for a match that changed under the awaits, and a failed save rolls the context back (T006b).

**Tests** (`ReverbMarketServiceTests`, `.serialized`, a `StubURLProtocol` keyed by URL over an ephemeral configuration, no sockets): headers present, `Authorization` absent; a punctuation-heavy name (`"'65 Twin Reverb + case & cover"`) round-trips through `query=` exactly; the search request carries `query` and `per_page` and nothing else; product 404 → `.productNotFound`; 429 → `.rateLimited`; 500 → `.serverError(500)`; `URLError(.notConnectedToInternet)` → `.unreachable`; seven fixture pages followed in order with `per_page=50`, `isTruncated == false`; `pageCap: 2` → two requests, `isTruncated == true`; a `next` on another host is not followed (mutation: drop the host check → red); a listing without `condition` is dropped, the page decodes; a fixture whose `price.currency` disagrees with `listing_currency` is excluded at computation (criterion 7); `requestProbe` records off-main for all three entry points called through the existential from the main actor (the `ExportConcurrencyTests` shape). DTO shape: `Mirror(reflecting: MarketListing(...)).children.count == 3`, and a decoded page from the title-bearing fixture retains no string but currencies and slugs.

**Fixtures** (the oracle numbers live in the fixtures, the README's generated block and the computation tests' literals — three places by hand; a re-record is deliberate, and the README's hand-written sections sit outside the recorder's markers): `scripts/record-reverb-fixtures.sh` (curl + a python trim) writes `TroveTests/Fixtures/Reverb/`: `csps-search-telecaster.json` (three candidates, photos cut to `small_crop`), `csp-126161.json`, `csp-404.json`, `listings-126161-p1…p7.json` (every real listing trimmed to `id`, `title`, `price`, `listing_currency`, `condition` — shop and seller fields removed; titles kept as the tripwire for the byte scan), and hand-built `rate-limited-429.json`, `listings-mixed.json` (non-USD, disagreeing currencies, unknown slug, missing price). Read by `#filePath` as `DocsSampleTests` does. Re-recording is a deliberate act; the oracle numbers are pinned from the live computation (Grounding).

---

## 4. The computation, the trend, adoption

`MarketSubject = .owned(condition:) | .wanted`. `MarketConditionMap.reverbSlugs(for:)` per Q1; `newStockSlugs = {brand-new, b-stock}`; `counts(listing, for:)`: `.owned` → slug ∈ the condition's set; `.wanted` → slug ∉ newStock. `MarketFigureComputation.compute(listings:subject:product:fetchedAt:) -> MarketReading` (`.figure(MarketFigure)` | `.withheld(count:usedLowCents:fetchedAt:)`): currency first, then condition; sort; median = middle, or `(a + b + 1) / 2` for even counts; low/high; withheld below three. A test asserts `knownSlugs ⊇ every slug in the recorded fixtures` so drift shows as red.

Oracle tests over the seven decoded pages, **numbers from the fixtures README** (recorded 2026-09-03; the September 2 probe's figures below were dollars, and its `.wanted` arithmetic — 340 − 184 − 5 = 151 — ignored the currency filter): `.owned(.excellent)` → count 34, median 139_999, low 115_200, high 325_000; `.owned(.good)` → 17, median 139_999; `.owned(.new)` → 208 (182 + 7 + 14 + 5); `.wanted` → **72** USD listings, median 149_999, low 100_000, high 325_000, against the product's `used_total` of 108 (all currencies) and `used_low_price` 100_000; `.owned(.fair)` and `.owned(.broken)` → withheld at zero (a test comparing our used count to `used_total` records the gap either way); synthetic: two listings → withheld with the product's `usedLowCents`; three → a figure; even-count median; a EUR listing and a converted-price listing excluded and the count says so; an unknown slug excluded for `.owned(.excellent)` and **included** for `.wanted`; `Condition.allCases` map to non-empty, pairwise-disjoint sets. Mutations: mean for median; drop the currency filter; put `good` in two buckets; make `.wanted` failure-closed → each red.

`MarketTrend: String { up, down, flat }` + `Optional` (nil = no trend yet — one spelling). `compute(history:)`: latest = last by `fetchedAt`; previous = the **most recent** point ≥ 7 days older (Q6); nil if none or previous median ≤ 0; `20 * (latest − previous) >= previous` → `.up`; the mirror → `.down`; else `.flat` (drawn as nothing). Boundary tests: 7 d exactly → a trend; 7 d − 1 s → nil; 1000→1050 up, →1049 flat, →950 down, →951 flat; points 20 d / 8 d / 1 d old compare against the 8 d point (mutation: pick the oldest → red); one point → nil.

`MarketFreshness.isCurrent(fetchedAt:now:)` = under thirty days, display-time only; history is never trimmed (mutation: prune old points → red). **One predicate** `MarketFreshness.currentMedianCents(of record, now:)` (nil when withheld or stale) is what the section, the sort and the dashboard all read — Decision 21 by construction.

`MarketAdoption.wholeCurrencyCents(from:)` per Q15, with the formatter-equality table.

---

## 5. The refresher and the index

`MarketRefreshTarget { subjectID, kind, productID, subject }`; `MarketRefresher(modelContext:service:now:)`, MainActor. `refresh(_:) async -> Outcome` (`.refreshed(MarketReading)` | `.stillFresh(fetchedAt:)` | `.failed(MarketError)` | `.saveFailed(String)`): (1) the stored figure within 3600 s → `.stillFresh`, **no call**; (2) `product(id:)`; (3) `listings(for:)`; (4) re-fetch the subject — unmatched or re-matched during the awaits → drop the result silently; **(as built, noted at T009's review, 2026-09-04: the re-read is what the computation uses — `current.subject` and `current.year` — so the caller's `MarketRefreshTarget.subject` and `.year` never reach it; only `key` and `productID` do. A view model that built the wrong subject would not be caught by any test. Whether the two fields leave the input type is a small design call deferred to the close-out; until then the detail VMs build them faithfully and the owned/wanted split rests on `MarketSubjectKey.kind`, which the store and both detail suites cover.)** (5) compute; (6) `MarketLocalStore.record` (figure upsert; a point iff median; trend; snapshot refresh); (7) `save()`. Nothing is written before (6), so P8 holds by construction; a foreign error maps to `.failed(.malformedResponse)`. `static func targets(in:) -> [MarketRefreshTarget]` (matched items in custom order, then matched wishlist items) — the **one** definition of "matched" (Settings' count derives from it).

`MarketIndex.load(from:)` → `[UUID: MarketSnapshotValue]` (median/low/high/count/fetchedAt/trend/isTruncated/usedLow, one fetch of the figure records, never the history). `ItemListViewModel.load()`, `WishlistViewModel.load()`, `DashboardViewModel.load()` each add one line and read through `MarketFreshness.currentMedianCents`.

Spy-driven tests: 59 min old → `.stillFresh`, spy uncalled; 60 min → fetches; success visible on a second context (figure, point, trend, snapshot); `.unreachable` leaves the old record byte-for-byte; a withheld reading writes the figure and **no point** (mutation: append anyway → red); the trend on the record equals `MarketTrend.compute(history)` on a second context; unmatch during a gated refresh leaves no record.

**Spies** in `TestSupport`: `MarketServiceSpy` (scripted `Result`s per method behind a `Mutex`; an exhausted script **throws**, so an unexpected extra call fails fast) and `GatedMarketServiceSpy` (first `listings` call gates — the T019/S1 rule).

---

## 6. Screens

### The detail view models (both, mirrored; the derivation written once)

Injection: `marketService: (any MarketService)? = nil` → `ReverbMarketService()` (shared session), `now: @escaping () -> Date = Date.init`. State: `marketState: MarketSectionState` (`.unmatched` | `.matched(MarketMatchDisplay { productID, title?, webURL?, reading })` with `reading` = `.none` | `.current(figure)` | `.withheld(figure)` | `.stale(fetchedAt)` — stale checked before withheld), `marketActivity: .refreshing?`, `marketNotice: .unreachable(lastFetchedAt:) | .rateLimited | .productGone?`, `adoptFailureMessage`, `isFindingMatch`, `noticeIsPending`, `canRefresh` (matched, idle, no figure under an hour old), `canAdopt` (`.current` and idle). `load()` ends with `loadMarket()` — never a fetch (criterion 9).

Intents: `findMatch()` (also Change match…; `noticeIsPending = !hasAcknowledgedNotice`; opens the sheet), `continueFromNotice()` (acknowledge + save; the picker then runs its seeded search), `declineNotice()` (closes; flag untouched — Q5), `setMatch(candidate)` (a different product → `clear` first (Decision 26); write the id, `updatedAt`, `recordMatch` snapshot; **one save**), `refresh() async` (guard `canRefresh`; activity; await the refresher; map outcomes to `marketNotice`; `loadMarket()`), `adopt()` (Q15; write the value, `updatedAt` on owned; one save; no refresh, no history write), `removeMatch()` (id nil, `updatedAt`, `clear`, **one save**; no confirmation — a single tap). The two-store save is not claimed atomic: the partial outcomes are named in the code comment. **As built at T009 (2026-09-04, orchestrator's transcription calls, reviewer-flagged):** every `updatedAt` write in this paragraph is the owned mirror's — `WishlistItem` carries no `updatedAt` (Decision 24; Q14 names `Item.updatedAt`), so the wanted mirror writes none in `setMatch`, `adopt` or `removeMatch`, and says so in a comment on each. `setMatch` and `removeMatch` also clear `marketNotice`: an unreachable or product-gone line describes a match that no longer exists. A refused save in `setMatch`, `removeMatch` or `continueFromNotice` rolls back the context — `rollback()` discards every pending change on the shared context, not only the intent's, the same recovery `Delete All` uses — and re-derives the state with **no message**: the plan's state set names `adoptFailureMessage` and nothing else, the spec's Copy gives no string for a failed match change, and inventing one is a spec question. A failed Remove match therefore looks like a no-op; carried to the Phase 3 report for the person. The unreachable notice carries a date **only when the reading is `.current`** — the copy says "The figure below is from {age}", and only a current reading shows the figure; withheld, stale and never-refreshed readings get the no-figure line (Q7), whatever `fetchedAt` the row holds (reviewer-flagged at T009 round 2).

Tests (mirrored): the resolve table (8 rows, mutations: drop `isCurrent` → stale row red; swap the order → stale-and-withheld red); `loadNeverFetches`; `refreshWithinTheHourIsSkipped`; mid-flight state and reentry through the gated spy; `unreachableKeepsTheFigureAndSaysWhy`; `productGoneKeepsTheMatch`; adopt on a second context with the formatter-equality, `updatedAt` advanced (owned), history untouched, refresher uncalled; `adoptRefusesWithheldAndStale`; `removeMatchClearsTheItemAndTheStoreInOneSave` (second context; `context.hasChanges == false`); `setMatchToADifferentProductClearsHistoryButTheSameProductDoesNot`; the notice sequence (first find → pending; decline → closed, flag false, spy uncalled; continue → flag true; a new VM over the same container → not pending).

### `MarketSection` (both detail screens; the visual from the Design pass)

| State | Content, top to bottom |
|---|---|
| unmatched | **Market**; **Find on Reverb…** — nothing else (criterion 1) |
| matched, none | **Market**; **On Reverb · {title}**; "Not refreshed on this device."; **View on Reverb**; **Refresh** · **Change match…** · **Remove match** |
| matched, current | title; source; figure as three elements `$1,450` · `12 listed` (the dot `accessibilityHidden`); `$1,100–$2,000`; `as of 2 hours ago`; the link; **Refresh** (disabled within the hour, spinner while refreshing) · **Use as my value** / **Use as estimated cost**; **Change match…** · **Remove match** |
| matched, withheld | title; source; the withheld sentence(s); age; link; Refresh; the match actions — no adopt |
| matched, stale | title; source; "A refresh is due." + `as of 34 days ago`; link; Refresh; the match actions — no figure, no adopt |
| any + notice | one rust line above the actions: unreachable / rate-limited / product gone; the reading beneath unchanged (criterion 11) |

Match actions are two plain buttons (rust for Remove match, brass otherwise) — not a menu, so not a `DropdownSurface`; `MenuPolicyTests` is untouched. The link is SwiftUI `Link` (`.isLink` trait) labelled "View on Reverb" with the hint "Opens reverb.com in your browser." (criterion 20); its ink is render-checked against `accentBrass` (whether `.buttonStyle(.plain)` styles a `Link` is verified, not assumed). The section root is `.accessibilityElement(children: .contain)` with explicit labels per part ("Median asking price $1,450", "from 12 listings", "Asking prices from $1,100 to $2,000", "As of 2 hours ago"). Placement: `ItemDetailView` after `details`, before Notes; `WishlistDetailView` where `marketPricePlaceholder` was (which goes, with its `tokens.md` ghost row). `MarketSection` takes one `MarketSectionActions` value (find/refresh/adopt/change/remove closures) so wiring is compiler-checked, not text-scanned.

### The notice and the picker

One `.sheet(isPresented: $viewModel.isFindingMatch, onDismiss: viewModel.load)` whose content branches on `noticeIsPending`: `MarketNoticeView` (the three sentences; `Link("See the privacy policy")`; **Continue** filled brass / **Not now** outlined; swipe-down = Not now) then `MarketMatchView`. Detents `[.medium, .large]` with `selection:` driven by the phase (or one `.large` if the switch stutters on the device pass).

`MarketMatchViewModel(seed:service:)`: `query`, `phase: .idle | .searching | .results([MarketCandidate]) | .empty(query) | .failed(.rateLimited | .unreachable)`, `search() async` (trimmed; blank → `.idle`, no call; reentry-guarded). `MarketMatchView`: `NavigationStack`, Cancel, `SearchField` with `.onSubmit`, the seeded search in `.task`, a status line (the `PhotoPickerField` pattern), `EmptyStateView` for `.empty`, candidate cards (`AsyncImage` in a fixed square with `RowThumbnail`'s placeholder, `accessibilityHidden`; title; brand; "Lowest used asking price $1,100 · 34 listed"; a **View on Reverb** link per card — Decision 28; the card itself picks). Pick → `setMatch` → the sheet closes → `load()`. Tests: seed is the item's name; `spy.queries == ["Fender Telecaster"]` (mutation: append the category → red); blank never calls; phase mapping (mutation: map `.rateLimited` to `.unreachable` → red); a second search while one runs is ignored.

### Rows and sort

`TrendArrow(trend: MarketTrend?)`: `.up` → `arrowtriangle.up.fill` 9 pt `accentMossText`, label "trending up"; `.down` → the mirror in `accentRustText`, "trending down"; `.flat`/nil → `EmptyView`. `ItemRow` gains `trend`, the arrow last in **both** branches of `valueLine` (also beside "Not yet valued" — the trend describes the market, not the person's value); `WishlistRow` wraps its cost in an `HStack` with the arrow **after** it (its explicit label keeps reading first). Both rows stay `.combine`d; the arrow's label joins the string. `TrendArrowRenderTests`: `.up`/`.down` ink within ΔE of the `*Text` tokens (mutation: the fill token → red); `.flat` measured positively — `HStack { Text("X"); TrendArrow(.flat) }` is exactly as wide as `Text("X")`.

List VMs: `marketSummaries: [UUID: MarketSummary { medianCents: Int?, trend }]` rebuilt in `load()` over the fetched items via `MarketFreshness.currentMedianCents`; `trend(for:)`. **Found at T012 (2026-09-04):** `marketSummaries` must be assigned right after the fetch and *before* the sort — assigned after, the comparator sees an empty dictionary, every pair ties, and the Market sort silently degrades to manual order; the sort tests caught it. `DashboardViewModel.apply` (T013) reads figures the same way and must order them the same way. A failed local-store read in `load()` reads as nothing stored (`try?`), matching `resolve(subjectID:…)`: a market-store problem must never empty the list. `SortOrder` — items: `custom, purchaseDate, currentValue, currentValueAscending, marketFigure, marketFigureAscending, desireToKeep`; wishlist: `custom, cost, costDescending, marketFigure, marketFigureAscending, desire, alphabetical`; labels `MarketCopy.sortDescending/Ascending`; `attributeOrder` copies the nil-last block verbatim with the summary's median. Tests: descending/ascending with matched, withheld, stale, unmatched (the last three in custom order); the manual-order tie trick (mutation: drop the `guard left != right` → red); `unmatchedItemsShowNoTrend`; the sort labels read `MarketCopy` (a scan over both VMs). `DropdownPlacementTests`: the surface is **measured** at seven rows through `renderBitmap`, and the two hand-written `243`-derived literals change with `size`.

### Dashboard

`apply(_:)` adds `marketTotalCents` and `marketFigureCount` over scoped owned items with a current median; `hasMarketFigures`; `marketLine` = "Market · $18,400 · 12 of 34 items" (Decision 22); the `load()` catch resets them with the others. Rendered inside `headline` after the if/else, gated on `hasMarketFigures` (no "$0 · 0 of 34"); form from the Design pass (P5), the qualifier inseparable by construction. Tests: the sum over current medians only (withheld, stale, unmatched, out-of-scope excluded); the whole-string line; `marketFiguresLeaveEveryOtherFigureAlone` (mutation: make the total read medians → red, and `theThreeHeadlineFiguresAlwaysReconcile` goes red too); the wiring scan pins `if viewModel.hasMarketFigures` around `viewModel.marketLine` in `headline`'s body.

### Settings and About

`Activity.refreshMarket`; `matchedCount = MarketRefresher.targets(in:).count` (one definition); `canRefreshMarketValues`; `marketRefreshProgress: (done, total)?`; `marketRefreshStatus: String?`. `refreshMarketValues() async`: targets → the due ones (not refreshed within the hour) → sequential `refresher.refresh`; progress after each (every `await` is a real suspension, so the row re-renders — the T056 lesson); `.rateLimited` → status = the rate-limit copy, return; any other failure → "Couldn't reach Reverb. 3 of 12 refreshed.", return (Decision 27); `defer { activity = nil; progress = nil; load() }`. `SettingsActionRow` gains `detail: String?` ("3 of 12" in mono meta before the spinner); a status line under the row in the delete footer's style (rust on failure). The Market section sits between Templates and iCloud. About gains the attribution (secondary/textQuiet, verbatim), `Link(contactAddress, mailto:)`, `Link("Privacy policy", blobURL)`. `SettingsWiringTests` constants move together with their mutations: rows 6 → 7, sections array + "Market" title, `accessibilityHint:` stays 2 (the new row passes none), `Link(` counted with the non-identifier-boundary regex; `SettingsView.swift` carries no literal containing "reverb"/"mailto"/"http". Tests: the walk over both kinds in custom order skipping unmatched and within-the-hour ones; progress observable mid-flight through the gated spy, reentry blocked; stop at the rate limit with earlier figures kept (mutation: keep walking → red); stop on unreachable with the copy; `matchedCount` counts both kinds via `targets`.

### Copy and vocabulary

`MarketCopy` (`nonisolated enum`, `Trove/Models/`): every string in the spec's Copy section as amended, Q7's additions, the notice, the sort labels, the dashboard line, the picker, Settings, About (`attribution` verbatim; `contactAddress` — a placeholder until Decision 25 is honoured; `privacyPolicyURL` = the blob URL; `privacyPolicyFilename = "PRIVACY.md"`), and the accessibility strings. `figure(medianCents:count:)` composes from `median`/`separator`/`listed`. `MarketCopyTests` pins every string whole (the `DeleteAllCopyTests` model), the notice reassembly, formatters at 1/2 listings, the en dash by code point, withheld with/without a price, and that `contactAddress` has one `@`, no whitespace, no `TODO`/`example.com`.

`MarketVocabularyTests` (P10): over string literals in `MarketCopy.swift`, `Trove/Views/Market/*`, `TrendArrow.swift` — strip the allowlist (`asking price(s)`, `Use as my value`, `Refresh market values`, `Market values`) then reject `\b(value|values|valued|valuation|worth|price|prices|priced|sold)\b`; plus the structural rule **no string literal containing a space in the Market view files** (identifiers and symbol names have none; copy always does — so every word reaches the scan through `MarketCopy`; `Text(verbatim:)` copy is forbidden there on purpose). Mutations: "$1,450 value" → red; "lowest used price" → red; an inline `Text("Find on Reverb…")` → red.

`MarketAge.description(of:at:)`: "just now" (< 60 s, or a future date), minutes, hours, days — whole strings pinned in a table; `Date.RelativeFormatStyle` rejected because whole-string tests would pin ICU's wording, and it has no "just now".

### UI tests (offline, `-uiTesting`, run twice back to back)

`testAnUnmatchedItemOffersFindOnReverbAndNothingElse` (owned; and on a wanted item that "Not tracked yet" is gone), `testTheFirstFindOnReverbShowsTheNoticeAndNotNowClosesIt` (the network claim is the unit test's), `testTheSortMenuOffersMarketRows` (both lists), `testSettingsCarriesTheMarketRowAndAttribution` (row disabled with nothing matched; "not endorsed" present; "Privacy policy" link). What Q13 costs, stated: no UI test ever taps Continue, matches an item, or writes a local row, so the notice flag's persistence and every figure-bearing state rest on the unit suites and the device pass — the twice-run proves re-runnability, nothing more. Identifiers: `market.find`, `market.refresh`, `market.adopt`, `market.changeMatch`, `market.removeMatch`, `market.link`, `market.notice.continue`, `market.notice.notNow`, `market.notice.privacy`, `market.search`, `settings.refreshMarket`, `about.contact`, `about.privacy`.

---

## 7. The contract — CSV, import, PDF

- `ExportSchema.itemHeaders` += `"Reverb Product ID"` (13); `wishlistHeaders` += the same (8); `itemSchemaBoundaries = [12]`, `wishlistSchemaBoundaries = [7]` — "every column count at which a shipped layout ended, oldest first". `row(from:)` appends `record.reverbProductID.map(String.init) ?? ""`.
- `ImportSchema.requireHeader` accepts the pinned headers or `prefix(n)` for any boundary `n`, **returns the matched width**; `wrongList` if the cells equal the other list's headers at any of its widths; else `mismatch`. The previews use the returned width for the extra-columns guard and still pad to `headers.count` — so a legacy 12-column file imports with every match empty, and its 13-cell row is still "more columns than the template" (the `items-partial.csv` row 7 case). `reverbProductID(from:)`: ASCII digits only, overflow-checked, `> 0`; blank → nil silent; else nil counted. Commit paths set the field. A literal test pins `Array(itemHeaders.prefix(12))` against the twelve legacy names typed out — the historical fact the boundary rule assumes.
- `PDFEntry`'s comment gains the carve-out ("less the Reverb product identifier — a key the CSV carries so a re-import restores the match, not a field the person reads"); `theEntryNeverCarriesTheReverbIdentifier` builds entries from records with an id and asserts no label or value contains "Reverb" or the digits (mutation: add a `PDFField` → red).
- Tests rewritten by construction: `headerListsMatchThePinnedSchema`; the row-carries-every-column pair (two different ids); `nilItemFieldsBecomeEmptyCellsNotZeroes`; `missingExtraRenamedAndReorderedColumnsAllMismatch` re-scoped (`missing` = an interior column, plus `prefix(11)`); new `theLegacyLayoutStillPasses` (both lists, width 12/7 returned), `aLegacyFilesOverlongRowIsStillExtraColumns`, `theOtherListsLegacyHeadersAreAlsoWrongList`, `reverbProductIDBlankIsSilentAndGarbageCounts` (`""`, `"abc"`, `"-1"`, `"0"`, `"12.5"`); the `cells()`/`wishlistCells()` fixtures gain the key; `aTroveExportRoundTripsLosslessly` gives one record an id and asserts it back; the hand-row test becomes the 13-cell row. Mutations: remove the tolerance → the legacy sample red; widen to any prefix → the `prefix(11)` case red; read `headers.count` for the width guard → `DocsSampleTests.itemsPartial…` red.
- Samples: regenerate `items-full.csv` (real ids on the four music rows, blank elsewhere), `items-resaved.csv`, `wishlist.csv` (one matched), the three `bad-*` files, at 13/8 columns; **`items-partial.csv` stays at 12 columns forever**, its test gaining "every match nil" and "the header has 12 cells". `docs/samples/README.md` and `docs/csv-reference.md` (counts 13/8, the two new rows, the "exactly these names — with one kept exception" sentence, "What fails the whole file", a "Reverb Product ID is a positive whole number" line, "Export carries an item's Reverb match, never the fetched figures"). `specs/011-data-export/plan.md`'s schema section gets the boundaries rule as a dated note; `specs/012-data-import/spec.md` superseded-in-part notes and the "68 bytes" citation.

---

## 8. `PRIVACY.md`, `CLAUDE.md`, docs

- **`PRIVACY.md`** (repo root, on the branch — Q20): what Trove stores and where (the spec's retention table plus the person's own data on device and in their private iCloud database); what leaves the device — **quoting `MarketCopy.noticeBody` verbatim**, then the refresh sentence; Reverb; iCloud; no accounts/analytics/SDKs; contact; changes. `PrivacyPolicyTests`: the file named by `MarketCopy.privacyPolicyFilename` exists at the repo root (resolved by `#filePath`), contains the notice body verbatim, the contact address, the four retention rows' nouns, and no placeholder; the blob URL's last path component equals the filename. Criterion 17's "is published" half has **no automated coverage** — a device-pass line item.
- **`CLAUDE.md`** (Decision 19, own commit, before T001): the "What this project is" sentence → "…pulling live/estimated resale values from marketplaces shipped in `002` as a Reverb asking-price indicator beside the person's value, never a replacement for it; eBay is its own follow-up"; an Architecture bullet: "**Networking** (from `002`): every remote service sits behind a `nonisolated protocol …: Sendable` with `@concurrent` requirements, constructor-injected as `(any X)? = nil` → the live implementation; decoding and computation are tested against fixtures recorded from real responses by a script under `scripts/`, trimmed to the fields the app reads, committed under `TroveTests/Fixtures/`; no test in `TroveTests` opens a network connection — the live API is exercised by hand at a spec's device pass." The T050 paragraph is untouched (Q13).
- **On the branch**: `docs/csv-reference.md`, `docs/samples/*`, `design/tokens.md` (the 002 section from the artboards; the retired ghost row; `TrendArrow` tokens), `design/brief.md` (a "Market figures" paragraph: asking prices, never value; the app's first external link), `design/elements/002-market-values/`, README feature sentences (the market bullet; the dashboard bullet's coverage clause; the export bullet's "carries the match, never the figures"; the sort clause; a Documentation link to `PRIVACY.md`), `specs/011`/`012` notes.
- **Post-merge (`fix/docs-002-shipped`)**: ROADMAP — rewrite the 002 entry (it still says "replace `currentValueCents`" and names eBay/Facebook), add its status row, record the 011 deferral's PDF clause as overridden by P17, add the eBay follow-up entry with Decision 1's two prerequisites, note 002 as `003`'s input; README Status/tree; `DECISIONS.md` — the first network dependency and local store, Reverb over a crawler, the terms' four obligations and where each lives, the 010 line restated (per-device facts never gate synced writes; no launch sweeps), the constitution-amendment reconciliation (Decision 19), the fifth routing bucket (Q20), blob-then-Pages (Decision 18).

---

## 9. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `theLocalModelsAreNotInTheSyncedSchema` — `models ∩ localModels = ∅`, `localModels` non-empty | a local model is added to `models` (CloudKitSchemaTests stays green on that — the reason G1 exists) |
| G2 | `theTwoDiskModesBuildTwoConfigurations` — `[0]` entity names == synced, `[1]` == local; `.cloudKit`'s `[0]` identifier == the container id; `[1]`'s nil | schemas swapped; the private id dropped |
| G2b | `everyConfigurationSpellsOutItsCloudKitDatabase` — source scan of every `ModelConfiguration(` in `TroveStore.swift` | `cloudKitDatabase:` deleted on any (the guard `== nil` **cannot** be, per the corrected fact) |
| G3 | `theStoresAreTwoFilesAndTheCollectionKeepsItsName` — urls differ; `[0].url.lastPathComponent == "default.store"`; `[1] == "MarketLocal.store"` | the name dropped; the synced one named |
| G4 | `theLocalModelsStoreOnlyAllowedFields` — per entity, `properties.map(\.name)` as a set **equals** its allowlist | `var listingTitle: String?` added anywhere |
| G5' | `aRefreshLeavesNoListingContentInTheStoreFile` (disk I/O, the CloudKit-test exception) — refresh through the stub against the seven-page fixture into a temp two-store container, save, close, read both SQLite files as bytes: none of the fixture's listing titles, ids or shop names appear; the product title **does** (Decision 20) | any listing string persisted |
| G6 | `uiTestsKeepEveryModelInMemory` — `.ephemeral` is in-memory, no CloudKit id, covers `models + localModels` | local models dropped from the ephemeral schema |
| G7 | `TwoStoreContainerTests.theProductionPairingLoadsAndSplits` — `configurations(for: .cloudKit, directory: tmp)` built through the real `build`, an `Item` and a `MarketFigureRecord` carrying a sentinel string saved; reopen `MarketLocal.store` alone → the record; reopen `default.store` under the synced schema → the item; then **the bytes**: the sentinel in `MarketLocal.store` (+ sidecars) and absent from `default.store` (Phase 1 review B1: a SwiftData reader over the collection's file can't be trusted to see a local model another configuration wrote there, so the split half is proven by bytes, the G5′ shape) | the record moved to the synced list (its unique key dropped so the pair loads) → the sentinel found in the collection's bytes |
| G8 | `combinedSchemaIsTheUnion` | a local model missing from `combinedSchema` |
| G9 | `previewsAndContentViewUseTheCombinedSchema` — scan | one preview left on `.schema` |
| G10 | `MarketListing` has four members (price, currency, condition slug, year — Amendment A); a decoded title-bearing page keeps no string but currencies, slugs and years | a field added |
| G11 | `MarketLocalStoreTests.historyIsNeverTrimmedByAge` — a 400-day-old point survives the next refresh and is still the trend's previous point (criterion 16, Decision 16) | a thirty-day prune in `record` |
| — | plus every mutation named in §§3–7 above |

---

## 10. Tasks — the shape (drafted after this plan is approved)

**Phase 0** — T000 the `CLAUDE.md` amendment (own commit, Decision 19).
**Phase 1 — foundations, no UI**: T001 the two-store spike (G7 first; G1–G4, G6, G8, G9; the `.automatic` audit; `makeInMemoryContainer` on the combined schema; nine previews + `ContentView`) → T002 the fixture script and fixtures → T003 model fields + export records (`CloudKitSchemaTests` red run) → T004 `MarketService`/`ReverbMarketService` + decoding + stub tests → T005 computation + trend + freshness + adoption → T006 local store + refresher + index + G5' + spies → T007 `MarketCopy` + `MarketAge` + vocabulary scan **[person: the contact address]**.
**Phase 2 — design**: T008 the Design pass **[person: invokes `/design` with the prompt; approves]** → artboards + PNGs + `tokens.md` section.
**Phase 3 — screens**: T009 detail VMs (intents, notice sequencing) → T010 `MarketSection` on both screens (placeholder retired) → T011 notice sheet → T012 picker → T013 rows + sort + placement re-measure → T014 dashboard variant → T015 Settings + About → T016 UI tests (×2).
**Phase 4 — contract and policy**: T017 CSV column + tolerance + samples + docs (one commit, "together or not at all") → T018 `PRIVACY.md` + guard + README link.
**Phase 5**: T019 device pass with the live API (match a real Telecaster — the notice once; refresh against the oracle numbers; the link opening reverb.com; withheld on a sparse product; offline via Link Conditioner; the hour rule; the Settings walk with progress; export → re-import restoring the match; the PDF without it; About's three lines; the privacy URL resolving after merge is a post-merge line; VoiceOver over the section; the detent switch) → T020 close-out (criteria 1–20 with honest partials: a real 429, the second-device history check; plan.md "As built"; the post-merge list).

## 11. Verification

Per task: `xcodebuild build` and `xcodebuild test -only-testing:TroveTests` with the count checked (per MEMORY: select suites, never functions); the UI target at T016 and T019, twice back to back. Every guard's red run recorded in its task's Done note. The live network is touched by the fixture script (by hand, T002) and the device pass (T019) only. The device pass runs on the `-uiTesting` store for anything destructive and on the dev store for the real match.

## Not in this plan

eBay (its own spec, two prerequisites); `003`'s trend-aware ranking (this spec builds its input); GitHub Pages (Decision 18's later flip); currency conversion; a stubbed Reverb under `-uiTesting` (Q13); a launch sweep of local rows (Q18).

---

## Amendment A — year narrowing (spec Decision 29, P18–P22; 2026-09-03)

Folded in after T002 at the person's direction. Grounded in a live
probe of Reverb's listing `year` field (free text: blank on about half
the modern Telecaster's listings; single years; ranges like
`1970 - 1984` and `2020 - Present`; decades like `2020s`; and oddities
— `0`, `2003-04`, `LATE 2000’s`) and on the catalog itself, which
already separates many variants (the D-18 is three products, the Blues
Junior IV three, the Stratocaster two), so the pick carries most of the
precision and narrowing is for the lumped cases.

### Models, forms, contract

- `var year: Int?` on `Item` and `WishlistItem` (after
  `reverbProductID`; trailing defaulted init parameter; CloudKit-clean).
  `ItemExportRecord`/`WishlistExportRecord` gain `year: Int?`.
- **The Year field** on both forms' Details, the forms' existing field
  style, optional, numeric keyboard, validated 1900…next year (P18);
  `ItemFormViewModel`/`WishlistFormViewModel` gain the field and its
  validation error ("Year should be four digits, 1900 to <next year>");
  saved as `Int?`. Tests: blank → nil; "1975" → 1975; "75", "abc",
  "1899", "<next year + 1>" → the error; round-trip on a second context.
  *Found at T009a (2026-09-04)*: "75" is rejected by the 1900 lower
  bound whatever the digit rule says, so it cannot detect the four-digit
  check being dropped — the falsifying case is a five-digit string in
  range once parsed, "01975", which both form tables now carry; the CSV
  importer's parse (T016a) needs the same case. The parse lives in both
  form view models by the task's instruction; if the importer becomes a
  third copy, `FieldNormalization` is the precedent home for a shared
  `year(from:)`.
- **CSV**: `Year` appended after `Reverb Product ID` on both lists (14
  and 9 columns); the boundaries stay `[12]` / `[7]` — both new columns
  append past the shipped layout, so the legacy tolerance covers both;
  import parses four digits in P18's range, blank → nil silent, else nil
  **counted**. `docs/csv-reference.md` gains the row; the samples' music
  rows carry plausible years; the PDF carve-out extends to the year
  (data, not a presented field — the PDF's `Bought` line already says
  when it was bought, and a model year beside it is a design question
  this amendment doesn't open).

### Client and computation

- `MarketListing` gains `year: String?` (four members; G10 → 4); the
  wire struct reads `year`. The fixtures carry it (re-recorded).
- `MarketYearCoverage.covers(stated: String?, year: Int, now: Date) ->
  Coverage` with `.unstated` (nil or blank after trimming), `.covers`,
  `.mismatch` — a pure, `nonisolated` parser: a four-digit year; `YYYY -
  YYYY` (any spacing around the dash); `YYYY - Present` / `Present`
  reaching the current year; `YYYYs` for a decade; anything else
  (including `0`, `2003-04`, `LATE 2000’s`) → `.mismatch` (P19).
- `MarketFigureComputation.compute` gains `year: Int?`: after currency
  and condition, drop listings whose coverage is `.mismatch`; if the
  survivors number fewer than three **and a year was given**, recompute
  over the unnarrowed set and mark the reading `.allYears(fallbackFrom:
  year)`; the reading's `yearScope` is `.any` (no year), `.year(Int)`, or
  `.allYears(fallbackFrom: Int)`. Withheld applies to whatever set was
  finally used (P20).
- `MarketFigureRecord` gains `yearFilter: Int?` and
  `isAllYearsFallback: Bool = false` (G4's allowlist grows by two; P21).
  `MarketHistoryPoint` unchanged. `MarketRefreshTarget.subject` carries
  the year.

### Section and copy

- The source line reads `On Reverb · {title} · {year}` when the item has
  a year. Under an all-years fallback, one line above the figure:
  `MarketCopy.allYearsFallback(year:)` — "Too few 1975 listings in this
  condition — all years shown." (wanted items: "Too few 1975 used
  listings — all years shown."). The figure beneath is an ordinary
  current figure: it sorts, sums and adopts (P20).
- Nothing new leaves the device; the notice and the policy stand.

### Tests and mutations (added to the tasks they belong to)

`MarketYearCoverageTests`: the table above, each recorded oddity, a
trailing space, `2020 - Present` at the current year and at next year's
item; mutation: treat unreadable as `.unstated` → the `0` case red.
Computation: the D-18-shaped synthetic set (twelve `1970 - 1984`, singles,
two blank) narrowed to 1975 → the twelve range listings, the 1975
singles and the two blanks count, 1973 excluded (mutation: drop the
blank-counts rule → red); a year with two survivors → `.allYears`
fallback over the full set (mutation: withhold instead → red); no year →
unchanged oracle numbers. Records: the two new fields on a second
context; the fallback flag round-trips. Forms: the validation table.
CSV: the fourteen-/nine-column layouts, the legacy tolerance still
passing at 12/7, a year of "75" counted as unmatched-year.

### Skeptical-review note

Not re-run for this amendment: it adds a field, a pure parser and one
reading, on the mechanisms the two plan reviews already covered; the
one genuinely new call — blank years count, thin years fall back — was
the person's, made against the probe. If the parser turns out to need
more shapes than the fixture shows, that is a data question for the
device pass, not a design change.

# Plan 003 — Trend-aware Sell Plan

**Status**: Draft — pending the skeptical-reviewer's sign-off (product-owner involvement level: Plan Mode plus the reviewer is the gate; the person receives the spec-conformance summary)
**Drafted**: 2026-09-06, against the approved `spec.md` (approved the same day), on branch `003-trend-aware-sell-plan` from `main` at `137446f` (the tuned model policy; 002 shipped).

## Context

What exists, read from the code rather than remembered:

- `SellPlanViewModel` (001) fetches every `Item`, keeps those `qualifies` (desire ≤ 3 via `DesireLevel.isSellCandidate`, a value entered) plus anything already selected, and sorts with a private static `rank`: desire ascending, value descending (nil last), name, id. `SellPlanView`'s private `SellPlanRow` draws checkbox, name, category, the person's value in `monoValue`, and the `DesireDial`, inside an `HStack` with default centre alignment. The screen's header reads "Lowest desire to keep first" and the wishlist detail's button subtitle describes the same order; both stay true under this plan.
- `MarketSummary { medianCents: Int?, trend: MarketTrend? }` (002) is the one derivation every row surface reads, through `MarketSummary.summaries(forSubjects:in:now:)`, which loads the figure index once and gates the median by `MarketFreshness`. Its `trend` is the figure record's stored `trendRawValue`, written by `MarketLocalStore.record` from the whole history, so it can never disagree with the history it was computed over. It is **not** gated by freshness today: the list rows draw an arrow on a stale figure. This plan does not change that surface (not in the spec); the Sell Plan gates it (§2).
- `MarketTrend.compute(history:)` picks `previous` as the most recent point at least seven days older than the latest, and classifies at ±5 % with integer arithmetic. It returns only the classification; the percentage and the earlier reading's date the reason line needs are not surfaced anywhere yet.
- `MarketLocalStore.historyEntries(for:in:)` returns an item's points as values, sorted by date.
- `-uiTesting` is read once in `TroveApp.isUITesting` and routes `TroveStore.make` to the in-memory pair; the UI suite launches with exactly that argument and builds its own state through the UI. Nothing seeds anything today.
- `MarketVocabularyTests` scans `MarketCopy.swift` and a list of Market view files for the forbidden words, after stripping allowed phrases (which include "asking prices"). `SellPlanView.swift` cannot join that list — its empty-state copy legitimately says "worth" and "value" for the person's numbers. `SellPlanFramingTests` scans `SellPlanView.swift`'s literals for gap-framing terms.

## Proposed at planning (Q1–Q9) — approved on sign-off unless overturned

- **Q1. The comparator gains one key, between desire and value.** `SellPlanRanking.rank(_:_:trend:)` — desire ascending; then the trend group `up → 0`, `flat`/`nil → 1`, `down → 2`; then value descending (nil last); then name; then id. `candidates(from:alreadySelected:trend:)` takes the trend as a `(UUID) -> MarketTrend?` so the pure function is testable with a dictionary and the existing 001 tests pass it nothing (their order is unchanged, which is criterion 9's first half).
- **Q2. The stored trend ranks and draws the arrow; the history supplies the reason.** The Sell Plan reads `MarketSummary` like every other row surface, so its arrow is the item list's arrow. `MarketSummary` gains `currentTrend: MarketTrend?` — the stored trend when `medianCents` is non-nil, else nil — and the Sell Plan reads only that, so a stale or withheld figure ranks neutral and draws nothing (spec "The ranking", third bullet; criterion 6). The list rows keep reading `trend` as before.
- **Q3. `MarketTrend.comparison(history:)` replaces the body of `compute`.** `MarketTrend.Comparison { latestCents, previousCents, previousAt, trend }`; `compute(history:)` becomes `comparison(history:)?.trend`, so the existing `MarketTrendTests` prove the previous-point selection is unchanged by construction. `Comparison.percent: Int` is `(latest − previous) / previous × 100`, rounded half away from zero (`Double(...).rounded()`), signed. `MarketRise { percent: Int, since: Date }` is what the reason line shows; the view model derives it only for candidates whose `currentTrend` is `.up`, reading `historyEntries(for:)` for those few (the Sell Plan holds a handful of rows; the index load stays one fetch). If the history's comparison does not classify `.up` — a mismatch would mean the history changed under the record, which no writer does — the rise is dropped: no reason line, never a wrong one.
- **Q4. The two lines live in one new Market view file, so the vocabulary scan covers them.** `Trove/Views/Market/SellPlanMarketLines.swift`: `SellPlanMarketLine(medianCents:trend:)` — `MarketCopy.sellPlanMarketLine(medianCents:)` in `monoMeta`/`textQuiet` with `TrendArrow` after it, `.accessibilityLabel(MarketCopy.figureAccessibilityLabel(medianCents:))` so the combined row reads "Median asking price $1,400, trending up" — and `SellPlanReasonLine(rise:now:)` — `MarketCopy.sellPlanReason(percent:since:now:)` in `secondary`/`textQuiet`, `lineLimit(nil)` and `fixedSize(horizontal: false, vertical: true)`. Identifiers `sellPlan.market`, `sellPlan.reason`. The file joins `MarketVocabularyTests.viewFiles` and `SellPlanFramingTests`' literal scan; `SellPlanView.swift` joins neither.
- **Q5. Copy.** `MarketCopy.sellPlanMarketLine(medianCents:)` → "$1,400 on Reverb". `MarketCopy.sellPlanReason(percent:since:now:)` → "Asking prices on Reverb are up 12 % since Aug 5." — the percent and the sign joined by a narrow no-break space (U+202F) so the pair never breaks across a line (the spec's "12 %" typeset); the date `.month(.abbreviated).day()` in the `en_US` locale the currency helpers already pin, with `.year()` appended when the reading's calendar year differs from `now`'s. Only the rising sentence exists; there is no falling variant to leave unused.
- **Q6. The row.** `SellPlanRow` becomes `HStack(alignment: .top)`: left column name, category, then the reason line when a rise exists; right column the person's value, then the market line when a summary with a current median exists; the dial after. Top alignment is what keeps the checkbox, name, value and dial on the same edge whether a row has zero, one or two extra lines (criterion 11's alignment half). `SellPlanView` passes `viewModel.summary(for:)` and `viewModel.rise(for:)` into the row; the row stays `.combine`d.
- **Q7. The view model.** `SellPlanViewModel.init` gains `now: @escaping () -> Date = Date.init` (the `ItemListViewModel` pattern). `load()` assigns `marketSummaries` **right after the item fetch and before the sort** (002's T012 lesson), then `rises` for the rising candidates, then `candidates` with `trend: { self.currentTrend(for: $0) }`. Reads of the local store are `try?` → nothing stored, the 002 direction: a market-store problem must never empty the plan. `summary(for:)`, `rise(for:)`, `currentTrend(for:)` are the row's readers.
- **Q8. The seed (spec Decision 9).** `Trove/App/UITestSeed.swift`: `static func shouldSeed(arguments:) -> Bool` is true only when the arguments contain **both** `-uiTesting` and `-seedSellPlan`; `static func sellPlan(into context: ModelContext, now: Date) throws` inserts one wanted item ("Summicron 35mm f/2", $2,400) and four owned items at desire 2: "Telecaster" $1,400 matched, figure median $1,400, history $1,250 fourteen days ago → $1,400 now (rising, +12 %); "Blues Junior" $640 matched, history $600 → $600 (flat); "Squier Classic Vibe" $380 unmatched (neutral, no market line); "NT1-A" $140 matched, history $200 → $170 (falling, −15 %). Each figure record's `trendRawValue` is set from `MarketTrend.compute` over the seeded history, the writer's invariant. `TroveApp.init` calls it once, after the store is built, guarded by `shouldSeed` — the constitution's test-only branch, read once, able only to add rows to that launch's in-memory stores. The order that should result: Telecaster, Blues Junior, Squier, NT1-A — one per trend group with the neutral pair ordered by value — which is what the UI test asserts.
- **Q9. No Design pass** (spec Decision 8, delegated); no schema change in either store (every new fact is derived at read time from rows 002 already writes, so `MarketLocalSchemaTests`' allowlists and `CloudKitSchemaTests` are untouched); no CSV, import, PDF or `PRIVACY.md` change (nothing new is stored or sent — a sentence in the close-out says so rather than editing the policy); README's Sell Plan bullet gains one sentence on the spec branch; `ROADMAP.md` on `main` at close-out.

## Layout and files

| File | Change |
|---|---|
| `Trove/Market/MarketTrend.swift` | `Comparison`, `comparison(history:)`, `compute` re-expressed, `MarketRise` |
| `Trove/Market/MarketIndex.swift` | `MarketSummary.currentTrend` |
| `Trove/Models/MarketCopy.swift` | `sellPlanMarketLine`, `sellPlanReason`, the date style |
| `Trove/ViewModels/SellPlanViewModel.swift` | `now`, `marketSummaries`, `rises`, the readers; `rank` → `SellPlanRanking` (same file, `nonisolated enum`) |
| `Trove/Views/Market/SellPlanMarketLines.swift` | new: the two line views |
| `Trove/Views/Wishlist/SellPlanView.swift` | the row composes the lines; top alignment |
| `Trove/App/UITestSeed.swift` | new: `shouldSeed`, `sellPlan(into:now:)` |
| `Trove/App/TroveApp.swift` | the one guarded call |
| `TroveTests/MarketTrendTests.swift` | comparison, percent, rise |
| `TroveTests/SellPlanViewModelTests.swift` | ranking with trends, readers, the 001 suites unchanged |
| `TroveTests/SellPlanMarketLinesTests.swift` | new: render and wiring |
| `TroveTests/MarketCopyTests.swift`, `MarketVocabularyTests.swift` | the new strings pinned; the new view file scanned |
| `TroveTests/UITestSeedTests.swift` | new: gating, contents, the writer's invariant |
| `TroveUITests/TroveUITests.swift` | one seeded test |
| `README.md` | one sentence |

New files land through the synchronized root groups — no `.pbxproj` edit.

## 1. Comparison and rise

`MarketTrend.Comparison: Sendable, Equatable { latestCents: Int, previousCents: Int, previousAt: Date, trend: MarketTrend }` with `var percent: Int`. `static func comparison(history:) -> Comparison?` is today's `compute` body returning the struct; `compute(history:)` = `comparison(history:)?.trend`. `MarketRise: Sendable, Equatable { percent: Int, since: Date }` with `init?(comparison:)` — nil unless `trend == .up`.

Tests (`MarketTrendTests`, extended): the existing suite is untouched and stays green (the by-construction proof); `percent`: 1000→1050 = 5, 1000→1124 = 12, 1000→1125 = 13 (half away), 1000→950 = −5, 1000→1049 = 5 (rounds up, yet `.flat` — the reason line never shows for it because `MarketRise` requires `.up`); `previousAt` is the 8-day point among 20 d / 8 d / 1 d (mutation: pick the oldest → red); `MarketRise(comparison:)` is nil for `.flat` and `.down`.

## 2. The summary's current trend

`MarketSummary.currentTrend` — `medianCents == nil ? nil : trend`. Test (`MarketIndexTests`): a snapshot 31 days old with `.up` stored → `currentTrend` nil, `trend` still `.up` (mutation: drop the gate → red).

## 3. The ranking and the view model

`SellPlanRanking.rank(_:_:trend:)` and `.group(of:)` (`up 0, flat/nil 1, down 2`). `SellPlanViewModel.candidates(from:alreadySelected:trend:)`.

Tests (`SellPlanRankingTests`, new suite in the existing file): same desire, rising beats flat regardless of value (criterion 1); flat beats falling regardless of value (2); rising desire-3 below flat desire-1 (3; mutation: put the group key before desire → red); same group → value then name (4); nil and `.flat` are the same group (mutation: give nil its own group → red); with `trend: { _ in nil }` the order equals 001's (9, first half — the existing `SellPlanCandidateTests` are this test already, and stay). View model: a matched rising item at desire 2 ranks above a flat one at higher value **through `load()`** with rows in the local store (the integration the pure test cannot give; mutation: assign `marketSummaries` after the sort → red, the T012 shape); `rise(for:)` is the seeded comparison for the rising item and nil for the others; a stale figure gives nil `currentTrend`, nil `rise`, neutral rank (6); the local-store read failing reads as no summaries and the plan still lists (the 002 `try?` direction); `selectedValueCents` ignores the market median (7; mutation: sum the median → red).

## 4. Copy

`MarketCopyTests` pins both strings whole: `sellPlanMarketLine(medianCents: 140_000)` == "$1,400 on Reverb"; `sellPlanReason(percent: 12, since: <2026-08-05>, now: <2026-09-06>)` == "Asking prices on Reverb are up 12\u{202F}% since Aug 5."; with `since` in 2025 → "… since Aug 5, 2025."; the year boundary is the calendar year, not 365 days (mutation: compare by interval → red). `MarketVocabularyTests`: both new strings pass `fires` (the "asking prices" phrase); `SellPlanMarketLines.swift` is in `viewFiles` and carries no literal with a space.

## 5. The row and the lines

`SellPlanMarketLinesTests`: **render** — `SellPlanMarketLine` with `.up` draws `accentMossText` ink and with `nil` draws none beyond the text (the `TrendArrowRenderTests` shape); a `SellPlanRow` with a rise renders taller than the same row without one and the extra height is the reason line's (mutation: drop the line from the row → the heights equal → red); at `.accessibility5` the reason line's rendered height exceeds one line-height (wraps, not truncates; mutation: `lineLimit(1)` → red). **Wiring** (`SourceScan` over `SellPlanView.swift`): the row composes `SellPlanMarketLine(` and `SellPlanReasonLine(`, reads `viewModel.summary(for:` and `viewModel.rise(for:`, and its `HStack(alignment: .top`; the lines file reads every string through `MarketCopy` and carries both identifiers.

## 6. The seed and the UI test

`UITestSeedTests`: `shouldSeed` is false for `[]`, `["-uiTesting"]`, `["-seedSellPlan"]` and true for both (mutation: `||` → red); `sellPlan(into:now:)` into an in-memory combined context yields exactly the four owned and one wanted rows, three figure records, six history points, and each record's `trendRawValue` equals `MarketTrend.compute` over that item's history (mutation: hard-code the Telecaster's trend as `.flat` → red); a `SellPlanViewModel` loaded over the seeded context orders Telecaster, Blues Junior, Squier, NT1-A and reports a +12 % rise for the Telecaster only. Scan: `TroveApp.swift` calls `UITestSeed.sellPlan` exactly once and only inside an `if UITestSeed.shouldSeed(` line (the read-once rule).

`TroveUITests.testTheSeededSellPlanRanksRisingFirstAndSaysWhy`: launch with `["-uiTesting", "-seedSellPlan"]`; Wishlist tab → the Summicron's detail → "Find items to sell"; the four names' `frame.minY` ascend in the seeded order; exactly one `sellPlan.reason` element, whose label begins "Asking prices on Reverb are up 12"; exactly three `sellPlan.market` elements (the Squier has none). The other tests keep launching with `-uiTesting` alone and see an empty collection (mutation: seed on `-uiTesting` alone → `testEmptyCollectionOffersImportAndSettingsButNotExport` red). Run twice back to back.

## 7. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | rising desire-3 below flat desire-1 | the group key moves ahead of desire |
| G2 | nil and `.flat` share a group | nil given its own group |
| G3 | `load()` ranks by trend | `marketSummaries` assigned after the sort |
| G4 | `currentTrend` nil on a stale figure | the freshness gate dropped |
| G5 | `selectedValueCents` ignores the median | the median summed |
| G6 | the reason line's year rule | interval compare for calendar year |
| G7 | the row grows by the reason line; wraps at `.accessibility5` | line dropped; `lineLimit(1)` |
| G8 | `shouldSeed` needs both flags; `TroveApp` calls the seed once under the guard | `\|\|`; a second call site |
| G9 | seeded records' trend equals `compute(history)` | a hard-coded trend |
| G10 | the existing `SellPlanCandidateTests` and `MarketTrendTests` | unchanged and green — the by-construction claims of Q1 and Q3 |

## 8. Tasks — the shape (drafted after sign-off)

**Phase 1 — foundations, no UI (foundational: per-task review at the reviewer's default tier)**: T001 comparison, rise, `currentTrend`, copy (§§1, 2, 4) → T002 ranking and view model (§3) → T003 the seed (§6's unit half).
**Phase 2 — the screen (mechanical: one per-phase review)**: T004 the lines file and the row (§5) → T005 the UI test, twice (§6).
**Phase 3 — close-out**: T006 the device pass **[person]** (the seeded plan on the simulator; the person's own device as history accrues — VoiceOver over a rising row, `.accessibility5`) → T007 close-out: criteria 1–12 cited, README sentence, `ROADMAP.md` on `main`, plan "As built", the pre-merge sweep at the reviewer's default tier on the documents plus `git diff main...HEAD`.

## 9. Verification

`scripts/verify.sh` per task (the unit suite; the orchestrator re-runs it in Phase 1, takes the implementer's verbatim output in Phase 2); `scripts/verify.sh ui` at T005 and T007, twice. Every guard's red run recorded in its task's Done note. No test opens a network connection; nothing in this spec touches the live API at all.

## Not in this plan

Cross-level lifting, falling-row text, the dashboard survey (009), notifications, new thresholds or a magnitude ranking, the median in the combined value, history sync (all spec non-goals). Gating the list rows' arrows by freshness — observed above, not in the spec, recorded for the person as a question rather than changed here.

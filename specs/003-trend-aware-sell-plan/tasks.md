# 003 — Trend-aware Sell Plan: Tasks

**Status**: Signed off — skeptical-reviewer, top tier, one review and one re-review, 2026-09-06 (plan B1 fixed by the orchestrator after the re-review, per the review cap; see plan.md's review record)
**Implements**: plan.md in this directory
**Foundational phases**: 1 — per-task reviewer cadence; Phase 2 is per-phase; Phase 3 is the person's pass and the close-out.

Drafted 2026-09-06 by the `sdd-planner` against the draft `plan.md` in
this directory, on branch `003-trend-aware-sell-plan` (the base commit
is recorded by the orchestrator when this file is committed). No new
technical decisions are made here — every task traces to a plan
section; where a task says "per plan," that section is the authority.
The plan's §8 gave the shape; this document is the shape with its
Verify criteria, its packet contents and its cadence.

<!-- Once implementation starts, this file gets written by more than one
party — whoever's steering adds scope and reshuffles tasks; the
orchestrating session (never the sdd-implementer subagent) checks boxes
and adds findings. Never edit this file from a stale copy. Prefer small,
targeted edits over regenerating it wholesale. -->

Ordering note: the pure pieces first, bottom-up, each with its guards —
the comparison and the copy (nothing depends on the screen), then the
ranking inside the view model (depends on the comparison and the
summary's gate), then the seed (depends on the local store's writer and
the ranking, and is what the UI test and the device pass stand on). The
screen follows once every fact it shows exists and is tested; the UI
test follows the screen. No `.pbxproj` edit anywhere: new files land
through the synchronized root groups.

House rules carried over: one commit per completed task, referencing the
task ID, made by the orchestrator after its own verification; every
guard test is **mutation-verified** (break the rule deliberately,
confirm red) before it lands, and the task's Done note records what was
broken and what went red; **`scripts/verify.sh` is the verification** —
the unit suite per task, `scripts/verify.sh ui` at the Phase 1 pause
once and at T005 and T007 twice back to back — with the count line read,
never just the banner; no test opens a network connection (nothing in
this spec touches the live API at all). Tasks marked **[person]** block
on something only the person has.

## Cadence (the constitution's model policy, as amended 2026-09-06)

- **Phase 1 is foundational**: each task is dispatched to the
  `sdd-implementer` on a task bundle assembled with shell (task line,
  plan sections, acceptance criteria, files, the pattern file), with
  the instruction not to read `plan.md`, `spec.md` or `tasks.md` in
  full; on return the orchestrator re-runs `scripts/verify.sh` itself,
  stages (`git add -A`), cuts a review bundle from the diff, and invokes
  the `skeptical-reviewer` at its default tier. **One review and at most
  one re-review per task**; anything still open after the re-review
  goes to the tier log and the sweep.
- **Phase 2 is mechanical**: the implementer's verbatim
  `scripts/verify.sh` output is the verification; one per-phase review
  at the reviewer's default tier over the phase's diff.
- **Phase 3** is the person's device pass and the close-out, ending in
  the pre-merge sweep at the reviewer's default tier over the three
  documents plus `git diff main...HEAD`.
- **The person pauses** after each phase, with the four-part report
  (why this pause; what you can now do; where execution deviated from
  the spec, and why; what needs your decision), and whenever something
  unexpected bears on spec adherence. **A fresh orchestrator session
  starts at each phase pause**, resuming from the first unchecked task
  here.
- **Escape hatch**: two failed verifications on one task, or a "stopped
  on a judgment call" the orchestrator considers well-specified → the
  orchestrator does the task itself at the top tier and logs the miss.

## Phase 1 — Foundations, no UI (foundational: per-task review)

- [x] **T001 — Comparison, rise, the summary's current trend, and the copy.** Plan §§1, 2, 4; Q2, Q3, Q5. `MarketTrend.Comparison` and `comparison(history:)`, `compute` re-expressed as `comparison(history:)?.trend`; `Comparison.percent` with the exact-integer numerator before the one division, `.rounded()` half away from zero; `MarketRise` and its failable `init(comparison:)`; `MarketSummary.currentTrend`; `MarketCopy.sellPlanMarketLine(medianCents:)` and `sellPlanReason(percent:since:now:)` (U+202F before the `%`; `en_US` month-day; the year appended only when `Calendar.current`'s year of `since` differs from `now`'s). Files: `Trove/Market/MarketTrend.swift`, `Trove/Market/MarketIndex.swift`, `Trove/Models/MarketCopy.swift`; tests in `TroveTests/MarketTrendTests.swift`, `MarketIndexTests.swift`, `MarketCopyTests.swift`, `MarketVocabularyTests.swift`. Pattern: `MarketTrend.compute` itself (integer arithmetic, the most-recent qualifying previous); `MarketCopyTests`' whole-string pins; `MarketIndexTests.value(median:at:)` for a record with a stored trend. **Verify**: `scripts/verify.sh` green with the count up; the existing `MarketTrendTests` untouched and green (plan G10); the tests plan §§1, 2, 4 name present — the whole `Comparison` pinned for 20 d / 8 d / 1 d, `percent` for 1000→1050/1124/1125/1145/950/850/1049 and 4000→4700, `MarketRise` nil for `.flat` and `.down` and populated for `.up`, `currentTrend` nil on a 31-day-old `.up` and on a withheld `.up`, both copy strings whole, the year rule by calendar year, both strings passing `fires`. **Mutations recorded red**: pick the oldest previous; take the date from one point and the median from another; divide first (1000→1145 → 14 — the only pin that discriminates); drop the freshness gate on `currentTrend`; compare the year by interval. Serves criteria 5 (the numbers), 6 (the gate), 8 (by construction), 10 (vocabulary).
  *Done (2026-09-06, `sdd-implementer`)*: `MarketTrend.Comparison`
  (`latestCents`, `previousCents`, `previousAt`, `trend`, `percent` with
  the exact-integer numerator), `comparison(history:)` carrying the
  selection verbatim, `compute` = `comparison(history:)?.trend`,
  `MarketRise(comparison:)` failable on `.up`; `MarketSummary.currentTrend`;
  `MarketCopy.sellPlanMarketLine` / `sellPlanReason` (U+202F, `en_US`,
  calendar-year rule via `Calendar.current` on both sides). Twelve new
  test functions, 1104 → 1116, the existing `MarketTrendTests` hunk pure
  additions (G10). **Mutations red**: oldest previous (the whole-
  `Comparison` pin and the existing most-recent-previous test); date from
  one point, median from another; divide first — red on the 1145 row
  only, 4000→4700 green as predicted; the freshness gate dropped (two
  `MarketIndexTests`); the year by interval (2025-12-31 → 2026-01-02); a
  "market value" literal → the vocabulary pass-through. Orchestrator's
  own `scripts/verify.sh`: 1116 in 148, green. Review (default tier):
  signed off, no blocking; two cosmetic notes folded by the orchestrator
  before the commit (an assertion entailed by the string pin removed; a
  comment that stated T002's ranking as fact reworded). Carried forward:
  `MarketIndexTests.value(median:at:trend:)` now writes a stored trend
  (T002/T003's fixture shape); the `viewFiles` entry for the new view
  file is T004's. The `verify.sh` count line counts test functions, not
  parameterised cases.

- [x] **T002 — The ranking, and the view model's market readers.** Plan §3; Q1, Q2, Q7. `SellPlanRanking.rank(_:_:trend:)` and `group(of:)` (MainActor, not `nonisolated`); `candidates(from:alreadySelected:trend:)` with `trend` defaulting to `{ _ in nil }` so the 001 suites compile untouched; `SellPlanViewModel.init(..., now:, history:)` with the closure-with-default `history`; `loadedAt`; `marketSummaries` assigned right after the item fetch and **before** the sort; `rises` for the rising candidates only, dropped unless the history's own comparison is `.up`; `summary(for:)`, `rise(for:)`, `currentTrend(for:)`; every local-store read `try?`; the `catch` clears the new state too. New identifiers stay clear of `SellPlanFramingTests`' terms (the file is scanned). Files: `Trove/ViewModels/SellPlanViewModel.swift`; tests in `TroveTests/SellPlanViewModelTests.swift` (a new `SellPlanRankingTests` suite and the view-model cases in plan §3). Pattern: `ItemListViewModel.load()`'s summaries line and its `now` injection; `TroveStore.make(recreateLocalStore:)` for the closure default; `MarketIndexTests` for writing figure rows through `MarketLocalStore.record` into `makeInMemoryContainer()`. **Verify**: `scripts/verify.sh` green; `SellPlanCandidateTests`, `SellPlanSelectionTests`, `SellPlanFiguresTests`, `SellPlanFramingTests`, `SellPlanEmptyReasonTests` untouched and green (plan G10); the plan §3 tests present — criteria 1–4 as pure tests, the two-pair G2, the integration through `load()` with rows in the local store, the stale and the withheld fixtures, the throwing `history` closure (no rises, every candidate still listed, no failure message), `selectedValueCents` ignoring the median. **Mutations recorded red**: group key ahead of desire (G1); nil before flat and flat before nil (G2, one pair each); `marketSummaries` assigned after the sort (G3); the median summed (G5). Serves criteria 1, 2, 3, 4, 6, 7, 9.
  *Done (2026-09-06, `sdd-implementer`)*: `SellPlanRanking` (MainActor;
  `group(of:)` up 0 / flat-or-nil 1 / down 2; `rank(_:_:trend:)` desire →
  group → value nil-last → name → id — 001's private `rank` moved, not
  duplicated); `candidates(from:alreadySelected:trend:)` with `{ _ in nil }`
  as the default so the five 001 suites compile untouched (the test file's
  one hunk is purely additive at line 569); `init(…, now:, history:)`, the
  history read a closure-with-default over `MarketLocalStore.historyEntries`;
  `load()` sets `loadedAt`, assigns `marketSummaries` **before** the sort,
  ranks through `currentTrend(for:)`, then fills `rises` for rising
  candidates only, through `MarketTrend.comparison` → `MarketRise.init`;
  every local-store read `try?`; `summary(for:)`, `currentTrend(for:)`,
  `rise(for:)`. Two new suites: `SellPlanRankingTests` (5) and
  `SellPlanMarketReaderTests` (6, through `load()` with rows written by
  `MarketLocalStore.record`); 1116 → 1127 in 150. **Mutations red**: G1
  (group key ahead of desire); G2 both pairs, each red on its own line
  (:633 / :637); G3 (summaries after the sort → 4 of 6 reader tests); G5
  (median summed → 200000 vs 60000); the throwing history closure (`try?`
  → `try` → candidates empty, trend nil, failure message set — all three
  assertions). Orchestrator's own `scripts/verify.sh`: 1127 in 150, green.
  Review (default tier): signed off; the dead second `trend` default on
  `rank` removed by the orchestrator before the commit (plan §3's
  signature). Recorded, not tested: the `MarketRise.init` disagreement
  branch (a stored `.up` whose history no longer classifies `.up`) is
  unreachable through the store's writer, which recomputes the trend from
  the same history at every write — the guard is belt-and-braces, noted for
  the As built. Finding: `MarketLocalStore.record`'s withheld branch
  recomputes the trend from the surviving points, so a withheld-with-`.up`
  fixture needs two prior figure readings ≥ 7 days apart (T003's seed and
  any later fixture). `loadedAt` is consumed first by T004's row; its test
  is there.

- [x] **T003 — The seed.** Plan §6 (the unit half); Q8. `Trove/App/UITestSeed.swift`: `argument`, `shouldSeed(mode:arguments:)` true only for `.ephemeral` with `-seedSellPlan`; `sellPlan(into:now:)` — the Summicron ($2,400), and at desire 2 the Telecaster (**$600**, `reverbProductID` 126161, two `MarketLocalStore.record` calls: $1,250 at −14 d, then $1,400 at `now`), the Blues Junior ($640, matched, $600 → $600), the Squier Classic Vibe ($380, unmatched, no market rows), the NT1-A (**$400**, matched, $200 → $170) — values chosen so value alone orders Blues Junior, Telecaster, NT1-A, Squier and only the trend key gives Telecaster, Blues Junior, Squier, NT1-A; every market row written through `MarketLocalStore.record`, never constructed directly; one `save()` at the end. `TroveApp.init`: one call, `if UITestSeed.shouldSeed(mode: store.mode, arguments: ProcessInfo.processInfo.arguments)`, after the store is built, over `store.container.mainContext`, a failure → `fatalError`; `"-uiTesting"` still read in exactly one place and `"-seedSellPlan"` absent from `TroveApp.swift`. Files: `Trove/App/UITestSeed.swift` (new), `Trove/App/TroveApp.swift`; tests in `TroveTests/UITestSeedTests.swift` (new). Pattern: `ItemDetailViewModelTests.seed(median:at:in:)` and `MarketIndexTests.reading(median:at:)` for a `MarketReading.figure` fed to `MarketLocalStore.record`; `ItemDetailViewModelTests.world(productID:)` for an `Item` with `reverbProductID`; `TroveStore.make(isUITesting: true)` for the container the test builds through; `MarketLocalSchemaTests` for a scan over `TroveApp.swift`. **Verify**: `scripts/verify.sh` green; `shouldSeed` false for `.ephemeral` + `[]`, `.ephemeral` + `["-uiTesting"]`, `.cloudKit` and `.localOnly` + both flags, true for `.ephemeral` + both flags; the seed through `TroveStore.make`'s container yields 4 owned, 1 wanted, 3 matched items, 3 snapshots, 3 figure records fetched at `now`, 6 points, every record's trend equal to `compute(history)` and to `up`/`flat`/`down` as seeded; the writer-only scan over `UITestSeed.swift`; a `SellPlanViewModel` over the seeded context orders Telecaster, Blues Junior, Squier, NT1-A with a +12 % rise for the Telecaster only; the scan on `TroveApp.swift` (one `UITestSeed.sellPlan(` call inside the `shouldSeed(mode: store.mode` block; `"-uiTesting"` once; `"-seedSellPlan"` absent). **Mutations recorded red**: gate on the arguments alone (G8); a seed call outside the `shouldSeed` guard (G8's call-site half); the Telecaster's second `record` replaced by a direct `MarketFigureRecord` insert carrying `"flat"` (G9, both halves); a second `"-uiTesting"` literal in `TroveApp.swift`; drop the group key from `rank` → the seeded order becomes Blues Junior, Telecaster, NT1-A, Squier. Serves criterion 12 (the unit half).
  *Done (2026-09-06, `sdd-implementer`, one fix pass)*: `UITestSeed`
  (`argument`, `shouldSeed(mode:arguments:)` = `.ephemeral` **and** the
  flag, `sellPlan(into:now:)` writing every market row through
  `MarketLocalStore.record` / `recordMatch`, one `save()`); `TroveApp.init`
  calls it once inside the guard after the store is built, with
  `"-uiTesting"` still read in one place; the values exactly the plan's
  (Telecaster $600 / 126161 / $1,250 → $1,400; Blues Junior $640 flat;
  Squier $380 unmatched; NT1-A $400 / $200 → $170). `UITestSeedTests` (6):
  the gate table incl. persistent modes with both flags, the call-site and
  read-once scans, the counts through `TroveStore.make(isUITesting: true)`
  read back on a **second** context, stored trend = `compute(history)` for
  up/flat/down, the writer-only scan, the seeded order with the Telecaster's
  +12 % alone. 1127 → 1133 in 151. **Mutations red**: G8 (arguments alone →
  `.cloudKit`/`.localOnly` true); the call *moved* outside the guard →
  `:61` the placement assertion alone (the first attempt had *added* a call,
  which only reached the count assertion — review B1); a second
  `"-uiTesting"` literal; G9 (a direct record insert carrying "flat" → the
  trend, the counts and the writer scan); G11 (group key dropped → Blues
  Junior, Telecaster, NT1-A, Squier); `save()` deleted from the seed → three
  tests red at the helper's `#require` (review B2: the suite had refetched
  on the inserting context — the constitution's named false-passing shape,
  fixed by a second `ModelContext`). Orchestrator's own `scripts/verify.sh`:
  1133 in 151, green. `scripts/verify.sh ui` under `-uiTesting` alone: see
  the pre-pause line below. Invented, declared: product ids 61927 / 40318
  and proportional bounds for the two extra matched items — carried to T005
  / the device pass in case a seeded Market section ever refreshes (review
  S1). Finding: `MarketFigure`'s short init is test-only; production passes
  all nine members.

Before the pause: one `scripts/verify.sh ui` run (the count line read: the same count as the last green UI run), since T003 touched the launch path every UI test goes through — recorded in T003's Done note. *Run by the orchestrator 2026-09-06 after T003's commit: `Executed 13 tests, with 0 failures`, the same 13 as before the spec — the seed does not fire under `-uiTesting` alone.*

**Phase 1 pause** — the person's report; a fresh session resumes at T004.

## Phase 2 — The screen (mechanical: one per-phase review)

- [x] **T004 — The two lines, and the row that composes them.** Plan §5; Q4, Q6, Q10. `Trove/Views/Market/SellPlanMarketLines.swift` (new): `SellPlanMarketLine(medianCents:trend:)` — the `Text` in `monoMeta`/`textQuiet` carrying `.accessibilityLabel(MarketCopy.figureAccessibilityLabel(medianCents:))` **on the `Text`**, `TrendArrow(trend:)` after it, identifier `sellPlan.market`; `SellPlanReasonLine(rise:now:)` — `secondary`/`textQuiet`, `lineLimit(nil)`, `fixedSize(horizontal: false, vertical: true)`, identifier `sellPlan.reason`; no string literal containing a space in the file's production code (a `#Preview` is outside the scan). `SellPlanRow` internal, `HStack(alignment: .top)`, the reason line under the category, the market line under the value in a trailing-aligned column, still `.combine`d, built from `summary: viewModel.summary(for:)`, `rise: viewModel.rise(for:)`, `now: viewModel.loadedAt`. Files: the new file, `Trove/Views/Wishlist/SellPlanView.swift`; tests in `TroveTests/SellPlanMarketLinesTests.swift` (new: render and wiring), the file added to `MarketVocabularyTests.viewFiles`. Pattern: `TrendArrow.swift` and `TrendArrowRenderTests` (ink within ΔE of the token; width/height comparisons with a control), `DesireGaugeTests` (sampling the dial's ramp colour), `MarketWiringTests` (`SourceScan` composition pins). **Verify**: `scripts/verify.sh` green (the implementer's verbatim output is the verification in this phase); the render tests — `.up` draws `accentMossText` ink, `nil` none in either arrow tone; a row with a summary and a rise (a sentence that cannot fit one line at 360 pt) taller than without by at least twice one `secondary` line-height (plan §5, the one threshold that goes red for both the dropped line and `lineLimit(1)`); the checkbox's top edge — found as the topmost y of a brass block at least 10 px tall in at least 10 adjacent columns within the left 40 pt, which neither edge of the 1 pt card border can satisfy; the located y printed on the healthy render and equal to 16 pt × the bitmap scale **before** the `.center` mutation is trusted (plan §5) — and the dial's ring top edge at the same y in both renders; the three heights (plain row, row with the lines, `oneLine`) recorded in the Done note; the wiring scan — both views composed, the three readers passed, both identifiers, the label inside the `Text(` chain, the row still `.combine`d; the vocabulary scan green over the new file (the no-spaced-literal rule's one home). **Mutations recorded red**: the reason line dropped from the row (difference under one line); `lineLimit(1)` (difference under two lines); `.center` alignment (the plain row's checkbox run starts lower); the label moved from the `Text` to the `HStack`; a spaced literal in the file's production code. Serves criteria 5, 6, 10, 11 (per plan Q10: wrap-not-truncate and alignment; the size setting itself changes nothing in this app).

  *Done (2026-09-06, `sdd-implementer`, first try)*: `SellPlanMarketLines.swift`
  (`SellPlanMarketLine` — `monoMeta`/`textQuiet`, the label on the `Text`,
  `TrendArrow` after it, `sellPlan.market`; `SellPlanReasonLine` —
  `secondary`/`textQuiet`, `lineLimit(nil)`, `fixedSize`, `sellPlan.reason`;
  no spaced literal in production code; a `#Preview`). `SellPlanRow` internal,
  `HStack(alignment: .top)`, the reason line under the category, the market
  line under the value in a trailing `VStack`, still `.combine`d; the list
  passes `summary(for:)`, `rise(for:)`, `loadedAt`. `SellPlanMarketLinesTests`
  (render 4, wiring 4) and the new file in `MarketVocabularyTests.viewFiles`.
  1133 → 1141 in 153, the implementer's verbatim output the verification
  (mechanical phase). **Heights recorded**: plain row 71, with the two lines
  141, `oneLine` 17 — difference 70 against the 34 threshold. **Instrument**:
  the checkbox's located y printed 16 on the healthy render (= `cardPadding`
  × scale 1) before the `.center` mutation was trusted; the dial's ring top
  found by the *track* ink (`divider` — at desire 2 the arc reaches only the
  left flank) at y 15 in both renders, 1 pt above the checkbox because the
  2 pt stroke is centred on the inscribed circle; asserted as equality across
  renders, not against the checkbox. **Mutations red**: the reason line
  dropped → difference 1 < 34; `lineLimit(1)` → 22 < 34 (one line plus the
  5 pt spacing, as the plan predicted); `.center` → checkbox 22/57, ring
  17/52, all three assertions; the label moved to the `HStack` → both halves
  of the placement pin; `Text("on Reverb")` → the vocabulary scan's rule 3.
  Two defaults the bundle left open, taken: the market line's `HStack` is
  `.firstTextBaseline`, spacing 6 (`ItemRow.valueLine`); the row's three new
  properties are required, not defaulted. Finding, for T007: the `.center`
  symptom on the plain row is only 6 px (16 → 22), so the cross-render
  equality is the assertion that carries the mutation, not the `== 16`
  instrument alone.

- [x] **T005 — The seeded UI test, twice.** Plan §6 (the UI half). `TroveUITests.testTheSeededSellPlanRanksRisingFirstAndSaysWhy`: launch `["-uiTesting", "-seedSellPlan"]`; the Wishlist tab → the Summicron's detail → "Find items to sell"; the four candidate buttons, matched by label, with `frame.minY` ascending Telecaster, Blues Junior, Squier, NT1-A; exactly one row's label contains "Asking prices on Reverb are up 12" and it is the Telecaster's; exactly three rows' labels contain "Median asking price" and the Squier's does not. **Instrument once and record in the Done note** whether `sellPlan.market` / `sellPlan.reason` are reachable from XCUITest inside the combined row — the test does not depend on the answer. Files: `TroveUITests/TroveUITests.swift`. Pattern: `testTheFirstFindOnReverbShowsTheNoticeAndNotNowClosesIt` (navigation helpers `openDetail`, `scrollUntilHittable`); `launchApp()` for the argument shape — this test sets its own two arguments and every other test keeps `launchApp()` as it is. **Verify**: `scripts/verify.sh ui` green **twice back to back**, the count line one more than the last green run before this task; every pre-existing UI test still launching with `-uiTesting` alone and green (the empty-collection tests are the mutation for "`-uiTesting` alone seeds nothing"). **Mutations recorded red**: drop the group key from `rank` → this test's order assertion red (G11); seed on `-uiTesting` alone → `testEmptyCollectionOffersImportAndSettingsButNotExport` red. Serves criteria 10 (the combined label read in full), 12 (the UI half).

  *Done (2026-09-06, `sdd-implementer`, first try)*:
  `testTheSeededSellPlanRanksRisingFirstAndSaysWhy` — its own two-argument
  launch (the only `-seedSellPlan` in the target; `launchApp()` untouched),
  the Wishlist tab → the Summicron → "Find items to sell" matched by label
  (`BEGINSWITH`; the button carries no identifier and was given none) → the
  four row buttons matched by `label CONTAINS` the name, adjacent-pair
  `frame.minY` ascending Telecaster, Blues Junior, Squier Classic Vibe,
  NT1-A; the rows whose label contains "Asking prices on Reverb are up 12"
  (matched short of the `%` so U+202F is never spelled in the UI target)
  exactly `["Telecaster"]`; the rows containing "Median asking price"
  exactly `["Telecaster", "Blues Junior", "NT1-A"]`. Implementer's
  `scripts/verify.sh ui` **twice back to back**: `Executed 14 tests, with 0
  failures` both runs (13 → 14; ~227 s a run); unit suite still 1141 in 153.
  **Instrumented once, recorded, then removed**: inside the `.combine`d row
  both identifiers are reachable from XCUITest — `sellPlan.reason` resolves
  to exactly 1 element, `sellPlan.market` to **6, two per matched row**
  (the `HStack` and an inner element inheriting the identifier), so it is
  addressable but is no count of market lines; a comment at the end of the
  test carries the answer. **Mutations red, run by the orchestrator on the
  single-test selector** (XCTest accepts per-function `-only-testing:`;
  the Swift Testing caveat in `verify.sh` does not apply): G11 — the group
  comparison disabled in `rank` → `:611` twice, "Telecaster should be ranked
  above Blues Junior" (441 vs 360) and "Squier Classic Vibe should be ranked
  above NT1-A" (657 vs 576) — both ends, as the seed's values were chosen to
  show; `shouldSeed` reduced to `mode == .ephemeral` →
  `testEmptyCollectionOffersImportAndSettingsButNotExport` `:260` twice
  (both export rows enabled on a collection that should be empty). Both
  reverted; the seeded test green alone afterwards on the final file.
  Tooling finding, for T007: `verify.sh`'s count grep matches "tests" only,
  so a one-test run prints `Executed 1 test` in the raw log but nothing
  under `## counts` and ends with the NO TEST COUNT failure — harmless for
  a mutation check read from the log, wrong for a single-test green.

- [ ] **T004a — Both lines under the category (spec Decision 14).** Added 2026-09-07 at the Phase 2 pause, the person's decision from the seeded row: at phone width the two-column split truncated the category to "MUSIC · GUI…" and stacked the sentence four lines deep beside the market line. `SellPlanRow`'s left `VStack` becomes name, category, `SellPlanMarketLine` (under `if let median = summary?.medianCents`, unchanged), then `SellPlanReasonLine` (under `if let rise`); the right side is the value `Text` alone (the trailing `VStack` goes); `HStack(alignment: .top)`, `.combine`, the three readers and both identifiers unchanged; `SellPlanMarketLines.swift` untouched. `SellPlanMarketLinesTests`' height test restructured per plan §5's amendment: three renders — plain, market line only, both — `both − marketOnly ≥ 2 × oneLine`, and `marketOnly − plain` pinned to one `monoMeta` line plus 5 pt (measure `SellPlanMarketLine` alone for the line); the marks test unchanged. The wiring scan's pins hold as written; the UI test's label assertions hold (order within the combined label changes, `contains` does not care). Files: `Trove/Views/Wishlist/SellPlanView.swift`, `TroveTests/SellPlanMarketLinesTests.swift`. **Verify**: `scripts/verify.sh` green (count unchanged or up; verbatim from the implementer); the three heights and the located marks in the Done note; then the orchestrator's `scripts/verify.sh ui` once (14) and a simulator screenshot of the seeded Telecaster row for the person. **Mutations recorded red**: the reason line dropped → `both − marketOnly` = 0; `lineLimit(1)` on the reason line → under two lines; the market line dropped → `marketOnly − plain` = 0; `.center` → the marks. Reviewed in the pre-merge sweep, not separately — a layout move inside one view after the phase review, at the person's direction.

**Phase 2 review** — one `skeptical-reviewer` pass at its default tier over `git diff <T003's commit>..HEAD` (T004–T005), the two task lines, plan §§5–6 and Q10, criteria 5, 6, 10, 11, 12. Then the **Phase 2 pause** — the person's report; a fresh session resumes at T006.

  *Reviewed (2026-09-06, `skeptical-reviewer`, default tier, over
  `git diff cc17467..HEAD`)*: **signed off, nothing blocking**; six second
  looks, dispositioned by the orchestrator: **S1** (the arrow's spoken half
  — "trending up" — asserted nowhere at runtime, and nothing pinned the row
  passing `trend: summary?.currentTrend`) → fixed: the UI test now asserts
  "trending up" on the Telecaster's row alone and "trending down" on the
  NT1-A's alone (green — plan Q4's claim about the combine confirmed on the
  simulator), and the row-composition scan pins the trend argument (mutation
  `trend: nil` → `:245` red). **S3** (`ringTop` is a locator bounded in
  neither axis, the shape found false twice at sign-off, with its value
  pinned only in prose) → fixed: the test now pins the plain row's ring at
  `cardPadding − 1` (the 2 pt stroke's spill) beside the cross-render
  equality. **S4** (the alignment test's name overstated — it never
  compares the checkbox to the dial) → renamed
  `theMarksStayWhereTheyWereWhenTheRowGainsItsLines`. **S2** (`.lineLimit(1)`
  on the market line, a modifier plan Q4 does not list; a long median could
  truncate invisibly to every test) → **measured, then fixed by the
  orchestrator**: a scratch render of `SellPlanRow` at 360 pt (deleted
  after) read the market line's ideal width as 126 pt for "$1,400 on Reverb"
  and the row with both lines as 141 under `lineLimit(1)` — a right column
  narrower than that ideal, so the seeded Telecaster's *own* figure was
  being cut short beside its sentence, not only a five-figure one; with no
  limit at all the figure wrapped after "on" even on a row with no sentence
  (market line alone: 71 → 87). `fixedSize(horizontal: true, vertical:
  false)` on the figure's `Text` is what the spec's "readable in full" and
  "wrap under their own column" together require: the figure whole at every
  median measured ($1,400 / $14,000 / $140,000 — row unchanged at 72 with
  the market line alone), the sentence wrapping in what it leaves. The
  consequence, for the person at T006: beside a rising row's figure the
  sentence's column is about 75 pt wide at 360 pt, so the row with both
  lines now measures 174 (was 141) — the reason line at five or six short
  lines. Reasoning recorded in the file's doc comment; plan §5 records it
  at T007. **S5** (the two-line floor is red for `lineLimit(1)` but would pass
  `lineLimit(2)`; the healthy 70 pt implies about four lines) → recorded for
  the sweep; the threshold is the one plan §5 chose with its reasoning.
  **S6** (the UI test's comments call the unmatched Squier "neutral") → no
  change: plan Q8 uses exactly that vocabulary (unmatched = neutral, the
  ±5 % band = flat), and criterion 9 says "a neutral rank" for no trend.
  Fix pass verified: unit 1141 in 153 green; the seeded UI test green alone.
  *Re-reviewed (same reviewer, default tier, the findings and the fix diff
  only)*: signed off; S1, S3, S4 closed as claimed; carry-forwards — S2 and
  S5 are one fact seen twice and reach the sweep together (the two-line
  floor cannot discriminate a change S2 might make to the figure's limit);
  the ring pin is bounded in y, still not in x, its "would land elsewhere"
  an inference, not a measurement; S6's decline rests on plan Q8's wording.
  After the `fixedSize` change: `scripts/verify.sh` 1141 in 153 green, the
  render heights now plain 71 / with lines 174 / `oneLine` 17 (the T004
  note's 141 was measured under the truncating limit), the marks at 16/16
  and 15/15 unchanged; `scripts/verify.sh ui` `Executed 14 tests, with 0
  failures`, once more on the final code.

## Phase 3 — Verification and close-out

- [ ] **T006 — The device pass. [person]** On the simulator with the seed (`-uiTesting -seedSellPlan`): the four rows in the seeded order — the Telecaster first at $600 above the Blues Junior's $640, the NT1-A last at $400 below the Squier's $380, so the reordering is visibly the trend's and not the values' — the Telecaster's reason line and moss arrow, the Blues Junior's market line with no arrow, the Squier with no market line, the NT1-A's rust arrow and no sentence; selecting the Telecaster reads "$600" in the combined figure, not $1,400; **a plain row beside a rising one** — the top-hung checkbox and dial (plan Q6) — judged acceptable or not; VoiceOver over the Telecaster's row reading the sentence in full and "Median asking price $1,400, trending up"; the largest accessibility text size turned on, the row unchanged (plan Q10 — the 001 limitation, attested as such). On the person's own device: the plan as it reads today (no trends yet, the market line present on matched items with a current figure, no arrow, no sentence) — criterion 9's "no extra text" and the spec's "At launch" section, attested. **Verify**: the person's word, recorded per item in the Done note; anything unexpected escalated before T007.

- [ ] **T007 — Close-out.** Criteria 1–12 in `spec.md` ticked with a citation each (criterion 8 by `sevenDaysExactlyIsATrendAndASecondLessIsNot` and `fivePercentIsTheBoundaryOnBothSides`; criterion 11 per plan Q10), honest partials named; `plan.md` gains an "As built" section (any deviation, the T005 instrumentation's answer, the tier totals, the closure-with-default `history` injection recorded as the accepted variant for a single store read, and the sentence plan Q9 promised: nothing new is stored or sent, so `PRIVACY.md` is unchanged); README's Sell Plan bullet gains one sentence; the tier log below totalled and compared against 002's; `scripts/verify.sh` and `scripts/verify.sh ui` green, the UI suite twice; then the **pre-merge sweep** — the `skeptical-reviewer` at its default tier over `spec.md`, `plan.md`, `tasks.md` and `git diff main...HEAD`, its findings dispositioned here; the PR marked ready and merged with a merge commit; the post-merge `fix/docs-003-shipped` branch for `specs/ROADMAP.md` (the 003 entry and status row; the two "Not in this plan" observations — the list rows' stale arrows and the fixed-size type — recorded for the person) and `DECISIONS.md` if anything belongs there. **Verify**: every box above checked; the sweep's disposition recorded; both suites green; `ROADMAP.md` (the 003 entry and status row; a new future entry for Dynamic Type, spec Decision 11; the list-row stale-arrow follow-up as a `fix/` candidate, Decision 12) no longer lists this spec's work as future.

---

## Handoff note

Once this file is signed off (product-owner involvement level: Plan Mode plus the `skeptical-reviewer` is the gate, the person receives the spec-conformance summary), hand it to the orchestrator with:

> Read `CLAUDE.md`, then `specs/003-trend-aware-sell-plan/spec.md`, `plan.md` and `tasks.md`, and begin at the first unchecked task. Involvement level is **product owner**. Dispatch each task to the `sdd-implementer` on a task bundle assembled with shell (task line, plan sections, acceptance criteria, files, the pattern file), telling it not to read the three documents in full; verify with `scripts/verify.sh` — re-run by you in Phase 1, taken verbatim from the implementer in Phase 2 — then commit. One review and at most one re-review per invocation. **Phase 1 is foundational**: have the `skeptical-reviewer` review after each of T001–T003, scoped to that task's staged diff and the plan section it implements, at its default tier. From Phase 2 onward, review after the phase instead. Pause for me after each phase, and whenever something unexpected bears on spec adherence; T006 is mine.

Each phase pause is also a session boundary: start the next phase in a fresh session, resuming from the first unchecked task, so the orchestrator's context doesn't carry the whole spec.

Every pause produces a report in this shape, in this order:

1. **Why this pause** — a phase boundary, a spec-adherence question, or an escalation trigger. One line.
2. **What you can now do** — behaviour that exists and can be tried, stated as a user would experience it, so attestation is possible.
3. **Where execution deviated from the spec, and why** — every place, never silently.
4. **What needs your decision** — product questions only.

## Tier log

The constitution's model policy (amended 2026-09-06) decides which tier runs each invocation. Every planner dispatch, implementer run and reviewer invocation is logged here with its tokens, plus any escape-hatch miss; the total is compared against 002's (~2.97M implementer, ~1.43M reviewer over 29 tasks, before the loop cap and the bundles) at close-out. The third tier is off.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| Planning: draft (`sdd-planner`) | fable | 191,974 | plan.md + tasks.md drafted; foundational phase 1 |
| Planning: sign-off, round 1 | fable (`skeptical-reviewer`) | 111,527 | fix and re-review — B1, B2 (two G7 render guards that could not go red), N1–N7 |
| Planning: sign-off, round 2 | fable (`skeptical-reviewer`) | 34,428 | B2, N4, N6 resolved; B1 still open (the left border) → fixed by the orchestrator directly and logged, not sent around a third time |
| *Superseded: in-session plan draft, sign-off rounds 1–2* | fable (`skeptical-reviewer`) | 81,575 + 38,400 | the drafts these planner drafts replace; their catches carried forward through the planning bundle |
| *Superseded: in-session tasks draft, sign-off rounds 1–2* | fable (`skeptical-reviewer`) | 56,584 + 36,920 | as above |
| T001 | opus (`sdd-implementer`) | 97,380 | verified first try; six mutations red as planned |
| T001 review | opus (`skeptical-reviewer`) | 53,200 | signed off; scope matched the bundle plus one locale grep |
| T002 | opus (`sdd-implementer`) | 83,167 | verified first try; five mutations red as planned |
| T002 review | opus (`skeptical-reviewer`) | 50,593 | signed off; scope matched the bundle exactly |
| T003 | opus (`sdd-implementer`) | 86,841 | verified first try; reviewer: fix and re-review |
| T003 review | opus (`skeptical-reviewer`) | 43,485 | fix and re-review — B1 (the wrong mutation for the call-site guard), B2 (same-context refetch), S1–S4 |
| T003 fix pass | opus (`sdd-implementer`) | 49,749 | both mutations red for the right reason; tests only changed |
| T003 re-review | opus (`skeptical-reviewer`) | 19,832 | signed off |
| T004 | opus (`sdd-implementer`) | 96,658 | verified first try; five mutations red as planned; the instrument printed 16 before the `.center` red was believed |
| T005 | opus (`sdd-implementer`) | 65,116 | verified first try; UI suite 14 twice; the two UI mutations run red by the orchestrator |
| Phase 2 review | opus (`skeptical-reviewer`) | 81,819 | signed off, nothing blocking; S1, S3, S4 fixed by the orchestrator, S2 → T006/T007, S5 → sweep, S6 declined (plan Q8's vocabulary) |
| Phase 2 re-review | opus (`skeptical-reviewer`) | 22,894 | signed off; S2 then settled by the orchestrator's own measurement (`fixedSize`), no third round |

## Skeptical-review record (this decomposition)

To be filled at sign-off.

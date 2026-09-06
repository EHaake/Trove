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

- [ ] **T001 — Comparison, rise, the summary's current trend, and the copy.** Plan §§1, 2, 4; Q2, Q3, Q5. `MarketTrend.Comparison` and `comparison(history:)`, `compute` re-expressed as `comparison(history:)?.trend`; `Comparison.percent` with the exact-integer numerator before the one division, `.rounded()` half away from zero; `MarketRise` and its failable `init(comparison:)`; `MarketSummary.currentTrend`; `MarketCopy.sellPlanMarketLine(medianCents:)` and `sellPlanReason(percent:since:now:)` (U+202F before the `%`; `en_US` month-day; the year appended only when `Calendar.current`'s year of `since` differs from `now`'s). Files: `Trove/Market/MarketTrend.swift`, `Trove/Market/MarketIndex.swift`, `Trove/Models/MarketCopy.swift`; tests in `TroveTests/MarketTrendTests.swift`, `MarketIndexTests.swift`, `MarketCopyTests.swift`, `MarketVocabularyTests.swift`. Pattern: `MarketTrend.compute` itself (integer arithmetic, the most-recent qualifying previous); `MarketCopyTests`' whole-string pins; `MarketIndexTests.value(median:at:)` for a record with a stored trend. **Verify**: `scripts/verify.sh` green with the count up; the existing `MarketTrendTests` untouched and green (plan G10); the tests plan §§1, 2, 4 name present — the whole `Comparison` pinned for 20 d / 8 d / 1 d, `percent` for 1000→1050/1124/1125/1145/950/850/1049 and 4000→4700, `MarketRise` nil for `.flat` and `.down` and populated for `.up`, `currentTrend` nil on a 31-day-old `.up` and on a withheld `.up`, both copy strings whole, the year rule by calendar year, both strings passing `fires`. **Mutations recorded red**: pick the oldest previous; take the date from one point and the median from another; divide first (1000→1145 → 14 — the only pin that discriminates); drop the freshness gate on `currentTrend`; compare the year by interval. Serves criteria 5 (the numbers), 6 (the gate), 8 (by construction), 10 (vocabulary).

- [ ] **T002 — The ranking, and the view model's market readers.** Plan §3; Q1, Q2, Q7. `SellPlanRanking.rank(_:_:trend:)` and `group(of:)` (MainActor, not `nonisolated`); `candidates(from:alreadySelected:trend:)` with `trend` defaulting to `{ _ in nil }` so the 001 suites compile untouched; `SellPlanViewModel.init(..., now:, history:)` with the closure-with-default `history`; `loadedAt`; `marketSummaries` assigned right after the item fetch and **before** the sort; `rises` for the rising candidates only, dropped unless the history's own comparison is `.up`; `summary(for:)`, `rise(for:)`, `currentTrend(for:)`; every local-store read `try?`; the `catch` clears the new state too. New identifiers stay clear of `SellPlanFramingTests`' terms (the file is scanned). Files: `Trove/ViewModels/SellPlanViewModel.swift`; tests in `TroveTests/SellPlanViewModelTests.swift` (a new `SellPlanRankingTests` suite and the view-model cases in plan §3). Pattern: `ItemListViewModel.load()`'s summaries line and its `now` injection; `TroveStore.make(recreateLocalStore:)` for the closure default; `MarketIndexTests` for writing figure rows through `MarketLocalStore.record` into `makeInMemoryContainer()`. **Verify**: `scripts/verify.sh` green; `SellPlanCandidateTests`, `SellPlanSelectionTests`, `SellPlanFiguresTests`, `SellPlanFramingTests`, `SellPlanEmptyReasonTests` untouched and green (plan G10); the plan §3 tests present — criteria 1–4 as pure tests, the two-pair G2, the integration through `load()` with rows in the local store, the stale and the withheld fixtures, the throwing `history` closure (no rises, every candidate still listed, no failure message), `selectedValueCents` ignoring the median. **Mutations recorded red**: group key ahead of desire (G1); nil before flat and flat before nil (G2, one pair each); `marketSummaries` assigned after the sort (G3); the median summed (G5). Serves criteria 1, 2, 3, 4, 6, 7, 9.

- [ ] **T003 — The seed.** Plan §6 (the unit half); Q8. `Trove/App/UITestSeed.swift`: `argument`, `shouldSeed(mode:arguments:)` true only for `.ephemeral` with `-seedSellPlan`; `sellPlan(into:now:)` — the Summicron ($2,400), and at desire 2 the Telecaster (**$600**, `reverbProductID` 126161, two `MarketLocalStore.record` calls: $1,250 at −14 d, then $1,400 at `now`), the Blues Junior ($640, matched, $600 → $600), the Squier Classic Vibe ($380, unmatched, no market rows), the NT1-A (**$400**, matched, $200 → $170) — values chosen so value alone orders Blues Junior, Telecaster, NT1-A, Squier and only the trend key gives Telecaster, Blues Junior, Squier, NT1-A; every market row written through `MarketLocalStore.record`, never constructed directly; one `save()` at the end. `TroveApp.init`: one call, `if UITestSeed.shouldSeed(mode: store.mode, arguments: ProcessInfo.processInfo.arguments)`, after the store is built, over `store.container.mainContext`, a failure → `fatalError`; `"-uiTesting"` still read in exactly one place and `"-seedSellPlan"` absent from `TroveApp.swift`. Files: `Trove/App/UITestSeed.swift` (new), `Trove/App/TroveApp.swift`; tests in `TroveTests/UITestSeedTests.swift` (new). Pattern: `ItemDetailViewModelTests.seed(median:at:in:)` and `MarketIndexTests.reading(median:at:)` for a `MarketReading.figure` fed to `MarketLocalStore.record`; `ItemDetailViewModelTests.world(productID:)` for an `Item` with `reverbProductID`; `TroveStore.make(isUITesting: true)` for the container the test builds through; `MarketLocalSchemaTests` for a scan over `TroveApp.swift`. **Verify**: `scripts/verify.sh` green; `shouldSeed` false for `.ephemeral` + `[]`, `.ephemeral` + `["-uiTesting"]`, `.cloudKit` and `.localOnly` + both flags, true for `.ephemeral` + both flags; the seed through `TroveStore.make`'s container yields 4 owned, 1 wanted, 3 matched items, 3 snapshots, 3 figure records fetched at `now`, 6 points, every record's trend equal to `compute(history)` and to `up`/`flat`/`down` as seeded; the writer-only scan over `UITestSeed.swift`; a `SellPlanViewModel` over the seeded context orders Telecaster, Blues Junior, Squier, NT1-A with a +12 % rise for the Telecaster only; the scan on `TroveApp.swift` (one `UITestSeed.sellPlan(` call inside the `shouldSeed(mode: store.mode` block; `"-uiTesting"` once; `"-seedSellPlan"` absent). **Mutations recorded red**: gate on the arguments alone (G8); a seed call outside the `shouldSeed` guard (G8's call-site half); the Telecaster's second `record` replaced by a direct `MarketFigureRecord` insert carrying `"flat"` (G9, both halves); a second `"-uiTesting"` literal in `TroveApp.swift`; drop the group key from `rank` → the seeded order becomes Blues Junior, Telecaster, NT1-A, Squier. Serves criterion 12 (the unit half).

Before the pause: one `scripts/verify.sh ui` run (the count line read: the same count as the last green UI run), since T003 touched the launch path every UI test goes through — recorded in T003's Done note.

**Phase 1 pause** — the person's report; a fresh session resumes at T004.

## Phase 2 — The screen (mechanical: one per-phase review)

- [ ] **T004 — The two lines, and the row that composes them.** Plan §5; Q4, Q6, Q10. `Trove/Views/Market/SellPlanMarketLines.swift` (new): `SellPlanMarketLine(medianCents:trend:)` — the `Text` in `monoMeta`/`textQuiet` carrying `.accessibilityLabel(MarketCopy.figureAccessibilityLabel(medianCents:))` **on the `Text`**, `TrendArrow(trend:)` after it, identifier `sellPlan.market`; `SellPlanReasonLine(rise:now:)` — `secondary`/`textQuiet`, `lineLimit(nil)`, `fixedSize(horizontal: false, vertical: true)`, identifier `sellPlan.reason`; no string literal containing a space in the file's production code (a `#Preview` is outside the scan). `SellPlanRow` internal, `HStack(alignment: .top)`, the reason line under the category, the market line under the value in a trailing-aligned column, still `.combine`d, built from `summary: viewModel.summary(for:)`, `rise: viewModel.rise(for:)`, `now: viewModel.loadedAt`. Files: the new file, `Trove/Views/Wishlist/SellPlanView.swift`; tests in `TroveTests/SellPlanMarketLinesTests.swift` (new: render and wiring), the file added to `MarketVocabularyTests.viewFiles`. Pattern: `TrendArrow.swift` and `TrendArrowRenderTests` (ink within ΔE of the token; width/height comparisons with a control), `DesireGaugeTests` (sampling the dial's ramp colour), `MarketWiringTests` (`SourceScan` composition pins). **Verify**: `scripts/verify.sh` green (the implementer's verbatim output is the verification in this phase); the render tests — `.up` draws `accentMossText` ink, `nil` none in either arrow tone; a row with a summary and a rise (a sentence that cannot fit one line at 360 pt) taller than without by at least twice one `secondary` line-height (plan §5, the one threshold that goes red for both the dropped line and `lineLimit(1)`); the checkbox's top edge — found as the topmost y of a brass block at least 10 px tall in at least 10 adjacent columns within the left 40 pt, which neither edge of the 1 pt card border can satisfy; the located y printed on the healthy render and equal to 16 pt × the bitmap scale **before** the `.center` mutation is trusted (plan §5) — and the dial's ring top edge at the same y in both renders; the three heights (plain row, row with the lines, `oneLine`) recorded in the Done note; the wiring scan — both views composed, the three readers passed, both identifiers, the label inside the `Text(` chain, the row still `.combine`d; the vocabulary scan green over the new file (the no-spaced-literal rule's one home). **Mutations recorded red**: the reason line dropped from the row (difference under one line); `lineLimit(1)` (difference under two lines); `.center` alignment (the plain row's checkbox run starts lower); the label moved from the `Text` to the `HStack`; a spaced literal in the file's production code. Serves criteria 5, 6, 10, 11 (per plan Q10: wrap-not-truncate and alignment; the size setting itself changes nothing in this app).

- [ ] **T005 — The seeded UI test, twice.** Plan §6 (the UI half). `TroveUITests.testTheSeededSellPlanRanksRisingFirstAndSaysWhy`: launch `["-uiTesting", "-seedSellPlan"]`; the Wishlist tab → the Summicron's detail → "Find items to sell"; the four candidate buttons, matched by label, with `frame.minY` ascending Telecaster, Blues Junior, Squier, NT1-A; exactly one row's label contains "Asking prices on Reverb are up 12" and it is the Telecaster's; exactly three rows' labels contain "Median asking price" and the Squier's does not. **Instrument once and record in the Done note** whether `sellPlan.market` / `sellPlan.reason` are reachable from XCUITest inside the combined row — the test does not depend on the answer. Files: `TroveUITests/TroveUITests.swift`. Pattern: `testTheFirstFindOnReverbShowsTheNoticeAndNotNowClosesIt` (navigation helpers `openDetail`, `scrollUntilHittable`); `launchApp()` for the argument shape — this test sets its own two arguments and every other test keeps `launchApp()` as it is. **Verify**: `scripts/verify.sh ui` green **twice back to back**, the count line one more than the last green run before this task; every pre-existing UI test still launching with `-uiTesting` alone and green (the empty-collection tests are the mutation for "`-uiTesting` alone seeds nothing"). **Mutations recorded red**: drop the group key from `rank` → this test's order assertion red (G11); seed on `-uiTesting` alone → `testEmptyCollectionOffersImportAndSettingsButNotExport` red. Serves criteria 10 (the combined label read in full), 12 (the UI half).

**Phase 2 review** — one `skeptical-reviewer` pass at its default tier over `git diff <T003's commit>..HEAD` (T004–T005), the two task lines, plan §§5–6 and Q10, criteria 5, 6, 10, 11, 12. Then the **Phase 2 pause** — the person's report; a fresh session resumes at T006.

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

## Skeptical-review record (this decomposition)

To be filled at sign-off.

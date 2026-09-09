# 004 — Light mode: Tasks

**Status**: Approved 2026-09-09 — `skeptical-reviewer` signed off (B1 fixed and re-reviewed clean) and the person's technical-lead sign-off given. Begin at T001.
**Implements**: plan.md in this directory
**Foundational phases**: 1 — per-task reviewer cadence (both tasks). Phase 2 is per-phase, with **T003 marked `review: per-task`** (root wiring the whole app inherits). Phase 3 is the person's pass and the close-out.

Drafted 2026-09-09 by the `sdd-planner` against the draft `plan.md` in
this directory, on branch `004-themes` (the base commit is recorded by
the orchestrator when this file is committed). No new technical
decisions are made here — every task traces to a plan section; where a
task says "per plan," that section is the authority. The plan's §9 gave
the shape; this document is the shape with its Verify criteria, its
packet contents and its cadence.

<!-- Once implementation starts, this file gets written by more than one
party — whoever's steering adds scope and reshuffles tasks; the
orchestrating session (never the sdd-implementer subagent) checks boxes
and adds findings. Never edit this file from a stale copy. Prefer small,
targeted edits over regenerating it wholesale. -->

Ordering note: the palette first, because everything renders through it
and its perceptual guarantees are the derivation loop (values are tuned
until the ΔE floors pass — the `001` method); then the choice, store and
resolver, which only need `Theme.light` to exist. The wiring follows once
both exist: the root, then the Settings control, then the UI test that
stands on both. No `.pbxproj` edit anywhere: new files land through the
synchronized root groups.

House rules carried over: one commit per completed task, referencing the
task ID, made by the orchestrator after its own verification; every
guard test is **mutation-verified** (break the rule deliberately, confirm
red) before it lands, and the task's Done note records what was broken and
what went red; **`scripts/verify.sh` is the verification** — the unit
suite per task, `scripts/verify.sh ui` at the Phase 1/Phase 2 boundary
once (T003 touched the launch path) and at T005 and T007 twice back to
back — with the count line read, never just the banner; no test opens a
network connection. Tasks marked **[person]** block on something only the
person has.

## Cadence (the constitution's model policy)

- **Phase 1 is foundational**: each task is dispatched to the
  `sdd-implementer` on a task bundle assembled with shell (task line,
  plan sections, acceptance criteria, files, the pattern file), with the
  instruction not to read `plan.md`, `spec.md` or `tasks.md` in full; on
  return the orchestrator re-runs `scripts/verify.sh` itself, stages
  (`git add -A`), cuts a review bundle from the diff, and invokes the
  `skeptical-reviewer` at its default tier. **One review and at most one
  re-review per task.**
- **Phase 2 is mechanical**: the implementer's verbatim `scripts/verify.sh`
  output is the verification; one per-phase review at the reviewer's
  default tier — **except T003**, marked `review: per-task`, whose staged
  diff the orchestrator re-runs and reviews on its own before T004.
- **Phase 3** is the person's device pass and the close-out, ending in the
  pre-merge sweep at the reviewer's default tier over the three documents
  plus `git diff main...HEAD`.
- **The person pauses** after each phase, with the four-part report, and
  whenever something unexpected bears on spec adherence. **A fresh
  orchestrator session starts at each phase pause**, resuming from the
  first unchecked task here.
- **Escape hatch**: two failed verifications on one task, or a "stopped on
  a judgment call" the orchestrator considers well-specified → the
  orchestrator does the task itself and logs the miss.

## Phase 1 — Foundations (foundational: per-task review)

- [x] **T001 — The light palette, its pins, and the re-earned guarantees.** Plan §§2, 3; Q3, Q4. Derive `ThemeColors.light` for a light ground by the Oklab method in `design/tokens.md`, keeping the brass/moss/rust identity; record the values as a light column in `design/tokens.md` **before** pinning them; add `Theme.light = Theme(colors: .light, typography: .standard, metrics: .standard)`; make `ThemeMetrics` and `ThemeTypography` `Equatable` (additive). Add `renderBitmap(_:theme:)` with `theme:` defaulting to `.dark` (every existing render caller unchanged). Files: `Trove/Views/Shared/Theme/ThemeColors.swift`, `Theme.swift`, `ThemeTypography.swift`, `ThemeMetrics.swift`, `design/tokens.md`; `TroveTests/TestSupport.swift`; tests in `TroveTests/ThemeTests.swift` (a new `LightThemeColorTokenTests` and the shared-composition guard), `DesireDialTests.swift` (`LightDesireDialColorTests`, `LightPaletteContrastTests`), `DesireGaugeTests.swift` (`LightDesireGaugeColorTests`), `TrendArrowRenderTests.swift` (a light suite). Pattern: `ThemeColorTokenTests` (independent channel-literal pins), `DesireDialColorTests`/`DesireGaugeColorTests`/`TrendArrowRenderTests` (the same suites against `.dark`), `design/tokens.md`'s dark ramp derivation. **Verify**: `scripts/verify.sh` green with the count up; every dark suite (`ThemeColorTokenTests`, `DesireDialColorTests`, `DesireGaugeColorTests`, `TrendArrowRenderTests`) **untouched and green** (criterion 1); the light suites present and green — light tokens pinned as independent channel literals, `Theme.light.metrics == Theme.dark.metrics` and typography equal, light dial adjacent-stop ΔE > 0.06 and no stop nearer brass than its neighbours, light numeral ≥ 3:1 on light surface while raw accents stay below, light text tokens clear WCAG on the light ground, light gauge tones distinguishable at row size, light trend arrows drawing the lifts. **Mutations recorded red**: a flipped digit in a light token or its pin (G3); `Theme.light` given non-`.standard` metrics (G4); two light dial stops equalised and one pulled toward brass (G5); a light lift set equal to its shape colour (G6); two light gauge tones collapsed (G7); a light arrow drawn in the raw accent (G8). **If the contrast split proves unsatisfiable** — a mid-tone accent that naturally clears 3:1 as text on the near-white surface, so it cannot stay shape-only while its lift also clears the bar — **escalate rather than lowering the ΔE/contrast floor** (sign-off second look; the floor is the derivation target, not a knob). Serves criteria 1, 2, 7, 8, 9 (the pins). **`review: per-task`** — the palette a dozen screens inherit.

  - _Done 2026-09-09._ `ThemeColors.light` derived by the Oklab method, recorded in `design/tokens.md`'s light column before pinning; `Theme.light` (shared `.standard` typography/metrics), `Equatable` on both; `renderBitmap(_:theme:)` defaulted `.dark`. Verify green — 1175 tests / 159 suites (orchestrator re-run). Dark suites untouched and green (criterion 1). Mutations red: G3 (flip a light token/pin digit → `LightThemeColorTokenTests`), G4 (`Theme.light` given `screenGutter: 999` → `ThemeCompositionTests.lightSharesDarksMetrics`), G5 (equalise two stops → `noTwoAdjacentLevelsLookAlike`; pull midpoint toward brass → `noStopIsMoreConfusableWithBrass…`), G6 (`accentMossText := accentMoss` → `LightPaletteContrastTests` numeral leg), G7 (`accentBrassMid := accentBrassDim` → `LightDesireGaugeColorTests` adjacent-tone), G8 (arrow drawn in raw accent → `LightTrendArrowRenderTests`). Contrast split satisfiable (raw rust/moss 2.7:1 < 3:1; lifts clear) — no escalation. **For the person's phase-pause attestation:** on the light ground `accentBrass` runs deep bronze-gold and `dialMidpoint` dark olive-green (to keep a legible money-brass from colliding with the dial midpoint) — passes the brass-proximity guarantee but the visual read is the person's; the plate alphas and `gaugeTrack` for light are pinned but not perceptually tested (provisional, in tokens.md). Reviewer signed off, no blocking findings.

- [x] **T002 — The appearance choice, resolver and store.** Plan §1; Q1, Q2. `AppearanceChoice: String, CaseIterable, Sendable` with `displayName` and **no SwiftUI import**; `AppearanceChoice+Theme.swift` with `preferredColorScheme` and `resolvedTheme(systemColorScheme:)` (an explicit choice ignores the system scheme; only `.system` reads it); `AppearanceStore` (`@Observable`) over `UserDefaults`, reading synchronously at init, defaulting `.dark`, persisting in `didSet`. Files: `Trove/Models/AppearanceChoice.swift` (new), `Trove/Views/Shared/Theme/AppearanceChoice+Theme.swift` (new), `Trove/App/AppearanceStore.swift` (new); tests in `TroveTests/AppearanceChoiceTests.swift` (new), `AppearanceStoreTests.swift` (new). Pattern: `SyncMonitor` for the app-level `@Observable` shape; `AppearanceStoreTests` builds its own `UserDefaults(suiteName:)` and clears it (the persistence-check discipline `TestSupport`'s `makeInMemoryContainer` note describes — a **second** store over the same suite is the read). **Verify**: `scripts/verify.sh` green; `preferredColorScheme` for all three; `resolvedTheme` — explicit cases ignore `colorScheme`, `.system` follows it — asserted via a token that differs between the palettes; `displayName` whole; the store defaults `.dark`, round-trips `.light` through a second store, reads `.dark` for an unrecognised string, and an isolated suite does not see `.standard`; a source scan confirms `AppearanceStore.swift` names no `NSUbiquitousKeyValueStore` or CloudKit/ubiquitous symbol — criterion 5's does-not-sync half, hardened at sign-off (spec Decision 4). **Mutations recorded red**: an explicit case made to read `colorScheme`, and the `.system` branch inverted (G1); the store default changed and `persist()` dropped from `didSet` (G2); `AppearanceStore.swift` made to reference `NSUbiquitousKeyValueStore` → the sync scan red (G13). Serves criteria 3 (the mapping), 4 (the store the root observes), 5, 6.

  - _Done 2026-09-09._ `AppearanceChoice` (model, Foundation only, `displayName`); `AppearanceChoice+Theme` (`preferredColorScheme`; `resolvedTheme` — explicit cases ignore the system scheme, only `.system` reads it); `AppearanceStore` (`@Observable`, `UserDefaults`, synchronous init, default `.dark` on absent/unrecognised, `persist()` in `didSet`, no ubiquitous/CloudKit). Verify green — 1184 tests / 161 suites (orchestrator re-run). Mutations red: G1a (`.light` reads `colorScheme` → `explicitLightIgnoresTheSystemScheme`), G1b (invert `.system` branch → `systemFollowsTheSystemScheme`), G2a (default `.system` → `aFreshSuiteReadsDark` + `anUnrecognisedStoredStringReadsDark`), G2b (drop `persist()` → `theChoicePersistsIntoASecondStore`, confirming the second-store read is a real persistence check), G13 (wire `NSUbiquitousKeyValueStore` → `theStoreNamesNoUbiquitousOrCloudKitSymbol`). Reviewer signed off, no blocking findings. **Carried to T003:** the `"appearanceChoice"` `UserDefaults` key is duplicated (private in the store, re-declared in the test) — T003 wants a single public accessor so the unrecognised-string test can't go vacuously green if the key ever drifts.

Before the pause: nothing to run beyond `scripts/verify.sh` — no launch-path change lands until T003. **Phase 1 pause** — the person's report; a fresh session resumes at T003.

## Phase 2 — Wiring and the control (mechanical: one per-phase review; T003 per-task)

- [ ] **T003 — Root wiring.** Plan §§4, 7; Q5, Q8. `ThemedRoot` (new) applying `.environment(\.theme, choice.resolvedTheme(systemColorScheme:))` and `.preferredColorScheme(choice.preferredColorScheme)` from the injected `AppearanceStore`; `TroveApp` builds one `AppearanceStore` (an isolated `UserDefaults` suite when the built store's mode is `.ephemeral` — structural, on `store.mode`, never a second read of the flag), wraps `ContentView` in `ThemedRoot`, injects `.environment(appearanceStore)`, and drops the hardcoded `.environment(\.theme, .dark)` and `.preferredColorScheme(.dark)`; `ContentView` untouched. Files: `Trove/Views/Shared/Theme/ThemedRoot.swift` (new), `Trove/App/TroveApp.swift`, `Trove/App/AppearanceStore.swift` (the isolated-suite initialiser if not already there); tests in `TroveTests/ThemeWiringTests.swift` (new). Pattern: `SettingsWiringTests`/`SourceScan` for the app-file scans; `UITestSeed.shouldSeed(mode:…)` for the structural `store.mode` gate. **Verify**: `scripts/verify.sh` green (orchestrator re-runs it — `review: per-task`); `TroveApp.swift` wraps `ContentView` in `ThemedRoot(`, injects `.environment(appearanceStore)`, and contains no `.preferredColorScheme(.dark)` and no `.environment(\.theme, .dark)`; `ThemedRoot.swift` drives both modifiers from `appearanceStore.choice` (the resolver and `preferredColorScheme`); the isolation gate keyed on the ephemeral store. **Mutations recorded red**: `.preferredColorScheme(.dark)` left in `TroveApp` (G9); `ThemedRoot` hardcoding `.dark`/`.environment(\.theme, .dark)` (G9). Serves criteria 3, 4 (the wiring half; the live/no-relaunch behaviour is the device pass). **`review: per-task`.**

- [ ] **T004 — The Settings Appearance control, the hosts, and the PDF guard.** Plan §§5, 6; Q6, Q7. `SettingsView` gains `@Bindable var appearanceStore: AppearanceStore` and an `appearanceSection` (`DetailSection(title: "Appearance")`, a `.pickerStyle(.segmented)` `Picker` over `AppearanceChoice.allCases` bound to `$appearanceStore.choice`, labels from `displayName`), composed **first**; the three hosts read `@Environment(AppearanceStore.self)` and thread it in. Files: `Trove/Views/Settings/SettingsView.swift`, `Trove/Views/Items/ItemListView.swift`, `Trove/Views/Wishlist/WishlistView.swift`, `Trove/Views/Dashboard/DashboardView.swift`; tests in `TroveTests/SettingsWiringTests.swift` (extended), `ThemeWiringTests.swift` (the PDF guard). Pattern: `SettingsWiringTests.theScreenAttachesTheSettingsSheetAndReloadsOnDismiss` (the host threading + arg scan), `theSectionsAppearInSpecOrder` (composition-order scan), `MenuPolicyTests`. **Verify**: `scripts/verify.sh` green (implementer's verbatim output — mechanical phase); every host passes `appearanceStore:` to `SettingsView` and reads it from the environment; `SettingsView` composes `appearanceSection` first, the picker `.segmented` and bound to the store over `allCases`, no typed appearance literal in the view; `MenuPolicyTests` green; `SettingsViewModel` and its tests untouched; `PDFComposer.swift` references no theme/appearance symbol and the existing PDF tests green. **Mutations recorded red**: the `appearanceStore:` arg dropped from a host (G10); the section not composed first / absent (G10); `.pickerStyle(.menu)` → `MenuPolicyTests` red (G10); `PDFComposer.swift` reading a `ThemeColors` token (G11). Serves criteria 2 (presence), 10.

- [ ] **T005 — The appearance UI test, twice.** Plan §7. `TroveUITests.testAppearanceControlDefaultsToDarkAndOffersThreeChoices`: launch `-uiTesting`; open Settings from a list; the Appearance segmented control shows System / Light / Dark with **Dark** selected; tapping Light leaves Light selected. Files: `TroveUITests/TroveUITests.swift`. Pattern: an existing UI test's `openSettings`/navigation helpers and `launchApp()` argument shape. **Verify**: `scripts/verify.sh ui` green **twice back to back**, the count one more than the last green run; every pre-existing UI test still launching `-uiTesting` alone and green (they start Dark — the isolation working). **Mutations recorded red**: the store default changed to `.system`/`.light` → this test's "Dark selected" red (G12). Serves criteria 2, 6 (the UI halves).

**Phase 2 review** — after T005: one `skeptical-reviewer` pass at its default tier over the T004–T005 diff (`git diff <T003's commit>..HEAD`; T003 was reviewed on its own as `review: per-task`, so the phase review covers T004 and T005), the task lines, plan §§4–7 and Q5–Q8. Criteria the diff carries directly: **2, 6, 10** (T004/T005's own); criteria **3, 4** as context — their wiring half is T003's (reviewed per-task) and T004's host threading, so plan §§4–7 stand in for the parts not in this diff. Then the **Phase 1/Phase 2 boundary run** and the **Phase 2 pause**: the orchestrator runs `scripts/verify.sh ui` once after T003 lands (the launch path gained a branch), and after T005 twice; the person's report; a fresh session resumes at T006. (Reconciled with the handoff note at sign-off, 2026-09-09 — B1: the review runs after T005 and covers both wiring tasks, so no task escapes it.)

## Phase 3 — Verification and close-out

- [ ] **T006 — The device pass. [person]** On the simulator and/or device: set Appearance to **Dark** and confirm every screen looks exactly as today (criterion 1); set **Light** and walk every screen — surfaces and dividers distinguishable, text legible, no element disappearing or clashing, the dial/gauge/trend arrows on-brand on the light ground (criteria 2, 7's look, 8); set **System** and flip the device's own light/dark setting, confirming the app follows live with no relaunch (criterion 3); change the choice in Settings and confirm the whole app and the system chrome (keyboard, pickers, selection) change immediately (criterion 4). **Verify**: the person's word, recorded per criterion in the Done note; anything unexpected escalated before T007.

- [ ] **T007 — Close-out.** Criteria 1–10 in `spec.md` ticked with a citation each (criterion 5's persistence by `AppearanceStoreTests`, its per-device half by the same; criteria 3/4's live behaviour by the device pass named honestly beside the resolver/wiring tests); `design/tokens.md`'s light column finalised to the shipped values; `plan.md` gains an "As built" section (any deviation, the tier totals, the light values, and Q9's sentence: nothing new is sent and the stored choice never leaves the device, so `PRIVACY.md` is unchanged); README gains one sentence; the tier log below totalled and compared against `002`'s and `003`'s; `scripts/verify.sh` and `scripts/verify.sh ui` green, the UI suite twice; then the **pre-merge sweep** — the `skeptical-reviewer` at its default tier over `spec.md`, `plan.md`, `tasks.md` and `git diff main...HEAD`, its findings dispositioned here; `specs/ROADMAP.md` updated on this branch (the `004` entry and status row); the PR marked ready and merged. **Verify**: every box above checked; the sweep's disposition recorded; both suites green; `ROADMAP.md` no longer lists this spec's work as future.

---

## Handoff note

Once this file is signed off (product-owner involvement level: Plan Mode plus the `skeptical-reviewer` is the gate; the person receives the spec-conformance summary), hand it to the orchestrator with:

> Read `CLAUDE.md`, then `specs/004-themes/spec.md`, `plan.md` and `tasks.md`, and begin at the first unchecked task. Involvement level is **product owner**. Dispatch each task to the `sdd-implementer` on a task bundle assembled with shell (task line, plan sections, acceptance criteria, files, the pattern file), telling it not to read the three documents in full; verify with `scripts/verify.sh` — re-run by you for the `review: per-task` tasks (T001, T002, T003), taken verbatim from the implementer otherwise — then commit. One review and at most one re-review per invocation. **Phase 1 is foundational**: review after each of T001–T002 at the reviewer's default tier, scoped to that task's staged diff and its plan section. In Phase 2, review T003 on its own (it is `review: per-task`), then review T004–T005 as the phase. Run `scripts/verify.sh ui` once after T003 lands and twice at T005/T007. Pause for me after each phase, and whenever something unexpected bears on spec adherence; T006 is mine.

Each phase pause is also a session boundary: start the next phase in a fresh session, resuming from the first unchecked task, so the orchestrator's context doesn't carry the whole spec.

Every pause produces a report in this shape, in this order:

1. **Why this pause** — a phase boundary, a spec-adherence question, or an escalation trigger. One line.
2. **What you can now do** — behaviour that exists and can be tried, stated as a user would experience it, so attestation is possible.
3. **Where execution deviated from the spec, and why** — every place, never silently.
4. **What needs your decision** — product questions only.

## Tier log

The constitution's model policy decides which tier runs each invocation. Every planner dispatch, implementer run and reviewer invocation is logged here with its tokens, plus any escape-hatch miss; the total is compared against `002`'s and `003`'s at close-out. This is the **third** spec's log under the amended policy. The third (lighter-implementer) tier is off.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| Planning: draft (`sdd-planner`) | opus | _(fill at commit)_ | plan.md + tasks.md drafted; ran at the implementation tier at high effort under the Fallback clause — `fable`'s budget spent |
| Planning: sign-off | opus | ~91k review + ~43k re-review | one blocking (B1, Phase 2 review-scope contradiction) fixed and re-reviewed clean; ran at the implementation tier at high effort under the Fallback clause |
| T001 | opus | ~204k | light palette + pins + re-earned perceptual/contrast suites; verify green (1175 tests, 159 suites, re-run by orchestrator); G3–G8 each mutation-verified red |
| T001 review | opus | ~70k | signed off, no blocking findings; non-blocking second looks (WCAG formula copied per suite, provisional plate/gauge alphas untested, brass/midpoint hue shift) routed to the record and the phase report |
| T002 | opus | ~82k | AppearanceChoice + resolver + AppearanceStore and tests; verify green (1184 tests, 161 suites, orchestrator re-run); G1/G2/G13 mutation-verified red |
| T002 review | opus | ~38k | signed off, no blocking findings; non-blocking: duplicated `appearanceChoice` key (drift hazard) routed to T003 |
| T003 | | | |
| T003 review | | | |
| T004 | | | |
| T005 | | | |
| Phase 2 review | | | |
| Pre-merge sweep | | | |

**Totals (final)** — to be filled at close-out, compared against `002`'s (~2.97M implementer, ~1.43M reviewer over 29 tasks) and `003`'s (~88k implementer, ~77k reviewer per task over six).

## Skeptical-review record (this decomposition)

Signed off 2026-09-09 (`skeptical-reviewer`, `opus`/high, Fallback
clause). The decomposition was found sound: every acceptance criterion
1–10 maps to a task, every task traces to a plan section, the
foundational marking and the T001/T002/T003 `review: per-task` marks are
right, and T001's size is justified by the single derivation loop
(values are tuned until the ΔE floors pass). One blocking finding, fixed
here:

- **B1 — Phase 2 review scope.** Reconciled the Phase 2 review line with
  the handoff note: one review after T005 covering T004 and T005
  (criteria 2, 3, 4, 6, 10), T003 reviewed per-task. Previously the two
  disagreed and the operative wording left T005 unreviewed against the
  per-phase rule.

Second-look items (non-blocking) are dispositioned in `plan.md`'s
sign-off record; the routed guards and cautions ride the T001 and T002
task lines above (T002's does-not-sync scan / G13; T001's escalate-don't-
retune note).

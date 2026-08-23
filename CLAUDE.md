# Project Constitution

This file is the standing contract for how this codebase is built. It loads
into every Claude Code session automatically. Specs and plans (see below)
must not contradict it; if a spec needs to, the constitution gets amended
first, explicitly, in its own commit.

## What this project is

**Trove** — *Your Gear, Valued*. A personal gear inventory app for
hobbyists who own valuable equipment (cameras/lenses, guitars/amps,
audiophile gear) and regularly buy and sell within their hobby. Core loop: track what you own and what you paid for it,
track what you want to buy next, and use the gap between current value and
original cost to plan sales that fund future purchases. Design quality —
visual polish and low-friction interaction — is a primary requirement, not
a nice-to-have. A likely future extension is pulling live/estimated resale
values from marketplaces (eBay, Reverb, Facebook Marketplace); the initial
data model should not preclude that, but it is not in scope for v1.

## Platform

- **Target**: iOS 26.0+ only. No back-compat shims, no `@available` branching
  for older OS versions.
- **UI framework**: SwiftUI only. No UIKit except where a genuine SwiftUI
  API gap forces it — either a `UIViewRepresentable` wrapper, or a narrow
  bridge/decode utility confined to one file (e.g. `UIImage(data:)` as
  the only path from `Data` to a SwiftUI `Image`, since `Image` has no
  `Data`-based initializer of its own). Either shape is a flagged
  exception, not a default: it should be visibly called out when it
  happens, confined to the smallest file that needs it, and never used
  as a shortcut past a SwiftUI API that does exist.
- **Language**: Swift 6, default (non-strict) concurrency mode.
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` project-wide is intentional
  — it's what makes MVVM view-model access convenient without hand
  annotation. One forced exception: `TroveUITests` overrides this to
  `nonisolated`, because `XCTestCase`'s designated initializers are
  `nonisolated` and a `MainActor`-isolated subclass can't override them.
  `TroveTests` (Swift Testing, plain structs) doesn't hit this and keeps
  the `MainActor` default deliberately. Individual UI test methods opt
  into `@MainActor` where `XCUIApplication` needs it, per Apple's own
  template pattern.
- **Project management**: plain `.xcodeproj`, managed through Xcode itself.
  See "Project file safety" below.

## Architecture

- **Pattern**: MVVM.
  - Views are declarative and own no business logic beyond trivial
    formatting/layout decisions.
  - Each screen (or cohesive cluster of views) gets an `@Observable` view
    model that owns its state and exposes intent methods (`func loadX()`,
    `func submit()`), not raw setters.
  - View models do not import SwiftUI.
  - Models are plain Swift types (structs where possible). Persistence and
    networking are injected into view models as protocols, not concrete
    types, so they can be faked in tests.
- No Combine. Use Swift concurrency (`async`/`await`, `AsyncSequence`) for
  everything asynchronous.

## Testing

- **Framework**: Swift Testing (`import Testing`, `@Test`, `#expect`), not
  XCTest, except for UI automation tests which still require `XCTest`'s
  `XCUIApplication`.
- Every view model gets unit tests covering its intent methods and state
  transitions, using fakes/mocks for injected dependencies — no networking
  or disk I/O in unit tests. This rule is scoped to view-model tests
  specifically, where the point is faking the dependency rather than
  hitting it for real. It doesn't extend to tests that are themselves
  verifying an infrastructure claim that can't be checked any other way —
  see the CloudKit schema-validation exception below.
- **Any architectural compatibility claim stated in `plan.md` — "this
  schema is CloudKit-compatible" being the motivating example — should
  have an automated test that actually verifies it, not just a sentence
  asserting it.** `specs/001-core-inventory/plan.md`'s Data model section
  makes this concrete: `CloudKitSchemaTests.swift` builds a real
  `ModelContainer` against a CloudKit `ModelConfiguration` and asserts it
  validates, needing no entitlement, account, or network to run. It does
  real disk I/O by necessity — CloudKit's validator can't run against an
  in-memory store — which is a deliberate, narrow exception to the rule
  above, not a loophole. Apply the same instinct going forward: if a plan
  document claims something is true about how the system is built, prefer
  writing the test that would catch it being false over writing the
  sentence and trusting it.
- **This isn't only for schema claims — visual/design correctness is
  testable too, not just eyeballed.** The desire dial's color ramp
  (`specs/001-core-inventory/plan.md`, signature element) is guarded by
  two mutation-verified tests: no adjacent level reads as visually
  confusable with its neighbor (a minimum perceptual-distance floor), and
  no level reads as confusable with `accentBrass` (which sits nearby as
  the price figure's color). Found via an Oklab model checked against
  actual rendered pixels, not picked by eye. Same principle as the
  CloudKit test, different domain: a claim like "these five colors are
  each distinguishable" is exactly as testable as "this schema validates"
  — write the test, don't just render it and glance.
- **A passing test is not evidence it can fail.** Three separate times in
  this project a test has been correct-looking, correctly named, green,
  and verifying nothing: a tie-break test that couldn't detect its own
  rule being deleted (`FetchDescriptor` doesn't return insertion order),
  a persistence test that refetched on the same `ModelContext` (which
  hands back objects carrying unsaved changes, so `save()` could be
  removed and it still passed), and a color-literal guard whose pattern
  was so broad it fired on legitimate helpers. For any test guarding a
  rule that matters, break the rule deliberately and confirm the test
  goes red — and when one turns out to be false-passing, audit for the
  same *shape* elsewhere rather than fixing the single instance. If a
  test can't be made to fail, delete it or restructure what it tests;
  leaving it reads as coverage that isn't there.
- **UI tests need a controlled starting state, and a narrow test-only
  branch in shipping code is an acceptable way to get one.** A UI test
  whose starting data is whatever the simulator happened to have left
  over from a previous run is the same defect as an unfalsifiable test,
  arriving from the other direction — the result is indeterminate rather
  than guaranteed, but either way a pass or fail doesn't mean what it
  claims to. `T050`'s `-uiTesting` launch argument (swaps the store to
  in-memory) is the pattern: read exactly once at startup, and its only
  possible effect is *losing* data for that one launch, never exposing
  or corrupting real persisted data — bounded enough that the test-only
  branch is worth the unease it should still provoke. Confirm isolation
  actually holds by running the suite twice back to back, don't assume
  the flag does what it's supposed to.
- **When checking whether a mechanism fired, instrument the mechanism —
  don't inspect an artifact that might not reliably show it.** `T056`'s
  pull-to-refresh was reported as broken on `ScrollView` — a platform
  capability with years of history — because a synchronous action
  completes within a single frame, so its spinner is gone before any
  screenshot can catch it. "No visible spinner" and "the action never
  fired" look identical and mean opposite things; only one of them is
  true. What actually settled it was a `print` inside the action itself.
  The control test made it worse, not better: comparing against `List`
  seemed to confirm the finding, but `List` and `ScrollView` differ in
  how they *render* a completed refresh, not in whether `.refreshable`
  fires — the comparison wasn't isolating the variable it claimed to.
  Two things follow: verify a claim about behavior with a probe on the
  behavior itself, not a visual proxy for it; and a long-standing
  platform API is the least likely thing in the room to be broken —
  suspect the newest, most custom code first.
- A task is not "done" until its tests exist and `xcodebuild test` passes.
  Claude Code should run the test command itself and show the result, not
  assert completion from reading the code.

## Dependencies

- No third-party Swift packages by default. Apple frameworks only
  (SwiftUI, SwiftData, Foundation, etc).
- If a task seems to need a third-party dependency, stop and ask rather than
  adding it.

## Project file safety

- Prefer adding new files via Xcode's own "New File" flow, or ask the user
  to add file/target membership by hand, over direct edits to `.pbxproj`.
- If a change genuinely requires editing `.pbxproj` (e.g. adding a new
  target), stop and flag it before doing so — don't fold it silently into
  an unrelated task.

## Spec-driven workflow

This project follows spec → plan → tasks → implement, gated by human review
between each phase. Artifacts live in `specs/<NNN>-<slug>/`:

- `spec.md` — what and why, user-facing behavior, acceptance criteria,
  explicit non-goals. No implementation detail.
- `plan.md` — technical design: types, data flow, view hierarchy, what
  changes where.
- `tasks.md` — ordered, small, independently verifiable tasks.

Do not begin implementation on a feature without an approved spec and plan
in that feature's directory. When resuming a session, check
`specs/<feature>/tasks.md` for the current state before doing anything else.

`spec.md` and `plan.md` get authored in a chat-based design conversation,
not in this session — if asked to scope a brand-new feature from
scratch, point back to that conversation rather than drafting them
inline here. This session's job starts once they already exist and are
approved.

## Collaboration workflow

If the `spec-driven-development` skill is installed
(`~/.claude/skills/spec-driven-development/`), its collaboration
workflow applies automatically — routine tasks proceed normally, real
decisions resolve via Plan Mode and the `skeptical-reviewer` subagent,
and the person is looped in only when something in the design turns out
infeasible or needs real rework, or a previously-unknown consideration
surfaces that would materially change the project's direction. Nothing
needs to be repeated here.

## Verification

After any implementation task, Claude Code must:

1. Build the project (`xcodebuild build` for the relevant scheme).
2. Run the test suite (`xcodebuild test`).
3. Report the actual pass/fail output, not a paraphrase.

A task is not complete until steps 1–2 are green. Do not weaken, skip, or
delete a test to make it pass — if a test seems wrong, flag it and ask.

## Git conventions

- **One branch per spec, not per task or phase.** When starting work on
  a spec (e.g. `specs/001-core-inventory/`), create and switch to a
  branch named after that spec's folder (e.g. `001-core-inventory`)
  before making any changes. Commit into that branch as work proceeds.
  Do not create additional branches per task or phase within a spec —
  that's finer-grained than useful here.
- **Never commit directly to `main`.** All implementation work happens
  on a spec branch.
- Opening the pull request early, as a **draft**, right after the branch
  is pushed, is fine and even encouraged — it gives a running diff to
  review on GitHub alongside each phase, separate from your own summary.
  What matters is that it stays in draft, unmerged, until every task in
  the spec's `tasks.md` is complete and verified — only then mark it
  "Ready for review" and merge. Never merge partway through a spec, even
  if an individual phase looks done.
- Keep the default `Co-Authored-By: Claude` attribution on commits and
  PR descriptions — don't strip it. It's accurate and worth keeping for
  a project meant to demonstrate an AI-assisted workflow.
- Never force-push.
- **A bug found in already-merged code gets its own small branch**
  (`fix/<short-description>`), never a reopened spec branch — that
  branch's job ended at merge. Not a new spec either, unless the fix
  turns out to need substantial rework or reveals a genuinely new
  design question, in which case treat it as one (see the
  `spec-driven-development` skill's "Bugs found after a spec ships"
  section). If the fix corrects a real misunderstanding about how the
  system works, update the relevant spec's `plan.md` in place, even
  though that spec already shipped.

## Commits

- One commit per completed task where practical, referencing the task ID
  from `tasks.md`.
- Commit messages describe what changed and why, not "implement task 3".

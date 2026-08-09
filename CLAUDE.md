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
- **UI framework**: SwiftUI only. No UIKit except where a SwiftUI API gap
  forces a `UIViewRepresentable` wrapper — and treat that as a flagged
  exception, not a default.
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
  or disk I/O in unit tests.
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

## Commits

- One commit per completed task where practical, referencing the task ID
  from `tasks.md`.
- Commit messages describe what changed and why, not "implement task 3".

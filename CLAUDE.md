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
a nice-to-have. Pulling resale values from marketplaces, first
imagined as an eBay/Reverb/Facebook extension, ships in `002` as a
**Reverb asking-price indicator beside the person's value** — never a
replacement for it, and never a sold price, because no source offers
one to a non-partner app; eBay is its own follow-up spec with
prerequisites of its own (amended 2026-09-03, spec `002` Decision 19).

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
- **Networking** (from `002`, amended 2026-09-03): every remote service
  sits behind a `nonisolated protocol …: Sendable` whose requirements
  are `@concurrent` (on the requirement and the implementation, for the
  reason `ExportService` records), constructor-injected as
  `(any X)? = nil` → the live implementation. Decoding and computation
  are tested against fixtures recorded from real responses by a script
  under `scripts/`, trimmed to the fields the app reads and committed
  under `TroveTests/Fixtures/`. No test in `TroveTests` opens a network
  connection; the live API is exercised by hand at a spec's device
  pass, and the recording script is run by hand, never by the build.

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
- **A passing test is not evidence it can fail.** Four separate times in
  this project a test has been correct-looking, correctly named, green,
  and verifying nothing: a tie-break test that couldn't detect its own
  rule being deleted (`FetchDescriptor` doesn't return insertion order),
  a persistence test that refetched on the same `ModelContext` (which
  hands back objects carrying unsaved changes, so `save()` could be
  removed and it still passed), a color-literal guard whose pattern
  was so broad it fired on legitimate helpers (the same over-broad
  shape returned in `002` as a policy scan for seven nouns that the
  prose alone satisfied — the table it guarded could be deleted and it
  stayed green), and a test asserting an invariant that a
  `precondition` in the code under test already guaranteed — it could
  only ever fail by trapping first, so it was deleted (`002`, T021's
  review). For any test guarding a rule that matters, break the rule
  deliberately and confirm the test goes red — and when one turns out
  to be false-passing, audit for the same *shape* elsewhere rather than
  fixing the single instance. If a test can't be made to fail, delete
  it or restructure what it tests; leaving it reads as coverage that
  isn't there. One mechanical rule from the same family: when a
  reviewer is scoped to a diff, cut the diff after `git add -N` so
  untracked files appear in it — a bundle that silently omits the new
  files gets a sign-off on nothing (`002`, T021).
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
  the flag does what it's supposed to. The same bounded branch may
  *add* rows for one launch — `003`'s seeded market history, so a UI
  test can exercise a ranking no real device has the history for yet —
  on two conditions (amended 2026-09-06, at `003`'s plan sign-off): the
  seed is gated on the store the app actually built being the in-memory
  one, never on reading the flag a second time, so the in-memory bound
  is structural and a test can show the seed refusing a persistent
  store even with every flag set; and it takes its own second argument,
  so the flag alone keeps starting from an empty collection and every
  existing UI test keeps the starting state it was written against.
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
  suspect the newest, most custom code first. `002`'s pre-merge sweep
  ran the rule the other way round: a reviewer suspected that dismissing
  the match sheet re-rendered it as the picker and fired a live search
  from the picker's `.task` — a trigger the view-model suite cannot see,
  since it lives in a view. Reasoning about SwiftUI's sheet lifecycle
  would have settled nothing either way; a file probe inside the service
  did, in one relaunch (it never fired). A `.task` inside sheet content
  is a mechanism to instrument once on the device before the tests are
  trusted to speak for it.
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

## Involvement level

Decided 2026-09-03, per the `spec-driven-development` skill's
"Involvement level" section.

**Product owner.** The person owns `spec.md`, attests to behavior by
using the app at phase pauses, and decides escalations. They do not
approve technical work: `plan.md` and `tasks.md` are signed off by Plan
Mode plus the `skeptical-reviewer`, foundational tasks are reviewed by
the `skeptical-reviewer` rather than the person, and what reaches the
person is a spec-conformance summary, not an architecture review.
Implementation pauses after each phase unless the person says to run
further, and whenever something unexpected bears on spec adherence.

## Model policy

Decided 2026-09-04, per the `spec-driven-development` skill's "Model
tiering" section; amended 2026-09-05 from the skill's tuned template
after `002-live-market-value`'s tier log was measured (the review loop
and raw build logs were the two largest costs), and 2026-09-06 to the
template's current wording, which moves plan and task drafting into
the `sdd-planner` subagent. Decided once, alongside the involvement
level; the tier names change as models do, the roles don't.

- **Decisions run at the best available tier**: the spec conversation,
  plan and task drafting (the `sdd-planner` subagent, one dispatch per
  spec on a planning bundle), Step 1 triage, orchestration of
  implementation, and the `skeptical-reviewer` when it's judging a
  decision — plan/tasks sign-off and reviews of routine-but-real
  decisions — via a per-call model override up from its default.
- **The `skeptical-reviewer` runs one tier down by default** (its
  definition says `opus`) for per-task reviews in foundational phases,
  per-phase reviews in mechanical ones, and the pre-merge sweep. Each
  review gets a single bundle file assembled with shell — diff, task
  lines, plan sections, acceptance criteria; for the sweep, the
  documents and the spec's full diff (`git diff main...HEAD`) — and
  reads nothing else. Stage before cutting the diff (`git add -A`), so
  untracked files appear in it.
- **Review loop cap**: one review and at most one re-review per
  invocation — task, phase, sign-off, or sweep. The re-review sees the
  findings and the fix diff only. Blocking means it would fail an
  acceptance criterion or a test, or contradicts `plan.md` or
  `CLAUDE.md`; nothing else blocks. Anything open after the re-review
  goes to the tier log and the sweep; a blocking finding still open
  after a sign-off's re-review is fixed by the orchestrator directly
  and logged, not sent around a third time.
- **Implementation runs one tier down**, in the `sdd-implementer`
  subagent, one task per dispatch, sequentially. The orchestrating
  session triages each task, dispatches routine ones on a task bundle
  assembled with shell (task line, plan section, acceptance criteria,
  files, the pattern file to copy), telling the implementer not to
  read `plan.md`, `spec.md`, or `tasks.md` in full, and on return
  verifies with the verification command below — re-run by the
  orchestrator in foundational phases, taken from the implementer's
  verbatim output in mechanical ones — never by re-reading the diff.
  Only the orchestrator edits `tasks.md` or commits.
- **Fresh orchestrator session at each phase pause**, resuming from
  the first unchecked task, so the top-tier context doesn't accumulate
  the whole spec.
- **Escape hatch**: two failed verifications on one task, or a "stopped
  on a judgment call" the orchestrator considers well-specified, and
  the orchestrator does that task itself at the top tier, noting the
  miss in `tasks.md`.
- **Third tier**: off. Turn on once a spec's tier log under this
  amended cadence justifies it: "Sonnet for tasks with an automated
  Verify check, a named pattern file, and a small footprint."
- **Log token usage per planner dispatch, implementer run and
  reviewer invocation**, plus tier misses, in `tasks.md`'s tier log —
  `002-live-market-value` (from T009a on) is the first spec's log and
  the baseline this amendment came from; the next spec's log is
  compared against it before the policy is treated as settled.

## Spec-driven workflow

This project follows spec → plan → tasks → implement, gated by review
between each phase — the person's or the `skeptical-reviewer`'s, per
the involvement level above. Artifacts live in `specs/<NNN>-<slug>/`:

- `spec.md` — what and why, user-facing behavior, acceptance criteria,
  explicit non-goals. No implementation detail.
- `plan.md` — technical design: types, data flow, what changes where.
- `tasks.md` — ordered, small, independently verifiable tasks.

Authorship: `spec.md` is written in the chat design conversation. The
*venue* of that conversation is decided per spec, by the person: the
default for a green-field feature is a dedicated claude.ai chat, but
they may direct it to happen in the Claude Code session instead — as
`012-data-import` and `003-trend-aware-sell-plan` were — which suits
specs whose design questions hang off contracts already shipped in the
repo; if they haven't said where, ask. In either venue the person
makes the product decisions, the resulting `spec.md` is committed to
the spec branch marked **Draft**, and it is human-approved before
`plan.md` is drafted against it. Until this project has shipped code,
`plan.md` and `tasks.md` are drafted in chat too; once shipped code is
what plans extend — this project's state since `001` merged — the
`sdd-planner` subagent drafts them instead, at the top tier, from a
planning bundle (the spec, the previous spec's plan and tasks as the
pattern, the file listing), against the actual codebase, and the
orchestrator commits them to the spec branch with the PR still in
draft. Both are signed off before any implementation task starts: at
the product-owner level by the `skeptical-reviewer` (blocking findings
fixed and re-reviewed), with the person receiving a spec-conformance
summary to approve; at the technical-lead level by the person
directly. If planning surfaces something that is actually a product
decision — scope, user-facing behavior, a spec contradiction — it goes
back to the person rather than being settled in `plan.md`. (Amended
2026-08-30, 2026-08-31, 2026-09-03 and 2026-09-06; the reasoning for
moving plan authorship out of chat once code exists is in
`DECISIONS.md`, 2026-08-30.)

Do not begin implementation on a feature without an approved spec and
plan in that feature's directory. When resuming a session, check
`specs/<feature>/tasks.md` for current state before doing anything else.

## Collaboration workflow

If the `spec-driven-development` skill is installed
(`~/.claude/skills/spec-driven-development/` or a project-level
`.claude/skills/`), its collaboration workflow applies automatically —
routine tasks proceed normally, real decisions resolve via Plan Mode and
the `skeptical-reviewer` subagent, and beyond the pauses their
involvement level defines, the person is looped in only when something
in the design turns out infeasible or needs real rework, or a
previously-unknown consideration surfaces that would materially change
the project's direction. Nothing needs to be repeated here.

## Verification

The verification command for this project is:

    scripts/verify.sh

It builds the app and runs the unit suite (`TroveTests`) on the
simulator, then prints a short summary instead of the raw log: compile
errors, test failures, the count lines, and the last 40 lines with the
per-test and CloudKit chatter filtered out. It fails on its own if no
test-count line appears, since a bad `-only-testing:` selector runs
zero tests and still reports success. `scripts/verify.sh ui` runs the
UI suite instead and `scripts/verify.sh all` runs both — the UI suite
is for phase ends and close-out, the unit suite for every task. Raw
build logs are the largest single thing an agent can put in its
context; every verification — implementer, reviewer re-run,
orchestrator check — uses this command and nothing more verbose.

After any implementation task, Claude Code must run that command and
report its actual output, not a paraphrase.

A task is not complete until that output is green. Do not weaken, skip,
or delete a test to make it pass — if a test seems wrong, flag it and
ask. When the task was dispatched to the `sdd-implementer`, its verbatim
output is the verification in mechanical phases; in foundational phases
the orchestrator re-runs the command itself before committing.

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
  from `tasks.md` — made by the orchestrating session after its own
  verification, never by the implementer subagent.
- Commit messages describe what changed and why, not "implement task 3".

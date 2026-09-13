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
approve technical work: `plan.md` and `tasks.md` are drafted by the
`sdd-planner` and signed off by the `skeptical-reviewer`, each phase
(and any task the planner marked for its own review) is reviewed by
the `skeptical-reviewer` rather than the person, and what reaches the
person is a spec-conformance summary, not an architecture review.
Implementation pauses after each phase unless the person says to run
further, and whenever something unexpected bears on spec adherence.

## Model policy

Adopted 2026-09-11 for **experiment 1**, following the
`spec-driven-development` skill's experiment-1 branch (session model
`claude-fable-5-1`). It replaces the prior policy — decided 2026-09-04 and
amended 2026-09-05 (after `002-live-market-value`'s tier log measured the
review loop and raw build logs as the two largest costs), 2026-09-06 (plan and
task drafting moved into the `sdd-planner`), 2026-09-07 (per-phase review, and
a session tier stepped down from implementation), and 2026-09-09 (a
`claude-opus-4-8` session tier with a high-effort fallback) — which ran the
orchestrating session on Opus. `005-stock-photos` began under that prior
policy; experiment 1 takes effect from its tier log's experiment-1 row onward.
Decided once, alongside the involvement level; the tier names change as models
do, the roles don't.

- **Tiers by name**: top tier `fable`; implementation tier `opus`;
  session tier `fable` at medium effort (experiment 1 — the top and
  session tiers are the same model at different effort; the fallback
  session model is `claude-opus-4-8`, the full ID, since a
  previous-generation model has no short alias). These names are the
  only place a model is spelled out; everything below refers to the
  roles.
- **The session runs at the session tier, at medium effort**, set in
  this repo's `.claude/settings.json` — written at project setup from
  the skill's `assets/settings-template.json` (`"model":
  "claude-fable-5-1"`, `"effortLevel": "medium"`, and a level under
  `"modelSettings"` for each tier's full model ID). If that file is missing or lacks these
  keys, recreate it from the template and commit it before dispatching
  anything; nobody creates it by hand. Project settings outrank user
  settings, so a model picked in the app's picker only affects the
  session it was picked in — new sessions in this repo start here
  regardless. The app's effort indicator may show the model's default
  rather than the level in effect; `/effort status` inside the session
  is the authoritative check. The orchestrating session takes many
  bookkeeping turns and re-sends its whole context on each one —
  measured across the first specs at eight to nine times the
  implementers' volume, the dominant cost of the workflow — and it makes
  no design decisions: it assembles bundles, dispatches, verifies,
  commits, and reports. The role never needs the top tier; it sits on
  the top tier's model under experiment 1 because Fable 5.1's cache-read
  rate makes the seat's re-sends cost about what they would on Opus, and
  this spec measures the allowance draw and the readability of the
  reports. If it drops the protocol (a skipped review, a stale
  `tasks.md` edit, a task done by hand), the first fix is high effort,
  one line in the same file.
- **The session tier never resolves a design question.** When triage
  finds a task that isn't routine, the session frames the question in
  Plan Mode — so nothing is touched meanwhile — and dispatches the
  `skeptical-reviewer` at the top tier on a decision bundle: the task
  line, the plan section, the acceptance criteria, and the options as
  the session sees them. It transcribes the recommendation into
  `plan.md` and dispatches what remains. A product question `spec.md`
  doesn't settle goes to the person instead.
- **Everything the person reads is plain language.** Pause reports,
  spec-conformance summaries, and questions use short sentences and
  everyday words — no task IDs, agent names, tier names, or internal
  shorthand unless the person asks — and assume the reader won't open
  `plan.md`. Say what can now be tried, where execution deviated from
  the spec and why, and what needs a decision. Technical detail
  belongs in `plan.md` and the commit log, not in the report.
- **What the person's walkthrough finds is a finding, not a task
  line.** When the person reports at a phase pause that something is
  wrong, the session restates it — which acceptance criterion, what
  they saw, what the spec says — and dispatches a diagnosis bundle to
  the `sdd-implementer` (the report, the restatement, the task line,
  the plan section, the acceptance criterion, the files). The
  implementer finds the cause and fixes it if the fix is routine and
  inside the footprint; otherwise it returns the diagnosis and
  options, which go to a decision review at the top tier. A fix is
  logged as a sub-lettered task; a finding that is really the spec
  being ambiguous goes back to the person as a product question. The
  session never diagnoses in place.
- **The top tier runs only inside the decisions**: the `sdd-planner`
  (one dispatch per spec) and the `skeptical-reviewer` on plan/tasks
  sign-off and on decision reviews — each dispatched with an explicit
  per-call override to the top tier's name. The three agent
  definitions carry `effort: high`, which overrides the session's
  medium, so reasoning stays at full strength where it matters.
- **Spec conversations happen in a Claude Code spec session of their
  own**, at the top tier, never inside an implementation session. The
  spec session also runs planning once `spec.md` is approved — the
  planner dispatch, the sign-off, the spec-conformance summary — and
  ends when `plan.md` and `tasks.md` are final, with a new session
  (not `/clear`, which keeps the model) whose opening prompt is the
  spec session's last message. A session in this repo opens at the
  session tier — the top tier's model at medium — so a spec session
  states its model and effort first (`/effort status`) and asks the
  person to raise effort to high for this session (`/effort high`)
  before continuing. The next session opens at medium again from
  `.claude/settings.json`. (The project's very first spec, `001`, with
  no codebase yet, happened in chat; `012` and `003` were the first
  written in a Claude Code session.)
- **The `skeptical-reviewer` runs at the implementation tier by
  default** (its definition says `opus`) for per-phase reviews, the
  per-task reviews the planner marks, and the pre-merge sweep. Each
  review gets a single bundle file assembled with shell — diff, task
  lines, plan sections, acceptance criteria; for the sweep, the
  documents and the spec's full diff — and reads nothing else. Stage
  before cutting the diff (`git add -A`), so untracked files appear in
  it. `tasks.md` states which phases are foundational and which tasks
  are marked `review: per-task` — an orchestrator left to guess guesses
  "all of them."
- **Review loop cap**: one review and at most one re-review per
  invocation — task, phase, sign-off, or sweep. The re-review sees the
  findings and the fix diff only. Blocking
  means it would fail an acceptance criterion or a test, or contradicts
  `plan.md` or `CLAUDE.md`; nothing else blocks. Anything open after
  the re-review goes to the tier log and the sweep; a blocking finding
  still open after a sign-off's re-review is fixed by the orchestrator
  directly and logged, not sent around a third time.
- **Implementation runs at the implementation tier**, in the
  `sdd-implementer` subagent (its definition says `opus`), one task
  per dispatch, sequentially. The orchestrating
  session triages each task, dispatches routine ones on a task bundle
  assembled with shell (task line, plan section, acceptance criteria,
  files, the pattern file to copy), and on return verifies with the
  verification command below — re-run by the orchestrator for tasks
  marked `review: per-task`, taken from the implementer's verbatim
  output otherwise — never by re-reading the diff. Only the
  orchestrator edits `tasks.md` or commits, and the orchestrator never
  implements second-look notes or does device or browser checks by
  hand.
- **One implementation session per spec.** It opens when `plan.md` and
  `tasks.md` are final and ends at the merge; a phase pause is a pause
  in it, not a boundary — the person attests and says continue.
  `/compact` if the context grows large; never clear or compact
  mid-task. `/clear` is not part of the workflow: both session
  boundaries are new sessions.
- **Every session-ending pause ends with a continuation prompt.** When
  the next step belongs in a fresh session — plan and tasks final, a
  merge with the next spec waiting on `ROADMAP.md`, or a phase pause
  the person is stopping at — the report's last item is the exact
  prompt to paste there, in its own fenced block. It names the spec directory,
  the files to read, where to resume, the involvement level, the
  pause cadence, and any effort switch the next session needs. Write
  anything the next session needs to a file first; the prompt points
  at files. If nothing can proceed until the person decides
  something, say so instead.
- **Batch the bookkeeping**: commit, checkbox, and tier-log row in one
  shell command; bundle assembly and dispatch back to back. Every turn
  saved is one fewer re-send of the whole context.
- **Fallback**: if the top tier's usage budget runs out, dispatch the
  planner and sign-off at the implementation tier for the rest of the
  window (drop the override; both definitions default to `opus`), and
  switch the session itself to `claude-opus-4-8` mid-session
  (`/model claude-opus-4-8` — one cache re-write, then continue).
  Nothing else changes; the tier log records what ran and when the
  switch happened, which is a result of experiment 1 in itself.
- **Escape hatch**: two failed verifications on one task, or a "stopped
  on a judgment call" the orchestrator considers well-specified, and
  the orchestrator does that task itself, noting the
  miss in `tasks.md`.
- **Lighter implementer**: off. <!-- Turn on per project once the
  first spec's tier log justifies it: "the session tier for tasks with
  an automated Verify check, a named pattern file, and a small
  footprint." -->
- **Log token usage per implementer run and per reviewer invocation**,
  plus tier misses, in `tasks.md`'s tier log for the first spec under
  this policy, and compare against a previous spec before treating the
  policy as settled — `002-live-market-value`'s and
  `003-trend-aware-sell-plan`'s tier logs are the prior-policy
  baselines, and `005-stock-photos`'s experiment-1 rows are the first
  measured under experiment 1.
- **Experiment 1 results (recorded 2026-09-13, at `005`'s merge; the
  full rows are in `specs/005-stock-photos/tasks.md`'s tier log).** The
  session ran on `claude-fable-5-1` at medium from `005`'s Phase 4 to
  the merge, and the fallback was never needed. Measured with `ccusage`
  on that session's transcript: the seat was about 4.5 M tokens, 96 %
  of them cache reads, for about $5.80, against about $58.70 of Opus
  subagent rows in the same stretch — the seat is roughly a tenth of
  the spend, so which model sits in it moves a spec's total by a few
  percent either way (hypothesis 1 holds at the spec level; the older
  "eight to nine times the implementers' volume" figure above did not
  reproduce under the bundle discipline). Allowance: 92 % at the start
  row and 32 % used / 68 % available at the merge, read from the usage
  page with three projects drawing on the same allowance — recorded as
  read for the experiment's coordinator, not interpreted here
  (hypothesis 2 open). Report readability: no verdict given, no report
  sent back (hypothesis 3 open). Procedural misses: none of the four
  named above; three bundle-hygiene misses and one policy gap are in
  the tier log — the `sdd-implementer` has no simulator tools, so a
  device pass runs in a `general-purpose` agent at the implementation
  tier until the definitions say otherwise (hypothesis 4 holds). The
  policy stays as written until the coordinator applies the decision
  rule; nothing here changes a tier.

## Spec-driven workflow

This project follows spec → plan → tasks → implement, gated by review
between each phase — the person's or the `skeptical-reviewer`'s, per
the involvement level above. Artifacts live in `specs/<NNN>-<slug>/`:

- `spec.md` — what and why, user-facing behavior, acceptance criteria,
  explicit non-goals. No implementation detail.
- `plan.md` — technical design: types, data flow, what changes where.
- `tasks.md` — ordered, small, independently verifiable tasks.

Authorship: `spec.md` is written in the spec conversation — which,
now that this project has shipped code, happens in a Claude Code
session of its own at the top tier, per the model policy above, and
ends when the spec is approved. (`001` was written in chat, before
there was a codebase; `012` and `003` were the first written in a
Claude Code session.) The person makes the product decisions, the
resulting `spec.md` is committed to the spec branch marked **Draft**,
and it is human-approved before `plan.md` is drafted against it.
Because shipped code is now what plans extend, the `sdd-planner`
subagent drafts `plan.md` and `tasks.md` — at the top tier, from a
planning bundle (the spec, the previous spec's plan and tasks as the
pattern, the file listing), against the actual codebase — and the
orchestrator commits them to the spec branch with the PR still in
draft. Both are signed off before any implementation task starts: at
the product-owner level by the `skeptical-reviewer` (blocking findings
fixed and re-reviewed), with the person receiving a spec-conformance
summary to approve; at the technical-lead level by the person
directly. If planning surfaces something that is actually a product
decision — scope, user-facing behavior, a spec contradiction — it goes
back to the person rather than being settled in `plan.md`. (Amended
2026-08-30, 2026-08-31, 2026-09-03, 2026-09-06 and 2026-09-07; the
reasoning for moving plan authorship out of chat once code exists is
in `DECISIONS.md`, 2026-08-30.)

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
output is the verification; for a task marked `review: per-task` the
orchestrator re-runs the command itself before committing.

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

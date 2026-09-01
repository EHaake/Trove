# Decisions & Context Log

Repo-wide, not spec-specific — lives at the root alongside `CLAUDE.md`.
This captures reasoning and context that shaped the project but doesn't
fit into `CLAUDE.md`'s directives or the specs' structured docs. Mostly
product/business-side decisions made in conversation. Purpose: survive a
fresh chat or a new Claude Code session without the reasoning getting
lost, even though the *outcomes* of these decisions are also reflected
in the other files where relevant.

## App identity

- **Name**: Trove. Runner-up was Flywheel (leaned into the buy-sell-buy
  mechanic more literally; Trove won on being a better standalone brand
  word — short, works as an icon name, implies "a collection worth
  having" rather than describing the mechanism).
- **Subtitle**: "Your Gear, Valued." Added because "Trove" alone
  collides with at least three existing App Store apps (a trading-card
  app, an investing app, an eBay-alerts app) — Apple doesn't require
  unique names, but the subtitle is the practical disambiguation tool in
  search results (30-character cap).

## Bundle ID and Apple Developer Program

- **Bundle ID**: `com.erikhaake.trove` (lowercase), chosen over a
  studio-name-style prefix. Reasoning: the bundle ID is invisible to
  users — the public "Seller" name on the App Store comes from Individual
  vs. Organization enrollment in the Developer Program, not from the
  bundle ID string. It also doesn't lock in naming for future apps, since
  each app picks its own bundle ID independently. Cheap to change before
  first submission; effectively impossible after (a new bundle ID means
  a brand-new App Store listing, losing any reviews/ratings/history).
- **Developer Program membership**: lapsed/expired at the start of this
  build. Decision: build now on the free Personal Team (covers local
  build/run, and CloudKit development against your own iCloud account),
  renew the $99/year membership only when actually ready for TestFlight
  or App Store submission. Not needed before then.

## Studio/brand name for future apps

Explored at length — see `studio-name-brainstorm.md` for the full
candidate list (~30 names across math/philosophy/navigation/photography/
music themes) and the rules of thumb that emerged: a real, existing
dual-meaning phrase beats an invented portmanteau; the name should read
as a noun, not a verb/instruction (this is why "Steering the Manifold"
was rejected in favor of trying to find a noun-phrase alternative); avoid
words with a negative connotation even if the wordplay is sound (this is
why "Drift" was dropped despite fitting well). No name has been settled
on. Current status: proceeding with the personal name
(`com.erikhaake.trove`) for Trove specifically; the studio name is a
parallel, non-blocking exploration, picked up in its own chat.

**On the App Store "Seller" name specifically**: decided not to pursue
this. Showing a studio name there instead of a personal legal name
requires enrolling with Apple as an Organization, which requires being
an actual legal entity (LLC or corp — Apple explicitly does not accept
DBAs or trade names for this) plus a D-U-N-S number and a verification
call. Not worth forming a company purely to change a display string;
the threshold for revisiting this is real revenue or a real business
reason, not branding preference. This doesn't affect the studio name's
other uses — bundle ID prefixes for future apps, informal branding,
a portfolio site — none of which need Apple's involvement at all, since
Apple never verifies that a bundle ID's reverse-DNS prefix corresponds
to anything real. Trove and any near-term future apps ship under the
personal Apple Developer account regardless of what the studio name
ends up being.

## Process and tooling notes

- **Git routing**: edits to `CLAUDE.md`, `specs/ROADMAP.md`, and this
  file go to `main` directly (repo-wide). Edits inside
  `specs/<feature>/` go to that feature's own branch. See `CLAUDE.md`'s
  Git conventions section for the full branch-per-spec / draft-PR
  workflow this implements.
- **Model and effort**: originally tiered per phase (Opus 5 for
  foundational/logic-dense phases, Sonnet 5 for mechanical ones — see
  `tasks.md`'s "Model and effort per phase" table). Later switched to
  running Opus 5 across all tasks for the remainder of the build, for
  peace of mind on a first SDD project — upgraded to a Max x5 plan
  specifically to support this. The phase-tiered table in `tasks.md` is
  now historical context for why each phase was originally built the way
  it was, not a live instruction.
- **Claude Code context management**: prefer `/clear` at phase
  boundaries over `/compact`, specifically because this project's
  discipline of keeping real decisions in the actual files (not just in
  conversation) means a cleared session loses very little — `CLAUDE.md`
  re-reads automatically. Use `/compact` instead only when mid-task and
  reluctant to interrupt.
- **This chat (claude.ai)**: no manual compact/clear command exists here
  — context is managed automatically, on a rolling basis. When starting
  a fresh chat for this project, make sure the Trove project's knowledge
  base has current versions of all files first — it's a manual-upload
  snapshot, not a live sync to the repo.
- **Working across two machines (desktop and laptop)**: the first
  concrete incident of this — a laptop `main` diverged from `origin/main`
  after a long desktop-only stretch, caught only when a push was
  rejected. Fixed cleanly with `git pull --no-rebase` since the two
  histories touched different parts of the same files, but the standing
  habit going forward is to check *before* editing, not after a rejected
  push: `git fetch && git status` on whichever machine is in use, before
  touching any file, every time work resumes there. Non-destructive,
  cheap, and would have caught this before any new content was written
  against a stale base rather than after. Worth running against both
  active branches (`main` and whatever spec branch is current) if a
  session is expected to touch both.
- **The collaboration workflow moved from ad hoc to a formal skill.**
  What started as a hand-written "Collaboration workflow" section in
  `CLAUDE.md` (routine tasks proceed, real decisions get a subagent
  check, the person is looped in only for infeasibility or a
  direction-changing unknown) was generalized into a portable
  `spec-driven-development` skill and a `skeptical-reviewer` subagent,
  installed once at the user level
  (`~/.claude/skills/spec-driven-development/`,
  `~/.claude/agents/skeptical-reviewer.md`) so every project gets it
  automatically rather than needing its own copy. `CLAUDE.md`'s section
  is meant to shrink to a short pointer to the installed skill once that
  swap actually lands. A second instance of the machine-sync gap noted
  above surfaced while confirming this: the section briefly looked
  missing entirely when reviewed from the desktop, which simply hadn't
  pulled the laptop's earlier push yet — not a lost commit, the same
  class of incident happening again from the other direction. A
  `.github/PULL_REQUEST_TEMPLATE.md`, built for the companion
  `spec-driven-development-template` repo, was retrofitted into this
  repo around the same time.
- **One claude.ai chat per spec, plus one standing administrative
  chat.** After `001` shipped, the single long project chat that had
  carried the whole v1 build (design, reviews, workflow-tooling, git
  troubleshooting, all of it) had become an everything-drawer — the
  same anti-pattern the methodology avoids at the file level, at the
  conversation level. Going forward: one dedicated chat per spec
  (`010`'s scoping and reviews live in their own chat, `011`'s in
  another), and the original long chat is kept as the standing home for
  administrative and workflow-tuning discussion that isn't spec-specific.
  This works precisely because the durable context lives in the repo and
  the Project knowledge base, not the chat log — a fresh spec chat needs
  no prior chat history, only current files. **Before starting a new
  spec chat, refresh the Project knowledge base with current versions of
  the repo files** (at minimum `CLAUDE.md`, `ROADMAP.md`, `DECISIONS.md`,
  and the relevant spec's docs) — the knowledge base is a manual-upload
  snapshot, not a live sync, and a stale one starts the new chat with a
  subtly wrong picture. The `spec-driven-development` skill applies
  automatically to every chat regardless, so working style carries over
  without being re-established.
- **`plan.md`/`tasks.md` authorship moved into Claude Code (2026-08-30,
  during `011-data-export`).** This is the entry `CLAUDE.md`'s
  authorship-split amendment points at; it was written after the fact
  (the T019 close-out found the pointer dangling). The original rule
  placed `plan.md` authorship in the chat conversation alongside
  `spec.md` — written when the project had no code, so a plan could be
  authored anywhere. With an established codebase that stopped being
  true: a plan's quality depends on ground truth only the repo has
  (actual model definitions, view structure, injection shapes), and the
  chat's knowledge-base snapshot is a manual upload that is reliably
  stale. So: `spec.md` stays with the chat conversation (product
  intent, no repo access needed); `plan.md` and `tasks.md` are drafted
  by Claude Code in-session — Plan Mode, `skeptical-reviewer` on
  non-routine calls, committed as Draft — with the human review gates
  unchanged (plan approved before tasks, both before implementation).
  `011` validated the split immediately: its plan was grounded in facts
  a chat draft would have missed (the custom header with no navigation
  bar, the `SortBadge`/T029c history, synchronized folder groups), and
  the walking-skeleton task it prescribed caught a toolchain behavior
  (`NonisolatedNonsendingByDefault`) that falsified part of its own
  concurrency design before any UI was built on it. The same amendment
  was proposed upstream to the `spec-driven-development` skill.
- **Spec-authorship venue is a per-spec call (2026-08-31, during
  `012-data-import`).** The 2026-08-30 authorship split fixed *who
  decides* (always the person) and *where grounding lives* (the repo),
  but had hard-coded *where the spec conversation happens* (a dedicated
  claude.ai chat). `012` relaxed that to the person's per-spec choice:
  its design questions hung almost entirely off `011`'s shipped CSV
  contract — pinned headers, positional order, empty-cell semantics,
  which fields the models actually require — all of which lives in the
  repo, so for once the in-session venue had the fresher ground truth,
  the same argument that moved `plan.md` in-session. The default for a
  green-field spec remains a dedicated chat (with the knowledge-base
  refresh first); the person picks per spec. `CLAUDE.md`'s
  authorship-split section carries the amended rule.

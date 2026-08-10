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

# Trove — Your Gear, Valued

A personal gear inventory app for hobbyists who own valuable equipment
— cameras and lenses, guitars and amps, audiophile gear — and regularly
buy and sell within their hobby. Track what you own and what you paid
for it, track what you want to buy next, and use the gap between
current value and original cost to plan sales that fund future
purchases.

## Features

- **Owned gear tracking** — name, category, purchase price and date,
  current estimated value, condition, photos, and a "desire to keep"
  rating that doubles as a quiet signal for what might be worth selling.
- **A wishlist** with its own "desire to own" rating, separate from
  desire-to-keep — three levels (Someday / Soon / Next), shown as a
  three-segment gauge rather than a recolored version of the owned-item
  dial, since the two ratings mean structurally different things.
- **A dashboard** — total current value, total spent, the gap between
  them, and a category breakdown, with un-valued items excluded from
  every figure rather than silently treated as worthless.
- **The Sell Plan** — an advisory, persisted shortlist of owned items
  with low desire-to-keep, reachable from any wishlist item, for
  answering "is this a reasonable time to buy, and what would make sense
  to sell if I did" — deliberately not a goal to complete or a sales
  ledger.
- **Low-friction item management** — swipe to delete, edit, or copy on
  both lists; press-and-hold drag reordering under a "Custom" sort,
  with an accessible Move up/Move down path for VoiceOver; and value
  and cost sorts in both directions, with ties resolving by your own
  manual order.
- **Export** — the exact view you're looking at (filters and sort
  respected), as a data-grade CSV with a canonical, re-importable
  schema, or as a print-first PDF collection document — cover summary,
  then one photo-and-fields entry per item — delivered through the
  share sheet.
- **iCloud sync** across your own devices via CloudKit, with real
  handling for the window between signing in and your existing
  collection actually finishing its first download.

## Status

Three specs shipped: `001-core-inventory` (v1 — item tracking, the
dashboard, the wishlist, the Sell Plan, CloudKit sync),
`010-item-management-enhancements` (merged 2026-08-30 — swipe actions,
drag-to-reorder, duplication, expanded sorting, and a design-depth
refresh across the app), and `011-data-export` (merged 2026-08-31 —
view-scoped CSV and PDF export from both list screens, whose CSV
schema is the canonical contract the upcoming import spec will parse).
See
[`specs/ROADMAP.md`](specs/ROADMAP.md) for what's shipped, what's in
progress, and what's next.

## Built with

- **Platform**: iOS 26.0+, SwiftUI only
- **Language**: Swift 6
- **Persistence & sync**: SwiftData, CloudKit
- **Architecture**: MVVM, `@Observable` view models
- **Testing**: Swift Testing for unit tests, XCTest for UI automation
- **Dependencies**: none — Apple frameworks only, by policy (see
  `CLAUDE.md`)

## Building it

1. Open `Trove.xcodeproj` in Xcode.
2. Select the `Trove` scheme and an iOS 26.0+ simulator or device.
3. Build and run.

CloudKit sync requires an active Apple Developer Program membership and
the iCloud capability configured for your own team — without it, the
app falls back to local-only storage automatically rather than failing.
No other setup, no package manager, nothing to install.

## How this was built

Trove was built end-to-end using Claude, Claude Code, and Claude
Design, through a spec-driven development (SDD) process: a written
constitution and a spec for each feature developed in conversation,
with the technical plan and task list drafted by Claude Code against
the real codebase (an authorship split amended into the constitution
on 2026-08-30, once there was a codebase to plan against — early specs
were planned entirely in conversation, before any code existed), all
human-approved before implementation and treated as ground truth. Every commit's authorship
reflects this honestly (`Co-Authored-By: Claude`).

The methodology itself — not this project's specific content — was
generalized into a portable Claude Skill and a project template, usable
on any future project:

- [`SDD-Skill`](https://github.com/EHaake/SDD-Skill) — the process
  knowledge: document templates, the collaboration workflow governing
  when Claude Code proceeds autonomously versus loops in a person, and
  a reviewer subagent.
- [`SDD-Template`](https://github.com/EHaake/SDD-Template) — the
  starting scaffold for a new project built this way.

## Project structure

```
Trove/                 App source
  App/                 App entry point, ModelContainer setup
  Export/               CSV/PDF export — canonical schema, renderers
  Import/               CSV import — parser, field policy, service
  Models/               SwiftData models
  ViewModels/            One per screen
  Views/                 Dashboard/, Items/, Wishlist/, Shared/
  Extensions/            Small, flagged UIKit-bridge exceptions live here
Trove/Fonts/            Bundled type (Archivo, IBM Plex Sans/Mono)
TroveTests/             Swift Testing, one file per view model
TroveUITests/           XCTest smoke tests
specs/
  001-core-inventory/    Shipped v1 — spec, plan, tasks
  010-.../               Shipped — item management + design refresh
  011-data-export/       Shipped — CSV + PDF export, canonical schema
  ROADMAP.md             Backlog of future specs
design/
  brief.md               Visual/interaction direction
  tokens.md               Colors, type, spacing as implemented
  screens/                Design references
docs/
  csv-reference.md       The CSV columns, formats, and Excel caveats
CLAUDE.md                Project constitution — read this first
DECISIONS.md             Business/product/process context
```

## Documentation

Start with [`CLAUDE.md`](CLAUDE.md) — the standing constitution for how
this codebase is built, read automatically by Claude Code every
session. [`DECISIONS.md`](DECISIONS.md) has the business and process
context that doesn't fit anywhere more structured. Each spec's own
`spec.md`/`plan.md`/`tasks.md` in `specs/<NNN>-<slug>/` is the detailed
record of what a feature does and why it's built the way it is.
[`docs/csv-reference.md`](docs/csv-reference.md) documents the CSV
layout the export writes and the import reads — columns, formats,
defaults, and the spreadsheet-app caveats.

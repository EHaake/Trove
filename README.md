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
  every figure rather than silently treated as worthless; and a Market
  line — the sum of the current medians over the matched items, always
  stated with its coverage ("12 of 34 items"), so a partial picture
  never reads as a whole one.
- **The Sell Plan** — an advisory, persisted shortlist of owned items
  with low desire-to-keep, reachable from any wishlist item, for
  answering "is this a reasonable time to buy, and what would make sense
  to sell if I did" — deliberately not a goal to complete or a sales
  ledger. Within a desire level it lists what Reverb's asking prices say
  is rising first and falling last, with the median beside each matched
  item and one dated sentence on a rising row saying by how much.
- **Low-friction item management** — swipe to delete, edit, or copy on
  both lists; press-and-hold drag reordering under a "Custom" sort,
  with an accessible Move up/Move down path for VoiceOver; and value
  and cost sorts in both directions, with ties resolving by your own
  manual order, and a Market sort on both lists.
- **Export** — the exact view you're looking at (filters and sort
  respected), as a data-grade CSV with a canonical, re-importable
  schema, or as a print-first PDF collection document — cover summary,
  then one photo-and-fields entry per item — delivered through the
  share sheet. The CSV carries an item's Reverb match and the year it
  was made, so a round trip restores them; it never carries the fetched
  figures, which belong to the device that fetched them.
- **Import** — CSV import of an externally-tracked collection on both
  lists, parsing the same canonical schema export writes: grab a blank
  template from Settings (or start from a real export), fill it in
  any spreadsheet app, and import — everything is validated up front,
  the confirmation itemizes exactly what will be skipped or defaulted
  before a single row is written, and nothing ever modifies existing
  items. Sample files for every state live in
  [`docs/samples/`](docs/samples/README.md).
- **Market values** — a Reverb asking-price indicator beside your own
  value, never in place of it. You pick the match yourself from a
  candidate list; the pick fetches the current asking prices at once
  and offers them on a slider between the typical low and high asking
  price, resting on the median, so you set your own value with a drag
  and a tap — or step back and keep what you had. The detail then
  shows the median asking price of the current listings in your item's
  condition (all used listings, for something on the wishlist),
  narrowed to the year it was made when you've given one, with the
  spread, how many listings it came from, and how long ago it was
  taken; a refresh is one tap, at most once an hour. The figures and
  their history stay on the device that fetched them and never sync,
  and a first search asks you first — see [`PRIVACY.md`](PRIVACY.md).
- **Settings** — one sheet, reached from the "…" on either list or on
  the dashboard: export *everything* as a CSV pair or a PDF pair (one
  share sheet, two files), the blank import templates, a live iCloud
  status row that says what the app actually knows, Refresh market
  values (one walk over every matched item that is due, with its
  progress shown), Delete All for either list (all-or-nothing, the
  count in the title, with "Export first if you want a copy" right
  there), and About — the Reverb attribution, the contact address and
  the privacy policy.
- **Menus that are the app's own** — every menu inside a page (Sort
  By, both "…" badges, the dashboard's category order) opens one
  shared dropdown surface in Trove's own type and tokens, growing out
  of its badge; the one system menu left is in the navigation bar,
  where the system's chrome belongs.
- **iCloud sync** across your own devices via CloudKit, with real
  handling for the window between signing in and your existing
  collection actually finishing its first download.

## Status

Six specs shipped: `001-core-inventory` (v1 — item tracking, the
dashboard, the wishlist, the Sell Plan, CloudKit sync),
`010-item-management-enhancements` (merged 2026-08-30 — swipe actions,
drag-to-reorder, duplication, expanded sorting, and a design-depth
refresh across the app), `011-data-export` (merged 2026-08-31 —
view-scoped CSV and PDF export from both list screens, whose CSV
schema is the canonical contract), `012-data-import` (merged
2026-09-01 — the read half of that contract: template-based CSV
import on both lists with parse-first confirmation, skip-and-report,
and tested sample files), and `013-settings-menu` (merged 2026-09-02
— the Settings sheet with export-everything, the templates, iCloud
status, Delete All and About, reached from every root's "…"; and, by
its Amendment A, the dashboard's "…" and every in-page menu on one
bespoke dropdown surface), and `002-live-market-value` (merged
2026-09-05 — a Reverb asking-price indicator beside your own value:
pick the match, set your value from the asking prices on a slider, and
see the median on the detail, the rows, a sort and the dashboard, with
the figures kept on the device that fetched them; `PRIVACY.md` and the
one-time notice came with it).
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
  Market/               Reverb client, the local (unsynced) market store, figures and trend
  Models/               SwiftData models
  ViewModels/            One per screen
  Views/                 Dashboard/, Items/, Wishlist/, Settings/, Market/, Shared/
  Extensions/            Small, flagged UIKit-bridge exceptions live here
Trove/Fonts/            Bundled type (Archivo, IBM Plex Sans/Mono)
TroveTests/             Swift Testing, one file per view model
TroveUITests/           XCTest smoke tests
specs/
  001-core-inventory/    Shipped v1 — spec, plan, tasks
  010-.../               Shipped — item management + design refresh
  011-data-export/       Shipped — CSV + PDF export, canonical schema
  012-data-import/       Shipped — CSV import against that schema
  013-settings-menu/     Shipped — Settings, and the bespoke in-page menus
  002-live-market-value/ Shipped — Reverb asking prices beside your value
  ROADMAP.md             Backlog of future specs
design/
  brief.md               Visual/interaction direction
  tokens.md               Colors, type, spacing as implemented
  screens/                Design references
  elements/               Design-pass artboards per spec (002's market surfaces)
docs/
  csv-reference.md       The CSV columns, formats, and Excel caveats
  samples/                Tested sample CSVs for every import state
scripts/                 record-reverb-fixtures.sh — run by hand, never by the build
PRIVACY.md               The privacy policy — what leaves the device, what is stored
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
[`PRIVACY.md`](PRIVACY.md) is the app's privacy policy — what Trove
stores and where, and the two things that leave your device when you
ask it to look something up on Reverb.

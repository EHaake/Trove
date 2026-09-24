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
- **Marking something bought** — when you finally buy the thing you were
  saving for, swipe its row on the wishlist and tap Buy (or use the same
  action from the item's "…" menu or from its Sell Plan). One sheet asks
  what you paid, when, where and what condition it's in, and says in
  passing how the price compared to what you'd estimated. The wanted item
  becomes an item in your collection, keeping its name, category, photos
  and their credits, its Reverb match, its year and your notes — nothing
  to retype — and it leaves the wishlist. Nothing is thrown away: the
  sell plan you built around it survives as a record of what you sold
  toward it, on the Plans tab's Completed side. There's no undo, on purpose — every way in goes through a
  sheet you have to confirm, and an undo would have to delete the item
  the purchase created. A purchase made by mistake is corrected by
  deleting the item and adding the want back.
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
- **Sell plans, in a tab of their own** — a sell plan is something you
  make on purpose: tap **Create a sell plan** on a wanted item, and it stays
  a plan however the items you set aside change, even once every one of
  them has sold. It ends when you buy the thing. The **Plans** tab lists
  them in two halves. **Active** holds the plans you're working on, and
  **Completed** holds the ones that ended in a purchase, each showing the
  picture of the thing you bought, when there is one. Every row says what the plan is for,
  how many items you've set aside, how many have sold toward it, and a
  quiet "Covered" once the sales alone have reached what you expect to pay.
  It never shows a money target or a total left to raise, because the plan
  is advice, not a goal. Each half keeps its own sort. From a row you can
  open the plan, swipe to buy the thing, or swipe to delete the plan. A
  completed plan opens as a read-only record of what sold toward it and
  when it was bought. Deleting a plan deletes only the plan: nothing you
  own or sold is touched, and the record of what sold toward it stays. The
  Overview gains an "active sell plans" card that takes you straight to
  the Plans tab. Plans you'd already made before this feature carry over
  on their own.
- **Marking something sold** — the Items tab has an Owned side and a
  Sold side: record what it sold for, when, where and any note, and the
  item moves across to the Sold side, which says in words whether each
  sale was a gain or a loss and by how much — and it can be returned to
  the collection, its sale details removed, after a confirmation, if it
  comes home. A sold item leaves your collection totals and every sell
  plan's candidates but keeps its photos and history; the dashboard
  gains a Sold card — how many, for how much, and how that compares to
  what you paid — and a sell plan keeps listing what was sold toward
  it, each row marked sold, even once every candidate has gone. Marking
  something sold is on the swipe as well as in the item's menu — Sell,
  between Edit and Copy, opening the same sheet — and the sold item's
  page shows the sale directly under its name. The Sold side has the
  same search, category chips and sort the Owned side does, with sorts
  that fit things already sold: date sold, price, what you paid, gain or
  loss, or name. Each side keeps its own search, chip and sort while you
  look at the other one.
- **Low-friction item management** — swipe to delete, edit, or copy on
  both lists (and to sell, on an owned item's row); press-and-hold drag
  reordering under a "Custom" sort, with an accessible Move up/Move down
  path for VoiceOver; and value
  and cost sorts in both directions, with ties resolving by your own
  manual order, and a Market sort on both lists.
- **Export** — the exact view you're looking at, as a data-grade CSV
  with a canonical, re-importable schema, or as a print-first PDF
  collection document — cover summary, then one photo-and-fields entry
  per item — delivered through the share sheet. On the Items tab each
  format asks which rows first: owned, sold, or both. Owned is the file
  you already had. "Owned and sold" as a CSV is the whole record — the
  owned rows as you filtered and sorted them, then the sold ones, most
  recent sale first, each with what it sold for, when and where — and as
  a PDF it is two documents in one share sheet. Sold on its own is its
  own document: a "Sold Items" PDF whose cover totals what those items
  sold for, what was paid and the realised gain or loss, each entry
  carrying the sale under the name, or a CSV of just those rows. Every
  choice follows what you have narrowed on screen, and a choice with
  nothing in it is greyed out — so a collection you have sold entirely
  still exports, in either format. The CSV carries an item's
  Reverb match and the year it was made, so a round trip restores them;
  it never carries the fetched figures, which belong to the device that
  fetched them.
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
- **Stock photos** — an item with no photo of its own can borrow one
  from Wikimedia Commons: tap Find a photo…, pick from the candidates,
  and the item gets a representative image, badged as a stock photo and
  carrying its credit — the photographer, the licence and a link back —
  in the app and in a PDF export. Searching happens only when you ask,
  after the same kind of one-time notice the market search uses, and a
  fetched photo syncs like your own.
- **Settings** — one sheet, reached from the "…" on every tab: export *everything* as a CSV pair or a PDF pair (one
  share sheet, two files), the blank import templates, a live iCloud
  status row that says what the app actually knows, Refresh market
  values (one walk over every matched item that is due, with its
  progress shown), Delete All for either list and for every sell plan
  (all-or-nothing, the count in the title, with "Export first if you
  want a copy" right there; deleting all sell plans leaves every item,
  wanted item and sale where it was), and About — the Reverb attribution, the contact address and
  the privacy policy.
- **Appearance** — a System / Light / Dark choice in Settings, where Light is a paper-ground variant of the same brass/moss/rust identity rather than a new palette, System follows the device live, and the choice is stored per-device (Dark by default, so an existing install updates to exactly today's look).
- **Menus that are the app's own** — every menu inside a page (Sort
  By, every tab's "…" badge, the dashboard's category order) opens one
  shared dropdown surface in Trove's own type and tokens, growing out
  of its badge; the one system menu left is in the navigation bar,
  where the system's chrome belongs.
- **iCloud sync** across your own devices via CloudKit, with real
  handling for the window between signing in and your existing
  collection actually finishing its first download.

## Status

Twelve specs shipped: `001-core-inventory` (v1 — item tracking, the
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
bespoke dropdown surface), `002-live-market-value` (merged
2026-09-05 — a Reverb asking-price indicator beside your own value:
pick the match, set your value from the asking prices on a slider, and
see the median on the detail, the rows, a sort and the dashboard, with
the figures kept on the device that fetched them; `PRIVACY.md` and the
one-time notice came with it), `003-trend-aware-sell-plan` (merged
2026-09-07 — the Sell Plan ranks rising items first and falling last
within a desire level, with the median on each matched row and one
dated sentence saying why), `004-themes` (merged 2026-09-09 — light
mode of the brass/moss/rust identity, with a System/Light/Dark choice
in Settings), `005-stock-photos` (merged 2026-09-13 — an item with
no photo of its own can borrow a credited one from Wikimedia Commons,
in the app and in the PDF export), `006-mark-as-sold` (merged
2026-09-15 — mark an item sold from its page or from a sell plan and
it moves to a Sold side of the Items tab with what it sold for, when
and where; a Sold card on the dashboard, a Sold figure on each sell
plan, four new CSV columns, and a sale that can be undone), and
`014-sold-side-parity` (merged 2026-09-19 — Mark as sold on the Items list's
swipe, the Sold side gaining the search, category chips and sort the
Owned side has with sorts that fit things already sold, each side
keeping its own, the sale shown under a sold item's name, and exports
that ask first whether you mean owned, sold or both), and
`015-mark-as-bought` (merged 2026-09-21 — mark a wanted item bought from
its swipe, its menu or its Sell Plan, and it becomes an item in your
collection carrying its photos, credits and Reverb match, while the sell
plan built around it survives as a record). `009-sell-plan-list` is
complete on its branch — sell plans as things you create, the Plans tab
and its Dashboard card — and not yet merged.
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
  Photos/                Wikimedia Commons client, licence filter, the notice store
  ViewModels/            One per screen
  Views/                 Dashboard/, Items/, Wishlist/, Plans/, Settings/, Market/, Photos/, Shared/
  Extensions/            Small, flagged UIKit-bridge exceptions live here
Trove/Fonts/            Bundled type (Archivo, IBM Plex Sans/Mono)
TroveTests/             Swift Testing, one file per view model
TroveUITests/           XCTest smoke tests
specs/
  001-core-inventory/    Shipped v1 — spec, plan, tasks
  010-item-management-enhancements/  Shipped — item management + design refresh
  011-data-export/       Shipped — CSV + PDF export, canonical schema
  012-data-import/       Shipped — CSV import against that schema
  013-settings-menu/     Shipped — Settings, and the bespoke in-page menus
  002-live-market-value/ Shipped — Reverb asking prices beside your value
  003-trend-aware-sell-plan/ Shipped — the trend-aware Sell Plan
  004-themes/            Shipped — light mode and the appearance choice
  005-stock-photos/      Shipped — credited stock photos from Wikimedia Commons
  006-mark-as-sold/      Shipped — the sale, the Sold side, the Sold card
  014-sold-side-parity/  Shipped — Sell on the swipe, and the Sold side's search, chips and sort
  015-mark-as-bought/    Shipped — the purchase: a wanted item becomes an owned one
  009-sell-plan-list/    Sell plans you create, the Plans tab and its Dashboard card
  SYNC-CHECKS.md         Every untested sync check, from all specs, for one pass
  ROADMAP.md             Backlog of future specs
design/
  brief.md               Visual/interaction direction
  tokens.md               Colors, type, spacing as implemented
  screens/                Design references
  elements/               Design-pass artboards per spec (002's market surfaces, 005's photo surfaces, 006's sale surfaces)
docs/
  csv-reference.md       The CSV columns, formats, and Excel caveats
  samples/                Tested sample CSVs for every import state
scripts/                 verify.sh, and the fixture recorders (Reverb, Wikimedia) — run by hand, never by the build
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

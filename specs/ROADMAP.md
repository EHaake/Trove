# Trove — Roadmap

## Why the first spec is one large unit, and later ones won't be

In SDD, a spec should map to one separable, reviewable piece of work —
usually one feature, one PR. `001-core-inventory` doesn't follow that:
it bundles item tracking, the dashboard, the wishlist, and the Sell Plan
into one 50-task spec.

That's not a deviation from the principle, it's what the principle
implies for a brand-new app: those four pieces share one data model and
none of them is independent of it yet, so splitting them into separate
specs would just mean coordinating shared schema changes across specs
that all have to land before any of them individually work. There's no
established codebase yet for a smaller spec to be "a feature added to."

Once `001-core-inventory` is merged, that condition stops holding — Trove
is then an established app, and every spec after this one should go back
to the normal rule: one feature, one spec, sized to be reviewable on its
own.

## Spec status

| Spec | Status |
|---|---|
| `001-core-inventory` | **Shipped** — merged to `main` 2026-08-23 via [PR #1](https://github.com/EHaake/Trove/pull/1); spec, plan and tasks all Approved in specs/001-core-inventory/ |
| `010-item-management-enhancements` | **Complete** — all tasks through the Phase 8 close-out done (2026-08-30); twenty acceptance criteria signed off; skeptical-review findings resolved or recorded in `tasks.md` |
| `011-data-export` | **Shipped** — merged to `main` 2026-08-31 via [PR #5](https://github.com/EHaake/Trove/pull/5); all nineteen tasks done, twelve criteria verified, close-out review findings dispositioned in `tasks.md` |
| `012-data-import` | **Shipped** — merged to `main` 2026-09-01 via [PR #7](https://github.com/EHaake/Trove/pull/7); all eighteen tasks done, sixteen criteria verified with a per-criterion record in `spec.md`; the T017 device pass and T018 audit each caught and fixed a real defect before merge |
| `013-settings-menu` | **Shipped** — merged to `main` 2026-09-02 via [PR #9](https://github.com/EHaake/Trove/pull/9); seventeen tasks plus Amendment A's nine (the Dashboard "…" and bespoke in-page menus, decided after the first close-out and before merge), twenty-seven criteria verified with per-criterion records in `spec.md`; three false-passing guards caught across the two phases, and the render oracle, the frame-by-frame recording and the safe-area probe each overturned a plan claim before it shipped |

## Future specs

Every one of these traces back to a non-goal explicitly deferred during
`001-core-inventory`'s planning — nothing here is a new idea, just the
backlog of what v1 deliberately didn't do. Roughly in dependency order;
after 003, the rest are independent and can happen in whatever order is
actually useful once the app is in daily use.

- **`002-live-market-value`** — Pull resale values from eBay, Reverb,
  Facebook Marketplace, or similar, to replace the manually-entered
  `currentValueCents`. The real unlock, and the one with genuine
  complexity: real API access, and possibly ToS friction depending on
  source (see plan.md's original discussion of this in
  `001-core-inventory` for the caution around scraping vs. official
  APIs).
- **`003-trend-aware-sell-plan`** — Upgrade the Sell Plan's ranking to
  factor in market-value trend, not just desire-to-keep — surfacing an
  item because it's both low-attachment *and* currently selling well.
  Depends on `002` existing first; this is where the originally-described
  "killer feature" actually lands. The Sell Plan's persistence and
  selection mechanics were built in `001` specifically so this upgrade
  only touches the ranking algorithm, not the screen's shape.
- **`004-themes`** — Light mode, plus a small set of additional curated
  color themes beyond the default. Uses the semantic `Theme` abstraction
  built into every view from `001` specifically so this is a config
  change, not a redesign.
- **`005-stock-photos`** — Auto-fetch a representative photo for items
  you don't own yet (most useful for wishlist items). Needs a real
  third-party image API with licensing terms to honor. Uses
  `Photo.source`, already sitting on the model unused since `001`.
- **`006-mark-as-sold`** — Real transaction tracking for the Sell Plan:
  marking a planned item as actually sold, removing it from inventory,
  a sale history. Deliberately excluded from `001` to keep the Sell Plan
  a decision-support tool rather than a ledger — worth revisiting once
  it's clear the decision-support version is actually useful day to day.
- **`007-auto-categorization`** — Suggest a category path from a photo
  instead of typing it. The category field being a plain string path
  (not a fixed enum) since `001` is what keeps this a pure addition.
- **`008-category-colors`** — A curated, theme-harmonizing palette applied
  to top-level categories only (`Photography`, `Music`, etc. — not every
  leaf), user-selectable when a new top-level category is first used, or
  auto-assigned if they don't choose. Came up during `001`'s Phase 4
  review as a way to make leaf-only chip labels ("Electric," "Hollowbody")
  less ambiguous at a glance; deferred because picking the palette is a
  real design decision on par with the original brief, not an
  incidental engineering one — worth a deliberate Claude Design pass,
  not a guess. **Validated, not just proposed**: Phase 5's dashboard
  category breakdown, rendered with color-coded mock data, looked good
  enough to prompt reconsidering the deferral outright — held to v2
  anyway since the mock data's category count was favorable and a real
  palette needs to work across whatever range a real collection has, but
  worth treating as a strong early candidate once `001` ships, not a
  backlog afterthought.
- **`009-sell-plan-list`** — A dedicated view of every wishlist item that
  currently has an active Sell Plan (a non-empty `plannedSaleItems`
  selection) — no new persisted entity, just a new lens on data that
  already exists. Surfaced via a card on the Dashboard ("N active sell
  plans"), reusing the cross-tab deep-link mechanism `001`'s `T042`
  already builds for the leaf-category and un-valued-items jumps.
  Deliberately *not* a fourth tab — a tab competing with Dashboard/
  Items/Wishlist for permanent attention should represent a genuinely
  distinct place to be, not a filtered slice of data already reachable
  elsewhere; a Dashboard card or a Wishlist-tab filter both deliver the
  same value more cheaply. Came up during `001`'s Phase 7 review, in the
  same conversation that resolved what the mock's placeholder fourth tab
  should actually become (see the Navigation note in `001`'s `plan.md`).
  Rows are card-sized, not compact-list-sized, given how much they need
  to show: thumbnail, name, category, the selected-value-vs-cost
  comparison with the same quiet color cue `SellPlanView` itself uses,
  and a selection count ("3 of 5 candidates selected"). Tapping a row
  goes straight into that item's existing `SellPlanView` — no new detail
  screen needed, only a new entry point into one that already exists.
  Deferred rather than folded into `001` because, unlike the wishlist-
  photos and desire-gauge additions, it's a genuinely new, undesigned
  screen that doesn't block or get blocked by anything already in
  flight — it deserves a real Claude Design pass rather than an
  improvised layout, the same reasoning that held `008` to v2.
- **`010-item-management-enhancements`** — Came up right as `001` was
  wrapping up: a request for swipe-left-to-delete on `ItemListView`/
  `WishlistView` rows (standard iOS convention), which grew into wanting
  a broader look at item-management interactions before committing to a
  spec. Deliberately kept out of `001` rather than bolted on as "just
  one more thing" — `001`'s `tasks.md` was already fully checked off,
  and growing it further would have undercut the same one-feature-one-
  spec discipline this file's own opening section argues for. The exact
  scope beyond swipe-to-delete is still open, to be settled in the
  actual idea conversation rather than guessed at here.

  One real technical consideration already surfaced, worth carrying into
  that conversation rather than rediscovering: SwiftUI's `.swipeActions()`
  is `List`-specific as far as investigated so far, and Trove's rows are
  deliberately `ScrollView`-based — the `T056` pull-to-refresh
  investigation already considered and rejected converting to `List`,
  since it would clobber the custom row styling (thumbnails, the desire
  dial/gauge) Design actually drew. Verify that constraint fresh rather
  than assuming it still holds by the time this spec starts; expect
  either a `List` reconsideration or a custom gesture implementation,
  not a one-line modifier.

  A second, unrelated consideration for the same spec: the wishlist
  row's `DesireGauge` doesn't read as a desire indicator on first
  encounter without already knowing what it is — flagged during `001`'s
  final review, on the actual running app, not hypothetically. `T036c`'s
  original "no legend" decision assumed the shape would already be
  learned from the form before someone saw a bare row, which doesn't
  hold if a row is the first encounter. Kept unlabeled for now,
  deliberately, rather than adding scope this close to `001`'s merge —
  a short label ("Desire" was one candidate raised) is one option, but
  worth actually exploring rather than assuming that's the fix once
  this spec is properly scoped.
- **`011-data-export`** — CSV and PDF export of the collection. Not a
  new idea, a validated one: `001`'s original `spec.md` explicitly
  listed "Insurance-document export or valuation reports" as a non-goal,
  noting it "may be a natural future feature, not v1." The pitch behind
  building it now: it's a real differentiator against the spreadsheet
  most hobbyists (including this app's own author) already use to track
  gear — something a spreadsheet can't easily produce on its own.

  Two genuinely different deliverables under one spec, not one thing:
  CSV (portable data, for backup or moving elsewhere) and PDF
  (presentation-quality, for insurance documentation or sharing — per-
  item spec sheets, a whole-collection appraisal document, or both,
  scope TBD). Photos belong to the PDF side, not CSV — that's a
  tabular/text format, and forcing images into it fights the format
  rather than using it well.

  Decided ahead of the idea conversation: CSV only, no `.xlsx`. Genuine
  Excel format — not a renamed CSV — would likely need a third-party
  library, which `CLAUDE.md`'s no-third-party-packages-without-
  discussion policy would put through real scrutiny; not worth it for a
  format any spreadsheet app already opens and can re-save as `.xlsx`
  itself in one step. CSV alone gets the actual portability benefit
  without the dependency question.

  **Shipped 2026-08-31** ([PR #5](https://github.com/EHaake/Trove/pull/5)
  — see `specs/011-data-export/` for the full record: view-scoped
  export via the "…" menu on both list screens, the canonical CSV
  schema pinned in its `plan.md` for `012` to parse, a print-first PDF
  collection document rendered with CoreGraphics/CoreText/ImageIO).
  Three things were deliberately deferred out of the original scoping,
  recorded here so they aren't lost:

  - **Export-everything** (both collections at once, from anywhere) —
    deferred to a settings menu that doesn't exist yet; now the
    motivating first occupant of `013-settings-menu` below.
  - **Dashboard export** — a future custom export of the Dashboard's
    own content (summary figures plus supporting detail), distinct
    from the list exports; the Dashboard has no view context for the
    export-follows-view rule to act on, so it needs its own designed
    shape rather than inheriting this spec's. *(Since `013` Amendment
    A the root Dashboard has a "…" holding Settings alone — kept a
    menu rather than a direct button precisely so this export can
    join it.)*
  - **Per-item export from the detail screens** — per-item PDF spec
    sheets as a refinement of the collection document; plausibly
    lands alongside or after `013`'s export-everything, whenever an
    export surface exists beyond the two list screens.

  Three more were recorded at `011`'s T018 manual pass (2026-08-31),
  with the feature verified and shipping:

  - **Exports track the schema, not the other way around** — when new
    per-item data lands (trending/market values above all), both
    export formats need revisiting in the same spec that adds the
    data: new CSV columns are a canonical-schema change made together
    with `012`'s parser, and the PDF's field grid and cover should
    carry the new figures. `011`'s plan.md schema section records the
    mechanics (append-only column growth).
  - **Sell-plan export** — a wishlist item's Sell Plan (the gear
    weighed against funding it) appears in no export today; deferred
    deliberately, not overlooked.
  - **A "Full" export** — dashboard figures, both lists, and each
    wishlist item's sell plan in one deliverable. A future export
    spec of its own, sensibly after trending values exist (it's the
    export whose value grows most with them). It overlaps `013`'s
    export-everything occupant and the dashboard-export deferral
    above — scoping should reconcile the three rather than build
    them separately. *(`013` shipped export-everything as Settings'
    CSV and PDF pairs; the Dashboard's "…" now exists to hang a
    Dashboard-shaped export on.)*
- **`012-data-import`** (**Shipped 2026-09-01** via
  [PR #7](https://github.com/EHaake/Trove/pull/7) — see
  `specs/012-data-import/` for the full record) — CSV import of
  externally-tracked gear, the adoption barrier from the other
  direction: a collection already tracked in a spreadsheet comes in
  without hand re-entry.

  The product questions flagged below were settled in the spec’s
  design conversation (run in-session — the venue amendment’s first
  use): malformed data is **skip-and-report with counted per-field
  defaults**, never a batch reject; **no duplicate detection** — the
  user owns the file; and instead of a preview screen, the
  parse-first **confirmation alert** carries the whole report (counts,
  skipped rows by spreadsheet number, defaults) before anything is
  written — the destructive-action instinct satisfied without new UI.
  Order is positional, appended to the end of custom order; the “…”
  badge became always-visible so a fresh install can reach Import and
  **Get Blank Template** (the templates moved to Settings › Templates
  at `013`; the badge stayed always-visible for Import and Settings);
  `docs/csv-reference.md` and the test-pinned `docs/samples/` files
  shipped with it.

  Scope decided ahead of the idea conversation, to keep this spec's own
  first version genuinely small: a rigid, Trove-defined column template
  plus documentation describing exactly what's expected (a README-style
  reference, not a mapping UI) is the v1 approach — someone reads the
  spec or exports a template, formats their data to match, imports
  directly. A flexible "tell us which column means what" mapping UI is
  real and valuable, but explicitly deferred — a natural enhancement to
  `012` itself once the rigid-template version has shipped and its
  actual friction is understood, rather than something built blind
  before knowing whether it is needed — **this deferral stands
  post-ship** and remains the natural next enhancement to `012`.
  Photos were confirmed a deliberate non-goal.

  Soft dependency on `011`, not a hard blocker like `002`→`003`: import
  can reuse whatever canonical schema export settles on for representing
  an item as a row, which also enables a natural "export a template,
  fill it in, re-import" pattern. Worth designing export's schema first
  even if import's own build happens later. With `011` shipped, that
  schema is no longer a definition but a working contract: `011`
  plan.md's "The canonical CSV schema" section is the document this
  spec parses against — pinned headers and column order, BOM to skip,
  CRLF endings including the trailing one, minimal quoting, positional
  row order, empty-cell-vs-zero semantics, locale-free money, the
  local-day date caveat, and the append-only growth rule for future
  columns. `ExportSchema.swift` carries the same constants in code.
- **`013-settings-menu`** (**Shipped 2026-09-02** via
  [PR #9](https://github.com/EHaake/Trove/pull/9) — see
  `specs/013-settings-menu/` for the full record) — the app's Settings
  sheet, one screen reached from every root: the lists' "…" (a fourth
  section at the bottom, below Import) and, since the spec's Amendment
  A, the Dashboard's own "…", which Design's mock always drew and
  which holds Settings alone. Its occupants, decided in the spec
  conversation: **export everything** as two actions (the CSV pair
  and the PDF pair, one share sheet with two files each — `011`'s
  deferral landed), the **blank templates** moved here from the lists'
  menu, a live **iCloud** status row (the store's fallback reason
  finally read, after sitting unread since `001`), **Delete All** per
  list (all-or-nothing, count in the title, the iCloud sentence only
  when the store is configured for iCloud), and **About**. The name
  stayed *Settings* although nothing on it is yet a preference: in
  iOS vocabulary it is the back-of-house screen, and `004`'s theme
  selection and a currency choice land exactly here. Amendment A also
  settled a rule the app had followed without stating it — **bespoke
  inside the page, system in the bars**: Sort By, both "…" badges and
  the Dashboard's category-order control open one shared dropdown
  surface (grown out of the badge with a fade, since the person found
  the still version stiff), while the detail screens' nav-bar "…"
  stays the app's one system menu, guarded by `MenuPolicyTests`.
  Deferred from here, recorded so they aren't lost: **restructuring
  Settings into submenus** (export, templates and delete each behind a
  row of their own) once real preferences arrive — the person's call,
  nothing to restructure around yet; **theme selection** to `004`; a
  **default-currency** setting and **iCloud account status / an iCloud
  toggle** to specs of their own; the **Dashboard export** and the
  "**Full**" export above, which now have a menu to live in.

## Working convention

Per `CLAUDE.md`: one branch per spec, no new spec branch starts until the
current one is merged to `main`. This roadmap is a backlog, not a
commitment to order — pick whichever spec is actually useful next once
`001-core-inventory` ships and the app's in real use.

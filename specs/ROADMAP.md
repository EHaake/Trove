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
| `010-item-management-enhancements` | **Shipped** — merged to `main` 2026-08-30 via [PR #3](https://github.com/EHaake/Trove/pull/3); twenty acceptance criteria signed off, skeptical-review findings resolved or recorded in `tasks.md` |

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
- **`010-item-management-enhancements`** — **Shipped 2026-08-30 via
  [PR #3](https://github.com/EHaake/Trove/pull/3)**; the full record
  lives in `specs/010-item-management-enhancements/`. Kept here for the
  origin story: it came up right as `001` was wrapping — a request for
  swipe-left-to-delete that grew into a broader item-management pass —
  and was deliberately kept out of `001` rather than bolted on, per
  this file's own one-feature-one-spec argument. It ended up covering
  swipe delete/edit/copy on both lists, drag-to-reorder with an
  accessible VoiceOver path, expanded sorting with manual-order
  tie-breaks, and a design-depth refresh (the extruded-plate
  treatment).

  The two considerations this entry used to carry both resolved during
  the build. The `.swipeActions()`-needs-a-`List` constraint was real,
  and was settled by adopting `List` with every visible default
  overridden — the custom row styling `T056` once worried a `List`
  would clobber survived intact. And the bare `DesireGauge` legibility
  flag became `010`'s stepped-ramp redesign with its per-row "DESIRE"
  legend, explicitly recorded in that spec's plan as reversing `001`'s
  "no legend" decision rather than quietly refining it.
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
- **`012-data-import`** — CSV import of externally-tracked gear. Aimed
  at the adoption barrier from the other direction: someone already
  tracking their collection in a spreadsheet shouldn't have to re-enter
  it by hand to switch to Trove.

  Genuinely harder than `011`, and for reasons that are product
  decisions more than engineering ones: what happens to malformed or
  missing data (reject the whole batch, skip and report, or fill
  defaults); how potential duplicates against an already-populated
  collection get handled; and — given the bulk-insert risk — almost
  certainly a preview-before-commit step, the same instinct that's
  shaped every destructive-action flow already in this app.

  Scope decided ahead of the idea conversation, to keep this spec's own
  first version genuinely small: a rigid, Trove-defined column template
  plus documentation describing exactly what's expected (a README-style
  reference, not a mapping UI) is the v1 approach — someone reads the
  spec or exports a template, formats their data to match, imports
  directly. A flexible "tell us which column means what" mapping UI is
  real and valuable, but explicitly deferred — a natural enhancement to
  `012` itself once the rigid-template version has shipped and its
  actual friction is understood, rather than something built blind
  before knowing whether it's needed. Photos are likely out of scope
  for a first pass either way — most spreadsheet tracking won't have
  structured photo references to import from — worth stating as a
  deliberate non-goal rather than silently omitting.

  Soft dependency on `011`, not a hard blocker like `002`→`003`: import
  can reuse whatever canonical schema export settles on for representing
  an item as a row, which also enables a natural "export a template,
  fill it in, re-import" pattern. Worth designing export's schema first
  even if import's own build happens later.

## Working convention

Per `CLAUDE.md`: one branch per spec, no new spec branch starts until the
current one is merged to `main`. This roadmap is a backlog, not a
commitment to order — pick whichever spec is actually useful next now
that the app's in real use.

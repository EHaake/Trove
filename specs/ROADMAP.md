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
| `002-live-market-value` | **Shipped** — merged to `main` 2026-09-05 via [PR #11](https://github.com/EHaake/Trove/pull/11); twenty-nine tasks (T001a–T024 with sub-letters, Amendments A and B folded in during implementation), twenty-three criteria verified with per-criterion records in `spec.md`; the first spec under the constitution's model policy, its tier log in `tasks.md`; the pre-merge sweep's one blocking finding settled by instrumentation on the simulator (not a defect) and one two-device gap recorded for a `fix/` branch |
| `003-trend-aware-sell-plan` | **Shipped** — merged to `main` 2026-09-07 via [PR #15](https://github.com/EHaake/Trove/pull/15); seven tasks (T001–T007 with T004a added at the Phase 2 pause for Decision 14, the person's layout call from the seeded simulator), twelve criteria verified with per-criterion records in `spec.md`; the second spec under the model policy — its tier log in `tasks.md` came in under 002's per-task cost with the review-loop cap holding throughout; two layout facts settled by measurement rather than argument before merge |
| `004-themes` | **Shipped** — merged to `main` 2026-09-09 via [PR #20](https://github.com/EHaake/Trove/pull/20); seven tasks (T001–T007), ten criteria verified with per-criterion citations in `spec.md`; **light mode of the existing brass/moss/rust identity** plus a System/Light/Dark choice in Settings — alternate-hue palettes stay deferred to their own Design pass (spec Decision 1). The third spec under the model policy, its tier log in `tasks.md` — **every invocation ran at `opus` under the Fallback clause** (`fable`'s budget spent for the whole spec); the T006 device pass signed off the light palette on-brand across every screen, and a one-time, non-reproducible title-refresh transient was recorded and dispositioned "note, don't fix" by the person |
| `005-stock-photos` | **Shipped** — merged to `main` 2026-09-13 via [PR #21](https://github.com/EHaake/Trove/pull/21); sixteen tasks with four sub-lettered additions (T012a, the taken-with relevance filter the person's Phase 3 device testing asked for; T015a–c, from the device pass), eleven criteria verified with per-criterion records in `spec.md` and **two honest partials named** (no second device for the sync check; no dual-licensed GFDL + CC-BY-SA file in any live search). The app's **second network dependency** — Wikimedia Commons, the one source whose terms let a fetched photo be stored, synced and shown offline. Two review findings were caught as false coverage rather than by failing (a ported-licence acceptance, a bare-number relevance drop), a render test was probed, found false-passing and deleted, and the picker's `.task` firing count was settled by a probe inside the service rather than by inference. The first spec measured under the model policy's **experiment 1** — the orchestrating session moved to Fable at Phase 4, its tier log in `tasks.md`. |
| `006-mark-as-sold` | **Shipped** — merged to `main` 2026-09-15 via [PR #23](https://github.com/EHaake/Trove/pull/23); twenty tasks (T001–T020) with ten sub-lettered additions — three of them from the person's walkthrough at the Phase 5 pause (T018a–T018c) and one from the device pass (T018d) — seventeen criteria (1–16, with 7a) verified with per-criterion records in `spec.md` and **two honest partials named** (no second device for the sync check; the VoiceOver reading is the person's step). The app's **first record of a real transaction** — a sale is four fields and a link on the item itself, so it syncs as one record and "Return to collection" is nil-ing them; the Items tab grows a Sold side beside Owned, the Dashboard a Sold card, and the Sell Plan a third figure that still subtracts nothing. Three things were settled by measurement rather than argument: a 19.7 pt jump in the Owned/Sold switch, the stutter beneath it (a `matchedGeometryEffect` across an insert/remove crossfades instead of moving), and the sale sheet presenting exactly once per confirm (a probe inside the writer, not a screenshot). Xcode 27 arrived mid-spec and the branch carries the toolchain fixes and a warning-free build. The second spec measured under the model policy's **experiment 1**, its tier log in `tasks.md`. |

## Future specs

Every one of these traces back to a non-goal explicitly deferred during
`001-core-inventory`'s planning — nothing here is a new idea, just the
backlog of what v1 deliberately didn't do. Roughly in dependency order;
after 003, the rest are independent and can happen in whatever order is
actually useful once the app is in daily use.

- **`002-live-market-value`** (**Shipped 2026-09-05** via
  [PR #11](https://github.com/EHaake/Trove/pull/11) — see
  `specs/002-live-market-value/` for the full record) — first imagined
  as pulling resale values from eBay, Reverb or Facebook Marketplace to
  *replace* the manually-entered `currentValueCents`. What shipped is
  narrower on purpose: a **Reverb asking-price indicator beside the
  person's value, never in place of it** — you pick the match from a
  candidate list, the pick fetches the current asking prices at once,
  and a slider between the typical low and high (10th–90th percentile)
  lets you set your own value from the median in one drag; the median,
  spread, count and age sit in a Market section on both detail screens,
  as a trend arrow on the rows, a Market sort, and a dashboard line
  always stated with its coverage. Figures and their history stay on
  the device that fetched them (a second, unsynced SwiftData store);
  only the match and the year sync. No source offers sold prices to a
  non-partner, so no *market* "sold" figure exists anywhere in the app,
  and a crawler was declined on terms and privacy grounds (spec Decision
  1). `006` added the only sold price Trove will ever hold: the one the
  person types in for their own sale.
  `PRIVACY.md` and the one-time notice came with it.
- **eBay asking prices** — the follow-up `002`'s Decision 1 deferred.
  Two prerequisites before it can be scoped: a **hosted proxy service**
  (eBay's token flow needs a secret that cannot ship in an iOS app, and
  its licence forbids persisting or modelling prices from its content,
  so the app could only ever display what a server relays), and a
  **decision to accept that access** — production access is documented
  as partner-only. Cameras and hi-fi, which Reverb barely covers, wait
  on this. `005-stock-photos` added a second reason to want it:
  Wikimedia has little or no coverage of brand-new premium gear (no
  standard Hasselblad X2D 100C body, for one), and eBay is where photos
  of current-market gear actually live — so the same proxy would close
  the stock-photo gap and the asking-price one together.
- **`003-trend-aware-sell-plan`** (**Shipped 2026-09-07** via
  [PR #15](https://github.com/EHaake/Trove/pull/15) — see
  `specs/003-trend-aware-sell-plan/` for the full record) — the Sell
  Plan's ranking now factors in the market trend within a desire level:
  rising first, then flat or unknown, then falling, with the 001 order
  inside each group and desire never overridden. Each matched row shows
  the Reverb median with the arrow beneath its category, and a rising row
  says by how much and since when in one sentence. Built on `002`'s
  on-device history and its seven-day ±5 % trend, with a seeded
  collection (`-uiTesting -seedSellPlan`) so the UI test could exercise
  a ranking no real device had the history for. Follow-ups it recorded:
  - **Dynamic Type** (spec Decision 11) — every font in the app is
    fixed-size, a `001` limitation this spec inherited; worth its own
    spec, since it touches every screen.
  - **Fixed** (`fix/stale-trend-arrows`, 2026-09-07) — **the list rows'
    stale arrows** (Decision 12): the item list and wishlist rows drew
    the trend arrow on a figure older than thirty days, where the Sell
    Plan, the Market section and both Market sorts all stay silent.
    Both list view models read `MarketSummary.trend`, the stored
    classification, rather than the freshness-gated `currentTrend` the
    figure itself goes through; they now read the same gate, so the
    arrow cannot outlive the figure it sits on.
  - **Fixed** (`fix/sell-plan-row-narrow-width`, 2026-09-07) — **the
    Sell Plan row at a narrow width** (sweep S1): the market line, the
    value and the dial were all rigid, and the render test settled it
    at a floor of **355 pt** — more than the row gets on any iPhone but
    a Max, not the 320 pt edge case the sweep supposed. Over the floor
    the row's content spilled out of its own card at both edges. The
    market line's `fixedSize(horizontal: true)` is gone; `lineLimit(1)`
    renders identically everywhere measured and shortens the figure
    only where the row cannot hold it. T004a's `layoutPriority(1)`,
    measured in the same pass, turns out to be inert — kept, and its
    comment now says so.
- **`004-themes`** (**Shipped 2026-09-09** via
  [PR #20](https://github.com/EHaake/Trove/pull/20) — see
  `specs/004-themes/` for the full record) — **Light mode** of the
  existing brass/moss/rust identity (a paper-ground variant, not new
  hues), plus a **System / Light / Dark** choice in Settings. System
  follows the device live with no relaunch; Light and Dark are explicit
  overrides; the default is Dark for everyone, so an existing install
  updates to exactly today's look. The choice is stored per-device in
  `UserDefaults` and does not sync (spec Decision 4) — the app's first
  stored preference. Spent the semantic `Theme` abstraction `001` built
  for exactly this: light mode was "inject a different `ThemeColors`
  instance," its Oklab-derived tokens pinned and its dial/gauge/trend
  perceptual guarantees re-earned on the light ground, not a redesign.
  The exported PDF is unaffected (its `PrintPalette` is paper-fixed).
  **Alternate-hue colour themes remain deferred** to their own spec and
  Design pass (spec Decision 1, the same reasoning that held `008`/`009`)
  — this spec was deliberately light-mode-only.
- **`005-stock-photos`** (**Shipped 2026-09-13** via
  [PR #21](https://github.com/EHaake/Trove/pull/21) — see
  `specs/005-stock-photos/` for the full record) — an item with no photo
  of its own borrows one from **Wikimedia Commons**: **Find a photo…**
  sends the item's name and nothing else, a picker offers a small set of
  candidates with their author and licence, and the one you pick is
  stored on the item as a `Photo` with `source = .fetched` — the case
  that has sat unused on the model since `001`. It shows on the detail
  and as the row thumbnail, badged as a stock photo and carrying its
  credit — photographer, licence, and a link back to the Commons file
  page — in the app and in the PDF export. Only CC-BY, CC-BY-SA, CC0 and
  public-domain files are ever offered; the source was chosen for that
  reason, since it is the only one whose terms permit *storing* the
  image, which is what lets a fetched photo sync to your other devices
  and show offline like a photo you took. A one-time notice precedes the
  first search, nothing is fetched on launch, on appear or in the
  background, and `PRIVACY.md` names the second service. What it
  recorded on the way out:
  - **Photos *of* the gear, not photos taken *with* it** (spec
    Decision 7, added from the person's device testing) — Wikimedia's
    text search matches gear named in a photo's capture metadata, so
    portraits shot on an X2D came back for "Hasselblad X2D". The picker
    drops any candidate categorized as taken with the same model
    searched. **Filter-only for v1**: broadening an over-specific name
    ("…100C ii" → "X2D") is deferred, so a name Wikimedia has no product
    shot for still shows the empty state.
  - **Wikimedia's coverage gap for brand-new premium gear is real, and
    the deferred eBay source is what would close it** (the person's
    Phase 3 device testing, 2026-09-10). Commons has no standard
    Hasselblad X2D 100C body — only a CC0 "Earth Explorer" limited
    edition — and the same thinness applies to most gear released in the
    last year or two. eBay carries current-market photos of exactly that
    gear, but reaching it needs the hosted proxy `002`'s Decision 19
    flagged, so it stays a follow-up spec (see the eBay entry above),
    not a patch to this one.
  - **Reusing Reverb's catalog image for matched music gear** (spec
    Decision 1) — noted as a possible later enhancement, not built.
    Reverb's terms are hotlink-only and matched-music-only, so its image
    could be *shown* beside a matched item but never stored, never
    synced and never exported: a different feature from this one, with a
    different privacy and offline story, and it would only ever cover
    items that already have a Reverb match.
- **`006-mark-as-sold`** (**Shipped 2026-09-15** via
  [PR #23](https://github.com/EHaake/Trove/pull/23) — see
  `specs/006-mark-as-sold/` for the full record) — the entry read: "Real
  transaction tracking for the Sell Plan: marking a planned item as actually
  sold, removing it from inventory, a sale history. Deliberately excluded from
  `001` to keep the Sell Plan a decision-support tool rather than a ledger —
  worth revisiting once it's clear the decision-support version is actually
  useful day to day." It was. What shipped: **Mark as sold…** from an item's
  page and from a Sell Plan row, asking for a price, a date, a place and a
  note; the sold
  item leaves the collection, every Dashboard figure and every plan's
  candidates, and lands on a **Sold side of the Items tab** one tap from Owned,
  where each row says in words whether it sold at a gain or at a loss and by
  how much. A **Sold card** on the Dashboard jumps there; the Sell Plan gains a
  third **Sold** figure and lists what was actually sold toward it, still
  subtracting nothing from the cost; the items CSV grows four appended columns
  and imports them back as a pair; the PDF stays a document of what you own.
  A sale can be undone — Return to collection restores the item at its old
  place in the custom order with no sale. What it recorded on the way out:
  - **The sale lives on the item, not in a `Sale` model** (plan Q1). The
    deciding reason was sync: fields travel as one CloudKit record, where a
    relationship is a second record that can arrive before or after its item,
    so a second device could briefly show a sold item as owned.
  - **"Sold" is still only the person's number.** `002`'s rule — no market
    sold price anywhere in the app, because no source offers one to a
    non-partner — is untouched. The only sold figure in Trove is the one that
    was typed in.
  - **What the person's walkthrough found was layout, motion and wording —
    and the two motion findings only yielded to measurement** (spec Decisions
    12–14): an Owned side emptied by selling needed its own empty state, the
    Sold side's stats line had to stay at zero sales (the switch was jumping
    19.7 pt), and the stutter beneath it turned out to be a
    `matchedGeometryEffect` crossfading across an insert/remove rather than
    sliding — visible only in a screen recording, per frame. **Two questions
    are left open for the person, both copy or placement, neither a defect**: a
    sell plan whose candidates have all sold still shows the "Nothing to sell
    yet" empty state above its sold rows, and the person did not find **Mark as
    sold…** in the item page's "…" menu, where Decision 4 put it — whether a
    visible control is wanted is theirs to say.
- **Considered, not planned — a visible Mark as sold button on the item
  page.** Proposed in `014-sold-side-parity`'s first Draft (2026-09-16) and
  withdrawn by the person at their reading: the page's bottom is not to
  become a shelf that more and more actions get added to. The "…" menu row
  and the Items list's leading swipe are the ways in. Revisit only if the
  menu row keeps going unfound in daily use.
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
    mechanics (append-only column growth). *(`002` did the CSV half —
    `Reverb Product ID` and `Year` appended, `012`'s parser widened —
    and overrode the PDF half by its P17: the fetched figures are
    per-device asking prices, not the person's values, so the PDF
    carries the match and the year but never the figures.)*
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

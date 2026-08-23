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
| `001-core-inventory` | In progress — see specs/001-core-inventory/ |

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

  The container facts, corrected at `001`'s sign-off (this entry
  previously claimed all of Trove's rows were `ScrollView`-based, which
  was half wrong and would have sent whoever picks this up hunting for a
  problem already half solved):

  - **`WishlistView` is a `List`** — since its first commit (T036),
    because spec-required drag reordering is a `List` capability — and
    therefore *already has* swipe-to-delete via `.onDelete`. As of the
    `001` sign-off it presents the same cascade-consequence alert the
    detail screen shows (shared `WishlistDeleteCopy`), routed through
    `WishlistViewModel.delete(id:)`. It also demonstrates that `List`
    can host Trove's custom row styling: plain list style, hidden
    separators, clear row backgrounds, custom insets, and tap-gesture
    navigation instead of `NavigationLink` (which is what avoids the
    disclosure chevrons a naive conversion shows).
  - **`ItemListView` is a `ScrollView` + `LazyVStack`** and has no
    row-level delete at all — deletion lives on the detail screen. This
    is the real scope of the swipe-to-delete work: either convert it to
    a `List` following the wishlist's proven pattern, or build a custom
    gesture. The wishlist's existence makes the `List` route much less
    speculative than this entry previously suggested.
  - If instant-delete-with-undo (the Mail model) ever feels better than
    confirm-then-delete, that's a `010` decision too — the shared-copy
    alert was chosen at `001` for consistency with the detail screens,
    with the undo model noted as the alternative.

  Also parked here from the `001` sign-off: the wishlist rows' desire
  gauge is deliberately unlabeled (the label lives in the form and
  detail screen, where the value is set and learned), but there's a real
  first-encounter observation that an unlabeled three-segment gauge
  doesn't read as a *desire* gauge on sight. Revisit alongside the other
  item-management interactions rather than patching one row now.

## Working convention

Per `CLAUDE.md`: one branch per spec, no new spec branch starts until the
current one is merged to `main`. This roadmap is a backlog, not a
commitment to order — pick whichever spec is actually useful next once
`001-core-inventory` ships and the app's in real use.

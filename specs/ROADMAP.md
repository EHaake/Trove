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

## Working convention

Per `CLAUDE.md`: one branch per spec, no new spec branch starts until the
current one is merged to `main`. This roadmap is a backlog, not a
commitment to order — pick whichever spec is actually useful next once
`001-core-inventory` ships and the app's in real use.

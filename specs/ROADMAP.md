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

Every sync, two-device, offline and signed-in check that no spec has run yet
is in [`SYNC-CHECKS.md`](SYNC-CHECKS.md), one checklist for one sitting with
two signed-in devices. A "partial" or an unticked criterion below that is
about sync is listed there.

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
| `006-mark-as-sold` | **Shipped** — merged to `main` 2026-09-15 via [PR #23](https://github.com/EHaake/Trove/pull/23); twenty tasks (T001–T020) with ten sub-lettered additions — three of them from the person's walkthrough at the Phase 5 pause (T018a–T018c) and one from the device pass (T018d) — seventeen criteria (1–16, with 7a) verified with per-criterion records in `spec.md` and **two honest partials named** (no second device for the sync check; the VoiceOver reading is the person's step) — both done (the person, 2026-09-16), and both criteria ticked. The app's **first record of a real transaction** — a sale is four fields and a link on the item itself, so it syncs as one record and "Return to collection" is nil-ing them; the Items tab grows a Sold side beside Owned, the Dashboard a Sold card, and the Sell Plan a third figure that still subtracts nothing. Three things were settled by measurement rather than argument: a 19.7 pt jump in the Owned/Sold switch, the stutter beneath it (a `matchedGeometryEffect` across an insert/remove crossfades instead of moving), and the sale sheet presenting exactly once per confirm (a probe inside the writer, not a screenshot). Xcode 27 arrived mid-spec and the branch carries the toolchain fixes and a warning-free build. The second spec measured under the model policy's **experiment 1**, its tier log in `tasks.md`. |
| `014-sold-side-parity` | **Shipped** — merged to `main` 2026-09-19 via [PR #25](https://github.com/EHaake/Trove/pull/25); all tasks through T011's close-out done (2026-09-18), every criterion verified — criterion 12 attested by the person with Accessibility Inspector on 2026-09-19, so the spec closes with no partials; eleven tasks with eleven sub-lettered additions (T009a–T009i for Decision 7's export scope and the dropdown-anchor defect it uncovered, T010a for the device pass's criterion-3 finding, T010b for the Phase 2b sweep), **1540 unit tests in 208 suites** and **23 UI tests** green, the UI suite twice back to back. Thirteen of fourteen criteria verified with per-criterion records in `spec.md` and **one honest partial named** (criterion 12's Accessibility Inspector sweep is the person's step). The two things `006` left the person fighting — **Mark as sold…** hidden in a menu, and a Sold side with no way to find anything in it — answered by a Sell action on the leading swipe and the Owned side's search, chips and sort on Sold, each side keeping its own. The person's Phase 2 reading added Decision 7 mid-spec: exports from the Items list now choose owned, sold or both, for either format, with a "Sold Items" PDF of its own. Two claims the work falsified are recorded in `plan.md`'s **As built** — a header equality that held only while nothing sat beside it (the device pass measured it 13.67 pt out, and two guards now hold it), and an `anchorPreference` that silently dropped two of three dropdown anchors. The session moved to the stepped-down Opus model at the person's instruction from T010 on; its tier log is in `tasks.md`. |
| `015-mark-as-bought` | **Shipped** — merged to `main` 2026-09-21 via [PR #29](https://github.com/EHaake/Trove/pull/29); all tasks through T013's close-out done (2026-09-21); thirteen tasks with eight sub-lettered additions (T006a from the Phase 1 review, T011a from the Phase 2 review, T011b and T012a–c from the person's two pauses, T012d–e from the review that followed), **1622 unit tests in 224 suites** and **25 UI tests** green, the UI suite twice back to back. Fourteen of fifteen criteria verified with per-criterion records in `spec.md` and **one honest partial named** (the two-device sync check — nobody has run it and no agent can). The buying half of the core loop, which the app had never had: **Mark as bought…** from the wishlist swipe, the wanted item's menu and its Sell Plan, one sheet for price, date, place and condition, and an item that carries the entry's photos, credits, category, Reverb match, year and notes across. The wanted entry is **marked, not deleted**, so the sell plan built around it survives as the record that it was carried out — which finally gives `009-sell-plan-list` a definition of "active". No undo, by the person's decision. The Phase 1 review caught that a purchase could happen **twice** (a second `Item`, and the first purchase's marker overwritten) — visible only at phase level, fixed in the one writer. The person's two pauses added four changes mid-spec: sentence case on the comparison line, at the Phase 2 pause; then at the walkthrough, a word instead of a bag glyph on the Sell Plan, an alert when a purchase is refused, and a saved sell plan leaving a trace on the wanted item's page. |
| `009-sell-plan-list` | **Complete** — all tasks through T016's close-out done (2026-09-23), pre-merge sweep pending; twenty-one tasks (T001–T021, Amendment A's T017–T021 among them) with six sub-lettered additions (T009a–T009d from the Phase 3 walkthrough, T014a from the Phase 4 walkthrough, T021a from the Phase 4A walkthrough), **1746 unit tests in 234 suites** and **36 UI tests** green, both suites twice back to back. Twenty of twenty-three criteria verified with per-criterion records in `spec.md`; **criteria 17, 20 and 22 stay unticked** because their sync halves are untested — the person cannot run a two-device pass yet, and every sync step is gathered in `specs/SYNC-CHECKS.md` for one later pass. The person's Accessibility Inspector and VoiceOver pass is done. **A sell plan becomes a thing you create**, stored on the wanted item, active until the thing is bought and completed after, rather than inferred from whichever candidates are ticked — which is what let a plan survive every item on it selling. Existing plans carry over **once, recorded on each row**, so a plan deleted on one device cannot be resurrected by another. A **fourth tab**, Plans, lists Active and Completed with a sort each, a Buy swipe, a delete swipe and a read-only record for a completed plan, and a Dashboard card counts the active ones. The person's walkthroughs added **Amendment A** mid-spec: Delete as its own rust button on the Sell Plan, two app-wide standards (a destructive action is always rust — a `CLAUDE.md` amendment; a card responds anywhere in its box), completed rows showing the bought item's picture through a new purchase record, Settings from every tab, and Delete All Sell Plans. |

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
    spec, since it touches every screen. **Numbered `017-dynamic-type`
    on 2026-09-19** — see its entry below.
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
  become a shelf that more and more actions get added to. **`014` shipped
  the alternative instead** (2026-09-18): the Items list's leading swipe
  now offers Sell between Edit and Copy, opening the same sale sheet, and
  the Sold side gained the Owned side's search, category chips and sort —
  so the menu row is no longer the only way in, and the Sold side is no
  longer a flat list. Revisit the button only if the swipe and the menu row
  both keep going unfound in daily use.
- **Follow-up from `014` — one shared list header.**
  `WishlistView.header` carries the identical construction the Items header
  had before `014` fixed it: a title-and-meta `VStack` beside the badges in
  one `HStack`, so the meta line only gets the width the badges leave it.
  That is the **same latent wrap** `014` measured on the Items list (the
  sold summary broke onto a second line and pushed the side switch 13.67 pt
  down), and it will surface on the Wishlist the day a long sort label meets
  a long meta line. `014` deliberately did not change it — out of that
  spec's footprint, and no criterion covers the Wishlist's header. The fix
  is to extract the one `ItemsListHeader` both screens use, with
  `ItemListHeaderLayoutTests`' height guard extended to the Wishlist's
  summaries. Small, mechanical, and worth doing before the next screen
  grows a badge.
- **`fix/swipe-glyph-contrast-in-light`** — a defect in **already-merged**
  code, observed by `015`'s device pass on both appearances and correctly
  scoped as not that spec's to fix. In **Light**, the leading swipe's Edit
  and Copy glyphs are white on a near-white circle and read faintly; `015`'s
  new Buy button, on `accentBrassMid`, is the legible one of the three. The
  contrast pair that matters was measured at `014` T010 and is fine; what
  was never measured is the *grey* buttons' glyph against their own fill.
  Measure it, and fix the fill or the glyph rather than the tint that passes.
  Affects both lists, since `014` made them one pattern.
- **`fix/wishlist-duplicate-loses-photo-credit`** — a licence-compliance
  defect in **already-merged** code, found while planning `015` and
  deliberately not fixed there. `WishlistViewModel.duplicate(id:)` rebuilds a
  copied entry's photos through `Photo(imageData:source:sortOrder:)`, which
  writes **none** of the three attribution fields — so duplicating a wanted
  item that carries a `005` stock photo produces a copy whose photographer,
  licence and source link are gone, while the photo itself is still shown.
  That is the credit `005` exists to keep, and the app is showing a
  CC-licensed image without it. Found because `015` Q6 had to decide how the
  purchase moves photos and refused this exact shape: the purchase **moves**
  the `Photo` rows by rewriting their two parent links, so nothing is
  reconstructed and nothing can be dropped. The fix is the same instinct
  applied to the duplicate — carry the three fields across (or construct
  through an initializer that cannot omit them) — with a test asserting the
  copy's credit, which is what `015`'s G6 does for the move. No criterion or
  plan section in `015` authorised touching it, and `CLAUDE.md` gives a
  merged-code bug its own branch. Check `ItemListViewModel.duplicate(id:)` for
  the same shape at the same time.
- **Follow-up from `015` — the Wishlist unwind should read as one movement.**
  Buying from a Sell Plan screen pops two screens, and they animate
  **sequentially**: the wanted item's detail page is drawn fully on screen,
  static, for **270–330 ms**, still reading WANTED, before it slides off.
  Measured and filmed at `015`'s device pass, taken to a decision review and
  **accepted for that spec** — criterion 8 is about surfaces and copies, and a
  stack unwinding is not a surface. The cause is not a platform defect: the
  detail screen's dismissal cannot be *requested* until its `.onAppear` fires,
  and `.onAppear` fires as the screen comes on, so the serialisation is
  entailed by the trigger's design. The fix direction, so the next spec does
  not repeat the analysis: **own the Wishlist's route at the root** so a
  purchase can pop to root in one movement. The tab is
  `NavigationStack { WishlistView(…) }` with **no path binding** today, unlike
  Items' `$router.itemsPath`, which is exactly why popping to root was not
  available cheaply in `015`. It rewrites `015`'s G18, whose `dismiss()` leg
  is deliberately scoped inside the `markBought` branch. Do it with whatever
  next touches Wishlist navigation.
- **Follow-up from `015` — a refused *sale* is still silent.**
  `015` gave a refused **purchase** an alert on all three of its hosts, at the
  person's instruction. The sale side still has the shape that was wrong:
  `SellPlanViewModel.markSold` writes `saveFailureMessage` and **no view reads
  it**, so a refused sale closes the sheet and says nothing. `015` could not
  fix it — its Non-goals forbid touching the sold side, and sharing the
  purchase's property would have surfaced a refused sale from the buy path.
  The fix is `015`'s own pattern: an alert on the host's view (not on the
  sheet's content, which is what keeps SwiftUI from dropping it), presented
  off the existing property, with the binding's setter clearing it.
- **Follow-up from `015` — a UI-test seed that produces a saved sell plan.**
  **Done in `009`** (T014, 2026-09-23): `-seedPlans`, under `CLAUDE.md`'s two
  conditions (its own argument, and gated on the built store being the
  in-memory one), seeds six wanted items through the app's own writers,
  including a saved plan with an item set aside, one whose selection a sale
  emptied, a completed plan and a pre-`009` row for the launch carry-over.
  The wanted page's "View your sell plan" state now has UI coverage
  (`testCreatingASellPlanFromAWantedItem`). **Still open from this entry**:
  no UI test drives a real purchase **refusal**, so the refusal alert's
  automated coverage is still the source scan it had. The seed now makes
  that test possible. The original entry:
  `-seedSellPlan` seeds candidates but has **never** assigned
  `plannedSaleItems`, so no UI test in this project has ever seen a saved
  plan. Two things `015` shipped therefore have no UI-suite coverage: the
  wanted page's "View your sell plan" / "<n> items set aside" state, and the
  refusal alert, whose only automated coverage is a source scan that would
  stay green if the alert were deleted and the string kept (the mechanism was
  confirmed once by hand on the device). Needs a **second** seed argument
  under `CLAUDE.md`'s two conditions — gated on the store the app actually
  built being the in-memory one, and separate from `-uiTesting` so every
  existing test keeps the starting state it was written against.
- **Follow-up from `015` — audit `*WiringTests` for unscoped substring
  checks.** Two shapes, both found in `015` and **both present in merged
  code**. An identifier check written as `code.contains("sale.sheet.price")`
  is satisfied by the longer literal `"sale.sheet.priceX"`, so renaming the
  identifier leaves the guard green (`SaleFormWiringTests.theIdentifiersArePresent`
  is a known instance; `015` caught its own copy before it landed and compares
  whole string literals instead). And an alert-message check read over the
  **whole file** is satisfied by a *neighbouring* alert's message closure —
  `WishlistView` carries four alerts and `WishlistDetailView` two, and during
  `015`'s mutation a `grep` confirmed the old leg would have stayed green on
  exactly the mutation it was supposed to catch. The export, import and delete
  alert checks were not looked at. Per `CLAUDE.md`'s audit-the-shape rule this
  is the sweep the second finding asks for, and per its merged-code rule it is
  a `fix/` branch, not a spec. One mechanical note for whoever does it: an
  alert's `message:` is a **trailing** closure, so
  `SourceScan.argumentLists(of: ".alert")` can never contain it — the
  slice-and-scope shape in
  `WishlistPurchaseWiringTests.everyPurchaseHostShowsTheRefusalAlert` is the
  one that works.
- **Follow-up from `015` — one shared field chrome for the three sheets.**
  `PurchaseFormView` copies `SaleFormView`'s chrome, which copied
  `ItemFormView`'s: the `PlateSurface` field plate, the label-plus-field
  pairing, the rust invalid border, the paired price/date row and the
  condition capsules now exist in three places. `015` Q8 chose the copy
  deliberately — the fields differ, and its Non-goals forbade changing the
  sale sheet — but three is the number at which a shared component stops being
  speculative. The extraction is mechanical and wants its own diff; nothing in
  the three sheets' behaviour should change, which makes it easy to verify and
  easy to keep putting off.
- **Follow-up from `009` — sell plans in the exports.** The person, at
  `009`'s Phase 4A walkthrough (2026-09-23): the Delete section's "Export
  first if you want a copy" is "fine for now, but we should add sell plans to
  the export eventually." `009` kept exports unchanged in shape (criteria 18,
  23): no plan, no selection, no plan date and no purchase record in the CSV
  or the PDF, so "Delete all sell plans" is the one Delete-all row whose
  footer's advice cannot save what it deletes. A spec of its own, since it
  changes both export formats and the import that must round-trip them.
- **Follow-up from `009` — one Settings sheet modifier for the four tabs.**
  The Settings sheet block — the `.sheet(isPresented:)`, the four
  environment reads it threads through (`storageMode`,
  `storageFallbackReason`, `AppearanceStore`, `colorScheme`) and the
  `onDismiss` reload — now exists in **four** copies, one per tab's root
  screen: `DashboardView`, `ItemListView`, `WishlistView` and, since `009`
  Amendment A, `PlansView`. `009` plan QA3 chose the fourth copy on purpose,
  since a shared `settingsSheet(isPresented:)` modifier would have rewritten
  three merged screens and `SettingsWiringTests`' two host tests for a
  feature that needed none of it. Four is the number at which it stops
  being speculative. It is mechanical, it wants its own diff, and
  `SettingsWiringTests.everyTabsRootReachesSettings`, which derives the
  hosts from the tab list, is the guard to keep green through it.
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
- **`009-sell-plan-list`** (**Complete 2026-09-23**, not yet merged — see
  `specs/009-sell-plan-list/` for the full record) — A dedicated view of every wishlist item that
  currently has an active Sell Plan (a non-empty `plannedSaleItems`
  selection)
  — *and note, from `015`'s sweep, that "non-empty" is a narrower definition
  than it looks: `ItemSaleStore.markSold` empties
  `plannedForWishlistItems`, so a plan whose every candidate has actually
  been **sold** reads as no plan at all. `015` T012c's trace on the wanted
  page disappears at exactly that moment, deliberately (nothing is set aside
  any more), but a list of "active" plans that drops a plan the moment it
  succeeds is probably not what this spec wants. Decide it here, since plan
  lifecycle is this spec's subject.* — no new persisted entity, just a new
  lens on data that already exists. Surfaced via a card on the Dashboard ("N active sell
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

  **Re-read 2026-09-19, after `006` and `014` shipped: worth more than
  when it was written, and now waiting on `015-mark-as-bought`.** Worth
  more, because `WishlistItem.itemsSoldToward` means a plan has
  *progress* — a row can say "3 of 5 sold, $1,240 raised of $1,800"
  rather than only `001`'s "3 of 5 candidates selected". Waiting,
  because the screen hangs entirely on the word **active** and the app
  has no definition of it: today the only one available is "you have
  ticked at least one candidate," and nothing can ever take a plan off
  the list again. Buy the thing the plan was funding and it still reads
  as active, forever. `015` supplies the ending — build this screen
  first and "active" quietly means "not un-ticked," which stops being
  true the day the buy side lands. `006`'s open question (a plan whose
  candidates have all sold still showing the "Nothing to sell yet"
  empty state) is the same missing lifecycle seen from another angle.

  **Unblocked 2026-09-21: `015` shipped, and "active" now has a definition.**
  A plan is active while its wanted entry is **not bought** —
  `WishlistItem.boughtDate == nil`, the predicate five read sites already use
  — and **completed** once it is, with `itemsSoldToward` kept and the unsold
  candidates released at the purchase. So this screen can list active plans
  and, if it wants, show completed ones as a record. Two things it inherits
  with the definition, both named in `015`'s Non-goals as `009`'s to handle.
  First, **a bought entry is invisible everywhere else in the app** — in no
  list and in no export — so until this screen ships, its retained sell plan
  has no surface at all and the unit tests are its only witness. Second, **a
  purchase corrected by hand leaves an orphan**: the person deletes the item
  and re-adds the want, which is a *new* entry, so the original marked-bought
  row stays in the store unreachable and will surface here as a completed plan
  for a purchase that never happened. This screen is the first place that can
  either show it, so it can be dealt with, or sweep it; `015` deliberately did
  neither, having nowhere to do it from.

  **How it was answered** (spec session 2026-09-21–22, and three
  walkthroughs). **A plan is a statement of intent, not a selection**
  (spec Decision 1): it is stored on the wanted item when the person taps
  *Create a sell plan*, it is active until the item is bought, and a plan
  whose every candidate has sold stays on Active. Existing plans carry over
  **once**, and the "once" is recorded on each row so it syncs with the row.
  **A fourth tab after all** (Decision 4), overturning the paragraph above
  on its own terms: "sell plans are a first class citizen, like owned items
  and wishlist items", so a plan is not a filtered slice of the wishlist but
  its own kind of record. A Dashboard card counts the active ones. **Counts,
  never money** (Decision 5): the "$1,240 raised of $1,800" row imagined
  above was declined, and a row says "Covered" once the sales alone reach
  the estimate. The orphan is **shown, not swept**: it appears on Completed
  and can be deleted there, and no automatic sweep was built. Deleting a plan
  deletes only the plan. Nothing sold is unsold, and the sold-toward record
  stays.
- **`015-mark-as-bought`** (**Shipped 2026-09-21** via [PR #29](https://github.com/EHaake/Trove/pull/29) — see
  `specs/015-mark-as-bought/` for the full record) — the other half of the
  core loop, and the one
  piece of it the app has never had. `CLAUDE.md`'s own description of Trove
  is "track what you own, track what you want to buy next, and use the gap
  between current value and original cost to plan sales that fund future
  purchases." `006` and `014` built the selling half properly. **Nothing
  records that the purchase happened.** There is no buy action, no
  wishlist→owned conversion, and no trace of the idea anywhere in the code
  or in this file — it was never deferred, it was never thought of.

  What that costs today: you sell three things toward a lens, `006` records
  them on `WishlistItem.itemsSoldToward`, you buy the lens — and then you
  delete the wishlist entry and retype the whole thing as a new item,
  losing its photos, its `categoryPath`, its `reverbProductID` match, its
  `year`, and the entire record of what paid for it. The app watches you
  save up and then looks away at the moment of purchase.

  The schema is most of the way there already. `itemsSoldToward` exists and
  is `.nullify`-ed precisely so those sales outlive the plan (`006` P5,
  P10). What is missing is the act and its record. The shape to scope,
  deliberately mirroring `014` rather than inventing a new idiom: a **Buy**
  action on the Wishlist's leading swipe beside the existing ones and on
  the detail screen's menu row; a sheet asking price, date, place and
  condition, as `SaleFormView` asks for the sale's four; an `Item` created
  carrying name, category, photos, Reverb match and year across; the
  wishlist entry leaving the list; and a link from the new item back to the
  sales that funded it, so the page can say whether they covered it.

  The real product questions, for the spec conversation rather than here:
  whether the Wishlist grows a **Bought side** the way the Items tab grew
  Sold (the parity argument from `014` says yes, the "don't build a shelf"
  instinct from the withdrawn item-page button says be careful), whether
  the funding link is shown on the item, on the bought wishlist entry, or
  both, and what happens to a purchase the sales did *not* cover. It also
  finally settles `006`'s open question about a sell plan whose candidates
  have all sold — a plan gets an ending.

  **`009-sell-plan-list` waited on this — it no longer does**; see its entry.

  **How the three product questions above were answered** (spec session,
  2026-09-19, and the walkthrough that followed). **No Bought side**: a bought
  thing is an item, it lives in Items, and the Wishlist grows nothing —
  `014`'s parity argument does not carry, because Owned and Sold are two
  states of *one* row whereas a Bought side would be a second copy of a row
  that now lives elsewhere. **No funding link on the new item**: the Sell Plan
  is guidance, not a trade ledger, and `006`'s `itemsSoldToward` already
  records what was sold toward the want — it is simply not *extended* onto the
  item. So the third question ("what happens to a purchase the sales did not
  cover") never arose. **No undo**, which was not one of the questions and
  turned out to matter most: returning a sold item destroys nothing, but
  un-buying would have to delete a row that by then may carry photos, a serial
  number or notes added since. A purchase marked in error is corrected by
  hand. Two consequences are accepted rather than solved, both `009`'s to
  address: the corrected entry's original marked-bought row stays in the store
  unreachable, and it will read as a completed plan once `009` has a screen.
- **`016-collection-value-history`** — how the collection's value has moved
  over time. The app knows what you paid and what things are worth right
  now, and the gap between those two numbers is its entire framing — but
  it is a snapshot with no past tense. `002` keeps per-product market
  history in the device-local store; **nothing records your collection's
  own total**, and `006`'s realized gains and losses from actual sales are
  charted nowhere.

  The unusual argument for doing this early rather than when it feels due:
  **it is the one spec whose value depends on having shipped it sooner.**
  A history feature built in six months opens on an empty chart either way.
  Built now, it has six months of data by then. Every month it waits is a
  month of history that does not exist.

  To scope: what gets snapshotted (total current value, total purchase
  cost, item count — and whether sold items' realized gain joins them),
  how often and on what trigger, and where the snapshots live. That last
  one is the interesting question and echoes a decision already made
  twice: `002` put market figures in a second, unsynced store because they
  are per-device facts, and `004` put the theme choice in `UserDefaults`
  for the same reason. A value history is *not* per-device — it is the
  person's own data and belongs in the synced store, which makes it the
  first new synced entity since `001` and brings the CloudKit rules with
  it (every property optional or defaulted, no `@Attribute(.unique)`,
  `CloudKitSchemaTests` extended). Where it surfaces is a Design question:
  a Dashboard line, a card that opens a chart, or a sparkline beside the
  hero total.
- **`017-dynamic-type`** — the iOS text-size setting, which Trove ignores
  completely. Recorded as a follow-up in `003`'s Decision 11 on 2026-09-07
  and never given a number; it is given one here so it stops aging inside
  another spec's footnotes.

  The state of it, from the code rather than from memory: every font in the
  app is built by one function, `ThemeTypography.font(_:size:weight:)`, and
  it returns `.custom(name, fixedSize: size)`. **`fixedSize:` is the
  initializer that explicitly opts out of scaling.** Below it sit hard
  numbers taken off Design's mock — a 30pt screen title, a 68pt dashboard
  total, 13.5pt body, 10.5pt mono labels. There is not one `relativeTo:`
  and not one `dynamicTypeSize` reference in the 127 source files. Set a
  phone to the largest accessibility size and Trove renders identically to
  the smallest, alone among the apps on the device.

  Two reasons it matters. It is an **accessibility floor, not a
  preference** — 10.5pt is unreadable for some people and there is
  currently nothing they can do about it; `014`'s criterion 12 needed an
  Accessibility Inspector pass by hand, the second spec running where
  accessibility was the person's manual step rather than something the
  suite covers. And **the bill grows with every screen**: the font change
  itself is nearly trivial (one function, one initializer, a text style per
  role), while the real work is every fixed row height, the desire dial's
  numeral sized off its own diameter, the header `014` already measured
  wrapping at default sizes, and the PDF export, which must *not* scale —
  `PrintPalette` is paper-fixed and its type should be too. `008`'s chips
  and `009`'s card rows would both be built at fixed sizes and then
  revisited.

  Related but distinct from `019` below: both are "the layout has only ever
  been asked to render one way." Dynamic Type stretches it vertically, the
  foldable horizontally, and a plausible scoping merges them. Kept separate
  because this one is an accessibility obligation the app owes today and
  the other waits on hardware.
- **`018-system-design-language`** — deciding, once, how much of Apple's
  design language the app wears. The occasion is a real inconsistency: the
  Dashboard and both list screens open the app's **own** dropdown surface
  from their "…", while the item and wishlist detail screens open a
  **system** `Menu` from the nav bar, and the tab bar at the bottom is a
  plain system `TabView` wearing iOS 26's liquid glass. Three different
  looks for the same gesture.

  **That split is not an accident, and this entry exists to reverse a
  decision rather than fix a bug.** `013` Amendment A, Decision 17 and
  criterion 27 set the standing rule — *bespoke inside the page, system in
  the bars* — and it is enforced: `MenuPolicyTests` walks every file under
  `Trove/Views` and `Trove/App` and **fails the build if a system menu
  appears inside page content**, allowlisting `DetailOverflowMenu.swift`
  alone. The guard is pointed the opposite way from where this spec wants
  to go, so adopting system menus means rewriting the policy and its test
  together, deliberately and in the open — not quietly deleting a red test,
  which `CLAUDE.md` forbids for good reason.

  The person's position, recorded 2026-09-19: lean **system**, because the
  tab bar already wears liquid glass, because more default iOS means less
  bespoke surface to build and maintain, and because it keeps the app
  conformant with Apple's current language. The honest counterweight, so
  the spec conversation has both halves: the rule reaches further than the
  "…" menus — `SideSwitch` (the Owned/Sold switch), the Sell Plan's own
  control and `SortPicker` are all bespoke *under this same rule*, so
  "go system" plausibly means a system `Picker` where `006` and `014` spent
  real effort measuring a 19.7 pt jump and a `matchedGeometryEffect`
  stutter out of a custom one. `013` also records that the person found the
  still dropdown **stiff**, which is why it grows out of the badge with a
  fade, and `OverflowDropdown` carries group breaks the system menu it
  replaced had none of. Those are things a system menu will not do.

  So the question to settle is not "system or bespoke" in the abstract but
  **where the line falls now**: menus and pickers to the system, with the
  app's identity carried by type, colour and the content of the cards
  rather than by the chrome, is one coherent answer — and probably the one
  the lean above points at. Worth a Claude Design pass, since it changes
  how most of the app looks. **Settle this before `019`**, so a foldable
  layout is not drawn around bespoke surfaces that are then thrown away.
- **`019-foldable-layout`** — a design for the foldable iPhone Duo,
  announced for release soon (noted 2026-09-19). The occasion is new
  hardware; the work underneath it is adaptive layout, which this app has
  never done at all.

  How narrow the app currently is, from the project file rather than from
  impression: `TARGETED_DEVICE_FAMILY = 1` (iPhone only, no iPad),
  `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone =
  UIInterfaceOrientationPortrait` (portrait locked), and **zero**
  references to `horizontalSizeClass`, `verticalSizeClass` or
  `NavigationSplitView` across all 127 source files. Trove has exactly one
  layout, drawn for one width, and has never been asked to be anything
  else. An unfolded foldable is not a wider iPhone — it is a different size
  class, where a single-column list of cards at 800-odd points reads as a
  mistake, and where the Dashboard/Items/Wishlist split is a natural
  two-column arrangement the app has no structure for.

  Two prerequisites before this can be scoped honestly. **The device's
  actual metrics and an SDK/simulator for it** — screen dimensions, the
  folded and unfolded size classes, how the transition is delivered to a
  SwiftUI app, and whatever Apple's own guidance says; none of that should
  be guessed at, and nothing in this entry does. And **a `.pbxproj`
  change**, since the orientation lock and possibly the device family have
  to move — `CLAUDE.md`'s "Project file safety" section says to stop and
  flag that before doing it, not fold it into an unrelated task, so it
  belongs in this spec's own first task with the person's sign-off.

  Related work already on the page: `003`'s `fix/sell-plan-row-narrow-width`
  measured the Sell Plan row's floor at **355 pt** and found the row
  spilling out of its own card below it — the one existing datapoint that
  the layout has real width sensitivities, and it was found at a *narrow*
  width. `017` above is the vertical half of the same unexamined
  assumption, and settling `018`'s chrome question first keeps this pass
  from designing surfaces that are about to be replaced.
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

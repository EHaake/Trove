# `018` — text for `main` after the merge

Drafted at T014's close-out (2026-09-30). Apply to `main` once the branch
has merged: `specs/ROADMAP.md` may be committed straight to `main` (the
constitution's one exception); `DECISIONS.md` goes with it. Fill in the
merge date where it says `<merge date>`. Nothing here is live until then.

---

## `specs/ROADMAP.md`

### 1. The status table — a new last row, after `009-sell-plan-list`

| `018-system-design-language` | **Shipped** — merged to `main` `<merge date>` via [PR #32](https://github.com/EHaake/Trove/pull/32); every task through T014's close-out and the pre-merge sweep done (2026-09-30); fourteen tasks (T001–T014) with nine sub-lettered additions, every one from the person's walkthroughs (T004a–T004b at the Phase 1 pause, T006a at Phase 2, T009a–T009f at Phase 3), **1740 unit tests in 231 suites** and **38 UI tests** green at the close-out, both suites twice back to back (the counts are in `tasks.md`). Thirteen of sixteen criteria verified with per-criterion records in `spec.md`; **criteria 8, 11 and 15 wait on the person** — the Dark add button's plus at 2.6:1, the Accessibility Inspector pass, and the one-language attestation *(update this sentence at the merge if the person has answered)*. **The rule `013` wrote is reversed, in the open: system controls, Trove content.** Every menu in the app is now the system's, the header's buttons wear Liquid Glass like the tab bar, and `MenuPolicyTests` guards the new line after `CLAUDE.md`'s example of it was reworded in its own commit. The spec measured T029c's tear before converting anything (gone on iOS 27.0; a self-correcting transient on 26.5 that the person accepted to keep the system's morph). The system segmented control proved unstyleable, so the Owned/Sold and Active/Completed switches became a glass side toggle, brass on the primary side. Six bespoke files and four test suites retired. The system navigation bar and toolbar on the tab roots are the next spec, `020`, before `019`. |

### 2. The `018` backlog entry, rewritten as shipped (replaces the whole entry)

- **`018-system-design-language`** (**Shipped `<merge date>`** via
  [PR #32](https://github.com/EHaake/Trove/pull/32) — see
  `specs/018-system-design-language/` for the full record) — deciding,
  once, how much of Apple's design language the app wears. The occasion
  was a real inconsistency: the list screens and the Dashboard opened the
  app's own dropdown from their "…", the detail screens a system menu from
  the navigation bar, and the tab bar wore iOS 26's glass — three looks for
  one gesture, produced on purpose by `013` Amendment A's rule (*bespoke
  inside the page, system in the bars*) and enforced by `MenuPolicyTests`.
  **What shipped: system controls, Trove content.** Sort By, every "…" and
  the Dashboard's order control open the system's menu; the three header
  controls (Sort By sized to its label, a side toggle, the "…" as a glass
  circle) and the add button wear Liquid Glass; the headers' type, the
  cards, rows, chips, dial, gauge and slider stay Trove's. The rule and its
  guard were rewritten together — `CLAUDE.md`'s example first, in its own
  commit — never deleted to get green. Two things were settled by
  measurement: T029c's tear, filmed first (clean on 27.0; on 26.5 a
  transient of about 1.5–1.8 s that the person accepted to keep the
  system's menu-to-button morph), and the system segmented control, which
  takes no font and no colour from SwiftUI and so became a glass toggle
  showing the current side, brass on Owned and Active. The person's
  walkthroughs also moved the page title to 34 pt centred on the controls
  and centred the meta line beneath them. **Left open for the person at
  the close-out:** the Dark add button's white plus on brass at 2.6:1;
  Reduce Motion does not stop the toggle's blur; on iOS 26.5 every
  trailing control sits 5 pt further from the edge than on 27.0.

### 3. A new entry, placed immediately before `019-foldable-layout`

- **`024-system-navigation-bars`** — the system navigation bar and
  toolbar on the tab roots, the step `018` deliberately stopped short of
  (its Decision 11 and first non-goal). `018` put the header's buttons in
  Liquid Glass but kept Trove's own standing header on Items, the
  Wishlist, Plans and the Dashboard: the title, the meta line and the
  three controls in a row the app lays out itself (`TitleRowLayout`,
  `MetaLineSpacing`, the `listTitle` token). The fully Apple-shaped
  answer is the title in a navigation bar and Sort By, the side toggle
  and the "…" in an iOS 26 toolbar, which also unlocks iOS 26's floating
  bottom search (it needs the navigation bar above, which is why `018`
  left the search field in the body). It is a redesign of every list's
  top, and the questions are real ones: where the meta line lives when
  the title is the system's; whether a large title collapsing on scroll
  suits screens this short; what becomes of the headers' measured
  geometry and of `MenuPolicyTests`' "every header control" line once the
  controls are toolbar items; and whether the iOS 26.5 artefacts `018`
  accepted (the Sort By transient, the 5 pt trailing offset) survive in a
  system toolbar. **Settle this before `019`**, for the same reason `018`
  came first: a foldable layout should not be drawn around a header that
  is about to be replaced.

---

## `DECISIONS.md` — a new section, after `009`'s

## System controls, Trove content (`018`, complete 2026-10-01)

The product decisions are numbered 1–23 (plus the P-items) in
`specs/018-system-design-language/spec.md`. Decisions 15–23 came from the
person's walkthroughs at the three phase pauses. This records what reaches
beyond that spec.

- **The rule was reversed, and its guard with it, in the open** (spec
  Decisions 1–3, 5, 12 and 13). `013` Amendment A had written *bespoke
  inside the page, system in the bars* and made it a failing build:
  `MenuPolicyTests` walked every view and allowed a system menu in one
  file. The person chose to lean system — the tab bar already wore
  Liquid Glass, less bespoke surface is less to build and maintain, and
  it keeps the app in Apple's current language — and to settle it before
  `019`, so a foldable layout would not be drawn around surfaces about to
  be thrown away. The new line is **system controls, Trove content**:
  every menu, picker and switch is the one iOS provides; the app's
  identity moves off its chrome onto its type, its colour and what its
  cards say. The order of work was the point. `CLAUDE.md` quoted the old
  guard as the example of a legitimate source scan, so its example was
  reworded first, in its own commit ("every header control opens a system
  menu and no view floats a surface of its own", noting that it quoted
  `013`'s opposite rule until `018`), and only then was `MenuPolicyTests`
  inverted: each tab root, derived from `ContentView`, composes the
  system menus; no view floats a surface through anchor preferences;
  glass in exactly four files; no appearance proxy. It was broken
  deliberately — a bespoke row put back on the Wishlist's Sort By — to
  show it goes red. The merged decisions it reverses keep their text,
  with a pointer appended in `013`'s spec, `010`'s tasks, `014`'s spec and
  `009`'s plan, and `design/brief.md` quotes the old rule as superseded.
  The general rule: **a guard pointed the wrong way is rewritten with the
  policy that points it, never deleted to get to green.** Blind spots the
  Phase 4 review named (a bespoke overlay beside a kept `SortMenu(`, the
  `Button(action:)` spelling, `backgroundPreferenceValue`, an explicit
  `GlassButtonStyle()`) are carried to `024`.
- **The tear was measured before anything else, and its result decided
  a trade** (criterion 1, P4, Decision 18). `010` T035 took the system
  `Menu` off Sort By because of T029c's tear, so putting it back started
  with a film, not an assumption. T002: clean on iOS 27.0; on 26.5 the
  tear in a settled form, the capsule left at the previous label's width
  until the next tap. P4's pre-authorised constant footprint fixed it
  (T003, re-filmed whole on both runtimes). Then the person asked for the
  capsule sized to its text and the "…" a circle, and the only fix found
  for 26.5 at that size — `.id(selection)` — replaced the system's
  menu-to-button morph with a crossfade on **both** runtimes. Asked
  whether the morph is standard iOS behaviour (it is), the person kept
  it: "it would be jarring to have menu buttons that look like standard
  iOS but then behave differently when tapped." **P4 was withdrawn** and
  26.5's transient accepted: on the finished header (T009) 27.0 is whole
  on every frame and 26.5 snaps right after 1.54–1.78 s, with a stale
  wider shadow on Light after a wide-to-narrow one; both were shown and
  passed. How it was measured matters as much: the Phase 1 review found
  the probe's TEAR verdict **could not fire** — a label's anti-aliased
  fringe counted as capsule, so a label past the rim widened the capsule
  with it — and the first films' claim was restated onto the settled
  extent against XCUITest's frame. Before the final film the probe was
  made able to fail and shown firing on T002's 26.5 frames. `CLAUDE.md`'s
  "a passing test is not evidence it can fail" applies to a film probe
  as much as to a unit test.
- **The switches became a glass side toggle, brass on the primary side,
  after the segmented control proved unstyleable** (Decisions 7 and
  19–21). The plan put Owned/Sold and Active/Completed on the system
  segmented control, and T009 filmed its glass selection sliding with the
  header still to the pixel. On the device the person saw what no render
  could: the control takes no font and no colour from SwiftUI (measured:
  SF about 13 pt medium, pure white or black, `.tint` inert) — "the font
  difference looks like a glaring oversight and we can't ship that." Of
  three rendered homes the person chose a glass capsule in the header's
  control row showing the current side as an SF Symbol and its word,
  which flips to the other side on a tap and opens nothing; a "Show"
  section in the "…" menu is recorded as their fallback. It sits between
  Sort By and the "…" because Sort By vanishes on an empty side and the
  toggle should not move (Decision 20), and it reads **brass on Owned and
  Active** — the one header control carrying the app's colour, a
  narrowing of Decision 15 by the person's choice. It is **one width for
  both its sides** on each screen (Decision 21): the glass capsule's
  resize runs outside SwiftUI's transactions, so a growing capsule
  clipped "Completed" for 0.17 s and no animation setting reached it. The
  person refused to trade the motion for it ("The animations are a big
  part of the liquid glass aesthetic"), so the swap is a
  `.blurReplace` at `.smooth(duration: 0.3)`, picked by film from
  thirteen candidates on both runtimes. The rule worth keeping: **a
  system control that ignores the app's type is not a free win for an app
  whose identity is its type** — measure what it will take before
  planning around it.
- **Glass only on the header's controls and the add button** (P8,
  Decisions 13–15 and 17). The sort capsule, the side toggle and the "…"
  wear `.glass`; the add button `.glassProminent`, brass-tinted. The
  search field ("I consider it to be in the body") and the Dashboard's
  order label, which sits in a card, keep their drawing, and no glass sits
  on a card or on other glass. The glass labels take the system's label
  colour, not brass (Decision 15, matching Apple's guidance to keep colour
  out of Liquid Glass controls) — reached through `.tint(.primary)`,
  because the glass style resolves a hierarchical `.foregroundStyle(.primary)`
  on its label against the button's tint (the reason the shape bars drew
  dimmed) — an explicit colour on the label holds, as the side toggle's
  brass shows, but `.primary` does not — which only the device showed.
  `NoHardcodedColorsTests` gained a per-file, per-line exemption list with
  a stale-entry check for those lines — a recorded exception to `004`'s
  rule, not a hole in it — and both colour scans moved to a simple word
  boundary after a system colour followed by a member was found slipping
  past. Size: `.regular` with 4 pt of label padding, 36.33 pt, chosen by
  the person from four rendered candidates between the system's two sizes
  (Decision 17).
- **The header's geometry is the person's, set by eye and then held by
  measurement** (Decisions 22–23). The title's line box is centred on the
  three controls, at a new `listTitle` size of 34 pt that shrinks to fit
  rather than truncating on narrower phones; the Dashboard's drill-down
  path keeps 30. The meta line sits midway between the title row and what
  follows it, and the search field and first row do not move by a point
  (the Wishlist's search field moved 4 pt once, to sit level with
  Items'). Plans' capsule reads "Wishlist" for the "Wishlist order" sort,
  because Plans' title already truncated beside its three controls; the
  menu row keeps the full name. The mechanisms are a custom `Layout`
  (`TitleRowLayout`) and one split function (`MetaLineSpacing`), each
  guarded by a render at 3×. One process note: T009e's first dispatch
  stopped because its bundle's premises were the orchestrator's
  arithmetic rather than read from the code — **a bundle states what the
  code says, not what it should say**.
- **What the renderer cannot see, the device carries** (the G1 stand-in).
  `ImageRenderer` crashes on a glass `Menu` in a `VStack` with siblings,
  draws glass as an opaque placeholder, and draws a glass circle as
  width × label height. So the header layout test renders a stand-in
  sized from a render of the control row alone (37 pt there, 36.33 on the
  device), no test compares the stand-in to its own source, and the
  circle's diameter, every glass colour and the title's ink centre were
  measured on the device pass instead — each test's doc comment says
  which.
- **The tests retired, and why each could go** (criteria 9, 12 and 13).
  Every one is named in `tasks.md`'s retirement table beside the control
  whose removal made it moot. The two-tap UI test went with the
  behaviour: two system menus behind two buttons switch in one tap, which
  is the system's rule (P5). The dropdown's wiring, anchor, placement and
  render suites went with the dropdown, the host and the drawn hairlines
  they guarded. The bespoke switch's slide, fill and half-width tests went
  with the switch (`009`'s G18 among them). P4's one-width leg went with
  P4, and the export chooser's header test with its two strings.
  `MenuPolicyTests`' old test was rewritten, not retired. No surviving
  guard was loosened: the header's heights were re-measured at every
  change and never given a tolerance.
- **Settled with the person at the close-out (2026-10-01).** The Dark
  add button's white plus on brass measures 2.6:1 (Light's darker brass
  7.4:1) — under the 3:1 guideline and a change from the old disc's
  dark ink; the person: "Looks fine." Reduce Motion does not stop the
  toggle's blur, where the old switch faded only; the person: "Leave
  it." Both accepted as shipped (spec Decision 24), with a later design
  pass left possible. The Accessibility Inspector pass came back "All as
  expected" (the badges as pop-up buttons, the toggle's label and value,
  Plans' "Wishlist" capsule speaking "Sort by Wishlist order"), and the
  one-language attestation was given. Still an observation, not a
  decision: on iOS 26.5 every trailing header control sits 5 pt further
  from the right edge than on 27.0.
- **What was deferred.** The system navigation bar and toolbar on the tab
  roots (Decision 11) — the fully Apple-shaped header, and the floating
  bottom search that needs it — are `ROADMAP.md`'s `024`, placed before
  `019`.

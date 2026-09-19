# Decisions & Context Log

Repo-wide, not spec-specific — lives at the root alongside `CLAUDE.md`.
This captures reasoning and context that shaped the project but doesn't
fit into `CLAUDE.md`'s directives or the specs' structured docs. Mostly
product/business-side decisions made in conversation. Purpose: survive a
fresh chat or a new Claude Code session without the reasoning getting
lost, even though the *outcomes* of these decisions are also reflected
in the other files where relevant.

## App identity

- **Name**: Trove. Runner-up was Flywheel (leaned into the buy-sell-buy
  mechanic more literally; Trove won on being a better standalone brand
  word — short, works as an icon name, implies "a collection worth
  having" rather than describing the mechanism).
- **Subtitle**: "Your Gear, Valued." Added because "Trove" alone
  collides with at least three existing App Store apps (a trading-card
  app, an investing app, an eBay-alerts app) — Apple doesn't require
  unique names, but the subtitle is the practical disambiguation tool in
  search results (30-character cap).

## Bundle ID and Apple Developer Program

- **Bundle ID**: `com.erikhaake.trove` (lowercase), chosen over a
  studio-name-style prefix. Reasoning: the bundle ID is invisible to
  users — the public "Seller" name on the App Store comes from Individual
  vs. Organization enrollment in the Developer Program, not from the
  bundle ID string. It also doesn't lock in naming for future apps, since
  each app picks its own bundle ID independently. Cheap to change before
  first submission; effectively impossible after (a new bundle ID means
  a brand-new App Store listing, losing any reviews/ratings/history).
- **Developer Program membership**: lapsed/expired at the start of this
  build. Decision: build now on the free Personal Team (covers local
  build/run, and CloudKit development against your own iCloud account),
  renew the $99/year membership only when actually ready for TestFlight
  or App Store submission. Not needed before then.

## Studio/brand name for future apps

Explored at length — see `studio-name-brainstorm.md` for the full
candidate list (~30 names across math/philosophy/navigation/photography/
music themes) and the rules of thumb that emerged: a real, existing
dual-meaning phrase beats an invented portmanteau; the name should read
as a noun, not a verb/instruction (this is why "Steering the Manifold"
was rejected in favor of trying to find a noun-phrase alternative); avoid
words with a negative connotation even if the wordplay is sound (this is
why "Drift" was dropped despite fitting well). No name has been settled
on. Current status: proceeding with the personal name
(`com.erikhaake.trove`) for Trove specifically; the studio name is a
parallel, non-blocking exploration, picked up in its own chat.

**On the App Store "Seller" name specifically**: decided not to pursue
this. Showing a studio name there instead of a personal legal name
requires enrolling with Apple as an Organization, which requires being
an actual legal entity (LLC or corp — Apple explicitly does not accept
DBAs or trade names for this) plus a D-U-N-S number and a verification
call. Not worth forming a company purely to change a display string;
the threshold for revisiting this is real revenue or a real business
reason, not branding preference. This doesn't affect the studio name's
other uses — bundle ID prefixes for future apps, informal branding,
a portfolio site — none of which need Apple's involvement at all, since
Apple never verifies that a bundle ID's reverse-DNS prefix corresponds
to anything real. Trove and any near-term future apps ship under the
personal Apple Developer account regardless of what the studio name
ends up being.

## Market values (`002`, shipped 2026-09-05)

The product decisions themselves are numbered 1–37 in
`specs/002-live-market-value/spec.md`; this records the reasoning that
reaches beyond that spec.

- **The first network dependency, and the first unsynced store.** Until
  `002` every byte the app held was the person's own and synced through
  their private CloudKit database. Market figures broke both habits on
  purpose: they are Reverb's data, not the person's, so they live in a
  second SwiftData configuration (`MarketLocal.store`) that never syncs
  and is deleted with the match — which is also what Reverb's retention
  terms ask for. Only the match (a product identifier) and the item's
  year ride on the synced model. The two-store pairing was the one
  architectural risk in the spec, so its spike was the first task, and
  the fallback it insured against (a second `ModelContext` threaded
  through five view models) was never needed.
- **Reverb over a crawler; eBay deferred.** No marketplace offers sold
  prices to a non-partner app, so the honest figure is an *asking*
  price, shown beside the person's value and never in place of it.
  Reverb's catalog and listings are free, catalog-keyed,
  condition-tagged and inside its terms. Building a crawler for
  eBay/Facebook was declined: it breaches every relevant site's written
  terms and adds a server and a new privacy posture. eBay's own API
  needs a hosted proxy (its token secret cannot ship in an app) and a
  decision to accept partner-only production access — the two
  prerequisites on the roadmap's eBay entry.
- **Reverb's terms put four obligations on the app, and each has one
  home.** The attribution line, verbatim, in Settings › About
  (`MarketCopy.attribution`, pinned by test); a displayed contact
  address, also in About and sent as the `User-Agent` on every request
  (`MarketCopy.contactAddress` — provisional, the person's own until
  publication, a two-file swap with `PRIVACY.md`); a privacy policy of
  the app's own, `PRIVACY.md` at the repo root, linked from About and
  the one-time notice; and a link back to the product wherever its data
  is shown, the candidate picker included. Two prohibitions — no
  retention beyond a reasonable period, no analytics/ML/scraping — are
  met by the per-match retention rules and by computing nothing across
  items.
- **The `010` line restated for a per-device fact.** `010` settled that
  a device-local fact never gates a synced write; `002` kept it: the
  figure never blocks adopting, editing or syncing, and there is no
  launch sweep over local rows (plan Q18) — nothing is fetched on
  launch, on appear or in the background, only on the person's tap, a
  pick, or the Settings walk.
- **Constitution amendment reconciled (spec Decision 19).** The
  routing rule below says `CLAUDE.md` edits go to `main` post-merge; the
  constitution's own "amend first, in its own commit" rule won for an
  amendment a spec contradicted (pulling values from marketplaces →
  an indicator beside the value). The amendment landed on the spec
  branch before implementation; this entry is the post-merge record.
  The same precedence applies next time: a spec that needs the
  constitution changed amends it first, wherever the commit lands.
- **A fifth routing bucket: `PRIVACY.md`** (plan Q20). Repo-root, but
  not repo-wide in the sense of `CLAUDE.md`: it describes shipped
  behaviour, so it travels with the branch that changes what it
  describes, like `design/` and `docs/`. Its test
  (`PrivacyPolicyTests`) reads it by `#filePath` and pins the notice
  text, the address, and each row of the retention table.
- **Blob URL first, GitHub Pages later (spec Decision 18).** The policy
  link points at the GitHub blob URL, which works the moment the branch
  merges; Pages is a later one-line `fix/` swap. "Is published" was the
  one criterion clause that could only become true at merge.
- **A corrupt local store never ends in `fatalError` (plan Q21).** The
  container builder's third attempt deletes the *local* store's files
  (never the collection's `default.store`) and rebuilds; the assertion
  that it is never handed the collection's URL caught a mutation that
  would have deleted the person's data. Market figures are recoverable
  by a refresh; the person's items are not.
- **The live network is touched twice in a spec's life, and by no
  test.** Once by the fixture-recording script, run by hand, whose
  trimmed responses are committed under `TroveTests/Fixtures/`; once by
  the device pass. `TroveTests` stubs every `URLSession` and an
  unregistered URL fails as `.unsupportedURL`. The rule is in
  `CLAUDE.md`'s Networking bullet; `002` was its first application.
- **The first spec under the model policy** (`CLAUDE.md`, 2026-09-04).
  From T009a on, routine tasks went to the `sdd-implementer` one tier
  down, with the orchestrator re-running build and tests itself before
  each commit; foundational tasks got a per-task `skeptical-reviewer`
  pass on a diff bundle. `tasks.md`'s tier log holds the evidence:
  about 2.97 M implementer tokens and 1.43 M reviewer tokens across 42
  logged runs, no escape-hatch redo (one task handed two stale doc
  widths back to the orchestrator), and a pre-merge sweep at the top
  tier whose single blocking finding was settled by instrumentation
  rather than argument. Compare against the next spec before treating
  the policy as settled.

## Stock photos (`005`, shipped 2026-09-13)

The product decisions are numbered 1–7 (plus the P-items) in
`specs/005-stock-photos/spec.md`; this records what reaches beyond that
spec.

- **The second network dependency, and the first one that stores what
  it fetches.** `002` established the posture — on demand only, a
  one-time notice, a policy that names the service. `005` reuses all of
  it for Wikimedia Commons and breaks one half of it deliberately: the
  bytes stay. A market figure is Reverb's data about a moving market, so
  it lives in an unsynced local store and dies with the match; a stock
  photo, once picked, is a file the person is licensed to keep, so it is
  an ordinary `Photo` row on the synced store. Two outside services now,
  each with a notice, and one of them leaves something behind.
- **Wikimedia Commons because storing is allowed at all.** Unsplash and
  Pexels were ruled out on their terms (no storing a copy, and their
  content is artistic rather than product photography); Reverb's own
  catalog image is hotlink-only and matched-music-only. Wikimedia's
  CC-BY / CC-BY-SA / CC0 / public-domain files are the only ones that
  can be *kept* — which is what makes a fetched photo sync to a second
  device and show with no network, the same as a photo the person took.
  The licence set is enforced in code (`StockPhotoLicence.classify`) and
  the credit is composed in one place, because the permission depends on
  the attribution travelling with the image everywhere it appears,
  including the PDF export.
- **A fetched photo syncs; `002`'s figures still don't — and the policy
  says both.** This is the one place the two network features differ in
  what the person can observe, so `PRIVACY.md`'s retention table and its
  iCloud section each state it in a line a test pins whole. The reason
  isn't a change of mind about sync: it's that the figures are somebody
  else's data held under retention terms, and the photo is the person's
  to keep.
- **The notice flag is one `UserDefaults` bool, not a row in `002`'s
  local store** (plan Q7). A per-device acknowledgement is the lighter
  pattern `004` used for the appearance choice, and reusing
  `MarketDeviceState` would have made `005` depend on `002`'s two-store
  arrangement for a single boolean. The cost showed up immediately, and
  is recorded in the process note below: a flag outside the SwiftData
  store is a flag `-uiTesting` doesn't reset.
- **`AppContact` is a unification candidate, not done here** (plan Q6).
  Wikimedia's User-Agent policy asks for a contact address exactly as
  Reverb's terms do, so `StockPhotoCopy.contactAddress` now holds the
  same real address as `MarketCopy.contactAddress`. `005` kept it
  self-contained rather than depending on `002`'s copy; the moment a
  third service or a publication-time address swap arrives, the two
  should become one `AppContact` and each `Copy` type should read from
  it. Both are pinned by placeholder guards, so the duplication is
  visible rather than silent.
- **Self-containment from `002` holds for copy and services, not for
  view chrome.** `005`'s notice and its Find a photo… actions reuse
  `002`'s button chrome as it stands — `marketFilledChrome`,
  `marketOutlinedChrome` and `MarketButtons`' hit/notice heights — in
  `PhotoNoticeView` and all four detail/form screens. Duplicating a
  button style to keep the `market` prefix honest would have been two
  identical modifiers drifting apart; the chrome is app-wide styling
  that happens to have been written for `002`. The `market` prefix is
  now a misnomer, and a generic rename (`noticeFilledChrome` or
  similar) is **deferred** to whichever spec next touches all its call
  sites.

## Marking something sold (`006`, shipped 2026-09-15)

The product decisions are numbered 1–14 (plus the P-items) in
`specs/006-mark-as-sold/spec.md`; this records what reaches beyond that spec.

- **The sale is four fields and a link on `Item`, not a `Sale` model** (plan
  Q1). The deciding reason is sync, not tidiness: stored properties travel as
  one CloudKit record, while a relationship is a second record that can arrive
  before or after its item — so a second device could briefly show a sold item
  as owned, or a sale pointing at nothing. Three consequences fell out of the
  same choice: every reader tells the two sides apart with one stored-property
  predicate (`soldDate == nil`), usable inside a `#Predicate` and in memory
  alike; "Return to collection" is nil-ing five fields, with no row to delete
  and no orphan to leak (the `PhotoSelection.orphaned` class of bug cannot
  arise); and `TroveSchema.models` is unchanged, so `002`'s store-disjointness
  pin needed no edit. The cost is four nil columns on every unsold item, paid
  knowingly. The general rule worth keeping: **when a fact belongs to a record
  and arrives with it, make it a field; reach for a relationship when the fact
  has its own identity or repeats.** An item is sold once, whole, so it has
  neither.
- **The Owned / Sold side is plain view-model state, with one intent that
  changes it** (plan Q4, Q15). Nothing persists the side, so "the tab opens on
  Owned at every launch" is true by construction rather than by a reset
  somewhere — there is no stored value that could be wrong. And because the
  sign-off found that a CSV exported from the Sold side would otherwise inherit
  the Owned side's category and search narrowing with no chip on screen to say
  so, `show(_ side:)` is the only way the side changes and it clears every
  narrowing in both directions; `side` is `private(set)`, so binding a control
  straight to it does not compile. The rule this is an instance of: **when two
  views share one view model, make the switch between them an intent, not a
  setter** — the state that must be reset lives in the same function as the
  change that invalidates it.
- **Copy and colour have one home each, and they are different homes.** Every
  string `006` fixes lives in `SaleCopy` (a `Trove/Models/` file: Foundation
  only, no SwiftUI, no colour), pinned whole by its tests and read by the views
  — the `MarketCopy` / `StockPhotoCopy` pattern, for the same reason, that two
  surfaces saying the same thing must not drift apart. The *colour* rule lives
  on the model as a boolean — `SaleOutcome.isLoss` for one sale and, after the
  Phase 5 review, `SaleTotals.isLoss` for a sum — and each view maps that to
  `accentRustText` / `accentMossText` itself. The review finding is the part
  worth remembering: the loss-over-a-sum rule had quietly grown two spellings
  (a card building a `SaleOutcome` over a delta, a list reading the sign
  directly), which a scan could not see until the rule had a name. **A
  predicate that decides an appearance belongs on the model with a name, not
  inline at each surface**; the scan that pins the surfaces to it is only as
  good as that name existing. Related and separate: the word carries the
  meaning and the colour only repeats it — "Gain $350 vs paid" / "Loss $150 vs
  paid" / "At cost" (spec Decision 11), so nothing is lost to a colour-blind
  reader or a greyscale print.
- **Import treats a sale as a pair, and counts the drop once** (plan Q6, R3). A
  row is a sold item only if both `Sold Date` and `Sale Price` parse; either
  half alone imports the item unsold and reports **one** counted default, not
  one per non-blank cell — an import report that overstates the damage is as
  misleading as one that hides it. Two asymmetries are recorded rather than
  smoothed over: a negative price is already unreadable to `012`'s parser, so
  it drops as "price unreadable", while a future sold date imports as written,
  because the parser has no clock and `Purchase Date` has always been accepted
  unbounded. The sheet's future-date bound is a data-entry courtesy; import
  trusts the file.
- **A second UI-test seed, and the conditions under which a seed may add
  rows.** `-seedSold` is the first use of `CLAUDE.md`'s amended `-uiTesting`
  rule — a test-only branch that *adds* data for one launch rather than only
  losing it — and it holds to both conditions the amendment set: it is gated on
  the store the app actually built being in-memory (never on a second read of a
  launch argument), so the bound is structural and a test can watch it refuse a
  persistent store; and it takes its own argument, so `-uiTesting` and
  `-seedSellPlan` alone keep the starting states every existing UI test was
  written against. It writes through `ItemSaleStore.markSold` rather than
  setting fields directly, so the seed cannot produce a shape the app itself
  could not, and its test reads the seeded totals back through
  `SaleOutcome.totals` rather than a third hand-written sum.
- **What the person's walkthrough changed, and why it took measurement**
  (spec Decisions 12–14, at the Phase 4 and Phase 5 pauses). Three of the four
  findings were about how the app *moved* or what it *said*, not what it
  computed. An Owned side emptied by selling now has its own empty state
  ("Everything's sold. Add something new.") instead of the first-launch "No
  gear yet", because the person has been using the app rather than just
  installing it. The Sold side keeps its stats line at zero sales ("0 sold ·
  $0") so the switch above it never moves — the jump the person saw measured
  19.7 pt, and only with an empty collection, which is why the seeded
  simulator had not shown it. And the stutter under that switch was not the
  cause anyone reasoned their way to: a `matchedGeometryEffect` pair across an
  `if isActive` insert/remove is a *structural* change that `.animation(_:
  value:)` never covered, so the fill crossfaded — a 22 % brightness dip while
  the travel stepped at about 20 Hz — and it took a screen recording with
  per-frame timing to see that, since a screenshot cannot show motion at all.
  It ships as one rectangle with an animatable offset. **Two general notes**:
  any other `matchedGeometryEffect` across an insert/remove in this app is a
  silent crossfade wearing the source code of a slide; and a layout finding a
  person reports should be reproduced with *their* data shape before it is
  diagnosed. The fourth, Decision 14 — a sell plan keeps listing its sold items
  under the empty state, each row marked sold — changed an accessibility label
  (the row now announces "Sold" first) and broke a UI-test helper that matched
  name-first. The miss is recorded in `tasks.md`: **a view change that alters
  an accessibility label must verify the UI suite, not just the unit suite.**

## Process and tooling notes

- **Git routing**: edits to `CLAUDE.md`, `specs/ROADMAP.md`, and this
  file go to `main` directly (repo-wide) — in practice through a
  `fix/docs-<spec>-shipped` branch and PR right after each merge, never
  a direct push. Edits inside `specs/<feature>/` go to that feature's
  own branch. Three more buckets, settled by how `011`–`013` actually
  moved (recorded 2026-09-02): **`design/`** (`brief.md`, `tokens.md`)
  and **`docs/`** travel with the feature branch that changes what
  they describe — tokens are "as implemented", the CSV reference is
  the contract's paper half; **`README.md`** splits — a feature
  sentence that becomes true on the branch (T015 of `013` reworded the
  import bullet when the template moved) goes with the branch, while
  the Status paragraph, the tree and the specs listing wait for the
  post-merge docs pass, since they describe what `main` has. See
  `CLAUDE.md`'s Git conventions section for the full
  branch-per-spec / draft-PR workflow this implements.
- **Model and effort**: originally tiered per phase (Opus 5 for
  foundational/logic-dense phases, Sonnet 5 for mechanical ones — see
  `tasks.md`'s "Model and effort per phase" table). Later switched to
  running Opus 5 across all tasks for the remainder of the build, for
  peace of mind on a first SDD project — upgraded to a Max x5 plan
  specifically to support this. The phase-tiered table in `tasks.md` is
  now historical context for why each phase was originally built the way
  it was, not a live instruction.
- **Claude Code context management**: prefer `/clear` at phase
  boundaries over `/compact`, specifically because this project's
  discipline of keeping real decisions in the actual files (not just in
  conversation) means a cleared session loses very little — `CLAUDE.md`
  re-reads automatically. Use `/compact` instead only when mid-task and
  reluctant to interrupt.
- **This chat (claude.ai)**: no manual compact/clear command exists here
  — context is managed automatically, on a rolling basis. When starting
  a fresh chat for this project, make sure the Trove project's knowledge
  base has current versions of all files first — it's a manual-upload
  snapshot, not a live sync to the repo.
- **Working across two machines (desktop and laptop)**: the first
  concrete incident of this — a laptop `main` diverged from `origin/main`
  after a long desktop-only stretch, caught only when a push was
  rejected. Fixed cleanly with `git pull --no-rebase` since the two
  histories touched different parts of the same files, but the standing
  habit going forward is to check *before* editing, not after a rejected
  push: `git fetch && git status` on whichever machine is in use, before
  touching any file, every time work resumes there. Non-destructive,
  cheap, and would have caught this before any new content was written
  against a stale base rather than after. Worth running against both
  active branches (`main` and whatever spec branch is current) if a
  session is expected to touch both.
- **The collaboration workflow moved from ad hoc to a formal skill.**
  What started as a hand-written "Collaboration workflow" section in
  `CLAUDE.md` (routine tasks proceed, real decisions get a subagent
  check, the person is looped in only for infeasibility or a
  direction-changing unknown) was generalized into a portable
  `spec-driven-development` skill and a `skeptical-reviewer` subagent,
  installed once at the user level
  (`~/.claude/skills/spec-driven-development/`,
  `~/.claude/agents/skeptical-reviewer.md`) so every project gets it
  automatically rather than needing its own copy. `CLAUDE.md`'s section
  is meant to shrink to a short pointer to the installed skill once that
  swap actually lands. A second instance of the machine-sync gap noted
  above surfaced while confirming this: the section briefly looked
  missing entirely when reviewed from the desktop, which simply hadn't
  pulled the laptop's earlier push yet — not a lost commit, the same
  class of incident happening again from the other direction. A
  `.github/PULL_REQUEST_TEMPLATE.md`, built for the companion
  `spec-driven-development-template` repo, was retrofitted into this
  repo around the same time.
- **One claude.ai chat per spec, plus one standing administrative
  chat.** After `001` shipped, the single long project chat that had
  carried the whole v1 build (design, reviews, workflow-tooling, git
  troubleshooting, all of it) had become an everything-drawer — the
  same anti-pattern the methodology avoids at the file level, at the
  conversation level. Going forward: one dedicated chat per spec
  (`010`'s scoping and reviews live in their own chat, `011`'s in
  another), and the original long chat is kept as the standing home for
  administrative and workflow-tuning discussion that isn't spec-specific.
  This works precisely because the durable context lives in the repo and
  the Project knowledge base, not the chat log — a fresh spec chat needs
  no prior chat history, only current files. **Before starting a new
  spec chat, refresh the Project knowledge base with current versions of
  the repo files** (at minimum `CLAUDE.md`, `ROADMAP.md`, `DECISIONS.md`,
  and the relevant spec's docs) — the knowledge base is a manual-upload
  snapshot, not a live sync, and a stale one starts the new chat with a
  subtly wrong picture. The `spec-driven-development` skill applies
  automatically to every chat regardless, so working style carries over
  without being re-established.
- **`plan.md`/`tasks.md` authorship moved into Claude Code (2026-08-30,
  during `011-data-export`).** This is the entry `CLAUDE.md`'s
  authorship-split amendment points at; it was written after the fact
  (the T019 close-out found the pointer dangling). The original rule
  placed `plan.md` authorship in the chat conversation alongside
  `spec.md` — written when the project had no code, so a plan could be
  authored anywhere. With an established codebase that stopped being
  true: a plan's quality depends on ground truth only the repo has
  (actual model definitions, view structure, injection shapes), and the
  chat's knowledge-base snapshot is a manual upload that is reliably
  stale. So: `spec.md` stays with the chat conversation (product
  intent, no repo access needed); `plan.md` and `tasks.md` are drafted
  by Claude Code in-session — Plan Mode, `skeptical-reviewer` on
  non-routine calls, committed as Draft — with the human review gates
  unchanged (plan approved before tasks, both before implementation).
  `011` validated the split immediately: its plan was grounded in facts
  a chat draft would have missed (the custom header with no navigation
  bar, the `SortBadge`/T029c history, synchronized folder groups), and
  the walking-skeleton task it prescribed caught a toolchain behavior
  (`NonisolatedNonsendingByDefault`) that falsified part of its own
  concurrency design before any UI was built on it. The same amendment
  was proposed upstream to the `spec-driven-development` skill.
- **Spec-authorship venue is a per-spec call (2026-08-31, during
  `012-data-import`).** The 2026-08-30 authorship split fixed *who
  decides* (always the person) and *where grounding lives* (the repo),
  but had hard-coded *where the spec conversation happens* (a dedicated
  claude.ai chat). `012` relaxed that to the person's per-spec choice:
  its design questions hung almost entirely off `011`'s shipped CSV
  contract — pinned headers, positional order, empty-cell semantics,
  which fields the models actually require — all of which lives in the
  repo, so for once the in-session venue had the fresher ground truth,
  the same argument that moved `plan.md` in-session. The default for a
  green-field spec remains a dedicated chat (with the knowledge-base
  refresh first); the person picks per spec. `CLAUDE.md`'s
  authorship-split section carries the amended rule.
- **The roadmap is updated on the spec branch, not after merge
  (2026-09-07, `003`'s close-out).** `002` updated `specs/ROADMAP.md` on
  a post-merge `fix/docs-002-shipped` branch, reasoning that the
  constitution forbids committing to `main` directly. `003`'s pre-merge
  sweep pointed out the reasoning doesn't hold — an edit on the spec
  branch merges through the PR like everything else — and that the
  mechanism left the roadmap listing shipped work as future between the
  two PRs. From `003` on, the roadmap's entry and status row are written
  on the spec branch in the close-out task, citing the draft PR's
  number, and the post-merge docs branch exists only if something is
  learned at merge itself.
- **An inline link in a `Text` gets an `accessibilityRepresentation`,
  never an `accessibilityLabel` (2026-09-11, `005`'s device pass).** The
  stock-photo credit's link was a sibling `Link` view beside a wrapping
  `Text`, so on any credit long enough to wrap the link sat beside line
  one and the sentence continued under it. A SwiftUI link is either a
  *view* (its own label, hint and identifier; cannot wrap inside a
  paragraph) or an *inline run* (wraps; no per-run accessibility). The
  decision review chose the run for layout and touch, with an
  `accessibilityRepresentation { Link … }` for VoiceOver — because an
  `accessibilityLabel` on a `Text` holding inline links strips the Links
  rotor on iOS 17+, and a hint on an element with no activation is a
  promise VoiceOver can't keep. Any link at the end of a sentence that
  may wrap faces the same choice; plan §6 of `005` records the fallback
  if the representation doesn't activate on device.
- **A controlled UI-test starting state has to be structural for every
  persisted flag, not just the store (2026-09-10, `005`'s Phase 3
  review).** `CLAUDE.md`'s `-uiTesting` rule was written for the
  SwiftData store, and read as if swapping the store were the whole of
  a controlled start. `005` put one bool in `UserDefaults`, which
  `-uiTesting` doesn't touch — so a UI test's starting state depended on
  whether an earlier run had tapped Continue, the indeterminate-start
  defect the rule exists to prevent. The generalization: **every piece
  of state that survives a launch needs its own reset**, and the reset
  must be gated on *the store the app actually built* being the
  in-memory one, never on reading the launch argument a second time.
  Gating it that way is what makes the in-memory bound structural — a
  test can show the reset refusing a persistent store even with every
  flag set (`PhotoNoticeStoreTests.theResetRefusesAPersistentStore`),
  which a second flag read could never demonstrate.
- **Two `.sheet` modifiers chained at the same level both present on
  iOS 26 (2026-09-13, `005`'s pre-merge sweep).** The detail screens
  chain `002`'s match sheet and `005`'s photo sheet on the same view. The
  old single-sheet limitation was suspected twice (Phase 3 review, the
  sweep) and settled once, on the simulator: both present on both
  screens in either order, no runtime warning. A third sheet can chain
  the same way; a decision to fold them into one step enum is not
  needed for that reason.

## Reversing a shipped approach mid-branch — the segmented-picker theming (2026-09-09, spec `004`)

- **`004`'s Appearance picker: the UIKit `UISegmentedControl.appearance()`
  bridge (T008) was removed and replaced by a SwiftUI sheet-level fix
  (T009).** The person's device pass found the segmented control's
  unselected labels illegible: near-black on the dark track in Dark, then
  (after the first fix) near-white on the light track in Light. T008 set
  the `.normal` title through a process-global `UISegmentedControl`
  appearance proxy with a trait-dynamic `UIColor`. That treated the
  symptom and keyed the colour off the control's UIKit trait — which,
  inside the Settings `.sheet`, does **not** follow a live in-app
  appearance switch (the app drives appearance with `.preferredColorScheme`
  at the root, and an already-presented sheet doesn't inherit the changed
  override). So the bridge read the wrong trait and mis-coloured. The same
  cause produced the "faint nav title" first mis-recorded at T006 as a
  non-reproducible transient.
- **Decision: fix the root, not the symptom, and delete the bridge.** T009
  makes the Settings sheet adopt the choice itself —
  `AppearanceChoice.sheetColorScheme(device:)` resolves the choice to a
  **concrete** `ColorScheme` (never `nil`: passing `nil` to a *presented*
  sheet's `.preferredColorScheme` hits a documented SwiftUI
  refresh-failure bug), read from each presenting host's own
  `@Environment(\.colorScheme)` and applied to the Settings sheet's
  `NavigationStack`. With the sheet's trait correct, the system segmented
  control renders its unselected label legibly by default, so the T008
  UIKit bridge (and its test, and its flagged-exception allow-list entry)
  were deleted. Net over T008+T009: **no** new UIKit exception, a system
  control taking the system label colour, and both the label and the title
  symptoms fixed at one cause. The trade — the unselected label is the
  system `.label`, not the exact `ThemeColors.textPrimary` token — was
  accepted: legibility is the requirement, a system control taking the
  system semantic colour is appropriate, and the person can ask for the
  exact token (which would mean retaining a bridge) if they ever want it.
- **Why on the spec branch, not a `fix/` branch.** `CLAUDE.md`'s "bug
  found in already-merged code gets a `fix/` branch" rule is scoped to
  *merged* code; `004` had not merged, so both fixes rode the spec branch
  before the PR was marked ready — the same reasoning as any late task in
  a spec. The `skeptical-reviewer` vetted the T009 mechanism as a decision
  before implementation (Fallback clause: at `opus`), which is why the
  reversal is recorded here rather than discovered later.

## 2026-09-14 — Xcode 27 arrived mid-spec (`006`)

The Mac moved to Xcode 27.0 between `006`'s Phase 4 and Phase 5. HEAD did
not build under it: two `Shape` conformances on `MainActor`-isolated
structs needed `nonisolated` under `InferIsolatedConformances`, and one
chained `#expect` timed out the type-checker. The three one-line fixes
went in as their own commit ahead of T013, outside any task's file list,
disclosed in T013's Done note and the tier log. Two operational facts for
the next upgrade: the license must be accepted by the person
(`sudo xcodebuild -license accept`) before git or xcodebuild run at all,
and `xcrun simctl list devices` must run once so CoreSimulator restarts
before `scripts/verify.sh` can find a destination.


## Sold-side parity and the export scope (`014`, complete 2026-09-18)

The product decisions are numbered 1–7 (plus the P-items) in
`specs/014-sold-side-parity/spec.md`; this records what reaches beyond that
spec.

- **Per-side state is two values behind one set of names** (plan Q1). The
  Items list now keeps a separate search, chip and sort for Owned and for
  Sold, and the obvious shape — a `side` check at every reader — would have
  put that check in the view, the chips, the empty states, the router's
  `apply` and both exports. Instead `ItemListViewModel` holds a private
  `ownedNarrowing` and `soldNarrowing` and exposes `categoryFilter`,
  `searchText` and `showsOnlyUnvalued` as computed properties over *the side
  on screen's* value. Nothing outside the view model can name the hidden
  side's narrowing, so "the controls always show the side on screen" and "a
  file is never narrowed by something not visible" are true by construction
  rather than by everyone remembering — and every existing test and binding
  kept its spelling. The rule this instances: **when one screen has two
  modes, make the mode a private selector over two stored values, not a
  parameter every reader has to pass.** Its one refusal is in the same
  spirit: `showsOnlyUnvalued`'s setter silently declines the write while Sold
  is on screen (`006`'s reasoning — a sold item's current value is not
  something the app has an opinion about), so the Sold copy can never be
  true and the shared chip row needs no side check. A refusal rather than a
  `precondition`, because no legitimate writer exists on that side.
- **A file's order comes from the record, its contents from the screen.** The
  CSV's sold half is always in date-sold order, whatever sort the Sold side
  is showing, while *which* rows it holds follows exactly what is narrowed on
  screen — and the hidden side's own narrowing plays no part at all. The two
  halves of that rule pull in opposite directions on purpose: the view's sort
  is a reading aid and the file's order is the record's, but a file that
  quietly held rows the screen was hiding would make its own coverage label a
  lie. It is also what keeps `013`'s byte identity between the Items list's
  unnarrowed export and Settings' export-everything alive with two sides in
  play. From the **Owned** side the owned rows are in visible order, as `011`
  always wrote them, so that identity holds under Custom specifically — the
  person corrected the criterion's wording to say so at their reading.
- **"Sell" on the button, "Mark as sold…" to VoiceOver.** The leading swipe
  action is 76 pt wide beside a glyph, which "Mark as sold" does not fit, so
  the visible word is "Sell" and the button's `.accessibilityLabel` is
  `SaleCopy.markAsSold` — the "…" menu row's own name — so the same action is
  announced the same way wherever it is reached from. That a modifier on a
  swipe-action `Button` overrides its `Label`'s text is a platform claim no
  unit test in this project can check; it was settled by reading the live
  accessibility tree with XCUITest, which reports the button as "Mark as
  sold…". **The shipped name is the spoken one.** The general note: when a
  visible string and a spoken string differ deliberately, pin both, and
  verify the spoken one against the tree rather than against the source.
- **The export scope is a chooser, not six menu rows** (spec Decision 7, plan
  Q14–Q17). Once exports could be owned, sold or both for either format, the
  obvious move was six rows in the "…" menu. Rejected on three counts: `013`
  criterion 1 fixes that menu's row order and its tests `#require` four rows;
  the menu is shared with the Wishlist, which has no sold half; and six rows
  reads as six unrelated actions. The two existing rows now *open* a second
  dropdown on the same badge — headed EXPORT AS CSV / EXPORT AS PDF, offering
  Owned items · Sold items · Owned and sold, each disabled when it has no
  rows — so the plate stays put and its contents swap. Also rejected: scoping
  by "this side", because changing side changes which *narrowing* is in
  force, and the two choices must be independent.
- **"Owned and sold" as a PDF is two documents, not one.** A single combined
  cover would have to print TOTAL VALUE beside TOTAL SOLD FOR under one item
  count — the mixed figures `006` Decision 7 refused — or grow a section page,
  which is new drawing in a spec with no design pass. So the choice stages
  two documents in **one** `exportFiles` call, owned then sold, with an empty
  half left out. One call, not two, because the export path writes one
  directory and a second call would purge the first file.
- **The sold document needs its own filename, and the shared one is not a
  bug.** `Trove-Sold-Items-<date>` exists because `exportFiles` writes a
  directory keyed by filename, so two documents under one name would
  overwrite each other; `.owned` keeps `Trove-Items-<date>` because it is the
  very document Settings ships under that name. The consequence worth writing
  down so nobody "fixes" it later: **"Owned and sold" over a collection where
  everything has sold writes a sold-only file under `Trove-Items-<date>`.**
  That is P15 as written — only the sold-*only* scope takes the sold name —
  not a mistake.
- **Settings' PDF pair is no longer "the complete record".** Settings exports
  owned + wishlist as PDFs and the complete record as a CSV pair, unchanged
  by this spec. With a sold document now available from the Items list, the
  PDF half of Settings' export is the narrower one, and any future wording
  about "everything" on that screen has to say which format it means.
- **`WishlistView.header` was left duplicated on purpose.** `014` extracted
  the Items header into `ItemsListHeader` to fix a wrap that pushed the side
  switch 13.67 pt down; the Wishlist's header is the same construction with
  the same latent wrap, and it was **not** changed — out of the spec's
  footprint, covered by no criterion, and a shared header is a small
  mechanical change that deserves its own diff rather than riding along in a
  close-out. It is on `ROADMAP.md` as the follow-up, with the guard to extend
  named. The rule: **finding a second instance of a bug you just fixed is a
  roadmap entry, not a licence to widen the current task** — as long as it is
  actually written down.
- **The session moved to the stepped-down Opus model mid-spec, by choice.**
  At the Phase 2b pause on 2026-09-18 the person instructed: for the rest of
  the spec, use the step-down Opus model for every task. That ends experiment
  1's Fable seat and the explicit top-tier overrides on decision reviews for
  this spec; the `sdd-implementer` and `skeptical-reviewer` defaults already
  matched, so nothing from T010 on carried an override. It is `CLAUDE.md`'s
  **Fallback clause exercised by choice rather than by an exhausted
  allowance**, which is a result of experiment 1 in itself, and the tier log
  records what ran and from when. Whether it becomes the standing policy is
  the person's call, not a decision `014` makes.

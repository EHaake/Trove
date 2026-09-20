# 015 — Mark as Bought: Tasks

**Status**: **Final** (2026-09-19) — the person approved the
spec-conformance summary the same day. No task has started.

Signed off (2026-09-19) by the `skeptical-reviewer` — one
blocking finding fixed and re-reviewed, two further blocking findings raised
by the re-review and fixed by the orchestrator under the loop cap, all logged
in the tier log.

Drafted against the approved `spec.md` (Approved 2026-09-19) and the draft
`plan.md` in this directory, for branch `015-mark-as-bought` off `main`
(`cb1d3a1`). No new technical decisions are made here — every call below traces
to a plan section; where a task says "per plan," that section is the authority.
Runs under `CLAUDE.md`'s model policy **as amended 2026-09-19**: the
`sdd-planner`, the `skeptical-reviewer` (sign-off, per-phase, per-task,
decision reviews, pre-merge sweep) and the `sdd-implementer` all run at
`opus`, which is what their definitions already default to, so **no dispatch
carries a model override**; the session runs at `opus` medium. The tier log
records what actually ran.

**Foundational phase**: **Phase 1** (T001–T006) — the marker every read site
and every guard is written against, the value type and the copy table, the one
writer of a purchase, the exclusion rule four surfaces obey, the sheet's view
model, and the three hosts' intents. Phase 2 is screens only and Phase 3 is
verification, so everything a later task inherits is settled in Phase 1.
**Tasks marked `review: per-task`**: **T003** (`WishlistPurchaseStore` — the
one writer; it moves photos that cannot be reconstructed, clears a plan, and
stamps a marker with no undo, and all three hosts inherit whatever it gets
wrong) and **T004** (the exclusion rule — five read sites, one of them a
destructive action's count and one of them an exported file; a miss here leaks
a bought entry into something the person sees or deletes). Every other task
gets the default one review per phase. An orchestrator left to guess guesses
"all of them" — these two are the ones marked.

Ordering note, recorded up front: the model first, since every test in the spec
writes or reads the marker; then the two plain value files it needs; then the
writer, so the exclusion rule and the hosts have something real to call; then
the exclusion rule, before any screen can show a bought entry by accident; then
the sheet's view model and the hosts' intents, so Phase 2 is view work only.
Inside Phase 2 the sheet lands before the three hosts that present it, and the
UI tests last so they run against the final layout. No design pass: the tint,
the glyph, the placement and the labels are settled in `plan.md` Q3, Q8 and
Q14, and T012's device pass checks them.

House rules carried over: one commit per completed task, referencing the task
ID; every guard test is **mutation-verified** (break the rule deliberately,
confirm red) before it lands, and the Done note records what was broken and
what went red; a task is not done until `scripts/verify.sh` is green and its
actual output is reported (suite-level `-only-testing`, test count checked —
per-function selectors run zero tests and report success); **persisted-state
assertions refetch on a second `ModelContext`**; **every new or rewritten
source scan `#require`s its anchor was found** before asserting anything about
it, so no scan can pass over a file that lacks the thing it guards; no broad
noun-scan guards (`plan.md` Q13 — the shape `CLAUDE.md` names twice as having
gone vacuous). Five new production files and five new test files land inside
synchronized folders — **no `.pbxproj` edit anywhere in this spec**; if the
build cannot see a new file or the new imageset, stop and flag. **No test
opens a network connection** (nothing here needs one, and criterion 14 is the
claim that nothing does).

Cadence (per `CLAUDE.md`'s model policy): each dispatch gets a **task bundle**
assembled with shell — task line, plan section, acceptance criteria, files,
pattern file — and the implementer is told not to read
`plan.md`/`spec.md`/`tasks.md` in full; verification is `scripts/verify.sh` and
nothing more verbose, re-run by the orchestrator for the two `review: per-task`
tasks and taken from the implementer's verbatim output otherwise; the
`skeptical-reviewer` reviews per phase (and the two marked tasks), one review
and at most one re-review each, on a bundle cut after `git add -A`; **one
implementation session for the whole spec** — a phase pause is a pause in it,
the person attests and says continue, and only a session-ending pause gets a
continuation prompt; the device pass runs in a `general-purpose` agent (the
`sdd-implementer` has no simulator tools). Everything the person reads is
plain language.

Handoff notes for the pause reports, so the orchestrator doesn't have to
rediscover them: **Phase 1 has nothing to try** — the report may say so and
offer to run straight on to the screens. **The Phase 2 report lists what can
be tried** (swipe a wanted item to the right and tap Buy; the same action from
the wanted item's "…" menu and from its Sell Plan; type a price above and below
the estimate and watch the line under it; cancel from each; then buy something
and look for it in Items with its photo and its credit) and says three things
the person will feel before they read them: the swipe's button reads **"Buy"**
while VoiceOver calls it "Mark as bought…" (the fuller name does not fit the
button); the Sell Plan's action is a **bag glyph in the top-right corner**, not
a word, and if that reads as a puzzle the one-line fallback is a button reading
"Bought" (plan §8); and **there is no undo** — a purchase made by mistake is
corrected by deleting the item and re-adding the want, which is Decision 5 and
not an omission. **Four things the spec did not say, which the person decides at
that pause**: a bought entry is not counted in Settings' wanted-items number,
is not in the export-everything wishlist file, and is **not** removed by
"Delete all wanted items" (plan R1); buying from a Sell Plan screen takes the
person back to the Wishlist, two screens up (plan R2); the line under the price
stays silent when the difference is under a dollar, rather than reading "$0
more than you estimated" (plan Q7 — criterion 6 says "when they differ", and
this is narrower); and the purchase date can be set in the future, unlike the
sale sheet's, because the Edit screen that owns the same field allows it (plan
Q9 — a departure from the spec's "the sale sheet's twin"). The report puts all
four as questions, not facts.

## Phase 1 — Foundations: the marker, the writer, the rule (**foundational**)

- [x] **T001 — `WishlistItem.boughtDate`, `isBought`, and the CloudKit claim.**
  Per plan §1 and Q1. Add `var boughtDate: Date?` to `WishlistItem` —
  **declared without an initializer**, exactly as `Item.soldDate` is, because
  T013's `PurchaseUndoTests` counts assignments and `= nil` would be one — with
  the doc comment plan §1 gives it (the one bought predicate; written only by
  `WishlistPurchaseStore`; never cleared, Decision 5). Add
  `var isBought: Bool { boughtDate != nil }` beside it, `Item.isSold`'s shape.
  Append one sentence each to `plannedSaleItems`' and `itemsSoldToward`' doc
  comments naming what a purchase does to them (cleared; kept — spec P6,
  Decision 3). Add a sentence to `CloudKitSchemaTests`' doc comment naming this
  field as the second thing the suite has been asked to catch. Pattern:
  `Item.soldDate` and `Item.isSold` in `Trove/Models/Item.swift`. Tests
  (`ModelTests`): G1 — a fresh entry reads `boughtDate == nil` and
  `isBought == false`; one with a date reads true (mutation: invert the
  predicate → red). **The CloudKit mutation is the point of this task**: make
  the field `@Attribute(.unique) var boughtDate: Date?`, confirm
  `CloudKitSchemaTests.schemaMeetsCloudKitRequirements` goes red, revert, and
  record both outputs — the plan's compatibility claim is only worth the test
  that can catch it being false.
  Files: `Trove/Models/WishlistItem.swift`, `TroveTests/ModelTests.swift`,
  `TroveTests/CloudKitSchemaTests.swift` (comment).
  **Verify:** `scripts/verify.sh` green; both mutations recorded verbatim.
  **Done** (2026-09-19): `boughtDate` declared with no initializer after
  `year`, `isBought` beside it, the two doc-comment sentences on
  `plannedSaleItems` (emptied) and `itemsSoldToward` (kept), and the
  `CloudKitSchemaTests` paragraph naming the field. New `ModelTests` suite
  "The bought marker on WishlistItem" (2 tests). `scripts/verify.sh` green:
  **1555 tests in 211 suites** (baseline 1553/210). Mutations, both reverted:
  inverting `isBought` to `boughtDate == nil` → both G1 tests red
  (`ModelTests.swift:442`, `:454`); `@Attribute(.unique) var boughtDate` →
  `CloudKitSchemaTests.schemaMeetsCloudKitRequirements` red on "CloudKit
  integration does not support unique constraints". **Recorded**: that second
  mutation also reddened `TwoStoreContainerTests.theProductionPairingLoadsAndSplits`
  — the CloudKit claim has two live guards, not one. Also recorded for later
  bundles: `Item.isSold` is declared in `Trove/Models/Sale.swift`, not
  `Item.swift`.

- [x] **T002 — `Purchase` and `PurchaseCopy`.**
  Per plan §2, Q2, Q3 and Q7. New `Trove/Models/Purchase.swift`
  (`nonisolated struct Purchase: Sendable, Equatable` — `date`, `priceCents`,
  `location: String?`, `condition: Condition`) and
  `Trove/Models/PurchaseCopy.swift` (`nonisolated enum`, no SwiftUI, no colour)
  carrying the spec's Copy section whole plus
  `comparison(paidCents:estimatedCostCents:) -> String?`: nil when the estimate
  is 0, nil when the two are within 100 cents, else
  `"<magnitude> less/more than you estimated"` with the magnitude through
  `formattedAsWholeCurrency(currencyCode: "USD")`. Pattern:
  `Trove/Models/Sale.swift` and `Trove/Models/SaleCopy.swift`. Tests: new
  `TroveTests/PurchaseCopyTests.swift` — G3 (every string pinned by literal,
  `SaleCopyTests`' shape) and G4 (the comparison's five cases: $120 under, $85
  over, equal → nil, no estimate → nil, 40¢ apart → nil — mutations: swap
  more/less → red; drop the zero-estimate guard → the no-estimate case reads
  "$2,400 less than you estimated" → red; drop the sub-dollar floor → the 40¢
  case reads "$0 more than you estimated" → red).
  Files: `Trove/Models/Purchase.swift` (new), `Trove/Models/PurchaseCopy.swift`
  (new), `TroveTests/PurchaseCopyTests.swift` (new).
  **Verify:** `scripts/verify.sh` green, the new suite **in the count** (stop
  and flag if it is not); mutations recorded.
  **Done** (2026-09-19): both value files landed in the synchronized folders
  with no `.pbxproj` edit; new `PurchaseCopyTests` suite "Purchase copy"
  (7 tests) **is in the count** — `scripts/verify.sh` green at **1562 tests
  in 212 suites** (baseline 1555/211). Mutations, all reverted: swap
  more/less → 4 issues across both comparison tests; drop the zero-estimate
  guard → the no-estimate case red; drop the sub-dollar floor → 3 issues
  (the 40¢ case *and* the exact-equality case, one more than predicted).
  **Deviations**: (a) the task line predicted the dropped-guard case would
  read "$2,400 less than you estimated" — with the spec's own sign
  convention (`paid − estimate`) a $2,400 purchase against a 0 estimate
  reads "more"; the spec's convention was implemented and the test still
  reddens. (b) `boughtFromPlaceholder`'s wording is given nowhere in spec or
  plan, so it mirrors `SaleCopy.soldAtPlaceholder`: "eBay, Reverb, a
  friend…". One-line reword if T012's pass wants otherwise.
  **Recorded for T013**: exact-equality silence is carried by the sub-dollar
  floor alone (`abs(delta) >= 100` covers delta 0) — if the floor is ever
  removed at the person's request, criterion 6's equality case needs an
  explicit `deltaCents != 0` guard to replace it.

- [x] **T003 — `WishlistPurchaseStore.markBought` — the one writer. `review: per-task`.**
  Per plan §3, Q4, Q5, Q6 and Q12. New
  `Trove/Models/WishlistPurchaseStore.swift`, exactly the body plan §3 gives:
  `MarketLocalStore.clear(subjectID:)` **first**; the `Item` built with the
  eleven fields `Item.init` takes there (the thirteen G5 checks are those
  eleven, plus `desireToKeep` left at the default and `sortOrder`), `sortOrder` from
  `ManualOrderHelper.nextPosition(after:)` over every existing `Item`;
  `context.insert`; the photos **moved** (per photo:
  `wishlistItem = nil`, `item = item`, `sortOrder` renumbered from zero over
  `PhotoSelection.inDisplayOrder`) — never rebuilt; `wanted.boughtDate = now`;
  `wanted.plannedSaleItems = []`; `itemsSoldToward` untouched; the item
  returned. **Callers save** — this function does not, and its doc comment says
  so in `ItemSaleStore`'s words. `desireToKeep` is left at the initializer's
  default with a comment naming P5, not passed. Pattern:
  `Trove/Models/ItemSaleStore.swift` (the enum, the contract, the
  clear-first ordering); `ItemFormViewModel.save()` for the `nextPosition`
  call; `WishlistViewModel.duplicate(id:)` as the shape to **not** copy for
  photos, and why. Tests: new `TroveTests/WishlistPurchaseStoreTests.swift`,
  every persisted assertion refetched on a **second `ModelContext`** over the
  same container —
  **G5** the created item's thirteen fields, including
  `currentValueCents == purchasePriceCents`, `desireToKeep == 3`, the condition
  from the purchase, and `sortOrder` past a deliberate gap in the existing
  items' positions (mutations: leave `currentValueCents` nil → red; pass
  `wanted.desireToOwn` as `desireToKeep` → red; `sortOrder` from a count → red);
  **G6** photos — a `.device` photo and a `.fetched` one with all three
  attribution strings: the same `Photo` ids on the item afterwards, the
  store-wide `Photo` row count unchanged, the credit's three strings intact,
  `wishlistItem` nil on each, the wanted entry's `photos` empty, display order
  preserved (mutations: rebuild them as new `Photo(imageData:source:sortOrder:)`
  rows, the `duplicate(id:)` shape → the id, count and credit legs red; leave
  `photo.wishlistItem` set → the ownership leg red);
  **G7** the plan — `plannedSaleItems` empty, `itemsSoldToward` the same items
  in the same number, the released candidates still in the store and still
  unsold (mutations: clear `itemsSoldToward` → red; skip clearing
  `plannedSaleItems` → red);
  **G2** the marker and everything above surviving the caller's `save()` on a
  second context (mutation: drop the `save()` → red);
  **G8** no `MarketFigureRecord` / `MarketHistoryPoint` / `MarketMatchSnapshot`
  left for the wanted subject (mutation: drop the clear → red).
  **G14 — the one-writer guard, which is criterion 15's** — lands here rather
  than at the close-out, because "this function is the only thing that ever
  writes the marker" is this task's own claim. New
  `TroveTests/PurchaseUndoTests.swift` per plan Q13: every production file
  under `Trove/` walked (`SourceScan.production`), `boughtDate` assigned
  exactly once across all of them, that one assignment inside
  `Trove/Models/WishlistPurchaseStore.swift`, and no `boughtDate = nil` or
  `boughtDate = .none` anywhere. **Not a noun scan** — it counts the marker's
  writers, nothing else. **Match assignments only**, `boughtDate\s*=(?!=)`:
  T004 adds four `boughtDate == nil` comparisons, and a pattern that counts
  those reddens at T004 having been recorded green here (mutations: add
  `wanted.boughtDate = nil` to any view model → red naming the file; move the
  write into `WishlistViewModel` → the location leg red; add a
  `boughtDate == nil` comparison to a view model → **stays green**, which is
  the third mutation and the one that proves the pattern tells a write from a
  read; all three reverted).
  Also confirm `PhotoOwnershipTests` stays green with no edit — and if its
  invariant has no case over a moved photo, add one there rather than here.
  Files: `Trove/Models/WishlistPurchaseStore.swift` (new),
  `TroveTests/WishlistPurchaseStoreTests.swift` (new),
  `TroveTests/PurchaseUndoTests.swift` (new),
  `TroveTests/PhotoOwnershipTests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded; the new suite in the count.
  **Done** (2026-09-19): the store is plan §3's body line for line; three new
  suites in the count — `scripts/verify.sh` green at **1570 tests in 214
  suites** (baseline 1562/212), **re-run by the orchestrator** before and
  after the review fix, same count both times. `PhotoOwnershipTests` **did**
  need a case added: its invariant had no case over a photo that changes
  parent. Mutations, all reverted and all red as specified — G5
  (`currentValueCents` nil; `desireToOwn` passed as `desireToKeep`;
  `sortOrder` from a count; and, added by the review, `currencyCode` dropped);
  G6 (photos rebuilt in `duplicate(id:)`'s faithful shape → id, count and
  credit legs red; `wishlistItem` left set → the ownership leg red in both
  suites); G7 (`itemsSoldToward` cleared; `plannedSaleItems` left); G2 (the
  caller's `save()` dropped); G8 (the market clear dropped); **G14's three**
  — a `boughtDate = nil` added to a view model → red naming the file; the
  write moved out of the store → the location leg red while the count leg
  stays green; a `boughtDate == nil` **comparison** added to a view model →
  **stays green**, which is what proves the pattern tells a write from a read
  and why T004's four predicates will not redden it.
  **G14 against the constitution rule added after sign-off** (`5026305`): it
  survives, and the reviewer agreed. It asserts an absence and a uniqueness
  count across all production files — no view-model suite can observe that
  the *app* contains no other writer, which is criterion 15's actual claim —
  and it fails the "delete the behaviour, keep the string" test in the right
  direction, since deleting the one assignment takes the count to zero.
  **Two false-passing fixtures found and fixed, same shape**: `desireToOwn`
  was 3, equal to `desireToKeep`'s default, so a carried-across value was
  invisible (found by the implementer); `currencyCode` was `"USD"`, which
  **both** initializers default to, so dropping `currencyCode:
  wanted.currencyCode` left the test green (found by the review, blocking).
  Per `CLAUDE.md` the whole diff was then audited for the shape leg by leg —
  nothing else found, and the reviewer re-checked the audit against the
  constructors. **Carry this forward**: whenever a test asserts field X is
  carried across, the fixture's X must differ from `Item.init`'s default for
  X — for `currencyCode` that means never `"USD"`.
  **Review**: `skeptical-reviewer`, one blocking finding (the `currencyCode`
  leg), fixed and re-reviewed; signed off with three non-blocking items left
  open for the sweep and T013 — (a) criterion 15's close-out wording must say
  G14 cannot see an undo implemented by deleting the created `Item` and
  re-inserting a `WishlistItem` (belongs in plan Q13's close-out note);
  (b) the doc comment's "a failure in the clear leaves nothing written" is
  inspection, not a test, matching `ItemSaleStore`'s existing posture;
  (c) `(try? context.fetch(…)) ?? []` would silently put the item at the
  *top* of the order — plan §3's literal code, identical to
  `ItemFormViewModel.save()`, so a known property of both call sites.

- [x] **T004 — What leaves the Wishlist: the exclusion rule at five read sites. `review: per-task`.**
  Per plan §4, Q11, Q12 and **R1**. `WishlistViewModel.load()` splits the fetch
  (`let wanted = all.filter { !$0.isBought }`) and derives `totalCount`,
  `items`, `categoryOptions`, `categoryLabels` and `marketSummaries` from
  `wanted`, never `all`. `SettingsViewModel`: `wishlistCount`'s `fetchCount`,
  `everythingInCustomOrder()`'s `wanted` fetch, and
  `confirmDeleteAll(.wishlist)`'s walk each take
  `#Predicate<WishlistItem> { $0.boughtDate == nil }`.
  `MarketRefresher.targets(in:)`'s wanted predicate gains
  `&& $0.boughtDate == nil`, with its doc comment extended in the sentence the
  sold rule already has. Leave the five fetches plan §4 lists as unchanged
  unchanged, each with the one-line comment saying why. Pattern:
  `ItemListViewModel.load`'s owned/sold split; `MarketRefresher.targets`' own
  `soldDate == nil` clause. Tests:
  **G9** (`WishlistViewModelTests`) a bought entry is out of `items`,
  `totalCount`, `categoryOptions` and `totalEstimatedCostCents`; buying the
  only entry leaves `emptyReason == .nothingAdded` (criterion 11, **today's**
  state — no new case); a bought entry never reappears after a reorder
  (mutations: drop the split → red; filter `items` but leave `totalCount =
  all.count` → the empty-state leg reddens **alone**);
  **G10** (`SettingsViewModelTests`) `wishlistCount` and `canDeleteWishlist`
  ignore it; export-everything's wishlist CSV and PDF carry only the live rows
  while the items CSV carries the purchased item; `confirmDeleteAll(.wishlist)`
  leaves the bought row in the store and deletes the live ones (mutations: drop
  each predicate in turn → the matching leg red);
  **G11** (`MarketRefresherTests`) a bought matched entry is no target, an
  unbought one still is, and Settings' matched count follows (mutation: drop
  the clause → red).
  Confirm `ExportSchemaTests`' `wishlistHeaders` literal stays green with no
  edit — no new column (criterion 13).
  Files: `Trove/ViewModels/WishlistViewModel.swift`,
  `Trove/ViewModels/SettingsViewModel.swift`, `Trove/Market/MarketRefresher.swift`,
  `TroveTests/WishlistViewModelTests.swift`, `TroveTests/SettingsViewModelTests.swift`,
  `TroveTests/MarketRefresherTests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded.
  **Done** (2026-09-19): all five read sites changed; the five left alone each
  carry their one-line "deliberately unchanged" comment. `scripts/verify.sh`
  green at **1580 tests in 216 suites** (baseline 1570/214), **re-run by the
  orchestrator**. `ExportSchemaTests` and `PurchaseUndoTests` both green
  **unmodified** — the four new `boughtDate == nil` predicates left the
  one-writer guard green, which is what T003's third mutation predicted.
  Mutations M1–M8, all reverted, each reddening its own predicate's legs and
  nothing else's; in particular M2 (filter `items`, leave `totalCount =
  all.count`) reddens the **empty-state leg alone**, as the task line
  required.
  **Two deviations, both accepted**: (a) four comment-only edits outside the
  task line's `Files:` list — plan §4 requires the "unchanged, deliberately"
  comment at each of those sites and the file list under-described it; per
  this file's own header the plan section is the authority. (b) `totalCount`
  is asserted in the empty-state test rather than in G9's first test, because
  M2 can only redden one leg if the count is asserted in one place.
  **Review**: `skeptical-reviewer`, **no blocking findings**, signed off.
  Seven second-look items; four were cheap and were applied in the same
  commit — the `load()` comment rewritten (see below), the export test's
  overclaiming message corrected, a `marketSummaries` leg added, and the
  reorder fixture moved so the position collision it describes actually
  happens. Three are carried: criterion 11's real guard is the *filtered*
  empty-state leg rather than the unfiltered one (say so at T013);
  `MarketRefresher.currentTarget(for:)` was missing from plan §4's
  enumeration (**fixed in `plan.md` in this commit**); and R1's promise that
  the person hears about the two Settings behaviours the spec never mentioned
  is carried into the Phase 2 pause report.
  **`plan.md` corrected in place, twice, by the orchestrator**: Q11's stated
  rationale was factually wrong — `ListEmptyReason.reason` falls through to
  `.nothingAdded` whenever nothing narrows the list, so a stale `totalCount`
  alone does not produce a filter's empty state. The requirement is unchanged
  and the real reason is that `WishlistView` gates the search field, the chips
  and the sort control on `totalCount > 0`. The implementer found it, then
  copied the wrong wording into a code comment anyway; the review caught that
  and both now state the traced reason. §4's "five left alone" list gained a
  sixth site with its reason.

- [x] **T005 — `PurchaseFormViewModel`.**
  Per plan §5, Q7, Q9 and Q10's seeding rule. New
  `Trove/ViewModels/PurchaseFormViewModel.swift`: `@Observable`, no SwiftUI
  import, `price: Decimal?` seeded from `estimatedCostCents` **only when it is
  non-zero** (nil otherwise — a pre-filled 0 cannot be typed over), `date` from
  the injected clock, `location`, `condition = .excellent`, two validation
  errors (`priceMissing`, `priceNegative`) and **no date rule** (Q9 — the field
  it fills is `Item.purchaseDate`, whose own form bounds nothing), `title` /
  `confirmLabel` / `comparisonLine` from `PurchaseCopy`, and `purchase() ->
  Purchase?` normalizing the location through `FieldNormalization.nilIfBlank`.
  Pattern: `Trove/ViewModels/SaleFormViewModel.swift`, field for field, minus
  the mode and the date bound. Tests: new
  `TroveTests/PurchaseFormViewModelTests.swift` — **G20**: the seed with and
  without an estimate; blank price → `.priceMissing` and `purchase() == nil`;
  negative → `.priceNegative`; zero → valid; **a date a week ahead → valid**,
  pinned with a comment naming Q9 so the divergence from the sale sheet is
  deliberate rather than forgotten; a whitespace-only location → nil;
  **G4**'s line read through `comparisonLine` at three typed prices (mutations:
  a `?? 0` seed → the no-estimate case red; a date rule added → the
  future-date case red).
  Files: `Trove/ViewModels/PurchaseFormViewModel.swift` (new),
  `TroveTests/PurchaseFormViewModelTests.swift` (new).
  **Verify:** `scripts/verify.sh` green, the new suite in the count; mutations
  recorded.
  **Done** (2026-09-19): `SaleFormViewModel` field for field, minus the mode
  and the date bound; Foundation and Observation only, no SwiftUI. Three new
  suites **in the count** — `scripts/verify.sh` green at **1591 tests in 219
  suites** (baseline 1580/216). Mutations, both reverted: a `?? 0` seed → the
  no-estimate case red on all three legs; a date rule added → **exactly one**
  test red, the Q9 pin that names the divergence, which is the right blast
  radius.
  **Falsifiability walk done on every new assertion** (the discipline T003
  and T004 forced): the estimate 240_000, the seeded price 2400, the typed
  price 239_901 and the `.fair` condition are each distinct from every
  default and from each other, so no leg passes by coincidence — and
  `.excellent` is *not* `Condition`'s first case, which is what makes the
  default assertion falsifiable at all.
  **One assertion declared weak rather than dressed up**:
  `namesTheSheetFromTheCopyTable` cannot catch `sheetTitle` and `confirm`
  being swapped, because **they are the identical string "Mark as bought"**.
  Kept, with a comment, because it does catch a hand-typed literal drifting
  from the table. **T007 must not write a view test that looks like it pins
  that wiring** — no test can.
  **One extra test beyond the task's list, declared**: `readsABlankPriceAsZero`,
  which is the only coverage of `comparisonLine`'s `?? 0` branch (plan §5
  names it; the task line's "three typed prices" did not reach it).

- [x] **T006 — The three hosts' intents.**
  Per plan §6 and Q10. On `WishlistViewModel`, `WishlistDetailViewModel` and
  `SellPlanViewModel`: `makePurchaseFormViewModel(for:)` (the detail's and the
  plan's take no argument — their subject is the entry they hold) and
  `markBought` → `WishlistPurchaseStore.markBought(…, at: now(), in:
  modelContext)`, one `save()`, `rollback()` on refusal, returning the outcome.
  **The failure property and the ordering are per host — do not copy one shape
  three times** (plan §6): `WishlistViewModel` sets `loadFailureMessage`
  *after* `rollback()` and `load()`, because its `load()` opens by clearing it
  (the ordering `delete(id:)` already has right and `014`'s T005 got
  backwards); `SellPlanViewModel` sets its existing `saveFailureMessage` in the
  order its own `markSold` uses (`rollback()`, message, `load()`), since its
  `load()` clears nothing and two intents on one screen should read alike;
  `WishlistDetailViewModel` gets a **new `purchaseFailureMessage`** — not
  `deleteFailureMessage`, which names a different act — set after `rollback()`.
  `WishlistDetailViewModel` also gains
  `private(set) var hasBeenBought`, set from the fetched entry in `load()`
  (plan R2). `SellPlanViewModel.markBought(purchase:)` does **not** reload on
  success — the screen is dismissing. Pattern:
  `SellPlanViewModel.markSold(_:sale:)` and `makeSaleFormViewModel(for:)`;
  `WishlistViewModel.delete(id:)` for the refusal ordering. Note checked at
  planning: no structural test allow-lists `WishlistPurchaseStore`'s callers,
  and the view-file scans that name `ItemSaleStore` assert a *view* never names
  it — T008–T010 must keep the three wishlist views free of the word
  `WishlistPurchaseStore` for the same reason. Tests:
  **G12** a new `everyHostSeedsThePurchaseSheetIdentically` (the `014`
  `everyHostSeedsTheMarkSheetIdentically` shape, in
  `WishlistDetailViewModelTests`) over the three hosts, with and without an
  estimate (mutation: `?? 0` in one seed → red; one host on a different clock →
  red); a purchase through each host leaves the same item and the same marker
  on a second context;
  **G13** the three refusal scans, the
  `ItemDetailViewModelTests.aRefusedAdoptSaveReportsAndCloses` shape: exactly
  one `modelContext.save()` per method, `rollback()` and the message inside the
  one `catch` and nowhere else (mutation: drop `rollback()` → red);
  **G19** `hasBeenBought` true for a bought entry, false otherwise;
  **G22** (criterion 10) `DashboardViewModel`'s figures over a store where the
  item arrived by purchase equal its figures over one where the same fields
  were typed in — the criterion's claim is indistinguishability, so the test
  compares two collections rather than asserting numbers (mutation: the store
  leaving `currentValueCents` nil → the un-valued count diverges → red).
  Files: `Trove/ViewModels/WishlistViewModel.swift`,
  `Trove/ViewModels/WishlistDetailViewModel.swift`,
  `Trove/ViewModels/SellPlanViewModel.swift`,
  `TroveTests/WishlistViewModelTests.swift`,
  `TroveTests/WishlistDetailViewModelTests.swift`,
  `TroveTests/SellPlanViewModelTests.swift`,
  `TroveTests/DashboardViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded; `scripts/verify.sh ui`
  once at the phase end, count recorded (the `014` Phase 1 review's cadence).
  **Done** (2026-09-19): the three hosts each got the two members, with the
  three *different* failure orderings plan §6 specifies — `WishlistViewModel`
  reports after `load()` because its `load()` clears that property, the other
  two before. `scripts/verify.sh` green at **1599 tests in 223 suites**
  (baseline 1591/219) and `scripts/verify.sh ui` green: `Executed 23 tests,
  with 0 failures (0 unexpected)`. **Fourteen mutations**, all reverted, each
  naming the leg it reddened — including M7, which is the `014` T005 ordering
  bug deliberately reintroduced and caught.
  **Three assertion legs deleted as unfalsifiable rather than shipped**: the
  cross-host `title`/`confirmLabel` comparison (get-only constants on one
  type), and a `fetch(WishlistItem).isEmpty` leg that asserted its own setup.
  **One fixture coincidence found and fixed by the implementer** before
  reporting: a seed of `desireToOwn: 3` would have let a store carrying the
  wanting scale across pass. That is the fifth instance of this shape in the
  spec and the second caught before review.
  **Recorded**: the Dashboard's breakdown groups by the *leading* path
  segment, so G22's fixture needed three different roots to exercise it;
  `FetchDescriptor<Item>` order is not insertion order, so the landing helper
  selects by name.

- [ ] **T006a — The Phase 1 review's blocking finding: a purchase can only happen once.**
  Raised by the phase review, not by the plan. **`markBought` was not
  idempotent**: there was no `isBought` check in the store or in any host, so
  a second call inserted a **second `Item`** and **re-stamped `boughtDate`,
  destroying the first purchase's marker** — the duplicate criterion 8
  forbids, with no undo to correct it. Two windows reached it, and the first
  is the case R2 exists for: `.onAppear` fires on push and on return, **not
  when the data changes underneath**, so a marker arriving from another
  device (criterion 12 says it syncs) leaves the action live on a foreground
  screen; and the Sell Plan deliberately does not reload on success, so its
  button stays live while the view dismisses. Only the phase view could see
  this — T003's review saw one function with one caller, and T006's hosts
  were written against a store that looked safe.
  **Fixed in the one writer**, so it closes both windows and every future
  host: `PurchaseError.alreadyBought`, thrown (**not** a `precondition`,
  which could only fail by trapping — the untestable shape `CLAUDE.md`
  records from `002` T021), guarded **before** the market clear so a refusal
  writes nothing at all. Both tests behavioural, refetched on a second
  context; the host test builds all three hosts *before* the purchase, which
  reproduces the cross-device window rather than describing it. Mutation
  (guard removed) → **12 legs red**, covering both halves of the damage.
  The implementer caught a clock coincidence in their own new test first —
  the hosts shared the store's injected clock, so a re-stamp would have
  written the identical instant and 2 of the 12 stayed green.
  Also fixed: S3 (the sixth unchanged refresher site got its comment), S4
  (the loose "its `load()` clears nothing" corrected in three code comments
  and in `plan.md` Q10), S5 (`itemPhotoNames` held sort orders, not names),
  S6 (the detail host's missing "nothing loaded" test), S1 (T005's weak
  assertion's comment now states what it actually guards). The orchestrator
  moved a mis-spliced G19 doc comment back onto its own test.
  `scripts/verify.sh` green at **1602 tests in 223 suites**, re-run by the
  orchestrator. **Re-reviewed and signed off; nothing blocking remains.**
  **Two things carried out of it**: (a) `plan.md` R2 now says what `.onAppear`
  does and does not cover, and **T012 must exercise the cross-device window
  deliberately** — the unit test proves the guard, not that the marker is
  visible in time; (b) **a refused purchase is silent on all three screens**
  (no view reads any failure message), which was a disk-failure path nobody
  would meet and is now the expected outcome of a real sequence. On the
  Wishlist row it self-corrects; on the other two the person taps, the sheet
  closes, and the page still offers the action. **This goes to the person at
  the Phase 2 pause as a fifth question**, with the cost stated: it needs a
  copy string plus either a `LocalizedError` conformance or an explicit case
  in each host, not a one-line change.

  **Phase 1 closes here — pause for the person** (nothing to try yet; the pause
  is the review gate — the report may offer to run straight on).

## Phase 2 — Screens

- [x] **T007 — The purchase sheet.**
  Per plan §7, Q8 and the spec's Copy and Design requirements. New
  `Trove/Views/Wishlist/PurchaseFormView.swift`: `SaleFormView`'s
  `NavigationStack`, detents, toolbar pair, `PlateSurface` chrome and rust
  invalid border; price and date paired on one row (identifier
  `purchase.sheet.price`, the date popover **unbounded**, Q9); the comparison
  line directly beneath when non-nil, `.monoLabel(color: theme.colors.textQuiet)`,
  no colour branch, identifier `purchase.sheet.comparison`; Bought from; and
  Condition as `ItemFormView`'s label-plus-`FlowLayout`-of-capsules over
  `Condition.allCases`, each chip keeping the selected trait. No Note field, no
  currency picker, every word from `PurchaseCopy`, nothing written here.
  Pattern: `Trove/Views/Items/SaleFormView.swift` for the whole file;
  `ItemFormView.conditionChip` for the capsules. Tests: new
  `TroveTests/WishlistPurchaseWiringTests.swift` — **G21**: the five elements
  in ascending source order; the file names no `SaleCopy`, no `"Note"`, no
  `ModelContext`, no `WishlistPurchaseStore`; the confirm button's action sits
  past a `viewModel.purchase()` guard (mutations: reorder two fields → red;
  call `confirm` without the guard → red). `MenuPolicyTests` re-confirmed (this
  file must host no system menu — a `.pickerStyle(.menu)` condition control
  would be the tempting mistake; try one, confirm red, revert).
  Files: `Trove/Views/Wishlist/PurchaseFormView.swift` (new),
  `TroveTests/WishlistPurchaseWiringTests.swift` (new).
  **Verify:** `scripts/verify.sh` green, the new suite in the count; mutations
  recorded. No simulator check here — T012 covers the sheet's look, its live
  comparison line and its spoken field names.
  **Done** (2026-09-20): the sale sheet's twin — same `NavigationStack`,
  detents, toolbar pair, `PlateSurface` chrome and rust invalid border; the
  date popover **unbounded** (Q9); the comparison line beneath the price with
  no colour branch; condition as capsules, not a picker. The file names no
  `SaleCopy`, no `"Note"`, no `ModelContext` and no `WishlistPurchaseStore`.
  New suite **in the count** — `scripts/verify.sh` green at **1607 tests in
  224 suites** (baseline 1602/223). **Seven mutations**, all reverted:
  reordering the fields' *composition* and reordering their *declarations*
  (both needed — either edit alone moves the fields, and only walking both
  catches both); confirm without the `purchase()` guard; a
  `.pickerStyle(.menu)` condition control → **`MenuPolicyTests` red**, so the
  tempting mistake is genuinely blocked; each of the four naming legs firing
  independently; a renamed identifier; and a date bound pasted back in.
  **A leg was found false-passing while being written and restructured before
  it landed**: `code.contains("purchase.sheet.comparison")` is satisfied by
  the longer literal `"purchase.sheet.comparisonX"`, so renaming the
  identifier left it green. It now compares whole string literals.
  **Two additions beyond the task line, both declared and mutation-verified**:
  `theIdentifiersArePresent` (T012 drives the sheet by those identifiers), and
  — at the orchestrator's request, from the implementer's own finding —
  `theDatePickerIsUnbounded`. The second is the twin-file risk plan Q9 names:
  paste `in:` back from `SaleFormView` and the deliberate divergence vanishes
  with nothing red. It passes the constitution's source-scan rule for the
  right reason — the view model's side is already covered behaviourally, but
  a *popover's bound* is a view-body fact no view-model test can observe.
  **Two findings carried to the close-out**: (a) **the same substring
  false-pass shape lives in merged code** — `SaleFormWiringTests.theIdentifiersArePresent`
  stays green if `sale.sheet.price` is renamed to `sale.sheet.priceX`. Per
  `CLAUDE.md`'s audit-the-shape rule this wants a scan of every `*WiringTests`
  for substring identifier checks, and per its merged-code rule that is a
  `fix/` branch of its own, not this spec. (b) `monoLabel` uppercases, so the
  comparison line reads **"$120 LESS THAN YOU ESTIMATED"**. That is what plan
  §7 specifies verbatim, and whether it reads as the "quiet" supporting text
  the spec asks for is **the person's call at the Phase 2 pause**.

- [x] **T008 — The Wishlist row's Buy swipe, the sheet on the list, the `ActionBuy` icon.**
  Per plan §8 and Q14. In `WishlistView`: `@State private var itemBeingBought:
  WishlistItem?`; the leading swipe becomes Edit / **Buy**
  (`Label { Text(PurchaseCopy.swipeBuy) } icon: { Image("ActionBuy") }`,
  `.tint(theme.colors.accentBrassMid)`,
  `.accessibilityLabel(PurchaseCopy.markAsBought)`) / Copy — Edit still nearest
  the edge (criterion 1); the trailing delete swipe untouched;
  `.sheet(item: $itemBeingBought, onDismiss: viewModel.load)` composing
  `PurchaseFormView` over `viewModel.makePurchaseFormViewModel(for:)`, confirm
  → `viewModel.markBought`, both closures nil-ing the state. New
  `design/icons/action-buy.svg` (a bag outline in `action-sell.svg`'s style: 24
  viewBox, 1.5 stroke, `#000`) copied into
  `Trove/Assets.xcassets/ActionBuy.imageset/` with `ActionSell`'s
  `Contents.json` shape (template, vector preserved). **Flag if** the build
  does not pick the imageset up — no `.pbxproj` edit. Pattern:
  `ItemListView`'s leading swipe block (`014` T007) and its
  `.sheet(item: $itemBeingSold)`. Tests (`WishlistPurchaseWiringTests`):
  **G15** — the one leading block's three `Button`s name, in order, `"Edit"`,
  `PurchaseCopy.swipeBuy`, `"Copy"`; the middle one writes `itemBeingBought`
  and carries `.accessibilityLabel(PurchaseCopy.markAsBought)` and
  `"ActionBuy"`; the trailing block names no `PurchaseCopy`; exactly one
  `.sheet(item: $itemBeingBought` over `PurchaseFormView(` and
  `makePurchaseFormViewModel(for:`; the file names no `WishlistPurchaseStore`
  (mutations: swap Buy and Copy → red; wire the middle button to
  `itemBeingEdited` → red). **G16** — `ActionIconTests` gains `ActionBuy`:
  it resolves, renders as a template, and the **five** action glyphs are five
  distinct marks (mutations: remove `"template-rendering-intent"` → red; copy
  `action-sell.svg`'s bytes into the new imageset → the distinctness leg → red).
  Files: `Trove/Views/Wishlist/WishlistView.swift`,
  `design/icons/action-buy.svg` (new),
  `Trove/Assets.xcassets/ActionBuy.imageset/Contents.json` + `action-buy.svg`
  (new), `TroveTests/WishlistPurchaseWiringTests.swift`,
  `TroveTests/TabIconTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded. No simulator check
  here — T012 covers the swipe on both appearances and the spoken name.
  **Done** (2026-09-20): Edit / **Buy** / Copy in the one leading block, Edit
  still nearest the edge (criterion 1), the trailing delete untouched and
  naming no `PurchaseCopy`; the sheet hosted once over the staged row; the
  view names no `WishlistPurchaseStore`. **The new imageset joined the build
  by existing inside `Trove/Assets.xcassets/` — no `.pbxproj` edit and
  nothing to flag**, which settles the same question for the rest of the
  spec's asset work. `scripts/verify.sh` green at **1609 tests in 224
  suites** (baseline 1607/224 — the parameterized icon tests count once per
  function, so the fifth glyph adds no test).
  **Six mutations**, all reverted (restored from the implementer's own copy,
  never `git checkout --`, which is unsafe once the orchestrator has staged):
  swap Buy and Copy → **7 legs red**; the middle button wired to
  `itemBeingEdited` → the target leg red **alone**, which is what proves each
  leg is evaluated against the middle button rather than the block; drop one
  `itemBeingBought = nil` → red; remove `"template-rendering-intent"` → only
  the `ActionBuy` case of the parameterized template test falls; copy
  `action-sell.svg`'s bytes into the new imageset → **the distinctness leg
  alone** red, resolve and template staying green as specified; and the two
  negative legs (`PurchaseCopy` in the trailing block, `WishlistPurchaseStore`
  in the view) each red on their own.
  **T007's substring trap was checked for, not assumed**: every positive
  literal in G15 is closed on both sides (`Text(PurchaseCopy.swipeBuy)`,
  `Image("ActionBuy")`, `.accessibilityLabel(PurchaseCopy.markAsBought)`), so
  a rename to `…X` cannot satisfy it. One leg is declared as reddened by no
  mutation run — `!buttons[1].contains("accentRust")` — but it is a genuine
  negative over a slice the other legs prove is the right slice.
  **Recorded for T012 and any later asset work**: an `Assets.xcassets` change
  forces a far slower `xcodebuild test` than a source change — each icon
  mutation took over ten minutes against roughly two for a Swift-only edit.

- [x] **T009 — The wishlist detail's menu row, its sheet, and dismiss-on-bought.**
  Per plan §8 and **R2**. In `WishlistDetailView`: the `DetailOverflowMenu`
  call moves to the `(noun:edit:middle:delete:)` initializer, which means the
  file now builds two **`DetailOverflowMenu.Row`** values — qualified, since
  `Row` does not resolve bare here — `edit:` being today's Edit/pencil row and
  `middle:` being `DetailOverflowMenu.Row(title: PurchaseCopy.markAsBought,
  systemImage: "bag", action: { isMarkingBought = true })`;
  `@State private var isMarkingBought = false` and
  a `.sheet(isPresented:)` over `PurchaseFormView`, confirming through
  `viewModel.markBought(purchase:)` and `dismiss()`ing on true; `.onAppear`
  becomes `viewModel.load()` then `if viewModel.hasBeenBought { dismiss() }`.
  **No button anywhere in `content(for:)`** (criterion 2, spec P1).
  **This reverses a `006` decision and breaks a `006` guard — rewrite it, do
  not dodge it.** `SoldStateWiringTests.theWishlistPageKeepsTheOriginalMenuAndNamesNoSaleCopy`
  (`:114–129`) asserts `!code.contains("DetailOverflowMenu.Row")` over this
  file, because in `006` the wishlist page was untouched; the change above
  makes that claim false, and spelling the rows `.init(...)` to keep the scan
  green would be the false-passing shape `CLAUDE.md` records four times.
  Rewrite it to pin the new rule: the file composes `DetailOverflowMenu(`,
  builds **two** `DetailOverflowMenu.Row` argument lists — `edit:` and
  `middle:` — of which **exactly one** names `PurchaseCopy.markAsBought`, and
  the file still names **no** `SaleCopy` (the half of the original claim that
  is still true). Use `SourceScan.argumentLists(of: "DetailOverflowMenu.Row",
  in: code)`, `#require` the total, then filter — the shape
  `SoldStateWiringTests.swift:54-68` already uses. Sign-off correction,
  2026-09-19 (re-review): counting `DetailOverflowMenu.Row` occurrences and
  expecting **one** reads red on correct code, since the file legitimately
  holds two. **Leave the two-argument convenience initializer in place** — after
  this change `ItemDetailView` and the component's own `#Preview` are its
  callers, the preview is invisible to `SourceScan.production`, and deleting
  the initializer is scope creep that would break it. Say so in the corrected
  doc comment, so it does not read as dead. Correct
  `DetailOverflowMenu.swift`'s doc comment in the same commit — the sentence
  recording the two-argument initializer as "what the wishlist's page asks for
  — it is untouched by this spec" is now false; say what `015` does to it and
  leave `006`'s reasoning above it intact. **Append a "Superseded by `015`"
  pointer to `specs/006-mark-as-sold/plan.md:559-561`**, whose claim that the
  two-argument initializer is kept "so `WishlistDetailView` is untouched" this
  task falsifies — in place, beside the original, never editing the shipped
  claim away (`014/plan.md:704-711` is the pattern). Sign-off correction,
  2026-09-19 (re-review N2): plan §1 first said no pointers were due.
  `DECISIONS.md` gets the reversal at T013, and T013 verifies the pointer
  landed. Mutations: spell the rows `.init(` → the rewritten test's
  one-middle-`Row` leg red (where the old test would have gone green — record
  both, that contrast is the point); drop the middle row → the `#require` on
  the anchor fails; name `SaleCopy` in the file → red.
  Pattern: `ItemDetailView.overflowMenu` and its `markAsSoldRow`. Tests
  (`WishlistPurchaseWiringTests`): **G17** — `PurchaseCopy.markAsBought`
  appears in `WishlistDetailView.swift` **exactly once**, inside the
  `DetailOverflowMenu(` argument list, and the file composes exactly one
  `.sheet(isPresented: $isMarkingBought` over `PurchaseFormView(`; the
  `.onAppear` names `hasBeenBought` and `dismiss` (mutations: add a page button
  → the count goes to 2 → red; drop the `.onAppear` guard → red; drop the row →
  the `#require` on the anchor fails → red). `MenuPolicyTests` stays green with
  no edit — this adds a row to the app's one system menu, not a second menu
  (confirm; a `Menu` added to `WishlistDetailView` → red, reverted).
  Files: `Trove/Views/Wishlist/WishlistDetailView.swift`,
  `Trove/Views/Shared/DetailOverflowMenu.swift` (doc comment),
  `TroveTests/SoldStateWiringTests.swift`,
  `TroveTests/WishlistPurchaseWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.
  **Done** (2026-09-20): the page moved to the `(noun:edit:middle:delete:)`
  initializer with two qualified rows built **inline** in the call (G17
  requires the word to sit *inside* the argument list, so a computed property
  like the pattern's `markAsSoldRow` would have reddened the guard over
  correct code); the sheet presented once; `.onAppear` reloads then dismisses
  on `hasBeenBought`; **no button in `content(for:)`**. `scripts/verify.sh`
  green at **1612 tests in 224 suites** (baseline 1609/224 — three new tests;
  the rewritten `006` guard replaces one, so no net change there).
  **The dodge was demonstrated, not just avoided.** Mutation M1 spelled the
  rows `.init(` **and temporarily re-added `006`'s guard verbatim beside the
  rewrite**: the rewritten guard went red on its two-row anchor while
  `theWishlistPageKeepsTheOriginalMenuAndNamesNoSaleCopy` — `006`'s
  assertions unchanged — **passed over a page that had already grown the
  row**. That is the second time this project has caught this exact shape on
  this exact guard (the first was `015`'s own planning finding about `014`),
  and it is now a demonstration rather than an argument.
  Seven further mutations, all reverted: the row dropped → both anchors
  `#require`-fail; `SaleCopy` named → red; a page button added → the mention
  count goes to 2 → red; the `.onAppear` guard dropped → red; a real `Menu`
  added → **`MenuPolicyTests` red** (it needed **no edit** for the rows
  themselves — a `DetailOverflowMenu.Row` is not a system menu); the sheet
  confirming into nothing → red; and **M8, criterion 2's real failure mode**
  — the word *moved* from the row to a page button, so the count stays 1 and
  only the "it is inside the menu's argument list" leg catches it.
  **The task line was wrong about one fact and the implementer corrected it
  accurately**: `ItemDetailView` calls the *four*-argument initializer, so
  after this change the component's own `#Preview` is the **only** caller of
  the two-argument one. Same conclusion — keep it, it is not dead — stated
  truthfully in the doc comment and in the `006` pointer.
  **A landmine found and worth the whole project knowing**: `SourceScan.production`
  cuts a file at the first literal `#Preview` **before** stripping comments,
  so merely writing "`#Preview`" **inside a doc comment** truncates the file
  to its header for every scan. Doing so silently reddened `MenuPolicyTests`
  and `SoldStateWiringTests` with no code change. Caught on the first verify
  and fixed by rewording. **T013 should record this in `plan.md` or beside
  `SourceScan` itself** — the next person to document a scanned file will hit
  it, and the failure points at the wrong file entirely.

- [ ] **T010 — The Sell Plan's action, its sheet, and its dismiss.**
  Sign-off correction, 2026-09-19 (re-review): G18's gate leg scans for a
  `viewModel.wishlistItem != nil` span, but `SellPlanView.swift:49` reads
  `if let wanted = viewModel.wishlistItem`. Write the gate with that exact
  spelling — `.toolbar { if viewModel.wishlistItem != nil { … } }` — so the
  scan matches what correct code says; a behaviourally-identical `if let _ =`
  or `.disabled(… == nil)` would redden a guard over working code.
  Per plan §8 and **R2**. In `SellPlanView`: a
  `.toolbar { ToolbarItem(placement: .topBarTrailing) { … } }` holding —
  **only when `viewModel.wishlistItem != nil`**, since this screen already
  draws a `missingItem` state when its entry has gone and an ungated button
  there would confirm a purchase with no subject — a
  `Button { isMarkingBought = true } label: { Image(systemName: "bag") }` with
  `.accessibilityLabel(PurchaseCopy.markAsBought)` and
  `.accessibilityIdentifier("purchase.sellPlan")`; `@State private var
  isMarkingBought = false`; a second `.sheet(isPresented:)` beside the existing
  `.sheet(item: $viewModel.saleCandidate)`, over `PurchaseFormView` seeded by
  `viewModel.makePurchaseFormViewModel()`, confirming through
  `viewModel.markBought(purchase:)` and `dismiss()`ing on true. No `Menu` (plan
  §8: a one-row menu is a menu for nothing). Pattern:
  `WishlistDetailView`'s `.toolbar` block for the placement;
  `SellPlanView`'s existing sale sheet for the host shape. Tests
  (`WishlistPurchaseWiringTests`): **G18** — exactly one toolbar button naming
  `PurchaseCopy.markAsBought`, composed **inside** a `viewModel.wishlistItem
  != nil` span, exactly one `.sheet(isPresented: $isMarkingBought` over
  `PurchaseFormView(`, the confirm closure naming both `markBought` and
  `dismiss`, and the file naming no `WishlistPurchaseStore` (mutations: drop
  the `dismiss()` → red; host the sheet twice → red; drop the gate → red). The existing `SellPlanWiringTests` and
  `SellPlanFramingTests` stay green with no edit — confirm.
  Files: `Trove/Views/Wishlist/SellPlanView.swift`,
  `TroveTests/WishlistPurchaseWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T011 — The UI tests, run twice.**
  Per plan §9 — **no seed change**: `-seedSellPlan` already carries the one
  wanted item ("Summicron 35mm f/2", estimated $2,400) and the owned
  candidates these two tests read. New
  `testTheWishlistsLeadingSwipeOffersMarkAsBoughtAndTheSheetSeedsFromTheEstimate`
  and `testMarkingAWantedItemBoughtMovesItToTheCollection`, exactly as plan §9
  lists their steps: the swipe opened with a **partial**
  `press(forDuration:thenDragTo:)` across ~40 % of the row, never
  `swipeRight()` (which fires the edge action — `014` T009's finding); the
  price read with grouping separators stripped; the middle button matched on
  `"Mark as bought\u{2026}"` **alone**, never `OR "Buy"` (the `014` close-out
  lesson — a hedge that lets the accessibility label silently stop working).
  Pattern: `testTheLeadingSwipeOffersMarkAsSoldBetweenEditAndCopyAndOpensTheSheet`
  and `element(in:identifiedBy:)`. Mutations (each reverted, recorded): the
  middle swipe button wired to `itemBeingEdited` → the price field absent →
  red; `.accessibilityLabel(PurchaseCopy.markAsBought)` removed → the button
  reads "Buy" → red; the Wishlist's bought filter dropped → the bought row is
  still listed → red. Then `scripts/verify.sh ui` **twice back to back**. If
  XCUITest cannot open the wishlist's leading actions with a partial drag,
  record it as a finding for T012 to instrument — do not drop the assertion.
  Files: `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green; `scripts/verify.sh ui` green twice,
  both counts in the Done note; mutations recorded. **Phase 2 closes here —
  pause for the person** (what can be tried is in the handoff note above).

## Phase 3 — Verification and close-out

- [ ] **T012 — Device pass. [general-purpose agent with simulator tools; person: VoiceOver]**
  Per plan §9 and every criterion, on the iPhone simulator with `-uiTesting
  -seedSellPlan`, and once more on the **persistent** store for the relaunch.
  **Instrument, don't eyeball**: a temporary file probe inside
  `WishlistPurchaseStore.markBought` exercised through all three hosts — Cancel
  0, swipe-down 0, a list re-render (background/foreground, appearance change)
  0, confirm 1 — removed before the suites run, and the file confirmed
  byte-identical to HEAD afterwards. **Film the two pops** (plan R2): buy from
  a Sell Plan screen and confirm it lands on the Wishlist without an
  intermediate frame showing the wanted item's detail as still wanted — if it
  steps, or lands anywhere else, that is a finding for a decision review, not
  an improvised fix. Walk: all three entry points opening the same sheet, each
  cancelling inert; the swipe's three buttons on **both appearances** (white on
  `accentBrassMid`, already measured 3.61:1 / 3.74:1 at `014` T010 — no new
  measurement owed) with Edit still on a full swipe; the swipe button's spoken
  name read from the accessibility tree ("Mark as bought…" if the modifier
  took, else "Buy" — record which, for T013); the comparison line appearing,
  changing and vanishing as the price is typed above and below the estimate,
  and absent when the entry has no estimate; a purchased item's page showing
  the **moved photo with its stock credit intact** (criterion 7) and the
  wishlist entry gone (criterion 8); the Dashboard's figures before and after
  one purchase (criterion 10); buying the last wanted item leaving today's
  wishlist empty state (criterion 11); **relaunch** on the persistent store and
  confirm the entry is still off the Wishlist and the item still in the
  collection (criterion 12); Settings' wanted-items count and the
  export-everything files read from the container, confirming a bought entry is
  in neither (criteria 13 and R1). Both suites twice. Findings fixed in place
  if routine and inside the footprint, else returned as a diagnosis for a
  decision review; each fix a sub-lettered task.
  **[person]** Accessibility Inspector (criterion 12's VoiceOver half): the
  swipe action, the detail menu's row, the Sell Plan's bar button, and the
  sheet's four fields and its comparison line; and, if they have two devices,
  that a purchase made on one leaves the entry off the Wishlist on the other.
  **Verify:** the record in the Done note with the probe's count per action per
  host, the filmed pop, the credit observation and the relaunch result;
  `scripts/verify.sh all` green twice.

- [ ] **T013 — Close-out.**
  Per plan §10. Criteria 1–15 ticked in `spec.md` with per-criterion citations
  — **criterion 14 ticked by inspection**, stating in the tick that no test can
  catch it being false without being the broad-scan shape `CLAUDE.md` names
  twice, and citing T012's probe as the observation; **criterion 15 ticked on
  `PurchaseUndoTests` plus the diff**, saying plainly that no test enumerates
  the bought item's menu and that the evidence is `ItemDetailView` and
  `ItemDetailView` being untouched and `DetailOverflowMenu` changed **only in
  its doc comment**, which adds no return path (the `014` criterion-2 lesson).
  Sign-off correction, 2026-09-19 (re-review N1): the citation first claimed
  both files were untouched, which this spec's own §8 refutes. **Verify the
  `006` pointer T009 appended is present** (`grep -c` over
  `specs/006-mark-as-sold/plan.md`, the `014` T001 shape); criterion 12 an honest partial until the person's
  Accessibility Inspector step, naming the spoken name T012 read. **Re-run
  G14's two mutations against the finished tree** (T003 wrote
  `PurchaseUndoTests` before the views existed, so its "exactly once across
  `Trove/`" claim is only proven over the whole spec here) and record them.
  Then: the Copy section's shapes replaced by
  the shipped strings (P-items → decisions); `plan.md` gains **As built** (what
  the plan got right, what it got wrong, R1 and R2 as confirmed or overturned,
  Q1–Q14 as shipped, and every deviation with its reason); `design/tokens.md`'s
  swipe-action table gains the wishlist's third leading action and its tint,
  plus a row for the purchase sheet; `README.md`'s wishlist bullet;
  `specs/ROADMAP.md`'s `015` entry and status row, its `009` entry (a completed
  plan now has a definition; the unreachable orphan a hand-corrected purchase
  leaves is `009`'s to surface or sweep), a follow-up line for the shared
  field chrome three sheets now copy (plan Q8), and a **`fix/` follow-up for a
  defect in already-merged code found while planning and deliberately not
  fixed here**: `WishlistViewModel.duplicate(id:)` rebuilds photos through
  `Photo(imageData:source:sortOrder:)`, which writes none of the three
  attribution fields, so duplicating a wanted item with a `005` stock photo
  loses its credit today — a licence-compliance defect outside every criterion
  in this spec, and `CLAUDE.md` gives a merged-code bug its own branch;
  `DECISIONS.md` (the marker as one optional date with no relationship and why;
  photos moved rather than copied, and why the duplicate path is the wrong
  shape here; Settings treating a bought entry as off the wishlist, R1; the
  unbounded purchase date, Q9; the sub-dollar floor and its consequence that a
  genuinely zero estimate reads as no estimate, Q7; **the `006` reversal** —
  the wishlist page now builds menu rows, `DetailOverflowMenu`'s doc comment
  corrected and `SoldStateWiringTests`' wishlist-page test rewritten rather
  than loosened; the Sell Plan's bar button and which spoken name shipped).
  Finally the pre-merge
  `skeptical-reviewer` sweep over `git diff main...HEAD` (bundle cut after
  `git add -A`, so untracked files are in it) and the PR marked ready for
  review.
  Files: `specs/015-mark-as-bought/spec.md`, `specs/015-mark-as-bought/plan.md`,
  this file, `design/tokens.md`, `README.md`, `specs/ROADMAP.md`,
  `DECISIONS.md`.
  **Verify:** everything above committed and pushed; `scripts/verify.sh all`
  green with the final counts recorded here (unit **and** UI lines both
  captured).

## Constitution changes since sign-off

`main` moved after these documents were signed off, and two commits bear on
them. The branch has `main` merged in as of 2026-09-19.

1. **`CLAUDE.md`'s Testing section gained a rule about source scans**
   (`5026305`): *a source scan may pin an injection point that nothing else
   can reach, and never a behavior a view-model test could reach instead.*
   It binds work from that commit, which is **after** this plan's guards were
   reviewed — so the first task that writes one should check it against the
   rule rather than assume the sign-off covered it. A first read says the
   planned scans survive, because each pins a fact about a **view body** that
   no view-model test can observe: G14 (the marker assigned exactly once, so
   no undo path exists), G15 (the swipe's button order), G17 (the menu row),
   G18 (the toolbar gate). None of them asserts a view model's behaviour.
   G18 is the one to look at hardest — the re-review already flagged that its
   scan pins an exact spelling — and if any guard turns out to assert
   something the view-model suite reaches, it goes to the phase review as a
   finding rather than being written and left.

2. **Two helpers moved** (`578b535`, PR #28), both in files this plan cites
   as patterns. `parsedYear` is now `FieldNormalization.parsedYear(_:maximum:)`
   and the form-save canonicalization is now
   `CategoryPathHelper.canonicalOrTyped(_:in:)`; the four private forwarding
   statics in `ItemFormViewModel` and `WishlistFormViewModel` are gone, and
   their call sites name `FieldNormalization` directly. Plan §3's
   `Item(...)`-plus-`sortOrder` sequence is unaffected, but anything copying
   the forms' *shape* should copy the current one.

## Tier log

`CLAUDE.md`'s model policy **as amended 2026-09-19**: every role runs at
`opus` — the `sdd-planner`, the `skeptical-reviewer` (plan/tasks sign-off,
per-phase, per-task and decision reviews, and the pre-merge sweep), the
`sdd-implementer`, and the `general-purpose` agent that drives the simulator —
which is each definition's own default, so **no dispatch carries a model
override**. The orchestrating session runs `claude-opus-5` at medium. Every
Tier entry below is the resolved name, never "default." Token usage from each
subagent return is filled in as the spec runs; escape-hatch misses (a task the
orchestrator had to redo, and why) are recorded here too.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| Spec session (this spec's `spec.md`, drafting and approval) | `opus` (raised to high for the spec conversation) | orchestrating seat, not measured separately | Draft 2026-09-19, approved the same day with Decisions 5–7 |
| `sdd-planner` — plan.md and tasks.md (draft, then the sign-off fix pass) | `opus` | 305k (257k draft + 48k fix pass) | 13 tasks, 3 phases, 23 guards; no product question returned |
| `skeptical-reviewer` — plan/tasks sign-off | `opus` | 175k | 1 blocking (B1: T009 reddens a `006` guard), 8 non-blocking; 6 folded into the fix pass, S7/S8 recorded |
| `skeptical-reviewer` — sign-off re-review | `opus` | 100k | B1 and S1–S6 confirmed resolved; **2 new blocking findings introduced by the fix pass** (N1, N2 — both stale "untouched" claims about `DetailOverflowMenu`). Loop cap reached, so the orchestrator fixed both directly and logged them, per `CLAUDE.md` |
| Orchestrator — post-re-review corrections | `opus` (session, medium) | n/a | N1, N2, plus four second-look items the re-review named: the "exactly one `Row`" phrasing (would redden on correct code), G18's gate spelling, the convenience initializer's fate, and Q10's factually-wrong rationale |
| `sdd-implementer` — T001 (the marker and the CloudKit mutation) | `opus` | 46k | Done first pass; both mutations red as planned; found a second CloudKit guard (`TwoStoreContainerTests`) |
| `sdd-implementer` — T002 (`Purchase`, `PurchaseCopy`, the comparison line) | `opus` | 53k | Done first pass; 3 mutations red; two small deviations logged in the Done note |
| `sdd-implementer` — T003 (`WishlistPurchaseStore`, the one writer) | `opus` | 115k | Done first pass; 11 mutations; found a false-passing fixture itself (`desireToOwn`) and fixed it |
| `skeptical-reviewer` — T003 per-task review | `opus` | 86k | **1 blocking** (the `currencyCode` leg could not fail — the same shape the implementer had just fixed once), 5 non-blocking |
| `sdd-implementer` — T003 review fix | `opus` (same agent resumed) | 20k more | Blocking fixed and mutation-verified; whole diff audited for the shape, nothing else found; 2 non-blocking applied |
| `skeptical-reviewer` — T003 re-review | `opus` (same agent resumed) | 4k more | Signed off; nothing blocking; 3 non-blocking carried to the sweep and T013 |
| `sdd-implementer` — T004 (the exclusion rule at five read sites) | `opus` | 122k | Done first pass; 6 mutations; returned a finding that plan Q11's rationale is factually wrong |
| `skeptical-reviewer` — T004 per-task review | `opus` | 90k | **No blocking findings**; 7 second-look, incl. a second false-passing shape (an assertion message claiming more than it can detect) and a missing sixth reader |
| `sdd-implementer` — T004 second-look fixes | `opus` (same agent resumed) | 39k more | 4 applied, 2 new mutations; the `marketSummaries` leg turned out reachable after all (a cross-device purchase) |
| `sdd-implementer` — T005 (`PurchaseFormViewModel`) | `opus` | 54k | Done first pass; 2 mutations; falsifiability walk found one assertion that cannot fail and said so instead of hiding it |
| `sdd-implementer` — T006 (the three hosts' intents) | `opus` | 141k | Done first pass; **14 mutations**; deleted 3 unfalsifiable legs and fixed a fixture coincidence itself |
| `skeptical-reviewer` — Phase 1 review | `opus` | 140k | **1 blocking** (B1: `markBought` not idempotent — only visible at phase level), 7 second-look |
| `sdd-implementer` — T006a (B1 + five second-look) | `opus` (same agent resumed) | 45k more | B1 fixed in the one writer; 12-leg mutation; caught a clock coincidence in its own new test |
| `skeptical-reviewer` — Phase 1 re-review | `opus` (same agent resumed) | 16k more | Signed off; nothing blocking; found a mis-spliced doc comment (orchestrator fixed) and one device-pass residual |
| `sdd-implementer` — T007 (the purchase sheet) + the unbounded-date guard | `opus` | 107k | Done first pass; 7 mutations; caught a substring false-pass in its own leg before landing it, and found the same shape in merged code |
| `sdd-implementer` — T008 (the Buy swipe, the sheet on the list, the `ActionBuy` glyph) | `opus` | 104k | Done first pass; 6 mutations (2 beyond the task line, to back its own added legs); the imageset needed no project edit |
| `sdd-implementer` — T009 (the menu row, the `006` reversal, the rewritten guard) | `opus` | 115k | Done first pass; 8 mutations; **demonstrated the `.init(` dodge** by running the old guard beside the new one; found the `#Preview`-in-a-comment scan landmine |
| _rows added per dispatch as the spec runs_ | | | |

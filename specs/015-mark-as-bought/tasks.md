# 015 — Mark as Bought: Tasks

**Status**: Draft — pending sign-off

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
not an omission. **Two things the spec did not say, which the person decides at
that pause**: a bought entry is not counted in Settings' wanted-items number,
is not in the export-everything wishlist file, and is **not** removed by
"Delete all wanted items" (plan R1); and buying from a Sell Plan screen takes
the person back to the Wishlist, two screens up (plan R2). The report puts both
as questions, not facts.

## Phase 1 — Foundations: the marker, the writer, the rule (**foundational**)

- [ ] **T001 — `WishlistItem.boughtDate`, `isBought`, and the CloudKit claim.**
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

- [ ] **T002 — `Purchase` and `PurchaseCopy`.**
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

- [ ] **T003 — `WishlistPurchaseStore.markBought` — the one writer. `review: per-task`.**
  Per plan §3, Q4, Q5, Q6 and Q12. New
  `Trove/Models/WishlistPurchaseStore.swift`, exactly the body plan §3 gives:
  `MarketLocalStore.clear(subjectID:)` **first**; the `Item` built with the
  eleven carried/entered fields and `sortOrder` from
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
  writers, nothing else (mutations: add `wanted.boughtDate = nil` to any view
  model → red naming the file; move the write into `WishlistViewModel` → the
  location leg red; both reverted).
  Also confirm `PhotoOwnershipTests` stays green with no edit — and if its
  invariant has no case over a moved photo, add one there rather than here.
  Files: `Trove/Models/WishlistPurchaseStore.swift` (new),
  `TroveTests/WishlistPurchaseStoreTests.swift` (new),
  `TroveTests/PurchaseUndoTests.swift` (new),
  `TroveTests/PhotoOwnershipTests.swift`.
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded; the new suite in the count.

- [ ] **T004 — What leaves the Wishlist: the exclusion rule at five read sites. `review: per-task`.**
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

- [ ] **T005 — `PurchaseFormViewModel`.**
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

- [ ] **T006 — The three hosts' intents.**
  Per plan §6 and Q10. On `WishlistViewModel`, `WishlistDetailViewModel` and
  `SellPlanViewModel`: `makePurchaseFormViewModel(for:)` (the detail's and the
  plan's take no argument — their subject is the entry they hold) and
  `markBought` → `WishlistPurchaseStore.markBought(…, at: now(), in:
  modelContext)`, one `save()`, on refusal `rollback()` then `load()` then the
  failure message **in that order** (`load()` clears the message first — the
  ordering `WishlistViewModel.delete` already has right and `014`'s T005 got
  backwards), returning the outcome. `WishlistDetailViewModel` also gains
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
  **Phase 1 closes here — pause for the person** (nothing to try yet; the pause
  is the review gate — the report may offer to run straight on).

## Phase 2 — Screens

- [ ] **T007 — The purchase sheet.**
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

- [ ] **T008 — The Wishlist row's Buy swipe, the sheet on the list, the `ActionBuy` icon.**
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

- [ ] **T009 — The wishlist detail's menu row, its sheet, and dismiss-on-bought.**
  Per plan §8 and **R2**. In `WishlistDetailView`: the `DetailOverflowMenu`
  call moves to the `(noun:edit:middle:delete:)` initializer with `middle =
  Row(title: PurchaseCopy.markAsBought, systemImage: "bag", action: {
  isMarkingBought = true })`; `@State private var isMarkingBought = false` and
  a `.sheet(isPresented:)` over `PurchaseFormView`, confirming through
  `viewModel.markBought(purchase:)` and `dismiss()`ing on true; `.onAppear`
  becomes `viewModel.load()` then `if viewModel.hasBeenBought { dismiss() }`.
  **No button anywhere in `content(for:)`** (criterion 2, spec P1). Pattern:
  `ItemDetailView.overflowMenu` and its `markAsSoldRow`. Tests
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
  `TroveTests/WishlistPurchaseWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T010 — The Sell Plan's action, its sheet, and its dismiss.**
  Per plan §8 and **R2**. In `SellPlanView`: a
  `.toolbar { ToolbarItem(placement: .topBarTrailing) { … } }` holding a
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
  `PurchaseCopy.markAsBought`, exactly one
  `.sheet(isPresented: $isMarkingBought` over `PurchaseFormView(`, the confirm
  closure naming both `markBought` and `dismiss`, and the file naming no
  `WishlistPurchaseStore` (mutations: drop the `dismiss()` → red; host the
  sheet twice → red). The existing `SellPlanWiringTests` and
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
  `DetailOverflowMenu` being untouched in this spec's diff (the `014`
  criterion-2 lesson); criterion 12 an honest partial until the person's
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
  leaves is `009`'s to surface or sweep), and a follow-up line for the shared
  field chrome three sheets now copy (plan Q8); `DECISIONS.md` (the marker as
  one optional date with no relationship and why; photos moved rather than
  copied, and why the duplicate path is the wrong shape here; Settings treating
  a bought entry as off the wishlist, R1; the unbounded purchase date, Q9; the
  Sell Plan's bar button and which spoken name shipped). Finally the pre-merge
  `skeptical-reviewer` sweep over `git diff main...HEAD` (bundle cut after
  `git add -A`, so untracked files are in it) and the PR marked ready for
  review.
  Files: `specs/015-mark-as-bought/spec.md`, `specs/015-mark-as-bought/plan.md`,
  this file, `design/tokens.md`, `README.md`, `specs/ROADMAP.md`,
  `DECISIONS.md`.
  **Verify:** everything above committed and pushed; `scripts/verify.sh all`
  green with the final counts recorded here (unit **and** UI lines both
  captured).

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
| `sdd-planner` — plan.md and tasks.md | `opus` | | |
| `skeptical-reviewer` — plan/tasks sign-off and re-review | `opus` | | |
| _rows added per dispatch as the spec runs_ | | | |

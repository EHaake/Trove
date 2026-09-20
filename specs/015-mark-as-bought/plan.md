# 015 — Mark as Bought — Technical Plan

**Status**: **Final** (2026-09-19) — the person approved the
spec-conformance summary the same day, which is the product-owner gate per
`CLAUDE.md`'s involvement level. Implementation may start.

Signed off (2026-09-19) by the `skeptical-reviewer`. Sign-off
raised one blocking finding, fixed and re-reviewed; the re-review raised two
more (N1, N2 — stale "untouched" claims about `DetailOverflowMenu` that this
spec's own §8 refutes), which the orchestrator fixed directly under the
review loop cap. Each correction is marked in place.

Drafted by the `sdd-planner` (Opus 5, high effort — per `CLAUDE.md`'s model
policy as amended 2026-09-19, where every role runs at `opus` and no dispatch
carries a model override) against the approved `spec.md` (Approved 2026-09-19)
and the code as it stands on the `015-mark-as-bought` branch at `cb1d3a1`.
Planning proposals (Q1–Q14) become decisions on plan approval, the way `014`'s
Q-items and `006`'s did. Two readings the plan had to take a side on are under
**Readings for sign-off**; neither is a product fork, each is stated so the
reviewer can overturn it and each goes to the person in plain words at the
Phase 2 pause.

## Context

Spec 015 adds **Mark as bought…** from three hosts — the Wishlist row's
leading swipe, the wishlist detail screen's menu, and the Sell Plan screen —
each opening **one purchase sheet**; confirming creates an `Item` carrying
everything the wishlist entry knew, marks the entry **bought** so it leaves the
Wishlist without being deleted, and releases the unsold candidates from its
plan while keeping what was sold toward it. Decisions 1–7 and P1–P7 settle the
behaviour; this plan settles the technical shape.

The footprint: **one new synced field** (`WishlistItem.boughtDate`), **five new
production files** (`Purchase`, `PurchaseCopy`, `WishlistPurchaseStore`,
`PurchaseFormViewModel`, `PurchaseFormView`), the three wishlist hosts and
their view models, and **five** existing read sites that must now skip a bought
entry (`WishlistViewModel.load`, `SettingsViewModel` ×3,
`MarketRefresher.targets`). One shared component is touched, in its doc
comment only: `DetailOverflowMenu` (§8, §9). No new export column, no import change, no new
service, no network call, no `.pbxproj` edit (the one new asset is an imageset
inside the existing catalogue, §8). No constitution amendment.

No rule in an earlier spec's `spec.md` is reversed here. **One `006`
`plan.md` statement is, and it takes a pointer** — sign-off correction,
2026-09-19 (re-review N2): the first draft of this section said there were no
"Superseded by" pointers to append, which is wrong under this project's own
convention. `specs/006-mark-as-sold/plan.md:559-561` states that the
two-argument initializer is kept "so `WishlistDetailView` is untouched", and
`015` makes that false. `014` established the treatment at exactly this kind
of plan-level statement — append the pointer in place rather than editing the
shipped claim away (`014/plan.md:704-711`, which also appended to a guard-table
row whose meaning had changed, with a `grep -c` verify in its T001). T009
appends it; T013 verifies it is there. **One `006` implementation decision is**
reversed,
deliberately and in one place: `006` left the wishlist page on
`DetailOverflowMenu`'s two-argument initializer, wrote that into the
component's doc comment ("which is what the wishlist's page asks for — it is
untouched by this spec"), and pinned it from the caller's side with
`SoldStateWiringTests.theWishlistPageKeepsTheOriginalMenuAndNamesNoSaleCopy`.
Criterion 2 puts **Mark as bought…** in that menu, so the comment is corrected
and the guard is **rewritten to pin the new rule, never loosened** (§8, G17) —
the same treatment `014` Q12 gave every test whose meaning it changed.
`ROADMAP.md`'s `009-sell-plan-list` entry gains one line as well (§10):
"active" now has a definition, and the orphan a hand-corrected purchase leaves
behind is `009`'s to surface or sweep, as this spec's Non-goals record.

## Readings for sign-off (not open questions — the plan builds to each)

- **R1 — Settings treats a bought entry as off the wishlist, in all three of
  its wishlist surfaces.** `SettingsViewModel` reads `WishlistItem` three
  times: `wishlistCount` (which feeds `canExportEverything`,
  `canDeleteWishlist` and the delete confirmation's count),
  `everythingInCustomOrder`'s `wanted` (the export-everything CSV and PDF), and
  `confirmDeleteAll(.wishlist)`'s walk. Criterion 13 settles the middle one — a
  bought entry exports in neither format. The other two the spec does not
  mention, and the plan takes them the same way: **a bought entry is not on the
  wishlist, so it is not counted and Delete all wanted items does not delete
  it.** Counting it would put a number in a destructive alert that disagrees
  with the list the person just looked at; deleting it would destroy the
  completed sell plan Decision 3 exists to keep, on a gesture whose count never
  mentioned it. The accepted cost is that a bought entry survives a wishlist
  wipe as an unreachable row — which is the consequence the spec's Non-goals
  already accept for a purchase corrected by hand, and which `009` is named
  there as the place to address. Guards G10, G11. **The spec did not say this**,
  so the person hears it at the Phase 2 pause and can overturn it: the reversal
  is two predicates and their tests.
- **R2 — a screen already pushed onto a bought entry gets itself out of the
  way.** Criterion 8 says the entry "appears nowhere else in the app", and the
  entry's own detail screen and Sell Plan screen are both *already on the
  navigation stack* when a purchase is confirmed from the deeper of the two. So:
  confirming on the **Sell Plan** dismisses it, and `WishlistDetailView`
  dismisses itself on `.onAppear` when the entry it holds reads bought (§6,
  §8) — two pops in sequence, landing on the Wishlist, which no longer lists
  it. Without this the detail screen behind the Sell Plan would keep offering
  **Mark as bought…** for an entry already bought, and a second tap would
  create a second item. **Scope, corrected at the Phase 1 review**:
  `.onAppear` covers a screen the person *navigates back to*, which is the
  in-session case above. It does not fire when the entry changes underneath a
  screen that is already in the foreground — the cross-device case criterion
  12 makes real. That window is closed in the one writer instead (§3, T006a),
  which is where it should have been from the start, since no view-side
  mechanism can cover every host. The alternative — showing the existing "This item is
  gone" state — was rejected: its detail line ("It was removed somewhere
  else.") would be false, and rewording it is a copy change this spec has no
  mandate for. The double pop is a thing only the device can show; T012
  instruments it (§9). Guards G18, G19.
  **Added at the Phase 1 re-review**: T006a's guard reads `wanted.isBought`
  off the object the host holds, so on a device it depends on CloudKit's
  merge having reached that context before the tap. The unit test proves the
  guard, not that the marker is visible in time — so **T012 exercises the
  cross-device window deliberately** (a relaunch mid-screen, or two
  simulators), per `CLAUDE.md`'s instrument-the-mechanism rule.

  **As built, measured at T012's device pass (2026-09-20).** Both pops fire,
  in order: `sellPlan.dismiss` at +52 ms from confirm,
  `detail.onAppear hasBeenBought=true` at +61 ms, `detail.dismiss` in the
  same frame. The logic spans 61 ms; the **animations do not overlap**. The
  detail screen's dismissal cannot be *requested* until `.onAppear` fires,
  and `.onAppear` fires as the screen comes on — so SwiftUI plays the two
  pops in sequence and the wanted item's detail page is drawn fully on
  screen, unobscured and static, for **270–330 ms** (visible in some form
  ~460 ms) before sliding off. Note the diagnosis does not blame the
  platform: the serialisation is entailed by the trigger's design, not by a
  `NavigationStack` defect, and it was established by a probe on the
  mechanism rather than by a visual proxy for it.
  **This is accepted for `015`** — decision review, 2026-09-20, recommending
  (a) over suppressing the intermediate animation or popping to root.
  Criterion 8 is about surfaces and copies — no Bought side, no Bought card,
  no second copy in a list — and a screen unwinding is not a surface; R2
  already specified the intermediate screen, so what the device pass found is
  the *duration* of an anticipated transition, not an unanticipated one.
  Criterion 8 is met; the polish bar is dented by ~300 ms on one of three
  paths. The two alternatives are both worse than they look: suppressing the
  second pop's animation removes the slide-off nobody is complaining about
  and leaves a jump cut mid-movement, and popping to root is **not available
  cheaply** — the Wishlist tab is `NavigationStack { WishlistView(…) }` with
  **no path binding**, unlike Items' `$router.itemsPath`, so there is no root
  path to clear. Both would also rewrite **G18**, whose `dismiss()` leg is
  deliberately scoped inside the `markBought` branch — a source-text guard
  re-spelled at close-out, weeks after the constitution's amendment about
  exactly that shape. And decisively: **nothing chosen here could be guarded
  by a test** — this plan says so itself, "the double pop is a thing only the
  device can show." Deferred to `ROADMAP.md` with the fix direction named, so
  the next spec inherits the analysis rather than repeating it.

## Proposed at planning (Q1–Q14) — approved on plan approval unless overturned

- **Q1. The marker is one optional `Date`, and nothing else.**
  `WishlistItem.boughtDate: Date?` — declared exactly as `Item.soldDate` is,
  with **no `= nil` initializer** (the scan in Q13 counts assignments, and a
  defaulted declaration would be one). `var isBought: Bool { boughtDate != nil }`
  is the one predicate, as `Item.isSold` is; `#Predicate`s spell
  `boughtDate == nil` themselves, since a predicate can only see the stored
  property. **No relationship to the item the purchase created**: nothing in
  this spec reads one, Decision 2 is about not asserting links the app cannot
  stand behind, and an optional relationship is CloudKit-additive, so `009` can
  add one without a migration if it turns out to want one. No purchase price or
  date on the entry either — those live on the `Item`, which is the record of
  the purchase.
- **Q2. `Purchase`, beside `Sale`, in its own file.** `nonisolated struct
  Purchase: Sendable, Equatable { date, priceCents, location: String?,
  condition: Condition }` in `Trove/Models/Purchase.swift`, the shape
  `Sale` has in `Trove/Models/Sale.swift`. No `Item.purchase` accessor pair:
  unlike a sale, these four fields are not a nullable group on an existing row
  — they are three columns an `Item` always has plus its condition, so there is
  no "a date without a price is not a purchase" hazard for an accessor to hide.
- **Q3. `PurchaseCopy` is this spec's string table.** `Trove/Models/PurchaseCopy.swift`,
  `SaleCopy`'s shape and rules (no SwiftUI, no colour, pinned whole by
  `PurchaseCopyTests`): `markAsBought` (`"Mark as bought\u{2026}"`),
  `swipeBuy` (`"Buy"`), `sheetTitle`, `confirm`, `cancel`, `purchasePriceLabel`,
  `purchaseDateLabel`, `boughtFromLabel`, `boughtFromPlaceholder`,
  `conditionLabel`, and `comparison(paidCents:estimatedCostCents:) -> String?`
  (Q7). Its own table rather than rows added to `SaleCopy`: the spec's
  non-goals forbid changing `006`'s fields, and one of the two should be
  rewordable without opening the other.
- **Q4. `WishlistPurchaseStore` is the one writer of a purchase**, the shape
  and the contract `ItemSaleStore` holds for a sale (006 plan Q3): one `enum`
  in `Trove/Models/`, **callers save**, so the item, the marker and the local
  market clear commit in one `save()` and a refused save leaves none of them.

  ```swift
  enum WishlistPurchaseStore {
      /// The purchase: a new owned item carrying everything the wanted entry
      /// knew, its photos moved across, the entry marked bought, its unsold
      /// candidates released and its sold-toward history kept.
      /// Throws only from the market clear, which runs first, so a failure
      /// there leaves nothing written. The caller saves.
      @discardableResult
      static func markBought(
          _ wanted: WishlistItem, purchase: Purchase, at now: Date, in context: ModelContext
      ) throws -> Item
  }
  ```

  Three hosts call it through their own view models; no view ever names it
  (the rule `SaleFormWiringTests` and `SellPlanWiringTests` already hold the
  sale's writer to, and which G15/G17/G18 extend here).
- **Q5. What the new item carries, and what it does not** (spec P3–P5,
  criterion 7). Carried: `name`, `categoryPath`, `notes`, `currencyCode`,
  `reverbProductID`, `year`, and the photos themselves (Q6). From the sheet:
  `purchasePriceCents`, `purchaseDate`, `purchaseLocation`, `condition`.
  Derived: `currentValueCents = purchasePriceCents` (P4), `sortOrder =
  ManualOrderHelper.nextPosition(after:)` over every existing `Item` (the item
  form's own rule — max + 1, never a count). Left at the `Item` initializer's
  defaults: `desireToKeep` 3 (P5 — the wishlist's three-level *wanting* scale
  is not the item's five-level *keeping* scale), `serialNumber`,
  `conditionNotes` nil, `createdAt`/`updatedAt` `now`. Not carried:
  `desireToOwn`, `estimatedCostCents`, `sortOrder`, and no funding link
  (Decision 2 — `soldTowardWishlistItem` stays a thing only a sale writes).
- **Q6. Photos move by rewriting the child's two parent links, one photo at a
  time.** `Photo` carries `item` and `wishlistItem` as two independently
  optional relationships and the invariant "at most one of the two" is held by
  every writer only ever writing its own side (`PhotoOwnershipTests`). The
  purchase is the one place a photo changes parent, so it writes both:
  `photo.wishlistItem = nil; photo.item = item` per photo, in display order
  (`PhotoSelection.inDisplayOrder`) with `sortOrder` renumbered from zero, and
  the two to-many sides follow through the declared inverses. **Nothing is
  constructed and nothing is deleted** — deliberately *not*
  `WishlistViewModel.duplicate(id:)`'s shape, which builds new `Photo` rows and
  in doing so drops `attributionAuthor`, `attributionLicense` and
  `attributionSourceURL`, i.e. exactly the `005` credit criterion 7 requires to
  survive. G6 is the guard, and the row count in the store is one of its legs:
  copying doubles it, losing one lowers it.
- **Q7. The comparison line is a `PurchaseCopy` function, and it is silent
  below a dollar.** `comparison(paidCents:estimatedCostCents:) -> String?`
  returns nil when the estimate is 0 (there is no estimate — `estimatedCostCents`
  is a non-optional `Int` whose 0 means "none", as the pre-fill already reads
  it) and nil when `abs(paid - estimate) < 100`; otherwise
  `"\(magnitude) less than you estimated"` / `"… more than you estimated"` with
  `magnitude = abs(delta).formattedAsWholeCurrency(currencyCode: "USD")`. The
  sub-dollar floor is not in the spec and is the plan's: every money figure in
  the app draws whole dollars, so a 40-cent difference would otherwise render
  "$0 more than you estimated", which is worse than the silence the spec asks
  for at equality. It is a departure from criterion 6's literal "when they
  differ", so the person hears it at the Phase 2 pause. One consequence to
  record rather than solve, and a `DECISIONS.md` line at plan approval: because
  `estimatedCostCents` is a non-optional `Int`, "no estimate" and "an estimate
  of exactly $0" are the same value here, while every other surface renders the
  latter as "$0" — so a genuinely zero estimate gets no pre-fill and no
  comparison line. Making the two distinguishable would mean an optional field
  and a migration for a case no criterion mentions. Guard G4.
- **Q8. The purchase sheet is a twin file, not a mode on `SaleFormView`.** The
  fields differ (Condition instead of Note, and a comparison line under the
  price), and the spec's non-goals forbid changing the sale sheet. So
  `PurchaseFormView` copies `SaleFormView`'s chrome — which `SaleFormView`
  itself copied from `ItemFormView`, the house precedent for exactly this — and
  the condition row is `ItemFormView.conditionChip`'s `FlowLayout` of capsules,
  copied the same way. A shared field-chrome component is a follow-up for
  `ROADMAP.md`, not this spec's business (§10).
- **Q9. The purchase date is unbounded — a stated divergence from the sale
  sheet's twin-ness.** `SaleFormView` bounds its picker at `now()` and
  `SaleFormViewModel` rejects a future date (006 P2). The purchase sheet does
  neither, because the field it fills is `Item.purchaseDate`, whose own editor
  — `ItemFormView`'s "Date bought" — takes any date at all; a sheet that
  refuses what the Edit screen accepts is one rule with two answers, and the
  person meets both. So `PurchaseFormViewModel` has two validation errors,
  `priceMissing` and `priceNegative`, and no date case. The reversal, if the
  reviewer prefers the twin: one `in: ...viewModel.latestDate` and one
  validation case, plus their tests.
- **Q10. Three hosts, one seed, one intent pair.** Each of `WishlistViewModel`,
  `WishlistDetailViewModel` and `SellPlanViewModel` gains
  `makePurchaseFormViewModel(for:)` — price from `estimatedCostCents` when it
  is non-zero and **nil otherwise** (never a pre-filled 0, the `006` P1 rule:
  a pre-filled zero cannot be typed over, the digits append) — and
  `@discardableResult func markBought(_:purchase:) -> Bool`, which calls the
  store and saves once. **The failure property and the ordering differ per
  host, because the three hosts differ** — spell them out rather than copying
  one shape three times: `WishlistViewModel` sets `loadFailureMessage`
  **after** `rollback()` and `load()`, because its `load()` opens by clearing
  that property (the ordering `WishlistViewModel.delete` already has right and
  the one `014`'s T005 got backwards); `SellPlanViewModel` sets its existing
  `saveFailureMessage`, which `load()` does not clear, in the order its own
  `markSold` uses (`rollback()`, message, `load()`) so the two intents on one
  screen read alike; `WishlistDetailViewModel` gets a **new**
  `purchaseFailureMessage` rather than reusing `deleteFailureMessage`, set
  after `rollback()` (its `load()` does not clear *that* property).
  **Corrected at the Phase 1 review**: this said "its `load()` clears
  nothing", which is false of both hosts — `SellPlanViewModel.load()` opens by
  clearing `loadFailureMessage`. The true and narrower statement, which is the
  one the ordering rests on, is that neither `load()` clears the property the
  purchase reports into. The reason is structural,
  not naming — sign-off correction, 2026-09-19 (re-review): the first draft
  said `deleteFailureMessage` "is read by a different call site", which is
  false, since nothing under `Trove/Views` reads it or `saveFailureMessage`
  at all. The real reason is that `WishlistDetailViewModel.delete()` clears
  `deleteFailureMessage` on entry (`:66`), so sharing it would let an
  unrelated delete attempt wipe a purchase refusal. Note the consequence
  while it is in view: nothing surfaces `purchaseFailureMessage` on screen
  either, so a refused purchase is silent on that page — consistent with the
  two existing properties, and recorded here rather than discovered later. `SellPlanViewModel`'s takes no
  argument beyond the
  purchase: its subject is the plan's own `wishlistItem`. G12 pins the three
  seeds equal, G13 the three refusal paths.
- **Q11. The Wishlist's fetch splits, it does not filter.** `WishlistViewModel.load()`
  fetches every `WishlistItem` as it does today and then takes
  `let wanted = all.filter { !$0.isBought }` — the `ItemListViewModel` owned/sold
  split's shape — with `totalCount`, `items`, `categoryOptions`,
  `categoryLabels` and `marketSummaries` all derived from `wanted`, never from
  `all`. `totalCount` matters as much as `items`.
  **Corrected at T004, in the code this paragraph directed**: the reason given
  here was wrong. `ListEmptyReason.reason` falls through to `.nothingAdded`
  whenever nothing is narrowing the list, so a stale `totalCount` alone does
  *not* produce a filter's empty state — that hazard needs a chip or a query
  still set, which is the secondary case. The real, unqualified reason is that
  `WishlistView` gates the search field and the category chips (`:99`) and the
  header's sort control (`:287`) on `totalCount > 0`, so a stale count leaves
  those sitting over an empty list after the last entry is bought, filter or
  no filter. The requirement is unchanged; only its justification was. Found
  by the implementer, confirmed by the per-task review.
  **No new empty reason**: buying the last wanted item lands on today's
  `.nothingAdded` state, whose copy ("Nothing on the list yet" / "Keep track of
  what you're after…") reads correctly after a purchase — unlike the Items
  side, where `006` needed `.everythingSold` because "No gear yet" did not.
  Criterion 11 is that state, unchanged. G9.
- **Q12. The bought entry's device-local market rows are cleared at the
  purchase, and a bought entry is never a refresh target.** `MarketLocalStore.clear(subjectID:)`
  runs **first** inside `markBought`, the ordering `ItemSaleStore.markSold`
  uses and for its reason (a failure there leaves the item unwritten). The rows
  are not moved onto the new item: they are keyed by subject *and kind*, and a
  `.wanted` figure is a different query from an `.owned(condition:)` one — the
  new item is unmatched-for-figures until its first refresh, exactly as a
  hand-added matched item is. `MarketRefresher.targets` gains
  `&& $0.boughtDate == nil` to its wanted predicate, the mirror of the
  `soldDate == nil` that `006` Decision 7 put on the owned one, so an invisible
  entry costs no request and no place in Settings' matched count. Neither
  change opens a connection or adds a service (criterion 14). G8, G11.
- **Q13. Criterion 15 is guarded by the marker's one writer, not by a search
  for the word "undo".** `PurchaseUndoTests` walks every production file under
  `Trove/`, requires that `boughtDate` is assigned exactly once across all of
  them, requires that the one assignment is inside
  `Trove/Models/WishlistPurchaseStore.swift`, and asserts that no file assigns
  it `nil` (or `.none`). **The match must exclude comparisons**: §4 adds four
  `boughtDate == nil` sites, so a naive `boughtDate\s*=` counts five and the
  guard reddens at T004 having recorded its mutations as green at T003. The
  pattern is `boughtDate\s*=(?!=)` (Swift's `Regex` has no lookbehind but does
  have lookahead), and one of T003's recorded mutations is a `boughtDate == nil`
  comparison added to a view model, confirming the guard stays **green** on
  it — a guard that cannot tell a write from a read is not guarding writes.
  Adding any path that clears the marker turns it red;
  moving the write into a view model turns it red. What it deliberately does
  **not** do is scan for nouns — the vacuous shape `CLAUDE.md` names twice. Its
  limit is stated honestly at close-out: it guards the marker, and the other
  half of criterion 15 (the bought item's menu offers nothing that returns it)
  is evidenced by the diff, which is the `014` criterion-2 lesson — cite the
  diff, do not claim a test enumerates it. State it precisely at close-out,
  because this spec's own §8 makes one of the two files a changed one:
  **`ItemDetailView` untouched, and `DetailOverflowMenu` changed only in its
  doc comment**, which adds no return path. Sign-off correction, 2026-09-19
  (re-review N1): the earlier wording claimed both files were untouched,
  which this spec's diff refutes. G14.
- **Q14. The swipe: "Buy" on the button, "Mark as bought…" to VoiceOver,
  `accentBrassMid`, a new `ActionBuy` template glyph, between Edit and Copy.**
  `014` settled every part of this shape on the Items list and it transfers
  whole: the existing first action stays nearest the edge so a full swipe still
  edits (spec criterion 1), the visible word is short because the action is
  ~76 pt wide, and the spoken name is the menu row's own so one action is
  announced one way from both places. `accentBrassMid` is the one brass that
  reads mid-tone in both appearances and measured 3.61:1 / 3.74:1 for white at
  `014`'s T010, so no new measurement is owed. Glyph: `design/icons/action-buy.svg`
  in `action-sell.svg`'s house style (24 viewBox, 1.5 stroke, `#000`, template,
  vector preserved) — a bag outline, the same sign the menu row wears as SF
  `bag`. G15, G16.

---

## Layout and files

New production files (each joins its target through the synchronized folder,
the `014` T009g/T010a precedent — **no `.pbxproj` edit anywhere in this spec**;
if the build cannot see a new file, stop and flag):

- `Trove/Models/Purchase.swift`, `Trove/Models/PurchaseCopy.swift`,
  `Trove/Models/WishlistPurchaseStore.swift`
- `Trove/ViewModels/PurchaseFormViewModel.swift`
- `Trove/Views/Wishlist/PurchaseFormView.swift`
- `Trove/Assets.xcassets/ActionBuy.imageset/` (`Contents.json` +
  `action-buy.svg`) and `design/icons/action-buy.svg`

Changed: `Trove/Models/WishlistItem.swift` (§1), `Trove/ViewModels/WishlistViewModel.swift`,
`WishlistDetailViewModel.swift`, `SellPlanViewModel.swift` (§6),
`SettingsViewModel.swift` (§4), `Trove/Market/MarketRefresher.swift` (§4),
`Trove/Views/Wishlist/WishlistView.swift`, `WishlistDetailView.swift`,
`SellPlanView.swift` (§8).

New test files: `TroveTests/PurchaseCopyTests.swift`,
`TroveTests/PurchaseFormViewModelTests.swift`,
`TroveTests/WishlistPurchaseStoreTests.swift`,
`TroveTests/WishlistPurchaseWiringTests.swift`,
`TroveTests/PurchaseUndoTests.swift`. Extended: `ModelTests`,
`CloudKitSchemaTests` (comment only), `WishlistViewModelTests`,
`WishlistDetailViewModelTests`, `SellPlanViewModelTests`,
`SettingsViewModelTests`, `MarketRefresherTests`, `PhotoOwnershipTests`,
`DashboardViewModelTests`, `SoldStateWiringTests` (§8 — the `006` guard this
spec rewrites), `TabIconTests`'s `ActionIconTests`, `TroveUITests`. Also
changed: `Trove/Views/Shared/DetailOverflowMenu.swift`, doc comment only (§8).
Docs at close-out: `spec.md`, this file, `design/tokens.md`, `README.md`,
`specs/ROADMAP.md`, `DECISIONS.md`.

---

## 1. The marker on `WishlistItem` (foundational)

```swift
/// 015: when this wanted item was bought, or nil while it is still wanted.
/// **The one bought predicate** — `boughtDate == nil` is "still wanted"
/// everywhere, in `#Predicate` and in memory alike, the way `Item.soldDate`
/// is the one sold predicate. Written only by `WishlistPurchaseStore`, and
/// never cleared: there is no undo (spec Decision 5, guarded by
/// `PurchaseUndoTests`).
var boughtDate: Date?
```

Plus `var isBought: Bool { boughtDate != nil }` in the same file. Nothing else
on the entry changes; `plannedSaleItems` and `itemsSoldToward` keep their
`.nullify` rules and their doc comments gain a sentence each about what a
purchase does to them (§3).

**The CloudKit claim and its test.** `WishlistItem` is in `TroveSchema.models`,
so `CloudKitSchemaTests.schemaMeetsCloudKitRequirements` builds a real
container over a CloudKit configuration including this field — the claim
"optional, no unique constraint, additive to an existing store" is already
carried by a test that can go red, and T001 proves it can by making the field
violate the rules (`@Attribute(.unique) var boughtDate: Date?`) and watching
that suite fail. That is the mutation, recorded; the test file itself needs no
change beyond a sentence in its doc comment naming this field as the second
thing it caught being asked of it. G1.

**Testable claims** (`ModelTests`): a fresh `WishlistItem` reads `isBought ==
false` and `boughtDate == nil`; setting a date makes `isBought` true (mutation:
`boughtDate == nil` in the predicate → red). Persistence is G2's, on a second
`ModelContext`.

## 2. `Purchase` and `PurchaseCopy`

Per Q2 and Q3. `PurchaseCopy.comparison(paidCents:estimatedCostCents:)` is the
only computed member; everything else is a literal. `PurchaseCopyTests` pins
every string whole and every comparison case (G3, G4).

## 3. `WishlistPurchaseStore` — the one writer

```swift
static func markBought(
    _ wanted: WishlistItem, purchase: Purchase, at now: Date, in context: ModelContext
) throws -> Item {
    // First, so a failure here leaves nothing written (ItemSaleStore's shape).
    try MarketLocalStore.clear(subjectID: wanted.id, in: context)

    let item = Item(
        name: wanted.name,
        categoryPath: wanted.categoryPath,
        purchasePriceCents: purchase.priceCents,
        purchaseDate: purchase.date,
        currencyCode: wanted.currencyCode,
        purchaseLocation: purchase.location,
        currentValueCents: purchase.priceCents,          // P4
        condition: purchase.condition,
        notes: wanted.notes,                             // Decision 7
        reverbProductID: wanted.reverbProductID,
        year: wanted.year
    )
    item.sortOrder = ManualOrderHelper.nextPosition(
        after: (try? context.fetch(FetchDescriptor<Item>())) ?? [])
    context.insert(item)

    // Moved, never copied (Q6): the credit on a 005 stock photo is three
    // stored strings on the row itself, and a rebuilt row loses them.
    for (position, photo) in PhotoSelection.inDisplayOrder(wanted.photos ?? []).enumerated() {
        photo.wishlistItem = nil
        photo.item = item
        photo.sortOrder = position
    }

    wanted.boughtDate = now
    // P6: nothing is earmarked toward a purchase that has happened. The
    // sales already recorded toward it (`itemsSoldToward`) are the record
    // Decision 3 keeps, and are deliberately untouched.
    wanted.plannedSaleItems = []
    return item
}
```

**Amended at the Phase 1 review, 2026-09-19 — the store refuses an entry it
has already bought.** As first written, `markBought` had no `isBought` check
and neither did any of the three hosts, so a second call inserted a **second
`Item`** and **re-stamped `boughtDate`, destroying the first purchase's
marker** — the duplicate criterion 8 forbids, with no undo to correct it
(Decision 5). Two windows reach it, and the first is the case R2 exists for:
`WishlistDetailView`'s `.onAppear` fires on push and on return from a pushed
screen, **not when the data changes underneath**, so a marker arriving from
another device (criterion 12 says it syncs) leaves the action live on a
foreground screen; and the Sell Plan deliberately does not reload on success
(§6), so its button stays live while the view dismisses. The guard belongs in
the one writer rather than in three views, so it closes both windows and every
future host at once, and it **throws** rather than asserting — a
`precondition` could only fail by trapping, which is the untestable shape
`CLAUDE.md` records from `002` T021. Logged as **T006a**.

`desireToKeep` is left at the initializer's 3 rather than passed, so P5 is
visible as an absence with a comment rather than as a value that looks chosen.
`Item.init` hard-sets `createdAt`/`updatedAt` to `.now`; `now` is the marker's
own stamp and the `at:` parameter exists so a test can pin it — the same
asymmetry `ItemSaleStore.markSold` carries.

**Testable claims** (`WishlistPurchaseStoreTests`, every persisted assertion
refetched on a **second `ModelContext`** over the same container): the item's
thirteen fields (G5) — the eleven passed to `Item.init` above (`name`,
`categoryPath`, `purchasePriceCents`, `purchaseDate`, `currencyCode`,
`purchaseLocation`, `currentValueCents`, `condition`, `notes`,
`reverbProductID`, `year`) plus the two the body settles afterwards,
`desireToKeep` (left at the default, P5) and `sortOrder` (past a gap); the
photos (G6); the plan (G7); the marker and the market rows (G2, G8). Each
mutation is in the task line.

## 4. What leaves the Wishlist

Five read sites, all five changing (Q11, Q12, R1):

| Site | Change | Why |
|---|---|---|
| `WishlistViewModel.load()` | split `all` into `wanted`; everything derives from `wanted` | the list, the count, the chips, the empty state |
| `SettingsViewModel.load()`'s `wishlistCount` | `fetchCount` takes `#Predicate { $0.boughtDate == nil }` | the delete alert's number, `canDeleteWishlist`, `canExportEverything` (R1) |
| `SettingsViewModel.everythingInCustomOrder()` | the `wanted` fetch takes the same predicate | criterion 13 — a bought entry exports in neither format |
| `SettingsViewModel.confirmDeleteAll(.wishlist)` | the walk takes the same predicate | R1 — the gesture deletes what the count promised |
| `MarketRefresher.targets(in:)` | `&& $0.boughtDate == nil` on the wanted predicate | Q12 — the mirror of `006`'s sold rule |

Unchanged, deliberately, each with a one-line comment saying so:
`WishlistDetailViewModel.load` and `SellPlanViewModel.load` (by id, and R2
keeps a bought entry off both screens); `WishlistViewModel.duplicate` and
`confirmImport` and `WishlistFormViewModel`'s `nextPosition` fetches (they
renumber or append over the whole table, which is what keeps positions dense);
`CategoryPathHelper.allCategoryPaths` (the category is real, and the new item
carries it anyway). **A sixth, added at T004's review**: `MarketRefresher.currentTarget(for:)`,
the by-id re-read after the network hop, which this list first missed. It is
left unchanged for the same reason its `.owned` branch already ignores
`soldDate` — an entry bought mid-walk costs at most one request for a row
that is already invisible and whose local rows were just cleared. So Q12's
flat sentence "a bought entry is never a refresh target" is true of
`targets(in:)` and not of a walk already under way. One consequence to state rather than fix: `WishlistViewModel.move`
renumbers the *visible* rows from zero, so a bought entry's stale `sortOrder`
can collide with a live one. `ManualOrderHelper.areInCustomOrder` breaks a
position tie by name and id, so the visible order stays fully determined, and
the bought entry is never in a list to be ordered against.

**Testable claims**: G9 (the Wishlist), G10 (Settings' three), G11 (the
refresher).

## 5. `PurchaseFormViewModel`

`SaleFormViewModel`'s shape, one mode, no SwiftUI import:

```swift
@Observable
final class PurchaseFormViewModel {
    enum ValidationError: Hashable { case priceMissing, priceNegative }   // Q9: no date case

    var price: Decimal?          // nil when the entry has no estimate — never a pre-filled 0
    var date: Date
    var location: String = ""
    var condition: Condition = .excellent          // Item's own default (spec: "the same value a new item defaults to")
    private(set) var validationErrors: Set<ValidationError> = []

    var title: String { PurchaseCopy.sheetTitle }
    var confirmLabel: String { PurchaseCopy.confirm }
    /// The spec's one line of copy under the price, or nothing (Q7).
    var comparisonLine: String? { PurchaseCopy.comparison(
        paidCents: price.map(Money.cents(from:)) ?? 0, estimatedCostCents: estimatedCostCents) }

    init(estimatedCostCents: Int, now: @escaping () -> Date = Date.init)
    /// Validates; nil with `validationErrors` set, else the purchase to record.
    func purchase() -> Purchase?
}
```

`location` is trimmed and blanked through `FieldNormalization.nilIfBlank`, as
the sale sheet does. The comparison line reads the *typed* price on every body
evaluation, so it tracks the field live; with the field blank it compares 0
against the estimate, which is a real "less than you estimated" reading and the
one the spec's under-case describes.

**Testable claims** (`PurchaseFormViewModelTests`, G4 and G20): the seed —
estimate 240000 → `price == 2400`, estimate 0 → `price == nil`, `date == now`,
`condition == .excellent`, `location == ""`; validation — blank price →
`.priceMissing` and `purchase() == nil`, negative → `.priceNegative`, zero →
valid (giving nothing for it is a purchase of $0), a future date → **valid**
(Q9, pinned so the divergence is deliberate rather than forgotten);
`purchase()` normalizes a whitespace-only location to nil; the comparison line's
five cases.

## 6. The three hosts' intents

Each view model gains the pair from Q10. `WishlistDetailViewModel` also gains

```swift
/// R2: a detail screen already pushed onto an entry that has since been
/// bought takes itself off the stack rather than offering to buy it again.
/// Set by `load()`; the view reads it in `.onAppear`.
private(set) var hasBeenBought = false
```

set from the fetched entry's `isBought`. `SellPlanViewModel.markBought(purchase:)`
acts on its own `wishlistItem` and needs no argument; its `load()` is not
re-run on success — the screen is dismissing.

**Testable claims**: G12 (`everyHostSeedsThePurchaseSheetIdentically`, the
`014` G17 test's shape over the three wishlist hosts, with and without an
estimate — mutation: `?? 0` in one seed → red); G13 (the refusal scan, per
method, the `aRefusedAdoptSaveReportsAndCloses` shape: exactly one
`modelContext.save()`, `rollback()` and the message inside the one `catch` and
nowhere else — mutation: drop `rollback()` → red); G19 (`hasBeenBought`);
and, on a second context, that a purchase made through each host leaves the
same item and the same marker (mutation: one host calling the store with a
different `now` or skipping the save → red). G22 belongs here too: criterion
10 says the Dashboard reflects the new item "exactly as it would an item added
any other way", which is a claim about *indistinguishability* — so the test
runs `DashboardViewModel` over a store where the item arrived by purchase and
over one where the same fields were typed in, and expects every figure equal
(mutation: the store leaving `currentValueCents` nil → the un-valued count
diverges → red).

## 7. The purchase sheet

`PurchaseFormView` — `SaleFormView`'s file structure, its `NavigationStack`,
its `[.medium, .large]` detents, its Cancel/confirm toolbar pair, its
`PlateSurface` field chrome and rust invalid border, its date button and
graphical popover (unbounded, Q9). Four fields in the spec's order:

1. **Purchase price** and **Purchase date** paired on one row, `priceAndDate`'s
   layout exactly (`$` prefix, decimal pad, `.accessibilityIdentifier("purchase.sheet.price")`).
2. The **comparison line** directly under that row when
   `viewModel.comparisonLine` is non-nil: ~~`.monoLabel(color: theme.colors.textQuiet)`~~
   **`.font(theme.typography.secondary)` + `.foregroundStyle(theme.colors.textQuiet)`**,
   no colour branch, no arrow, no figure treatment — the spec's "quiet,
   supporting text, not colour-coded as gain or loss". Identifier
   `"purchase.sheet.comparison"`.
   **Overturned by the person at the Phase 2 pause, 2026-09-20 (T011b).**
   `monoLabel` applies `.textCase(.uppercase)` and `monoLabelTracking`, so
   this plan's choice shipped the line as `$120 LESS THAN YOU ESTIMATED` —
   letterspaced all-caps in the identical treatment as the `PURCHASE PRICE`
   field label above it, reading as a third field label rather than as an
   observation. Faithful to this paragraph, and not what the spec's Design
   section asked for. The person chose sentence case on being shown the
   rendered string. `secondary` on `textQuiet` is the app's house pairing for
   quiet supporting prose (28 call sites; the closest analogues are
   `SellPlanMarketLines`' reason line and `PhotoPickerField`'s status line),
   and there is no shared modifier for it — `monoLabel` is the app's only
   text-treatment modifier. **Recorded for the sweep**: this line's treatment
   shipped pinned by nothing — the wiring guard covered presence, position,
   conditionality and no-accent, but not the styling — which is why the
   plan's choice reached the person rather than a test. Quiet supporting text
   elsewhere in the app has the same exposure.
3. **Bought from** — `labelledField` + `plainTextField`, the sale sheet's
   `soldAtField` with this spec's words.
4. **Condition** — `ItemFormView`'s label-plus-`FlowLayout`-of-capsules over
   `Condition.allCases`, copied (Q8). Each chip keeps
   `.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)`,
   which is how a UI test and VoiceOver both read the selection.

**No Note field** (the spec's four fields are the whole sheet) and no currency
picker (`001`'s USD-only rule). Every word comes from `PurchaseCopy`.

**Testable claims** (`WishlistPurchaseWiringTests`, G21): the file composes, in
ascending source order, `PurchaseCopy.purchasePriceLabel`,
`PurchaseCopy.purchaseDateLabel`, `viewModel.comparisonLine`,
`PurchaseCopy.boughtFromLabel`, `PurchaseCopy.conditionLabel`; it names
`SaleCopy` nowhere and `Note` nowhere; it names no `ModelContext` (the rule
`SaleFormView` holds — the sheet writes nothing); the confirm button calls a
`confirm(purchase)` closure past a `viewModel.purchase()` guard (mutation:
confirm wired to call `confirm` unguarded → red). The comparison line's own
*content* is the view model's and is G4's.

## 8. The swipe, the menu and the Sell Plan action

- **`WishlistView`** (the list): `@State private var itemBeingBought: WishlistItem?`;
  the leading swipe becomes Edit (`divider`), **Buy** (`Image("ActionBuy")`,
  `.tint(theme.colors.accentBrassMid)`, `.accessibilityLabel(PurchaseCopy.markAsBought)`),
  Copy (`surfaceInset`) — Edit still nearest the edge (criterion 1); the
  trailing delete swipe is untouched (criterion 1). Plus
  `.sheet(item: $itemBeingBought, onDismiss: viewModel.load) { PurchaseFormView(viewModel:
  viewModel.makePurchaseFormViewModel(for: $0), confirm: …, cancel: …) }`,
  `014` §5's host shape, both closures nil-ing the state.
- **`WishlistDetailView`**: the existing `DetailOverflowMenu(noun:edit:delete:)`
  call becomes the `(noun:edit:middle:delete:)` one — so the file now builds
  two **`DetailOverflowMenu.Row`** values, spelled out and qualified, since
  `Row` is nested in the component and does not resolve bare in this file:
  `edit: DetailOverflowMenu.Row(title: "Edit", systemImage: "pencil", action: { isEditing = true })`
  and `middle: DetailOverflowMenu.Row(title: PurchaseCopy.markAsBought, systemImage: "bag", action: { isMarkingBought = true })`
  — `006`'s own placement of **Mark as sold…** on the item page, and the app's
  one system menu stays one (`MenuPolicyTests` unchanged, re-confirmed).

  **This reverses a `006` decision and fails a `006` guard, which is rewritten
  rather than dodged.** `SoldStateWiringTests.theWishlistPageKeepsTheOriginalMenuAndNamesNoSaleCopy`
  asserts `!code.contains("DetailOverflowMenu.Row")` over this very file, on
  the reasoning that "the wishlist's page is untouched by this spec" — true of
  `006`, false of `015`. Spelling the rows `.init(...)` would keep it green
  while its stated claim had become false, which is the false-passing shape
  `CLAUDE.md` records four times; so the test is **rewritten to pin the new
  rule**: the wishlist page composes `DetailOverflowMenu(`, builds exactly
  **one** middle `DetailOverflowMenu.Row` and that row's title is
  `PurchaseCopy.markAsBought`, and the file still names **no** `SaleCopy` —
  which is the half of the original claim that is still true and still worth
  holding (selling remains the owned side's business). `DetailOverflowMenu`'s
  own doc comment, which records the two-argument initializer as "what the
  wishlist's page asks for — it is untouched by this spec", is corrected in the
  same task, and `DECISIONS.md` records the reversal at close-out (§10).
  `@State private var isMarkingBought = false` and a `.sheet(isPresented:)`
  over `PurchaseFormView`; confirming calls `viewModel.markBought(...)` and
  `dismiss()`es on true. **No button in `content(for:)`** (criterion 2, spec
  P1) — G17 counts `PurchaseCopy.markAsBought` in the file and requires
  exactly one occurrence, so a page button turns it red. `.onAppear` becomes
  `viewModel.load(); if viewModel.hasBeenBought { dismiss() }` (R2).
- **`SellPlanView`**: `ToolbarItem(placement: .topBarTrailing)` holding — **only
  when `viewModel.wishlistItem != nil`** — a
  `Button { isMarkingBought = true } label: { Image(systemName: "bag") }` with
  `.accessibilityLabel(PurchaseCopy.markAsBought)` and
  `.accessibilityIdentifier("purchase.sellPlan")` — a bar button, not a menu,
  because this screen has no Edit or Delete to sit beside and a one-row menu is
  a menu for nothing; it lands in the same top-right corner the detail screen's
  "…" occupies, so "the action is top-right" is true on both screens. The gate
  is not decoration: this screen already draws a `missingItem` state when its
  entry has gone (another device deleted it), and an ungated button there would
  be tappable over no subject and would confirm a purchase of nothing. Second
  `.sheet(isPresented: $isMarkingBought)`, beside the existing
  `.sheet(item: $viewModel.saleCandidate)`; confirming calls
  `viewModel.markBought(purchase:)` and `dismiss()`es on true (R2). **If the
  person finds a bare glyph unreadable at the Phase 2 pause, the fallback is a
  text button reading "Bought" with the same accessibility label** — `014` Q9's
  short-word-plus-spoken-name pattern — which is a one-line change, not a
  redesign; it is offered in the pause note rather than guessed at now.

**Testable claims**: G15 (the list's swipe order and wiring), G16 (the glyph),
G17 (the menu row and the absent page button), G18 (the Sell Plan's toolbar,
sheet and dismiss), G19 (the detail's dismiss-on-appear). Every scan `#require`s
its anchor before asserting anything about it.

## 9. UI tests and the device pass

UI tests (`TroveUITests`, `-uiTesting -seedSellPlan` — **no seed change**: that
seed already has one wanted item, "Summicron 35mm f/2" at an estimated $2,400,
and four owned candidates, which is everything these two tests read):

- `testTheWishlistsLeadingSwipeOffersMarkAsBoughtAndTheSheetSeedsFromTheEstimate`:
  Wishlist tab; a **partial** drag across ~40 % of the Summicron row
  (`press(forDuration:thenDragTo:)`, never `swipeRight()`, which fires the edge
  action — `014` T009's finding); buttons "Edit", "Mark as bought…" and "Copy"
  exist with ascending `frame.minX`; tap it → `purchase.sheet.price` reads
  `2400` with grouping stripped; Cancel → the sheet gone, the row still on the
  Wishlist, Items still without it. Mutations: the middle button wired to
  `itemBeingEdited` → the price field absent → red; the
  `.accessibilityLabel` dropped → the button reads "Buy" → red (the `014`
  close-out lesson: pin the name that actually ships, never `OR` the two).
- `testMarkingAWantedItemBoughtMovesItToTheCollection`: same seed, same swipe;
  tap "Mark as bought…", set a condition chip, tap "Mark as bought" → the sheet
  closes, "Summicron 35mm f/2" is gone from the Wishlist and the Wishlist shows
  its existing empty state ("Nothing on the list yet", criterion 11), and the
  Items tab lists it with $2,400. Mutation: the Wishlist's bought filter
  dropped → the row is still there → red.

`scripts/verify.sh ui` twice back to back at the phase end.

**Device pass** (T012, a `general-purpose` agent with simulator tools — the
`sdd-implementer` has none): all three entry points opening the same sheet and
cancelling inert; the swipe's three buttons on both appearances and the middle
one's spoken name read from the accessibility tree (recorded for `DECISIONS.md`);
the comparison line appearing, changing and vanishing as the price is typed
(it is the one piece of copy no unit test can show *in place*); **a file probe
inside `WishlistPurchaseStore.markBought`** — Cancel 0, swipe-down 0, a list
re-render 0, confirm 1 — removed before the suites run, the `014` T010 shape
and the constitution's "instrument the mechanism, don't inspect an artifact"
rule; **the two pops** after a purchase from the Sell Plan, filmed (R2 — if it
steps or lands anywhere but the Wishlist, that is a finding for a decision
review, not an improvised fix); a purchased item's page showing the moved
photo **with its stock credit intact** (criterion 7, the one leg of G6 that is
also visual); **relaunch** and confirm the entry is still off the Wishlist and
the item still in the collection (criterion 12's persistence half, on the
persistent store, not the in-memory one); the Dashboard's figures before and
after one purchase (criterion 10). **The person's steps**: Accessibility
Inspector over the swipe action, the menu row, the Sell Plan's bar button and
the sheet's four fields (criterion 12's VoiceOver half); and iCloud sync of the
marker between devices if they have two, which no agent can do.

## 10. Docs and close-out

At T013: this spec's fifteen criteria ticked with per-criterion citations
(criterion 14 ticked **by inspection**, stating that no test can catch it being
false without being the broad-scan shape the constitution twice names as having
gone vacuous — the device pass's probe is the observation; criterion 15 ticked
on G14 **plus the diff**, per Q13); the Copy section's shapes replaced by the
shipped strings (P-items → decisions); this file gains **As built**;
`design/tokens.md`'s swipe-action table names the wishlist's third leading
action and its tint, and gains a row for the sheet; `README.md`'s wishlist
bullet gains the purchase; `specs/ROADMAP.md`'s `015` entry and status row, its
`009` entry (a completed plan now has a definition, and the unreachable orphan
a hand-corrected purchase leaves is `009`'s to surface or sweep), a follow-up
line for the shared field chrome the three sheets now copy (Q8), and a
**`fix/` follow-up for a defect in shipped code found while planning and
deliberately not fixed here**: `WishlistViewModel.duplicate(id:)` rebuilds
photos through `Photo(imageData:source:sortOrder:)`, which writes none of the
three attribution fields, so duplicating a wanted item with a `005` stock photo
already loses its credit today — a licence-compliance defect no criterion or
plan section here authorises touching, and which `CLAUDE.md` says gets its own
branch. (It is the same mis-shape Q6 refuses for the purchase, which is how it
was found.) `DECISIONS.md` (the marker as one optional date with no
relationship; photos moved rather than copied, and why the duplicate path is
the wrong shape here; Settings treating a bought entry as off the wishlist, R1;
the unbounded purchase date, Q9; the sub-dollar floor and the zero-estimate
consequence, Q7; **the `006` reversal** — the wishlist page now builds menu
rows, the component's doc comment corrected and `SoldStateWiringTests`'
wishlist-page test rewritten to pin the new rule). Then the pre-merge
`skeptical-reviewer` sweep over
`git diff main...HEAD` (bundle cut after `git add -A`) and the PR marked ready.

## 11. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `CloudKitSchemaTests` over the new field; `ModelTests`' `isBought` | `@Attribute(.unique)` or a non-optional marker; the predicate inverted |
| G2 | `WishlistPurchaseStoreTests`, second `ModelContext`: the marker, the item, the photos and the cleared selections all survive a `save()` | the caller's `save()` dropped; the refetch put back on the same context |
| G3 | `PurchaseCopyTests`: every string by literal | any word drifts |
| G4 | the comparison line: under, over, equal, no estimate, 40¢ apart | "more"/"less" swapped; the zero-estimate guard dropped (reads "$2,400 less"); the sub-dollar floor dropped (reads "$0 more") |
| G5 | the created item's thirteen fields, including `currentValueCents == purchasePriceCents`, `desireToKeep == 3`, `sortOrder` past a gap | `currentValueCents` left nil; `desireToOwn` mapped onto `desireToKeep`; `sortOrder` from a count |
| G6 | photos: same `Photo` ids, store-wide row count unchanged, `.fetched` credit's three strings intact, `wishlistItem` nil, `item` the new one, display order preserved | rebuilt as new rows (`duplicate(id:)`'s shape) → ids and count red, credit red; `wishlistItem` left set → ownership red |
| G7 | the plan: `plannedSaleItems` empty, `itemsSoldToward` identical, the released candidates still owned and still present | the sold-toward list cleared; the selections kept; a candidate deleted |
| G8 | the wanted subject's local market rows are gone after a purchase | the `MarketLocalStore.clear` call dropped |
| G9 | `WishlistViewModelTests`: a bought entry is out of `items`, `totalCount`, `categoryOptions` and `totalEstimatedCostCents`; buying the last leaves `.nothingAdded`; it never reappears after a reorder | the split dropped; `totalCount` taken from `all` (the empty-state case reddens alone) |
| G10 | `SettingsViewModelTests`: `wishlistCount`, `canDeleteWishlist`, the export-everything wishlist CSV and PDF, and delete-all's survivors | any of the three predicates dropped |
| G11 | `MarketRefresherTests`: a bought wanted entry is no target, an unbought matched one still is | `&& $0.boughtDate == nil` dropped |
| G12 | `everyHostSeedsThePurchaseSheetIdentically`, with and without an estimate; the same item and marker from each host | `?? 0` in one seed; one host using a different clock |
| G13 | the three refusal scans: one `save()`, `rollback()` and the message in the one `catch` and nowhere else | `rollback()` dropped; the message set outside the catch |
| G14 | `PurchaseUndoTests`: `boughtDate` assigned exactly once in `Trove/`, in `WishlistPurchaseStore.swift`, never to nil | any undo path added; the write moved into a view model |
| G15 | `WishlistPurchaseWiringTests`: the leading swipe names Edit, `PurchaseCopy.swipeBuy`, Copy in order; Buy writes `itemBeingBought`, carries `.accessibilityLabel(PurchaseCopy.markAsBought)` and `"ActionBuy"`; the trailing block names no `PurchaseCopy`; one `.sheet(item: $itemBeingBought` over `PurchaseFormView(` and `makePurchaseFormViewModel(for:` | any order, wiring or label change |
| G16 | `ActionIconTests`: `ActionBuy` resolves, renders as a template, and the five action glyphs are five distinct marks | the imageset missing or not template; the svg copied from `action-sell` |
| G17 | the detail's `DetailOverflowMenu` carries the middle row, and `PurchaseCopy.markAsBought` appears in that file exactly once; **`SoldStateWiringTests`' rewritten wishlist-page test** — exactly one middle `DetailOverflowMenu.Row`, titled `PurchaseCopy.markAsBought`, and still no `SaleCopy` | a page button added (count 2); the row dropped (count 0, `#require` fails); the rows spelled `.init(` to dodge the old scan; `SaleCopy` reaching this page |
| G18 | the Sell Plan composes one toolbar buy action **inside a `wishlistItem != nil` gate** and one `.sheet(isPresented: $isMarkingBought)` over `PurchaseFormView(`, and dismisses on a true `markBought` | the dismiss dropped; the sheet hosted twice; the gate dropped, leaving the action tappable over the missing-item state |
| G19 | `hasBeenBought` is true for a bought entry and false otherwise; `WishlistDetailView.onAppear` dismisses on it | the flag never set; the `.onAppear` check dropped |
| G20 | `PurchaseFormViewModelTests`: the seed, the two validation errors, a future date accepted, a blank location nil'd | a pre-filled 0; a date rule added without a decision |
| G21 | the sheet's five composed elements in source order; no `SaleCopy`, no Note, no `ModelContext`; confirm guarded by `purchase()` | a field reordered or dropped; confirm fires on an invalid sheet |
| G22 | `DashboardViewModelTests`: a purchase-created item moves every Dashboard figure exactly as an identical hand-added one | the item created without a value or outside the collection |
| G23 | UI: the swipe's three buttons and the seeded sheet; a confirmed purchase leaves the Wishlist empty-stated and lands on Items; twice back to back | see §9's mutations |

Every guard is mutation-verified before it lands (`CLAUDE.md` Testing); the
task's Done note records what was broken and what went red. Every source scan
`#require`s its anchor was found before asserting anything about it. The
claims the suites cannot reach — the sheet's spoken names, the comparison line
in place, the two pops, the credit on a moved photo on screen, the relaunch —
are §9's device pass, and criterion 14 is ticked by inspection with that stated
in the open.

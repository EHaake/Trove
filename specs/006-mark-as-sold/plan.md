# 006 — Mark as Sold — Technical Plan

**Status**: **Signed off** (2026-09-13) — skeptical-reviewer at `fable` (experiment
1's top tier); one blocking finding at the first review (B1, the Sold side's
CSV export inheriting the Owned side's narrowing — fixed as Q15/G33) and
eleven second-look notes, all folded in; the re-review signed off with
nothing open. Ready for implementation once the person approves the
spec-conformance summary.

Drafted by the `sdd-planner` (Fable 5.1, high effort — experiment 1's top
tier) against the approved `spec.md` (Approved 2026-09-13) and the code as it
stands on `main` at `465e733`, from which `006-mark-as-sold` branches.
Planning proposals (Q1–Q15) become decisions on plan approval, the way `005`'s
Q-items and this spec's P-items do. Three readings of the spec that the plan
had to take a side on are listed under **Readings for sign-off**; none is a
product fork, each is stated so the reviewer can overturn it.

## Context

Spec 006 lets an owned item be **marked as sold** — price, date, place, note —
and keeps it in the app on a **Sold side** of the Items tab, out of every
collection figure, with a Dashboard card and a Sell Plan that learn what was
sold toward what. Decisions 1–10 and P1–P17 settle the behaviour; this plan
settles two technical questions the dispatch named and everything that
follows from them:

1. **The sale is four optional fields on `Item` plus one optional to-one
   relationship**, not a separate synced `@Model` (Q1).
2. **The Owned/Sold side is `ItemListViewModel` state; the Dashboard card
   reaches it through a new `AppRouter.ItemsRequest.sold`** (Q4).

Nothing here touches `002`'s network code, adds a service, a store, a
launch-time migration or a `.pbxproj` edit. **No constitution amendment is
required**: the "What this project is" paragraph's rule is about *market*
sold prices, and the only sold price this spec stores is the one the person
types (spec "What and why"). So there is no Phase 0.

## Readings for sign-off (not open questions — the plan builds to each)

- **R1 — A scoped Sold card lands on the whole Sold side.** The card follows
  the Dashboard's category scope (P7) and "jumps to the Sold side" (Decision
  6/9). The Sold side has no filtering (Non-goals), so the jump from a
  category's card shows every sale, not the category's. Building a hidden
  category narrowing for the Sold side would contradict the non-goal; the
  plan doesn't.
- **R2 — Delete All (Settings) removes sold items too.** Settings is
  "unchanged" (P17) and a sold item is an item; leaving sold rows behind
  would give the person no way to clear them in bulk. The alert's count
  includes them.
- **R3 — One counted default per dropped sale on import.** P11 says either
  half alone is "dropped as a counted default"; the plan counts the dropped
  *sale* once, however many of the four sale cells were non-blank, and counts
  nothing when all four are blank. Two counts for one dropped sale would
  overstate the damage the confirmation reports.

## Proposed at planning (Q1–Q15) — approved on plan approval unless overturned

- **Q1. Fields on `Item`, not a `Sale` model.** Four optional stored
  properties and one optional to-one relationship on `Item` (§1). Reasons,
  each of which a separate model would forfeit: (a) the sale syncs *with* the
  item as one CloudKit record — a relationship syncs as a second record that
  can arrive before or after its item, so a second device could briefly show
  a sold item as owned, or a sale pointing at nothing; (b) every reader
  distinguishes the sides by one stored-property predicate, `soldDate == nil`,
  usable inside `#Predicate` and in-memory alike; (c) "Return to collection"
  is nil-ing five fields, with no row to delete and no orphan to leak — the
  `PhotoSelection.orphaned` class of bug never arises; (d) an item is sold
  once, whole (Non-goals), so a 1:1 relationship would carry nothing a field
  can't. Cost: four nil columns on every unsold item. `TroveSchema.models` is
  unchanged, so `MarketLocalSchemaTests`' disjointness pin needs no edit.
- **Q2. Names, and the one sold predicate.** `soldDate: Date?`,
  `salePriceCents: Int?`, `saleLocation: String?` (mirrors
  `purchaseLocation`; CSV "Sold At"; sheet "Sold at"), `saleNote: String?`,
  `soldTowardWishlistItem: WishlistItem?`. Not `soldAt` for the date: every
  `…At` in this schema is a timestamp and the spec's "Sold At" is the
  *place* — one name for two meanings is the drift this project keeps
  finding. **An item is sold iff `soldDate != nil`**; every writer sets the
  date and the price together (Q3, Q6) and `Item.sale` reads them as a pair.
- **Q3. One writer: `ItemSaleStore`.** A MainActor `enum` in
  `Trove/Models/ItemSaleStore.swift`, the `MarketLocalStore` "callers save"
  shape, with three statics — `markSold`, `editSale`, `returnToCollection`
  (§2). Both entry points (the detail, the Sell Plan row) and both later
  actions go through it, so "drops every plan selection, clears the market
  rows, keeps the funding link, never touches `sortOrder`" is one function's
  contract rather than four screens' agreement.
- **Q4. The side lives on the list view model; the router carries a request.**
  `ItemListViewModel.side: Side = .owned` (`enum Side { owned, sold }`), plain
  `@Observable` state with no store behind it — so the tab opens on Owned at
  every launch by construction (P16) and keeps its side across tab switches
  within a launch. `AppRouter.ItemsRequest` gains `.sold`;
  `router.showSoldItems()` sets it and pops to the Items root, exactly as
  `showItems(inCategory:)` does; `ItemListView.apply` turns `.sold` into one
  `viewModel.show(.sold)` call (Q15), and turns `.category`/`.unvalued` into
  `show(.owned)` plus today's narrowing — a request from the Dashboard
  always lands on the side it was about (§4).
- **Q5. Exports.** The list's **CSV** is the Owned side's visible rows, in
  visible order, followed by the sold items that pass the *same* narrowing
  (category, search, un-valued — a narrowing is about which gear, and sold
  gear still has a category, a name and a value field), in Sold-side order.
  Because changing side clears every narrowing (Q15), the narrowing is the
  identity on the Sold side, so a CSV exported from there is the complete
  record; from the Owned side a *visible* chip or query narrows both halves
  and the coverage label stays true. Settings' export-everything CSV is owned-in-Custom-order then sold in
  Sold-side order, through the same two comparators, so `013`'s byte-identity
  (unfiltered Custom list CSV == Settings CSV) still holds with sales
  present. The **PDF** is the Owned side only, on both paths, and its cover
  totals are the list view model's owned-only arithmetic, so they match the
  Dashboard by construction. `canExport` splits into `canExportCSV`
  (either side non-empty) and `canExportPDF` (owned non-empty); the
  `OverflowDropdown` takes both and `ExportWiringTests` is **broadened**, not
  weakened: two rows, one gate each, Import and Settings still ungated (§7).
  *Superseded by `014-sold-side-parity` (its plan, P11): the CSV is narrowed by the on-screen side only, so the Sold side's narrowing is no longer the identity and the "Because changing side clears every narrowing (Q15)" clause above no longer holds.*
- **Q6. Import pair rule.** A row is a sold item iff **both** `Sold Date` and
  `Sale Price` parse (the schema's own date and money parsers). Otherwise the
  item imports unsold, and — if *any* of the four sale cells was non-blank —
  the dropped sale counts **one** default (R3). An imported sale points at no
  plan (P11): the record carries no plan and the commit sets none. Two rules
  the sheet enforces (Q12) and import does not repeat, stated: a **negative
  `Sale Price`** is unreadable to `012`'s parser already — `ImportSchema.cents`
  rejects any sign — so it is the "price unreadable" case, the sale is
  dropped and counted, the item imports unsold; a **future `Sold Date`**
  imports as a sale as written, because `ImportSchema.day` has no clock and
  `Purchase Date` is accepted unbounded the same way — the sheet's bound is a
  data-entry courtesy, import trusts the file, and the asymmetry is recorded
  here rather than hidden in a parser that would need a `now` it doesn't take.
- **Q7. Delete All items includes sold items** (R2). `itemCount` in Settings
  keeps counting every `Item`.
- **Q8. The sold detail state hides what would act.** The Market section and
  Find a photo… are not rendered on a sold item (the page is read-only; a
  sold item "has no market value to track", Decision 7), the desire dial is
  `isInteractive: false`, and the stat pair keeps WORTH NOW / PAID unchanged
  beneath the Sold mark. The item's `reverbProductID` is **kept** (Decision
  1: the match is left as it was); only the device-local rows are cleared, so
  after Return the section shows the match as never-refreshed-here and
  Refresh resumes, because the refresher's target predicate (§2) reads the
  sold flag, not the match.
- **Q9. Sold-side order and empty reason.** Most recent sale first, then name
  (case-insensitive), then id — fully determined by the data, the `SellPlanRanking`
  rule. `ListEmptyReason` gains `.nothingSold`; on the Sold side the reason is
  `stillSyncing` if the store may still be importing and nothing sold is
  here, else `nothingSold` when empty, else nil — no search/category cases,
  since the side has no narrowing (Q15 is what makes that true by
  construction, not only by what the page renders).
- **Q10. A second UI-test seed, `-seedSold`**, mirrored on `UITestSeed`'s
  shape: its own argument (`UITestSeed.soldArgument`), its own structural
  gate (`shouldSeedSold(mode:arguments:)`), its own guard in `TroveApp`, and
  `UITestSeedTests` mirrored for it; `-seedSellPlan` and `-uiTesting` alone
  keep the starting states every existing UI test was written against
  (`CLAUDE.md`'s amended rule).
- **Q11. Copy and colour in one place, `SaleCopy`.** Every string the spec's
  Copy section fixes, plus the composed lines: the card ("3 items · $2,400",
  "+$350 vs paid"), the Sold-side summary ("3 sold · $2,400 · +$350 vs
  paid"), a row's outcome ("Gain $350" / "Loss $150" / "Sold at cost"), the
  page's outcome ("Sold at a gain of $350" / "Sold at a loss of $150" /
  "Sold at cost"), the sale line ("Sold 12 Sep 2026 · $1,200 · eBay", the
  place omitted when nil — the date through
  `formatted(date: .abbreviated, time: .omitted)`, the detail's "Bought" row's
  own formatter, so it follows the device locale and reads "Sep 12, 2026" on a
  US device; the spec's example is the same date in a day-first locale, not a
  fixed order). A realised delta of zero on the card and summary
  reads "+$0 vs paid" through the Dashboard's own
  `formattedAsSignedWholeCurrency` (the Gain figure already prints "+$0");
  the rows and page say "Sold at cost" in words. Colour: the *rule* lives on
  the model as `SaleOutcome.isLoss` (`deltaCents < 0`) — `SaleCopy` is a
  `Trove/Models/` file and names no colour — and `SoldItemRow`, `SoldMark`
  and `SoldCard` each map it to `accentRustText` / `accentMossText` exactly
  as `ItemRow` maps its delta, so "Sold at cost" is moss like a zero Gain is
  today.
  **The two outcome strings are placeholders** (spec Decision 10, as
  clarified): what is fixed is that a row and the page make the gain or loss
  and its amount unmistakable without colour carrying it; the Design pass
  (T008) may replace the words with a labelled figure or a mark, in which
  case `SaleCopy` and `SaleCopyTests` change in the T008-following screen
  task and the UI tests (T018, written after T008) assert the settled form.
  A form change there is a copy change inside the spec, not new copy.
- **Q12. Sale price rules mirror the form's purchase price.** Required
  (blank rejected), zero allowed (given away is a sale of $0), negative
  rejected; whole `Decimal` → cents through `Money.cents(from:)`. The date:
  any instant ≤ `now()` (P2 — before the purchase date is allowed), the
  `DatePicker` bounded with `in: ...now` *and* the view model validating,
  since the picker's bound is a courtesy and the view model's check is the
  falsifiable one.
- **Q13. `updatedAt` bumps** on mark, edit-sale and return: each is a change
  to the item row, and "bumped on every edit by the view models that own
  mutation" is the standing rule.
- **Q14. The Sell Plan reads its sales off the relationship**,
  `wishlistItem.itemsSoldToward`, never a fetch over every sold item: the
  link is the fact (P5), and reading it the same way the plan reads
  `plannedSaleItems` keeps one shape. The colour cue stays a boolean:
  `selectedValueMeetsCost` becomes `(selectedCount + soldCount) > 0 &&
  selectedValueCents + soldValueCents >= estimatedCostCents` (P14). The name
  is kept so the guard that pins it as a boolean keeps its target.
- **Q15. Changing side is an intent that clears every narrowing** (added at
  sign-off, blocking finding B1). `ItemListViewModel.show(_ side: Side)` sets
  `side` and, whenever the side actually changes, clears `searchText`,
  `categoryFilter` and `showsOnlyUnvalued` in both directions — Owned is
  "today's Items list" (P16), never today's list under a filter left behind
  by a visit to Sold, and the Sold side can never carry a narrowing it does
  not show. `side` becomes `private(set)`; `SideSwitch` binds through
  `show(_:)`; `ItemListView.apply(.sold)` is one call to it. The former
  design cleared the narrowing only on the router path, so tapping the
  switch after filtering Owned to "Cameras" would have exported a Cameras-only
  CSV from a Sold side that showed every sale.
  *Superseded by `014-sold-side-parity` (its spec, Decision 4): a side change clears nothing — each side keeps its own search, chip and sort across a switch, held as two values behind one set of names.*

---

## Layout and files

New production files (all under synchronized groups — no `.pbxproj` edit; if
one is ever needed, stop and flag):

| File | Holds |
|---|---|
| `Trove/Models/Sale.swift` | `Sale` (value), `SaleOutcome`, `Item.sale` accessor + `isSold` |
| `Trove/Models/ItemSaleStore.swift` | `markSold`, `editSale`, `returnToCollection` (Q3) |
| `Trove/Models/SaleCopy.swift` | every string and composed line (Q11) |
| `Trove/ViewModels/SaleFormViewModel.swift` | the sale sheet's state and validation |
| `Trove/Views/Items/SaleFormView.swift` | the sale sheet (shared by the detail and the Sell Plan row) |
| `Trove/Views/Items/SideSwitch.swift` | the Owned / Sold control (Design pass) |
| `Trove/Views/Items/SoldItemRow.swift` | the Sold side's row |
| `Trove/Views/Items/SoldMark.swift` | the sold state's header block on the detail |
| `Trove/Views/Dashboard/SoldCard.swift` | the Dashboard card |

Changed: `Item`, `WishlistItem` (§1); `AppRouter` (§4); `ItemListViewModel`,
`ItemListView`, `ListEmptyReason` (§4; `ItemRow` is untouched — the Sold side
has its own row); `ItemDetailViewModel`,
`ItemDetailView`, `DetailOverflowMenu`, `ItemDeleteCopy` (§5);
`DashboardViewModel`, `DashboardView` (§6); `SellPlanViewModel`,
`SellPlanView` (§3); `MarketRefresher.targets` (§2); `SettingsViewModel`
(§7); `ExportSchema`, `ImportSchema`, `ItemListViewModel.confirmImport`,
`OverflowDropdown` (§7); `UITestSeed`, `TroveApp` (§8); `PRIVACY.md`,
`docs/csv-reference.md`, `docs/samples/`, `specs/011-data-export/plan.md`
(§9). `CloudKitSchemaTests` covers the schema change and stays green.

---

## 1. The sale on `Item` (foundational, schema change)

Five additions to `Item` (`Trove/Models/Item.swift`), after `year`, every one
optional — CloudKit-additive, so `CloudKitSchemaTests` continues to validate
(red run: declare `soldDate` as a non-optional `Date` with no default → the
validator names it; a defaulted scalar would also validate, so the red run
must remove the default, not the optionality alone):

```swift
/// 006: when this item was sold, or nil while it is owned. **The one sold
/// predicate** — `soldDate == nil` is "owned" everywhere, in `#Predicate`
/// and in memory alike (plan Q2). Written together with `salePriceCents`
/// by `ItemSaleStore` and the import commit, never alone.
var soldDate: Date?
/// The sale price in minor units, as every money field is. Nil while owned.
var salePriceCents: Int?
/// Where it sold ("eBay, Reverb, a friend…"), optional as `purchaseLocation` is.
var saleLocation: String?
var saleNote: String?
/// 006 (spec P5): the wishlist item this sale was recorded toward, set only
/// when sold from that item's Sell Plan. `.nullify` both ways: deleting the
/// wishlist item leaves the sale standing with no plan (P10); deleting the
/// item drops it from the wishlist item's list. Distinct from
/// `plannedForWishlistItems`, which is a *selection* and is emptied at the
/// sale (P6).
@Relationship(deleteRule: .nullify, inverse: \WishlistItem.itemsSoldToward)
var soldTowardWishlistItem: WishlistItem?
```

`WishlistItem` gains the inverse, `@Relationship(deleteRule: .nullify) var
itemsSoldToward: [Item]? = []`, declared like `plannedSaleItems` (the `Item`
side owns `inverse:`). `Item.init` gains no sale parameters — an item is
never created sold except by import, which sets `sale` after construction.

`Trove/Models/Sale.swift`:

```swift
nonisolated struct Sale: Sendable, Equatable {
    var date: Date
    var priceCents: Int
    var location: String?
    var note: String?
}

/// Gain or loss against what was paid — the one arithmetic this spec adds.
nonisolated struct SaleOutcome: Sendable, Equatable {
    let deltaCents: Int            // priceCents − purchasePriceCents
    var isLoss: Bool { deltaCents < 0 }   // the colour rule, on the model (Q11)
    init(salePriceCents: Int, purchasePriceCents: Int)
}

/// The three figures every "what was sold" surface shows, summed once.
/// `ItemListViewModel`, `DashboardViewModel` and the UI seed's expected
/// numbers all read this, so AC7's "the summary matches the card" is one
/// sum, not two hand-written ones agreeing.
nonisolated struct SaleTotals: Sendable, Equatable {
    let count: Int
    let proceedsCents: Int         // Σ salePriceCents
    let realisedDeltaCents: Int    // Σ SaleOutcome.deltaCents
}

extension SaleOutcome {
    /// Over the sold items among `items` — an unsold item contributes nothing.
    @MainActor static func totals(over items: [Item]) -> SaleTotals
}

extension Item {
    var isSold: Bool { soldDate != nil }
    /// The sale as a pair, or nil while owned. Setting nil clears all four
    /// fields **and** `soldTowardWishlistItem` (Return to collection, P12);
    /// setting a value writes the four fields and leaves the link alone.
    var sale: Sale? { get set }
    var saleOutcome: SaleOutcome?  // nil while owned
}
```

The `get` requires `soldDate`; a row carrying a date and no price — reachable
only from a future version or a bug, never from this app's writers — reads
its price as 0 rather than hiding the sale, and `ModelTests` records that
branch as the defensive one. **Testable claims**: the schema stays
CloudKit-compatible — `CloudKitSchemaTests` (T001, G1); `sale = nil` clears
the link and all four fields on a second context — `ModelTests` (T001, G2);
deleting the wishlist item nullifies `soldTowardWishlistItem` and the sale
stands — `WishlistDeletionTests` (T001, G3); `SaleOutcome.totals` over a
gain, a loss, an at-cost sale and an owned item gives count 3, the summed
proceeds and the summed delta, and neither list nor dashboard view model
does the arithmetic itself — `SaleOutcomeTests` plus a scan that both view
models call `SaleOutcome.totals(` and neither contains `salePriceCents -`
(T001, T009, T010, G32).

## 2. The writer, and who reads the flag

`ItemSaleStore` (MainActor, `Trove/Models/ItemSaleStore.swift`), callers save:

```swift
enum ItemSaleStore {
    /// Mark: the sale, the optional plan it was sold toward, every plan
    /// selection dropped (P6), the device's market rows cleared (Decision 7),
    /// `updatedAt` bumped, `sortOrder` untouched. Throws only from the
    /// market clear.
    static func markSold(_ item: Item, sale: Sale, toward plan: WishlistItem?, at now: Date, in context: ModelContext) throws
    /// Edit sale…: the four fields only. The plan link and the (already
    /// empty) selections are not touched.
    static func editSale(_ item: Item, sale: Sale, at now: Date)
    /// Return to collection…: `sale = nil` (fields + link), `updatedAt`.
    /// `sortOrder` untouched, so the item reappears at its former place in
    /// Custom order by construction; it rejoins no plan (P12).
    static func returnToCollection(_ item: Item, at now: Date)
}
```

`markSold` writes `item.plannedForWishlistItems = []` — the inverse of what
deletion's `.nullify` does today, done explicitly because the item survives.

**Who reads the flag.** Every reader that today fetches `FetchDescriptor<Item>()`
and means "the collection" splits on `isSold`:

| Reader | Change |
|---|---|
| `ItemListViewModel.load` (§4) | `owned` / `sold` split; every existing figure over `owned` |
| `DashboardViewModel.load` (§6) | `apply(owned…)` unchanged in body; sold figures from `sold` |
| `SellPlanViewModel.load` (§3) | `owned` excludes sold before `candidates`, `ownedCount`, `lowDesireCount` |
| `MarketRefresher.targets(in:)` | predicate `reverbProductID != nil && soldDate == nil`; Settings' `matchedCount` and the walk follow for free |
| `SettingsViewModel.everythingInCustomOrder` (§7) | returns owned and sold separately |
| `ManualOrderHelper.nextPosition(after:)`, `duplicate`'s placement fetch | **unchanged** — positions are over every row, sold included, so a returned item's slot is never reused |

**Testable claims** (`ItemSaleStoreTests`, second-context refetch throughout):
a marked item is on no `plannedSaleItems` afterwards while the wishlist entry
survives (mutation: drop the `plannedForWishlistItems = []` line → red, G4);
its market rows are gone and another item's remain (mutation: drop the clear
→ red, G5); `soldTowardWishlistItem` is set only when a plan is passed (G6);
mark then return leaves `sortOrder` equal to before and the item back in its
Custom-order slot among three others (mutation: reset `sortOrder` on return →
red, G7); a sold matched item is not among `MarketRefresher.targets`
(mutation: drop the clause → red, G8); every stored sale has both date and
price (the pair, G9).

## 3. The Sell Plan

`SellPlanViewModel` gains, read off `wishlistItem.itemsSoldToward` (Q14):
`soldItems: [Item]` (most recent sale first, the §4 comparator), `soldCount`,
`soldValueCents` (sum of `salePriceCents`), `hasSales`; `selectedValueMeetsCost`
reads Selected plus Sold (Q14); `load()` filters sold items out of `owned`
before everything else, so a sold item is never a candidate and never counts
toward `ownedCount`/`lowDesireCount`. New intent:

```swift
/// Mark as sold… from a row: the sale points at this plan (P5), the item
/// leaves the candidates (it is on no selection after the store call) and
/// the figures re-derive. Returns false on a refused save, which rolls back.
@discardableResult func markSold(_ item: Item, sale: Sale) -> Bool
/// The row whose sheet is up — `.sheet(item:)` state, view-settable.
var saleCandidate: Item?
/// The sheet's view model for a row, seeded exactly as the detail seeds
/// its `.mark` sheet (P1: the price from the item's current value, the
/// date today) — one seeding rule for both hosts.
func makeSaleFormViewModel(for item: Item) -> SaleFormViewModel
```

`SellPlanView`: the figures row becomes three cells when `hasSales` — Selected
(caption "N of M items"), **Sold** (caption "N items", `sellPlan.soldFigure`),
Estimated cost — and stays two otherwise; the divider `Rectangle` pattern
repeats. Each candidate row gains a bespoke in-page **Mark as sold…** control
in the row's own style (`sellPlan.row.markAsSold`; the checkbox toggles, the
new control opens the sheet — two tap targets, the row's `Button` no longer
wraps the whole card, or the control is placed outside the toggle's hit
area; the Design pass decides which). Under the candidate list, when
`hasSales`, a **Sold** section — one quiet row per sale: name, date, price
(P15). The sheet is `SaleFormView` (§5), hosted with `.sheet(item:
$viewModel.saleCandidate)`.

**The framing guard, extended not weakened.** `SellPlanFramingTests`'
term scan already covers the whole view-model file and the view's string
literals, so the new members and copy are inside it from the first commit;
`bothFiguresExistIndependently` gains a third figure: with one sale recorded,
`soldValueCents` is its price, `estimatedCostCents` is unchanged, and no
member equals `estimatedCostCents − selectedValueCents − soldValueCents`
(mutation: subtract sold from the cost → the cost assertion red, G10). The
cue: a plan whose sales alone meet the cost reads as met, and one with sales
short of it does not (mutation: read Selected alone → red, G11).

**Testable claims** (`SellPlanViewModelTests`): `markSold` from the plan sets
`soldTowardWishlistItem` to this plan and removes the row from `candidates`
(G6, G12); sold from elsewhere, `soldItems` is empty; a sold item never
qualifies even at desire 1 with a value (mutation: drop the sold filter →
red, G12); `soldItems` order.

## 4. The Items tab's two sides

`ItemListViewModel`:

```swift
enum Side: Hashable { case owned, sold }
private(set) var side: Side = .owned
/// The one way the side changes (Q15): sets it and, when it actually
/// changes, clears every narrowing — then `load()`.
func show(_ side: Side)
private(set) var soldItems: [Item] = []       // Sold-side order
private(set) var soldTotals = SaleTotals(count: 0, proceedsCents: 0, realisedDeltaCents: 0)   // SaleOutcome.totals(over: sold)
var soldSummaryLine: String   // never nil — "0 sold · $0" at zero sales (Decision 13, amended 2026-09-15; was String?, nil when nothing was sold, per Decision 11)   // SaleCopy.soldSideSummary(soldTotals)
static func areInSoldOrder(_ lhs: Item, _ rhs: Item) -> Bool   // date desc, name, id
```

`load()` fetches once and splits: `items`, `totalCount`, `categoryOptions`,
`marketSummaries`, `unvaluedCount`, `totalCurrentValueCents` — every existing
member — derive from `owned`; `soldItems` from `sold`, sorted, and
`soldTotals` through `SaleOutcome.totals` (no arithmetic here). `emptyReason`
switches on `side` (Q9). `canReorder` adds `side == .owned`. `delete(id:)`
looks in both arrays (the Sold side's swipe, P16). `canExport` → `canExportCSV`
/ `canExportPDF` (Q5); `exportCSV` appends the narrowed sold rows; `exportPDF`
unchanged in body (it reads `items`). The narrowing applied to sold rows is
the same three filters, extracted into one `narrowed(_:)` so the two sides
can't drift — and on the Sold side `narrowed` is the identity, because
`show(.sold)` cleared the three fields (Q15).
*Superseded by `014-sold-side-parity` (its spec, Decision 4, and its plan P11): each side keeps its own narrowing, so `narrowed` is not the identity on the Sold side; the CSV is narrowed by the on-screen side only (P11).*

`AppRouter`: `ItemsRequest.sold`, `func showSoldItems()` (sets the request,
`popToItemsRoot()`). `ItemListView.apply`: `.sold` → `viewModel.show(.sold)`;
`.category`/`.unvalued` → `viewModel.show(.owned)` then today's writes.

`ItemListView`: the `SideSwitch` (Design pass) sits in the **header**, which
both branches of `body` compose — so it is there when the Owned side is
empty (a person whose only item is now sold) exactly as it is over rows — and
binds through `viewModel.show(_:)`, never to `side` directly. On the Sold side:
the summary line is `soldSummaryLine`; the search field and chips are not
rendered; `sortControl` is not rendered (P16); `overflowControl` stays; the
rows are `SoldItemRow`s in the same `List` chrome, tap → `router.itemsPath.append`,
trailing swipe → `pendingDeletion` (the same staging), no leading swipe, no
`onMove`; the empty state maps `.nothingSold` to `SaleCopy.nothingSoldHeadline`
/ `nothingSoldDetail`. The delete alert's message is
`ItemDeleteCopy.message(isSold: item.isSold)` (§5).

**The emptied Owned side (spec Decision 12, amended 2026-09-14).**
`ListEmptyReason` gains `everythingSold` — the Owned side is empty because
every item has been sold. Like `nothingSold` it is never returned by
`reason(...)`: `ItemListViewModel.emptyReason`'s `.owned` branch maps the
`.nothingAdded` that `reason(...)` returns to `.everythingSold` when
`soldItems` is non-empty, and passes every other reason through unchanged.
So `reason(...)`'s precedence and its tests stay as they are, `stillSyncing`
still wins while the collection may be arriving, and a narrowed-to-nothing
Owned side keeps its filter copy. `SaleCopy.everythingSoldHeadline` /
`everythingSoldDetail` ("Everything's sold." / "Add something new.") — the
person's wording, tunable at the phase pause. `ItemListView.emptyState` maps
the case with the Items mark, and `WishlistView`'s reason switch folds it
like `.nothingSold`. Guard: with one sold item and no owned, `emptyReason`
is `.everythingSold`; with none of either it is `.nothingAdded`; with the
sync monitor reporting an import in flight it is `.stillSyncing`.

`SoldItemRow`: `RowThumbnail`, name, "Sold 12 Sep 2026" mono line, the price
in `monoValue`, the outcome in words (`SaleCopy.rowOutcome`) in the Q11
colour; `.accessibilityElement(children: .combine)` so VoiceOver reads name,
date, price and outcome (criterion 16); no dial, no trend arrow (a sold item
has no market line).

**Testable claims** (`ItemListViewModelTests` / `AppRouterTests` /
`ItemListSidesWiringTests`): a sold item is absent from `items`, `totalCount`,
`totalCurrentValueCents`, `unvaluedCount` and `categoryOptions` and present in
`soldItems` (mutation: drop the split → red, G13); Sold-side order (G14);
`soldSummaryLine` equals `SaleCopy.soldSideSummary` over the same figures; on
the Owned side a category filter narrows the CSV's sold rows too and the
un-filtered CSV lists owned then sold (G15); **`show(_:)` clears the
narrowing**: set a category filter and a query, `show(.sold)`, and
`exportCSV` lists every owned and every sold row while `categoryFilter`,
`searchText` and `showsOnlyUnvalued` read empty; `show(.owned)` from a
filtered Sold side likewise; `show(.owned)` on the Owned side leaves a filter
alone (mutation: keep the filter across the switch → red, G33); the PDF's
entries and cover totals exclude a sold item (G16); `delete(id:)` on a sold
item removes it and reloads both arrays; `showSoldItems()` sets `.sold` and
pops; `canReorder` is false on the Sold side; source scans: `ItemListView`
renders no `sortControl` and no `SearchField` inside the Sold branch, the
swipe block on the Owned rows contains no `SaleCopy.markAsSold` (criterion
1), the Sold rows compose `SoldItemRow`, the `.sold` case of `apply` is one
`viewModel.show(.sold)` call, and the `SideSwitch` call site names
`viewModel.show` and no `$viewModel.side`.

## 5. The item detail: mark, sold state, edit, return

`SaleFormViewModel` (`@Observable`, no SwiftUI):

```swift
enum ValidationError: Hashable { case priceMissing, priceNegative, dateInFuture }
enum Mode { case mark, edit }
var price: Decimal?; var date: Date; var location: String; var note: String
private(set) var validationErrors: Set<ValidationError>
let mode: Mode
var title: String   // by mode over SaleCopy.sheetTitleMark / sheetTitleEdit — "Mark as sold" / "Edit sale" (as shipped at T002: constants, not a mode function, since the mode is a view-model type and SaleCopy stays a plain string table; corrected at the Phase 1 review)
var confirmLabel: String   // "Mark as sold" / "Save"
var latestDate: Date { now() }
init(mode: Mode, prefill: Sale?, currentValueCents: Int?, now: @escaping () -> Date = Date.init)
/// Validates; nil with `validationErrors` set, else the sale to record.
func sale() -> Sale?
```

Seeding (P1): `.edit` prefills from the sale; `.mark` prefills the price from
`currentValueCents` when present, else blank; the date is `now()`; location
and note blank. `sale()` trims location and note through `FieldNormalization`
and nils blanks, exactly as the item form does.

`SaleFormView(viewModel:confirm:cancel:)` — a `NavigationStack` sheet in the
item form's field style: the money field (`TextField(value:format:)`, `$`
prefix, `.decimalPad`, `sale.sheet.price`), the date field with the popover
`DatePicker(… in: ...viewModel.latestDate)` (the item form's `dateField`
lifted into a shared shape if the Design pass keeps it identical), "Sold at"
with the spec's placeholder, "Note", Cancel / confirm (`sale.sheet.confirm`),
`[.medium, .large]` detents. Confirm calls `viewModel.sale()` and hands the
value to `confirm`; the host decides what to do with it. The same view serves
the Sell Plan row (§3) — one component, not two.

`ItemDetailViewModel` gains: `isSold`, `sale`, `saleOutcome`,
`saleSheet: SaleSheet?` (`.mark | .edit`, view-settable for `.sheet(item:)`),
`isConfirmingReturn` (view state is fine, but the intents are here),
`makeSaleFormViewModel() -> SaleFormViewModel` (mode from `saleSheet`, seeded
per P1), and the three intents:

```swift
@discardableResult func markSold(_ sale: Sale) -> Bool   // ItemSaleStore.markSold(toward: nil), save, rollback+load on refusal
@discardableResult func editSale(_ sale: Sale) -> Bool
@discardableResult func returnToCollection() -> Bool     // ItemSaleStore.returnToCollection, save
```

`DetailOverflowMenu` gains a configurable middle row and an edit label, with
the existing `(noun:edit:delete:)` initializer kept so `WishlistDetailView`
is untouched:

```swift
struct DetailOverflowMenu: View {
    struct Row { let title: String; let systemImage: String; let action: () -> Void }
    let noun: String
    let edit: Row                 // "Edit"/pencil, or "Edit sale…"/pencil
    var middle: Row? = nil        // "Mark as sold…"/tag, or "Return to collection…"/arrow.uturn.backward
    let delete: () -> Void
    init(noun: String, edit: @escaping () -> Void, delete: @escaping () -> Void)   // today's shape
    init(noun: String, edit: Row, middle: Row?, delete: @escaping () -> Void)
}
```

It stays the app's one system `Menu` (`MenuPolicyTests` unchanged). Owned
item: Edit, **Mark as sold…**, Delete. Sold item: **Edit sale…**, **Return to
collection…**, Delete (P4). `ItemDetailView` renders the sold state when
`viewModel.isSold`: a `SoldMark` block first in the scroll content, above the photo hero (per the approved artboard; amended 2026-09-14 at the Phase 5 review — the earlier "above the category/name" predated the design pass) — the word
**Sold**, the sale line, the outcome in words with what was paid beside it
(`sold.mark`) — then the ordinary content with the Q8 omissions; the return
confirmation is a standard `.alert` with `SaleCopy.returnTitle(name)`,
`returnMessage`, **Return** / **Keep as sold**; the delete alert reads
`ItemDeleteCopy.message(isSold:)`.

`ItemDeleteCopy.message` becomes `message(isSold: Bool) -> String`: the owned
message is today's three sentences verbatim; the sold one is "Its photos go
too. This can't be undone." (P13). `DeletionGuardTests`' `contains("ItemDeleteCopy.message")`
scans stay green on the call; `ItemDeleteCopyTests` gains the sold case:
photos and permanence present, "sell plan" absent (mutation: reuse the owned
message → red, G17).

**Testable claims** (`SaleFormViewModelTests`, `ItemDetailViewModelTests`):
a blank price → `.priceMissing`, negative → `.priceNegative`, a date one
second past `now` → `.dateInFuture`, a date before the purchase date is
accepted (G18); `.mark` prefills the current value, blank without one, `.edit`
prefills the sale (G19); `markSold` on a second context: the four fields, no
plan link, the item's own fields, photos and `reverbProductID` unchanged, the
market rows gone (G5, G20); `editSale` keeps the plan link an earlier plan
sale set (G21); `returnToCollection` clears everything and the item is back in
`ItemListViewModel.items` at its slot (G7); `delete` on a sold item removes
it and its photos. Source scans (`SoldStateWiringTests`): `ItemDetailView`
passes both middle rows through `SaleCopy`; `WishlistDetailView` names no
`SaleCopy` member; the sold branch of `ItemDetailView` composes no
`MarketSection(` and no `findPhotoAction` (a brace-span scan, the
`ImportWiringTests` shape, which `#require`s its `if viewModel.isSold` anchor
found before asserting anything about the span).

## 6. The Dashboard

`DashboardViewModel.load()` splits `scoped` into owned and sold; `apply(owned,
marketSummaries:)` is unchanged in body — so total value, paid, delta, counts,
ruler, breakdown, `unvaluedDestination` and the market line exclude sold
items by construction — and the sold figures come from `sold`:

```swift
private(set) var soldTotals = SaleTotals(count: 0, proceedsCents: 0, realisedDeltaCents: 0)   // SaleOutcome.totals(over: sold scoped items)
var hasSales: Bool { soldTotals.count > 0 }
var soldLine: String        // SaleCopy.dashboardSummary(soldTotals) — "3 items · $2,400"
var soldDeltaLine: String   // SaleCopy.realised(deltaCents:) — "+$350 vs paid"
```

`SoldCard` (`Trove/Views/Dashboard/SoldCard.swift`, Design pass): header
**Sold**, the two lines, the delta in the Q11 colour, a `Button` whose
action is `router.showSoldItems()`, `.accessibilityElement(children: .combine)`,
hint "Shows what you've sold in Items", identifier `dashboard.soldCard`.
Placed in `DashboardView` after the un-valued callout and before the
breakdown, rendered iff `viewModel.hasSales`, on the root and on every scoped
copy (P7) — and never inside `spentAndGain` or the headline, which is what
"sits apart" means structurally. Note `MarketSummary.summaries` is still
asked for `scoped` owned ids only, so a sold item's (already cleared) rows
could not count even if they existed.

**Testable claims** (`DashboardViewModelTests`): with one sold item among
valued owned ones, `totalCurrentValueCents − totalSpentCents ==
valueDeltaCents`, and the sold item's value and cost are in neither, nor in
`totalItemCount`, `breakdown` or `marketFigureCount` (mutation: count sold in
`apply` → red, G22); the sold figures equal the seeded sale arithmetic and
follow `scope` (a sale outside the scope is absent; `hasSales` false when
none in scope, G23); `soldLine`/`soldDeltaLine` equal `SaleCopy` over the
same numbers. `DashboardWiringTests` (scan): `SoldCard(` appears once, inside
an `if viewModel.hasSales` span, and its closure calls `router.showSoldItems()`
— the scan first `#require`s that the `if viewModel.hasSales` anchor was found
exactly once, so it cannot pass over a file that never renders the card.

## 7. Exports and import

`ItemExportRecord` gains `soldDate: Date?`, `salePriceCents: Int?`,
`saleLocation: String?`, `saleNote: String?` (all nil from `init(item:)` on
an owned item, from the item's `sale` on a sold one). `ExportSchema`:

```swift
static let itemHeaders = [ …14 existing…, "Sold Date", "Sale Price", "Sold At", "Sale Note" ]
static let itemSchemaBoundaries = [12, 14]   // 14 = the layout 002…005 shipped
```

`row(from:)` appends `day(soldDate)`, `money(salePriceCents)`, location,
note — each blank when nil. The wishlist headers are unchanged (criterion
12). `PDFEntry.init(record:)` is unchanged — the PDF never sees a sold record
because both callers pass owned items only (Q5).

`ImportSchema.itemsPreview`: four more `column(…)` lookups; `soldDate =
day(from:)`, `salePrice = cents(from:)`; the pair rule (Q6/R3) sets
`record.soldDate`/`salePriceCents`/`saleLocation`/`saleNote` when both parse,
else nils all four and adds one to `defaulted` iff any of the four trimmed
cells was non-blank. The gate accepts widths 18, 14 and 12. The commit
(`ItemListViewModel.confirmImport`) sets `item.sale = Sale(…)` after
construction when the record carries a date and price — no plan.

`SettingsViewModel.everythingInCustomOrder` returns `(owned, sold, wanted)`;
`exportEverythingAsCSV` writes owned then sold (Q5); `exportEverythingAsPDF`
uses owned only for entries and totals. `OverflowDropdown(canExportCSV:canExportPDF:…)`;
`WishlistView` passes its one `canExport` to both.

`docs/csv-reference.md`: 18 columns, four new rows in the items table (Sold
Date `yyyy-MM-dd`, Sale Price plain number, Sold At text, Sale Note text —
"blank for an item you still own; a date and a price together make the row a
sold item, either alone is dropped and counted"), the legacy-width paragraph
now names 12 and 14. `docs/samples/items-full.csv` gains the four columns
with two rows sold (one at a gain, one at a loss) and `README.md` says so;
`items-partial.csv` stays at 12 (the pre-002 fixture, forever);
`items-resaved.csv` **stays at 14 deliberately** and becomes the 14-boundary
fixture, pinned by width in `DocsSampleTests` exactly as the 12-column file
is. `specs/011-data-export/plan.md` §"The canonical CSV schema": the italic
note under the heading names `006`'s four columns, and "Recorded schema
decisions" gains one bullet — the columns, the pair rule,
`itemSchemaBoundaries = [12, 14]`, and one line on positional order: sold
rows are written after the owned rows, so an item returned to the collection
after a CSV round trip lands at the end of Custom order, not at its former
place — inherent to the schema's "no `sortOrder` column" decision and outside
this spec — appended, nothing above it edited (the append rule applied to the
prose too).

**Testable claims** (`ExportSchemaTests`, `ImportSchemaTests`,
`DocsSampleTests`, `SettingsViewModelTests`, `ExportWiringTests`): headers
and boundaries pinned by literal (G24); a sold record's row carries the four
cells and an owned one's are blank (mutation: write the price for owned →
red, G25); a 14-column header imports with the four blank, a 12-column one
too, a 13- or 17-column one fails (G26); the pair rule's five cases — both,
date only, price only, all blank, place only — with the counted-default
totals 0/1/1/0/1 (mutation: count per cell → the date-only case reads 1
still but a date-unreadable-plus-price case reads 2 → red; the fixture
carries that row, G27); a sold row round-trips CSV → import → `Item.sale`
equal; the Settings CSV equals the unfiltered Custom list CSV with a sold
item present (G28); the everything-PDF's `itemCount` and totals exclude the
sold item (G16); `OverflowDropdown` rows gate on `canExportCSV` and
`canExportPDF` once each, Import and Settings ungated (G29); the samples
import exactly as documented, the sold rows included (G30).

## 8. UI-test seeding and UI tests

`UITestSeed` gains `soldArgument = "-seedSold"`, `shouldSeedSold(mode:arguments:)`
(`mode == .ephemeral && arguments.contains(soldArgument)`), and `sold(into:now:)`:
one owned item ("Leica M6", Photography/Cameras, paid $2,200, value $2,600,
desire 5), two sold — "Telecaster" (Music/Guitars, paid $900, sold $1,250 on
`now − 3 d` at "eBay", note "Sold with the hard case") and "Blues Junior"
(Music/Amps, paid $700, sold $550 on `now − 12 d` at "Reverb") — and one
wishlist item ("Summicron 35mm f/2", $2,400) with the Telecaster's sale
recorded toward it, written through `ItemSaleStore.markSold` so the seed can't
produce a shape the app can't. Totals the tests read: 2 sold · $1,800 · +$200
vs paid; Telecaster above Blues Junior; "Gain $350", "Loss $150"; the plan's
Sold figure $1,250 · 1 item — the seed's test reads those totals through
`SaleOutcome.totals`, not a second hand-written sum. `TroveApp` gets a second
guard under the first, same shape. `UITestSeedTests` mirrors the existing
gate tests (`seedsOnlyTheInMemoryStoreAndOnlyWithItsOwnArgument`) for the sold seed and
the "called once under its guard, argument spelled only in `UITestSeed`"
scan; `theAppCallsTheSeedOnceUnderTheGuardAndReadsTheFlagOnce` stays green
because `shouldSeedSold(mode:` does not match its `shouldSeed(mode:` anchor.

UI tests (`TroveUITests`, all offline):
- `testTheSoldCardLandsOnTheSoldSideWhichListsSalesMostRecentFirst`
  (`-seedSold`): the Overview shows `dashboard.soldCard` with "2 items ·
  $1,800"; tap → the Items tab with the switch on Sold; Telecaster's row
  above Blues Junior's; the rows' combined labels contain "Gain $350" and
  "Loss $150"; the summary reads "2 sold · $1,800 · +$200 vs paid";
  `sortOptions.items` absent, `moreActions.items` present; switch to Owned →
  the Leica row, `sortOptions.items` present. Mutation: reverse the sold
  comparator → the order assertion red.
- `testMarkingAnItemSoldMovesItToTheSoldSideAndReturnRestoresIt`
  (`-uiTesting`): add an owned item through the form (the existing helpers),
  open it, the menu's **Mark as sold…**, the sheet with the price blank
  (no value), type 500, confirm → `sold.mark` visible, the menu offers **Edit
  sale…** and **Return to collection…** and not **Edit**; back → Owned side
  empty ("Everything's sold." — spec Decision 12, amended 2026-09-14; §8 was written before T015a); Sold side → the row; open it, **Return to
  collection…** → the alert → **Return** → the Owned side lists it again and
  the Sold side shows "Nothing sold yet". Mutation: `returnToCollection`
  keeping `soldDate` → red.
- `testASellPlanRowSoldFromThePlanShowsTheSoldFigure` (`-seedSellPlan`):
  the seeded plan; Blues Junior's row action **Mark as sold…** → confirm the
  prefilled price → the header shows the **Sold** figure "$640" captioned "1
  item", the candidates no longer list Blues Junior, the Sold section lists
  it. Mutation: `markSold` passing `toward: nil` → the figure absent → red.
Run twice back to back. Identifiers: `items.sideSwitch`, `dashboard.soldCard`,
`sale.sheet.price`, `sale.sheet.confirm`, `sold.mark`, `sellPlan.soldFigure`,
`sellPlan.row.markAsSold`; the menu rows are matched by label.

## 9. Privacy and docs

`PRIVACY.md`'s storage table enumerates item fields ("names, categories,
prices, dates, conditions, notes, ratings"), so per P9 the first row gains
"and, once you mark something sold, what it sold for, when, where and any
note" — same row, same "yes, to your private iCloud database". No new
service, no notice, no "what leaves" change. `PrivacyPolicyTests` gains one
containment check on that phrase (mutation: remove it → red, G31). README's
feature list gains one sentence on the branch; ROADMAP/DECISIONS at
close-out (§"Docs on the spec branch", the `005` split).

## 10. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `CloudKitSchemaTests` validates `Item` with the five additions | one is declared non-optional without a default |
| G2 | `ModelTests`: `sale = nil` clears four fields + the link, second context | the setter leaves the link |
| G3 | `WishlistDeletionTests`: deleting the wanted item leaves the sale, link nil | the relationship's rule is not `.nullify` |
| G4 | `ItemSaleStoreTests`: a sale empties every plan selection | the `plannedForWishlistItems = []` line is dropped |
| G5 | `ItemSaleStoreTests`/`ItemDetailViewModelTests`: market rows cleared, another item's kept | the clear is dropped |
| G6 | plan link set only from the plan | `toward:` ignored, or the detail passes a plan |
| G7 | mark + return leaves `sortOrder` and the Custom slot unchanged | return resets `sortOrder` |
| G8 | a sold matched item is not a refresh target | the `soldDate == nil` clause is dropped |
| G9 | every stored sale has both date and price | a writer sets one alone |
| G10 | `SellPlanFramingTests`: three independent figures, cost unchanged | sold is subtracted from the cost |
| G11 | the cue reads Selected + Sold | it reads Selected alone |
| G12 | a sold item is never a candidate | the sold filter in `load` is dropped |
| G13 | `ItemListViewModelTests`: sold absent from every Owned figure, present in `soldItems` | the split is dropped |
| G14 | Sold-side order: date desc, name, id | the comparator is reversed or unterminated |
| G15 | CSV: owned then sold, both under the Owned side's *visible* narrowing | sold rows unfiltered while a chip shows, or omitted |
| G16 | PDF entries and cover totals exclude sold, both paths | a sold record reaches `PDFEntry` |
| G17 | `ItemDeleteCopyTests`: the sold message omits "sell plan", keeps the rest | the owned message is reused |
| G18 | `SaleFormViewModelTests`: future date refused, past-before-purchase accepted | `dateInFuture` uses `<` or the check is dropped |
| G19 | prefill: current value for `.mark`, blank without, the sale for `.edit` | the seed reads the wrong source |
| G20 | `markSold` leaves the item's own fields, photos and match untouched | the writer clears the match |
| G21 | `editSale` keeps the plan link | edit routes through `markSold(toward: nil)` |
| G22 | `DashboardViewModelTests`: reconciliation with a sold item present | sold counted in `apply` |
| G23 | sold figures follow scope; `hasSales` false when none in scope | scope filter skipped for sold |
| G24 | `ExportSchemaTests`: headers and `[12, 14]` pinned by literal | a boundary is added speculatively |
| G25 | owned rows blank in the four cells, sold rows filled | the price is written for owned |
| G26 | `ImportSchemaTests`: widths 18/14/12 accepted, 13 and 17 refused | the gate accepts any prefix |
| G27 | the pair rule's five cases and their counts 0/1/1/0/1 | one default per cell, or a lone half accepted |
| G28 | Settings CSV == unfiltered Custom list CSV with a sale present | the two orderings diverge |
| G29 | `ExportWiringTests`: one gate per export row, Import/Settings ungated | a gate is shared or dropped |
| G30 | `DocsSampleTests`: `items-full.csv` sold rows; `items-resaved.csv` width 14 | a sample is regenerated at the wrong width |
| G31 | `PrivacyPolicyTests`: the storage row names the sale details | the phrase is removed |
| G32 | `SaleOutcomeTests` + scan: `totals` sums count/proceeds/delta; both view models read it | a view model sums `salePriceCents` itself |
| G33 | `ItemListViewModelTests`: `show(_:)` clears every narrowing on a side change | the filter survives the switch — *Superseded by `014-sold-side-parity` (its spec, Decision 4): the narrowing now survives the switch by design, and `014`'s guards assert per-side state instead.* |

Every guard is mutation-verified before it lands (`CLAUDE.md` Testing); the
task's Done note records what was broken and what went red. Every source scan
this spec adds first asserts its anchor was found (`#require` on the anchor
count, `#expect(!literals.isEmpty, …)` on a literal scan — the
`SellPlanFramingTests` shape), so none can pass over a file that lacks the
thing it guards. Two things the
suites cannot see and the device pass (T019) instruments instead: that the
sale sheet's `DatePicker` really refuses a future day on screen, and that a
`.sheet(item:)` over a row's `Item` presents once per tap (the `002`/`005`
`.task`-in-a-sheet lesson — a probe in `ItemSaleStore.markSold`, removed
before the suites run).

---

## As built (2026-09-15, at T020's close-out)

Where the shipped code differs from the sections above, how the three readings
stand, and what became of each Q-item. Twenty tasks with ten sub-lettered
additions; nothing here re-opens a decision.

**The readings, R1–R3.** All three were confirmed at the sign-off and none was
overturned in implementation.

- **R1 — a scoped Sold card lands on the whole Sold side** — confirmed twice:
  at the sign-off, and by the person, who was told at the Phase 5 pause that
  this is how it behaves (the tasks' own handoff note said they would feel it
  before they read it) and accepted it. Q15 made it structural rather than
  conventional: `show(_ side:)` clears every narrowing, so the Sold side can
  never carry a category it does not show.
- **R2 — Delete All removes sold items too** — confirmed and untouched;
  `SettingsViewModel.itemCount` still counts every `Item`
  (`confirmDeletesEveryItemAndOnlyItems`), and the device pass watched an
  all-items delete take the sold ones with it.
- **R3 — one counted default per dropped sale** — confirmed and pinned;
  `ImportSchemaTests.theSalePairRuleCountsOneDefaultPerDroppedSale` counts one
  however many of the four sale cells were non-blank, and the per-cell mutation
  goes red at 2 ≠ 1.

**Deviations and additions, in the order they happened.**

- **The Sold mark sits above the photo hero**, not "above the category/name"
  as §5 and T014's (pre-design) task line say. The approved artboards place it
  there; T014 shipped to the artboards and declared it.
- **`SaleCopy` is a plain string table, so the sheet's titles are four
  constants**, not the `sheetTitle(mode:)` function §5 sketched (T004): the
  mode is a view-model type and `Trove/Models/` names none. §5's line was
  corrected in place at the Phase 1 review.
- **The Sold side's empty state is two strings, not one** —
  `nothingSoldHeadline` / `nothingSoldDetail` (T002a, the Phase 1 review's one
  blocking finding: the plan asked for headline + detail, T002 shipped one
  `emptyState`).
- **`ItemDeleteCopy.message(isSold:)` had three readers, not two** (T002);
  `DeleteAllCopyTests` pins the owned message word for word.
- **`ItemSaleStore.markSold` runs the throwing market clear first** (T003), so
  a refused clear leaves the item unwritten rather than half-sold.
- **The emptied Owned side got its own state mid-spec** — `ListEmptyReason
  .everythingSold` and "Everything's sold." / "Add something new." (T015a),
  spec Decision 12, taken by the person at the Phase 4 pause. §4's paragraph
  was written then, not at planning.
- **`sellPlan.soldFigure` did not ship with T017.** T018's UI test read three
  positional static texts instead; the Phase 5 review blocked on it and T017a
  gave the Sold cell `.accessibilityElement(children: .combine)` and the
  identifier §3/§8 always named, with the UI test reading that one label (the
  `toward: nil` mutation still turns it red).
- **`SaleTotals.isLoss` was added at T017a.** The loss rule over a *sum* had
  grown two homes — `SoldCard` built a `SaleOutcome` over the delta and
  `ItemListView.soldMeta` read the sign directly — so it now lives once in
  `Sale.swift` beside `SaleOutcome.isLoss`, read by both, with
  `ItemListView.swift` added to the colour scan's surface list and the scan's
  skip-if-absent arms dropped now that every listed surface exists.
- **The Sell Plan row's Mark as sold… is a footer strip with a 44 pt hit
  area** (T017, corrected at the Phase 5 re-review from the design notes' first
  figure), taken as 4 pt of bottom padding so the area grows downward only and
  never over the toggle above it; the card is 4 pt taller than before. The
  strip's tap target spans the card's width — observed on the device, accepted
  as unambiguous.
- **`soldSummaryLine` is a non-optional `String`, and the Sold side's line is
  always shown** (T018b, spec Decision 13, which replaces Decision 11's
  hide-at-zero). At zero sales it reads "0 sold · $0" — the realised part
  dropped rather than set to "+$0 vs paid", because a gain measured over no
  sales states a measurement where there is none. The reason is a measurement,
  not a preference: with an empty collection the Owned/Sold switch jumped
  **19.7 pt** between sides, and only then (with sales seeded, neither symptom
  appears — `-seedSold` alone could not reproduce the person's report).
- **The switch's slide was fixed structurally, and the plan's suspected cause
  was wrong** (T018b). The row swap was not to blame: a `matchedGeometryEffect`
  pair across an `if isActive` insert/remove is a *structural* change that
  `.animation(_:value:)` never covered, so the fill crossfaded — a 22 %
  brightness dip while the 19.7 pt travel stepped at about 20 Hz. It ships as
  one `Rectangle` with an animatable `.offset` at 0.2 s; measured from a screen
  recording afterwards, the edge moves monotonically over 9–11 distinct frames
  at 60 Hz in 164 ms, flat brightness, 0 pt of travel for the switch itself.
  The design notes' Motion row went 0.25 → 0.2 s. **Worth carrying forward**:
  any other `matchedGeometryEffect` across an insert/remove in this app is a
  silent crossfade, not the motion it looks like in the source.
- **A Sell Plan keeps its Sold section under the empty state, and each sold row
  opens with a compact SOLD tag** (T018c, spec Decision 14). §3 and both
  artboards put the section under the candidates only; spec P15 lists the sold
  items unconditionally; with every candidate sold the section vanished while
  the header still showed the Sold figure. The person settled it at the Phase 5
  pause. Two consequences: those rows now differ from `SellPlanThree.png` by
  the tag, and the plan's sold row's combined accessibility label opens with
  "Sold" rather than the name — which broke a UI helper matching
  `BEGINSWITH "<name>,"` (T019's finding F1, fixed at T018d by
  `soldRow(in:named:precededBy:)`; the Items tab's rows keep the name-first
  default). **Left open, deliberately**: inside the `ScrollView` the empty state
  sits above the section rather than centring, and its copy ("Nothing to sell
  yet — Add the gear you own…") reads oddly directly above a list of sold rows.
  That is a copy question for the person, not a defect — as is the other item
  their walkthrough left open: they did not find **Mark as sold…** in the item
  page's "…" menu, which is where spec Decision 4 places it, and whether a
  visible control is wanted has not been answered.
- **Xcode 27 arrived between Phase 4 and Phase 5**, and HEAD did not build
  under it. Three one-line fixes went in ahead of T013, outside any task's file
  list (two `Shape` conformances needing `nonisolated` under
  `InferIsolatedConformances`; one chained `#expect` that timed out the
  type-checker). T018a then repointed `scripts/verify.sh`'s `DESTINATION` at an
  iPhone 18 Pro on iOS 27.0 and took the repo's own sources from 11 warnings to
  0 — `SyncMonitor.observer` gains `@ObservationIgnored` (the compiler's own
  fixit does not compile on an `@Observable` stored property),
  `StockPhotoCredit`'s deprecated `Text + Text` becomes interpolation, six
  discarded fixtures in four test files get `_ =`, and `launchApp()` in the UI
  target gains `@MainActor`. One SDK-side warning (AppIntents metadata, no repo
  path) remains. `DECISIONS.md` carries the operational facts for the next
  upgrade; the lesson for the log is that an incremental build hides warnings
  from unchanged files, so the count must be taken after a `clean`.

**Q1–Q15 as shipped.**

- **Q1 — the sale as four fields and a relationship on `Item`, not a `Sale`
  model**: shipped as written. One CloudKit record, one stored-property
  predicate, and Return is nil-ing five fields with no orphan to leak.
- **Q2 — the names and the one sold predicate**: shipped as written
  (`soldDate`, `salePriceCents`, `saleLocation`, `saleNote`,
  `soldTowardWishlistItem`; sold iff `soldDate != nil`).
- **Q3 — one writer, `ItemSaleStore`**: shipped; every entry point and both
  later actions go through its three statics, callers save.
- **Q4 — the side on the list view model, the router carrying a request**:
  shipped; Owned at every launch is true by construction, not by a reset.
- **Q5 — the exports**: shipped; `canExportCSV` counts the *narrowed* halves
  (declared at T009, so a chip matching nothing on either side disables the row
  rather than staging a header-only file — `011`'s criterion 2), which is the
  one place Q5's "either side non-empty" reads looser than the code.
- **Q6 — the import pair rule**: shipped, both stated asymmetries included (a
  negative price is unreadable to `012`'s parser, so the sale drops and counts;
  a future sold date imports as written, since the parser has no clock).
- **Q7 — Delete All includes sold items**: shipped, unchanged.
- **Q8 — the sold detail state hides what would act**: shipped; the match is
  kept and only the device-local rows are cleared, so Return resumes refreshing.
- **Q9 — Sold-side order and empty reason**: shipped; `.nothingSold`, plus
  `.everythingSold` which Decision 12 added later.
- **Q10 — the second UI-test seed `-seedSold`**: shipped, gated on the store
  the app actually built being `.ephemeral` and never on a second flag read;
  `-seedSellPlan` and `-uiTesting` alone keep the starting states every
  existing UI test was written against.
- **Q11 — copy and colour in one place**: shipped, with the Design pass's form
  (T008a, Decision 11) replacing the placeholder outcome strings: one body in
  `rowOutcome`, `pageOutcome` forwarding to it. The colour rule stays on the
  model, now in two shapes — `SaleOutcome.isLoss` for one sale and
  `SaleTotals.isLoss` for a sum (T017a).
- **Q12 — the sale price rules mirror the form's purchase price**: shipped;
  both the picker's bound and the view model's check, as planned.
- **Q13 — `updatedAt` bumps on all three writes**: shipped and guarded.
- **Q14 — the Sell Plan reads its sales off the relationship**: shipped;
  `selectedValueMeetsCost` keeps its name and reads Selected plus Sold.
- **Q15 — changing side clears every narrowing** (the sign-off's blocking
  finding): shipped as `show(_ side:)` with `side` `private(set)`, so binding a
  control to it does not compile.

**What was verified by hand rather than by a test**, and what is still
outstanding: the sale sheet's presentation count (a file probe inside
`ItemSaleStore.markSold` — Cancel 0, swipe-down 0, a host re-render 0, confirm
1 from each host — removed before the suites ran); the date picker's disabled
future days (a screenshot, the unit suite holding the past-midnight edge); the
switch's motion (a screen recording with per-frame timing, since a screenshot
cannot show it); and every surface against its artboard, by a simulator agent
at each screen task. **Still the person's**: a sale arriving on a second device
(criterion 15) and the VoiceOver reading of the new surfaces (criterion 16),
including the plan's sold row now announcing "Sold" first.

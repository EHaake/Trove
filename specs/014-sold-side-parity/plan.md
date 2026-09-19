# 014 — Sold-Side Parity and Mark as Sold on the Swipe — Technical Plan

**Status**: **Signed off** (2026-09-16) — drafted by the `sdd-planner` at the top tier, reviewed by the `skeptical-reviewer` at the top tier: three blocking findings (a hidden-narrowing leak into the Owned empty state, by-eye simulator steps in three tasks, a tie-break guard that could not reliably go red) fixed and re-reviewed in one round, verdict sign off. Awaiting the person's approval of the spec-conformance summary.

Drafted by the `sdd-planner` (Fable 5.1, high effort — experiment 1's top
tier) against the approved `spec.md` (Approved 2026-09-16) and the code as it
stands on `main` at `1aeb741` (`fix/006-post-merge` merged), from which
`014-sold-side-parity` branches. Planning proposals (Q1–Q13) become decisions
on plan approval, the way `006`'s Q-items did. Two readings of the spec that
the plan had to take a side on are under **Readings for sign-off**; neither is
a product fork, each is stated so the reviewer can overturn it.

## Context

Spec 014 puts **Mark as sold…** on the Items list's leading swipe, gives the
**Sold side** the Owned side's search field, category chips and Sort By (with
its own sort options), makes **each side keep its own narrowing and sort**
across a switch, and moves the sold page's **Sold mark under the item's
name**. Decisions 1–6 and P3–P11 settle the behaviour; this plan settles the
technical shape, and the whole of it is inside `ItemListViewModel`,
`ItemListView`, `ItemDetailView` and their tests. No schema, no network, no
export format, no new service, no `.pbxproj` edit (the one new asset is an
imageset inside the existing catalogue, §5). No constitution amendment.

What this spec reverses in `006` — Decision 4/criterion 1 (the swipe stays
delete-only), P16/Non-goals (no narrowing or sorting on Sold) and Q15/G33
(switching sides clears the narrowing) — is reversed here *by design*, and
the `006` documents get one-line pointers at each (§9, T001). Every test that
pinned the old rule is **rewritten to pin the new one**, never loosened (Q12).

## Readings for sign-off (not open questions — the plan builds to each)

- **R1 — From the Sold side, a CSV's owned half is written in Custom order.**
  The spec says the owned rows go "in visible order" and that a file exported
  with no narrowing on the side on screen is byte-identical to Settings' CSV
  "whatever sort either side is showing" (criterion 10). From the Owned side
  "visible order" is the Owned sort, as `011` wrote it, and `013`'s identity
  holds there under Custom as it always has — the spec calls the CSV rule
  "unchanged in words". From the Sold side no owned row is visible, so
  "visible order" names nothing; P10's own reasoning applies to that half
  ("the view's sort is a reading aid, the file's order is the record's") and
  the file is Settings' bytes whatever either side's sort shows. Guard G14.
- **R2 — The PDF follows the on-screen side's narrowing too**, owned half
  only, same coverage label, Custom order from the Sold side (R1). (Confirmed
  and extended 2026-09-18: it now names the Owned scope; the sold document
  applies the same rule to the sold half — §4a, R3.) The spec
  says only "the PDF stays owned-only"; P11's principle — a file is never
  narrowed by something not on screen, and `011`'s rule that the document
  never claims more than the screen showed — decides the rest. The
  alternative (the whole owned collection under a "Cameras" label, or a
  label the spec doesn't have) would make the cover lie. On the Owned side
  nothing changes: the rows and the cover are exactly today's. Guard G15.
  **This one the spec did not say**, so the person hears it in plain words
  at the Phase 2 pause (the tasks' handoff note carries the sentence) and
  can overturn it there.

## Proposed at planning (Q1–Q13) — approved on plan approval unless overturned

- **Q1. Per-side state is two `Narrowing` values and two sort properties,
  behind the existing property names.** `ItemListViewModel` holds a private
  `ownedNarrowing` and `soldNarrowing` (`struct Narrowing { categoryFilter,
  searchText, showsOnlyUnvalued }`) and a second sort property
  `soldSortOrder`. `categoryFilter`, `searchText` and `showsOnlyUnvalued`
  become computed get/set properties over **the side on screen's** value, so
  the search field's binding, the chips, the empty-state actions, the
  router's `apply` and every existing test keep their spelling — and "what
  the controls show is always the side on screen" is true by construction:
  there is no way to read or write the hidden side's narrowing from outside
  (§1). Nothing is stored: both sides start clean at every launch (P8).
- **Q2. Un-valued is Owned-only structurally.** `showsOnlyUnvalued`'s setter
  refuses the write while the Sold side is on screen (returns without
  writing; Owned's copy is untouched), so `soldNarrowing.showsOnlyUnvalued`
  can never be true, the shared chip row's `if viewModel.showsOnlyUnvalued`
  never renders the chip there, and `narrowed(_:by:)` needs no side check.
  No legitimate writer exists on the Sold side (the chip renders only when
  it is on; the router's `.unvalued` calls `show(.owned)` first; the
  `everythingIsValued` action is Owned's), so a refusal, not a trap. G6.
- **Q3. `show(_ side:)` no longer clears; the router's `apply` clears only
  inside the Owned cases.** `show` sets the side and reloads — that is all
  (Decision 4 replaces `006` Q15). `ItemListView.apply` today writes
  `viewModel.searchText = ""` *before* the switch, which under Q1 would wipe
  the Sold side's query on the way to an Owned request — a leak the spec
  forbids. The clear moves after `show(.owned)` in `.category` and
  `.unvalued`; `.sold` stays exactly one `show(.sold)` call (P9: the side as
  it stands). G4, G20.
- **Q4. `SoldSortOrder`, nested beside `SortOrder`, with the spec's
  labels.** `Date sold`, `Price ↓`, `Price ↑`, `Paid ↓`, `Paid ↑`, `Gain ↓`,
  `Gain ↑`, `Name` — the placeholders kept (Decision 5), because the arrow
  convention is the Owned side's: `↓` is largest first, as `Value ↓` already
  reads, so `Gain ↓` puts the largest gain first and the largest loss last
  and `Gain ↑` the reverse, which is the spec's one fixed rule ("a reader can
  tell which end a loss sorts to") carried by the glyph, never by colour.
  `Name` rather than the wishlist's `Alphabetical` for the badge's width and
  the spec's word. Comparators in the `attributeOrder ?? standing` shape the
  Owned side uses, the standing order being `areInSoldOrder` (P7); nil-safe
  in the Value pair's nil-last block. The whole comparator is a **static**
  `areInSoldOrder(_:_:under:)` that the instance sort calls, so a test can
  hand it two items directly — the tie-break's guard cannot run through a
  fetch, whose order is indeterminate (the `CLAUDE.md` tie-break lesson) (§2).
- **Q5. Chips per side, under the existing names.** `categoryOptions` and
  `categoryLabels` become computed over the side on screen from two stored
  pairs built in `load()` — Owned's from the owned half as today, Sold's from
  the sold half — so `categoryChips` and `exportCoverageLabel` change no
  spelling and the Sold side never offers a category nothing sold sits in.
- **Q6. The Sold side's summary follows the narrowing; the controls gate is
  the view model's.** `soldTotals` is summed over the narrowed `soldItems`
  (P4; the Dashboard's card keeps the whole side through its own load), so
  "0 sold · $0" is what a narrowing that matches nothing reads. A new
  `soldTotalCount` (sold before narrowing) is the Sold side's `totalCount`,
  and `offersNarrowingControls` (`side == .owned ? totalCount > 0 :
  soldTotalCount > 0`) is the one gate both sides' controls open on.
- **Q7. The Sold side's empty reason goes through `ListEmptyReason.reason`**
  with the sold half's counts and the Sold narrowing, and `.nothingAdded` is
  mapped to `.nothingSold` — the exact shape `ownedEmptyReason` uses for
  `.everythingSold`. `reason(...)` and its precedence are untouched;
  `stillSyncing` still wins over an empty side and still yields to a typed
  query (P5). `ListEmptyReason.nothingSold`'s doc comment is corrected.
- **Q8. Exports read two `exportable…` rows sets under the on-screen
  narrowing.** `exportableOwnedItems` = the owned half narrowed by the side
  on screen, in visible order on Owned and Custom order from Sold (R1);
  `exportableSoldItems` = the sold half narrowed the same way, **always** in
  `areInSoldOrder` (P10) — never `soldItems`, whose order is the view's. The
  CSV is the first then the second; the PDF is the first (R2); the two
  `canExport…` gates read them. On the Owned side `exportableOwnedItems`
  equals `items` row for row, so `006`'s G15/G16/G28 stay green unchanged.
- **Q9. The swipe: "Sell" on the button, "Mark as sold…" to VoiceOver, brass
  mid-tone, a template tag icon, the sheet hosted by the list.** The visible
  word is `SaleCopy.swipeSell = "Sell"` — "Mark as sold" does not fit 76 pt
  beside a glyph at the swipe's label size — and the button's
  `.accessibilityLabel` is `SaleCopy.markAsSold`, the menu row's own name, so
  the same action is announced the same way from both places (criterion 12).
  **That a modifier on a swipe-action `Button` overrides its `Label`'s text
  is a platform claim the suites cannot check**; the device pass reads the
  accessibility tree (§8). If the modifier is ignored, the spoken name is the
  `Label`'s "Sell" — criterion 12 asks for *a name*, and "Sell" is one — so
  the implementer keeps the modifier, does not stop, and the `DECISIONS.md`
  entry records which name shipped. Tint `accentBrassMid`: the one brass that is mid-tone in *both* palettes
  (named in `010` for exactly this between-case), so the white label reads
  the same on either appearance; brass, not rust, because the action is not
  consequential (a sheet follows), and not a third neutral because three
  grey buttons in a row would be one gesture with no legible middle. If the
  device pass finds the white label illegible on it in either appearance,
  that is a decision review, not a swap the implementer makes. Glyph:
  `ActionSell`, a price-tag outline in `action-edit.svg`'s house style
  (24 viewBox, 1.5 stroke, `#000`, template, vector preserved) — the menu row
  already wears SF `tag`, so the swipe wears the same sign. The sheet is
  `.sheet(item: $itemBeingSold)` on `ItemListView` composing `SaleFormView`
  over a new `ItemListViewModel.makeSaleFormViewModel(for:)` — seeded
  exactly as the detail and the plan seed theirs (P1) — confirming into a
  new `markSold(_:sale:)` that goes through `ItemSaleStore.markSold(toward:
  nil)`. No second `Menu`; `MenuPolicyTests` unchanged (§5).
- **Q10. The header gate literal changes, and `ImportWiringTests` takes a
  per-screen anchor.** `if viewModel.totalCount > 0, viewModel.side ==
  .owned` (spelled twice) becomes `if viewModel.offersNarrowingControls`
  (spelled twice). `ImportWiringTests.theOverflowControlSitsOutsideEveryEmptyCollectionGate`
  anchors on the prefix `if viewModel.totalCount > 0` across both list
  screens; it gains a `(path, gate)` pair so the Items screen's anchor is the
  new literal and the wishlist's stays — the assertion (sort inside, overflow
  outside) is unchanged. `DropdownWiringTests`' anchors (`sortControl`'s body,
  `case .sort:` + `SortDropdown(` in the host) hold as written.
- **Q11. The Sold mark moves inside the same `VStack`**, after
  `titleBlock(for:)` and before `statPair(for:)` in the sold branch, so the
  stack's `sectionGap` is the gap above and below it (Design requirements)
  and no new spacing is introduced. `SoldMark.swift` is untouched but for its
  header comment; `tokens.md`'s Position row gets an "As implemented" cell.
- **Q12. Tests that change meaning are rewritten, not weakened**, each named
  in the task that owns it: `theSoldSideRendersNoSortControlAndNoSearchField`
  → both sides share one gate; `theOwnedRowsSwipesDoNotOfferMarkAsSold` →
  the leading swipe is Edit, Sell, Copy in that order and the trailing stays
  delete-only; `switchingToSoldClearsEveryNarrowing` /
  `switchingBackToOwnedClearsEveryNarrowingToo` → each side keeps its own
  (G4); `theSoldSidesEmptyStateIsNothingSoldOrStillSyncing` → extended with
  the narrowed cases (G9); `theSoldBranchStampsTheMark` → extended with the
  order (G21); the Sold-card UI test's "Sort By must not show on the Sold
  side" → it must, reading "Date sold" (G24). `theSoldRowsCarryOnlyTheTrailingDelete`,
  `theSoldRequestIsExactlyOneShowCall`, `theSwitchReportsThroughShowAndBindsToNothing`
  and `askingForTheSideAlreadyOnScreenLeavesTheFilterAlone` stay as they
  are — still true, still falsifiable.
- **Q13. No seed change.** `-seedSold` (a Leica owned at $2,600 in
  Photography/Cameras; a Telecaster sold at a gain in Music/Guitars three
  days back; a Blues Junior sold at a loss in Music/Amps twelve days back)
  already has two sold categories, two prices, two outcomes and one owned
  row with a value to prefill — everything §8's UI tests read.

---

## Layout and files

No new production Swift file. New: `Trove/Assets.xcassets/ActionSell.imageset/`
(`Contents.json` + `action-sell.svg`, template) and `design/icons/action-sell.svg`
— inside the existing catalogue, so no `.pbxproj` edit and no Xcode step; if
the build cannot find the image, stop and flag rather than editing the
project file. New test file: `TroveTests/SoldSortOrderTests.swift`.

Changed: `ItemListViewModel` (§1–§4), `ItemListView` (§5–§6),
`ItemDetailView` (§7), `SaleCopy` (§5), `SoldMark` and `ListEmptyReason`
(comments only); tests `ItemListViewModelTests`, `ItemListSidesWiringTests`,
`SoldStateWiringTests`, `ImportWiringTests`, `SettingsViewModelTests`,
`SaleCopyTests`, `TabIconTests` (or a sibling for action icons),
`TroveUITests`; docs `specs/006-mark-as-sold/spec.md` + `plan.md` (pointers),
`design/tokens.md`, `README.md`, `specs/ROADMAP.md`, `DECISIONS.md`, and
this spec's `spec.md` at close-out.

---

## 1. Per-side state on `ItemListViewModel` (foundational)

```swift
/// One side's narrowing, kept while the other side is on screen (spec 014
/// Decision 4, replacing 006 Q15's clearing). Plain state, never stored:
/// both sides start clean at every launch (P8).
struct Narrowing: Equatable {
    var categoryFilter = ""
    var searchText = ""
    /// Owned only — the Sold copy never holds `true` (Q2).
    var showsOnlyUnvalued = false
}
private var ownedNarrowing = Narrowing()
private var soldNarrowing = Narrowing()
/// The side on screen's narrowing: what the controls show and what a file
/// exported from here follows (P11).
private var narrowing: Narrowing {
    get { side == .owned ? ownedNarrowing : soldNarrowing }
    set { if side == .owned { ownedNarrowing = newValue } else { soldNarrowing = newValue } }
}

var categoryFilter: String { get { narrowing.categoryFilter } set { narrowing.categoryFilter = newValue } }
var searchText: String     { get { narrowing.searchText }     set { narrowing.searchText = newValue } }
var showsOnlyUnvalued: Bool {
    get { narrowing.showsOnlyUnvalued }
    set { guard side == .owned else { return }; ownedNarrowing.showsOnlyUnvalued = newValue }   // Q2
}
var sortOrder: SortOrder = .purchaseDate          // Owned's — unchanged, "Date" still means purchase date
var soldSortOrder: SoldSortOrder = .soldDate      // Sold's (§2)

/// The one way the side changes: sets it and reloads. Clears nothing (Q3).
func show(_ side: Side) { self.side = side; load() }

private var owned: [Item] = []                    // the split halves, unnarrowed — the exports read them (§4)
private var sold: [Item] = []
private(set) var soldTotalCount = 0               // sold before narrowing: the Sold side's `totalCount`
private var ownedCategoryOptions/Labels, soldCategoryOptions/Labels   // built in load() (Q5)
var categoryOptions: [String]        { side == .owned ? ownedCategoryOptions : soldCategoryOptions }
var categoryLabels: [String: String] { side == .owned ? ownedCategoryLabels : soldCategoryLabels }
/// "Controls need a list to narrow" — one gate, both sides (Q6).
var offersNarrowingControls: Bool { side == .owned ? totalCount > 0 : soldTotalCount > 0 }
/// What the sort badge shows for the side on screen.
var visibleSortLabel: String { side == .owned ? sortOrder.label : soldSortOrder.label }
```

`load()` fetches once and splits as today, then: `items = narrowed(owned, by:
ownedNarrowing).sorted(by: isOrderedBefore)`; `soldItems = narrowed(sold, by:
soldNarrowing).sorted(by: isInSoldOrder)`; `soldTotals =
SaleOutcome.totals(over: soldItems)` (narrowed, P4); the two category pairs
from their halves; `soldTotalCount = sold.count`. `narrowed(_:by:)` takes the
narrowing explicitly so no call can read the wrong side's. `ownedEmptyReason`
reads `ownedNarrowing`'s fields by name, not the computed properties, and
**its Everything-sold guard reads `soldTotalCount > 0`, never
`!soldItems.isEmpty`** — `soldItems` is now the *narrowed* sold half, and a
query left on the Sold side that matches nothing would otherwise turn an
emptied Owned side back into a first launch ("No gear yet"), which is the
hidden side leaking into the visible one that Decision 4 forbids and `006`
Decision 12 answered. `soldEmptyReason` (Q7) reads `soldNarrowing`'s. `canReorder` is unchanged in
spelling (its `side == .owned` leads, so the computed properties it reads are
Owned's). `@Observable` tracks the computed properties through the stored
ones they read, so `$viewModel.searchText` and `.onChange(of:
viewModel.searchText)` keep working — note the `onChange` fires once on a side
change (the visible query changes value), which is one extra `load()`, not a
defect.

**Testable claims** (`ItemListViewModelTests`, the "changing side" suite
rewritten): set Owned's chip, query, un-valued and a non-default sort;
`show(.sold)` → all three narrowing fields read empty and `soldSortOrder ==
.soldDate`; set Sold's query, chip and `Price ↑`; `show(.owned)` → Owned's
four values exactly as set and `items` narrowed by them; `show(.sold)` →
Sold's three as set and `soldItems` narrowed (mutation: the old clears back in
`show`, or one shared `Narrowing` → red, G4). A fresh view model has both
sides clean and `.owned` on screen (G5, extending `aFreshViewModelOpensOnOwned`).
On Sold, `showsOnlyUnvalued = true` reads false afterwards and Owned's copy
is unchanged (mutation: drop the guard → red, G6). Sold chips are the sold
half's categories only, Owned's unchanged, and `categoryOptions` follows the
side (mutation: build both from `all` → red, G7). `offersNarrowingControls`:
Owned with 0 owned/1 sold → false; Sold with 1 sold → true; Sold with 0
sold/1 owned → false (G8). An Owned side emptied by selling still reads
`.everythingSold` after the Sold side was left with a query matching nothing
(`show(.sold)`, `searchText = "zzz"`, `show(.owned)`), and `.nothingAdded`
only when nothing was ever sold (mutation: the guard reading
`soldItems.isEmpty` → the first expectation reads `.nothingAdded` → red, G25).

## 2. The Sold side's sort

```swift
enum SoldSortOrder: String, CaseIterable, Identifiable {
    case soldDate, salePriceDescending, salePriceAscending,
         paidDescending, paidAscending, gainDescending, gainAscending, name
    var id: String { rawValue }
    var label: String   // "Date sold", "Price ↓", "Price ↑", "Paid ↓", "Paid ↑", "Gain ↓", "Gain ↑", "Name"
}
```

Case order is the menu order (Decision 3, P6); no Custom, Market or Desire.
Comparators, the Owned side's shape:

```swift
/// The Sold side's sort under one option: the option's own comparison, and
/// the standing order on any tie (P7). Static, with the option as an
/// argument, so a test can ask it about two items directly — the tie-break
/// is only falsifiable when the pair's order is the test's to choose.
static func areInSoldOrder(_ lhs: Item, _ rhs: Item, under order: SoldSortOrder) -> Bool {
    soldAttributeOrder(lhs, rhs, under: order) ?? areInSoldOrder(lhs, rhs)
}
private func isInSoldOrder(_ lhs: Item, _ rhs: Item) -> Bool {   // what load() sorts with
    Self.areInSoldOrder(lhs, rhs, under: soldSortOrder)
}
private static func soldAttributeOrder(_ lhs: Item, _ rhs: Item, under order: SoldSortOrder) -> Bool? {
    switch order {
    case .soldDate: return nil                                       // the standing order *is* the sort
    case .salePriceDescending, .salePriceAscending:                 // nil-last, the Value pair's block
        (lhs.salePriceCents, rhs.salePriceCents) … guard != else nil; guard let left else false; guard let right else true; desc ? > : <
    case .paidDescending, .paidAscending:   purchasePriceCents (non-optional), nil on equal
    case .gainDescending, .gainAscending:   saleOutcome?.deltaCents, nil-last, nil on equal
    case .name:                             localizedCaseInsensitiveCompare, nil on .orderedSame
    }
}
```

`areInSoldOrder` stays static and unchanged — Settings and the CSV (§4) sort
with it. `salePriceCents` is nil only for an unsold item, which callers filter
before sorting; the nil-last arm is the defensive one and `SoldSortOrderTests`
records it as such.

**The fixture** (`SoldSortOrderTests`, one parameterised test over all eight
cases plus the tie test), four sales chosen so every order differs from the
standing order and from every other order, and one price tie falls the way
the standing order says and *not* the way name order would:

| Name | Paid | Sold for | Sold | Outcome |
|---|---|---|---|---|
| Amp | $500 | $650 | 3 days ago | +$150 |
| Drum | $1,250 | $1,250 | 3 days ago | at cost |
| Bass | $1,000 | $1,250 | 7 days ago | +$250 |
| Cello | $850 | $600 | 12 days ago | −$250 |

Standing order: Amp, Drum, Bass, Cello. Expected: **Date sold** Amp, Drum,
Bass, Cello · **Price ↓** Drum, Bass, Amp, Cello · **Price ↑** Cello, Amp,
Drum, Bass · **Paid ↓** Drum, Bass, Cello, Amp · **Paid ↑** Amp, Cello,
Bass, Drum · **Gain ↓** Bass, Amp, Drum, Cello · **Gain ↑** Cello, Drum,
Amp, Bass · **Name** Amp, Bass, Cello, Drum. Deleting any one comparator
(falling to the standing order) or reversing it changes that case's
expectation, and reading price for paid or price for gain does too (G2). The
tie: Drum and Bass share $1,250 and sit Drum-then-Bass on Price ↓ because the
standing order's *date* decides, where name order would put Bass first. G3
asks the **static comparator about the pair directly, in both argument
orders** — `areInSoldOrder(drum, bass, under: .salePriceDescending) == true`
and `areInSoldOrder(bass, drum, under: .salePriceDescending) == false` —
never through `load()`, whose fetch hands the pair back in an order the test
does not control (mutation: `?? false` in place of the standing order → the
first reads false → red; tie-break by name → the first reads false → red).
G2's eight orders may run through `load()` because none of them has a tie
the attribute leaves open except this pair, which G3 owns. Labels, case
order and the `.soldDate` default pinned by literal (G1).

## 3. Chips, summary, empty state, the controls gate

Covered by Q5–Q7 and §1. `soldSummaryLine` keeps its spelling and now reads
the narrowed totals: two sales, a query matching one → "1 sold · …"; matching
none → "0 sold · $0" (G10). `emptyReason`'s `.sold` branch:

```swift
private var soldEmptyReason: ListEmptyReason? {
    let reason = ListEmptyReason.reason(
        totalCount: soldTotalCount, visibleCount: soldItems.count,
        searchText: soldNarrowing.searchText, categoryFilter: soldNarrowing.categoryFilter,
        showsOnlyUnvalued: false, mayStillBeImporting: syncMonitor.mayStillBeImporting)
    return reason == .nothingAdded ? .nothingSold : reason
}
```

`ItemListView.emptyState` needs no change: its `searchMatchedNothing` and
`categoryMatchedNothing` actions write `viewModel.searchText` /
`categoryFilter`, which under Q1 are the side on screen's. **Testable claims**
(G9): on Sold, a query matching nothing → `.searchMatchedNothing(query:)`, a
chip matching nothing → `.categoryMatchedNothing`, nothing sold at all →
`.nothingSold` (with or without a stale query — `reason(...)`'s `totalCount`
guard), importing and nothing sold → `.stillSyncing`, importing with a query
matching nothing → `.searchMatchedNothing` (mutation: pick the case without
`reason(...)` → the query cases red).

## 4. Exports

```swift
/// The owned rows a file from here carries: the side on screen's narrowing
/// over the owned half (P11); in visible order on Owned, in Custom order
/// from Sold, where no owned row is visible (plan R1).
private var exportableOwnedItems: [Item] {
    switch side {
    case .owned: items                                   // the rows on screen, as-is — one computation, never a second sort
    case .sold: narrowed(owned, by: narrowing).sorted(by: ManualOrderHelper.areInCustomOrder)
    }
}
/// The sold rows: the same narrowing, always the standing order (P10) —
/// never `soldItems`, whose order is the view's reading aid.
private var exportableSoldItems: [Item] { narrowed(sold, by: narrowing).sorted(by: Self.areInSoldOrder) }
var canExportCSV: Bool { !exportableOwnedItems.isEmpty || !exportableSoldItems.isEmpty }
var canExportPDF: Bool { !exportableOwnedItems.isEmpty }
```

`exportCSV` writes `exportableOwnedItems + exportableSoldItems`; `exportPDF`
builds entries and the cover (`itemCount`, value, paid, un-valued) over
`exportableOwnedItems` (R2), through one private `figures(over:)` that the
header's `totalCurrentValueCents` / `unvaluedCount` / `totalPaidCents` also
read, so the arithmetic has one home. `exportCoverageLabel` is unchanged in
spelling — under Q1/Q5 it names the on-screen chip and query. On the Owned
side `exportableOwnedItems` *is* `items`, so `exportCSV`'s standing claim —
records built from `items` as-is, never a refetch or a second sort — stays
literally true there, and every figure equals today's, row for row.

**Testable claims** (`ItemListViewModelTests` "the CSV's two halves" extended;
`SettingsViewModelTests`): from the Sold side narrowed to a category, the CSV
holds the owned and sold rows in it and the coverage label names it, while a
chip and query left on Owned change nothing (mutation: read `ownedNarrowing`
in the export → red, G11); from the Owned side a query left on Sold changes
nothing (G12); with `soldSortOrder = .salePriceAscending` the CSV's sold rows
are still date-desc (mutation: write `soldItems` → red, G13); **byte
identity**: the list's CSV from the Sold side with Owned on `Date` and Sold
on `Price ↑`, no narrowing on screen, equals Settings' bytes, and from the
Owned side under Custom with Sold on `Gain ↓` likewise (mutation: owned rows
in `isOrderedBefore` from the Sold side → red, G14); the PDF from a Sold side
narrowed to a category lists the owned rows in it, cover count and totals over
them, label "Category: …" (mutation: read `items` → red, G15); a Sold-side
chip that excludes every owned row leaves `canExportCSV` true and
`canExportPDF` false (G16).

## 4a. Export scope (Decision 7 — added 2026-09-18 at the Phase 2 pause)

Decided by the person at the Phase 2 pause (spec Decision 7) and shaped by a
decision review at the top tier (`skeptical-reviewer`, `fable`, ~226k tokens),
approved by the person the same day. Q14–Q17 and R3 below are that review's
recommendation transcribed; the reasoning it gave in plain words is in the
plan file the person approved and in the tier log.

- **Q14. One enum, one gate, every caller says what it exports.**
  `ItemListViewModel.ExportScope: CaseIterable { owned, sold, both }` in menu
  order, `label` = "Owned items" / "Sold items" / "Owned and sold".
  `private func rows(for scope:) -> [Item]` = `exportableOwnedItems` /
  `exportableSoldItems` / the first then the second. `func canExport(_ scope:)
  -> Bool { !rows(for: scope).isEmpty }`; `canExportCSV` and `canExportPDF`
  both read `canExport(.both)` — the menu row is enabled when any chooser row
  is; `OverflowDropdown`'s two flags stay for the Wishlist's reason and its
  comment says the Items list feeds them equal. `exportCSV(scope:)` and
  `exportPDF(scope:)` take the scope with **no default** — every existing
  call site names `.both` (CSV) or `.owned` (PDF), so today's tests pin
  today's files under their new names. The `.both` CSV path is byte-for-byte
  the current `exportCSV` body. Why not six menu rows: `013` criterion 1's
  fixed row order, the four-row `#require`s, and the menu being shared with
  the Wishlist (no sold half). Why not "this side": scope must be chosen
  independently of side, because changing side changes which narrowing is in
  force (Decision 4).
- **Q15. The sold document.** `CoverSummary.Totals.sold(proceedsCents:
  paidCents:realisedDeltaCents:)`; `drawCover`'s arm draws TOTAL SOLD FOR
  (print brass, the headline slot), TOTAL PAID (ink), REALISED (ink,
  `SaleCopy.realised(deltaCents:)` — sign carried by the words, no colour:
  `PrintPalette` has no moss/rust and gains none) through `drawTotal` and a
  text-taking sibling; `countLine` → "N sold"; no floor note. `PDFEntry.init(
  record:)` **prepends** `Sold` (`ExportSchema.day`), `Sold for` (money),
  `Sold at` (if non-empty), `Outcome` (`SaleCopy.rowOutcome(deltaCents:)` from
  `SaleOutcome(salePriceCents:purchasePriceCents:)`), `Sale note` (if
  non-empty) when the record carries a sale — `soldDate` and `salePriceCents`
  unwrapped as the pair `012`'s rule guarantees (as built at T009c; `?? 0`
  would print "Sold for $0") — then the owned grid unchanged —
  prepended because Decision 6 put the mark directly under the name; the
  composer is untouched. `ExportFilename.soldItems(fileExtension:on:timeZone:)`
  = `Trove-Sold-Items-<day>`; `ItemListViewModel.soldDocumentTitle = "Sold
  Items"`. The sold PDF must have its own name — `exportFiles` writes one
  directory by filename, so two documents in one set with one name would
  overwrite; `.owned` keeps `Trove-Items` because it is the very document
  Settings ships under that name. Genuinely new drawing: none — new words on
  existing shapes, inside "no design pass".
- **Q16. The scoped PDF stages a set.** `exportPDF(scope:)` builds the owned
  document (as today, over `exportableOwnedItems`) and/or the sold one (title
  `soldDocumentTitle`, `exportCoverageLabel`, `itemCount = rows.count`, totals
  from `SaleOutcome.totals(over: rows)` and `figures(over: rows).paidCents`,
  entries over `exportableSoldItems`), drops a document with no entries (`011`
  criterion 2: an empty file is never produced), and stages through **one**
  `exportFiles` call — a set of one or two — so the two-file case cannot purge
  itself and the one-file cases share the path. A single combined cover was
  rejected: it would set TOTAL VALUE beside TOTAL SOLD FOR under one count,
  the mixed figures `006` Decision 7 refused, or need a section page, which
  is new drawing.
- **Q17. The chooser is a `HeaderDropdown` case anchored at the overflow
  badge.** `HeaderDropdown.exportScope(ExportFormat)` (`ExportFormat { csv,
  pdf }`, private to `ItemListView.swift`), `dismissLabel` "Dismiss export
  options". `DropdownHost` draws a dropdown only for an identifier that has an
  anchor, so `overflowControl` carries three `.dropdownAnchor`s — `.overflow`,
  `.exportScope(.csv)`, `.exportScope(.pdf)`. **Corrected 2026-09-18 at T009f (decision review):**
  `dropdownAnchor` is a `transformAnchorPreference`, not an
  `anchorPreference` — a set-modifier stacked on one view replaces the key's
  value, so only the last tag survives (T009f found the "…" badge opening
  nothing at `cf3e1ee`; six UI tests red); a transform adds its entry to
  what the view already publishes, and the key's `reduce` then merges across
  siblings as before. Guarded by `DropdownAnchorTests` (T009g): three tags on
  one view reach a reader as three keys, and the helper reverted to
  `anchorPreference` leaves one. The
  Items list's `OverflowDropdown` closures set `openDropdown =
  .exportScope(.csv / .pdf)`; the host's `case .exportScope(let format):`
  composes `DropdownSurface(title: ExportCopy.scopeTitleCSV / scopeTitlePDF)
  { ForEach(ItemListViewModel.ExportScope.allCases) { scope in
  DropdownRow(title: scope.label, isEnabled: viewModel.canExport(scope)) {
  … exportCSV(scope: scope) / exportPDF(scope: scope) } } }`. The row's
  `dismiss()` then the action's `openDropdown = .exportScope(…)` net to one
  `.overflow → .exportScope` change in one transaction, so the plate stays
  and its rows swap (the device pass looks at that once). No `Menu`, no
  `confirmationDialog` (`013` Decision 17). The Wishlist's call is unchanged.
- **Q18. The meta line takes the header's full width; the badges share the
  title's row** (added 2026-09-18, decision review, at T010's device pass).
  The pass measured the Sold side's switch at 168.00 pt against the Owned
  side's 154.33 pt once anything is sold — one mono line. Cause, measured:
  `header`'s `HStack` gave the title-and-meta `VStack` only the width the
  badges left it (226.3 pt on Sold under "Date sold", 259.3 pt on Owned under
  "Date"), and the sold summary needs about 232 pt, so it wrapped. §6's claim
  held only while the slot's *width* held the line, which `014` ended by
  putting a badge on the Sold side. `header` becomes `VStack(alignment:
  .leading, spacing: 6) { HStack(alignment: .top) { title; Spacer(); badges };
  metaLine }`, extracted as `ItemsListHeader` (`Trove/Views/Items/ItemListHeader.swift`)
  taking the meta and the badges as `@ViewBuilder`s so its height is
  measurable off-device. The badges stay top-aligned with the title, so the
  header's height is the title's line box plus 6 plus one meta line on both
  sides — unchanged from today provided the title's box is at least the badge
  row's 30 pt, which T010a measures rather than assumes. The gate literal,
  `sortControl` and `overflowControl` stay spelled in `ItemListView.swift`,
  where G20's and `ImportWiringTests`' scans read them. **Not** `lineLimit(1)`
  or `minimumScaleFactor` (`001`'s fixed type sizes, and either one blinds the
  guard that has to be able to go red), **not** a shortened sold summary (the
  person's copy, and it fails again at six-figure totals). No copy change and
  no criterion amendment. The same latent wrap existed on the Owned side —
  "34 ITEMS · $18,420 · 3 UNVALUED" under a long Owned sort label — and this
  fixes it there too. Consequence to disclose: the header's VoiceOver order
  becomes title, badges, meta; the person confirms it at criterion 12's
  Accessibility Inspector step, and `.accessibilitySortPriority` on the meta
  is the one-line answer if they don't like it. `WishlistView.header` carries
  the identical shape and is **not** changed here (follow-up, `ROADMAP.md`).
- **R3 — reading for the record:** R2 stands and now names the Owned scope;
  the sold document is the same rule applied to the sold half.

**Testable claims** are guards G26–G37 in §10; the Phase 2b task lines carry
each mutation. Two testing notes from the Phase 2b decision review
(2026-09-18): `GatedExportServiceSpy` gates only the first call across
`exportCSV` and `exportFiles`, so the Items and Settings reentry tests share
one rule and a leaked reentrant call fails a count instead of hanging
(T009i); and `MenuPolicyTests` names `.confirmationDialog(` beside `Menu`,
closing the half of `013` Decision 17 the scan had left unguarded (T009h).

## 5. The swipe's Mark as sold, and the sheet on the list

`SaleCopy` gains `static let swipeSell = "Sell"` (pinned; the spoken name is
`markAsSold`, unchanged). `ItemListViewModel` gains:

```swift
/// The swipe's sheet, seeded exactly as the detail's `.mark` sheet and a
/// Sell Plan row's (006 P1): the price from the item's current value, the
/// date now, location and note blank.
func makeSaleFormViewModel(for item: Item) -> SaleFormViewModel
/// The swipe's sale: `ItemSaleStore.markSold(toward: nil)` (006 P5), one
/// save, rollback + `load()` on refusal (the `store(_:)` shape), then `load()`.
@discardableResult func markSold(_ item: Item, sale: Sale) -> Bool
```

`ItemListView`: `@State private var itemBeingSold: Item?`; the leading swipe
becomes Edit (`divider`), **Sell** (`accentBrassMid`, `Image("ActionSell")`,
`.accessibilityLabel(SaleCopy.markAsSold)`), Copy (`surfaceInset`) — Edit
still nearest the edge, so a full swipe still edits (Decision 2); and

```swift
.sheet(item: $itemBeingSold, onDismiss: viewModel.load) { item in
    SaleFormView(
        viewModel: viewModel.makeSaleFormViewModel(for: item),
        confirm: { sale in viewModel.markSold(item, sale: sale); itemBeingSold = nil },
        cancel: { itemBeingSold = nil })
}
```

The trailing swipe and `soldRows` are untouched. The asset: `design/icons/action-sell.svg`
(a price-tag outline, the house style) copied into
`Trove/Assets.xcassets/ActionSell.imageset/` with a `Contents.json` identical
to `ActionEdit`'s but for the filename.

**Testable claims**: `makeSaleFormViewModel(for:)`'s seed equals
`ItemDetailViewModel.makeSaleFormViewModel()`'s and `SellPlanViewModel`'s for
the same item, with and without a value (mutation: `?? 0` → red, G17);
`markSold` on a second context writes the four fields, no plan link, empties
the item's plan selections, and the item is in `soldItems` and not `items`
afterwards; a refused save rolls back (the structural `catch` scan
`ItemDetailViewModelTests` already runs, extended to this file, G18).
`ItemListSidesWiringTests` (G19): the Owned rows' one leading block names, in
order, `"Edit"`, `SaleCopy.swipeSell`, `"Copy"`, the middle button reaches
`itemBeingSold` and carries `.accessibilityLabel(SaleCopy.markAsSold)`, the
trailing block still names no `SaleCopy`, `soldRows` still has no leading
swipe; `.sheet(item: $itemBeingSold` composes `SaleFormView(` over
`viewModel.makeSaleFormViewModel(for:` exactly once. `ActionSell` loads as a
template image (`TabIconTests`' `UIImage(named:in:with:)` + Contents.json
checks, G22). `MenuPolicyTests` re-confirmed (a second `Menu` in
`ItemListView` → red). What the suites cannot see, the device pass instruments
(§8): the `.sheet(item:)` over a row's `Item` presents once per tap and writes
once per confirm.

## 6. The header and the sort control

`ItemListView.body`'s header: both gated spans open on
`viewModel.offersNarrowingControls` (Q10); the search field and chips render
on both sides in the same slots, and **the switch's top edge is the same on
both sides because the meta line is the full header width, not because the
slot is unchanged** (Q18, corrected 2026-09-18 at T010's device pass, which
measured the old sentence false). `006` Decision 13's slot — one
unconditional mono line on both sides — still holds, and it is a *height*
claim two guards now measure (G38, G39) rather than a sentence the device
pass spot-checks. `sortControl` reads
`viewModel.visibleSortLabel` for the badge and its accessibility label. The
host's `case .sort:` switches on `viewModel.side`: Owned composes today's
`SortDropdown` over `SortOrder.allCases`; Sold composes one over
`SoldSortOrder.allCases`, `isManualOrder: { _ in false }` (no REORDER tag —
there is no manual order), selecting into `soldSortOrder` then `load()`.
`apply` per Q3.

**Testable claims** (`ItemListSidesWiringTests`, G20): the gate is spelled
exactly twice, both `offersNarrowingControls`, and `side == .owned` appears
nowhere in the header; `sortControl` is composed once inside a gate;
`SearchField(` once inside a gate; the host's `case .sort:` composes exactly
two `SortDropdown(`, one naming `SortOrder.allCases` and one
`SoldSortOrder.allCases`, the second selecting into `soldSortOrder`; `apply`'s
body between `guard let request` and `switch request` names no `viewModel.`;
each Owned case calls `show(.owned)` before any write (the existing
ordering assertion). `ImportWiringTests` per Q10.

## 7. The sold page's mark

`ItemDetailView.content(for:)`'s sold branch becomes `photoHero`,
`titleBlock(for: item)`, `SoldMark(…)`, `statPair`, `desireCard(…false)`,
`details` — the mark inside the same `sectionGap` stack, nothing else
touched (Decision 6). `SoldMark.swift`'s header comment says "under the
title block"; its words, colours, `sold.mark` identifier and combined
accessibility element are unchanged (criterion 11).

**Testable claims** (`SoldStateWiringTests.theSoldBranchStampsTheMark`
extended, G21): in the sold branch, the offsets satisfy `photoHero` <
`titleBlock(for: item)` < `SoldMark(` < `statPair(for: item)` (mutation: move
the mark back above the hero → red). The existing UI test still finds
`sold.mark`.

## 8. UI tests and the device pass

UI tests (`TroveUITests`, `-uiTesting -seedSold`, no seed change — Q13):

- `testTheSoldCardLandsOnTheSoldSideWhichListsSalesMostRecentFirst`
  **rewritten at its Sort By assertion**: on the Sold side `sortOptions.items`
  exists with label "Sort by Date sold", the search field ("Search name or
  serial") exists, chips "Guitars" and "Amps" exist, "Cameras" and "Not yet
  valued" do not; back on Owned the badge reads "Sort by Date" and "Cameras"
  is a chip.
- `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch`: on Sold pick
  `Price ↑` → Blues Junior's row above the Telecaster's; type "tele" → only
  the Telecaster, summary "1 sold · $1,250 · +$350 vs paid"; switch to Owned
  → the field reads its placeholder, the Leica row shows, badge "Sort by
  Date"; back to Sold → the field still reads "tele", only the Telecaster,
  badge "Sort by Price ↑"; then type "zzz" → "No matches for “zzz”" and no
  "Nothing sold yet."; Clear search → both rows. Mutation: the old clearing
  back in `show` → red.
- `testTheLeadingSwipeOffersMarkAsSoldBetweenEditAndCopyAndOpensTheSheet`:
  on Owned, a **partial** drag on the Leica row (`press(forDuration:thenDragTo:)`
  across about 40 % of the row — `swipeRight()` is a full-velocity swipe that
  fires the edge action, Edit); buttons "Edit", "Mark as sold…" and "Copy"
  exist with ascending `frame.minX`; tap "Mark as sold…" → `sale.sheet.price`
  exists reading the Leica's $2,600 (grouping stripped); Cancel → the sheet
  gone, the Leica still on Owned, no `sold.mark`. Mutation: the middle button
  wired to `itemBeingEdited` → the price field absent → red. If XCUITest
  cannot open the leading actions reliably, that is a finding for the device
  pass to instrument, not a reason to drop the assertion.

`scripts/verify.sh ui` twice back to back (criterion 13; G24).

**Device pass** (T009, a `general-purpose` agent with simulator tools):
the switch's top edge on both sides at zero sales and with `-seedSold`
(criterion 3, the `006` 7a measurement re-taken with the controls present);
the Sold side with the field, chips and badge in the Owned side's slots; a
narrowing on each side surviving a round trip; the no-matches state on Sold;
the swipe's three buttons on both appearances (the white label on
`accentBrassMid` legible, Q9) and the middle one's name read from the
accessibility tree ("Mark as sold…" if the modifier took, else "Sell" —
recorded for `DECISIONS.md`, Q9), the sheet prefilled, Cancel inert; **a file
probe in `ItemSaleStore.markSold`** through the swipe's sheet — Cancel 0,
swipe-down 0, a re-render of the list 0, confirm 1 — removed before the
suites run; the sold page's mark under the name with `sectionGap` above and
below, measured; a CSV from a Sold side narrowed to "Amps" read from the
container (owned + sold amps only, the label true), and an unnarrowed one
byte-equal to Settings' with Sold sorted by Price ↑. **The person's step**:
Accessibility Inspector over the swipe action ("Mark as sold…"), the Sold
side's field, chips and badge (criterion 12).

## 9. Docs and the `006` pointers

At T001 (docs only, before any code): `specs/006-mark-as-sold/spec.md` gains
a one-line *"Superseded by `014` (…)"* pointer at Decision 4, criterion 1,
P16 and the Non-goals bullet "Sorting, filtering or searching the Sold side";
`specs/006-mark-as-sold/plan.md` at Q15, G33 and §4's "on the Sold side
`narrowed` is the identity" sentence, plus Q5's "Because changing side clears
every narrowing" clause. Appended pointers, nothing above them edited.

At close-out (T010): this spec's criteria ticked with citations; the Copy
section gains "Sell" and the eight labels (P-items → decisions); `plan.md`'s
"As built"; `design/tokens.md`'s `006` rows "Placement" ("`15` above the
first row on Sold" — now the Owned spacing on both sides), "Header on Sold"
and the Sold mark's "Position" get their "As implemented" cells, and the
Swipe-action table names the third leading action and its tint; `README.md`'s
sold bullet gains the swipe and the Sold side's controls; `ROADMAP.md`'s 014
entry and status row; `DECISIONS.md` (per-side state as two values behind one
set of names; the CSV's order rule from the hidden side; why "Sell" on the
button and "Mark as sold…" to VoiceOver).

## 10. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `SoldSortOrderTests`: eight labels, case order, `.soldDate` default by literal | a label, the order or the default changes |
| G2 | the eight orders over the four-row fixture | any comparator is deleted, reversed, or reads the wrong field |
| G3 | Price ↓ tie, asked of the static comparator in both argument orders: Drum before Bass (the standing order's date) | `?? false` in place of the standing order, or the tie falls to name |
| G4 | `ItemListViewModelTests`: each side keeps chip, query, un-valued, sort across a switch, both directions, no leak | a clear on switch, or one shared narrowing |
| G5 | a fresh view model: both sides clean, Owned on screen, `Date` / `Date sold` | anything stored or defaulted otherwise |
| G6 | `showsOnlyUnvalued` refused on Sold; Owned's copy untouched | the setter's guard is dropped |
| G7 | Sold chips from the sold half only; `categoryOptions` follows the side | either pair built from `all`, or the getter ignores the side |
| G8 | `offersNarrowingControls` per side | the gate reads the other side's count |
| G9 | the Sold side's five empty-reason cases through `reason(...)` | the case is picked without `reason(...)` |
| G10 | `soldTotals` / `soldSummaryLine` follow the narrowing ("0 sold · $0" at no match) | totals summed over `sold` |
| G11 | CSV from Sold under Sold's chip, both halves; Owned's hidden narrowing inert | the export reads `ownedNarrowing` or `items` |
| G12 | CSV from Owned; Sold's hidden query inert (G15 kept) | the export reads `soldNarrowing` |
| G13 | the CSV's sold rows are date-desc whatever `soldSortOrder` shows | the export writes `soldItems` |
| G14 | `SettingsViewModelTests`: byte identity from both sides, any sort (R1) | owned rows from Sold in the Owned sort; sold rows in the view's |
| G15 | PDF from a narrowed Sold side: owned rows in it, cover over them, label true (R2) | the PDF reads `items` or the label ignores the side |
| G16 | `canExportCSV` / `canExportPDF` read the exportable rows | a gate reads `items` / `soldItems` |
| G17 | the list's sale-sheet seed equals the detail's and the plan's, with and without a value | `?? 0`, or a different `now` |
| G18 | `markSold` from the list: four fields, no link, selections dropped, side changed; refusal rolls back | `toward:` non-nil; `rollback()` dropped (structural scan) |
| G19 | `ItemListSidesWiringTests`: leading swipe Edit, Sell, Copy in order; Sell → `itemBeingSold` + spoken `markAsSold`; trailing delete-only; Sold rows no leading swipe; one `.sheet(item: $itemBeingSold` over `makeSaleFormViewModel(for:` | any order, wiring or label change |
| G20 | one gate spelled twice, both sides; two `SortDropdown(` in `case .sort:`; `apply` writes nothing before `show` | a `side == .owned` gate returns; one dropdown; a write moves up |
| G21 | `SoldStateWiringTests`: hero < title < `SoldMark(` < stats in the sold branch | the mark moves |
| G22 | `ActionSell` loads as a template image | the imageset is missing or not template |
| G23 | `SaleCopyTests`: `swipeSell == "Sell"`; the swipe's `.accessibilityLabel` is `SaleCopy.markAsSold` (scan) | either spelling drifts |
| G24 | UI: per-side state, the swipe's sheet, the Sold controls and no-matches; twice back to back | see §8's mutations |
| G25 | an emptied Owned side reads `.everythingSold` with a no-match query left on Sold | `ownedEmptyReason`'s guard reads `soldItems.isEmpty` instead of `soldTotalCount > 0` |
| G26 | `ItemListViewModelSoldExportTests`: `ExportScope` labels and case order by literal | a label or the order changes |
| G27 | the three scopes partition the record from a narrowed Sold side: owned in Custom order, sold date-desc whatever `soldSortOrder`, both = owned + sold | `.owned` reads `items` from Sold; `.sold` reads `soldItems`; `.both` sold-first |
| G28 | `canExport(_:)` per scope on all-sold / all-owned / a chip matching neither; `exportCSV(scope: .owned)` on an all-sold collection stages nothing | a gate reads `items`/`soldItems` |
| G29 | CSV filenames: `.sold` → `Trove-Sold-Items-<day>.csv`; `.owned`/`.both` → `Trove-Items-<day>.csv` | the names swap |
| G30 | `PDFComposerTests`: the sold cover's page text — "Sold Items", "N sold", TOTAL SOLD FOR / TOTAL PAID / REALISED, "+$350 vs paid", no floor note | the `.sold` arm draws the `.items` labels; the floor note drawn; "items" in the count line |
| G31 | `ExportSchemaTests`: a sold record's entry begins Sold, Sold for, Sold at, Outcome, Sale note (optionals skipped when empty), then Paid; an owned record carries none | fields appended not prepended; outcome from `currentValueCents`; an empty `Sold at` emitted |
| G32 | `ExportFilename.soldItems` == `Trove-Sold-Items-YYYY-MM-DD.pdf` under a fixed date and zone | the name drifts |
| G33 | the sold PDF from a narrowed Sold side under `Price ↑`: entries date-desc, title, label, `itemCount == entries.count`, totals over exactly those rows | entries from `soldItems`; cover over `sold`; paid from `salePriceCents` |
| G34 | unnarrowed Sold side: the sold cover's (count, proceeds, realised) == `soldTotals` | proceeds over `purchasePriceCents` |
| G35 | `.both` PDF: one `exportFiles` call, documents owned-then-sold, filenames `[items, soldItems]`, `stagedExport` the same; an empty half left out | two single calls; the empty half staged; order swapped |
| G36 | all-sold: `canExportPDF` true, `canExport(.owned)` false | `canExportPDF` reads the owned half |
| G37 | `ExportWiringTests`: the Items rows open `.exportScope(.csv/.pdf)`, the Wishlist's still export directly; the host's case composes one titled surface over `ExportScope.allCases`, rows gated `canExport(scope)`, actions passing `scope` (no literal case); three `.dropdownAnchor(` on `overflowControl` | a row gated on `canExportCSV`; the action passing `.both`; an anchor dropped |
| G38 | `ItemListHeaderLayoutTests`: the header's rendered height at the device's content width is the one-line baseline for the Owned line, for the Sold line, and for the Sold line under the widest `SoldSortOrder` label | the meta line goes back inside the badges' row, or any control takes width from it |
| G39 | UI: `items.sideSwitch` has the same `frame.minY` on both sides with `-seedSold` | the Sold summary wraps — the 13.67 pt T010 measured |

Every guard is mutation-verified before it lands (`CLAUDE.md` Testing); the
task's Done note records what was broken and what went red. Every source scan
first asserts its anchor was found (`#require` on the count, the
`ItemListSidesWiringTests` shape). One thing the suites cannot see, the
device pass instruments (§8): the swipe's sheet presenting once per tap. The
switch's top edge, listed here until T010a, is guarded twice since — G38
off-device and G39 on it.

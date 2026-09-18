# 006 — Mark as Sold

**Status**: **Approved** (2026-09-13) — written with the person in this spec
session; amended the same day at the person's reading of the Draft (Decision
9, the two-sided Items view; Decision 10, gain or loss unmistakable with the
amount, its form left to the design pass) and approved with that last note.

Authored in a Claude Code spec session of its own, per `CLAUDE.md`'s model
policy (Fable 5.1, the session raised to high effort for the spec
conversation). Every product decision below was made by the person and is
listed in the Decisions record; the P-items are Claude Code's proposals and
become decisions on plan approval, as `002`'s and `005`'s did.

**Depends on**: `001-core-inventory` (`Item`, the item detail screen, the
Dashboard and its figures, the Sell Plan), `003-trend-aware-sell-plan` (the
Sell Plan rows this spec adds an action to), `010-item-management-enhancements`
(the delete flow and its confirmation copy, which a sold item reuses),
`011-data-export` and `012-data-import` (the append-only CSV schema this spec
extends, and the parser that must accept the new columns), `013-settings-menu`
(the Dashboard's "…" and the "bespoke in the page, system in the bars" rule
that places the new action). It touches nothing in `002`'s network code and
adds no outside service.

## Summary

Trove's Sell Plan helps you decide what you would sell to fund the next thing
you want. Until now it stopped there: nothing in the app could record that you
actually sold something. The only way an item left your collection was to
delete it — photos, history and all. This feature adds **Mark as sold…**: a
sold item leaves your collection and your totals but stays in the app, with
the price, date and place of the sale, on a **Sold** side of the Items tab —
one tap from what you own — and at a glance on a new Dashboard card. A sale
can be undone. The Sell Plan learns what was sold
toward a wishlist item and says so, still without ever doing your arithmetic
for you.

## What and why

The roadmap's `006-mark-as-sold` entry reads: "Real transaction tracking for
the Sell Plan: marking a planned item as actually sold, removing it from
inventory, a sale history. Deliberately excluded from `001` to keep the Sell
Plan a decision-support tool rather than a ledger — worth revisiting once it's
clear the decision-support version is actually useful day to day."

It is. Three specs have built on the Sell Plan since `001`, and the gap it
leaves is now the one a hobbyist meets first: gear does get sold, and the app
offers only **Delete**, which is the wrong verb — it forgets the item, the
photos, what was paid and what it fetched, and it silently drops the item from
the plan it was sold for. What is wanted is the opposite: keep everything, and
add the one fact the app never had, **what it actually sold for**.

Two things this spec deliberately preserves from `001`:

- **The Sell Plan stays a decision tool.** It gains a "Sold" figure beside
  "Selected", and it still never subtracts anything from the estimated cost.
  The framing decision `001` made — two figures side by side, a colour cue,
  no gap, surplus or shortfall — holds unchanged (Decision 5).
- **"Sold" is the person's word, not the market's.** `002` and `CLAUDE.md` say
  no *market* sold price may ever appear in the app, because no source offers
  one to a non-partner app. That rule is about Reverb's data and is untouched.
  A sale price the person types in is their own record of their own
  transaction — the first real "sold" number in the app, and the only kind
  there will be.

## Core behavior

### Marking an item as sold

- Any owned item offers **Mark as sold…** (Decision 4), from two places:
  - the item detail screen's top-right menu, beside **Edit** and **Delete**;
  - each row of a wishlist item's **Sell Plan**, since that is where the
    decision to sell was made.
  It is not on the Items list's swipe, which stays delete-only.
- The action opens a **sale sheet** asking for (Decision 2):
  - **Sale price** — required; pre-filled with the item's current value when
    it has one, otherwise blank (P1);
  - **Sold on** — the sale date; defaults to today; cannot be in the future
    (P2);
  - **Sold at** — where it sold, free text, optional (as the item's purchase
    location is);
  - **Note** — optional.
  No fees, shipping or net-proceeds fields (Non-goals).
- Confirming the sheet marks the item sold. The item's own fields — name,
  category, what was paid, current value, desire to keep, condition, photos,
  notes, market match — are left exactly as they were; the sale is recorded
  alongside them, not in place of them (Decision 1).
- **Sold from a Sell Plan row**, the sale also remembers **which wishlist item
  it was sold toward** (Decision 5, P5). Sold from the detail screen, it
  remembers no plan.

### What "sold" does

A sold item **leaves the collection and stays in the app** (Decision 1):

- It is **gone from the Items list**, from every **Dashboard figure** — total
  value, paid, the delta, the counts, the value ruler, the category breakdown
  and the market line — and from **Sell Plan candidates**. Its cost leaves
  "paid" with it: the collection figures describe what you own now, nothing
  more.
- It is **removed from every Sell Plan it was selected on** at the moment of
  the sale (it can no longer be sold), the same way deletion drops it today —
  but, when sold from a plan, the plan keeps the funding link described below
  (P6).
- Its **market figures on this device are cleared**, as deletion clears them
  today, and it is no longer refreshed (Decision 7). A sold item has no market
  value to track.
- It **appears on the Sold side of the Items tab**, and its sale contributes
  to the Dashboard's Sold card and to the Sell Plan it was sold toward.
- It **stays out of the PDF export** and **appears in the CSV export** with its
  sale columns filled (Decision 7; below).
- It is **synced** like any item: the sale details are part of the person's
  own data and travel to their other devices (P9).

### The sold item's page

- Tapping a row on the Sold side opens the item's own detail screen in a
  **sold state** (P4): a **Sold** mark at the top with the sale — price, date,
  place, note — and, shown the same way as on the row, **whether it sold at
  a gain or at a loss and by how much** against what was paid (Decision 10),
  then the item's ordinary content below it, read-only. Its photos, notes and details remain
  visible; a stock photo keeps its badge and credit.
- The page offers exactly three actions (P4): **Edit sale…** (the sale sheet
  again, pre-filled), **Return to collection…** (Decision 3), and **Delete**.
  Editing the item's *own* fields while sold is not offered — return it to the
  collection first.
- **Return to collection…** asks first, because the sale details are
  discarded: confirmed, the item reappears in the collection exactly as it
  was, with no sale, at its former place in the custom order. It does not
  rejoin any Sell Plan it had been on (P12).
- **Delete** on a sold item uses the same confirmation as today's delete and
  is just as permanent (Decision 3). Its message need not mention sell plans,
  since a sold item is on none (P13).

### The two sides of Items

- The **Items tab has two sides, Owned and Sold**, switched in one tap by a
  control at the top of the page (Decision 9). Owned is today's Items list,
  unchanged. Sold is the list of sold items. The tab opens on Owned at every
  launch (P16); the Dashboard's Sold card jumps straight to the Sold side
  (Decision 6).
- **The Sold side**: rows show the item's thumbnail, name, sold date, sale
  price, and — **unmistakably — whether it sold at a gain or at a loss, and
  by how much** against what was paid (Decision 10). The form is the design
  pass's call: the placeholder strings are "Gain $350", "Loss $150" and
  "Sold at cost" when the two are equal, in the same quiet moss/rust tone
  the Sell Plan and the detail screen already use for value-versus-cost; what
  is fixed is that the outcome and the amount are clear at a glance and that
  colour alone never carries the meaning. Above the rows, a short summary line — how many sold,
  total proceeds, and the realised gain or loss — the same figures the
  Dashboard card shows.
- Ordered **most recent sale first** (P3); the **Sort By** control is hidden on
  the Sold side, and there is no filtering or grouping in this version
  (Non-goals). Swipe-to-delete works on a sold row with the same confirmation
  as an owned one (P16).
- The **"…" menu stays on both sides** (P17): its **CSV export covers both
  sides** — the sale columns already say which side each row is on — its
  **PDF export stays owned-only**, and Import and Settings are unchanged.
- The Sold side's **empty state** ("Nothing sold yet…") shows when nothing has
  been sold, and when the last sale is returned or deleted while the side is
  open.

### The Dashboard

The person asked that the Dashboard take sales into account; this is the
proposal, for reaction at the draft (P7, P8):

- The collection figures are **unchanged in meaning** and simply exclude sold
  items: total current value, paid and the delta still describe what you own
  and reconcile exactly as `001` made them (value − paid = delta, valued items
  only).
- A new **Sold card** joins the Dashboard: a header **Sold**, the count and
  the total proceeds ("3 items · $2,400"), and the **realised gain or loss** —
  proceeds minus what was paid for those items ("+$350 vs paid"), in the
  moss/rust tone. Tapping it jumps to the **Sold side of the Items tab**,
  the way a category slice already jumps into Items. The card **hides
  entirely when nothing in scope has been sold**, so an existing install
  sees no change until its first sale.
- The card **follows the Dashboard's scope**: on the root it covers every
  sale; drilled into a category it covers sales in that category, hiding when
  there are none.
- Sold money and collection money are **never added together** anywhere on
  the Dashboard: the card sits apart from the totals, and no "lifetime" or
  "net position" figure combines them (Non-goals).
- The market line is unaffected except that sold items no longer count toward
  it.

### The Sell Plan

- Each Sell Plan row of a candidate gains **Mark as sold…** (Decision 4);
  marking it sold from here records the plan's wishlist item on the sale (P5)
  and removes the item from the candidates, since a sold item cannot be sold.
- The plan's header gains a **Sold** figure beside **Selected** and
  **Estimated cost** — the total of sales recorded toward this wishlist item,
  captioned with the count ("2 items") — shown only once at least one sale
  points at the plan (Decision 5). As `001` settled: three figures side by
  side, **nothing subtracted from the cost**, no gap, surplus or shortfall
  (Decision 5); the existing colour cue is unchanged in meaning and now reads
  from **Selected plus Sold** against the cost, so a plan whose sales alone
  meet the cost reads as met (P14).
- The sold items themselves are listed under the plan's candidates in a
  short **Sold** section — name, date, price — so the plan reads as a
  record of what was actually done toward it, not only what might be (P15).
- Deleting the wishlist item leaves its sales standing; they simply no longer
  point at a plan (P10). Buying the wishlist item, or turning it into an owned
  item, is a different feature (Non-goals).

### Exports and import

- **CSV** (Decision 7): three columns are **appended** to the items CSV, in
  this order, after `Year`: **Sold Date**, **Sale Price**, **Sold At** — and a
  fourth, **Sale Note**. They are blank for an unsold item and filled for a
  sold one, so an export of items **includes sold items** and is a complete
  record. The wishlist CSV is unchanged. The columns follow `011`'s schema
  rules exactly: appended at the end, never renamed or reordered, money and
  dates in the schema's existing formats, and the shipped-layout boundary
  recorded so an older file still imports as a prefix.
- **Import** (`012`) accepts the new columns: a row with a sold date and a
  sale price imports as a **sold item**; a row with neither imports as before;
  a row with one but not the other imports as **unsold**, and the dropped sale
  is a **counted default** in the import report, per `012`'s skip-and-report
  rules (P11). The Sold At and Sale Note columns without a date and price are
  ignored the same way. A sale imported from CSV points at no plan.
- **PDF** (Decision 7): the collection document describes what you own and
  **leaves sold items out**. A sold-items document is not part of this spec
  (Non-goals). The PDF's cover totals therefore match the Dashboard's
  collection figures, as they do today.
- `docs/csv-reference.md` and the sample files gain the new columns.

### Privacy and sync

- **Nothing new leaves the device.** No outside service is involved; there is
  no notice, and `PRIVACY.md` needs no new service entry. If its description of
  what the app stores enumerates item fields, it gains the sale details (P9).
- **Sale details sync** with the item, like every other item field — they are
  the person's own data — and, like every item field, are included in the CSV
  export and the "export everything" pair in Settings.

## Copy

The strings as shipped. Every one of them lives in `Trove/Models/SaleCopy.swift`
(T002, with the Design pass's changes at T008a) and is pinned whole by
`SaleCopyTests`; the wording below is the settled form, replacing the draft's
placeholders per P8 and Decisions 11–14.

- The action: **Mark as sold…** — in the detail's top-right menu (a "tag"
  symbol beside Edit's pencil and Delete's trash) and on each Sell Plan row.
- The sale sheet: title **Mark as sold**; fields **Sale price**, **Sold on**,
  **Sold at** (placeholder "eBay, Reverb, a friend…"), **Note** (placeholder
  "Anything worth remembering" — Decision 11); buttons **Cancel** and **Mark
  as sold**. Reopened for editing, the title is **Edit sale** and the confirm
  button **Save**.
- The sold mark on the item's page: the tag **Sold**, the sale in one line —
  "Sep 12, 2026 · $1,200 · eBay", the date in the device's own format and the
  place dropped when there isn't one, the word "Sold" dropped because the tag
  above it says so (Decision 11) — the sale's note as a quiet line beneath
  when there is one, and the outcome **"Gain $350 vs paid"** / **"Loss $150 vs
  paid"** / **"At cost"**.
- A Sold-side row's outcome: the same three strings. Decision 11 settled one
  form for the row and the page; the page only sets it larger, so
  `pageOutcome` forwards to `rowOutcome` and the two cannot drift.
- The page's actions: **Edit sale…**, **Return to collection…**, **Delete**.
- The return confirmation: "Return {name} to your collection?" / "Its sale
  details will be removed." with **Return** and **Keep as sold**.
- The Dashboard card: header **Sold**; "3 items · $2,400"; "+$350 vs paid" (a
  realised delta of zero reads "+$0 vs paid", as the Dashboard's Gain figure
  already does). The card carries its arrow and no word beside it (Decision 11).
- The Items tab's switch: **Owned** and **Sold**.
- The Sold side: summary "3 sold · $2,400 · +$350 vs paid", shown at all times
  — "0 sold · $0" when nothing is sold, the realised part dropped rather than
  set to "+$0", so the switch above it never moves (Decision 13, replacing
  Decision 11's hide-at-zero). Empty state "Nothing sold yet." / "Mark an item
  as sold from its page or from a sell plan."
- The Owned side emptied by selling: "Everything's sold." / "Add something
  new." (Decision 12) — not the first-launch state.
- The Sell Plan: the third figure's header **Sold**, captioned "2 items"; the
  section beneath the candidates titled **Sold**, kept under the empty state
  too, each of its rows opening with a compact **SOLD** tag (Decision 14).
- Sell Plan row action: **Mark as sold…**.
- **Delete** keeps `ItemDeleteCopy`'s existing word and confirmation; a sold
  item's message drops the sell-plan sentence and keeps the rest (P13).

## Design requirements

- A **Design pass, in-session with the `design` skill** (the pattern `002` and
  `005` used), for the genuinely new surfaces: the **Owned / Sold switch** at
  the top of the Items page (a bespoke in-page control in the family of the
  Sort By dropdown — the person's "two sides of the same view" is the brief,
  and a flip or turn is a fair thing for the pass to try, not a mandate), the
  **Sold card** on the Dashboard (it must sit apart from the collection totals
  and read as a separate ledger, not a fourth headline figure), the **Sold
  side's** row and summary, the **sold state** of the item detail screen (the Sold mark and
  sale line at the top of a page whose rest is the familiar detail), and the
  Sell Plan's **third figure and Sold section**. The design brief's rules
  apply; no rendered materials; the app's own type and tokens.
- The **sale sheet** is a form in the app's existing form style (the item
  form's fields, the money field's formatting, the date picker the item form
  uses for the purchase date).
- **System in the bars, bespoke in the page** (`013`): **Mark as sold…** joins
  the detail's system menu, which is the app's one system `Menu`; the Sell Plan
  row's action is a bespoke in-page control in the row's own style; the return
  confirmation and the delete confirmation are standard alerts (two-choice
  questions).
- Gain-or-loss figures use the **same moss/rust cue** the app already uses for
  value against cost — never a new colour, never red/green.
- The Dashboard card **hides rather than shows zero**, matching how the
  Dashboard already treats an unpriced collection.
- Every action is one tap plus, where something is discarded, one
  confirmation.

## Acceptance criteria

Fifteen of the seventeen were verified at T020's close-out (2026-09-15) — by
the unit suites, the UI suite, and the T019 device pass on an iPhone 18 Pro
(iOS 27.0) with the in-memory store. **Two are the person's own steps and stay
unticked**: criterion 15 (a second device signed into the same iCloud account)
and criterion 16 (Accessibility Inspector over the new surfaces). Each names
what the agent *did* verify, so what is left is exactly the observation nobody
has made yet.

1. [x] An owned item's detail screen offers **Mark as sold…** in its top-right
   menu beside Edit and Delete; the Items list's swipe does not offer it.
    *Verified by*: `SoldStateWiringTests.bothMenuRowsAndTheSoldEditLabelReadSaleCopy`
    and `theMenuIsComposedOnceWithItsRowsSwappedByTheSoldFlag` (one `Menu`, its
    rows chosen by `isSold`), `theOverflowMenuHostsExactlyOneSystemMenu`
    (`013`'s rule, re-confirmed by adding a second `Menu` → red); the swipe half
    by `ItemListSidesWiringTests.theOwnedRowsSwipesDoNotOfferMarkAsSold`
    (brace-span scan over the Owned rows' `.swipeActions`, `#require`ing its
    anchor). On the device (T019): the menu row present on an owned page and
    used from there; the swipe's contents are the scan's, not an observation.
    *Superseded by `014-sold-side-parity` (its spec, Decision 2): the Items list's swipe now offers **Mark as sold…** too, between Edit and Copy, with Edit nearest the edge.*
2. [x] The sale sheet requires a sale price (pre-filled with the current value
   when the item has one), defaults the date to today and refuses a future
   date, and takes an optional place and note. Cancel records nothing.
    *Verified by*: `SaleFormViewModelTests` — `refusesABlankPrice`,
    `refusesANegativePrice`, `acceptsAZeroPrice` (given away is a sale of $0),
    `refusesADateOneSecondInTheFuture`, `acceptsASaleDatedExactlyNow`,
    `acceptsADateYearsBeforeThePurchase` (P2), `markPrefillsTheCurrentValueAndToday`,
    `markLeavesThePriceBlankWithoutACurrentValue`,
    `trimsAndNilsTheBlankPlaceAndNote` (plan G18, G19); the picker's own bound
    by `SaleFormWiringTests.theDatePickerIsBoundedAtLatestDate` (mutation: drop
    the `in:` bound → red) and Cancel by `confirmingHandsTheSaleOutAndWritesNothing`
    (nothing in the view writes to a `modelContext`). On the device (T019): the
    picker's future days visibly disabled (screenshot), and a **probe inside
    `ItemSaleStore.markSold`** counted Cancel 0, swipe-down 0, a host re-render
    0, confirm 1 — the `.sheet(item:)` lesson from `002`/`005`, instrumented
    rather than eyeballed.
3. [x] Confirming the sheet marks the item sold with those details; the item's
   own fields and photos are unchanged.
    *Verified by*: `ItemSaleStoreTests.markingSoldLeavesTheItemsOwnFieldsPhotosAndMatchUntouched`
    (name, category, paid, value, desire, condition, photos, notes *and*
    `reverbProductID` — mutation: clear the match → red, G20) and
    `everyStoredSaleHasBothADateAndAPrice` (G9); the round trip by
    `ModelTests.aSaleRoundTripsAllFourFields` on a second `ModelContext`; the
    detail path by `ItemDetailViewModelTests.markSoldRecordsTheSaleOnNoPlanAndLeavesTheItemItselfAlone`.
4. [x] A sold item no longer appears in the Items list, in any Dashboard
   figure (value, paid, delta, counts, ruler, category breakdown, market
   line), or among any Sell Plan's candidates, and is removed from every plan
   it was selected on.
    *Verified by*: `ItemListViewModelTests.aSoldItemLeavesEveryOwnedFigureAndAppearsOnTheSoldSide`
    (mutation: drop `load()`'s split → red, G13);
    `DashboardViewModelTests.theCollectionFiguresExcludeSoldItemsAndStillReconcile`
    (value, spent, delta, counts, ruler, breakdown, `unvaluedDestination` and
    the market count, all over one sold item — mutation: count sold in `apply`
    → 13 issues, G22); `SellPlanViewModelTests.aSoldItemIsNeverACandidateEvenAtTheLowestDesire`
    (G12); the selections by `ItemSaleStoreTests.aSaleEmptiesEveryPlanSelectionAndLeavesTheWishlistEntriesStanding`
    (G4). On the device (T019): the row gone from the Items list, the Dashboard
    card appearing while the collection figures dropped the item, and the
    plan's candidate row gone.
5. [x] A sold item's device-local market figures are cleared on the sale and
   it is not refreshed afterwards.
    *Verified by*: `ItemSaleStoreTests.theSaleClearsThisItemsMarketRowsAndLeavesAnothersStanding`
    (mutation: drop the clear → red, G5) and
    `MarketRefresherTests.aSoldMatchedItemIsNoTarget` with
    `SettingsViewModelTests`' matched count following (mutation: drop the
    `soldDate == nil` clause → both red, G8). The match itself is kept
    (Decision 1, plan Q8), so Return resumes refreshing. On the device (T019):
    the Market section gone from the sold page, the market line dropping,
    Refresh skipping it, and the match back as never-refreshed-here after
    Return.
6. [x] The Dashboard shows a **Sold** card — count, total proceeds, realised
   gain or loss against what was paid — only when something in scope has been
   sold; it follows the category scope; tapping it lands on the Items tab's
   Sold side. The collection figures exclude sold items and still reconcile
   (value − paid = delta over valued items).
    *Verified by*: `DashboardViewModelTests.theSoldTotalsSumTheSalesInScope`,
    `theSoldFiguresFollowTheScope`, `hasSalesIsFalseWithNothingSold` (mutation:
    skip the scope filter for sold → red, G23), `theCardsLinesAreSaleCopyOverTheSameNumbers`
    and `theCollectionFiguresExcludeSoldItemsAndStillReconcile` (G22);
    `DashboardWiringTests.theCardIsComposedOnlyBehindTheSalesGate`,
    `theCardSitsBetweenTheCalloutAndTheBreakdownAndInsideNoFigure`,
    `tappingTheCardAsksTheRouterForTheSoldSide`,
    `theCardShowsTheViewModelsTwoLinesRatherThanWordsOfItsOwn` (each
    `#require`ing the `if viewModel.hasSales` anchor); the router by
    `AppRouterTests.showingTheSoldSideSwitchesTabsAndAsksForIt` and
    `theSoldRequestIsClearedOnceApplied`; end to end by the UI test
    `testTheSoldCardLandsOnTheSoldSideWhichListsSalesMostRecentFirst`. On the
    device (T019): the card at the root, inside a category, and hidden where
    nothing in scope sold. Recorded as designed (plan R1): a **category-scoped
    card lands on the whole Sold side**, which has no narrowing of its own —
    the person saw it at the Phase 5 pause and accepted it.
7. [x] The Items tab switches between **Owned** and **Sold** in one tap and
   opens on Owned at launch. The Sold side shows every sold item, most recent
   sale first, each row with name, sold date, sale price and gain or loss;
   each row making unmistakable whether it sold at a gain or at a loss and
   by how much; its summary line matches the card; Sort By is hidden there; swipe-to-delete
   works with the usual confirmation; the empty state shows when nothing is
   sold or the last sale is removed.
    *Verified by*: the side as plain view-model state, so Owned at every launch
    is true by construction (plan Q4) — `ItemListViewModelTests.switchingToSoldClearsEveryNarrowing`
    and `askingForTheSideAlreadyOnScreenLeavesTheFilterAlone` (G33),
    `theSoldSideLeadsWithTheMostRecentSaleThenNameThenID` (G14),
    `reorderingIsRefusedOnTheSoldSide`, `deletingWorksOnASoldItemToo`,
    `theSoldSidesEmptyStateIsNothingSoldOrStillSyncing`,
    `theEmptiedOwnedSideSaysEverythingSold` (Decision 12);
    `ItemListSidesWiringTests` for the screen —
    `theSoldSideRendersNoSortControlAndNoSearchField`,
    `theSoldRowsCarryOnlyTheTrailingDelete`,
    `theRowsFollowTheSideAndTheSoldBranchDrawsTheSoldRow`,
    `theSwitchReportsThroughShowAndBindsToNothing`,
    `theSwitchStandsOutsideTheEmptyState`,
    `theSoldSideReadsTheViewModelsSummaryLine`,
    `neitherSidesMetaLineIsConditional` (Decision 13),
    `theSwitchIsLabelledAndMarksItsActiveHalfSelected`; the row's words by
    `SoldItemRowTests` (`aRowOverALossReadsTheLossAndItsAmount`,
    `aRowOverAGainReadsTheGainAndItsAmount`, `aRowOverEqualFiguresReadsAtCost`,
    `theRowNamesTheSaleDateAndNotThePurchaseDate`,
    `theRowShowsTheSalePriceAndNotTheValueOrTheCost`, plus the rendered
    `aLossPaintsRustAndAGainPaintsMoss` / `anAtCostRowPaintsNeitherTone` — the
    words carry it, the colour repeats it). "Its summary line matches the card" — at the Dashboard root; a category-scoped card shows that scope's figures and lands on the unscoped Sold side (R1) —
    is one sum, not two: both read `SaleOutcome.totals` through `SaleCopy`
    (`SaleCopyTests.theSoldSideSummaryAtAGainALossAndZero`, G32's scan that
    neither view model does arithmetic of its own). On screen: the UI test
    above and `testMarkingAnItemSoldMovesItToTheSoldSideAndReturnRestoresIt`;
    on the device (T019, and the T018b/T018c checks) the switch, the three
    outcomes, Sort By hidden, the swipe delete with its confirmation and the
    re-count afterwards — the empty state *after the last sale is removed* is
    the UI test's assertion, which walks mark → Sold side → Return → "Nothing
    sold yet". **Measured, not eyeballed**
    (T018b, Decision 13): the switch's top edge sits at 154.3 pt on both sides
    with zero and with one sale, and the fill's travel is 9–11 distinct frames
    at 60 Hz over 164 ms, flat brightness — from a screen recording, since a
    screenshot cannot show motion.
7a. [x] From either side, the "…" menu's CSV export includes both owned and
   sold items and its PDF export includes owned items only; Import and
   Settings behave as before.
    *Verified by*: `SettingsViewModelTests.theItemsCSVIsOwnedInCustomOrderThenSoldInSoldSideOrder` (Settings' export-everything path),
    `aVisibleFilterNarrowsTheSoldHalfOfTheCSVToo` (G15),
    `switchingToSoldClearsEveryNarrowing` (so a CSV from the Sold side is the
    complete record — G33, the sign-off's blocking finding),
    `anAllSoldCollectionCanExportACSVButNotAPDF`,
    `aFilterThatExcludesBothHalvesDisablesTheCSVToo`, and
    `thePDFLeavesSoldItemsOutOfItsEntriesAndItsCover` (G16);
    `ExportWiringTests.eachExportRowDimsOnItsOwnGate` with
    `OverflowDropdownRenderTests` (G29 — two rows, one gate each, Import and
    Settings still ungated: broadened, not weakened). On the device (T019): a
    CSV taken from the Sold side read back from the container with both sides
    and the four new columns; the PDF owned-only.
8. [x] A sold item's page shows the Sold mark, the sale details and,
   unmistakably, whether it sold at a gain or at a loss and by how much
   against what was paid, with the item's content read-only beneath; it offers exactly **Edit sale…**, **Return to collection…** and
   **Delete**.
    *Verified by*: `SoldStateWiringTests.theSoldBranchStampsTheMark`,
    `theMarkReadsSaleCopyAndAnnouncesItselfAsOneElement`,
    `theSoldBranchOmitsTheMarketSectionAndFindAPhoto` (a brace-span scan that
    first `#require`s the `if viewModel.isSold` anchor found exactly once),
    `theSoldPagesDialIsNotInteractive` (the dial is handed a constant binding,
    so VoiceOver's adjustable action cannot write either),
    `theSaleSheetAndReturnAlertAreHostedHere` and the menu tests of criterion
    1; the words themselves by `SaleCopyTests.thePageOutcomeReadsTheSameAsTheRow`
    and `aLossNeverReadsAsAGain`. On the device (T019 and T014's check): the
    page at a gain, a loss and at cost against the approved artboards.
9. [x] **Edit sale…** changes the sale details in place; **Return to
   collection…** asks first, then restores the item to the collection with no
   sale and at its former order position, on no Sell Plan; **Delete** confirms
   and deletes permanently, photos included.
    *Verified by*: `ItemSaleStoreTests.editSaleKeepsThePlanLink` (G21),
    `markThenReturnLeavesSortOrderAndTheCustomSlotUnchanged` (the item back in
    its slot among three others — mutation: reset `sortOrder` on return → red,
    G7), `allThreeWritersBumpUpdatedAt` (Q13);
    `ItemDetailViewModelTests.returnToCollectionClearsAllFiveAndRestoresTheItemsSlot`,
    `editSaleKeepsAnEarlierPlanLink`, `theEditSheetIsSeededFromTheRecordedSale`
    and `deletingASoldItemRemovesItAndItsPhotos`; the alerts by
    `SoldStateWiringTests.theSaleSheetAndReturnAlertAreHostedHere` and
    `theDeleteAlertAsksTheItemWhichSideItIsOn` over
    `ItemDeleteCopyTests.theSoldMessageDropsTheSellPlanLineAndKeepsTheRest`
    (G17). On screen: `testMarkingAnItemSoldMovesItToTheSoldSideAndReturnRestoresIt`.
    On the device (T019): edit in place, Return landing back at its Custom
    slot on no plan, and the shorter delete message on a sold row.
10. [x] A Sell Plan row offers **Mark as sold…**; sold from there, the sale
    points at that wishlist item, and the plan shows a **Sold** figure beside
    Selected and Estimated cost with the count, plus a Sold section listing
    the sale — with nothing subtracted from the cost anywhere on the screen.
    The colour cue reads Selected plus Sold against the cost.
    *Verified by*: `SellPlanViewModelTests.aSaleFromThePlanPointsAtItAndTheRowLeavesTheCandidates`
    (G6/G12), `theSoldFigureIsAThirdIndependentFigureAndTheCostIsUntouched`
    (mutation: subtract sold from the cost → red, G10),
    `theCueReadsTheSelectionAndTheSalesTogether`, `salesAloneCanMeetTheCost`,
    `salesShortOfTheCostDoNotMeetIt`, `anEmptyPlanWithNoSalesNeverReadsAsMeetingTheCost`
    (G11, P14), `soldItemsReadMostRecentSaleFirst`; the screen by
    `SellPlanWiringTests.theSoldCellIsInsideTheHasSalesBranchAndNowhereElse`,
    `theHeaderSubtractsTheSaleFromNothing`,
    `theSoldSectionFollowsTheCandidatesAndOnlyWhenThereAreSales`,
    `theSoldSectionIsHostedUnderTheEmptyStateToo` and
    `eachSoldRowCarriesTheSoldMark` (Decision 14 — mutation: drop the section
    from the empty branch → red),
    `theSoldSectionListsTheSalesAndAddsNothingUp`,
    `theRowsControlIsASecondTapTargetThatSetsTheSaleCandidate`,
    `theSheetIsTheOneSaleFormOverTheOneSeedingRule` (one component, one
    seeding rule, not a second form) and `theNewCopyIsNeverTypedInline`, with
    `SellPlanFramingTests`' term scan still refusing any "remaining"/"gap"
    wording (`001`'s framing rule, re-confirmed by adding the word → red). On
    screen: `testASellPlanRowSoldFromThePlanShowsTheSoldFigure` reading the
    combined `sellPlan.soldFigure` element (mutation: `markSold(toward: nil)`
    → red). On the device (T017/T018c checks): the two- and three-figure
    headers, the section at one and two sales, and — per Decision 14 — the
    section still listed under the empty state once every candidate is sold,
    each row opening with a SOLD tag.
11. [x] Sold from the detail screen, a sale points at no plan; deleting a
    wishlist item leaves its sales standing.
    *Verified by*: `ItemSaleStoreTests.theSaleLinksToAPlanOnlyWhenOneIsPassed`
    (G6) and `ItemDetailViewModelTests.markSoldFromTheDetailLeavesTheItemOnNoSellPlan`
    (mutation: the detail passing a plan → red);
    `WishlistDeletionTests.deleteLeavesSalesRecordedTowardItStandingWithNoPlan`
    (mutation: the relationship's `.nullify` → `.cascade` → red, G3) and
    `SellPlanViewModelTests.aSaleRecordedFromTheDetailIsOnNoPlan`. On the
    device (T019): deleting the wanted item left its sale standing.
12. [x] The items CSV export carries four appended columns — Sold Date, Sale
    Price, Sold At, Sale Note — blank for unsold items and filled for sold
    ones, so sold items are included; the wishlist CSV is unchanged; an
    export from before this spec still imports as a prefix.
    *Verified by*: `ExportSchemaTests.headerListsMatchThePinnedSchema` and
    `theLegacyLayoutsArePinnedByLiteralName` (the boundaries `[12, 14]` by
    literal — mutation: add a speculative `13` → red, G24),
    `itemRecordCarriesTheSaleFromTheModel`, `theSaleCellsAreBlankWhenOwnedAndFilledWhenSold`
    (mutation: write the price for an owned row → red, G25) and
    `itemRowCarriesEveryColumnInHeaderOrder`; the prefix rule by
    `ImportSchemaTests.theTwoLegacyItemWidthsPassAndTheWidthsBetweenThemDoNot`
    (18/14/12 accepted, 13 and 17 refused — mutation: accept any prefix → red,
    G26), `aLegacyFileImportsWithNoMatchAndNoYear` and
    `DocsSampleTests.itemsResavedToleratesTransportDamage` over the
    14-column fixture kept deliberately (G30). The wishlist CSV is untouched
    (`wishlistRowCarriesEveryColumnInHeaderOrder`). Documented in
    `docs/csv-reference.md` and `docs/samples/items-full.csv` (T007). On the
    device (T019): a real export read back with the four columns.
13. [x] Import creates a sold item from a row with both a sold date and a sale
    price, an unsold item from a row with neither, and an unsold item with a
    counted default from a row with only one; an imported sale points at no
    plan.
    *Verified by*: `ImportSchemaTests.aSoldRowCarriesAllFourCellsAndADroppedOneCarriesNone`,
    `theSalePairRuleCountsOneDefaultPerDroppedSale` (five cases, counts
    0/1/1/0/1 — mutations: one default per *cell* → 2 ≠ 1 red; a lone half
    accepted → the unsold assertion red; G27, plan R3),
    `aSoldRecordRoundTripsThroughTheCSV`, `aZeroSalePriceImportsAsAnItemGivenAway`
    and `aNegativePriceDropsTheSaleAndAFutureDateImportsAsWritten` (plan Q6's
    two stated asymmetries: the parser rejects a signed price, and it has no
    clock, so a future sold date imports as written exactly as `Purchase Date`
    does); the commit by `ItemListViewModelTests.commitRestoresTheSaleAndPointsAtNoPlan`
    (mutations: drop `sale`, or set a plan link → red) and
    `DocsSampleTests.itemsFullImportsCleanly` over the two sold sample rows.
14. [x] The PDF export leaves sold items out and its cover totals match the
    Dashboard's collection figures.
    *Verified by*: `ItemListViewModelTests.thePDFLeavesSoldItemsOutOfItsEntriesAndItsCover`
    and `SettingsViewModelTests.theEverythingPDFLeavesSoldItemsOut` (both
    paths — mutation: hand the composer every item → red, G16). The cover
    totals are the list view model's owned-only arithmetic, the same figures
    the Dashboard computes, so they match by construction (plan Q5) and
    criterion 6's reconciliation test covers the other half; byte identity
    with Settings survives a sale
    (`SettingsViewModelTests.theListsUnfilteredCSVStillMatchesSettingsByteForByteWithASalePresent`,
    G28). On the device (T019): the PDF owned-only from both paths.
15. [x] **Attested by the person, 2026-09-16** — marking as sold and returning to the collection both synced across two iCloud devices. (Was pending at the merge.) Sale details sync with the item to a
    second device signed into the same iCloud account (attested by the person,
    or recorded as an honest partial as `005` did).
    *What was verified*: `CloudKitSchemaTests.schemaMeetsCloudKitRequirements`
    builds a real `ModelContainer` against a CloudKit `ModelConfiguration` with
    the five additions and validates — the **red run is recorded** (T001:
    `soldDate` declared non-optional without a default → "CloudKit integration
    requires that all attributes be optional, or have a default value set",
    naming `Item: soldDate`, G1), which is what makes the fields syncable at
    all; and `ModelTests.aSaleRoundTripsAllFourFields` for the four fields and
    the link travelling with the item on a second context. The sale is stored
    *on* the item (plan Q1), so it is one CloudKit record on the path `001`'s
    item fields already take — there is no second record that could arrive
    out of order. **Nobody has watched a sale arrive on a second device**: no
    second device was available, exactly as `005`'s criterion 4 recorded.
16. [x] **Attested by the person, 2026-09-16** — every listed element passed Xcode's Accessibility Inspector. (Was pending at the merge.) VoiceOver: **Mark as sold…**, the
    Owned / Sold switch and which side is showing, the Sold card, each
    Sold-side row, the sold mark and the sale line, and the Sell Plan's Sold
    figure are labelled; a sold item is announced as sold with its price and
    date.
    *What was verified*: every one of those surfaces is a combined element
    with a label the tests read — `SoldStateWiringTests.theMarkReadsSaleCopyAndAnnouncesItselfAsOneElement`
    (the mark reads "Sold", the sale line and the outcome as one element),
    `DashboardWiringTests.theCardIsOneElementWithAHintAndAnIdentifier`,
    `ItemListSidesWiringTests.theSwitchIsLabelledAndMarksItsActiveHalfSelected`
    (label "Owned or sold", the value the current side, `.isSelected` on the
    active half), `SellPlanWiringTests.eachSoldRowCarriesTheSoldMark`, and the
    `sellPlan.soldFigure` cell combined and identified at T017a. The Sold-side
    row combines its children too (`SoldItemRow`'s
    `.accessibilityElement(children: .combine)` with the stock-photo value),
    and `SoldItemRowTests` pins the words that combination is made of, though
    no unit test asserts the combining itself — the UI test below is what reads
    the resulting label. The UI suite
    reads these labels for real rather than by inspection —
    `testTheSoldCardLandsOnTheSoldSideWhichListsSalesMostRecentFirst` matches
    on the rows' combined labels ("Gain $350", "Loss $150") and
    `testASellPlanRowSoldFromThePlanShowsTheSoldFigure` on the Sold figure's
    one label. **What is left is the reading itself**: Accessibility Inspector
    (or VoiceOver on a device) over the menu rows, the switch, the card, a
    Sold row, the sold mark and the plan's Sold figure. Note for that pass:
    the plan's sold row announces "Sold" *first*, before the name (Decision
    14's tag), which is what T019's finding F1 turned up.

## Decisions record

Made by the person, 2026-09-13, in this spec conversation:

1. **A sold item stays in the app and leaves the collection.** It disappears
   from the Items list, every Dashboard figure, Sell Plan candidates and the
   collection exports, and keeps its photos, notes, details and history in a
   Sold side of the Items tab. Chosen over "delete it and keep a small sale record", which
   would lose the photos and make a mistaken sale unrecoverable.
2. **A sale records price, date, place and an optional note.** Price defaults
   to the current value, date to today. No fees or shipping in this version.
3. **A sale can be undone, and a sold item can be deleted.** Return to
   collection restores the item exactly as it was; Delete keeps today's
   confirmation and permanence.
4. **Mark as sold… lives in the detail's top-right menu and on Sell Plan
   rows.** Not on the Items list's swipe, which stays delete-only.
   *Superseded by `014-sold-side-parity` (its spec, Decision 2): Mark as sold… is on the Items list's swipe as well, sitting between Edit and Copy with Edit nearest the edge.*
5. **The Sell Plan learns what was sold toward it, and still subtracts
   nothing.** A sale sold from a plan remembers that wishlist item; the plan
   shows a Sold figure beside Selected. `001`'s no-arithmetic framing holds.
   Buying the wishlist item with the proceeds is a separate feature.
6. **A Dashboard card shows sales at a glance and jumps to the Sold side.**
   "N sold · $X realised", following the roadmap's own reasoning (`009`) that
   a new place to be is a card, not a fourth tab. Rows show name, date, price
   and gain or loss. The card, the Sold side and the Sell Plan are the only
   places sold money appears. (Amended by Decision 9: the card's destination
   is the Items tab's Sold side, not a screen of its own.)
7. **Exports and market data.** Sale columns are appended to the items CSV so
   a full export includes sold items and round-trips through import; the PDF
   stays a document of what you own; a sold item's market figures are cleared
   on this device as deletion clears them today.
8. **The Dashboard takes sales into account** — the person asked for this to
   be considered; the shape (the Sold card apart from the collection totals,
   scoped, hidden at zero, sold money never combined with collection money) is
   proposed at P7 and confirmed or amended when the person approves the Draft.

Added 2026-09-13, at the person's reading of the Draft:

9. **The Items tab has two sides, Owned and Sold, one tap apart.** The
   person's proposal — "almost like two sides of the same view" — in place of
   the Draft's standalone Sold list reached only from the Dashboard. Sold
   items are things you used to own, so Items is where you'd look for them;
   the card on the Overview tab hides at zero and put the list two taps away;
   and a switch inside the page is a bespoke Trove control under `013`'s
   rule, which the design pass can make literal. The Dashboard card stays
   and jumps to the Sold side. Consequences settled with it: Sort By hides on
   the Sold side (P16), the "…" menu's CSV export covers both sides and the
   PDF stays owned-only (P17).
10. **Gain or loss, and by how much, is unmistakable on the Sold side's rows
    and on the sold item's page.** Not only a signed figure in a colour: each
    row and the page make clear that the item sold at a gain or at a loss and
    by how much against what was paid ("at cost" when equal). The person's
    note at approval — and their clarification the same day that the literal
    wording ("Sold at a gain…") is *not* required: the strings in Copy are
    placeholders, and the design pass settles the form (words, a labelled
    figure, a mark) as long as colour alone never carries the meaning.
11. **The design pass's form and copy, settled by the person at the pass
    (2026-09-13).** The outcome reads words first, then the amount, then
    the basis, the same on a row and on the page: "Gain $350 vs paid" /
    "Loss $150 vs paid" / "At cost" — the colour only repeats the word.
    The Sold side's summary line is hidden when nothing is sold. The sold
    page's sale line drops the word "Sold" (the tag above it says it):
    "Sep 12, 2026 · $1,200 · eBay". The sale's note shows as a quiet line
    under the sale line when there is one. The Note field's placeholder is
    "Anything worth remembering". The Dashboard card carries only its
    arrow, no word beside it. The desire card on a sold page shows no hint
    line. These replace the Copy section's placeholders at close-out (P8).
12. **An Owned side emptied by selling gets its own empty state (2026-09-14,
    at the Phase 5 start).** When everything the person owns has been marked
    sold, the Owned side no longer shows the first-launch "No gear yet"
    state — it says something like "Everything's sold. Add something new."
    — because the person has been using the app, not just installed it.
    Chosen over reusing the first-launch state (option 1). The Sold side's
    own empty state is unchanged.

13. **The Sold side keeps a stats line under the header at all times, and
    the switch never moves (2026-09-15, at the Phase 5 pause).** The person
    saw the Owned/Sold switch jump up on the Sold side. The Sold side shows
    its summary line in the same place as the Owned side's item stats even
    when nothing is sold ("0 sold · $0"), replacing Decision 11's "hidden
    when nothing is sold". The switch's slide must be fast and smooth; the
    person saw it stutter at a low frame rate.
14. **A Sell Plan keeps listing its sold items even when no candidates
    remain, each clearly marked sold (2026-09-15, at the Phase 5 pause).**
    The person's answer to the Phase 5 question: the sold items remain on
    the plan under the empty state too, and each row makes it clear the
    item has been sold. (Read as: the Sold section stays with the empty
    state, and its rows carry a Sold mark — not sold rows mixed into the
    candidate list.)

15. **A Sell Plan whose every item has sold says so (2026-09-16, after the
    merge).** The empty state above the plan's sold list no longer reads
    "Nothing to sell yet — Add the gear you own…"; it reads along the lines
    of "Everything on this plan has sold." Fixed on `fix/006-post-merge`.
16. **Deferred to a new spec (2026-09-16):** a visible Mark as sold button
    on the item page and a leading-swipe action on Items rows (reverses
    Decision 4 and criterion 1), and the Sold side gaining search, category
    chips and Sort By with "Date sold" and context-fitting options (reverses
    P16's "no filtering or sorting on the Sold side" and Q15's clearing
    rule). Both are design changes to shipped behaviour, so they get a spec
    of their own rather than a fix branch.

Proposed at drafting, 2026-09-13, by Claude Code (these become decisions on
plan approval):

- **P1. Sale price is required.** Pre-filled with the current value when the
  item has one; blank and required otherwise, because a sale without a price
  is the one fact this feature exists to record.
- **P2. The sale date cannot be in the future.** Any past date is allowed,
  including before the purchase date (data entry is the person's; the app
  does not second-guess it). Default: today.
- **P3. The Sold side is ordered most recent sale first**, with no sort or
  filter controls in this version.
- **P4. A sold item's page is the existing detail screen in a sold state**,
  read-only beneath a Sold mark, with exactly three actions: Edit sale…,
  Return to collection…, Delete. Editing the item's own fields while sold is
  not offered.
- **P5. A sale points at a wishlist item only when sold from that item's Sell
  Plan.** Sold from the detail screen, it points at none; there is no picker
  to attach a plan after the fact.
- **P6. Marking sold removes the item from every plan's selection**, exactly
  as deletion does today; the funding link is a separate fact on the sale,
  not a selection.
- **P7. The Sold card** — header, count and proceeds, realised gain or loss —
  sits apart from the collection totals, follows the Dashboard's scope, and
  hides when nothing in scope is sold.
- **P8. Copy this spec doesn't fix is settled at the copy and design tasks**
  and joins the Copy section on plan approval.
- **P9. Sale details are item data**: they sync, they export, nothing leaves
  the device, and `PRIVACY.md` changes only if it enumerates stored item
  fields.
- **P10. Deleting a wishlist item leaves its sales standing**, pointing at no
  plan.
- **P11. Import treats a sale as a pair**: a sold date and a sale price
  together make a sold item; either alone is dropped as a counted default and
  the item imports unsold.
- **P12. Returning an item to the collection does not rejoin any Sell Plan.**
  The selections it was removed from at the sale are not remembered.
- **P13. The delete confirmation for a sold item omits the sell-plan
  sentence** — a sold item is on no plan — and keeps the rest.
- **P14. The Sell Plan's colour cue reads Selected plus Sold against the
  cost.** Still a boolean cue, still no figure; a plan funded by sales alone
  reads as met.
- **P15. The Sell Plan lists the sales made toward it** in a short Sold
  section under the candidates — name, date, price — so the plan is a record
  of what was done as well as what might be.
- **P16. The Items tab opens on Owned at every launch**; the side is not
  remembered across launches, and the Dashboard card is what lands on Sold.
  Sort By is hidden on the Sold side, which is always most recent first;
  swipe-to-delete works on a sold row with the same confirmation as an owned
  one, since Delete is one of the sold page's three actions anyway.
  *Superseded by `014-sold-side-parity` (its spec, Decision 3 and P6): Sort By is offered on the Sold side too, with its own five options — Date sold, Price, Paid, Gain, Name — defaulting to Date sold, newest first.*
- **P17. The "…" menu is the same on both sides.** Its CSV export covers
  both owned and sold items (the file is the complete record and the sale
  columns mark the side), its PDF export stays owned-only (the collection
  document), and Import and Settings are unchanged. Export follows the tab,
  not the side.

## Non-goals (explicit)

- **Fees, shipping, or net proceeds** — a single sale price, nothing deducted
  (Decision 2).
- **Buying the wishlist item**, turning a wishlist item into an owned item, or
  any "acquired" tracking — a separate feature (Decision 5).
- **Any figure that combines sold money with collection money** — no
  lifetime, net-position or "total ever spent" figure on the Dashboard.
- **Sales over time** — no chart, no year filter, no grouping; the Sold side is
  a flat, dated list. A natural follow-up once there is history to show.
- **Sorting, filtering or searching the Sold side**, or mixing sold items into
  the Owned side behind a filter — the two sides stay distinct.
  *Superseded by `014-sold-side-parity` (its spec, Decisions 3 and 4): the Sold side gains its own search, category chip and sort, and each side keeps its own across a switch; the two sides still stay distinct.*
- **A sold-items PDF**, or sold items in the collection PDF (Decision 7); the
  Sold side's "…" offers the same owned-only PDF as the Owned side (P17).
- **Multiple sales per item, quantities, or partial sales** — an item is sold
  once, whole.
- **Editing an item's own fields while it is sold** — return it first (P4).
- **Attaching a sale to a plan after the fact** (P5).
- **Recovering a deleted sold item** — Delete stays permanent; a recycle bin
  remains `010`'s deferral.
- **Any market "sold" figure** — `002`'s rule stands; the only sold price in
  the app is the one the person types.
- **Listing management** — posting to eBay or Reverb, tracking a listing's
  status, or anything before the sale itself.
- **Currencies other than USD** — the app is single-currency; the sale price
  is in the item's currency.

## Inherited caveats

- `001`'s fixed type sizes apply to the new surfaces.
- The app is USD-only and single-region; nothing here changes that.
- `011`'s append-only CSV rule governs the new columns; `012`'s
  skip-and-report rules govern their import.
- `013`'s "system in the bars, bespoke in the page" rule places the action.
- A UI test that needs sold items starts from a seeded in-memory store under
  its own launch argument, per `CLAUDE.md`'s amended `-uiTesting` rule
  (`003`'s pattern); the flag alone keeps starting from an empty collection.
- `010`'s "no recycle bin" deferral stands: a deleted sold item is gone.

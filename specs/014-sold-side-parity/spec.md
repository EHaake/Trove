# 014 — Sold-Side Parity and Mark as Sold on the Swipe

**Status**: **Approved** (2026-09-16) — written with the person in this spec
session from the requests carried out of `006` (its Decision 16, which
deferred exactly these two changes to a spec of their own), and revised the same day at the person's reading of the
first Draft (Decisions 1–6) and approved the same day with P9 and P11 confirmed. Every product decision below was made by the
person and is listed in the Decisions record; the P-items are Claude Code's
proposals and become decisions on plan approval, as `006`'s did.

Authored in a Claude Code spec session of its own, per `CLAUDE.md`'s model
policy (Fable 5.1, the session raised to high effort for the spec
conversation).

**Depends on**: `006-mark-as-sold` (the sale, the Sold side, the sale sheet,
the sold page's Sold mark this spec moves), `010-item-management-enhancements`
(the Items list's search, category chips, Sort By and leading swipe, which the
Sold side now shares), `011-data-export` (the CSV's narrowing rule, which the
Sold side's narrowing now feeds), `013-settings-menu` (the "…" menu stays
the one system `Menu`). It touches no network code and no schema; the CSV
schema is unchanged, and the PDF gains a sold document (Decision 7, amended
2026-09-18 at the Phase 2 pause).

## Summary

`006` gave Trove a Sold side and a way to record a sale, and then the person
used it. Two things were harder than they should be. **Mark as sold…** was
hidden in the item page's "…" menu, where the person did not find it, and it
was not on the Items list's swipe at all — so the one action the feature
exists for took a hunt. And the Sold side was a flat list: no search, no
category chips, no sort, so once a few sales were in it there was no way to
find one. This spec fixes both: a **Mark as sold action on the Items list's
leading swipe**, opening the same sale sheet as before; and the **Sold side
gains the search bar, the category chips and Sort By**, matching the Owned
side, with sort options that make sense for things already sold — **Date
sold** first — and **each side keeps its own search, chip and sort while you
switch between them**. One more thing the person asked for on reading the
Draft: on a sold item's page the Sold mark — outcome, date, price, place —
moves from above the photo to **directly under the item's name**.

A visible Mark as sold button on the item page was in the first Draft and
was taken out at the person's reading (Decision 1): the page's bottom is not
to become a shelf for more and more actions. It is on the roadmap as a
consideration, not a plan.

## What and why

`006` Decision 4 put Mark as sold… in the detail's "…" menu and on Sell Plan
rows, and kept the Items swipe delete-only, on the reasoning that a sale is
a considered act. In use the opposite held: the person did not find the menu
row (recorded at `006`'s close-out and in the roadmap), and the swipe — the
lowest-friction gesture in the app, already carrying Edit and Copy — is
where a hobbyist who has just shipped a guitar reaches first. The sale sheet
that follows is still the considered step: nothing here makes a sale a
single tap. The menu row stays where it is; the swipe is the second way in,
not a replacement.

`006` P16 kept the Sold side without narrowing or sorting "in this version",
as a scoping call, not a design one. With sales accumulating the Sold side
needs what the Owned side has, and the reason `006`'s plan gave for sharing
one narrowing function across both halves — "a narrowing is about which
gear, and sold gear still has a category, a name and a value field" (`006`
plan Q5) — is the reason the same controls fit. The one place the sides
genuinely differ is what you would sort by: a sold item has no manual order,
no market figure and no desire to keep, and it has a sold date, a sale price
and an outcome the Owned side does not.

This spec reverses three things `006` fixed, and says so rather than
patching around them: Decision 4 and criterion 1 (the swipe stays
delete-only), P16 and Non-goals (no narrowing or sorting on the Sold side),
and Q15/G33 (switching sides clears the narrowing — replaced by each side
keeping its own). `006`'s
`spec.md` and `plan.md` are annotated in place at this spec's plan approval
to point here (Inherited caveats).

## Core behavior

### Mark as sold on the Items list's swipe

- The Owned side's rows gain **Mark as sold…** on the **leading** swipe,
  between Edit and Copy: Edit stays nearest the edge, so a full swipe still
  edits (Decision 2). It opens the sale sheet for that item, directly, with
  the same defaults as everywhere else, and the sale points at no plan
  (`006` P5); the swipe never records a sale by itself. Cancelling the sheet
  leaves the item exactly as it was.
- The item page's "…" menu is unchanged in both states. No visible button
  is added to the page (Decision 1).
- The trailing swipe stays delete-only on both sides. The Sold side's rows
  gain no leading swipe (a sale is edited and returned from the item's page,
  as today).
- The Sell Plan rows' Mark as sold… is unchanged.

### The Sold side gains the Owned side's controls

- The Sold side shows the **search field**, the **category chips** and the
  **Sort By** control in the same places, at the same sizes, as the Owned
  side — so switching sides moves nothing in the header (`006` Decision 13
  still holds: the switch never jumps). The controls appear once anything
  has been sold, under the same "controls need a list to narrow" rule the
  Owned side uses at zero items.
- **Search** matches name and serial number, as on Owned.
- **Category chips** are built from the categories of sold items, with the
  same "All" chip and the same reveal-on-select behaviour. The Owned side's
  **Un-valued** chip does not appear on the Sold side: a sold item's current
  value is no longer something the app has an opinion about (`006`,
  `SoldItemRow`'s reasoning), so "unvalued" is not a way to narrow it.
- The **summary line** under the title follows the narrowing on the Sold
  side as it does on Owned: "2 sold · $1,900 · Gain $350" over the rows on
  screen, "0 sold · $0" when a narrowing matches nothing — still always
  present, so the switch never moves (P4). The Dashboard's Sold card keeps
  showing the whole side.
- A Sold side narrowed to nothing shows the Owned side's **no-matches**
  empty state with its filter copy, not "Nothing sold yet" — the same
  precedence rule, both sides (P5).

### Sort By on the Sold side

- The Sold side's Sort By offers, in this order (Decision 3, P6):
  - **Date sold** — most recent sale first. The default, and the order the
    side has had since `006` (its P3).
  - **Price ↓** / **Price ↑** — by sale price.
  - **Paid ↓** / **Paid ↑** — by what was paid for it.
  - **Gain ↓** / **Gain ↑** — by the sale's outcome against what was paid:
    Gain ↓ puts the largest gain first and the largest loss last; Gain ↑ the
    reverse.
  - **Name** — alphabetical.
  The labels are placeholders settled at planning from the existing sort
  labels (Decision 5), with one fixed rule: a reader must be able to tell
  which end a loss sorts to.
- No **Custom** (a sold item has no manual order; "Date sold" is the order
  the CSV writes), no **Market** (a sold item's market figures are cleared
  on the device, `006` Decision 7), no **Desire** (a sold item has none).
- **Ties** fall back to the Sold side's existing order — sold date, then
  name, then id — so every sort is total and the same rows never swap
  between two loads (P7).
- The Owned side's Sort By is unchanged; "Date" there still means purchase
  date. Each side keeps its own sort selection, as it keeps its own
  narrowing (below).

### Switching sides

- **Each side keeps its own state** — its search text, its chip, its sort,
  and on Owned the Un-valued chip too — and switching sides shows the other
  side exactly as you left it (Decision 4). Searching "Fender" on Owned,
  going to Sold and coming back finds "Fender" still in the field and the
  rows still narrowed; the Sold side meanwhile shows whatever it was showing
  before. Neither side's state leaks into the other's, and nothing is
  remembered across launches: both sides start clean, Owned on "Date" and
  Sold on "Date sold" (P8). This replaces `006` Q15's clearing rule.
- What the controls show is always the side on screen, so a narrowing is
  never in force without its chip or query visible.
- The **Dashboard's Sold card** goes to the Sold side as it currently stands
  within the launch (P9); the Dashboard's category routes still set the
  Owned side's chip and land on Owned, as today.

### Exports

- The CSV's rule is unchanged in words and now bites on both sides: the
  file is the Owned rows that pass the **on-screen side's** narrowing, in
  visible order, then the sold rows that pass the same narrowing, in
  Sold-side order (`006` Q5). The other side's own, hidden narrowing plays
  no part (P11) — a file is never narrowed by something not on screen. A
  CSV exported from a Sold side narrowed to "Cameras" holds owned and sold
  cameras, and the coverage label says so. With no narrowing on the side on
  screen the file is the complete record.
- The Sold side's **sort choice does not change the CSV's sold order**: the
  file's sold rows are always in Date-sold order (P10), the way Settings'
  export-everything CSV writes them, so `013`'s byte-identity between the
  two paths still holds.
- From the Items list, each export row asks which items — **Owned items**,
  **Sold items**, or **Owned and sold** — before the share sheet (Decision 7,
  P12; amended 2026-09-18 at the Phase 2 pause, replacing "The PDF stays
  owned-only"). Every choice follows the side on screen's narrowing (P11).
  The owned file is today's; the sold CSV is the sold rows that pass, in
  Date-sold order (P10); the sold PDF is a document titled "Sold Items" whose
  cover totals what those items sold for, what was paid and the realised gain
  or loss, and whose entries show the sale under the name (P14). "Owned and
  sold" is one CSV — the complete record, byte-identical to Settings' when
  unnarrowed — and, as a PDF, the two documents in one share sheet (P13). A
  choice with no rows is disabled. Sold-only files are named
  `Trove-Sold-Items-<date>` (P15). Settings' Export All is unchanged. The
  Wishlist's exports are unchanged. Import is untouched.

### The sold page's mark

- On a sold item's page the **Sold mark** — the SOLD tag with the outcome
  ("Loss $150 vs paid"), the sale line (date · price · place) and the note —
  moves from the top of the page, above the photo, to **directly under the
  item's name** (Decision 6): photo, then name, then the mark, then the
  paid/value stats and the rest of the read-only page as today. Its words,
  colours and VoiceOver reading are unchanged; only its place moves.

## Copy

Settled at planning and shipped as written — the placeholders below became
decisions on plan approval, and these are the strings that are in the build:

- **Leading swipe action**: "Sell" on the button (`SaleCopy.swipeSell`) —
  "Mark as sold" does not fit the 76 pt action width beside a glyph at the
  swipe's label size — with **"Mark as sold…"** (`SaleCopy.markAsSold`, the
  "…" menu row's own name) as the spoken name, so the same action is
  announced the same way from both places (plan Q9). XCUITest read the button
  back as "Mark as sold…" at T009, so the modifier took.
- **Sort options**, in menu order: "Date sold", "Price ↓", "Price ↑",
  "Paid ↓", "Paid ↑", "Gain ↓", "Gain ↑", "Name"
  (`ItemListViewModel.SoldSortOrder.label`), defaulting to "Date sold". `↓` is
  largest first, the Owned side's convention, which is what carries the one
  fixed rule — a reader can tell which end a loss sorts to — by the glyph and
  never by colour.
- **The export scope chooser** (Decision 7): headers "EXPORT AS CSV" /
  "EXPORT AS PDF" (`ExportCopy.scopeTitleCSV` / `scopeTitlePDF`), rows "Owned
  items" / "Sold items" / "Owned and sold"
  (`ItemListViewModel.ExportScope.label`), dismiss catcher "Dismiss export
  options". The sold document's title is "Sold Items"
  (`ItemListViewModel.soldDocumentTitle`), its cover eyebrows TOTAL SOLD FOR,
  TOTAL PAID and REALISED, its count line "N sold". Filenames:
  `Trove-Sold-Items-<YYYY-MM-DD>` for sold-only files, `Trove-Items-<YYYY-MM-DD>`
  for owned and for owned-and-sold (P15).
- The Sold side's no-matches state reuses the Owned side's copy.

## Design requirements

- **No design pass** (Decision 5): everything here is settled at planning
  from `design/tokens.md` and the components that exist.
- **The leading swipe keeps `010`'s swipe-row rules**: 76 pt per leading
  action, rust the only consequential colour on a swiped-open row. Mark as
  sold is not destructive and is followed by a sheet, so it takes a neutral
  or brass tint, never rust; planning picks the tint and the glyph (a
  template icon from `design/icons/`, like Edit's and Copy's, not an SF
  Symbol).
- **The sold page's mark keeps its own look** — unplated, a stamp on the
  page — in its new place under the name; the gap above and below it is the
  page's standing section gap.
- **Nothing in the header moves when the side changes.** Search, chips and
  Sort By occupy the same slots on both sides; `006` Decision 13's
  measurement (the switch's top edge at the same point on both sides) is
  re-taken with the controls present.
- **Colour never carries a sort direction alone**: the arrow glyphs in the
  labels do.
- Fixed type sizes (`001`) apply.

## Acceptance criteria

Thirteen of the fourteen were verified at T011's close-out (2026-09-18) — by
the unit suite (**1540 tests in 208 suites**), the UI suite (**23 tests, run
twice back to back**), and the T010 device pass on the simulator, walked twice:
once over the seeded states and once over the person's own 7 owned / 6 sold
collection, loaded through the app's own import. **Criterion 12 is an honest
partial and stays unticked** — the Accessibility Inspector sweep is the
person's own step, and what an agent could read of it is recorded there.
Each criterion below names what was actually verified, so what is left is
exactly the observation nobody has made yet.

1. [x] On the Owned side, a row's leading swipe offers Edit, Mark as sold…
   and Copy in that order; a full swipe still edits; Mark as sold… opens the
   sale sheet for that row's item, and cancelling it changes nothing. The
   trailing swipe is still delete-only on both sides, and Sold rows have no
   leading swipe.
    *Verified by*: `ItemListSidesWiringTests.theOwnedRowsLeadingSwipeOffersEditThenSellThenCopy`
    (the three leading buttons by position — Edit nearest the edge, so the
    full swipe keeps editing — the middle one reading `SaleCopy.swipeSell`,
    staging `itemBeingSold` and carrying `SaleCopy.markAsSold` as its
    accessibility label, G19/G23), `theSaleSheetIsHostedOnceOverTheStagedRow`
    (exactly one `.sheet(item: $itemBeingSold)` over
    `makeSaleFormViewModel(for:)`, confirming through `markSold` and clearing
    the staged row) and `theSoldRowsCarryOnlyTheTrailingDelete` (no leading
    swipe on the Sold side; the trailing swipe delete-only on both).
    Mutations: Sell and Copy swapped → red; the middle button staging
    `itemBeingEdited` → red; confirm calling `load()` instead of the writer →
    red. The sale itself by
    `ItemListViewModelSwipeSaleTests.aSaleFromTheSwipeRecordsTheFourFieldsAndMovesTheRow`
    (G18, refetched on a second `ModelContext`) and the seed by
    `ItemDetailViewModelTests.everyHostSeedsTheMarkSheetIdentically` (G17 —
    the list, the detail and the plan seed one sheet one way). On screen:
    `testTheLeadingSwipeOffersMarkAsSoldBetweenEditAndCopyAndOpensTheSheet`.
    On the device (T010): a probe inside the sale writer counted seed 2,
    Cancel 0, swipe-down 0, background/foreground 0, appearance change 0 and
    confirm 1 — the `.sheet(item:)` lesson instrumented rather than
    eyeballed — and the file was byte-identical to HEAD once the probe came
    out.
2. [x] The item page's "…" menu is unchanged in both states, and no new
   button appears on the page.
    *Verified by*: the **existing** `SoldStateWiringTests` staying green with
    no edit — `bothMenuRowsAndTheSoldEditLabelReadSaleCopy`,
    `theMenuIsComposedOnceWithItsRowsSwappedByTheSoldFlag` (one `Menu`, its
    rows chosen by `isSold`) and `theOverflowMenuHostsExactlyOneSystemMenu` —
    together with `MenuPolicyTests`, likewise unedited except for T009h's
    broadening (it now names `.confirmationDialog(` beside `Menu`, closing
    the half of `013` Decision 17 the scan had left unguarded; mutation: a
    `.confirmationDialog` on `AddButton` → red naming the file). Those suites
    pin the menu's composition positively, so the evidence is that they held
    while the page around them changed — not that the diff happens to be
    silent on the file. That no button was added is evidenced by the **diff**,
    not by a test: `ItemDetailView`'s only change in this spec is the reorder
    Decision 6 asked for — `photoHero` and `titleBlock(for: item)` moved above
    the mark's `if` block, four insertions and two deletions, no new element.
    The tests around it pin less than that:
    `SoldStateWiringTests.theSoldBranchStampsTheMark` pins the *order* of the
    four elements it names (hero < title < `SoldMark(` < stats, G21) and
    `theSoldBranchOmitsTheMarketSectionAndFindAPhoto` pins two named
    *exclusions*. **Neither enumerates the branch**, so a seventh element
    added to it — including the very button Decision 1 withdrew — would pass
    every suite today. Recorded here rather than claimed away; an
    enumerating scan is the guard if that ever needs to be more than a
    reading of the diff.
3. [x] Once anything has been sold, the Sold side shows the search field, the
   category chips and Sort By in the Owned side's positions; the switch's
   top edge is at the same point on both sides (measured, as `006`
   criterion 7a was).
    *Verified by*: **T010's re-take after T010a** — the switch's top edge
    **154.333 pt on both sides** in all three states: zero sales, `-seedSold`,
    and the person's own 13-row collection, which is the state that read
    168.00 pt before the fix. The Sold summary is one band running to x=764
    where it used to break at x=584 and spill a second line; title/badge row,
    meta, switch, search field and chip row land on identical rows on both
    sides, and the Owned side under its widest label (`Market ↓`) is
    unchanged. **And two standing guards**, because a number measured once is
    not a rule: `ItemListHeaderLayoutTests.theHeaderIsOneMetaLineTallForEverySummaryAndEverySortLabel`
    (G38 — the header's rendered height at the device content width is the
    one-line baseline for every Owned and every Sold summary, each also at
    six-figure scale, under each side's widest sort label, the widest
    measured by rendering every label rather than counted; plus an
    empty-trailing case that reddens **alone** if the badge row ever outgrows
    the title's line box, verified by raising `OverflowBadge`'s padding to
    30) with `theScreensHeaderPutsTheMetaLineUnderTheBadgesRatherThanBesideThem`,
    and on screen `items.sideSwitch`'s `frame.minY` read on both sides with
    `-seedSold` (G39 — the 13.667 pt the device pass measured). The first
    device pass **found this criterion failing** (Sold 168.00 vs Owned 154.33,
    the sold summary wrapping because the new sort badge narrowed its slot);
    the cause and the fix are plan Q18 — the meta line takes the header's
    full width with the badges on the title's row — and the pre-fix red was
    captured first and reproduced the device measurement exactly.
4. [x] Searching on the Sold side narrows the rows by name or serial; the
   summary line follows the rows on screen and never disappears.
    *Verified by*: `ItemListViewModelSoldSideTests.theSoldSummaryFollowsTheSoldSidesNarrowing`
    (G10 — a query narrows `soldItems`, the totals follow it, and a query
    matching nothing reads exactly "0 sold · $0"),
    `theSummaryLineIsTheSharedCopyOverTheSharedTotals` and
    `theSoldTotalsComeFromSaleOutcomeAndNotFromArithmeticHere`; the name-or-serial
    rule itself is `SearchMatchingTests`', reached by both halves through the
    one `narrowed(_:by:)`. Never disappearing:
    `ItemListSidesWiringTests.neitherSidesMetaLineIsConditional` and
    `theSoldSideReadsTheViewModelsSummaryLine`. Mutation: totals summed over
    the unnarrowed `sold` → red. On screen:
    `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch` types into the
    Sold field and reads the rows back.
5. [x] The Sold side's chips are the categories of sold items only; tapping
   one narrows the rows, and there is no Un-valued chip.
    *Verified by*: `ItemListViewModelSoldSideTests.theSoldSidesChipsAreTheSoldCategoriesOnly`
    (G7 — the Sold pair built from the sold half, the Owned pair unchanged,
    `categoryOptions` following the side on screen; mutation: build either
    from `all` → red) and `ItemListViewModelShowSideTests.theUnvaluedFilterIsRefusedWhileTheSoldSideIsOnScreen`
    (G6, plan Q2 — the setter refuses the write on Sold and leaves Owned's
    copy standing, so `soldNarrowing.showsOnlyUnvalued` can never be true and
    the shared chip row cannot render the chip there; mutation: drop the
    guard → red). On screen: the Sold-card UI test's chip assertions in
    `testTheSoldCardLandsOnTheSoldSideWhichListsSalesMostRecentFirst`.
6. [x] Sort By on the Sold side offers exactly Date sold, Price ↓, Price ↑,
   Paid ↓, Paid ↑, Gain ↓, Gain ↑ and Name, defaults to Date sold, and each
   order is correct on a fixture with a gain, a loss and an at-cost sale;
   ties resolve by the side's standing order.
    *Verified by*: `SoldSortOrderTests.theMenuIsTheSpecsEightOptionsInOrder`
    and `theSoldSideDefaultsToDateSold` (G1 — the labels, the case order and
    the default by literal), `eachOrderSortsTheFixtureItsOwnWay` (G2 — all
    eight orders over a four-row fixture carrying a gain, a loss and an
    at-cost sale; mutations: any comparator deleted → its cases red, reversed
    → red, the gain comparator reading paid → the Gain cases red) and
    `aSalePriceTieFallsToTheStandingOrderNotToName` (G3 — asked of the
    **static** comparator in both argument orders, since a tie-break cannot
    be guarded through a fetch, whose order is indeterminate; mutations:
    `?? false` in place of the standing order → red, the tie falling to name
    → red both ways).
7. [x] Each side keeps its own search, chip and sort while the other side is
   visited, in both directions, and neither side's state changes the
   other's; at launch both sides are clean. The Owned side's Sort By is
   unchanged and reads "Date".
    *Verified by*: `ItemListViewModelShowSideTests.theOwnedSideKeepsItsNarrowingWhileTheSoldSideIsVisited`
    and `theSoldSideKeepsItsNarrowingWhileTheOwnedSideIsVisited` (G4 — chip,
    query, un-valued and sort across a switch in both directions, with the
    rows narrowed by them on return; mutations: `006`'s clears back in
    `show`, or one shared `Narrowing` → red), `aFreshViewModelOpensOnOwned`
    (G5 — both sides clean, Owned on screen, "Date" and "Date sold"),
    `askingForTheSideAlreadyOnScreenLeavesTheFilterAlone`, and the badge leg
    of `ItemListSidesWiringTests.oneNarrowingGateCoversBothSidesAndEachSideBringsItsOwnSort`
    (G20 — `sortControl` reads `visibleSortLabel`, not `sortOrder.label`;
    mutation: back to `sortOrder.label` → red). `apply`'s clear moved below
    `show(.owned)` so an Owned request cannot wipe the Sold side's query on
    its way through (plan Q3), pinned by the same suite's ordering assertion.
    On screen: `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch` types
    into the field, switches, comes back and reads it — the round trip driven
    through the UI, not through state.
8. [x] The Dashboard's Sold card lands on the Sold side as it stands; the
   Dashboard's category routes still land on Owned with that chip set.
    *Verified by*: `ItemListSidesWiringTests.theSoldRequestIsExactlyOneShowCall`
    (the `.sold` route is one `show(.sold)` and writes nothing — P9) with the
    same suite's assertion that every Owned case calls `show(.owned)` before
    any write (G20, plan Q3). On screen:
    `testTheSoldCardLandsOnTheSoldSideWhichListsSalesMostRecentFirst`. On the
    device (T010): the Sold card landing on a Sold side that still carried
    its own chip, and a category route landing on Owned with that chip set.
9. [x] A Sold side narrowed to nothing shows the no-matches state with its
   filter copy, not "Nothing sold yet"; with nothing sold at all it still
   shows "Nothing sold yet" and no controls.
    *Verified by*: `ItemListViewModelSoldSideTests.theSoldSidesEmptyStateIsNothingSoldOrStillSyncing`
    (G9 — five cases through the shared `ListEmptyReason.reason`, with
    `.nothingAdded` mapped to `.nothingSold` afterwards and `stillSyncing`'s
    precedence intact; mutation: pick the case directly again, `006`'s shape
    → the query and chip cases read `.nothingSold` → red) and
    `theEmptiedOwnedSideStillSaysEverythingSoldWithANoMatchQueryLeftOnSold`
    (G25 — the hidden side's query cannot turn an emptied Owned side back
    into a first launch; mutation: the guard reading `soldItems.isEmpty`
    instead of `soldTotalCount > 0` → red), with
    `ItemListSidesWiringTests.theNothingSoldStateReadsTheSoldCopyAndOffersNoAction`
    and `ItemListViewModelSoldSideTests.theNarrowingControlsGateFollowsTheSideOnScreen`
    (G8 — the gate reads the side on screen's own count, so nothing sold
    means no controls). On the device (T010): a Sold side with nothing sold
    at all showing "Nothing sold yet" and no controls.
10. [x] An Owned-and-sold CSV exported from a narrowed Sold side holds the
    owned and sold rows that pass that narrowing, with a true coverage label,
    and the hidden side's own narrowing has no effect on it; exported with no
    narrowing on the side on screen it is byte-identical to Settings'
    export-everything CSV whatever sort the Sold side is showing, and from
    the Owned side under the Custom sort as `013` established (corrected
    2026-09-18 at the person's reading: from Owned the file is the rows in
    visible order, so the identity holds under Custom, plan R1).
    *Verified by*: `ItemListViewModelSoldExportTests.aCSVFromTheSoldSideFollowsTheSoldChipAndNotTheOwnedOne`
    (G11), `aCSVFromTheOwnedSideIgnoresTheSoldSidesKeptQuery` (G12),
    `theCSVsSoldHalfIsDateSoldOrderWhateverTheSideIsShowing` (G13, P10) and
    `SettingsViewModelTests.theListsCSVMatchesSettingsFromEitherSideWhateverSortsShow`
    (G14) beside `theListsUnfilteredCSVStillMatchesSettingsByteForByteWithASalePresent`;
    mutations: the export reading `ownedNarrowing` or `items` from the Sold
    side → red; reading `soldNarrowing` from Owned → red; writing `soldItems`
    (the view's order) → red. The coverage label follows the side on screen
    through `exportCoverageLabel` (mutation: build it from `ownedNarrowing` →
    red). On the device (T010): an unnarrowed Owned-and-sold CSV taken from
    the Items list and Settings' export-everything CSV compared with `cmp` —
    no difference, 501 bytes, same md5. **Read from the Sold side this is the
    whole criterion**; from the **Owned** side the identity holds under
    Custom, which is what the criterion's own corrected wording says (plan
    R1, the correction the person made on 2026-09-18 at their reading). The
    Owned side's own export is `011`'s, unchanged.
11. [x] On a sold item's page the Sold mark sits directly under the item's
    name, below the photo and above the stats, with its words and colours
    unchanged.
    *Verified by*: `SoldStateWiringTests.theSoldBranchStampsTheMark`
    (G21 — in the sold branch the offsets satisfy `photoHero` <
    `titleBlock(for: item)` < `SoldMark(` < `statPair(for: item)`; mutation:
    the mark back above the hero → red on `title < mark`), with the mark's
    own words, colours and combined accessibility element untouched
    (`theMarkReadsSaleCopyAndAnnouncesItselfAsOneElement`,
    `everySoldSurfaceMapsIsLossToTheRustAndMossTokens`). On the device
    (T010): the mark measured 29.33 pt under the title with the section gap
    matching an owned page's by comparison.
12. [ ] Every new control is reachable by VoiceOver with a label and, for the
    swipe action, a name — the person's step with Accessibility Inspector.
    **An honest partial — this one is not done.** *What is known*: the swipe
    action's spoken name is **"Mark as sold…"**, read out of the live
    accessibility tree by XCUITest at T009, which is what settles the one
    platform claim the suites could not check (that `.accessibilityLabel` on
    a swipe-action `Button` overrides its `Label`'s text — plan Q9; "Sell" is
    the visible word, `SaleCopy.swipeSell`). The labels themselves are pinned
    off-device: `SaleCopyTests.theActionLabels`,
    `ItemListSidesWiringTests.theSwitchIsLabelledAndMarksItsActiveHalfSelected`,
    the swipe button's label leg of `theOwnedRowsLeadingSwipeOffersEditThenSellThenCopy`
    (G23), the chooser's dismiss catcher "Dismiss export options" and the
    sort badge's "Opens sort options" with `visibleSortLabel` as its value.
    *What is owed*: the person's own pass with Accessibility Inspector over
    the Sold side's search field, its category chips and its sort badge, and
    over the export scope chooser — first-row focus on opening and the
    dismiss catcher — plus a confirmation that the header's VoiceOver order
    (now **title, badges, meta**, a disclosed consequence of plan Q18) reads
    acceptably; `.accessibilitySortPriority` on the meta line is the one-line
    answer if it does not. Nobody has run Accessibility Inspector over these
    surfaces; the tool is not available to an agent here.
13. [x] The existing UI suite still starts from the state each test was
    written against; the suite passes twice back to back.
    *Verified by*: `scripts/verify.sh all` run twice, consecutively, at
    `a1f5acf` (23 tests, 0 failures each) and again after the header fix at
    `d5be739` (23 tests, 0 failures each) — the second pair the one that
    counts, since T010a changed the header every UI test renders. No seed
    changed in this spec (plan Q13): `-seedSold` is `006`'s, still gated on
    the store the app actually built being in-memory, so every existing test
    keeps the starting state it was written against
    (`UITestSeedTests`).
14. [x] From the Items list, Export as CSV… and Export as PDF… each offer
    Owned items, Sold items and Owned and sold, each enabled only when it has
    rows under the on-screen narrowing; the sold CSV holds exactly the sold
    rows that pass, in Date-sold order; the sold PDF's cover reads "Sold
    Items" with the count, total sold for, total paid and the realised gain
    or loss over exactly its entries, each entry carrying the sale under the
    name; Owned and sold gives criterion 10's CSV and, as a PDF, the two
    documents in one share sheet; the "…" menu's rows, the Wishlist's
    exports and Settings' exports are unchanged.
    *Verified by*: `ItemListViewModelSoldExportTests.theExportScopesReadOwnedSoldBothInMenuOrder`
    (G26), `theThreeScopesPartitionTheRecordFromANarrowedSoldSide` (G27 —
    owned in Custom order, sold date-desc whatever `soldSortOrder` shows,
    both = owned then sold), `eachScopeIsGatedOnTheRowsItWouldCarry` with
    `anAllSoldCollectionOffersBothFormatsWithTheOwnedScopeDisabled` (G28/G36)
    and `aSoldChipNoOwnedRowIsInDisablesTheOwnedScopeAlone`;
    `ExportTempFileTests.filenamesCarryTheLocalDay` and the same sold-export
    suite's `onlyTheSoldOnlyCSVTakesTheSoldFilename` (G29/G32 —
    `Trove-Sold-Items-<day>` for sold-only, `Trove-Items-<day>` for owned and
    for both); `PDFComposerTests.soldCoverCarriesTheSaleTotalsAndNoFloorNote`
    and `soldCoverCountLineIsSingularForOneSale` (G30 — "Sold Items",
    "N sold", TOTAL SOLD FOR / TOTAL PAID / REALISED, no floor note);
    `ExportSchemaTests.soldEntryLeadsWithTheSaleThenTheOwnedGrid` and
    `ownedEntryCarriesNoSaleFields` (G31 — the five sale fields **prepended**
    under the name, optionals skipped when empty, an owned record carrying
    none; a half-record fixture with a sold date and no price added at T010b
    pins the pair-unwrap, and makes the `?? 0` rewrite red);
    `theSoldPDFCoversTheSoldRowsThatPassTheChipInDateSoldOrder` (G33, with
    T010b's `realised == proceeds − paid` expectation beside the concrete
    triple), `theSoldCoverIsTheSoldSidesOwnTotals` (G34) and
    `theBothPDFStagesOwnedThenSoldInOneFileSet` (G35 — one `exportFiles`
    call, owned then sold, an empty half left out); the wiring by
    `ExportWiringTests.theItemsListComposesTheScopeChooserOverEveryScope`,
    `theScopeChooserHeadersReadAsTheSpecWritesThem` (G37) and its per-screen
    `csvAction`/`pdfAction` literals — the Wishlist's rows still export
    directly, and Settings' exports are untouched at the source: `Trove/ViewModels/SettingsViewModel.swift`
    is **absent from this spec's diff entirely**, which is the claim that
    matters — `SettingsViewModelTests` itself did change (its call sites took
    the scoped `exportCSV(scope:)` / `exportPDF(scope:)` signatures, an
    exhaustive `switch cover.totals` gained a `.sold` arm, and G14's
    byte-identity cases grew), so citing that suite as unedited would have
    been false. The anchor mechanism itself has its own guard after T009f
    found it broken: `DropdownAnchorTests` (three stacked tags reach a reader
    as three keys; the helper reverted from `transformAnchorPreference` to
    `anchorPreference` leaves one). On screen:
    `testTheExportRowsOpenAScopeChooserGatedByWhatIsOnScreen`. On the device
    (T010): all six files read back out of the container, the sold PDF's
    cover figures checked against the Sold side's own summary, the eleven-
    and thirteen-field sold entry pages drawing correctly with a long note
    wrapping, the two-document share sheet, and the menu-to-chooser swap
    re-sizing in place (plate top fixed at 115.33 pt across every frame).

## Decisions record

Made by the person, 2026-09-16, at their reading of the first Draft:

1. **No visible Mark as sold button on the item page.** The first Draft
   proposed one under the desire card, mirrored by a Return to collection…
   button on a sold page. Withdrawn: the person does not want the page's
   bottom to become a place where more and more things get added. The "…"
   menu row stays the page's way in; the swipe is the low-friction one. The
   button is recorded on the roadmap as a consideration, not a plan.
2. **Edit stays nearest the edge on the leading swipe**, so a full swipe
   still edits; Mark as sold… sits between Edit and Copy.
3. **The Sold side's sort offers Date sold, Price, Paid, Gain and Name** —
   "Paid" and "Name" added to the Draft's list at the person's answer.
4. **Each side keeps its own search, chip and sort across a switch.**
   Searching or filtering on one side, visiting the other and coming back
   finds the narrowing as it was. The person's call over the Draft's
   "switching clears", which `006` Q15 had settled.
5. **No design pass.** Placement, tint and labels are settled at planning
   from the existing tokens.
6. **The sold page's Sold mark moves from above the photo to directly under
   the item's name.**

Made by the person, 2026-09-18, at the Phase 2 pause:

7. **Exports from the Items list choose their scope — owned, sold, or both
   — for the CSV and the PDF; Settings' export-everything is unchanged.**
   Answering plan R2's question; the person chose both formats over the
   orchestrator's CSV-only recommendation, and the Items list over Settings
   as the only place the choice lives. Reverses `006` Decision 7, P17 and
   its non-goal "a sold-items PDF". The how was settled by a decision review
   at the top tier (plan §4a, Q14–Q17) and approved by the person the same
   day.

Proposed at drafting, 2026-09-16, by Claude Code (these become decisions on
plan approval):

- **P3. The leading swipe's Mark as sold… opens the sheet directly**, with
  no intermediate confirmation; the sheet is the confirmation.
- **P4. The Sold summary line follows the narrowing**, as the Owned side's
  line does, and is never hidden (`006` Decision 13).
- **P5. The no-matches state is shared** between sides; "Nothing sold yet"
  is only for a Sold side with nothing sold at all.
- **P6. Sold-side sort options are Date sold, Price ↓, Price ↑, Paid ↓,
  Paid ↑, Gain ↓, Gain ↑, Name**; no Custom, Market or Desire.
- **P7. Ties fall back to the standing Sold order** (date, name, id).
- **P8. Both sides start clean at every launch** — Owned on "Date" with no
  narrowing, Sold on "Date sold" with none — and nothing about either side
  is remembered across launches, as nothing is today.
- **P9. The Dashboard's Sold card goes to the Sold side as it stands.** It
  means "show me the Sold side", and the side's own chip or query is
  visible when it arrives; the Dashboard's category routes keep setting the
  Owned side's chip.
- **P10. The CSV's sold rows are always in Date-sold order**, whatever the
  side is showing; the view's sort is a reading aid, the file's order is
  the record's.
- **P11. The CSV is narrowed by the on-screen side's narrowing only**, over
  both halves; the hidden side's state never touches the file.

Proposed at the Phase 2 pause, 2026-09-18, by the decision review (approved
by the person the same day):

- **P12. The scope is chosen on a second dropdown surface** that the existing
  "Export as CSV…" / "Export as PDF…" rows open, headed EXPORT AS CSV / EXPORT
  AS PDF, with Owned items · Sold items · Owned and sold — never six menu rows,
  never "this side".
- **P13. "Owned and sold" as a PDF is two documents in one share sheet**,
  owned then sold; a half with no rows is left out, so with nothing sold it
  is today's single owned document.
- **P14. The sold document**: title "Sold Items"; cover with the count, TOTAL
  SOLD FOR, TOTAL PAID and REALISED (the Dashboard card's words for a sum);
  each entry the owned layout with Sold, Sold for, Sold at, Outcome and Sale
  note directly under the name.
- **P15. Filenames**: sold-only files are `Trove-Sold-Items-<date>`; owned
  and owned-and-sold keep `Trove-Items-<date>`.

## Non-goals (explicit)

- **A visible Mark as sold button on the item page** (Decision 1) — a
  roadmap consideration.
- **Editing or copying a sold item from its row** — the Sold side's rows
  gain no leading swipe.
- **Grouping or a year filter on the Sold side**, sales over time, charts —
  still a follow-up once there is history to show (`006` Non-goals).
- **Remembering the side, a sort or a narrowing across launches** — per
  side within a launch only (Decision 4).
- **A manual order for sold items.**
- **A one-tap sale** — every path opens the sale sheet.
- **Mark as sold on the Wishlist or Dashboard**, or a sell-plan picker from
  an owned item's page (`010`'s unbuilt row stays unbuilt).
- **Any change to the sale sheet** or to the sold page beyond the mark's
  place.
- **Any change to the sale's fields, the CSV columns, import, or sync.**
- **Remembering the last export scope** (P8's rule — nothing is remembered
  across launches).
- **A sold document from Settings** — Settings' Export All stays owned +
  wishlist as a PDF pair and the complete record as a CSV pair (Decision 7).

## Inherited caveats

- `006` Decision 4, criterion 1, P16, Q15/G33 and its Non-goals are
  superseded here; `006`'s `spec.md` and `plan.md` get a one-line pointer
  at each on this spec's plan approval.
- `001`'s fixed type sizes and USD-only rule apply.
- `006` Decision 7, P17 and its non-goal "A sold-items PDF" are superseded
  by Decision 7 here; `006`'s `spec.md` and `plan.md` get a pointer at each.
  `011`'s filename rule gains a second items name (`Trove-Sold-Items-<date>`)
  and its "The PDF" section a pointer.
- `013`'s rule stands: the "…" menu stays the one system `Menu`; the sort
  dropdown and the swipe are Trove's own.

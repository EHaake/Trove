# 020 — Purchase Provenance

**Status**: **Complete** (2026-10-06, the close-out) — criteria 1–26 and 28
are verified, each with its record under **Acceptance criteria**; criterion
27 (sync to a second device) is unticked, an honest partial, until the
two-device pass in `specs/SYNC-CHECKS.md`. **Approved** (2026-09-29) — written with the person in this
spec session; widened the same day, at their reading of the first Draft,
to a new/used preference on wishlist entries (Decision 8), and approved at
their reading of the second, which confirmed that leaving the preference
blank is the "no preference" choice (no separate "either" value). **Amended
2026-10-01** at the Phase 1 pause (Decision 11): the condition chips sit on one
row that scrolls sideways and never wrap. **Amended 2026-10-03** at the Phase 3
pause (Decision 12). The Decisions record below holds every product decision made in
the conversation; the **P-items** are Claude Code's proposals and become
decisions on plan approval, as in earlier specs.

Authored in a Claude Code spec session of its own, per `CLAUDE.md`'s model
policy (Opus profile, the session raised to high effort for the spec
conversation).

**Depends on**: `001-core-inventory` (`Item`, its form and page, the
condition scale), `002-live-market-value` (the condition-to-Reverb mapping
the market figure filters by, and the wanted item's "used listings"
figure), `010-item-management-enhancements` (Copy,
which duplicates an item), `011-data-export` (the items CSV and the PDF),
`012-data-import` (the items template and its header gate),
`015-mark-as-bought` (the purchase sheet). It adds no outside service.

## Summary

Trove records what you paid, when and where — but never **whether you
bought the thing new or used**. For hobby gear that is most of the story of
a purchase: the same lens bought new from a dealer and used off eBay are
different buys, and a collector who trades within the hobby knows which
one they made. The only trace the app has today is the **New** condition,
which says what state an item is in, not how it arrived.

This spec adds one optional fact to every owned item — **bought new** or
**bought used** — its twin on every wishlist entry — **looking for new**
or **looking for used** — and one grade to the condition scale, **Very
Good**, between Excellent and Good. The wishlist half does real work:
a wanted item's market figure has always read used listings only, and
for something you mean to buy new that is the wrong price.

## What and why

The occasion is the person's own collection: ninety items compiled in a
spreadsheet ahead of importing them (`specs/ROADMAP.md`, "A collection at
real scale"). Compiling it surfaced two gaps. The sheet had nowhere to say
new or used, and ten of its items are graded **Very Good**, a grade the
app's scale does not have. Reverb's own scale has it, and so does most
secondhand selling.

This spec goes first of the five that conversation produced because it is
the smallest and because it should land **before** the import: ninety rows
that carry new/used in one pass beat ninety hand edits afterwards.

What it deliberately leaves to later specs: **reading** the new fact
anywhere beyond the item itself. Filtering or grouping the list by new or
used is `022-grouped-browsing`'s; charting it is `023-dashboard-charts`'s;
making the importer lenient about how a spreadsheet writes it is
`021-import-expansion`'s. This spec records the fact and shows it on the
item. The one thing that reads it is the wishlist half: a wanted item's
preference chooses which Reverb listings its market figure is drawn
from, and prefills the purchase sheet when it is bought.

## Core behavior

### Bought new or used

- Every owned item gains an optional **Bought** fact with two values,
  **New** and **Used**. It may also be **not recorded**, which is what
  every existing item is after updating, and what any item is until the
  person picks (Decision 3).
- **It is never inferred.** An item whose condition is New is not assumed
  to have been bought new: a used item can be in new condition, and a
  gift or a long-stored purchase breaks the link the other way (Decision
  4).
- **A gift is not a third value.** A gift can be new or used, so it isn't
  an alternative to either (Decision 2). A gift stays what it is today: an
  item with a purchase price of zero.
- It belongs to the item and survives everything the item survives:
  editing, selling, returning to the collection, syncing.

### Where it is set

- **The add/edit item form** gains a **Bought** field: two chips, **New**
  and **Used**, the same shape as the condition chips beside it. Neither is
  selected by default. **Tapping the selected chip again clears it**, back
  to not recorded — an optional field needs a way back to empty, which the
  always-set condition chips never did (P1).
- **The Mark as bought sheet** (`015`) gains the same field, also
  unselected by default. Whatever is picked there lands on the new item.
- **Copy** carries the fact across with the rest of the item, as it
  carries the condition (P2).
- **It is never required.** Saving an item or completing a purchase with
  it unset is allowed and silent (Decision 3).

### Where it is shown

- **The item's page** says **Bought new** or **Bought used** alongside the
  purchase details it already shows — as the label of the row that already
  reads **Bought** beside the purchase date (Decision 10). When not recorded, the page says
  nothing about it — no dash, no "not recorded" line (P3).
- **The list rows do not show it.** The rows are already dense, and a
  marker on every row belongs to the list redesign if it belongs anywhere
  (Decision 5).
- **The Dashboard does not use it.** No figure, card or breakdown changes.

### Looking for new or used (the wishlist)

- Every wishlist entry gains an optional **Looking for** preference with
  the same two values, **New** and **Used**, and the same not-recorded
  state, which is what every existing entry is after updating
  (Decision 8).
- **Set on the wishlist add/edit form** with the same two chips, neither
  selected by default, the selected one clearable by tapping it again.
  Never required.
- **Shown on the wanted item's page** as a **Looking for — New / Used** row
  in its details, like the page's other facts; nothing when not recorded
  (Decision 10).
- **Copy** on a wishlist entry carries it across.
- **It shapes the market figure** — see "The market figure" below.
- **Marking the entry bought prefills the purchase sheet's Bought field**
  from it: looking for used → Used selected, looking for new → New
  selected, not recorded → nothing selected. The person can change or
  clear it before saving; a preference is not a record of what happened
  (P6).
- Not shown on wishlist rows, and nothing filters or sorts by it, for the
  same reasons as Decision 5.

### Very Good

- The condition scale becomes **New, Excellent, Very Good, Good, Fair,
  Broken**, in that order everywhere the scale is listed. Every place a
  condition can be chosen offers it: the item form and the Mark as bought
  sheet.
- **It reads "Very Good"** wherever a condition is shown — the item's
  page, the chips, the PDF — with a space and both words capitalised.
- **No existing item changes grade.** An item graded Good stays Good.

### The market figure

- **Very Good compares against Reverb's "very good" listings.** **Good
  keeps comparing against Reverb's "very good" and "good" listings**, as it
  has since `002` (Decision 6). The two grades overlap on purpose: nothing
  already graded Good sees its figure move, which is worth more than the
  cleaner split.
- **Bought new or used does not affect an owned item's market figure.**
  The figure reads the item's condition, which is what a buyer prices;
  how the owner came by it is not.
- **A wanted item's figure follows its Looking for preference**
  (Decision 9):
  - **Used** — Reverb's used listings, which is everything that is not
    new stock. Exactly today's figure.
  - **New** — Reverb's new-stock listings only (brand new and B-stock).
  - **Not recorded** — used listings, as today, so **no existing wanted
    item's figure moves** until the person states a preference.
- The words follow the figure: wherever a wanted item's market line says
  "used listings" today, it says **"new listings"** when the preference
  is New.
- Changing the preference changes the figure the same way changing an
  owned item's condition does — no new fetch timing, no new trigger.

### Sync and privacy

- The new fact syncs with the item like any of its other fields. It is the
  person's own data; nothing about it leaves the device except through
  their own iCloud sync and their own exports.
- **An older copy of the app on another device** — before this update —
  keeps showing that device's view of the item without the new fact, and
  must not lose it for the updated device when it edits the item (P4).
  Very Good on such a device must not crash it or reset the grade.

### Exports and import

- **The items CSV gains one column at the end, "Bought"**, holding `new`,
  `used`, or nothing — appended after every existing column, as `006`'s
  sale columns were, so the template's existing order is untouched
  (Decision 7).
- **Import reads it back**, ignoring letter case. An empty cell imports as
  not recorded. An older file without the column still imports, every row
  not recorded.
- **Very Good round-trips.** The CSV writes it the way it writes the other
  grades (lower case, with its space: `very good`) and import reads it in
  any letter case (P5). Wider leniency — other spellings, other date and
  money formats — is `021`'s.
- **The downloadable template** gains the column too, so a file built from
  it today carries new/used from the start.
- **The PDF** says it the way the item's page does: the field that already
  holds the purchase date is labelled **Bought new** or **Bought used**,
  and plain **Bought** when not recorded — no second field labelled
  "Bought" (Decisions 7 and 10).
- **The wishlist CSV gains one column at the end, "Looking For"**,
  holding `new`, `used` or nothing, read back on import the same way,
  with older files importing as not recorded. The wishlist template gains
  it too.
- **The wishlist PDF** lists **Looking for: New** or **Used** where
  recorded, and omits it where not.

## Copy

| Where | Text |
|---|---|
| Form and purchase sheet field label | **BOUGHT** (the mono label style every field uses) |
| Chips | **New**, **Used** |
| Item page | **Bought new** / **Bought used** — the label of the existing purchase-date row |
| Condition chip and page | **Very Good** |
| CSV header | `Bought` |
| CSV values | `new`, `used`, empty; condition `very good` |
| PDF, items | the purchase-date field labelled **Bought new** / **Bought used** (plain **Bought** when not recorded) |
| Wishlist form field label | **LOOKING FOR** |
| Wanted item's page | a details row, **Looking for** — **New** / **Used** |
| Wanted market line, New preference | "new listings" wherever it says "used listings" today |
| Wishlist CSV header | `Looking For` |
| Wishlist PDF field | **Looking for** — **New** / **Used** |

## Design requirements

- The Bought chips **match the condition chips** exactly — size, stroke,
  selected tint — so the form reads as one system. Two chips need no
  wrapping.
- The six condition chips sit on **one row that scrolls sideways**, on
  every screen the row appears (the item form and the Mark as bought
  sheet). **The row never wraps onto a second line**, and no chip is
  squeezed narrower than its words need. Where the row runs past the
  screen, a chip cut off at the edge shows there is more to scroll to, and
  the row opens with the selected grade in view. Check it at the narrowest
  supported width. *(Amended 2026-10-01, Decision 11 — until then this
  read "wrapping onto a second row is fine".)*
- The Looking for chips on the wishlist form match the same chips.
- On the item's page the Bought line sits **with the purchase details**
  (price, date, place), not with the condition, because it describes the
  purchase, not the state.
- VoiceOver reads the chips' selected state, as the condition chips do,
  and a cleared Bought field reads as nothing selected.

## Acceptance criteria

1. [x] The add/edit item form shows a **Bought** field with **New** and
   **Used**, neither selected for a new item.
   *Verified by*
   `ItemFormViewModelTests.startsWithBoughtNotRecordedAndSavesWithoutIt`; the
   UI test `testBoughtIsSetClearedAndShownOnTheItemsPage`, which finds neither
   chip selected on a new form; and a source check that each form shows the
   Bought field once, under its label
   (`eachFormComposesTheBoughtFieldOnceWithItsLabelAndIdentifier`).
2. [x] Picking New or Used and saving stores it; reopening the item's form
   shows it selected.
   *Verified by* `ItemFormViewModelTests.savesBoughtAndReopensWithItSelected`,
   which reads the saved item back from the store through a second connection;
   the same UI test reopens the form and finds Used selected.
3. [x] Tapping the selected Bought chip clears it; saving then stores the
   item as not recorded.
   *Verified by* `NewOrUsedCopyTests.tappingTheSelectedChipClearsIt`,
   `ItemFormViewModelTests.clearingBoughtSavesNotRecorded`, and the same UI
   test's clear step. Shown able to fail: with the field made to keep whatever
   was tapped, it went red.
4. [x] An item saves with Bought unset, with no prompt, warning or
   validation message.
   *Verified by*
   `ItemFormViewModelTests.startsWithBoughtNotRecordedAndSavesWithoutIt` — the
   save succeeds and raises no validation message. Shown able to fail: a
   validation rule added for an unset Bought turned it red.
5. [x] Every item that existed before the update opens as not recorded,
   whatever its condition — including items graded New.
   *Verified on a device, by upgrading in place* (the device pass, 2026-10-06):
   `main`'s build with one item graded Good and one graded New, then this build
   installed over it on the same stored data — both pages read plain "Bought"
   and both forms opened with neither Bought chip selected, the item graded New
   included. A model-level test agrees
   (`ProvenanceFieldsTests.aRowWithOnlyOlderFieldsReadsNotRecordedAndItsOldGrade`)
   but is not the evidence: a row built in a test starts unset whatever the app
   does.
6. [x] The item's page labels its purchase-date row **Bought new** or
   **Bought used**, and plain **Bought** when not recorded.
   *Verified by* `NewOrUsedCopyTests`, which pins the three labels word for
   word; two UI tests — `testBoughtIsSetClearedAndShownOnTheItemsPage` reads
   "Bought used" and then plain "Bought" on the date row, and
   `testLookingForPrefillsThePurchaseSheet` reads "Bought new" with the date
   on the item it buys; and a source check that the page's date row takes its
   label from the item's Bought value
   (`theItemPagesDateRowIsLabelledFromTheItemsBoughtField`).
7. [x] The Mark as bought sheet shows the same Bought field, unselected
   unless the entry has a Looking for preference (criterion 23); the item
   it creates carries what was picked, or not recorded. *(Wording amended
   2026-10-03, Decision 12.)*
   *Verified by* `PurchaseFormViewModelTests.seedsBoughtFromThePreference` and
   `.recordsTheBoughtChosenWhenTheSheetIsConfirmed`;
   `WishlistPurchaseStoreTests.theBoughtItemCarriesThePurchasesBoughtValueNotTheEntrysPreference`;
   the UI test `testLookingForPrefillsThePurchaseSheet`.
8. [x] Copying an item carries its Bought value to the copy.
   *Verified by* `ItemDuplicationTests.theCopyCarriesBought`.
9. [x] Selling an item and returning it to the collection leaves its Bought
   value unchanged.
   *Verified by* `ItemSaleStoreTests.markThenReturnLeavesBoughtUnchanged`.
10. [x] The condition scale offers **New, Excellent, Very Good, Good, Fair,
    Broken** in that order on the item form and the purchase sheet; Very
    Good saves, reopens selected, and reads **Very Good** on the item's
    page.
    *Verified by*
    `ModelTests.theScaleReadsInOrderWithVeryGoodBetweenExcellentAndGood`;
    `ItemFormViewModelTests.veryGoodSavesAsGoodPlusARefinementAndReopensSelected`;
    a source check that both screens draw the one shared condition row over the
    whole scale; the UI tests, which find the six chips by name on the item
    form and on the purchase sheet and check that their left edges run left to
    right in the order New, Excellent, Very Good, Good, Fair, Broken; and the
    device pass, which saw the six chips in order on both forms. Very Good on
    an item's page was part of the person's Phase 1 walkthrough (2026-10-01:
    the sixth grade is there).
11. [x] No existing item's condition changes on update.
    *Verified on a device, by upgrading in place* (the device pass,
    2026-10-06): across the upgrade on stored data, Good stayed Good and New
    stayed New. The model-level test named under criterion 5 agrees on the
    grades.
12. [x] An item graded Very Good gets a market figure from Reverb's
    "very good" listings only; an item graded Good gets one from "very
    good" and "good", exactly as before this spec.
    *Verified by*
    `MarketFigureComputationTests.theConditionBucketsOverlapOnlyWhereVeryGoodMeetsGood`
    and `.aVeryGoodItemCountsOnlyVeryGoodListingsAndAGoodItemCountsBoth`, and
    `aGoodOwnedItemSpansVeryGoodAndGood`, which predates this spec and passes
    unedited.
13. [x] The items CSV export ends in a **Bought** column with `new`, `used`
    or empty, and writes Very Good as `very good`.
    *Verified by* `ExportSchemaTests.headerListsMatchThePinnedSchema`,
    `.theBoughtCellIsTheLastAndCarriesNewUsedOrNothing` and
    `.veryGoodIsWrittenAsVeryGood`.
14. [x] Importing that export restores every item's Bought value and every
    Very Good grade; `NEW`, `Used`, `Very Good` and `VERY GOOD` all import.
    *Verified by*
    `ItemListViewModelCommitTests.commitRestoresBoughtAndVeryGoodThroughTheCSV`
    (export, import, then read back from the store through a second
    connection); `ImportSchemaTests.newOrUsedReadsInAnyLetterCase` and
    `.veryGoodReadsInAnyCase`.
15. [x] An items CSV in the previous layout, without the Bought column,
    still imports, every row not recorded.
    *Verified by*
    `ImportSchemaTests.anEighteenColumnItemsFileImportsWithNothingRecorded`;
    the tests for the two older layouts (12 and 14 columns) pass unedited.
16. [x] The downloadable items template includes the Bought column.
    *Verified by* `ImportSchemaTests.theTemplatesEndInBoughtAndLookingFor`;
    `SettingsViewModelTests` pins that the template Settings hands out is built
    from that same list of columns.
17. [x] The PDF labels an item's purchase date **Bought new** or **Bought
    used** where recorded and plain **Bought** where not, with no second
    "Bought" field, and prints Very Good as **Very Good**.
    *Verified by*
    `ExportSchemaTests.itemEntryDateFieldIsLabelledBoughtNewOrUsed`, which
    compares an entry's whole list of labels word for word — so a second
    "Bought" would fail it — and prints Very Good.
18. [x] The six condition chips sit on a single row that scrolls
    sideways, on both the item form and the purchase sheet: the row never
    wraps, no chip is squeezed, every grade can be reached by scrolling at
    the narrowest supported width, and the row opens with the selected
    grade in view. *(Amended 2026-10-01, Decision 11.)*
    *Verified by*, as amended by Decision 11: the UI tests
    `testTheConditionRowIsOneScrollingRowAndOpensOnTheSelectedGrade` and
    `testThePurchaseSheetsConditionRowIsOneScrollingRow` (one row, wider than
    the screen, it scrolls, and it opens on the selected grade);
    `ConditionFieldLayoutTests` (no chip is squeezed); and the device pass on
    an iPhone SE — 375 pt wide, the narrowest iPhone this app supports — in
    light and dark: one line, it slides to Broken, and an item graded Broken
    reopens with Broken in view. **Not covered by any test**: how the cut-off
    chip at the edge looks. On the SE the chip cut by the edge is Fair, with
    about 85 % of it showing — a thin hint that the row scrolls, put to the
    person as an observation.
19. [x] The wishlist add/edit form shows a **Looking for** field with
    **New** and **Used**, neither selected for a new entry; it saves,
    reopens selected, clears by tapping the selected chip, and saves
    unset without a prompt.
    *Verified by* `WishlistFormViewModelTests`
    (`startsWithLookingForNotRecordedAndSavesWithoutIt`,
    `savesLookingForAndReopensWithItSelected`,
    `clearingLookingForSavesNotRecorded`); source checks for where the field
    sits; and the UI test `testLookingForPrefillsThePurchaseSheet`, which
    selects a value on the form and saves. Reopening, clearing and saving unset
    on the wishlist form itself are tested beneath the screen and were part of
    the person's Phase 3 walkthrough (2026-10-03: "Everything looks good"); no
    UI test repeats them.
20. [x] Every wishlist entry that existed before the update opens as not
    recorded.
    *Verified on a device, by upgrading in place* (the device pass,
    2026-10-06): the wishlist entry made before the update shows no Looking for
    row, and its form opens with neither chip selected. The model-level test is
    as under criterion 5 — it agrees, and is not the evidence.
21. [x] The wanted item's page shows a **Looking for** row reading **New** or
    **Used**, and no row when not recorded.
    *Verified by* a source check that the page's row reads the entry's
    preference (`theWantedPagesLookingForRowReadsTheItemsLookingForField`) and
    the UI test `testLookingForPrefillsThePurchaseSheet`, which reads
    "Looking for, Used" on the page once the preference is set — and, before
    setting it, opens the same entry's page, waits for its Added row, and
    finds no row beginning "Looking for" (that check was added after the
    pre-merge review). "No row when not recorded" was also seen on the device
    pass (after the upgrade and again after a relaunch) and in the person's
    Phase 3 walkthrough.
22. [x] A wanted item looking for new gets its market figure from Reverb's
    brand-new and B-stock listings only, and its market line says "new
    listings"; one looking for used, or not recorded, gets exactly the
    figure and wording it gets today.
    *Verified by* `MarketFigureComputationTests` (looking for new counts
    brand-new and B-stock listings only; used and not recorded give exactly the
    figure they gave before this spec, over the recorded Reverb responses);
    `MarketRefresherTests`, including the case of too few new listings
    (`aWantedItemLookingForNewWithTooFewNewListingsIsWithheldAndRecordedSo`:
    two new listings among five used give no figure, and the saved reading is
    still marked as read from new stock — added after the pre-merge review);
    `MarketCopyTests.aFigureReadFromNewStockSaysNewListings` and
    `.theTwoWantedStringsFromBefore020AreUnchanged`;
    `MarketIndexTests.theListingBasisIsReadOffTheFigure`; and one source check,
    `theSectionsListingWordsFollowTheFigureShown`, which is all that covers the
    wording on the screen itself. **Checked live against Reverb** on the device
    pass (2026-10-06), one product read both ways: looking for new, 58 listed,
    $439–$670; looking for used, 35 listed, $168–$440; the counts on screen
    matched. The sentence shown when there are too few new listings did not
    come up in the live check; it rests on the tests.
23. [x] Marking a wanted item bought preselects the purchase sheet's
    Bought chip from its preference (nothing when not recorded), and the
    person can change or clear it before saving.
    *Verified by* `PurchaseFormViewModelTests.seedsBoughtFromThePreference`;
    `WishlistDetailViewModelTests.everyHostSeedsThePurchaseSheetIdentically`
    (all four places the sheet opens from); and the UI test
    `testLookingForPrefillsThePurchaseSheet` — Used is preselected, the test
    changes it to New, and the new item reads "Bought new". Clearing it on the
    sheet is tested beneath the screen, not in a UI test.
24. [x] Copying a wishlist entry carries its preference.
    *Verified by* `WishlistDuplicationTests.theCopyCarriesLookingFor`.
25. [x] The wishlist CSV export ends in a **Looking For** column; importing
    it restores every preference; an older wishlist file without it still
    imports, every row not recorded; the wishlist template includes it.
    *Verified by*
    `ExportSchemaTests.theLookingForCellIsTheLastAndCarriesNewUsedOrNothing`;
    `WishlistViewModelCommitTests.commitRestoresLookingForThroughTheCSV`;
    `ImportSchemaTests.aNineColumnWishlistFileImportsWithNothingRecorded` and
    `.theTemplatesEndInBoughtAndLookingFor`.
26. [x] The wishlist PDF shows **Looking for** where recorded and omits it
    where not.
    *Verified by*
    `ExportSchemaTests.wishlistEntryCarriesLookingForOnlyWhenRecorded`, and the
    earlier four-field test, which passes unedited.
27. [ ] The Bought value, the Looking for preference and Very Good sync to a second signed-in device.
    *(A two-device check; gathered in `specs/SYNC-CHECKS.md` if it cannot
    be run at the close-out.)*
    **Unticked — sync untested, gathered in `specs/SYNC-CHECKS.md` (steps 3.11
    and 3.12) for one later pass.** No second signed-in device was available at
    the close-out, so none of the three has been seen to arrive on another
    device. *What has been checked*: the three new fields are accepted by
    CloudKit's own validator (criterion 28), and all three, once set, survive
    the app being closed and reopened on one device (the device pass,
    2026-10-06). **What has not been done**: the Bought value, the Looking for
    preference and Very Good set on one device and read on another (step
    3.12); and an older copy of the app on the second device editing those
    rows without wiping them (step 3.11 — see P4 below).
28. [x] The CloudKit schema test still validates with both new fields.
    *Verified by* `CloudKitSchemaTests.schemaMeetsCloudKitRequirements`, which
    now validates three new synced fields, not two — Bought, Looking for, and
    the one that marks a Good item as Very Good. Shown able to fail: a
    uniqueness rule put on the Bought field turned it red, along with
    `TwoStoreContainerTests`.

## Decisions record

1. **This spec first, before the import** (the person, 2026-09-29). Of the
   five specs from the collection-at-scale conversation, provenance is the
   smallest and the ninety-row import should carry it.
2. **No gift value** (the person, 2026-09-29). Offered as a third choice
   beside New and Used; declined because a gift can itself be new or used.
   A gift is an item with a zero purchase price, as today. Whether charts
   treat zero-price items specially is `023`'s question.
3. **Optional, no default** (the person, 2026-09-29). Not required on the
   form or the purchase sheet; not prefilled; existing items start not
   recorded. Chosen over "required for new items" and over "defaults to
   Used", which would save a wrong default silently.
4. **Never inferred from condition** (proposed in the conversation, not
   objected to). New condition is a state, not a history.
5. **Shown on forms, the item page, the CSV and the PDF — not on list
   rows** (the person, 2026-09-29).
6. **Very Good between Excellent and Good; Good's market comparison
   unchanged** (the person, 2026-09-29). Offered: split Good to Reverb's
   "good" only, for accuracy. Chosen: keep Good on "very good" + "good" so
   no existing figure moves, with Very Good on "very good" alone.
7. **One appended CSV column** and a PDF line — the PDF half refined by
   Decision 10 (follows from Decision 5 and
   `006`'s precedent for adding columns).

8. **A new/used preference on wishlist entries, in this spec** (the
   person, 2026-09-29, at their reading of the first Draft). Offered as
   the one natural widening of a narrow spec; accepted. Same two values,
   optional, no default, not inferred.
9. **Not recorded keeps today's used-listings figure** (proposed with
   Decision 8). Reading all listings when unstated would have been the
   more neutral default, but it would move every existing wanted item's
   figure on update — the same reasoning as Decision 6.

10. **How the words sit on the pages and the PDF** (the person, 2026-09-29,
    answering the plan's four readings before sign-off). The item page folds
    new/used into the existing purchase-date row's label ("Bought used ·
    Mar 3, 2024") rather than adding a row; the wanted page uses a details
    row ("Looking for · New") rather than a sentence; the PDF matches the
    item page rather than printing a second field labelled "Bought"; and a
    wanted item looking for new whose new listings are too few keeps the
    second sentence naming the lowest *used* asking price — it says "used"
    plainly and is a useful hint.

11. **Six grades on one scrolling row, never two rows** (the person,
    2026-10-01, at the Phase 1 pause, on seeing the six chips wrap on an
    iPhone 17 Pro: "the condition selections span 2 rows, which isn't
    good"). Offered: keep six grades on one row that scrolls sideways;
    drop Very Good and go back to five; or scroll now and revisit the
    number of grades in a later spec. Chosen: six grades, one scrolling
    row, "in all of the places it appears". Proposed with it and not
    objected to: a chip showing at the edge so the row reads as
    scrollable, and the row opening scrolled to the selected grade. This
    replaces the first Draft's "wrapping is fine". The Bought and Looking
    for rows have two chips and do not scroll.

12. **Two readings confirmed at the Phase 3 pause** (the person,
    2026-10-03: "Everything looks good and I like your suggestions").
    The match picker's candidate line ("Lowest used asking price …" /
    "No used listings") keeps saying "used" for a wanted item looking for
    New — a fact about Reverb's catalogue, the same reasoning as Decision
    10's kept sentence. And criterion 7 gains "unless the entry has a
    Looking for preference", so it agrees with criterion 23 and P6.

### The P-items, now decisions

Claude Code's proposals. Each became a decision when the plan was approved
(2026-09-30), and each is recorded here as it shipped.

- **P1 — decided: tapping the selected chip clears it.** The same rule
  serves Bought on the item form and the purchase sheet and Looking for on
  the wishlist form — one rule, written once (criteria 3, 19 and 23).
- **P2 — decided: Copy carries the value.** A copied item keeps its Bought
  value and a copied wishlist entry keeps its Looking for preference
  (criteria 8 and 24).
- **P3 — decided: the page is silent when not recorded.** The item's page
  reads plain "Bought" on its date row, exactly as before this spec, and
  the wanted item's page shows no Looking for row — never a dash (criteria
  6 and 21).
- **P4 — decided: an older copy of the app on another device must neither
  crash on nor erase the new data. Half of this is tested and half is not.**
  - **Very Good — tested.** It is stored so that an older copy of the app
    reads the item as **Good**, its nearest known grade, and saving there
    does not reset it: the item is still Very Good on an updated device. A
    test replays what the older app does on reading and on saving
    ("Very Good and an app older than 020"), and it fails if Very Good is
    stored the simple way. What that test is, exactly: a frozen copy of the
    older app's read and save, run in memory. It shows that the older app's
    own code never resets the grade to Excellent. Whether an older app's
    iCloud sync leaves the extra field that marks Very Good intact is the
    same unverified claim as for Bought and Looking for below, and it waits
    on step 3.11 with them. One edge is known and accepted: if the older
    device moves the item to another grade and back to Good, it reads Very
    Good again on an updated device.
  - **Bought and Looking for — untested until the two-device pass.** An
    older copy of the app does not know these two fields. Whether editing a
    row there leaves them alone depends on how iCloud sync treats fields an
    app has never heard of, and no test in this project can reach that.
    Nothing has been seen to go wrong, and nothing has been seen to go
    right: it waits on step 3.11 in `specs/SYNC-CHECKS.md`, with an older
    build on a second device.
- **P5 — decided: Very Good is written `very good` in the CSV**, with its
  space, and is read back in any letter case (criteria 13 and 14).
- **P6 — decided: marking a wanted item bought prefills the sheet's Bought
  chip from its preference**, and it can still be changed or cleared before
  saving (criteria 7 and 23; criterion 7's wording by Decision 12).

## Non-goals (explicit)

- **A gift field or value** (Decision 2).
- **Inferring Bought from condition, price, place or date** (Decision 4) —
  including any one-time guess for existing items.
- **Filtering, grouping, sorting or searching by Bought** — `022`.
- **Any Dashboard figure or chart using it** — `023`.
- **A Bought marker on list rows** (Decision 5).
- **Setting Bought on many items at once.** The way to do that for an
  existing collection is `021`'s round-trip import.
- **Import leniency beyond the new column and the new grade** — `$`
  prices, other date formats, missing columns, blank rows — `021`.
- **An "either" preference** that reads new and used listings together.
  Not recorded already means "no preference stated", and it keeps
  today's used figure (Decision 9).
- **Re-grading existing items** or changing what New, Excellent, Good,
  Fair or Broken mean.

## Inherited caveats

- Every font is fixed-size (`017-dynamic-type`); the new field inherits
  that.
- Two-device sync checks are gathered in `specs/SYNC-CHECKS.md`; nobody
  has run that pass yet. This spec adds steps 3.11 and 3.12 to it
  (criterion 27 and P4).

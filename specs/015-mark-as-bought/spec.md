# 015 — Mark as Bought

**Status**: **Approved** (2026-09-19) — written with the person in this spec
session and approved the same day at their reading of the Draft, which
answered its three open questions: **no undo** (Decision 5), the
over/under-estimate line **kept** (Decision 6), and the wishlist notes
**carried across** (Decision 7). The Decisions record below holds every
product decision; the **P-items** are Claude Code's proposals and become
decisions on plan approval, as `002`'s, `005`'s and `006`'s did.

Authored in a Claude Code spec session of its own, per `CLAUDE.md`'s model
policy as amended 2026-09-19 (Opus 5, the session raised to high effort for
the spec conversation).

**Depends on**: `001-core-inventory` (`Item`, `WishlistItem`, the wishlist
screen and its rows, the Sell Plan, the custom order), `006-mark-as-sold`
(the sale sheet this spec mirrors, and `itemsSoldToward`),
`010-item-management-enhancements` (the wishlist's leading and trailing
swipes),
`013-settings-menu` ("bespoke in the page, system in the bars", which places
the new action), `014-sold-side-parity` (the Sell-on-the-swipe pattern this
spec copies onto the Wishlist, and its withdrawn item-page button, whose
reasoning applies here too). It touches nothing in `002`'s or `005`'s
network code and adds no outside service.

## Summary

Trove has always been able to say what you own and what you want next, and
since `006` it can say what you sold. It has never been able to say that you
**bought** the thing you wanted. Today the only way to finish the loop is to
delete the wishlist entry and retype it as a new item — losing its photos,
its category, its Reverb match and its year, and quietly abandoning the sell
plan that was built around it.

This feature adds **Mark as bought…**: from the Wishlist's swipe, from the
wishlist item's menu, and from its Sell Plan screen, one sheet asks what you
paid, when, where and in what condition. The wishlist entry becomes an item
in your collection, carrying everything it already knew about itself, and
leaves the Wishlist. It is not deleted — it is marked bought, so its sell
plan survives as a **completed** one, which is the record that the plan was
carried out.

## What and why

The roadmap's `015-mark-as-bought` entry, added 2026-09-19, reads: "the other
half of the core loop, and the one piece of it the app has never had…
`006` and `014` built the selling half properly. Nothing records that the
purchase happened."

`CLAUDE.md` describes Trove as: track what you own, track what you want to
buy next, and use the gap between current value and original cost to plan
sales that fund future purchases. Four specs have now built the selling side
— `003` ranked the plan, `006` recorded the sale, `014` gave the Sold side
parity and put Sell on the swipe. The buying side has had nothing built for
it at all, and unlike almost everything else in this roadmap it was never a
deliberate `001` non-goal. It was simply never thought of, because before the
app existed there was no moment at which you would sit there having just
bought something.

The gap is felt at the best moment the app has: you saved for a thing, you
sold gear toward it, you bought it. The app's response is to make you do data
entry, and to silently lose the part of the record that was interesting.

Three things this spec deliberately preserves:

- **The Sell Plan stays guidance, not a ledger.** `006` held this line and so
  does this spec. Marking a wishlist item bought does not assert that any
  particular sale paid for it, and nothing in the app will claim it did
  (Decision 2). What already exists — `006`'s `itemsSoldToward` and the Sell
  Plan's Sold figure — is untouched and is not extended onto the new item.
- **One record per object.** A bought thing is an item. It appears in Items
  and nowhere else; the Wishlist grows no Bought side (Decision 1). Owned and
  Sold are two states of one row, which is why `014`'s parity argument does
  not transfer here.
- **Nothing is thrown away.** The wishlist entry is marked, not deleted
  (Decision 3), so the plan built around it survives.

## Core behavior

### Marking a wishlist item as bought

- Any wishlist item offers **Mark as bought…**, from three places
  (Decision 4):
  - the Wishlist row's **leading swipe**, beside the actions `010` put
    there — the same move `014` made with Sell on the Items list, and the
    reason the Wishlist's leading swipe already exists ("one pattern, both
    lists");
  - the **wishlist detail screen's menu**, beside Edit and Delete, as `006`
    placed **Mark as sold…** on the item page;
  - each **Sell Plan** screen, which is the screen the decision is actually
    made on and the one where a completed plan means something.
- It is **not** a visible button at the bottom of the wishlist detail page.
  `014` Decision 1 withdrew exactly that on the item page — the person does
  not want a page's bottom becoming a shelf that actions accumulate on — and
  the same reasoning applies (P1).
- Every path opens the same **purchase sheet**, seeded identically, and
  nothing is written until it is confirmed. There is no one-tap purchase:
  a swipe that acted immediately would be a mis-tap away from a false record,
  which is the same reasoning `014` applied to Sell.

### The purchase sheet

Asks for four things (P2), mirroring `006`'s sale sheet field for field:

- **Purchase price** — required; pre-filled with the wishlist item's
  estimated cost when it has one, and editable. Pre-filling mirrors `006`,
  which pre-fills the sale price with the item's current value.
- **Purchase date** — required, defaults to today.
- **Purchase location** — optional, free text ("Reverb, a shop, a friend"),
  as `006`'s sale location is.
- **Condition** — required, defaulting to the same value a new item defaults
  to. This is the one field with no wishlist counterpart: an `Item` has a
  condition and a `WishlistItem` has never had one, so it cannot be carried
  across and has to be asked for.

When the entered price differs from the estimated cost, the sheet says by how
much in one sentence — over or under what you had guessed (Decision 6). It
is a line of copy, not a figure the app stores or acts on. This is the kind of
observation the app exists to make, and it costs nothing: both numbers are
already on screen.

### What buying does

On confirming the sheet:

- A new **item** is created in the collection, carrying across everything the
  wishlist entry already knew (P3): its **name**, **category path**,
  **photos** with their credits intact (a `005` stock photo keeps its
  photographer, licence and link), its **Reverb product match**, its
  **year**, and its **currency**. Its **notes** carry across too — losing
  typed text is worse than carrying a sentence that is now slightly stale,
  and it is editable like any other field (the notes specifically confirmed
  as Decision 7).
- The item's **current value** starts at the purchase price (P4). For
  something bought today those are the same number, and starting it unvalued
  would put a brand-new purchase straight into the Dashboard's un-valued
  count, which is noise rather than a prompt.
- The item's **desire to keep** starts at the ordinary default. The
  wishlist's *desire to own* is a three-level scale about wanting and the
  item's is a five-level scale about keeping; they are different questions
  and mapping one onto the other would invent an answer (P5).
- The item is **appended to the end of the custom order**, as an imported
  item is.
- The **wishlist entry is marked bought** and leaves the Wishlist. It is not
  deleted (Decision 3). It appears nowhere in the app in this spec.
- Its **sell plan is retained and reads as completed**: the items sold toward
  it stay recorded, and the remaining *unsold* candidates are released from
  the plan, since nothing is earmarked toward a purchase that has happened
  (P6). This mirrors `006` P6, which empties the selection at the sale.
- Every Dashboard figure updates as it would for any item added by any other
  route. There is **no Bought card** and no new Dashboard surface
  (Decision 1).

### Correcting a mistake

**There is no undo** (Decision 5). This is a deliberate departure from
`006`, which ships Return to collection, and the asymmetry is the reason:
returning a sold item destroys nothing, because the sale was four fields on
a row that already existed, whereas returning a bought item would have to
delete a row the purchase brought into being — one that by then may carry
photos, a serial number or notes added since. An undo that destroys real
data is a worse hazard than the mistake it reverses.

The mistake is also much harder to make than the one `006` guards against.
Every path to a purchase opens a sheet that has to be filled in and
confirmed; there is no gesture that completes a purchase on its own.

A purchase marked in error is corrected by hand, with tools the app already
has: delete the item, and add the thing back to the wishlist. Two
consequences follow and are accepted rather than solved here — the
re-added entry is a new one, so the original marked-bought entry stays in
the store unreachable, and it will appear as a completed plan when `009`
ships. Both are recorded in the Non-goals.

### Sync and privacy

- The bought marker is the person's own data about their own purchase, so it
  **syncs**, like the sale fields `006` added. It follows the same CloudKit
  rules every field in this schema follows.
- **Nothing leaves the device.** This spec adds no network call, touches
  neither Reverb nor Wikimedia, and adds nothing to `PRIVACY.md`.

### Exports and import

- The new item **exports as an ordinary item**, in both formats, with no new
  column and no mark distinguishing it from one typed in by hand. Its
  purchase price, date and location are the columns the CSV has carried since
  `011`, which is exactly what the purchase sheet filled in.
- A **bought wishlist entry does not export**: it is no longer on the
  wishlist, and the wishlist CSV is what is on the wishlist.
- **Import is unchanged.** No new column means nothing new to parse (P7).

## Copy

**The shipped strings, replacing the shapes this section asserted** (T013,
2026-09-21). Every one of them lives in `PurchaseCopy` and is pinned by
literal in `PurchaseCopyTests`; nothing below is typed inline in a view. Where
a line differs from the shape the Draft asserted, the reason is beside it.

- The action, everywhere it is spoken or written in full: **Mark as bought…**
  (`markAsBought`, with a real `…`).
- The short form, in the two places whose width is short — the wishlist row's
  swipe button and, since the walkthrough, the Sell Plan's bar button:
  **Buy** (`swipeBuy`). VoiceOver says "Mark as bought…" in both, so the
  spoken name is one name.
- **No sheet title.** The Draft asked for "Mark as bought" in the bar; it
  shipped that way and the device pass found it truncating to `Mark as bo…`
  on all three hosts, beside a confirm button saying the same words, so the
  person had it removed (T012a). `PurchaseCopy.sheetTitle` no longer exists.
- Fields: **Purchase price**, **Purchase date**, **Bought from**
  (placeholder "eBay, Reverb, a friend…"), **Condition**.
- Confirm button: **Mark as bought**. Cancel: **Cancel**.
- The comparison line, under the price field: **"$120 less than you
  estimated"** / **"$85 more than you estimated"**, and **absent** when the
  two are equal, when there is no estimate, **and when they are less than a
  dollar apart** — the last of those is the plan's sub-dollar floor (Q7),
  narrower than this section's "differs", because every money figure in the
  app draws whole dollars and a 40-cent difference would otherwise read "$0
  more than you estimated". A consequence worth stating: `estimatedCostCents`
  is a non-optional `Int`, so a genuinely zero estimate is indistinguishable
  from no estimate here and gets no pre-fill and no line.
- **A refused purchase says so** (T012b, the person's decision at the
  walkthrough — this was not in the Draft at all): an alert titled
  **"Couldn't mark it bought"**, reading **"This one is already marked bought
  — it may have been bought on another device. Nothing was changed."** when
  the entry already carries a marker, and **"Something went wrong saving the
  purchase. Nothing was changed."** otherwise.
- **The wanted entry's Sell Plan button** (T012c, the person's decision — a
  change to `001`'s copy, not this spec's own): **"View your sell plan"** over
  **"<n> item(s) set aside"** once a plan is saved; today's "Find items to
  sell" / "Browse your lowest desire-to-keep items" when there is none.

There was no design pass for this spec, so the wording above was settled by
the plan, then corrected twice by the person at the pauses (the comparison
line's case, T011b; the sheet title and the bar button's word, T012a).

## Design requirements

- The purchase sheet is **the sale sheet's twin**. `006` built one and `014`
  seeds it identically from three hosts; this spec does the same with one
  sheet and three hosts, and the two sheets should read as a pair rather than
  as two designs for the same job.
- The swipe button follows `014`'s leading-swipe rules: the existing action
  stays nearest the edge so a full swipe keeps doing what it already does,
  and the new one sits beside it.
- The comparison line is **quiet** — supporting text, not a figure competing
  with the price field, and not colour-coded as gain or loss. It is an
  observation, not a verdict.
- No new colour, no new component, no new surface. Everything here is an
  existing sheet, an existing swipe and an existing menu.

## Acceptance criteria

Fourteen of the fifteen were verified at T013's close-out (2026-09-21) — by
the unit suite (**1622 tests in 224 suites**), the UI suite (**25 tests, run
twice back to back**), and the T012 device pass on the simulator, walked over
the seeded store and again over the person's own loaded collection, with a
file probe inside the writer rather than a screenshot. **Criterion 12 is an
honest partial and stays unticked**: everything an agent or the person could
check has been checked, and the two-device sync has not — nobody has run it
and no agent can. Each criterion below names what was actually verified, and
where the only witness is a unit test or an inspection it says so rather than
implying more.

1. [x] A wishlist row's leading swipe offers **Mark as bought…** beside the
   actions already there; the existing action stays nearest the edge so a
   full swipe still does what it did; the trailing swipe is unchanged.
    *Verified by*: `WishlistPurchaseWiringTests.theWishlistRowsLeadingSwipeOffersEditThenBuyThenCopy`
    (the one leading block's three buttons in order — Edit nearest the edge,
    then `PurchaseCopy.swipeBuy` staging `itemBeingBought` and carrying
    `Image("ActionBuy")` and `.accessibilityLabel(PurchaseCopy.markAsBought)`,
    then Copy — plus the trailing delete block naming no `PurchaseCopy`, G15)
    and `thePurchaseSheetIsHostedOnceOverTheStagedRow`. Mutations: Buy and
    Copy swapped → **7 legs red**; the middle button wired to
    `itemBeingEdited` → the target leg red **alone**, which is what shows each
    leg is read against the middle button and not the block. Every positive
    literal is closed on both sides, so T007's substring false-pass cannot
    reach it. On screen:
    `testTheWishlistsLeadingSwipeOffersMarkAsBoughtAndTheSheetSeedsFromTheEstimate`
    (a partial drag, never `swipeRight()`, and the middle button matched on
    "Mark as bought…" alone — no `OR "Buy"` hedge). On the device (T012): the
    three buttons at `minX` 10 / 70 / 130 read from the accessibility tree on
    **both appearances**, with a full swipe still opening Edit.
2. [x] The wishlist detail screen's menu offers **Mark as bought…** beside
   Edit and Delete, and there is **no button** for it on the page.
    *Verified by*: `WishlistPurchaseWiringTests.theMenuIsTheOnlyPlaceThePageOffersMarkAsBought`
    (`PurchaseCopy.markAsBought` appears in `WishlistDetailView.swift`
    **exactly once**, and that once is **inside** the `DetailOverflowMenu(`
    argument list, G17) and the **rewritten** `006` guard
    `SoldStateWiringTests.theWishlistPageBuildsItsOwnRowsAndStillNamesNoSaleCopy`
    (two `DetailOverflowMenu.Row` argument lists, exactly one of them naming
    `PurchaseCopy.markAsBought`, and still no `SaleCopy`), with
    `MenuPolicyTests` green **unedited** — a row added to the app's one system
    menu is not a second menu. Mutations: a page button added → the count goes
    to 2 → red; the row dropped → the `#require` on the anchor fails; **the
    word *moved* from the row to a page button** → the count stays 1 and only
    the "inside the menu's argument list" leg catches it, which is criterion
    2's real failure mode; the rows spelled `.init(` → the rewritten guard red
    **while `006`'s original assertions, run beside it, passed over a page
    that had already grown the row**. **Stated plainly**: the guard counts the
    *symbol*, so a page button spelled with the raw literal "Mark as bought…"
    rather than `PurchaseCopy.markAsBought` would pass it. The device pass is
    what checked the page itself.
3. [x] Each Sell Plan screen offers **Mark as bought…** for the wishlist item
   the plan belongs to.
    *Verified by*: `WishlistPurchaseWiringTests.theSellPlanOffersMarkAsBoughtOnlyWhileItsEntryIsStillThere`
    (exactly one toolbar action naming `PurchaseCopy.markAsBought`, composed
    inside a `viewModel.wishlistItem != nil` gate, wearing
    `Text(PurchaseCopy.swipeBuy)` and **no `Image(`** since T012a, G18) and
    `thePlansPurchaseSheetIsHostedOnceAndPopsTheScreenOnlyOnceItTakes`.
    Mutations: the gate dropped → red (the leg that matters — this screen
    already draws a "this is gone" state, and an ungated button would confirm
    a purchase with no subject); the `dismiss()` dropped → red; the sheet
    hosted twice → red; the bag glyph put back → red on both halves.
    **No automated end-to-end coverage**: the one UI test runs the swipe,
    which is the only path involving no navigation. This criterion was walked
    on the device (T012) — the action, the sheet, the confirm and the unwind.
4. [x] All three paths open **one sheet**, seeded identically, and cancelling
   any of them changes nothing at all.
    *Verified by*: `WishlistDetailViewModelTests.everyHostSeedsThePurchaseSheetIdentically`
    (G12 — the three hosts' seeds compared with and without an estimate;
    mutations: `?? 0` in one seed → red; one host on a different clock → red)
    and `aPurchaseThroughAnyHostLandsIdentically` (the same item and the same
    marker from each host, refetched on a second `ModelContext`). The cancel
    half is a **view-body** fact and is pinned on all three hosts
    (`thePurchaseSheetIsHostedOnceOverTheStagedRow`,
    `thePurchaseSheetIsPresentedOnceOverTheEntryThePageHolds`,
    `thePlansPurchaseSheetIsHostedOnceAndPopsTheScreenOnlyOnceItTakes`) —
    added at T011a, where it turned out two of the three were unguarded and
    deleting the cancel closure's one line left both suites green **while
    Cancel stopped closing the sheet at all**. On the device (T012): a file
    probe inside `WishlistPurchaseStore.markBought` counted Cancel 0 on all
    three hosts, swipe-down dismiss 0, a list re-render (background/foreground
    and an appearance change) 0, and confirm 1 — the mechanism instrumented
    rather than an artifact inspected.
5. [x] The sheet requires a price, a date and a condition, accepts an
   optional location, and pre-fills the price from the estimated cost when
   there is one.
    *Verified by*: `PurchaseFormViewModelTests` —
    `seedsThePriceFromTheEstimateAndTheDateFromTheClock`,
    `leavesThePriceBlankWithoutAnEstimate` (nil, never a pre-filled 0, which
    cannot be typed over), `refusesABlankPrice`, `refusesANegativePrice`,
    `acceptsAZeroPrice`, `recordsTheTypedAmountAndTheChosenCondition` and
    `trimsAndNilsTheBlankPlace` (G20) — and the sheet's composition by
    `WishlistPurchaseWiringTests.theFiveElementsAppearInTheSpecsOrder`,
    `theSheetNamesNoSaleCopyNoNoteAndNothingThatWrites` and
    `confirmingHandsThePurchaseOutPastTheViewModelsGuard` (G21). Mutation:
    a `?? 0` seed → the no-estimate case red on all three legs. **The date
    and the condition cannot be blank**: both are seeded (today, and
    `.excellent`) and neither control can clear itself, so "required" is
    structural here rather than a validation rule — the price is the only
    field with one. **The purchase date is deliberately unbounded** (plan Q9,
    `acceptsADateAWeekAhead`, pinned with the reason in the test), unlike the
    sale sheet's, because `ItemFormView`'s "Date bought" — the same field's
    own editor — accepts any date.
6. [x] The sheet shows how the entered price compares to the estimate when
   they differ, in words, and shows nothing when they are equal or when there
   is no estimate.
    *Verified by*: `PurchaseCopyTests.theComparisonUnderAndOverTheEstimate`,
    `theComparisonAtTheEstimateIsSilent`, `theComparisonWithNoEstimateIsSilent`
    and `theComparisonBelowADollarIsSilent` (G4; mutations: more/less swapped
    → red; the zero-estimate guard dropped → red; the sub-dollar floor dropped
    → **3 legs** red, the 40¢ case *and* the exact-equality case, since one
    guard carries both silences), read through the view model by
    `readsTheTypedPriceAgainstTheEstimate`, and rendered conditionally by
    `WishlistPurchaseWiringTests.theComparisonLineIsConditionalOnTheOptionalAndCarriesNoAccent`
    — the leg T011a added, because `Text(viewModel.comparisonLine ?? "")`
    would have satisfied the older scan while the silence stopped being
    silent. **Two things to state rather than imply.** The **sub-dollar
    floor** is narrower than this criterion's "when they differ" (plan Q7),
    and the person heard it at the Phase 2 pause. And the **no-estimate case
    is unreachable through the app's own forms** — the wanted-item form
    refuses to save without an estimated cost — so only an import can produce
    one; the device pass reached it that way.
7. [x] Confirming creates an item carrying the wishlist entry's name,
   category, photos (with a stock photo's credit intact), Reverb match, year,
   currency and notes; its current value equals the purchase price; its
   desire to keep is the default; it sits at the end of the custom order.
    *Verified by*: `WishlistPurchaseStoreTests.theBoughtItemCarriesTheEntrysFieldsThePurchasesAndTheEndOfTheOrder`
    (thirteen fields, refetched on a second `ModelContext`, with `sortOrder`
    taken past a deliberate gap in the existing positions — G5; mutations:
    `currentValueCents` left nil → red; `desireToOwn` passed as
    `desireToKeep` → red; `sortOrder` from a count → red; `currencyCode`
    dropped → red) and `thePhotosMoveToTheItemWithTheirIdsCreditAndOrderIntact`
    (G6 — the same `Photo` ids on the item, the **store-wide row count
    unchanged**, the `.fetched` credit's three attribution strings intact,
    `wishlistItem` nil on each and display order preserved; mutations: the
    photos rebuilt in `WishlistViewModel.duplicate(id:)`'s faithful shape →
    the id, count and credit legs red; `wishlistItem` left set → the ownership
    leg red in both suites), with `PhotoOwnershipTests` gaining the case its
    invariant had never had: a photo that **changes parent**. Two fixtures in
    this suite were found unable to fail and fixed — `desireToOwn` equal to
    `desireToKeep`'s default, and `currencyCode` "USD", which both
    initializers default to — and the whole diff was then audited for the
    shape. On the device (T012): the purchased item's page showing the moved
    photo with its **STOCK PHOTO** badge and credit intact, which is the one
    leg of G6 that is also visual.
8. [x] The wishlist entry leaves the Wishlist on confirming, and appears
   nowhere else in the app — there is no Bought side, no Bought card, and no
   second copy of the thing in any list.
    *Verified by*: `WishlistViewModelTests.aBoughtEntryIsOutOfTheListTheChipsTheTotalAndTheMarketSummaries`,
    `aPurchaseTakesTheRowOffTheListImmediately` and
    `aBoughtEntryNeverReappearsAfterAReorder` (G9),
    `SettingsViewModelTests.theWishlistCountAndItsFlagsIgnoreABoughtEntry`
    and `theMatchedCountDropsTheBoughtEntryAndPicksUpItsItem` (G10),
    `MarketRefresherTests.aBoughtMatchedEntryIsNoTarget` (G11), and
    `WishlistPurchaseWiringTests.thePageDismissesItselfOnAppearOnceItsEntryIsBought`
    with `WishlistDetailViewModelTests.hasBeenBoughtIsTrueOnlyForABoughtEntry`
    (G19) for the two screens that are already on the stack when the purchase
    happens. Mutations: the split dropped → red; each Settings predicate
    dropped in turn → its own leg red; the refresher clause dropped → red.
    On screen: `testMarkingAWantedItemBoughtMovesItToTheCollection` (the row
    gone from the Wishlist and listed on Items). **One thing measured and
    accepted rather than ticked past**: buying from a Sell Plan unwinds two
    screens, and the device pass filmed the wanted item's page sitting fully
    on screen, static, for **270–330 ms** before it slides off. A decision
    review accepted it for `015` — criterion 8 is about surfaces and copies,
    and a stack unwinding is not a surface — and the fix direction is on
    `ROADMAP.md`.
9. [x] The wishlist entry is **not deleted**: its record and its sell plan
   survive the purchase, the items sold toward it stay recorded, and the
   remaining unsold candidates are released from the plan.
    *Verified by*: `WishlistPurchaseStoreTests.thePurchaseReleasesTheUnsoldCandidatesAndKeepsWhatWasSoldTowardIt`
    (G7 — `plannedSaleItems` empty, `itemsSoldToward` the same items in the
    same number, the released candidates still in the store and still unsold;
    mutations: `itemsSoldToward` cleared → red; `plannedSaleItems` left → red)
    and `theEntryIsMarkedBoughtAndEverythingSurvivesTheCallersSave` (G2, on a
    second `ModelContext`; mutation: the caller's `save()` dropped → red).
    **Stated plainly: the unit tests are the only witness.** The device pass
    established that a retained bought entry is **not observable through the
    UI** once it leaves the Wishlist, and by criterion 13 it is in no export,
    so nothing on a screen can show it survived. `009-sell-plan-list` is the
    spec that will first have a surface for it.
10. [x] Every Dashboard figure reflects the new item exactly as it would an
    item added any other way, and the Dashboard grows no new surface.
    *Verified by*: `DashboardViewModelTests.aPurchasedItemReadsExactlyLikeATypedOne`
    (G22 — the criterion's claim is *indistinguishability*, so the test
    compares the figures over a store where the item arrived by purchase with
    the figures over one where the same fields were typed in, rather than
    asserting numbers; mutation: the store leaving `currentValueCents` nil →
    the un-valued count diverges → red). That no surface was added is
    evidenced by the **diff** — no file under `Trove/Views/Dashboard/` is in
    it — and observed on the device (T012), figures read before and after one
    purchase.
11. [x] Buying the last wishlist item leaves the Wishlist in its existing
    empty state, not a broken or blank one.
    *Verified by*: `WishlistViewModelTests.buyingTheOnlyWantedEntryLandsOnTodaysNothingAddedState`
    (today's `.nothingAdded` state, no new empty reason) and, on screen, the
    tail of `testMarkingAWantedItemBoughtMovesItToTheCollection`. **The guard
    that actually holds it is the `totalCount` leg**: filtering `items` while
    leaving `totalCount = all.count` reddens the empty-state leg **alone**,
    which is the mutation that shows why the count matters as much as the list
    — `WishlistView` gates the search field, the chips and the sort control on
    `totalCount > 0`, so a stale count leaves them sitting over an empty list.
12. [ ] The bought marker survives a relaunch and syncs; the schema still
    validates against CloudKit.
    **An honest partial.** *Verified*: the schema by
    `CloudKitSchemaTests.schemaMeetsCloudKitRequirements` — and the mutation
    that proves it can fail was run at T001 (`@Attribute(.unique) var
    boughtDate: Date?` → red on "CloudKit integration does not support unique
    constraints"), which also reddened
    `TwoStoreContainerTests.theProductionPairingLoadsAndSplits`, so the
    compatibility claim turns out to have two live guards. Persistence by G2's
    refetch on a **second `ModelContext`**, and on the device (T012) by a
    **relaunch on the persistent store**: the entry still off the Wishlist,
    the item still in the collection. VoiceOver: the swipe button's spoken
    name was read from the live accessibility tree as **`Mark as bought…`** —
    the modifier takes, it does not read "Buy" — and the person's
    Accessibility Inspector pass over the swipe action, the menu row, the Sell
    Plan's bar button and the sheet's fields reported all as expected.
    **What has not been done: the two-device sync check.** No agent can run
    it, and the person has not. The `alreadyBought` guard that exists *for*
    the cross-device case is proven by
    `WishlistDetailViewModelTests.everyHostRefusesToBuyAnEntryTwice` and
    `anEntryCanOnlyBeBoughtOnce` (mutation: the guard removed → **12 legs
    red**), but a unit test proves the guard, not that a marker arriving from
    another device is visible in time. The device pass tried to rebuild that
    window and could not: a relaunch resets navigation to the root, and the
    only in-app window is the ~300 ms of criterion 8's unwind, shorter than
    one round trip of the tap tooling.
13. [x] Exports are unchanged in shape: the new item exports as an ordinary
    item in both formats, a bought wishlist entry exports in neither, and
    import parses today's files exactly as it does now.
    *Verified by*: `SettingsViewModelTests.theWishlistCSVCarriesOnlyLiveRowsWhileTheItemsCSVCarriesThePurchase`
    and `deleteAllWantedLeavesTheBoughtEntryInTheStore` (G10; mutation: the
    export predicate dropped → the wishlist file carries the bought row →
    red), with `ExportSchemaTests.headerListsMatchThePinnedSchema` green
    **unedited** — no new column, which is why there is nothing new to parse.
    That import is unchanged is evidenced by the **diff**: no file under
    `Trove/Import/` or `Trove/Models/ExportSchema.swift` is in it. On the
    device (T012): the export-everything files read out of the container — the
    items CSV carrying the purchased item with unchanged headers, the wishlist
    CSV **header-only** — and an import was used to reach criterion 6's
    no-estimate case, which exercised the parse side on today's files.
14. [x] Nothing in this feature opens a network connection.
    **Ticked by inspection, and the inspection is the honest ceiling here.**
    No test in this project can catch this being false without being a broad
    noun-scan over the source — the shape `CLAUDE.md` names twice as having
    gone vacuous (the seven-noun policy scan whose table could be deleted
    while it stayed green, and `014`'s menu-row guard that `.init(` kept
    green). What can be said precisely: the purchase path takes no service
    and constructs none — `WishlistPurchaseStore`, `PurchaseFormViewModel` and
    `PurchaseFormView` name no `URLSession`, no `ReverbService` and no
    `WikimediaService`, and the diff adds no argument to any view model's
    initializer that could carry one. The one place this spec touches `002`'s
    network layer is `MarketRefresher.targets(in:)`, where it **removes** work
    (a bought entry is no longer a refresh target, G11). The device pass adds
    the observation rather than the proof: no request was made on any purchase
    it drove, though the absence of a connection could not be observed without
    cutting the session, so T012 recorded it as not separately proven and this
    tick is the inspection.
15. [x] No path in the app undoes a purchase, and the bought item's menu
    offers nothing that returns it to the wishlist (Decision 5).
    *Verified by*: `PurchaseUndoTests` **plus the diff**, and the two halves
    are evidenced differently — which is the `014` criterion-2 lesson: cite
    the diff, do not claim a test enumerates a menu. The **marker's half** is
    the test (G14, plan Q13): every production file under `Trove/` is walked,
    `boughtDate` is assigned **exactly once** across all of them, that one
    assignment is inside `Trove/Models/WishlistPurchaseStore.swift`, and no
    file assigns it `nil` or `.none` — so no screen *could* put a bought entry
    back, there being nothing that writes the reversal. Re-run against the
    finished tree at T013, because T003 wrote it before the views existed:
    adding `boughtDate = nil` to a view model reddens both tests and names the
    file; adding a `boughtDate == nil` **comparison** to a view model leaves
    it **green**, which is what shows the pattern tells a write from a read
    and why §4's four predicates do not redden it. **The menu's half is the
    diff**: `ItemDetailView` — the bought item's page, and the file that owns
    its "…" menu — is **not in this spec's diff at all**, and
    `DetailOverflowMenu` is in it **only in its doc comment** (13 insertions,
    2 deletions, every one of them a comment line), which adds no return path.
    **What G14 cannot see, stated rather than left implied**: an undo written
    as "delete the created `Item` and insert a fresh `WishlistItem`" would
    never touch `boughtDate` and would pass it. Nothing in this spec does
    that; no test could tell you if a later one did.

## Decisions record

Made by the person, 2026-09-19, in this spec session:

1. **No Bought side on the Wishlist.** Once an item is bought it is in Items,
   and the person does not want duplicates. `014`'s parity argument does not
   carry: Owned and Sold are two states of one row, whereas a Bought side
   would be a second copy of a row that now lives elsewhere.
2. **No funding record on the bought item.** The person's reasoning: the Sell
   Plan is guidance, not a trade ledger — "we're selling things and then
   buying them separately," and a link asserting that three specific sales
   paid for this purchase would be a claim the app has no business making.
   Noted during the conversation and worth recording, because it narrows the
   decision rather than reversing anything: the funding record **already
   exists and already ships** — `006` built `itemsSoldToward` and the Sell
   Plan already lists what was sold toward a wishlist item. This decision is
   that it is not *extended* onto the new item's page.
3. **The wishlist entry is marked bought, not deleted** — the person's own
   alternative from the same answer: "we could retain the sell plan and have
   the sell plan marked as completed, which would be a record of that
   anyways." Chosen over deletion because the plan hangs off the wishlist
   entry and dies with it, and because deletion would destroy the
   sold-toward history `006` deliberately made survivable. A third reason
   given at the time — that an undo is impossible once the row is gone —
   fell away with Decision 5; the first two carry the decision on their
   own.
4. **All three entry points** — the swipe, the detail menu and the Sell Plan
   screen — with the placement details left to Claude Code's judgement.

Made by the person, 2026-09-19, at their reading of the Draft, answering its
three open questions and approving it:

5. **No undo.** The Draft proposed **Return to wishlist** in the bought
   item's menu, mirroring `006`'s Return to collection. Withdrawn: that undo
   would have to delete the item the purchase created, which by then may
   carry photos, a serial number or notes added since, and a destructive
   undo is a worse hazard than the mistake it reverses. Every path to a
   purchase already goes through a sheet that has to be confirmed, so the
   mis-tap `006` guards against cannot happen here. A purchase marked in
   error is corrected by hand.
6. **The over/under-estimate line stays.** When the price paid differs from
   the estimate, the sheet says by how much, in words.
7. **The wishlist entry's notes carry across** to the new item.

## Non-goals (explicit)

- **A Bought side on the Wishlist**, a Bought card on the Dashboard, or any
  other new surface (Decision 1).
- **Any assertion that particular sales funded a particular purchase**
  (Decision 2). `006`'s existing sold-toward record is untouched and
  unextended.
- **Surfacing completed sell plans anywhere.** The data is retained; the
  screen that shows it is `009-sell-plan-list`, whose entry records that it
  waits on this spec for a definition of "active". A bought wishlist entry is
  invisible until `009` ships.
- **Undoing a purchase** (Decision 5). No Return to wishlist, no
  confirmation flow, nothing in the bought item's menu. Two consequences are
  accepted rather than solved: a purchase corrected by hand leaves the
  original marked-bought entry in the store unreachable, and that orphan
  will read as a completed plan once `009-sell-plan-list` ships. Both are
  cheap to address in `009`, which is the spec that first has a screen to
  address them on.
- **A one-tap purchase** — every path opens the sheet.
- **Buying something that was never on the wishlist.** Adding an item
  directly is what the Items tab has always done; this spec is about the
  wishlist entry's ending, not about a second way to create items.
- **Partial or planned purchases**, deposits, layaway, or a purchase recorded
  as pending.
- **Any change to the sale sheet, the sold side, or `006`'s fields.**
- **Any new CSV column, export document, or import behaviour** (P7).
- **A Dashboard figure for money spent**, purchases over time, or any chart —
  that is `016-collection-value-history`'s territory.
- **Mapping desire-to-own onto desire-to-keep** (P5).
- **Editing the purchase after the fact through this feature** — the item is
  an ordinary item and its Edit screen already owns every field the sheet
  filled in.

## Inherited caveats

- `001`'s fixed type sizes apply — every font in this feature's sheet is
  fixed-size like the rest of the app, until `017-dynamic-type`.
- `001`'s USD-only rule applies; the purchase sheet has no currency picker,
  and the item inherits the wishlist entry's currency code.
- `013` Amendment A's "bespoke in the page, system in the bars" rule places
  the menu actions, and `MenuPolicyTests` enforces it — until
  `018-system-design-language` revisits the rule itself.

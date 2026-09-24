# 009 — Sell Plan List

**Status**: **Approved** (2026-09-22) — written with the person in a spec
session of its own, per `CLAUDE.md`'s model policy as amended 2026-09-19 (Opus
5, raised to high effort for the conversation; the session moved to Opus 5.5 on
2026-09-22). Approved by the person on 2026-09-22 conditionally on one more
review pass, with the instruction to resolve whatever it found unless something
needed them; it found nothing that did, and its changes are listed under
**Review pass** at the end. The **Decisions record** below
holds every product decision the person made in that conversation. The
**P-items** are Claude Code's proposals and become decisions on plan approval,
as `002`'s, `005`'s, `006`'s and `015`'s did. The conversation ran to a second
round: the person's reading of the first Draft replaced its most destructive
proposal with a simpler rule (Decision 9) and settled the one remaining fork
through the principle behind it (Decision 10), so **nothing is left open**.
**Amendment A** (2026-09-23), from the person's Phase 3 and Phase 4
walkthroughs, is at the end: Decisions 13–18 and criteria 20–23; it revises
Decision 11 and criterion 7. Approved by the person on 2026-09-23 ("Correct
on both").

**Depends on**: `001-core-inventory` (the wishlist, the Sell Plan screen and
its ranking, the tab bar, the manual wishlist order, the cross-tab deep-link
mechanism), `003-trend-aware-sell-plan` (the ranking and the standing refusal
of a target figure), `006-mark-as-sold` (`itemsSoldToward`, the sold-toward
record and the Sold figure on the Sell Plan), `010-item-management-enhancements`
(the sort picker and the delete confirmation idiom), `013-settings-menu`
("bespoke in the page, system in the bars"), `014-sold-side-parity` (the
two-sided list screen with its own sort per side), `015-mark-as-bought` (the
bought marker, which is what ends a plan, and the purchase sheet this spec
hosts a fourth time). It adds no outside service and touches no network code.

## Summary

Trove has had sell plans since `001` and has never had a way to see them. A
plan lives inside one wanted item's screen; to find out which of your wants
you are actually working toward, you open them one at a time. `015` finally
gave a plan an ending — the wanted entry is marked bought, not deleted, so the
plan survives as the record that it was carried out — but nothing in the app
displays that record, so it exists only in the test suite.

This feature gives sell plans a place. A **plan becomes a real thing you
create**, rather than something inferred from whichever items happen to be
ticked at the moment, and a new **Plans tab** lists them: the ones you are
working on, and, in a section of its own, the ones that ended in a purchase.
Each row says what the plan is for, how much you have set aside, what has
already sold toward it, and whether the sales have covered what you expect to
pay. From a row you can open the plan, mark the thing bought, or delete the
plan.

## What and why

The roadmap's `009-sell-plan-list` entry has been open since `001`'s Phase 7
review and was blocked for most of that time on one word. The screen hangs
entirely on **active**, and the app had no definition of it: the only one
available was "you have ticked at least one candidate," and nothing could ever
take a plan off the list again. Buy the thing the plan was funding and it
still read as active, forever.

`015` supplied the ending. It also, at its sweep, found that the obvious
definition fails from the other side: `markSold` empties the selection, so a
plan whose every candidate has actually been **sold** — the plan that worked —
reads as no plan at all. A list of active plans that drops a plan at the
moment it succeeds is the wrong list.

Both failures have the same cause, and this spec fixes the cause rather than
patching the two symptoms. **A selection is not a plan.** The set of items you
are weighing is a working surface that changes every time you tick something,
sell something, or change your mind; it is the wrong thing to hang a lifecycle
on. A plan is a **statement of intent to buy a particular thing** (Decision 1).
You make it deliberately, it persists while you work at it however the
selection churns underneath, and it ends when you buy the thing or when you
decide you are not going to.

Three things this spec deliberately preserves:

- **The Sell Plan stays advisory.** `003` refused a target and a completion
  figure on the wanted item's button, and `015` held that line again at the
  person's instruction: a count of what you set aside is allowed where "$840
  of $3,900" is not. This spec shows counts, never money figures
  (Decision 5), and adds no number the app does not already stand behind.
- **The candidate pool stays dynamic.** It is every qualifying owned item,
  re-ranked on every visit — not a saved list. Selling one removes it from the
  pool and anything else that qualifies is still suggested. That is how the
  Sell Plan already works and this spec does not change it.
- **Real history is never destroyed.** Deleting a plan never unsells anything.
  `006` made the sold-toward link survivable on purpose; everything sold stays
  sold, stays in your collection's Sold side, and keeps its sale record.

## Core behavior

### A plan is created, not inferred

- A wanted item either **has a plan or does not**, and that is a fact the app
  stores (Decision 1). It no longer follows from whether anything is currently
  ticked.
- The wanted item's Sell Plan entry point becomes an explicit act. With no
  plan it offers to **create** one; with a plan it offers to **view** it, over
  the count of what is set aside (P9). This replaces today's two states, which
  are both derived from the selection — so a plan whose items have all sold
  currently reverts to reading as though no plan was ever made.
- **The plan exists from the tap** — the person's words: it "is created when
  selecting 'Create a sell plan'." Creating it opens the Sell Plan screen as it
  opens today, with nothing auto-selected and still no target to reach. Backing
  out without ticking anything leaves a plan with nothing set aside, which is a
  plan like any other and is deleted like any other.
- **The entry point never says "0 items set aside."** With a plan, its second
  line is the count set aside when there is one, otherwise the count sold
  toward it, otherwise a line saying nothing is set aside yet (P9).
- **A plan is active until the wanted item is bought**, at which point it is
  **completed** (Decision 1) — `015`'s marker is the ending, and it is the
  only one besides deletion.
- **Existing plans carry over, once.** Anyone using the app today has wanted
  items with selections, sold-toward history, or both, and no stored plan.
  Those become plans and appear on the list; nobody has to re-make a plan they
  already made (P10). This happens **once**, to the collection as it stands —
  it is not a standing rule that a want with sold-toward history has a plan.
  That distinction matters because the sold-toward record survives a deletion
  (P3): a standing rule would resurrect a plan the moment you deleted it.
  Entries **already bought** by the time this ships carry over by their
  sold-toward history alone, since `015` released their selections at the
  purchase; one bought with a selection but no sales left no trace a plan
  existed, and does not appear.
- **Buying a wanted item that has no plan creates none.** It never appears on
  the Completed side; there was no plan to complete.

### The Plans tab

- A **fourth tab**, beside Overview, Items and Wishlist (Decision 4). It is
  the first change to the tab bar since `001`, which left the fourth slot
  deliberately empty with the instruction to fill it "when an actual feature
  needs it, not preemptively."
- The tab has **two sides**, switched the way the Items tab's Owned and Sold
  are switched (P1): **Active** and **Completed**. It opens on Active at every
  launch, as the Items tab opens on Owned.
- Each side keeps **its own sort selection**, as `014` gave the Sold side its
  own (Decision 6, P5). The control is the app's existing sort picker.
- Rows are **card-sized**, not compact list rows, because of how much they
  carry. Tapping a row opens that wanted item's **existing Sell Plan screen** —
  there is no new detail screen in this feature.

### What a row says

Every row carries (P2):

- the wanted item's name and category, and on an **active** row its
  **thumbnail**, drawn the way the wishlist's own rows draw them;
- **what you have set aside** — a count, in the words the wanted item's page
  already uses, and absent when nothing is;
- **what has sold toward it** — a count, and absent when nothing has;
- a quiet **covered** marker when the sales alone have reached the wanted
  item's estimated cost, and never when it has no estimate (P8). This is not a new judgement: the app already decides this and
  already shows it on the Sell Plan screen, where it is rendered as a colour.
  Here it is a word, because a row with no money figure on it has nothing for a
  colour to attach to, and a bare colour carries nothing to VoiceOver.

A **completed** row says the same things in the past tense and carries the
**date bought** — and **no picture and no picture slot** (Decision 11). The
wanted item's photos moved to the item it became at the purchase (`015`), so
there is nothing left to draw; rather than a placeholder where a picture used
to be, every row on the Completed side is the same text-only shape, so nothing
ever visibly loses its image in place. Its covered marker still reads against the estimate, which
is the only figure the entry holds: it keeps no link to what was actually paid
(`015` Decision 2). What it does not carry is any figure comparing what was
raised to what was paid — that is the arithmetic `003` refused and `015`
declined to introduce, and buying does not make it a different claim.

### Deleting a plan

A plan can be deleted, like anything else in the app (Decision 3) — and like
an owned or wanted item, from two places: the row's swipe on the Plans tab, and
the plan's own screen (P11). Both use the app's existing delete confirmation
and a sentence naming what survives — the shape `010` settled and
`WishlistDeleteCopy` holds.

Deleting a **wanted item** takes its plan with it, as it always has; that
item's existing delete confirmation already says the gear on its plan stays
where it is, and remains true.

**Deleting a plan deletes the plan and nothing else** (Decision 9). The same
rule on both sides, in the person's words: "deleting a sell plan should only
delete the sell plan. Sold items should be items that are sold. Nothing more."

- Every **item** involved is untouched. Owned gear that was set aside is still
  owned and goes back in the pool. Anything sold toward the plan is still
  sold, still in your collection's Sold side, still carrying the price you
  recorded for it.
- **Deleting an active plan** leaves the wanted item on your wishlist,
  unchanged and still wanted, with no plan — its page goes back to offering to
  create one (P3).
- **Deleting a completed plan** leaves the item you bought exactly where it is,
  an ordinary item in your collection. What goes is the record that the
  purchase was planned (P4).
- **The record of what sold toward the want survives the deletion** (P3). Those
  sales really happened and really were toward that thing; deleting a plan is
  a statement about the plan, not a retraction of history. Delete an active
  plan and make a new one for the same want later, and that history is still
  there.

This is what answers the orphan `015` left behind. When a purchase is marked
in error the correction is done by hand — delete the item, add the want back —
and the original marked-bought entry stays in the store, unreachable, and
surfaces here as a completed plan for a purchase that never happened. The app
cannot tell that entry apart from a real one and does not try: it **shows**
it, which is the first time anything has, and lets you delete the phantom plan
off the list. No automatic sweep, because there is nothing to sweep by: a
bought entry keeps no link to the item its purchase created (`015` Decision 2
declined one), so the app cannot even ask whether that item still exists — and
if it could, the answer would be equally "no" for a real purchase later sold or
deleted. A sweep would silently destroy real history to tidy up a rare
mistake.

*Revised in part by Amendment A (Decision 16; plan QA1), 2026-09-23: a
purchase made from then on **does** record the item it became
(`WishlistItem.boughtItem`), so "keeps no link" is true only of purchases
made before the amendment. The conclusion stands on the same ground: a
deleted item nils the link, so a real purchase whose item was later deleted
still reads exactly like an orphan, and the app still cannot tell them
apart. No sweep. The paragraph above is the person's and is left as
written.*

**What that leaves, said plainly rather than implied**: the orphaned entry
itself is not removed from the store, only its plan and its place on this
list. A bought entry with no plan is in no list, no count, no export and no
screen — it is exactly as inert as `015` left it, and deleting its plan is
what takes it off the one surface it had reached. Removing the row itself
would mean deleting a record `015` kept on purpose, on a guess about which
purchases were real.

### Opening a plan

- An **active** plan opens its Sell Plan screen exactly as today: the ranked
  pool, the selection, the Sold section, **Mark as sold…** on a candidate, and
  **Mark as bought…**.
- A **completed** plan opens **the record, not the workbench** (P12): what
  sold toward it and when it was bought, and nothing that acts. No candidate
  pool, no selecting, no **Mark as sold…** and no **Mark as bought…**. The
  purchase has happened; a pool of gear to sell toward it would be advice about
  a decision already made, and a selection on a bought entry would be exactly
  the state `015` released at the purchase. Deleting the plan is the one action
  it offers.

  This is new ground, not a restatement: until now no path in the app has ever
  opened a bought entry's plan, so today's screen has never had to know the
  difference, and as built it would offer both actions.

### Marking something bought from here

Every active row offers **Mark as bought…** (Decision 7), opening `015`'s
purchase sheet seeded exactly as its three existing hosts seed it. This is the
screen where the decision is most likely to be made — the plan is what you came
to check — and confirming moves the row from Active to Completed in front of
you.

Everything else about a purchase is `015`'s and is unchanged: the sheet's
fields, what the new item carries across, the entry being marked rather than
deleted, the unsold candidates being released, and the refusal alert when the
entry is already marked.

There is still **no undo** (`015` Decision 5). Deleting a completed plan is not
an undo: it removes the record of the plan, not the purchase.

### The Dashboard card

- The Dashboard grows a card reading **how many active sell plans** you have,
  which opens the Plans tab on its Active side (Decision 4) — the cross-tab deep-link `001`
  already built and `006`'s Sold card already uses.
- The card is **absent entirely** when there are no active plans, as the Sold
  card is absent when nothing has sold (P6) — and absent on the Dashboard's
  first-run screen, before you own anything, as every card is (Decision 12).
  That screen's one job is to get the first item added; the Plans tab is in
  the tab bar regardless.
- It appears on the **Dashboard's root only**, not inside a category
  drill-down (P6). A plan is not a category's property — the gear sold toward
  it can come from anywhere in the collection — so a scoped count would be
  arbitrary, and a count that ignored the scope would be the only figure on
  that screen that did.

### Sync and privacy

- That a plan exists is the person's own data about their own intentions, so
  it **syncs**, like the bought marker `015` added and the sale fields `006`
  added. It follows the same CloudKit rules every field in this schema
  follows.
- **Nothing leaves the device.** This spec adds no network call, touches
  neither Reverb nor Wikimedia, and adds nothing to `PRIVACY.md`.

### Exports and import

- **Exports are unchanged**, in both formats (P7). A plan is not a column, and
  what a wishlist CSV carries is what is on the wishlist. A bought entry
  surfaced on this screen is still not in any export, exactly as `015` left
  it.
- **Import is unchanged.** No new column means nothing new to parse. An
  imported wanted item arrives with no plan, and can have one created like any
  other.

## Copy

**The shipped strings, replacing the shapes this section asserted** (T016,
2026-09-23). Every one of them lives in `SellPlanCopy` and is pinned by
literal in `SellPlanCopyTests` — except the Delete All Sell Plans strings,
which live in `DeleteAllCopy` beside the two Delete All rows they join (plan
QA4) and are pinned in `DeleteAllCopyTests`. Where a line differs from the
shape the Draft asserted, the reason is beside it.

- The tab: **Plans** (`tab`). The two sides: **Active** and **Completed**,
  spoken together as **"Active or completed"** (`sideSwitchLabel`, the Items
  switch's "Owned or sold" shape).
- The wanted item's entry point, with no plan: **Create a sell plan** over
  **Browse your lowest desire-to-keep items** (`createPlan`,
  `noPlanSubtitle`). With a plan: **View your sell plan** (`viewPlan`) over,
  in order of preference, **"1 item set aside" / "<n> items set aside"**,
  else **"<n> sold toward it"**, else **"Nothing set aside yet"** — so it
  never reads "0 items set aside" (P9). The three strings `015` T012c had
  typed inline in `WishlistDetailViewModel` moved into `SellPlanCopy`
  unchanged.
- An active row's lines: **"<n> item(s) set aside"**, **"<n> sold toward
  it"**, then **Covered** (`covered`), each present only when its count is
  non-zero or its rule holds.
- A completed row's lines, in the past tense: **"Bought Sep 12, 2026"**
  (`bought(on:)`, the date `.abbreviated`), then **"1 was sold toward it" /
  "<n> were sold toward it"** (`soldTowardPast`), then **Covered**. The
  Draft named no past-tense form; the plan settled it (§3).
- A completed plan's record, when nothing sold toward it: **"Nothing was
  sold toward it."** (`nothingSoldToward`) — a line the Draft did not
  anticipate, since it did not yet have a record screen (P12).
- Deleting a plan: **"Delete the sell plan for <name>?"** (`deleteTitle`,
  with **"this item"** standing in for a missing name) over **"Nothing you
  own or sold is touched, and <clause>. What sold toward it stays on the
  record. This can't be undone."** — the clause **"it stays on your
  wishlist"** on Active and **"the item you bought stays in your
  collection"** on Completed, one function with one varying clause. Confirm
  **Delete**, cancel **Keep**. On the Sell Plan screen the confirm word is
  also the bar button's label — **Delete**, in rust, apart from **Buy**
  (Decisions 13 and 14).
- The Dashboard card: header **Sell plans** over **"1 active sell plan" /
  "<n> active sell plans"**, hint **"Shows your active sell plans"**.
- The four empty states: **"No sell plans yet"** / **"A plan starts from
  something on your wishlist. Open it and tap Create a sell plan."**;
  **"Nothing on your wishlist"** / **"A sell plan starts with something you
  want. Add it to your wishlist first."**; **"Nothing completed yet"** /
  **"A plan lands here when you mark its item bought."**; and the app's
  existing **"Catching up with iCloud"** over **"Your plans are on their way
  to this device. They'll appear here as they arrive."**
  (`stillSyncingDetail`). **Stated rather than implied**: that one headline
  is typed inline in `PlansView`, as it is in the four other list screens
  that show it — it is the app's shared wording, not this spec's, and moving
  it would have touched four merged screens.
- The sort labels, on their enums (the `SoldSortOrder.label` pattern):
  Active **Newest**, **Oldest**, **Name**, **Wishlist order**; Completed
  **Newest**, **Oldest**, **Name** — where Newest and Oldest read the **date
  bought**.
- The Plans "…" (Decision 17): one row, **Settings**; the dropdown's dismiss
  control reads **"Dismiss more actions"**, as the other tabs' do.
- **Delete All Sell Plans** (Decision 18, `DeleteAllCopy`): the row
  **"Delete All Sell Plans…"**, hint **"Permanently deletes every sell plan,
  active and completed."**; the title **"Delete all 4 sell plans?"** /
  **"Delete your only sell plan?"**; the message **"Nothing you own or sold is
  touched, and everything on your wishlist stays there. What sold toward them
  stays on the record."** (**"…toward it…"** for one), then on iCloud only
  **" If you're signed in to iCloud, the plans are removed from your other
  devices as well."** (**"the plan is"** for one — named, because after
  "what sold toward them" a bare "they're" would read as the sales), then
  **" This can't be undone."**; confirm **Delete All**, cancel **Keep**; the
  section's footer **"Export first if you want a copy."** unchanged (RA3,
  kept by the person).
- **Delete All Items, and deleting one item a purchase created** (T021a, the
  person's call at the Phase 4A walkthrough — not in any Draft): the
  several-items message now reads **"Their photos go too. Every sell plan
  loses its items, and completed plans lose their pictures."**; for one
  item, only when it is the item a purchase became, **"…Any sell plan it's
  on drops it, and the completed plan it was bought for loses its
  picture."** (owned) / **"Its photos go too, and the completed plan it was
  bought for loses its picture."** (sold). Otherwise the text is exactly what
  it was.

There was **no design pass for this spec** (Decision 8), so the wording above
was settled by the plan and corrected by the person at the pauses: the Sell
Plan's Delete as a word of its own rather than a "…" (T009b), and the
picture clause on Delete All Items (T021a).

## Design requirements

- **The tab icon is drawn to match** the existing three, not passed through
  Claude Design (Decision 8). `001` said tab icons need a real design pass
  rather than engineering guesswork; the person has scoped that out for now,
  so the mark is built in the same flat/graphic language as `TabDashboard`,
  `TabItems` and `TabWishlist` and can be revisited.
- **No new colour and no new component.** The two-sided screen, the sort
  picker, the card row, the delete confirmation, the purchase sheet and the
  Dashboard card all exist; this screen assembles them.
- The **covered marker is quiet** — supporting text, not a badge competing
  with the name, and not coloured as gain or loss. It is an observation, the
  same register the comparison line on `015`'s sheet was corrected into.
- **Rows keep the list-screen rules `001` set**: on the Active side a
  thumbnail slot is always reserved so the scroll keeps its rhythm, and the
  header stays fixed while only the rows scroll. The Completed side keeps the
  same rhythm the other way round — **no** row there has a slot (Decision 11),
  which is `001`'s reason (every row in one scroll the same shape) applied to a
  side where no row has a picture to show.

## Acceptance criteria

Verified at T016's close-out (2026-09-23) by the unit suite (**1746 tests in
234 suites**), the UI suite (**36 tests**, run twice back to back at each
phase end and twice more at T015), and the T015 device pass — two upgrades
in place and a walk over the persistent store on two spare simulators, with
a file probe inside `SellPlanStore` rather than a screenshot — plus the
person's own Accessibility Inspector and VoiceOver pass, reported on
2026-09-23: "All voiceover labels are as expected." **Twenty of the
twenty-three criteria are ticked. Criteria 17, 20 and 22 stay unticked**:
everything one device can show about them has been shown, and their sync
halves have not been run by anyone — the person cannot run them yet and
asked for them to be marked **untested**. Each is gathered in
`specs/SYNC-CHECKS.md` for one later pass. Both simulators were signed out
of iCloud, so every carry-over the device pass saw ran the signed-out path.
Each criterion below names what was actually verified; where the only
witness is a unit test, an inspection or a hand check, it says so.

1. [x] A wanted item with no plan offers to **create** one; the plan exists
   from that tap, and it opens the Sell Plan screen with nothing selected and
   no target. With a plan, the entry point never reads "0 items set aside".
    *Verified by*: `WishlistDetailViewModelTests.theSellPlanEntryOffersToCreateAPlanWhenThereIsNone`,
    `openingTheSellPlanCreatesItExactlyOnce`,
    `aRowAwaitingTheCarryOverOffersCreateAndTheTapCreatesThePlan` and
    `openingTheSellPlanOnABoughtEntryCreatesNothing` (G16 — the plan is
    stored at the tap, refetched on a second context; mutation: re-create on
    a second tap → the date leg red), with
    `theSellPlanEntryNamesThePlanAndCountsWhatIsSetAside`,
    `theSellPlanEntryFallsBackToWhatWasSoldTowardIt` and
    `SellPlanSummaryTests.theEntrySubtitlesThreeReadings` (G4) for the
    subtitle (mutations: the fallbacks swapped → red; "0 items set aside"
    returned → red). `SellPlanStoreTests.createDatesThePlanNowAndStampsTheRowChecked`
    and `aSecondCreateKeepsTheFirstDate` (G5) hold the one writer. The Sell
    Plan screen itself is unchanged (a Non-goal), and
    `SellPlanFramingTests` stayed green **unedited** — still no target. On
    screen: `testCreatingASellPlanFromAWantedItem` (Rode → **Create a sell
    plan** → the Sell Plan → back → **View your sell plan** over **Nothing
    set aside yet**; the Plans tab lists Rode), whose tap leg went red when
    the view skipped `openSellPlan()` (the Phase 3 review's addition). The
    person walked it at the Phase 3 pause.
2. [x] A plan stays on the Active side no matter what happens to the
   selection — including after every item on it has been **sold**, which is
   the case `015`'s sweep found reads as no plan at all today.
    *Verified by*: `PlansViewModelTests.aPlanWhoseEveryItemWasSoldStaysActive`
    (G10; mutation: `active` read from the selection → 12 issues red) and
    `WishlistDetailViewModelTests.theSellPlanEntryKeepsThePlanWhenItsSelectionIsReleased`.
    On screen: `testThePlansTabSitsFourthAndOpensOnActiveEveryLaunch` lists
    the seeded Vox AC15 — whose one set-aside item was sold, emptying the
    selection — on Active, reading "1 sold toward it". On the device (T015):
    the upgraded store's entry with only a sale toward it lands on Active.
3. [x] A plan leaves the Active side and appears on the Completed side when
   the wanted item is marked bought, by any of the four paths that can mark
   it; a wanted item bought with no plan appears on neither.
    *Verified by*: `WishlistDetailViewModelTests.aPurchaseThroughAnyHostLandsIdentically`
    — all four hosts (the Wishlist swipe, the wanted page's menu, the Sell
    Plan's Buy and the Plans row's swipe) land one entry, bought, **with its
    plan on its own date**, refetched on a second context (G13; mutation:
    the fourth host skipping its save → the landing leg red) — and
    `aPurchaseThroughAnyHostLeavesAPlanlessEntryPlanless` (each host buys a
    planless entry and the Plans view model shows it on neither side; the
    Plans tab, handed a stray row for one, refuses and writes nothing).
    `PlansViewModelTests.buyingMovesAPlanToCompleted` and
    `anEntryWithNoPlanIsOnNeitherSide` (G10). On screen:
    `testAnActiveRowsBuySwipeMovesThePlanToCompleted`, and the seeded Nikon
    FM2 (bought, no plan) absent from both sides in
    `testThePlansTabSitsFourthAndOpensOnActiveEveryLaunch`.
4. [x] Wanted items that already have a selection or a sold-toward history
   when this ships appear as plans, without anyone re-creating them — on
   Completed if already bought, by their sold-toward history alone.
    *Verified by*: `SellPlanStoreTests.theCarryOverPlansEachRowWithASelectionOrASoldTowardHistoryDatedNow`,
    `theCarryOverLeavesRowsWithNothingToCarryPlanless`,
    `theCarryOverLeavesAllSixRowsChecked` and
    `aSecondCarryOverMakesNoPlanAndChangesNothing` (G7, six rows in one
    store — bought-with-a-sale planned, bought-with-neither not; mutations:
    only the selection counted → the sold-only and bought legs red; only
    planned rows stamped → the all-six-checked leg red), with
    `runCarryOverSavesThePlansItMakes`; the trigger by `SyncMonitorTests`'
    `anInMemoryStoreSettlesOnceAtLaunch`, `aSuccessfulImportSettlesBeforeItIsCounted`,
    `aFinishedFailedSetupSettlesOnce`, `aFailedImportAfterAGoodSetupNeverSettles`
    and `exportsAndInFlightEventsNeverSettle` (G8); and
    `UITestSeedTests.oneCarryOverOverThePlansSeedLeavesThreeActiveOneCompletedTwoPlanless`
    (G9). **The launch wiring's only automated coverage** is the Fuji leg of
    `testThePlansTabSitsFourthAndOpensOnActiveEveryLaunch` — a seeded
    pre-`009` row arriving on Active — which went red both with the
    `onSettled` closure dropped and with the seeds moved below the monitor
    (T014). On the device (T015), an **upgrade in place from `main`**: a
    selection → Active "1 item set aside"; a sale toward it → Active "1 sold
    toward it"; bought with a sale → Completed, "1 was sold toward it";
    bought with neither → neither; nothing → neither; the probe counting 3
    plans made of 5 unchecked rows on the upgrade launch and 0 on every
    relaunch. **Stated plainly**: both simulators were signed out, so the
    carry-over ran on the signed-out path; the iCloud path (after the first
    successful import) is unit-tested at the trigger, and its timing against
    real synced data is sync untested — gathered in `specs/SYNC-CHECKS.md`
    for one later pass, with plan Q2's three windows.
5. [x] The Plans tab sits fourth in the tab bar, opens on Active at every
   launch, and each side keeps its own sort selection across visits within a
   launch.
    *Verified by*: `AppRouterTests.plansIsTheFourthAndLastTab`,
    `PlansViewModelTests.aFreshViewModelOpensOnActiveWithBothSortsNewest` and
    `eachSideKeepsItsOwnSortAcrossShow` (G11; mutation: one shared sort for
    both sides → red), `TabIconTests.theFourIconsAreFourDifferentMarks` and
    `theAssetIsTemplateRendered` (G20). On screen:
    `testThePlansTabSitsFourthAndOpensOnActiveEveryLaunch` (tab buttons in
    ascending `minX` Overview/Items/Wishlist/Plans; the switch reads Active;
    terminate, relaunch → Active again) and
    `testSortingEachSideReordersTheRowsAndIsKeptAcrossASwitch`. On the
    device: the icon beside the other three in both appearances —
    **observed to carry about half the visual weight of the other three**
    (an 18.5 × 6.7 pt mark, drawn as planned; Decision 8 leaves it
    revisitable).
6. [x] Each side offers its own sort options, applied to the rows on screen,
   with the most recent plan first by default.
    *Verified by*: `PlansViewModelTests.theActiveSortsOrderTheActiveRows`,
    `theCompletedSortsReadTheDateBought`, `settingTheActiveSortReordersTheRowsOnScreen`,
    `settingTheCompletedSortReordersTheRowsOnScreen`,
    `aTieFallsTheWishlistOrderWayNotTheNameWay` and
    `aFreshViewModelOpensOnActiveWithBothSortsNewest` (G11 — two fixtures
    in which every order differs from every other; mutations: a comparator
    reversed; the bought date read as the plan date; the tie broken by name;
    the Completed Name comparator dropped, which the Phase 2 review found
    **green** until the fixture's wishlist positions stopped matching its
    name order — each red), and `PlansWiringTests.noSortDropdownOffersAManualOrder`
    (P5: the manual order is an order here, never editable). On screen:
    `testSortingEachSideReordersTheRowsAndIsKeptAcrossASwitch`.
7. [x] A row shows the wanted item's name and category, the count set aside
   when there is one, the count sold toward it when there is one, and nothing
   where a count would be zero. An active row shows its thumbnail (or the
   reserved placeholder, as a wishlist row does); a completed row has no
   picture and no picture slot. *(Revised by Amendment A, criterion 20.)*
    **Ticked as criterion 20 revised it** — every row on both sides has one
    picture slot. *Verified by*: `SellPlanSummaryTests.anActiveRowHasALineOnlyForANonZeroCount`
    and `aCompletedRowLeadsWithTheBoughtDate` (G4; mutation: `setAside(0)`
    emitted → red), `PlansViewModelTests.eachRowsLinesAreItsSummarysRowLines`
    (G10), and `PlansWiringTests.theRowDrawsItsLinesAndAThumbnailOnEveryRow`
    (G31 — `RowThumbnail(photos: row.photos)` exactly once, in no `if`, and
    no `SellPlanCopy` count function composed in the view; mutations: the
    thumbnail under `if !row.isCompleted` → red; `RowThumbnail(photos: [])`
    → red; `SellPlanCopy.setAside(` in place of `row.lines` → red). Which
    picture each side draws is criterion 20's. On screen: Vox's row reads
    "1 sold toward it" in `testThePlansTabSitsFourthAndOpensOnActiveEveryLaunch`.
    On the device (T015): every Plans screen in both appearances.
8. [x] A row shows the covered marker exactly when the sales alone have
   reached the estimated cost — never with no estimate, and never counting
   what is merely set aside — and no row anywhere on this screen shows a money
   figure, a target, a total raised, or a remaining-to-go.
    *Verified by*: `SellPlanSummaryTests.salesExactlyAtTheEstimateAreCovered`,
    `salesADollarShortAreNotCovered`, `noEstimateIsNeverCovered`,
    `aSelectionOverSalesShortOfTheEstimateIsNotCovered` (the fixture on which
    `SellPlanViewModel.selectedValueMeetsCost` reads **true**),
    `aValueOverTheEstimateWithASaleUnderItIsNotCovered` (Decision 10),
    `anActiveRowSaysCoveredLastAndOnlyWhenCovered` and
    `theCountAndTheSumAgreeWithTheSellPlanScreen` (G4; mutations: `>` for
    `>=`; the zero-estimate guard dropped; the selection's value added;
    `currentValueCents` summed — each red). The money half: `PlanRow`
    declares no money field, and `PlansWiringTests.theScreenDrawsNoMoneyAndReachesNoStore`
    (no `formattedAsWholeCurrency`, no `.currency(`, no `Cents` in
    `PlansView.swift`; mutations: each added to the row → red).
    **Stated plainly**: that scan pins spellings, so a figure formatted some
    other way would pass it, and since Amendment A a row's `Photo` reaches
    an `Item` and its prices — the scan, not the row's type, is what keeps
    money off the row (plan QA2). On screen: Vox reads "Covered" and the
    Hasselblad (sales short of its estimate) does not. On the device (T015):
    Covered shown with no money anywhere on the row.
9. [x] Tapping an active row opens that wanted item's existing Sell Plan
   screen exactly as it works today. Tapping a completed row opens the plan as a
   record — what sold toward it and when it was bought — offering no candidate,
   no selection, no sale, no purchase, and nothing that can change it except
   deleting it.
    *Verified by*: `SellPlanRecordTests.aBoughtEntrysPlanIsARecordWithNoPool`,
    `toggleOnACompletedPlanWritesNothing`, `markSoldOnACompletedPlanWritesNothing`
    and `anActivePlanOffersThePurchaseAndTheDelete` (G14, second context;
    mutations: the `toggle` guard dropped; the pool built for a bought entry;
    `markSold`'s guard dropped — each red);
    `SellPlanWiringTests.aBoughtPlanOpensAsARecordThatComposesNothingThatActs`
    (no candidate list, row, figures, sale or purchase in `record(for:)`, and
    no generic control; mutations: `viewModel.toggle` or `SellPlanRow(` put
    in → red) and `WishlistPurchaseWiringTests.theSellPlanOffersMarkAsBoughtOnlyWhileItsEntryIsStillThere`,
    **rewritten** to the `offersPurchase` gate (`015`'s G18): Buy gated back
    on `wishlistItem != nil` → the old guard **green**, the new one red.
    `MenuPolicyTests` green unedited, and red with a real `Menu` planted in
    `record(for:)`. On screen: `testACompletedPlanOpensAsARecord` (no Buy, no
    "Sell candidates", the NT1-A sold row, "Bought", and in the bar Delete and
    nothing else but Back). On the device (T015): an active row opens the
    live Sell Plan; the record in both appearances; the lone Delete with no
    stray gap before it.
10. [x] Deleting a plan, on either side, changes no item anywhere in the app:
    nothing is created, removed, unsold, or repriced, and gear that was set
    aside is simply owned again.
    *Verified by*: `SellPlanStoreTests.deletingAnActivePlanTakesThePlanAndSelectionAndNothingElse`
    and `deletingACompletedPlanLeavesThePurchaseAndTheHistory` (G6, G27 —
    every `Item`'s sale date, sale price, value, desire and count identical
    on a second context, `itemsSoldToward` the same ids, the purchase record
    untouched; mutations: `itemsSoldToward` cleared; the selection kept; one
    item's sale cleared; the entry deleted; `boughtItem` cleared — each red),
    `SellPlanRecordTests.deletingAnActivePlanChangesNoItem` and
    `deletingACompletedPlanChangesNoItem` (G14) and
    `PlansViewModelTests.deletingAnActivePlanLeavesTheEntryAndItsSales`. On
    screen: `testDeletingAPlanLeavesTheWantedItemAndTheSale` (the Items
    tab's Sold side still lists Blues Junior). On the device (T015): the
    wanted item and its sales survive a plan's delete.
11. [x] Deleting an active plan leaves the wanted item on the wishlist with no
    plan; deleting a completed plan leaves the purchased item in the collection
    untouched. A plan can be deleted from its row and from its own screen, and
    both say what will happen before it happens; neither can be undone.
    *Verified by*: the outcomes as criterion 10's, with
    `PlansViewModelTests.anOrphanIsOnCompletedAndDeletingItsPlanTakesItOff`
    (the entry stays in the store); the words by
    `SellPlanCopyTests.theDeleteConfirmationsWords` and
    `theTwoDeleteMessagesDifferInExactlyOneSentence` (G3; mutation: a shared
    sentence reworded in one branch → red, even with the literal test edited
    to match); the two hosts by `PlansWiringTests.theTrailingSwipeStagesTheDeletionAndNamesNoPurchase`,
    `SellPlanWiringTests.theDeleteIsARedButtonOfItsOwnApartFromBuyOfferedOnlyWhileThereIsAPlan`
    and `confirmingTheDeletePopsTheScreenOnlyOnceItTook` (mutation:
    `dismiss()` outside the `deletePlan()` branch → red). On screen:
    `testDeletingAPlanLeavesTheWantedItemAndTheSale` (the alert's title,
    Delete, the row gone; Vox on the Wishlist, its page offering **Create a
    sell plan**). **Guarded by no automated test, said plainly**: which clause
    each host passes to `deleteMessage(isCompleted:)`. The device pass read
    both alerts' text on both sides (T015). The probe in
    `SellPlanStore.delete` counted: swipe opened and closed 0, the row's
    alert Keep 0, Delete 1; the Sell Plan's Keep 0. No path restores a
    deleted plan, and both alerts say "This can't be undone."
12. [x] The record of what sold toward a want survives deleting its plan, and
    a plan created for that want afterwards still shows that history — and a
    deleted plan does not come back on its own.
    *Verified by*: G6's `itemsSoldToward` leg (the same ids, in the same
    number, after the delete), `SellPlanStoreTests.theCarryOverNeverResurrectsADeletedPlan`
    and `deletingOnAnUncheckedRowLeavesItCheckedSoTheCarryOverMakesNoPlan`
    (G7; mutation: delete's nil-stamp dropped → the unchecked leg red), and
    `SettingsDeleteAllSellPlansTests.confirmRemovesEveryPlanAndNothingElse`,
    whose carry-over after Delete all is asserted per removed row. **G7's
    resurrection mutation was re-run against the finished tree at T016**,
    since T003 wrote it before any host existed. With the fetch's checked
    filter dropped (T003's own mutation), the same three `SellPlanStoreTests`
    legs went red as then and nothing else did — `awaitsCarryOver`'s own
    check still keeps the plan away. With **both** layers dropped — a real
    resurrection — 7 tests in three suites went red (13 issues), now
    including the Delete-all host's no-carry-over leg
    (`SettingsViewModelTests.swift:1620`) and the two seed tests. That a new
    plan shows the history is the Sell Plan screen's Sold section reading
    `itemsSoldToward`, unchanged since `006`, over G6's kept record — no test
    creates a second plan and reads its Sold section; the person walked it at
    the Phase 3 pause. On the device (T015): 0 plans made on every relaunch,
    including after Delete all.
13. [x] An orphaned completed plan — the one a hand-corrected purchase leaves
    behind — is visible on the Completed side and can be taken off it by
    deleting the plan.
    *Verified by*: `PlansViewModelTests.anOrphanIsOnCompletedAndDeletingItsPlanTakesItOff`
    (bought with a plan, its created item deleted: on Completed, then off it
    once its plan is deleted, the entry still in the store — P4) and
    `WishlistPurchaseStoreTests.deletingTheBoughtItemLeavesTheEntryBoughtAndPlannedWithNoRecord`
    (G26; mutation: `.cascade` on the item's end → the entry-present leg
    red). On the device (T015): deleting the bought item left the row on
    Completed with the placeholder, and the probe counted 0 plan deletes.
14. [x] **Mark as bought…** from an active row opens the same sheet, seeded
    the same way, as the three hosts `015` built; confirming moves the row to
    Completed, and cancelling changes nothing at all.
    *Verified by*: `WishlistDetailViewModelTests.everyHostSeedsThePurchaseSheetIdentically`,
    `everyHostRefusesToBuyAnEntryTwice` and
    `aPurchaseThroughAnyHostLandsIdentically`, extended to the fourth host
    (G13; mutation: `?? 0` in the fourth seed → red),
    `PlansViewModelTests.buyingMovesAPlanToCompleted`,
    `PlansWiringTests.theBuySwipeIsTheLeadingBlockOnActiveRowsOnly` and
    `thePurchaseSheetIsHostedOnceAndCancelClearsTheStaging` (G19; mutations:
    Buy outside the Active gate → red; the cancel closure emptied → red), and
    `WishlistPurchaseWiringTests.everyPurchaseHostShowsTheRefusalAlert` with
    `PlansView.swift` among its hosts. On screen:
    `testAnActiveRowsBuySwipeMovesThePlanToCompleted` (a partial drag,
    "Mark as bought…" matched alone, the price reading 2400; Cancel → still
    Active; confirm → gone from Active, on Completed).
15. [x] The Dashboard shows a card counting active sell plans that opens the
    Plans tab on Active; it is absent when there are none, absent on the
    first-run Dashboard before anything is owned, and does not appear inside a
    category drill-down.
    *Verified by*: `DashboardPlansCardTests.theCountExcludesCompletedAndPlanlessEntries`,
    `noCardWithNoActivePlans`, `noCardInsideACategoryScope` and
    `settledCountFollowsTheMonitor` (G15; mutations: `boughtDate == nil`
    dropped; `scope.isEmpty` dropped — each red), `AppRouterTests.showingActivePlansSwitchesTabsPopsAndRaisesTheFlag`
    and `thePlansRequestIsClearedOnceApplied`, and
    `DashboardWiringTests.thePlansCardIsComposedOnceBehindItsGateAndOnlyOffTheFirstRunState`,
    `tappingThePlansCardAsksTheRouterForActivePlans` and
    `theDashboardReloadsWhenTheStoreSettles` (G21; mutations: the card out
    of its gate; moved above the empty/scroll split; a second card in the
    first-run branch; `showSoldItems()` for the action; the `settledCount`
    reload dropped — each red). On screen:
    `testTheDashboardCardOpensThePlansTabOnActive` (left on Completed, the
    card reads "3 active sell plans", the tap lands on Active). On the
    device (T015): the card lands on Active, and read "2 active sell plans"
    over the upgraded store.
16. [x] Each of the four empty states says something true about what is
    missing, rather than a blank screen or the wrong diagnosis.
    *Verified by*: `PlansViewModelTests.anEmptyWishlistReadsNothingWantedAndNothingCompleted`,
    `aPlanlessWishlistReadsNoPlans`, `aSideWithRowsHasNoEmptyReason`,
    `stillSyncingOutranksEveryOtherReasonWhileImporting` and
    `anEntryAwaitingTheCarryOverReadsStillSyncingWhenNotImporting` (G12;
    mutations: `stillSyncing` below `noPlans`; the awaiting check dropped —
    each red), with `SellPlanCopyTests.theEmptyStatesWords` for the words.
    On screen: the two Delete-all legs of
    `testDeletingAllSellPlansLeavesEverythingElse` ("No sell plans yet",
    "Nothing completed yet"). On the device (T015): every Plans screen in
    both appearances. **Not observed**: the offline
    "Catching up with iCloud" while a plan awaits the carry-over — sync
    untested, gathered in `specs/SYNC-CHECKS.md` for one later pass; the
    unit test above is its witness. One known wrinkle, accepted at plan
    sign-off (R7): on a `.localOnly` launch of a pre-`009` store the same
    line can show for that one launch although nothing is syncing.
17. [ ] That a plan exists survives a relaunch and syncs; the schema still
    validates against CloudKit.
    **Unticked — sync untested, gathered in `specs/SYNC-CHECKS.md` for one
    later pass.** *Verified*: the schema by
    `CloudKitSchemaTests.schemaMeetsCloudKitRequirements` and
    `TwoStoreContainerTests.theProductionPairingLoadsAndSplits`, both red
    with `@Attribute(.unique)` on `sellPlanCreatedAt` (G1, T001, error
    134060); the fields by `WishlistSellPlanFieldTests.aFreshEntryIsPlanlessAndChecked`
    and `aDateMakesItAPlan` (G2); persistence by every store test's
    second-context refetch, and on the device (T015) by a **relaunch on the
    persistent store** and by two **upgrades in place** — from `main`, and
    from this branch's Phase 4 build — each launching over its old store with
    the new fields read as the plan and migration claims say (plan §1's
    "a pre-009 row reads unchecked" held: the upgrade launch carried 3 plans
    of 5 unchecked rows). VoiceOver over the rows, the switch, the card, the
    Sell Plan's Delete and the Plans "…": done by the person, 2026-09-23.
    **What has not been done**: a plan created, sold through, deleted and
    carried over on one device and seen on another, and plan Q2's three
    windows — a signed-in device launched offline, a device returning after
    a long absence, and which write survives when a carried row meets a
    deletion made elsewhere. No agent can run them and the person has not
    yet.
18. [x] Exports and import are unchanged in shape: no new column in either
    format, no plan in any export, and today's files parse exactly as they do
    now.
    *Verified by*: `ExportSchemaTests` and `ImportSchemaTests` green
    **unedited** at every task that touched the schema (T001, T017 — G23,
    G38), `headerListsMatchThePinnedSchema` among them, so no column was
    added and there is nothing new to parse. That no plan reaches an export
    is evidenced by the **diff**: no file under `Trove/Export/`,
    `Trove/Import/` or `Trove/Models/ExportSchema.swift` is in it, and
    `ItemExportRecord`/`WishlistExportRecord` read named fields rather than
    the model's properties (plan QA1).
19. [x] Nothing in this feature opens a network connection.
    **Ticked by inspection, and the inspection is the honest ceiling here.**
    No test in this project can catch this being false without being a broad
    noun-scan over the source — the shape `CLAUDE.md` names as having gone
    vacuous (the seven-noun policy scan whose table could be deleted while it
    stayed green, and `014`'s menu-row guard that `.init(` kept green) — and
    a scan pins a spelling, not a behaviour. What can be said precisely, from
    `git diff main...HEAD`: no file under `Trove/Market/` or `Trove/Photos/`
    is in it; no added line names `URLSession`, `URLRequest`,
    `ReverbService` or `WikimediaService` (the only `http` in it is the tab
    icon's SVG namespace); no new service type exists; the new view models
    take a `ModelContext`, a `SyncMonitor` and a clock, nothing that could
    carry a connection; and `PRIVACY.md` is not in the diff. The device pass
    adds the observation, not the proof.

## Decisions record

Made by the person, 2026-09-21, in this spec session:

1. **A plan is a statement of intent, not a selection.** The person's words:
   "a sell plan should not rely on having specific items selected. It's simply
   a statement of intent to purchase a wishlist item and is created when
   selecting 'Create a sell plan' on a wishlist item." Active until the wanted
   item is bought. This is what resolves both failures of the inferred
   definition — the plan that never ends, and the plan that ends the moment it
   succeeds.
2. **The candidate pool stays dynamic and keeps suggesting.** "If you've sold
   everything on the sell plan, there should be more items suggested, if
   applicable… the sell plan should always dynamically suggest items to sell
   based on the criteria." This is how the Sell Plan already works and is
   recorded because it constrains the definition above: the plan cannot be the
   pool, and the pool cannot be the plan.
3. **A plan can be deleted**, like anything else in the app.
4. **Both a Dashboard card and a fourth tab**, because **"sell plans are a
   first class citizen, like owned items and wishlist items."** That sentence
   is the reasoning, and it meets the roadmap's objection on its own terms
   rather than setting it aside: the roadmap held that a tab should be a
   distinct place to be and not a filtered slice of data reachable elsewhere,
   and the answer is that a plan is not a slice of the wishlist at all. It is
   its own kind of thing — a want on one tab, the gear that would fund it on
   another, and an intent that spans them and lives on neither. The two
   existing content tabs are the app's two first-class records; this is the
   third. It does **not** overturn `001`, which left the fourth slot empty with
   the instruction to fill it when a real feature needed it.
5. **Counts, not money figures.** The standing refusal from `003`, held again
   by `015`, holds here. Said when the alternative was offered and declined
   for now: a completed plan could say what it raised without naming a target,
   and does not.
6. **Sorting with options**, most recent first by default, with custom,
   alphabetical and date ordering among them.
7. **Mark as bought… is offered from this screen too** — "the point of the
   sell plan is to complete it by purchasing the item."
8. **No design pass for the fourth tab's icon**, "at the moment anyways."
9. **Deleting a sell plan deletes only the sell plan.** "Sold items should be
   items that are sold. Nothing more." The same rule on both sides: no item is
   created, removed or altered by deleting a plan, and nothing is unsold. This
   replaces the Draft's proposal that deleting a completed plan should also
   remove the bought entry behind it — see P4 for what that leaves.
10. **A sale's figure is the price it actually sold for**, not the value the
    item carried while it was owned. "Once an item is sold and updated as such,
    that should be reflected in the sell plan, since it will be reflected in
    the sold item itself." Already true of the Sell Plan's Sold figure, and
    recorded here because it is what settles P8: a judgement built on prices
    actually received is a different claim from one built partly on estimates
    of what unsold gear might fetch.

Made by the person, 2026-09-22, answering the two contradictions planning
found between this spec and the code:

11. *(Revised by Amendment A, Decision 16 — completed rows show a picture.)*
    **Completed rows have no picture slot at all.** Planning found a completed
    row cannot show the wanted item's picture: `015` moves the photos to the
    bought item, and keeps no link back. The planned answer was the empty
    placeholder; the person rejected it — "if it goes from having an image to
    not having an image and showing an empty placeholder, that's not good.
    Either keep the image or remove the image placeholder entirely." Removing
    it was chosen (the choice left to Claude Code) because keeping the image
    cannot be done reliably: a plan completed before this spec has no way back
    to its photos, and one after it would lose its picture again whenever the
    bought item was sold or deleted — the same effect, deferred.
12. **No Plans card on the first-run Dashboard**, "whatever is the most
    streamlined and intuitive for the user" (the choice left to Claude Code):
    the Sold card's rule, since that screen exists to get the first item
    added and the tab bar already carries the Plans tab.

## Proposals (P-items)

Claude Code's, becoming decisions on plan approval unless the person
overturns them. **Decisions since the plan's approval on 2026-09-22**, as
`002`'s, `005`'s, `006`'s and `015`'s did; none was overturned. Two were
built differently from their first shape, each at the person's word and each
recorded where it happened: P11's placement on the plan's own screen is
**Delete as a button of its own**, not a "…" (Decision 13, plan Q12 as
amended), and P2's rows gained a **picture on the Completed side too**
(Decision 16). P1's labels, P5's sort options, P8's covered rule, P9's
fallback and P12's read-only record shipped as written; the strings are in
**Copy** above.

- **P1 — Two sides, not a menu option.** The person offered either; this takes
  the Items tab's Owned/Sold shape, because `014` already built it, already
  settled that each side keeps its own sort, and a second idiom for the same
  job would be a third answer to "how do you switch halves of a list."
  Labels **Active** and **Completed**; the tab is **Plans**.
- **P2 — Row content** as listed above, and nothing else. In particular, no
  ranking preview and no candidate list on the row: the Sell Plan screen is one
  tap away and is where the pool belongs.
- **P3 — What "the plan" is, for deletion.** The stored plan and the current
  selection go; the **sold-toward record stays**. Decision 9 settles that no
  item is touched, and this settles the one thing inside the plan that is not
  an item: the link saying these sales were made toward this want. It stays
  because it is a record of something that really happened, because `006` made
  it survivable on purpose, and because keeping it means a new plan for the
  same want later still knows what you already sold.
- **P4 — Deleting a completed plan removes the plan, not the bought entry**
  (Decision 9). The consequence to be clear about: the entry itself then sits
  in the store with no plan, in no list, no count, no export and no screen —
  exactly as inert as `015` left it, and no longer surfacing here. So an
  orphan can be taken off this list but its underlying row is never removed.
  That is the cost of the rule, and it is cheaper than the alternative, which
  was to delete a record `015` kept on purpose on a guess about which
  purchases were real.
- **P5 — Sort options per side.** Active: date created (newest first, the
  default), date created oldest first, name, and the wishlist's own manual
  order. Completed: date bought (newest first, the default), date bought
  oldest first, and name. The manual order is offered as an *order* only — it
  belongs to the Wishlist and is not editable from here, so the sort picker's
  reorder affordance does not appear on this screen.
- **P6 — The Dashboard card** is absent at zero and appears on the root
  Dashboard only.
- **P7 — No export or import change of any kind**, as `015` made none.
- **P8 — The covered marker reads the sales alone**, not the sales plus the
  current selection, and Decision 10 is what picks it. The app's existing
  boolean on the Sell Plan screen includes the selection, so it is part real
  money and part estimate — an answer to "would this plan pencil out," on a
  screen where the estimates are visible beside it and can be judged. A row on
  a list has no such context, so the only claim it can make honestly is the one
  built entirely on prices actually received: **the money is already raised.**
  The two cues live side by side, mean different things, and each belongs where
  it is.
- **P9 — The wanted item's entry point gains a create state**, and its second
  line falls back from the set-aside count to the sold count to a "nothing set
  aside yet" line, so a plan never reads as "0 items". This is a third
  change to merged code on that page — `001` built it, `015` T012c retouched
  it at the person's instruction, and this spec changes what its two states
  mean — and is recorded as a scope addition rather than as drift.
- **P10 — Existing wanted items with a selection or a sold-toward history
  read as having a plan.** How that is arranged is `plan.md`'s to settle; that
  nobody has to re-make a plan they already made is this spec's requirement.
- **P11 — Delete from the plan's own screen as well as its row**, because the
  person asked for plans to be deleted "just like any other item," and every
  item and wanted item in the app can be deleted from its list and from its own
  page. Placement follows `013`'s rule; `plan.md` settles it.
- **P12 — A completed plan opens read-only.** Follows from Decision 1 — a plan
  ends at the purchase — and from `015`, which released the selection at the
  purchase and allows no undo. Recorded as a proposal rather than a decision
  because the person never saw the question: no path had ever opened a bought
  entry's plan, so it did not exist until this screen made one.

## Non-goals (explicit)

- **Any money figure on this screen** — no total raised, no remaining, no
  target, no percentage, on either side (Decision 5). `003` refused it, `015`
  held the line, and a list is not a reason to reverse it.
- **Reopening a completed plan**, or any way to resume working on it (P12).
- **A second manual order.** The Wishlist owns the custom order; this screen
  can sort by it and cannot edit it.
- **Changing how the Sell Plan screen ranks, selects, or shows anything.**
  This spec changes what a plan *is* and gives plans a list; the screen itself
  is unchanged apart from the entry point that leads to it.
- **Any change to the purchase sheet or to what buying does** (`015`). This
  screen is a fourth host for an existing sheet.
- **Undoing a purchase** (`015` Decision 5). Deleting a completed plan removes
  the plan's record, never the item.
- **Automatically detecting or sweeping orphaned entries** (P4), and
  **removing the bought entry behind a deleted completed plan** (Decision 9).
- **Unselling, repricing, or otherwise altering any item as a side effect of
  deleting a plan** (Decision 9).
- **Surfacing bought entries anywhere else** — no Bought side on the Wishlist,
  no export, no Dashboard figure. `015` Decision 1 stands; this screen is the
  one surface they get.
- **A plan for something that is not on the wishlist.** A plan is a wanted
  item's plan.
- **Multiple plans for one wanted item**, or a plan spanning several wants.
- **Notifications, reminders, or any prompt about a plan's age.**
- **A designed tab icon** (Decision 8) — drawn to match, revisitable.
- **Charting plans over time** — `016-collection-value-history`'s territory.

## Inherited caveats

- `001`'s fixed type sizes apply — every font on this screen is fixed-size
  like the rest of the app, until `017-dynamic-type`. The roadmap already
  notes that this screen's card rows will be built at fixed sizes and then
  revisited there.
- `001`'s USD-only rule applies.
- `013` Amendment A's "bespoke in the page, system in the bars" rule places
  every control on this screen, and `MenuPolicyTests` enforces it — until
  `018-system-design-language` revisits the rule itself.
- `015`'s two-device sync check remains the person's step; this spec adds a
  synced property and inherits the same limit.

## Open questions

**None.** The four the first Draft carried were answered in the same session:

1. **The fourth tab's reasoning** — answered, and it is now Decision 4's first
   sentence rather than a gloss of mine.
2. **Deleting a completed plan** — the proposal was overturned. Decision 9
   replaced it with one rule for both sides, and P4 states what that leaves.
3. **The covered marker** — settled by Decision 10 rather than by picking one
   of the two options: a figure built on prices actually received is the only
   one a row can state without its context, which is P8.
4. **The labels** — Plans, Active and Completed, left to Claude Code and kept.
   One word per tab, as the three existing tabs are, and the two sides named
   for the lifecycle Decision 1 defines rather than for what is on them.

What remains before implementation is the ordinary gate: the `sdd-planner`
drafts `plan.md` and `tasks.md` against this spec, and the `skeptical-reviewer`
signs them off.

## Amendment A — the walkthroughs (2026-09-23)

Decided by the person at the Phase 3 and Phase 4 walkthroughs; each is
recorded in `tasks.md` against the task that carries it.

### Decisions

13. **Delete on the Sell Plan screen is its own button, separate from Buy**
    — "the delete button under the ... is fine if there are more items
    beneath the ... but there aren't … I'd just have two separate buttons:
    Buy and Delete at the top right." (T009b)
14. **A destructive action is always drawn red, as a standard** — "This needs
    to be implemented as standards across the app so that I don't have to
    manually point it out every time." Red is the app's rust wherever the app
    draws the control; the system's red where the system does. (T009d; now in
    `CLAUDE.md` and `design/tokens.md`.)
15. **A card, row or chip responds anywhere in its box** — "tapping anywhere in
    the item box marks or unmarks", then, for the Overview's callout and the
    category chips, "Fix it now." (T009c, T014a; in `design/tokens.md`.)
16. **Completed rows show a picture** — revising Decision 11. "Why can't the
    complete sale plan show the same image as from the active plan? I think
    that makes sense to do." From this amendment on, marking an item bought
    records which item it became, and a completed row shows that item's
    picture. A plan completed before this amendment has no such record and
    shows the empty placeholder — the same slot every Active row keeps — so
    every row on both sides has one shape again.
17. **Every tab reaches Settings from its "…"** — "There should always be a
    way to get to the settings menu." The Plans tab gains the "…" the other
    tabs have, holding Settings.
18. **Settings can delete all sell plans** — "There should be a setting to
    delete all plans." It removes every plan, active and completed, after a
    confirmation that says how many; it touches nothing else — wanted items,
    owned items, sales and the sold-toward record stay exactly as a single
    delete leaves them (Decision 9). The row is dimmed when there are no
    plans, drawn in rust (Decision 14).

### Acceptance criteria

Verified at T016 as criteria 1–19 were (the preamble above). Criteria 20
and 22 stay **unticked** for their sync halves, as 17 does; 21 and 23 are
ticked.

20. [ ] Every row on both sides of the Plans tab has a picture slot. An active
    row shows the wanted item's picture or the placeholder; a completed row
    shows the picture of the item the purchase created, when the purchase
    recorded it and that item still has one, and the placeholder otherwise.
    A purchase made from any of the four hosts records the item it became.
    **Unticked — sync untested, gathered in `specs/SYNC-CHECKS.md` for one
    later pass** (a purchase on one device showing its picture on the
    other's Completed row). *Verified on one device*: which picture each row
    carries by `PlansViewModelTests.anActiveRowShowsItsEntrysPhotosAndACompletedRowItsBoughtItems`,
    `aCompletedRowWhoseBoughtItemWasDeletedHasNoPicture` and
    `aCompletedRowWithNoPurchaseRecordHasNoPicture` (G30 — each with a
    photo attached to the wanted entry **after** the purchase, which the row
    must not show; mutations: completed rows reading `wanted.photos` → red,
    **and the deleted `showsThumbnail` guard passed that one**; the
    `?? wanted.photos` fallback → the two late-photo legs red; active rows
    reading `boughtItem` → red; photos only while unsold → the sold leg
    red); that the view draws them on every row by
    `PlansWiringTests.theRowDrawsItsLinesAndAThumbnailOnEveryRow` (G31);
    the record by `WishlistPurchaseStoreTests.thePurchaseRecordsTheItemItBecameOnBothEnds`,
    `aRefusedSecondPurchaseLeavesTheRecordOnTheFirstItem`,
    `deletingTheBoughtItemLeavesTheEntryBoughtAndPlannedWithNoRecord`,
    `sellingTheBoughtItemLeavesTheRecordIntact` and
    `deletingTheBoughtEntryLeavesTheItemAndItsPhotos` (G25, G26, second
    context; mutations: the assignment dropped; the purchase also writing
    `soldTowardWishlistItem`; `.cascade` on either end — each red); all four
    hosts by `WishlistDetailViewModelTests.aPurchaseThroughAnyHostLandsIdentically`'s
    absolute per-host leg (G28 — with the assignment dropped it went red once
    per host **while the equality legs stayed green**, which is why the
    absolute leg exists); the seed by
    `UITestSeedTests.thePlansSeedWritesSixWantedItemsInTheirShapes` (G29);
    and a duplicate taking no record by
    `ItemDuplicationTests.sellPlanMembershipIsNotInherited` (G39). On the
    device (T015), the picture's four states on the persistent store: a
    plan completed before the record existed → the placeholder (the second
    upgrade in place, from this branch's Phase 4 build); bought → the photo;
    its item sold → still the photo; its item deleted → the placeholder,
    the row still on Completed.
21. [x] The Plans tab's header has a "…" that opens Settings, and every tab's
    root screen has a way to Settings.
    *Verified by*: `SettingsWiringTests.everyTabsRootReachesSettings` (G32 —
    **derived from the tab list**, not from a list of files: each `Tab(`'s
    root view in `ContentView`, as many as `AppRouter.Tab.allCases`, must
    host an anchored `OverflowBadge(` and a dropdown that raises the sheet;
    mutations: the Plans badge replaced by a `Button`; `PlansView` out of
    `settingsHosts`; the Plans root swapped for `SellPlanView` (6 issues);
    the row toggling instead of raising — each red), the parameterized
    `theScreenAttachesTheSettingsSheetAndReloadsOnDismiss` and
    `eachHostThreadsTheAppearanceStoreIntoSettings` over `PlansView.swift`
    (mutation: the sheet's reload dropped → red), and
    `DropdownWiringTests.everyBadgeCarriesItsHintAndIdentifier` (G33;
    mutation: `moreActions.plans` removed → red). On screen:
    `testEveryTabsRootReachesSettings` — badge, Settings, the bar, Done, on
    all four tabs (mutation: the Plans badge removed → red, "the Plans tab's
    root must have a '…'"). On the device (T015): the Plans "…" with its one
    Settings row over a full and an empty side in both appearances, the
    switch's top at 134.67 pt in every state, and Settings reached from all
    four tabs. VoiceOver over the "…": done by the person, 2026-09-23.
22. [ ] Settings offers "Delete all sell plans" under the existing Delete-all
    rows: dimmed with no plans; with plans, a confirmation naming the count;
    confirming removes every plan, active and completed, and nothing else
    (criteria 10–12 hold for every plan it removed); it is announced as
    destructive and drawn in rust.
    **Unticked — sync untested, gathered in `specs/SYNC-CHECKS.md` for one
    later pass** (Delete all on one device clearing the other, and plan
    RA2's window: a plan made on one device and not yet arrived on the other
    is neither counted nor deleted there). *Verified on one device*:
    `SettingsDeleteAllSellPlansTests.theCountIsTheStoredPlansAndTheRowAwaitingTheCarryOver`
    (4, under RA2(b) as the person answered it),
    `withNoPlansTheRowIsDimmedAndTheRequestStagesNothing`,
    `theRequestReCountsAPlanThatArrivedAfterLoad`,
    `confirmRemovesEveryPlanAndNothingElse` and
    `activityIsSetSynchronouslyAndASecondActionIsRefused` (G35, second
    context — every entry present, every item's sale, value, desire and
    count identical, `itemsSoldToward` the same ids, the purchase record
    identical, every removed row checked and given no plan by a following
    carry-over; mutations: entries deleted instead of plans; completed
    plans skipped; `itemsSoldToward` cleared; the save dropped; the count
    over every entry; `SellPlanStore.delete`'s nil-stamp dropped — each
    red); the words by `DeleteAllCopyTests.theSellPlansTitlesCountAndPluralize`,
    `theSellPlansMessagesNameWhatStaysWhenSyncing`,
    `theSellPlansMessagesOnALocalOnlyStoreLeaveICloudOut` and
    `everyMessageEndsWithNoUndo` (G34); the row by
    `SettingsWiringTests.everyDeleteRowCarriesAnAccessibilityHintAndTheRowAppliesIt`
    and `everyActionRowGatesOnBusyAndReadsItsOwnActivity` (G36 — exactly 3
    destructive rows, 3 hints, 8 action rows; mutations: `isDestructive`,
    the hint and the busy gate each removed → red), with
    `DestructiveColourPolicyTests.everyAppDrawnDestructiveControlIsColouredRust`
    green unedited (the row's rust comes through `SettingsActionRow.color`,
    its pinned exemption). The refused save's rollback is untested, as for
    every Delete All. On screen: `testDeletingAllSellPlansLeavesEverythingElse`
    ("Delete all 4 sell plans?", Keep, then Delete All; both sides empty;
    Summicron, Vox and Fuji still on the Wishlist, Vox offering Create; the
    two sales on the Sold side; the bought Hasselblad on Owned; the row
    dimmed). On the device (T015): the row sampled `accentRustText` in both
    appearances, dimmed with no plans, its alert's text, and the probe in
    `SellPlanStore.delete` counting Keep 0 and Delete All 4. VoiceOver over
    the row with its hint: done by the person, 2026-09-23.
23. [x] The schema still validates against CloudKit with the purchase's new
    record (criterion 17), and exports and import are unchanged in shape
    (criterion 18).
    *Verified by*: G24 — `deleteRule: .deny` on either end of the new pair
    turned `CloudKitSchemaTests.schemaMeetsCloudKitRequirements` and
    `TwoStoreContainerTests.theProductionPairingLoadsAndSplits` red (134060,
    "unsupported delete rules"), and so did removing `inverse:` (SwiftData
    made two one-way links — the plan's feared mis-pairing did not happen;
    QA1 corrected as built); and G38 — `ExportSchemaTests`,
    `ImportSchemaTests`, `PurchaseUndoTests`, `PhotoOwnershipTests`,
    `MenuPolicyTests`, `DestructiveColourPolicyTests`, `SellPlanFramingTests`
    and `PlansWiringTests.theScreenDrawsNoMoneyAndReachesNoStore` all green
    **unedited** at T017. The pair's migration of a store already in the
    field was seen on the device, from `main` and from the Phase 4 build
    (T015). Criterion 17's own sync half is not part of this one's claim.

## Review pass

Run 2026-09-22 at the person's instruction, over the approved Draft, with the
instruction to resolve whatever it found unless something needed them. Nothing
did: every finding below follows from a decision the person had already made.

- **A completed plan opened into a live workbench** (the one real gap). Tapping
  a completed row was specified as opening the Sell Plan screen "exactly as
  that screen shows them today" — which, verified in the code, would have
  offered the ranked pool, the selection, **Mark as sold…**, and a **Mark as
  bought…** that the already-bought guard would refuse. Now P12 and
  criterion 9.
- **The orphan-sweep argument was wrong in its reason, not its conclusion.** It
  said an orphan's only distinguishing signal is that its purchased item no
  longer exists; a bought entry keeps no link to that item at all, so the app
  cannot even check. The conclusion — no sweep — stands on firmer ground.
- **Already-bought entries** needed a carry-over rule: their selections were
  released at purchase, so only sold-toward history can carry them. And a want
  bought with no plan must not surface as a completed one.
- **The covered marker** named "what you expect to pay" without saying which
  figure, and could fire on a zero estimate. It reads the estimate on both
  sides — the only figure a bought entry holds — and is silent with none.
- **"0 items set aside"**: a plan with nothing set aside would have shown it on
  the wanted item's page. P9 now falls back.
- **Delete from the plan's own screen** (P11), from "just like any other item".
- **Smaller**: "each of the four empty states" listed three; the card now says
  which side it opens; the plan exists from the tap, per the person's own
  words; "make a new plan later" was scoped to active plans, since a completed
  plan's entry cannot be planned again; deleting a wanted item's plan with it
  is stated.
- **After planning** (2026-09-22): two things the plan could not build as the
  spec read — a completed row's picture, and the Dashboard card before anything
  is owned — went to the person rather than being settled in `plan.md`, and
  came back as Decisions 11 and 12; criteria 7 and 15 carry them.

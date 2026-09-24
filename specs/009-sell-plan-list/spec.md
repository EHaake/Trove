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

Shapes, not shipped strings — the strings are settled in `plan.md` and
recorded here at close-out, as `015`'s were. Everything below lives in one
copy type and is pinned by literal, never typed inline in a view.

- The tab: **Plans** (P1). One word, as the three existing tabs are.
- The two sides: **Active** and **Completed** (P1).
- The wanted item's entry point, with no plan: **Create a sell plan** over
  today's "Browse your lowest desire-to-keep items". With a plan: today's
  **View your sell plan** over **"<n> item(s) set aside"**, unchanged (P9).
- A row's counts, reusing the wanted page's existing wording: **"<n> item(s)
  set aside"**, and **"<n> sold toward it"**.
- The covered marker: one short word, **Covered** (P8).
- Deleting a plan: **"Delete the sell plan for <name>?"** over a consequence
  sentence naming all three promises, the way `WishlistDeleteCopy` does —
  nothing you own or sold is touched, what sold toward it stays on the record,
  and this can't be undone. Confirm **Delete**, cancel **Keep**, matching
  `010`'s unified verb.
- The two sides differ in **one clause**, because what remains differs: on
  Active the wanted item stays on your wishlist, on Completed the item you
  bought stays in your collection. One string with one varying clause, not two
  sets of copy that can drift — the mistake `WishlistDeleteCopy`'s own doc
  comment records being found at a pre-merge review.
- The Dashboard card: **"<n> active sell plan(s)"**.
- Empty states, four of them, each naming what is actually missing: **no
  plans while things are wanted** (plans start from a wanted item), **nothing
  wanted at all** (the Wishlist is where a plan begins), **nothing completed
  yet** (a plan lands here when its item is bought), and **still syncing**, the
  reason every list screen in the app already has.

There is **no design pass for this spec** (Decision 8), so the wording above
is settled by the plan and corrected by the person at the pauses, as `015`'s
was.

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

1. [ ] A wanted item with no plan offers to **create** one; the plan exists
   from that tap, and it opens the Sell Plan screen with nothing selected and
   no target. With a plan, the entry point never reads "0 items set aside".
2. [ ] A plan stays on the Active side no matter what happens to the
   selection — including after every item on it has been **sold**, which is
   the case `015`'s sweep found reads as no plan at all today.
3. [ ] A plan leaves the Active side and appears on the Completed side when
   the wanted item is marked bought, by any of the four paths that can mark
   it; a wanted item bought with no plan appears on neither.
4. [ ] Wanted items that already have a selection or a sold-toward history
   when this ships appear as plans, without anyone re-creating them — on
   Completed if already bought, by their sold-toward history alone.
5. [ ] The Plans tab sits fourth in the tab bar, opens on Active at every
   launch, and each side keeps its own sort selection across visits within a
   launch.
6. [ ] Each side offers its own sort options, applied to the rows on screen,
   with the most recent plan first by default.
7. [ ] A row shows the wanted item's name and category, the count set aside
   when there is one, the count sold toward it when there is one, and nothing
   where a count would be zero. An active row shows its thumbnail (or the
   reserved placeholder, as a wishlist row does); a completed row has no
   picture and no picture slot. *(Revised by Amendment A, criterion 20.)*
8. [ ] A row shows the covered marker exactly when the sales alone have
   reached the estimated cost — never with no estimate, and never counting
   what is merely set aside — and no row anywhere on this screen shows a money
   figure, a target, a total raised, or a remaining-to-go.
9. [ ] Tapping an active row opens that wanted item's existing Sell Plan
   screen exactly as it works today. Tapping a completed row opens the plan as a
   record — what sold toward it and when it was bought — offering no candidate,
   no selection, no sale, no purchase, and nothing that can change it except
   deleting it.
10. [ ] Deleting a plan, on either side, changes no item anywhere in the app:
    nothing is created, removed, unsold, or repriced, and gear that was set
    aside is simply owned again.
11. [ ] Deleting an active plan leaves the wanted item on the wishlist with no
    plan; deleting a completed plan leaves the purchased item in the collection
    untouched. A plan can be deleted from its row and from its own screen, and
    both say what will happen before it happens; neither can be undone.
12. [ ] The record of what sold toward a want survives deleting its plan, and
    a plan created for that want afterwards still shows that history — and a
    deleted plan does not come back on its own.
13. [ ] An orphaned completed plan — the one a hand-corrected purchase leaves
    behind — is visible on the Completed side and can be taken off it by
    deleting the plan.
14. [ ] **Mark as bought…** from an active row opens the same sheet, seeded
    the same way, as the three hosts `015` built; confirming moves the row to
    Completed, and cancelling changes nothing at all.
15. [ ] The Dashboard shows a card counting active sell plans that opens the
    Plans tab on Active; it is absent when there are none, absent on the
    first-run Dashboard before anything is owned, and does not appear inside a
    category drill-down.
16. [ ] Each of the four empty states says something true about what is
    missing, rather than a blank screen or the wrong diagnosis.
17. [ ] That a plan exists survives a relaunch and syncs; the schema still
    validates against CloudKit.
18. [ ] Exports and import are unchanged in shape: no new column in either
    format, no plan in any export, and today's files parse exactly as they do
    now.
19. [ ] Nothing in this feature opens a network connection.

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
overturns them.

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

20. [ ] Every row on both sides of the Plans tab has a picture slot. An active
    row shows the wanted item's picture or the placeholder; a completed row
    shows the picture of the item the purchase created, when the purchase
    recorded it and that item still has one, and the placeholder otherwise.
    A purchase made from any of the four hosts records the item it became.
21. [ ] The Plans tab's header has a "…" that opens Settings, and every tab's
    root screen has a way to Settings.
22. [ ] Settings offers "Delete all sell plans" under the existing Delete-all
    rows: dimmed with no plans; with plans, a confirmation naming the count;
    confirming removes every plan, active and completed, and nothing else
    (criteria 10–12 hold for every plan it removed); it is announced as
    destructive and drawn in rust.
23. [ ] The schema still validates against CloudKit with the purchase's new
    record (criterion 17), and exports and import are unchanged in shape
    (criterion 18).

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

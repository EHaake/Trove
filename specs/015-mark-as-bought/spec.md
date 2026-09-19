# 015 — Mark as Bought

**Status**: **Draft** (2026-09-19) — written with the person in this spec
session. The Decisions record below holds what they have already settled;
the **P-items** are Claude Code's proposals and become decisions on plan
approval, as `002`'s, `005`'s and `006`'s did. The **Open questions** section
is what the person still has to answer at their reading of this Draft.

Authored in a Claude Code spec session of its own, per `CLAUDE.md`'s model
policy as amended 2026-09-19 (Opus 5, the session raised to high effort for
the spec conversation).

**Depends on**: `001-core-inventory` (`Item`, `WishlistItem`, the wishlist
screen and its rows, the Sell Plan, the custom order), `006-mark-as-sold`
(the sale sheet this spec mirrors, `itemsSoldToward`, and the
Return-to-collection undo whose shape this spec's undo follows),
`010-item-management-enhancements` (the wishlist's leading and trailing
swipes, and the delete confirmation a destructive undo reuses),
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
much in one sentence — over or under what you had guessed (P3). It is a line
of copy, not a figure the app stores or acts on. This is the kind of
observation the app exists to make, and it costs nothing: both numbers are
already on screen.

### What buying does

On confirming the sheet:

- A new **item** is created in the collection, carrying across everything the
  wishlist entry already knew (P4): its **name**, **category path**,
  **photos** with their credits intact (a `005` stock photo keeps its
  photographer, licence and link), its **Reverb product match**, its
  **year**, and its **currency**. Its **notes** carry across too — losing
  typed text is worse than carrying a sentence that is now slightly stale,
  and it is editable like any other field.
- The item's **current value** starts at the purchase price (P5). For
  something bought today those are the same number, and starting it unvalued
  would put a brand-new purchase straight into the Dashboard's un-valued
  count, which is noise rather than a prompt.
- The item's **desire to keep** starts at the ordinary default. The
  wishlist's *desire to own* is a three-level scale about wanting and the
  item's is a five-level scale about keeping; they are different questions
  and mapping one onto the other would invent an answer (P6).
- The item is **appended to the end of the custom order**, as an imported
  item is.
- The **wishlist entry is marked bought** and leaves the Wishlist. It is not
  deleted (Decision 3). It appears nowhere in the app in this spec.
- Its **sell plan is retained and reads as completed**: the items sold toward
  it stay recorded, and the remaining *unsold* candidates are released from
  the plan, since nothing is earmarked toward a purchase that has happened
  (P7). This mirrors `006` P6, which empties the selection at the sale.
- Every Dashboard figure updates as it would for any item added by any other
  route. There is **no Bought card** and no new Dashboard surface
  (Decision 1).

### Undoing a purchase

A purchase marked by mistake can be undone (P8), the way a sale can since
`006`. **Return to wishlist** sits in the bought item's own menu — not as a
button on the page, for the reason above. It restores the wishlist entry at
its old place in the wishlist's custom order, with its sell plan active
again, and **removes the item that the purchase created**.

That last clause is the one real asymmetry with `006`. Returning a sold item
to the collection destroys nothing, because the sale was four fields on a row
that already existed. Returning a bought item to the wishlist has to remove a
row that the purchase brought into being, and by then it may carry photos, a
serial number or notes that were added afterwards. So the undo goes behind
the same confirmation the delete flow uses, and its copy says plainly that
the item record goes away.

**This is the one thing in this Draft the person has not yet settled** — see
Open questions.

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
- **Import is unchanged.** No new column means nothing new to parse (P9).

## Copy

- The action, everywhere it appears: **Mark as bought…**
- The swipe button, where width is short: **Buy**
- Sheet title: **Mark as bought**
- Fields: **Purchase price**, **Purchase date**, **Bought from**, **Condition**
- Confirm button: **Mark as bought**
- The comparison line, under the price field, when a non-zero estimate
  exists and differs:
  - under: **$120 less than you estimated**
  - over: **$85 more than you estimated**
  - equal: the line is absent, not a sentence saying zero.
- The undo action: **Return to wishlist…**
- The undo confirmation title: **Return to wishlist?**
- Its body: **This puts *(name)* back on your wishlist with its sell plan.
  The item and anything added to it since — photos, notes, serial number —
  will be removed from your collection.**
- Its confirm button: **Return to wishlist**

Exact wording is the design pass's to refine; the shape above is what the
spec asserts.

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

1. [ ] A wishlist row's leading swipe offers **Mark as bought…** beside the
   actions already there; the existing action stays nearest the edge so a
   full swipe still does what it did; the trailing swipe is unchanged.
2. [ ] The wishlist detail screen's menu offers **Mark as bought…** beside
   Edit and Delete, and there is **no button** for it on the page.
3. [ ] Each Sell Plan screen offers **Mark as bought…** for the wishlist item
   the plan belongs to.
4. [ ] All three paths open **one sheet**, seeded identically, and cancelling
   any of them changes nothing at all.
5. [ ] The sheet requires a price, a date and a condition, accepts an
   optional location, and pre-fills the price from the estimated cost when
   there is one.
6. [ ] The sheet shows how the entered price compares to the estimate when
   they differ, in words, and shows nothing when they are equal or when there
   is no estimate.
7. [ ] Confirming creates an item carrying the wishlist entry's name,
   category, photos (with a stock photo's credit intact), Reverb match, year,
   currency and notes; its current value equals the purchase price; its
   desire to keep is the default; it sits at the end of the custom order.
8. [ ] The wishlist entry leaves the Wishlist on confirming, and appears
   nowhere else in the app — there is no Bought side, no Bought card, and no
   second copy of the thing in any list.
9. [ ] The wishlist entry is **not deleted**: its record and its sell plan
   survive the purchase, the items sold toward it stay recorded, and the
   remaining unsold candidates are released from the plan.
10. [ ] Every Dashboard figure reflects the new item exactly as it would an
    item added any other way, and the Dashboard grows no new surface.
11. [ ] Buying the last wishlist item leaves the Wishlist in its existing
    empty state, not a broken or blank one.
12. [ ] **Return to wishlist** restores the entry at its old place in the
    wishlist's custom order with its plan active again, removes the item, and
    asks for confirmation first with copy that says the item record goes
    away.
13. [ ] The bought marker survives a relaunch and syncs; the schema still
    validates against CloudKit.
14. [ ] Exports are unchanged in shape: the new item exports as an ordinary
    item in both formats, a bought wishlist entry exports in neither, and
    import parses today's files exactly as it does now.
15. [ ] Nothing in this feature opens a network connection.

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
   entry and dies with it, because deletion would destroy the sold-toward
   history `006` deliberately made survivable, and because an undo is
   impossible once the row is gone.
4. **All three entry points** — the swipe, the detail menu and the Sell Plan
   screen — with the placement details left to Claude Code's judgement.

## Open questions

For the person, at their reading of this Draft:

1. **Does the undo ship in this spec, and in this shape?** P8 proposes
   **Return to wishlist** in the bought item's menu, removing the item behind
   a confirmation. The alternative is **no undo at all**: every path to a
   purchase goes through a sheet that must be confirmed, so an accidental
   *completed* purchase is considerably harder to produce than the mis-tap
   `006`'s Return to collection guards against — and a mistake can still be
   fixed by hand, by deleting the item and re-adding the wishlist entry. The
   argument for shipping it anyway is symmetry with `006` and the fact that
   the marked-bought entry is otherwise unreachable by any means.
2. **Is the comparison line (P3) wanted?** It is the one piece of this spec
   that is an opinion rather than a mechanic.
3. **Should the wishlist entry's notes carry across (P4)?** Proposed yes. A
   note reading "want this in black" is odd on something you now own, but
   losing text someone typed is worse, and it is editable.

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
- **A one-tap purchase** — every path opens the sheet.
- **Buying something that was never on the wishlist.** Adding an item
  directly is what the Items tab has always done; this spec is about the
  wishlist entry's ending, not about a second way to create items.
- **Partial or planned purchases**, deposits, layaway, or a purchase recorded
  as pending.
- **Any change to the sale sheet, the sold side, or `006`'s fields.**
- **Any new CSV column, export document, or import behaviour** (P9).
- **A Dashboard figure for money spent**, purchases over time, or any chart —
  that is `016-collection-value-history`'s territory.
- **Mapping desire-to-own onto desire-to-keep** (P6).
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

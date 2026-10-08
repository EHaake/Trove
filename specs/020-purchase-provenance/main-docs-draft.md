# `020` — text for `main` after the merge

Drafted at T015's close-out (2026-10-06). Apply to `main` once the branch
has merged: `specs/ROADMAP.md`, `DECISIONS.md` and `README.md` are prose
and may be committed straight to `main` (the constitution's documentation
exception). Fill in the merge date where it says `<merge date>`. Nothing
here is live until then.

Two things for whoever applies it. The status row says the pre-merge sweep
is done; it was drafted before the sweep ran, so confirm that clause or
reword it. And section 4 (two `README.md` lines) is not something the
close-out task asked for — it is here because both lines need the merge
date or the word "Shipped", so they could not go on the branch; drop the
section if the README's status paragraph is handled some other way.

---

## `specs/ROADMAP.md`

### 1. The status table — a new last row, after `018-system-design-language`

| `020-purchase-provenance` | **Shipped** — merged to `main` `<merge date>` via [PR #33](https://github.com/EHaake/Trove/pull/33); every task through T015's close-out and the pre-merge sweep done (2026-10-06); fifteen tasks (T001–T015) and one sub-lettered addition (T015a, the pre-merge sweep's fix round) — the two phase-pause findings became spec Decisions 11 and 12 rather than fix tasks, and the device pass found no failure — **1805 unit tests in 236 suites** and **42 UI tests** green after the pre-merge sweep's fix round (1804 at the close-out), and both suites twice back to back after the device pass (the counts are in `tasks.md`). Twenty-seven of twenty-eight criteria verified with per-criterion records in `spec.md`; **one honest partial named**: criterion 27 (Bought, Looking for and Very Good reaching a second signed-in device) stays unticked until `specs/SYNC-CHECKS.md` steps 3.11 and 3.12 are run, and with it the half of P4 no test here can reach — whether an older copy of the app editing a row keeps Bought and Looking for. **Bought new or used** on every owned item and **Looking for new or used** on every wishlist entry, both optional, never defaulted and never inferred from condition; **Very Good** joins the condition scale between Excellent and Good, and the six grades sit on **one row that scrolls sideways** (the person's call at the Phase 1 pause, on seeing them wrap). A wanted item looking for new reads its market figure from Reverb's new stock and says "new listings"; used or unstated keeps exactly the figure it had. Marking a wanted item bought prefills the sheet from the preference. One appended CSV column on each list, files from before it still importing; the PDF and the item's page carry new/used in the purchase-date row's label. No figure and no grade moved on update — checked by upgrading in place on a device. |

### 2. The `020` backlog entry, rewritten as shipped (replaces the whole entry)

- **`020-purchase-provenance`** (**Shipped `<merge date>`** via
  [PR #33](https://github.com/EHaake/Trove/pull/33) — see
  `specs/020-purchase-provenance/` for the full record) — whether an item
  was **bought new or used**, which the app had never recorded: the only
  signal was the New condition, which says what state a thing is in, not
  how it arrived. **What shipped.** An optional **Bought** fact on every
  owned item — New, Used or not recorded, never defaulted and never
  guessed from condition — set on the item form and on the Mark as bought
  sheet, cleared by tapping the selected chip, carried by Copy, and shown
  by folding it into the purchase-date row's label on the item's page and
  in the PDF ("Bought used · Mar 3, 2024"; plain "Bought" when not
  recorded). Its twin on every wishlist entry, **Looking for**, added at
  the person's reading of the first Draft, which does real work: a wanted
  item looking for new reads its market figure from Reverb's brand-new
  and B-stock listings and says "new listings", where used or unstated
  keeps exactly the used-listings figure it always had; and it prefills
  the purchase sheet. **Very Good** joins the condition scale between
  Excellent and Good, reading Reverb's "very good" listings alone while
  Good keeps "very good" and "good", so no existing figure moved. Six
  grades wrapped onto two lines on an iPhone 17 Pro; at the Phase 1 pause
  the person said that "isn't good" and chose six grades on **one row
  that scrolls sideways**, everywhere it appears. Each list's CSV gains
  one last column (`Bought`, `Looking For`), with files from before it
  still importing and the templates carrying it. **Gifts** stay what they
  were: the person declined a gift value because a gift can itself be new
  or used, so a gift is a zero purchase price, and how charts treat
  zero-price items is `023`'s question. **For the specs that follow**:
  Very Good is stored as Good plus a refinement so that an older copy of
  the app cannot reset it, which means anything that filters, sorts or
  groups by condition must read `condition`, never `conditionRawValue`
  alone — `022-grouped-browsing` is the likely first to need it
  (`DECISIONS.md`). Filtering or grouping by Bought is `022`'s, any
  Dashboard figure using it `023`'s, and setting it on many items at once
  is `021`'s round-trip import. **Left open**: criterion 27 and half of
  P4 wait on the two-device pass (`specs/SYNC-CHECKS.md` 3.11 and 3.12);
  and a handful of things the device pass saw, for the person's eye — on
  an iPhone SE the chip cut off at the row's edge is Fair with about 85 %
  showing, a thin hint that the row scrolls; the Mark as bought sheet on
  an SE opens with Condition below the fold; unselected chip outlines are
  faint in light appearance.

### 3. No change to `021`'s entry

`021-import-expansion` already carries the person's words from the Phase 4
pause (2026-10-06) and the facts of their own spreadsheet — that edit was
committed on this branch (`6bcf950`), so it rides the branch and reaches
`main` with the merge. Nothing to apply here; it is named so nobody goes
looking.

---

## `README.md`

### 4. The Status paragraph and the project tree (not asked of the close-out — see the note at the top)

In **Status**: "Fourteen specs shipped" becomes "Fifteen specs shipped",
the "and" before `018-system-design-language` stays, and after that
entry's closing parenthesis, before the full stop:

    , and `020-purchase-provenance` (merged <merge date> — whether you
    bought each thing new or used, whether you're looking for a wanted one
    new or used, with its market figure read from the matching listings,
    and Very Good on a six-grade condition row that scrolls)

In **Project structure**, after the `018-system-design-language/` line:

      020-purchase-provenance/ Shipped — bought new or used, looking for new or used, Very Good

---

## `DECISIONS.md` — a new section, after `018`'s

## Bought new or used, and a sixth grade (`020`, complete 2026-10-06)

The product decisions are numbered 1–12 (plus the P-items, now decisions)
in `specs/020-purchase-provenance/spec.md`. Decisions 11 and 12 came from
the person's walkthroughs at the Phase 1 and Phase 3 pauses. This records
what reaches beyond that spec.

- **Very Good is stored as Good plus a refinement, and nothing may read
  the raw grade alone** (spec Decision 6 and P4; plan Q2 and R4). The
  simple shape — a sixth raw value, `very good`, in the field that already
  holds the grade — fails a spec requirement on data already on disk, and
  it fails on someone else's device. A copy of the app older than `020`
  does know that field: it reads a grade it has never heard of as
  Excellent and writes its form's grade back on every save. So any edit
  of a Very Good item on a device that had not updated would have reset
  it to Excellent, silently, which is exactly what P4 forbids. The
  shipped shape is the more complex of the two and was chosen for that
  one reason: `conditionRawValue` keeps holding one of the five grades an
  older app knows, and a new optional `conditionRefinement` holds
  `"very good"` beside `"good"` and is nil otherwise. **Its cost is
  visible and accepted** (R4): on a device that has not updated, a Very
  Good item reads **Good** — its nearest known grade, rather than the
  Excellent a naïve value would have fallen back to. One edge is stated
  rather than solved: if the older device moves the item off Good and
  back to Good, the refinement is still there, and the item reads Very
  Good again on an updated device. **And it leaves a rule for everything
  after it: every future query, predicate, sort or grouping reads
  `condition` (or both stored fields), never `conditionRawValue` alone**,
  because that field says "good" for a Very Good item.
  `022-grouped-browsing` is the likely first consumer. At the close-out
  no production code outside `Item.swift` touched the raw field. The
  claim "an older app neither resets nor
  misreads it" is a test, not a sentence: a frozen five-grade replica of
  the pre-`020` read and save ("Very Good and an app older than 020"),
  red under the naïve storage. It runs in memory and cannot see the
  iCloud leg — see what is untested, below.
- **One value type for both facts, and nil is "not recorded" everywhere**
  (spec Decisions 2–4, 8 and 9; plan Q1). Bought and Looking for share
  `NewOrUsed`, stored as an optional raw string. There is no third case:
  the person declined a gift value because a gift can itself be new or
  used, and declined an "either" preference because leaving it blank
  already says so. Nothing is prefilled and nothing is inferred from
  condition — New is a state, not a history — so every row that existed
  before the update reads not recorded, including items graded New.
- **The words describe the figure shown, not the live preference** (plan
  Q4 and R5, after `002`'s `yearFilter`). A wanted item's market figure
  now depends on its Looking for preference: New reads Reverb's brand-new
  and B-stock listings, Used or not recorded reads exactly what it read
  before (spec Decision 9 — reading all listings when unstated would have
  moved every existing wanted figure on update, the same reasoning that
  kept Good's comparison unchanged in Decision 6). A changed preference
  takes effect at the next refresh, as a changed condition does, so for
  up to an hour the screen holds a figure read under the old one. The
  simpler shape — take the words from the entry's current preference —
  would say "new listings" over a used-listings figure for that hour. So
  the figure **records what it was read from** (`isNewStockOnly` on the
  local record, written by the refresher, on withheld readings too) and
  the section reads its words off the figure. The history is not cleared
  on a change, so a trend arrow may compare across it once; that is
  stated, not solved. Checked against live Reverb on the device pass, one
  product read both ways: 58 listed at $439–$670 as new stock, 35 listed
  at $168–$440 as used.
- **One row, not two: the date row's label carries new or used, and the
  PDF matches the page** (spec Decision 10; plan R1, R2, R3 and R6, each
  answered by the person before sign-off). The item's page already had a
  row labelled "Bought" holding the purchase date. A second row reading
  "Bought | New" would have put the word twice in one table, and "Bought
  new" is not a label and a value. So that one row's label becomes
  "Bought new" or "Bought used" when recorded and stays "Bought" when
  not — which also makes the page exactly what it was for every existing
  item (P3). The PDF had the same field and got the same answer, at the
  person's instruction: no second "Bought" field. The wanted item's page
  takes the table's ordinary shape instead, a "Looking for" row with its
  value, left out when not recorded. And one sentence was deliberately
  **not** changed: when a wanted item looking for new has too few new
  listings, the second sentence still names the lowest *used* asking
  price. It says "used" plainly, it is true whatever the preference, and
  it tells the person a used one is to be had.
- **The wrap was rejected at a pause, and the guard was rebuilt around
  what replaced it** (spec Decision 11; plan Amendment A). The first
  Draft said six chips wrapping onto a second line was fine. At the Phase
  1 pause the person saw it on an iPhone 17 Pro — "the condition
  selections span 2 rows, which isn't good" — and, offered five grades or
  a scrolling row, chose six grades on one row that scrolls sideways,
  everywhere it appears. A decision review picked the shape: copy the
  scrolling chip row `CategoryPickerField` already ships in the same
  form, with the row opening on the selected grade; `FlowLayout`, left
  with no user, was deleted. The guard is the instructive part. The
  original layout test had already been found vacuous at sign-off —
  `FlowLayout` reports the width it is offered, so "the row fits" could
  not fail — and a scrolling row cannot be judged from a render at all:
  whether it overflows, scrolls and opens on the selected grade are
  facts about a live scroll view. So the guard became two UI tests, each
  leg broken on purpose and seen red (a two-row layout; the scroll view
  removed; scrolling disabled; the scroll-on-appear deleted), plus a
  render test for the two things a render can say (no chip squeezed, the
  spacing). The six chips measure 434 pt against a 327 pt field on the
  narrowest iPhone, so the row scrolls on every one. **What stays
  eyes-only**: how the chip cut off at the edge looks, which is the
  row's only hint that it scrolls. `.scrollClipDisabled()` is pinned by a
  source scan, which pins a spelling. On an iPhone SE the cut chip is
  Fair with about 85 % showing — a thin cue, put to the person as an
  observation, not decided.
- **Two shipped rules changed, each with a pointer and a rewritten
  guard** (`018`'s rule, applied twice). `002`'s plan pinned the
  condition-to-Reverb sets as pairwise-disjoint; Decision 6 makes Very
  Good and Good overlap on "very good" on purpose. The test was rewritten
  to pin the new rule — exactly one overlap, exactly there — and renamed,
  since its old name had become false, and `002`'s sentence keeps its
  text with "Superseded in part by `020`" beside it. `015`'s purchase
  sheet was pinned at four fields in order; it has five now, and that
  test was rewritten to the new order. Neither guard was deleted to get
  to green.
- **Two test shapes were caught before they could pass for coverage**
  (`CLAUDE.md`, "a passing test is not evidence it can fail"). First, the
  mutation written for the persistence guard — put the refetch back on
  the same context and drop the save — **stays green**: it describes the
  false-pass shape itself, since a same-context refetch hands back
  unsaved changes. The guard was shown able to fail the other way round,
  with the save dropped and the refetch still on a second context. A
  mutation is only evidence if it is the right mutation. Second, the
  **carried-across nil**: "every row from before the update opens as not
  recorded" (criteria 5 and 20) cannot be shown by building a row in a
  test and reading nil back, because a fresh row is nil whatever the app
  does. One such assertion was written and removed; the model-level test
  that remains is cited as agreeing, not as the evidence. The evidence is
  the device pass: `main`'s build with real rows, this build installed
  over it on the same persistent store, and both pages and both forms
  read as the criteria say — an item graded New included, and Good and
  New unchanged (criterion 11). A third, smaller instance: because a
  direct write of `"very good"` into the old field also reads back as
  Very Good on this build, every save-path test asserts the stored pair
  as a literal on a second context, or it could not tell the two
  storages apart. And one thing is said plainly rather than dressed as
  coverage: the Market section's wording has one source scan at the view
  layer, which by the constitution's own reading means that layer is
  untested by the suite; the live check on the device is what speaks for
  it.
- **What is untested, and waiting** (criterion 27; P4). No second
  signed-in device was to hand, so nothing has been seen to sync:
  criterion 27 is unticked, an honest partial by the house convention.
  P4 splits in two. Its Very Good half is tested, by the replica above.
  Its other half is not and cannot be here: an older copy of the app
  does not know the Bought and Looking for fields at all, and whether
  its edits leave them alone depends on CloudKit exporting only the
  fields that app changed — the same claim `009` recorded as unverified.
  The plan does nothing extra for those fields and says so. Both wait in
  `specs/SYNC-CHECKS.md`: step 3.11, an older build on the second device
  editing a Bought-used, Very Good item and a Looking-for-new entry
  (whether an app older than `020` editing a row keeps Bought and
  Looking for), and step 3.12, all three reaching the other device.
  Smaller gaps, named for the sweep: the wanted page showing no row when
  nothing is recorded has no automated assertion; the wishlist form's
  reopen and clear steps and the sheet's clear step are view-model tests
  and the person's walkthrough, not UI tests; the "Too few new listings"
  sentence was not seen live.
- **Two readings confirmed at the Phase 3 pause** (spec Decision 12; the
  person, 2026-10-03: "Everything looks good and I like your
  suggestions"). The match picker's candidate line keeps saying "used"
  ("Lowest used asking price …") for a wanted item looking for new: it
  is a fact about Reverb's catalogue, not about the preference, the same
  reasoning as the kept sentence above. And criterion 7 had said the
  purchase sheet's Bought field opens unselected while criterion 23 and
  P6 preselect it from the preference; it was built to 23, and 7 gained
  "unless the entry has a Looking for preference". A contradiction
  between two criteria is a product question even when the build already
  picked a side, so it went to the person rather than being settled in
  the plan.
- **The device pass ran as four dispatches, one checklist section each**
  — upgrade in place, a narrow phone in both appearances, a live market
  probe, relaunch — per the constitution's 2026-09-24 rule. Four
  sections came to 585,061 tokens and 27.6 minutes,
  against the skill's measured single pass of 319 turns. The probe was a
  temporary file write inside the store function, removed, with the tree
  byte-identical afterwards: instrument the mechanism, don't infer it
  from the screen. One protocol note from the Phase 1 pause: the build
  the person was asked to try had been installed only on the test
  simulator, so a pause report should say which simulator carries it.
- **The person's own spreadsheet stays `021`'s.** At the Phase 4 pause
  they asked whether their gear spreadsheet would import. It would not —
  the header gate, `$` prices and `M/D/YYYY` dates — and none of that is
  this spec's: `020` reads its one new column and its one new grade
  leniently and nothing else. They chose to leave it there ("we'll
  handle it in the next spec. Continue here"), and `ROADMAP.md`'s `021`
  entry carries their words and the file's facts.
- **Seen on the device pass and left for the person's eye, not decided.**
  On an iPhone SE the Mark as bought sheet opens with Bought showing and
  Condition below the fold. Unselected chip outlines are faint in light
  appearance. When the condition row is slid, chips run off the left
  screen edge with no margin. The wishlist PDF's Looking for field is
  not set in mono like its neighbours. And on the estimate sheet, which
  predates this spec, a new-stock reading shows the "median" label
  overprinting the low-end price when the two are equal, and the hint
  about dragging toward the high end "if yours is in better shape than
  most" reads oddly for something you don't own yet.

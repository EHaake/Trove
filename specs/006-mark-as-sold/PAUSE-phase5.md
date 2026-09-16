# Phase 5 pause — 2026-09-14

State: T013–T018 and the review fix T017a are done, reviewed (two blocking
findings fixed, re-review signed off), committed and pushed to draft PR #23.
Remaining: T019 (device pass; person's steps: second-device sync and
VoiceOver) and T020 (close-out), Phase 6.

Open for the person at this pause:
1. Product question (from T017): when a Sell Plan has no candidates left,
   the empty state replaces the list and the Sold section disappears while
   the header still shows the Sold figure. Plan §3 and the artboards put the
   section under the candidates; spec P15 lists the sold items
   unconditionally. Options: (a) keep as drawn; (b) show the Sold section
   under the empty state too (a layout call on an approved artboard).
2. Eye-only checks the device agent could not settle: the Owned/Sold
   switch's 0.25 s slide; the Sell Plan candidate card now 4 pt taller
   (T017a's strip).
3. Worth one look: a category-scoped Dashboard's Sold card lands on the
   unscoped Sold side (by design, Q15) — confirm the person is fine with it.
4. Small copy fact: the sale sheet's Note field has the placeholder
   "Anything worth remembering" (Decision 11); the artboard drew it empty.

Phase 5 review second looks not acted on (recorded for the sweep):
S6 rows don't cross-fade on a side change (design notes' Motion row);
S7 scoped card → unscoped Sold side (conforming); the sale sheet's rust
border clears on the next confirm (same as the item form); WORTH NOW /
PAID unchanged on a sold page (plan §5).

## 2026-09-15 — after the person's walkthrough

Findings T018a–T018c done, reviewed by device pass, pushed. New open item
for the person: with every candidate sold, the plan's empty state still
says "Nothing to sell yet — Add the gear you own and anything you'd part
with turns up here" directly above the SOLD list. Options: (a) leave it;
(b) a sold-aware wording for that case (e.g. "Everything on this plan has
sold."), which is a copy decision. The Mark-as-sold action lives in the
item page's "…" menu (Decision 4); the person reported not finding it —
awaiting whether a visible button is wanted.

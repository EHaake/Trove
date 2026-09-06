# 013 — Settings Menu

Status: **Approved** (2026-09-01, same day as drafting; the seven
drafting proposals P1–P7 in the Decisions record became decisions on
approval, as that section says they would. Two sentences were amended
the same day during planning, after the skeptical review found each
one stating something the code couldn't make true — see the inline
notes and Decisions 13–14.)
Amended 2026-09-02 — **Amendment A (Approved the same day; implemented
and verified the same day, T018–T025 with T024a)**: the Dashboard entry point and
bespoke in-page menus. Raised by the person after all
seventeen tasks were complete and before the merge, and decided in this
session; recorded as Decisions 15–20 (18–19 added during the
amendment's planning, 20 after T024's device look), drafting proposals
P8–P13, and criteria 20–27. Everything outside the sections marked "Amendment A"
is as approved on 2026-09-01. The person approved the amendment on
2026-09-02, and P8–P13 became decisions with it; its plan addendum and
tasks follow the usual gates.
Authored in-session at the person's direction — the second use of the
per-spec venue clause `012` added to the constitution. Every product
decision below was made by the person in that conversation and is
listed in the Decisions record; a handful of smaller calls were
proposed at drafting time and are marked as such there, so the review
could accept or overturn each one explicitly rather than by omission.

Depends on: `011-data-export` (the CSV and PDF writers, the share-sheet
delivery, the staging rules), `012-data-import` (the blank templates,
the "…" menu this spec grows), and the storage and sync groundwork from
`001-core-inventory` (the store's recorded fallback reason, the sync
monitor's phases).

## What and why

Trove has no settings surface in any form. Three things have been
waiting on one:

- **Export everything.** `011` deliberately has no "export everything"
  — export follows the view — and parked the both-collections-in-one-
  gesture action here rather than bolt it onto a list screen where it
  would break that rule. This is the spec's motivating occupant.
- **Sync status.** Since `001` the store has recorded *why* a launch
  fell back from iCloud to local-only storage, and its own comment
  says nothing reads it because "v1 has nowhere to say it." `001`'s
  plan parked the sync-status indicator until "a settings surface
  exists for another reason." That reason is now here.
- **The whole-collection actions that have no list to live on.** The
  blank templates (a one-time setup artifact, not a per-view action)
  and bulk deletion (the mirror of import, which just landed and
  which — as the ~300-row test import in the development store shows —
  creates a real need to clear a list in one go).

The organizing rule this spec settles, so future additions have
somewhere obvious to go: **the "…" menu on a list is for what you do
repeatedly with the list in front of you** — export this view, import
into this list — **and Settings is for whole-collection and one-time
things** — export everything, get a template, see how sync is doing,
clear a list. Import stays on the lists because each list imports its
own schema; the templates move because handing out a blank file is
setup, not daily use.

What Settings does *not* hold yet is any persisted preference. Every
row in v1 is either an action or a readout. That's the honest shape of
the app today — the first real preference arrives with `004-themes`,
and this spec exists partly so that one has a home when it lands.

## Core behavior: one Settings, reached from the lists and the Dashboard

Settings is a single modal screen, presented as a sheet over whichever
screen opened it, with a "Settings" title and a Done button in the
sheet's navigation bar — the same chrome the add/edit forms use. Done
returns to that screen exactly as it was left: a list's filter, sort,
and search untouched. Opening it from the Items list, from the
Wishlist, or — since Amendment A — from the Dashboard yields the
identical screen; there is one Settings, not one per tab.

Nothing on the screen depends on which list opened it. Export-everything
exports both collections regardless; the templates come as a pair; the
delete actions are named per list, not chosen by where you came from.

## Entry point

Both list screens' "…" menu — `011`'s overflow, grown by `012` — gains a
third section at the bottom, below the import section, holding one
item: **Settings**. No trailing ellipsis: it opens a screen, not a flow
that needs more input (the export and import items keep theirs because
a share sheet or a file picker follows).

At the same time, **Get Blank Template… leaves the menu.** From this
spec on, both menus read:

- Export as CSV…
- Export as PDF…
- ─────
- Import from CSV…
- ─────
- Settings

The badge stays always visible, as `012` made it: on an empty
collection the export items are disabled (nothing to export), and
Import and Settings are both enabled — an empty collection is exactly
who a template and an import serve, and both are still reachable
without a single item, one tap further for the template than before
("…" → Settings → Templates). This supersedes the template half of
`012`'s criterion 1 and entry-point section; a cross-reference note is
added there as part of this spec's implementation, the way `012` did
for `011`.

*As approved on 2026-09-01 this section ended: "The Dashboard gets no
entry point in v1" (P1). Amendment A overturns that — the next
subsection is the Dashboard's entry point.*

### The Dashboard's "…" (Amendment A)

The root Dashboard — the TROVE screen, not the category drill-down,
which has a navigation bar and is the same screen narrowed — gains the
"…" Design's mock draws at the top-right of its header. It is the
lists' badge: the same bordered brass pill, sized as theirs, in the
header's trailing position, top-aligned with the wordmark. The mock
draws the mark bare; the pill is chosen so the three root screens carry
one control rather than two drawings of it (P8).

Its menu holds one row: **Settings**. A one-row menu is a small wart,
taken deliberately (P13): the roadmap already holds two Dashboard-only
occupants for exactly this spot — the Dashboard export and the "Full"
export, `011`'s deferrals — so the control starts in the shape it will
keep, and a "…" means the same thing on every screen: a menu, never a
button that happens to open a screen. If one tap ever matters more,
the honest form is a different glyph, not a "…" that isn't a menu.

The badge is always visible on the root Dashboard, empty state
included — the fresh install reaching for a template may well land on
the Dashboard first. It never shows the busy spinner: nothing runs from
the Dashboard. Settings opened here is the same sheet, and Done returns
to the Dashboard with its figures reloaded, so a Delete All is
reflected at once — the sheet's dismissal runs the same load the
screen runs on appear, the way the lists' Settings sheet already does.

The question P1 deferred was answered once the sheet existed: the
whole-collection screen is where whole-collection actions most
naturally live, and the mock had drawn the mark from the start.

## Menus: bespoke inside the page, system in the bars (Amendment A)

Until this amendment the two badges in each list's header opened two
visual languages. Sort By opened `010`'s Design-drawn dropdown — the
232-point surface, the mono header, hairline rows, the brass-tinted
selected row — while "…" opened a system menu, iOS 26's glass. Drawn as
one control family and sitting side by side, they didn't read as one.
The person's call, 2026-09-02: **homogenize on bespoke**, and write
down the rule that says where bespoke stops.

The rule is the one the app already followed without stating it:

- **Inside the page, menus are Trove's own.** The "…" on both lists
  and on the Dashboard, the Sort By picker, and the Dashboard's
  category-order control all open the Sort By dropdown's surface — the
  same width, background, border, radius, row padding, and row
  hairlines — differing only in what the rows say. It should look, in
  the person's words, "exactly like the Sort By options, just with
  different text."
- **In the bars, chrome is the system's.** The detail screens' "…"
  lives in the navigation bar beside the system back chevron, drawn in
  the system's circle, and stays a system menu — as the tab bar, the
  floating add button, and the sheets' Done buttons stay system. A
  bespoke dropdown hung off a bar item, floating over a pushed screen,
  is the fragile version of this idea and buys nothing the rule needs.

One honest consequence: a "…" in a header and a "…" in a bar open
different-looking menus. The layer boundary is what justifies it.

Going the other way — both system — was considered and declined.
`010`'s T029c record is the reason: the sort control *was* a system
menu, and the menu-dismiss transaction animated its variable-width
label's bounds from UIKit, tearing the badge's border for about 400 ms
on every width-growing switch, beyond the reach of any SwiftUI fix. The
cure was the custom dropdown. Returning to a system menu would reopen
that defect, discard an approved Design element (a system menu can show
none of the SORT BY header, the REORDER tag, the tinted row, or the
app's type), and put a glass material inside a page the brief keeps
matte — trading design quality, which the constitution names primary,
for less code.

### What the overflow dropdown looks like

- No header row (P9). Sort By's header names the choice being made;
  "…" has no word to echo, and the system menu had none.
- Rows read as the sort dropdown's unselected rows: body type in
  `textBody`, the same row padding, a `surfaceInset` hairline between
  rows. Nothing is ever "selected" here, so no tint and no checkmark.
- The two group breaks of criterion 1 — after the export pair, after
  Import — are hairlines in `divider`, the surface's own border color,
  rather than `surfaceInset` (P10): a visibly stronger rule drawn in a
  color the surface already uses. No new token.
- A disabled row — the export pair on an empty collection — reads in
  `textDisabled`, does nothing when tapped, and reads as dimmed to
  VoiceOver (P11). Criterion 2's rule is unchanged; only its drawing is
  now the app's.
- Choosing a row closes the dropdown before the action runs, so the
  badge's busy spinner (criterion 14, unchanged) is what the user sees
  during an export, exactly as today.

### What the Dashboard's order dropdown looks like

The "BY VALUE" control keeps its drawing — the mono quiet label the
mock draws, not a pill — and opens the same surface with a header
reading **ORDER BY** (matching its VoiceOver name, "Order categories
…") and its two rows, By value and By count, the current one tinted and
checked as the sort dropdown draws any selected row. No REORDER tag:
that belongs to the manual-order option alone, and there is none here
(P12). This control has carried the exact shape T029c evicted — a
variable-width label in a system menu — since `001`, unreported only
because its label has no border to lag; converting it removes the risk
rather than waiting for it.

### Behavior shared by every in-page dropdown

- One open at a time per screen. While a dropdown is open, a tap
  anywhere outside it — the open badge, the *other* badge, the content
  beneath — closes it and nothing else; the next tap opens whichever
  badge it lands on. Two taps to switch, exactly as Sort By behaves
  today (Decision 19). Choosing a row closes it. The dropdown floats
  over the screen's content beneath the header, at the trailing
  gutter, as Sort By's does today.
- Opening and closing match Sort By's exactly, including whether and
  how they animate — one behavior, not two. Since Decision 20 that
  behavior is an animation: the dropdown grows out of the badge and
  fades in on a snappy spring over a quarter second (the app's
  0.2-second idiom, a touch longer for a surface this size), and fades
  out faster; under
  Reduce Motion, the fade alone.
- VoiceOver: each badge is a button whose hint says what it opens
  ("Opens sort options", "Opens more actions", "Opens order options")
  — SwiftUI exposes no pop-up-button trait, so that announcement is
  the system menu's alone (Decision 18); opening moves focus into the
  dropdown; the escape gesture closes it; the tap-outside layer is
  labelled for what it does ("Dismiss more actions", "Dismiss sort
  options", "Dismiss order options").

## The Settings screen

Sections, top to bottom. Every action row is a single tap; every
readout is text.

### Export

- **Export All as CSV…** — one share sheet carrying **two files**:
  `Trove-Items-YYYY-MM-DD.csv` and `Trove-Wishlist-YYYY-MM-DD.csv`,
  the canonical schemas from `011` unchanged. Every owned item and every
  wanted item, no filter, no search, rows in **Custom order** — the
  user-authored order, and the one `012`'s import appends to, so an
  export-everything → import round trip preserves the arrangement.
- **Export All as PDF…** — one share sheet carrying **two collection
  documents**, `Trove-Items-YYYY-MM-DD.pdf` and
  `Trove-Wishlist-YYYY-MM-DD.pdf`, each the same document the
  corresponding list would produce unfiltered in Custom order, cover
  and all.

Each file is exactly what its list screen would export with no filter,
no search, and Custom sort — not a third export format, the existing
two produced together. Items and wishlist stay separate files with
separate schemas; `011`'s never-combined rule holds.

Both actions are disabled when both collections are empty. When only
one is empty, the gesture still delivers two files — the empty list's
CSV is header-only (the same bytes as its template) and its PDF is a
cover-only document saying so. A file that's absent is a question; a
file that's empty is an answer, and "everything" should mean it.
(Proposed at drafting — see P2.)

### Templates

- **Items Template…**
- **Wishlist Template…**

Each stages the header-only canonical CSV `012` defined, through the
share sheet, under the same undated filenames
(`Trove-Items-Template.csv`, `Trove-Wishlist-Template.csv`). Same bytes
as before — `012`'s criterion 12 continues to hold; only where the
action lives has changed.

### iCloud

One read-only row, always present, that tells the truth about where the
collection is and whether it's moving. It reads from what the app
already knows — how the store was configured, why it fell back if it
did, and what the sync monitor has heard — and asks iCloud nothing new.
The states, in prose (exact copy is pinned at plan time):

- **Configured for iCloud and caught up** — syncing with iCloud; this
  device has the collection.
- **Configured for iCloud, still arriving** — syncing with iCloud;
  catching up (the same condition the empty states already describe as
  "still arriving").
- **Configured for iCloud, but iCloud isn't available** — no account
  signed in, or iCloud can't be reached; the collection stays on this
  device and nothing is lost. The row cannot tell those two apart and
  must not pretend to.
- **Local-only fallback** — iCloud couldn't be set up at launch, so the
  collection is on this device only; the row shows the recorded reason.

The row updates live while the screen is open — a sync finishing or
iCloud coming back changes what it says without leaving and returning.
The wording follows the save captions' rule from `001`: being
configured for iCloud is not the same as being signed in, and no state
may claim "your other devices have this" to someone who isn't.

### Delete

- **Delete All Items…**
- **Delete All Wishlist Items…**

Drawn as destructive rows (the rust accent, the destructive role, and
an explicit accessibility hint — *corrected at T017, 2026-09-02: the
draft said "the role VoiceOver reads", but `ButtonRole.destructive`
isn't documented to announce anything outside alerts and menus; the
hint is what VoiceOver reads, and criterion 18 rests on it — the plan
carried this correction from its review and the spec now does too*),
each disabled when its list is empty. A section footer under them says
that Export, above, is how to keep a copy first.

Tapping one shows a confirmation alert whose **title carries the exact
count** — "Delete all 309 items?", "Delete all 12 wishlist items?"; a
single item reads "Delete your only item?" (decided at plan review;
its message likewise reads with the single-item alert's own sentences,
count-aware as built at T004 in the same spirit) — and whose message
extends the single-item delete copy the app already
uses, because none of the consequences are guessable from the button:

- Items: their photos go too; every sell plan loses its items (the
  nullify direction — plans empty out, wishlist entries stay); the
  iCloud sentence below, when it applies; it can't be undone.
- Wishlist: their photos go too; their sell plans go with them, and
  the gear on those plans stays exactly where it is; the same iCloud
  sentence, when it applies; it can't be undone.

The iCloud sentence — "if you're signed in to iCloud, this removes them
from your other devices too" — **appears only when the store is
configured for iCloud.** *(Amended 2026-09-01 during planning, Decision
13: the draft said the "if signed in" form made the sentence true in
every storage state, but in the local-only fallback nothing syncs
whether or not you're signed in, so it would have been false exactly
where the iCloud row on the same screen says so. The save captions
already branch on storage mode for the same reason; this alert follows
them.)* The buttons are **Delete All** (destructive) and **Keep** — the
same pair the single-item alerts use, so the two kinds of deletion
share a vocabulary.

Deletion is **all-or-nothing**: one save; if it fails, nothing is
deleted and an alert says so ("Nothing was deleted." — the mirror of
import's "Nothing was imported."). There is no undo, no trash, no
grace period; the footer's "export first" is the mitigation, and it
sits on the same screen.

After a delete completes, Settings stays open (the row disables — its
count is now zero). Dismissing it returns to a list showing its genuine
empty state, the Dashboard reflects the change when next shown, and
sell plans reflect it the next time they're opened.

### About

- **Trove** — *Your Gear, Valued.*
- **Version** — the running build's marketing version and build number,
  read from the bundle, never typed into the screen.

Nothing tappable. No links, no acknowledgements (the app has no
third-party packages to acknowledge).

## Busy and failure states

Settings has one busy state. While any of its actions is in flight —
generating an export pair, staging a template, deleting a list — the
acting row shows the app's compact spinner and every other action row
is disabled, so no two actions can overlap. Done stays available.
Dismissing Settings during an export abandons it: no share sheet
appears later, and the generated file is cleared by the next export or
the next launch, the way every staged file is. *(Amended 2026-09-01
during planning, Decision 14: the draft promised "nothing is left
staged", which file generation — a synchronous body that can't be
interrupted — can't honestly deliver; `011`'s no-residue rule is what
actually holds, and criterion 15 already states it.)* Dismissing during
a delete neither stops it nor makes it partial — it completes,
all-or-nothing, and the list behind reflects it. (Proposed at drafting
— see P4.)

An export-everything that fails says so with `011`'s existing export
failure copy; a failed delete says "Nothing was deleted." Every failure
is an alert with one OK; none leaves the screen in a state that needs
explaining.

Share sheets present over Settings and return to it when dismissed —
not to the list. `011`'s no-residue rule (nothing staged outlives its
share sheet beyond the next export or the next launch) covers the
two-file pair exactly as it covers one file.

## What changes in shipped behavior

This spec alters things `012` shipped and documented, all in the open:

- **Get Blank Template… leaves both "…" menus** (above). `012`'s
  criterion 1 and entry-point section get a superseded-in-part note
  pointing here.
- **The wrong-file import alert** currently tells the user that "Get
  Blank Template… in the … menu shows the expected layout." That
  sentence becomes false the moment the template moves; it is reworded
  to point at Settings › Templates. User-facing copy, so it's this
  spec's, not a plan detail.
- **`docs/csv-reference.md` and the README** describe the template as
  living on the list screens; both sentences move with it.
- **`012`'s fresh-install UI test** checks that an empty collection's
  menu offers the template; it changes to check the menu offers Import
  and Settings, and that the template is reachable through Settings.

Nothing about the CSV schema, the import flow, or the list exports
changes.

Amendment A adds three more, each visible:

- **Both lists' "…" stops being a system menu.** `011` chose the
  system `Menu` "deliberately" — `tokens.md`'s "Export badge and menu"
  table records why: a constant-size label sidestepped T029c. Its
  items, order, and enablement rules are unchanged (criteria 1–2); its
  drawing becomes the Sort By surface. That `tokens.md` row is
  superseded and rewritten as part of the amendment's implementation,
  and `brief.md` gets the page/bars rule so the next menu doesn't have
  to rediscover it.
- **The Dashboard's category-order control stops being a system
  menu** — same options, same effect, the app's drawing.
- **The root Dashboard grows a "…"** where it had none.

`010`'s Sort By dropdown is unchanged to the eye; that it becomes the
shared surface the others draw on is an implementation matter.

## Design requirements

- Built from the app's existing vocabulary, no separate Design pass:
  the detail screens' section headings (mono label), label/value rows
  with hairlines, brass for actions, rust for the two destructive rows,
  on the graphite background — the "labelled rows in sections" language
  the app already draws. It should read as a Trove screen, not as the
  iOS Settings app dropped into a dark theme.
- The sheet's chrome (title, Done) is the system's, as the forms' is.
- The iCloud row is one accessibility element reading the whole state
  in a sentence; every action row is labelled for VoiceOver, and the
  delete rows carry the destructive role.
- The busy spinner is the same compact brass spinner the list badges
  use — one idiom for "working" across the app.
- (Amendment A) In-page menus are the Sort By dropdown's surface with
  different rows — no new component vocabulary and no Design pass, per
  the person: "it will look exactly like the Sort By options, just
  with different text." The one new mark is a group-break hairline in
  `divider`; the one new state is a disabled row in `textDisabled`;
  both are existing tokens.
- (Amendment A) Nav-bar menus stay system, and the rule is written
  into `brief.md`.

## Decisions record

Made by the person, 2026-09-01, in the design conversation:

1. Entry point: **an item in the "…" menu of both list screens, in its
   own section at the bottom, below the import section** — a
   further-grown version of the existing overflow, the roadmap's first
   named option. Not a Dashboard control, not a fourth tab.
2. **Get Blank Template… moves to Settings. Import stays in the "…"
   menu.**
3. v1 scope beyond export-everything: **sync status, About, and
   delete-all for each list.** Theme selection waits for `004`; a
   default-currency setting is its own spec.
4. Export everything delivers **the CSV pair and the PDF pair as two
   actions**, each one share sheet with two files — the lists' existing
   exports produced together, never a combined file.
5. **No Design pass** — the screen is built from the existing
   component vocabulary.

Proposed at drafting, 2026-09-01, by Claude Code. These become
decisions on spec approval unless the person overturns them:

- **P1. No Dashboard entry point in v1.** The person's answer named the
  lists' menu; the Dashboard's drawn "…" stays unbuilt and recorded.
- **P2. Export-everything always delivers both files** when at least
  one collection has content; an empty list yields a header-only CSV
  or cover-only PDF. Disabled only when both are empty.
- **P3. Rows in Custom order** for both files — the user-authored order
  and the one import appends to, so the round trip is order-stable.
  (The lists' own exports follow the visible sort; export-everything
  has no view, so it needs a rule, and this is the only order the user
  actually made.)
- **P4. Busy handling**: one busy state, acting-row spinner, other rows
  disabled, Done available; dismissing abandons an export and never
  interrupts a delete.
- **P5. Settings presents as a sheet**, not a push: it's reachable from
  two tabs, and one modal surface that returns you where you were is
  cleaner than a pushed copy living on each tab's stack.
- **P6. Delete confirmation is one alert with the count in its title**
  and Delete All / Keep buttons — proportionate to the app's existing
  two-step single delete, with the export footer as the mitigation,
  rather than a type-to-confirm ceremony.
- **P7. Section order**: Export, Templates, iCloud, Delete, About —
  the things you came for first, the destructive pair near the bottom,
  the version last as a footer.

Added 2026-09-01, during planning (escalated as spec-level by the
skeptical review, decided by the person):

13. The delete alerts' iCloud sentence appears **only when the store is
    configured for iCloud** — the save captions' rule. The "if signed
    in" form alone isn't enough: in the local-only fallback nothing
    syncs regardless.
14. Dismissing Settings mid-export leaves the generated file to `011`'s
    existing purge (next export or next launch) rather than promising
    "nothing is left staged" — generation can't be interrupted, and
    building a cancellation-plus-purge path for a temp file the sweep
    already reclaims isn't worth a new mechanism.

Added 2026-09-02 (Amendment A), decided by the person in this session
after the seventeen tasks were complete and before the merge:

15. **The screen keeps the name Settings**, although nothing on it is
    yet a preference. In iOS vocabulary Settings is the app's
    back-of-house screen, and export, sync status, delete-all, and
    About are its usual residents; the roadmap's theme selection
    (`004`) and a currency choice land exactly here and make the word
    literal. Once real preferences arrive, the export, template, and
    delete groups may move behind rows of their own — deferred,
    recorded in Non-goals here and, in the post-merge docs pass, in the
    roadmap — not designed now.
16. **The root Dashboard gets the "…"** the mock draws, holding
    Settings alone — P1 overturned. Not the category drill-down.
17. **In-page menus go bespoke; nav-bar menus stay system.** The
    lists' "…", the Dashboard's "…", Sort By, and the Dashboard's
    category-order control share the Sort By dropdown's surface; the
    detail screens' "…" stays a system menu. **No Design pass**: same
    surface, different text.

Proposed at drafting the amendment, 2026-09-02, by Claude Code, and
decisions since the amendment's approval the same day:

- **P8. The Dashboard's badge is the lists' bordered pill**, not the
  mock's bare glyph — one control on three screens.
- **P9. The overflow dropdown has no header row.**
- **P10. Group breaks are `divider` hairlines**; row separators stay
  `surfaceInset`.
- **P11. Disabled rows are `textDisabled`**, inert, dimmed to
  VoiceOver.
- **P12. The order dropdown's header reads ORDER BY**, its selected
  row tinted and checked, no REORDER tag; its label stays the mock's
  mono text.
- **P13. A one-row menu on the Dashboard rather than a direct
  button**, for the reasons in the entry-point section.

Added 2026-09-02, during the amendment's planning (escalated as
spec-level by the skeptical review, decided by the person):

18. **The badges announce as buttons with a hint**, not as pop-up
    buttons: SwiftUI has no public trait for the pop-up announcement
    (the system `Menu` gets it from a private one), and building a
    representation around an empty `Menu` was declined as unverified
    and as a system menu back inside a page. Criterion 26 reads
    accordingly.
19. **Switching menus takes two taps**, as Sort By behaves today: the
    tap-outside layer covers the badges, so a tap on the other badge
    only closes the open dropdown; the next tap opens. One-tap
    switching was declined — it needs a cut-out over each badge, and a
    hole over a badge inside the Dashboard's scroll view lets a drag
    scroll the content under an open dropdown, which then needs a
    close-on-scroll as well.

Added 2026-09-02, after T024's device look (raised and decided by the
person):

20. **In-page dropdowns animate.** Built without animation — Sort By
    never had one — the three dropdowns read as stiff beside the
    system menus they replaced. Every in-page dropdown now grows out
    of its badge: a scale from the badge's trailing edge with a fade,
    on a snappy spring opening (a quarter second — the app's 0.2-second
    idiom, a touch longer for a surface this size) and a
    shorter ease-out closing; under Reduce Motion, the fade alone. One
    animation for all of them, applied by the shared host and scoped
    to it, so no screen's own state write is ever animated — the sort
    badge's label still snaps, and its border with it (the T029c
    lesson). The exact system presentation isn't replicable, being
    private; its feel is the target.

## Acceptance criteria

1. [x] Both list screens' "…" menu reads, in order: Export as CSV…,
   Export as PDF…, a divider, Import from CSV…, a divider, Settings.
   "Get Blank Template…" appears in neither menu.
2. [x] On an empty collection the "…" badge is visible; Import from
   CSV… and Settings are enabled; both export items are disabled.
3. [x] Settings opens as a sheet titled "Settings" with a Done button;
   Done returns to the list with its filter, sort, and search exactly
   as they were. Opening from the Items list and from the Wishlist
   shows the identical screen.
4. [x] The screen's sections appear in the order Export, Templates,
   iCloud, Delete, About.
5. [x] Export All as CSV… presents one share sheet containing exactly
   two files, `Trove-Items-YYYY-MM-DD.csv` and
   `Trove-Wishlist-YYYY-MM-DD.csv`. The items file is byte-identical to
   the Items list's own CSV export with no filter, no search, and
   Custom sort; the wishlist file likewise against the Wishlist's.
6. [x] Export All as PDF… presents one share sheet containing exactly
   two documents, `Trove-Items-YYYY-MM-DD.pdf` and
   `Trove-Wishlist-YYYY-MM-DD.pdf`, each with the same cover and the
   same entries in the same order as the corresponding list's
   unfiltered Custom-order export.
7. [x] Both export-everything actions are disabled when both
   collections are empty. With exactly one collection empty, the
   gesture still delivers two files; the empty one's CSV is
   header-only and its PDF is a cover-only document.
8. [x] Items Template… and Wishlist Template… each stage a file
   byte-identical to `012`'s blank template, under `012`'s filenames.
9. [x] The iCloud row shows a truthful state in each of: configured
   for iCloud and caught up; configured and still arriving; configured
   but iCloud unavailable (signed out or unreachable — described
   without claiming to know which); local-only fallback, with the
   recorded reason. It updates while the screen is open.
10. [x] No iCloud-row state claims other devices have the collection to
    a user who isn't signed in.
11. [x] Delete All Items… is disabled at zero items. Otherwise its
    alert's title carries the exact current count (the singular reads
    "Delete your only item?"); its message names
    photos, sell plans emptying, and no undo — plus the iCloud
    sentence when, and only when, the store is configured for iCloud
    (Decision 13). Keep changes nothing. Delete All removes every item:
    the Items list shows its genuine empty state, the Dashboard shows
    its empty state, every wishlist item's sell plan is empty, and no
    wishlist item is touched.
12. [x] Delete All Wishlist Items… is the symmetric case: disabled at
    zero; count in the title; message names photos, sell plans going
    with them and gear staying, no undo, and the iCloud sentence under
    the same rule as criterion 11. Delete All removes
    every wishlist item and no owned item is touched.
13. [x] A delete that fails deletes nothing and says "Nothing was
    deleted."
14. [x] While any Settings action is in flight, the acting row shows
    the spinner and every other action row is disabled; no second
    action can start. Done remains available.
15. [x] A share sheet presented from Settings returns to Settings when
    dismissed, and nothing staged for it outlives the next export or
    the next launch.
16. [x] A failed export-everything shows `011`'s export failure copy.
17. [x] About shows the app name, the subtitle, and the running build's
    version and build number as read from the bundle.
18. [x] VoiceOver: every action row is labelled; the delete rows are
    announced as destructive; the iCloud row reads as one element.
19. [x] The wrong-file import alert no longer refers to the "…" menu
    for the template; it points at Settings › Templates.
    `docs/csv-reference.md` and the README say where the template now
    lives. `012`'s spec carries the superseded-in-part note.

Amendment A (2026-09-02) — verified at T025; the record follows the list:

20. [x] The root Dashboard's header shows the "…" badge at its
    top-right, drawn as the lists' badge, on an empty collection as on
    a full one; the category drill-down shows none. Its dropdown holds
    exactly one row, Settings, which opens the identical Settings
    sheet. Done returns to the Dashboard with its figures reloaded —
    after Delete All Items, the Dashboard's empty state.
21. [x] The "…" on both lists and on the Dashboard opens a dropdown
    drawn on the Sort By surface — same width, background, border,
    radius, row padding, and row hairlines — and no system menu. The
    lists' rows read in criterion 1's order, with the two group breaks
    drawn as `divider` hairlines and no header row.
22. [x] On an empty collection the export rows are drawn in
    `textDisabled` and tapping one does nothing; Import from CSV… and
    Settings still act. (Criterion 2, now under the app's drawing.)
23. [x] Choosing a row closes the dropdown before its action runs;
    during an export the badge shows the spinner and disables exactly
    as before (criterion 14).
24. [x] One dropdown at a time: while Sort By is open, a tap on "…"
    closes Sort By and opens nothing, and the reverse — the next tap
    opens (Decision 19); tapping the open badge, tapping outside, or
    choosing a row closes the open one. The Sort By dropdown's drawing
    is unchanged; it opens and closes with the same animation as every
    in-page dropdown (Decision 20).
25. [x] The Dashboard's category-order control opens the same surface
    with an ORDER BY header and the rows By value and By count, the
    current one tinted and checked; choosing the other reorders the
    breakdown and updates the label.
26. [x] VoiceOver: each badge announces as a button whose hint says
    what it opens (Decision 18), opening moves focus into the
    dropdown, the escape gesture closes it, the tap-outside layer is
    labelled, and disabled rows read as dimmed.
27. [x] The detail screens' "…" is unchanged, and it is the only
    system menu left in the app: no screen presents a system menu
    inside its content.

### Verification record — Amendment A (T025, 2026-09-02)

How each of criteria 20–27 was checked, and where a check stops short.
The instruments: the unit target (790 tests in 116 suites at close), the UI target
(9 tests, 0 failures — run twice back to back at close, and twice per UI task), the
simulator on the dev
store and — for anything destructive — on the `-uiTesting` store only,
and for two claims a frame-by-frame screen recording.

- **20** — The root Dashboard's badge: on the empty state (T022's UI
  test; by hand on the `-uiTesting` store at T025) and on the 307-item
  dev store (T022, by hand); the drill-down shows the back chevron and
  none (T022, by hand; the `isRoot` gate scanned). One row, Settings →
  the identical sheet (UI test; by hand). Done reloads: on the
  `-uiTesting` store, one item added, Settings › Delete All Items… →
  "Delete your only item?" → Delete All → Done → "0 ITEMS", "Nothing
  tracked yet", the badge still there (T025, by hand). Never on the
  dev store. The root Dashboard scrolls and pulls to refresh under
  the host's always-present reader (T025, by hand — the reader is
  empty at rest and drags reach the scroll view through it).
- **21** — The lists' and the Dashboard's "…" open the shared surface
  (`sortByComposesTheSharedSurface`,
  `theOverflowDropdownIsHeaderlessOnTheSharedSurface`, the host
  composition scans; by hand at T021/T022). No system menu:
  `MenuPolicyTests` (criterion 27). Criterion 1's order and the two
  group breaks on exactly the Import and Settings rows:
  `theMenuCarriesFiveItemsInThreeGroups`; the breaks drawn as `divider`
  hairlines and visibly stronger than the row separator:
  `OverflowDropdownRenderTests` (Oklab floor, on pixels); no header
  row: the headerless scan. Seen by hand on both lists.
- **22** — Under an empty search the export rows dim while Import and
  Settings stay bright (T021, by hand); the fresh-install UI test
  asserts the export rows exist and are disabled and Import and
  Settings enabled. The disabled drawing is pinned on pixels
  (`theExportRowsDimWhenThereIsNothingToExport`) — **as built, the
  `textDisabled` token under the button's own dimming**, the compound
  `SettingsActionRow` ships; recorded in the plan's As built.
- **23** — Every row closes before it acts: `everyRowDismissesBeforeItActs`
  reads the button's action in order; the host's injection is scanned
  as attached to the dropdown content. The badge's spinner and
  disable: the pill is new code since T021, so its body is scanned
  (`theBadgeShowsTheSpinnerAndDisablesWhileBusy` — the busy branch
  draws the spinner, the idle one the glyph, the whole control
  disables); the busy *path* through the view model is 013's T016
  verification. **Not re-exercised live** at this pass: a synchronous
  export completes within a frame, and its spinner is unobservable by
  screenshot (T056).
- **24** — Two taps to switch (Decision 19):
  `testAnOpenMenuClosesOnAnyOutsideTapIncludingTheOtherBadge`, and by
  hand at T025 on the Items list. Outside tap, badge tap, row choice
  all close (the catcher, by hand at T020/T021; rows by scan). Sort
  By's drawing: pixel-identical to the frozen original through the
  T018/T019 oracle, then deleted as planned; its position within a
  third of a point of the old offset (T020's probe, screenshots on the
  same pixel row). Its opening and closing now animate (Decision 20) —
  a screen recording at T024a shows the ramp.
- **25** — ORDER BY, By value / By count, the current one tinted and
  checked; By count reorders and the label reads BY COUNT (T023, by
  hand); the composition scanned
  (`theDashboardOrderControlOpensTheSharedSurfaceUnderOrderBy`). On the
  drill-down it opens under the nav bar (by hand). The flip-above
  branch is unreachable on this screen's layouts and rests on
  `DropdownPlacementTests`.
- **26** — **Partial.** Labels and enabled states are proven by the
  UI tests' queries (`isEnabled` asserted on rows found by title);
  three of the six identifiers by the same queries, and all six with
  the three hints by `everyBadgeCarriesItsHintAndIdentifier`'s reading of
  each control's body. The labelled catcher is exercised: the
  switching UI test taps "Dismiss more actions". Focus moving to the
  first row on open, the escape gesture, the `.isModal` containment
  and the dimmed announcement are **composed and scanned**
  (`theSurfaceMarksItsFirstRowWhichTakesFocusAndClosesOnEscape`,
  `theHostInjectsDismissAndContainsVoiceOver`) but **not exercised**:
  no VoiceOver and no Accessibility Inspector from this environment.
  For the person's hands — the same honest partial 013's first pass
  recorded for VoiceOver.
- **27** — `MenuPolicyTests` walks every view file; exactly
  `DetailOverflowMenu.swift` may host a system menu and must; mutation
  red on a planted `Menu` (on the second try — a mutation placed after
  a `#Preview` is invisible to every `SourceScan`, recorded). The
  detail screens' "…" is untouched but for its doc comment (git).

### Verification record (T017, 2026-09-02)

Each criterion above is checked against the test that would catch it
false and, where a person could see it, against the T016 simulator
pass on the ~307-item dev store. Honest partials are stated as such.

1. Menu order — `ExportWiringTests.theMenuCarriesFiveItemsInThreeGroups`
   (Settings present, template absent, two dividers, two gates, Import
   before Settings); seen on device, both lists.
2. Empty badge — `ImportWiringTests.theOverflowControlSitsOutsideEveryEmptyCollectionGate`
   and `testEmptyCollectionOffersImportAndSettingsButNotExport`; seen on
   device after Delete All: badge present, exports dimmed, Import and
   Settings live.
3. Sheet, Done, one screen — `SettingsWiringTests.theScreenAttachesTheSettingsSheetAndReloadsOnDismiss` (renamed at Amendment A/T022, when the Dashboard joined)
   (both lists, all four init arguments) and the Settings UI test's Done
   step; on device, Done returned to the Items list with filter and
   sort as left.
4. Section order — `theSectionsAppearInSpecOrder`, reading the body's
   composition (its first version read declaration order and was caught
   by its own mutation); seen on device.
5. CSV pair — `eachFileIsByteIdenticalToTheListsOwnUnfilteredCustomExport`
   and `theCSVPairIsBothListsWholeInCustomOrderInOneCall` (explicit
   expected order over a tie fixture); on device the share sheet read
   "Save as 2 Items", and Files received `Trove-Items-2026-09-02.csv`
   (308 lines, BOM, CRLF) and `Trove-Wishlist-2026-09-02.csv` (4 lines).
   The items file then re-imported as "Import 307 items? No problems
   found." — the round trip, in practice.
6. PDF pair — `thePDFPairMatchesTheListsUnfilteredDocuments`; on device
   "2 Documents", 116 pages and 2 pages, both saved to Files.
7. Both-empty / one-empty — `nothingIsExportedWhenBothCollectionsAreEmpty`,
   `oneEmptyCollectionStillDeliversTwoFiles`; on device, after the
   wishlist delete the wishlist PDF came back as one cover-only page,
   and after the items delete both export rows disabled.
8. Templates — `SettingsViewModelTemplateTests` (bytes and names, the
   012 pins re-homed); on device the wishlist template staged at
   68 bytes, as in 012. *(2026-09-05, at 002's close-out: 91 bytes
   since 002 appended `Reverb Product ID` and `Year` to the wishlist
   header; `SettingsViewModelTemplateTests` derives the expected bytes
   from `ExportSchema.wishlistHeaders`, so it followed by itself.)*
9. iCloud row — `SyncStatusCopyTests` (full-string table, nil/short/long
   reasons) and `theICloudRowFollowsTheMonitorLive`; on device the
   signed-out simulator read "iCloud isn't available". *Honest partial*:
   caught-up and catching-up need a signed-in device; the local-only
   fallback copy exists only in a preview (the fallback can't be
   provoked on demand).
10. No other-devices claim — `noStateClaimsOtherDevicesHaveTheCollection`
    over every table cell, plus the whole-string pins.
11. Delete All Items — `confirmDeletesEveryItemAndOnlyItems` (second
    context; photos zero; sell plans emptied; wishlist untouched),
    `requestCarriesTheLiveCount`, `cancelAfterRequestLeavesTheStoreIntact`,
    `DeleteAllCopyTests`; on device "Delete all 307 items?" with the
    full message, Delete All → "No gear yet" and "Nothing tracked yet".
12. Delete All Wishlist Items — `confirmDeletesEveryWishlistItemAndOnlyThose`;
    on device "Delete all 3 wishlist items?", Keep left the count at 3,
    Delete All disabled the row and left the 307 items in place.
13. All-or-nothing — `confirmDeleteAllRollsBackOnSaveFailure` (scan:
    exactly one `save()` in the body, and `rollback()` present in the
    extracted `catch` block and nowhere else — tightened at T017 from a
    `contains` pair the sweep found would pass two saves or a rollback
    on the success path) and `DeleteAllCopy.failureMessage` ending
    "Nothing was deleted." *Honest partial*: an in-memory save can't be
    made to throw, so the failure path is pinned structurally, as 012's
    was.
14. Busy — the view-model half by
    `activityIsObservableMidFlightAndBlocksReentry` and
    `activityIsSetSynchronouslyAndClearsWhenDone`; the view half by
    `everyActionRowGatesOnBusyAndReadsItsOwnActivity` (all six rows
    disable on `isBusy` and read their own `activity` for the spinner —
    added at T017 after the sweep found nothing guarded the view side,
    since the view model's guard refuses a reentrant call whether or not
    the rows disable) and `doneIsNeverDisabled`. *Honest partial*: the
    spinner itself was not seen on device, and the reason is worth
    stating precisely — not that it's fast, but that nothing can observe
    a frame; every action completed within a screenshot's latency and
    the wiring is what the scan pins.
15. Share sheet and residue — on device every share sheet returned to
    Settings, and listing the staging directory showed only the latest
    set each time (the CSV pair gone once the PDF pair staged); the
    two-set lifecycle is pinned by `aSecondFileSetLeavesOnlyTheSecondSet`.
    *Honest partial*: the "dismissing mid-export leaves no sheet later"
    half can't be exercised by hand at ~ms generation and has no test;
    it rests on the sheet's state dying with the view, and on the purge
    listing for the file.
16. Export failure copy — `aThrowingServiceSurfacesTheSharedExportCopy`,
    `theFailureAlertsReadTheSharedCopy`, and the `ExportCopy` scan in
    `theViewModelReadsTheSharedCopy`.
17. About — `AppVersionTests` (including that the running bundle carries
    both keys) and `noVersionLiteralInTheSettingsFiles`; on device
    "Version 1.0 (1)".
18. VoiceOver — `bothDeleteRowsCarryAnAccessibilityHintAndTheRowAppliesIt`
    pins the two hints at the call sites *and* their application in the
    row, plus the iCloud block's `.accessibilityElement(children:
    .combine)` (both extended at T017 — the sweep found the first
    version read only the arguments, the declaration-vs-composition
    shape again). *Honest partial*: not driven with VoiceOver by hand —
    that needs Accessibility Inspector or a device in someone's hands.
19. Copy and docs — `theWrongLayoutMessagePointsAtSettingsTemplatesExactlyOnce`
    (whole-string); `docs/csv-reference.md`, the README, and 012's
    spec carry the moves (T015).

## Non-goals (explicit)

- **Theme selection** — `004-themes`; this spec builds the home, not
  the picker.
- **Default currency** — USD is a UI-level assumption on every screen;
  changing it is a spec of its own, not a settings row.
- **Import from Settings** — the person's decision: import stays a
  per-list action on the "…" menu.
- **Restructuring Settings into submenus** — once real preferences
  arrive (`004`'s theme picker first), the export, template, and
  delete groups may each move behind a row of their own; the person's
  call on 2026-09-02 was to defer that until there is something to
  restructure around (Decision 15).
- **Bespoke menus in the navigation bars** — Decision 17 draws the
  line at the page; the detail screens' "…" stays system.
- **A "…" on the Dashboard's category drill-down** — the root screen
  only (Decision 16); the drill-down is the same screen narrowed, with
  a navigation bar, and one entry per tab is enough. (The original
  non-goal here, "A Dashboard entry point", was P1, overturned by
  Amendment A.)
- **iCloud account status or a sign-in prompt** — the row reports what
  the app already knows and asks iCloud nothing; querying account
  status, or deep-linking to the system Settings, is a later nicety
  that would add CloudKit surface for a readout.
- **An iCloud on/off toggle** — turning sync off has real data
  consequences and deserves its own spec.
- **The "Full" export, dashboard export, per-item export** — roadmap
  items; `011`'s deferrals say when and why.
- **Delete everything in one action**, undo, a trash, or selective
  bulk deletion — two per-list actions are the scope; the rest is
  speculation about needs that haven't shown up.
- **Persisted preferences** — none exist yet; the first arrives with
  `004`.
- **Archives** (a `.zip` of the pair) — the share sheet carries two
  files natively.
- **Export history or scheduling.**

## Inherited caveats

- `001`'s fixed type sizes (no Dynamic Type) apply to this screen as to
  every other; the accessibility pass it defers is still deferred.
  Amendment A's dropdowns inherit it exactly as Sort By's does: none
  of them scrolls, and none needs to until that pass lands.
- `011`'s timezone-day caveat on CSV dates applies to the
  export-everything files exactly as to the list exports.
- The store's rule from `001` that being configured for iCloud says
  nothing about sign-in shapes every sentence the iCloud row and the
  delete alerts can say.

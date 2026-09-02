# 013 — Settings Menu

Status: **Approved** (2026-09-01, same day as drafting; the seven
drafting proposals P1–P7 in the Decisions record became decisions on
approval, as that section says they would. Two sentences were amended
the same day during planning, after the skeptical review found each
one stating something the code couldn't make true — see the inline
notes and Decisions 13–14.)
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

## Core behavior: one Settings, reached from the lists

Settings is a single modal screen, presented as a sheet over whichever
list opened it, with a "Settings" title and a Done button in the sheet's
navigation bar — the same chrome the add/edit forms use. Done returns
to the list exactly as it was left: filter, sort, and search untouched.
Opening it from the Items list or from the Wishlist yields the identical
screen; there is one Settings, not one per tab.

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

The Dashboard gets no entry point in v1. Design's Dashboard mock draws
a "…" at the top-right of the TROVE header that has never been built;
it stays unbuilt and is recorded in the Decisions record and in the
roadmap rather than forgotten. (Proposed at drafting — see P1.)

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
3. Sheet, Done, one screen — `SettingsWiringTests.theListAttachesTheSettingsSheetAndReloadsOnDismiss`
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
   68 bytes, as in 012.
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
- **A Dashboard entry point** — P1; the mock's drawn mark is recorded
  for a later spec, not built here.
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
- `011`'s timezone-day caveat on CSV dates applies to the
  export-everything files exactly as to the list exports.
- The store's rule from `001` that being configured for iCloud says
  nothing about sign-in shapes every sentence the iCloud row and the
  delete alerts can say.

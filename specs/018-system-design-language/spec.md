# 018 — System Design Language

**Status**: **Draft** (2026-09-24) — written with the person in a spec
session of its own, per `CLAUDE.md`'s model policy. One note for the
record: the session ran on Fable 5.1 at high effort, which the Opus profile
adopted this morning does not name; the person chose the entry before
choosing a model, the session model was a per-session pick from the app's
picker rather than a role-table change, and `tasks.md`'s tier log records it
as such. The **Decisions record** below holds the product decisions the
person has already made — three of them on the roadmap on 2026-09-19 — and
the ones they make in this conversation. The **P-items** are Claude Code's
proposals and become decisions on plan approval, as `009`'s did. The
**Open questions** at the end are the ones the person still has to answer,
each with a recommendation, so "go with the recommendations" is a complete
answer.

**Depends on**: `010-item-management-enhancements` (the sort picker, and
T029c — the record of why it stopped being a system menu),
`013-settings-menu` (Amendment A's rule, *bespoke inside the page, system in
the bars*, and `MenuPolicyTests`, which enforces it), `006-mark-as-sold` and
`014-sold-side-parity` (the Owned/Sold switch and its measurements),
`009-sell-plan-list` (the Plans tab's switch and menus, the fourth copies
of both), `004-themes` (the record of what happens when a system control is
themed through UIKit). It adds no data, no service, and no screen. It
touches no model and no store.

**Settle before**: `019-foldable-layout`, so a wide layout is not drawn
around surfaces this spec removes.

## Summary

Trove answers the same gesture three ways. Tap "…" in a list's header and
the app's own dropdown grows out of the badge — a 232-point plate in the
app's type, hairline rows, a brass-tinted selection. Tap "…" in the
navigation bar of an item's page and iOS draws its menu. Tap the tab bar at
the bottom and it wears iOS 26's glass. That is not a bug: `013` wrote the
rule that produces it, and a test fails the build if anyone crosses it.

This spec reverses that rule, once, in the open. **Controls go to the
system; content stays Trove's.** Every menu, picker and switch in the app
becomes the control iOS provides, drawn and animated by iOS, wherever it
sits — inside a page or in a bar. What Trove keeps drawing is everything
that is the app rather than the operating system: the headers' type and
meta lines, the cards and plates, the rows, the chips, the desire dial and
gauge, the value slider, the empty states, the forms. The app's identity
moves off its chrome and onto its type, its colour, and what its cards say.

## What and why

`013` chose bespoke because two badges side by side opened two visual
languages, and because going the other way would have reopened a defect
`010` had spent real effort escaping: a system menu's dismiss animated the
sort badge's variable-width label from UIKit and tore its border for about
400 ms on every width-growing switch. Homogenising on the app's own
dropdown fixed both at once. The cost was carried gladly: a surface to
design, a host to write, placement and anchoring to get right, an animation
to add later because the first version "read as stiff", and a policy test
to hold the line.

Three things have moved since.

- **The bars already wear iOS 26.** The tab bar is glass. The Sell Plan's
  Buy and Delete are two glass capsules in the bar. The detail pages' "…"
  is the system's. The app's own surfaces are now the minority look, and
  every new screen — `009` added a fourth tab with a fourth copy of the
  dropdown host and a second copy of the switch — adds to the side that
  has to be maintained by hand.
- **The bespoke surface costs more than it looks.** `013` Decision 20 added
  the grow-from-badge animation because the still dropdown felt stiff;
  `014` found the dropdown's plate had to be measured frame by frame to
  prove it stayed put while its rows swapped; the anchoring needed a fix
  for three tags on one badge; the Plans tab's switch had to be sized from
  a render so its labels fit. None of that is the app. A system menu
  brings its motion, its placement, its Dynamic Type, its VoiceOver traits
  and its Reduce Motion behaviour for free, and `017-dynamic-type` will
  find one less thing to scale.
- **The person's position, recorded 2026-09-19**: lean system, because the
  tab bar already wears glass, because more default iOS means less bespoke
  surface to build and maintain, and because it keeps the app conformant
  with Apple's current language.

The honest counterweight, so the decision is made with both halves in
view. `013`'s objection was a real one and it is still true that a system
menu shows none of the SORT BY header's type, the REORDER tag, the brass
selected row, or the group hairlines. The rule this spec reverses also
reaches beyond the menus: the Owned/Sold and Active/Completed switches are
bespoke *under the same rule*, and `006` spent a measured effort on the
switch's motion. And T029c's tear was never fixed — it was escaped by
removing the system menu, and a system menu behind the same badge may
bring it straight back. This spec answers each: the type and colour that
carried the app's identity in the menu now carry it in the header beside
the menu (P1); the switches go system because a switch is a control, not
content, and a system segmented control brings its own motion (Decision
3); and the tear is **measured before anything else is built** (criterion
1), with a fallback the spec pre-authorises so its result never blocks the
work (P4).

What this spec does not do is redesign the app around Apple's shape. The
tab roots keep their own headers rather than gaining large titles and
toolbars; the search field, the floating add button, Settings' rows, the
chips and the forms are all content by the new rule and stay as they are.
Those are real questions and some of them are listed as non-goals with a
pointer; this spec is the one decision the roadmap asked for, where the
line falls, and the mechanical consequence of drawing it.

## The rule

**System controls, Trove content.**

A *control* is something iOS provides as a control and the person taps to
open, choose or switch: a menu, a picker, a segmented switch, a button in a
bar, a sheet's bar, an alert. Controls are the system's — drawn, placed,
animated and announced by iOS — wherever they sit. The old boundary
between "inside the page" and "in the bars" is gone.

*Content* is everything Trove says and shows: a screen's title and meta
line, a card and its plate, a row, a chip, a field, the desire dial, the
desire gauge, the value slider, a photo carousel, an empty state, a save
bar. Content is Trove's, drawn as `design/tokens.md` says, and this spec
changes none of it.

The one place the two meet is the button that opens a control. A menu's
button is content — it sits in Trove's header, in Trove's type — and it
opens a system menu. That is the shape the detail pages have had since
`013`: the app's own "…" glyph in the bar, the system's menu below it.

## Core behavior

### The "…" menus

The four "…" badges — Dashboard, Items, Wishlist, Plans — open a **system
menu**. Every row keeps its label, its order, its enabled gate and its
action:

- **Dashboard** and **Plans**: Settings, alone. A one-row system menu is
  the shape `013` Amendment A gave the Dashboard and `009` Decision 17
  gave Plans; nothing about a system menu changes the argument.
- **Wishlist**: Export as CSV…, Export as PDF…, then Import from CSV…,
  then Settings — three groups, the two exports disabled when there is
  nothing on screen to export.
- **Items**: the same four, except that the two export rows are **submenus**
  rather than a second dropdown on the same badge (`014` Decision 7). Each
  opens the three scopes — Owned items, Sold items, Owned and sold — each
  enabled exactly when it has rows under the narrowing on screen. A row
  that opens a submenu drops its ellipsis, because iOS draws a chevron
  there and the ellipsis means a further step that is not a menu (P2).

Group breaks are the system's separators. A disabled row is the system's
disabled row. The badge keeps its busy state: while an export runs, the
glyph is a spinner and the badge is inert, exactly as now.

### Sort By

The sort badge opens a **system menu holding a picker**: one row per sort
option, the current one checked, under a **Sort by** header. Choosing a
row applies the sort as it does today; the badge's label updates to name
it. Nothing about which sorts exist, what they are called, which side of
a two-sided list owns which, or how a choice is remembered changes.

The **REORDER** tag on the Custom row — the one mark that told the person
the manual order is the one they can drag — becomes the row's **subtitle**,
"Drag rows to reorder", which iOS draws under the row's title in the
system's secondary type (P3, and Open question 2). Only the Wishlist's and
the Items' Owned side offer a manual order; nothing else gains one.

### The Dashboard's order control

"BY VALUE" keeps its drawing — the quiet mono label, no pill — and opens a
**system menu holding a picker** under an **Order by** header: By value and
By count, the current one checked.

### The two switches

Owned/Sold on the Items list and Active/Completed on the Plans tab become
the **system segmented control** — the same control Settings' Appearance
row has used since `004`. It takes the system's look and the system's
motion: the app does not theme it through UIKit's appearance proxies,
which is the mistake `004` made and reversed (Decision 3, `004`'s record in
`DECISIONS.md`). What the switch *does* is unchanged: it reports which side
the person chose, the screen shows that side, each side keeps its own
search, chips and sort across a switch, and the header stays one meta line
tall on both sides — `014`'s G38 and G39 are kept, not relaxed.

### The badges

The sort badge and the "…" badge keep their drawing — the brass hairline
pill, the mono label, the three-bar glyph and the ellipsis — and become the
buttons that open the system menus (P1, and Open question 1). Their
identifiers are unchanged so every UI test that finds them still does.
Their hints go: `013` Decision 18 gave them "Opens sort options" and "Opens
more actions" because a bespoke button had no pop-up trait to carry; a
system menu's button has one, and VoiceOver says "pop-up button" on its
own.

### What stays exactly as it is

Everything that is already the system's, and everything that is content:

- the detail pages' "…" in the navigation bar, and its rows
- the Sell Plan's Buy and Delete in its bar
- every sheet's Cancel, Save, Done and confirm buttons
- the tab bar and its four drawn icons
- every alert, and the standing choice of alerts over confirmation
  dialogs (`015`'s and `009`'s reason: from a bar button, the dialog
  drops its cancel)
- Settings' Appearance segmented control
- the date fields and the system date picker they open
- the search field, the floating add button, the headers' titles and meta
  lines, the category chips, the condition capsules, the cost presets,
  the form fields and plates, the save bars, the empty states, the desire
  dial and gauge, the market value slider, the photo carousel, the Sell
  Plan's cards and their Mark as sold strip, Settings' rows

Nothing in a row, a card, a form or a sheet changes. No copy changes
except the two ellipses P2 removes.

### Motion

The system's. The grow-from-badge animation `013` Decision 20 added goes
with the dropdown it animated; the switch's sliding fill goes with the
switch. Under Reduce Motion the system does what it does for every app.
The one motion claim this spec makes of its own is criterion 1: a badge's
outline is whole on every frame of a menu's dismiss, whatever the width of
the label it lands on.

### Accessibility

Every control announces as the system control it is. The sort menu's
picker announces the current sort as selected; the segmented control
announces its selected segment; the "…" is a pop-up button. The switches'
identifiers and the "Owned or sold" / "Active or completed" labels are
kept. The detail pages' Delete row keeps its red: it is a system-drawn
destructive control and the role alone colours it, per the constitution's
rust rule. No row that moves into a system menu is destructive, so no
control loses its rust by moving.

### Design documents

`design/brief.md`'s "Menus and chrome" section is rewritten to state this
spec's rule and to record that it supersedes `013` Amendment A's.
`design/tokens.md`'s "Sort picker — and the shared dropdown surface" and
"Export badge and menu" sections are cut to what remains Trove's — the two
badges and the order label — with one line saying what each opens and
that the system draws it; the `006` switch table and the Plans switch line
are replaced the same way. No Design pass: there is nothing to draw, which
is the point (Decision 4, Open question 4).

## Acceptance criteria

1. [ ] **The T029c tear is measured first, and is absent at the end.** With
   the sort badge opening a system menu, switching the Items sort between
   the narrowest and the widest label, on device or simulator, filmed
   frame by frame with the `scripts/motion-probe/` method `006` used: the
   badge's border is whole on every frame, both sides present, from the
   tap to the settled label. If the first measurement shows the tear, P4's
   fallback is applied and the measurement repeated; the criterion is met
   by the final one. This is the first task of the spec, before any other
   surface is converted.
2. [ ] Each of the four "…" badges opens a system menu whose rows carry the
   labels, order, groups and enabled gates the bespoke dropdown carried,
   and each row does what it did. On an empty collection the export rows
   are disabled and Import and Settings are not.
3. [ ] On the Items list, Export as CSV and Export as PDF are submenus
   offering Owned items, Sold items and Owned and sold, each enabled
   exactly when it has rows under the narrowing on screen; choosing one
   exports that scope. The two rows carry no ellipsis. The Wishlist's two
   export rows export directly and keep theirs.
4. [ ] While an export runs the badge shows its spinner and is inert;
   when it finishes the share sheet appears, exactly as today.
5. [ ] The sort badge opens a system menu with one row per sort option
   under a **Sort by** header, the current sort checked; choosing a row
   applies it and the badge's label names it. The Custom row, where a
   list offers one, carries the subtitle "Drag rows to reorder" and no
   other row carries a subtitle.
6. [ ] The Dashboard's order control keeps its mono label and opens a
   system menu with By value and By count under an **Order by** header,
   the current one checked.
7. [ ] Owned/Sold and Active/Completed are system segmented controls.
   Switching shows the other side; each side keeps its own search, chips
   and sort across a switch (`014` criterion 8's guarantee, restated); the
   header's height and the switch's vertical position are equal on both
   sides within a point (`014` G38 and G39, kept).
8. [ ] The two switches are not themed through any UIKit appearance proxy.
   Both appearances, Light and Dark, show a legible selected and
   unselected label at the system's own colours — checked on the device
   pass in both, since `004`'s defect showed only in the sheet.
9. [ ] The bespoke dropdown surface, its host, its placement and anchoring,
   the overflow dropdown, the sort dropdown and the side switch are
   removed from the app, with the tests that existed only to guard them.
   No screen carries a dropdown host, a dismiss catcher, or a tap-outside
   layer.
10. [ ] The policy guard is rewritten to hold the new line: no view under
    the app draws a menu, picker or segmented switch of its own, and every
    "…", sort and order control opens a system menu. It is the legitimate
    source-scan shape — a fact about view bodies no view-model test can
    see — and it is broken deliberately once (a bespoke row put back)
    to show it goes red.
11. [ ] Every badge, switch and control keeps its accessibility
    identifier; the two menu badges lose their "Opens …" hints and
    announce as pop-up buttons; the switches announce their selected
    segment. Checked with the Accessibility Inspector on the device pass.
12. [ ] The UI suite's tests that drove the bespoke controls — the sort
    rows, the overflow rows, the export-scope chooser, the two-tap
    switching, the side switches — drive the system controls instead and
    pass twice back to back. The two-tap-to-switch test is retired with
    the behaviour: two system menus behind two buttons switch in one tap,
    which is the system's rule and the better one.
13. [ ] The unit suite passes with no test weakened. Tests deleted under
    criterion 9 are listed by name in `tasks.md`, each with the control
    whose removal made it moot.
14. [ ] `design/brief.md` and `design/tokens.md` say what the app now does,
    per "Design documents" above, and the `013` rule is recorded as
    superseded rather than deleted.
15. [ ] Every screen is walked in both appearances at the phase pause and
    reads as one language: a "…" in a header, a "…" in a bar and the tab
    bar open or wear the same system chrome. The person attests.

## Decisions record

Made by the person:

1. **Lean system** (2026-09-19, recorded on the roadmap): because the tab
   bar already wears liquid glass, because more default iOS means less
   bespoke surface to build and maintain, and because it keeps the app
   conformant with Apple's current language.
2. **Settle this before `019`** (2026-09-19, roadmap): so a foldable
   layout is not drawn around bespoke surfaces that are then thrown away.
3. **Reverse the rule, don't delete the test** (2026-09-19, roadmap): the
   policy guard is pointed the opposite way from where this spec goes, so
   adopting system menus means rewriting the policy and its test together,
   deliberately and in the open.
4. **This spec, next, and kept small** (2026-09-24): "It should be the
   easiest to knock out and also good to get done sooner." The scope
   below is drawn to that: the one decision, and its mechanical
   consequences, with the larger reshapings listed as non-goals.

## Proposals (P-items)

Claude Code's; they become decisions on plan approval unless the person
overrules one here.

- **P1 — The badges keep their drawing.** The sort badge and the "…"
  badge stay the brass hairline pills in the app's mono type, and become
  the buttons that open the system menus. The header is content and the
  badges live in it; what changed is what they open. The alternative —
  iOS 26 glass buttons in the header — is Open question 1.
- **P2 — A submenu row drops its ellipsis.** iOS draws a chevron on a row
  that opens a submenu; an ellipsis promises a further step of another
  kind. Items' two export rows lose theirs; the Wishlist's keep theirs,
  since those rows go straight to the share sheet.
- **P3 — REORDER becomes a subtitle.** "Drag rows to reorder", drawn by the
  system under the Custom row's title. It keeps the one job the tag had —
  telling the person which order they can drag — in the idiom the system
  menu offers for exactly that.
- **P4 — The tear's fallback is pre-authorised.** If criterion 1's first
  measurement shows T029c's border tear behind a system menu, the sort
  badge takes a constant footprint: sized once to its widest label, so
  the menu's dismiss has no width to animate. That was the interim fix
  T029c measured at two frames inside the dismiss dissolve, before T035
  removed the menu; with the label no longer changing width it should be
  none. If the tear survives even that, the work pauses and the person
  is asked, with the film. The spec does not assume the defect is gone
  and does not assume it is still there; it measures.
- **P5 — One-tap switching between the two badges.** Opening the sort menu
  while the "…" menu is open, or the reverse, is whatever the system does
  with two menus behind two buttons. The bespoke host's two-tap rule and
  its test go with it (criterion 12).
- **P6 — The switches take the system's colours.** Brass `.tint` where the
  system applies it, the system's own label colours otherwise, and no
  appearance proxy. `004`'s record: "a system control taking the system
  semantic colour is appropriate."
- **P7 — The Plans tab's switch is sized by the system.** `009` sized its
  halves from a render so both labels fit; a segmented control sizes its
  segments to their content. The G18 render test that pinned the halves
  goes with the switch.

## Non-goals (explicit)

- **Large titles, navigation bars or toolbars on the tab roots.** The
  headers — title, meta line, badges, switch — are content and stay
  Trove's. Putting sort and "…" into an iOS 26 toolbar would be the fully
  Apple-shaped answer and is a redesign of every list's top, not this
  spec. A follow-up if the person wants it, after seeing this one.
- **The search field** becoming `.searchable`, and the floating add
  button becoming a bar item. Both are content by the rule and both
  depend on the tab roots having a bar, which is the non-goal above.
- **Settings' rows** becoming a system list or form. They are the app's
  row treatment on a sheet whose bar is already the system's. Open
  question 3 asks the person to confirm.
- **Alerts becoming confirmation dialogs.** The standing reason holds.
- **The condition capsules, cost presets and category chips** becoming
  pickers. A chip row shows every option at once; that is a different
  control from a menu, and iOS has no chip control to go to.
- **The desire dial, the gauge, the value slider, the photo carousel.**
  Trove's, by the rule, and each has a record of why it is not the
  system's control.
- **Merging Sort By into the "…" as a submenu** (Apple's Files shape). It
  would remove a badge, and with it the header's statement of the current
  sort. Considered; Open question 5 offers it.
- **`019-foldable-layout`.** This spec clears its way and does none of it.
- **Any change to what a sort, an export, an import, a switch or a menu
  row does.** Every action is unchanged; only the control that reaches it.

## Inherited caveats

- **T029c is a real risk, stated as such.** The whole reason the sort
  control is bespoke is a defect nobody fixed. Criterion 1 and P4 are the
  spec's answer; if both fail, the spec pauses on a product question
  rather than shipping a torn badge or quietly keeping the dropdown.
- **`DestructiveColourPolicyTests` exempts rows inside a system menu**,
  because the system colours them. No destructive row moves into a menu
  under this spec; if a later spec adds one, the exemption is right, not
  a gap.
- **The UI tests find the sort rows by their labels and the "SORT BY"
  header by its text.** System menus expose their rows as buttons and
  their headers as static text with different casing; the rewrite in
  criterion 12 is mechanical but not free.

## Open questions

Each with a recommendation. "Go with the recommendations" answers all
five.

1. **The badges' look.** Keep the drawn brass pills as the menus' buttons
   (P1), or replace them with iOS 26 glass buttons so the button matches
   the menu it opens? *Recommendation: keep the pills.* The header is
   content, and a glass capsule in a matte header is the material the
   brief keeps out of the page. The detail pages already show the shape
   works: the app's glyph, the system's menu. If the person wants glass,
   it is one modifier and the T029c measurement covers it too.
2. **REORDER.** Keep it as a subtitle on the Custom row (P3), or drop it,
   since the person has used the app long enough to know? *Recommendation:
   keep it.* It is one line of copy and it is the only hint a new manual
   order can be dragged.
3. **Settings' rows.** Confirm they stay Trove's. *Recommendation: yes.*
   Converting them is a screen rewrite for no inconsistency anyone has
   seen; the sheet's bar and its Appearance control are already system.
4. **A Design pass.** The roadmap said this was worth one. *Recommendation:
   none.* Going system means the system draws it; a pass would be drawing
   what will not be drawn. The two document edits under "Design
   documents" are the whole of the design work.
5. **One badge or two.** Keep Sort By as its own badge naming the current
   sort, or fold it into the "…" as a Sort by submenu, Apple's shape?
   *Recommendation: two.* The badge's label is the only place the header
   says how the list is ordered; a submenu hides it behind two taps.

Once these are answered the spec is approved, and the ordinary gate
follows: the `sdd-planner` drafts `plan.md` and `tasks.md` against it, and
the `skeptical-reviewer` signs them off.

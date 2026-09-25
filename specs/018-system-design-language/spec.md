# 018 — System Design Language

**Status**: **Draft**, second round (2026-09-24) — written with the person in
a spec session of its own, per `CLAUDE.md`'s model policy. One note for the
record: the session ran on Fable 5.1 at high effort, which the Opus profile
adopted this morning does not name; the person chose the entry before
choosing a model, the session model was a per-session pick from the app's
picker rather than a role-table change, and `tasks.md`'s tier log records it
as such. The **Decisions record** below holds the product decisions the
person has made — three on the roadmap on 2026-09-19, and their reading of
the first Draft on 2026-09-24, which overturned two of its proposals and
set the goal in one sentence: **"full iOS standard, so liquid glass wherever
possible."** The **P-items** are Claude Code's proposals and become
decisions on plan approval, as `009`'s did. The **Open questions** at the
end are what the person still has to answer, each with a recommendation,
so "go with the recommendations" is a complete answer. The first of them is
the one that sizes the spec.

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
navigation bar of an item's page and iOS draws its menu in Liquid Glass.
Tap the tab bar at the bottom and it wears the same glass. That is not a
bug: `013` wrote the rule that produces it, and a test fails the build if
anyone crosses it.

This spec reverses that rule, once, in the open. **Controls go to the
system; content stays Trove's.** Every menu, picker and switch in the app
becomes the control iOS provides, drawn and animated by iOS, wherever it
sits — and the buttons that open them, which sit in Trove's headers, wear
iOS 26's Liquid Glass like the bars already do. What Trove keeps drawing is
everything that is the app rather than the operating system: the headers'
type and meta lines, the cards and plates, the rows, the chips, the desire
dial and gauge, the value slider, the empty states, the forms. The app's
identity moves off its chrome and onto its type, its colour, and what its
cards say.

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
- **The person's position**, recorded 2026-09-19 and restated
  2026-09-24: full iOS standard, Liquid Glass wherever possible, because
  the tab bar and the detail pages' menu already wear it, because more
  default iOS means less bespoke surface to build and maintain, and
  because it keeps the app conformant with Apple's current language.

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
the menu; the switches go system because a switch is a control, not
content, and iOS 26's segmented control brings a sliding glass selection
of its own (see "The two switches"); and the tear is **measured before
anything else is built** (criterion 1), with a fallback the spec
pre-authorises so its result never blocks the work (P4).

**Apple's own rule for where glass goes, because it draws the line this
spec needs.** The Human Interface Guidelines put Liquid Glass in "the
topmost layer of the interface, where you define your navigation" — the
functional layer of controls floating *above* content — and say not to
use it in the content layer, where "it can result in unnecessary
complexity and a confusing visual hierarchy". They also say to apply it
to custom controls "sparingly" and to "limit these effects to the most
important functional elements in your app". Trove's list headers are that
functional layer already: they stand above the rows, outside the scroll,
and hold nothing but the controls that act on the list. A card is content.
That is the reading the sections below apply.

What this spec does not do, under the recommended scope, is redesign the
app around Apple's *layout*. The tab roots keep their standing headers
rather than gaining the system navigation bar and toolbar; the search
field, the chips, Settings' rows and the forms stay as they are. Open
question 1 puts the alternative — the navigation bar and toolbar on every
tab root, which is what glass is designed to float in — in front of the
person as a named choice, because "full iOS standard" arguably means it,
and recommends it as the next spec rather than this one.

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

Where the two meet — a button in Trove's header that opens a system menu —
the button is a control too, and wears Liquid Glass (Decision 5). Glass
goes where Apple puts it: the functional layer above content, never on a
card, and never stacked on glass.

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
a two-sided list owns which, or how a choice is remembered changes. Sort
By stays its own button beside the "…" (Decision 8): the badge's label is
the one place the header says how the list is ordered.

The **REORDER** tag — today a small mono word drawn on the Custom row
*only while Custom is the selected sort*, inside the open dropdown, on the
Wishlist and the Items' Owned side, which is why it is easy never to have
seen — becomes the Custom row's **subtitle**, "Drag rows to reorder", which
iOS draws under a menu row's title in the system's secondary type, whether
or not Custom is selected (P3; Decision 6 keeps it, with the person's
reservation noted).

### The Dashboard's order control

"BY VALUE" opens a **system menu holding a picker** under an **Order by**
header: By value and By count, the current one checked. Whether the label
itself wears glass is Open question 2: it sits inside the category
breakdown card, which is content by Apple's rule and this spec's, and the
recommendation is that it keeps its quiet mono drawing.

### The two switches

Owned/Sold on the Items list and Active/Completed on the Plans tab become
the **system segmented control** — the same control Settings' Appearance
row has used since `004`. On iOS 26 that control *is* Liquid Glass: a
capsule whose selected segment is a glass pill that slides between
segments when tapped, with the separators gone. Apple's engineers have
said on the developer forums that its shape is not customisable — it is
"the new system design for a SegmentedPickerStyle" — which is the point:
the app does not theme it, through UIKit's appearance proxies or
otherwise (Decision 7; `004`'s reversal is the record of why not). That
slide is the "reasonable transition" the person asked for, and criterion
7 measures it the way `006` measured the bespoke one, so the decision rests
on film rather than on a description.

What the switch *does* is unchanged: it reports which side the person
chose, the screen shows that side, each side keeps its own search, chips
and sort across a switch, and the header stays one meta line tall on both
sides — `014`'s G38 and G39 are kept, not relaxed.

### The badges

The sort badge and the "…" badge become **Liquid Glass buttons** — the
system's `.glass` button style, the capsule iOS 26 gives a button in a
bar — carrying the same content they carry now: the three-bar glyph and
the current sort's name in the app's mono type on one, the ellipsis on the
other (Decision 5). Their brass hairline border and drawn background go;
the glass is the background. Their identifiers are unchanged so every UI
test that finds them still does. Their hints go: `013` Decision 18 gave
them "Opens sort options" and "Opens more actions" because a bespoke
button had no pop-up trait to carry; a system menu's button has one, and
VoiceOver says "pop-up button" on its own.

Two consequences stated plainly. Glass over a flat header shows a frosted
capsule with the material's highlight and nothing refracting beneath it,
because the header stands still and the rows scroll under the *list*, not
under it; that is what a glass button looks like anywhere Apple puts one
over a solid surface, and it is what Open question 1's alternative would
change. And the badges are the only custom glass in the app under this
spec — two per header, which is the "sparingly" Apple asks for.

### What stays exactly as it is

Everything that is already the system's, and everything that is content:

- the detail pages' "…" in the navigation bar, and its rows
- the Sell Plan's Buy and Delete in its bar
- every sheet's Cancel, Save, Done and confirm buttons
- the tab bar and its four drawn icons
- every alert, and the standing choice of alerts over confirmation
  dialogs (`015`'s and `009`'s reason: from a bar button, the dialog
  drops its cancel)
- Settings' Appearance segmented control, and Settings' rows (Decision 9)
- the date fields and the system date picker they open
- the headers' titles and meta lines, the category chips, the condition
  capsules, the cost presets, the form fields and plates, the save bars,
  the empty states, the desire dial and gauge, the market value slider,
  the photo carousel, the Sell Plan's cards and their Mark as sold strip
- the search field and the floating add button, unless Open questions 3
  and 4 say otherwise

Nothing in a row, a card, a form or a sheet changes. No copy changes
except the two ellipses P2 removes and the subtitle P3 adds.

### Motion

The system's. The grow-from-badge animation `013` Decision 20 added goes
with the dropdown it animated; the switch's sliding brass fill goes with
the switch, replaced by the system's sliding glass. Under Reduce Motion
and Reduce Transparency the system does what it does for every app. The
motion claims this spec makes of its own are criterion 1 (a badge's
outline is whole on every frame of a menu's dismiss) and criterion 7 (the
segmented control's selection slides, and the header does not move).

### Accessibility

Every control announces as the system control it is. The sort menu's
picker announces the current sort as selected; the segmented control
announces its selected segment; the "…" is a pop-up button. The switches'
identifiers and the "Owned or sold" / "Active or completed" labels are
kept. The detail pages' Delete row keeps its red: it is a system-drawn
destructive control and the role alone colours it, per the constitution's
rust rule. No row that moves into a system menu is destructive, so no
control loses its rust by moving. Glass buttons' legibility under Increase
Contrast and Reduce Transparency is the system's to provide and the device
pass's to look at, in both appearances (criterion 8).

### Design documents

`design/brief.md`'s "Menus and chrome" section is rewritten to state this
spec's rule and to record that it supersedes `013` Amendment A's; its
"no rendered materials" line gains the one exception the rule creates —
the system's glass, on the system's controls and on the buttons that open
them, never on content. `design/tokens.md`'s "Sort picker — and the shared
dropdown surface" and "Export badge and menu" sections are cut to what
remains Trove's — the glyphs and the label type inside the two badges,
and the order label — with one line saying what each opens and that the
system draws the rest; the `006` switch table and the Plans switch line
are replaced the same way. No Design pass: nothing new is being designed
(Decision 10).

## Acceptance criteria

1. [ ] **The T029c tear is measured first, and is absent at the end.** With
   the sort badge a glass button opening a system menu, switching the
   Items sort between the narrowest and the widest label, on device or
   simulator, filmed frame by frame with the `scripts/motion-probe/`
   method `006` used: the badge's capsule is whole on every frame, from
   the tap to the settled label. If the first measurement shows the tear,
   P4's fallback is applied and the measurement repeated; the criterion
   is met by the final one. This is the first task of the spec, before
   any other surface is converted.
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
6. [ ] The Dashboard's order control opens a system menu with By value and
   By count under an **Order by** header, the current one checked, and is
   drawn as Open question 2 decides.
7. [ ] Owned/Sold and Active/Completed are system segmented controls.
   Switching shows the other side; each side keeps its own search, chips
   and sort across a switch (`014` criterion 8's guarantee, restated); the
   header's height and the switch's vertical position are equal on both
   sides within a point (`014` G38 and G39, kept). Filmed with the motion
   probe: the selection slides between the segments rather than cutting,
   and the header above and the rows below do not move during it.
8. [ ] The two switches and the two badges are not themed through any
   UIKit appearance proxy. Both appearances, Light and Dark, show a
   legible label on every glass control at the system's own colours —
   checked on the device pass in both, and once each under Increase
   Contrast and Reduce Transparency, since `004`'s defect showed only in
   the sheet.
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
    bar wear and open the same system glass. The person attests.

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
   easiest to knock out and also good to get done sooner."
5. **Full iOS standard; the header's buttons wear Liquid Glass**
   (2026-09-24, on reading the first Draft, overturning its P1): "My goal
   for this spec is to go full iOS standard, so liquid glass wherever
   possible. That means menu buttons and any other interactible in the
   header for sure should be liquid glass. We're already using liquid
   glass for the menu for item detail, and the tab bar at the bottom."
6. **REORDER stays, for now** (2026-09-24): "my instinct is keep it for
   now (though I reserve the right to change my mind)." As P3's subtitle.
7. **The switches go to glass if the transition is reasonable**
   (2026-09-24): "I'd like to switch it over to liquid glass if there is
   a reasonable transition and would like to explore that." The system
   segmented control's sliding glass selection is the transition; it is
   filmed under criterion 7 and the person sees it at the phase pause.
8. **Sort By stays its own button, in glass** (2026-09-24): "Keep it as a
   separate button, but it should be liquid glass."
9. **Settings' rows stay** (2026-09-24): "I think the current settings
   menu looks very good, so keep it, unless there is a specific iOS 27
   design standard I can look at and consider." The standard to look at
   is the Human Interface Guidelines' "Lists and tables" page — the iOS
   Settings shape is the grouped list — and it has not changed for iOS
   26 or 27; nothing there argues for redoing a screen the person likes.
   Recorded as kept.
10. **No Design pass** (2026-09-24): "No design pass needed since we
    aren't designing anything new."

## Proposals (P-items)

Claude Code's; they become decisions on plan approval unless the person
overrules one here.

- **P1 — withdrawn** (the badges keeping their drawn pills), by
  Decision 5.
- **P2 — A submenu row drops its ellipsis.** iOS draws a chevron on a row
  that opens a submenu; an ellipsis promises a further step of another
  kind. Items' two export rows lose theirs; the Wishlist's keep theirs,
  since those rows go straight to the share sheet.
- **P3 — REORDER becomes a subtitle.** "Drag rows to reorder", drawn by the
  system under the Custom row's title. It keeps the one job the tag had —
  telling the person which order they can drag — in the idiom the system
  menu offers for exactly that, and it is now visible whenever the menu
  is open rather than only once Custom is chosen.
- **P4 — The tear's fallback is pre-authorised.** If criterion 1's first
  measurement shows T029c's tear behind a system menu, the sort badge
  takes a constant footprint: sized once to its widest label, so the
  menu's dismiss has no width to animate. That was the interim fix T029c
  measured at two frames inside the dismiss dissolve, before T035 removed
  the menu; with the label no longer changing width it should be none. If
  the tear survives even that, the work pauses and the person is asked,
  with the film. The spec does not assume the defect is gone and does not
  assume it is still there; it measures.
- **P5 — One-tap switching between the two badges.** Opening the sort menu
  while the "…" menu is open, or the reverse, is whatever the system does
  with two menus behind two buttons. The bespoke host's two-tap rule and
  its test go with it (criterion 12).
- **P6 — Glass controls take the system's colours.** Brass `.tint` where
  the system applies it, the system's own label colours otherwise, and no
  appearance proxy. `004`'s record: "a system control taking the system
  semantic colour is appropriate."
- **P7 — The Plans tab's switch is sized by the system.** `009` sized its
  halves from a render so both labels fit; a segmented control sizes its
  segments to their content. The G18 render test that pinned the halves
  goes with the switch.
- **P8 — Glass is never stacked and never on a card.** Apple's rule,
  adopted as the app's: a glass control sits on the header's flat surface
  or floats over the scrolling rows, never inside a plate, and no glass
  element overlaps another. This is what keeps Open question 2's answer
  and any later "make it glass" request from drifting onto content.

## Non-goals (explicit)

- **The system navigation bar and toolbar on the tab roots** — under the
  recommended answer to Open question 1. The headers — title, meta line,
  badges, switch — stay Trove's standing header. Putting the title in a
  navigation bar and sort and "…" into an iOS 26 toolbar is the fully
  Apple-shaped answer and a redesign of every list's top; it is proposed
  as the next spec, before `019`.
- **The search field** becoming the system's search, which on iOS 26
  floats at the bottom of the screen and needs the navigation bar above.
  It goes with the non-goal above. (Open question 3 asks about its
  drawing meanwhile.)
- **Settings' rows** becoming a system list (Decision 9).
- **Alerts becoming confirmation dialogs.** The standing reason holds.
- **The condition capsules, cost presets and category chips** becoming
  pickers or wearing glass. A chip row shows every option at once; that
  is a different control from a menu, iOS has no chip control to go to,
  and a row of eight glass capsules is the "overusing this material in
  multiple custom controls" Apple warns against.
- **The desire dial, the gauge, the value slider, the photo carousel.**
  Trove's, by the rule, and each has a record of why it is not the
  system's control.
- **Merging Sort By into the "…" as a submenu** (Decision 8).
- **`019-foldable-layout`.** This spec clears its way and does none of it.
- **Any change to what a sort, an export, an import, a switch or a menu
  row does.** Every action is unchanged; only the control that reaches it.

## Inherited caveats

- **T029c is a real risk, stated as such.** The whole reason the sort
  control is bespoke is a defect nobody fixed. Criterion 1 and P4 are the
  spec's answer; if both fail, the spec pauses on a product question
  rather than shipping a torn badge or quietly keeping the dropdown. A
  glass button is system-drawn, which may be exactly what removes the
  tear — the border that tore was SwiftUI's, animated by UIKit — but that
  is a hope, not a measurement, until criterion 1 runs.
- **The app builds against the iOS 27 SDK and runs on iOS 26 and 27.**
  Xcode 27 arrived during `006`; the deployment target stays 26.0 per the
  constitution. iOS 27 refined Liquid Glass — Apple tuned how it diffuses
  content behind it and added a person-set transparency slider — so the
  same control looks slightly different on the two, and on whatever
  setting the person has chosen. The spec claims nothing about the glass's
  exact appearance; it is the system's. The device pass runs on the
  installed 27.0 runtime and says so.
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
four. The first sizes the spec.

1. **Glass buttons in Trove's header, or the system's bar?** Two ways to
   honour "full iOS standard":
   - **(A) This spec as written.** The tab roots keep their standing
     headers; the sort and "…" badges become glass buttons in them; the
     switches become the system segmented control. Glass over a flat
     header reads as a frosted capsule — the material's highlight without
     anything scrolling beneath it.
   - **(B) The tab roots take the system navigation bar and toolbar.** The
     title becomes the bar's title, sort and "…" become toolbar items in
     the system's glass with the system's scroll-edge effect, the meta
     line, switch, search and chips become the top of the scrolling
     content or a bar of their own, the add button likely becomes a
     toolbar item, and the search field can become the system's. This is
     what Liquid Glass is designed to float in, and it is the shape every
     Apple list app has on iOS 26.

   *Recommendation: (A) now, (B) as its own spec, placed before `019`.*
   (A) is the decision the roadmap asked for and the scope Decision 4
   chose; it removes every bespoke control and leaves nothing (B) would
   have to undo — (B) moves glass buttons from a header into a bar, which
   is a layout change, not a reversal. (B) touches every list's top, the
   header layout guards, the empty states, the add button and search, and
   it is the pass that should be drawn with `019`'s wide layout in mind,
   which is why it wants its own spec rather than a phase here. If the
   person would rather see the finished shape once, (B) folds in and the
   spec roughly doubles.
2. **The Dashboard's order label.** It opens a system menu either way. Does
   "BY VALUE" become a glass button, or keep its quiet mono drawing?
   *Recommendation: keep the drawing.* It sits inside the category
   breakdown card — content, by Apple's rule and P8 — and a glass capsule
   inside a plate is exactly the stacking Apple says not to do. It is the
   one interactable that is not in a header.
3. **The search field.** It is in the header, so Decision 5's "any other
   interactible in the header" reaches it. Its system form (the floating
   bottom search) belongs to option (B). Meanwhile: leave it on its plate,
   or draw it as a glass capsule? *Recommendation: leave it.* A glass text
   field beside a glass button is two materials fighting for the same
   line, and it would be redrawn again under (B).
4. **The floating add button.** Not in a header, but it is the one control
   that floats over scrolling content — where Apple puts glass and where
   it actually refracts — and iOS 26's own compose buttons are glass
   discs. Make it a prominent glass button, brass-tinted, keeping its
   size and place? *Recommendation: yes.* It is one modifier, it is the
   most important functional element on both lists, and it is the one
   place in this spec the material does what it is for.

Once these are answered the spec is approved, and the ordinary gate
follows: the `sdd-planner` drafts `plan.md` and `tasks.md` against it, and
the `skeptical-reviewer` signs them off.

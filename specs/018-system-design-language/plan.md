# 018 — System Design Language — Technical Plan

**Status**: **Signed off** (2026-09-24) — drafted by the `sdd-planner`, reviewed by the `skeptical-reviewer` (two blocking findings, B1 and B2, fixed and re-reviewed the same day: signed off). Final for the implementation session.

Drafted by the `sdd-planner` (per `CLAUDE.md`'s model policy, Opus profile as
reconciled 2026-09-24: every role runs at `opus`, no dispatch carries a model
override; the plan-and-tasks draft at the implementation tier is on trial from
2026-09-24 and starts with this spec) against the approved `spec.md`
(Approved 2026-09-24, Decisions 1–14, P2–P8) and the code on the
`018-system-design-language` branch at `0d6c28a`. Planning proposals (Q1–Q14)
become decisions on plan approval, as `009`'s did. The readings the plan had
to take a side on are under **Readings for sign-off**; none is a product fork,
each is stated so the reviewer can overturn it, and each reaches the person in
plain words at the pause where it can first be seen.

## Context

Spec 018 reverses `013` Amendment A's rule — *bespoke inside the page, system
in the bars* — for **System controls, Trove content**. Every "…", Sort By and
order control opens a **system menu**; the two switches become the **system
segmented control**; the two header badges become **`.glass` buttons** and the
add button a **`.glassProminent`** one. Nothing a sort, export, import, switch
or menu row *does* changes (Non-goals). The spec's first act is a measurement:
criterion 1 films the sort badge through a width-changing sort before anything
else is converted, with P4's constant-footprint fallback pre-authorised.

The footprint: **three new production files** (`SortMenu`, `OverflowMenu`,
`SidePicker`, all in `Trove/Views/Shared/`), **six deleted**
(`Dropdown.swift`, `DropdownHost.swift`, `OverflowBadge.swift`,
`OverflowDropdown.swift`, `SortPicker.swift`, `Items/SideSwitch.swift`), and
changes to the four tab roots (`ItemListView`, `WishlistView`, `PlansView`,
`DashboardView`), `AddButton`, `ThemeMetrics` (one token out), `ExportCopy`
(two strings out), and the two design documents. **No model, view model,
store, service or schema changes** — every sort write moves verbatim from a
dropdown row's closure into a menu's `select` (Q7). No new dependency, no
`.pbxproj` edit (the root `Trove` and `TroveTests` groups are synchronized
folders — a new file joins the build by existing; if one doesn't, stop and
flag).

**One constitution amendment, in its own commit, before the guard flips.**
The rule this spec reverses lives in `design/brief.md` and `MenuPolicyTests`,
and it is also quoted in `CLAUDE.md`: the Testing section's source-scan
paragraph gives `MenuPolicyTests` as "the legitimate shape — 'no system menu
inside page content' is a fact about view bodies that no view-model test can
observe." After T011 that sentence would describe a guard asserting the
opposite. T011's **first step, committed on its own before the guard is
rewritten** (the constitution's amendment rule), rewords the example to the
new guard — "'every header control opens a system menu and no view floats a
surface of its own' is a fact about view bodies that no view-model test can
observe" — with a parenthesis noting that the example quoted `013`'s
opposite rule until `018` reversed it (plan §7). Nothing else in `CLAUDE.md`
changes.

**Merged decisions this reverses, each with a pointer appended in place at
close-out, never edited away** (`014/plan.md:704-711` is the pattern):

- `013` Amendment A — the rule (Decision 17), the hints (Decision 18), the
  two-tap switching (Decision 19), the grow-from-badge animation (Decision
  20) and criterion 27 — in `specs/013-settings-menu/spec.md`.
- `010` T035 — the system `Menu` removed from Sort By because of T029c — in
  `specs/010-item-management-enhancements/tasks.md`. `018` restores it,
  measured (criterion 1).
- `014` Decision 7's "second dropdown on the same badge" — now two submenus
  (spec "The '…' menus") — in `specs/014-sold-side-parity/spec.md`.
- `009` plan Q14 and G18 — the generic `SideSwitch` and its measured 69 pt
  half (P7) — in `specs/009-sell-plan-list/plan.md`.
- Code doc comments that restate the old rule are corrected in place, not
  pointed at (T011): `DetailOverflowMenu.swift:16–21`,
  `ItemDetailView.swift:~116`, `PurchaseFormView.swift:~254`,
  `SellPlanView.swift:~796`, `MarketSection.swift:~260`, and the
  `SettingsWiringTests.theAppearanceSection…` comment naming the old guard.

## Readings for sign-off (not open questions — the plan builds to each)

- **R1 — The segmented control hugs its content**, left-aligned where the
  bespoke switch stood (`.fixedSize()`), rather than stretching gutter to
  gutter. P7's words are "a segmented control sizes its segments to their
  content"; hugging also keeps the header's footprint the person approved at
  `006`/`014`. Seen at the Phase 3 pause; one modifier to change.
- **R2 — Tapping the segment already showing no longer reloads that side.**
  `SideSwitch` called `select` "even for the half already showing"; a
  `Picker`'s binding is set only on a change. Nothing the spec describes
  depends on it, and pull to refresh still reloads. Stated because it is a
  behaviour the old doc comment promised.
- **R3 — The badges draw no colour of their own** (P6). The glyph bars and the
  mono label take the glass style's foreground; brass arrives only through
  the root `.tint(accentBrass)` where the style applies it. If the device
  pass shows the labels in the system's label colour rather than brass, that
  is P6 as written, and the person is told so at Phase 1's pause.
  **Overtaken at the Phase 1 pause (spec Decision 15):** the badges set the
  system's primary label colour explicitly (`.foregroundStyle(.primary)` on
  the label, still never a theme colour), so the root tint no longer
  colours them; T004a.
- **R4 — The Wishlist's add button is labelled "Add wanted item"**, as the
  code has it since `001`; the spec's prose says "Add to wishlist", and
  criterion 16 says the label is unchanged. The plan keeps "Add wanted item".
  The button has no accessibility identifier today; criterion 16's
  "identifier unchanged" is read as "still none — the label is the handle
  the UI tests use".
- **R5 — The Dashboard's order menu opens from the plain mono label** —
  `monoLabel(color: textQuiet)`, no glass (Decision 13, P8) — and the label
  keeps that colour rather than the tint the system gives a menu label.
- **R6 — `.contextMenu` leaves the policy guard's ban; `.confirmationDialog`
  stays banned in a test of its own.** Under the new rule a context menu is a
  system control like any other. Alerts-over-dialogs is a separate standing
  decision (`015`, `009`: from a bar button the dialog drops its cancel) that
  the old guard happened to carry; it keeps its coverage (G12d).
- **R7 — The tear is filmed on both installed runtimes**, iOS 27.0 and 26.5.
  The spec's device pass names 27.0; the deployment target is 26.0 and
  T029c's tear was UIKit's, so the older runtime is where a regression would
  hide. If no 26.5 runtime is installed when a film runs, the film records
  that and runs on 27.0 alone.

## Proposed at planning (Q1–Q14) — approved on plan approval unless overturned

- **Q1. `SortMenu<Option: Hashable>` replaces `SortBadge` + `SortDropdown`**
  (§1). One per side on a two-sided screen, each over its side's own options
  and selection, so the badge's label is always the selection of the menu it
  opens (what `visibleSortLabel` did through one badge). `manualOrder:
  Option? = nil` replaces `isManualOrder: (Option) -> Bool`: the one option
  that carries P3's subtitle, and a call site with no manual order simply
  omits it. Generic over `Hashable` rather than `Identifiable` so the render
  test can build one over bare strings. Its two strings live in a
  non-generic `enum SortMenuCopy` beside it — Swift forbids stored statics in
  a generic type (`009` Q14's finding).
- **Q2. `OverflowMenu<Content: View>` replaces `OverflowBadge` +
  `OverflowDropdown`** (§2): the glass "…" with its busy state, wrapping a
  system `Menu` whose rows the screen writes in a `@ViewBuilder`. **No shared
  row set**: the Items rows are submenus and the Wishlist's are buttons, the
  Dashboard's and Plans' are one row — a shared four-row view would be a
  configuration switch over rows that differ in kind on the only two screens
  that share them. "Import from CSV…" and "Settings" are written on the
  screens that carry them, and `ExportWiringTests` pins each screen's rows.
- **Q3. `SidePicker<Side: Hashable>` replaces `SideSwitch`** (§4), moved to
  `Views/Shared/` since two screens use it. It is the thin wrapper that keeps
  each switch's words, label and identifier in one place — the bespoke
  drawing, its metrics and its animation are what criterion 9 removes. The
  `Binding(get:set:)` lives **inside** the component and its setter is
  `select`, so the call sites stay `SidePicker(side: viewModel.side, select:
  { viewModel.show($0) })`: MVVM's rule (intent methods, never raw setters)
  holds, and `ItemListViewModel.side` stays `private(set)`. The guard that
  pinned "binds to nothing" is rewritten to pin exactly that, not relaxed.
- **Q4. The add button is `.buttonStyle(.glassProminent)`,
  `.buttonBorderShape(.circle)`, `.tint(theme.colors.accentBrass)`**, its
  plus glyph taking the style's foreground, sized so the rendered button is
  56 × 56 as the disc is today (§5). The drawn `Circle().fill` goes.
- **Q5. Glass only through the two button styles** — `.glass` on the two
  badges, `.glassProminent` on the add button — never `.glassEffect(_:in:)`
  directly, and **no `GlassEffectContainer`**: two capsules 8 pt apart that
  never morph into each other need no container; one earns its place with
  the toolbar the bar spec (Decision 11) would bring. The policy guard pins
  glass to those three files (G12c), which is P8 and "the only custom glass
  in the app" as a test.
- **Q6. The badges' control size is measured, not chosen by eye** (§1). The
  G38 proviso (`ItemListHeaderLayoutTests`) is that the title's line box, not
  the badge row, sets the header's height; T001 renders the glass badge at
  `.regular` and `.small` and ships the largest that keeps the proviso.
  **The render must speak for the device**: if T002 finds the device's
  `sortOptions.items` frame height more than a point off T001's render, the
  control-size choice is re-made from the device's height (the orchestrator
  sends it back to T001's implementer as a follow-up) before T004 and T005
  copy it. If neither size keeps the proviso, the badge row sets the height on both sides equally
  (criterion 7 still holds); the proviso case is then **rewritten to pin the
  new relationship** — header = badge row + 6 + one meta line — never
  deleted, and the Done note says which element now sets the height.
  **Overtaken at the Phase 1 pause (spec Decision 16):** the person found
  the 28 pt capsule squashed against the system's 44 pt control height;
  the badges go to `.large` (45 pt rendered) and the proviso case is
  rewritten exactly as this paragraph pre-authorised — the badge row sets
  the header's height on both sides equally; T004a. The mono label keeps
  its 11 pt.
- **Q7. No view-model change.** Each menu's `select` carries the closure the
  dropdown row ran — `viewModel.sortOrder = $0; viewModel.load()` on Items
  and the Wishlist, `viewModel.setActiveSort($0)` on Plans,
  `viewModel.breakdownOrder = $0; viewModel.load()` on the Dashboard. Those
  raw writes predate this spec; turning them into intents is not its
  footprint (the spec touches no view model's behaviour, and adding intents
  is a refactor nothing here needs).
- **Q8. The header and subtitle of a sort or order menu.** One "Sort by" /
  "Order by" header over an inline `Picker`: `Section(header) { Picker(…)
  .pickerStyle(.inline).labelsHidden() }`, or the inline picker's own label
  if iOS draws that as the section title — whichever renders **exactly one**
  header, counted by the UI test (G13). The Custom row's subtitle is a second
  `Text` in that option's content. **Both are claims to verify on the
  device** (T002): if a picker row cannot carry a subtitle, stop and return
  for a decision review — criterion 5 (the subtitle) and criterion 11 (the
  picker announces the current sort as selected) pull opposite ways if the
  rows have to become buttons.
  **Decided at T001's decision review (2026-09-24, `skeptical-reviewer`,
  Opus profile).** The stop was taken. The implementer's probe on iOS 27.0
  (an accessibility-tree dump of the open Owned menu from a temporary UI
  test) found: an inline `Picker` inside a `Menu`, labelled or wrapped in a
  `Section`, draws **no header** and shows only a row's first `Text`; a
  `Section` over `Button` rows draws the header and the subtitle but the
  current row carries **no Selected trait**; a `Section` over `Toggle` rows
  draws the header, the subtitle *and* the Selected trait, since SwiftUI
  draws a `Toggle` inside a `Menu` as a checkmark row. **The mechanism is
  therefore `Section(SortMenuCopy.header) { ForEach(options, id: \.self) {
  Toggle(isOn: Binding(get: { option == selection }, set: { _ in
  select(option) })) { Text(label(option)); if option == manualOrder {
  Text(SortMenuCopy.reorderSubtitle) } } } }`** — the setter re-selects on
  any tap, as a picker does (`select` is idempotent), so there is no
  turn-off branch. The spec's "a system menu holding a picker" is met by
  behaviour (one header, one check, the selected trait) rather than by the
  `Picker` type; recorded here as a divergence, not a product question,
  since what the person sees and hears is what the spec describes. Three
  things the probe did not prove, which **T002 checks on device on both
  runtimes**: exactly one checkmark in the open menu; tapping a row closes
  the menu; no frame of the close shows two checks or none. If iOS 26.5
  draws the toggle as a switch or drops the header, T002 stops and a second
  decision review follows. §3's `orderControl` uses the same shape under
  "Order by" (a small shared rows view with two callers is a second look,
  not required). G2 and G5 are reworded in §11 accordingly.
- **Q9. Group breaks are `Divider()`s** inside the menu, as the pre-`013`
  system menu had; disabled rows are `.disabled(...)`. Items' two export rows
  are `Menu("Export as CSV") { … }` / `Menu("Export as PDF") { … }` — P2's
  titles, no ellipsis — each gated as a whole on `canExportCSV` /
  `canExportPDF` (any scope has rows) and each scope row on its own
  `canExport(scope)`, the bespoke chooser's two gates carried over exactly.
  One private helper `exportMenu(_ format: ExportFormat)` writes both, over
  the file's existing `ExportFormat`.
- **Q10. Tests migrate with the control they guard, task by task** (§6, and
  `tasks.md`'s retirement table). A screen's task deletes the legs of the
  old guards that name its screen and writes the behaviour that survives
  into the new guards; a test that guarded only a removed control goes with
  the control and is listed by name (criterion 13). New home for the header
  controls' shared wiring: **`TroveTests/HeaderControlsWiringTests.swift`**
  (created at T001).
- **Q11. `MenuPolicyTests` is inverted once, at T011, and stays meaningful
  until then.** Its current regex flags `Menu {` / `Menu(` outside
  `DetailOverflowMenu.swift`; each task that introduces a system `Menu` adds
  exactly that file to the allowlist, by name, in the same task (T001
  `SortMenu.swift`; T005 `OverflowMenu.swift`, `ItemListView.swift`; T006
  `DashboardView.swift`). The inverted guard is §7.
- **Q12. `ExportCopy.scopeTitleCSV` / `scopeTitlePDF` are deleted** at T005
  with the chooser they headed, and their literal test with them: a submenu's
  title is its row's own label (P2).
- **Q13. `ThemeMetrics.dropdownGap` is deleted** at T010 with the placement it
  served. No test names it.
- **Q14. The motion probe gains a background-difference mode** (§9). Its
  column profile masks brass; neither a glass capsule's rim nor a segmented
  control's glass pill is brass. The T002 agent adds an argument selecting
  "distance from the box's corner colour" as the mass, documents it in
  `scripts/motion-probe/README.md`, and the orchestrator commits it with
  T002. Throwaway-grade, as the README says of the rest.

---

## Layout and files

New production files:

- `Trove/Views/Shared/SortMenu.swift` (`SortMenu`, `SortMenuCopy`)
- `Trove/Views/Shared/OverflowMenu.swift`
- `Trove/Views/Shared/SidePicker.swift`

Deleted: `Trove/Views/Shared/Dropdown.swift`, `DropdownHost.swift`,
`OverflowBadge.swift`, `OverflowDropdown.swift`, `SortPicker.swift`;
`Trove/Views/Items/SideSwitch.swift`.

Changed: `Trove/Views/Items/ItemListView.swift`,
`Trove/Views/Wishlist/WishlistView.swift`, `Trove/Views/Plans/PlansView.swift`,
`Trove/Views/Dashboard/DashboardView.swift`, `Trove/Views/Shared/AddButton.swift`,
`Trove/Views/Shared/Theme/ThemeMetrics.swift` (`dropdownGap` out),
`Trove/Export/ExportService.swift` (`ExportCopy`'s two scope titles out);
doc comments only in `DetailOverflowMenu.swift`, `ItemDetailView.swift`,
`PurchaseFormView.swift`, `SellPlanView.swift`, `MarketSection.swift`.

New test file: `TroveTests/HeaderControlsWiringTests.swift`. Rewritten:
`MenuPolicyTests`, `ItemListHeaderLayoutTests`, and legs of
`ItemListSidesWiringTests`, `PlansWiringTests`, `ExportWiringTests`,
`SettingsWiringTests`, `TroveUITests`. Deleted whole: `DropdownWiringTests`,
`DropdownAnchorTests`, `DropdownPlacementTests`, `OverflowDropdownRenderTests`.
Scripts: `scripts/motion-probe/profile.swift`, `README.md` (Q14). Constitution:
`CLAUDE.md`'s one Testing example (Context), its own commit at T011. Docs:
`design/brief.md`, `design/tokens.md`; at close-out the pointers above,
`README.md` if its words describe the old controls, and the post-merge draft.

---

## 1. `SortMenu` and the tear (foundational)

```swift
/// 018: Sort By's two strings. Not on `SortMenu` — a generic type can't
/// hold stored statics.
enum SortMenuCopy {
    static let header = "Sort by"
    static let reorderSubtitle = "Drag rows to reorder"   // P3
}

/// 018: Sort By — a Liquid Glass button opening the system menu, a picker
/// under one "Sort by" header, the current option checked.
struct SortMenu<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let label: (Option) -> String
    /// The option whose row carries "Drag rows to reorder" — nil where the
    /// list has no manual order (Items' Sold side, both Plans sides).
    var manualOrder: Option? = nil
    let select: (Option) -> Void

    var body: some View {
        Menu {
            // Q8 as decided at T001's review: one header, checkmark rows
            // bound through `select`. (The draft's inline `Picker` drew no
            // header and no subtitle inside a `Menu` on iOS 27.0.)
            Section(SortMenuCopy.header) {
                ForEach(options, id: \.self) { option in
                    Toggle(isOn: Binding(get: { option == selection },
                                         set: { _ in select(option) })) {
                        Text(label(option))
                        if option == manualOrder { Text(SortMenuCopy.reorderSubtitle) }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                glyph                                   // three bars 10/7/4 × 1.5, 2.5 apart,
                Text(label(selection))                  // unfilled Rectangles: the style's foreground
                    .font(ThemeTypography.font(.mono, size: 11))
            }
        }
        .buttonStyle(.glass)
        // .controlSize(…) per Q6, the same literal OverflowMenu uses
    }
}
```

The glyph keeps its token widths; its bars are `Rectangle()`s with no fill of
their own, so they and the label take the style's foreground together (R3).
**Nothing in the file names `theme.colors`.**

Call sites. Items and Plans switch on the side inside `sortControl`, one
`SortMenu` per side; the identifier and the spoken label stay on the
control, the hint goes (criterion 11):

```swift
@ViewBuilder private var sortControl: some View {
    Group {
        switch viewModel.side {
        case .owned:
            SortMenu(options: ItemListViewModel.SortOrder.allCases, selection: viewModel.sortOrder,
                     label: \.label, manualOrder: .custom) { viewModel.sortOrder = $0; viewModel.load() }
        case .sold:
            SortMenu(options: ItemListViewModel.SoldSortOrder.allCases, selection: viewModel.soldSortOrder,
                     label: \.label) { viewModel.soldSortOrder = $0; viewModel.load() }
        }
    }
    .accessibilityLabel("Sort by \(viewModel.visibleSortLabel)")
    .accessibilityIdentifier("sortOptions.items")
}
```

The Wishlist: one `SortMenu` over `WishlistViewModel.SortOrder.allCases`,
`manualOrder: .custom`. Plans: one per side, no `manualOrder`, `select`
calling `setActiveSort` / `setCompletedSort`. Each screen's `HeaderDropdown`
loses `.sort`, and its host loses the `.sort` case.

**The tear (criterion 1, P4).** T029c's tear was UIKit's menu-dismiss bounds
animation on a SwiftUI-drawn border around a label that changed width. A
glass button's capsule is drawn by the system, which may be what removes it —
a hope until it is filmed. T001 converts the Items sort alone; T002 films it
before any other surface moves. **"Whole on every frame"** is defined so the
film can answer it: in the badge's box, at its vertical mid-line, the
columns that differ from the header's background form **one contiguous
span**, and **every label column** (the glyph and text, found the same way
at the label's height) **lies inside it**, on every frame from the tap to the
settled label. A frame where the label stands outside the capsule, or the
capsule breaks into two runs, is the tear. Filmed on Owned Date → the widest
Owned label (G38's own measurement picks it) and back, and on Sold Name →
Date sold, on iOS 27.0 and 26.5 (R7). **Filmed twice**: first at T001's
commit (T002, criterion 1's "measured first"), and again at T008's commit
(T009, criterion 1's "absent at the end"), because by then T005 has put a
second glass `Menu` beside the sort badge and removed the dropdown host the
first film was taken beside — a different header than the one measured.

**As built (Phase 1, 2026-09-24).** The tear was filmed twice (T002, T003).
What the films measure, stated exactly: the probe's `bg` mode takes the
capsule as every pixel differing from the box's corner colour that is not
brass, over the box's full height (on 26.5 the fill and side rims are
within 2/441 of the background at the mid-line, so the mid-line alone
reads nothing), and the label as the brass columns. **Its TEAR verdict
cannot fire on either runtime**: a label's anti-aliased fringe is
differing-and-not-brass, so a label standing past the rim carries its own
edge with it and the measured capsule grows to cover it. The mid-line's
run count is printed for information only. What the films therefore rest
on is (a) the settled capsule extent checked against XCUITest's frame on
every switch — within 0.7 pt on every row after T003, where at T002 the
two 26.5 narrow-to-wide rows disagreed by 12–16 pt, which is how the tear
was found — and (b) the named frames viewed by eye (T003's Done note lists them). **Criterion
1's first measurement is met on that evidence**, not on an automatic
verdict. Before T009's final film the probe is made able to fail: pixels
adjacent to a brass pixel are excluded from the capsule, and the change is
shown firing TEAR on T002's 26.5 frames 819–864 before the finished header
is filmed (T009's task line carries this). Q6 as built: `.regular`, the
render 29 pt against 28.33 on both runtimes. Q8 as built: `Section` of
`Toggle` rows; on iOS 26.5 the subtitle is drawn but absent from the
accessibility tree, so VoiceOver on 26.x does not read it — the UI test's
subtitle legs hold on 27.0, where the suite runs, and would go red rather
than falsely green on 26.x.

**If the tear shows** (T003): the label takes a constant footprint —
`ZStack(alignment: .leading) { ForEach(options) { Text(label($0)).hidden() };
Text(label(selection)) }` — sized once to the widest of its menu's options,
so the dismiss has no width to animate; re-filmed. **If it survives that**,
the work stops and the person is asked, with the film (spec, Inherited
caveats).

**Testable claims.** G1 (the header layout, rewritten per the T001 decision
review: `ImageRenderer` crashes the test process — `precondition failure:
invalid type ID: 0` — whenever a glass `Menu` sits in a `VStack` with
siblings, and `ItemsListHeader` is one, so the header is rendered with a
**stand-in** `Color.clear.frame(width:height:)` in the trailing slot, sized
from a separate render of the badge row alone — `HStack { SortMenu(one
option); OverflowBadge }`, `OverflowMenu` from T005 — which does render;
`widestLabel(of:)` renders a one-option `SortMenu` per label; the two badges
render at one height. No leg asserts the stand-in equals the render it was
sized from — that can only pass. The file's doc comment records the crash.
What the render cannot show is how the glass behaves once it sits in the
header; that rests on T002/T009's device frame check and G39). G2
(`HeaderControlsWiringTests`: `SortMenu`'s body composes a `Menu {`, a
`Section(SortMenuCopy.header)`, a `Toggle(` inside a `ForEach`,
`.buttonStyle(.glass)`, and names no `theme.colors` — a spelling check; the
checkmark and the selected trait are T004's UI test's to guard). G6/G7 (per-side menus on Items and Plans). G13 (the menu's
shape on screen). G14a (the films, T002 and T009). **Needs verification on
the device, not by the suites:** that `ImageRenderer` lays a glass `Menu` out
at the height the device draws it — T002 reads `sortOptions.items`' frame
height from a temporary UI test and compares it with G1's render; if they
differ by more than a point, Q6's control size is re-made from the device's
height before T004/T005 copy it, G1 can't speak for the device, and the claim
rests on G39 (the UI test), said so in **As built**.

## 2. `OverflowMenu` and the four "…" menus

```swift
/// 018: the header's "…" — a Liquid Glass button opening the system menu
/// the screen writes. Spinner and inert while an export or import runs.
struct OverflowMenu<Content: View>: View {
    var isBusy = false
    @ViewBuilder let content: Content

    var body: some View {
        Menu { content } label: {
            Group {
                if isBusy { ProgressView().controlSize(.small) }
                else { Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold)) }
            }
            .frame(width: 18, height: 14)           // the sort badge's content row, as today
        }
        .buttonStyle(.glass)
        // .controlSize(…) — SortMenu's literal (Q6); G1 holds them to one height
        .disabled(isBusy)
        .accessibilityLabel(isBusy ? "Working" : "More actions")
    }
}
```

No hint (criterion 11: a menu's button is a pop-up button to VoiceOver on its
own). The rows, per screen:

| Screen | Rows (a `Divider()` between groups) |
|---|---|
| Dashboard (root only) | `Button("Settings") { isShowingSettings = true }` |
| Plans | the same |
| Wishlist | `Button("Export as CSV…")`, `Button("Export as PDF…")` — each `.disabled(!viewModel.canExport)`, firing `exportCSV()` / `exportPDF()` in a `Task` · `Button("Import from CSV…") { isPickingImportFile = true }` · `Button("Settings")` |
| Items | `exportMenu(.csv)`, `exportMenu(.pdf)` (Q9) · Import · Settings |

```swift
private func exportMenu(_ format: ExportFormat) -> some View {
    Menu(format == .csv ? "Export as CSV" : "Export as PDF") {
        ForEach(ItemListViewModel.ExportScope.allCases) { scope in
            Button(scope.label) {
                Task { switch format { case .csv: await viewModel.exportCSV(scope: scope)
                                        case .pdf: await viewModel.exportPDF(scope: scope) } }
            }
            .disabled(!viewModel.canExport(scope))
        }
    }
    .disabled(format == .csv ? !viewModel.canExportCSV : !viewModel.canExportPDF)
}
```

Each screen's `overflowControl` is `OverflowMenu(isBusy: …) { rows }` plus its
unchanged `moreActions.*` identifier. With Sort By converted in Phase 1 and
the "…" here, **Items, Wishlist and Plans lose their dropdown host
entirely** — `HeaderDropdown`, `@State openDropdown`, `.dropdownHost(…)` and
every `.dropdownAnchor(…)`. The share sheet, the failure alert, the file
importer and the Settings sheet are untouched: they present off the same
state they do today (criterion 4's "exactly as today"). The system menu
dismisses itself before a row's action runs, which is what `DropdownRow`
did by hand.

**Testable claims.** G4 (the busy branch: spinner, `.disabled(isBusy)`,
"Working"/"More actions" — criterion 4, since no UI test can hold an export
mid-run). G8 (`ExportWiringTests`, rewritten: each list's one `OverflowMenu`
fed `isBusy: viewModel.isBusy`; its rows in order, the export rows gated on
their own flags and nothing else gated, two `Divider()`s, Import and
Settings wired, no template; the Items submenus over `ExportScope.allCases`,
each row gated on `canExport(scope)`, each action carrying `scope`, no
`.owned`/`.sold`/`.both` literal, titles without an ellipsis). G9
(`SettingsWiringTests.everyTabsRootReachesSettings`, rewritten: every tab
root's `overflowControl` composes exactly one `OverflowMenu(` whose content
writes `isShowingSettings = true`). G5 (the Dashboard's "…" on the root
alone). G13 (the rows and gates on screen).

## 3. The Dashboard's order menu

```swift
private var orderControl: some View {
    Menu {
        // Q8's header mechanism as decided at T001's review, "Order by":
        // a Section over Toggle checkmark rows, the setter writing and reloading.
        Section("Order by") {
            ForEach(DashboardViewModel.BreakdownOrder.allCases) { order in
                Toggle(isOn: Binding(get: { viewModel.breakdownOrder == order },
                                     set: { _ in viewModel.breakdownOrder = order; viewModel.load() })) {
                    Text(order.label)
                }
            }
        }
    } label: {
        Text(viewModel.breakdownOrder.label).monoLabel(color: theme.colors.textQuiet)
    }
    .accessibilityLabel("Order categories \(viewModel.breakdownOrder.label)")
    .accessibilityIdentifier("orderOptions.dashboard")
}
```

No glass (R5, P8). With the "…" moved at T005, this removes the Dashboard's
host: `DashboardDropdown`, `openDropdown`, `.dropdownHost`. **One caller**, so
the header-plus-inline-picker shape is written here rather than shared with
`SortMenu` — it is five lines, and the two differ in their label and in glass.

**Testable claims.** G5 (the `Section("Order by")` of `Toggle(` rows over
`BreakdownOrder.allCases`, its setter writing and reloading, the mono label,
no `.glass`). G13 (a new UI test:
"Order by" once, By value selected, By count chosen → the control reads "Order
categories By count").

## 4. `SidePicker` — the two switches

```swift
/// 018: a list screen's two sides as the system segmented control — on iOS
/// 26 a capsule whose selected segment is a glass pill that slides. Reports
/// a choice through `select` and never writes the side (Q3).
struct SidePicker<Side: Hashable>: View {
    let side: Side
    let leading: Side, leadingLabel: String
    let trailing: Side, trailingLabel: String
    let accessibilityLabel: String
    let identifier: String
    let select: (Side) -> Void

    var body: some View {
        Picker(accessibilityLabel, selection: Binding(get: { side }, set: select)) {
            Text(leadingLabel).tag(leading)
            Text(trailingLabel).tag(trailing)
        }
        .pickerStyle(.segmented)
        .fixedSize()                               // R1
        .accessibilityIdentifier(identifier)
    }
}
```

The two constrained `init(side:select:)` extensions keep `SideSwitch`'s words,
labels and identifiers exactly — Owned/Sold, "Owned or sold",
`items.sideSwitch`; `SellPlanCopy.active`/`completed`,
`SellPlanCopy.sideSwitchLabel`, `plans.sideSwitch`. `halfWidth`,
`SideSwitchMetrics` and the brass fill go (P7). **Not themed** — no tint, no
appearance proxy (Decision 7, `004`'s record). The call sites change one
word. Each side keeps its own search, chips and sort because `show(_:)` does
(`014`), untouched.

**Testable claims.** G10 (`SidePicker.swift` composes `Picker(` with
`.pickerStyle(.segmented)` and `Binding(get:` whose `set:` is `select`, no
`@Binding`, the words, label and identifier; each screen composes one
`SidePicker(` with `viewModel.show` and no `$` projection, outside the
empty-state branch). G13 (switching by segment, `.isSelected` on the
segment, both sides' state kept, G39's `minY` equality). G14b (the slide on
film). **The header's height and the switch's position are equal on both
sides** — the switch is one control on both sides and the header above it is
G1's; G39 measures it on screen.

## 5. The add button

Per Q4. The overlay, its padding and its placement on both lists are
unchanged; `ItemListView` and `WishlistView` do not change for this. The doc
comment's "permanent v1 design … brass disc" is rewritten to say what `018`
made it and why (Decision 14). **"Its current size and place" is made
falsifiable before the restyle**: T008 writes the UI test first and runs it
against the drawn disc — the button's frame 56 × 56 within a point, its
trailing edge at the window's trailing edge less the gutter, its bottom edge
where the disc's is (read from the tree, recorded) — then restyles, and the
same test must stay green. It also opens the same sheet (the existing
add-item tests tap it by label).

**Testable claims.** G11 (`AddButton.swift` wears `.glassProminent`, the circle
border shape and `accentBrass` tint, and fills no `Circle()`; the UI test
above, on both lists).

## 6. Retiring the bespoke controls

T010 deletes the five shared files and `dropdownGap` once nothing calls them
(the switch file goes at T007 with its callers). The build is the first
proof: a reference left anywhere fails to compile. The tests that existed
only to guard the removed controls are deleted with them, **by name**, in the
task whose change made them moot — `tasks.md` carries the full table
(criterion 13). The behaviours they held that survive are rewritten, never
dropped: identifiers (→ G3), the busy spinner (→ G4), the Dashboard's
root-only "…" and order control (→ G5), the Sold and Plans menus offering no
manual order (→ G6, G7), the export gates and scopes (→ G8), Settings from
every tab (→ G9), "reports through `show`, binds nothing" (→ G10). What goes
without a successor: the surface's drawing, the rows' dismiss-then-act, the
first-row focus and escape, the host's modal trap, catcher and animation,
the placement and anchoring maths, the render checks of the plate's
hairlines and dimming, the switch's fill, slide duration and label fit, the
export chooser's headers, and the two-tap rule's UI test — each the system's
now.

## 7. The policy guard, inverted (criterion 10)

`MenuPolicyTests` keeps its file and its suite, and states the new rule. Four
tests, each a view-body fact no view model can observe (`CLAUDE.md`'s
legitimate source-scan shape), each `#require`-ing its anchors:

- **G12a `everyMenuControlOpensASystemMenu`.** The tab roots are derived from
  `ContentView`'s `Tab(` closures (the `everyTabsRootReachesSettings`
  derivation; as many as `AppRouter.Tab.allCases`). In each root:
  `overflowControl` composes `OverflowMenu(`. **`sortControl` is required by
  name** in `ItemListView`, `WishlistView` and `PlansView` — `#require`d to be
  declared exactly once in each, so a renamed or missing control fails
  rather than being skipped — and composes `SortMenu(`; the Dashboard's
  `orderControl` is required likewise and composes `Menu {` and `Picker(`.
  `SortMenu.swift` and `OverflowMenu.swift` each compose a `Menu {`;
  `DetailOverflowMenu.swift` still does. **Mutation (criterion 10's "a
  bespoke row put back")**: the Wishlist's `sortControl` becomes a `Button`
  toggling a `@State` that shows an `.overlay` of hand-drawn rows → red.
- **G12b `noViewFloatsASurfaceOfItsOwn`.** No file under `Trove/Views` or
  `Trove/App` uses `overlayPreferenceValue`, `anchorPreference` or
  `transformAnchorPreference` — the mechanism every floating in-page surface
  in this app used. (Not the catchers' "Dismiss …" labels: a scan for a
  wording pins the spelling, and the mechanism is the thing.) **No leg on
  picker styles**: the draft's "every `.pickerStyle(` is `.segmented` or
  `.inline`" would have banned `.pickerStyle(.menu)` and unstyled pickers,
  which are system controls the rule allows (Decision 12); "no picker of its
  own" is G12a's positive half and G10's `SidePicker` legs, not a style
  allowlist. Mutation: `DropdownHost.swift` restored from `main` and one host
  re-attached → red. **What it does not claim**: a bespoke control built
  some other way (an `HStack` of buttons with a selected trait) is invisible
  to it; G12a's positive half and review are what catch that, and the plan
  says so rather than implying coverage.
- **G12c `glassIsOnlyOnTheHeaderBadgesAndTheAddButton`** (P8, Q5). Every
  `.glass`, `.glassProminent`, `.glassEffect(` and `GlassEffectContainer`
  under `Trove/Views` and `Trove/App` sits in `SortMenu.swift`,
  `OverflowMenu.swift` or `AddButton.swift`, and each of the three has one.
  Mutation: `.glassEffect()` on `PlansCard` → red.
- **G12d `noUIKitAppearanceProxyAndNoConfirmationDialog`** (criterion 8, R6).
  No `UI[A-Za-z]+\.appearance(` anywhere under `Trove/` — `import SwiftUI`
  re-exports UIKit, so `ExportWiringTests`' import check can't see one — and
  no `.confirmationDialog(` under `Trove/Views`/`Trove/App`. Mutations:
  `UISegmentedControl.appearance().selectedSegmentTintColor = .brown` in
  `TroveApp.init` → red; a `.confirmationDialog` on a Delete → red.

**Every `Picker(` match in these guards (G2, G5, G10, G12a) is on a word
boundary** — `(?:^|[^A-Za-z0-9_])Picker\s*\(`, the existing `Menu` regex's
shape — so `DatePicker(` and `PhotosPicker(` never fire.

The allowlist and `theOnlySystemMenuIsTheDetailScreensNavBarOverflow` go; the
doc comments that state the old rule are corrected in the same task (Context).
**Before any of it, in its own commit**: `CLAUDE.md`'s Testing paragraph that
cites `MenuPolicyTests` as the legitimate source-scan shape is reworded to the
new guard, keeping a note that the old wording quoted `013`'s rule (Context).
The constitution is amended first, then the guard follows it.

## 8. Design documents (criterion 14)

`design/brief.md`: "Menus and chrome" is rewritten to **System controls,
Trove content** — the spec's rule in its words, Apple's placement of glass
(functional layer, never content, sparingly, never stacked), the three
custom glass controls, and a closing paragraph recording that it supersedes
`013` Amendment A's *bespoke inside the page, system in the bars*, quoting
it as history. The "no rendered materials" section gains one line: the
system's glass, on the system's controls and on the buttons that open them,
never on content. `design/tokens.md`: "Sort picker … shared dropdown surface"
and "Export badge and menu" are cut to what stays Trove's — the glyph, the
label's type, the badges' one height, the busy spinner, the order control's
mono label — with one line each saying what the control opens and that the
system draws the rest; the `006` switch table's shape, halves and motion
rows and the Plans "Side switch" row become one line each (the system
segmented control, untinted, hugging its content, R1); the Plans "Trailing"
row stops naming `OverflowBadge`; the row-treatment line's "both dropdowns"
goes; a short **Add button (`018`)** entry records Q4. Historical element
briefs under `design/elements/` are left as the records they are. No
Design pass (Decision 10).

## 9. UI tests and the device pass

**UI tests move with their controls** (Q10); each phase ends with
`scripts/verify.sh ui` at its final commit, and the whole suite runs twice
back to back at the device pass (criterion 12). XCUITest shapes: a system
menu's rows are `app.buttons[title]`; its header is a static text in the
system's casing ("Sort by"); a menu is closed by a tap outside it (iOS
consumes that tap — one helper, one coordinate); a segmented control is found
by identifier and read by `.buttons["Sold"].isSelected`, never `.value`.

- Rewritten: `assertMarketSortRows` ("Sort by", closed by the outside tap);
  `testEachSideKeepsItsOwnSearchChipAndSortAcrossASwitch`;
  `testSortingEachSideReordersTheRowsAndIsKeptAcrossASwitch`;
  `testEmptyCollectionOffersImportAndSettingsButNotExport` (Items' rows lose
  the ellipsis; a Wishlist leg added, its rows keeping theirs);
  `testTheExportRowsOpenAScopeChooserGatedByWhatIsOnScreen` →
  `testTheExportRowsAreSubmenusGatedByWhatIsOnScreen` (the submenu's three
  rows, the Guitars-narrowed Sold side disabling Owned items);
  the four switch reads at `TroveUITests.swift:~1058, ~2073, ~2110, ~2285`
  (`.value` → `.isSelected`); `testAppearanceControlDefaultsToDarkAndOffersThreeChoices`
  finds the control containing a "System" segment rather than
  `segmentedControls.firstMatch`, which now matches the Items switch behind
  the sheet.
- Retired: `testAnOpenMenuClosesOnAnyOutsideTapIncludingTheOtherBadge` (P5).
- New: `testEverySortMenuOffersItsOrdersUnderSortByWithTheCurrentOneChecked`
  (`-uiTesting -seedPlans`: Items Owned, Items Sold, Wishlist, Plans Active
  and Completed — one "Sort by" each, the default selected, "Drag rows to
  reorder" present on Items Owned and the Wishlist and absent on the other
  three); `testTheOverviewsOrderMenuOffersValueAndCountUnderOrderBy`;
  `testTheAddButtonKeepsItsSizeAndPlace` (both lists, §5).
- **Needs verification, owned by the new sort test**: that XCUITest exposes a
  picker row's checkmark as `isSelected`, and how it exposes a row subtitle
  (a static text, or joined into the button's label). The implementer
  records which; if `isSelected` isn't exposed, that leg moves to the
  person's Accessibility Inspector step and **As built** says so.

**Films** (a `general-purpose` agent; the implementers have no simulator):
G14a at T002 (§1, criterion 1's first measurement) and **again at T009**, at
T008's commit on the same runtimes with the same probe — the Items sort,
Owned from Date to the widest label and back and Sold from Name to Date
sold, with the same "whole on every frame" verdict — which is the film
criterion 1's "absent at the end" rests on, since by then T005 has put the
glass "…" beside the badge and removed the host; and G14b at T009 — the
segmented control through Owned → Sold → Owned and Active → Completed: the
selection's edge takes several distinct frames to cross (a slide, not a
cut), and the title, meta line and the switch's own top edge, and the list's
top edge, hold still to within a pixel throughout (criterion 7).

**Device pass** (T013, one `general-purpose` dispatch per section, each
returning a short pass/fail list; the constitution's three habits): (1) every
screen in Light and Dark — the four headers, the open menus, the switches,
the add button over rows — screenshots for the person (criteria 8, 15, 16).
**The appearance is changed with the app's own Appearance control while the
app runs**, with the Items and Plans screens behind the Settings sheet, and
those screens looked at after the sheet closes, in both directions — `004`'s
defect showed only on an in-app switch, so relaunching into each appearance
is not the same check; (2) once each under Increase Contrast (`xcrun simctl
ui … increase_contrast enabled`) and Reduce Transparency (the person's step
if `simctl` offers no switch for it) — every glass label legible (criterion
8); (3) an export from each list's menu: the spinner on the "…", then the
share sheet (criterion 4); and **Import from CSV… from each list's system
menu opens the file importer** (criterion 2 — no UI test reaches the
system's document picker; cancelled, the list unchanged); (4) the Items "…"
on the Sold side under a chip: the scope rows' gates (criterion 3's look). On iOS 27.0, said so. **The person's steps**: the
Accessibility Inspector over the two badges (pop-up button, no hint), a sort
menu's rows (the current one selected), both switches (the selected segment)
and the add button (criterion 11); the walkthrough attestation that every
screen reads as one language (criterion 15).

## 10. Docs and close-out

At T014, on an evidence bundle (the constitution's close-out rule; no full
reads of `spec.md`, `plan.md`, `tasks.md`): criteria 1–16 ticked with
citations — **criterion 1 on both films, T002's (measured first) and T009's
(absent at the end, on the finished header)**; P-items → decisions; this file gains **As built** (the tear's
result and whether P4 shipped, the control size, the header and subtitle
mechanisms, the `isSelected` finding, G1's render-vs-device comparison);
the pointers of Context appended in place (`grep -c` each); `README.md` if
its words describe the old controls; the post-merge draft
`specs/018-system-design-language/main-docs-draft.md` holding the
`specs/ROADMAP.md` text (`018`'s entry and status row, and the follow-up
Decision 11 defers — **the system navigation bar and toolbar on the tab
roots, placed before `019`**) and the `DECISIONS.md` text (the rule reversed
and why; the tear measured and its result; the switches system and
unthemed; glass only on the header badges and the add button; the tests
retired and why each could go); `scripts/verify.sh all`. Then the pre-merge
`skeptical-reviewer` sweep over `git diff main...HEAD`, cut after
`git add -A`, and the PR marked ready.

## 11. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `ItemListHeaderLayoutTests` (`014` G38, kept): the header one meta line tall under every summary and every sort label, the trailing slot a stand-in sized from a render of the badge row alone (`SortMenu` + `OverflowBadge`, then `OverflowMenu` from T005 — a glass `Menu` in the header's `VStack` crashes `ImageRenderer`, T001 review); the no-badges proviso (or its Q6 rewrite); **the two badges one height** (new); with P4, **one width for every selection** (T003). What the render can't show — the glass once it sits in the header — rests on T002/T009's device frame check and G39 | the meta line back beside the badges; the baseline rendered at 200 pt (the instrument check); `SortMenu` at `.large` (the proviso); `OverflowMenu` at another control size; P4's hidden labels dropped |
| G2 | `HeaderControlsWiringTests`: `SortMenu` is a `Menu` whose content is a `Section(SortMenuCopy.header)` of `Toggle(` rows in a `ForEach`, `.glass`, no `theme.colors` (spelling only; the check and selected trait are T004's UI test's) | the `Toggle` rows replaced by `Button` rows; `.foregroundStyle(theme.colors.accentBrass)` on the label |
| G3 | `HeaderControlsWiringTests`: every header control carries its identifier (`sortOptions.items/wishlist/plans`, `moreActions.items/wishlist/plans/dashboard`, `orderOptions.dashboard`) and no hint — per control as each is converted (T001–T006), then, once `OverflowBadge.swift` is gone (T010), no `.accessibilityHint("Opens` anywhere under `Trove/Views` | an identifier dropped; a hint put back |
| G4 | `HeaderControlsWiringTests`: `OverflowMenu`'s busy branch — `ProgressView()`, `.disabled(isBusy)`, "Working"/"More actions"; each list passes `viewModel.isBusy` | `.disabled` removed; `isBusy: false` on Items |
| G5 | `HeaderControlsWiringTests`: the Dashboard's "…" inside exactly one `if isRoot` span; `orderControl` a `Menu` whose content is a `Section("Order by")` of `Toggle(` rows over `BreakdownOrder.allCases` whose setter writes and calls `load()`, `.monoLabel(`, no `.glass` | the "…" outside the gate; `load()` dropped; `.buttonStyle(.glass)` on the label |
| G6 | `ItemListSidesWiringTests` (G20 rewritten): `sortControl` inside the narrowing gate, one `SortMenu` per side, Owned over `SortOrder` with `manualOrder: .custom` writing `sortOrder`, Sold over `SoldSortOrder` with no `manualOrder` writing `soldSortOrder` | `manualOrder:` on the Sold menu; the Sold menu writing `sortOrder` |
| G7 | `PlansWiringTests.noSortMenuOffersAManualOrder`: two `SortMenu`s, neither with `manualOrder:` | `manualOrder: .newest` on one |
| G8 | `ExportWiringTests` (three rewritten): rows, order, gates, two `Divider()`s, Import and Settings wired and ungated; Items' two submenus over every scope, each row on its own gate, no scope literal, no ellipsis | the PDF row gated on the CSV flag; a submenu exporting `.both` directly; Import gated; "Export as CSV…" on Items |
| G9 | `SettingsWiringTests.everyTabsRootReachesSettings` (rewritten) | Plans' `OverflowMenu` replaced; its Settings row removed |
| G10 | `ItemListSidesWiringTests` + `PlansWiringTests`: `SidePicker` segmented, bound through `select`, no `@Binding`; one call per screen with `viewModel.show`, no `$`, outside the empty-state branch | `.pickerStyle(.menu)`; `set: { _ in }`; `$viewModel.side` at a call site; the call moved into the empty branch |
| G11 | `HeaderControlsWiringTests` + `testTheAddButtonKeepsItsSizeAndPlace` | `.glassProminent` removed; `Circle().fill` back; the button 60 pt |
| G12 | `MenuPolicyTests` a–d (§7) | a bespoke sort back on the Wishlist; `DropdownHost` restored; glass on `PlansCard`; an appearance proxy; a confirmation dialog |
| G13 | UI tests, §9, twice back to back | each new test's own mutation: `manualOrder` on Plans; the order setter not writing; the add button's frame changed |
| G14 | Films: a — the capsule whole on every frame (criterion 1), at T002 (and T003 if needed) and again at T009 on the finished header; b — the selection slides, the header holds (criterion 7), at T009 | — (measurements; the frame tables are the record) |
| G15 | Unedited and green: `DestructiveColourPolicyTests` (its site counts recorded), `SoldStateWiringTests.theOverflowMenuHostsExactlyOneSystemMenu`, `SettingsWiringTests.theAppearanceSectionLeadsAsASegmentedPickerOverTheChoice` (comment only), `ReorderWiringTests`, `PullToRefreshTests`, `ExportWiringTests.theShareSheetAndFailureAlertAreWired`, `ThemeTests` | — |

Every guard is mutation-verified before it lands; the Done note records what
was broken and what went red. Every new or rewritten scan `#require`s its
anchor and compares whole literals. What the suites cannot reach — the glass,
the motion, legibility under the accessibility settings, the spoken traits —
is §9's films, device pass and the person's steps.

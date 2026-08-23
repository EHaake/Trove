# Tasks: Core Inventory (v1)

**App**: Trove — *Your Gear, Valued*
**Status**: Draft — pending review
**Implements**: plan.md in this directory

Ordered, small, independently verifiable. Each task should be completable
(and testable) on its own — resist the urge to bundle several into one
commit. If a session ends mid-list, resume by finding the first unchecked
task; don't re-verify everything above it unless something looks off.

Per CLAUDE.md: every implementation task ends with an actual build and,
where tests exist for what changed, an actual test run — reported, not
summarized.

---

## Phase 0 — Project scaffolding (one-time)

- [x] **T001** — Create the Xcode project: App target `Trove`, SwiftUI
      lifecycle, iOS 26.0 minimum deployment, plain `.xcodeproj` (no
      XcodeGen/Tuist). *Verify: project opens and builds an empty app in
      the simulator.*
- [x] **T002** — Add iCloud capability and a CloudKit container to the
      target's Signing & Capabilities. *Was deferred, not skipped*, from
      2026-08-08 to 2026-08-12: creating a CloudKit container needs
      Certificates, Identifiers & Profiles access, which needs an active
      paid Apple Developer Program membership (a Personal Team can
      build/run locally but can't provision a container). Completed once
      the membership was renewed, in two halves:
      - **In Xcode (by hand):** iCloud + CloudKit capability on container
        `iCloud.com.erikhaake.trove`, wiring `CODE_SIGN_ENTITLEMENTS` to
        the already-committed `Trove/Trove.entitlements`.
      - **In code:** `TroveStore` replaces T009's inline local-only
        container — three configurations (CloudKit / local-only /
        in-memory), an unconditional CloudKit ask, and a fallback that
        keeps the same store file when CloudKit won't load. Plus
        `UIBackgroundModes: [remote-notification]` in `Config/Info.plist`,
        the second half flagged by the T002-blocked commit and the thing
        that lets other devices' changes arrive by push rather than at
        next foreground. `TroveStoreTests` (11 tests) covers the
        decisions; all nine rules were mutation-verified red.
      *Verify: `xcodebuild build` and `xcodebuild test` green — 434 tests
      in 67 suites, plus 4 UI tests.*
- [x] **T003** — Add a `TroveTests` target (Swift Testing) and a
      `TroveUITests` target (XCTest). *Verify: an empty placeholder test
      in each target runs green via `xcodebuild test`.*
- [x] **T004** — Create the folder structure from plan.md
      (`App/`, `Models/`, `ViewModels/`, `Views/{Dashboard,Items,
      Wishlist,Shared}/`, `Extensions/`). *Verify: folders exist and are
      reflected as groups in Xcode.*

## Phase 1 — Data models

- [x] **T005** — `Condition` enum (`new/excellent/good/fair/broken`,
      `String`-backed, `Codable`, `CaseIterable`).
- [x] **T006** — `Photo` model (`id`, `imageData` with
      `.externalStorage`, `source` — always `"device"` in v1, `sortOrder`,
      inverse `item` relationship).
- [x] **T007** — `Item` model per plan.md's table, including
      `currencyCode` (default `"USD"`), the computed `condition`
      property wrapping the `Condition` enum, and the
      `plannedForWishlistItems` inverse relationship.
- [x] **T008** — `WishlistItem` model per plan.md's table, including
      `currencyCode` and the `plannedSaleItems` relationship to `Item`.
- [x] **T009** — Configure `ModelContainer` in `TroveApp`, registering
      all three model types. **Local-only for now** (no CloudKit
      database) since T002 is deferred — the schema was built
      CloudKit-compatible from the start specifically so this is a small,
      contained swap later (add the CloudKit database configuration and
      the "not signed into iCloud" handling) rather than a migration.
      *Verify: app launches in the simulator without errors.*
      **Swapped at T002, and it was the contained swap this predicted** —
      no migration, no model change, no view touched.
- [x] **T010** — Unit tests: creating each model type via an in-memory
      `ModelContainer` produces the expected defaults (`desireToKeep ==
      3`, `currencyCode == "USD"`, etc). *Verify: `xcodebuild test`
      green.*

**Not a numbered task, added during T007, worth being on the record**:
`CloudKitSchemaTests.swift` — asserts the schema actually validates
against a CloudKit `ModelConfiguration`, rather than plan.md just
asserting it in prose. This is what caught the `[Photo]` vs `[Photo]?`
bug (see plan.md's Data model intro). Runs as part of `xcodebuild test`
going forward with no entitlement or network needed; every future model
change gets checked immediately rather than at T002-resumption time.

## Phase 2 — Shared utilities

- [x] **T011** — `Int+Currency` extension: cents → formatted currency
      string, given a `currencyCode`.
- [x] **T012** — Unit tests for currency formatting (zero, negative if
      applicable, typical values).
- [x] **T013** — Category-path helper: given a `ModelContext`, fetch
      distinct `categoryPath` values across `Item` and `WishlistItem`;
      a filter function that matches by prefix, case-insensitively,
      against user-typed input; a canonicalization function that, given
      a newly-typed path, returns the existing casing if a
      case-insensitive match exists among current paths, or the
      as-typed string otherwise. Called on save, not on every keystroke.
- [x] **T014** — Unit tests for the category-path helper: dedup,
      case-insensitive prefix filtering, empty input, and
      canonicalization specifically (typing an existing path with
      different casing reuses the stored casing; a genuinely new path is
      stored as typed).

## Phase 3 — Item CRUD: view models

- [x] **T015** — `ItemFormViewModel`: create/edit an `Item`; validates
      required fields (name, category, price, date) and clamps
      `desireToKeep` to 1–5.
- [x] **T016** — Unit tests for `ItemFormViewModel` (valid create, invalid
      create rejected, edit updates `updatedAt`, defaults applied).
- [x] **T017** — `ItemListViewModel`: fetch all items; filter by category
      prefix; sort by desire-to-keep, current value, or purchase date.
- [x] **T018** — Unit tests for `ItemListViewModel` (each sort order,
      filter behavior, empty state).
- [x] **T019** — `ItemDetailViewModel`: load a single item, delete it.
- [x] **T020** — Unit tests for `ItemDetailViewModel`.

## Phase 4 — Item CRUD: views

**Not a separate numbered task, but genuinely foundational**: the
`Theme` abstraction (plan.md's "Future: theming" section — semantic
color/type tokens from `design/tokens.md`, never hardcoded per-view)
lands here, inside T021, since it's the first view built. Worth the same
weight as `TroveSchema.swift` in Phase 1 — every subsequent view in every
later phase depends on this being right, and a wrong shape here is
expensive to unwind once a dozen views are already reading from it
directly rather than through the abstraction.

- [x] **T021** — `CategoryPickerField`: text field + autocomplete
      suggestions, backed by the Phase 2 helper. *Verify: manual check in
      a SwiftUI preview.*

**Pending action item, not blocking, discovered during T021**: Archivo
and IBM Plex (Sans + Mono) aren't in the repo yet, so every screen is
currently rendering on system-font fallback —
`ThemeTypography.customFontsInstalled = false`. Correct size, weight, and
rhythm; wrong character. Both are free (SIL OFL, already license-checked
in design/brief.md), available from Google Fonts. Download the weights
tokens.md specifies (Archivo 600; IBM Plex Sans 400/500/600; IBM Plex
Mono 400/500), get the `.ttf` files into the repo, then have Claude Code
wire up `UIAppFonts` and flip the constant. Worth doing before judging
any Phase 4 screen visually — until then, "looks a little off" may just
be this, not a real design deviation.

- [x] **T022** — `PhotoPickerField`: wraps `PhotosUI.PhotosPicker` for
      multi-photo selection, returns `[Photo]`.
- [x] **T023** — `ItemFormView`: required fields up front, optional
      fields behind a "more details" disclosure. Used for both add and
      edit.
- [x] **T024** — `ItemListView`: list with filter and sort controls, using
      `ItemListViewModel`.
- [x] **T025** — `ItemDetailView`: displays an item, links to edit
      (reuses `ItemFormView`), delete with confirmation.
- [x] **T026** — Manual verification: add an item end-to-end in the
      simulator (quick-add path and full-detail path), edit it, delete
      it.

## Phase 5 — Dashboard

- [x] **T027** — `DashboardViewModel`: total current value (excluding
      un-valued items), count of un-valued items, total spent, delta,
      category breakdown. Scopable, so spec.md's "drill into a category to
      see the same numbers scoped to it" is this same type with a
      `scope`, not a second screen that could drift from it.
- [x] **T028** — Unit tests for `DashboardViewModel`, including the
      un-valued-exclusion behavior specifically. Note that exclusion
      applies to **spend as well as value**: counting what un-valued items
      cost while leaving their worth out understates the gain by exactly
      their purchase price, which can flip a collection that's up into
      reading as a loss. Mutation-verified.
- [x] **T029** — `DashboardView`.
- [x] **T030** — Manual verification: dashboard numbers match a small set
      of manually-entered test items. Every figure checked against an
      independent calculation of the seed data — total, spend, gain,
      un-valued count, and all four category rows with their shares — at
      both the root scope and drilled into Photography.

## Phase 6 — Wishlist CRUD

- [x] **T031** — `WishlistFormViewModel`: create/edit a `WishlistItem`.
      Blank estimated cost is rejected rather than saved as $0, matching
      the item form's purchase price. New entries append to the manual
      order by taking the highest `sortOrder` in use, not by counting
      rows — counting reuses a position after a deletion.
- [x] **T032** — Unit tests for `WishlistFormViewModel`.
- [x] **T033** — `WishlistViewModel`: fetch/list wishlist items, filter by
      category (same matching as `ItemListViewModel`), search by name,
      manual reordering via `sortOrder`. Reordering is offered only
      against the whole list in its own order — a drag on a filtered or
      cost-sorted list would renumber the visible rows and silently
      reshuffle the rest.
- [x] **T034** — Unit tests for `WishlistViewModel`, including the
      category filter, search, and the dense/unique `sortOrder`
      invariant across many moves.
- [x] **T035** — `WishlistFormView`.
- [x] **T036** — `WishlistView`: list with category filter control and
      reordering.
- [x] **T036a** — Wishlist photos, added to scope after Phase 6 and
      before Phase 7. `Photo` gains a second optional inverse
      (`wishlistItem`) alongside `item`, `WishlistItem` gains
      `photos: [Photo]?` (`.cascade`, deliberately unlike
      `plannedSaleItems`' `.nullify`), and `WishlistFormView` reuses the
      same `PhotoPickerField` the item form already uses rather than
      growing a second one. Nothing enforces "one parent, never both" at
      the schema level — SwiftData can't express it — so
      `PhotoOwnershipTests` is what holds the line instead of a comment.
- [x] **T036b** — `RowThumbnail`: the reserved photo slot both list
      screens now use, replacing `ItemRow`'s inline version so the two
      can't drift. Empty rows draw a flat placeholder rather than
      collapsing, per plan.md's standing rule. The claim is checked by
      rendering the view and measuring it, not by eye —
      `RowThumbnailTests` also pins that the thumbnail is the user's
      first photo by `sortOrder`, which a row reading `photos.first`
      would get wrong only intermittently.
- [x] **T036c** — `desireToOwn` and `DesireGauge`, added to scope after
      Phase 6 and before Phase 7, same handling as T036a/T036b above.
      `WishlistItem` gains `desireToOwn` (`Int`, default `2`, clamped
      1–3 in the view model), rendered by a new `DesireGauge` — three
      sheared-parallelogram segments, empty tracks left visible,
      brightness ramping across the filled ones, labeled
      "Someday"/"Soon"/"Next" in the form and detail view and unlabeled
      in list rows. Not a recolored `DesireDial`: see plan.md's
      `DesireGauge` entry for why two distinct controls beat two
      near-identical ones meaning different things. Doing this before
      Phase 7 rather than after means `WishlistDetailView` (T038) gets
      built against the final `WishlistItem` shape instead of being
      revisited.

      Display-only, and `DesireToOwnOrderingTests` pins that from both
      sides: neither sort order consults the rating, and no sort option
      is named for it. Adding a rating to a list and deliberately not
      sorting by it is the unusual choice, so it's the one a later
      change is most likely to "fix".

      The three fill tones are `accentBrassDim`, a perceptual half-mix
      of it with `accentBrass`, and `accentBrass` — held between the
      existing tokens rather than reaching for `accentBrassHover`, which
      is a state token rather than a brightness step. Chosen by
      searching the Oklab model, not by eye. Per CLAUDE.md's
      design-correctness rule they're then measured off pixels sampled
      from the gauge rendered at its 14×10pt row size, not off the
      palette: adjacent tones land 0.109 and 0.108 apart and the dimmest
      sits 0.162 from the empty track, against the 0.06 floor
      `DesireDialColorTests` holds the dial's stops to. A separate guard
      distinguishes "sampled the card instead of the fill" from a
      genuine collapse, since both otherwise report zero. The Oklab
      model now lives once in `TestSupport` and serves both the dial
      (palette tokens) and the gauge (sampled pixels), so their
      thresholds stay comparable rather than drifting as two copies.

## Phase 7 — Wishlist detail and the Sell Plan

`WishlistDetailView` and `SellPlanView` are deliberately separate
screens, not one combined view: the wishlist item's own details lead, and
the Sell Plan — a v1 approximation of a feature that's meant to grow into
something bigger once market data exists — is one tap away via a button,
not shown automatically. See spec.md and plan.md for the reasoning. The
Sell Plan logic itself (T039–T040) is the piece most worth over-testing
regardless of which screen shows it — it's the thing a future
trend-aware version builds on top of directly, and it's also the one
place in the app with real persisted, user-editable state beyond simple
CRUD.

- [x] **T037** — `WishlistDetailViewModel`: load a `WishlistItem`'s own
      fields for display (name, category, estimated cost, notes,
      photos). No ranking or plan logic here.

      Holds the id and re-fetches, like `ItemDetailViewModel` — an entry
      deleted on another device then reads as absent rather than as a
      stale reference, which is the case the guard actually pins. Photo
      ordering, category splitting and the desire-level clamp live here
      rather than in the view: they're correctness rules, not layout.
      Phase 7 lists no separate unit-test task for this view model, but
      CLAUDE.md requires one regardless, so the tests land here — four
      guards mutation-verified (cached load, unsorted photos, unclamped
      level, empty-string notes).
- [x] **T038** — `WishlistDetailView`: plain display of the wishlist
      item's fields, with space reserved in the layout for future
      pricing/trend info, and a single "Find items to sell" button/nav
      link to `SellPlanView`. Photos follow `ItemDetailView`'s
      shrink-the-hero rule, not the list rows' reserved-slot rule — see
      plan.md on why those are two answers to different questions.

      **The "Find items to sell" button is deferred to T041**, the same
      call as T042's deep-links: it would otherwise be a control that
      looks tappable and isn't. Its space sits at the end of the scroll,
      after the market-price block. Everything else on the screen is
      built.

      Three things Design's mock predates, resolved against the newer
      documents rather than the drawing. Its "Priority · Next up" row
      becomes the labeled `DesireGauge` (the brief asks for the gauge
      labeled in the detail view, and a plain row saying the same thing
      in different words invites the two to disagree); it has no photo
      area, so the shrink-the-hero carousel is added; and its Edit and
      Delete toolbar buttons are kept, which is what `delete()` on the
      view model is for — plan.md's "a single button" is about the route
      to the Sell Plan, not the screen's total button count.

      `PhotoCarousel` moved from inside `ItemDetailView` to `Views/
      Shared/` rather than being copied, and tapping a wishlist row now
      opens the item instead of jumping straight to the edit form — the
      same shape as the item list, and what makes this screen reachable
      at all.
- [x] **T039** — `SellPlanViewModel`: given a `WishlistItem`,
      - compute the candidate pool (owned items, `desireToKeep ≤ 3`,
        non-nil `currentValueCents`, sorted ascending by `desireToKeep`,
        tie-break higher current value first);
      - load the existing selection from `plannedSaleItems` — starts
        empty on first visit, **no auto-selection**;
      - expose toggle methods that add/remove a candidate from
        `plannedSaleItems` and persist on every change;
      - expose the selected items' combined current value and the
        wishlist item's `estimatedCostCents` as two separate figures for
        the view to compare, rather than a single pre-computed
        surplus/shortfall value with baked-in framing.
- [x] **T040** — Unit tests for `SellPlanViewModel`: empty candidate pool,
      a tie resolved correctly, un-valued items excluded from the pool,
      the plan starts with nothing selected on first load, toggling a
      candidate updates the persisted selection and the selected-value
      figure, and re-loading after a toggle reflects the persisted
      selection rather than resetting.
      Two decisions the plan didn't cover, both flagged rather than
      folded in silently. A selected item can drift out of the pool —
      raise its desire-to-keep, or clear its value — so the list carries
      anything currently selected even once it stops qualifying;
      otherwise it's stranded, still counted with no row to switch it
      off from. And the colour cue spec.md permits is exposed as a
      boolean (`selectedValueMeetsCost`), not a figure: a tone needs a
      side, not a distance.

      `SellPlanFramingTests` scans the source for surplus/shortfall/
      remaining-style names, the same technique as
      `NoHardcodedColorsTests`. A behavioural test can show what the type
      does; only a scan shows what it declines to offer, and the way that
      framing comes back is someone adding a computed property because it
      reads tidier at the call site.

      **Mutation testing found a false-passing test here**: the
      "persists on every change" checks refetched on the same
      `ModelContext`, which returns objects carrying unsaved changes, so
      they passed with `save()` removed. Now checked through a second
      context over the same container, plus `hasChanges`.
      `makeInMemoryContainer()` in `TestSupport` exists for that.
      `ModelTests`' `itemsSurviveASaveAndRefetch` had the same flaw and
      is fixed alongside — its name made the claim its body didn't test.

- [x] **T041** — `SellPlanView`: selectable candidate list (visually
      distinguishing selected from unselected), the selected total shown
      alongside the estimated cost as two comparable figures. A quiet
      color distinction between "meets or exceeds" and "doesn't" is fine;
      no copy nudging the user to select more ("keep going," "check
      another item," or similar) — this is advisory, not a target to
      complete. Reached via `WishlistDetailView`'s button — no other
      entry point. A per-row shortcut on `WishlistView` was drawn by
      Design, built here, and removed after seeing it: a CTA repeated
      down every row pushes harder toward the Sell Plan than the
      goal-completion framing already cut from the plan screen itself,
      which is the same over-prominence in another form. See spec.md.

      Two of the mock's elements are not built, both flagged rather than
      quietly dropped. **"Mark 3 for sale"** is the sale-tracking action
      spec.md and plan.md both rule out of v1 in as many words, and it
      implies a commit step that doesn't exist — every toggle already
      persists on its own. **"Nothing is listed or sold until you say
      so"** is reassurance about that button; without it, the line
      answers a question the screen never raises while implying listing
      and selling are things this app does. The mock's two-figure card
      is exactly right and is kept as drawn.

      Design's row meta reads "GUITARS · DESIRE 1" beside a dial already
      showing 1 — the same value twice in two notations. The meta line
      carries the category alone, matching `ItemRow`, which pairs a
      category meta line with a separate dial for that reason.

      The affordance deferred from T038 lands here: the detail screen's
      "Find items to sell" button. `SellPlanRoute` is a named type
      rather than a bare `UUID` because the wishlist stack already
      pushes items by id — "open this item" and "open this item's sell
      plan" carry the same value and mean different things.

**Phase 7 complete.** Verified on device end to end: the detail
screen's button reaches the plan, ranking is desire 1→2→3 with the
un-valued item correctly absent, and a selection made on one visit is
still there after leaving and coming back — the
persisted-not-recomputed claim, checked against the store rather than
the screen.

## Phase 8 — Navigation and app shell

- [x] **T042** — Root `TabView` (Dashboard / Items / Wishlist), each tab
      a `NavigationStack`. Once this exists, wire the two deep-links
      deferred from Phase 5: tapping a leaf category in the dashboard's
      breakdown jumps to the Items tab pre-filtered to that category, and
      the "Value →" callout jumps to Items pre-filtered to un-valued
      items. Both need `ItemListViewModel`'s existing `categoryFilter`
      (or an equivalent un-valued flag) set from outside the view itself
      — a cross-tab navigation concern that couldn't exist before this
      task, not new filtering logic.

      **Refinement decided at the Phase 7 review**: "Value →" checks the
      un-valued count first. If exactly one item is un-valued it jumps
      straight to that item's detail screen rather than to a filtered
      list holding one row — fewer taps for the common case, and the
      same destination tapping that row would have reached anyway. Two
      or more still land on the filtered list. See plan.md's
      `DashboardView` entry.

      `AppRouter` carries both, holding `[UUID]` rather than a
      `NavigationPath` so it stays free of SwiftUI per CLAUDE.md. It
      publishes a *request* rather than writing into
      `ItemListViewModel`: navigation asks, the screen decides how to
      show it, and the list clears the request once applied so a later
      return doesn't silently re-narrow a list the user has changed
      since.

      The un-valued filter is the only one with no control of its own on
      the list, so the chip row grows a dismissible "Not yet valued"
      chip while it's on — a filter the user can't see or clear is worse
      than one they can't set. Any category chip, "All" included, also
      steps out of it, so "All" always means all.

      Verified on device: one un-valued item goes straight to that
      item's screen; adding a second sends the same action to the
      filtered list with the chip showing "2 ITEMS · $0 · 2 UNVALUED";
      the leaf-category row lands on Items filtered, popping whatever
      was already pushed there.
- [x] **T043** — Add-item and add-wishlist-item entry points in the
      toolbar of their respective tabs (not buried in a menu).

      Landed as one shared `AddButton` — Design's raised brass disc —
      floating bottom-right on both list screens, which plan.md now
      records as the permanent v1 design rather than a stand-in. Design
      puts that disc in the centre slot of a five-tab bar (Overview ·
      Items · **+** · Wishlist · More); v1 has three tabs and no More,
      so the treatment carries over and the position adapts.

      Built first into each screen's header on a "toolbar" reading of
      this task, then reverted: the header move forced both title blocks
      to be restructured to fit, and bottom-right is easier to reach
      one-handed. The one thing kept from that attempt is the button
      being a single shared component instead of two copies. Both
      headers are back to their pre-T043 shape.

      **List content is uncapped at the bottom on purpose.** No scroll
      margin, no trailing padding on the rows — the add button and the
      system tab bar are *meant* to sit over the last row or two when
      scrolled fully down, because that overlap is what gives iOS 26's
      glass material something to refract. An earlier pass added margin
      to dodge the button, reasoning from T024-era logic that the
      overlap was a bug; plan.md's Navigation section now says
      otherwise, in as many words, so it doesn't get re-fixed.
- [x] **T044** — Manual full click-through: launch → dashboard → add item
      → items list → item detail → wishlist → filter wishlist by
      category → add wishlist item → wishlist detail → "Find items to
      sell" → Sell Plan → toggle a candidate.

      Walked on an iPhone 17 Pro simulator. Every step on the path
      worked, including the pieces that only exist between screens: the
      dashboard's leaf drill-in switches tabs and arrives filtered, both
      lists refetch on return so a dial change made on a detail screen
      shows on the row behind it, the un-valued "Value →" link with
      exactly one candidate lands on that item rather than a list of
      one, per-tab navigation stacks stay independent, and a Sell Plan
      selection survives leaving and re-entering.

      **Found and fixed: the category field dropped every character
      after the first.** `CategoryPickerField` swaps a breadcrumb
      read-out in for the text field once a path is set, and the swap
      condition didn't account for focus. An empty field shows the text
      field — there's no breadcrumb yet — so tapping it focuses that
      directly and never sets `isEditingPath`; the first keystroke made
      the path non-empty, the read-out took over, and SwiftUI tore the
      focused field out mid-word. Typing "Photography/Cameras" left
      "P". That broke the field's whole reason for existing, since
      typing is the only way to make a category that doesn't exist yet
      — the chips can only offer paths already in use.

      The rule is now a tested static, `showsReadOut(isEditingPath:
      isFocused:categoryPath:)`, and a focused field is never swapped
      out. `CategoryPickerFieldTests` types a path one character at a
      time and asserts the field survives each one; mutation-verified by
      dropping `isFocused` from the guard, which fails first at "P" —
      the same character the device stopped at.

      Three more findings, raised at review and approved as fixes:

      - **The active filter chip was off-screen when the Items tab was
        reached from a dashboard drill-in.** The filter applied and the
        chip lit up brass, both past the right edge, so the list looked
        narrowed for no reason a user could see. `ItemListView`'s chip
        row now uses the same `ScrollViewReader`/`scrollTo(anchor:
        .center)` treatment `CategoryPickerField` already had. Scoped to
        deep-links only — a chip the user tapped themselves is already
        where they can see it, so moving it would be motion for nothing.
      - **Wishlist detail printed estimated cost twice**, once as the
        headline and again in the details table to the cent ("$1,000.00"
        under "$1,000"). The row is gone; whole dollars is the app-wide
        convention and the card was already using it. Same reasoning
        already written above that table for why there's no "Priority"
        row.
      - **The tab bar was drawing in the system blue** — the one thing
        on screen not from `tokens.md`. Now tinted `accentBrass`, and
        the three placeholder SF Symbols are replaced by Design's marks
        (`design/icons/`): a tachometer for the dashboard, a 2×2 grid
        for items, and three ramping bars for the wishlist that echo
        `DesireGauge` on purpose — the bars' opacity ramp survives
        template rendering, so they read as the same language as the
        gauges in the rows below them.

      The icons are template-rendered single glyphs, so the tint draws
      both states and there's no selected variant to keep in step.
      `TabIconTests` guards them, because both ways they can break are
      silent and look identical: a misnamed asset draws an empty slot,
      and a lost template intent draws the glyph in its authored black,
      invisible on `background`. Same failure shape as
      `FontRegistrationTests`, so the same treatment. Both checks
      mutation-verified.

## Phase 9 — Empty and loading states

- [x] **T045** — Empty state for the items list: two distinct cases, not
      one. **Truly empty** (no items exist yet) points at the add
      action — an icon, a line like "No gear yet," a way to add. **Empty
      because search or the category filter matched nothing** is a
      different situation needing different words — nudge toward
      clearing the search/filter, not toward adding an item that
      probably already exists.

      Landed as **four** cases, not two. The third was already there in
      ad hoc form (search and category were distinguished from each
      other, just not designed). The fourth was missing entirely: the
      un-valued filter has no case of its own, so emptying it fell
      through to the truly-empty copy. That's reachable, and it's the
      *success* path — value the last item from the dashboard's
      "Value →" callout and the list you're standing in empties. It
      read "Nothing here yet" to someone who had just finished valuing
      their whole collection. Now "Everything has a value".

      Which case applies is `ListEmptyReason`, derived in the view
      models — it's a rule about the data, not layout, same call as
      `ItemDetailViewModel`'s photo sort. Precedence is tested and
      mutation-verified: an empty collection outranks every filter,
      because offering to clear a search that would reveal nothing is a
      dead end.

      Also gone on a first run: the search field, the chips and the
      sort control. Controls for narrowing a list need a list to narrow,
      and a lone "All" chip over a search field over nothing made the
      screen look like it had lost something rather than not started.
- [x] **T046** — Empty state for the wishlist. Same two-case split as
      T045 (truly empty vs. search/filter matched nothing) — unlike
      Items, the filtered-empty case here hasn't been verified at all.

      Three of the four: there's no un-valued filter on a wishlist,
      since nothing on it is owned. Shares `ListEmptyReason` so the two
      screens can't drift on the cases they do share, and shares none of
      the copy — "no gear yet" is the wrong sentence on a screen that
      never holds gear. The never-verified filtered case now has a test
      and was walked on device.
- [x] **T047** — Empty/zero state for the dashboard when there's no data
      yet. Bigger than it looks now that Phase 5 exists: with zero items,
      the category breakdown has nothing to break down, the tick gauge
      (a derived percentage, not decoration, since its Phase 5 rework)
      has nothing to derive a percentage of, and the "Value →" callout
      has nothing to link to. Each needs an explicit answer, not an
      assumption that the normal layout degrades gracefully on its own.

      **All three turned out to be moot at zero items** — the whole
      figure stack is replaced by the empty state, so none of them
      renders. The state that actually degrades is **items with no
      values**, reachable as soon as someone adds their first few pieces
      and hasn't priced them: every derived figure is zero, so the
      screen read "$0" over a breakdown where each row was "$0 · 0%" —
      a collection reported as worthless rather than un-priced, the one
      claim this app is otherwise careful never to make.

      `hasAnyValues` now gates the money-derived parts. Headline reads
      "Not yet known"; ruler, spent/gain card and stacked bar are
      hidden; breakdown rows keep their counts, drop the percentage, and
      say "Not valued" instead of "$0" — decided per row, so a category
      nobody has priced says so even on a dashboard full of figures. The
      callout was the one part already safe, and is unchanged.

      The root empty state points at adding through
      `AppRouter.startAddingItem()`, since the form lives on the Items
      tab. A scoped dashboard gets no action: the user drilled in from a
      row that had items, so an empty one means they've been deleted or
      refiled, and adding wouldn't file anything here.

      **The sample-data seeding is gone**, as its own comment said it
      would be at T045 — a first run now lands on a real empty state
      instead of eight fabricated items.
- [x] **T047a** — New: empty state for `SellPlanView`'s candidate pool.
      Not covered anywhere before this — T040 already handles "empty
      candidate pool" as a tested business-logic case, but no task ever
      specified what the *screen* shows when it happens. Should follow
      the same invitation-to-act voice as the other empty states: name
      what would make an item eligible (desire-to-keep ≤ 3, a current
      value entered) rather than a bare "no candidates."

      Three reasons rather than one, because qualifying takes two things
      and which one is missing decides what the user should go and do.
      The screen's own comment already promised this ("says which, since
      the two have different fixes") and the code had never done it.
      None of the three offers a button: what each asks for happens on
      another screen, and there's no single item to send the user to.
- [x] **T047b** — Decide and document: does v1 need any loading states
      at all? All data is local SwiftData for v1, and local fetches are
      near-instant, so there may be nothing to design here — but that
      should be a stated decision in plan.md, not a silent gap in a
      phase whose own name promises it. Revisit once CloudKit sync
      (Phase 10, currently blocked) can introduce real network latency
      a screen might need to show waiting for.

      **Decision: none, deliberately.** Every read is a synchronous
      fetch against a local store — there's no await, so no window in
      which a spinner could be seen. Written into plan.md as its own
      section, with the Phase 10 trigger: sync introduces a genuine
      unknown-yet state on a new device, where an empty store means "not
      downloaded" rather than "nothing added" — and today those are the
      same screen. The empty states above are what would be wrong.

      **Two review fixes, applied after approval.** "Not yet valued" is
      now the only phrasing for the fact that something has no current
      value — the dashboard's headline and its breakdown rows had each
      invented their own ("Not yet known", "Not valued"), which read
      across screens as three different states. `UnvaluedCopyTests`
      scans the view sources so a fourth can't appear, and checks the
      canonical phrase is still in use, so deleting all four wouldn't
      quietly satisfy it.

      And `SellPlanViewModel.emptyReason`'s precedence is now pinned
      rather than implicit in the order of two `guard`s. The reasons
      overlap: with nothing rated low enough, it's also trivially true
      that nothing rated low enough has a value, so `everythingIsAKeeper`
      and `nothingValued` both describe that collection. Desire wins —
      someone unwilling to part with anything doesn't have a pricing
      problem, and sending them off to value things wouldn't put a row
      on the screen. `SellPlanEmptyReasonTests` covers the overlap the
      way `ListEmptyReasonTests` covers the list screens'.

## Phase 9a — Detail screen chrome

- [x] **T047c** — `DetailOverflowMenu`: one shared circular "..." button
      opening a `Menu` with Edit and Delete, replacing the permanent
      `Edit` `Delete` pair on both detail screens. Delete carries the
      menu's `.destructive` role, which is the only signal a menu row
      has and so isn't decorative.

      Two always-visible words in the nav bar — one of them destructive,
      a thumb-width from the other — read as dated against the rest of
      the app's iOS 26 treatment: the floating `AddButton`, the
      translucent tab bar, the circular back chevron this now sits
      opposite and matches.

      Changes only how Edit and Delete are *reached*. Each screen keeps
      its own edit sheet and its own delete confirmation, including
      `WishlistDetailView`'s alert about the cascade/nullify asymmetry
      ("Anything on its sell plan stays where it is") — verified
      unchanged on device on both screens.

## Phase 10 — Sync and device verification (manual)

**Unblocked as of 2026-08-12** — the Developer Program membership is
renewed and T002 is done, so sync is live and both of these are now
runnable. Both are yours to run: they need real iCloud accounts on real
devices, which is exactly why plan.md's testing strategy leaves them
manual.

- [x] **T048** — Manual: run the app on two simulators (or a simulator
      and a device) signed into the same iCloud account; confirm an item
      added on one appears on the other. Not automated — see plan.md's
      testing strategy.

      Run on a physical device + a simulator. An item added on the
      device appeared on the simulator after signing in and relaunching
      — but it took several minutes, not seconds. Worth treating as real
      evidence, not a hypothetical: this is the exact window `T049a`/
      Phase 12 below exist for. A screen that confidently says "no gear
      yet" during a wait this long would be actively misleading, not
      just imprecise.
- [x] **T049** — Manual: confirm the app behaves reasonably when the
      simulator/device is not signed into iCloud at all. Expectation to
      check against: everything works, nothing mentions iCloud, and no
      error appears — `TroveStore` never asks about the account, so a
      signed-out launch takes the same path as a signed-in one. What it
      *won't* do is tell the user sync isn't happening, which is the open
      question below rather than a bug in this task.

      Confirmed on a simulator never signed into iCloud: normal
      operation throughout, nothing mentions an account, no error
      surfaced anywhere.
- [x] **T049a** — Small, immediate fix for the smaller of the two open
      items below: `ItemFormView`/`WishlistFormView`'s caption currently
      hardcodes "Saves to your library on this device," which is now
      false in the common case. Read the already-existing `TroveStore.mode`
      (no new infrastructure needed) and show accurate copy per mode —
      something like "Saves to your library and syncs across your
      devices" for `.cloudKit`, the original line for `.localOnly`. The
      fuller sync-status *indicator* (a persistent, visible affordance
      showing live status) stays deferred — see plan.md's CloudKit sync
      section — since it needs a real decision about where it lives in a
      three-tab app with no settings screen, and isn't a correctness bug
      the way the empty states are.

      `SaveCaption` maps mode → copy, injected as `\.storageMode` the
      same way `\.theme` is. **Wording deviates from the suggestion
      above, deliberately:** `.cloudKit` means the *container* is
      configured for sync, not that anyone is signed in — `TroveStore`
      never asks, and T049 confirmed a signed-out launch takes the
      identical path. "Syncs across your devices" would therefore be
      false for exactly the people T049 was about. Shipped copy is
      "Saves to your library, iCloud if signed in," which is true in
      both cases; `.localOnly` keeps the original line.

      A width check came out of building it: the caption has no
      `lineLimit`, so copy that outgrows the gutters wraps and silently
      changes the save bar's height. The first wording did, and the test
      caught it before the simulator did. Verified after the fact on
      device — 313pt against a predicted 315pt, so the arithmetic is
      trustworthy. *Verify: 440 tests in 69 suites, plus 5 UI tests. All
      four rules mutation-verified red, including a UI test that catches
      `TroveApp` not injecting the mode at all — which every unit test
      here would happily survive.*

**Resolved.** Both open items below are now scoped: `T049a` above for
the small copy fix, Phase 12 for the larger empty-states work. Turning
sync on made two things due that a container swap shouldn't decide:

- ~~**plan.md's Loading states section comes due.**~~ Now Phase 12.
- ~~**Nothing in the app says sync is off.**~~ Now `T049a` (the honest
  copy) plus a deferred future decision (the fuller indicator).

## Phase 11 — UI smoke test

- [x] **T050** — One `XCUIApplication` test: launch the app, add an item
      through the quick-add flow, confirm it appears in the items list.

      Three tests, not one — the second and third earned their place:

      - **The smoke test itself.** Launch → Items → the floating add
        button → fill name, category and price → save → the row is in
        the list. Mutation-verified by disconnecting the save button's
        action, which fails it with the right message.
      - **`testAppLaunches`**, kept from the placeholder. Costs four
        seconds and distinguishes "the app won't start" from "the add
        flow is broken" when both would otherwise fail together.
      - **Typing a whole category path.** `CategoryPickerFieldTests`
        pins the rule that broke at T044; this pins that the rule is
        still attached to a field a person can type into. Different
        failure modes — only one of them involves a keyboard, and it's
        the one that shipped.

      **Runs against an in-memory store**, via a `-uiTesting` launch
      argument `TroveApp` reads. A UI test whose starting state is
      whatever the last run left behind passes or fails for reasons
      nobody in the test can see. A test-only branch in shipping code is
      worth being uneasy about, so it's one flag, read in one place, that
      can only lose data and never expose it. Isolation confirmed by
      running the suite twice back to back — the smoke test asserts the
      first-run dashboard before adding anything, so persisted data
      would fail the second run.

      **Found on the way: three form fields had no accessibility label.**
      Supplying a `prompt:` to a SwiftUI `TextField` takes the
      placeholder slot and leaves the title unused, so name, category and
      price were reading their example values to VoiceOver — "Leica M6"
      as though it were the field's name. Fixed on all three; it's what
      made them findable from the test, but it was a real defect
      independent of that.

      **Audited the rest, and the pattern was everywhere.** Nine of the
      app's twelve text fields had no accessibility label — the three
      fixed above plus current value, estimated cost, the wishlist's
      name and notes, the search field, and all four optional fields
      behind "more details", which shared one helper. Those last are
      the worst: their placeholders are hints, not names, so a VoiceOver
      user reached the serial-number field and heard "If it has one".
      The search field loses its placeholder the moment anything is
      typed, leaving a field that announces its contents with no name at
      all.

      `testEveryFormFieldIsNamedForVoiceOver` walks both forms — with
      the disclosure open, since that's where four of them hide — and
      asserts every field has a non-empty label. **Checked against the
      live accessibility hierarchy rather than the source**: a regex
      pairing `prompt:` with `.accessibilityLabel` would pass on code
      that has them in different views and fail on anything named a
      different way. This asks the question VoiceOver asks.
      Mutation-verified by dropping the shared helper's label, which
      fails naming all four fields.

## Phase 12 — Sync-aware empty states

Empty states from Phase 9 were all written before sync was live, and
every one of them currently asserts "you own nothing" with total
confidence. That's now wrong in a specific, real window: a device that's
signed in but hasn't finished its *first* CloudKit import yet looks
identical to a device that's genuinely empty, and `T048` just confirmed
that window can run several minutes long. This phase closes that gap —
see plan.md's "Loading states" section for the full design reasoning.

- [x] **T051** — A sync-import-status observable (name TBD by whoever
      builds it) distinguishing "haven't heard from CloudKit yet,"
      "import in progress," and "caught up" — likely via
      `NSPersistentCloudKitContainer`'s event notifications, but verify
      the exact mechanism against the framework rather than assuming;
      this is genuinely new territory for this codebase. Injected the
      same way `TroveStore` already is, so it's fakeable in tests rather
      than requiring a real CloudKit round-trip to test against.

      `SyncMonitor` + `SyncPhase`. **Verified rather than assumed**, with
      a throwaway probe wired into a real launch and read off the console
      (deleted afterwards). Three things it settled:
      - `NSPersistentCloudKitContainer.eventChangedNotification` *does*
        fire for a container SwiftData created. That was the load-bearing
        assumption for the whole phase.
      - Events arrive in pairs — in-flight (`endDate == nil`) then
        finished — and `succeeded` reads `false` on the in-flight one, so
        it means nothing until `endDate` is set.
      - **A fourth state was needed.** On a device with no account, setup
        finishes *failed* and no import event ever follows. Three states
        would have left every signed-out device saying "still catching
        up" forever. `.unavailable` came from that observation.

      Reaching past SwiftData to Core Data's container is a flagged
      layering exception, confined to one function — SwiftData publishes
      nothing about sync progress.
- [x] **T052** — Unit tests for T051, using fake/injected signals rather
      than a real CloudKit container — this status can't be produced by
      a real account in a unit test, so the fake *is* the test surface.

      `SyncEvent` is that surface: the real event type has no public
      initialiser, so the state machine is written against a local struct
      and the mapping kept to one function.
- [x] **T053** — Extend the empty-state reasoning (`ListEmptyReason` or
      a parallel concept) with a `stillSyncing` case: applies when
      CloudKit is active, the initial import hasn't completed, and local
      data currently looks empty. Decide and test its precedence against
      the existing cases — my instinct is it should outrank
      `nothingAdded` (a confident wrong claim is worse than an honest
      uncertain one) but the filtered-empty cases (`searchMatchedNothing`,
      `categoryMatchedNothing`) are less clearly wrong to show even
      mid-sync, since an incomplete search result isn't a new kind of
      lie the way "you own nothing" is. Flag if that reasoning doesn't
      hold up once it's actually built.

      **The conclusion holds; the stated reason doesn't.** "No matches
      for *hasselblad*" mid-import is the same kind of claim as "you own
      nothing," not a lesser one — both assert absence over a collection
      the app hasn't finished receiving, and if the Hasselblad is among
      the items still in flight, both are false. The filtered cases still
      win, for two better reasons: they're feedback on something typed a
      second ago, and replacing that with a message about iCloud leaves
      the user unsure the search even ran; and `categoryMatchedNothing`
      is close to unreachable mid-import anyway, since the chips are
      built from items already fetched — a category can't be offered
      until something in it has arrived.

      Since the claim really is false, though, it doesn't go unqualified:
      the surviving cases get `stillArrivingNote` appended, so the
      narrower claim keeps its context and stops being stated as final.

      One case moved off your list: `everythingIsValued` is treated as a
      whole-collection claim, not a filtered one, so `stillSyncing`
      outranks it. It isn't feedback on a narrowing — it's a *success*
      message, and congratulating someone on a complete set of values
      covering a third of their gear is exactly this phase's failure. The
      Sell Plan goes further still: `stillSyncing` outranks all three of
      its reasons, none of which is user-typed. "Everything's a keeper"
      is as wrong as "nothing to sell yet" when the low-desire items are
      the ones still arriving.
- [x] **T054** — Wire `stillSyncing` into all four places an empty state
      can currently mislead: Items list, Wishlist list, Dashboard, and
      the Sell Plan (which depends on `Item` data existing locally, so
      it inherits the same risk). Copy for this case is necessarily
      different in kind from the others — there's nothing to click, it's
      a "still catching up" message, not an invitation to act — so it
      doesn't need to force-fit the existing voice principle, just avoid
      contradicting it (no apology, no false urgency).

      "Catching up with iCloud" on all four, each naming what's arriving
      in its own screen's terms. No action button — there's nothing to
      press and nothing to fix — which is the one empty state in the app
      without one, and the reason `EmptyStateView.Action` was already
      optional.

      The plumbing was the larger half: `SyncMonitor` is created in
      `TroveApp` from the store's mode, put in the environment, and
      handed down through `ContentView` to the three tab roots, plus the
      two nested screens that can also be empty — the scoped dashboard
      and the Sell Plan pushed from wishlist detail. Both of those are
      easy to miss, so a wiring test reads the source for them: the
      default is `SyncMonitor.notSyncing`, which fails silently by never
      showing the new state at all.

      **The copy promises "it'll appear here as it arrives," and that
      turned out not to be true without more work.** The view models
      fetch on appear and hold an array — they don't observe the store —
      so a screen open through the import window would have sat on
      "Catching up with iCloud," reached `caughtUp`, and switched to "No
      gear yet" over a store that had just filled with two hundred items.
      The same false claim as before, moved later. `SyncMonitor` counts
      landed imports and all four screens refetch on the count, which is
      also why it's a count rather than a flag: a long first import
      arrives in several passes.

      This is narrower than live sync generally — see the note under
      Phase 12's heading.
**Found while building T054, not fixed here.** The app has never
refreshed on remote changes — every screen fetches on appear and holds
its results. T048 saw this directly: the synced item only showed up
*after relaunching*. Phase 12 fixes it only for the case it's about (an
import landing while an empty screen is open); an edit made on another
device while you're looking at the item list still won't appear until
you navigate away and back. Worth its own task, and it wants a decision
about whether view models observe the store rather than fetching, which
is a bigger change than this phase.

- [x] **T055** — Manual: on a device signed into an account with existing
      data elsewhere, confirm the `stillSyncing` state actually appears
      during the real sync window rather than the old false-empty state.
      `T048` already demonstrated the window is long enough to observe
      directly — no need to simulate it.

      **Two checks, and the second is the one that matters more.** I could
      verify the signed-*out* path myself — T051's probe recorded it, and
      it's covered by tests — but not the signed-in one, because signing
      a simulator into iCloud means entering your Apple Account password,
      which isn't mine to type.

      1. *The state appears.* Delete and reinstall on a device signed
         into the account that has data. All four screens should read
         "Catching up with iCloud" rather than "No gear yet" / "Nothing
         tracked yet", and should fill in as items arrive.
      2. *The state goes away when there's nothing to import.* Sign in on
         a device with an account that is **genuinely empty**, and confirm
         the screens settle to "No gear yet" instead of sitting on
         "Catching up with iCloud."

      Check 2 is the falsifiable question in the design. `SyncMonitor`
      treats a *successful setup* as "the mirror is running, data may
      still be coming" and waits for an import event to declare it caught
      up. That's right if `NSPersistentCloudKitContainer` posts an import
      event even when there's nothing to fetch — which I believe it does,
      since it always runs a fetch pass after setup, but couldn't observe
      without an account. If it doesn't, a signed-in user with an empty
      collection sees "Catching up with iCloud" forever, and the first-run
      experience on a new account is the case that breaks. The fix if so
      is small and contained — treat a successful setup with no import
      following within a few seconds as caught up — but it needs a clock,
      so it isn't worth building against a risk that may not exist.

      **Both checks passed.** Reinstalled on a device signed into the
      account holding the data: all four screens read "Catching up with
      iCloud" and filled in as items arrived. On an account with
      genuinely nothing in it, the screens showed "Catching up with
      iCloud" briefly and then settled to "Nothing tracked yet" / "No
      gear yet" as appropriate — so `NSPersistentCloudKitContainer` does
      post an import event with nothing to fetch, and the state can't
      stick. **The risk this task existed to falsify is closed**, and no
      clock is needed.

      The brief appearance on a genuinely empty account is the predicted
      behaviour, not a defect: `SyncMonitor` starts at `.unknown` because
      nothing has been heard from CloudKit yet, which is honest. It
      resolves in the safe direction — an uncertain message replaced by a
      confident one, never the reverse.

## Phase 12a — Pull to refresh

- [x] **T056** — `.refreshable` on `ItemListView`, `WishlistView` and
      `DashboardView`, each calling straight into its own existing
      `load()`. Deliberately not on the detail screens, which already
      refetch by id on appear. See plan.md's CloudKit sync section.

      Works exactly as specified — one modifier per screen, no new fetch
      logic. Confirmed on device: gesture, indicator and action.

      **First reported here as blocked, wrongly, and that's worth
      keeping.** `load()` is synchronous, so a refresh finishes within a
      frame; the spinner was gone before any screenshot could catch it,
      and "no spinner" got read as "no refresh". A `List` was tried as a
      control, appeared to work — it holds its offset for the duration of
      an action — and that seemed to confirm a platform limitation that
      doesn't exist.

      What actually settled it, in order: a `print` inside the action
      (fires on the first pull, in the real `ItemListView`, with a single
      row); a bare `NavigationStack` + `ScrollView` probe outside all of
      this app's chrome (works); the same probe with the hidden toolbar
      and the ZStack/fixed-header shape (works); and finally the action
      slowed to twenty-five seconds, which made the indicator plainly
      visible between the chips and the first row.

      The lesson for next time is the cheap one: instrument the mechanism
      rather than photographing the artefact. A missing spinner and a
      missing action look identical and mean opposite things.

      One real caveat, unrelated to the above: the empty states aren't
      inside a `ScrollView` — they were deliberately moved out at Phase 9
      so they'd centre properly — so there's nothing to pull on a screen
      showing "Catching up with iCloud". Phase 12's import-driven refetch
      covers that screen, so it isn't a gap, but it does mean the gesture
      is unavailable exactly where someone might reach for it.

## Pre-merge review — findings

A `skeptical-reviewer` pass over the whole spec against what shipped,
run before taking the PR out of draft. Its four blocking findings are
fixed; the rest are recorded here rather than dropped.

**Fixed before merge:**

- **A real data-integrity defect: removing a photo while editing orphaned
  the row.** SwiftData's `.cascade` fires when the *parent* is deleted;
  there's no orphan-removal rule for a child dropped from a to-many
  relationship. So reassigning `item.photos` left the removed `Photo` in
  the store with both inverses nil, still holding an
  `@Attribute(.externalStorage)` blob that CloudKit uploads as a
  `CKAsset` and nothing ever collects — invisible, cumulative, synced
  everywhere. `PhotoSelection.orphaned(previous:current:)` plus a delete
  in both form view models; `PhotoRemovalTests` covers both paths and was
  written red first.
- **`plan.md` prescribed copy the test suite rejects** — "Not yet known"
  and "Not valued", both on `UnvaluedCopyTests`'s rejected list since
  T047b unified them. The design document of record was telling the next
  reader to write code that goes red.
- **A comment asserted a Sell Plan entry point that was deliberately
  removed** ("besides the wishlist row's shortcut"), contradicting both
  spec.md and `WishlistView`'s own comment.
- **Two guards in `StillSyncingWiringTests` couldn't fail as claimed** —
  the same bare-`contains` shape that suite's header says it was rewritten
  to avoid. One was satisfiable by a comment; the other by a private
  helper that had stopped being called. Both now structural, along with
  `SaveCaptionWiringTests`, which had the same shape and wasn't flagged.
  All hardened scans share `SourceScan` so the next one starts hardened.

Also fixed, cheaper: `plan.md` describing category filtering as *prefix*
matching when the code is deliberately segment-bounded; `plan.md`
claiming the remote-change problem was "resolved" when it's addressed on
three screens by a manual gesture; the pull-to-refresh limitation being
scoped to `stillSyncing` when it applies to every empty state; two
references to a `Trove/Info.plist` that deliberately doesn't exist; and
`SellPlanFramingTests` guarding only the view model when spec.md's
constraint is about copy on the screen.

**Recorded, not fixed — worth a decision before wide distribution:**

- [ ] **`SyncMonitor` registers its observer after the container is
      built**, so anything posted in that window is lost. If the setup
      pair is missed on a signed-out device, `phase` stays `.unknown` and
      all four screens show "Catching up with iCloud" for the whole
      launch — the bug `.unavailable` exists to prevent, through another
      door. The window is small and T055 saw correct behaviour on real
      devices, so this is theory, not an observed failure.
- [ ] **Signed in, setup succeeds, no network: `.working` forever.** The
      copy says data "is on its way" when nothing is coming. No timeout,
      no reachability check. `SyncMonitor.event(from:)`'s `nil` paths are
      also untested, though they're testable with a hand-built
      `Notification`.
- [ ] **The sell-candidate threshold is restated as a literal in shipping
      copy** ("rated 3 or lower"), independent of
      `DesireLevel.isSellCandidate`, which plan.md insists is the single
      source. Change the rule and the sentence goes quietly false.
- [ ] **Wishlist swipe-delete bypasses the view model and the
      confirmation.** It calls `modelContext.delete` straight from the
      view — business logic in a view, untested — and cascades the photos
      instantly, where the same action from the detail screen sits behind
      an alert explaining the cascade. Swipe-without-confirmation is a
      normal iOS idiom, so this is a consistency and MVVM question rather
      than a defect.
- [ ] **Coverage gaps in the design-correctness guards.** The dial's ramp
      is checked at palette-token level while the gauge's is checked
      against rendered pixels; the two are equivalent today only because
      the arc is an opaque stroke. `EmptyStateMarkTests` checks one system
      symbol of seven. `TabIconTests` hardcodes the three asset names
      rather than reading them from `ContentView`, so renaming one there
      leaves the test green and the tab blank.

---

## Handoff note

Once this file is reviewed and approved (flip the Status field above),
hand it to Claude Code with something like:

> Read CLAUDE.md and specs/001-core-inventory/{spec,plan,tasks}.md, then
> begin implementing starting at T001. For Phase 0 and Phase 1, stop for
> review after each individual task. From Phase 2 onward, stop after each
> phase instead of after each task. When building views from Phase 4
> onward, match the screens in design/screens/ and use the exact values
> in design/tokens.md — implement colors via a semantic Theme abstraction
> (see plan.md's "Future: theming" section), never hardcoded per-view.

The tighter cadence for Phases 0–1 is deliberate: mistakes in project
scaffolding or the data model (a wrong deployment target, a schema that
isn't actually CloudKit-compatible) are cheap to catch immediately and
expensive to unwind once other work is layered on top. Everything from
Phase 2 on is comparatively cheap to fix after the fact, so batching
review by phase is fine there — and from T021 onward you'll be watching
it happen live in the iOS Simulator pane anyway.

## Model and effort per phase

Model/effort isn't something Claude Code sets from reading this file —
it's a manual switch (`/model` or `/effort`) you make yourself at each
phase-boundary checkpoint, since that's already a natural pause point.
This table is the reference for what to switch to at each one:

| Phase | Model / effort | Why |
|---|---|---|
| 0 — Project scaffolding | Opus 5, xhigh | Foundational; a wrong deployment target or project setup mistake is expensive to unwind later. |
| 1 — Data models | Opus 5, xhigh | CloudKit schema constraints are exactly the "gotcha you only know from experience" category — worth the extra effort. |
| 2 — Shared utilities | Sonnet 5, high | Well-specified, mechanical. |
| 3 — Item CRUD: view models | Sonnet 5, high | Well-specified, mechanical. |
| 4 — Item CRUD: views | Sonnet 5, high | Building against a provided screenshot and detailed task description — little for extra "expertise" to add. |
| 5 — Dashboard | Sonnet 5, high | Same as above. |
| 6 — Wishlist CRUD | Sonnet 5, high | Same as above. |
| 7 — Wishlist detail and the Sell Plan | Opus 5, xhigh | The densest logic in the app — persistence, ranking, toggle semantics — and the piece most worth over-testing. |
| 8 — Navigation and app shell | Sonnet 5, high | Mechanical wiring. |
| 9 — Empty and loading states | Sonnet 5, high | Mechanical. |
| 10 — Sync and device verification | Sonnet 5, high | Manual verification steps, not code generation. |
| 11 — UI smoke test | Sonnet 5, high | One straightforward `XCUIApplication` test. |

You're on Pro and a light user otherwise, so there's real headroom for
this — but Claude Code sessions can burn a weekly cap faster than normal
chat, especially at xhigh across a multi-day build. Watch the usage
indicator in Claude Code as you go; if it's tightening faster than
expected partway through, lean harder toward Sonnet for anything short
of Phase 1/Phase 7-level risk rather than treating this table as fixed.

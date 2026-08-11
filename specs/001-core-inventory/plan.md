# Plan: Core Inventory (v1)

**App**: Trove — *Your Gear, Valued*
**Status**: Draft — pending review
**Implements**: spec.md in this directory

## Data model (SwiftData)

Three model types. Two separate CloudKit constraints, easy to conflate —
this plan previously did, and it took until T007 to surface: scalar
properties need *either* to be optional *or* carry a default value, but
**every to-many relationship must be optional regardless of anything
else** — `[Photo]?`, not `[Photo]`, even though an empty array might feel
like a reasonable "default." Nil and empty mean the same thing at the
call site (`photos ?? []`). No `@Attribute(.unique)` anywhere, for the
same general CloudKit-schema-rejects-this reason.

This is no longer just an assertion in this document — `CloudKitSchemaTests.swift`
builds a real `ModelContainer` against a CloudKit `ModelConfiguration`
for the current schema and asserts it validates, with no entitlement,
account, or network required to run it. Every future model or
relationship added to this schema gets checked by `xcodebuild test`
immediately, not discovered later when T002 resumes with real data
already in the store.

### `Item`

| Property | Type | Notes |
|---|---|---|
| `id` | `UUID` | default `UUID()` |
| `name` | `String` | default `""` |
| `categoryPath` | `String` | e.g. `"Photography/Cameras"`, default `""` |
| `serialNumber` | `String?` | |
| `purchasePriceCents` | `Int` | stored as minor units, default `0` — see "Money" below |
| `currencyCode` | `String` | ISO 4217 code, default `"USD"` |
| `purchaseDate` | `Date` | default `.now` |
| `purchaseLocation` | `String?` | |
| `currentValueCents` | `Int?` | nil = "not yet estimated"; see Dashboard below |
| `desireToKeep` | `Int` | default `3`, valid range 1–5 enforced in the view model, not the schema |
| `conditionRawValue` | `String` | stored; raw value of `Condition` enum, default `Condition.excellent.rawValue` |
| `conditionNotes` | `String?` | |
| `notes` | `String?` | |
| `photos` | `[Photo]?` | to-many relationship, see below — optional array, CloudKit requires all relationships to be optional; nil and empty both mean "no photos," read via `photos ?? []` |
| `createdAt` | `Date` | default `.now` |
| `updatedAt` | `Date` | default `.now`, bumped on every edit |
| `plannedForWishlistItems` | `[WishlistItem]?` | inverse of `WishlistItem.plannedSaleItems` — see "Sell Plan" below; optional for the same CloudKit reason |

```swift
enum Condition: String, Codable, CaseIterable {
    case new, excellent, good, fair, broken
}
```

Stored as a raw `String` rather than a native enum attribute — SwiftData
can model enums directly, but keeping it a plain `String` with a Swift-side
wrapper is the more conservative choice for CloudKit schema stability if
we ever add a case later.

**Naming convention for every enum-backed field in this schema**: the
persisted SwiftData attribute takes the `RawValue` suffix
(`conditionRawValue`); the clean, unsuffixed name (`condition`) is a
computed property on `Item` that wraps/unwraps the enum and is what the
rest of the app actually reads and writes. This is deliberate, not
arbitrary — it means the ergonomic name is reserved for the type-safe
accessor, so a view model reaching for `item.condition` gets a `Condition`
back, not a raw string it has to re-parse. The tradeoff: `FetchDescriptor`
predicates and sort descriptors can only see stored properties, so any
future filtering or sorting by condition has to reference
`conditionRawValue` directly, not `condition`. Not a v1 concern — nothing
in `tasks.md` sorts or filters by condition — but worth remembering if
that changes later. Apply this same pattern to any future enum-backed
field without re-deriving it each time.

### `WishlistItem`

| Property | Type | Notes |
|---|---|---|
| `id` | `UUID` | default `UUID()` |
| `name` | `String` | default `""` |
| `categoryPath` | `String` | default `""` |
| `estimatedCostCents` | `Int` | default `0` |
| `currencyCode` | `String` | ISO 4217 code, default `"USD"` |
| `notes` | `String?` | |
| `photos` | `[Photo]?` | to-many relationship, same optionality reason as `Item.photos` |
| `desireToOwn` | `Int` | default `2`, valid range 1–3 enforced in the view model, not the schema — same pattern as `Item.desireToKeep` |
| `sortOrder` | `Int` | default `0`, user-adjustable manual ordering |
| `createdAt` | `Date` | default `.now` |
| `plannedSaleItems` | `[Item]?` | to-many relationship — see "Sell Plan" below; optional for the same CloudKit reason as `Item.photos` |

### `Photo`

| Property | Type | Notes |
|---|---|---|
| `id` | `UUID` | default `UUID()` |
| `imageData` | `Data` | `@Attribute(.externalStorage)` — see below |
| `sourceRawValue` | `String` | stored; raw value of a `PhotoSource` enum (`device`/`fetched`), default `"device"` |
| `sortOrder` | `Int` | default `0` |
| `item` | `Item?` | inverse of `Item.photos` |
| `wishlistItem` | `WishlistItem?` | inverse of `WishlistItem.photos` |

A `Photo` belongs to at most one of `item` or `wishlistItem`, never both —
enforced by which form created it, not a schema-level constraint. Both
relationships being independently optional is what makes one `Photo`
type work for both entities without a shared parent protocol or a
polymorphic relationship SwiftData doesn't really support.

`@Attribute(.externalStorage)` tells SwiftData to store the blob outside
the main store file and hand it to CloudKit as a `CKAsset` rather than
inlining it — the right call for photos, which will otherwise bloat the
local SQLite store and the sync payload. No custom file-management code
needed; this is a built-in SwiftData attribute option.

Same `RawValue`-suffix convention as `Item.condition` above: the
persisted attribute is `sourceRawValue`, and `source: PhotoSource` is the
computed, app-facing accessor on `Photo`.

`source` exists now even though v1 only ever writes `"device"` — no
stock-photo fetching happens yet (see spec non-goals). It's a cheap,
additive field today and expensive to retrofit once real photos exist in
CloudKit; adding it now means a future fetch feature is a UI/network
addition, not a schema migration.

### Money

Storing money as `Int` cents rather than `Decimal` or `Double` avoids
floating-point rounding entirely and keeps CloudKit's schema simple.
Formatting to a currency string happens at the view-model/view boundary
via `Decimal(cents) / 100` and `.formatted(.currency(code:))`.

**v1 only ever writes `"USD"`** into `currencyCode` and the UI has no
currency picker — you're US-based and don't need it. But the field exists
on the model now rather than being added later: CloudKit schema changes
after real user data exists are the kind of thing worth avoiding, and a
purely additive field with a default costs nothing today. If a future
version wants to support other countries, that's then a UI/formatting
change (add a currency picker, format using the stored code) rather than
a data migration.

## Categories: no separate entity

Per spec, category paths are free-typed strings, not a managed table. For
autocomplete, the view model fetches the distinct `categoryPath` values
currently in use (across both `Item` and `WishlistItem`) and offers them
as suggestions, filtered by what the user has typed so far. At the
personal-collection scale this app is built for (tens to low hundreds of
items), fetching everything and deduplicating in memory is simpler than
maintaining a separate `Category` table and is fast enough not to matter.
If the collection ever grows large enough for this to be a real cost, or
if we want a proper tree-browsing UI later, promoting categories to a
real entity is a clean, isolated migration — flagging it here so it's a
known future option, not a surprise.

Filtering the item list by category matches on path *prefix*, so
filtering by `"Photography"` also shows `Photography/Cameras` and
`Photography/Lenses`.

**Case handling**: matching is case-insensitive throughout (search-as-
you-type in the picker, list filtering), always on — no setting for this,
since it's not a real user preference, just correct behavior. To avoid
the taxonomy accumulating near-duplicates like `"Photography/Cameras"`
and `"photography/Cameras"` as separate-looking entries, casing is
*canonicalized at write time*: when a category path is saved, the helper
checks existing distinct paths case-insensitively; if one matches, the
existing casing is reused rather than storing what the user just typed.
First-used casing for a given path wins, permanently, with no user-facing
mechanism to change it later (renaming a category path across all items
that use it is a reasonable future feature, not v1).

## Architecture (MVVM)

View models own `ModelContext`, not `@Query`. SwiftUI's `@Query` property
wrapper is convenient but lives in the view layer and isn't something we
can unit-test outside a rendered view; per the constitution's testing
requirement, fetch logic needs to be testable independent of SwiftUI. So:

- Views hold a view model (`@State private var viewModel: SomeViewModel`,
  since `@Observable` is used rather than the older `ObservableObject`).
- View models hold a `ModelContext` (injected at creation) and perform
  fetches via `FetchDescriptor`, not `@Query`.
- Tests construct an in-memory `ModelContainer`
  (`ModelConfiguration(isStoredInMemoryOnly: true)`) and hand its context
  to the view model under test — this is the standard approach for testing
  SwiftData-backed code and gives real persistence semantics without
  CloudKit or disk I/O.

### Screens / view models

- **`DashboardView`** / `DashboardViewModel` — total current value, total
  spent, delta; category breakdown, drillable — tapping a category with
  subcategories narrows the same view to that scope (Photography opens
  onto Cameras/Lenses), not a new screen per level. A leaf category
  (nothing beneath it) is currently a dead end; **planned for T042/T043**
  once the real `TabView` exists: tapping a leaf jumps to the Items tab
  pre-filtered to that category. Same underlying capability the deferred
  "Value →" action needs (jumping to Items filtered to un-valued items,
  see the design-deviations note in tasks.md's Phase 5 section) — build
  both together once cross-tab navigation is real, not against the
  temporary two-tab stand-in Phase 5 uses to unblock testing.
- **`ItemListView`** / `ItemListViewModel` — browse/filter/sort/search
  owned items. Search matches name or serial number, case-insensitive,
  combined with (not replacing) the category filter — both narrow the
  same result set.
- **`ItemDetailView`** / `ItemDetailViewModel` — view a single item, edit,
  delete.
- **`ItemFormView`** / `ItemFormViewModel` — shared add/edit form. Required
  fields (name, category, price, date) up front; everything else
  (serial, location, current value, condition, photos, notes) behind a
  "more details" disclosure, per the spec's quick-add requirement.
- **`WishlistView`** / `WishlistViewModel` — browse/filter/search
  wishlist items, filterable by category (same prefix/case-insensitive
  matching as `ItemListViewModel`) and searchable by name, same
  treatment as the item list. Each row includes a "See sell plan" button
  that jumps straight to that item's `SellPlanView`, bypassing
  `WishlistDetailView` — a shortcut, not a replacement for the main flow.
- **`WishlistDetailView`** / `WishlistDetailViewModel` — a plain view of
  the wishlist item itself: name, category, estimated cost, notes. Space
  is reserved in the layout for live pricing/trend info (a future
  feature — see spec non-goals), even though nothing populates it in v1.
  Includes a single button ("Find items to sell") that pushes to
  `SellPlanView`. This screen does **not** show the ranked list by
  default — see the note under `SellPlanView` for why.
- **`SellPlanView`** / `SellPlanViewModel` — "Sell Plan" is the formalized
  name for what was internally "sell-candidate ranking"; the name (and
  the idea that this deserves to be a persisted, concrete thing rather
  than a disposable computed list) came out of designing the screens in
  Claude Design, and it's a real improvement worth keeping. Reached via
  `WishlistDetailView`'s button or `WishlistView`'s per-row shortcut, not
  shown automatically anywhere.

  **This is advisory, not goal-directed** — worth stating plainly because
  it shapes the behavior below. The feature answers "is this a
  reasonable time to buy, and what would make the most sense to sell if
  I did," not "prove you can fully cover this purchase from a sale."
  An earlier version of this spec had the plan auto-select candidates
  until their value met the wishlist item's cost, and displayed the
  result as a "surplus or shortfall" — that framing implicitly told the
  user they were supposed to close the gap, which was never the intent
  and got caught only after seeing it rendered in Claude Design. Behavior:

  - Candidate pool: owned items where `DesireLevel.isSellCandidate` is
    true (built at T023 specifically to mirror this `desireToKeep ≤ 3`
    threshold in exactly one place, so the item list/detail UI and this
    filter can't independently drift) and a non-nil `currentValueCents`,
    ranked ascending by `desireToKeep` (tie-break: higher current value
    first). Use the shared predicate here, don't re-derive the threshold.
  - **Selection is persisted**, via `WishlistItem.plannedSaleItems`, not
    recomputed fresh each time — but it **starts empty** and stays that
    way until the user actively selects something. No auto-selection, no
    target to reach.
  - The user can freely toggle any candidate in or out; each toggle
    updates `plannedSaleItems` right away — no separate save step,
    consistent with the app's low-friction bar.
  - **A selected item that stops qualifying stays in the list** (decided
    at T039): raising an item's desire-to-keep above the threshold, or
    clearing its current value, removes it from the candidate pool but
    not from a plan that already selected it. Dropping it would strand
    the selection — still counted in the total, with no row to switch it
    off from. Eligibility governs what can be *added*, not what stays
    visible once chosen.
  - Display the selected items' combined value alongside the wishlist
    item's estimated cost as two comparable figures. A quiet color
    distinction (e.g. one tone once selected value meets or exceeds the
    cost, another when it doesn't) is fine — but no accompanying copy
    that nudges toward covering the gap ("keep going," "check another
    item," or similar). The comparison is information the user
    interprets themselves, not an instruction.
  - **v1 ranks by desire-to-keep only** — it does not (and can't yet)
    factor in market-value trend. The full feature described in the
    spec — surfacing an item because its desire-to-keep is low *and*
    its resale value is currently trending high, at a moment when the
    wishlist item itself is trending favorably to buy — depends on live
    market data, explicitly out of scope until that data source exists
    (see spec non-goals). This view is the scaffolding that feature
    plugs into later: the ranking algorithm gains a trend signal, the
    selection/persistence mechanics don't need to change shape.
  - **Explicitly not in v1**: marking a planned item as actually sold,
    removing it from inventory, or any transaction/sale-tracking. The
    Sell Plan is a decision-support tool, not a sales ledger — a natural
    future feature, deliberately excluded now to keep this screen simple.
- **`WishlistFormView`** / `WishlistFormViewModel` — add/edit wishlist
  item, including `PhotoPickerField` — same shared component `ItemFormView`
  uses, now bound to `WishlistItem.photos` instead of `Item.photos` — and
  an editable, labeled `DesireGauge` for `desireToOwn`.
- **`DesireGauge`** — the wishlist counterpart to `DesireDial`, and
  deliberately *not* the same control. Three parallelogram segments
  (slight consistent shear, flat fill, hard edges — no gradient, per the
  design brief's flat/graphic constraint) in a horizontal row, filled
  left to right by `desireToOwn`. Unfilled segments stay visible as dim
  empty tracks, so it reads as a scale with a reading on it rather than
  a tally of marks. The three filled tones ramp within the gauge —
  segment 1 dimmest brass, 2 medium, 3 brightest — so count and
  brightness reinforce each other and the brightest tone appears only at
  "Next". Labeled ("Someday"/"Soon"/"Next") in the form and detail
  screen, unlabeled in list rows.

  Why not reuse `DesireDial`: the dial's rust→moss sweep encodes a
  keep/sell axis, which has no meaning for something you don't own yet —
  a "1" on a wishlist means low priority, not "get rid of this." Two
  near-identical dials meaning structurally different things would read
  worse than two clearly different controls. Per `CLAUDE.md`'s
  design-correctness rule, the three fill states need a test asserting
  they're perceptually distinguishable at their *rendered row size*,
  validated against sampled pixels — the same Oklab approach used for the
  dial's ramp, not an eyeball check.
- **`CategoryPickerField`** — shared component (text field + autocomplete
  suggestion list), used by both item and wishlist forms.
- **`PhotoPickerField`** — wraps `PhotosUI.PhotosPicker` for multi-photo
  selection, shared between `ItemFormView` and `WishlistFormView`. Device
  photos only in v1 — see "Future: stock photos" below.

### Navigation

`TabView` with three tabs — **Dashboard**, **Items**, **Wishlist** — each
a `NavigationStack`. A prominent add button is available from Items and
Wishlist tabs (toolbar, not buried in a menu), consistent with the
quick-add requirement.

**Design's build includes a fourth "More" tab; v1 does not.** Confirmed
with Design: it's a layout-balance placeholder for the four-tab bar, not
a screen that was ever designed — no intended destination, not even a
loose one. Deliberately not built now: a tab leading nowhere is worse
than no tab at all. Add it when an actual feature needs it (`004-themes`
in `specs/ROADMAP.md` is the most likely trigger, given the theming and
multi-currency groundwork already in this schema), not preemptively.

**List screens keep their header fixed.** On `ItemListView` (and
`WishlistView` once built, for the same reason), the title, any summary
line, and the category filter chip row stay in place — only the row
content beneath scrolls independently. Found at T025 review: everything
was originally one scrolling unit, so the filter chips disappeared along
with the list on scroll. Apply this as a standing layout rule for any
future list-style screen, not a one-off fix.

**List rows always reserve a thumbnail slot; detail screens don't.**
Two different answers to "no photo exists" for two different scales.
List rows (`ItemListView`, `WishlistView`) show a small, consistent
placeholder — matching the flat/graphic icon language from the design
brief, not a blank grey box — when an item has no photo, so every row in
a scroll keeps the same width and rhythm regardless of which items
happen to have images. A row that's sometimes text-only and sometimes
has a thumbnail reads as visually broken in a scrolling list. Detail
screens are the opposite call, already made at T025: `ItemDetailView`'s
hero shrinks from 240pt to 108pt rather than showing an empty photo area
at full size, because a large empty rectangle is a worse look than a
smaller one — the placeholder-vs-shrink tradeoff flips once the empty
space gets big enough to dominate the screen. Both are deliberate; don't
unify them just because they're both "no photo" states.

## Dashboard value calculation

All three headline figures — current value, total spent, and the delta
between them — must scope over the same set of items, or the delta is
silently wrong. Items where `currentValueCents` hasn't been set are
**excluded from all three**, not just current value: an un-valued item's
`purchasePriceCents` counted in "spent" while its worth is excluded from
"current value" understates the gain (or overstates the loss) by exactly
that item's purchase price. The dashboard shows a separate count/link
("3 items not yet valued") alongside the three figures, so the user
knows they're a floor over the valued subset, not a complete picture —
and the callout explaining this should say so explicitly (something like
"left out of every figure above"), not imply only one figure is affected.

## CloudKit sync

`ModelContainer` is configured with a CloudKit database
(`.automatic`/private database — no sharing in v1, per spec's
single-user non-goal). Practical requirements this imposes, beyond the
schema constraints already reflected in the data model above:

- Requires an iCloud capability + CloudKit container added in the Xcode
  project's Signing & Capabilities.
- Works in development against your own iCloud account on the free tier;
  no paid Apple Developer Program membership needed for this stage.
  (You'll need that membership regardless once we're preparing an actual
  App Store submission — not a v1 blocker.)
- The app should handle "user not signed into iCloud" gracefully (data
  still works locally; sync just doesn't happen) rather than treating it
  as an error state.

## Testing strategy

- View model unit tests use an in-memory `ModelContainer`, per above —
  covering creation, editing, deletion, filtering, sorting, and the
  sell-candidate ranking calculation.
- No CloudKit-specific automated tests in v1 (CloudKit sync itself isn't
  practical to unit test); sync is verified manually by running on two
  simulators/devices signed into the same iCloud account.
- One or two `XCUIApplication` smoke tests covering the add-item flow
  end-to-end, per the constitution's allowance for XCTest in UI
  automation specifically.

## File structure

```
Trove.xcodeproj/     PBXFileSystemSynchronizedRootGroup — files under
                      Trove/ join the target automatically, no project
                      file edits needed for new files (see T001)
Config/
  Info.plist          Must live outside Trove/ — anything inside the
                      synchronized Trove/ folder is also copied as a
                      bundle resource, which collides with the
                      auto-generated Info.plist if it's placed there
                      (found at T022)
Trove/
  App/                TroveApp.swift, ModelContainer setup
  Fonts/              Archivo, IBM Plex Sans/Mono .ttf files — also
                      auto-included as bundle resources via the
                      synchronized group, which is what UIAppFonts needs
  Models/             Item.swift, WishlistItem.swift, Photo.swift, Condition.swift
  ViewModels/          one file per view model listed above
  Views/
    Dashboard/
    Items/
    Wishlist/
    Shared/            CategoryPickerField, PhotoPickerField, formatting helpers
  Extensions/          Int+Currency.swift, Image+Data.swift (the flagged
                      UIKit bridge — see Platform section in CLAUDE.md), etc.
TroveTests/           Swift Testing, one file per view model
TroveUITests/         XCTest smoke tests
```

This diverges from the original plan in two small, discovered-during-
implementation ways (`Config/` existing at all, `Fonts/` as a subfolder)
— both are corrections to reality, not scope changes.

## Resolved decisions

1. **Currency**: USD only in v1, UI-level. `currencyCode` field exists on
   both models now (default `"USD"`) so adding real multi-currency support
   later is additive, not a migration.
2. **Un-valued items**: excluded from the dashboard's current-value total,
   shown as a separate count instead of falling back to purchase price.
3. **Sell-candidate tie-break**: higher current value first.

## Future: theming

Not v1 scope, but worth anchoring now since it affects how color gets
implemented from the start. Light mode and additional curated color
themes (see spec.md non-goals) mean colors should never be hardcoded
per-view — implement them as a `Theme` abstraction (a `Color` extension
or a small `AppTheme` type exposing named semantic colors: `background`,
`surface`, `textPrimary`, `accentPrimary`, etc., matching the tokens in
design/brief.md) from the very first view built, not refactored in
later. A future theme picker becomes "swap which `Theme` instance is
active," not a rewrite. Where a user's selected theme eventually gets
stored is a small addition (`UserDefaults` or a lightweight settings
model) outside the `Item`/`WishlistItem` schema — not a v1 task.

## Known v1 limitation: no Dynamic Type

`ThemeTypography`'s sizes are fixed points, matching tokens.md's scale
exactly — deliberate, but it means text doesn't grow with the user's
system text-size setting, a real accessibility gap for anyone who relies
on that. Not being fixed now because addressing it properly means
rethinking the type scale as Dynamic-Type-relative rather than swapping
one file, which is more scope than this pass warrants. Worth a real
accessibility pass before wide distribution — flagging here so it isn't
forgotten — a known, deliberate v1 trade-off rather than an oversight,
in the same spirit as `TroveApp`'s fatalError-on-store-failure decision
(discussed with Claude Code at T009, not otherwise written down here).

## Future: stock photos

Not v1 scope. The idea: instead of only photographing an item yourself,
fetch a representative stock photo — most useful for wishlist items,
which you don't own yet and can't photograph. Deferred because it's a
real third-party dependency (an image-search API) with licensing terms
to honor (attribution, typically), not something to bolt on casually.
`Photo.source` exists now specifically so this is additive later: a
fetch feature adds a network call and a picker UI, not a schema change
or a migration of existing photos.

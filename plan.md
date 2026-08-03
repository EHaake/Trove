# Plan: Core Inventory (v1)

**App**: Trove — *Your Gear, Valued*
**Status**: Draft — pending review
**Implements**: spec.md in this directory

## Data model (SwiftData)

Three model types. All properties are optional or carry a default value —
required for SwiftData's CloudKit sync (`ModelConfiguration` with a
CloudKit database rejects schemas that don't meet this). No
`@Attribute(.unique)` anywhere, for the same reason.

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
| `condition` | `String` | raw value of `Condition` enum, default `Condition.excellent.rawValue` |
| `conditionNotes` | `String?` | |
| `notes` | `String?` | |
| `photos` | `[Photo]` | to-many relationship, see below |
| `createdAt` | `Date` | default `.now` |
| `updatedAt` | `Date` | default `.now`, bumped on every edit |

```swift
enum Condition: String, Codable, CaseIterable {
    case new, excellent, good, fair, broken
}
```

Stored as a raw `String` rather than a native enum attribute — SwiftData
can model enums directly, but keeping it a plain `String` with a Swift-side
wrapper is the more conservative choice for CloudKit schema stability if
we ever add a case later. `condition` is exposed to the rest of the app via
a computed property on `Item` that wraps/unwraps the enum.

### `WishlistItem`

| Property | Type | Notes |
|---|---|---|
| `id` | `UUID` | default `UUID()` |
| `name` | `String` | default `""` |
| `categoryPath` | `String` | default `""` |
| `estimatedCostCents` | `Int` | default `0` |
| `currencyCode` | `String` | ISO 4217 code, default `"USD"` |
| `notes` | `String?` | |
| `sortOrder` | `Int` | default `0`, user-adjustable manual ordering |
| `createdAt` | `Date` | default `.now` |

### `Photo`

| Property | Type | Notes |
|---|---|---|
| `id` | `UUID` | default `UUID()` |
| `imageData` | `Data` | `@Attribute(.externalStorage)` — see below |
| `sortOrder` | `Int` | default `0` |
| `item` | `Item?` | inverse of `Item.photos` |

`@Attribute(.externalStorage)` tells SwiftData to store the blob outside
the main store file and hand it to CloudKit as a `CKAsset` rather than
inlining it — the right call for photos, which will otherwise bloat the
local SQLite store and the sync payload. No custom file-management code
needed; this is a built-in SwiftData attribute option.

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
  spent, delta; category breakdown.
- **`ItemListView`** / `ItemListViewModel` — browse/filter/sort owned
  items.
- **`ItemDetailView`** / `ItemDetailViewModel` — view a single item, edit,
  delete.
- **`ItemFormView`** / `ItemFormViewModel` — shared add/edit form. Required
  fields (name, category, price, date) up front; everything else
  (serial, location, current value, condition, photos, notes) behind a
  "more details" disclosure, per the spec's quick-add requirement.
- **`WishlistView`** / `WishlistViewModel` — browse wishlist items.
- **`WishlistDetailView`** / `WishlistDetailViewModel` — the sell-candidate
  ranking: owned items with `desireToKeep` ≤ 3, sorted ascending by
  `desireToKeep` (tie-break: higher current value first, so the most
  "fundable" low-attachment item surfaces first), with a running
  cumulative total against the wishlist item's estimated cost. **v1 ranks
  by desire-to-keep only** — it does not (and can't yet) factor in
  market-value trend. The full "killer feature" described in the spec —
  surfacing an item because its desire-to-keep is low *and* its resale
  value is currently trending high — depends on live market data, which
  is explicitly out of scope until that data source exists (see spec
  non-goals). This view is the scaffolding that feature will plug into
  later: the ranking algorithm gains a trend signal, the UI doesn't need
  to change shape.
- **`WishlistFormView`** / `WishlistFormViewModel` — add/edit wishlist
  item.
- **`CategoryPickerField`** — shared component (text field + autocomplete
  suggestion list), used by both item and wishlist forms.
- **`PhotoPickerField`** — wraps `PhotosUI.PhotosPicker` for multi-photo
  selection.

### Navigation

`TabView` with three tabs — **Dashboard**, **Items**, **Wishlist** — each
a `NavigationStack`. A prominent add button is available from Items and
Wishlist tabs (toolbar, not buried in a menu), consistent with the
quick-add requirement.

## Dashboard value calculation

Items where `currentValueCents` hasn't been set are **excluded** from the
"total current value" figure — the dashboard shows that total alongside a
separate count/link ("3 items not yet valued") so the user knows the
total is a floor, not a complete picture, and has an obvious next action.
"Total spent" always includes every item, since `purchasePriceCents` is
required at creation.

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
Trove/
  App/            TroveApp.swift, ModelContainer setup
  Models/         Item.swift, WishlistItem.swift, Photo.swift, Condition.swift
  ViewModels/      one file per view model listed above
  Views/
    Dashboard/
    Items/
    Wishlist/
    Shared/        CategoryPickerField, PhotoPickerField, formatting helpers
  Extensions/      Int+Currency.swift, etc.
TroveTests/         Swift Testing, one file per view model
TroveUITests/       XCTest smoke tests
```

## Resolved decisions

1. **Currency**: USD only in v1, UI-level. `currencyCode` field exists on
   both models now (default `"USD"`) so adding real multi-currency support
   later is additive, not a migration.
2. **Un-valued items**: excluded from the dashboard's current-value total,
   shown as a separate count instead of falling back to purchase price.
3. **Sell-candidate tie-break**: higher current value first.

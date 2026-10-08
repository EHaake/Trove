# 020 — Purchase Provenance — Technical Plan

**Status**: **Final** (2026-09-30) — signed off by the `skeptical-reviewer`
(one review, one re-review, the last blocking item fixed by the orchestrator
per the loop cap); the P-items and readings are decisions as of this sign-off,
R1/R2/R3/R6 by the person (spec Decision 10). **As built** (close-out,
2026-10-06) is the last section of this file; nothing above it was rewritten
at the close-out.

Drafted by the `sdd-planner` (Opus 5.5, high effort — per `CLAUDE.md`'s model
policy, Opus profile, the plan-and-tasks draft row at the implementation tier
with no override, the trial continuing from `018`) against the approved
`spec.md` (Approved 2026-09-29) and `main` at `637a950`. **Implementation
starts only after `018-system-design-language` merges**; the branch is brought
up to date with `main` first, and every task that touches a file `018` changes
says so and re-reads it rather than trusting this plan's line numbers. The
P-items become decisions on plan approval, as in earlier specs; the planning
choices below (Q1–Q9) likewise. Six readings are under **Readings for
sign-off** — none is a product fork the plan decides, each is stated so the
reviewer can overturn it, and each goes to the person in plain words at the
pause named.

## Amendment A — the condition row is one scrolling row (2026-10-01)

At the Phase 1 pause the person saw the six chips wrap on an iPhone 17 Pro and
decided: six grades, **one row that scrolls sideways, never two** (spec Decision
11). The `skeptical-reviewer`'s decision review chose the shape below; §6, G14,
§10's section (b) and T006 are rewritten in place, each marked. What it replaced:
a `FlowLayout` row and a G14 built around the wrap. `ConditionField` copies the
scrolling chip row `CategoryPickerField` already ships in the same form
(`CategoryPickerField.swift:76-95`, and `ItemListView.categoryChips`): the house
pattern, with the scroll-to-selected the spec now asks for. Options rejected: a
row clipped at the gutter (the cut-off chip is then an accident of width);
negative padding or `.contentMargins` (the gutter in two places); `ViewThatFits`
(a `ScrollView` whose content fits already does not scroll, and six chips never
fit an iPhone). `FlowLayout.swift` has no user after this and is deleted.

## Context

Spec 020 adds one optional fact to every owned item (**Bought**: new or used),
its twin on every wishlist entry (**Looking for**), and one grade to the
condition scale (**Very Good**, between Excellent and Good). The wishlist
preference is the one thing that is *read*: it chooses which Reverb listings a
wanted item's figure is drawn from and prefills the purchase sheet.

The footprint: **three new synced optional fields** (`Item.boughtRawValue`,
`Item.conditionRefinement`, `WishlistItem.lookingForRawValue`), **one local
field** (`MarketFigureRecord.isNewStockOnly`), one condition case, three new
production files (`NewOrUsed`, `NewOrUsedCopy`, the shared chip components),
the three forms and their view models, the purchase sheet's four hosts, the two
detail pages, the two Copy paths, the market subject and its wording, the CSV
(both lists, both directions) and the PDF. No new service, no network call, no
`.pbxproj` edit, no constitution amendment.

**Two earlier rules change, and each takes a pointer, never a silent edit.**
`002`'s plan (`specs/002-live-market-value/plan.md:193`) pins the condition
buckets "pairwise-disjoint", and `MarketFigureComputationTests.theConditionBucketsAreDisjointAndNonEmpty`
guards it; spec Decision 6 makes Very Good and Good overlap on `very-good` on
purpose, so the guard is **rewritten to pin the new rule** (exactly one overlap,
exactly there) and `002`'s line gains a "Superseded in part by `020`" pointer.
`015`'s purchase sheet is pinned as four fields by
`WishlistPurchaseWiringTests.theFiveElementsAppearInTheSpecsOrder`; this spec
adds a fifth field, so that test is rewritten to the new order — the `014` Q12
treatment of a guard whose meaning changed.

## Readings for sign-off (not open questions — the plan builds to each)

- **R1 — The item page says "Bought new" on the row that already says
  "Bought".** `ItemDetailView.details` already labels the purchase *date*
  "Bought" (`ItemDetailView.swift:470`). A second row reading "Bought | New"
  would put the word twice in one table, and "Bought new" is not a label/value
  pair. So that one row's **label** becomes `Bought new` / `Bought used` when
  recorded and stays `Bought` when not: "BOUGHT NEW · Mar 3, 2024". It sits with
  the date and the place, not with the condition (Design), and when not recorded
  the page is exactly today's (P3). **Decided by the person, 2026-09-29, at the
  spec-conformance questions** (spec Decision 10).
- **R2 — The wanted item's page gains a `Looking for | New` row** in its
  Details table, after `Added`, omitted when not recorded — the table's own
  label/value shape, which is the nearest honest form of the spec's "Looking for
  new". **Decided by the person, 2026-09-29** (spec Decision 10).
- **R3 — A New preference changes the words "used listings" and nothing
  else.** `MarketCopy` has two wanted lines that say "used listings" (the
  withheld sentence and the all-years line); both read "new listings" for a
  figure read from new stock. The withheld reading's *second* sentence — "The
  lowest used asking price on Reverb is $1,100." — is Reverb's catalog-wide
  used-low figure, stays true whatever the preference, and the spec's rule names
  "used listings" only, so it is kept. **Kept by the person's decision,
  2026-09-29** (spec Decision 10): it says "used" plainly and tells them a used
  one is available.
- **R4 — An older copy of the app shows a Very Good item as Good.** Plan Q2's
  storage is what keeps the grade from being reset (P4); its visible cost on a
  device that has not updated is that the item reads **Good** there (its nearest
  known grade) rather than Excellent, which is what a naïve raw value would fall
  back to. One edge is stated rather than solved: if the older device moves the
  item off Good and back to Good before this device saves it, it reads Very Good
  again here. Phase 1 pause (Very Good lands there), and `DECISIONS.md`.
- **R5 — Changing Looking for changes the figure at the next refresh, as
  changing an owned item's condition does** (the spec's own rule). Until then
  the section shows the last figure *with the words that figure was read under*
  (Q4) — never "new listings" over a used-listings figure. The history is not
  cleared, exactly as a condition change doesn't clear it, so a row's trend arrow
  may compare across the change once. Phase 3 pause.
- **R6 — The PDF matches the page: the date field's label carries new/used.**
  The PDF already has a "Bought" field holding the purchase date
  (`ExportSchema.swift:273`), so a second "Bought — New" field would repeat the
  label. **Decided by the person, 2026-09-29** (spec Decision 10): as on the item
  page (R1), that one field's **label** becomes `Bought new` / `Bought used`
  when recorded and stays `Bought` when not — `Bought used 2024-03-03`. No new
  PDF field for items; the wishlist PDF still gains its `Looking for` field.

## Proposed at planning — approved on plan approval unless overturned

### The spec's P-items, resolved

- **P1 — tapping the selected chip clears it.** One pure rule,
  `NewOrUsed.selection(afterTapping:current:)` (§2), called by the one shared
  field component (§6) on all three screens, so the rule exists once and is unit
  tested. Guards G7, G20.
- **P2 — Copy carries the fact.** `ItemListViewModel.duplicate(id:)` passes
  `bought: original.bought`; `WishlistViewModel.duplicate(id:)` passes
  `lookingFor: original.lookingFor` (§5). G13.
- **P3 — the page is silent when not recorded.** R1 and R2: the item's date row
  reads exactly as today; the wanted page's row is filtered out by the table's
  existing empty-value filter. G16.
- **P4 — an older app neither crashes on nor erases the new data.** Two
  different mechanisms, and only one is testable here:
  - **Bought and Looking for** are new CloudKit fields an older app does not
    know. Whether its edits leave them intact depends on the mirroring exporting
    only the fields that app changed — Apple's additive-schema behaviour, and
    exactly the claim `009` recorded as unverified ("whether an app older than
    `009` editing a row keeps fields it doesn't know", `specs/SYNC-CHECKS.md`
    3.1). **No test in `TroveTests` can reach it.** The plan does nothing extra
    for these fields and marks the claim **needing verification**: two new steps
    in `specs/SYNC-CHECKS.md` (§10), run by the person with an older build on a
    second device.
  - **Very Good** is different: the older app *does* know `conditionRawValue`,
    reads an unknown grade as Excellent (`Condition(rawValue:) ?? .excellent`,
    `Item.swift:122`) and writes its form's condition back on every save
    (`ItemFormViewModel.swift:126`). A raw value `very good` would therefore be
    reset to `excellent` by any edit on that device — the spec forbids exactly
    this. Q2 stores Very Good so the older app reads and writes back `good`, and
    **that is testable**: a frozen replica of the pre-020 read/write path in
    `ModelTests` (G3) goes red under the naïve storage.
- **P5 — Very Good is written `very good`.** It is the case's raw value (Q3), so
  the CSV writes it the way it writes every grade and import reads it back in any
  case through the existing `Condition(rawValue: field.lowercased())`. G6, G17.
- **P6 — the preference prefills the purchase sheet.**
  `PurchaseFormViewModel.init(estimatedCostCents:lookingFor:now:)` seeds `bought`
  from it; the four hosts pass their entry's `lookingFor` (§4). G11.

### Planning choices (Q1–Q9)

- **Q1. One `NewOrUsed` type for both facts, stored as an optional raw
  `String`.** `Condition`'s convention (`001`: raw storage for CloudKit schema
  stability). A shared type rather than two enums because it has two real
  callers today with identical values and identical CSV spelling; nil is "not
  recorded" everywhere, never a third case (Decision 2, the non-goals' "either").
- **Q2. Very Good is stored as Good plus a refinement** (P4). The more complex
  of the two shapes, chosen because the simpler one fails a spec requirement on
  data on disk — the one place backward compatibility with ourselves binds.
  `conditionRawValue` keeps holding one of the five grades an older app knows;
  a new optional `conditionRefinement` holds `"very good"` beside `"good"` and is
  nil otherwise. **One consequence the rest of the plan designs around**:
  `Item.conditionRawValue` is no longer `condition.rawValue` for one grade, so
  every production read of it goes through `condition` (the export snapshot is
  the only one today, `ExportSchema.swift:174`, and T001 fixes it).
- **Q3. `case veryGood = "very good"`** — a raw value with a space. It is what
  the CSV writes (P5), what `ImportSchema.condition(from:)` already matches after
  lowercasing, and what every existing display site's `rawValue.capitalized`
  turns into **Very Good** (`ItemFormView:390`, `PurchaseFormView:272`,
  `ItemDetailView:468`, `ExportSchema:282`). The simpler choice over adding a
  `displayName`: four sites stay untouched and G2 pins the expression's output
  for every case.
- **Q4. The wanted subject carries the preference, and the figure records what
  it was read from.** `MarketSubject.wanted` gains an associated
  `lookingFor: NewOrUsed?`; `MarketFigureRecord` gains `isNewStockOnly`, written
  by the refresher, so the section's words describe the figure *shown* — the
  precedent is `yearFilter`, recorded for exactly this reason (`002` P21,
  `MarketLocalModels.swift:56`). The more general of two shapes (the other: read
  the words off the live preference), chosen because the other says "new
  listings" over a used-listings figure for up to an hour after a change (R5).
- **Q5. Three small shared chip components**, one file (§6): `ChoiceChip` (the
  capsule, extracted verbatim from `ItemFormView.conditionChip`, which
  `PurchaseFormView` already carries a copy of), `ConditionField` (two callers)
  and `NewOrUsedField` (three callers). Earned by the callers, and it is what
  makes "the Bought chips **match** the condition chips exactly" structural rather
  than a thing to eyeball.
- **Q6. Import policy for the new columns is the house policy**: blank → not
  recorded, silent; `new`/`used` in any case → the value; anything else → not
  recorded, **counted** as a default — the `Reverb Product ID`/`Year` split.
  Wider leniency is `021`'s (spec).
- **Q7. The shipped CSV widths grow**: `itemSchemaBoundaries` gains `18` (the
  layout `006`–`019` wrote), `wishlistSchemaBoundaries` gains `9` (`002`–`019`).
  Both are released layouts, which is the file's own rule for adding a width.
- **Q8. `PurchaseFormViewModel`'s `lookingFor:` is a required parameter**, not a
  defaulted one, so no host can seed the sheet without deciding what it passes
  (G11's cross-host test is the behavioural net; the signature is the cheap one).
  The export records' new fields, by contrast, are `var … = nil` so the dozens of
  test fixtures building `ItemExportRecord` compile unchanged; both production
  builders pass them explicitly and the round trip (G17) catches either missing.
- **Q9. "The narrowest supported width" is 375 pt** — iPhone SE (2nd/3rd gen)
  and 12/13 mini, the narrowest iPhones iOS 26 runs on — so the chip row is
  measured at 375 − 2 × `screenGutter` (24) = **327 pt**, or narrower if the
  implementer finds either form nests the field inside extra padding. The device
  list is an assumption T014 checks against the simulator runtimes installed.

---

## Layout and files

New production files (synchronized folders — no `.pbxproj` edit; if the build
cannot see one, stop and flag): `Trove/Models/NewOrUsed.swift`,
`Trove/Models/NewOrUsedCopy.swift`, `Trove/Views/Shared/ChoiceChips.swift`.

Changed: `Condition.swift`, `Item.swift`, `WishlistItem.swift`, `Purchase.swift`,
`WishlistPurchaseStore.swift` (§1, §4); `Market/MarketFigure.swift`,
`MarketRefresher.swift`, `MarketLocalModels.swift`, `MarketLocalStore.swift`,
`MarketIndex.swift`, `Models/MarketCopy.swift`, `Views/Market/MarketSection.swift`
(§3); `ItemFormViewModel`, `PurchaseFormViewModel`, `WishlistFormViewModel`,
`WishlistViewModel`, `WishlistDetailViewModel`, `SellPlanViewModel`,
`PlansViewModel`, `ItemListViewModel` (§3–§5, §8); `ItemFormView`,
`PurchaseFormView`, `WishlistFormView`, `ItemDetailView`, `WishlistDetailView`
(§6, §7); `Export/ExportSchema.swift`, `Import/ImportSchema.swift` (§8, §9);
`docs/csv-reference.md`, `docs/samples/items-full.csv`, `docs/samples/wishlist.csv`,
`docs/samples/README.md`.

**Files `018` changes that this plan touches** — re-read after the sync, never
from this plan's line numbers: `ItemListViewModel.swift` (T005, T011),
`PlansViewModel.swift` (T004 — modified in `018`'s working tree at planning),
`ExportWiringTests.swift` (T011, only if it goes red). `ThemeTypography.swift`
is also changing under `018`; T006's chip measurement reads it, which is why the
measurement is taken after the sync and never estimated here.

New test files: `NewOrUsedCopyTests`, `ConditionFieldLayoutTests`,
`ProvenanceWiringTests`. Extended: `ModelTests`, `CloudKitSchemaTests` (comment),
`MarketFigureComputationTests`, `MarketRefresherTests`, `MarketLocalStoreTests`,
`MarketLocalSchemaTests`, `MarketIndexTests`, `MarketCopyTests`,
`MarketWiringTests`, `ItemFormViewModelTests`, `PurchaseFormViewModelTests`,
`WishlistPurchaseStoreTests`, `WishlistDetailViewModelTests` (the cross-host
seed test), `WishlistFormViewModelTests`, `ItemDuplicationTests`,
`WishlistDuplicationTests`, `ItemSaleStoreTests`, `WishlistPurchaseWiringTests`,
`ExportSchemaTests`, `ImportSchemaTests`, `DocsSampleTests`, `TroveUITests`.

---

## 1. The two facts and Very Good on the model (foundational)

```swift
/// 020: bought new or used — and, on a wanted entry, which the person is
/// looking for. Stored optional everywhere: nil is "not recorded", never a
/// third value (spec Decisions 2, 3). Never inferred (Decision 4).
nonisolated enum NewOrUsed: String, CaseIterable, Sendable {
    case new
    case used
}
```

`Condition` gains `case veryGood = "very good"` **between `excellent` and
`good`** — declaration order is `allCases` order, which is the order both chip
rows draw (criterion 10). Its doc comment's "if a case is ever added" sentence
gains what `020` did about it (Q2).

`Item`:

```swift
/// Backing store for `condition` — one of the five grades an app older than
/// 020 knows. **Not** `condition.rawValue` for Very Good: read `condition`.
var conditionRawValue: String = Condition.excellent.rawValue

/// 020 (plan Q2, spec P4): "very good" beside a `conditionRawValue` of
/// "good", nil otherwise. An older app never sees it, reads Good, and writes
/// Good back, so its edits cannot reset the grade.
var conditionRefinement: String?

/// 020: `NewOrUsed.rawValue`, or nil — not recorded. Every item that
/// predates 020 reads nil (Decision 3).
var boughtRawValue: String?

var condition: Condition {
    get { Self.condition(raw: conditionRawValue, refinement: conditionRefinement) }
    set { (conditionRawValue, conditionRefinement) = Self.storage(for: newValue) }
}

var bought: NewOrUsed? {
    get { boughtRawValue.flatMap(NewOrUsed.init(rawValue:)) }
    set { boughtRawValue = newValue?.rawValue }
}

/// The storage rule, both directions — the one place it is written.
static func storage(for condition: Condition) -> (raw: String, refinement: String?)
static func condition(raw: String, refinement: String?) -> Condition
```

`storage(for: .veryGood)` is `("good", "very good")`; every other case is
`(rawValue, nil)`. `condition(raw:refinement:)` is `Condition(rawValue: raw) ??
.excellent` (today's fallback, unchanged), refined to `.veryGood` **only when the
base is `.good` and the refinement is exactly `Condition.veryGood.rawValue`** —
so an older app that moves the item to Fair is read as Fair whatever refinement
is left behind, and an unknown refinement over Good reads Good. `Item.init` gains `bought: NewOrUsed? = nil`
after `year`, and sets the condition through `storage(for:)` rather than writing
`conditionRawValue` directly.

`WishlistItem` gains `var lookingForRawValue: String?` (declared without an
initializer, as `boughtDate` is), `var lookingFor: NewOrUsed?` over it, and an
init parameter `lookingFor: NewOrUsed? = nil`.

Two changes forced by the new case in the same task, so the tree never builds
wrong: `MarketConditionMap.reverbSlugs` gains `.veryGood: ["very-good"]` (the
switch is exhaustive — criterion 12; `.good` stays `["very-good", "good"]`,
Decision 6), and `ItemExportRecord.init(item:)` reads
`item.condition.rawValue` instead of `item.conditionRawValue` (Q2) — and
`ItemExportRecord.conditionRawValue` gains a doc comment saying it holds
`condition.rawValue` (so `"very good"` for Very Good), **not**
`Item.conditionRawValue`, so nobody "fixes" the snapshot back to the stored field.

**The CloudKit claim and its test.** All three fields are optional, carry no
unique constraint and are therefore additive to the store in the field;
`CloudKitSchemaTests.schemaMeetsCloudKitRequirements` already builds the real
schema, so T001 proves the claim is checked by making one field
`@Attribute(.unique)` and watching it go red (criterion 28, G1).

**Testable claims** (`ModelTests`, persisted assertions on a second
`ModelContext`): the storage rule per case (G2 — `EnumBackedPropertyTests`'
`conditionRoundTripsThroughItsRawValue` asserts `conditionRawValue ==
condition.rawValue`, which is now false for one case by design, so it is
**rewritten** to assert each case's stored pair against a **literal tuple** —
`.veryGood` → `("good", "very good")`, every other case → `(rawValue, nil)` —
never against `Item.storage(for:)` itself, plus the read-back; and a leg that an
unknown refinement over Good reads Good); every
case's `rawValue.capitalized` is `New, Excellent, Very Good, Good, Fair, Broken`
in that order (G2); the older-app replica (G3); a fresh item and wish read nil,
a row built with only pre-020 fields reads nil and its old grade (criteria 5, 11,
20 at the model level — the on-disk upgrade is T014's), and all three fields
survive a save (G4).

## 2. Copy and the clear-on-tap rule

`NewOrUsed` gains the P1 rule:

```swift
/// P1: tapping the chip already selected clears the field; any other tap selects.
static func selection(afterTapping tapped: NewOrUsed, current: NewOrUsed?) -> NewOrUsed? {
    current == tapped ? nil : tapped
}
```

`NewOrUsedCopy` (`nonisolated enum`, `PurchaseCopy`'s shape and rules, pinned
whole by `NewOrUsedCopyTests`): `boughtLabel` ("Bought"), `lookingForLabel`
("Looking for"), `chip(_:)` ("New" / "Used"), and
`detailDateRowLabel(bought:)` — "Bought" when nil, "Bought new" / "Bought used"
otherwise (R1). The CSV headers stay in `ExportSchema`, which is the schema's one
home. Form labels go through `.monoLabel()`, which uppercases, so the spec's
**BOUGHT** and **LOOKING FOR** are these strings rendered. G7.

## 3. The wanted item's figure follows Looking for

```swift
nonisolated enum MarketSubject: Sendable, Equatable {
    case owned(condition: Condition)
    /// 020 (Decision 9): new → new stock only; used or not recorded → everything
    /// that is not new stock, exactly today's figure.
    case wanted(lookingFor: NewOrUsed?)

    var readsNewStockOnly: Bool { self == .wanted(lookingFor: .new) }
}
```

`MarketConditionMap.counts` for `.wanted` is derived from the subject's own
predicate — `subject.readsNewStockOnly ? newStockSlugs.contains(slug) :
!newStockSlugs.contains(slug)` — so "New means new stock only" is one rule in
one place, read by both the counting and the recorded flag. `newStockSlugs` is
`brand-new` and `b-stock` — the spec's "brand new and B-stock".

`MarketRefresher.targets(in:)` and `currentTarget(for:)` build
`.wanted(lookingFor: item.lookingFor)`. **`currentTarget` is the one that
decides the figure**: `refresh` computes over `current.subject`, the post-hop
re-read, never the caller's target — so a preference changed while a fetch is in
flight is honoured, and the subject `WishlistDetailViewModel` passes at its two
target sites (`:432`, `:524`) is superseded. Those two sites are updated for
honesty, but **no view-model test can catch them passing the wrong subject**, and
none is written that pretends to; the behaviour is guarded at the refresher.

`MarketLocalStore.record(_:product:for:newStockOnly:)` gains
`newStockOnly: Bool = false`, written to the new
`MarketFigureRecord.isNewStockOnly: Bool = false` (local store, lightweight
migration, `MarketLocalSchemaTests`' allowlist gains the name). The refresher —
the only production writer of a wanted reading — passes
`current.subject.readsNewStockOnly`; the default keeps every owned caller and
fixture unchanged. `MarketSnapshotValue` carries `isNewStockOnly` and gains:

```swift
/// Which listings the section's words should name for this figure (Q4).
func listingBasis(isWanted: Bool) -> MarketCopy.ListingBasis {
    isWanted ? (isNewStockOnly ? .new : .used) : .inCondition
}
```

`MarketCopy` gains `enum ListingBasis { case inCondition, used, new }`;
`withheld(usedLowCents:wanted:)` and `allYearsFallback(year:wanted:)` take
`basis:` instead of `wanted:`, with `withheldWantedNew = "Too few new listings to
say."` and "Too few \(year) new listings — all years shown." beside today's two
wanted strings (R3). `MarketSection`'s two call sites pass
`figure.listingBasis(isWanted: isWanted)`. Every other `wanted:` function
(`valueStepTitle`, `useAmount`, `yourValue`) is untouched.
`MarketVocabularyTests` must stay green unedited.

The strings are `MarketCopyTests`' and the basis mapping is `MarketIndexTests'`;
that `MarketSection` passes *the figure's* basis into them is a view-body fact no
view-model test reaches, so G9's source scan pins it — and per the constitution
that scan is the honest limit of unit coverage: **the "new listings" wording is
untested at the view layer.** T014's probe observes the recorded basis on a live
refresh; nothing automated observes the words on screen.

**Testable claims**: G8 (counting per preference; nil and `.used` identical to
the pre-020 wanted rule — the existing wanted computation tests re-spelled with
`lookingFor: nil` staying green *is* Decision 9's evidence, plus one leg over the
`listings-126161` fixtures asserting nil, `.used` give the same reading); G9
(targets and the re-read carry the preference; the flag is recorded; the basis
maps; the strings).

## 4. The forms and the purchase sheet's hosts (view models)

- `ItemFormViewModel`: `var bought: NewOrUsed?` — nil on a new form, populated
  from `item.bought` on edit, written by `save()`. No validation case (Decision
  3). Pattern: its own `condition` field.
- `WishlistFormViewModel`: `var lookingFor: NewOrUsed?`, the same three lines.
- `Purchase` gains `var bought: NewOrUsed?`. `PurchaseFormViewModel` gains
  `var bought: NewOrUsed?` and its init becomes
  `init(estimatedCostCents: Int, lookingFor: NewOrUsed?, now: …)`, seeding
  `bought = lookingFor` (P6); `purchase()` carries it. `WishlistPurchaseStore.markBought`
  passes `bought: purchase.bought` to `Item.init`.
- The four hosts — `WishlistViewModel.makePurchaseFormViewModel(for:)`,
  `WishlistDetailViewModel` and `SellPlanViewModel`'s `makePurchaseFormViewModel()`,
  `PlansViewModel.makePurchaseFormViewModel(for:)` — pass their entry's
  `lookingFor` (`wanted.lookingFor`, `item?.lookingFor`,
  `wishlistItem?.lookingFor`, `entries[row.id]?.lookingFor`). The
  `PurchaseFormView` preview gains `lookingFor: nil`.

**Testable claims**: G10 (criteria 1–4, the view-model half), G11 (the seed
from each preference, change and clear before `purchase()`, the store carrying
it, and `everyHostSeedsThePurchaseSheetIdentically` extended so the four hosts
agree on `bought` for an entry looking for used — fixture value `.used`, never
nil, which is the default a broken host would produce), G12.

## 5. Copy, sale and return

`ItemListViewModel.duplicate(id:)` adds `bought: original.bought`;
`WishlistViewModel.duplicate(id:)` adds `lookingFor: original.lookingFor` (P2).
Selling and returning need **no code**: `ItemSaleStore.markSold` and
`returnToCollection` write the four sale fields and never the new ones, and
criterion 9 is pinned by a test so a future edit that clears them goes red. G13.

## 6. The chips and the three forms

`Trove/Views/Shared/ChoiceChips.swift`:

```swift
/// One selectable capsule — `ItemFormView.conditionChip`, extracted verbatim:
/// size, stroke, selected tint, the `contentShape` fix (009 T014a), and the
/// selected trait that VoiceOver and the UI tests read.
struct ChoiceChip: View { let title: String; let isSelected: Bool; let action: () -> Void }

/// The condition row: a mono label over ONE sideways-scrolling row of one chip
/// per case (spec Decision 11, Amendment A) — `CategoryPickerField`'s row, copied:
/// ScrollViewReader { ScrollView(.horizontal, showsIndicators: false) {
///   HStack(spacing: Self.chipSpacing) { ChoiceChip(…).id(condition) } }
///   .scrollClipDisabled()
///   .onAppear { proxy.scrollTo(selection, anchor: .center) } }   // no animation
struct ConditionField: View { static let chipSpacing: CGFloat = 8; let label: String; @Binding var selection: Condition }

/// Bought / Looking for: a mono label over two chips in an `HStack(spacing: 8)`
/// (two need no wrapping). Tapping goes through `NewOrUsed.selection(afterTapping:current:)`.
/// Each chip is identified "<identifier>.new" / "<identifier>.used" — the
/// condition row has a "New" chip too, so a label cannot address it. The field is
/// an accessibility container labelled with its field label, so VoiceOver
/// announces "Bought" before the two words it shares with the condition row.
struct NewOrUsedField: View { let label: String; let identifier: String; @Binding var selection: NewOrUsed? }
```

`ItemFormView` and `PurchaseFormView` replace their private `conditionChip`
copies with `ConditionField` (keeping `PurchaseFormView`'s `conditionField`
property name, which `WishlistPurchaseWiringTests` anchors on). Placement:

- **Item form** (inside More details, where Condition lives): `NewOrUsedField(label:
  NewOrUsedCopy.boughtLabel, identifier: "bought", …)` directly **above** the
  condition row, so the two chip rows sit together and Condition keeps its notes
  beneath it.
- **Purchase sheet**: a `boughtField` between `boughtFromField` and
  `conditionField` — the same adjacency.
- **Wishlist form**: a `lookingForField` (`identifier: "lookingFor"`) directly
  after `desireField`.

**The row (Amendment A).** Its frame stays inside the gutter: at offset 0 the
first chip lines up with the label and with the Bought row above it.
`.scrollClipDisabled()` lets chips draw through the gutter to the screen edge,
and because `chipSpacing` (8) is less than `screenGutter` (24) a chip is always
visible in the gutter on any side that has more to scroll to — the spec's "chip
cut off at the edge", with the field knowing nothing of the gutter. Both forms
pad their inner `VStack`, not the `ScrollView`, so the nearest clip is the screen
or sheet edge. The row scrolls to the selected chip on appear only, never on a
selection change. If leg (iv) below goes red with `onAppear`, the routine
fallback inside T006 is an initial `ScrollPosition(id:anchor:)` state — no new
decision. `FlowLayout.swift` is deleted with its last user; `design/tokens.md`'s
Condition row is rewritten and says Decision 11 supersedes the wrapped chips in
`design/screens/Trove Item Form.png`.

**Criterion 18, guarded in three places** (Amendment A — replaces the wrap's
measured legs (a)–(c)):

- **Unit, `ConditionFieldLayoutTests`** — chips rendered alone with
  `ImageRenderer` under a real theme, never the `ScrollView` (a static render
  cannot observe scrolling): **(b)** each of the six `ChoiceChip`s is at least
  its title's rendered width plus the two 14 pt paddings — none squeezed;
  **(d)** `ConditionField.chipSpacing` is less than the theme's `screenGutter` —
  the premise of the peek arithmetic, not its look. Recorded, not asserted: each
  chip's width, the six-chip total with spacing, and that total against 327, 354
  and 392 pt. (The wrap's legs (a) and (c) lose their job: a scroll view reaches
  any chip at any width.)
- **UI, `testTheConditionRowIsOneScrollingRowAndOpensOnTheSelectedGrade`** (item
  form; builds its own item, no seed change): **(i)** with More details open all
  six chips exist with equal `frame.minY` and height — one row; **(ii)** `Broken`
  is **not** hittable before any gesture — the row overflows, so it is neither
  squeezed nor trivially wide; **(iii)** after `swipeLeft()` on a chip `Broken`
  is hittable, taps, and reads `isSelected`; **(iv)** save, reopen the edit form,
  More details: before any gesture `Broken.isHittable` and its frame lies inside
  the window. `isHittable` and `frame` are read **before** any `tap()`, since
  `tap()` may scroll the element into view by itself.
- **UI, `testThePurchaseSheetsConditionRowIsOneScrollingRow`**: legs (i)–(iii) on
  the Mark as bought sheet.
- **Scan, `ProvenanceWiringTests`**: both forms compose `ConditionField(` exactly
  once and draw no `Capsule()`; `ChoiceChips.swift` carries
  `.scrollClipDisabled()`. No scan for `ScrollView(.horizontal` (the UI test
  reaches that behaviour) and none for "no `FlowLayout(`" (the type is deleted;
  the compiler is the guard).

**Stated untested**: the *look* of the peek (the `.scrollClipDisabled()` scan
pins a spelling — per `CLAUDE.md` that is untested; it stays with eyes at the
Phase 3 walkthrough and T014(b)); anything at 375 pt (the UI suite runs on the
pinned iPhone 18 Pro only — reachability at the narrowest width is by
construction plus T014(b)); scroll-to-selected on the sheet for a non-default
grade (the sheet always seeds Excellent — if that ever changes, leg (iv) is owed
there); Dynamic Type sizes; a finger starting in the 24 pt gutter (the peeking
part of a chip is outside the scroll view's bounds, as on the category row).

## 7. The two pages

- `ItemDetailView.details`: the date row's label becomes
  `NewOrUsedCopy.detailDateRowLabel(bought: item.bought)` (R1).
- `WishlistDetailView.details`: a third row
  `(NewOrUsedCopy.lookingForLabel, item.lookingFor.map(NewOrUsedCopy.chip) ?? "", false)`
  after `Added`; the table's existing `.filter { !$0.value.isEmpty }` is the
  silence (R2, P3).

The words are `NewOrUsedCopyTests`'; that each page passes *its item's* field
into them is a view-body fact no view-model test reaches (the rows are built in
the view), so a scan pins it — and per the constitution, that scan is the honest
limit of unit coverage here; the UI test (§10) observes the row.

## 8. CSV, templates and import

- `ItemExportRecord` gains `var bought: NewOrUsed? = nil`, `WishlistExportRecord`
  `var lookingFor: NewOrUsed? = nil` (Q8), each filled by its `init(item:)`.
- `ExportSchema.itemHeaders` appends `"Bought"`; `wishlistHeaders` appends
  `"Looking For"`; the rows append `record.bought?.rawValue ?? ""` /
  `record.lookingFor?.rawValue ?? ""`. `itemSchemaBoundaries = [12, 14, 18]`,
  `wishlistSchemaBoundaries = [7, 9]` (Q7). The Settings templates are built from
  these arrays and follow by construction (criterion 16, pinned by literal).
- `ImportSchema.newOrUsed(from:)` → `NewOrUsed(rawValue: field.lowercased())`;
  both previews read their new column with Q6's policy. `ImportSchema.condition(from:)`
  already accepts `very good` in any case once the case exists (its "five known
  raw values" doc comment becomes six).
- The commits: `ItemListViewModel.confirmImport` passes `bought: record.bought`;
  `WishlistViewModel`'s import commit passes `lookingFor: record.lookingFor`.

**Testable claims** (G17): headers pinned by literal; a row per value and blank;
Very Good written `very good`; `NEW`, `Used`, `Very Good`, `VERY GOOD` parse;
unreadable counted, blank silent; an 18-column items file and a 9-column wishlist
file import with every row not recorded; the 12- and 14-column files still import
(existing tests, unedited); the end-to-end round trip — export, write, parse,
preview, commit, refetch on a second context — restores every Bought value,
Looking for value and Very Good grade (criteria 13–16, 25). Fixture values must
differ from the defaults a broken path produces (`015`'s lesson): at least one
`.used`, one `.new` and one nil in every round trip.

## 9. PDF

`PDFEntry.init(record: ItemExportRecord)` labels its existing purchase-date
field `NewOrUsedCopy.detailDateRowLabel(bought: record.bought)` — `Bought new` /
`Bought used` when recorded, `Bought` when not — the same function the item
page's date row uses, so page and PDF cannot drift (R6); no new item field. The
Condition field already prints
`rawValue.capitalized` → **Very Good**. `init(record: WishlistExportRecord)`
appends `Looking for` after `Desire to own` when recorded. Omitted when nil, as
empty condition notes are. G18 (criteria 17, 26; `ExportSchemaTests:343`'s
labels literal reads `Bought used` in the date field's place for a recorded
fixture and is unchanged for a nil one).

## 10. UI tests, the device pass and the sync checks

UI tests (`TroveUITests`; `-uiTesting`, **no seed change** — each test sets the
fact through the form, so every existing test keeps its starting state):

- `testBoughtIsSetClearedAndShownOnTheItemsPage`: add an item via the form with
  More details open → neither `bought.new` nor `bought.used` is selected; tap
  Used → selected; save; the page's date row reads "Bought used"; edit → Used
  selected; tap Used → neither selected; save → the row reads "Bought".
  Mutations: `NewOrUsedField` writing `tapped` unconditionally → the clear leg
  red; the page row back to the literal "Bought" → red.
- `testLookingForPrefillsThePurchaseSheet` (`-seedSellPlan`): edit the seeded
  Summicron, tap `lookingFor.used`, save → its page shows "Looking for" / "Used";
  swipe Buy → `bought.used` is selected; tap `bought.new`; confirm → the new
  item's page reads "Bought new". Mutation: one host seeding `lookingFor: nil`
  → red.

`scripts/verify.sh ui` twice back to back at Phase 3's end.

**Device pass** (T014, `general-purpose` agents — the implementer has no
simulator tools), dispatched as **four separate sections, each given only its
own section and returning a pass/fail list**; any failure goes to the
`sdd-implementer` as a diagnosis bundle and is logged as a sub-lettered task:
(a) **the upgrade on a persistent store** — build and install `main`, add two
items (one Good, one New) and a wanted entry, then install this branch over it
and confirm each opens not recorded, grades unchanged (criteria 5, 11, 20: the
lightweight migration of three additive optional fields, which no in-memory
test observes); (b) the condition row on **iPhone SE (3rd generation)** in both
appearances — one line, a chip cut off at the screen edge, sliding to Broken, a
Broken item reopening with Broken in view (criterion 18's visual half,
Amendment A); (c) **the
market probe** — a temporary file probe inside `MarketLocalStore.record`
logging `newStockOnly` and the reading's count, exercised on **two freshly
matched wanted entries, one set to New and one to Used** (a fresh match has no
figure, so the refresher's freshness window — `MarketRefresher.swift:53-55`
returns `.stillFresh` within the hour — never intervenes; remove-and-rematch
works equally), removed before the suites run (instrument the mechanism, not
the screen); (d) relaunch persistence. Chip selected state is G20's (the UI
tests read `isSelected`), not the pass's. **The person's steps**: Accessibility
Inspector over the three fields and the two page rows at the **Phase 3 pause**,
and the sync checks below.

**`specs/SYNC-CHECKS.md` gains two steps** under Part 3 (B on the older build),
drafted here so the close-out copies them: *"3.x — An older app editing an item
keeps Bought, Looking for and Very Good. Do: on A, set an item to Bought used and
Very Good, and a wanted item to Looking for new; on B, edit each one's notes and
save. You should see: on A, all three still set. On B, the item reads Good."*
and *"3.y — Bought, Looking for and Very Good reach the other device"* (both on
the new build — criterion 27).

## 11. Docs and close-out

`docs/csv-reference.md`: row 19 `Bought` and wishlist row 10 `Looking For`
(format, blank, unreadable per Q6), the Condition row's six words with
`very good`'s space, and the kept-exceptions paragraph naming the 18- and
9-column layouts. `docs/samples/items-full.csv` and `wishlist.csv` gain the
column (a mix of `new`, `used` and — in `wishlist.csv` — blank; `items-full`
stays "every field filled" and gains one `very good` row), the README says so,
and `DocsSampleTests` pins it (G19).

At close-out (T015, on an evidence bundle): criteria ticked with citations —
**27 an honest partial** until the person's two-device pass (house convention),
and P4's Bought/Looking-for half stated as untested; P-items → decisions in
`spec.md`; the `002` pointer at `plan.md:193`; the two SYNC-CHECKS steps;
`README.md`'s item and wishlist bullets; `ROADMAP.md`'s `020` entry and status
row; `DECISIONS.md` (Q2's storage and its cost R4 — including the rule that **every
future query, predicate, sort or grouping reads `condition` (or both stored
fields), never `conditionRawValue` alone**, since that field holds "good" for a
Very Good item; `022-grouped-browsing` is the likely first consumer; the
recorded basis Q4; R1's merged row; R6 as the person answered it).

## 12. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `CloudKitSchemaTests` over the three new fields | `@Attribute(.unique)` on any one |
| G2 | `ModelTests`: each case's stored pair against a literal tuple (never against `storage(for:)`) and read-back; an unknown refinement over Good reads Good; `allCases.map { $0.rawValue.capitalized }` pinned | the setter writes `"very good"` into `conditionRawValue`; `veryGood` declared after `good`; any non-nil refinement over Good read as Very Good |
| G3 | `ModelTests`, the older app: a frozen five-case replica of the pre-020 read (`?? .excellent`) and form save, run over a Very Good item → the replica reads Good, and after its save the item still reads Very Good; a replica move to Fair reads Fair | naïve storage (the replica reads Excellent and its save resets the grade); the refinement honoured whatever the base |
| G4 | `ModelTests`, second context: `bought`, `lookingFor`, Very Good survive a save; fresh and pre-020 rows read nil and their old grade | the caller's `save()` dropped; a default other than nil |
| G5 | `MarketFigureComputationTests`: buckets non-empty, union `knownSlugs`, **exactly one** overlap — Very Good ∩ Good = `very-good`; Good's set pinned to `["very-good","good"]`; a Very Good item counts only `very-good` listings | Very Good given `good`; Good narrowed to `good`; any second overlap |
| G6 | `ExportSchemaTests`: a Very Good item's record carries `"very good"` | `init(item:)` back on `item.conditionRawValue` |
| G7 | `NewOrUsedCopyTests`: every string by literal; the P1 rule's four cases | any word drifts; the rule returning `tapped` always |
| G8 | wanted counting: New → `brand-new` + `b-stock` only; nil and Used → today's rule, equal over the fixtures | the preference ignored; New counting `mint` |
| G9 | `MarketRefresherTests`: both target builders carry `lookingFor`, the re-read wins, the record's flag set for New; `MarketIndexTests`: `listingBasis`; `MarketCopyTests`: the three bases' strings; `MarketLocalSchemaTests` allowlist; `MarketWiringTests`: the section passes `figure.listingBasis(isWanted:` | the `newStockOnly:` argument dropped; `currentTarget` left at `lookingFor: nil`; the section reading `isWanted` alone |
| G10 | `ItemFormViewModelTests`: nil on a new form; set, save, reopen; clear saves nil; saving nil raises no validation error; `.veryGood` saved and reopened through the form on a second context, with the refetched stored pair asserted as the literal `("good", "very good")` | `populate` skipping `bought`; a validation case added; the form's save writing the raw value directly |
| G11 | `PurchaseFormViewModelTests` seed per preference and change/clear; `WishlistPurchaseStoreTests` carries `.used` and nil; the four-host seed test agrees on `bought` | one host passing nil; the store dropping `bought:` |
| G12 | `WishlistFormViewModelTests`: the three states round-trip, save unset silently | `save()` skipping `lookingFor` |
| G13 | duplication carries `.used` on both lists; sold-then-returned keeps `.new` | either duplicate dropping the argument; a sale writer clearing it |
| G14 | *(Amendment A)* `ConditionFieldLayoutTests` (b), (d); the two UI tests' legs (i)–(iv); scan: both forms compose `ConditionField(` once, no `Capsule()`, and the field carries `.scrollClipDisabled()` | `.frame(width: 60)` on `ChoiceChip` → (b) red · `chipSpacing = 24` → (d) red · the `HStack` swapped for a two-row layout → (i) red · the `ScrollView` removed (plain `HStack`) → (ii) red · `.scrollDisabled(true)` → (iii) red · the `.onAppear` scroll deleted → (iv) red · a chip copy pasted back, or `.scrollClipDisabled()` removed → scan red |
| G15 | `ProvenanceWiringTests` + the rewritten purchase-sheet order: each form composes `NewOrUsedField` once, in its stated place, with its identifier; the field calls `NewOrUsed.selection(afterTapping:` | a field moved or dropped; a hand-rolled toggle |
| G16 | the two page rows pass `item.bought` / `item.lookingFor` into `NewOrUsedCopy` | the literal "Bought" restored; the wanted row reading a constant |
| G17 | CSV: headers, rows, parse, counted defaults, boundaries, the round trip on a second context, the template's last column | a column misplaced; a boundary missing; the commit dropping a field |
| G18 | PDF: an item's date field labelled `Bought new` / `Bought used` when recorded and `Bought` when nil (full label list compared to a literal); the wishlist's Looking for field present when recorded, absent when nil; Very Good printed | the item label reverted to plain `Bought`; the wishlist nil guard dropped |
| G19 | `DocsSampleTests`: the samples' new columns as the README describes | a sample and its README disagreeing |
| G20 | the two UI tests, twice back to back | §10's mutations |

Every guard is mutation-verified before it lands and the Done note records what
was broken and what went red; every source scan `#require`s its anchor. What the
suites cannot reach — the on-disk upgrade, the chips' look on a narrow phone,
the figure's basis on a live refresh — is T014's; the spoken names are the
person's Accessibility Inspector step at the Phase 3 pause; what no
agent can reach — an older build on a second device — is the person's, in
`SYNC-CHECKS.md`, and is stated as untested until then.

## As built (close-out, T015, 2026-10-06)

What shipped, for whoever extends it. Written from the close-out's evidence
bundle; the sections above keep their text, and where this section and they
disagree, this one is what the code does.

**The count.** Fifteen tasks (T001–T015), no sub-lettered additions: the two
phase-pause findings became spec Decisions 11 and 12, and the device pass found
no failure. **1804 unit tests in 236 suites and 42 UI tests**, both suites
twice back to back after the device pass (T014) and once more at the close-out.
No `.pbxproj` edit, no new dependency, no constitution amendment.

- **Very Good's storage (Q2), and the rule it leaves behind.**
  `Item.conditionRawValue` holds one of the five grades an older app knows;
  `Item.conditionRefinement` holds `"very good"` beside `"good"` and is nil
  otherwise, so a Very Good item's stored pair is `("good", "very good")`. Any
  other refinement over Good reads Good, and a refinement is honoured only over
  Good. At T001 no production code outside `Item.swift` read or wrote
  `conditionRawValue` (the export record's own field of that name is filled
  from `condition`). **Every future query, predicate, sort or grouping reads
  `condition` (or both stored fields), never `conditionRawValue` alone** — that
  field says "good" for a Very Good item. `022-grouped-browsing` is the likely
  first consumer. One thing follows for tests: a direct write of `"very good"`
  into `conditionRawValue` also reads Very Good on this build, so a save-path
  test that only reads `condition` back cannot tell the two storages apart —
  the form, the import round trip and G10 assert the stored pair as a literal
  on a second context.
- **Two tests named above were renamed at T001** because their old names became
  false: `conditionRoundTripsThroughItsRawValue` →
  `conditionRoundTripsThroughItsStoredPair`, and
  `theConditionBucketsAreDisjointAndNonEmpty` →
  `theConditionBucketsOverlapOnlyWhereVeryGoodMeetsGood`. §1 and §12 still
  cite the old names. `002`'s plan carries the pointer for the
  second ("Superseded in part by `020`", beside its disjoint-buckets sentence).
- **The market store (§3, Q4).** The function is
  `record(_:product:for:newStockOnly:in:)` — §3 spells it without the trailing
  `in:`. `MarketFigureRecord.isNewStockOnly` is written on withheld readings
  too, so the "too few listings" sentence also names the stock it was read
  from. The section's words come off the figure (`figure.listingBasis(isWanted:)`),
  never off the entry's live preference. Checked live at T014(c), one Reverb
  product read both ways: New → `newStockOnly=true`, 58 listed, $439–$670;
  Used → `false`, 35 listed, $168–$440; the counts on screen matched.
- **Amendment A as shipped (§6).** `Trove/Views/Shared/ChoiceChips.swift` holds
  `ChoiceChip` (extracted verbatim from `ItemFormView.conditionChip`),
  `ConditionField(label:selection:)` and
  `NewOrUsedField(label:identifier:selection:)`. `ConditionField` is a mono
  label over `ScrollViewReader { ScrollView(.horizontal, showsIndicators:
  false) { HStack(spacing: chipSpacing) { ChoiceChip(…).id(condition) } }
  .scrollClipDisabled().onAppear { proxy.scrollTo(selection, anchor: .center) } }`
  — `chipSpacing` 8, no animation, no vertical padding on the `HStack`, and it
  scrolls on appear only. **Leg (iv) passed with `onAppear`; the
  `ScrollPosition(id:anchor:)` fallback was not built.** `NewOrUsedField` is an
  `HStack` of two chips that does not scroll, calls
  `NewOrUsed.selection(afterTapping:current:)`, and identifies its chips
  `"<identifier>.new"` / `".used"`. `FlowLayout.swift` is deleted.
- **Measured chip widths** (3× render, dark theme): New 53.33, Excellent 79.67,
  Very Good 86.00, Good 58.00, Fair 49.00, Broken 68.33 pt; six with 8 pt
  spacing are **434.33 pt** — past 327 by 107.33, past 354 by 80.33 and past
  392 by 42.33, so the row scrolls on every iPhone. "Good" ends 301 pt from the
  row's start, 53 pt inside the 354 pt field, which is why the existing
  `buttons["Good"]` taps still land. Q9 held at T014(b): the narrowest
  supported iPhone on both installed runtimes is 375 pt.
- **The sheet's identifier.** The Mark as bought sheet's Bought field is
  identified `"bought"`, the same as the item form's — its other identifiers
  are prefixed `purchase.sheet.`. The two screens are never up together. The
  item-form placement scan pins "directly above" (nothing composed between the
  field and `ConditionField(`), so a modifier chained onto the field would
  redden it with nothing broken. Neither form's `selection:` binding is pinned
  by a scan; the UI tests observe it.
- **The UI tests' shape (§10).** A condition chip is addressed by
  `label == %@ AND identifier == ''`, since the Bought field puts a second
  "New" on both screens. The item-form scrolling test runs on the **edit**
  form, swipes up until the row is on screen and asserts Excellent is hittable
  first, so "Broken is not hittable" cannot pass with the row off screen; it
  reads `isHittable` and `frame` before any `tap()`. A `DetailRow` is one
  combined accessibility element labelled `"<label>, <value>"`, so the page
  assertions are `"Bought used, <date>"` on the date row and
  `"Looking for, Used"`. Two fragilities, both false reds and neither a false
  green: the date string is computed in the test runner, so a run straddling
  midnight fails; and leg (ii) rests on a 12 pt margin on the pinned 402 pt
  simulator, so a wider window turns it red. The reopened edit form of a Broken
  item still opens at its top (`Name` hittable before any scroll).
- **The CSV round trips (§8) live in the two view-model commit suites** —
  `ItemListViewModelCommitTests.commitRestoresBoughtAndVeryGoodThroughTheCSV`
  and `WishlistViewModelCommitTests.commitRestoresLookingForThroughTheCSV` —
  outside T011's Files line, disclosed at the Phase 4 review. Each exports,
  imports and refetches on a second context; the items one asserts the stored
  pair `("good", "very good")`.
- **The template check.** `ImportSchemaTests.theTemplatesEndInBoughtAndLookingFor`
  builds the template's bytes from the header arrays, not through Settings.
  What closes the loop is `SettingsViewModelTests`, which already pinned that
  Settings stages its templates from `ExportSchema.itemHeaders` and
  `wishlistHeaders` — so criterion 16 is covered end to end by the pair, not by
  either alone.
- **Two test shapes caught and corrected.** (1) G4's mutation as T001's line
  worded it — "refetch put back on the same context and the save dropped" —
  **stays green**: it is the known false-pass shape (a same-context refetch
  hands back unsaved changes). The guard was verified by §12's wording instead:
  the save dropped with the refetch still on a second context, six issues.
  (2) The carried-across nil: a row built in a test reads "not recorded"
  whatever the app does, so `aRowWithOnlyOlderFieldsReadsNotRecordedAndItsOldGrade`'s
  nil legs are not evidence for criteria 5, 11 and 20, and an "old entry
  reopens as nil" assertion written in Phase 2 was removed for the same reason.
  Those three criteria rest on T014(a)'s upgrade in place on a persistent
  store. Before any of that, the sign-off had found G14's leg (d) vacuous under
  the original `FlowLayout` (it reports the proposed width) and G10's Very Good
  leg unable to fail under its named mutation; both were fixed in the plan
  before T001.
- **The device pass (T014), four dispatches, one section each.** (a) Upgrade in
  place from `main`'s build, binaries confirmed by md5: three rows survive,
  Good stays Good, New stays New, both pages read plain "Bought", both forms
  open with neither chip selected, the pre-update wishlist entry has no Looking
  for row, and its live figure ("$800 · 67 listed") is unchanged — which is
  also the on-disk check of `MarketFigureRecord.isNewStockOnly` arriving on an
  existing local store. (b) iPhone SE 3rd generation, 375 pt, light and dark:
  one line, nothing squeezed, slides to Broken, a Broken item reopens with
  Broken in view. (c) The live probe above; the temporary file probe in
  `MarketLocalStore.record` was removed and the tree was byte-identical to
  HEAD. (d) Everything set in (a)–(c) survived a terminate and relaunch.

### What is untested

- **Criterion 27, and P4's Bought / Looking for half.** No two-device run.
  Whether an app older than `020` editing a row keeps Bought and Looking for
  rests on CloudKit's additive-schema behaviour, which no test here can reach;
  `specs/SYNC-CHECKS.md` steps 3.11 (older build on B) and 3.12 (both on the
  new build) carry it. P4's Very Good half *is* tested — G3's frozen replica of
  the pre-020 read and save — but G3 runs in memory and cannot see the iCloud
  leg, which is why 3.11 edits a Very Good item on the older build.
- **R4's edge**, stated and not solved: an older build moving a Very Good item
  off Good and back to Good leaves the refinement in place, so it reads Very
  Good again here.
- **The look of the cut-off chip.** `.scrollClipDisabled()` is pinned by a scan,
  which pins a spelling. At rest on a 402 pt screen the cue is 12 pt of
  Broken's rounded end; on the 375 pt SE it is Fair with about 85 % showing.
- **"No row when not recorded" on the wanted page** (criterion 21) has no
  automated assertion — a `?? "Not recorded"` would stay green. Seen at
  T014(a) and (d) and in the person's walkthrough.
- **The wording on the Market section itself** is covered at the view layer by
  one scan (`theSectionsListingWordsFollowTheFigureShown`) and T014(c)'s live
  look. The "Too few new listings" sentence was not seen live.
- **The wishlist form's reopen, clear and save-unset legs, and the sheet's
  clear leg**, are view-model tests and the person's walkthrough, not UI tests.

### Open for the pre-merge sweep (none blocking)

**Closed in the fix round after the sweep (T015a, 2026-10-06).** The
`SellPlanViewModelTests` test double that snapshotted `item.conditionRawValue`
now reads `item.condition.rawValue`, so its bullet is gone from this list. The
stale comments below are corrected, all but the last. The "019" in the comments
naming the layouts earlier releases wrote now reads 018, the last spec that
shipped one. And three guards the sweep asked for exist, each
mutation-verified: a withheld new-stock reading records its flag
(`aWantedItemLookingForNewWithTooFewNewListingsIsWithheldAndRecordedSo`), an
entry with no preference shows no Looking for row
(`testLookingForPrefillsThePurchaseSheet`), and the six condition chips run
left to right in the scale's order on both screens
(`assertTheConditionRowIsOneScrollingRow`). What remains below is what the
sweep judged fine to leave.

- No test drives `markBought` with a Very Good purchase and asserts the stored
  pair (correct by construction through `Item.init`).
- `aPreferenceChangedDuringTheFetchIsTheOneComputed` waits on its gate without
  a bound: it would hang rather than redden.
- Stale comments — **corrected at T015a**: "three hosts" / "G12 pins" on three
  `makePurchaseFormViewModel` docs and the host test; "the eleven `Item.init`
  is passed" in `WishlistPurchaseStoreTests`; a scan's doc comment claiming a
  "composed twice or not at all" mutation that was not run. **Still open**:
  `theTwoLegacyItemWidthsPassAndTheWidthsBetweenThemDoNot` now covers three
  widths.
- Neither `duplicate` passes `year` or `reverbProductID` (predates `020`; not
  checked whether intended).
- The wishlist's width 8 being rejected is not shown in `020`'s diff.

### Seen on the device pass, for the person's eye

On the SE the Mark as bought sheet shows Bought at its opening size with
Condition below the fold; unselected chip outlines are faint in light
appearance; when the condition row is slid, chips run off the left screen edge
with no margin; the wishlist PDF's Looking for field is not set in mono like
its neighbours. On the estimate sheet, which predates this spec, a new-stock
reading shows the "median" label overprinting "$439" when the median equals
the low end, and the hint "Drag toward the high end if yours is in better
shape than most" reads oddly for a wanted, new-stock figure. The match picker
still says "used" — accepted, spec Decision 12.

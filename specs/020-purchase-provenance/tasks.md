# 020 — Purchase Provenance: Tasks

**Status**: **Final** (2026-09-30) — signed off by the `skeptical-reviewer`
after one review and one re-review; the re-review's one remaining blocking
item (N1, G10's Very Good leg) fixed directly by the orchestrator per
`CLAUDE.md`'s review-loop cap, and logged in the tier log.

Drafted against the approved `spec.md` (Approved 2026-09-29) and the draft
`plan.md` in this directory, for branch `020-purchase-provenance` off `main`
(`637a950`). No new technical decisions are made here — every call traces to a
plan section, and where a task says "per plan", that section is the authority.
**No task starts until `018-system-design-language` has merged and this branch
has `main` merged in**; tasks that touch a file `018` changes say so, and their
implementer re-reads that file after the sync.

**Foundational phase**: **Phase 1** (T001–T002) — the three stored fields, the
Very Good case and its storage rule, the `NewOrUsed` type, its copy and the
clear-on-tap rule. Every later task reads or writes these, and the storage rule
is data on disk that an older app on another device also reads.
**Tasks marked `review: per-task`**: **T001** — the storage rule for Very
Good (plan Q2) is what every reader of `condition` inherits, and the one place
where a plausible-looking simpler version silently fails the spec (P4); and
**T003** — Decision 9 (no existing wanted item's figure moves) rests on it, and
Phase 2 has no pause at which the person could notice a moved figure. Every
other task gets the default one review per phase. An orchestrator left to guess
guesses "all of them"; these two are the ones marked.

Ordering note: the model first, since the new case breaks two exhaustive
switches and changes what `conditionRawValue` means; then the copy and the pure
rule the fields call. Phase 2 is view models and the market with no screen
change, so Phase 3 is view work only. Inside Phase 3 the shared chip components
land before the three screens that use them, and the UI tests last. The CSV and
PDF depend only on the model and run as their own phase so the person can check
the files in one sitting.

House rules carried over: one commit per completed task, referencing its ID;
every guard is **mutation-verified** (break the rule, confirm red) before it
lands, and the Done note records what was broken and what went red; a task is
done when `scripts/verify.sh` is green and its actual output is reported
(suite-level selection, count checked — per-function Swift Testing selectors run
zero tests); **persisted-state assertions refetch on a second `ModelContext`**;
**every source scan `#require`s its anchor**, and scans pin view-body facts only
— never a behaviour a view-model test reaches (`CLAUDE.md`, 2026-09-19);
**a fixture's value must differ from what a broken path produces** — for these
fields that means never asserting a carried-across nil (`015`'s lesson). New
files land in synchronized folders — **no `.pbxproj` edit**; if the build cannot
see one, stop and flag. No test opens a network connection.

Cadence (per `CLAUDE.md`'s model policy): each dispatch gets a task bundle
assembled with shell — task line, plan section, acceptance criteria, files,
pattern file — and the implementer does not read `plan.md`/`spec.md`/`tasks.md`
in full; verification is `scripts/verify.sh` and nothing more verbose, re-run by
the orchestrator for T001 and T003 and taken from the implementer's verbatim output
otherwise; the `skeptical-reviewer` reviews per phase and T001 and T003, one review and at
most one re-review each, on a bundle cut after `git add -A`; one implementation
session for the whole spec; the device pass runs in a `general-purpose` agent.
Everything the person reads is plain language.

---

## Phase 1 — Foundations: the two facts and Very Good (**foundational**) · walkthrough: yes — on the item form (under More details) and on the Mark as bought sheet the condition row now reads New, Excellent, Very Good, Good, Fair, Broken and wraps onto a second line on a narrow phone; an item saved as Very Good reopens with Very Good selected and its page reads "Very Good"; nothing else in the app looks different yet

- [ ] **T001 — `NewOrUsed`, the three stored fields, Very Good and its storage rule. `review: per-task`.**
  Per plan §1, Q1–Q3 and P4. New `Trove/Models/NewOrUsed.swift`
  (`nonisolated enum NewOrUsed: String, CaseIterable, Sendable { case new, used }`).
  `Condition` gains `case veryGood = "very good"` **between `excellent` and
  `good`**, and its doc comment says what `020` did about the added case.
  `Item` gains `conditionRefinement: String?` and `boughtRawValue: String?`
  (declared without initializers, as `WishlistItem.boughtDate` is), `bought`
  over the latter, the two static functions `storage(for:)` and
  `condition(raw:refinement:)` exactly as plan §1 specifies (refine to Very Good
  **only** over a base of Good), `condition` rewritten over them, and an init
  parameter `bought: NewOrUsed? = nil` after `year` — the init sets the
  condition through `storage(for:)`, never by writing `conditionRawValue`.
  `conditionRawValue`'s doc comment says it is not `condition.rawValue` for Very
  Good. `WishlistItem` gains `lookingForRawValue: String?`, `lookingFor`, and
  `lookingFor: NewOrUsed? = nil` in its init. Two edits the new case forces, in
  this task so the tree never builds wrong: `MarketConditionMap.reverbSlugs`
  gains `.veryGood: ["very-good"]` (`.good` untouched), and
  `ItemExportRecord.init(item:)` reads `item.condition.rawValue` instead of
  `item.conditionRawValue` — grep every other production read of
  `conditionRawValue` and confirm there is none — and
  `ItemExportRecord.conditionRawValue` gains a doc comment saying it holds
  `condition.rawValue` (`"very good"` for Very Good), **not**
  `Item.conditionRawValue`, so nobody "fixes" it back. `CloudKitSchemaTests` gains a
  doc-comment paragraph naming the three fields.
  Pattern: `Item.condition`/`conditionRawValue` for the storage;
  `WishlistItem.boughtDate` (015 T001) for the field additions and the CloudKit
  mutation.
  Tests (`ModelTests`, persisted legs on a second context):
  **G2** — `EnumBackedPropertyTests.conditionRoundTripsThroughItsRawValue`
  **rewritten**, not loosened: it asserts `conditionRawValue == condition.rawValue`,
  which is now false for Very Good by design; the new version asserts each
  case's stored `(conditionRawValue, conditionRefinement)` against a **literal
  tuple** — `.veryGood` → `("good", "very good")`, every other case →
  `(rawValue, nil)` — **never against `Item.storage(for:)` itself**, plus the
  read-back; an unknown refinement (e.g. `"mint"`) over Good reads Good; and
  `Condition.allCases.map { $0.rawValue.capitalized } == ["New", "Excellent",
  "Very Good", "Good", "Fair", "Broken"]` (mutations: the setter writing
  `"very good"` into `conditionRawValue` → red; `veryGood` declared after `good`
  → red; `condition(raw:refinement:)` accepting any non-nil refinement over Good
  → the unknown-refinement leg red). **G3** — a new suite "Very Good and an app older than 020": a frozen
  five-case replica of the pre-020 enum in the test file, and the pre-020 read
  (`Replica(rawValue: item.conditionRawValue) ?? .excellent`) and form save
  (`item.conditionRawValue = replicaRead.rawValue`, which is what
  `ItemFormViewModel.save` does on that build) run over a Very Good item → the
  replica reads **Good**, and after its save `item.condition` is still
  `.veryGood`; a replica move to Fair reads `.fair` here (mutations: naïve
  storage — the replica reads Excellent and its save resets the grade → red;
  `condition(raw:refinement:)` honouring the refinement whatever the base → the
  Fair leg red). **G4** — a fresh `Item` and `WishlistItem` read `bought == nil`
  / `lookingFor == nil`; an item built with only pre-020 fields (Good, and New)
  reads nil and its old grade; `bought`, `lookingFor` and Very Good survive a
  `save()` on a second context (mutation: refetch put back on the same context
  and the save dropped → red; recorded, then restored). An unknown raw value in
  `boughtRawValue` reads nil. **G1** — make one new field `@Attribute(.unique)`,
  confirm `CloudKitSchemaTests.schemaMeetsCloudKitRequirements` goes red, revert,
  record both outputs (`015` T001 found `TwoStoreContainerTests` reddens too —
  record whether it does again). **G5** (`MarketFigureComputationTests`) —
  `theConditionBucketsAreDisjointAndNonEmpty` is **rewritten to pin Decision 6**,
  never deleted: every bucket non-empty, the union is `knownSlugs`, **exactly
  one** pair overlaps and it is Very Good ∩ Good = `["very-good"]`, Good's set is
  the literal `["very-good", "good"]`; plus a Very Good item's figure counts only
  `very-good` listings and a Good item's counts both (criterion 12) (mutations:
  Very Good given `good` → red; Good narrowed to `good` → red; `fair` added to
  Broken → the one-overlap leg red). **G6** (`ExportSchemaTests`) — a Very Good
  item's record carries `"very good"` (mutation: `init(item:)` back on
  `item.conditionRawValue` → red).
  Files: `Trove/Models/NewOrUsed.swift` (new), `Trove/Models/Condition.swift`,
  `Trove/Models/Item.swift`, `Trove/Models/WishlistItem.swift`,
  `Trove/Market/MarketFigure.swift`, `Trove/Export/ExportSchema.swift`,
  `TroveTests/ModelTests.swift`, `TroveTests/MarketFigureComputationTests.swift`,
  `TroveTests/ExportSchemaTests.swift`, `TroveTests/CloudKitSchemaTests.swift`
  (comment).
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); every mutation
  recorded verbatim; the new suite in the count.

- [ ] **T002 — `NewOrUsedCopy` and the clear-on-tap rule.**
  Per plan §2 and P1. `NewOrUsed.selection(afterTapping:current:)` in
  `NewOrUsed.swift`. New `Trove/Models/NewOrUsedCopy.swift` (`nonisolated enum`,
  no SwiftUI): `boughtLabel`, `lookingForLabel`, `chip(_:)`,
  `detailDateRowLabel(bought:)` with the strings plan §2 gives.
  Pattern: `Trove/Models/PurchaseCopy.swift` and `TroveTests/PurchaseCopyTests.swift`.
  Tests: new `TroveTests/NewOrUsedCopyTests.swift` — **G7**: every string by
  literal, including `detailDateRowLabel(bought: nil) == "Bought"` (today's page
  row, P3); the rule's four cases — nil + New → New, New + New → nil, New + Used
  → Used, Used + Used → nil (mutation: return `tapped` always → the two clearing
  cases red).
  Files: `Trove/Models/NewOrUsed.swift`, `Trove/Models/NewOrUsedCopy.swift`
  (new), `TroveTests/NewOrUsedCopyTests.swift` (new).
  **Verify:** `scripts/verify.sh` green, the new suite in the count; mutation
  recorded. Then `scripts/verify.sh ui` once at the phase end, count recorded —
  the chip row gained a sixth chip and the existing UI tests tap condition chips
  by label.

  **Phase 1 closes here — pause for the person** (walkthrough above; the phase
  review first). The report also says, as a statement the person can overturn,
  what an older copy of the app on another device will show for a Very Good item
  — Good, never Excellent, and the grade is kept here (plan R4).

## Phase 2 — View models, the market and Copy · walkthrough: none — every change here is in a view model, the purchase sheet's seed, Copy or the market's reading of a preference nobody can set yet; no control and no screen changes until Phase 3, and by design (Decision 9) no existing wanted item's figure or wording moves

- [ ] **T003 — A wanted item's figure follows Looking for, and its words follow the figure. `review: per-task`.**
  Per plan §3, Q4, R3 and R5. `MarketSubject.wanted` becomes
  `wanted(lookingFor: NewOrUsed?)` with `readsNewStockOnly`;
  `MarketConditionMap.counts` **derived from `subject.readsNewStockOnly`** — one
  rule, one place, per plan §3; `MarketRefresher.targets(in:)` and
  `currentTarget(for:)` build it from `item.lookingFor`;
  `MarketFigureRecord.isNewStockOnly: Bool = false`;
  `MarketLocalStore.record(_:product:for:newStockOnly:)` with the defaulted
  parameter, which the refresher passes as `current.subject.readsNewStockOnly`;
  `MarketSnapshotValue.isNewStockOnly` and `listingBasis(isWanted:)`;
  `MarketCopy.ListingBasis`, `withheldWantedNew`, and `withheld`/`allYearsFallback`
  taking `basis:`; `MarketSection`'s two call sites passing
  `figure.listingBasis(isWanted: isWanted)`; `WishlistDetailViewModel`'s two
  `MarketRefreshTarget` sites (`:432`, `:524`) passing the item's preference —
  **and no test that claims to catch those two being wrong**, since the refresher
  re-reads the subject after the hop (plan §3). Every test that spells the old
  `.wanted` subject is re-spelled `.wanted(lookingFor: nil)` and must pass
  **unchanged otherwise** — that is Decision 9's evidence, so say in the Done
  note which tests those were.
  Pattern: the `yearFilter`/`isAllYearsFallback` path —
  `MarketFigureRecord` → `MarketLocalStore.apply` → `MarketSnapshotValue` →
  `MarketSection.sourceBlock` — for recording what a figure was computed over.
  Tests: **G8** (`MarketFigureComputationTests`) New counts `brand-new` and
  `b-stock` only; nil and Used count everything else, and over the recorded
  `listings-126161` fixtures nil, Used and the pre-020 rule give the same reading
  (mutations: the preference ignored → the New leg red; `mint` counted for New
  → red). **G9** — `MarketRefresherTests`: both builders carry the preference; a
  preference changed between the call and the re-read is the one computed; the
  stored record's `isNewStockOnly` is true for New and false for Used and nil
  (mutations: the `newStockOnly:` argument dropped → red; `currentTarget` left at
  `lookingFor: nil` → the re-read leg red); `MarketIndexTests`: the three
  `listingBasis` mappings; `MarketCopyTests`: the new strings by literal and
  today's two wanted strings unchanged; `MarketLocalSchemaTests`: the allowlist
  gains `isNewStockOnly` (confirm it went red before the edit); `MarketWiringTests`:
  the section passes `figure.listingBasis(isWanted: isWanted)` at both sites
  (view-body fact — and the Done note says plainly that this scan is the whole
  of the view-layer coverage: the "new listings" wording on screen is untested
  by any automated check). `MarketVocabularyTests` green **unedited**.
  Files: `Trove/Market/MarketFigure.swift`, `Trove/Market/MarketRefresher.swift`,
  `Trove/Market/MarketLocalModels.swift`, `Trove/Market/MarketLocalStore.swift`,
  `Trove/Market/MarketIndex.swift`, `Trove/Models/MarketCopy.swift`,
  `Trove/Views/Market/MarketSection.swift`,
  `Trove/ViewModels/WishlistDetailViewModel.swift`, the market test files named
  above, and every test file that spells the `.wanted` subject (compile fixes
  only).
  **Verify:** `scripts/verify.sh` green (orchestrator re-runs); mutations
  recorded; the re-spelled tests listed.

- [ ] **T004 — Bought through the item form's view model and the purchase sheet.**
  Per plan §4 and P6, Q8. `ItemFormViewModel.bought` (populate, save, no
  validation). `Purchase.bought`; `PurchaseFormViewModel.bought` and the init
  `init(estimatedCostCents:lookingFor:now:)` — **required** `lookingFor:` —
  seeding it; `purchase()` carrying it; `WishlistPurchaseStore.markBought`
  passing `bought: purchase.bought` to `Item.init`. The four hosts pass their
  entry's preference: `WishlistViewModel`, `WishlistDetailViewModel`,
  `SellPlanViewModel`, **`PlansViewModel` (changed by `018` — re-read after the
  sync)**. The `PurchaseFormView` preview gains `lookingFor: nil`.
  Pattern: `ItemFormViewModel.condition` (populate/save);
  `WishlistDetailViewModelTests.everyHostSeedsThePurchaseSheetIdentically`
  (`015` G12, extended by `009`).
  Tests: **G10** (`ItemFormViewModelTests`) a new form's `bought` is nil; Used
  set, saved, reopened → Used; cleared to nil and saved → nil on a second
  context; saving with nil sets no validation error and returns true (criteria
  1–4); `.veryGood` set through the form, saved, and reopened through a new
  `ItemFormViewModel` on a second context reads `.veryGood`, **and the refetched
  item's stored pair `(conditionRawValue, conditionRefinement)` equals the literal
  `("good", "very good")`** (criterion 10; the pair assertion is what the last
  mutation below reaches — the read-back alone stays green under it, since
  `Condition(rawValue: "very good")` is `.veryGood`) (mutations: `populate` skipping `bought` → the reopen leg red; `save`
  skipping it → red; `save` writing `conditionRawValue = condition.rawValue`
  directly → the Very Good leg red). **G11** — `PurchaseFormViewModelTests`: the seed for each
  of nil, New, Used; changed and cleared before `purchase()` → the purchase
  carries what is chosen; `WishlistPurchaseStoreTests`: the created item carries
  `.used`, and nil when nil (criterion 7); the four-host test gains an entry
  looking for **used** and asserts all four seeds agree on `bought == .used`
  (mutation: one host passing nil → red; the store dropping `bought:` → red).
  Files: `Trove/ViewModels/ItemFormViewModel.swift`, `Trove/Models/Purchase.swift`,
  `Trove/ViewModels/PurchaseFormViewModel.swift`,
  `Trove/Models/WishlistPurchaseStore.swift`,
  `Trove/ViewModels/WishlistViewModel.swift`,
  `Trove/ViewModels/WishlistDetailViewModel.swift`,
  `Trove/ViewModels/SellPlanViewModel.swift`, `Trove/ViewModels/PlansViewModel.swift`,
  `Trove/Views/Wishlist/PurchaseFormView.swift` (preview only),
  `TroveTests/ItemFormViewModelTests.swift`,
  `TroveTests/PurchaseFormViewModelTests.swift`,
  `TroveTests/WishlistPurchaseStoreTests.swift`,
  `TroveTests/WishlistDetailViewModelTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T005 — Looking for through the wishlist form's view model; both Copies; sale and return.**
  Per plan §4, §5 and P2. `WishlistFormViewModel.lookingFor` (populate, save).
  `ItemListViewModel.duplicate(id:)` passes `bought: original.bought`
  (**`ItemListViewModel.swift` is changed by `018` — re-read after the sync**);
  `WishlistViewModel.duplicate(id:)` passes `lookingFor: original.lookingFor`.
  No code for sale and return.
  Pattern: `WishlistFormViewModel.desireToOwn`; `ItemListViewModel.duplicate`'s
  `condition:` line.
  Tests: **G12** (`WishlistFormViewModelTests`) nil on a new form; each value
  saved and reopened; cleared and saved nil; unset saves silently (criteria 19,
  20) (mutation: `save` skipping it → red). **G13** — `ItemDuplicationTests` and
  `WishlistDuplicationTests`: an original set to **Used** gives a copy set to
  Used (criteria 8, 24) (mutation: drop either argument → red);
  `ItemSaleStoreTests`: an item set to **New**, sold through `markSold` and
  returned through `returnToCollection`, reads New on a second context
  (criterion 9) (mutation: `returnToCollection` clearing `bought` → red).
  Files: `Trove/ViewModels/WishlistFormViewModel.swift`,
  `Trove/ViewModels/ItemListViewModel.swift`, `Trove/ViewModels/WishlistViewModel.swift`,
  `TroveTests/WishlistFormViewModelTests.swift`, `TroveTests/ItemDuplicationTests.swift`,
  `TroveTests/WishlistDuplicationTests.swift`, `TroveTests/ItemSaleStoreTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

  **Phase 2 closes here — `walkthrough: none`; after its review, run on.**

## Phase 3 — Screens · walkthrough: yes — on the item form (More details) a Bought row with New and Used sits just above Condition, neither picked; pick one, save, and the item's page reads "Bought new" or "Bought used" where it said "Bought" beside the date; tap the picked chip again and it clears, and the page goes back to "Bought"; the wishlist form has a Looking for row after "How much do you want it", and the wanted item's page shows "Looking for · New" or "Used" (nothing when unset); marking that item bought opens the sheet with its Bought chip already picked to match, changeable before saving; a matched wanted item set to New shows a figure from new listings after its next refresh, and "new listings" wherever it used to say "used listings"; on a narrow phone the six condition chips wrap without clipping; and, the person's own check, Accessibility Inspector or VoiceOver over the Bought and Looking for chips (each announces its word and whether it is selected; a cleared row announces nothing selected) and over the two page rows

- [ ] **T006 — The shared chips, the condition row moved onto them, and criterion 18 measured.**
  Per plan §6 and Q5, Q9. New `Trove/Views/Shared/ChoiceChips.swift` with
  `ChoiceChip` (extracted **verbatim** from `ItemFormView.conditionChip` — no
  visual change), `ConditionField(label:selection:)` and
  `NewOrUsedField(label:identifier:selection:)` exactly as plan §6 specifies
  (the field calls `NewOrUsed.selection(afterTapping:current:)`; chips identified
  `"<identifier>.new"`/`".used"`; the field an accessibility container labelled
  with its field label). `ItemFormView` and `PurchaseFormView` replace their
  private chip copies with `ConditionField` — `PurchaseFormView` keeps its
  `conditionField` property name.
  Pattern: `ItemFormView.conditionChip` and its `FlowLayout` row;
  `TroveTests/ItemListHeaderLayoutTests.swift` for `ImageRenderer` measurement
  under a real theme.
  Tests: new `TroveTests/ConditionFieldLayoutTests.swift` — **G14**'s legs
  (a)–(c) from plan §6 at the Q9 width (no whole-field width leg: `FlowLayout`
  always reports the proposed width, so it would be vacuous), **measured after the `018` sync** since
  `ThemeTypography` is changing there; the Done note records the container width
  used, each chip's measured width and the row count observed (mutations: a
  fixed `.frame(width: 60)` on `ChoiceChip` → leg (b) red; the container proposed
  narrower than the widest chip → leg (a) red). New
  `TroveTests/ProvenanceWiringTests.swift`: both forms compose `ConditionField(`
  exactly once and contain no `Capsule()` (mutation: paste the old chip back into
  either form → red); `NewOrUsedField` calls `NewOrUsed.selection(afterTapping:`
  (mutation: a hand-rolled toggle → red). `MenuPolicyTests` and every existing
  `WishlistPurchaseWiringTests` test green unedited.
  Files: `Trove/Views/Shared/ChoiceChips.swift` (new),
  `Trove/Views/Items/ItemFormView.swift`, `Trove/Views/Wishlist/PurchaseFormView.swift`,
  `TroveTests/ConditionFieldLayoutTests.swift` (new),
  `TroveTests/ProvenanceWiringTests.swift` (new).
  **Verify:** `scripts/verify.sh` green, both new suites in the count; mutations
  and the measured widths recorded.

- [ ] **T007 — Bought on the item form and the purchase sheet.**
  Per plan §6. `ItemFormView.optionalFields`: `NewOrUsedField(label:
  NewOrUsedCopy.boughtLabel, identifier: "bought", selection: $viewModel.bought)`
  directly above the condition row. `PurchaseFormView`: a `boughtField` between
  `boughtFromField` and `conditionField`, in both the declarations and the
  column. **`WishlistPurchaseWiringTests.theFiveElementsAppearInTheSpecsOrder`
  is rewritten, not dodged**: the sheet now has a fifth field, so its declared
  list gains `NewOrUsedCopy.boughtLabel` before `PurchaseCopy.conditionLabel` and
  its composed list gains `boughtField` before `conditionField`; rename it for
  what it now pins and update its doc comment ("the spec's four fields" → five).
  The `"Note"` scan in the neighbouring test must stay green.
  Pattern: `PurchaseFormView.conditionField`; `ItemFormView.optionalFields`.
  Tests (`ProvenanceWiringTests`, **G15**): each form composes `NewOrUsedField(`
  once with its identifier and label, above the condition row (mutation: move it
  below Condition on either form → red; drop it → the anchor `#require` fails).
  `testEveryFormFieldIsNamedForVoiceOver` checked in the phase-end UI run.
  Files: `Trove/Views/Items/ItemFormView.swift`,
  `Trove/Views/Wishlist/PurchaseFormView.swift`,
  `TroveTests/ProvenanceWiringTests.swift`,
  `TroveTests/WishlistPurchaseWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T008 — Looking for on the wishlist form.**
  Per plan §6. `WishlistFormView`: a `lookingForField` —
  `NewOrUsedField(label: NewOrUsedCopy.lookingForLabel, identifier: "lookingFor",
  selection: $viewModel.lookingFor)` — directly after `desireField`.
  Pattern: `WishlistFormView.desireField`.
  Tests (`ProvenanceWiringTests`, **G15**): the form composes it once, after
  `desireField` and before `PhotoPickerField` (mutation: reorder → red).
  Files: `Trove/Views/Wishlist/WishlistFormView.swift`,
  `TroveTests/ProvenanceWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutation recorded.

- [ ] **T009 — The two pages.**
  Per plan §7, R1, R2 and P3. `ItemDetailView.details`: the date row's label
  becomes `NewOrUsedCopy.detailDateRowLabel(bought: item.bought)`.
  `WishlistDetailView.details`: a third row, `NewOrUsedCopy.lookingForLabel` and
  `item.lookingFor.map(NewOrUsedCopy.chip) ?? ""`, after `Added`, left to the
  existing empty filter.
  Pattern: the two `details(for:)` row arrays.
  Tests (`ProvenanceWiringTests`, **G16**): each page passes its item's field
  into the copy function inside `details(for:` (mutations: the literal `"Bought"`
  restored → red; the wanted row reading a constant → red). State in the Done
  note that these scans are the whole of the unit coverage for the rows and that
  T010's UI test is what observes them.
  Files: `Trove/Views/Items/ItemDetailView.swift`,
  `Trove/Views/Wishlist/WishlistDetailView.swift`,
  `TroveTests/ProvenanceWiringTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T010 — The UI tests, run twice.**
  Per plan §10 (**G20**). `testBoughtIsSetClearedAndShownOnTheItemsPage` and
  `testLookingForPrefillsThePurchaseSheet` exactly as plan §10 walks them,
  addressing the new chips by identifier and reading selection through
  `isSelected`; **no seed change**. Mutations: `NewOrUsedField` writing `tapped`
  unconditionally → the clear leg red; one host seeding `lookingFor: nil` → the
  preselect leg red; the page row back to the literal → red. The Done note names
  **which host** the preselect mutation reaches — the test buys through the
  Wishlist row's swipe, so it reaches `WishlistViewModel`'s seed only; the other
  three hosts' seeds are G11's cross-host unit test, not this one.
  Pattern: `testMarkingAWantedItemBoughtMovesItToTheCollection` (the swipe and
  the sheet), `testAddingAnItemThroughQuickAddPutsItInTheList` (the form).
  Files: `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh ui` green **twice back to back**, both counts
  recorded; `scripts/verify.sh` green; mutations recorded.

  **Phase 3 closes here — pause for the person** (walkthrough above). The report
  also names **the person's own step here**: Accessibility Inspector (or
  VoiceOver) over the Bought row on the item form and the sheet, the Looking for
  row on the wishlist form — each chip's spoken name and selected state, a
  cleared row announcing nothing selected — and the two page rows. R1, R2 and R3
  were decided by the person before the build (spec Decision 10); the report
  points them at R5 (the figure changing at the next refresh, not at the edit).

## Phase 4 — CSV, templates, import and PDF · walkthrough: yes — Settings › Templates: the items template now ends in a Bought column and the wishlist template in Looking For; export the collection as CSV and the last column reads new, used or blank, with a Very Good item written "very good"; import that file into an empty collection and every Bought value and Very Good grade comes back; an older export with no Bought column still imports; the collection PDF's date field reads "Bought new" or "Bought used" where recorded and plain "Bought" where not, and prints Very Good; the wishlist PDF lists "Looking for" the same way

- [ ] **T011 — The CSV columns, the templates, and import on both lists.**
  Per plan §8, Q6–Q8. `ItemExportRecord.bought` / `WishlistExportRecord.lookingFor`
  as `var … = nil`, filled by each `init(item:)`; the two header arrays appended;
  the two row functions appended; `itemSchemaBoundaries = [12, 14, 18]`,
  `wishlistSchemaBoundaries = [7, 9]`, each doc comment naming the layout that
  ended there; `ImportSchema.newOrUsed(from:)` and both previews reading the new
  column with Q6's policy; `ImportSchema.condition(from:)`'s doc comment says six;
  the two import commits pass the field (**`ItemListViewModel.swift` is changed
  by `018` — re-read after the sync**; if `ExportWiringTests`, also `018`'s,
  goes red, re-read it before touching it).
  Pattern: `006`'s four appended sale columns through `ExportSchema.row`, the
  `Reverb Product ID` blank-silent/unreadable-counted block in `itemsPreview`,
  and `ItemListViewModel.confirmImport`'s `reverbProductID:` line.
  Tests (**G17**): `ExportSchemaTests` — both header arrays by literal, a row per
  value and blank, Very Good as `very good`; `ImportSchemaTests` — `NEW`, `Used`,
  `new` read; `Very Good`, `VERY GOOD`, `very good` read as `.veryGood`; `maybe`
  → nil and counted; blank → nil and silent; an 18-column items file and a
  9-column wishlist file import, every row nil (mutations: drop a boundary → that
  file rejected → red; the unreadable case not counted → red); the round trip —
  records with `.used`, `.new` and nil and a Very Good grade exported, written,
  parsed, previewed, committed and refetched on a second context — restores every
  value on both lists (criteria 13–15, 25) (mutations: a commit dropping the
  field → red; the export row writing `conditionRawValue` → red); the items
  template's header row's last cell is `Bought` and the wishlist's `Looking For`
  (criterion 16), by literal. Existing 12- and 14-column tests green unedited.
  Files: `Trove/Export/ExportSchema.swift`, `Trove/Import/ImportSchema.swift`,
  `Trove/ViewModels/ItemListViewModel.swift`, `Trove/ViewModels/WishlistViewModel.swift`,
  `TroveTests/ExportSchemaTests.swift`, `TroveTests/ImportSchemaTests.swift`, and
  the round-trip's home test file (`ImportSchemaTests`'
  `aTroveExportRoundTripsLosslessly` / `aWishlistExportRoundTripsLosslessly`
  shapes, carried through the commit).
  **Verify:** `scripts/verify.sh` green; mutations recorded.

- [ ] **T012 — The PDF lines.**
  Per plan §9 and R6. `PDFEntry.init(record: ItemExportRecord)` labels its
  existing purchase-date field with `NewOrUsedCopy.detailDateRowLabel(bought:)`
  (no new item field); `init(record: WishlistExportRecord)` appends Looking for
  after `Desire to own` when recorded.
  Pattern: the optional `Bought from` and `Condition notes` fields in the same
  initializer.
  Tests (**G18**, `ExportSchemaTests`): a recorded item's date field is labelled
  the literal `"Bought used"` (and `"Bought new"` for a `.new` fixture), with no
  second `"Bought"` label — asserted by comparing the **full label list** to a
  literal, never by a `contains("Bought")` test, since `"Bought from"` contains
  the word; a nil item's labels are the literal at `:343`
  unchanged; a Very Good item's Condition field reads
  `"Very Good"`; the wishlist's field present and absent the same way (criteria
  17, 26) (mutations: the item label reverted to plain `Bought` → the recorded
  leg red; the wishlist nil guard dropped → the unchanged-literal leg red).
  Files: `Trove/Export/ExportSchema.swift`, `TroveTests/ExportSchemaTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutation recorded.

- [ ] **T013 — The CSV reference, the samples, and their test.**
  Per plan §11. `docs/csv-reference.md`: items row 19 `Bought`, wishlist row 10
  `Looking For`, the Condition row's six words with `very good`'s space, the
  field-formats bullets, and the kept-exceptions paragraph naming the 18- and
  9-column layouts. `docs/samples/items-full.csv` gains the column on every row
  (a mix of `new` and `used`, keeping "every field filled") and one row graded
  `very good`; `docs/samples/wishlist.csv` gains the column (new, used, blank);
  `docs/samples/README.md` says so. The two legacy-layout samples are untouched —
  they are what prove the 12- and 14-column doors stay open.
  Pattern: `006`'s additions to the same three files and to `DocsSampleTests.itemsFullImportsCleanly`.
  Tests (**G19**, `DocsSampleTests`): every `items-full` row has `bought != nil`,
  the exact Very Good row is named, the wishlist's three states counted as the
  README says (mutation: blank one sample cell → red).
  Files: `docs/csv-reference.md`, `docs/samples/items-full.csv`,
  `docs/samples/wishlist.csv`, `docs/samples/README.md`,
  `TroveTests/DocsSampleTests.swift`.
  **Verify:** `scripts/verify.sh` green; mutation recorded; then
  `scripts/verify.sh ui` once at the phase end, count recorded.

  **Phase 4 closes here — pause for the person** (walkthrough above). R6 was
  decided before the build (spec Decision 10): the PDF's date label carries
  new/used, as the item page's does.

## Phase 5 — Verification and close-out · walkthrough: none — the device pass and the documents; nothing new is built. The person's Accessibility Inspector step was taken at the Phase 3 pause, and the older-build, two-device steps wait in `specs/SYNC-CHECKS.md`

- [ ] **T014 — Device pass. [general-purpose agents with simulator tools, one per section]**
  Per plan §10, criteria 5, 11, 18, 20, 22 and 27. Dispatched as **four
  separate `general-purpose` sections, each given only its own section below**
  (never the whole task line), each returning a short **pass/fail list**. **Any
  failure goes to the `sdd-implementer` as a diagnosis bundle** (the finding,
  the criterion, the plan section, the files) and is logged as a sub-lettered
  task; no section fixes anything itself.
  **(a) The upgrade on a persistent store**: build and install `main` on the
  simulator, add an item graded Good, one graded New and a wanted entry, then
  build and install this branch over it — each opens not recorded, the grades
  unchanged (the lightweight migration of three additive fields, which no
  in-memory test observes).
  **(b) iPhone SE (3rd generation) layout**, in both appearances — the condition
  row wrapping unclipped on the item form and the sheet, the Bought and Looking
  for rows matching it; and confirm from the installed runtimes that no
  supported iPhone is narrower than 375 pt (plan Q9). Selected state is **not**
  this pass's: the UI tests read `isSelected` (G20), and the spoken names were
  the person's step at the Phase 3 pause.
  **(c) The market probe** — instrument, don't eyeball: a temporary file probe
  inside `MarketLocalStore.record` logging `newStockOnly` and the reading's
  count. The refresher answers `.stillFresh` within the hour of a figure
  (`MarketRefresher.swift:53-55`), so **do not wait it out**: use **two freshly
  matched wanted entries, one set to New and one to Used** (or remove and
  re-match one entry between the two readings) — a fresh match has no figure,
  so the pick's own refresh fetches. New → the probe reads true and the count
  matches new-stock listings; Used → false. A New-preference withheld or
  all-years line, if the live catalogue produces one, reads "new listings".
  Probe removed before the suites run, the tree confirmed byte-identical to HEAD.
  **(d) Relaunch** and confirm everything set in (a)–(c) survived; then both
  suites twice. The sections run **one after another** on the simulator, never
  together, and the orchestrator passes (a)–(c)'s returned lists into (d)'s
  bundle so it knows what was set.
  **[person]** the two new `SYNC-CHECKS.md` steps if two devices and an older
  build are to hand — otherwise they wait in that file (criterion 27).
  **Verify:** each section's pass/fail list recorded in the Done note — the
  upgrade result, the measured narrowest width, the probe's lines per entry —
  every failure a sub-lettered task, and `scripts/verify.sh all` green twice.

- [ ] **T015 — Close-out.**
  Dispatched to the implementer the model policy's close-out row names
  (`sdd-implementer`), on a **close-out bundle** the orchestrator assembles with
  shell: each acceptance criterion with the test names or Done notes that
  satisfied it, the walkthrough list below and what the person said at each
  pause, the tier log, the spec's summary and decided lines, the `ROADMAP.md`
  entries this spec touches, `015`'s `DECISIONS.md` section as the shape to copy,
  and plan §10's drafted `SYNC-CHECKS.md` steps. **The dispatch forbids full
  reads of `spec.md`, `plan.md` and `tasks.md`.** The close-out: ticks criteria
  1–26 and 28 in `spec.md` with per-criterion citations, **criterion 27 an honest
  partial and unticked** until the two-device pass (house convention), and says
  plainly that P4's Bought/Looking-for half is untested until then while its
  Very Good half is G3; replaces the P-items with decisions; appends a
  "Superseded in part by `020`" pointer beside `specs/002-live-market-value/plan.md:193`
  (the disjoint-buckets claim), never editing the shipped line; adds the two
  steps to `specs/SYNC-CHECKS.md` (Part 3, and its "Steps per spec" section);
  updates `README.md`'s item and wishlist bullets; drafts the `ROADMAP.md` entry
  and status row and the `DECISIONS.md` section (Q2's storage and its cost, R4,
  stating that **every future query, predicate, sort or grouping reads
  `condition` (or both stored fields), never `conditionRawValue` alone** —
  `022-grouped-browsing` is the likely first consumer; the recorded basis, Q4; R1's merged row; R6 as the person answered it) into a
  file on the branch, to be applied to `main` after the merge; and runs
  `scripts/verify.sh all`. `plan.md` gains **As built** from the same bundle.
  Only then the pre-merge `skeptical-reviewer` sweep over `git diff main...HEAD`
  (bundle cut after `git add -A`), and the PR marked ready.
  Files: `specs/020-purchase-provenance/spec.md`, `specs/020-purchase-provenance/plan.md`,
  `specs/002-live-market-value/plan.md` (pointer), `specs/SYNC-CHECKS.md`,
  `README.md`, the drafted `ROADMAP.md`/`DECISIONS.md` text file.
  **Verify:** `grep -c "Superseded in part by \`020\`" specs/002-live-market-value/plan.md`
  returns 1; `scripts/verify.sh all` green with both count lines recorded here;
  the sweep signed off or its findings resolved.

---

## Walkthrough list (for the close-out)

| Phase | Paused? | What to try |
|---|---|---|
| Phase 1 | | the six-grade condition row and Very Good on a page |
| Phase 2 | no — `walkthrough: none` | nothing observable; view models, Copy and the market's reading of an unset preference |
| Phase 3 | | Bought and Looking for on the three forms, the two pages, the sheet's prefill, the New-preference figure; the person's Accessibility Inspector / VoiceOver step over the chips and rows |
| Phase 4 | | the templates, a CSV round trip, an old file, both PDFs |
| Phase 5 | no — `walkthrough: none` | the device pass; the person's two-device steps wait in `SYNC-CHECKS.md` |

## Handoff note

Involvement level: **product owner** (`CLAUDE.md`). Model policy: **Opus
profile** — every role at `opus`, no dispatch carries a model override, the
session at `claude-opus-5-5` medium; the plan-and-tasks draft ran at the
implementation tier under the trial continuing from `018`. Foundational phase:
**Phase 1**; `review: per-task`: **T001** and **T003**. Pause cadence: after each phase
marked `walkthrough: yes` (Phases 1, 3, 4) once its review is signed off; Phases
2 and 5 run on after their review, their reasons added to the walkthrough list.
Pause also whenever something unexpected bears on spec adherence.

> Read `CLAUDE.md` and `specs/020-purchase-provenance/{spec,plan,tasks}.md`.
> First confirm `018-system-design-language` has merged, then merge `main` into
> `020-purchase-provenance` and run `scripts/verify.sh`. Begin at the first
> unchecked task. Involvement is product owner. Dispatch each task to the
> implementer the role table names, on a task bundle; verify with
> `scripts/verify.sh`, then commit. One review and at most one re-review per
> invocation. The `skeptical-reviewer` reviews after each phase with a phase
> bundle, and T001 and T003 get their own reviews as well. Pause for me after Phases 1, 3
> and 4; run straight on after Phases 2 and 5's reviews.

Every pause report is plain language, in this order: why this pause; what can
now be tried; where execution deviated from the spec and why; what needs a
decision (product questions only). A phase pause never ends with a continuation
prompt. What the person reports from a walkthrough is a finding against a
criterion — restated, diagnosed by the implementer, and logged as a sub-lettered
task under the task it corrects.

## Tier log

`CLAUDE.md`'s model policy, Opus profile: every role at `opus`, no override;
the session at `claude-opus-5-5`, medium. Each row's Tier is the resolved model
name. Token usage from each subagent return is filled in as the spec runs, with
escape-hatch misses recorded here too.

| Task / invocation | Tier | Tokens | Outcome / miss reason |
|---|---|---|---|
| Plan and tasks draft (`sdd-planner`) | `opus` | 357,111 (85 tool uses, 18.2 min) | Plan-and-tasks draft at the implementation tier, no override (trial continuing from `018`). 15 tasks, 5 phases, 20 guards |
| Sign-off (`skeptical-reviewer`) | `opus` | 169,310 (44 tool uses, 8.2 min) | Sign off after fixes: 2 blocking (T014 device pass shape vs `CLAUDE.md`; G14 leg (d) vacuous — FlowLayout reports the proposed width), 15 second-look notes |
| Sign-off fixes (`sdd-planner`, resumed) | `opus` | 386,562 cumulative (38 tool uses, 2.9 min) | Both blocking and 11 second-look notes applied; R1/R2/R3/R6 transcribed by the orchestrator from the person's answers (spec Decision 10) |
| Sign-off re-review (`skeptical-reviewer`, resumed) | `opus` | 199,198 cumulative (2 tool uses, 1.0 min) | B1 and B2 resolved, R6 consistent; one new blocking item N1 (G10's Very Good leg could not fail under its named mutation) — **fixed directly by the orchestrator** (the stored-pair literal added to T004 and G10), per the loop cap; second-look notes 1–4 applied the same way |
| Sync with `main` after `018` merged (orchestrator, 2026-10-01) | `claude-opus-5-5` medium | — | `main` merged in clean (71 commits, no conflicts); `scripts/verify.sh` green, 1740 tests in 231 suites. Every file, test and symbol `plan.md`/`tasks.md` names still exists; the files `018` and this plan share (`ItemDetailView`, `MarketSection`, `PurchaseFormView`, `PlansViewModel`, `ItemListViewModel`, `ItemListHeaderLayoutTests`, `ThemeTypography`, `TroveUITests`) changed in comments or outside the lines this plan edits — nothing retired or reshaped, no decision review needed |

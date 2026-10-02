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
Phase 2 has no pause at which the person could notice a moved figure; and
**T006** (added 2026-10-01, plan Amendment A) — the person rejected the wrapping
row at the Phase 1 pause, the first G14 had a vacuous leg caught at sign-off, and
T007–T010 build on the component. Every
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

## Phase 1 — Foundations: the two facts and Very Good (**foundational**) · walkthrough: yes — on the item form (under More details) and on the Mark as bought sheet the condition row now reads New, Excellent, Very Good, Good, Fair, Broken and wraps onto a second line on a narrow phone *(the wrap was rejected at this pause — spec Decision 11; the row is rebuilt as one scrolling row in T006)*; an item saved as Very Good reopens with Very Good selected and its page reads "Very Good"; nothing else in the app looks different yet

- [x] **T001 — `NewOrUsed`, the three stored fields, Very Good and its storage rule. `review: per-task`.**
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
  **Done (2026-10-01).** `scripts/verify.sh` green, re-run by the orchestrator:
  1751 tests in 233 suites (was 1740 / 231; new suites "Very Good and an app
  older than 020" and "Bought, looking for and Very Good on the models").
  Per-task review: signed off, no blocking findings. **Two rewritten tests were
  renamed** because their old names became false:
  `conditionRoundTripsThroughItsRawValue` → `conditionRoundTripsThroughItsStoredPair`,
  `theConditionBucketsAreDisjointAndNonEmpty` →
  `theConditionBucketsOverlapOnlyWhereVeryGoodMeetsGood` — plan §1/§12 and this
  line cite the old names. **Grep**: no production code outside `Item.swift`
  reads or writes `Item.conditionRawValue` (the remaining hits are the export
  record's own field); one test double, `SellPlanViewModelTests.swift:1207`,
  still snapshots it — harmless until fed a Very Good item, logged for the sweep.
  Mutations, each red then restored (tree byte-compared): naïve storage → G2's
  stored-pair test, G3's replica (reads Excellent, save resets) and G4 red;
  Very Good given `good`, Good narrowed to `good`, `fair` added to Broken → G5
  red; any non-nil refinement over Good → the unknown-refinement leg red; the
  refinement honoured whatever the base → G3's Fair leg red; `veryGood` declared
  after `good` → the order literal red; export back on `item.conditionRawValue`
  → G6 red; `@Attribute(.unique)` on `boughtRawValue` → `CloudKitSchemaTests`
  **and** `TwoStoreContainerTests` red (as `015` T001 found); an init default
  of `.new` → the fresh-row legs red. **G4's mutation as this line words it
  ("refetch put back on the same context and the save dropped") stays green**
  — it is the known false-pass shape; the guard was verified by the guard
  table's wording instead (the save dropped, refetch still on a second context
  → 6 issues). G3 runs in memory (it tests the read/write rule; the persisted
  leg is G4's). For the sweep: G3 cannot see the iCloud leg — "still Very Good
  after the older app's save" also needs that app's export to leave
  `conditionRefinement` intact, so the `SYNC-CHECKS.md` step must include a
  Very Good item edited on the older build (plan §10's draft does); and
  `aRowWithOnlyOlderFieldsReadsNotRecordedAndItsOldGrade`'s nil legs are a
  carried-across nil — criteria 5, 11, 20 rest on T014's on-disk upgrade, not on it.

- [x] **T002 — `NewOrUsedCopy` and the clear-on-tap rule.**
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
  **Done (2026-10-01).** `scripts/verify.sh` green: 1756 tests in 234 suites
  (new suite "New or used copy", 5 tests). G7 mutation: the rule's body changed
  to `tapped` → `tappingTheSelectedChipClearsIt` red on both clearing cases (2
  issues), the selecting cases green; restored, full suite green again. Only
  the rule was mutated — the strings rest on their literal comparisons.
  Phase-end UI run: `scripts/verify.sh ui` green, **38 tests, 0 failures**
  (994 s) — no existing UI test tripped on the sixth condition chip. Process
  notes: a red single-suite run takes ~10.5 min (xcodebuild waits 600 s on
  simulator diagnostics) and the UI suite ~16.5 min, so both need running in
  the background.

  **Phase 1 closes here — pause for the person** (walkthrough above; the phase
  review first). The report also says, as a statement the person can overturn,
  what an older copy of the app on another device will show for a Very Good item
  — Good, never Excellent, and the grade is kept here (plan R4).

## Phase 2 — View models, the market and Copy · walkthrough: none — every change here is in a view model, the purchase sheet's seed, Copy or the market's reading of a preference nobody can set yet; no control and no screen changes until Phase 3, and by design (Decision 9) no existing wanted item's figure or wording moves

- [x] **T003 — A wanted item's figure follows Looking for, and its words follow the figure. `review: per-task`.**
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
  **Done (2026-10-01).** `scripts/verify.sh` green, re-run by the orchestrator:
  1766 tests in 234 suites (+10 test functions). Per-task review: signed off, no
  blocking findings. **Decision 9's evidence** — re-spelled
  `.wanted(lookingFor: nil)` and otherwise unchanged, all green with their
  original numbers: `MarketFigureComputationTests.aWantedItemReadsEveryUsedListingInDollars`
  (72 / 149_999 / 100_000 / 325_000), `.anUnknownSlugIsOutForAnOwnedItemAndInForAWantedOne`,
  `.newStockNeverCountsForAWantedItem`, and
  `MarketRefresherTests.targetsAreTheMatchedOwnedInCustomOrderThenTheMatchedWanted`.
  Two `MarketCopyTests` took the signature's compile fix (`basis:` for `wanted:`)
  with their expected strings untouched. `MarketVocabularyTests` unedited.
  **As built**: the store function is `record(_:product:for:newStockOnly:in:)`
  (the plan omits the trailing `in:`); the flag is written on withheld readings
  too. Mutations, each red and restored (tree hash-compared): `mint` counted for
  New, the preference ignored (72 against the fixtures' 187 new-stock listings),
  Used reading new stock too → G8 red; the `newStockOnly:` argument dropped,
  `currentTarget` left at `lookingFor: nil` (the re-read leg and the plain New
  test), `targets(in:)` left at nil, the store only ever setting the flag →
  `MarketRefresherTests` red; the allowlist without `isNewStockOnly` → red;
  `listingBasis` ignoring the flag, or ignoring `isWanted` → `MarketIndexTests`
  red; the New strings saying "used listings" → `MarketCopyTests` red; the
  section reading `isWanted` alone → the scan red at both sites. **The
  `MarketWiringTests` scan is the whole of the view-layer coverage: the "new
  listings" wording on screen is untested by any automated check.** For the
  sweep and T014: the on-disk migration of `MarketFigureRecord.isNewStockOnly`
  is untested (added to T014(a) below); `aPreferenceChangedDuringTheFetchIsTheOneComputed`
  waits on the gate without a bound, so a regression there hangs rather than
  reddens. **A third string says "used listings"**: the match picker's
  candidate line, `MarketCopy.candidateReading` ("No used listings" / "Lowest
  used asking price …") — a Reverb catalogue fact about the candidate product,
  shown when matching any item, not a wanted item's market line; left as is on
  R3's reasoning (spec Decision 10) and put to the person at the Phase 3 pause
  as a statement they can overturn.

- [x] **T004 — Bought through the item form's view model and the purchase sheet.**
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
  **Done (2026-10-01).** `scripts/verify.sh` green (the implementer's verbatim
  output): 1773 tests in 234 suites (+7 test functions). G10 is four tests
  (`startsWithBoughtNotRecordedAndSavesWithoutIt`, `savesBoughtAndReopensWithItSelected`,
  `clearingBoughtSavesNotRecorded`, `veryGoodSavesAsGoodPlusARefinementAndReopensSelected`);
  G11 is `seedsBoughtFromThePreference`, `recordsTheBoughtChosenWhenTheSheetIsConfirmed`,
  `theBoughtItemCarriesThePurchasesBoughtValueNotTheEntrysPreference`, and
  `everyHostSeedsThePurchaseSheetIdentically` extended with an entry looking for
  used and a per-host pin. Mutations, each red and restored (tree byte-compared):
  `populate` skipping `bought` → the reopen leg alone; `save` skipping it → both
  save tests; `save` writing `conditionRawValue = condition.rawValue` → the
  stored-pair lines only (the read-back stayed green, which is what the pair
  assertion is for); a `boughtMissing` validation case → 73 issues, this task's
  among them; `PlansViewModel` passing `lookingFor: nil` → the four-host test;
  the init not seeding, and `purchase()` dropping `bought:` → the sheet's tests;
  the store dropping `bought:` → the store test. "One host passing nil" was run
  on one host; the per-host pin fired four times under the unseeded init. The
  store test's fixtures set each entry's preference opposite to what the
  purchase records, so a store reading the preference fails. Notes: `Purchase`'s
  memberwise init defaults `bought` to nil, so Q8's "required" binds
  `PurchaseFormViewModel.init` only; a stale comment in
  `WishlistPurchaseStoreTests` ("the eleven `Item.init` is passed" — now twelve)
  left for the sweep; a red run with dozens of failures can pass 600 s.

- [x] **T005 — Looking for through the wishlist form's view model; both Copies; sale and return.**
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
  **Done (2026-10-01).** `scripts/verify.sh` green (the implementer's verbatim
  output): 1779 tests in 234 suites (+6 test functions). G12:
  `startsWithLookingForNotRecordedAndSavesWithoutIt`,
  `savesLookingForAndReopensWithItSelected(value:)` over both values,
  `clearingLookingForSavesNotRecorded` (which first asserts the form opened as
  Used). G13: `theCopyCarriesBought`, `theCopyCarriesLookingFor`,
  `markThenReturnLeavesBoughtUnchanged`, each on a second context from a non-nil
  value. Mutations, red and restored (`cmp` against a backup): `save()` skipping
  `lookingFor`, either `duplicate` dropping its argument, `returnToCollection`
  clearing `bought` → exactly the nine expected issues; `populate` skipping it →
  the reopen and clear legs; a validation case on nil → 61 issues, this task's
  among them. No production code for sale and return. **Criterion 20 at this
  layer** rests on "a new form is nil" and "an unset save stores nil" — an "old
  entry reopens as nil" assertion was written and removed as a carried-across
  nil; the on-disk half is T014(a)'s. For the sweep: neither `duplicate` passes
  `year` or `reverbProductID` — predates this spec, not checked whether intended.

  **Phase 2 closes here — `walkthrough: none`; after its review, run on.**

## Phase 3 — Screens · walkthrough: yes — on the item form (More details) a Bought row with New and Used sits just above Condition, neither picked; pick one, save, and the item's page reads "Bought new" or "Bought used" where it said "Bought" beside the date; tap the picked chip again and it clears, and the page goes back to "Bought"; the wishlist form has a Looking for row after "How much do you want it", and the wanted item's page shows "Looking for · New" or "Used" (nothing when unset); marking that item bought opens the sheet with its Bought chip already picked to match, changeable before saving; a matched wanted item set to New shows a figure from new listings after its next refresh, and "new listings" wherever it used to say "used listings"; the six condition chips sit on one line you can slide sideways, on the item form and on the Mark as bought sheet; a chip is cut off at the edge of the screen to show there is more; an item saved as Fair or Broken reopens with that chip already in view; and, the person's own check, Accessibility Inspector or VoiceOver over the Bought and Looking for chips (each announces its word and whether it is selected; a cleared row announces nothing selected) and over the two page rows

- [ ] **T006 — The shared chips, the condition row as one scrolling row, and criterion 18 guarded. `review: per-task`.**
  *(Rewritten 2026-10-01 — plan Amendment A, spec Decision 11; nothing of the
  earlier wording was built.)* Per plan §6, Q5, Q9. New
  `Trove/Views/Shared/ChoiceChips.swift` with `ChoiceChip` (extracted
  **verbatim** from `ItemFormView.conditionChip` — no visual change),
  `ConditionField(label:selection:)` **as plan §6 now specifies** — a mono label
  over `ScrollViewReader { ScrollView(.horizontal, showsIndicators: false) {
  HStack(spacing: Self.chipSpacing) { ChoiceChip(…).id(condition) } }
  .scrollClipDisabled().onAppear { proxy.scrollTo(selection, anchor: .center) } }`,
  no animation, `static let chipSpacing: CGFloat = 8`, scrolling on appear only —
  and `NewOrUsedField(label:identifier:selection:)` exactly as plan §6 specifies
  (the field calls `NewOrUsed.selection(afterTapping:current:)`; chips identified
  `"<identifier>.new"`/`".used"`; the field an accessibility container labelled
  with its field label; an `HStack`, it does not scroll). `ItemFormView` and
  `PurchaseFormView` replace their private chip copies and `FlowLayout` rows with
  `ConditionField` — `PurchaseFormView` keeps its `conditionField` property name.
  **Delete `Trove/Views/Shared/FlowLayout.swift`** (no user remains; synchronized
  folders, no `.pbxproj` edit), fix the `FlowLayout` comment at
  `PurchaseFormView.swift:12`, and rewrite `design/tokens.md`'s Condition row,
  saying Decision 11 supersedes the wrapped chips in
  `design/screens/Trove Item Form.png`. If leg (iv) goes red with `onAppear`, the
  fallback is an initial `ScrollPosition(id:anchor:)` state — routine, no new
  decision.
  Pattern: `CategoryPickerField.swift:76-95` (the row and the scroll-on-appear);
  `ItemFormView.conditionChip` (the chip);
  `TroveTests/ItemListHeaderLayoutTests.swift` (`ImageRenderer` under a real
  theme); `testAddingAnItemThroughQuickAddPutsItInTheList` and
  `testMarkingAWantedItemBoughtMovesItToTheCollection` (the UI walks).
  Tests — **G14** as plan §6 and §12 now give it, every mutation run and
  recorded: new `TroveTests/ConditionFieldLayoutTests.swift`, legs (b) and (d),
  chips rendered alone, widths and the six-chip total recorded against 327, 354
  and 392 pt (mutations: `.frame(width: 60)` on `ChoiceChip` → (b) red;
  `chipSpacing = 24` → (d) red); new UI tests
  `testTheConditionRowIsOneScrollingRowAndOpensOnTheSelectedGrade` (legs (i)–(iv),
  item form, its own item, no seed change) and
  `testThePurchaseSheetsConditionRowIsOneScrollingRow` (legs (i)–(iii)), reading
  `isHittable` and `frame` **before** any `tap()` (mutations: a two-row layout →
  (i) red; the `ScrollView` removed → (ii) red; `.scrollDisabled(true)` → (iii)
  red; the `.onAppear` scroll deleted → (iv) red); new
  `TroveTests/ProvenanceWiringTests.swift`: both forms compose `ConditionField(`
  exactly once and contain no `Capsule()`, and `ChoiceChips.swift` carries
  `.scrollClipDisabled()` (mutations: paste the old chip back into either form →
  red; remove `.scrollClipDisabled()` → red); `NewOrUsedField` calls
  `NewOrUsed.selection(afterTapping:` (mutation: a hand-rolled toggle → red).
  `MenuPolicyTests` and every existing `WishlistPurchaseWiringTests` test green
  unedited. The Done note records: the six widths and the total; where "Good"
  ends against the 354 pt field (the existing `buttons["Good"]` taps depend on
  it); whether (iv) passed with `onAppear` or needed the fallback; and that the
  look of the peek is untested.
  Files: `Trove/Views/Shared/ChoiceChips.swift` (new),
  `Trove/Views/Shared/FlowLayout.swift` (deleted),
  `Trove/Views/Items/ItemFormView.swift`, `Trove/Views/Wishlist/PurchaseFormView.swift`,
  `design/tokens.md`, `TroveTests/ConditionFieldLayoutTests.swift` (new),
  `TroveTests/ProvenanceWiringTests.swift` (new), `TroveUITests/TroveUITests.swift`.
  **Verify:** `scripts/verify.sh` green, both new unit suites in the count, **and
  `scripts/verify.sh ui` green once** — the scroll-on-appear and the existing
  chip taps are mechanisms to instrument, not reason about; the orchestrator
  re-runs both before committing. Mutations and the measured widths recorded.

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
  *(Added at T003's review.)* Before the upgrade, match the wanted entry on
  `main` so it carries a figure; after it, that figure still shows and its words
  still say "used listings" — the local market store gained
  `MarketFigureRecord.isNewStockOnly`, and a store that failed to open would
  drop every existing figure until the next refresh (Decision 9).
  **(b) iPhone SE (3rd generation) layout**, in both appearances, on the item
  form and the sheet *(Amendment A)*: the six condition chips on one line; a
  chip visibly cut off at the screen edge; the row slides by finger to Broken;
  an item saved as Broken reopens with Broken in view (the one deterministic
  check kept here, because the UI suite does not run at 375 pt); the Bought and
  Looking for rows start at the same left edge with the same chip size. Confirm
  from the installed runtimes that no supported iPhone is narrower than 375 pt
  (plan Q9). Selected state is **not** this pass's: the UI tests read
  `isSelected` (G20), and the spoken names were the person's step at the
  Phase 3 pause.
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
| Phase 1 | yes | the six-grade condition row and Very Good on a page. **The person (2026-10-01)**: the sixth grade is there, but the row spanning two lines "isn't good" → spec Decision 11 (one scrolling row, six grades kept), plan Amendment A, T006 rewritten |
| Phase 2 | no — `walkthrough: none` | nothing observable; view models, Copy and the market's reading of an unset preference |
| Phase 3 | | Bought and Looking for on the three forms, the two pages, the sheet's prefill, the New-preference figure; the person's Accessibility Inspector / VoiceOver step over the chips and rows |
| Phase 4 | | the templates, a CSV round trip, an old file, both PDFs |
| Phase 5 | no — `walkthrough: none` | the device pass; the person's two-device steps wait in `SYNC-CHECKS.md` |

## Handoff note

Involvement level: **product owner** (`CLAUDE.md`). Model policy: **Opus
profile** — every role at `opus`, no dispatch carries a model override, the
session at `claude-opus-5-5` medium; the plan-and-tasks draft ran at the
implementation tier under the trial continuing from `018`. Foundational phase:
**Phase 1**; `review: per-task`: **T001**, **T003** and (from 2026-10-01) **T006**. Pause cadence: after each phase
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
| T001 (`sdd-implementer`) | `opus` | 130,312 (15 tool uses, 37.1 min) | Done first pass; 11 mutations red and restored. Verification runs after touching `Item.swift` take 3+ min each |
| T001 per-task review (`skeptical-reviewer`) | `opus` | 54,410 (3 tool uses, 1.8 min) | Signed off, no blocking; 7 second-look notes (recorded in T001's Done note). Ran one grep beyond the bundle — the production-reads check the implementer's report lacked |
| T002 (`sdd-implementer`) | `opus` | 48,794 (19 tool uses, 31.4 min — 16.5 of it the UI suite, 10.5 the red mutation run) | Done first pass; no deviations |
| Phase 1 review (`skeptical-reviewer`) | `opus` | 55,690 (2 tool uses, 1.3 min) | Signed off, no blocking. Second-look notes carried forward: (1) a direct write of `"very good"` into `conditionRawValue` reads Very Good on this build, so every later save-path test (form, sheet, duplicate, import) asserts the stored pair `("good", "very good")` on a second context — T004's G10 already does; add to T011's round trip; (2) today's item-page row is the literal `"Bought"` (`ItemDetailView.details`, confirmed by the orchestrator at the sync), so `detailDateRowLabel(nil)` matches it — T009 replaces that literal; (3) T011 pins `Looking For` by literal (it differs from the label by one capital on purpose); (4) a stale refinement brings Very Good back if an older app moves Good → Fair → Good — R4's stated edge, one line for the `SYNC-CHECKS.md` step; (5) plan §1/§12 still cite the two renamed tests — for the close-out; (6) G7's strings were not mutated, only the rule (literal equality cannot be vacuous); (7) `SellPlanViewModelTests.swift:1207` double, for the sweep |
| Phase 1 pause finding → decision review (`skeptical-reviewer`) | `opus` | 84,596 (27 tool uses, 5.7 min) | The person rejected the wrapping condition row (spec Decision 11). Recommendation transcribed as plan Amendment A: `ConditionField` copies `CategoryPickerField`'s scrolling row; G14 rewritten around two UI tests; `FlowLayout` deleted; T006 rewritten and marked `review: per-task`. No product question. **Protocol note**: the question was framed in a decision bundle with no code touched, but not inside Plan Mode — its exit needs the person's approval of a technical plan, which the product-owner level does not ask of them. Also: the Phase 1 build had only been installed on the test simulator (iPhone 18 Pro, iOS 27.0); the orchestrator built and launched it on the person's iPhone 17 Pro (26.5) when they asked — a pause report should say which simulator carries the build |
| T003 (`sdd-implementer`) | `opus` | 165,216 (29 tool uses, 22.7 min) | Done first pass; 12 mutations red and restored. Finding: the 600 s diagnostics wait hits red *single-suite* runs only — red whole-suite runs finish in about a minute, so mutations go against plain `scripts/verify.sh` |
| T003 per-task review (`skeptical-reviewer`) | `opus` | 55,180 (2 tool uses, 1.7 min) | Signed off, no blocking; 5 second-look notes (in T003's Done note). Its note 2 checked by the orchestrator with one grep: a third "used listings" string exists (`candidateReading`, the match picker) — recorded, goes to the person at the Phase 3 pause |
| T004 (`sdd-implementer`) | `opus` | 115,960 (19 tool uses, 19.6 min) | Done first pass; 8 mutations in three batched whole-suite runs |
| T005 (`sdd-implementer`) | `opus` | 83,102 (18 tool uses, 28.6 min) | Done first pass; 6 mutations in three whole-suite runs. Two foreground calls hit the 600 s tool limit and finished in the background |
| Phase 2 review (`skeptical-reviewer`) | `opus` | 62,185 (6 tool uses, 1.7 min) | Signed off, no blocking. Second-look notes for the sweep: (1) no test drives `markBought` with a Very Good purchase and asserts the stored pair on a second context (correct by construction through `Item.init`); (2) UI suite owed at the phase's final commit — run by the orchestrator, row below; (3) `Purchase`'s memberwise init defaults `bought`; (4) criterion 7 says the sheet's Bought field is "unselected" while 23 preselects it from a preference — built to 23 and P6; the wording goes to the person at the Phase 3 pause; (5) stale comments: "three hosts"/"G12 pins" on three `makePurchaseFormViewModel` docs and the host test, "the eleven `Item.init` is passed"; (6) the two "starts not recorded" tests' stored-nil lines are default nils — not save coverage; (7) "one host passing nil" was mutated on `PlansViewModel` only. Went outside the bundle for three greps on the Very Good question |
| Phase 2 end, UI suite (orchestrator, 2026-10-02) | `claude-opus-5-5` medium | — | `scripts/verify.sh ui` at `58bb664`: 38 tests, 0 failures (1015 s). Phase 2 runs on to Phase 3 (`walkthrough: none`) |

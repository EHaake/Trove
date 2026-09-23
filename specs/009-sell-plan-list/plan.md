# 009 — Sell Plan List — Technical Plan

**Status**: Signed off (2026-09-22) by the `skeptical-reviewer`; the spec-conformance summary approved by the person on 2026-09-22

Drafted by the `sdd-planner` (per `CLAUDE.md`'s model policy as amended
2026-09-19: every role runs at `opus`, no dispatch carries a model override)
against the approved `spec.md` (Approved 2026-09-22) and the code on the
`009-sell-plan-list` branch at `8124f12`. Planning proposals (Q1–Q19) become
decisions on plan approval, as `014`'s and `015`'s did. The readings the plan
had to take a side on are under **Readings for sign-off**; none is a product
fork, each is stated so the reviewer can overturn it, and each reaches the
person in plain words at the pause where it can first be seen.

Revised 2026-09-22 after the `skeptical-reviewer`'s sign-off: blocking
finding 1 (the carry-over fired on a failed import and in `.localOnly`) is
fixed in Q2, Q3 and §4, with the derive-on-read alternative weighed there;
the non-blocking findings are folded in where each lands. Finding 2 (R2, R4)
went to the person and came back 2026-09-22 as spec Decisions 11 and 12 —
transcribed into R2, R4, §5, §11 and T005/T011 by the orchestrator.

## Context

Spec 009 makes a sell plan a **stored fact** on a wanted item (Decision 1),
carries existing plans over **once** (P10), gives plans a **fourth tab** with
Active and Completed sides (P1, P5), a **Dashboard card** (P6), deletion from
the row and from the plan's own screen (Decision 9, P3, P4, P11), a
**read-only record** for a completed plan (P12), and a fourth host for `015`'s
purchase sheet (Decision 7). Decisions 1–10 and P1–P12 settle the behaviour;
this plan settles the shape.

The footprint: **two new synced fields** (`WishlistItem.sellPlanCreatedAt`,
`WishlistItem.sellPlanCheckedAt`), **seven new production files**
(`SellPlanCopy`, `SellPlanSummary`, `SellPlanStore`, `PlansViewModel`,
`PlansView`, `PlansCard`, the `TabPlans` imageset), and changes to
`SyncMonitor`, `TroveApp`, `UITestSeed`, `AppRouter`, `ContentView`, the
Sell Plan screen and its view model, the wanted item's page and its view
model, the Dashboard and its view model, and two shared components
(`SideSwitch`, `DetailOverflowMenu`). No export column, no import change, no
new service, no network code, no `.pbxproj` edit (the root `Trove` group is a
synchronized folder — a new `Views/Plans/` subfolder and a new imageset join
the build by existing; if either doesn't, stop and flag). No constitution
amendment.

**Merged decisions this reverses, each with a pointer appended in place at
close-out, never edited away** (`014/plan.md:704-711` is the pattern):

- `015` T012c (`specs/015-mark-as-bought/plan.md`, *As built*, "A saved sell
  plan now leaves a trace"): the entry point's two states were derived from
  the selection. P9 replaces that with a stored plan and a create state.
- `015` §8's "a one-row menu is a menu for nothing" — true of the Buy action
  it was written about; this plan puts **Delete** behind a one-row "…" on the
  Sell Plan screen (Q12), for the reason `DetailOverflowMenu` exists at all.
- `001`'s `ContentView` doc comment ("Three, not four") — a code comment,
  corrected in place at T012 rather than pointed at: the fourth slot is
  filled, as `001` said it would be when a real feature needed it. If
  `specs/001-core-inventory/plan.md` states the three-tab rule itself, T016
  appends the pointer there too.

## Readings for sign-off (not open questions — the plan builds to each)

- **R1 — A completed plan's record is the Sold section plus the date bought,
  with no figures card.** P12 enumerates the record: "what sold toward it and
  when it was bought, and nothing that acts." The three-figure card's first
  cell is **Selected**, which on a bought entry reads "$0 · 0 of 0 items" (the
  selection was released at the purchase); dropping just that cell would be a
  two-figure layout nobody has drawn. So the record shows its heading, a
  "Bought <date>" line, and the existing Sold section — each sale with its
  date and price, as today — or one quiet line when nothing sold toward it.
  Heard at the Phase 4 pause (it is first reachable there).
- **R2 — A completed row has no picture and no picture slot** (spec
  Decision 11, the person's answer 2026-09-22 — superseding this plan's draft
  reading, an always-empty placeholder, which the person rejected). `015` Q6
  moves an entry's photos onto the bought item and keeps no link back, so a
  bought entry has nothing to draw. `PlanRow` carries `showsThumbnail`, set by
  the view model — true for an active row, false for a completed one — and
  `PlanRowView` draws `RowThumbnail` only when it is true. An active row
  without a photo still gets `RowThumbnail`'s placeholder (`001`'s rhythm
  rule, within a side).
- **R3 — Carried-over plans are dated when the carry-over ran**, not guessed
  from the wanted item's own date: the app does not know when a pre-`009`
  plan began, and a stored date should be a fact (the `015` Decision 2
  instinct). Under **Newest** they therefore sit together, ordered among
  themselves by the wishlist's own order (the tie-break, Q9).
- **R4 — The Dashboard card appears only where the Dashboard shows figures**,
  exactly as the Sold card does: with no owned items the Dashboard shows its
  first-run state, and no card, even if a plan exists. Confirmed by the person
  2026-09-22 as spec Decision 12 and written into criterion 15.
- **R5 — Settings' "Delete all wanted items" takes active plans with their
  wanted items and leaves completed plans on the Completed side.** Deleting a
  wanted item takes its plan (spec, "Deleting a plan"), and a bought entry is
  not on the wishlist (`015` R1, which that delete already honours).
- **R6 — The Plans tab has no search, no category chips, no header summary
  line and no "…"**: the spec lists none, exports are unchanged (P7), and
  Settings stays reachable from the other three tabs.
- **R7 — On a device using iCloud, the carry-over waits for the first
  successful import of the launch** (Q3), and it never runs on a launch where
  iCloud failed to load. Until it runs, a Plans side with nothing on it says
  "Catching up with iCloud" when there are plans still to carry, and a wanted
  item whose plan is still waiting reads "Create a sell plan" on its page —
  tapping it creates the plan then and there, as the person's own act (Q2).
  One accepted wrinkle: on a `.localOnly` launch (iCloud failed to load for
  that launch) the same "Catching up with iCloud" line can appear, although
  nothing is syncing; it lasts that one launch, only on stores from before
  this spec. On a device
  that stays offline this can last the whole offline session. The wait is
  what stops a second device, working from an old copy, from bringing back a
  plan that was deleted on the first.

## Proposed at planning (Q1–Q19) — approved on plan approval unless overturned

- **Q1. The plan is one optional date on the wanted item, not an entity.**
  `WishlistItem.sellPlanCreatedAt: Date?` — nil means no plan. The spec
  forbids more than one plan per want and a plan spanning wants, so a
  `SellPlan` `@Model` would be a one-to-one relationship with nothing of its
  own but a date, plus a CloudKit relationship whose two ends can arrive out
  of order. The simpler structure holds everything the spec asks for.
  **Active** is `hasSellPlan && !isBought`; **completed** is
  `hasSellPlan && isBought` — no third state, no stored lifecycle.
- **Q2. "Once" is recorded per entry, in synced data** —
  `WishlistItem.sellPlanCheckedAt: Date?`. Nil only on a row written by an app
  older than `009` that no `009` device has checked; **stamped at `init`** for
  every entry created from `009` on (there is nothing to carry), and by the
  carry-over for everything else. A per-device `UserDefaults` flag was
  rejected: a second device updated a week later would run the carry-over
  over entries the first device had already carried *and the person had
  since deleted the plan of* — their sold-toward history still there (P3) —
  and resurrect them. Stored on the row, the "already looked at this" travels
  with the row. The three scenarios the dispatch named:
  - *Two devices both run it*: each writes the same two fields on the same
    unchecked rows; either write means "has a plan, checked". No duplicate
    can exist (a plan is not a row).
  - *A device runs it before synced data arrives*: it doesn't — on iCloud it
    waits for a **successful** import (Q3), and a failed import never
    triggers it. Rows arriving later, still unchecked, are carried at the
    next successful import.
  - *A deleted plan*: delete leaves `sellPlanCheckedAt` set, so no device
    ever re-evaluates that row, whatever history it carries (G7).
  **Residual, stated — three windows remain where a write can land on an old
  copy**, each handed to the person's two-device step (T015):
  (1) a finished **failed setup** is taken as "signed out" (the signature
  `SyncMonitor`'s T051 probe found) and runs the carry-over on local rows — if a signed-in device
  launched offline reports the same event, it is indistinguishable, and
  **unverified**; (2) a **multi-pass first import**: the hook fires after
  the first successful pass, and a row whose newer state is still in a later
  pass is carried from its old one; (3) whichever write CloudKit keeps when
  such a carried row meets a deletion, and whether an app older than `009`
  editing a row preserves fields it doesn't know. `.localOnly` is **not** a
  window: the carry-over does not run there (Q3). These are the same class of
  limit `015` inherited, and `DECISIONS.md` records "once, per row" with them
  at close-out.

  **Weighed and rejected as the mechanism: deriving the plan for unchecked
  rows on read** (the sign-off's alternative). It removes every launch-time
  write, so no stale write can happen at all — its real strength. But a
  derived plan lives only as long as its evidence, and the evidence is
  destroyed by at least seven writers in five files (`SellPlanViewModel.toggle`,
  `ItemSaleStore.markSold` — which drops the sold item from **every** plan's
  selection, not just the one it sold toward — `ItemSaleStore.returnToCollection`,
  `WishlistPurchaseStore.markBought`, and every owned-item delete, where the
  loss is the implicit `.nullify` cascade, including Settings' bulk delete).
  Each would have to store the derived plan of every affected row first, or
  criterion 2 breaks silently the moment the last ticked item goes; and the
  only guard that could enumerate those writers is a source scan, the shape
  `CLAUDE.md` says leaves the thing untested. **Kept from it, read-only**:
  `WishlistItem.awaitsCarryOver` (§1) — the carry-over's own predicate — is
  read in **one** place so the pending window is honest rather than wrong: an
  empty Plans side says `stillSyncing` while any row awaits (criterion 16).
  **The wanted item's page does not read it** (orchestrator fix after the
  sign-off re-review, 2026-09-22): the draft had the page treat a waiting row
  as having a plan and store it when the person tapped **View** — which, on a
  device whose import failed, is the same stale-copy write this trigger
  exists to prevent, moved from launch to a tap, and on a button the person
  pressed to look rather than to create. A waiting row reads **Create a sell
  plan** instead; the only write the page can make is an explicit create.
- **Q3. When the carry-over runs: `SyncMonitor.onSettled`.** A closure
  `SyncMonitor` calls on the main actor **only when this device's copy is
  known current or known to be the only copy**: on every **successful
  import**; on a finished **failed setup event** (the signed-out signature);
  and at `init` for `.ephemeral` (an in-memory store no other device can
  touch). **Never** on a failed import, and **never in `.localOnly`** — that
  mode is the synced store opened without its mirror for one launch, so a
  write there would export next launch from a copy of unknown age; skipping
  costs one launch. Always **before** `completedImports` moves, and followed
  by a bump of a new `settledCount`, which the Dashboard and the Plans tab
  also reload on — a failed setup moves no import count, so without it the
  launch tab would keep a stale zero. Ordering by construction, not by the
  unspecified order of two `onChange` handlers. `TroveApp.init` passes
  `SellPlanStore.runCarryOver` over the main context; the UI-test seeds move
  above the `SyncMonitor` construction so an in-memory launch carries a
  seeded legacy row exactly as an upgrade would (Q18).
- **Q4. `SellPlanStore` is the one writer of plan state**, the
  `ItemSaleStore`/`WishlistPurchaseStore` shape — an `enum` in `Trove/Models/`,
  **callers save** (except `runCarryOver`, which is its own intent with no
  other caller):

  ```swift
  enum SellPlanStore {
      /// The plan exists from this instant (spec: "created when selecting
      /// Create a sell plan"). False, writing nothing, on a bought entry;
      /// true without rewriting the date when a plan already exists.
      @discardableResult
      static func create(for wanted: WishlistItem, at now: Date) -> Bool
      /// Decision 9, P3: the plan and the current selection go; the
      /// sold-toward record, every item, and the entry itself stay.
      static func delete(planOf wanted: WishlistItem, at now: Date)
      /// P10: every unchecked entry with a selection or a sold-toward
      /// history gets a plan dated `now`; every unchecked entry is stamped
      /// checked. Returns how many plans it made. The caller saves.
      static func carryOver(in context: ModelContext, at now: Date) throws -> Int
      /// `carryOver`, then one save **only if `context.hasChanges`** — the
      /// closure `SyncMonitor.onSettled` runs, on every settle. On a refused
      /// save it rolls back, which discards *every* pending change on the
      /// main context, not only its own (the house caveat; the app saves
      /// each intent immediately, so there is normally nothing else).
      static func runCarryOver(in context: ModelContext, now: Date)
  }
  ```

  `create` and `delete` both stamp `sellPlanCheckedAt` when nil, so any
  plan-state write settles the row — for `delete` a defence rather than a
  path normal use reaches, and G6 carries a leg for it (a delete on an
  unchecked row leaves it checked, so a later carry-over cannot re-plan it).
  Views never name the store (G17, G19).
- **Q5. `SellPlanSummary` — one derivation of a plan's facts and its words,
  three readers.** `setAsideCount` (`plannedSaleItems.count`),
  `soldTowardCount` (`itemsSoldToward.count`), `isCovered` (Q6), and the two
  pieces of copy built from them with `SellPlanCopy`: `rowLines(boughtDate:)`
  — the row's lines, each present only when its count is non-zero — and
  `entrySubtitle`, the wanted item's page's fallback (P9). The sold-price sum
  is **one static helper**, `SellPlanSummary.soldCents(of:)`, which
  `SellPlanViewModel.soldValueCents` now calls too, so the Sell Plan
  screen's Sold figure and the covered rule cannot read different sums.
  No money field is stored: it carries a Bool, never the sum (Q8).
- **Q6. Covered is the sales alone against the estimate** (P8, Decision 10):
  `estimatedCostCents > 0 && soldCents >= estimatedCostCents`, where
  `soldCents` sums `sale?.priceCents` — the price recorded at the sale, never
  a current value, never the selection. Deliberately **not**
  `SellPlanViewModel.selectedValueMeetsCost`, which adds the selection; G4's
  fixture makes that property true and this one false.
- **Q7. `SellPlanCopy` is this spec's one string table** (`PurchaseCopy`'s
  shape: `nonisolated enum`, no SwiftUI, pinned whole by literal). The wanted
  item's entry-point strings **move into it** from
  `WishlistDetailViewModel` — the spec's Copy section puts them in the one
  type — and `PurchaseCopy`'s doc comment, which says they live inline, is
  corrected in the same task. Settled strings in §3.
- **Q8. The Plans rows are a value type with nothing to draw money from.**
  `PlansViewModel.PlanRow` holds `id`, `name`, `categoryPath`, `photos`,
  `lines` (from `SellPlanSummary.rowLines`, so which counts show is a
  view-model fact G10 reaches, not a branch in the view), `boughtDate` — no
  `Cents` field. Criterion 8 is then guarded
  twice: structurally (the row cannot supply a figure) and by one source scan
  on the view (it draws no currency) — a view-body fact no view-model test
  reaches (G19).
- **Q9. Sort options (P5) and the tie-break.** Active:
  `newest` (default), `oldest`, `name`, `wishlistOrder`, labelled "Newest",
  "Oldest", "Name", "Wishlist order". Completed: `newest` (default),
  `oldest`, `name` — "Newest"/"Oldest" read the **date bought** there. Every
  order falls back to `ManualOrderHelper.areInCustomOrder` (position, name,
  id), so ties — R3's carried-over plans above all — are fully determined.
  `wishlistOrder` *is* that comparator. Comparators are static with the order
  as an argument, the `014` G3 shape, so the tie-break is asked about a pair
  directly in both argument orders rather than through `load()`.
- **Q10. The empty reasons are the Plans view model's own enum**, not new
  `ListEmptyReason` cases: that type is about narrowing a list, and this
  screen narrows nothing. `noPlans`, `nothingWanted`, `nothingCompleted`,
  `stillSyncing` — the last outranking the others, since each is a claim
  about the whole collection (`SellPlanViewModel.poolEmptyReason`'s
  reasoning). `stillSyncing` is chosen while the monitor may still be
  importing **or while any row `awaitsCarryOver`** (Q2): with the narrower
  trigger, an offline signed-in device is not "importing" yet has plans still
  to carry, and "No sell plans yet" would be the wrong diagnosis.
- **Q11. The completed record is gated in the view model, not by the store's
  refusal.** `SellPlanViewModel` gains `isCompleted`, `offersPurchase`,
  `offersDelete`; `toggle` and `markSold` write nothing on a completed plan;
  `load()` builds no candidate pool for one. The view branches on
  `isCompleted` and gates Buy on `offersPurchase`. `WishlistPurchaseStore`'s
  `alreadyBought` stays as the backstop it is, never as the thing that hides
  the action.
- **Q12. Deleting a plan: the row's trailing swipe on both sides, and a "…"
  holding only Delete on the plan's own screen.** `DetailOverflowMenu` gains
  `init(noun:delete:)` with no Edit row (`edit` becomes `Row?`); a plan has
  nothing to edit, and Delete keeps the second tap every other detail page's
  Delete has. On an active plan the "…" sits beside Buy. Both hosts use the
  existing alert idiom and `SellPlanCopy`'s one-clause message.
  **Amended 2026-09-23 at the person's Phase 3 walkthrough:** a "…" holding
  one row read as a menu with nothing in it, and Buy grouped beside it
  looked odd. The plan's own screen shows **Delete as its own toolbar
  button**, in rust (`accentRustText`, §9a), physically separate from Buy — no "…"
  and no `DetailOverflowMenu` on this screen, so its delete-only
  initializer is withdrawn. Still two taps: the button opens the same
  alert. Nothing else is planned for the menu (reopening a completed
  plan is a spec Non-goal), so there is nothing to group. The row swipes
  are unchanged. Task T009b.
- **Q13. Buy from a row is the leading swipe on Active rows only**, `015`'s
  Wishlist shape exactly (`Buy` + `ActionBuy`, `accentBrassMid`, spoken
  `PurchaseCopy.markAsBought`), hosted `.sheet(item:)` over the staged row,
  with the refusal alert — the fourth host. Completed rows have no leading
  swipe.
- **Q14. `SideSwitch` becomes generic over its side**, with a constrained
  `init(side:select:)` per screen, so `ItemListView`'s call site and
  `ItemListSidesWiringTests`' scan of it are untouched. Swift forbids stored
  statics in a generic type, so `slideDuration`, `height` and the default
  `halfWidth` move to a non-generic `SideSwitchMetrics` in the same file and
  the one test reference follows them. Whether **"Completed" fits a 62 pt
  half** at 11 pt mono medium is unknown — the task measures it with a
  scratch render and sets Plans' half width from the measurement (G18).
- **Q15. The tab icon is drawn to match** (Decision 8):
  `design/icons/tab-plans.svg` in the tab set's language (24 viewBox, flat
  `#000` fills, the `scale(1.2)` group, opacity steps as `TabWishlist` uses):
  two squares, the left at 0.45 opacity and the right solid, joined by a
  right-pointing arrow — gear funding a want. Template, vector preserved.
  Revisitable; the device pass looks at it in both appearances.
- **Q16. The Dashboard card copies the Sold card's chrome into `PlansCard`**
  rather than generalizing `SoldCard`: the Sold card's delta line, colour
  rule and attributed figures are `006`-guarded, and this card needs a
  header, one line and the arrow. About fifteen lines of plate-and-arrow
  duplicated; an extraction is a roadmap line if a third card appears.
- **Q17. Routing: `AppRouter.Tab.plans`, `plansPath: [UUID]`, and a
  `wantsActivePlans` flag** — `itemsPath`'s shape and the add-item flag's
  (a request the destination applies and clears). `showActivePlans()` selects
  the tab, pops its stack and raises the flag; `PlansView` applies it with
  `viewModel.show(.active)`.
- **Q18. A new UI-test seed, `-seedPlans`, under `CLAUDE.md`'s two
  conditions**: its own argument, and `shouldSeedPlans(mode:arguments:)`
  gated on the built store being `.ephemeral`. It writes through the app's
  own writers (`SellPlanStore.create`, `ItemSaleStore.markSold`,
  `WishlistPurchaseStore.markBought`) — **except one row**, whose
  `sellPlanCheckedAt` it sets to nil: the legacy shape only a pre-`009` app
  writes, and the only way any automated test can observe that the
  carry-over is actually wired at launch (per `CLAUDE.md`, wiring whose only
  coverage is a source scan is untested). `015`'s As built named this seed's
  absence as a gap.
- **Q19. Four sets of merged tests change meaning and are rewritten to pin
  the new rule, never loosened**:
  `WishlistPurchaseWiringTests.theSellPlanOffersMarkAsBoughtOnlyWhileItsEntryIsStillThere`
  (`015` G18: its gate becomes `offersPurchase`);
  `SellPlanWiringTests.theSoldSectionIsHostedUnderTheEmptyStateToo`
  (`soldSection` gains the record as a third host: count 3 → 4);
  `WishlistDetailViewModelTests`' four T012c entry-point tests (`hasSellPlan`
  now reads the stored plan); and the two UI tests that tap "Find items to
  sell". Each rewrite records the mutation that would have passed the old
  guard and fails the new one.

---

## Layout and files

New production files:

- `Trove/Models/SellPlanCopy.swift`, `Trove/Models/SellPlanSummary.swift`,
  `Trove/Models/SellPlanStore.swift`
- `Trove/ViewModels/PlansViewModel.swift`
- `Trove/Views/Plans/PlansView.swift` (with its private `PlanRowView`)
- `Trove/Views/Dashboard/PlansCard.swift`
- `Trove/Assets.xcassets/TabPlans.imageset/` (`Contents.json` +
  `tab-plans.svg`) and `design/icons/tab-plans.svg`

Changed: `Trove/Models/WishlistItem.swift` (§1), `Trove/App/SyncMonitor.swift`,
`Trove/App/TroveApp.swift`, `Trove/App/UITestSeed.swift` (§4, §13),
`Trove/ViewModels/SellPlanViewModel.swift`, `WishlistDetailViewModel.swift`,
`DashboardViewModel.swift`, `AppRouter.swift` (§5–§8),
`Trove/Views/Wishlist/SellPlanView.swift`, `WishlistDetailView.swift`,
`Trove/Views/Dashboard/DashboardView.swift`, `Trove/App/ContentView.swift`,
`Trove/Views/Items/SideSwitch.swift`, `Trove/Views/Shared/DetailOverflowMenu.swift`
(§9–§12); `Trove/Models/PurchaseCopy.swift` (doc comment only).

New test files: `SellPlanCopyTests`, `SellPlanSummaryTests`,
`SellPlanStoreTests`, `PlansViewModelTests`, `PlansWiringTests`. Extended:
`ModelTests`, `CloudKitSchemaTests` (comment), `SyncMonitorTests`,
`UITestSeedTests`, `SellPlanViewModelTests`, `WishlistDetailViewModelTests`,
`DashboardViewModelTests`, `AppRouterTests`, `SellPlanWiringTests`,
`WishlistPurchaseWiringTests`, `ItemListSidesWiringTests` (one reference),
`TabIconTests`, `TroveUITests`. Docs at close-out: `spec.md`, this file,
`design/tokens.md`, `README.md`, `specs/ROADMAP.md`, `DECISIONS.md`, and the
pointers above.

---

## 1. The plan on `WishlistItem` (foundational)

```swift
/// 009: when this wanted item's sell plan was created, or nil when it has
/// none. **The one plan predicate** — a plan is a stored fact, never
/// inferred from the selection (spec Decision 1). Written only by
/// `SellPlanStore`.
var sellPlanCreatedAt: Date?

/// 009: when this entry's plan state became stored rather than inferred —
/// stamped at `init` for every entry made from 009 on, and by the one-time
/// carry-over (spec P10) for older ones. Nil only on a row an app older than
/// 009 wrote and no 009 device has checked yet. Synced, so "once" travels
/// with the row (plan Q2).
var sellPlanCheckedAt: Date?

var hasSellPlan: Bool { sellPlanCreatedAt != nil }

/// 009: an older row the carry-over has yet to reach that will become a plan
/// when it does — unchecked, with a selection or a sold-toward history. **The
/// carry-over's own predicate** (`SellPlanStore.carryOver` reads it), and
/// read-only everywhere else (plan Q2): it never makes a plan by itself.
var awaitsCarryOver: Bool {
    sellPlanCheckedAt == nil
        && (!(plannedSaleItems ?? []).isEmpty || !(itemsSoldToward ?? []).isEmpty)
}
```

Both declared **without an initializer** (the `boughtDate` precedent); `init`
gains `self.sellPlanCheckedAt = .now` and no parameter. So `duplicate(id:)`,
the import and every seed make planless, checked entries — "an imported
wanted item arrives with no plan" by construction.

**The CloudKit claim and its test.** Both fields are optional with no unique
constraint, additive to the existing store. `CloudKitSchemaTests` already
builds a real CloudKit-configured container over `WishlistItem`; T001 makes
`sellPlanCreatedAt` `@Attribute(.unique)`, watches the suite (and
`TwoStoreContainerTests`, `015` T001's finding) go red, and reverts (G1).
**"A pre-009 row reads `sellPlanCheckedAt == nil` after migration"** is
load-bearing — if it read non-nil, nothing would ever carry over and no test
in the unit suite would notice. It rests on the same optional-attribute rule
`boughtDate` relied on; it is **verified on a real migrated store at the
device pass** (T015, upgrade in place from `main`), not asserted.

## 2. `SellPlanSummary` and the covered rule

```swift
struct SellPlanSummary: Equatable {
    let setAsideCount: Int
    let soldTowardCount: Int
    let isCovered: Bool
    init(_ wanted: WishlistItem)
    /// Active: setAside(n) if n > 0, soldToward(n) if n > 0, covered if
    /// covered. Completed: bought(on:), soldTowardPast(n) if n > 0, covered.
    func rowLines(boughtDate: Date?) -> [String]
    /// P9's fallback: setAside(n), else soldToward(n), else nothingSetAside.
    var entrySubtitle: String { get }
    static func soldCents(of sold: [Item]) -> Int      // sum of sale?.priceCents
    static func isCovered(soldCents: Int, estimatedCostCents: Int) -> Bool
}
```

`Trove/Models/SellPlanSummary.swift`, main-actor by default (it reads
`@Model`s). `SellPlanViewModel.soldValueCents` becomes
`SellPlanSummary.soldCents(of: soldItems)` — one sum, two readers.
**Testable claims** (G4): the covered cases — sales exactly at the
estimate → covered; a dollar short → not; estimate 0 with sales → not; a
selection worth more than the estimate over sales short of it → not, while
`SellPlanViewModel.selectedValueMeetsCost` reads **true** on the same entry;
an item whose `currentValueCents` exceeds the estimate but whose sale price
does not → not (Decision 10). Agreement over one entry: `soldTowardCount`
equals `SellPlanViewModel.soldCount` and `soldCents` equals its
`soldValueCents`. `rowLines`: zero counts produce **no line** on either side
(criterion 7), a completed entry's first line is the bought date, `covered`
last and only when covered; `entrySubtitle`'s three readings.

## 3. `SellPlanCopy` — the settled strings

| Member | String |
|---|---|
| `tab` | `Plans` |
| `active`, `completed` | `Active`, `Completed` |
| `sideSwitchLabel` | `Active or completed` |
| `createPlan` | `Create a sell plan` |
| `noPlanSubtitle` | `Browse your lowest desire-to-keep items` (moved, unchanged) |
| `viewPlan` | `View your sell plan` (moved, unchanged) |
| `setAside(_ n:)` | `1 item set aside` / `<n> items set aside` (moved, unchanged) |
| `soldToward(_ n:)` | `<n> sold toward it` |
| `soldTowardPast(_ n:)` | `1 was sold toward it` / `<n> were sold toward it` |
| `nothingSetAside` | `Nothing set aside yet` |
| `covered` | `Covered` |
| `bought(on:)` | `Bought <date, .abbreviated>` |
| `nothingSoldToward` | `Nothing was sold toward it.` |
| ~~`overflowNoun`~~ | withdrawn at T009b (Q12 amended 2026-09-23) — Delete is its own button, labelled `deleteConfirm` |
| `deleteTitle(for:)` | `Delete the sell plan for <name>?` |
| `deleteMessage(isCompleted:)` | `Nothing you own or sold is touched, and <clause>. What sold toward it stays on the record. This can't be undone.` — clause `it stays on your wishlist` / `the item you bought stays in your collection` |
| `deleteConfirm`, `deleteCancel` | `Delete`, `Keep` |
| `cardHeader` | `Sell plans` |
| `activeCount(_ n:)` | `1 active sell plan` / `<n> active sell plans` |
| `cardHint` | `Shows your active sell plans` |
| `noPlansHeadline` / `…Detail` | `No sell plans yet` / `A plan starts from something on your wishlist. Open it and tap Create a sell plan.` |
| `nothingWantedHeadline` / `…Detail` | `Nothing on your wishlist` / `A sell plan starts with something you want. Add it to your wishlist first.` |
| `nothingCompletedHeadline` / `…Detail` | `Nothing completed yet` / `A plan lands here when you mark its item bought.` |
| `stillSyncingDetail` | `Your plans are on their way to this device. They'll appear here as they arrive.` (headline: the app's existing `Catching up with iCloud`) |

The delete message is **one function with one varying clause** — the spec's
guard against `WishlistDeleteCopy`'s recorded drift — and G3 pins it by
splitting both renderings into sentences and requiring exactly one to differ.
Sort labels stay on their enums (the `SoldSortOrder.label` pattern). None of
these words trips `SellPlanFramingTests` ("covered" is not "covers").

## 4. `SellPlanStore` and the carry-over's trigger (foundational)

Per Q2–Q4. `delete(planOf:at:)` sets `sellPlanCreatedAt = nil` and
`plannedSaleItems = []`, stamps `sellPlanCheckedAt` if nil, and touches
nothing else — no `Item`, no `itemsSoldToward`, not the entry. `carryOver`
fetches `#Predicate<WishlistItem> { $0.sellPlanCheckedAt == nil }` and, per
row: if `awaitsCarryOver` → `sellPlanCreatedAt = now`; always
`sellPlanCheckedAt = now`. A bought row
qualifies by its sold-toward history alone, since `015` released its
selection — the spec's rule falls out of the one predicate.

`SyncMonitor` gains `init(mode:onSettled:)` (default nil, so every existing
construction compiles unchanged) and, in `record(_:)`:

```swift
phase = Self.phase(after: event, from: phase)
let imported = event.kind == .importChanges && event.isFinished && event.succeeded
let signedOut = event.kind == .setup && event.isFinished && !event.succeeded
if imported || signedOut { settle() }            // never on a failed import
if imported { completedImports += 1 }            // after the hook

private func settle() { onSettled?(); settledCount += 1 }
```

plus `settle()` at the end of `init` **for `.ephemeral` only** — not
`.localOnly` (Q3). The trigger is an **event**, not the `.unavailable`
edge: `phase(after:from:)` maps *any* finished failed event to
`.unavailable`, a failed import included, which is exactly the stale-copy
case (sign-off B1). `TroveApp.init`: store → the UI-test seeds (moved up;
they need only the store; T014 adds the third) → `SyncMonitor(mode:onSettled:)`
with `{ SellPlanStore.runCarryOver(in: context, now: .now) }`.

**Testable claims.** G5 `create`; G6 `delete` — the entry, every `Item` and
its sale fields, and `itemsSoldToward` identical on a second context, the
plan and selection gone (criteria 10–12), and a delete on an unchecked row
leaving it checked; G7 the carry-over — six fixture
rows (selection only; sold-toward only; bought with sold-toward; bought with
neither; wanted with neither; **checked, planless, with sold-toward — a
deleted plan**), the fifth and sixth stay planless, a second run returns 0,
the date written is `now` and differs from the rows' `createdAt`; G8 the
hook — fires once at `init` for `.ephemeral` and **never** at `init` for
`.localOnly` or `.cloudKit`; once on a successful import **with
`completedImports` still at its old value inside the hook**; once on a
finished failed setup; **not** when setup succeeds and an import then
finishes failed (the phase reads `.unavailable` and the hook stays silent);
never on an export or an in-flight event; `settledCount` rises by one after
each call.

## 5. `PlansViewModel`

```swift
@Observable
final class PlansViewModel {
    enum Side: Hashable { case active, completed }
    enum ActiveSortOrder: String, CaseIterable, Identifiable { case newest, oldest, name, wishlistOrder }
    enum CompletedSortOrder: String, CaseIterable, Identifiable { case newest, oldest, name }
    enum EmptyReason: Equatable { case noPlans, nothingWanted, nothingCompleted, stillSyncing }
    struct PlanRow: Identifiable {           // Q8: nothing to draw money from
        let id: UUID; let name: String; let categoryPath: String; let photos: [Photo]
        let lines: [String]; let boughtDate: Date?   // lines: SellPlanSummary.rowLines
        let showsThumbnail: Bool                  // R2: set by the split, false on Completed
        var isCompleted: Bool { boughtDate != nil }
    }

    private(set) var side: Side = .active    // every launch opens on Active
    var activeSortOrder: ActiveSortOrder = .newest
    var completedSortOrder: CompletedSortOrder = .newest
    private(set) var activeRows: [PlanRow] = []
    private(set) var completedRows: [PlanRow] = []
    var rows: [PlanRow] { side == .active ? activeRows : completedRows }
    var emptyReason: EmptyReason? { … }      // Q10
    var visibleSortLabel: String { … }
    var purchaseFailureMessage: String?      // 015 T012b's shape, fourth host
    var completedImports: Int { syncMonitor.completedImports }
    var settledCount: Int { syncMonitor.settledCount }   // reload on both (Q3)

    init(modelContext: ModelContext, syncMonitor: SyncMonitor = .notSyncing, now: @escaping () -> Date = Date.init)
    func show(_ side: Side)                  // sets and reloads; clears nothing
    func load()
    func makePurchaseFormViewModel(for row: PlanRow) -> PurchaseFormViewModel
    @discardableResult func markBought(_ row: PlanRow, purchase: Purchase) -> Bool
    @discardableResult func deletePlan(id: UUID) -> Bool
    static func areInActiveOrder(_ l: WishlistItem, _ r: WishlistItem, under: ActiveSortOrder) -> Bool
    static func areInCompletedOrder(_ l: WishlistItem, _ r: WishlistItem, under: CompletedSortOrder) -> Bool
}
```

`load()` fetches every `WishlistItem` once and splits (`015` Q11's shape):
the planned ones into active and completed, the count of unbought ones for
`emptyReason`'s `noPlans`/`nothingWanted` choice, and whether any row
`awaitsCarryOver` (Q10's `stillSyncing`); it keeps the entries by
id privately for the two intents. `markBought` is `WishlistViewModel`'s
body over the looked-up entry — store, one save, `rollback()` → message →
`load()` → false on refusal. `deletePlan` is `SellPlanStore.delete`, one save,
`rollback()` + `load()` on refusal, silent as every delete in the app is.

**Testable claims** — G10 membership: a plan whose every selected item has
been **sold** stays on Active (criterion 2 — mutation: `active` read as
`!plannedSaleItems.isEmpty` → red); buying moves it to Completed; a bought
entry with no plan and a wanted entry with no plan are on neither side
(criterion 3); an orphan — bought with a plan, its created `Item` deleted —
is on Completed and `deletePlan` takes it off while the entry stays in the
store (criterion 13, P4); `showsThumbnail` is true on every active row and
false on every completed one (criterion 7, Decision 11 — mutation: set it true
throughout → red); each row's `lines` equal `SellPlanSummary.rowLines`
for its entry, with no line for a zero count (criterion 7 — mutation: emit
`setAside(0)` → red). G11 sorts, fixture
chosen so every order differs from the others:

| Active | plan created | wishlist position |
|---|---|---|
| Bravo | day 1 | 0 |
| Alpha | day 2 | 2 |
| Charlie | day 3 | 1 |

Newest C,A,B · Oldest B,A,C · Name A,B,C · Wishlist order B,C,A.

| Completed | bought | plan created |
|---|---|---|
| Delta | day 5 | day 1 |
| Echo | day 4 | day 3 |
| Foxtrot | day 6 | day 2 |

Newest F,D,E · Oldest E,D,F · Name D,E,F — and sorting by plan date instead
of bought date reads E,F,D, so that mutation goes red. The tie: two plans
with one `sellPlanCreatedAt`, asked of the static comparator in both argument
orders, fall the wishlist-order way and not the name way. Per-side state:
set Active to Name, `show(.completed)`, set Oldest, `show(.active)` → Name
still; a fresh view model is on Active with both defaults Newest (criteria
5, 6). G12 the four empty reasons and `stillSyncing`'s precedence
(criterion 16), including a **not-importing** monitor over a store holding
one row that `awaitsCarryOver` → `stillSyncing`, not `noPlans` (mutation:
drop the awaiting check → red). G13 the fourth purchase host: `015`'s
`everyHostSeedsThePurchaseSheetIdentically`, `everyHostRefusesToBuyAnEntryTwice`
and the "one landing" test (the `Landing` comparison near
`WishlistDetailViewModelTests.swift:1597`, which would catch
`PlansViewModel.markBought` drifting from the body it copies) extended to
four hosts — the Plans host's fixture entry needs a plan, since its subject
comes from its rows; confirming moves the row from `activeRows` to
`completedRows` (criterion 14).

## 6. `SellPlanViewModel` — the record and the delete

Adds `isCompleted` (`wishlistItem?.isBought == true`), `offersPurchase`
(`wishlistItem != nil && !isCompleted`), `offersDelete`
(`wishlistItem?.hasSellPlan == true`), `boughtDate`, and
`@discardableResult func deletePlan() -> Bool`. `toggle` and `markSold`
return without writing when `isCompleted`; `load()` skips the owned fetch
and leaves `candidates` empty for a completed plan. `soldValueCents` reads
`SellPlanSummary.soldCents(of:)` (Q5) — the same sum, from one place.
Everything else — ranking, figures, `markBought` — unchanged (the spec's
Non-goals).

**Testable claims** (G14, `SellPlanViewModelTests`, second context):
completed → `isCompleted`, `!offersPurchase`, `candidates` empty,
`soldItems` still the history; `toggle` on it leaves `plannedSaleItems`
empty (mutation: drop the guard → red); `markSold` on it returns false and
the item stays unsold; `deletePlan` on active and on completed leaves every
`Item` identical and the entry present (criteria 10, 11).

## 7. `WishlistDetailViewModel` — the entry point (P9)

`hasSellPlan` reads the stored plan only, `item.hasSellPlan` — **not**
`awaitsCarryOver` (Q2: a row the carry-over has yet to reach reads "Create a
sell plan", so a tap can never write a plan from a stale copy on a button
pressed only to look); `plannedSaleCount` becomes `sellPlanSummary: SellPlanSummary?`, set in
`load()`. Title: `viewPlan` with a plan, `createPlan` without. Subtitle:
without a plan `noPlanSubtitle`; with one, `sellPlanSummary.entrySubtitle`
(Q5) — never "0 items". New intent
`@discardableResult func openSellPlan() -> Bool`: with a stored plan, true;
otherwise `SellPlanStore.create` (an explicit create, whether or not the row
awaits the carry-over — and on a waiting row it keeps that row's existing
selection, as the carry-over would; added at Phase 3's review),
one save, true — or `rollback()` and false, and the view doesn't navigate.
The view's button becomes `if viewModel.openSellPlan() { sellPlanRoute = … }`.
The type's header comment ("No ranking or Sell Plan logic lives here") is
rewritten: the page now creates a plan, through `SellPlanStore`, and still
computes no candidates.

**Testable claims** (G16): the readings, each fixture distinct (a plan with
2 set aside and 1 sold reads the set-aside line; 0 set aside and 1 sold reads
"1 sold toward it"; neither reads the fallback; no plan and checked reads
"Create a sell plan"; **unchecked with 2 selected** — awaiting the carry-over
— reads "Create a sell plan" and the no-plan subtitle, and `openSellPlan` on
it creates the plan); `openSellPlan` creates exactly once (a second call keeps the first
date). The four T012c tests are rewritten to this rule (Q19).

## 8. `DashboardViewModel` and `AppRouter`

`DashboardViewModel.load()` adds `activePlanCount` via `fetchCount` over
`#Predicate<WishlistItem> { $0.sellPlanCreatedAt != nil && $0.boughtDate == nil }`
(zeroed in the catch), `showsPlansCard: Bool { scope.isEmpty && activePlanCount > 0 }`,
`plansLine` from `SellPlanCopy.activeCount`, and `settledCount` passed
through from the monitor so `DashboardView` reloads on it (Q3; sign-off
finding 3 — the launch tab is the one showing when a signed-out device's
carry-over lands). `AppRouter` per Q17.

**Testable claims** (G15): the count excludes completed and planless
entries; `showsPlansCard` false at 0 and false in any scope with plans
present (P6); `showActivePlans` selects `.plans`, empties `plansPath` and
raises the flag, `clearPlansRequest` lowers it; `.plans` is the fourth case.

## 9. The Sell Plan screen (P11, P12)

`body` becomes `if let wanted { if viewModel.isCompleted { record(for: wanted) } else { content(for: wanted) } }`.
`record(for:)`: the heading (`[SellPlanCopy.completed] + category` over the
name, the active heading's shape), `SellPlanCopy.bought(on:)` quietly beneath,
then `if viewModel.hasSales { soldSection } else { Text(SellPlanCopy.nothingSoldToward) }`
in a `ScrollView` — no figures, no candidates header, no rows, no empty pool.
The toolbar:

```swift
.toolbar {
    if viewModel.offersPurchase {
        ToolbarItem(placement: .topBarTrailing) { /* 015's Buy button, unchanged */ }
    }
    if viewModel.offersDelete {
        // T009b (Q12 amended 2026-09-23): its own red button, apart from Buy
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button(role: .destructive) { isConfirmingDelete = true } label: { Text(SellPlanCopy.deleteConfirm) }
        }
    }
}
```

and an alert over `SellPlanCopy.deleteTitle`/`deleteMessage(isCompleted:)`
whose Delete runs `if viewModel.deletePlan() { dismiss() }`. From the wanted
item's page the dismissal lands on it, whose `onAppear` reload offers
**Create a sell plan**; from the Plans tab it lands on the list. Two trailing
items on iOS 26 may share one glass group — the device pass looks (T015).

**Testable claims** (G17, `SellPlanWiringTests` + the rewritten `015` G18):
the Buy button sits inside exactly one `if viewModel.offersPurchase` span and
nowhere else (mutation: gate back on `wishlistItem != nil` → red — the exact
mutation the old guard would have passed on a completed plan); the "…" sits
inside `if viewModel.offersDelete` and holds no `Button`; `record(for:)` names
no `candidateList`, `SellPlanRow`, `figures(`, `saleCandidate`,
`isMarkingBought` or `viewModel.toggle`; `soldSection` has one declaration
and three hosts; the delete confirm dismisses only inside the `deletePlan()`
branch; the file names no `SellPlanStore`. The record's *behaviour* is G14's.
`MenuPolicyTests` is re-confirmed with a real `Menu` placed **in page
content** — inside `record(for:)`, the location the rule ("bespoke in the
page") exists for — not in the toolbar, where a red could be read as the
file-level allowlist firing rather than the page rule (sign-off finding 10).

### 9a. Destructive actions are drawn in rust — T009d (decided 2026-09-23, decision review)

At the person's instruction ("the Delete button needs to be red … implemented
as standards across the app"). A destructive action is any control with
`ButtonRole.destructive`. **Where the app draws the control, the colour goes on
the control itself; where the system draws it, the role alone does it.** The
Sell Plan's toolbar Delete gets `.tint(theme.colors.accentRustText)` (a word,
so the text token; `.foregroundStyle` on the label if the device check shows
`.tint` loses to `ContentView`'s brass cascade on the glass toolbar). **No
shared modifier** (swipes need the fill token, words the text token, and
Settings colours its label through `SettingsActionRow.color` — a shared
modifier would be a parameter plus a rewrite of merged screens, against the
spec's "no new component"); **rust, not system red** (tokens.md's swipe rule
and the spec's "no new colour" settle it; the person is told plainly at the
pause that "red" means the app's rust, and the alert's Delete stays system
red). Rejected: cutting the brass tint at the root (brings system red onto
every app-drawn control).

**Guard — `DestructiveColourPolicyTests`** (a view-body fact no view model can
see, `MenuPolicyTests`' shape): over `Trove/Views` and `Trove/App` through
`SourceScan.production`, every `\.destructive\b` is classified by its
enclosing brackets (one scan per file, a bracket stack that skips string
literals): inside `alert`, `confirmationDialog`, `contextMenu` or `Menu` →
system-drawn, exempt; otherwise the nearest enclosing call must be `Button`
(else fail "unclassified destructive site"), and that Button's extent — its
parentheses, trailing closures and modifier chain — must contain `accentRust`.
One exemption, `SettingsView.swift` (colour via `SettingsActionRow.color`),
itself pinned: the file must still read `isDestructive ?
theme.colors.accentRustText`. Anchors `#require`d: the file floor; an empty
bracket stack at each file's end; at least 13 sites, ≥ 8 system-drawn, ≥ 5
app-drawn. Mutations that must go red: the tree before the fix (naming
SellPlanView only); the Items owned-row swipe's `.tint` removed; the fix's
`.tint` moved onto Buy; the fix commented out; the Delete re-spelled
`Button(SellPlanCopy.deleteConfirm, role: .destructive)` uncoloured; the role
spelled `ButtonRole.destructive`; Settings' destructive colour made brass. It
must not fire on the seven alert buttons, DetailOverflowMenu's row, or
comments. It proves the colour is named on the control, not that it renders —
the device check (a screenshot sampled in both appearances against
`#B8674F`/`#8E3A24` and brass) is the rendering half. It does not reach a
destructive action without the role (MarketSection's "Remove match" is rust
by hand), nor which rust token a site used.

Written as `design/tokens.md`'s **Destructive actions** section and a
`CLAUDE.md` line in its own commit. Q12's and the toolbar comment's "in red"
read "in rust (`accentRustText`)".

## 10. `SideSwitch` generic (shared)

Per Q14: `struct SideSwitch<Side: Hashable>` with `leading`/`trailing` side
values and labels, `selected`, `halfWidth`, `accessibilityLabel`,
`identifier`, `select`; the fill's offset reads `selected == leading`.
`extension SideSwitch where Side == ItemListViewModel.Side { init(side:select:) }`
keeps Owned/Sold, "Owned or sold", `items.sideSwitch`; the Plans extension
gives Active/Completed, `SellPlanCopy.sideSwitchLabel`, `plans.sideSwitch`
and its measured half. **Testable claims** (G18): every label of both
switches renders narrower than its half less 4 pt either side, measured on a
scratch `ImageRenderer` render at the switch's own font (mutation: Plans' half
at 50 → red); `ItemListSidesWiringTests` green with one reference renamed.

## 11. The Plans tab

`PlansView` — `WishlistView`'s file shape with only what the spec asks for:
a fixed header (`Plans` in `screenTitle`, the `SortBadge` on the right while
`!viewModel.rows.isEmpty`), the `SideSwitch` under it reporting through
`viewModel.show`, then the empty state or a plain `List` of `PlanRowView`s.
`dropdownHost` with `.sort` only: `SortDropdown` over the side's enum,
`isManualOrder: { _ in false }` on both (P5 — no REORDER tag). Row tap:
`router.plansPath.append(row.id)`; one `.navigationDestination(for: UUID.self)`
to `SellPlanView`. Leading swipe, Active rows only (Q13). Trailing swipe
stages `pendingDeletion`; the alert reads `SellPlanCopy` with
`deleteMessage(isCompleted: row.isCompleted)`. `.sheet(item: $planBeingBought,
onDismiss: viewModel.load)`, both closures nil-ing the state; the refusal
alert; `.onAppear` applies `router.wantsActivePlans` then loads;
`.onChange(of: router.wantsActivePlans)`; `.onChange(of:
viewModel.completedImports)` and `.onChange(of: viewModel.settledCount)`;
`.refreshable` with `RefreshPacing`.

`PlanRowView` — `WishlistRow`'s head (`RowThumbnail` **only when
`row.showsThumbnail`** — no slot, no placeholder otherwise, R2 — name in `rowTitle`,
category `monoLabel`, the stock-photo accessibility value) with
`ForEach(row.lines)` stacked beneath in `secondary` on `textQuiet` (`015`
T011b's house pairing). **The view decides nothing about which lines show**
— `SellPlanSummary.rowLines` did (Q5, G4, G10). No trailing column, no gauge,
no figure; `.extrudedPlate()`; one combined accessibility element.

`ContentView` gains the fourth `Tab(SellPlanCopy.tab, image: "TabPlans",
value: .plans) { NavigationStack(path: $router.plansPath) { PlansView(…) } }`
and loses "Three, not four".

**Testable claims** (G19, `PlansWiringTests`, each `#require`-ing its anchor,
each a view-body fact): the leading swipe block is composed inside an Active
gate only, names `Text(PurchaseCopy.swipeBuy)`, `Image("ActionBuy")`,
`.accessibilityLabel(PurchaseCopy.markAsBought)`, writes `planBeingBought`;
the trailing block stages `pendingDeletion` and names no `PurchaseCopy`; one
purchase sheet over `PurchaseFormView(` and `makePurchaseFormViewModel(for:`
whose cancel closure clears the staging (the `015` T011a lesson); the file
names no `formattedAsWholeCurrency`, no `.currency(`, no `Cents`, no
`SellPlanStore`, no `WishlistPurchaseStore`; `PlanRowView` draws
`row.lines` and names no `SellPlanCopy` count function; `SideSwitch` is called with `viewModel.show` and no
`$`; every `SortDropdown(` passes `isManualOrder: { _ in false }`.
`PlansView.swift` joins `purchaseHosts` in `WishlistPurchaseWiringTests`, and
`MenuPolicyTests` stays green unedited. **Not guarded by any automated
test, said plainly**: which clause each host passes to
`deleteMessage(isCompleted:)` — the copy is G3's, the host's choice of
`row.isCompleted` / `viewModel.isCompleted` is read at the device pass
(T015), where both alerts' text is recorded. G20: `TabIconTests` lists four
names and four distinct marks.

## 12. The Dashboard card

`PlansCard(line:action:)` — `SoldCard`'s button, plate, `cardPadding`,
brass arrow and combined element, with `SellPlanCopy.cardHeader` over `line`
in `monoValue`/`textPrimary`, hint `SellPlanCopy.cardHint`, identifier
`dashboard.plansCard`. `DashboardView` composes it directly below the Sold
card inside `if viewModel.showsPlansCard`, action `router.showActivePlans()`,
and gains `.onChange(of: viewModel.settledCount) { viewModel.load() }` beside
its existing `completedImports` reload (Q3). **Testable claims** (G21): composed exactly once, inside that gate, calling
`router.showActivePlans()`. The count and scope rules are G15's.

## 13. UI tests and the device pass

`UITestSeed.plans(into:now:)` under `-seedPlans` (Q18). Owned: Telecaster
(value $600, desire 2), Blues Junior, NT1-A, Leica M6 (desire 5 — so the
Dashboard has figures). Wanted: **Summicron 35mm f/2** ($2,400, plan
3 days ago, Telecaster set aside); **Vox AC15** ($1,050, plan 2 days ago,
Blues Junior sold toward it for $1,100 — covered, and the selection emptied
by the sale: criterion 2's case); **Hasselblad 80mm** ($950, plan 5 days ago,
NT1-A sold toward it for $300, then bought — Completed, not covered); **Rode
NT5** (no plan); **Nikon FM2** (bought, no plan — on neither side);
**Fuji X100V** (Telecaster set aside, `sellPlanCheckedAt` nil — carried over
at launch, so Active by the wiring alone).

UI tests (`TroveUITests`, all on `-uiTesting -seedPlans`):

- `testThePlansTabSitsFourthAndOpensOnActiveEveryLaunch` — tab buttons
  ascending `minX` Overview/Items/Wishlist/Plans; the switch's value Active;
  Fuji, Vox, Summicron listed (Fuji proves the launch wiring — mutation: drop
  `onSettled` from `TroveApp.init` → red); Vox's row reads "1 sold toward it"
  and "Covered"; Rode, Nikon, Hasselblad absent; Completed lists Hasselblad
  with "Bought"; terminate, relaunch → Active again.
- `testSortingEachSideReordersTheRowsAndIsKeptAcrossASwitch` — Name puts
  Summicron before Vox; switch to Completed and back → still Name.
- `testAnActiveRowsBuySwipeMovesThePlanToCompleted` — partial drag on
  Summicron, "Mark as bought…" alone (never `OR "Buy"`), price reads 2400;
  Cancel → still Active; again, confirm → gone from Active, on Completed.
- `testDeletingAPlanLeavesTheWantedItemAndTheSale` — trailing swipe on Vox,
  the alert's title, Delete → gone; Wishlist lists Vox, whose page offers
  "Create a sell plan"; Items' Sold side still lists Blues Junior.
- `testACompletedPlanOpensAsARecord` — Hasselblad: no `purchase.sellPlan`, no
  "Sell candidates", the NT1-A sold row present, "Bought" present, the "…"
  offering Delete.
- `testTheDashboardCardOpensThePlansTabOnActive` — leave Plans on Completed;
  Overview's card reads "3 active sell plans"; tap → Plans, switch value
  Active.
- `testCreatingASellPlanFromAWantedItem` — Rode → "Create a sell plan" → the
  Sell Plan screen → back → "View your sell plan" over "Nothing set aside
  yet"; Plans lists Rode.

The two `-seedSellPlan` tests that tap "Find items to sell" tap "Create a sell
plan" instead (T008). `scripts/verify.sh ui` twice back to back at Phase 4's
end.

**Device pass** (T015, a `general-purpose` agent with simulator tools): an
**upgrade in place** — build `main`, install, make wanted items with a
selection, with sales toward them, one bought, one plan-free; build this
branch, install over it; confirm the carried-over plans on the right sides
and nothing else (criterion 4 and §1's migration claim on a real store);
then on the persistent store: every screen in both appearances, the tab icon,
"Completed" in its half, the header not moving between sides (read `minY`
from the tree), the Sell Plan's two bar items, the record, the delete alerts'
text, the Dashboard card; a **file probe** in `SellPlanStore.delete` and
`carryOver` (delete: swipe-cancel 0, alert-Keep 0, Delete 1; carry-over on
relaunch: 0 plans made the second time) removed before the suites run;
relaunch for persistence (criterion 17). **The person's steps**: VoiceOver
over a row, the switch, the card and the Sell Plan's "…"; and, with two
devices, a plan created, deleted and carried over on one seen correctly on
the other (criterion 17's sync half) — including Q2's three windows: a
signed-in device launched **offline** (does its setup finish failed, and so
run the carry-over on an old copy?), a device returning after a long
absence (a multi-pass import), and which write survives if a carried row
meets a deletion made elsewhere.

## 14. Docs and close-out

At T016: criteria 1–19 ticked with per-criterion citations — **criterion 19
by inspection** (no new service, no `URLSession`, no change under
`Trove/Market/` or `Trove/Photos/`), criterion 17 an honest partial until the
two-device step; the Copy section's shapes replaced by the shipped strings
(P-items → decisions); this file gains **As built**; `design/tokens.md` gains
the Plans screen, the card and the fourth tab icon; `README.md`;
`specs/ROADMAP.md`'s `009` entry and status row (and the `015` follow-up for a
seeded saved plan, now done); `DECISIONS.md` (a plan as a stored date; "once"
per row and synced, why not per device, and **its limits** — Q2's three
windows as the two-device step left them; derive-on-read weighed and
rejected, and what was kept of it; the settle hook firing on events, never
on a failed import or in `.localOnly`; R1–R7 as the person left them; the
`015` reversals); the pointers from Context. Then
the pre-merge `skeptical-reviewer` sweep over `git diff main...HEAD`, bundle
cut after `git add -A`, and the PR marked ready.

## 15. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `CloudKitSchemaTests` (and `TwoStoreContainerTests`) over the two fields | `@Attribute(.unique)` on `sellPlanCreatedAt` |
| G2 | `ModelTests`: fresh entry planless and checked at init; a date makes `hasSellPlan` true | init stamp dropped; predicate inverted |
| G3 | `SellPlanCopyTests`: every string by literal; plurals; the two delete messages differ in exactly one sentence | any word drifts; a shared sentence reworded on one side |
| G4 | `SellPlanSummaryTests`: counts; covered at, below, zero estimate, selection-only, value-not-price; `rowLines` with no zero-count line; `entrySubtitle`'s three readings; count **and sum** agreement with `SellPlanViewModel` | `>` for `>=`; zero guard dropped; selection added; `currentValueCents` read; a zero-count line emitted; `soldValueCents` summing on its own |
| G5 | `SellPlanStoreTests.create`: date `now`, checked stamped, idempotent, refuses bought | date rewritten on a second call; a bought entry gains a plan |
| G6 | `SellPlanStoreTests.delete`, second context: plan and selection gone; entry, every `Item`'s sale and value fields, and `itemsSoldToward` identical; an unchecked row left checked | sold-toward cleared; selection kept; an item unsold; the entry deleted; the nil-stamp dropped |
| G7 | `SellPlanStoreTests.carryOver`: six rows, all six end checked, a second run returns 0, the deleted plan never resurrected, dated `now` | the checked filter dropped (resurrection leg); sold-toward ignored (sold-only and bought legs); only planned rows stamped (**the all-six-checked leg** — the idempotency leg stays green, since a second run makes no plan either way); `createdAt` written (date leg) |
| G8 | `SyncMonitorTests`: `onSettled` at init for `.ephemeral` only; on a successful import, before the bump; on a finished failed setup; **not** on a failed import after a good setup; never on export/in-flight; `settledCount` after each call | hook after the bump; fired on the `.unavailable` edge (the failed-import leg); fired at init in `.localOnly`; fired on export |
| G9 | `UITestSeedTests`: `shouldSeedPlans` refuses a persistent store with every flag set; the seed's shape; one carry-over over it yields three active | gate reads the flag alone; seed row missing |
| G10 | `PlansViewModelTests` membership: all-sold stays Active; bought moves; planless on neither; orphan shown and deletable; rows' `lines`; `showsThumbnail` true on Active, false on Completed | active from the selection; completed ignoring the plan; a zero count drawn |
| G11 | `PlansViewModelTests` sorts: seven orders over two fixtures; the tie both ways; per-side persistence; fresh defaults | a comparator dropped or reversed; bought date read as plan date; tie by name; one shared sort |
| G12 | `PlansViewModelTests` empty reasons and precedence, including an awaiting row under a not-importing monitor | `stillSyncing` below another; `nothingWanted` for a planless wishlist; the awaiting check dropped |
| G13 | four-host seed equality, refusal and the one-landing comparison; the Buy moves the row | `?? 0` in the fourth seed; the fourth host skipping the store or its save |
| G14 | `SellPlanViewModelTests` completed mode and `deletePlan` | toggle guard dropped; pool built for a bought entry |
| G15 | `DashboardViewModelTests`, `AppRouterTests` | completed counted; card in a scope; flag not raised |
| G16 | `WishlistDetailViewModelTests` entry point and `openSellPlan`, including a row awaiting the carry-over | fallback order swapped; "0 items set aside"; plan re-created; an awaiting row offered "Create" |
| G17 | `SellPlanWiringTests` + rewritten `015` G18: Buy gate, delete gate, the record composes nothing that acts, `soldSection` ×3 hosts | Buy gated on `wishlistItem != nil`; a row or `toggle` in the record; dismiss outside `deletePlan()` |
| G18 | `SideSwitch` label fit; `ItemListSidesWiringTests` | a half narrower than its label |
| G19 | `PlansWiringTests`: swipes, sheet, cancel, no money (`formattedAsWholeCurrency`, `.currency(`, `Cents`), rows draw `row.lines`, switch, no REORDER; `purchaseHosts` + `MenuPolicyTests` | Buy on Completed rows; cancel not clearing; a currency figure drawn; a count line composed in the view |
| G20 | `TabIconTests`: `TabPlans` resolves, template, four distinct | template intent dropped; an existing svg copied |
| G21 | `DashboardWiringTests`-style scan of `DashboardView` | card outside the gate; wrong action |
| G22 | UI tests, §13, twice back to back | see §13 |
| G23 | Unedited and green: `PurchaseUndoTests`, `ExportSchemaTests`, `ImportSchemaTests`, `MenuPolicyTests`, `SellPlanFramingTests` (criterion 18) | — |

Every guard is mutation-verified before it lands; the Done note records what
was broken and what went red. Every new or rewritten scan `#require`s its
anchor. Fixture values differ from what a broken implementation would
produce (`015` As built): dates distinct from `createdAt`, sale prices
distinct from current values, estimates never 0 unless 0 is the case. What
the suites cannot reach — the migration, the look, the spoken names, sync —
is §13's device pass and the person's steps.

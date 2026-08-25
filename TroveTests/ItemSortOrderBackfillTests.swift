import Foundation
import SwiftData
import Testing
@testable import Trove

/// T006. The backfill is the one piece of `010` where a bug means silently
/// destroying a user's real data — a re-run against an order someone arranged
/// by hand doesn't crash, doesn't warn, it just quietly puts their gear back
/// in chronological order. So per plan.md's testing strategy, this suite gets
/// the mutation-verified treatment, and every assertion about persisted state
/// reads through a *second* `ModelContext`: the same-context refetch that let
/// a deleted `save()` pass in `001` hands back unsaved changes and can't
/// prove anything landed.
///
/// The one leg not tested here: that a *failed* save leaves the flag unset
/// (the retry-next-launch property). SwiftData offers no way to make an
/// in-memory save throw without faking `ModelContext`, which it doesn't
/// allow. The ordering is enforced by the routine's shape — the `set` is the
/// line after `save()` — and the flag-setting line itself is covered below.
@Suite("Item sort-order backfill")
struct ItemSortOrderBackfillTests {
    // MARK: - The first run

    @Test func theFirstRunAssignsSequentialOrderByCreatedAt() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // Inserted in an order deliberately different from `createdAt` order:
        // a fetch that lost its sort descriptor hands back arbitrary,
        // usually insertion-shaped order (the tie-break false-pass from
        // `001`), and with these three that produces the wrong answer
        // instead of the right one by luck.
        let items = seedItems(context, namesInInsertionOrder: ["Charlie", "Alpha", "Bravo"])
        items["Alpha"]?.createdAt = Date(timeIntervalSince1970: 100)
        items["Bravo"]?.createdAt = Date(timeIntervalSince1970: 200)
        items["Charlie"]?.createdAt = Date(timeIntervalSince1970: 300)
        try context.save()

        try ItemSortOrderBackfill.runIfNeeded(mode: .cloudKit, context: context, defaults: freshDefaults())

        let saved = try savedItemsBySortOrder(in: container)
        #expect(saved.map(\.name) == ["Alpha", "Bravo", "Charlie"])
        #expect(saved.map(\.sortOrder) == [0, 1, 2])
    }

    @Test func theRunThatLandsSetsTheFlag() throws {
        let container = try makeContainer()
        let defaults = freshDefaults()

        try ItemSortOrderBackfill.runIfNeeded(
            mode: .cloudKit,
            context: ModelContext(container),
            defaults: defaults
        )

        #expect(defaults.bool(forKey: ItemSortOrderBackfill.flagKey))
    }

    /// The fallback store opens the same collection as the CloudKit one
    /// (`TroveStoreTests` pins that), so a device that fell back still needs
    /// its items backfilled — skipping `.localOnly` would strand exactly the
    /// launches that already lost sync.
    @Test(arguments: [StorageMode.cloudKit, .localOnly])
    func bothPersistentModesRun(mode: StorageMode) throws {
        let container = try makeContainer()
        let defaults = freshDefaults()

        try ItemSortOrderBackfill.runIfNeeded(
            mode: mode,
            context: ModelContext(container),
            defaults: defaults
        )

        #expect(defaults.bool(forKey: ItemSortOrderBackfill.flagKey), "\(mode) never backfills")
    }

    // MARK: - What must never happen again

    /// The idempotency case, and the reason this suite exists: once the user
    /// has dragged things into an order, no later launch may put it back.
    @Test func anOrderTheUserArrangedSurvivesLaterLaunches() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let defaults = freshDefaults()
        let items = seedItems(context, namesInInsertionOrder: ["Alpha", "Bravo", "Charlie"])
        items["Alpha"]?.createdAt = Date(timeIntervalSince1970: 100)
        items["Bravo"]?.createdAt = Date(timeIntervalSince1970: 200)
        items["Charlie"]?.createdAt = Date(timeIntervalSince1970: 300)
        try context.save()
        try ItemSortOrderBackfill.runIfNeeded(mode: .cloudKit, context: context, defaults: defaults)

        // The user drags Charlie to the top.
        items["Charlie"]?.sortOrder = 0
        items["Alpha"]?.sortOrder = 1
        items["Bravo"]?.sortOrder = 2
        try context.save()

        // The next launch.
        try ItemSortOrderBackfill.runIfNeeded(mode: .cloudKit, context: context, defaults: defaults)

        let saved = try savedItemsBySortOrder(in: container)
        #expect(
            saved.map(\.name) == ["Charlie", "Alpha", "Bravo"],
            "A relaunch re-derived the backfill and destroyed the user's arrangement"
        )
    }

    /// Every item sitting at 0 is exactly what a store looks like when its
    /// items were created *after* the flag was set — the form doesn't assign
    /// positions yet. Values that "look unbackfilled" are not license to run.
    @Test func theFlagAloneDecidesNotWhatTheValuesLookLike() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let defaults = freshDefaults()
        defaults.set(true, forKey: ItemSortOrderBackfill.flagKey)
        let items = seedItems(context, namesInInsertionOrder: ["Alpha", "Bravo"])
        items["Alpha"]?.createdAt = Date(timeIntervalSince1970: 100)
        items["Bravo"]?.createdAt = Date(timeIntervalSince1970: 200)
        try context.save()

        try ItemSortOrderBackfill.runIfNeeded(mode: .cloudKit, context: context, defaults: defaults)

        let saved = try savedItemsBySortOrder(in: container)
        #expect(saved.map(\.sortOrder) == [0, 0], "The flag was set; nothing may be assigned")
    }

    /// T005's finding, now pinned: `UserDefaults` isn't scoped to a store, so
    /// a `-uiTesting` launch that burned the flag against its throwaway
    /// store would permanently block the real store's backfill on that
    /// device. The untouched values matter less than the unburned flag.
    @Test func theThrowawayStoreNeverRunsAndNeverBurnsTheFlag() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let defaults = freshDefaults()
        let items = seedItems(context, namesInInsertionOrder: ["Alpha", "Bravo"])
        items["Alpha"]?.createdAt = Date(timeIntervalSince1970: 100)
        items["Bravo"]?.createdAt = Date(timeIntervalSince1970: 200)
        try context.save()

        try ItemSortOrderBackfill.runIfNeeded(mode: .ephemeral, context: context, defaults: defaults)

        let saved = try savedItemsBySortOrder(in: container)
        #expect(saved.map(\.sortOrder) == [0, 0])
        #expect(
            !defaults.bool(forKey: ItemSortOrderBackfill.flagKey),
            "An ephemeral launch burned the flag — the real store on this device can now never backfill"
        )
    }

    /// The key is a persisted contract with every device that already ran
    /// the backfill. Rename it and each of them re-runs on next launch —
    /// which is the arrangement-destroying re-derive above, delivered by a
    /// refactor instead of a heuristic.
    @Test func theFlagKeyIsAPersistedContract() {
        #expect(ItemSortOrderBackfill.flagKey == "hasBackfilledItemSortOrder")
    }

    // MARK: - Support

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: TroveSchema.schema,
            configurations: ModelConfiguration(
                schema: TroveSchema.schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
    }

    /// A unique suite per test: the standard-defaults singleton would leak
    /// the flag between tests and into the test host itself.
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ItemSortOrderBackfillTests-\(UUID().uuidString)")!
    }

    @discardableResult
    private func seedItems(
        _ context: ModelContext,
        namesInInsertionOrder names: [String]
    ) -> [String: Item] {
        var byName: [String: Item] = [:]
        for name in names {
            let item = Item(name: name, categoryPath: "Test/Gear", purchasePriceCents: 100)
            context.insert(item)
            byName[name] = item
        }
        return byName
    }

    /// Read back through a fresh `ModelContext` so only *saved* state counts.
    private func savedItemsBySortOrder(in container: ModelContainer) throws -> [Item] {
        try ModelContext(container).fetch(
            FetchDescriptor<Item>(sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.createdAt),
            ])
        )
    }
}

import Foundation
import SwiftData
import Testing
@testable import Trove

/// The list's swipe-to-delete, which until the pre-merge review was the one
/// deletion in the app that bypassed its view model — `modelContext.delete`
/// called straight from the view, untested, and silent about consequences the
/// detail screen's alert spells out.
@Suite("Wishlist deletion")
struct WishlistDeletionTests {
    private func makeWanted(
        in context: ModelContext,
        name: String,
        sortOrder: Int = 0
    ) -> WishlistItem {
        let wanted = WishlistItem(name: name, categoryPath: "Music/Amps")
        wanted.sortOrder = sortOrder
        context.insert(wanted)
        return wanted
    }

    @Test func deleteRemovesTheItemFromTheStore() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let wanted = makeWanted(in: context, name: "Vox AC15")
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.delete(id: wanted.id)

        // A second context, so this checks what reached the store rather than
        // what the first context still holds unsaved.
        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<WishlistItem>()).isEmpty)
        #expect(viewModel.items.isEmpty, "The list should reload itself after a delete")
    }

    @Test func deleteLeavesOtherItemsAlone() throws {
        let context = try makeInMemoryContext()
        let doomed = makeWanted(in: context, name: "Vox AC15", sortOrder: 0)
        makeWanted(in: context, name: "Summicron 35mm f/2", sortOrder: 1)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.delete(id: doomed.id)

        #expect(viewModel.items.map(\.name) == ["Summicron 35mm f/2"])
    }

    @Test func deleteWithAnUnknownIDDoesNothing() throws {
        let context = try makeInMemoryContext()
        makeWanted(in: context, name: "Vox AC15")
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.delete(id: UUID())

        #expect(viewModel.items.count == 1)
    }

    /// The asymmetry the alert's message states: photos go, sell-plan gear
    /// stays. Same shape as `WishlistDetailViewModelTests`' pair, because the
    /// swipe path has to keep the same promises the detail path makes.
    @Test func deleteCascadesPhotosAndSparesSellPlanGear() throws {
        let context = try makeInMemoryContext()
        let wanted = makeWanted(in: context, name: "Vox AC15")
        wanted.photos = [Photo(imageData: Data([0x01]), source: .device)]
        let owned = Item(name: "Blues Junior", categoryPath: "Music/Amps")
        owned.currentValueCents = 54_000
        context.insert(owned)
        wanted.plannedSaleItems = [owned]
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.delete(id: wanted.id)

        #expect(try context.fetch(FetchDescriptor<Photo>()).isEmpty, "Photos should cascade")
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1, "Sell-plan gear must survive")
    }

    /// 002/T006c: the device's market rows for the item — figure, history,
    /// snapshot — go with it, in the same save, read back on a second context.
    private func seedMarketRows(for id: UUID, in context: ModelContext) throws {
        let product = MarketProduct(id: 126_161, slug: "fender-american-professional-ii-telecaster", title: "Fender American Professional II Telecaster", usedLowCents: 100_000, usedTotal: 108, listingsURL: URL(string: "https://api.reverb.com/api/listings/all?cp_ids%5B%5D=320855")!)
        let figure = MarketFigure(medianCents: 140_000, lowCents: 130_000, highCents: 150_000, count: 12, fetchedAt: .now, isTruncated: false, yearScope: .any)
        try MarketLocalStore.record(.figure(figure), product: product, for: MarketSubjectKey(subjectID: id, kind: .wanted), in: context)
    }

    private func marketRowsRemain(for id: UUID, in container: ModelContainer) throws -> Bool {
        let fresh = ModelContext(container)
        let figure = try MarketLocalStore.figure(for: id, in: fresh)
        let snapshot = try MarketLocalStore.snapshot(for: id, in: fresh)
        let history = try MarketLocalStore.history(for: id, in: fresh)
        return figure != nil || snapshot != nil || !history.isEmpty
    }

    @Test func deleteClearsTheItemsMarketRowsInTheSameSave() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let doomed = makeWanted(in: context, name: "D-18")
        let kept = makeWanted(in: context, name: "Timeline", sortOrder: 1)
        try seedMarketRows(for: doomed.id, in: context)
        try seedMarketRows(for: kept.id, in: context)
        try context.save()

        let viewModel = WishlistViewModel(modelContext: context)
        viewModel.load()
        viewModel.delete(id: doomed.id)

        #expect(!(try marketRowsRemain(for: doomed.id, in: container)), "the deleted item's market rows survived it")
        #expect(try marketRowsRemain(for: kept.id, in: container), "another item's rows went too")
    }

}

/// The structural half: where deletion is allowed to live, and what both
/// routes to it must say.
@Suite("Deletion guard")
struct DeletionGuardTests {
    /// No view deletes from the store. The desire dials' write-through *saves*
    /// are an established, commented exception for nudging a scalar in place —
    /// destruction is different: it's exactly the write that wants a tested
    /// path and a consequence line, which is what the view models provide.
    @Test func noViewDeletesFromTheStoreDirectly() throws {
        let viewsDirectory = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Trove/Views")
        let files = FileManager.default.enumerator(at: viewsDirectory, includingPropertiesForKeys: nil)

        var offenders: [String] = []
        var scanned = 0
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            scanned += 1
            let source = SourceScan.stripComments(try String(contentsOf: url, encoding: .utf8))
            if source.contains("modelContext.delete(") {
                offenders.append(url.lastPathComponent)
            }
        }

        #expect(scanned > 10, "Scanned only \(scanned) view files — this would pass over nothing.")
        #expect(
            offenders.isEmpty,
            "Views deleting from the store directly, bypassing the tested path: \(offenders.joined(separator: ", "))"
        )
    }

    /// Both wishlist screens read the shared copy rather than restating it —
    /// checked per file, since the whole point is that neither can drift.
    @Test(arguments: [
        "Trove/Views/Wishlist/WishlistView.swift",
        "Trove/Views/Wishlist/WishlistDetailView.swift",
    ])
    func bothDeleteRoutesReadTheSharedCopy(path: String) throws {
        let source = try SourceScan.production(path)

        #expect(source.contains("WishlistDeleteCopy.title"), "\(path) titles its own delete alert")
        #expect(source.contains("WishlistDeleteCopy.message"), "\(path) writes its own consequence line")
    }

    /// The item side's mirror, added with its second entry point
    /// (T015/T017): both routes to an item deletion read the shared copy, so
    /// they can't drift any more than the wishlist's pair can — plan.md's
    /// testing strategy asks for exactly this extension.
    @Test(arguments: [
        "Trove/Views/Items/ItemListView.swift",
        "Trove/Views/Items/ItemDetailView.swift",
    ])
    func bothItemDeleteRoutesReadTheSharedCopy(path: String) throws {
        let source = try SourceScan.production(path)

        #expect(source.contains("ItemDeleteCopy.title"), "\(path) titles its own delete alert")
        #expect(source.contains("ItemDeleteCopy.message"), "\(path) writes its own consequence line")
    }

    /// The third delete route (013's Delete All) reads its shared copy the
    /// way the first two do — from the view model, since that's where its
    /// alert is composed (the storage-mode branch is a view-model fact).
    @Test func theSettingsDeleteRouteReadsTheSharedCopy() throws {
        let source = try SourceScan.production("Trove/ViewModels/SettingsViewModel.swift")

        #expect(source.contains("DeleteAllCopy.title"), "Settings titles its own delete alert")
        #expect(source.contains("DeleteAllCopy.message"), "Settings writes its own consequence line")
    }

    /// The consequence line carries all three promises — the cascade, the
    /// nullify, and the permanence `010` added once the undo-sentence proved
    /// equally true here. Losing any one makes the alert a shrug.
    @Test func theMessageKeepsAllThreePromises() {
        let message = WishlistDeleteCopy.message

        #expect(message.localizedCaseInsensitiveContains("photos"), "\(message)")
        #expect(message.localizedCaseInsensitiveContains("sell plan"), "\(message)")
        #expect(message.localizedCaseInsensitiveContains("undone"), "\(message)")
    }

    /// `010`'s verb unification, pinned — and pinned because T010a changed
    /// these shipped strings and found *nothing* guarding them: every test
    /// stayed green while "Remove" became "Delete". The verb matches
    /// `delete(id:)` and doesn't soften a permanent action; a drift back
    /// would now fail here instead of shipping silently.
    @Test func theConfirmButtonAndTitleSayDelete() {
        #expect(WishlistDeleteCopy.confirm == "Delete")
        #expect(WishlistDeleteCopy.title(for: "Vox AC15") == "Delete Vox AC15?")
    }
}

import Foundation
import SwiftData
import Testing
@testable import Trove

/// Plan §9, G7 — the spike the whole of 002 rests on: the pairing
/// `TroveStore` really builds (an unnamed CloudKit-mirrored configuration
/// beside the named local one, in one container over the union schema)
/// loads, and a save lands each model in its own file. Built through the
/// real builder into a scratch directory — not a hand-made pair — so what
/// is proven is what the app does.
///
/// Real disk I/O, deliberately: the split is a property of two files, and
/// no in-memory store can show it. The same narrow exception
/// `CloudKitSchemaTests` records.
@Suite("Two-store container")
struct TwoStoreContainerTests {
    @Test func theProductionPairingLoadsAndSplits() throws {
        let directory = URL.temporaryDirectory.appending(path: "two-store-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let itemID = UUID()
        let subjectID = UUID()

        do {
            let container = try TroveStore.buildContainer(TroveStore.configurations(for: .cloudKit, directory: directory))
            let context = ModelContext(container)
            let item = Item(name: "Telecaster", categoryPath: "Music/Guitars", purchasePriceCents: 1_500_00, condition: .excellent)
            item.id = itemID
            context.insert(item)
            context.insert(MarketFigureRecord(subjectID: subjectID, subjectKind: .owned, productID: 126_161, fetchedAt: .now))
            try context.save()
        }

        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "default.store").path))
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "MarketLocal.store").path))

        // The local file alone, under the local schema alone: the record is there.
        do {
            let local = try ModelContainer(
                for: TroveSchema.localSchema,
                configurations: ModelConfiguration(
                    TroveStore.localStoreName,
                    schema: TroveSchema.localSchema,
                    url: directory.appending(path: "MarketLocal.store"),
                    cloudKitDatabase: .none
                )
            )
            let records = try ModelContext(local).fetch(FetchDescriptor<MarketFigureRecord>())
            #expect(records.map(\.subjectID) == [subjectID])
        }

        // The collection's file alone, opened with the *union* schema so a
        // record could be found if it had landed there: the item is present,
        // no record is.
        do {
            let collection = try ModelContainer(
                for: TroveSchema.combinedSchema,
                configurations: ModelConfiguration(
                    schema: TroveSchema.combinedSchema,
                    url: directory.appending(path: "default.store"),
                    cloudKitDatabase: .none
                )
            )
            let context = ModelContext(collection)
            #expect(try context.fetch(FetchDescriptor<Item>()).map(\.id) == [itemID])
            #expect(try context.fetchCount(FetchDescriptor<MarketFigureRecord>()) == 0, "A market record reached the synced collection")
        }
    }
}

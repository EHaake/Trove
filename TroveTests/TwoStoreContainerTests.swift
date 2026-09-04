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
        let sentinel = "G7-SENTINEL-\(UUID().uuidString)"

        do {
            let container = try TroveStore.buildContainer(TroveStore.configurations(for: .cloudKit, directory: directory))
            let context = ModelContext(container)
            let item = Item(name: "Telecaster", categoryPath: "Music/Guitars", purchasePriceCents: 1_500_00, condition: .excellent)
            item.id = itemID
            context.insert(item)
            let record = MarketFigureRecord(subjectID: subjectID, subjectKind: .owned, productID: 126_161, fetchedAt: .now)
            record.trendRawValue = sentinel
            context.insert(record)
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

        // The collection's file alone, under the synced schema: the item.
        do {
            let collection = try ModelContainer(
                for: TroveSchema.schema,
                configurations: ModelConfiguration(schema: TroveSchema.schema, url: directory.appending(path: "default.store"), cloudKitDatabase: .none)
            )
            #expect(try ModelContext(collection).fetch(FetchDescriptor<Item>()).map(\.id) == [itemID])
        }

        // The split half of the spike, by bytes. A SwiftData reader over the
        // collection's file can't be trusted to see a local model another
        // configuration wrote there (T006a's routing finding, and the Phase 1
        // review's mutation showed exactly that), so this reads the files
        // themselves: a sentinel written on the record must be in the local
        // file with its sidecars and nowhere in the collection's.
        func bytes(of name: String) throws -> Data {
            var data = Data()
            for suffix in ["", "-wal", "-shm"] {
                let url = directory.appending(path: name + suffix)
                if FileManager.default.fileExists(atPath: url.path) { data += try Data(contentsOf: url) }
            }
            return data
        }
        let needle = Data(sentinel.utf8)
        let local = try bytes(of: "MarketLocal.store")
        let collection = try bytes(of: "default.store")
        #expect(local.range(of: needle) != nil, "the record's sentinel is not in the local store's bytes — the scan reads nothing")
        #expect(collection.range(of: Data("Telecaster".utf8)) != nil, "the item's name is not in the collection's bytes — the scan reads nothing")
        #expect(collection.range(of: needle) == nil, "A market record reached the synced collection")
    }
}

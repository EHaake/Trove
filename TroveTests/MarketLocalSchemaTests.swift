import Foundation
import SwiftData
import Testing
@testable import Trove

/// Spec 002, Decision 7 and criteria 12 and 18: the market figures, history
/// and the matched product's catalog snapshot live on the device and never
/// sync. The mechanism is a second `ModelConfiguration` in the one container
/// — `TroveStore.localConfiguration`, `cloudKitDatabase: .none`, owning
/// exactly `TroveSchema.localModels`. These are the guards on that shape,
/// each named for the mutation that turns it red (plan §9, G1–G4).
///
/// Why the obvious guard isn't enough: `CloudKitSchemaTests` would stay
/// green if a plain local model were added to the synced list, because every
/// local field is defaulted and CloudKit would accept it. Only the
/// disjointness check objects. (A unique-keyed local model would turn both
/// red — which is a different thing being proven.)
@Suite("Market local schema")
struct MarketLocalSchemaTests {
    private static let syncedNames = Set(TroveSchema.schema.entities.map(\.name))
    private static let localNames = Set(TroveSchema.localSchema.entities.map(\.name))

    // G1
    @Test func theLocalModelsAreNotInTheSyncedSchema() {
        let synced = Set(TroveSchema.models.map { ObjectIdentifier($0) })
        let local = Set(TroveSchema.localModels.map { ObjectIdentifier($0) })

        #expect(!local.isEmpty, "Nothing is local — the two-store split guards nothing")
        #expect(synced.isDisjoint(with: local), "A local model is registered in the synced list — it would sync")
    }

    // G2
    @Test(arguments: [StorageMode.cloudKit, .localOnly])
    func theDiskModesBuildTheSyncedConfigurationThenTheLocalOne(mode: StorageMode) throws {
        let configurations = TroveStore.configurations(for: mode)
        try #require(configurations.count == 2)

        #expect(Set(try #require(configurations[0].schema).entities.map(\.name)) == Self.syncedNames)
        #expect(Set(try #require(configurations[1].schema).entities.map(\.name)) == Self.localNames)
        #expect(configurations[1].cloudKitContainerIdentifier == nil)
        #expect(!configurations[1].isStoredInMemoryOnly)
        if mode == .cloudKit {
            #expect(configurations[0].cloudKitContainerIdentifier == TroveStore.cloudKitContainerIdentifier)
        }
    }

    // G2b — `cloudKitContainerIdentifier` is nil for `.automatic` and `.none`
    // alike (checked 2026-09-03), so a dropped `.none` is invisible to every
    // `== nil` assertion. The label in the source is the only thing that can
    // be seen.
    @Test func everyConfigurationSpellsOutItsCloudKitDatabase() throws {
        let code = try SourceScan.production("Trove/App/TroveStore.swift")
        let calls = SourceScan.argumentLists(of: "ModelConfiguration", in: code)

        try #require(calls.count >= 5, "found only \(calls.count) ModelConfiguration( calls — wrong file or a refactor moved them")
        for call in calls {
            #expect(call.contains("cloudKitDatabase:"), "A configuration inherits .automatic and would sync: ModelConfiguration(\(call))")
        }
    }

    // G3
    @Test func theStoresAreTwoFilesAndTheCollectionKeepsItsName() {
        let pair = TroveStore.configurations(for: .cloudKit)

        #expect(pair[0].url != pair[1].url)
        #expect(pair[0].url.lastPathComponent == "default.store", "The collection moved — the app would open empty")
        #expect(pair[1].url.lastPathComponent == "MarketLocal.store")
        #expect(TroveStore.localConfiguration().url == pair[1].url)
    }

    // G4 — criterion 18's structural half: each local model's stored fields
    // are exactly these, so nothing from a listing can be added quietly. The
    // snapshot's `slug` and `title` are the product's catalog data (Decision
    // 20), not a listing's.
    @Test func theLocalModelsStoreOnlyAllowedFields() throws {
        let allowed: [String: Set<String>] = [
            "MarketFigureRecord": [
                "subjectID", "subjectKindRawValue", "productID", "fetchedAt", "count",
                "medianCents", "lowCents", "highCents", "usedLowCents", "isTruncated", "trendRawValue",
                "yearFilter", "isAllYearsFallback",
            ],
            "MarketHistoryPoint": ["subjectID", "fetchedAt", "medianCents", "lowCents", "highCents", "count"],
            "MarketMatchSnapshot": ["subjectID", "productID", "slug", "title", "usedLowCents", "takenAt"],
            "MarketDeviceState": ["key", "noticeAcknowledgedAt"],
        ]

        let entities = TroveSchema.localSchema.entities
        #expect(Set(entities.map(\.name)) == Set(allowed.keys), "A local model appeared or vanished without its allowlist")
        for entity in entities {
            let fields = Set(entity.attributes.map(\.name)).union(entity.relationships.map(\.name))
            #expect(fields == allowed[entity.name], "\(entity.name) stores \(fields.sorted()) — expected \(allowed[entity.name]?.sorted() ?? [])")
            #expect(entity.relationships.isEmpty, "\(entity.name) declares a relationship — local rows are keyed by UUID, never related")
        }
    }

    // G6 — `-uiTesting`: the pair, in memory, no CloudKit, and between them
    // every model, local ones included — a UI-test launch that
    // fetched a market row from a store without the entity would crash
    // there and nowhere else.
    @Test func uiTestsKeepEveryModelInMemory() throws {
        let configurations = TroveStore.configurations(for: .ephemeral)
        try #require(!configurations.isEmpty)

        var covered = Set<String>()
        for configuration in configurations {
            #expect(configuration.isStoredInMemoryOnly)
            #expect(configuration.cloudKitContainerIdentifier == nil)
            covered.formUnion(try #require(configuration.schema).entities.map(\.name))
        }
        #expect(covered == Self.syncedNames.union(Self.localNames), "The ephemeral store is missing \(Self.syncedNames.union(Self.localNames).subtracting(covered).sorted())")
    }

    // G8 — the container's schema is exactly the two lists together; a
    // model in `localModels` but not here fails at the first fetch.
    @Test func theCombinedSchemaIsTheUnion() {
        let combined = Set(TroveSchema.combinedSchema.entities.map(\.name))
        #expect(combined == Self.syncedNames.union(Self.localNames))
        #expect(Set(TroveSchema.allModels.map { ObjectIdentifier($0) })
            == Set((TroveSchema.models + TroveSchema.localModels).map { ObjectIdentifier($0) }))
    }

    // G9 — every container built outside `TroveSchema`/`TroveStore`/tests
    // (the previews, `ContentView`'s) is over the union. Read raw, not
    // through `SourceScan.production`, because the construction sites are
    // *inside* `#Preview` blocks — exactly what `production` strips.
    @Test func previewsAndContentViewUseTheCombinedSchema() throws {
        let root = URL(filePath: "\(#filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        var files = try FileManager.default.subpathsOfDirectory(atPath: root.appending(path: "Trove/Views").path)
            .filter { $0.hasSuffix(".swift") }
            .map { "Trove/Views/\($0)" }
        files.append("Trove/App/ContentView.swift")
        try #require(files.count > 10, "scanned only \(files.count) files — wrong root?")

        var offenders: [String] = []
        var builders = 0
        for file in files {
            let source = try String(contentsOf: root.appending(path: file), encoding: .utf8)
            if source.contains("TroveSchema.schema") || source.contains("TroveSchema.models") {
                offenders.append(file)
            }
            if source.contains("TroveSchema.combinedSchema") || source.contains("TroveSchema.allModels") {
                builders += 1
            }
        }
        #expect(offenders.isEmpty, "containers over the synced schema alone — a fetch of a market row would crash: \(offenders)")
        #expect(builders >= 8, "only \(builders) files build a container — the previews moved somewhere this scan can't see")
    }
}

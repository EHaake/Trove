import Foundation
import Synchronization
import Testing
@testable import Trove

/// T005's instrumented off-main claim (criterion 11). The probe lives inside
/// the generation bodies and records the thread the work actually ran on —
/// the T056 lesson: instrument the mechanism, never a visual or timing proxy
/// for it. Mutation-verified by forcing the bodies onto the main actor.
struct ExportConcurrencyTests {
    /// Thread-safe capture the nonisolated generation body can write into.
    /// `nonisolated` explicitly — the suite keeps the test target's MainActor
    /// default, and a MainActor-isolated box couldn't be written off-main.
    private nonisolated final class Probe: Sendable {
        private let state = Mutex<[Bool]>([])
        func record(_ isMainThread: Bool) { state.withLock { $0.append(isMainThread) } }
        var sawMainThread: [Bool] { state.withLock { $0 } }
    }

    @Test func generationRunsOffTheMainThreadForBothFormats() async throws {
        let probe = Probe()
        let scratch = FileManager.default.temporaryDirectory
            .appending(path: "ExportConcurrencyTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        // Typed through the existential deliberately: the view models call
        // through `any ExportService`, where the *protocol requirement's*
        // `@concurrent` governs — a probe on the concrete class would pass
        // even if the protocol annotation were dropped, and the app's real
        // call path silently moved back onto the main actor.
        let service: any ExportService = FileExportService(
            container: try makeInMemoryContainer(),
            directory: scratch,
            generationProbe: { probe.record($0) }
        )

        // Called from the main actor — exactly how the view models will call
        // it — so a pass means the nonisolated-async hop genuinely happened,
        // not that the test started somewhere convenient. (Sampled through a
        // sync helper; `Thread.isMainThread` is `noasync`.)
        #expect(sampledOnMainThread())
        _ = try await service.exportCSV(CSVTable(headers: ["A"], rows: [["1"]]), filename: "probe.csv")
        _ = try await service.exportPDF(minimalDocument, filename: "probe.pdf")

        #expect(probe.sawMainThread == [false, false])
    }

    private nonisolated func sampledOnMainThread() -> Bool { Thread.isMainThread }

    private var minimalDocument: PDFDocumentModel {
        PDFDocumentModel(
            cover: CoverSummary(
                title: "Owned Items",
                coverageLabel: "All items",
                generatedAt: .now,
                itemCount: 0,
                totals: .items(currentValueCents: 0, paidCents: 0, unvaluedCount: 0)
            ),
            entries: []
        )
    }
}

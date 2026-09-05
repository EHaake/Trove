import Foundation
import SwiftData

/// Which item a local row belongs to.
struct MarketSubjectKey: Equatable, Sendable {
    let subjectID: UUID
    let kind: MarketSubjectKind
}

/// Reads and writes the device-local market rows through the caller's own
/// `ModelContext` — the local models live in the same container as the
/// collection (plan §1), so nothing new is injected. **Callers save**: every
/// writer here leaves its changes in the context so an intent can commit
/// the item's write and the local rows in one `save()`, and a failed save
/// leaves neither half behind.
///
/// `record` is the single writer of the cached trend, and history is
/// append-only, so the row's `trendRawValue` and `MarketTrend.compute` over
/// the points can never disagree (plan §5, N3).
enum MarketLocalStore {
    // MARK: - Reads

    static func figure(for subjectID: UUID, in context: ModelContext) throws -> MarketFigureRecord? {
        var descriptor = FetchDescriptor<MarketFigureRecord>(predicate: #Predicate { $0.subjectID == subjectID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    static func snapshot(for subjectID: UUID, in context: ModelContext) throws -> MarketMatchSnapshot? {
        var descriptor = FetchDescriptor<MarketMatchSnapshot>(predicate: #Predicate { $0.subjectID == subjectID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Oldest first.
    static func history(for subjectID: UUID, in context: ModelContext) throws -> [MarketHistoryPoint] {
        try context.fetch(FetchDescriptor<MarketHistoryPoint>(
            predicate: #Predicate { $0.subjectID == subjectID },
            sortBy: [SortDescriptor(\.fetchedAt)]
        ))
    }

    static func historyEntries(for subjectID: UUID, in context: ModelContext) throws -> [MarketHistoryEntry] {
        try history(for: subjectID, in: context).map {
            MarketHistoryEntry(fetchedAt: $0.fetchedAt, medianCents: $0.medianCents, lowCents: $0.lowCents, highCents: $0.highCents, count: $0.count)
        }
    }

    /// Whether the one-time notice has been continued past on this device
    /// (spec Decision 14). A fetch that fails reads as *not* acknowledged —
    /// the notice showing once more is the safe direction.
    static func hasAcknowledgedNotice(in context: ModelContext) -> Bool {
        (try? deviceState(in: context))?.noticeAcknowledgedAt != nil
    }

    // MARK: - Writes (no save)

    /// The pick (spec Decision 3): the product's catalog snapshot for the
    /// link-back and the title, before any refresh (Decision 20).
    static func recordMatch(_ candidate: MarketCandidate, for subjectID: UUID, at now: Date, in context: ModelContext) throws {
        let snapshot = try snapshot(for: subjectID, in: context)
            ?? insert(MarketMatchSnapshot(subjectID: subjectID, productID: candidate.id, slug: candidate.slug, title: candidate.title, usedLowCents: candidate.usedLowCents, takenAt: now), into: context)
        snapshot.productID = candidate.id
        snapshot.slug = candidate.slug
        snapshot.title = candidate.title
        snapshot.usedLowCents = candidate.usedLowCents
        snapshot.takenAt = now
    }

    /// One refresh's outcome: the figure row upserted, a history point
    /// appended when the reading has a median (Decision 23), the trend
    /// recomputed from the whole history, and the snapshot refreshed.
    static func record(_ reading: MarketReading, product: MarketProduct, for key: MarketSubjectKey, in context: ModelContext) throws {
        let fetchedAt: Date
        switch reading {
        case .figure(let figure): fetchedAt = figure.fetchedAt
        case .withheld(_, _, let at, _): fetchedAt = at
        }

        let row = try figure(for: key.subjectID, in: context)
            ?? insert(MarketFigureRecord(subjectID: key.subjectID, subjectKind: key.kind, productID: product.id, fetchedAt: fetchedAt), into: context)
        row.subjectKindRawValue = key.kind.rawValue
        row.productID = product.id
        row.fetchedAt = fetchedAt
        row.usedLowCents = product.usedLowCents

        switch reading {
        case .figure(let figure):
            row.count = figure.count
            row.medianCents = figure.medianCents
            row.lowCents = figure.lowCents
            row.highCents = figure.highCents
            row.isTruncated = figure.isTruncated
            apply(figure.yearScope, to: row)
            context.insert(MarketHistoryPoint(
                subjectID: key.subjectID, fetchedAt: figure.fetchedAt,
                medianCents: figure.medianCents, lowCents: figure.lowCents, highCents: figure.highCents, count: figure.count
            ))
        case .withheld(let count, _, _, let scope):
            row.count = count
            row.medianCents = nil
            row.lowCents = nil
            row.highCents = nil
            row.isTruncated = false
            apply(scope, to: row)
        }

        // The whole history, the just-inserted point included: a same-context
        // fetch sees pending inserts, which here is exactly what we want.
        row.trendRawValue = MarketTrend.compute(history: try historyEntries(for: key.subjectID, in: context))?.rawValue

        let snapshot = try snapshot(for: key.subjectID, in: context)
            ?? insert(MarketMatchSnapshot(subjectID: key.subjectID, productID: product.id, slug: product.slug, title: product.title, usedLowCents: product.usedLowCents, takenAt: fetchedAt), into: context)
        snapshot.productID = product.id
        snapshot.slug = product.slug
        snapshot.title = product.title
        snapshot.usedLowCents = product.usedLowCents
        snapshot.takenAt = fetchedAt
    }

    /// Everything the device knows about one item's market: the figure, its
    /// history and the snapshot. Unmatch, a change of match, and every
    /// deletion path call this before their own save (spec P11, Decision 26).
    static func clear(subjectID: UUID, in context: ModelContext) throws {
        if let row = try figure(for: subjectID, in: context) { context.delete(row) }
        if let snapshot = try snapshot(for: subjectID, in: context) { context.delete(snapshot) }
        for point in try history(for: subjectID, in: context) { context.delete(point) }
    }

    static func acknowledgeNotice(at now: Date, in context: ModelContext) throws {
        let state = try deviceState(in: context) ?? insert(MarketDeviceState(), into: context)
        if state.noticeAcknowledgedAt == nil {
            state.noticeAcknowledgedAt = now
        }
    }

    // MARK: - Private

    private static func deviceState(in context: ModelContext) throws -> MarketDeviceState? {
        var descriptor = FetchDescriptor<MarketDeviceState>()
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func insert<Model: PersistentModel>(_ model: Model, into context: ModelContext) -> Model {
        context.insert(model)
        return model
    }

    private static func apply(_ scope: YearScope, to row: MarketFigureRecord) {
        switch scope {
        case .any:
            row.yearFilter = nil
            row.isAllYearsFallback = false
        case .year(let year):
            row.yearFilter = year
            row.isAllYearsFallback = false
        case .allYears(let year):
            row.yearFilter = year
            row.isAllYearsFallback = true
        }
    }
}

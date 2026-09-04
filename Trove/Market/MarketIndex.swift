import Foundation
import SwiftData

/// A figure row as a value the lists, the sort and the dashboard read.
struct MarketSnapshotValue: Equatable, Sendable {
    let productID: Int
    let fetchedAt: Date
    let count: Int
    let medianCents: Int?
    let lowCents: Int?
    let highCents: Int?
    let usedLowCents: Int?
    let isTruncated: Bool
    let trend: MarketTrend?
    let yearFilter: Int?
    let isAllYearsFallback: Bool

    init(record: MarketFigureRecord) {
        productID = record.productID
        fetchedAt = record.fetchedAt
        count = record.count
        medianCents = record.medianCents
        lowCents = record.lowCents
        highCents = record.highCents
        usedLowCents = record.usedLowCents
        isTruncated = record.isTruncated
        trend = record.trendRawValue.flatMap(MarketTrend.init(rawValue:))
        yearFilter = record.yearFilter
        isAllYearsFallback = record.isAllYearsFallback
    }

    /// The median a surface may use — nil when withheld or no longer
    /// current (spec Decision 21), through the one predicate.
    func currentMedianCents(now: Date) -> Int? {
        MarketFreshness.currentMedianCents(medianCents: medianCents, fetchedAt: fetchedAt, now: now)
    }
}

/// Every figure row, keyed by the item it belongs to — one fetch per
/// `load()`, never the history (plan §5). A row whose item was deleted on
/// another device is simply never looked up (Q18).
struct MarketIndex: Equatable {
    let figures: [UUID: MarketSnapshotValue]

    static let empty = MarketIndex(figures: [:])

    static func load(from context: ModelContext) throws -> MarketIndex {
        let rows = try context.fetch(FetchDescriptor<MarketFigureRecord>())
        return MarketIndex(figures: Dictionary(rows.map { ($0.subjectID, MarketSnapshotValue(record: $0)) }, uniquingKeysWith: { _, last in last }))
    }
}

/// What the Market section shows for one item (plan §6): unmatched, or
/// matched with one of four readings. Pure, so the table is testable
/// without a view model.
enum MarketSectionState: Equatable {
    case unmatched
    case matched(MarketMatchDisplay)

    static func resolve(productID: Int?, figure: MarketSnapshotValue?, snapshot: MarketMatchSnapshotValue?, now: Date) -> MarketSectionState {
        guard let productID else { return .unmatched }
        let reading: MarketMatchDisplay.Reading
        if let figure {
            if !MarketFreshness.isCurrent(fetchedAt: figure.fetchedAt, now: now) {
                reading = .stale(fetchedAt: figure.fetchedAt)
            } else if figure.medianCents == nil {
                reading = .withheld(figure)
            } else {
                reading = .current(figure)
            }
        } else {
            reading = .none
        }
        return .matched(MarketMatchDisplay(
            productID: productID,
            title: snapshot?.title,
            webURL: snapshot.map { ReverbAPI.productURL(slug: $0.slug) },
            reading: reading
        ))
    }
}

struct MarketMatchDisplay: Equatable {
    enum Reading: Equatable {
        /// Matched, nothing fetched on this device yet.
        case none
        case current(MarketSnapshotValue)
        case withheld(MarketSnapshotValue)
        /// Over thirty days old: the figure is not carried (spec P13).
        case stale(fetchedAt: Date)
    }

    let productID: Int
    let title: String?
    let webURL: URL?
    let reading: Reading
}

/// The catalog snapshot as a value.
struct MarketMatchSnapshotValue: Equatable, Sendable {
    let productID: Int
    let slug: String
    let title: String
    let usedLowCents: Int?
    let takenAt: Date

    init(record: MarketMatchSnapshot) {
        productID = record.productID
        slug = record.slug
        title = record.title
        usedLowCents = record.usedLowCents
        takenAt = record.takenAt
    }

    init(productID: Int, slug: String, title: String, usedLowCents: Int?, takenAt: Date) {
        self.productID = productID
        self.slug = slug
        self.title = title
        self.usedLowCents = usedLowCents
        self.takenAt = takenAt
    }
}

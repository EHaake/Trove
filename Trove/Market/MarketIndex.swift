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

/// What a list row and the Market sort read for one item (plan §6): the
/// median they may show — nil when the figure is withheld or no longer
/// current, through the one freshness predicate, so stale and withheld
/// items fall into the sort's nil-last block (spec Decision 21) — and the
/// trend the row's arrow draws, which is the figure row's stored trend
/// (`MarketLocalStore.record` is its single writer, so it can never
/// disagree with the history it was computed over).
struct MarketSummary: Equatable, Sendable {
    let medianCents: Int?
    let trend: MarketTrend?

    init(snapshot: MarketSnapshotValue, now: Date) {
        medianCents = snapshot.currentMedianCents(now: now)
        trend = snapshot.trend
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

extension MarketSectionState {
    /// The same derivation, read from the device's own rows — the step both
    /// detail view models share (plan §6, "the derivation written once"), so
    /// the two screens can never map the store to a reading differently.
    /// A read that throws reads as "nothing stored", which resolves to
    /// `.none` under a match: the safe direction, and never a wrong figure.
    static func resolve(subjectID: UUID, productID: Int?, in context: ModelContext, now: Date) -> MarketSectionState {
        resolve(
            productID: productID,
            figure: (try? MarketLocalStore.figure(for: subjectID, in: context)).map(MarketSnapshotValue.init(record:)),
            snapshot: (try? MarketLocalStore.snapshot(for: subjectID, in: context)).map(MarketMatchSnapshotValue.init(record:)),
            now: now
        )
    }

    /// The fetch time behind the reading, whatever kind it is — what
    /// `canRefresh` measures the hour against, so a withheld or stale
    /// reading counts as a fetch and doesn't re-offer the button. Nil when
    /// nothing has been fetched here. Not what the unreachable line dates
    /// itself by: see `currentFigureFetchedAt`.
    /// Nil when nothing has been fetched here — or when nothing readable is
    /// stored: a throwing store read degrades to `.none`, and the button is
    /// re-offered; the refresher answers `.stillFresh` if it was a fetch.
    var lastFetchedAt: Date? {
        guard case .matched(let display) = self else { return nil }
        switch display.reading {
        case .none: return nil
        case .current(let figure), .withheld(let figure): return figure.fetchedAt
        case .stale(let fetchedAt): return fetchedAt
        }
    }

    /// The fetch time behind the figure the section is actually *showing* —
    /// the date the unreachable line dates itself by, since its copy reads
    /// "the figure below is from {age}" and only a `.current` reading puts a
    /// figure below it (plan §6). `.withheld`, `.stale` and `.none` carry no
    /// date, so that line falls back to "Couldn't reach Reverb." on its own.
    var currentFigureFetchedAt: Date? {
        guard case .matched(let display) = self, case .current(let figure) = display.reading else { return nil }
        return figure.fetchedAt
    }
}

/// What the Market section is doing right now (plan §6). One case today;
/// an enum rather than a `Bool` so a second activity doesn't reshape the
/// state — the shape `SettingsViewModel.Activity` already uses.
enum MarketActivity: Equatable, Sendable {
    case refreshing
}

/// The one rust line above the actions when a refresh didn't land (spec
/// criterion 11, Q3): the reading beneath it is left exactly as it was.
enum MarketNotice: Equatable, Sendable {
    /// Offline, a server error, or a body we couldn't read — dated by the
    /// figure that is still showing, when there is one.
    case unreachable(lastFetchedAt: Date?)
    case rateLimited
    /// Reverb no longer has the matched product; the match stays (Q3).
    case productGone

    /// One refresh's outcome as the section's notice — written once so both
    /// detail view models map it identically. A `saveFailed` reads as
    /// unreachable: nothing new is showing either way, and the person's next
    /// move is the same.
    static func notice(for outcome: MarketRefresher.Outcome, lastFetchedAt: Date?) -> MarketNotice? {
        switch outcome {
        case .refreshed, .stillFresh, .superseded:
            return nil
        case .failed(.rateLimited):
            return .rateLimited
        case .failed(.productNotFound):
            return .productGone
        case .failed(.unreachable), .failed(.serverError), .failed(.malformedResponse), .saveFailed:
            return .unreachable(lastFetchedAt: lastFetchedAt)
        }
    }
}

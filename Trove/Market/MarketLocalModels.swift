import Foundation
import SwiftData

/// Whether a market row belongs to an owned `Item` or a wanted `WishlistItem`.
enum MarketSubjectKind: String, Codable, CaseIterable {
    case owned
    case wanted
}

// The four device-local models of spec 002. They live in the `MarketLocal`
// configuration (`TroveStore.localConfiguration`), which carries
// `cloudKitDatabase: .none`, so none of this ever syncs — a second device
// builds its own (spec Decision 7). Two consequences shape every declaration:
//
// - **Keyed by the item's UUID, never a `@Relationship`.** SwiftData can't
//   relate across configurations, and that impossibility is the isolation
//   the spec wants: nothing here can drag a synced object into the local
//   store or the other way round. Readers join from the item's side.
// - **`@Attribute(.unique)` is legal here** — no CloudKit — and makes
//   "one figure per item, one row per device" structural rather than
//   something upsert code has to get right.
//
// Defaults everywhere are for lightweight migration when a field is added,
// not for CloudKit. `MarketLocalSchemaTests` pins each model's field set to
// an allowlist so a listing's title, seller or image can never be added
// quietly (spec P14, criterion 18).

/// The last figure computed for one matched item on this device.
@Model
final class MarketFigureRecord {
    @Attribute(.unique) var subjectID: UUID = UUID()
    var subjectKindRawValue: String = MarketSubjectKind.owned.rawValue
    /// The product the figure was computed for; a refresh under a different
    /// match replaces the row.
    var productID: Int = 0
    var fetchedAt: Date = Date.now
    /// Listings that counted — in the app's currency and the item's condition.
    var count: Int = 0
    /// `nil` means withheld: fewer than three listings counted (Decision 6).
    var medianCents: Int?
    var lowCents: Int?
    var highCents: Int?
    /// The trimmed range the value slider runs between (Decision 36,
    /// Amendment B): the 10th and 90th percentiles of the counted asking
    /// prices. Nil on a row written before that amendment — the bounds then
    /// fall back to low and high, in `MarketValueBounds`.
    var p10Cents: Int?
    var p90Cents: Int?
    /// The catalog's lowest used asking price — what a withheld figure offers.
    var usedLowCents: Int?
    /// The page cap was hit; the figure covers what was fetched (plan Q2).
    var isTruncated: Bool = false
    /// The trend, recomputed from history on every refresh by
    /// `MarketLocalStore.record` — its single writer — so lists read one row.
    var trendRawValue: String?
    /// The year the figure narrowed to, if the item had one (Decision 29,
    /// P21) — so the section can still say so after the item's year changes.
    var yearFilter: Int?
    /// Narrowing left fewer than three, so every year counted (P20).
    var isAllYearsFallback: Bool = false

    init(subjectID: UUID, subjectKind: MarketSubjectKind, productID: Int, fetchedAt: Date) {
        self.subjectID = subjectID
        self.subjectKindRawValue = subjectKind.rawValue
        self.productID = productID
        self.fetchedAt = fetchedAt
    }
}

/// One refresh that yielded a median. Append-only; never trimmed by age
/// (Decision 16); cleared only with the match (Decisions 26, P11).
@Model
final class MarketHistoryPoint {
    var subjectID: UUID = UUID()
    var fetchedAt: Date = Date.now
    var medianCents: Int = 0
    var lowCents: Int = 0
    var highCents: Int = 0
    var count: Int = 0

    init(subjectID: UUID, fetchedAt: Date, medianCents: Int, lowCents: Int, highCents: Int, count: Int) {
        self.subjectID = subjectID
        self.fetchedAt = fetchedAt
        self.medianCents = medianCents
        self.lowCents = lowCents
        self.highCents = highCents
        self.count = count
    }
}

/// What the device remembers about the matched product itself — catalog
/// data, never listing content (Decision 20): the slug the link-back is
/// built from, the title the section names, the lowest used asking price a
/// withheld figure falls back to.
@Model
final class MarketMatchSnapshot {
    @Attribute(.unique) var subjectID: UUID = UUID()
    var productID: Int = 0
    var slug: String = ""
    var title: String = ""
    var usedLowCents: Int?
    var takenAt: Date = Date.now

    init(subjectID: UUID, productID: Int, slug: String, title: String, usedLowCents: Int?, takenAt: Date) {
        self.subjectID = subjectID
        self.productID = productID
        self.slug = slug
        self.title = title
        self.usedLowCents = usedLowCents
        self.takenAt = takenAt
    }
}

/// The per-device facts, one row. The one-time notice (Decision 14) is the
/// only one so far: it gates whether a sheet is shown before a search, and
/// writes nothing synced — the right side of the line 010's removed backfill
/// flag was on the wrong side of.
@Model
final class MarketDeviceState {
    @Attribute(.unique) var key: String = "device"
    var noticeAcknowledgedAt: Date?

    init() {}
}

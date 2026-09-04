import Foundation

/// Every user-facing string of spec 002 lives here (T007), the way
/// `DeleteAllCopy` holds Settings' — pinned whole by `MarketCopyTests`, read
/// by the views and view models, never typed inline. T004 lands only the
/// contact address, because the API client's user agent carries it.
nonisolated enum MarketCopy {
    /// The dedicated contact address for the app (spec Decisions 12 and 25):
    /// shown in Settings › About, named in `PRIVACY.md`, and sent in the
    /// Reverb client's `User-Agent` — one constant, so the placeholder guard
    /// in `MarketCopyTests` covers every copy. Supplied by the person; until
    /// then this value fails that guard on purpose.
    static let contactAddress = "TODO@example.com"
}

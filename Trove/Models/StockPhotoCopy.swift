import Foundation

/// Spec 005's copy — the stock-photo picker's strings. This task lands only
/// the one guard that can block work: the contact address the Wikimedia
/// User-Agent carries (plan Q6). The rest of the section arrives in T004.
///
/// 005 is self-contained from 002, so the one real address is duplicated here
/// deliberately rather than shared with `MarketCopy` — a later `AppContact`
/// unification is a close-out note (plan Q6).
nonisolated enum StockPhotoCopy {
    /// The contact address Wikimedia's User-Agent policy asks a client to
    /// carry, so a maintainer is reachable. Read from here, its one home.
    static let contactAddress = "canadianfishturkey@gmail.com"
}

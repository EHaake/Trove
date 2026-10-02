import Foundation

/// How an owned item is holding up.
///
/// `Item` stores this as a raw `String` rather than as a native SwiftData enum
/// attribute, and exposes it through a computed `condition` property. Per
/// plan.md that's the conservative choice for CloudKit schema stability if a
/// case is ever added.
///
/// `020` added one — `veryGood` — and raw storage alone was not enough: an app
/// older than `020` reads a raw value it doesn't know as Excellent and writes
/// that back on its next save, which would reset the grade. So Very Good is
/// **not** stored under its own raw value: `Item` keeps `"good"` in
/// `conditionRawValue` and `"very good"` beside it in `conditionRefinement`
/// (`Item.storage(for:)`, 020 plan Q2). The raw value here is what the CSV
/// writes and what `rawValue.capitalized` displays; declaration order is the
/// order the chip rows draw.
enum Condition: String, Codable, CaseIterable {
    case new
    case excellent
    case veryGood = "very good"
    case good
    case fair
    case broken
}

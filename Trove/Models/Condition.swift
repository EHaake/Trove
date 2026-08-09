import Foundation

/// How an owned item is holding up.
///
/// `Item` stores this as a raw `String` rather than as a native SwiftData enum
/// attribute, and exposes it through a computed `condition` property. Per
/// plan.md that's the conservative choice for CloudKit schema stability if a
/// case is ever added.
enum Condition: String, Codable, CaseIterable {
    case new
    case excellent
    case good
    case fair
    case broken
}

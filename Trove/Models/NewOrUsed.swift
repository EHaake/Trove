import Foundation

/// 020: bought new or used — and, on a wanted entry, which the person is
/// looking for. Stored optional everywhere: nil is "not recorded", never a
/// third value (spec Decisions 2, 3). Never inferred (Decision 4).
nonisolated enum NewOrUsed: String, CaseIterable, Sendable {
    case new
    case used
}

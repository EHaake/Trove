import Foundation

/// The 1–5 desire-to-keep scale, and what each point on it means in words.
///
/// The dial shows a numeral; the summary next to it is what actually tells the
/// user what they picked. Kept here rather than in the dial so the form, the
/// detail screen and any future list row all say the same thing.
enum DesireLevel: Int, CaseIterable, Sendable {
    case readyToSell = 1
    case wouldLetItGo
    case undecided
    case keepingForNow
    case absolutelyKeeping

    /// Clamps rather than failing: `Item.desireToKeep` is a plain `Int` whose
    /// range is enforced in the view model, so anything reading a stored value
    /// has to cope with one that predates that rule.
    init(clamping value: Int) {
        self = DesireLevel(rawValue: min(max(value, 1), 5)) ?? .undecided
    }

    /// "Keeping for now" and "Absolutely keeping it" are Design's own words,
    /// from the item form and item detail mocks. The other three follow their
    /// voice — plain, first-person about the gear, no filler.
    var summary: String {
        switch self {
        case .readyToSell: "Ready to sell"
        case .wouldLetItGo: "Would let it go"
        case .undecided: "Undecided"
        case .keepingForNow: "Keeping for now"
        case .absolutelyKeeping: "Absolutely keeping it"
        }
    }

    /// Whether an item at this level turns up in a Sell Plan's candidate pool.
    /// Mirrors the spec's rule so the form can tell the user what their rating
    /// actually does, rather than leaving the threshold a hidden mechanic.
    var isSellCandidate: Bool { rawValue <= 3 }
}

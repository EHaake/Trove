import Foundation

/// The 1–3 desire-to-own scale for wishlist items, and what each point on it
/// means in words.
///
/// Deliberately coarser than `DesireLevel`'s 1–5, per spec.md: three levels is
/// about the resolution people actually have about their own wants, and it
/// keeps the two ratings from reading as one measurement pointed in opposite
/// directions.
///
/// The words live here rather than in `DesireGauge` so the form, the detail
/// screen and VoiceOver all say the same thing — the gauge itself is unlabeled
/// in list rows.
enum DesireToOwnLevel: Int, CaseIterable, Sendable {
    case someday = 1
    case soon
    case next

    /// Clamps rather than failing, same as `DesireLevel`: `desireToOwn` is a
    /// plain `Int` whose range is enforced in the view model, so anything
    /// reading a stored value has to cope with one that predates that rule.
    init(clamping value: Int) {
        self = DesireToOwnLevel(rawValue: min(max(value, 1), 3)) ?? .soon
    }

    /// Design's own words, from the brief's desire-gauge section.
    var summary: String {
        switch self {
        case .someday: "Someday"
        case .soon: "Soon"
        case .next: "Next"
        }
    }
}

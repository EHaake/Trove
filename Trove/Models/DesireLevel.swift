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

    /// "Keeping for now", "Absolutely keeping it" and — since `010`'s design
    /// refresh — "On the fence" are Design's own words, from the item form and
    /// detail mocks. The other two follow their voice: plain, first-person
    /// about the gear, no filler. (Level 3 read "Undecided" until `010`; the
    /// case keeps its old name, which nothing user-facing depends on.)
    var summary: String {
        switch self {
        case .readyToSell: "Ready to sell"
        case .wouldLetItGo: "Would let it go"
        case .undecided: "On the fence"
        case .keepingForNow: "Keeping for now"
        case .absolutelyKeeping: "Absolutely keeping it"
        }
    }

    /// The line under the summary: what this rating actually *does*, in terms
    /// of behaviour that exists today.
    ///
    /// Design's mock wrote these against a richer sell plan than `010` ships —
    /// target-shortfall escalation ("only offered up if you're far short of a
    /// target") and per-level exclusion overrides. Reworded at the `010`
    /// design review to describe only what's real: `isSellCandidate` decides
    /// who joins the pool, and `SellPlanViewModel.rank` orders it
    /// least-wanted-first. **Revisit when that richer logic lands** — levels 4
    /// and 5 differ in the mock's copy and are deliberately near-synonyms here,
    /// because today they behave identically. `tasks.md`'s Phase 7 header and
    /// `tokens.md`'s dial-copy table carry the same note.
    ///
    /// - Parameter isValued: whether the item has a current value. An unvalued
    ///   item can't join a plan whatever its rating (`SellPlanViewModel
    ///   .qualifies`), so saying otherwise would be the same kind of untrue
    ///   promise the rewording exists to remove.
    func detail(isValued: Bool) -> String {
        guard isSellCandidate else {
            switch self {
            case .keepingForNow: return "Left out of the sell-candidate pool."
            default: return "Never offered up. This one stays."
            }
        }
        guard isValued else {
            return "Won't appear in a sell plan until it has a value."
        }
        switch self {
        case .readyToSell: return "First in line when a sell plan needs candidates."
        case .wouldLetItGo: return "Offered early among sell candidates."
        default: return "Still a sell candidate — the last in line."
        }
    }

    /// Whether an item at this level turns up in a Sell Plan's candidate pool.
    /// Mirrors the spec's rule so the form can tell the user what their rating
    /// actually does, rather than leaving the threshold a hidden mechanic.
    var isSellCandidate: Bool { rawValue <= 3 }
}

import Foundation

/// What "matches" means when the user types into a list screen's search box.
///
/// A plain type rather than something a view model owns, for the same reason
/// `CategoryPathHelper` is one: the item list and the wishlist list search
/// different fields — an item has a serial number, a wishlist item doesn't —
/// but they have to agree on the rule itself. Two screens that look identical
/// answering the same query differently is the bug this exists to prevent.
enum SearchMatching {
    /// Whitespace-only input is no query at all. Without this a stray space
    /// left behind by autocorrect empties the list and looks like data loss.
    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the query is empty — searching for nothing shows everything —
    /// or appears anywhere in any of the given fields. `nil` fields simply
    /// don't match, so an optional serial number needs no special casing at
    /// the call site.
    ///
    /// `localizedStandardContains` is case- *and* diacritic-insensitive, which
    /// is what someone typing "leica" into a search box expects, and what lets
    /// "rode" find a Røde microphone.
    static func matches(query: String, in fields: [String?]) -> Bool {
        let query = normalized(query)
        guard !query.isEmpty else { return true }
        return fields.contains { $0?.localizedStandardContains(query) == true }
    }
}

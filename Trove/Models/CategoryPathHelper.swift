import Foundation
import SwiftData

/// Category paths are free-typed strings, not a managed entity — see plan.md's
/// "Categories: no separate entity" section. This fetches the paths currently
/// in use across `Item` and `WishlistItem` and provides matching and
/// case-insensitive canonicalization on top of that flat list.
///
/// A plain type over an injected `ModelContext`, not a view model: it has no
/// screen-owned state, just queries, so it's testable directly against an
/// in-memory container the same way the models themselves are.
struct CategoryPathHelper {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Distinct category paths in use, deduplicated case-insensitively and
    /// sorted alphabetically for display. Where two records use the same path
    /// with different casing, the casing from whichever record was created
    /// first wins — matching the canonicalization rule below, so a path never
    /// appears to change casing depending on who's asking.
    func allCategoryPaths() throws -> [String] {
        try canonicalPaths().sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Known paths whose start matches `prefix`, case-insensitively — for
    /// autocomplete as the user types. An empty prefix returns every path.
    func suggestions(matching prefix: String) throws -> [String] {
        try allCategoryPaths().filter { Self.path($0, matchesPrefix: prefix) }
    }

    /// The one definition of "this category path matches what the user typed":
    /// prefix, case-insensitive, empty matches everything. Filtering by
    /// `"Photography"` therefore also turns up `Photography/Cameras`.
    ///
    /// Shared so autocomplete and the item/wishlist list filters can't drift
    /// into disagreeing about what matches.
    static func path(_ path: String, matchesPrefix prefix: String) -> Bool {
        let prefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return true }
        return path.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil
    }

    /// Given a newly-typed path, returns the existing casing if a
    /// case-insensitive match is already in use, or the input unchanged if
    /// this is a genuinely new path. Call on save, not on every keystroke —
    /// this exists to keep the taxonomy from accumulating near-duplicates like
    /// "Photography/Cameras" and "photography/Cameras" as separate-looking
    /// entries, not to correct the user's typing live.
    func canonicalize(_ typedPath: String) throws -> String {
        let all = try canonicalPaths()
        return all.first { $0.caseInsensitiveCompare(typedPath) == .orderedSame } ?? typedPath
    }

    /// Every distinct path in use, case-insensitively, keeping whichever
    /// casing was attached to the earliest-created record using that path.
    private func canonicalPaths() throws -> [String] {
        let itemRecords = try modelContext.fetch(FetchDescriptor<Item>())
            .map { (path: $0.categoryPath, createdAt: $0.createdAt) }
        let wishlistRecords = try modelContext.fetch(FetchDescriptor<WishlistItem>())
            .map { (path: $0.categoryPath, createdAt: $0.createdAt) }

        return Self.distinctPathsPreferringEarliestCasing(itemRecords + wishlistRecords)
    }

    /// The ordering rule itself, as a pure function over `(path, createdAt)`
    /// pairs: distinct paths, case-insensitively, each keeping the casing of
    /// the earliest-created record that used it.
    ///
    /// Split out from the fetching deliberately. Driving this through the
    /// `ModelContext` can't prove the rule holds, because `FetchDescriptor`
    /// makes no ordering guarantee — a test that inserts records in one order
    /// and expects them back in another passes or fails on whatever SwiftData
    /// happens to do, not on this comparator. Taking the records as an argument
    /// lets a test hand over a deliberately unsorted list and get a
    /// deterministic answer.
    static func distinctPathsPreferringEarliestCasing(
        _ records: [(path: String, createdAt: Date)]
    ) -> [String] {
        let chronological = records
            .filter { !$0.path.isEmpty }
            .sorted { $0.createdAt < $1.createdAt }

        var seenKeys = Set<String>()
        var result: [String] = []
        for record in chronological where seenKeys.insert(record.path.lowercased()).inserted {
            result.append(record.path)
        }
        return result
    }
}

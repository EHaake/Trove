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
        let all = try allCategoryPaths()
        guard !prefix.isEmpty else { return all }
        return all.filter { $0.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil }
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

        let chronological = (itemRecords + wishlistRecords)
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

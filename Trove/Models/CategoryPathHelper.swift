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
        Self.sortedDistinctPaths(try allRecords())
    }

    /// The distinct paths a single screen's own rows use, for its filter chips.
    ///
    /// Deliberately not `allCategoryPaths()`. Autocomplete spans both entities
    /// because a path established anywhere should be offered everywhere — that's
    /// an acceptance criterion. Filter chips are the opposite: a chip on the
    /// wishlist for a category only owned gear sits in leads to an empty list,
    /// and with a short wishlist most of the row ends up doing that.
    ///
    /// Pass the screen's **unfiltered** rows, so choosing one chip never
    /// removes the means of choosing another.
    static func sortedDistinctPaths(_ records: [(path: String, createdAt: Date)]) -> [String] {
        distinctPathsPreferringEarliestCasing(records)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Known paths whose start matches `prefix`, case-insensitively — for
    /// autocomplete as the user types. An empty prefix returns every path.
    func suggestions(matching prefix: String) throws -> [String] {
        try allCategoryPaths().filter { Self.path($0, matchesPrefix: prefix) }
    }

    /// Short labels for a set of category paths, keyed by path.
    ///
    /// A path shows its leaf alone — "Cameras" for `Photography/Cameras` —
    /// which is what the filter chips in `design/screens/` do. Where two paths
    /// share a leaf ("Music/Amps" and "Audio/Amps") both widen to their last
    /// two segments, since a chip reading "Amps" twice tells the user nothing.
    /// Widening is per-path: unaffected paths keep their leaf.
    ///
    /// Display only. Filtering still matches on the full path prefix, so a
    /// chip labelled "Cameras" filters by `Photography/Cameras`.
    static func displayLabels(for paths: [String]) -> [String: String] {
        var labels: [String: String] = [:]

        for path in paths {
            let segments = path.split(separator: "/").map(String.init)
            guard !segments.isEmpty else {
                labels[path] = path
                continue
            }

            // Widen a segment at a time until nothing else would show the same
            // label. Falls through to the full path, which is unique by
            // construction — `paths` holds distinct paths.
            let widest = min(2, segments.count)
            var chosen = path
            for depth in 1...widest {
                let candidate = segments.suffix(depth).joined(separator: "/")
                let clashes = paths.contains { other in
                    other != path && Self.suffix(of: other, segments: depth).caseInsensitiveCompare(candidate) == .orderedSame
                }
                if !clashes {
                    chosen = candidate
                    break
                }
            }
            labels[path] = chosen
        }

        return labels
    }

    /// The trailing segments of a path, for meta lines that show a category
    /// inline beside other content.
    ///
    /// Design's meta lines are always two parts ("LEICA · CAMERAS"), and a
    /// deeper path rendered in full just truncates mid-word in a list row.
    /// The trailing segments are the specific ones anyway — "Guitars ·
    /// Electric" says more in a row than "Music · Guitars · Ele…".
    ///
    /// Unlike `displayLabels(for:)` this needs no collision handling: a row
    /// shows one item's own category, not a set to tell apart.
    static func trailingSegments(of path: String, limit: Int = 2) -> [String] {
        let segments = path.split(separator: "/").map(String.init)
        return Array(segments.suffix(limit))
    }

    private static func suffix(of path: String, segments count: Int) -> String {
        path.split(separator: "/").map(String.init).suffix(count).joined(separator: "/")
    }

    /// "This path starts with what the user has typed so far" — the rule for
    /// **autocomplete**, where the prefix is a fragment mid-word. Typing
    /// `"Photo"` turns up `Photography/Cameras`, which is the whole point.
    ///
    /// Not the rule for filtering: see `path(_:isWithin:)`.
    static func path(_ path: String, matchesPrefix prefix: String) -> Bool {
        let prefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return true }
        return path.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil
    }

    /// "This path sits inside that category" — the rule for **filtering and
    /// scoping**, where the category is one that already exists rather than
    /// something half-typed. Empty scope means everything.
    ///
    /// Deliberately stricter than `path(_:matchesPrefix:)`. A partial-segment
    /// prefix is right for autocomplete and wrong here: selecting `Audio`
    /// would otherwise sweep in `Audiophile`, and a chip for `Music/Amps`
    /// would pull in `Music/Amplifiers` — the filter quietly showing items
    /// from a category the user didn't pick. So the match has to end where a
    /// segment ends.
    ///
    /// The two rules were one rule until the dashboard needed to scope by
    /// category and the difference stopped being academic.
    static func path(_ path: String, isWithin scope: String) -> Bool {
        let scope = scope.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !scope.isEmpty else { return true }
        guard let matched = path.range(of: scope, options: [.caseInsensitive, .anchored]) else {
            return false
        }

        let remainder = path[matched.upperBound...]
        return remainder.isEmpty || remainder.hasPrefix("/")
    }

    /// The child category of `scope` that a path belongs to — the grouping the
    /// dashboard's breakdown rows are built from.
    ///
    /// Under the empty scope that's the path's first segment; under
    /// `Photography` it's `Photography/Cameras`. A path that *is* the scope, or
    /// has nothing below it, groups under itself, so an item filed directly at
    /// `Accessories` still gets a row rather than vanishing.
    static func categoryGroupKey(for path: String, under scope: String) -> String {
        let scope = scope.trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = path.split(separator: "/").map(String.init)
        let depth = scope.isEmpty ? 0 : scope.split(separator: "/").count

        guard segments.count > depth else { return path }
        return segments.prefix(depth + 1).joined(separator: "/")
    }

    /// Given a newly-typed path, returns the existing casing if a
    /// case-insensitive match is already in use, or the input unchanged if
    /// this is a genuinely new path. Call on save, not on every keystroke —
    /// this exists to keep the taxonomy from accumulating near-duplicates like
    /// "Photography/Cameras" and "photography/Cameras" as separate-looking
    /// entries, not to correct the user's typing live.
    func canonicalize(_ typedPath: String) throws -> String {
        Self.canonicalize(typedPath, against: try canonicalPaths())
    }

    /// The matching rule itself, extracted at `012`/T009 so bulk import can
    /// apply it against a path set fetched **once** — the instance method
    /// above does a full two-entity fetch per call, which is fine per form
    /// save and ruinous per imported row (012 plan §The commit path). One
    /// definition, the instance method delegating; `nonisolated` because
    /// it's pure and import's callers shouldn't need this type's isolation.
    nonisolated static func canonicalize(_ typedPath: String, against known: [String]) -> String {
        known.first { $0.caseInsensitiveCompare(typedPath) == .orderedSame } ?? typedPath
    }

    /// The form-save path: trim what was typed, canonicalize it against the
    /// paths already in use, and fall back to the typed text when the fetch
    /// fails. One definition, for the reason the pair above records — the two
    /// form view models held byte-identical private copies of exactly this.
    ///
    /// Deliberately here rather than in `FieldNormalization` beside the year
    /// parsing it was hoisted with: that type is `nonisolated` string work the
    /// import pipeline runs off the main actor, and a `ModelContext` parameter
    /// would put a non-Sendable type in its API for a caller that is always on
    /// the main actor anyway.
    static func canonicalOrTyped(_ typedPath: String, in modelContext: ModelContext) -> String {
        let typed = FieldNormalization.trimmed(typedPath)
        return (try? CategoryPathHelper(modelContext: modelContext).canonicalize(typed)) ?? typed
    }

    /// Every distinct path in use, case-insensitively, keeping whichever
    /// casing was attached to the earliest-created record using that path.
    private func canonicalPaths() throws -> [String] {
        Self.distinctPathsPreferringEarliestCasing(try allRecords())
    }

    private func allRecords() throws -> [(path: String, createdAt: Date)] {
        let itemRecords = try modelContext.fetch(FetchDescriptor<Item>())
            .map { (path: $0.categoryPath, createdAt: $0.createdAt) }
        // Bought entries included, deliberately (015 plan §4): the category
        // is real, and the item the purchase created carries it anyway.
        let wishlistRecords = try modelContext.fetch(FetchDescriptor<WishlistItem>())
            .map { (path: $0.categoryPath, createdAt: $0.createdAt) }
        return itemRecords + wishlistRecords
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

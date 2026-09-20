import Foundation
import Testing
@testable import Trove

/// 015/T003, criterion 15 (plan Q13). "No path in the app undoes a purchase"
/// is guarded by the marker's **one writer**, not by a search for the word
/// "undo": if `boughtDate` is assigned in exactly one place, and that place is
/// `WishlistPurchaseStore.markBought`, then no screen can put a bought entry
/// back on the wishlist — there is nothing that could write the reversal.
///
/// A whole-source scan rather than a view-model test on purpose, and the
/// distinction `CLAUDE.md` draws is the reason it is allowed to be one: this
/// asserts an **absence across every production file**, which no view-model
/// test can observe — a view-model suite can only show that the view models
/// it knows about don't clear the marker, never that the app contains no
/// other writer. The behaviour each writer performs is tested where it lives
/// (`WishlistPurchaseStoreTests`); what is pinned here is that there is only
/// the one.
///
/// **Assignments only**, `boughtDate\s*=(?!=)`: §4's wanted predicates spell
/// out `boughtDate == nil` in several places, and a pattern that counted
/// those would be counting reads. Swift's `Regex` has no lookbehind but does
/// have lookahead, so the comparison is excluded on the character after the
/// `=`.
@Suite("Purchase undo — the marker has one writer")
struct PurchaseUndoTests {
    private static let writer = "Trove/Models/WishlistPurchaseStore.swift"

    /// An assignment of the marker, never a comparison with it — the lookahead
    /// is what keeps §4's `boughtDate == nil` predicates out of the count.
    /// One definition, used by both tests: two copies of this pattern would
    /// agree today and drift the first time one of them is adjusted.
    private static let assignment = try! Regex(#"boughtDate\s*=(?!=)"#)

    /// Every assignment of `boughtDate` in the app, by file.
    private func assignmentsByFile() throws -> [String: Int] {
        var counts: [String: Int] = [:]
        let files = try SourceScan.swiftFiles(under: "Trove", minimum: 21)
        // The anchor: the walk must have reached the one writer before any
        // claim about what it found is worth reading.
        try #require(files.contains(Self.writer), "the source walk never reached \(Self.writer) — wrong root?")
        for path in files {
            let found = try SourceScan.production(path).ranges(of: Self.assignment).count
            if found > 0 { counts[path] = found }
        }
        return counts
    }

    /// Criterion 15's first half. Two legs, because they fail differently: a
    /// second writer anywhere (an undo action, a re-list-it button) breaks the
    /// count, and moving the write into a view model breaks the location while
    /// leaving the count at one.
    @Test func theMarkerIsWrittenExactlyOnceAndOnlyByTheStore() throws {
        let writers = try assignmentsByFile()

        #expect(
            writers.values.reduce(0, +) == 1,
            "`boughtDate` is assigned \(writers.values.reduce(0, +)) times, in \(writers.keys.sorted()) — the purchase has exactly one writer"
        )
        #expect(
            writers.keys.sorted() == [Self.writer],
            "`boughtDate` is assigned in \(writers.keys.sorted()), not in \(Self.writer) alone"
        )
    }

    /// Criterion 15's second half, at the only level it can be held: nothing
    /// clears the marker. A return-to-wishlist path would have to write `nil`
    /// (or `.none`) here to exist at all.
    ///
    /// The control is the test above: the same pattern finds the one real
    /// assignment, so an empty result here is an absence rather than a regex
    /// that matches nothing.
    @Test func nothingInTheAppClearsTheMarker() throws {
        let clearing = try Regex(#"boughtDate\s*=\s*(?:nil|\.none)\b"#)
        let files = try SourceScan.swiftFiles(under: "Trove", minimum: 21)
        try #require(files.contains(Self.writer), "the source walk never reached \(Self.writer) — wrong root?")

        let clearers = try files.filter { try SourceScan.production($0).contains(clearing) }
        #expect(clearers.isEmpty, "\(clearers) clears `boughtDate` — a purchase is not undoable (Decision 5)")

        // The assignment the app does make is not a clear, which is what makes
        // the emptiness above meaningful.
        #expect(try SourceScan.production(Self.writer).contains(Self.assignment))
    }
}

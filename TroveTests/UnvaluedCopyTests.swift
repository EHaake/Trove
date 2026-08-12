import Foundation
import Testing
@testable import Trove

/// One phrase for one fact.
///
/// "This has no current value" is stated on five screens, and by Phase 9 it was
/// being said three different ways — "Not yet valued" (the established one),
/// "Not yet known", and "Not valued". None of them is wrong in isolation, which
/// is exactly why they accumulated: each was written while looking at one
/// screen. Read across screens they suggest three different states.
///
/// A source scan rather than a rendering check, because the failure is a new
/// variant appearing somewhere, and the only way to catch that is to look
/// everywhere at once. Same instinct as `SellPlanFramingTests`.
@Suite("Un-valued copy")
struct UnvaluedCopyTests {
    /// The one phrasing, established at T024 and kept.
    private static let canonical = "Not yet valued"

    /// Variants that have been in the app and shouldn't come back. Quoted with
    /// their opening `"` so this matches string literals rather than the prose
    /// in comments that explains the decision — including this file's own.
    private static let rejected = ["\"Not valued", "\"Not yet known", "\"Unvalued", "\"No value yet"]

    private var viewsDirectory: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Trove/Views")
    }

    private func swiftSources() throws -> [(name: String, contents: String)] {
        let files = FileManager.default.enumerator(at: viewsDirectory, includingPropertiesForKeys: nil)
        var sources: [(String, String)] = []
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            sources.append((url.lastPathComponent, try String(contentsOf: url, encoding: .utf8)))
        }
        return sources
    }

    @Test func everyScreenSaysItTheSameWay() throws {
        let sources = try swiftSources()

        #expect(!sources.isEmpty, "Found no view sources — this test would pass over nothing.")

        var violations: [String] = []
        for (name, contents) in sources {
            for (offset, line) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                for variant in Self.rejected where line.contains(variant) {
                    violations.append("\(name):\(offset + 1): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }

        #expect(
            violations.isEmpty,
            """
            One fact, one phrase — use "\(Self.canonical)" everywhere an item, \
            a category or a total has no current value:
            \(violations.joined(separator: "\n"))
            """
        )
    }

    /// The other half: the canonical phrase is actually in use. Without this,
    /// deleting every variant *including* the right one would pass the check
    /// above — a guard against drift that's satisfied by saying nothing at all.
    @Test func theCanonicalPhraseIsInUse() throws {
        let usingIt = try swiftSources()
            .filter { $0.contents.contains("\"\(Self.canonical)") }
            .map(\.name)
            .sorted()

        #expect(
            usingIt.count >= 3,
            "Only \(usingIt.count) view(s) say \"\(Self.canonical)\": \(usingIt.joined(separator: ", "))"
        )
    }
}

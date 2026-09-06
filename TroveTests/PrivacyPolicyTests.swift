import Foundation
import Testing
@testable import Trove

/// Criterion 17's testable half, and Decision 13's: the policy the app links
/// to has to *exist*, at the name the app links it by, saying the things the
/// spec says it says. A policy that drifts from `MarketCopy.noticeBody` is a
/// policy that lies about what the app sends, so the notice is quoted here
/// verbatim rather than paraphrased — and this test reads the committed file
/// off disk by `#filePath` (the `DocsSampleTests`/`SourceScan` move), because
/// the file is repository documentation, not a bundle resource.
///
/// What this cannot check is the other half of criterion 17 — that the policy
/// **is published**. The blob URL only resolves once the branch merges; that
/// stays a by-hand line item (T018 / post-merge).
@Suite("Privacy policy")
struct PrivacyPolicyTests {
    private static func policyText(file: StaticString = #filePath) throws -> String {
        let url = URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: MarketCopy.privacyPolicyFilename)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func thePolicyExistsAtTheNameTheAppLinksItBy() throws {
        let text = try Self.policyText()
        #expect(!text.isEmpty)
    }

    /// The app promises the person exactly one sentence pair about what
    /// leaves the device; the policy has to be that same pair, word for word.
    @Test func thePolicyQuotesTheNoticeVerbatim() throws {
        let text = try Self.policyText()
        #expect(text.contains(MarketCopy.noticeBody))
    }

    /// Reverb's terms ask for both, and `MarketCopy` is their one home — so
    /// swapping the provisional address (Decision 25) turns this red until
    /// the policy follows.
    @Test func thePolicyCarriesTheContactAddressAndReverbsAttribution() throws {
        let text = try Self.policyText()
        #expect(text.contains(MarketCopy.contactAddress))
        #expect(text.contains(MarketCopy.attribution))
    }

    /// The spec's retention table, as amended by Decision 20: each row of
    /// "What Trove stores" is pinned by the phrase that opens it, so deleting
    /// the table — or one row of it — goes red. The earlier form checked
    /// seven nouns anywhere in the file, which the prose alone satisfied (the
    /// over-broad-pattern shape, caught at 002's pre-merge sweep).
    @Test func thePolicyNamesEveryRowOfTheRetentionTable() throws {
        let text = try Self.policyText()
        let rows = [
            "| Your owned items and wishlist items",
            "| Your photos of your items",
            "| Your own value for an item, adopted or typed",
            "| The match — the Reverb product identifier you picked for an item",
            "| The item's year, when you give one",
            "| The last figure for a matched item — median, low, high, count, when it was fetched",
            "| The matched product's catalog slug and title",
            "| The history of figures for a matched item",
            "| When you tapped Continue on the one-time notice",
            "| Anything from an individual listing — its title, seller, image or listing identifier | nowhere; it is never stored |",
        ]
        for row in rows {
            #expect(text.contains(row), "the retention table lost the row starting \"\(row)\"")
        }
    }

    /// The same guard `MarketCopyTests` puts on the contact address, applied
    /// to the document that publishes it: a policy cannot ship half-written.
    @Test func thePolicyCarriesNoPlaceholder() throws {
        let text = try Self.policyText().lowercased()
        for placeholder in ["todo", "tbd", "lorem", "example.com"] {
            #expect(!text.contains(placeholder), "the policy still says \"\(placeholder)\"")
        }
    }

    @Test func thePolicyStatesWhenItWasLastUpdated() throws {
        let text = try Self.policyText()
        let line = try Regex(#"^Last updated: \d{4}-\d{2}-\d{2}$"#)
        let head = text.split(separator: "\n", omittingEmptySubsequences: false).prefix(5)
        #expect(head.contains { $0.wholeMatch(of: line) != nil })
    }

    /// The link in Settings › About and the file in the repository are the
    /// same document — the filename is the only thing tying them together.
    @Test func theLinkedURLEndsInTheFilename() {
        #expect(MarketCopy.privacyPolicyURL.lastPathComponent == MarketCopy.privacyPolicyFilename)
    }
}

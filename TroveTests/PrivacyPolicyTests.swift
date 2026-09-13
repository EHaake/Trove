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
    private static func policyText(
        named filename: String = MarketCopy.privacyPolicyFilename,
        file: StaticString = #filePath
    ) throws -> String {
        let url = URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: filename)
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
            "| When you tapped Continue on the one-time notice before a first search of Reverb",
            "| When you tapped Continue on the one-time notice before a first photo search",
            "| A stock photo you picked from Wikimedia Commons",
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

    /// The line every copy of this document opens with. Asserting the linked
    /// name resolves to a file that *says* it is the privacy policy is what
    /// makes these two link tests falsifiable: matching the URL's last
    /// component against the filename constant passes for any pair of equal
    /// strings, so repointing both constants at `README.md` used to stay
    /// green (Phase 4 review note 2, the 002 shape it inherited).
    private static let policyTitle = "# Trove — Privacy Policy"

    /// The link in Settings › About and the file in the repository are the
    /// same document — the filename ties them together, and the file it names
    /// has to be the policy itself.
    @Test func theLinkedURLEndsInTheFilename() throws {
        #expect(MarketCopy.privacyPolicyURL.lastPathComponent == MarketCopy.privacyPolicyFilename)
        let text = try Self.policyText(named: MarketCopy.privacyPolicyFilename)
        #expect(
            text.contains(Self.policyTitle),
            "the name the app links by is not the privacy policy"
        )
    }

    // MARK: - Spec 005: the stock-photo half (criterion 9, P6)

    /// The same coupling as the Reverb notice, for the photo notice: the
    /// sheet's words and the policy's words are one string, so a reworded
    /// notice that leaves the policy behind goes red (guard G12).
    @Test func thePolicyQuotesTheStockPhotoNoticeVerbatim() throws {
        let text = try Self.policyText()
        #expect(text.contains(StockPhotoCopy.noticeBody))
    }

    /// Criterion 9's two substantive claims: Wikimedia Commons is named as a
    /// second outside service, and the policy says a fetched photo *does*
    /// sync — the one place stock photos differ from the market figures.
    /// Pinned as whole lines, so flipping the table's answer to "no" or
    /// dropping the sentence goes red rather than passing on the noun alone.
    @Test func thePolicyNamesWikimediaCommonsAndStatesThatAFetchedPhotoSyncs() throws {
        let text = try Self.policyText()
        #expect(text.contains("Wikimedia Commons"))
        #expect(
            text.contains(
                "| A stock photo you picked from Wikimedia Commons, with its credit — the photographer, the licence and the link back | on your device | yes, to your private iCloud database |"
            ),
            "the retention table no longer says a fetched photo syncs"
        )
        // Unwrapped first: the sentence is prose, so its line breaks move
        // whenever the paragraph reflows, and only its words should matter.
        let unwrapped = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(
            unwrapped.contains("A stock photo you picked does sync, with its credit"),
            "the iCloud section no longer states that a fetched photo syncs"
        )
    }

    /// Wikimedia's User-Agent policy asks for a way to reach the developer,
    /// the same way Reverb's terms do, and `StockPhotoCopy` is 005's home for
    /// that address — so changing it there turns this red until the policy
    /// follows.
    @Test func thePolicyCarriesTheStockPhotoContactAddress() throws {
        let text = try Self.policyText()
        #expect(text.contains(StockPhotoCopy.contactAddress))
    }

    /// The photo notice's "See the privacy policy" link and the committed
    /// file are the same document, by the same two ties the market notice
    /// uses: the filename the app links by, and a file that exists under it.
    @Test func theStockPhotoLinkPointsAtTheSameExistingFile() throws {
        #expect(StockPhotoCopy.privacyPolicyURL.lastPathComponent == StockPhotoCopy.privacyPolicyFilename)
        let text = try Self.policyText(named: StockPhotoCopy.privacyPolicyFilename)
        #expect(
            text.contains(Self.policyTitle),
            "the name the photo notice links by is not the privacy policy"
        )
    }
}

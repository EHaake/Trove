import Foundation
import Testing
@testable import Trove

/// Spec 005's copy, pinned whole (the `MarketCopyTests` model): every string
/// in the spec's Copy section, the notice split reassembled to its full
/// sentence, the composed credit at its edges, and the one guard that can
/// block a task — the contact address (plan Q6).
@Suite("Stock photo copy")
struct StockPhotoCopyTests {
    @Test func theActionAndPickerStrings() {
        #expect(StockPhotoCopy.findAPhoto == "Find a photo…")
        #expect(StockPhotoCopy.pickerTitle == "Choose a photo")
        #expect(StockPhotoCopy.emptyState == "No usable photos found for that name.")
        #expect(StockPhotoCopy.searchAgain == "Search again")
        #expect(StockPhotoCopy.badge == "Stock photo")
    }

    /// The picker's status line, search-field placeholder and Cancel — added
    /// at T008 for the picker sheet (item A), pinned whole like the rest.
    @Test func thePickerSheetStrings() {
        #expect(StockPhotoCopy.searching == "Searching Wikimedia Commons…")
        #expect(StockPhotoCopy.searchPlaceholder == "Search Wikimedia Commons")
        #expect(StockPhotoCopy.cancel == "Cancel")
    }

    @Test func theNoticeStrings() {
        #expect(StockPhotoCopy.noticeBody == "Finding a photo sends this item’s name to Wikimedia Commons — nothing else about it. The photo you pick is stored on your device and syncs with your other devices, like a photo you take.")
        #expect(StockPhotoCopy.noticeLinkTitle == "See the privacy policy")
        #expect(StockPhotoCopy.noticeContinue == "Continue")
        #expect(StockPhotoCopy.noticeNotNow == "Not now")
    }

    /// The spec's sentence, reassembled from the body and the link the sheet
    /// draws separately — the `MarketCopyTests.theNoticeReassemblesToTheSpecsSentence`
    /// shape. `PRIVACY.md` (T014) quotes this verbatim.
    @Test func theNoticeReassemblesToTheSpecsSentence() {
        #expect(StockPhotoCopy.noticeBody + " " + StockPhotoCopy.noticeLinkTitle + "."
            == "Finding a photo sends this item’s name to Wikimedia Commons — nothing else about it. The photo you pick is stored on your device and syncs with your other devices, like a photo you take. See the privacy policy.")
    }

    @Test func theCreditPieces() {
        #expect(StockPhotoCopy.creditSource == "Wikimedia Commons")
        #expect(StockPhotoCopy.creditSeparator == "·")
    }

    @Test func theCreditAtARealAuthor() {
        #expect(StockPhotoCopy.credit(author: "Jane Doe", licenseName: "CC BY-SA 4.0")
            == "Photo: Jane Doe · CC BY-SA 4.0 · Wikimedia Commons")
    }

    /// The no-author fallback names Wikimedia Commons as the author, so the
    /// segment repeats — pinned so the composition doesn't drift.
    @Test func theCreditAtTheNoAuthorAuthor() {
        #expect(StockPhotoCopy.credit(author: "Wikimedia Commons", licenseName: "Public domain")
            == "Photo: Wikimedia Commons · Public domain · Wikimedia Commons")
    }

    @Test func theReplaceKeepAlert() {
        #expect(StockPhotoCopy.replaceKeepMessage == "This item has a stock photo. Keep it, or replace it with your photo?")
        #expect(StockPhotoCopy.keepBoth == "Keep both")
        #expect(StockPhotoCopy.replace == "Replace")
    }

    @Test func theFailureCopy() {
        #expect(StockPhotoCopy.failure == "Couldn’t reach Wikimedia Commons. Try again in a while.")
    }

    @Test func theAccessibilityStrings() {
        #expect(StockPhotoCopy.badgeAccessibilityLabel == "Representative stock image")
        #expect(StockPhotoCopy.creditLinkHint == "Opens Wikimedia Commons in your browser")
    }

    @Test func theAboutLinks() {
        #expect(StockPhotoCopy.privacyPolicyTitle == "Privacy policy")
        #expect(StockPhotoCopy.privacyPolicyFilename == "PRIVACY.md")
        #expect(StockPhotoCopy.privacyPolicyURL.absoluteString == "https://github.com/EHaake/Trove/blob/main/PRIVACY.md")
        #expect(StockPhotoCopy.privacyPolicyURL.lastPathComponent == StockPhotoCopy.privacyPolicyFilename)
    }

    @Test func theContactAddressIsARealOne() {
        let address = StockPhotoCopy.contactAddress
        let lowered = address.lowercased()
        // Computed ahead of the expectations: a closure inside `#expect`
        // trips the macro's throwing inference.
        let atSigns = address.filter { $0 == "@" }.count
        let hasWhitespace = address.contains(where: \.isWhitespace)
        let domain = address.split(separator: "@").last.map(String.init) ?? ""
        let domainHasADot = domain.range(of: ".") != nil
        let isPlaceholder = lowered.range(of: "todo") != nil || lowered.range(of: "example.com") != nil

        #expect(atSigns == 1, "not one @: \(address)")
        #expect(!hasWhitespace, "whitespace in the address: \(address)")
        #expect(!isPlaceholder, "the placeholder is still in place: \(address)")
        #expect(domainHasADot, "no domain after the @: \(address)")
    }
}

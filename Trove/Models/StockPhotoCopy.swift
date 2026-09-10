import Foundation

/// Spec 005's copy — the stock-photo picker's strings, pinned whole by
/// `StockPhotoCopyTests` and read by the views and view models, never typed
/// inline. Mirrors `MarketCopy`'s shape, including its notice split (a body
/// that excludes the link title, and a link title that reassembles with it
/// to the full spec sentence) and its privacy-policy URL/filename/title.
///
/// 005 is self-contained from 002, so the one real address is duplicated here
/// deliberately rather than shared with `MarketCopy` — a later `AppContact`
/// unification is a close-out note (plan Q6).
nonisolated enum StockPhotoCopy {
    // MARK: - Action

    /// The ellipsis is `…` (`\u{2026}`), matching `MarketCopy.findOnReverb`.
    static let findAPhoto = "Find a photo\u{2026}"

    // MARK: - The one-time notice (criterion 9, §5)

    /// The notice body, excluding the link title (which the sheet draws
    /// separately). `PRIVACY.md` (T014) quotes this verbatim, so it is the
    /// exact final string. `noticeBody + " " + noticeLinkTitle + "."` is the
    /// full spec sentence — pinned in `StockPhotoCopyTests`.
    static let noticeBody = "Finding a photo sends this item\u{2019}s name to Wikimedia Commons \u{2014} nothing else about it. The photo you pick is stored on your device and syncs with your other devices, like a photo you take."
    static let noticeLinkTitle = "See the privacy policy"
    static let noticeContinue = "Continue"
    static let noticeNotNow = "Not now"

    // MARK: - The picker

    static let pickerTitle = "Choose a photo"
    static let emptyState = "No usable photos found for that name."
    static let searchAgain = "Search again"
    /// The picker's status line while a search is in flight (the design's
    /// analog of MarketCopy.searching). The ellipsis is `…` (\u{2026}).
    static let searching = "Searching Wikimedia Commons\u{2026}"
    /// The search field's placeholder when cleared.
    static let searchPlaceholder = "Search Wikimedia Commons"
    /// The picker's Cancel toolbar item. 005 stays self-contained from 002's
    /// `MarketCopy.cancel`, so it carries its own.
    static let cancel = "Cancel"

    // MARK: - The badge

    static let badge = "Stock photo"

    // MARK: - The credit (spec P4)

    /// The link segment of the credit line.
    static let creditSource = "Wikimedia Commons"
    /// The middle dot between credit segments (`\u{00B7}`), matching
    /// `MarketCopy.separator`.
    static let creditSeparator = "\u{00B7}"

    /// The full plain-text credit — used by the PDF export (T013) and
    /// VoiceOver. The view (T007) draws the last segment as a link using
    /// `creditSource`.
    static func credit(author: String, licenseName: String) -> String {
        "Photo: \(author) \(creditSeparator) \(licenseName) \(creditSeparator) \(creditSource)"
    }

    // MARK: - The replace/keep alert (Decision 4a)

    static let replaceKeepMessage = "This item has a stock photo. Keep it, or replace it with your photo?"
    static let keepBoth = "Keep both"
    static let replace = "Replace"

    // MARK: - Failure

    static let failure = "Couldn\u{2019}t reach Wikimedia Commons. Try again in a while."

    // MARK: - Accessibility

    static let badgeAccessibilityLabel = "Representative stock image"
    static let creditLinkHint = "Opens Wikimedia Commons in your browser"

    // MARK: - Contact

    /// The contact address Wikimedia's User-Agent policy asks a client to
    /// carry, so a maintainer is reachable. Read from here, its one home.
    static let contactAddress = "canadianfishturkey@gmail.com"

    // MARK: - Privacy policy (mirror `MarketCopy`)

    static let privacyPolicyTitle = "Privacy policy"
    static let privacyPolicyFilename = "PRIVACY.md"
    static let privacyPolicyURL = URL(string: "https://github.com/EHaake/Trove/blob/main/PRIVACY.md")!
}

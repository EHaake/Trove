import Testing
@testable import Trove

/// Wiring guards for the stock-photo notice and picker sheet (T008).
///
/// These scan the two view files' *production* source (comments stripped,
/// `#Preview` dropped by `SourceScan.production`) so a guard can't be satisfied
/// by a comment or a preview — the hardened `SourceScan` shape the project
/// settled after shipping scans that couldn't fail.
@Suite("Stock photo picker wiring")
struct PhotoPickerWiringTests {
    private static let notice = "Trove/Views/Photos/PhotoNoticeView.swift"
    private static let picker = "Trove/Views/Photos/PhotoPickerSheetView.swift"

    /// The notice draws a real `Link` to the policy, once — not a `Button`,
    /// not `openURL`. The non-identifier-boundary regex is `MarketWiringTests`'
    /// `theOutwardLinkIsALinkNotAButton` pattern, so `NavigationLink(` can't
    /// stand in for it. Mutation: make the notice's `Link` a `Button` → red.
    @Test func theNoticeLinksToThePolicy() throws {
        let code = try SourceScan.production(Self.notice)
        let link = try Regex(#"(?:^|[^A-Za-z0-9_])Link\("#)
        let links = code.ranges(of: link).count
        #expect(links == 1, "the notice draws \(links) links — the privacy link is the one and only")
        #expect(code.contains("StockPhotoCopy.privacyPolicyURL"), "the notice's link doesn't point at the policy URL")
    }

    /// The candidate cell composes the shared `StockPhotoCredit` rather than a
    /// second credit view (item C).
    @Test func theCandidateComposesStockPhotoCredit() throws {
        let code = try SourceScan.production(Self.picker)
        #expect(code.contains("StockPhotoCredit("), "the candidate cell doesn't compose StockPhotoCredit")
    }

    /// Exactly one photos view file fetches an image over the network — the
    /// picker, and nowhere else — the `onlyThePickerFetchesAnImageFromTheNetwork`
    /// shape for 005.
    @Test func asyncImageLivesInExactlyOnePhotosViewFile() throws {
        let files = try SourceScan.swiftFiles(under: "Trove/Views/Photos", minimum: 2)
        let fetchers = try files.filter { try SourceScan.production($0).contains("AsyncImage(") }
        #expect(fetchers == [Self.picker], "AsyncImage lives in \(fetchers) — it should be the picker alone")
    }

    /// The notice's three identifiers and the picker's search identifier are
    /// present in production source.
    @Test func theIdentifiersArePresent() throws {
        let noticeCode = try SourceScan.production(Self.notice)
        #expect(noticeCode.contains("stockphoto.notice.continue"))
        #expect(noticeCode.contains("stockphoto.notice.notNow"))
        #expect(noticeCode.contains("stockphoto.notice.privacy"))

        let pickerCode = try SourceScan.production(Self.picker)
        #expect(pickerCode.contains("stockphoto.search"))
    }
}

import Foundation
import Testing
@testable import Trove

/// Spec 002's copy, pinned whole (the `DeleteAllCopyTests` model): every
/// string in the spec's Copy section as amended, the planning additions,
/// the composed forms at their edges, and the one guard that can block a
/// task — the contact address (Decision 25).
@Suite("Market copy")
struct MarketCopyTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - The section

    @Test func theSectionsFixedStrings() {
        #expect(MarketCopy.sectionTitle == "Market")
        #expect(MarketCopy.sourceLine == "On Reverb")
        #expect(MarketCopy.separator == "·")
        #expect(MarketCopy.refreshDue == "A refresh is due.")
        #expect(MarketCopy.notRefreshedHere == "Not refreshed on this device.")
    }

    @Test func theSourceLineCarriesTheTitleAndTheYearWhenItHasThem() {
        #expect(MarketCopy.sourceLine(title: nil, year: nil) == "On Reverb")
        #expect(MarketCopy.sourceLine(title: "Martin D-18", year: nil) == "On Reverb · Martin D-18")
        #expect(MarketCopy.sourceLine(title: "Martin D-18", year: 1975) == "On Reverb · Martin D-18 · 1975")
        #expect(MarketCopy.sourceLine(title: "", year: 1975) == "On Reverb · 1975")
    }

    @Test func theFigureIsTheMedianAndTheCount() {
        #expect(MarketCopy.figure(medianCents: 145_000, count: 12) == "$1,450 · 12 listed")
        #expect(MarketCopy.figure(medianCents: 139_999, count: 1) == "$1,400 · 1 listed")
        #expect(MarketCopy.listed(count: 2) == "2 listed")
    }

    @Test func theSpreadIsAnEnDash() {
        let spread = MarketCopy.spread(lowCents: 110_000, highCents: 200_000)
        #expect(spread == "$1,100–$2,000")
        #expect(spread.unicodeScalars.contains("\u{2013}"))
        #expect(!spread.contains("-"))
    }

    @Test func theAgeReadsAsOf() {
        #expect(MarketCopy.age(fetchedAt: t0.addingTimeInterval(-2 * 3600), at: t0) == "as of 2 hours ago")
        #expect(MarketCopy.age(fetchedAt: t0.addingTimeInterval(-3 * 86_400), at: t0) == "as of 3 days ago")
    }

    @Test func theWithheldCopyOffersTheCatalogsLowestUsedPriceWhenThereIsOne() {
        #expect(MarketCopy.withheld(usedLowCents: 110_000, wanted: false)
            == "Too few listings in this condition to say. The lowest used asking price on Reverb is $1,100.")
        #expect(MarketCopy.withheld(usedLowCents: nil, wanted: false) == "Too few listings in this condition to say.")
        #expect(MarketCopy.withheld(usedLowCents: 110_000, wanted: true)
            == "Too few used listings to say. The lowest used asking price on Reverb is $1,100.")
    }

    @Test func theAllYearsFallbackNamesTheYear() {
        #expect(MarketCopy.allYearsFallback(year: 1975, wanted: false) == "Too few 1975 listings in this condition — all years shown.")
        #expect(MarketCopy.allYearsFallback(year: 1975, wanted: true) == "Too few 1975 used listings — all years shown.")
    }

    // MARK: - Actions, notice, failure

    @Test func theActions() {
        #expect(MarketCopy.findOnReverb == "Find on Reverb…")
        #expect(MarketCopy.refresh == "Refresh")
        #expect(MarketCopy.useAsMyValue == "Use as my value")
        #expect(MarketCopy.useAsEstimatedCost == "Use as estimated cost")
        #expect(MarketCopy.changeMatch == "Change match…")
        #expect(MarketCopy.removeMatch == "Remove match")
        #expect(MarketCopy.viewOnReverb == "View on Reverb")
    }

    // MARK: - The value step (B7, Amendment B)

    @Test func theValueStepsStrings() {
        #expect(MarketCopy.fetchingAskingPrices == "Fetching asking prices\u{2026}")
        #expect(MarketCopy.valueStepTitle(wanted: false) == "Set your value")
        #expect(MarketCopy.valueStepTitle(wanted: true) == "Set your estimated cost")
        #expect(MarketCopy.valueGuidance == "Drag toward the high end if yours is in better shape than most.")
        #expect(MarketCopy.medianMark == "median")
        #expect(MarketCopy.yourValue(wanted: false) == "Your value")
        #expect(MarketCopy.yourValue(wanted: true) == "Your estimated cost")
    }

    /// The filled button carries the amount the slider is on, at both kinds.
    @Test func theButtonNamesTheAmountItWouldWrite() {
        #expect(MarketCopy.useAmount(cents: 145_000, wanted: false) == "Use $1,450 as my value")
        #expect(MarketCopy.useAmount(cents: 34_900, wanted: true) == "Use $349 as estimated cost")
    }

    /// Spec Decision 37's wording for the slider's spoken marks and hint.
    @Test func theSlidersSpokenMarksAndHint() {
        #expect(MarketCopy.sliderHint == "Slides between the typical low and high asking prices.")
        #expect(MarketCopy.typicalLowLabel(cents: 115_000) == "typical low asking price $1,150")
        #expect(MarketCopy.medianAskingPriceLabel(cents: 145_000) == "median asking price $1,450")
        #expect(MarketCopy.typicalHighLabel(cents: 190_000) == "typical high asking price $1,900")
        #expect(MarketCopy.figureAccessibilityLabel(medianCents: 145_000) == "Median asking price $1,450")
    }

    /// The spec's sentence, reassembled from the body and the link the sheet
    /// draws separately.
    @Test func theNoticeReassemblesToTheSpecsSentence() {
        #expect(MarketCopy.noticeBody + " " + MarketCopy.noticeLinkTitle + "."
            == "Finding a match sends this item’s name to Reverb — nothing else about it. Refreshing later sends only which product it is — your item’s details stay on this device. See the privacy policy.")
        #expect(MarketCopy.noticeContinue == "Continue")
        #expect(MarketCopy.noticeNotNow == "Not now")
    }

    @Test func theFailureCopy() {
        #expect(MarketCopy.unreachable(fetchedAt: t0.addingTimeInterval(-2 * 3600), at: t0) == "Couldn’t reach Reverb. The figure below is from 2 hours ago.")
        #expect(MarketCopy.unreachableNoFigure == "Couldn’t reach Reverb.")
        #expect(MarketCopy.rateLimited == "Reverb is asking us to slow down. Try again in a while.")
        #expect(MarketCopy.productGone == "This product is no longer on Reverb. Change the match to keep refreshing.")
    }

    // MARK: - Sort, dashboard, picker, Settings

    @Test func theSortLabels() {
        #expect(MarketCopy.sortDescending == "Market ↓")
        #expect(MarketCopy.sortAscending == "Market ↑")
    }

    @Test func theDashboardLineCarriesItsCoverage() {
        #expect(MarketCopy.dashboardLine(totalCents: 1_840_000, count: 12, totalCount: 34) == "Market · $18,400 · 12 of 34 items")
    }

    @Test func thePickerCopy() {
        #expect(MarketCopy.pickerTitle == "Find on Reverb")
        #expect(MarketCopy.searchPlaceholder == "Search Reverb")
        #expect(MarketCopy.searching == "Searching Reverb…")
        #expect(MarketCopy.noCandidates(query: "AV II Strat") == "No matches for “AV II Strat” on Reverb")
        #expect(MarketCopy.noCandidatesDetail == "Try a shorter name — the brand and model are enough.")
        #expect(MarketCopy.candidateReading(usedLowCents: 110_000, usedTotal: 34) == "Lowest used asking price $1,100 · 34 listed")
        #expect(MarketCopy.candidateReading(usedLowCents: nil, usedTotal: 0) == "No used listings")
        #expect(MarketCopy.candidateReading(usedLowCents: 110_000, usedTotal: 0) == "No used listings")
        #expect(MarketCopy.tryAgain == "Try again")
        #expect(MarketCopy.cancel == "Cancel")
    }

    @Test func theSettingsCopy() {
        #expect(MarketCopy.settingsSectionTitle == "Market")
        #expect(MarketCopy.refreshAll == "Refresh market values")
        #expect(MarketCopy.progress(done: 3, total: 12) == "3 of 12")
        #expect(MarketCopy.refreshStoppedUnreachable(done: 3, total: 12) == "Couldn’t reach Reverb. 3 of 12 refreshed.")
    }

    // MARK: - About

    /// Reverb's terms, verbatim — typed here from the terms, not copied
    /// from the constant.
    @Test func theAttributionIsVerbatim() {
        #expect(MarketCopy.attribution == "This application uses the Reverb API but is not endorsed, created by or certified by Reverb.com, LLC.")
    }

    @Test func theAboutLinks() {
        #expect(MarketCopy.privacyPolicyTitle == "Privacy policy")
        #expect(MarketCopy.privacyPolicyFilename == "PRIVACY.md")
        #expect(MarketCopy.privacyPolicyURL.absoluteString == "https://github.com/EHaake/Trove/blob/main/PRIVACY.md")
        #expect(MarketCopy.privacyPolicyURL.lastPathComponent == MarketCopy.privacyPolicyFilename)
        #expect(MarketCopy.contactURL.scheme == "mailto")
    }

    @Test func theContactAddressIsARealOne() {
        let address = MarketCopy.contactAddress
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

    // MARK: - The year field, accessibility

    @Test func theYearField() {
        #expect(MarketCopy.yearLabel == "Year")
        #expect(MarketCopy.yearValidationError(nextYear: 2027) == "Year should be four digits, 1900 to 2027.")
    }

    @Test func theAccessibilityStrings() {
        #expect(MarketCopy.trendUp == "trending up")
        #expect(MarketCopy.trendDown == "trending down")
        #expect(MarketCopy.figureAccessibilityLabel(medianCents: 145_000) == "Median asking price $1,450")
        #expect(MarketCopy.countAccessibilityLabel(12) == "from 12 listings")
        #expect(MarketCopy.spreadAccessibilityLabel(lowCents: 110_000, highCents: 200_000) == "Asking prices from $1,100 to $2,000")
        #expect(MarketCopy.ageAccessibilityLabel(fetchedAt: t0.addingTimeInterval(-7200), at: t0) == "As of 2 hours ago")
        #expect(MarketCopy.reverbLinkHint == "Opens reverb.com in your browser.")
        #expect(MarketCopy.refreshWithinHourHint == "Refreshed less than an hour ago.")
    }
}

/// The hand formatter's table, boundary by boundary.
@Suite("Market age")
struct MarketAgeTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private nonisolated static let table: [(Double, String)] = [
        (0, "just now"), (30, "just now"), (59, "just now"), (-3600, "just now"),
        (60, "1 minute ago"), (61, "1 minute ago"), (119, "1 minute ago"), (120, "2 minutes ago"), (3540, "59 minutes ago"),
        (3600, "1 hour ago"), (7200, "2 hours ago"), (86_340, "23 hours ago"),
        (86_400, "1 day ago"), (259_200, "3 days ago"), (2_937_600, "34 days ago"),
    ]

    @Test(arguments: table)
    func theTable(secondsAgo: Double, expected: String) {
        #expect(MarketAge.description(of: t0.addingTimeInterval(-secondsAgo), at: t0) == expected)
    }
}

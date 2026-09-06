import Foundation

/// Every user-facing string of spec 002 — its Copy section as amended,
/// the planning additions (plan Q7), the year field (Decision 29), and
/// the accessibility strings — pinned whole by `MarketCopyTests` and read
/// by the views and view models, never typed inline. `MarketVocabularyTests`
/// scans this file for the words spec P10 forbids of the fetched figure:
/// it is an *asking price on Reverb*, never a value, a worth or a price.
///
/// Money is formatted the way the rest of the app formats it, so the
/// figure beside the person's own value is typeset identically.
nonisolated enum MarketCopy {
    // MARK: - The section

    static let sectionTitle = "Market"
    static let sourceLine = "On Reverb"
    static let separator = "·"

    /// "On Reverb · Martin D-18 · 1975" — the title when the device has the
    /// product's snapshot, the year when the item has one.
    static func sourceLine(title: String?, year: Int?) -> String {
        var parts = [sourceLine]
        if let title, !title.isEmpty { parts.append(title) }
        if let year { parts.append(String(year)) }
        return parts.joined(separator: " \(separator) ")
    }

    static func median(cents: Int) -> String {
        cents.formattedAsWholeCurrency(currencyCode: "USD")
    }

    static func listed(count: Int) -> String {
        "\(count) listed"
    }

    /// "$1,450 · 12 listed", composed from its parts so the three can't drift.
    static func figure(medianCents: Int, count: Int) -> String {
        "\(median(cents: medianCents)) \(separator) \(listed(count: count))"
    }

    /// "$1,100–$2,000", an en dash.
    static func spread(lowCents: Int, highCents: Int) -> String {
        "\(median(cents: lowCents))\u{2013}\(median(cents: highCents))"
    }

    /// "as of 2 hours ago"
    static func age(fetchedAt: Date, at now: Date) -> String {
        "as of \(MarketAge.description(of: fetchedAt, at: now))"
    }

    static let withheldOwned = "Too few listings in this condition to say."
    static let withheldWanted = "Too few used listings to say."

    /// The withheld reading, with the catalog's lowest used asking price
    /// when it has one (spec Decision 6; the second sentence drops when the
    /// catalog offers none — plan Q7).
    static func withheld(usedLowCents: Int?, wanted: Bool) -> String {
        let first = wanted ? withheldWanted : withheldOwned
        guard let usedLowCents else { return first }
        return "\(first) The lowest used asking price on Reverb is \(median(cents: usedLowCents))."
    }

    /// Decision 29: narrowing by year left fewer than three, so every year
    /// counted — said above the figure.
    static func allYearsFallback(year: Int, wanted: Bool) -> String {
        wanted
            ? "Too few \(year) used listings \u{2014} all years shown."
            : "Too few \(year) listings in this condition \u{2014} all years shown."
    }

    static let refreshDue = "A refresh is due."
    static let notRefreshedHere = "Not refreshed on this device."

    // MARK: - Actions

    static let findOnReverb = "Find on Reverb\u{2026}"
    static let refresh = "Refresh"
    static let useAsMyValue = "Use as my value"
    static let useAsEstimatedCost = "Use as estimated cost"
    static let changeMatch = "Change match\u{2026}"
    static let removeMatch = "Remove match"
    static let viewOnReverb = "View on Reverb"

    // MARK: - The value step (Amendment B)

    /// The sheet's own status line while the pick's refresh is in flight,
    /// so the sheet doesn't go blank between the pick and the slider.
    static let fetchingAskingPrices = "Fetching asking prices\u{2026}"

    static func valueStepTitle(wanted: Bool) -> String {
        wanted ? "Set your estimated cost" : "Set your value"
    }

    static let valueGuidance = "Drag toward the high end if yours is in better shape than most."

    /// "Use $1,450 as my value" — the filled button, carrying the amount
    /// the slider is on.
    static func useAmount(cents: Int, wanted: Bool) -> String {
        wanted ? "Use \(median(cents: cents)) as estimated cost" : "Use \(median(cents: cents)) as my value"
    }

    static let medianMark = "median"

    static func yourValue(wanted: Bool) -> String {
        wanted ? "Your estimated cost" : "Your value"
    }

    /// Q22 — proposed wording, pending the person's answer at T020; the
    /// approved Copy block says "lowest/highest asking price" and "Slides
    /// between the lowest and highest asking prices."
    static let sliderHint = "Slides between the typical low and high asking prices."

    /// Q22 — proposed wording, pending the person's answer at T020; the
    /// approved Copy block says "lowest/highest asking price" and "Slides
    /// between the lowest and highest asking prices."
    static func typicalLowLabel(cents: Int) -> String {
        "typical low asking price \(median(cents: cents))"
    }

    /// Q22 — proposed wording, pending the person's answer at T020; the
    /// approved Copy block says "lowest/highest asking price" and "Slides
    /// between the lowest and highest asking prices."
    static func typicalHighLabel(cents: Int) -> String {
        "typical high asking price \(median(cents: cents))"
    }

    /// The slider's middle mark — the spec's spoken marks are all lowercase
    /// ("median asking price $1,450"), unlike the section's own
    /// `figureAccessibilityLabel`, which opens a sentence and stays capitalised.
    static func medianAskingPriceLabel(cents: Int) -> String {
        "median asking price \(median(cents: cents))"
    }

    // MARK: - The one-time notice (Decision 14, P15)

    /// Decision 31: the second sentence names what the refresh request
    /// carries — the product identifier alone; the condition and the year
    /// are applied on the device, to the listings after they arrive.
    static let noticeBody = "Finding a match sends this item\u{2019}s name to Reverb \u{2014} nothing else about it. Refreshing later sends only which product it is \u{2014} your item\u{2019}s details stay on this device."
    static let noticeLinkTitle = "See the privacy policy"
    static let noticeContinue = "Continue"
    static let noticeNotNow = "Not now"

    // MARK: - Failure

    /// "Couldn't reach Reverb. The figure below is from 2 hours ago."
    static func unreachable(fetchedAt: Date, at now: Date) -> String {
        "\(unreachableNoFigure) The figure below is from \(MarketAge.description(of: fetchedAt, at: now))."
    }

    static let unreachableNoFigure = "Couldn\u{2019}t reach Reverb."
    static let rateLimited = "Reverb is asking us to slow down. Try again in a while."
    static let productGone = "This product is no longer on Reverb. Change the match to keep refreshing."

    // MARK: - Sort

    static let sortDescending = "Market \u{2193}"
    static let sortAscending = "Market \u{2191}"

    // MARK: - Dashboard (Decision 22)

    /// "Market · $18,400 · 12 of 34 items"
    static func dashboardLine(totalCents: Int, count: Int, totalCount: Int) -> String {
        "\(sectionTitle) \(separator) \(median(cents: totalCents)) \(separator) \(count) of \(totalCount) items"
    }

    // MARK: - The picker

    static let pickerTitle = "Find on Reverb"
    static let searchPlaceholder = "Search Reverb"
    static let searching = "Searching Reverb\u{2026}"

    static func noCandidates(query: String) -> String {
        "No matches for \u{201C}\(query)\u{201D} on Reverb"
    }

    static let noCandidatesDetail = "Try a shorter name \u{2014} the brand and model are enough."

    /// "Lowest used asking price $1,100 · 34 listed", or "No used listings".
    static func candidateReading(usedLowCents: Int?, usedTotal: Int) -> String {
        guard let usedLowCents, usedTotal > 0 else { return "No used listings" }
        return "Lowest used asking price \(median(cents: usedLowCents)) \(separator) \(listed(count: usedTotal))"
    }

    static let tryAgain = "Try again"
    static let cancel = "Cancel"

    // MARK: - Settings

    static let settingsSectionTitle = "Market"
    static let refreshAll = "Refresh market values"

    static func progress(done: Int, total: Int) -> String {
        "\(done) of \(total)"
    }

    /// Decision 27: the walk stopped by a failure that isn't the rate limit.
    static func refreshStoppedUnreachable(done: Int, total: Int) -> String {
        "\(unreachableNoFigure) \(done) of \(total) refreshed."
    }

    // MARK: - About (Decisions 12, 13, 18, 25)

    /// Reverb's terms, verbatim.
    static let attribution = "This application uses the Reverb API but is not endorsed, created by or certified by Reverb.com, LLC."

    /// The dedicated contact address for the app (spec Decisions 12 and 25):
    /// shown in Settings › About, named in `PRIVACY.md`, and sent in the
    /// Reverb client's `User-Agent` — one constant, so the placeholder guard
    /// in `MarketCopyTests` covers every copy. Supplied by the person
    /// 2026-09-04 as a **provisional** personal address, to be swapped for a
    /// dedicated one before the app is published — one edit here, and the
    /// whole-string pins in `MarketCopyTests` move with it.
    static let contactAddress = "canadianfishturkey@gmail.com"

    static var contactURL: URL { URL(string: "mailto:\(contactAddress)")! }

    static let privacyPolicyTitle = "Privacy policy"
    static let privacyPolicyFilename = "PRIVACY.md"
    static let privacyPolicyURL = URL(string: "https://github.com/EHaake/Trove/blob/main/PRIVACY.md")!

    // MARK: - The year field (Decision 29, P18)

    static let yearLabel = "Year"

    static func yearValidationError(nextYear: Int) -> String {
        "Year should be four digits, 1900 to \(nextYear)."
    }

    // MARK: - Accessibility (criterion 20)

    static let trendUp = "trending up"
    static let trendDown = "trending down"

    static func figureAccessibilityLabel(medianCents: Int) -> String {
        "Median asking price \(median(cents: medianCents))"
    }

    static func countAccessibilityLabel(_ count: Int) -> String {
        "from \(count) listings"
    }

    static func spreadAccessibilityLabel(lowCents: Int, highCents: Int) -> String {
        "Asking prices from \(median(cents: lowCents)) to \(median(cents: highCents))"
    }

    static func ageAccessibilityLabel(fetchedAt: Date, at now: Date) -> String {
        "As of \(MarketAge.description(of: fetchedAt, at: now))"
    }

    static let reverbLinkHint = "Opens reverb.com in your browser."
    static let refreshWithinHourHint = "Refreshed less than an hour ago."
}

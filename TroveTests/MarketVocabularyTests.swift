import Foundation
import Testing
@testable import Trove

/// Spec P10, as an instrument (the `UnvaluedCopyTests` shape): the fetched
/// figure is an *asking price on Reverb* — never the item's value, worth
/// or price, and never "sold". Two rules over the files that describe it,
/// both able to fail:
///
/// 1. In every string literal of the named files, after the allowed phrases
///    are removed, none of the forbidden words remains.
/// 2. Every named file exists and is scanned — a `#require` on the count,
///    the `MenuPolicyTests` lesson — and the framing is actually in use.
///
/// Scoped to the Market files on purpose: "Current value", "Worth now" and
/// "Not yet valued" are the app's own words for the *person's* numbers,
/// and a scan over every view would false-fire on them. The scope stays
/// honest because the Market view files may carry no string literal
/// containing a space at all (rule 3, below) — every word they show
/// reaches the screen through `MarketCopy`, and so through rule 1.
@Suite("Market vocabulary")
struct MarketVocabularyTests {
    /// Grown by the tasks that create the files (T010–T012, T009a).
    private static let copyFiles = ["Trove/Models/MarketCopy.swift"]
    private static let viewFiles: [String] = [
        "Trove/Views/Shared/TrendArrow.swift",
        "Trove/Views/Market/MarketSection.swift",
        "Trove/Views/Market/MarketNoticeView.swift",
        "Trove/Views/Market/MarketMatchView.swift",
    ]

    /// The two forms carrying the Year field (T009a). Kept apart from
    /// `viewFiles` on purpose — see `bothFormsReadTheYearFieldsCopyFromMarketCopy`.
    private static let yearFieldFiles = [
        "Trove/Views/Items/ItemFormView.swift",
        "Trove/Views/Wishlist/WishlistFormView.swift",
    ]

    /// "your value" covers "Your value" and "Set your value"; "as my value"
    /// covers the button that carries the amount ("Use $1,450 as my value")
    /// as well as the section's own "Use as my value", which it subsumes —
    /// the value step's names for the *person's* number (Amendment B, T021).
    /// Each is a whole phrase, never the bare word, so "value" anywhere else
    /// still fires.
    private static let allowedPhrases = ["asking prices", "asking price", "as my value", "your value", "refresh market values", "market values"]
    private static let forbidden = try! Regex(#"(?i)\b(value|values|valued|valuation|worth|price|prices|priced|sold)\b"#)

    /// Rule 1 as a pure function: strip the allowed phrases, then look for a
    /// forbidden word in what is left.
    ///
    /// The strip respects a word boundary at *both* ends, which a raw
    /// substring replace does not: "your value" heads "your values", so
    /// replacing it blindly left "refresh s" behind and the rule passed
    /// "Refresh your values", a literal that names the figure the person's
    /// values; "as my value" tails "has my value", so replacing it blindly
    /// left "trove h" and the rule passed "Trove has my value" too. A phrase
    /// is removed only where the character before it and the character after
    /// it are each a non-letter or the literal's edge; otherwise it stays,
    /// and the longer word it sits inside is matched whole.
    static func fires(_ literal: String) -> Bool {
        var stripped = literal.lowercased()
        for phrase in allowedPhrases { stripped = strip(phrase, from: stripped) }
        return stripped.contains(forbidden)
    }

    /// Every whole-phrase occurrence of `phrase` removed; occurrences that
    /// head or tail a longer word are left where they are, so the text around
    /// them is unchanged. Both boundaries are judged against `text` itself,
    /// never against what has been emitted so far — an earlier strip must not
    /// change what counts as a boundary later.
    private static func strip(_ phrase: String, from text: String) -> String {
        var output = ""
        var searchStart = text.startIndex
        while let found = text.range(of: phrase, range: searchStart..<text.endIndex) {
            output += text[searchStart..<found.lowerBound]
            let startsWord = found.lowerBound == text.startIndex
                || !text[text.index(before: found.lowerBound)].isLetter
            let after = found.upperBound
            let endsWord = after == text.endIndex || !text[after].isLetter
            if !(startsWord && endsWord) { output += text[found] }
            searchStart = after
        }
        return output + text[searchStart...]
    }

    @Test func theFetchedFigureIsNeverAValueAWorthOrAPrice() throws {
        try #require(!Self.copyFiles.isEmpty)
        var offenders: [String] = []
        for file in Self.copyFiles + Self.viewFiles {
            let code = try SourceScan.production(file)
            for literal in SourceScan.stringLiterals(in: code) where Self.fires(literal) {
                offenders.append("\(file): \"\(literal)\"")
            }
        }
        #expect(offenders.isEmpty, "the figure described as a value, worth or price:\n\(offenders.joined(separator: "\n"))")
    }

    /// The strip itself, over the shapes that distinguish a strip bounded at
    /// both ends from a raw substring replace: the bare word fires, an allowed
    /// phrase that only *heads* or only *tails* a forbidden word still fires,
    /// and the copy the value step actually ships passes.
    ///
    /// Two rows isolate the two boundaries. "Refresh your values" is the
    /// trailing one: a raw replace takes "your value" out of it and leaves
    /// "refresh s", which names nothing and passes. "Trove has my value" is
    /// the leading one: "as my value" is a suffix of "has my value", so a
    /// replace that checks only the character after leaves "trove h" and
    /// passes a literal that calls the figure the person's value. The
    /// repeated-phrase row runs the strip's loop more than once, so a strip
    /// that stopped after the first match would leave the second behind. The
    /// other rows hold under either strip — "valuation" reads "valu" +
    /// "ation" and never contains "value" at all, so it fires on the
    /// forbidden word directly.
    @Test(arguments: [
        ("value", true),
        ("your valuation", true),
        ("Refresh your values", true),
        ("Trove has my value", true),
        ("Use $1,450 as my value", false),
        ("Set your value", false),
        ("your value, your value", false),
        ("market value", true),
    ])
    func theAllowlistStripRespectsAWordBoundaryAtBothEnds(literal: String, shouldFire: Bool) {
        #expect(Self.fires(literal) == shouldFire, "\"\(literal)\" should \(shouldFire ? "fire" : "pass")")
    }

    @Test func theFramingIsInUse() throws {
        let code = try SourceScan.production("Trove/Models/MarketCopy.swift")
        #expect(code.ranges(of: "asking price").count >= 2, "the copy no longer says what the figure is")
        #expect(code.contains("\"On Reverb\""), "the source line is gone")
    }

    /// The Year field's wiring (002 Amendment A, T009a), scoped to that one
    /// field: the two form files are *not* in `viewFiles`, because they are
    /// ordinary forms full of legitimate copy — the no-space rule would fire
    /// on every placeholder they already carry. So this checks only what the
    /// year field is allowed to be: the label and the validation message come
    /// from `MarketCopy`, and neither form types the word itself.
    @Test func bothFormsReadTheYearFieldsCopyFromMarketCopy() throws {
        for file in Self.yearFieldFiles {
            let code = try SourceScan.production(file)
            #expect(code.contains("MarketCopy.yearLabel"), "\(file): the year label isn't wired")
            #expect(
                code.contains("MarketCopy.yearValidationError"),
                "\(file): the year validation message isn't wired"
            )

            let inlined = SourceScan.stringLiterals(in: code).filter {
                $0 == "Year" || $0.hasPrefix("Year should")
            }
            #expect(inlined.isEmpty, "\(file): the year copy is typed inline: \(inlined)")
        }
    }

    /// Rule 3: no string literal with a space in a Market view file —
    /// identifiers and symbol names have none, copy always does — so the
    /// views can't carry words this scan doesn't see. `Text(verbatim:)` copy
    /// is forbidden there on purpose.
    @Test func theMarketViewsCarryNoCopyOfTheirOwn() throws {
        var offenders: [String] = []
        for file in Self.viewFiles {
            let code = try SourceScan.production(file)
            for literal in SourceScan.stringLiterals(in: code) where literal.contains(" ") {
                offenders.append("\(file): \"\(literal)\"")
            }
        }
        #expect(offenders.isEmpty, "copy typed inline in a Market view:\n\(offenders.joined(separator: "\n"))")
    }
}

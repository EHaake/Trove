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
    private static let viewFiles: [String] = []

    /// The two forms carrying the Year field (T009a). Kept apart from
    /// `viewFiles` on purpose — see `bothFormsReadTheYearFieldsCopyFromMarketCopy`.
    private static let yearFieldFiles = [
        "Trove/Views/Items/ItemFormView.swift",
        "Trove/Views/Wishlist/WishlistFormView.swift",
    ]

    private static let allowedPhrases = ["asking prices", "asking price", "use as my value", "refresh market values", "market values"]
    private static let forbidden = try! Regex(#"(?i)\b(value|values|valued|valuation|worth|price|prices|priced|sold)\b"#)

    @Test func theFetchedFigureIsNeverAValueAWorthOrAPrice() throws {
        try #require(!Self.copyFiles.isEmpty)
        var offenders: [String] = []
        for file in Self.copyFiles + Self.viewFiles {
            let code = try SourceScan.production(file)
            for literal in SourceScan.stringLiterals(in: code) {
                var stripped = literal.lowercased()
                for phrase in Self.allowedPhrases { stripped = stripped.replacingOccurrences(of: phrase, with: "") }
                if stripped.contains(Self.forbidden) { offenders.append("\(file): \"\(literal)\"") }
            }
        }
        #expect(offenders.isEmpty, "the figure described as a value, worth or price:\n\(offenders.joined(separator: "\n"))")
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

import Foundation
import Testing
@testable import Trove

/// 021's guards G2–G4 (plan §2): the reader's grammar — prices with a
/// symbol, a space after it and thousands commas; slash dates read in one
/// order per file; `N/A` as an empty cell; the Trove ID parsed, not
/// compared. Every value here is invented.
struct ImportGrammarTests {
    // MARK: - G2: money (criteria 11 and 46)

    @Test func symbolsGroupsAndBareFormsReadToTheCent() {
        #expect(ImportSchema.cents(from: "$3,179.95") == 317_995)
        #expect(ImportSchema.cents(from: "€1,250") == 125_000)
        #expect(ImportSchema.cents(from: "£99.5") == 9_950)
        #expect(ImportSchema.cents(from: "¥500") == 50_000)
        #expect(ImportSchema.cents(from: "1,250.00") == 125_000)
        #expect(ImportSchema.cents(from: "500") == 50_000)
        #expect(ImportSchema.cents(from: "$0.00") == 0)
        #expect(ImportSchema.cents(from: "1,234,567.89") == 123_456_789)
    }

    /// Criterion 46 (spec Decision 22): spaces after the symbol are skipped.
    @Test func aSpaceAfterTheSymbolReads() {
        #expect(ImportSchema.cents(from: "$ 3,179.95") == 317_995)
        #expect(ImportSchema.cents(from: "€ 1,250") == 125_000)
        #expect(ImportSchema.cents(from: "$  5") == 500)
    }

    /// Criterion 11's unreadable list, and the shapes plan §2 adds to it:
    /// another grouping, a lone symbol, a symbol after the number, and a
    /// space with no symbol before it.
    @Test(arguments: ["1.250,00", "-5", "(5.00)", "1,25", "500 USD", "12,34,567",
                      "$", "5$", "5 $", "1 250", "1,2345", ",500", "1,", "$$5", "$-5"])
    func otherPriceShapesAreUnreadable(field: String) {
        #expect(ImportSchema.cents(from: field) == nil)
    }

    @Test(arguments: [0, 1, 999, 10_000, 123_456_789, 999_999_999_99])
    func exportedMoneyStillReadsBack(cents: Int) {
        #expect(ImportSchema.cents(from: ExportSchema.money(cents: cents)) == cents)
    }

    // MARK: - G3: dates (criteria 12 and 13)

    @Test func isoReadsAsBeforeWithAndWithoutAnOrder() {
        let expected = date(2026, 3, 9)
        #expect(ImportSchema.day(from: "2026-03-09", timeZone: utc) == expected)
        #expect(ImportSchema.day(from: "2026-03-09", timeZone: utc, order: .monthFirst) == expected)
        #expect(ImportSchema.day(from: "2026-03-09", timeZone: utc, order: .dayFirst) == expected)
    }

    @Test func aSlashDateWithNoOrderIsUnreadable() {
        #expect(ImportSchema.day(from: "5/1/2025", timeZone: utc) == nil)
    }

    /// The file decides, against a region that would say the opposite.
    @Test func aDateAboveTwelveInTheSecondPlaceSettlesMonthFirstForTheWholeFile() {
        let file = ["12/28/2025", "5/1/2025"]
        let decided = ImportSchema.slashDateOrder(in: file, region: enGB)
        #expect(decided.order == .monthFirst)
        #expect(!decided.regionDecided)
        #expect(ImportSchema.day(from: "12/28/2025", timeZone: utc, order: decided.order) == date(2025, 12, 28))
        #expect(ImportSchema.day(from: "5/1/2025", timeZone: utc, order: decided.order) == date(2025, 5, 1))
    }

    @Test func aDateAboveTwelveInTheFirstPlaceSettlesDayFirstForTheWholeFile() {
        let file = ["28/12/2025", "1/5/2025"]
        let decided = ImportSchema.slashDateOrder(in: file, region: enUS)
        #expect(decided.order == .dayFirst)
        #expect(!decided.regionDecided)
        #expect(ImportSchema.day(from: "28/12/2025", timeZone: utc, order: decided.order) == date(2025, 12, 28))
        #expect(ImportSchema.day(from: "1/5/2025", timeZone: utc, order: decided.order) == date(2025, 5, 1))
    }

    @Test func aFileThatDoesNotSettleTheOrderTakesTheRegionsAndSaysSo() {
        let us = ImportSchema.slashDateOrder(in: ["5/1/2025", "2026-01-15", ""], region: enUS)
        #expect(us.order == .monthFirst)
        #expect(us.regionDecided)
        #expect(ImportSchema.day(from: "5/1/2025", timeZone: utc, order: us.order) == date(2025, 5, 1))

        let gb = ImportSchema.slashDateOrder(in: ["5/1/2025", "2026-01-15", ""], region: enGB)
        #expect(gb.order == .dayFirst)
        #expect(gb.regionDecided)
        #expect(ImportSchema.day(from: "5/1/2025", timeZone: utc, order: gb.order) == date(2025, 1, 5))
    }

    /// A contradiction: the region decides, and the date that doesn't fit
    /// its order is unreadable.
    @Test func aFileThatContradictsItselfTakesTheRegionsOrder() {
        let file = ["12/28/2025", "28/12/2025"]

        let us = ImportSchema.slashDateOrder(in: file, region: enUS)
        #expect(us.order == .monthFirst)
        #expect(us.regionDecided)
        #expect(ImportSchema.day(from: "12/28/2025", timeZone: utc, order: us.order) == date(2025, 12, 28))
        #expect(ImportSchema.day(from: "28/12/2025", timeZone: utc, order: us.order) == nil)

        let gb = ImportSchema.slashDateOrder(in: file, region: enGB)
        #expect(gb.order == .dayFirst)
        #expect(gb.regionDecided)
        #expect(ImportSchema.day(from: "28/12/2025", timeZone: utc, order: gb.order) == date(2025, 12, 28))
        #expect(ImportSchema.day(from: "12/28/2025", timeZone: utc, order: gb.order) == nil)
    }

    @Test func aFileOfIsoDatesReportsNoRegionDecision() {
        let decided = ImportSchema.slashDateOrder(in: ["2026-01-15", "2025-12-28", ""], region: enGB)
        #expect(!decided.regionDecided)
    }

    @Test(arguments: ["3/9/26", "2/30/2025", "13/13/2025", "3-9-2026", "3.9.2026", "003/9/2026", "3/9/02026"])
    func otherSlashShapesAndImpossibleDatesAreUnreadable(field: String) {
        #expect(ImportSchema.day(from: field, timeZone: utc, order: .monthFirst) == nil)
        #expect(ImportSchema.day(from: field, timeZone: utc, order: .dayFirst) == nil)
    }

    @Test func theRegionsOrderComesFromItsOwnDatePattern() throws {
        #expect(SlashDateOrder.regional(for: enUS) == .monthFirst)
        #expect(SlashDateOrder.regional(for: enGB) == .dayFirst)
        #expect(SlashDateOrder.regional(for: Locale(identifier: "de_DE")) == .dayFirst)
        #expect(SlashDateOrder.regional(for: Locale(identifier: "ja_JP")) == .monthFirst)
    }

    // MARK: - G4: blank cells and the Trove ID (criterion 14; P6)

    @Test(arguments: ["", "   ", "N/A", "n/a", " #N/A ", "#n/a", "N/a"])
    func notApplicableIsBlank(field: String) {
        #expect(ImportSchema.isBlank(field))
    }

    @Test(arguments: ["NA", "none", "-", "N/A/", "#N/A!", "n / a"])
    func otherPlaceholdersAreNotBlank(field: String) {
        #expect(!ImportSchema.isBlank(field))
    }

    @Test func aCodeReadsInAnyLetterCaseAndWithSpacesAround() throws {
        let id = try #require(UUID(uuidString: "3F2B8C1D-7A4E-4F60-9B2D-5E8A1C7D0F93"))
        #expect(ImportSchema.troveID(from: "3F2B8C1D-7A4E-4F60-9B2D-5E8A1C7D0F93") == .value(id))
        #expect(ImportSchema.troveID(from: "3f2b8c1d-7a4e-4f60-9b2d-5e8a1c7d0f93") == .value(id))
        #expect(ImportSchema.troveID(from: "  3F2B8C1D-7A4E-4F60-9B2D-5E8A1C7D0F93 ") == .value(id))
    }

    @Test func aCodeThatIsNotOneIsUnreadableAndABlankIsEmpty() {
        #expect(ImportSchema.troveID(from: "abc") == .unreadable)
        #expect(ImportSchema.troveID(from: "3F2B8C1D-7A4E-4F60-9B2D-5E8A1C7D0F9") == .unreadable)
        #expect(ImportSchema.troveID(from: "") == .empty)
        #expect(ImportSchema.troveID(from: "  ") == .empty)
        #expect(ImportSchema.troveID(from: "N/A") == .empty)
    }

    // MARK: - Fixtures

    private let utc = TimeZone(identifier: "UTC")!
    private let enUS = Locale(identifier: "en_US")
    private let enGB = Locale(identifier: "en_GB")

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

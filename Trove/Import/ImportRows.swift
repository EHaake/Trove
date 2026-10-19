import Foundation

/// One cell, read. `empty` covers a blank cell, an N/A, and a column the file
/// does not have — the spec's three ways of saying nothing (021, plan §2).
nonisolated enum Cell<Value: Sendable & Equatable>: Sendable, Equatable {
    case empty, unreadable, value(Value)
}

/// The order a slash date's first two numbers are read in (021, plan §2;
/// spec Decision 6). One order per file: `ImportSchema.slashDateOrder(in:region:)`
/// decides it from the file's own dates, and the phone's region only when
/// the file can't.
nonisolated enum SlashDateOrder: Sendable, Equatable {
    case monthFirst, dayFirst

    /// The phone's region: day-first iff "d" comes before "M" in the locale's
    /// own "yMd" pattern (en_US M/d/y, en_GB dd/MM/y, ja_JP y/M/d → month-first).
    static func regional(for locale: Locale) -> SlashDateOrder {
        let pattern = DateFormatter.dateFormat(fromTemplate: "yMd", options: 0, locale: locale) ?? ""
        guard
            let day = pattern.firstIndex(of: "d"),
            let month = pattern.firstIndex(of: "M")
        else { return .monthFirst }
        return day < month ? .dayFirst : .monthFirst
    }
}

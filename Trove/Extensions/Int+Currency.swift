import Foundation

enum Currency {
    /// The currency symbol on its own.
    ///
    /// Derived by formatting zero and dropping everything numeric, rather than
    /// read off the locale: `Locale.currencySymbol` only answers for the
    /// locale's *own* currency, which would quietly return "$" for any code
    /// once the multi-currency groundwork in the schema gets used.
    static func symbol(for currencyCode: String) -> String {
        let zero = 0.formattedAsWholeCurrency(currencyCode: currencyCode)
        let stripped = zero.filter { !$0.isNumber && !$0.isWhitespace && $0 != "." && $0 != "," }
        return stripped.isEmpty ? currencyCode : stripped
    }
}

// `nonisolated` explicitly (011/T006): `PDFComposer` draws the cover totals
// with these same display formatters off the main actor — one source of money
// display keeps the PDF's figures rendered the way every screen renders them
// — and the project's MainActor default would otherwise forbid the call.
// Pure formatting; nothing here needs an actor.
nonisolated extension Int {
    /// Formats this value, interpreted as minor currency units (cents), as a
    /// localized currency string — e.g. `129_900` with `"USD"` formats as
    /// `"$1,299.00"`. Every money field in the schema is stored this way; see
    /// plan.md's "Money" section.
    ///
    /// Locale is pinned to `en_US` rather than the device's own, since v1 is
    /// USD-only with no currency picker (spec.md's resolved decision) — this
    /// keeps formatting consistent regardless of the device's region setting,
    /// rather than silently reformatting for a user who hasn't asked for
    /// anything but USD.
    func formattedAsCurrency(currencyCode: String) -> String {
        let amount = Decimal(self) / 100
        return amount.formatted(.currency(code: currencyCode).locale(Locale(identifier: "en_US")))
    }

    /// The same figure without cents, which is how every money value is drawn
    /// in `design/screens/` — "$3,450", never "$3,450.00".
    ///
    /// Not only a style choice: at these magnitudes the cents are noise, and
    /// they cost enough width to wrap a list row onto two lines.
    func formattedAsWholeCurrency(currencyCode: String) -> String {
        let amount = Decimal(self) / 100
        return amount.formatted(
            .currency(code: currencyCode)
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "en_US"))
        )
    }

    /// Grouped whole units with no currency symbol at all — for the
    /// dashboard's total, where Design draws the symbol separately at a
    /// smaller size and raised, so it can't come baked into the digits.
    var formattedAsWholeAmount: String {
        (abs(self) / 100).formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
    }

    /// A signed whole amount *with* the symbol — the dashboard's GAIN reads
    /// "+$1,515", where an item row's delta reads "+550 vs paid". Different
    /// enough to need both, close enough to be worth saying why.
    func formattedAsSignedWholeCurrency(currencyCode: String) -> String {
        let magnitude = abs(self).formattedAsWholeCurrency(currencyCode: currencyCode)
        return "\(self < 0 ? "−" : "+")\(magnitude)"
    }

    /// A signed whole-dollar difference with no currency symbol, as Design
    /// writes it beside a value: "+550 vs paid", "−150 vs paid". Uses a real
    /// minus sign rather than a hyphen.
    var formattedAsSignedWholeAmount: String {
        let whole = abs(self) / 100
        let magnitude = whole.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
        return "\(self < 0 ? "−" : "+")\(magnitude)"
    }
}

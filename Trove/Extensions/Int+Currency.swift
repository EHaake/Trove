import Foundation

extension Int {
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
}

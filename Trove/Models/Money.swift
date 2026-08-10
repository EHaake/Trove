import Foundation

/// Converting between what a user types and what the schema stores.
///
/// Every money field in the model is `Int` minor units (plan.md's "Money"
/// section); every form holds a `Decimal`, because that's what someone typing
/// "1299.00" produces. This is the one boundary between the two, shared by the
/// item and wishlist forms so a price and an estimated cost can't round
/// differently.
enum Money {
    /// Rounds to the nearest cent rather than truncating, so a stray third
    /// decimal doesn't quietly lose the user a penny.
    static func cents(from amount: Decimal) -> Int {
        var scaled = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    static func amount(fromCents cents: Int) -> Decimal {
        Decimal(cents) / 100
    }
}

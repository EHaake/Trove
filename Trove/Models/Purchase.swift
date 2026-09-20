import Foundation

/// The four fields a purchase is entered with, read and written as one value.
///
/// The shape `Sale` has in `Trove/Models/Sale.swift`, with one deliberate
/// difference (plan Q2): there is no `Item.purchase` accessor pair. Unlike a
/// sale, these are not a nullable group on an existing row — the price, the
/// date and the place are three columns an `Item` always has, plus its
/// condition — so there is no "a date without a price is not a purchase"
/// hazard for an accessor to hide.
nonisolated struct Purchase: Sendable, Equatable {
    var date: Date
    var priceCents: Int
    var location: String?
    var condition: Condition
}

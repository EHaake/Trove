import Foundation

/// The one definition of what a blank field is — shared by the two form
/// view models and the import pipeline, so an imported cell and a
/// hand-typed field can never normalize differently (012 plan §Row
/// pipeline; the spec's amended trimming rule: "blank" means empty after
/// trimming).
///
/// Extracted from the forms' private statics at 012/T005 rather than
/// reused in place: those statics are `private`, and under the
/// project-wide MainActor default they're MainActor-isolated too — import
/// validation runs off the main actor and pure string trimming has no
/// isolation to need. Both form view models now delegate here; this is
/// the same one-definition extraction the plan prescribes for
/// `CategoryPathHelper.canonicalize`.
nonisolated enum FieldNormalization {
    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Optional-in-the-model fields: whitespace-only means nil.
    static func nilIfBlank(_ value: String) -> String? {
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// P18's lower bound on a year, here for the reason `trimmed(_:)` is
    /// here: the two form view models and the import pipeline all apply it,
    /// and a hand-typed year and an imported cell must not be able to
    /// disagree about the range. Only the lower bound is shared — the upper
    /// one moves with the calendar, and each caller reads a clock of its own
    /// (the forms `Calendar.current`, `ImportSchema.year(from:)` the time
    /// zone and instant it is handed).
    static let earliestYear = 1900
}

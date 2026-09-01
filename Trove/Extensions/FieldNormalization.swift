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
}

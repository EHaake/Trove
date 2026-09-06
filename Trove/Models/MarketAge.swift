import Foundation

/// "2 hours ago", by hand (plan §6): a whole-string copy test over
/// `Date.RelativeFormatStyle` would pin ICU's wording ("2 hr. ago") rather
/// than the spec's, and Foundation has no "just now". Minutes, hours, days
/// — past thirty days the figure is stale and the section says so, so the
/// age never needs weeks. A date in the future (clock skew) reads as now.
nonisolated enum MarketAge {
    static func description(of fetchedAt: Date, at now: Date) -> String {
        let seconds = now.timeIntervalSince(fetchedAt)
        guard seconds >= 60 else { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return unit(minutes, "minute") }
        let hours = minutes / 60
        if hours < 24 { return unit(hours, "hour") }
        return unit(hours / 24, "day")
    }

    private static func unit(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s") ago"
    }
}

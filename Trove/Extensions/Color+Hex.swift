import SwiftUI

extension Color {
    /// Builds a color from a `#RRGGBB` design token, optionally at reduced
    /// opacity — several tokens in `design/tokens.md` are defined as a
    /// percentage of the base ivory rather than as their own hex value.
    ///
    /// Intended for `ThemeColors` and nothing else; views read named tokens.
    init(hex: String, opacity: Double = 1) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        assert(digits.count == 6, "Design tokens are 6-digit hex (RRGGBB); got \(hex)")

        let value = UInt64(digits, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: opacity
        )
    }
}

import SwiftUI

extension Color {
    /// Builds a color from a `#RRGGBB` design token, optionally at reduced
    /// opacity — several tokens in `design/tokens.md` are defined as a
    /// percentage of the base ivory rather than as their own hex value.
    ///
    /// Intended for `ThemeColors` and nothing else; views read named tokens.
    ///
    /// A malformed token is a programmer error, not user input: every caller
    /// passes a literal from one file. It trips `assertionFailure` in debug
    /// and falls back to black in release. **Deliberately not a
    /// `precondition`** — a token typo that reached a shipped build would
    /// crash the app at first render, which is worse for the person holding
    /// the phone than one wrong swatch. The loud failure belongs at test
    /// time, which is what `rgbComponents(hex:)` below is separated out for.
    init(hex: String, opacity: Double = 1) {
        guard let rgb = Color.rgbComponents(hex: hex) else {
            assertionFailure("Design tokens are 6-digit hex (RRGGBB); got \(hex)")
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: opacity)
            return
        }
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: opacity)
    }

    /// The token parse on its own, returning `nil` rather than a color, so the
    /// failure is observable without a `Color` to inspect and without tripping
    /// the assertion above — `ColorHexTests` is the whole reason it is a
    /// separate function.
    ///
    /// Stricter than the check it replaces, which compared only the digit
    /// *count*: `#GGGGGG` is six characters, so it passed the old assertion,
    /// failed `UInt64(_:radix:)`, and rendered as black through a `?? 0`
    /// fallback — silently, in debug as well as release. Validity is now part
    /// of the same answer as length.
    ///
    /// The three conditions below were mutation-tested rather than assumed,
    /// and they do not carry equal weight:
    /// - `count == 6` and `UInt64(_:radix:)` each redden a test when removed.
    /// - `isHexDigit` earns its line on exactly one case: `UInt64` accepts a
    ///   leading sign, so `"+804A0"` is six characters that parse cleanly to
    ///   `0x804A0` and would slide every channel. Dropping it reddens
    ///   `aSignedTokenOfTheRightLengthIsRefused`.
    /// - `isASCII` is **inert** — dropping it leaves the suite green, because
    ///   `UInt64(_:radix:)` already refuses full-width digits. Kept as cheap
    ///   insurance against that changing, and said here so it does not read
    ///   as load-bearing (the `003` `layoutPriority(1)` precedent).
    nonisolated static func rgbComponents(
        hex: String
    ) -> (red: Double, green: Double, blue: Double)? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6,
              digits.allSatisfy({ $0.isASCII && $0.isHexDigit }),
              let value = UInt64(digits, radix: 16)
        else { return nil }

        return (
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

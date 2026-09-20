import Foundation
import SwiftUI
import Testing
@testable import Trove

/// `Color(hex:)` had no test at all, and the gap hid a real defect: its
/// `assert` compared the digit *count* and nothing else, so a token like
/// `#GGGGGG` passed the check, failed `UInt64(_:radix:)`, and came out black
/// through a `?? 0` fallback — in debug as well as release, with nothing said.
///
/// The parse is now `Color.rgbComponents(hex:)`, returning `nil` instead of a
/// color, which is what makes the failure assertable here without tripping the
/// initializer's assertion. These tests are on that function rather than on
/// `Color(hex:)`, deliberately: a test that drove a malformed token through
/// the initializer could only fail by trapping, which is the shape `CLAUDE.md`
/// records as having been deleted once already.
///
/// Complements `ThemeColorTokenTests`, which pins the channel values of the
/// tokens themselves. This pins what the parser does with input that is not a
/// token.
@Suite("Color hex parsing")
struct ColorHexTests {

    // MARK: - What it accepts

    @Test func aSixDigitTokenParsesToItsThreeChannels() throws {
        let rgb = try #require(Color.rgbComponents(hex: "#804A00"))
        #expect(Int((rgb.red * 255).rounded()) == 0x80)
        #expect(Int((rgb.green * 255).rounded()) == 0x4A)
        #expect(Int((rgb.blue * 255).rounded()) == 0x00)
    }

    @Test func theLeadingHashIsOptional() throws {
        let withHash = try #require(Color.rgbComponents(hex: "#ECE7DC"))
        let without = try #require(Color.rgbComponents(hex: "ECE7DC"))
        #expect(withHash == without)
    }

    @Test func casingDoesNotMatter() throws {
        let upper = try #require(Color.rgbComponents(hex: "#DDB877"))
        let lower = try #require(Color.rgbComponents(hex: "#ddb877"))
        #expect(upper == lower)
    }

    @Test func theChannelRangeRunsFromZeroToOne() throws {
        let black = try #require(Color.rgbComponents(hex: "#000000"))
        #expect(black == (red: 0, green: 0, blue: 0))

        let white = try #require(Color.rgbComponents(hex: "#FFFFFF"))
        #expect(white == (red: 1, green: 1, blue: 1))
    }

    /// The channels are independent — a parser that read the same byte three
    /// times, or shifted the wrong way, passes every symmetric token above.
    @Test func theChannelsAreNotInterchangeable() throws {
        let rgb = try #require(Color.rgbComponents(hex: "#FF0000"))
        #expect(rgb.red == 1)
        #expect(rgb.green == 0)
        #expect(rgb.blue == 0)
    }

    // MARK: - What it refuses

    /// The defect this file exists for. Six characters, so the old
    /// count-only assertion was satisfied; not hex, so the value fell back to
    /// zero and rendered black.
    @Test func sixNonHexCharactersAreRefusedRatherThanRenderedBlack() {
        #expect(Color.rgbComponents(hex: "#GGGGGG") == nil)
        #expect(Color.rgbComponents(hex: "#12345Z") == nil)
    }

    @Test func theWrongNumberOfDigitsIsRefused() {
        #expect(Color.rgbComponents(hex: "#FFF") == nil)
        #expect(Color.rgbComponents(hex: "#FFFFF") == nil)
        #expect(Color.rgbComponents(hex: "#FFFFFFF") == nil)
        #expect(Color.rgbComponents(hex: "#FFFFFFFF") == nil)
    }

    @Test func emptyAndPunctuationOnlyInputIsRefused() {
        #expect(Color.rgbComponents(hex: "") == nil)
        #expect(Color.rgbComponents(hex: "#") == nil)
    }

    /// The one case the length check cannot reach, and the only reason the
    /// `allSatisfy` validity check earns its line.
    ///
    /// `UInt64(_:radix:)` accepts a leading sign, so `"+804A0"` is six
    /// characters that parse cleanly to `0x804A0` — a token the old
    /// count-only assertion and a length-plus-`UInt64` guard would both wave
    /// through, silently sliding every channel. Found by mutation: removing
    /// the validity check left the suite green until this case was written
    /// with six characters instead of seven.
    @Test func aSignedTokenOfTheRightLengthIsRefused() {
        #expect(Color.rgbComponents(hex: "+804A0") == nil)
        #expect(Color.rgbComponents(hex: "-804A0") == nil)
    }

    /// Pins behaviour this parser depends on rather than behaviour it
    /// implements: `isASCII` was mutation-tested and found inert, because
    /// `UInt64(_:radix:)` refuses full-width digits on its own. Kept as a
    /// regression pin on that, and labelled so nobody later reads it as a
    /// guard over our own check — no mutation of this file turns it red.
    @Test func nonASCIIDigitsAreRefused() {
        #expect(Color.rgbComponents(hex: "#８０４Ａ００") == nil)
    }

    @Test func surroundingWhitespaceIsNotTrimmedAway() {
        // Not a trimming function: a token with a stray space is malformed,
        // and quietly accepting it would hide the typo the assertion is for.
        #expect(Color.rgbComponents(hex: " #804A00") == nil)
        #expect(Color.rgbComponents(hex: "#804A00 ") == nil)
    }
}

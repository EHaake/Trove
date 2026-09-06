import SwiftUI

/// The two button treatments the market surfaces share, from `tokens.md`'s
/// button rule: **filled brass** writes the person's own data, **outlined
/// brass** fetches or steps back.
///
/// Built by `MarketSection` at T010 as two private helpers; lifted here at
/// T011 when the notice sheet needed the same pair. They are `ViewModifier`s
/// rather than wrapper views so the label keeps its own font and the
/// caller's `Button` keeps its own hit target, exactly as the section's
/// versions worked — and so `MarketSection` could adopt them without any
/// call site changing.
///
/// No copy lives here: a chrome has no words.
enum MarketButtons {
    /// The app's tap target, and the section's button height.
    static let hitHeight: CGFloat = 44

    /// The notice's two buttons stand taller (the `PickerNotice` artboard):
    /// they are the only thing in a sheet whose whole job is that choice.
    static let noticeHeight: CGFloat = 48
}

/// `accentBrass` fill, `background` ink, the button radius, grown to the
/// row. The label brings its own font.
struct MarketFilledChrome: ViewModifier {
    var minHeight: CGFloat = MarketButtons.hitHeight

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(theme.colors.background)
            .padding(.horizontal, theme.metrics.cardPadding)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                    .fill(theme.colors.accentBrass)
            )
    }
}

/// A hairline brass border and brass ink. `fills` is the artboards' `flex`:
/// the button hugs its label when something sits beside it and grows to the
/// row when it stands alone.
struct MarketOutlinedChrome: ViewModifier {
    var fills: Bool
    var minHeight: CGFloat = MarketButtons.hitHeight
    var ink: Color?
    var border: Color?

    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(ink ?? theme.colors.accentBrass)
            .padding(.horizontal, theme.metrics.cardPadding)
            .frame(maxWidth: fills ? .infinity : nil, minHeight: minHeight)
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                    .strokeBorder(border ?? theme.colors.accentBrass, lineWidth: theme.metrics.hairline)
            )
            // An outline leaves the interior transparent, and a transparent
            // interior isn't hit-testable — the lesson `findItemsToSell`
            // records on the wishlist screen.
            .contentShape(Rectangle())
    }
}

extension View {
    func marketFilledChrome(minHeight: CGFloat = MarketButtons.hitHeight) -> some View {
        modifier(MarketFilledChrome(minHeight: minHeight))
    }

    func marketOutlinedChrome(
        fills: Bool,
        minHeight: CGFloat = MarketButtons.hitHeight,
        ink: Color? = nil,
        border: Color? = nil
    ) -> some View {
        modifier(MarketOutlinedChrome(fills: fills, minHeight: minHeight, ink: ink, border: border))
    }
}

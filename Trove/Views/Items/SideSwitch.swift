import SwiftUI

/// The Items tab's Owned / Sold switch — spec `006` Decision 9's "two sides of
/// the same view", one tap apart, per the Design pass's artboards
/// (`design/elements/006-mark-as-sold/SwitchOwned` and `SwitchSold`).
///
/// A bespoke in-page control rather than a system `Picker`, under `013`'s
/// standing rule (system in the bars, bespoke in the page): it is drawn in the
/// Sort By badge's family — a `hairline` brass border at the button radius,
/// two equal mono halves, the active one filled brass with the page's own ink
/// as its letters.
///
/// **It never writes the side.** `ItemListViewModel.side` is `private(set)`
/// because changing sides also clears every narrowing (plan Q15), so this
/// control reports a tap through `select` and the view model decides what that
/// means. A `Binding` here would let a future call site skip the clearing,
/// which is exactly the bug Q15 was added to prevent.
///
/// VoiceOver (criterion 16) gets the pair as a labelled container whose value
/// is the side showing, with `.isSelected` on the active half — the chips'
/// own treatment in `ItemListView`, so "which side am I on" is announced the
/// same way "which filter is on" already is.
struct SideSwitch: View {
    let side: ItemListViewModel.Side

    /// What a tapped half asks for. Called even for the half already showing:
    /// `show(_:)` treats that as "reload this side", not as a change.
    let select: (ItemListViewModel.Side) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The Design pass's measurements: two 62 pt halves, no seam between
    /// them, at the badges' own 32 pt height.
    private static let halfWidth: CGFloat = 62
    private static let height: CGFloat = 32

    /// How long the fill takes to cross, in seconds — spec Decision 13's
    /// "fast and smooth", and the rate every other in-page control in the
    /// app already moves at (`DesireDial`, `DesireGauge` and `PhotoCarousel`
    /// are all `.snappy(duration: 0.2)`; 0.25 s is the floating dropdown's,
    /// which travels much further). Named rather than typed twice so the
    /// Reduce Motion arm can't drift from the travelling one, and pinned by
    /// `ItemListSidesWiringTests`.
    static let slideDuration: TimeInterval = 0.2

    var body: some View {
        HStack(spacing: 0) {
            half(.owned, label: SaleCopy.owned)
            half(.sold, label: SaleCopy.sold)
        }
        // One rectangle that moves, rather than one per half appearing and
        // disappearing — see the note on the animation below for why the
        // second shape never actually slid.
        .background(alignment: .leading) {
            Rectangle()
                .fill(theme.colors.accentBrass)
                .frame(width: Self.halfWidth, height: Self.height)
                .offset(x: side == .owned ? 0 : Self.halfWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                .strokeBorder(theme.colors.accentBrass, lineWidth: theme.metrics.hairline)
        )
        // Scoped to this control with `.animation(_:value:)`, never
        // `withAnimation` around the view model's write — the rows reload in
        // the same instant, and tweening those is the `DropdownHost` lesson
        // (T029c) from the other direction. Reduce Motion keeps the change,
        // drops the travel.
        //
        // T018b measured this rather than reasoned about it (the T056 rule):
        // `simctl io recordVideo` through a tap, brass-masked column profile
        // per frame. Two things came out of it, and neither was the `List`
        // swapping its whole row set on the same update — that costs the
        // slide nothing.
        //
        // One: the fill used to be a `Rectangle` in each half's `.background`
        // paired by `matchedGeometryEffect`, and it never slid. Inserting one
        // view and removing another is a *structural* change, which this
        // modifier does not cover — it animates the animatable data of the
        // subtree it is on. So the two halves cross-faded, the whole control
        // dimming to 22 % of its brightness halfway across, which is what
        // "stutters at a low frame rate" looks like from the outside. A
        // literal `.easeInOut(duration: 2.0)` here changed the timing not at
        // all, which is how the inertness was proved rather than argued. One
        // rectangle with an animatable `.offset` is covered, and measures as
        // a real slide.
        //
        // Two: the control itself used to travel 19.7 pt upward at the same
        // time, because the Sold side's header line vanished at zero sales.
        // Spec Decision 13 fixed that by keeping the line, not here.
        .animation(
            reduceMotion
                ? .easeInOut(duration: Self.slideDuration)
                : .snappy(duration: Self.slideDuration),
            value: side
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Owned or sold")
        .accessibilityValue(side == .owned ? SaleCopy.owned : SaleCopy.sold)
        .accessibilityIdentifier("items.sideSwitch")
    }

    private func half(_ half: ItemListViewModel.Side, label: String) -> some View {
        let isActive = half == side

        return Button {
            select(half)
        } label: {
            Text(label)
                // 11 pt mono, the badges' label size; the active half lifts to
                // 500 so the filled word doesn't read lighter than the hollow
                // one it sits beside.
                .font(ThemeTypography.font(.mono, size: 11, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? theme.colors.background : theme.colors.accentBrass)
                .frame(width: Self.halfWidth, height: Self.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(alignment: .leading, spacing: 24) {
            SideSwitch(side: .owned, select: { _ in })
            SideSwitch(side: .sold, select: { _ in })
        }
        .padding(24)
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}

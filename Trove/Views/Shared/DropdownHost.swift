import SwiftUI

/// Closes the open in-page dropdown (013 Amendment A). Injected by the
/// screen-level host on the dropdown it shows; read by `DropdownRow` before
/// every action and by `DropdownSurface`'s escape gesture.
///
/// The default is loud on purpose: a row composed outside a host would
/// otherwise never close, with every wiring guard still green — the exact
/// shape of failure this project keeps finding in its own tests.
struct DismissDropdownAction {
    let run: () -> Void

    func callAsFunction() {
        run()
    }
}

extension EnvironmentValues {
    @Entry var dismissDropdown = DismissDropdownAction {
        assertionFailure("DropdownRow used outside a dropdownHost — nothing will close this dropdown")
    }
}

// MARK: - Anchors

/// The bounds of every badge that can open a dropdown, keyed by the screen's
/// own menu identifier and published up to the screen-level host. Anchors
/// are resolved lazily in the host's overlay, so a badge inside a scrolling
/// header is found where it currently is — no geometry is ever written into
/// state, which is what keeps this free of layout cycles.
struct DropdownAnchorKey: PreferenceKey {
    static let defaultValue: [AnyHashable: Anchor<CGRect>] = [:]

    static func reduce(value: inout [AnyHashable: Anchor<CGRect>], nextValue: () -> [AnyHashable: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Tags a badge as the thing the dropdown with this identifier positions
    /// against.
    func dropdownAnchor<ID: Hashable>(_ id: ID) -> some View {
        anchorPreference(key: DropdownAnchorKey.self, value: .bounds) { [AnyHashable(id): $0] }
    }

    /// The screen-level host for a screen's in-page dropdowns: one open at a
    /// time (the binding is a single optional), floated over the whole screen
    /// against the badge tagged with the open identifier, a labelled
    /// tap-outside layer beneath it. Replaces `010`'s per-screen overlay and
    /// its fixed offset with one mechanism for every screen, including the
    /// Dashboard, whose header scrolls.
    ///
    /// Attach it after the screen's other overlays — the add button's above
    /// all — so the dropdown draws above them. Presentations (sheets, alerts)
    /// don't take part in z-order, so their position in the chain is moot.
    func dropdownHost<ID: Hashable, Dropdown: View>(
        open: Binding<ID?>,
        dismissLabel: @escaping (ID) -> String,
        @ViewBuilder content: @escaping (ID) -> Dropdown
    ) -> some View {
        modifier(DropdownHost(open: open, dismissLabel: dismissLabel, content: content))
    }
}

// MARK: - The host

private struct DropdownHost<ID: Hashable, Dropdown: View>: ViewModifier {
    @Binding var open: ID?
    let dismissLabel: (ID) -> String
    let content: (ID) -> Dropdown

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Open on the app's snappy spring, close on a shorter ease-out (spec
    /// Decision 20). Scoped to the overlay with `.animation(_:value:)`,
    /// never `withAnimation` around the screens' writes: the sort badge's
    /// label changes in the same instant a row is chosen, and animating
    /// that write would tween its border against a snapping label — the
    /// T029c tear, from the other direction.
    private var animation: Animation {
        open == nil ? .easeOut(duration: 0.15) : .snappy(duration: 0.25)
    }

    /// Grows out of the badge — a scale from the badge's trailing edge with
    /// a fade — or, under Reduce Motion, the fade alone.
    private func transition(growingFrom anchor: UnitPoint) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.92, anchor: anchor).combined(with: .opacity)
    }

    func body(content host: Content) -> some View {
        host.overlayPreferenceValue(DropdownAnchorKey.self, alignment: .topLeading) { anchors in
            // The reader stays inside the safe area on purpose: its bounds
            // then end where the tab bar begins and start under the status
            // bar, which is what the flip-above rule needs. A reader that
            // ignored the safe area reported zero insets on iOS 26 (T020's
            // probe), so "read the ignored insets back" is not a mechanism
            // this host can lean on. Only the catcher reaches the screen's
            // edges. Always present — empty at rest, so nothing to hit —
            // because the transition below runs only on the view the
            // conditional itself inserts, and that view needs the reader's
            // geometry for its anchor (T024a: a transition nested inside
            // the inserted view never ran; a recording showed a step).
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    if let id = open, let anchor = anchors[AnyHashable(id)] {
                        let badge = proxy[anchor]
                        let region = CGRect(origin: .zero, size: proxy.size)
                        dropdown(id, badge: badge, region: region)
                            // The inserted view fills the region, so a scale
                            // anchored at the badge's edge as a point of the
                            // region scales the placed dropdown about that
                            // edge — below or flipped above alike, no flip
                            // knowledge needed. The catcher scales with it,
                            // invisibly.
                            .transition(transition(growingFrom: DropdownPlacement.growthAnchor(badge: badge, region: region)))
                    }
                }
                .animation(animation, value: open)
            }
        }
    }

    /// The open dropdown and its tap-outside layer, in the reader's space.
    private func dropdown(_ id: ID, badge: CGRect, region: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            // The tap-outside layer. It covers the badges too — that is what
            // makes "tapping the open badge closes it" true, exactly as
            // T035's catcher did, and why switching menus takes two taps
            // (spec Decision 19). A real tap target, so VoiceOver calls it
            // what it is (T039 review, finding 13), with an explicit action
            // so activation never synthesizes a centre tap that could land
            // on the plate.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityLabel(dismissLabel(id))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { close() }
                .accessibilitySortPriority(-1)

            DropdownPlacementLayout(
                badge: badge,
                region: region,
                gutter: theme.metrics.screenGutter,
                gap: theme.metrics.dropdownGap
            ) {
                self.content(id)
                    // The one place the dismiss action is real.
                    .environment(\.dismissDropdown, DismissDropdownAction { close() })
            }
        }
        // VoiceOver stays inside the dropdown and its catcher; the badges,
        // rows and fields behind are unreachable until it closes. The
        // escape gesture closes it.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
    }

    private func close() {
        open = nil
    }
}

// MARK: - Placement

/// Where a dropdown goes, as a pure function so the rule can be table-tested
/// rather than eyeballed. `region` is the whole area the dropdown may occupy
/// — the screen's safe region, under the status bar and above the tab bar —
/// and `badge` is in the same coordinate space. Trailing edge at the
/// region's trailing gutter (the badge supplies only the vertical — Sort By
/// has always hung at the gutter, and every other in-page dropdown follows
/// it); never past the leading gutter; below the badge by the gap, or above
/// it when below would run past the region's bottom, and pinned to the
/// region's top if neither fits.
///
/// No insets parameter: the host's reader already sits inside the safe
/// area, so its bounds *are* the region. (Reading the insets back and
/// subtracting them again double-counted them — T020's probe caught the
/// dropdown pinned two points low.)
enum DropdownPlacement {
    nonisolated static func origin(
        badge: CGRect,
        region: CGRect,
        size: CGSize,
        gutter: CGFloat,
        gap: CGFloat
    ) -> CGPoint {
        let x = max(region.maxX - gutter - size.width, region.minX + gutter)

        var y = badge.maxY + gap
        if y + size.height > region.maxY {
            y = badge.minY - gap - size.height
        }
        y = max(y, region.minY)

        return CGPoint(x: x, y: y)
    }

    /// Where a dropdown grows from and shrinks to (spec Decision 20): the
    /// badge's trailing edge at its vertical centre, as a point of the
    /// region — a scale anchored there, applied to a view that fills the
    /// region, scales the dropdown about the badge whether it hangs below
    /// or flips above. Clamped, so a badge scrolled past the region's edge
    /// still anchors at that edge.
    nonisolated static func growthAnchor(badge: CGRect, region: CGRect) -> UnitPoint {
        guard region.width > 0, region.height > 0 else { return .topTrailing }
        let x = (badge.maxX - region.minX) / region.width
        let y = (badge.midY - region.minY) / region.height
        return UnitPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }
}

/// Fills the host's overlay and places its one subview by
/// `DropdownPlacement.origin`. A `Layout` because it measures the dropdown
/// in the same pass it places it — no state, no one-frame jump before a
/// measured size arrives, no cycle. The `FlowLayout` shape.
private struct DropdownPlacementLayout: Layout {
    let badge: CGRect
    let region: CGRect
    let gutter: CGFloat
    let gap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let dropdown = subviews.first else { return }
        let size = dropdown.sizeThatFits(.unspecified)
        // `badge` and `region` share the reader's coordinate space; `bounds`
        // is in the layout's parent's, whose origin need not be the reader's
        // — so the computed point is placed relative to the layout's own
        // origin, never as an absolute.
        let origin = DropdownPlacement.origin(
            badge: badge,
            region: region,
            size: size,
            gutter: gutter,
            gap: gap
        )
        dropdown.place(
            at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
            anchor: .topLeading,
            proposal: .unspecified
        )
    }
}

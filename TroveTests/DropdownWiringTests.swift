import Foundation
import SwiftUI
import Testing
@testable import Trove

/// The in-page dropdown's wiring (013 Amendment A): the rules its
/// components must compose, read from the bodies that compose them — never
/// from a declaration, the false-passing shape this project has hit three
/// times.
@Suite("Dropdown wiring")
struct DropdownWiringTests {
    private let dropdownFile = "Trove/Views/Shared/Dropdown.swift"

    /// Criterion 23 by construction: the row's own button action closes the
    /// dropdown and *then* runs what it was asked to. Read from the Button's
    /// action closure, in order — the two calls both present in the wrong
    /// order would still be "wired".
    @Test func everyRowDismissesBeforeItActs() throws {
        let code = try SourceScan.production(dropdownFile)
        let row = try #require(structSource("DropdownRow", in: code), "no DropdownRow")
        let action = try #require(
            SourceScan.closureBodies(after: "Button", in: row).first,
            "DropdownRow builds no Button"
        )
        let dismiss = try #require(action.range(of: "dismiss()"), "the row never dismisses")
        let act = try #require(action.range(of: "action()"), "the row never acts")
        #expect(dismiss.lowerBound < act.lowerBound, "dismiss() must run before action()")
    }

    /// P11: a disabled row is inert and dimmed — `.disabled`, which is what
    /// gives VoiceOver its "dimmed" and XCUITest its `isEnabled == false`,
    /// and the disabled text token, not a lower opacity on the body colour.
    @Test func aDisabledRowIsInertAndDimmed() throws {
        let code = try SourceScan.production(dropdownFile)
        let row = try #require(structSource("DropdownRow", in: code))
        #expect(row.contains(".disabled(!isEnabled)"), "the row must disable off isEnabled")
        #expect(row.contains("theme.colors.textDisabled"), "a disabled row reads in textDisabled")
    }

    /// The surface marks its first subview through the environment (under
    /// the switch the render tests turn off) and closes on the escape
    /// gesture; the row applies the focus modifier, which acts on the first
    /// row alone. The focus half of criterion 26 is verified by hand — this
    /// pins that the wiring is composed at all, on every side.
    @Test func theSurfaceMarksItsFirstRowWhichTakesFocusAndClosesOnEscape() throws {
        let code = try SourceScan.production(dropdownFile)
        let surface = try #require(structSource("DropdownSurface", in: code))
        let surfaceBody = try #require(SourceScan.closureBodies(after: "var body: some View", in: surface).first)
        #expect(surfaceBody.contains("Group(subviews:"), "the surface must enumerate its subviews to find the first")
        #expect(
            surfaceBody.contains(".environment(\\.isFirstDropdownRow, focusesFirstRow && subview.id == subviews.first?.id)"),
            "the first subview must be marked, only the first, and only under the switch"
        )
        #expect(surfaceBody.contains(".accessibilityAction(.escape)"), "escape must close the dropdown")
        #expect(surfaceBody.contains(".accessibilityElement(children: .contain)"), "the surface is a container")

        let row = try #require(structSource("DropdownRow", in: code))
        let rowBody = try #require(SourceScan.closureBodies(after: "var body: some View", in: row).first)
        #expect(rowBody.contains(".modifier(FirstRowFocus(isFirst: isFirst, focus: $isFocused))"), "the row applies the focus modifier")

        let focus = try #require(structSource("FirstRowFocus", in: code))
        let focusBody = try #require(SourceScan.closureBodies(after: "if isFirst", in: focus).first, "the modifier never branches on isFirst")
        #expect(focusBody.contains(".accessibilityFocused(focus)"), "the first row must carry the focus binding")
        #expect(focusBody.contains("focus.wrappedValue = true"), "the first row must actually take focus")
        // The switch's default is the one thing a scan of the source line
        // can't see: off by default would disable focus-on-open app-wide.
        #expect(EnvironmentValues().dropdownFocusesFirstRow, "the first-row marking must be on by default")
    }

    /// Decision 18 in code: every badge is a button whose hint says what it
    /// opens, and every badge carries the identifier the UI tests query.
    /// Read from the controls' own bodies. The three sort badges left at
    /// `018` for system menus, and the four "…" badges at T005 — they carry
    /// no hint, and `HeaderControlsWiringTests` (G3) pins their identifiers
    /// now. What is left here is `OverflowBadge` itself, until it goes at
    /// T010, and the Dashboard's order control, until T006.
    @Test func everyBadgeCarriesItsHintAndIdentifier() throws {
        let badge = try SourceScan.production("Trove/Views/Shared/OverflowBadge.swift")
        let badgeBody = try #require(SourceScan.closureBodies(after: "var body: some View", in: badge).first)
        #expect(badgeBody.contains(".accessibilityHint(\"Opens more actions\")"), "the \"…\" badge's hint")
        #expect(badgeBody.contains("isBusy ? \"Working\" : \"More actions\""), "the \"…\" badge's label, both states")

        let dashboard = try SourceScan.production("Trove/Views/Dashboard/DashboardView.swift")
        let order = try #require(SourceScan.closureBodies(after: "private var orderControl: some View", in: dashboard).first)
        #expect(order.contains(".accessibilityHint(\"Opens order options\")"), "the order control's hint")
        #expect(order.contains(".accessibilityIdentifier(\"orderOptions.dashboard\")"), "the order control's identifier")
    }

    /// Criterion 14/23's badge half on the pill T021 rewrote: while busy the
    /// glyph gives way to the spinner and the whole control disables. Read
    /// from the badge's body — the call-site scan pins only that `isBusy`
    /// is passed.
    @Test func theBadgeShowsTheSpinnerAndDisablesWhileBusy() throws {
        let code = try SourceScan.production("Trove/Views/Shared/OverflowBadge.swift")
        let body = try #require(SourceScan.closureBodies(after: "var body: some View", in: code).first)
        let busy = try #require(SourceScan.closureBodies(after: "if isBusy", in: body).first, "no busy branch")
        #expect(busy.contains("ProgressView()"), "the busy branch shows the spinner")
        #expect(body.contains("Image(systemName: \"ellipsis\")"), "the idle branch shows the glyph")
        #expect(body.contains(".disabled(isBusy)"), "the whole control disables while busy")
    }

    /// Sort By is the shared surface with Sort By's rows — the drawing lives
    /// once. Read from `SortDropdown`'s body: the struct declaring a
    /// `DropdownSurface` somewhere would not make its body compose one.
    @Test func sortByComposesTheSharedSurface() throws {
        let code = try SourceScan.production("Trove/Views/Shared/SortPicker.swift")
        let dropdown = try #require(structSource("SortDropdown", in: code), "no SortDropdown")
        let body = try #require(SourceScan.closureBodies(after: "var body: some View", in: dropdown).first)
        #expect(body.contains("DropdownSurface(title: \"SORT BY\""), "Sort By must open the shared surface under its header")
        #expect(body.contains("DropdownRow("), "Sort By's rows must be the shared row")
        #expect(!dropdown.contains("PlateSurface"), "the plate is the surface's to draw, not Sort By's")
    }

    // MARK: - The host and its screens

    /// The overflow dropdown is the shared surface with no header (P9),
    /// read from its body — and nothing in its file draws a plate of its
    /// own.
    @Test func theOverflowDropdownIsHeaderlessOnTheSharedSurface() throws {
        let code = try SourceScan.production("Trove/Views/Shared/OverflowDropdown.swift")
        let dropdown = try #require(structSource("OverflowDropdown", in: code), "no OverflowDropdown")
        let body = try #require(SourceScan.closureBodies(after: "var body: some View", in: dropdown).first)
        #expect(body.contains("DropdownSurface {"), "the overflow must open the shared surface, headerless")
        #expect(!body.contains("DropdownSurface(title:"), "the overflow dropdown carries no header row")
        #expect(!dropdown.contains("PlateSurface") && !dropdown.contains("Menu {"), "the plate is the surface's to draw; no system menu")
    }

    /// The host is where the dismiss action becomes real, where VoiceOver is
    /// kept inside the open dropdown, and where the escape gesture and the
    /// labelled catcher live. Read from the modifier's body.
    @Test func theHostInjectsDismissAndContainsVoiceOver() throws {
        let code = try SourceScan.production("Trove/Views/Shared/DropdownHost.swift")
        let host = try #require(structSource("DropdownHost", in: code), "no DropdownHost modifier")
        // The modifier's body composes the open dropdown through a helper;
        // the helper's body is where the catcher and the injection live.
        let body = try #require(SourceScan.closureBodies(after: "func body(content host: Content)", in: host).first)
        #expect(body.contains("dropdown(id, badge: badge, region: region)"), "the body must compose the dropdown for the open id")
        // Decision 20: the transition sits on the view the conditional
        // inserts — nested any deeper it never runs (T024a's recording).
        let inserted = try #require(SourceScan.closureBodies(after: "if let id = open, let anchor = anchors[AnyHashable(id)]", in: body).first)
        #expect(inserted.contains(".transition(transition(growingFrom: DropdownPlacement.growthAnchor("), "the inserted view must carry the transition, growing from the badge")
        let dropdown = try #require(
            SourceScan.closureBodies(after: "private func dropdown(_ id: ID, badge: CGRect, region: CGRect) -> some View", in: host).first,
            "no dropdown helper"
        )
        // Attached to the dropdown content itself — on the catcher it would
        // be present and useless (the sweep's S1).
        let contentStart = try #require(dropdown.range(of: "self.content(id)"), "the host must compose the content")
        let afterContent = dropdown[contentStart.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(
            afterContent.hasPrefix(".environment(\\.dismissDropdown, DismissDropdownAction { close() })"),
            "the host must inject the real dismiss action directly on the dropdown content"
        )
        #expect(dropdown.contains(".accessibilityAddTraits(.isModal)"), "VoiceOver must stay inside the open dropdown")
        #expect(dropdown.contains(".accessibilityAction(.escape) { close() }"), "escape must close it")
        #expect(dropdown.contains(".accessibilityAddTraits(.isButton)"), "the catcher is a real tap target and must say so")
        #expect(dropdown.contains(".accessibilityLabel(dismissLabel(id))"), "the catcher must be labelled per menu")
        // Decision 20: the dropdown grows out of the badge and fades, on an
        // animation scoped to the host's overlay — never `withAnimation`
        // around a screen's write, which would tween the sort badge's
        // border against its snapping label (T029c).
        #expect(body.contains(".animation(animation, value: open)"), "the animation must be scoped to the overlay, keyed on the open state")
        #expect(host.contains("accessibilityReduceMotion"), "Reduce Motion must be honoured")
        // The numbers tokens.md carries (Decision 20), pinned here so the two
        // encodings can't drift apart unnoticed.
        #expect(host.contains(".snappy(duration: 0.25)") && host.contains(".easeOut(duration: 0.15)"), "open on the 0.25 s spring, close on the 0.15 s ease-out")
        #expect(host.contains("scale: 0.92"), "the dropdown grows from 92%")
        #expect(!host.contains("withAnimation"), "no screen write is ever animated — the animation is the host's alone")
        #expect(!host.contains("$0.animation = nil"), "the transaction's animation is no longer stripped")
    }

    /// The Dashboard's category-order control (spec P12, criterion 25): the
    /// mono label stays a label — no pill — and opens the shared surface
    /// under ORDER BY, its rows the shared row with the current order
    /// selected. Read from the control's body and the host's `.order` case.
    @Test func theDashboardOrderControlOpensTheSharedSurfaceUnderOrderBy() throws {
        let code = try SourceScan.production("Trove/Views/Dashboard/DashboardView.swift")
        #expect(code.ranges(of: ".dropdownAnchor(DashboardDropdown.order)").count == 1, "the order control must be anchored, once")
        let control = try #require(SourceScan.closureBodies(after: "private var orderControl: some View", in: code).first)
        #expect(control.contains("openDropdown = .order"), "the control must open the order dropdown")
        #expect(control.contains(".monoLabel("), "the label stays the mock's mono text (P12)")
        #expect(!control.contains("Badge("), "the order control is not a pill (P12)")

        let host = try #require(SourceScan.closureBodies(after: ".dropdownHost(open: $openDropdown", in: code).first)
        let orderCase = try #require(host.range(of: "case .order:"), "the host must compose the order dropdown")
        let composition = String(host[orderCase.upperBound...])
        #expect(composition.contains("DropdownSurface(title: \"ORDER BY\")"), "the order dropdown opens under ORDER BY")
        #expect(composition.contains("DropdownRow(title: order.label, isSelected: order == viewModel.breakdownOrder)"), "the rows are the shared row, the current order selected")
        #expect(composition.contains("viewModel.breakdownOrder = order") && composition.contains("viewModel.load()"), "choosing must reorder and reload")
    }

    // MARK: - Helpers

    /// The text of one top-level `struct <name>` declaration, up to the next
    /// top-level declaration — so a scan can't be satisfied by a neighbour.
    private func structSource(_ name: String, in code: String) -> String? {
        guard let start = code.range(of: "struct \(name)") else { return nil }
        let rest = code[start.upperBound...]
        let ends = ["\nstruct ", "\nprivate struct ", "\nextension ", "\nenum ", "\n#Preview"]
            .compactMap { rest.range(of: $0)?.lowerBound }
        let end = ends.min() ?? code.endIndex
        return String(code[start.lowerBound..<end])
    }
}

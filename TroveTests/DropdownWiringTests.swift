import Foundation
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

    private nonisolated static let lists = [
        "Trove/Views/Items/ItemListView.swift",
        "Trove/Views/Wishlist/WishlistView.swift",
    ]

    /// One optional is the screen's whole open-menu state: exactly one
    /// `openDropdown`, no surviving boolean, and a host bound to it — placed
    /// after the add button's overlay so the dropdown draws above it.
    @Test(arguments: lists)
    func eachListHostsItsDropdownsOffOneOptional(path: String) throws {
        let code = try SourceScan.production(path)
        #expect(code.ranges(of: "@State private var openDropdown: HeaderDropdown?").count == 1, "\(path): one optional, declared once")
        #expect(!code.contains("isSortMenuOpen"), "\(path): the boolean must be gone")
        let hosts = code.ranges(of: ".dropdownHost(open: $openDropdown")
        #expect(hosts.count == 1, "\(path) attaches \(hosts.count) hosts, expected exactly 1")
        let addButton = try #require(code.range(of: ".overlay(alignment: .bottomTrailing)"), "\(path): no add-button overlay?")
        if let host = hosts.first {
            #expect(host.lowerBound > addButton.upperBound, "\(path): the host must come after the add button's overlay")
        }
        #expect(code.ranges(of: ".dropdownAnchor(HeaderDropdown.sort)").count == 1, "\(path): the sort badge must be anchored, once")
        #expect(code.ranges(of: ".dropdownAnchor(HeaderDropdown.overflow)").count == 1, "\(path): the overflow badge must be anchored, once")
        let host = try #require(SourceScan.closureBodies(after: ".dropdownHost(open: $openDropdown", in: code).first)
        #expect(host.contains("case .sort:") && host.contains("SortDropdown("), "\(path): the host must compose Sort By")
        #expect(host.contains("case .overflow:") && host.contains("OverflowDropdown("), "\(path): the host must compose the overflow")
    }

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
        let body = try #require(SourceScan.closureBodies(after: "func body(content host: Content)", in: host).first)
        #expect(body.contains(".environment(\\.dismissDropdown, DismissDropdownAction { close() })"), "the host must inject the real dismiss action")
        #expect(body.contains(".accessibilityAddTraits(.isModal)"), "VoiceOver must stay inside the open dropdown")
        #expect(body.contains(".accessibilityAction(.escape) { close() }"), "escape must close it")
        #expect(body.contains(".accessibilityAddTraits(.isButton)"), "the catcher is a real tap target and must say so")
        #expect(body.contains(".accessibilityLabel(dismissLabel(id))"), "the catcher must be labelled per menu")
        #expect(!body.contains("withAnimation"), "opening and closing don't animate, as Sort By never has")
    }

    /// The root Dashboard alone carries the "…" (spec Decision 16): the
    /// anchor sits inside exactly one `if isRoot` span and nowhere else,
    /// the screen's open-menu state is one optional, and the host composes
    /// the one-row Settings menu on the shared surface.
    @Test func theDashboardAnchorsItsBadgeOnTheRootAloneAndComposesSettings() throws {
        let code = try SourceScan.production("Trove/Views/Dashboard/DashboardView.swift")
        let anchor = ".dropdownAnchor(DashboardDropdown.overflow)"
        #expect(code.ranges(of: anchor).count == 1, "the Dashboard badge must be anchored, once")
        let rootSpans = SourceScan.closureBodies(after: "if isRoot", in: code)
        try #require(!rootSpans.isEmpty, "no `if isRoot` gates — wrong scan target?")
        #expect(rootSpans.filter { $0.contains("overflowControl") }.count == 1, "the badge must be gated on isRoot, in exactly one span")
        // The control's body carries the anchor; the gate carries the control.
        let control = try #require(SourceScan.closureBodies(after: "private var overflowControl: some View", in: code).first)
        #expect(control.contains(anchor) && control.contains("openDropdown = .overflow"), "the badge must open the overflow and be anchored")

        #expect(code.ranges(of: "@State private var openDropdown: DashboardDropdown?").count == 1, "one optional, declared once")
        let hosts = SourceScan.closureBodies(after: ".dropdownHost(open: $openDropdown", in: code)
        try #require(hosts.count == 1, "the Dashboard attaches \(hosts.count) hosts, expected exactly 1")
        #expect(hosts[0].contains("case .overflow:") && hosts[0].contains("DropdownSurface {") && hosts[0].contains("DropdownRow(title: \"Settings\")"), "the host must compose the one-row Settings menu")
        #expect(hosts[0].contains("isShowingSettings = true"), "the Settings row must open the sheet")
        // The order control's system menu leaves at T023; `MenuPolicyTests`
        // owns that rule. This host, at least, composes no system menu.
        #expect(!hosts[0].contains("Menu {"), "no system menu inside the Dashboard's host")
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

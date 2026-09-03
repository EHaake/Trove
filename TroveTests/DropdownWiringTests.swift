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

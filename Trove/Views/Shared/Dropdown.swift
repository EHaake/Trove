import SwiftUI

/// The in-page dropdown's surface (013 Amendment A): the 232-point plate
/// `010` drew for Sort By, now the one drawing every in-page menu opens —
/// Sort By, the lists' and the Dashboard's "…", and the Dashboard's
/// category-order control. Same width, background, border and radius; an
/// optional mono header ("SORT BY", "ORDER BY"); rows composed by the
/// caller from `DropdownRow`.
///
/// Bespoke inside the page, system in the bars — the rule this file exists
/// for (spec Decision 17). The detail screens' nav-bar "…" stays a system
/// `Menu`; nothing drawn inside a page's content is one
/// (`MenuPolicyTests`).
///
/// Accessibility: the surface is a container, and VoiceOver focus lands on
/// its **first row** one run-loop turn after it appears — a container isn't
/// itself focusable, so `Group(subviews:)` tells the first subview it is
/// first through the environment and `DropdownRow` takes the focus itself.
/// Only `.environment` touches a subview. The focus binding itself lives on
/// the first row, applied only when `dropdownFocusesFirstRow` is on: a view
/// carrying an accessibility-focus binding renders as nothing under
/// `ImageRenderer`, which has no focus system — found by the T018 oracle,
/// not by eye — so the render tests turn the marking off and the simulator
/// pass covers that the binding draws nothing on a real screen. The escape
/// gesture closes the dropdown through the environment's dismiss action,
/// the same one every row calls before it acts.
struct DropdownSurface<Content: View>: View {
    let title: String?
    let content: Content

    @Environment(\.theme) private var theme
    @Environment(\.dismissDropdown) private var dismiss
    @Environment(\.dropdownFocusesFirstRow) private var focusesFirstRow

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if let title {
                Text(title)
                    .font(ThemeTypography.font(.mono, size: 10))
                    .tracking(1.6)
                    .foregroundStyle(theme.colors.textQuiet)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 11, leading: 14, bottom: 9, trailing: 14))
            }

            Group(subviews: content) { subviews in
                ForEach(subviews) { subview in
                    subview.environment(\.isFirstDropdownRow, focusesFirstRow && subview.id == subviews.first?.id)
                }
            }
        }
        .frame(width: 232)
        .background { PlateSurface() }
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.buttonRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                .strokeBorder(theme.colors.divider, lineWidth: theme.metrics.hairline)
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) { dismiss() }
    }
}

extension EnvironmentValues {
    /// Set by `DropdownSurface` on its first subview alone, so that row —
    /// and only that row — takes VoiceOver focus when the dropdown opens.
    @Entry var isFirstDropdownRow = false

    /// Whether a surface marks a first row at all. On everywhere the app
    /// draws; the render tests turn it off, because the focus binding it
    /// leads to erases the row under `ImageRenderer` (see `DropdownSurface`).
    @Entry var dropdownFocusesFirstRow = true
}

/// One row on a `DropdownSurface`: `010`'s sort row — body type, the brass
/// selected state with its tint and drawn checkmark, an optional mono tag
/// (REORDER) — plus what the other menus need: a disabled state (P11), a
/// group break drawn as the row's own top hairline in `divider` rather
/// than `surfaceInset` (P10, one hairline — a separate break view would
/// stack a second under this one), and no hairline at all on the first row
/// of a headerless surface, where it would double the border.
///
/// Every row dismisses the dropdown **before** its action runs, through the
/// environment's `dismissDropdown` — criterion 23 holds by construction
/// rather than by each screen remembering to close.
struct DropdownRow: View {
    let title: String
    var isSelected = false
    var isEnabled = true
    var startsGroup = false
    var hasTopHairline = true
    var tag: String? = nil
    let action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismissDropdown) private var dismiss
    @Environment(\.isFirstDropdownRow) private var isFirst
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        Button {
            dismiss()
            action()
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(theme.typography.body)
                    .foregroundStyle(titleColor)

                Spacer(minLength: 0)

                if isSelected {
                    if let tag {
                        Text(tag)
                            .font(ThemeTypography.font(.mono, size: 9.5))
                            .tracking(1.14)
                            .foregroundStyle(theme.colors.textQuiet)
                    }
                    CheckmarkGlyph()
                        .stroke(
                            theme.colors.accentBrass,
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 12, height: 12)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(isSelected ? theme.colors.accentBrassTint : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Inert, "dimmed" to VoiceOver, `isEnabled == false` to XCUITest —
        // the row stays in the tree so a test can see it is disabled.
        .disabled(!isEnabled)
        .overlay(alignment: .top) {
            if hasTopHairline {
                (startsGroup ? theme.colors.divider : theme.colors.surfaceInset)
                    .frame(height: theme.metrics.hairline)
            }
        }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .modifier(FirstRowFocus(isFirst: isFirst, focus: $isFocused))
    }

    private var titleColor: Color {
        if !isEnabled { return theme.colors.textDisabled }
        return isSelected ? theme.colors.accentBrass : theme.colors.textBody
    }
}

/// The first row's focus binding, and the take-focus-on-appear that goes
/// with it — applied to every row, acting on the first alone, so that no
/// other row carries a binding it never uses.
private struct FirstRowFocus: ViewModifier {
    let isFirst: Bool
    let focus: AccessibilityFocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if isFirst {
            content
                .accessibilityFocused(focus)
                .onAppear {
                    // One run-loop turn after the dropdown appears: focus set
                    // in the insertion's own transaction is routinely dropped
                    // by VoiceOver.
                    Task { @MainActor in focus.wrappedValue = true }
                }
        } else {
            content
        }
    }
}

/// tokens.md's 12×12 checkmark at 1.6 stroke, drawn rather than borrowed so
/// the stroke weight is exact.
private struct CheckmarkGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.8))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.85, y: rect.minY + rect.height * 0.25))
        return path
    }
}

#Preview("Headerless, with a group break and a disabled row") {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        DropdownSurface {
            DropdownRow(title: "Export as CSV…", isEnabled: false, hasTopHairline: false) {}
            DropdownRow(title: "Export as PDF…", isEnabled: false) {}
            DropdownRow(title: "Import from CSV…", startsGroup: true) {}
            DropdownRow(title: "Settings", startsGroup: true) {}
        }
        .environment(\.dismissDropdown, DismissDropdownAction {})
    }
    .environment(\.theme, .dark)
}

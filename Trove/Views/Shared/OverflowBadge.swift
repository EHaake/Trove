import SwiftUI

/// The header's "…" badge — 011's `ExportBadge`, renamed at 012/T013 when
/// the import actions joined its menu, and since 013 Amendment A a plain
/// button that opens `OverflowDropdown` on the screen's dropdown host.
///
/// It hosted a system `Menu` from 011 to 013: safe from the T029c tear
/// because its label is a constant-size glyph, and chosen then so the
/// header wouldn't carry a second overlay-and-catcher state machine. The
/// amendment's rule ended that — **bespoke inside the page, system in the
/// bars** — so the two badges that sit side by side open one visual
/// language, and the host is the one state machine for both. The detail
/// screens' nav-bar "…" (`DetailOverflowMenu`) stays a system menu: that's
/// the bar's chrome, beside the system back chevron.
///
/// The whole control disables behind a compact spinner while any export or
/// import runs (`isBusy`). The badge shows regardless of collection size:
/// its menu carries Import and Settings, always enabled, and the fresh
/// install with a spreadsheet in hand is exactly who they serve.
struct OverflowBadge: View {
    let isBusy: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.colors.accentBrass)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(theme.colors.accentBrass)
            // Sized against SortBadge's content row (mono 11 text) so the
            // two badges share a height without either knowing the other's.
            .frame(width: 18, height: 14)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.buttonRadius)
                    .strokeBorder(theme.colors.accentBrass, lineWidth: theme.metrics.hairline)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(isBusy ? "Working" : "More actions")
        // A button whose hint says what it opens — SwiftUI has no pop-up
        // trait to give it (spec Decision 18).
        .accessibilityHint("Opens more actions")
    }
}

#Preview {
    ZStack {
        Theme.dark.colors.background.ignoresSafeArea()
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                SortBadge(label: "Custom") {}
                OverflowBadge(isBusy: false) {}
            }
            OverflowBadge(isBusy: true) {}
        }
    }
    .environment(\.theme, .dark)
    .preferredColorScheme(.dark)
}

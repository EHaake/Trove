import SwiftUI

/// One selectable capsule — `ItemFormView.conditionChip`, extracted verbatim
/// (020 plan §6, Q5): size, stroke, selected tint, the `contentShape` fix
/// (009 T014a), and the selected trait.
///
/// The selected trait is load-bearing twice over: it is how VoiceOver says
/// which chip is chosen, and how a UI test reads the selection.
struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.typography.secondary)
                .foregroundStyle(isSelected ? theme.colors.accentBrass : theme.colors.textBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isSelected ? theme.colors.accentBrassTint : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? theme.colors.accentBrass : theme.colors.divider,
                        lineWidth: theme.metrics.hairline
                    )
                )
                // A clear fill doesn't hit-test: without this an unselected
                // chip's padding took no tap (009 T014a).
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The condition row: a mono label over ONE sideways-scrolling row of one
/// chip per case (020 spec Decision 11, plan Amendment A) —
/// `CategoryPickerField`'s row, copied. Not a picker: the capsules are the
/// form's design.
///
/// The row's frame stays inside the gutter, so at offset 0 the first chip
/// lines up with the label. `.scrollClipDisabled()` lets chips draw through
/// the gutter to the screen edge, and because `chipSpacing` is less than the
/// gutter a chip is always visible there on any side that has more to scroll
/// to — the cut-off chip that says the row scrolls — with the field knowing
/// nothing of the gutter.
struct ConditionField: View {
    static let chipSpacing: CGFloat = 8

    let label: String
    @Binding var selection: Condition

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text(label).monoLabel()

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Self.chipSpacing) {
                        ForEach(Condition.allCases, id: \.self) { condition in
                            ChoiceChip(
                                title: condition.rawValue.capitalized,
                                isSelected: selection == condition
                            ) {
                                selection = condition
                            }
                            .id(condition)
                        }
                    }
                }
                .scrollClipDisabled()
                // An item saved as Fair or Broken opens with its grade off to
                // the right, where a single row hides it. On appear only,
                // never on a selection change, and without an animation.
                .onAppear {
                    proxy.scrollTo(selection, anchor: .center)
                }
            }
        }
    }
}

/// Bought / Looking for: a mono label over two chips (two need no wrapping,
/// and the row does not scroll). Tapping goes through
/// `NewOrUsed.selection(afterTapping:current:)`, so tapping the selected chip
/// clears the field.
///
/// Each chip is identified "<identifier>.new" / "<identifier>.used" — the
/// condition row has a "New" chip too, so a label cannot address it. The
/// field is an accessibility container labelled with its field label, so
/// VoiceOver announces "Bought" before the two words it shares with the
/// condition row.
struct NewOrUsedField: View {
    let label: String
    let identifier: String
    @Binding var selection: NewOrUsed?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.metrics.fieldGap) {
            Text(label).monoLabel()

            HStack(spacing: 8) {
                ForEach(NewOrUsed.allCases, id: \.self) { value in
                    ChoiceChip(
                        title: NewOrUsedCopy.chip(value),
                        isSelected: selection == value
                    ) {
                        selection = NewOrUsed.selection(afterTapping: value, current: selection)
                    }
                    .accessibilityIdentifier("\(identifier).\(value.rawValue)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

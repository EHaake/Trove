import Testing
@testable import Trove

/// Guards `CategoryPickerField`'s swap between the text field and the
/// breadcrumb read-out.
///
/// The rule is three booleans and looks too small to be worth a suite, which is
/// exactly why it shipped wrong: it was written as an inline condition, read
/// fine, and broke the field's whole reason to exist. T044's click-through
/// found it by typing a category and watching nineteen characters become one.
@Suite("Category picker field")
struct CategoryPickerFieldTests {
    // MARK: - The regression

    /// The bug, as a sequence. An empty field has no breadcrumb, so the text
    /// field is what's on screen and tapping it focuses that directly —
    /// `isEditingPath` never becomes true. Before the fix, the first character
    /// made the path non-empty and the read-out took over, destroying the
    /// focused field; the rest of the word went nowhere.
    ///
    /// Asserting per character rather than on the final string is deliberate:
    /// the failure happens on the first one, and the message should say so
    /// rather than reporting the end state.
    @Test func typingIntoAnEmptyFieldNeverSwapsItOut() {
        var typed = ""

        for character in "Photography/Cameras" {
            typed.append(character)

            #expect(
                !CategoryPickerField.showsReadOut(
                    isEditingPath: false,
                    isFocused: true,
                    categoryPath: typed
                ),
                "The field became a read-out mid-word, after typing \"\(typed)\""
            )
        }
    }

    /// The same guarantee stated directly: focus wins over everything else.
    /// Typing is the case that matters, but any re-render while the field holds
    /// the keyboard has to leave it there.
    @Test func aFocusedFieldIsNeverSwappedOut() {
        #expect(
            !CategoryPickerField.showsReadOut(
                isEditingPath: false,
                isFocused: true,
                categoryPath: "Photography/Cameras"
            )
        )
    }

    // MARK: - The ordinary transitions

    /// Nothing typed yet: the field is the only thing there is to show.
    @Test func anEmptyPathShowsTheField() {
        #expect(
            !CategoryPickerField.showsReadOut(
                isEditingPath: false,
                isFocused: false,
                categoryPath: ""
            )
        )
    }

    /// A set value reads back as a breadcrumb once the user has moved on.
    @Test func aSetPathReadsBackAsTheBreadcrumb() {
        #expect(
            CategoryPickerField.showsReadOut(
                isEditingPath: false,
                isFocused: false,
                categoryPath: "Photography/Cameras"
            )
        )
    }

    /// Tapping the breadcrumb returns to editing, which is the path the field
    /// takes when an existing item is opened for editing.
    @Test func tappingTheBreadcrumbReturnsToTheField() {
        #expect(
            !CategoryPickerField.showsReadOut(
                isEditingPath: true,
                isFocused: false,
                categoryPath: "Photography/Cameras"
            )
        )
    }

    /// Spaces alone aren't a category. Without the trim, a field the user
    /// cleared down to a stray space would read back as a breadcrumb showing
    /// nothing, with no obvious way back into it.
    @Test func whitespaceAloneIsNotAPath() {
        #expect(
            !CategoryPickerField.showsReadOut(
                isEditingPath: false,
                isFocused: false,
                categoryPath: "   "
            )
        )
    }
}

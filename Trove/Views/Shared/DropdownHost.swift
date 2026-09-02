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

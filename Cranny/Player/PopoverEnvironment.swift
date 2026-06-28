import SwiftUI

/// Closes the menu-bar popover. Provided by StatusBarController; used by the browser to
/// dismiss after a row tap / play action (since `\.dismiss` only works inside MenuBarExtra).
private struct DismissPopoverKey: EnvironmentKey {
    static let defaultValue: @MainActor () -> Void = {}
}

extension EnvironmentValues {
    var dismissPopover: @MainActor () -> Void {
        get { self[DismissPopoverKey.self] }
        set { self[DismissPopoverKey.self] = newValue }
    }
}

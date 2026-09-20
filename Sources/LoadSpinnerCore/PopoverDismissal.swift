import Foundation

/// Where a mouse-down seen by the app's *local* event monitor landed.
///
/// Clicks in other processes never reach the local monitor — the global
/// monitor sees those, and every one of them is outside the popover.
public enum PopoverClickSite: Equatable, Sendable {
    /// The status item button's window.
    case statusItemButton
    /// The popover's own window.
    case popover
    /// Any other window of this app.
    case elsewhere
}

/// Whether a local mouse-down should close the popover.
///
/// The status item button is *not* an outside click: its own action toggles
/// the popover, so closing here as well would turn one click into
/// close-then-reopen and the popover could never be dismissed from the button.
public func shouldClosePopover(isShown: Bool, clickSite: PopoverClickSite) -> Bool {
    guard isShown else { return false }
    switch clickSite {
    case .statusItemButton, .popover: return false
    case .elsewhere: return true
    }
}

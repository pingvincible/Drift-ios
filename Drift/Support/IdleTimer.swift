import UIKit

/// Thin wrapper around the auto-lock switch, so views never touch
/// `UIApplication` directly.
enum IdleTimer {
    @MainActor
    static func setDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}

import AppKit
import SwiftUI

/// Lightweight delegate for app-level lifecycle bits. The welcome window
/// and launch flow are handled by SwiftUI scenes in `MDPrintViewApp` — see
/// `.defaultLaunchBehavior(.presented)` on the Welcome `Window`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Apply the user's saved appearance (system/light/dark) before any
        // window is on screen — otherwise the welcome briefly flashes in
        // system mode before flipping.
        AppSettings().applyAppearanceToApp()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}

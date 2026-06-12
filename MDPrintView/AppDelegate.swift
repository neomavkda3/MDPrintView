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
        //
        // Read UserDefaults directly rather than constructing a throwaway
        // AppSettings() — a second @Observable instance distinct from the
        // app's @State one works today (both back onto UserDefaults) but
        // becomes a trap the moment AppSettings gains in-memory state.
        let raw = UserDefaults.standard.string(forKey: "appearance") ?? ""
        let appearance = AppSettings.Appearance(rawValue: raw) ?? .system
        NSApp.appearance = appearance.nsAppearance
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}

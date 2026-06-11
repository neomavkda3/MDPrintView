import AppKit
import SwiftUI

/// Lightweight delegate for app-level lifecycle bits. The welcome window
/// and launch flow are handled by SwiftUI scenes in `MdviewApp` — see
/// `.defaultLaunchBehavior(.presented)` on the Welcome `Window`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}

import AppKit
import SwiftUI

/// NSDocumentController subclass that suppresses the launch-time Open panel.
///
/// On macOS 26, SwiftUI's DocumentGroup calls `NSDocumentController.openDocument(_:)`
/// directly during app launch when there's no document to open, bypassing the
/// standard `applicationShouldOpenUntitledFile` / `applicationOpenUntitledFile`
/// delegate hooks. The result is an Open panel popping up at launch even after
/// we've taken over the untitled-file flow.
///
/// We install this subclass in `applicationWillFinishLaunching` (before SwiftUI
/// can spawn the default controller). During the launch window, `openDocument`
/// is a no-op. After the welcome window has been shown, we set
/// `allowOpenPanel = true` so user-initiated Cmd+O works normally.
@MainActor
final class WelcomingDocumentController: NSDocumentController {
    nonisolated(unsafe) static var allowOpenPanel = false

    override func openDocument(_ sender: Any?) {
        guard Self.allowOpenPanel else { return }
        super.openDocument(sender)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var welcomeWindowController: NSWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Instantiate our NSDocumentController subclass before SwiftUI's
        // DocumentGroup has a chance to create the default one. First
        // instance becomes `NSDocumentController.shared`.
        _ = WelcomingDocumentController()
    }

    // Delegate hooks for the untitled-file path. macOS may or may not call
    // these depending on launch path (terminal exec vs Spotlight vs Finder);
    // we return true to be belt-and-braces, but the real load-bearing
    // suppression is `WelcomingDocumentController.openDocument`.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.showWelcomeIfAppropriate()
            // Now that launch is complete, allow openDocument to do its
            // normal Open-panel thing for user-initiated Cmd+O.
            WelcomingDocumentController.allowOpenPanel = true
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWelcomeIfAppropriate() }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    private func showWelcomeIfAppropriate() {
        if UserDefaults.standard.bool(forKey: "suppressWelcomeOnLaunch") { return }
        if !NSDocumentController.shared.documents.isEmpty { return }

        if let existing = welcomeWindowController, let window = existing.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let host = NSHostingController(rootView: WelcomeView())
        let window = NSWindow(contentViewController: host)
        window.title = "Welcome to mdview"
        window.identifier = NSUserInterfaceItemIdentifier("mdview.welcome")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.tabbingMode = .disallowed

        let controller = NSWindowController(window: window)
        welcomeWindowController = controller

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

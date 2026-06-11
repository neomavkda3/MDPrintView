import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var welcomeWindowController: NSWindowController?

    // === Suppressing the launch Open panel ===
    //
    // SwiftUI's macOS DocumentGroup falls back to showing an Open panel
    // ("looks like Finder") on launch when there's no document. To prevent
    // that fallback we *handle* the untitled-file open ourselves.
    //
    //   Step 1: applicationShouldOpenUntitledFile → true  (yes, ask me)
    //   Step 2: applicationOpenUntitledFile      → true  (I handled it)
    //
    // In practice macOS may not always call these (DocumentGroup sometimes
    // bypasses them), so applicationDidFinishLaunching is the load-bearing
    // hook — it always fires and is where we actually open the welcome.

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Returning true means "handled" — AppKit won't fall through to its
        // default panel. The actual welcome opens in applicationDidFinishLaunching.
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Defer to the next runloop so any file arguments Cocoa is about to
        // process have a chance to land in NSDocumentController.documents
        // before we decide whether to show the welcome window.
        DispatchQueue.main.async { [weak self] in
            self?.showWelcomeIfAppropriate()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Dock-icon click with no visible windows → re-show welcome.
        if !flag {
            showWelcomeIfAppropriate()
        }
        return true
    }

    // Silences the macOS 14+ secure restorable state warning. We don't
    // encode any restorable state ourselves, so this is a formality.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func showWelcomeIfAppropriate() {
        if UserDefaults.standard.bool(forKey: "suppressWelcomeOnLaunch") { return }
        if !NSDocumentController.shared.documents.isEmpty { return }

        // Already have a window — bring it to front + activate the app.
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
        // Welcome shouldn't tab with document windows.
        window.tabbingMode = .disallowed

        let controller = NSWindowController(window: window)
        welcomeWindowController = controller

        // Activate the app FIRST, then make the welcome key. During launch
        // NSApp isn't yet the foreground app — without explicit activate,
        // the window is created but stays behind whatever app the user came
        // from.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

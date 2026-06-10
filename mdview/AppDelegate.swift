import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var welcomeWindowController: NSWindowController?

    // === Suppressing the launch Open panel ===
    //
    // SwiftUI's macOS DocumentGroup falls back to showing an Open panel
    // ("looks like Finder") on launch when there's no document. To prevent
    // that fallback we must *handle* the untitled-file open ourselves —
    // not just refuse it.
    //
    //   Step 1: applicationShouldOpenUntitledFile → true  (yes, ask me)
    //   Step 2: applicationOpenUntitledFile      → true  (I handled it)
    //
    // Returning true from step 2 tells AppKit "done, don't fall through to
    // your default behavior." Our handling is "show the welcome window, or
    // do nothing if the user suppressed it" — never create an untitled doc,
    // never open a panel.

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Defer to next runloop so any file arguments Cocoa is about to
        // process have a chance to land in NSDocumentController.documents
        // before we decide whether to show the welcome window.
        DispatchQueue.main.async { [weak self] in
            self?.showWelcomeIfAppropriate()
        }
        return true
    }

    // If the user clicks the dock icon while no windows are visible, show
    // the welcome window again.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showWelcomeIfAppropriate()
        }
        return true
    }

    private func showWelcomeIfAppropriate() {
        // Honor the user's suppress preference. AppDelegate reads UserDefaults
        // directly because @AppStorage in AppSettings persists to the same store.
        if UserDefaults.standard.bool(forKey: "suppressWelcomeOnLaunch") { return }
        // Skip if any document is open (e.g. user opened a .md from Finder).
        if !NSDocumentController.shared.documents.isEmpty { return }
        // Don't double-open if a welcome window is already visible.
        if let existing = welcomeWindowController, existing.window?.isVisible == true {
            existing.window?.makeKeyAndOrderFront(nil)
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
        controller.showWindow(nil)
        welcomeWindowController = controller
    }
}

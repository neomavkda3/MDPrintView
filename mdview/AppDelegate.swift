import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var welcomeWindowController: NSWindowController?

    // Suppress the default behavior of opening the Open panel ("looks like
    // Finder") when launching with no document. We show the welcome window
    // instead — or, if the user opened a .md from Finder/dock, the doc
    // window takes precedence.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Defer until Cocoa has processed any file-open args.
        DispatchQueue.main.async { [weak self] in
            self?.showWelcomeIfAppropriate()
        }
    }

    // If the user clicks the dock icon while no windows are visible, show
    // the welcome window again (same call as launch).
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

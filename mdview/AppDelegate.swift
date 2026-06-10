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
        print("[mdview.app] applicationShouldOpenUntitledFile — returning true")
        return true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        print("[mdview.app] applicationOpenUntitledFile — returning true (handled)")
        DispatchQueue.main.async { [weak self] in
            self?.showWelcomeIfAppropriate()
        }
        return true
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        print("[mdview.app] applicationWillFinishLaunching")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[mdview.app] applicationDidFinishLaunching — docs=\(NSDocumentController.shared.documents.count)")
        DispatchQueue.main.async { [weak self] in
            self?.showWelcomeIfAppropriate()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        print("[mdview.app] application:open:urls — \(urls)")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("[mdview.app] applicationShouldHandleReopen — hasVisibleWindows=\(flag)")
        if !flag {
            showWelcomeIfAppropriate()
        }
        return true
    }

    // Required on macOS 14+ to silence the secure restorable state warning.
    // Returning true means our restorable state encoders adopt NSSecureCoding —
    // we don't actually encode anything, so this is a formality.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func showWelcomeIfAppropriate() {
        let suppressed = UserDefaults.standard.bool(forKey: "suppressWelcomeOnLaunch")
        let docCount = NSDocumentController.shared.documents.count
        print("[mdview.app] showWelcomeIfAppropriate — suppressed=\(suppressed) docs=\(docCount)")

        if suppressed { return }
        if docCount > 0 { return }
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

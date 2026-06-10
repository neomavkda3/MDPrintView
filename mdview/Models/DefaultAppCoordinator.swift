import AppKit
import UniformTypeIdentifiers

/// Logic for the "set mdview as default for .md files" prompt.
/// At most one prompt is shown per app launch, to avoid pestering the user
/// when they open multiple files in quick succession. Per-launch dedupe
/// can be cleared via `resetForCurrentSession()` if you want a fresh prompt
/// (e.g. for a "show prompt again" Settings affordance).
@MainActor
enum DefaultAppCoordinator {
    private static var promptedThisSession = false

    static func checkAndPrompt(in window: NSWindow, settings: AppSettings) {
        guard !settings.suppressDefaultAppPrompt else { return }
        guard !promptedThisSession else { return }
        guard !isCurrentDefault() else { return }

        promptedThisSession = true
        showPrompt(in: window, settings: settings)
    }

    static func resetForCurrentSession() {
        promptedThisSession = false
    }

    static func isCurrentDefault() -> Bool {
        let markdownType = UTType(importedAs: "net.daringfireball.markdown")
        guard let currentDefaultURL = NSWorkspace.shared.urlForApplication(toOpen: markdownType) else {
            return false
        }
        return currentDefaultURL.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
    }

    private static func showPrompt(in window: NSWindow, settings: AppSettings) {
        let alert = NSAlert()
        alert.messageText = "Open Markdown files with mdview?"
        alert.informativeText = """
        mdview can be your default app for .md, .markdown, and .mdown files. \
        macOS will use it whenever you double-click a Markdown file in Finder or \
        open one from another app.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Use mdview as Default")
        alert.addButton(withTitle: "Not Now")

        let suppressCheckbox = NSButton(checkboxWithTitle: "Don't show this anymore", target: nil, action: nil)
        suppressCheckbox.state = .off
        alert.accessoryView = suppressCheckbox

        alert.beginSheetModal(for: window) { response in
            Task { @MainActor in
                if suppressCheckbox.state == .on {
                    settings.suppressDefaultAppPrompt = true
                }
                if response == .alertFirstButtonReturn {
                    setAsDefault()
                }
            }
        }
    }

    private static func setAsDefault() {
        let markdownType = UTType(importedAs: "net.daringfireball.markdown")
        NSWorkspace.shared.setDefaultApplication(
            at: Bundle.main.bundleURL,
            toOpen: markdownType
        ) { error in
            if let error {
                print("[mdview] Failed to set as default app for \(markdownType): \(error)")
            }
        }
    }
}

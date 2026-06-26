import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// SwiftUI drop delegate for the app's windows (Welcome + document chrome).
/// Highlights and accepts only *file* drags whose content type the app can open.
///
/// Content type can't be read synchronously from `DropInfo`: a Finder file
/// drag's item provider registers only `public.file-url` (never the concrete
/// type), and `DropInfo.itemProviders(for:)` matches a file provider against
/// any requested type. So we read the real file URLs synchronously from the
/// drag pasteboard (`NSPasteboard(name: .drag)`) and gate on their resolved
/// UTI via `FileDrop.accepts`. That makes the highlight accurate (a `.png`
/// never lights up) and lets `performDrop` open without an async URL load.
struct FileDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    /// Opens one accepted file. Runs on the main actor (touches NSDocumentController).
    let open: @MainActor (URL) -> Void

    /// File URLs in the current drag that the app can open. Read synchronously
    /// from the drag pasteboard; non-file drags (e.g. text selected in another
    /// app) yield nothing.
    private func openableURLs() -> [URL] {
        FileDrop.openableURLs(in: NSPasteboard(name: .drag))
    }

    func validateDrop(info: DropInfo) -> Bool {
        !openableURLs().isEmpty
    }

    func dropEntered(info: DropInfo) {
        isTargeted = !openableURLs().isEmpty
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: openableURLs().isEmpty ? .forbidden : .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let urls = openableURLs()
        guard !urls.isEmpty else { return false }
        let open = self.open  // capture the Sendable @MainActor closure, not self
        for url in urls {
            Task { @MainActor in open(url) }
        }
        return true
    }
}

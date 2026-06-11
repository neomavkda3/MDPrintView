import Foundation
import AppKit

/// Watches a single file URL and fires `onChange` (on main) whenever
/// another process modifies it on disk.
///
/// Built on `NSFilePresenter` so it cooperates with `NSFileCoordinator` —
/// when MDPrintView itself saves, the coordinator pauses presenter
/// notifications during the write, and well-behaved macOS apps (TextEdit,
/// the system shell out from Claude Code, Xcode's atomic-write path) do
/// the same. The result: no fights, no half-written reads.
///
/// Self-save de-dupe is handled by the *caller* — after we re-read disk,
/// the caller compares to the in-memory document text and only updates
/// if they differ, so MDPrintView writing the file does not loop back.
final class FileWatcher: NSObject, NSFilePresenter {
    private let url: URL
    private let onChange: @MainActor () -> Void

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }

    // MARK: NSFilePresenter

    var presentedItemURL: URL? { url }

    /// Drive callbacks on .main so the closure can touch SwiftUI state
    /// without an extra hop. NSFileCoordinator serializes calls onto this
    /// queue, so we don't risk re-entrant reads.
    var presentedItemOperationQueue: OperationQueue { .main }

    func presentedItemDidChange() {
        // We're already on main (per presentedItemOperationQueue), but
        // Swift can't statically prove it — Task @MainActor cheaply
        // confirms isolation for the @MainActor-typed closure.
        let action = onChange
        Task { @MainActor in
            action()
        }
    }
}

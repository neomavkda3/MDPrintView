import Foundation

/// Watches a single file URL for any on-disk modification and fires
/// `onChange` on the main actor.
///
/// Implementation: `DispatchSource.makeFileSystemObjectSource` (a thin
/// wrapper around the kernel `kqueue` facility).
///
/// We switched away from `NSFilePresenter` because it only reliably
/// notifies when the *other* writer also uses `NSFileCoordinator`
/// (TextEdit, Pages, Word). Tools that do raw atomic writes — vim,
/// `echo >`, sed, Claude Code's Edit tool, VS Code — bypass the
/// coordination layer entirely and never trigger NSFilePresenter
/// callbacks. kqueue catches all of them because it's hooked into the
/// VFS at the kernel level.
///
/// Atomic-write handling: most editors save by writing a `.tmp` file
/// and `rename(2)`-ing it over the original. That replaces the inode
/// our file descriptor points to. We detect this via the `.delete` /
/// `.rename` event flags and re-`open(2)` the path so the watcher
/// continues firing for subsequent edits. The re-open retries with
/// backoff because slow writers (large files, sync tools, git checkout)
/// can leave a window where the path briefly doesn't exist.
///
/// Lifecycle contract: the OWNER must call `cancel()` from the main
/// actor before releasing the last reference (DocumentView does this in
/// `onDisappear` and when the URL changes). `deinit` keeps a best-effort
/// backstop, but explicit cancel is what guarantees `source` is only
/// ever touched from the main actor.
///
/// `@unchecked Sendable`: all reads/writes of `source` happen on the
/// main actor (init from SwiftUI body, cancel from the owner, restart
/// via Task { @MainActor }). Swift's checker can't see that invariant,
/// hence the unchecked annotation.
final class FileWatcher: @unchecked Sendable {
    private let url: URL
    private let onChange: @MainActor () -> Void
    private var source: DispatchSourceFileSystemObject?

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
        _ = start()
    }

    deinit {
        // Best-effort backstop. Owners cancel() explicitly on the main
        // actor; by the time deinit runs, source is normally already nil.
        source?.cancel()
    }

    /// Stop watching and release the file descriptor. Call from the main
    /// actor before dropping the last reference.
    func cancel() {
        source?.cancel()
        source = nil
    }

    @discardableResult
    private func start() -> Bool {
        // O_EVTONLY: file descriptor that delivers vnode events without
        // counting as an open for read or write — won't conflict with
        // other apps holding the file open.
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return false }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )

        let callback = onChange
        src.setEventHandler { [weak self] in
            let events = src.data
            let needsRestart = events.contains(.delete) || events.contains(.rename)

            Task { @MainActor in
                callback()
            }

            if needsRestart {
                // Route the restart through the MainActor executor (not a
                // bare GCD block) so `source` mutation stays on the same
                // executor as start()/cancel().
                Task { @MainActor [weak self] in
                    await self?.restartWithRetry()
                }
            }
        }
        src.setCancelHandler {
            close(fd)
        }
        source = src
        src.resume()
        return true
    }

    /// After an atomic rename the new file is usually in place within
    /// milliseconds, but slow writers (large files, git checkout, sync
    /// tools) can take longer — and a genuinely deleted file may come
    /// back moments later. Retry a few times with growing delay before
    /// giving up.
    @MainActor
    private func restartWithRetry() async {
        source?.cancel()
        source = nil
        for delayMs in [50, 250, 1000] {
            try? await Task.sleep(for: .milliseconds(delayMs))
            if start() { return }
        }
        // File never reappeared. The watcher is dormant; the owner
        // recreates it if the document's URL changes.
    }
}

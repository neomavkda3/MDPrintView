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
/// `.rename` event flags and re-`open(2)` the path after a short delay
/// so the watcher continues firing for subsequent edits.
///
/// `@unchecked Sendable`: the dispatch source's event handler runs on
/// `.main`, and `start`/`restart` are only invoked from main, so all
/// reads/writes of `source` happen on a single thread. Swift's strict
/// concurrency checker can't see that, hence the unchecked annotation.
final class FileWatcher: @unchecked Sendable {
    private let url: URL
    private let onChange: @MainActor () -> Void
    private var source: DispatchSourceFileSystemObject?

    init(url: URL, onChange: @escaping @MainActor () -> Void) {
        self.url = url
        self.onChange = onChange
        start()
    }

    deinit {
        source?.cancel()
    }

    private func start() {
        // O_EVTONLY: file descriptor that delivers vnode events without
        // counting as an open for read or write — won't conflict with
        // other apps holding the file open.
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

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
                // Atomic-write window: by the time we get the delete
                // event, the new file is usually already in place. A
                // small delay handles the rare case where it isn't yet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.restart()
                }
            }
        }
        src.setCancelHandler {
            close(fd)
        }
        source = src
        src.resume()
    }

    private func restart() {
        source?.cancel()
        source = nil
        start()
    }
}

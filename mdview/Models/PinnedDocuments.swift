import Foundation
import AppKit

/// Persists the user's pinned welcome-screen documents using
/// security-scoped bookmarks so pins survive across launches even in the
/// sandboxed App Store build.
///
/// Notes for the sandboxed Release build:
/// - The `com.apple.security.files.user-selected.read-write` entitlement
///   covers any URL the user explicitly opened, so `.withSecurityScope`
///   bookmarks created from `NSDocumentController.recentDocumentURLs` are
///   resolvable on next launch.
/// - We do NOT call `startAccessingSecurityScopedResource()` here — when
///   the user clicks a pinned card we hand the URL to
///   `NSDocumentController.openDocument(withContentsOf:)`, which manages
///   sandbox access for us.
@MainActor
final class PinnedDocuments {
    static let shared = PinnedDocuments()

    private(set) var urls: [URL] = []
    private let storageKey = "pinnedBookmarks"

    private init() {
        load()
    }

    private func load() {
        guard let bookmarks = UserDefaults.standard.array(forKey: storageKey) as? [Data] else { return }
        var resolved: [URL] = []
        var didDropStale = false
        for data in bookmarks {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                resolved.append(url)
                if stale { didDropStale = true }
            } else {
                didDropStale = true
            }
        }
        urls = resolved
        // Re-save so we drop stale / unresolvable entries on next read.
        if didDropStale { save() }
    }

    private func save() {
        let bookmarks: [Data] = urls.compactMap {
            try? $0.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        UserDefaults.standard.set(bookmarks, forKey: storageKey)
    }

    func toggle(_ url: URL) {
        if let idx = urls.firstIndex(of: url) {
            urls.remove(at: idx)
        } else {
            urls.append(url)
        }
        save()
    }

    func contains(_ url: URL) -> Bool {
        urls.contains(url)
    }
}

import Foundation
import AppKit

/// Persists the user's pinned welcome-screen documents using
/// security-scoped bookmarks so pins survive across launches.
///
/// Resilience policy: a bookmark that fails to resolve is NOT discarded.
/// Resolution can fail transiently — the file lives on an unmounted
/// external drive, a network share that's offline, an iCloud item that's
/// been evicted. We keep the original bookmark data and retry on next
/// launch; the pin simply doesn't appear in `urls` until it resolves.
/// (The previous implementation rewrote storage from resolved URLs only,
/// which permanently destroyed pins after a single bad launch.)
///
/// Sandbox note for a future sandboxed build: regenerating bookmark data
/// with `.withSecurityScope` requires an active security scope on the
/// URL. We therefore only regenerate data for entries that resolved
/// *stale*, and keep the original data if regeneration throws.
@MainActor
final class PinnedDocuments {
    static let shared = PinnedDocuments()

    /// One entry per pin: the persisted bookmark plus its resolved URL
    /// (nil while unresolvable, e.g. volume not mounted).
    private var entries: [(data: Data, url: URL?)] = []
    private let storageKey = "pinnedBookmarks"

    /// Pins that currently resolve, in user-pin order.
    var urls: [URL] {
        entries.compactMap(\.url)
    }

    private init() {
        load()
    }

    private func load() {
        guard let bookmarks = UserDefaults.standard.array(forKey: storageKey) as? [Data] else { return }
        var needsSave = false
        entries = bookmarks.map { data in
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else {
                // Keep the bookmark; it may resolve on a future launch.
                return (data: data, url: nil)
            }
            if stale, let fresh = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                needsSave = true
                return (data: fresh, url: url)
            }
            return (data: data, url: url)
        }
        if needsSave { save() }
    }

    private func save() {
        UserDefaults.standard.set(entries.map(\.data), forKey: storageKey)
    }

    func toggle(_ url: URL) {
        if let idx = entries.firstIndex(where: { $0.url == url }) {
            entries.remove(at: idx)
        } else if let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            entries.append((data: data, url: url))
        }
        save()
    }

    func contains(_ url: URL) -> Bool {
        entries.contains { $0.url == url }
    }
}

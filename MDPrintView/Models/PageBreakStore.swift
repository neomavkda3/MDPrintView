import Foundation
import Observation

/// A user-placed page break, anchored after a top-level markdown block.
/// Session-only: markdown has no page-break concept, so breaks are never
/// written to the document or persisted — they live for the lifetime of the
/// document window and are gone when it closes.
struct PageBreak: Codable, Equatable {
    /// Break sits AFTER the top-level block at this index.
    var afterBlock: Int
    /// Identity of that block's text, used to re-find it when edits shift
    /// indices. See `fingerprint(of:)`.
    var fingerprint: String

    /// Whitespace-collapsed, trimmed, 64-char prefix. Stable across
    /// reflows/indentation changes; cheap to compare.
    static func fingerprint(of text: String) -> String {
        let collapsed = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String(collapsed.prefix(64))
    }
}

/// Message from the preview pane's pagebreak.js.
enum PageBreakAction {
    case add(after: Int)
    case remove(after: Int)
}

/// In-memory page breaks for one document window. Intentionally NOT
/// persisted anywhere (no UserDefaults, no sidecar): print layout is a
/// per-session decision made just before ⌘P / PDF export.
@MainActor
@Observable
final class PageBreakStore {
    private(set) var breaks: [PageBreak] = []

    func add(afterBlock: Int, fingerprint: String) {
        guard !breaks.contains(where: { $0.afterBlock == afterBlock }) else { return }
        breaks.append(PageBreak(afterBlock: afterBlock, fingerprint: fingerprint))
    }

    func remove(afterBlock: Int) {
        breaks.removeAll { $0.afterBlock == afterBlock }
    }

    /// Re-anchor stored breaks against the current document's block
    /// fingerprints. Per break: nearest fingerprint match wins; else the
    /// stored index if still valid (covers "preceding block was edited");
    /// else dropped. Deduped. Resolved anchors are written back so they
    /// track the document as it is edited.
    func resolve(against fingerprints: [String]) -> Set<Int> {
        var resolved = Set<Int>()
        for brk in breaks {
            let matches = fingerprints.indices.filter { fingerprints[$0] == brk.fingerprint }
            if let nearest = matches.min(by: { abs($0 - brk.afterBlock) < abs($1 - brk.afterBlock) }) {
                resolved.insert(nearest)
            } else if brk.afterBlock < fingerprints.count {
                resolved.insert(brk.afterBlock)
            }
            // else: orphan, dropped
        }
        breaks = resolved.sorted().map {
            PageBreak(afterBlock: $0, fingerprint: fingerprints[$0])
        }
        return resolved
    }
}

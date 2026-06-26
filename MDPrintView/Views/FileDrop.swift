import Foundation
import AppKit
import UniformTypeIdentifiers

/// Drag-and-drop file handling shared across the app (Welcome window and
/// document windows). Decides what can be opened and opens it as a document.
/// Mirrors `MarkdownDocument.readableContentTypes` ([.markdown, .plainText]).
enum FileDrop {

    /// True when `type` conforms to one of the app's readable content types.
    /// `net.daringfireball.markdown` conforms to `public.plain-text`, so the
    /// `.plainText` branch also covers markdown and any source/text subtype —
    /// identical to what the Open panel allows.
    static func accepts(_ type: UTType) -> Bool {
        type.conforms(to: .markdown) || type.conforms(to: .plainText)
    }

    /// True when the file at `url` resolves to an acceptable content type.
    /// Unknown / extensionless files resolve to `public.data` and are rejected,
    /// the same outcome as the Open panel. No content sniffing.
    static func accepts(_ url: URL) -> Bool {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        else { return false }
        return accepts(type)
    }

    /// All file URLs on a pasteboard, unfiltered. Empty ⇒ not a file drag (e.g.
    /// text selected in another app). Lets callers tell a "file drag, but
    /// unsupported type" apart from a "non-file drag".
    static func fileURLs(in pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }

    /// Openable file URLs on a pasteboard — `fileURLs` filtered by `accepts`.
    /// Works on a drag pasteboard (`NSPasteboard(name: .drag)`) or a drop
    /// sender's `draggingPasteboard`.
    static func openableURLs(in pasteboard: NSPasteboard) -> [URL] {
        fileURLs(in: pasteboard).filter(accepts)
    }

    /// Open `url` as a document. With the windows' `tabbingMode = .preferred`,
    /// additional documents join the existing window as tabs; an already-open
    /// file is just focused (NSDocumentController dedupes by URL). `completion`
    /// runs on the main actor after the open is requested (openDocument's
    /// completion handler is not guaranteed to run on the main thread).
    @MainActor
    static func open(_ url: URL, then completion: (@MainActor () -> Void)? = nil) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in
            guard let completion else { return }
            Task { @MainActor in completion() }
        }
    }
}

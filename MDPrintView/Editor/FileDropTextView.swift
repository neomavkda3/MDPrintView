import AppKit
import UniformTypeIdentifiers

/// NSTextView that opens dropped markdown/text files as document tabs instead
/// of inserting them as text.
///
/// Three cases:
/// - openable file drag → open as tab(s).
/// - file drag, unsupported type (e.g. .png) → reject WITHOUT calling super, so
///   the file is not inserted as text.
/// - non-file drag (selected text) → defer to super, so text move/insert works.
final class FileDropTextView: NSTextView {
    private func isFileDrag(_ sender: any NSDraggingInfo) -> Bool {
        !FileDrop.fileURLs(in: sender.draggingPasteboard).isEmpty
    }
    private func openable(_ sender: any NSDraggingInfo) -> [URL] {
        FileDrop.openableURLs(in: sender.draggingPasteboard)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard isFileDrag(sender) else { return super.draggingEntered(sender) }
        return openable(sender).isEmpty ? [] : .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard isFileDrag(sender) else { return super.draggingUpdated(sender) }
        return openable(sender).isEmpty ? [] : .copy
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard isFileDrag(sender) else { return super.prepareForDragOperation(sender) }
        return !openable(sender).isEmpty
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard isFileDrag(sender) else { return super.performDragOperation(sender) }
        let urls = openable(sender)
        guard !urls.isEmpty else { return false }   // unsupported file: consume, do nothing
        urls.forEach { FileDrop.open($0) }
        return true
    }
}

import WebKit
import AppKit
import UniformTypeIdentifiers

/// WKWebView that opens dropped markdown/text files as document tabs and
/// prevents a dropped file from navigating the preview away from the bundled
/// template.
///
/// Three cases (same as FileDropTextView):
/// - openable file drag → open as tab(s).
/// - file drag, unsupported type (e.g. .png) → reject WITHOUT super, so WebKit
///   does not navigate to the file.
/// - non-file drag → defer to super (WebKit's normal handling).
final class FileDropWebView: WKWebView {
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

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
        guard !urls.isEmpty else { return false }   // unsupported file: consume, no navigation
        urls.forEach { FileDrop.open($0) }
        return true
    }
}

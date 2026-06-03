import SwiftUI
import WebKit

@MainActor
@Observable
final class PreviewPrintController {
    weak var webView: WKWebView?

    func printPreview() {
        guard let webView, let window = webView.window else { return }
        let info = NSPrintInfo.shared
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    func exportPDF() {
        guard let webView, let window = webView.window else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        let baseName = window.title.isEmpty ? "document" : window.title
        let stripped = (baseName as NSString).deletingPathExtension
        savePanel.nameFieldStringValue = "\(stripped).pdf"
        savePanel.beginSheetModal(for: window) { [weak webView] response in
            guard response == .OK,
                  let url = savePanel.url,
                  let webView,
                  let window = webView.window else { return }
            let info = NSPrintInfo()
            info.jobDisposition = .save
            info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
            info.topMargin = 54
            info.bottomMargin = 54
            info.leftMargin = 54
            info.rightMargin = 54
            let operation = webView.printOperation(with: info)
            operation.showsPrintPanel = false
            operation.showsProgressPanel = false
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        }
    }
}

struct PrintPreviewFocusKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ExportPDFFocusKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var printPreview: PrintPreviewFocusKey.Value? {
        get { self[PrintPreviewFocusKey.self] }
        set { self[PrintPreviewFocusKey.self] = newValue }
    }

    var exportPDF: ExportPDFFocusKey.Value? {
        get { self[ExportPDFFocusKey.self] }
        set { self[ExportPDFFocusKey.self] = newValue }
    }
}

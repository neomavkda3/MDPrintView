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
}

struct PrintPreviewFocusKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var printPreview: PrintPreviewFocusKey.Value? {
        get { self[PrintPreviewFocusKey.self] }
        set { self[PrintPreviewFocusKey.self] = newValue }
    }
}

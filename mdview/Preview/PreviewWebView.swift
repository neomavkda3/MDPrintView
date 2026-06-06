import SwiftUI
import WebKit

enum PreviewMode: String, CaseIterable, Identifiable {
    case screen
    case print

    var id: String { rawValue }

    var label: String {
        switch self {
        case .screen: return "Screen"
        case .print: return "Print"
        }
    }
}

struct PreviewWebView: NSViewRepresentable {
    let html: String
    let mode: PreviewMode
    let printController: PreviewPrintController

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator

        context.coordinator.pendingHTML = html
        context.coordinator.pendingMode = mode
        printController.webView = webView
        loadTemplate(in: webView)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.templateReady {
            Self.inject(html: html, mode: mode, into: webView)
        } else {
            context.coordinator.pendingHTML = html
            context.coordinator.pendingMode = mode
        }
    }

    private func loadTemplate(in webView: WKWebView) {
        guard let url = Bundle.main.url(forResource: "preview", withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    fileprivate static func inject(html: String, mode: PreviewMode, into webView: WKWebView) {
        let escaped = escape(html)
        let cls = mode.rawValue
        let js = """
        document.body.className = '\(cls)';
        document.getElementById('content').innerHTML = `\(escaped)`;
        if (window.mermaid) {
            try {
                window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: document.body.classList.contains('dark') ? 'dark' : 'default' });
                window.mermaid.run({ querySelector: 'code.language-mermaid' });
            } catch(e) { console.error('Mermaid render failed:', e); }
        }
        """
        webView.evaluateJavaScript(js)
    }

    fileprivate static func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var pendingHTML: String = ""
        var pendingMode: PreviewMode = .screen
        var templateReady: Bool = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            templateReady = true
            PreviewWebView.inject(html: pendingHTML, mode: pendingMode, into: webView)
        }
    }
}

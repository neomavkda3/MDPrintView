import SwiftUI
import WebKit

struct PreviewWebView: NSViewRepresentable {
    let html: String

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
        loadTemplate(in: webView)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.templateReady {
            inject(html: html, into: webView)
        } else {
            context.coordinator.pendingHTML = html
        }
    }

    private func loadTemplate(in webView: WKWebView) {
        guard let url = Bundle.main.url(forResource: "preview", withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    fileprivate static func inject(html: String, into webView: WKWebView) {
        let escaped = escape(html)
        webView.evaluateJavaScript("setBody(`\(escaped)`);")
    }

    fileprivate static func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    private func inject(html: String, into webView: WKWebView) {
        Self.inject(html: html, into: webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var pendingHTML: String = ""
        var templateReady: Bool = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            templateReady = true
            PreviewWebView.inject(html: pendingHTML, into: webView)
        }
    }
}

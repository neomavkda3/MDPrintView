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

enum PreviewTheme: String, CaseIterable, Identifiable {
    case original
    case sepia
    case quiet
    case focus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return "Original"
        case .sepia: return "Sepia"
        case .quiet: return "Quiet"
        case .focus: return "Focus"
        }
    }
}

struct PreviewWebView: NSViewRepresentable {
    let html: String
    let mode: PreviewMode
    let theme: PreviewTheme
    let printController: PreviewPrintController

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        // Enable right-click Inspect Element in Debug builds for diagnosing
        // preview-pane render issues. Public property since macOS 13.3.
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif
        webView.navigationDelegate = context.coordinator

        context.coordinator.pendingHTML = html
        context.coordinator.pendingMode = mode
        context.coordinator.pendingTheme = theme
        printController.webView = webView
        loadTemplate(in: webView)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.templateReady {
            Self.inject(html: html, mode: mode, theme: theme, into: webView)
        } else {
            context.coordinator.pendingHTML = html
            context.coordinator.pendingMode = mode
            context.coordinator.pendingTheme = theme
        }
    }

    private func loadTemplate(in webView: WKWebView) {
        guard let url = Bundle.main.url(forResource: "preview", withExtension: "html") else {
            print("[MDPrintView.preview] FAIL: preview.html not in Bundle.main — resources not bundled?")
            return
        }
        print("[MDPrintView.preview] loading template at:", url.path)
        let navigation = webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        if navigation == nil {
            print("[MDPrintView.preview] FAIL: loadFileURL returned nil — load not initiated")
        } else {
            print("[MDPrintView.preview] loadFileURL returned non-nil navigation; waiting for delegate callback")
        }
    }

    fileprivate static func inject(html: String, mode: PreviewMode, theme: PreviewTheme, into webView: WKWebView) {
        let escaped = escape(html)
        let cls = "\(mode.rawValue) theme-\(theme.rawValue)"

        // Step 1: setBody and class swap. Each statement wrapped in its own
        // try/catch so a failure in either doesn't block the other or block
        // the subsequent KaTeX/Mermaid passes.
        let setBodyJS = """
        try { document.body.className = '\(cls)'; } catch(e) { console.error('class swap failed:', e); }
        try { document.getElementById('content').innerHTML = `\(escaped)`; } catch(e) { console.error('innerHTML failed:', e, 'first 200 chars:', `\(escaped)`.slice(0, 200)); }
        """
        webView.evaluateJavaScript(setBodyJS) { _, error in
            if let error { print("[MDPrintView] setBody evaluateJavaScript error:", error) }
        }

        // Step 2: math + diagram rendering. Independent — even if both fail,
        // the rendered HTML from Step 1 is already on screen.
        let renderJS = """
        if (window.renderMathInElement) {
            try {
                window.renderMathInElement(document.getElementById('content'), {
                    delimiters: [
                        { left: '$$', right: '$$', display: true },
                        { left: '$', right: '$', display: false },
                        { left: '\\\\(', right: '\\\\)', display: false },
                        { left: '\\\\[', right: '\\\\]', display: true }
                    ],
                    throwOnError: false
                });
            } catch(e) { console.error('KaTeX render failed:', e); }
        }
        if (window.mermaid) {
            try {
                window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: document.body.classList.contains('theme-focus') ? 'dark' : 'default' });
                window.mermaid.run({ querySelector: 'code.language-mermaid' });
            } catch(e) { console.error('Mermaid render failed:', e); }
        }
        // Terminate with a bridgeable value so evaluateJavaScript's completion
        // handler doesn't report WKErrorDomain Code=5 ("unsupported type") on
        // mermaid.run()'s Promise return value.
        null;
        """
        webView.evaluateJavaScript(renderJS) { _, error in
            if let error { print("[MDPrintView] render evaluateJavaScript error:", error) }
        }
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
        var pendingTheme: PreviewTheme = .original
        var templateReady: Bool = false

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("[MDPrintView.preview] didStartProvisionalNavigation — URL=\(webView.url?.absoluteString ?? "nil")")
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            print("[MDPrintView.preview] didCommit — URL=\(webView.url?.absoluteString ?? "nil")")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[MDPrintView.preview] template loaded — URL=\(webView.url?.absoluteString ?? "nil")")
            templateReady = true
            // Confirm the template structure we expect actually exists before we
            // hand HTML to it. If `#content` is missing, log instead of failing
            // silently — saves users from staring at an empty preview.
            webView.evaluateJavaScript("!!document.getElementById('content')") { result, error in
                if let error {
                    print("[MDPrintView.preview] DOM probe failed:", error)
                }
                print("[MDPrintView.preview] #content element present:", result ?? "nil")
            }
            PreviewWebView.inject(html: pendingHTML, mode: pendingMode, theme: pendingTheme, into: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[MDPrintView.preview] navigation failed:", error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("[MDPrintView.preview] provisional navigation failed:", error)
        }
    }
}

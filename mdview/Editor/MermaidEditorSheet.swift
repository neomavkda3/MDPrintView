import SwiftUI
import WebKit

struct MermaidEditorSheet: View {
    let initialSource: String
    let onApply: (String) -> Void
    let onCancel: () -> Void

    @State private var draft: String

    init(initialSource: String, onApply: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.initialSource = initialSource
        self.onApply = onApply
        self.onCancel = onCancel
        self._draft = State(initialValue: initialSource)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Mermaid Diagram").font(.headline)
                Spacer()
            }
            .padding()

            HSplitView {
                MermaidSourceView(text: $draft)
                    .frame(minWidth: 280)

                MermaidLivePreview(source: draft)
                    .frame(minWidth: 280)
            }
            .frame(minHeight: 360)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.escape)
                Button("Apply") { onApply(draft) }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

private struct MermaidSourceView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.textContainerInset = NSSize(width: 10, height: 10)
        tv.string = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        if tv.string != text { tv.string = text }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
        }
    }
}

private struct MermaidLivePreview: NSViewRepresentable {
    let source: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        loadTemplate(into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        render(source, into: webView)
    }

    private func loadTemplate(into webView: WKWebView) {
        guard let url = Bundle.main.url(forResource: "preview", withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func render(_ source: String, into webView: WKWebView) {
        // We escape the source for safe injection into a template literal, then
        // let Mermaid handle HTML escaping for the displayed diagram text.
        let escaped = source
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        let js = """
        const raw = `\(escaped)`;
        const html = raw.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        document.getElementById('content').innerHTML = '<pre><code class="language-mermaid">' + html + '</code></pre>';
        if (window.mermaid) {
            try {
                window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict' });
                window.mermaid.run({ querySelector: 'code.language-mermaid' });
            } catch(e) { console.error(e); }
        }
        """
        webView.evaluateJavaScript(js)
    }
}

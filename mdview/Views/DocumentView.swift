import SwiftUI

struct DocumentView: View {
    @Bindable var document: MarkdownDocument

    private static let renderer = MarkdownRenderer()

    var body: some View {
        HSplitView {
            MarkdownTextView(text: $document.text)
                .frame(minWidth: 320)

            PreviewWebView(html: Self.renderer.renderHTML(from: document.text))
                .frame(minWidth: 320)
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}

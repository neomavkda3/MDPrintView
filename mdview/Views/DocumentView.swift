import SwiftUI

struct DocumentView: View {
    @Bindable var document: MarkdownDocument
    @State private var render = RenderState()
    @State private var printController = PreviewPrintController()

    var body: some View {
        HSplitView {
            MarkdownTextView(text: $document.text)
                .frame(minWidth: 320)

            PreviewWebView(html: render.html, printController: printController)
                .frame(minWidth: 320)
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            render.renderNow(document.text)
        }
        .onChange(of: document.text) { _, newValue in
            render.schedule(newValue)
        }
        .focusedSceneValue(\.printPreview, printController.printPreview)
    }
}

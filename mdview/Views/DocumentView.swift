import SwiftUI

struct DocumentView: View {
    @Bindable var document: MarkdownDocument
    @State private var render = RenderState()
    @State private var printController = PreviewPrintController()
    @State private var editor = EditorController()
    @State private var outline: [OutlineNode] = []

    var body: some View {
        NavigationSplitView {
            OutlineSidebar(nodes: outline)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            HSplitView {
                MarkdownTextView(text: $document.text, controller: editor)
                    .frame(minWidth: 320)

                PreviewWebView(html: render.html, printController: printController)
                    .frame(minWidth: 320)
            }
            .frame(minWidth: 720, minHeight: 480)
        }
        .onAppear {
            render.renderNow(document.text)
            outline = Outline.extract(from: document.text)
        }
        .onChange(of: document.text) { _, newValue in
            render.schedule(newValue)
            outline = Outline.extract(from: newValue)
        }
        .focusedSceneValue(\.printPreview, printController.printPreview)
        .toolbar { EditorToolbar(controller: editor) }
    }
}

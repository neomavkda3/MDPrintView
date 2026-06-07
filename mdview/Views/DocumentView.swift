import SwiftUI

struct DocumentView: View {
    @Bindable var document: MarkdownDocument
    @Environment(AppSettings.self) private var settings
    @State private var render = RenderState()
    @State private var printController = PreviewPrintController()
    @State private var editor = EditorController()
    @State private var outline: [OutlineNode] = []
    @State private var previewMode: PreviewMode = .screen
    @State private var previewTheme: PreviewTheme = .original
    @State private var editorMode: EditorMode = .source

    var body: some View {
        NavigationSplitView {
            OutlineSidebar(nodes: outline)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            HSplitView {
                MarkdownTextView(text: $document.text, controller: editor, mode: editorMode, editorFontSize: CGFloat(settings.editorFontSize), editorFontFamily: settings.editorFontFamily)
                    .frame(minWidth: 320)

                VStack(spacing: 0) {
                    HStack {
                        Spacer(minLength: 0)
                        Picker("", selection: $previewMode) {
                            ForEach(PreviewMode.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 200)

                        Menu {
                            Picker("Theme", selection: $previewTheme) {
                                ForEach(PreviewTheme.allCases) { Text($0.label).tag($0) }
                            }
                        } label: {
                            Image(systemName: "paintpalette")
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 36)
                        .help("Reading theme")
                        .accessibilityLabel("Reading theme")
                        .accessibilityIdentifier("preview.theme")

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .background(.bar)

                    PreviewWebView(html: render.html, mode: previewMode, theme: previewTheme, printController: printController)
                }
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
        .focusedSceneValue(\.exportPDF, printController.exportPDF)
        .toolbar { EditorToolbar(controller: editor, mode: $editorMode) }
        .sheet(item: Binding(
            get: { editor.editingMermaidBlock },
            set: { editor.editingMermaidBlock = $0 }
        )) { block in
            MermaidEditorSheet(
                initialSource: block.code,
                onApply: { newCode in editor.applyMermaidEdit(newCode) },
                onCancel: { editor.cancelMermaidEdit() }
            )
        }
    }
}

import SwiftUI

struct DocumentView: View {
    @Bindable var document: MarkdownDocument
    /// nil for an untitled (unsaved) document — we only file-watch once
    /// the user has saved and SwiftUI hands us a URL.
    let fileURL: URL?
    @Environment(AppSettings.self) private var settings
    @State private var render = RenderState()
    @State private var printController = PreviewPrintController()
    @State private var editor = EditorController()
    @State private var outline: [OutlineNode] = []
    @State private var previewMode: PreviewMode = .screen
    @State private var previewTheme: PreviewTheme = .original
    @State private var editorMode: EditorMode = .source
    /// Owned per-document. Recreated when fileURL changes; deallocated
    /// when the view goes away (deinit removes the file presenter).
    @State private var fileWatcher: FileWatcher?

    var body: some View {
        @Bindable var settings = settings

        NavigationSplitView {
            OutlineSidebar(nodes: outline)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            HSplitView {
                if settings.defaultLayoutMode.showsEditor {
                    MarkdownTextView(
                        text: $document.text,
                        controller: editor,
                        mode: editorMode,
                        editorFontSize: CGFloat(settings.editorFontSize),
                        editorFontFamily: settings.editorFontFamily
                    )
                    .frame(minWidth: 320)
                }

                if settings.defaultLayoutMode.showsPreview {
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

                        PreviewWebView(
                            html: render.html,
                            mode: previewMode,
                            theme: previewTheme,
                            printController: printController
                        )
                    }
                    .frame(minWidth: 320)
                }
            }
            .frame(minWidth: 480, minHeight: 480)
        }
        .background(WindowAccessor { window in
            // Force tabbing so additional documents open as tabs of the
            // existing MDPrintView window instead of separate windows.
            window.tabbingMode = .preferred
            // First time we see a doc window, offer to set MDPrintView as the
            // default Markdown handler if it isn't already.
            DefaultAppCoordinator.checkAndPrompt(in: window, settings: settings)
        })
        .onAppear {
            render.renderNow(document.text)
            outline = Outline.extract(from: document.text)
        }
        .onChange(of: document.text) { _, newValue in
            render.schedule(newValue)
            outline = Outline.extract(from: newValue)
        }
        // Live external-edit watching: when a file URL is attached (i.e.
        // the doc has been saved), spin up a FileWatcher. If the URL
        // changes (Save As…), tear the old one down and start a new one.
        .onChange(of: fileURL, initial: true) { _, newURL in
            fileWatcher?.cancel()
            guard let url = newURL else {
                fileWatcher = nil
                return
            }
            fileWatcher = FileWatcher(url: url) {
                reloadFromDiskIfChanged(url: url)
            }
        }
        .onDisappear {
            // Explicit main-actor teardown — @State deinit alone can run
            // off-main during document teardown, racing the watcher's
            // dispatch source.
            fileWatcher?.cancel()
            fileWatcher = nil
        }
        .focusedSceneValue(\.printPreview, printController.printPreview)
        .focusedSceneValue(\.exportPDF, printController.exportPDF)
        .toolbar {
            EditorToolbar(controller: editor, mode: $editorMode, layoutMode: $settings.defaultLayoutMode)
        }
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

    /// Re-read the file and adopt the disk content only when it represents
    /// a genuine external change. Three guards, in order:
    ///
    /// 1. disk == editor text          → nothing changed; no-op.
    /// 2. disk == lastSavedText        → this event is our OWN save landing
    ///    (the atomic rename fires the watcher). The editor may already
    ///    have newer keystrokes; adopting disk here would eat them.
    /// 3. editor != lastSavedText      → user has unsaved in-app edits AND
    ///    something external also wrote the file. Conflict. We protect the
    ///    user's typing and skip; their next save wins (last-write).
    ///
    /// Only when none of those hold (editor is clean, disk is genuinely
    /// newer) do we reload — the "viewing while editing externally" flow.
    private func reloadFromDiskIfChanged(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let diskText = String(data: data, encoding: .utf8) else { return }
        guard diskText != document.text else { return }
        guard diskText != document.lastSavedText else { return }
        guard document.text == document.lastSavedText else { return }
        document.text = diskText
        document.lastSavedText = diskText
    }
}

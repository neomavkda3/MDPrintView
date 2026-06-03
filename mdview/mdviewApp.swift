import SwiftUI

@main
struct MdviewApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            DocumentView(document: file.document)
        }
        .commands {
            CommandGroup(replacing: .printItem) {
                PrintMenuItem()
                ExportPDFMenuItem()
            }
        }
    }
}

private struct PrintMenuItem: View {
    @FocusedValue(\.printPreview) private var printAction

    var body: some View {
        Button("Print…") { printAction?() }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(printAction == nil)
    }
}

private struct ExportPDFMenuItem: View {
    @FocusedValue(\.exportPDF) private var exportAction

    var body: some View {
        Button("Export as PDF…") { exportAction?() }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(exportAction == nil)
    }
}

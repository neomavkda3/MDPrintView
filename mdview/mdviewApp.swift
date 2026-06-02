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

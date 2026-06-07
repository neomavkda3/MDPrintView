import SwiftUI

struct EditorToolbar: ToolbarContent {
    let controller: EditorController
    @Binding var mode: EditorMode

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Picker("Mode", selection: $mode) {
                ForEach(EditorMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .help("Editor mode")
            .accessibilityLabel("Editor mode")
            .accessibilityIdentifier("toolbar.mode")
        }

        ToolbarItemGroup(placement: .principal) {
            Button { controller.toggleBold() } label: { Image(systemName: "bold") }
                .keyboardShortcut("b", modifiers: .command)
                .help("Bold")
                .accessibilityLabel("Bold")
                .accessibilityIdentifier("toolbar.bold")
            Button { controller.toggleItalic() } label: { Image(systemName: "italic") }
                .keyboardShortcut("i", modifiers: .command)
                .help("Italic")
                .accessibilityLabel("Italic")
                .accessibilityIdentifier("toolbar.italic")
            Button { controller.toggleStrike() } label: { Image(systemName: "strikethrough") }
                .help("Strikethrough")
                .accessibilityLabel("Strikethrough")
                .accessibilityIdentifier("toolbar.strike")

            Divider()

            Menu {
                Button("Heading 1") { controller.toggleHeading(level: 1) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Heading 2") { controller.toggleHeading(level: 2) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Heading 3") { controller.toggleHeading(level: 3) }
                    .keyboardShortcut("3", modifiers: .command)
            } label: {
                Image(systemName: "textformat.size")
            }
            .help("Heading level")
            .accessibilityLabel("Heading level")
            .accessibilityIdentifier("toolbar.heading")

            Button { controller.insertLink() } label: { Image(systemName: "link") }
                .keyboardShortcut("k", modifiers: .command)
                .help("Insert link")
                .accessibilityLabel("Insert link")
                .accessibilityIdentifier("toolbar.link")

            Divider()

            Menu {
                Button("Bullet list") { controller.insertBullet() }
                Button("Numbered list") { controller.insertNumbered() }
                Button("Task list") { controller.insertTask() }
            } label: {
                Image(systemName: "list.bullet.indent")
            }
            .help("Lists")
            .accessibilityLabel("Lists")
            .accessibilityIdentifier("toolbar.lists")

            Menu {
                Button("Inline code") { controller.toggleInlineCode() }
                Button("Code block") { controller.insertCodeBlock() }
                Divider()
                Button("Mermaid diagram…") { controller.openMermaidEditor() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
            } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
            }
            .help("Code & diagrams")
            .accessibilityLabel("Code and diagrams")
            .accessibilityIdentifier("toolbar.code")
        }
    }
}

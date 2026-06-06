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

            Divider()

            Button { controller.insertBullet() } label: { Image(systemName: "list.bullet") }
                .help("Bullet list")
                .accessibilityLabel("Bullet list")
                .accessibilityIdentifier("toolbar.bulletList")
            Button { controller.insertNumbered() } label: { Image(systemName: "list.number") }
                .help("Numbered list")
                .accessibilityLabel("Numbered list")
                .accessibilityIdentifier("toolbar.numberedList")
            Button { controller.insertTask() } label: { Image(systemName: "checklist") }
                .help("Task list")
                .accessibilityLabel("Task list")
                .accessibilityIdentifier("toolbar.taskList")

            Divider()

            Button { controller.toggleInlineCode() } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                .help("Inline code")
                .accessibilityLabel("Inline code")
                .accessibilityIdentifier("toolbar.inlineCode")
            Button { controller.insertCodeBlock() } label: { Image(systemName: "curlybraces") }
                .help("Code block")
                .accessibilityLabel("Code block")
                .accessibilityIdentifier("toolbar.codeBlock")
            Button { controller.insertLink() } label: { Image(systemName: "link") }
                .keyboardShortcut("k", modifiers: .command)
                .help("Link")
                .accessibilityLabel("Insert link")
                .accessibilityIdentifier("toolbar.link")
            Button { controller.openMermaidEditor() } label: { Image(systemName: "chart.xyaxis.line") }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .help("Edit Mermaid diagram (inserts skeleton if none at cursor)")
                .accessibilityLabel("Edit Mermaid diagram")
                .accessibilityIdentifier("toolbar.mermaid")
        }
    }
}

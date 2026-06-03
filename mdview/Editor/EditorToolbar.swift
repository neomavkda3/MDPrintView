import SwiftUI

struct EditorToolbar: ToolbarContent {
    let controller: EditorController

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .principal) {
            Button { controller.toggleBold() } label: { Image(systemName: "bold") }
                .keyboardShortcut("b", modifiers: .command)
                .help("Bold")
            Button { controller.toggleItalic() } label: { Image(systemName: "italic") }
                .keyboardShortcut("i", modifiers: .command)
                .help("Italic")
            Button { controller.toggleStrike() } label: { Image(systemName: "strikethrough") }
                .help("Strikethrough")

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

            Divider()

            Button { controller.insertBullet() } label: { Image(systemName: "list.bullet") }
                .help("Bullet list")
            Button { controller.insertNumbered() } label: { Image(systemName: "list.number") }
                .help("Numbered list")
            Button { controller.insertTask() } label: { Image(systemName: "checklist") }
                .help("Task list")

            Divider()

            Button { controller.toggleInlineCode() } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                .help("Inline code")
            Button { controller.insertCodeBlock() } label: { Image(systemName: "curlybraces") }
                .help("Code block")
            Button { controller.insertLink() } label: { Image(systemName: "link") }
                .keyboardShortcut("k", modifiers: .command)
                .help("Link")
            Button { controller.insertMermaid() } label: { Image(systemName: "chart.xyaxis.line") }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .help("Mermaid diagram")
        }
    }
}

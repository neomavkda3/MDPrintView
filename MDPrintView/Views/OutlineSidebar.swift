import SwiftUI

struct OutlineSidebar: View {
    let nodes: [OutlineNode]

    var body: some View {
        if nodes.isEmpty {
            ContentUnavailableView("No headings yet",
                systemImage: "list.bullet.indent",
                description: Text("Add `#`, `##`, or `###` lines to outline this document."))
        } else {
            List {
                OutlineGroup(nodes, children: \.optionalChildren) { node in
                    Text(node.title)
                        .font(.system(size: max(11, 14 - CGFloat(node.level - 1))))
                        .lineLimit(2)
                        .accessibilityLabel("Heading: \(node.title)")
                        .accessibilityHint("Level \(node.level)")
                }
            }
            .listStyle(.sidebar)
            .accessibilityLabel("Document outline")
            .accessibilityIdentifier("sidebar.outline")
        }
    }
}

private extension OutlineNode {
    var optionalChildren: [OutlineNode]? {
        children.isEmpty ? nil : children
    }
}

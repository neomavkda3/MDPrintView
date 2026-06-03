import Foundation
import Markdown

struct OutlineNode: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let level: Int
    var children: [OutlineNode]
}

enum Outline {
    static func extract(from source: String) -> [OutlineNode] {
        let document = Document(parsing: source)
        let flat: [(level: Int, title: String)] = document.children.compactMap { node in
            guard let heading = node as? Heading else { return nil }
            return (heading.level, heading.plainText)
        }
        return nest(flat)
    }

    private static func nest(_ flat: [(level: Int, title: String)]) -> [OutlineNode] {
        var roots: [OutlineNode] = []
        for entry in flat {
            insert(entry, into: &roots)
        }
        return roots
    }

    private static func insert(_ entry: (level: Int, title: String), into parents: inout [OutlineNode]) {
        // If the last sibling is at a shallower level than this entry, descend into its children.
        if let lastIndex = parents.indices.last, parents[lastIndex].level < entry.level {
            var child = parents[lastIndex]
            insert(entry, into: &child.children)
            parents[lastIndex] = child
            return
        }
        parents.append(OutlineNode(title: entry.title, level: entry.level, children: []))
    }
}

import Foundation
import Markdown

struct MermaidBlock {
    let code: String
    let fullRange: NSRange

    static func containing(cursor: Int, in source: String) -> MermaidBlock? {
        let document = Document(parsing: source)
        for node in document.children {
            guard let block = node as? CodeBlock,
                  block.language == "mermaid",
                  let range = nsRange(for: block, in: source) else { continue }
            if cursor >= range.location && cursor <= range.location + range.length {
                return MermaidBlock(code: block.code, fullRange: range)
            }
        }
        return nil
    }

    private static func nsRange(for markup: Markup, in source: String) -> NSRange? {
        guard let range = markup.range else { return nil }
        let start = offset(for: range.lowerBound, in: source)
        let end = offset(for: range.upperBound, in: source)
        guard start >= 0, end >= start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private static func offset(for location: SourceLocation, in source: String) -> Int {
        let lines = source.components(separatedBy: "\n")
        var offset = 0
        let targetLine = max(1, location.line)
        for (i, line) in lines.enumerated() {
            if i + 1 == targetLine {
                let col = max(1, location.column) - 1
                let lineLength = (line as NSString).length
                return offset + min(col, lineLength)
            }
            offset += (line as NSString).length + 1
        }
        return offset
    }
}

extension MermaidBlock: Identifiable {
    var id: Int { fullRange.location }
}

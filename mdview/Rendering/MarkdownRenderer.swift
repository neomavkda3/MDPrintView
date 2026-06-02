import Foundation
import Markdown

struct MarkdownRenderer {
    func renderHTML(from source: String) -> String {
        let document = Document(parsing: source)
        var emitter = HTMLEmitter()
        emitter.visit(document)
        return emitter.output
    }
}

private struct HTMLEmitter: MarkupWalker {
    var output: String = ""

    mutating func visitHeading(_ heading: Heading) {
        output += "<h\(heading.level)>"
        descendInto(heading)
        output += "</h\(heading.level)>"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        output += "<p>"
        descendInto(paragraph)
        output += "</p>"
    }

    mutating func visitText(_ text: Text) {
        output += text.string
    }
}

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

    mutating func visitUnorderedList(_ list: UnorderedList) {
        output += "<ul>"
        descendInto(list)
        output += "</ul>"
    }

    mutating func visitListItem(_ item: ListItem) {
        output += "<li>"
        descendInto(item)
        output += "</li>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        output += "<em>"
        descendInto(emphasis)
        output += "</em>"
    }

    mutating func visitStrong(_ strong: Strong) {
        output += "<strong>"
        descendInto(strong)
        output += "</strong>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        output += "<code>\(inlineCode.code)</code>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        output += "<pre><code>\(codeBlock.code)</code></pre>"
    }

    mutating func visitLink(_ link: Link) {
        let dest = link.destination ?? ""
        output += "<a href=\"\(dest)\">"
        descendInto(link)
        output += "</a>"
    }
}

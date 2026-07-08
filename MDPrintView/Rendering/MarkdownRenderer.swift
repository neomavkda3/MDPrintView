import Foundation
import Markdown

func htmlEscape(_ s: String) -> String {
    var result = ""
    result.reserveCapacity(s.count)
    for ch in s {
        switch ch {
        case "&": result += "&amp;"
        case "<": result += "&lt;"
        case ">": result += "&gt;"
        case "\"": result += "&quot;"
        case "'": result += "&#39;"
        default: result.append(ch)
        }
    }
    return result
}

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
    private var inTableHead: Bool = false

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
        output += htmlEscape(text.string)
    }

    mutating func visitUnorderedList(_ list: UnorderedList) {
        output += "<ul>"
        descendInto(list)
        output += "</ul>"
    }

    mutating func visitListItem(_ item: ListItem) {
        if let checkbox = item.checkbox {
            let attr = checkbox == .checked ? " checked" : ""
            output += "<li><input type=\"checkbox\" disabled\(attr)>"
            descendInto(item)
            output += "</li>"
        } else {
            output += "<li>"
            descendInto(item)
            output += "</li>"
        }
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
        output += "<code>\(htmlEscape(inlineCode.code))</code>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let escapedCode = htmlEscape(codeBlock.code)
        if let lang = codeBlock.language, !lang.isEmpty {
            let escapedLang = htmlEscape(lang)
            output += "<pre><code class=\"language-\(escapedLang)\">\(escapedCode)</code></pre>"
        } else {
            output += "<pre><code>\(escapedCode)</code></pre>"
        }
    }

    mutating func visitLink(_ link: Link) {
        let dest = htmlEscape(link.destination ?? "")
        output += "<a href=\"\(dest)\">"
        descendInto(link)
        output += "</a>"
    }

    mutating func visitImage(_ image: Image) {
        let src = htmlEscape(image.source ?? "")
        let alt = htmlEscape(image.plainText)
        output += "<img src=\"\(src)\" alt=\"\(alt)\">"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        output += htmlEscape(inlineHTML.rawHTML)
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        output += "<blockquote>"
        descendInto(blockQuote)
        output += "</blockquote>"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        output += "<hr>"
    }

    mutating func visitOrderedList(_ list: OrderedList) {
        output += "<ol>"
        descendInto(list)
        output += "</ol>"
    }

    mutating func visitTable(_ table: Table) {
        output += "<table>"
        descendInto(table)
        output += "</table>"
    }

    mutating func visitTableHead(_ head: Table.Head) {
        inTableHead = true
        output += "<thead><tr>"
        descendInto(head)
        output += "</tr></thead>"
        inTableHead = false
    }

    mutating func visitTableBody(_ body: Table.Body) {
        output += "<tbody>"
        descendInto(body)
        output += "</tbody>"
    }

    mutating func visitTableRow(_ row: Table.Row) {
        output += "<tr>"
        descendInto(row)
        output += "</tr>"
    }

    mutating func visitTableCell(_ cell: Table.Cell) {
        if inTableHead {
            output += "<th>"
            descendInto(cell)
            output += "</th>"
        } else {
            output += "<td>"
            descendInto(cell)
            output += "</td>"
        }
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) {
        output += htmlEscape(htmlBlock.rawHTML)
    }
}

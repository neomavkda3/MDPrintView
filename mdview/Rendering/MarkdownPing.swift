import Markdown

enum MarkdownPing {
    static func parses(_ source: String) -> Bool {
        let document = Document(parsing: source)
        return document.childCount >= 0
    }
}

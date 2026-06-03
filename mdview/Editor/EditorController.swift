import AppKit
import SwiftUI

@MainActor
@Observable
final class EditorController {
    weak var textView: NSTextView?

    /// Wrap the current selection (or insert at cursor) with `prefix` and `suffix`.
    /// If selection is empty, inserts `placeholder` between them and reselects the placeholder.
    func wrap(prefix: String, suffix: String, placeholder: String = "") {
        guard let textView, let storage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let nsString = storage.string as NSString
        let selected = nsString.substring(with: range)
        let body = selected.isEmpty ? placeholder : selected
        let replacement = "\(prefix)\(body)\(suffix)"
        storage.replaceCharacters(in: range, with: replacement)
        let newLocation = range.location + (prefix as NSString).length
        let newLength = (body as NSString).length
        textView.setSelectedRange(NSRange(location: newLocation, length: newLength))
        textView.didChangeText()
    }

    /// Prepend `marker` to the start of every line touched by the current selection.
    func prefixLines(with marker: String) {
        guard let textView, let storage = textView.textStorage else { return }
        let selRange = textView.selectedRange()
        let nsString = storage.string as NSString
        let lineRange = nsString.lineRange(for: selRange)
        let block = nsString.substring(with: lineRange)
        let lines = block.components(separatedBy: "\n")
        let prefixed = lines.enumerated().map { i, line in
            (i == lines.count - 1 && line.isEmpty) ? line : "\(marker)\(line)"
        }.joined(separator: "\n")
        storage.replaceCharacters(in: lineRange, with: prefixed)
        textView.setSelectedRange(NSRange(location: lineRange.location, length: (prefixed as NSString).length))
        textView.didChangeText()
    }

    func toggleBold() { wrap(prefix: "**", suffix: "**", placeholder: "bold") }
    func toggleItalic() { wrap(prefix: "*", suffix: "*", placeholder: "italic") }
    func toggleStrike() { wrap(prefix: "~~", suffix: "~~", placeholder: "strike") }
    func toggleInlineCode() { wrap(prefix: "`", suffix: "`", placeholder: "code") }

    func toggleHeading(level: Int) {
        prefixLines(with: String(repeating: "#", count: level) + " ")
    }

    func insertBullet() { prefixLines(with: "- ") }
    func insertNumbered() { prefixLines(with: "1. ") }
    func insertTask() { prefixLines(with: "- [ ] ") }

    func insertLink(url: String = "https://") {
        wrap(prefix: "[", suffix: "](\(url))", placeholder: "link text")
    }

    func insertCodeBlock() {
        wrap(prefix: "```\n", suffix: "\n```", placeholder: "code")
    }

    func insertMermaid() {
        wrap(prefix: "```mermaid\n", suffix: "\n```", placeholder: "graph TD\n  A --> B")
    }
}

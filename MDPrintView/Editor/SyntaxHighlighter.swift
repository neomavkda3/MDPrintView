import AppKit
import Markdown

@MainActor
struct SyntaxHighlighter {
    let baseFontSize: CGFloat
    let fontFamily: EditorFontFamily
    let baseTextColor: NSColor?

    init(baseFontSize: CGFloat = 14,
         fontFamily: EditorFontFamily = .systemMono,
         baseTextColor: NSColor? = nil) {
        self.baseFontSize = baseFontSize
        self.fontFamily = fontFamily
        self.baseTextColor = baseTextColor
    }

    /// Heading sizes derived from base: h1=+8, h2=+5, h3=+3, h4=+1, h5/h6=base.
    private var headingSizes: [CGFloat] {
        [baseFontSize + 8, baseFontSize + 5, baseFontSize + 3, baseFontSize + 1, baseFontSize, baseFontSize]
    }

    func apply(to storage: NSTextStorage) {
        let source = storage.string
        let document = Document(parsing: source)
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.beginEditing()
        defer { storage.endEditing() }

        // Reset to defaults so re-applies are idempotent.
        storage.removeAttribute(.font, range: fullRange)
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.font, value: fontFamily.nsFont(size: baseFontSize), range: fullRange)
        storage.addAttribute(.foregroundColor,
                             value: baseTextColor ?? NSColor.textColor,
                             range: fullRange)

        for markup in document.children {
            apply(markup, to: storage, source: source)
        }
    }

    private func bold(_ font: NSFont) -> NSFont {
        var traits = font.fontDescriptor.symbolicTraits
        traits.insert(.bold)
        let desc = font.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: desc, size: font.pointSize) ?? font
    }

    private func apply(_ markup: Markup, to storage: NSTextStorage, source: String) {
        if let range = nsRange(for: markup, in: source) {
            switch markup {
            case let heading as Heading:
                let sizeIndex = max(0, min(heading.level - 1, headingSizes.count - 1))
                let font = bold(fontFamily.nsFont(size: headingSizes[sizeIndex]))
                storage.addAttribute(.font, value: font, range: range)
            case is InlineCode, is CodeBlock:
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
            case is Link:
                storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            default:
                break
            }
        }

        for child in markup.children {
            apply(child, to: storage, source: source)
        }
    }

    private func nsRange(for markup: Markup, in source: String) -> NSRange? {
        guard let range = markup.range else { return nil }
        let nsString = source as NSString
        let start = offset(for: range.lowerBound, in: source)
        let end = offset(for: range.upperBound, in: source)
        guard start >= 0, end >= start, end <= nsString.length else { return nil }
        return NSRange(location: start, length: end - start)
    }

    /// Convert swift-markdown SourceLocation (1-indexed line, 1-indexed column) to UTF-16 offset
    /// suitable for use in NSRange on the same source string.
    private func offset(for location: SourceLocation, in source: String) -> Int {
        let lines = source.components(separatedBy: "\n")
        var offset = 0
        let targetLine = max(1, location.line)
        for (i, line) in lines.enumerated() {
            if i + 1 == targetLine {
                let col = max(1, location.column) - 1
                let lineLength = (line as NSString).length
                return offset + min(col, lineLength)
            }
            offset += (line as NSString).length + 1 // +1 for the consumed "\n"
        }
        return offset
    }
}

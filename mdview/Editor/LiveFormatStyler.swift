import AppKit
import Markdown

@MainActor
struct LiveFormatStyler {
    private let baseFontSize: CGFloat = 16
    private let headingSizes: [CGFloat] = [28, 22, 18, 16, 16, 16]

    func apply(to storage: NSTextStorage) {
        let source = storage.string
        let document = Document(parsing: source)
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.beginEditing()
        defer { storage.endEditing() }

        storage.removeAttribute(.font, range: fullRange)
        storage.removeAttribute(.foregroundColor, range: fullRange)
        storage.addAttribute(.font, value: bodyFont(), range: fullRange)
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)

        for markup in document.children {
            apply(markup, to: storage, source: source)
        }
    }

    private func bodyFont() -> NSFont {
        NSFont.systemFont(ofSize: baseFontSize, weight: .regular)
    }

    private func headingFont(level: Int) -> NSFont {
        let idx = max(0, min(level - 1, headingSizes.count - 1))
        return NSFont.systemFont(ofSize: headingSizes[idx], weight: .bold)
    }

    private func boldVariant(of font: NSFont) -> NSFont {
        var traits = font.fontDescriptor.symbolicTraits
        traits.insert(.bold)
        let desc = font.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: desc, size: font.pointSize) ?? font
    }

    private func italicVariant(of font: NSFont) -> NSFont {
        var traits = font.fontDescriptor.symbolicTraits
        traits.insert(.italic)
        let desc = font.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: desc, size: font.pointSize) ?? font
    }

    private func monoFont() -> NSFont {
        NSFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .regular)
    }

    private func apply(_ markup: Markup, to storage: NSTextStorage, source: String) {
        if let range = nsRange(for: markup, in: source) {
            switch markup {
            case let heading as Heading:
                storage.addAttribute(.font, value: headingFont(level: heading.level), range: range)
                // Fade leading "# " (or "## ", etc.) — `level` hashes + 1 space.
                let markLen = heading.level + 1
                if range.length >= markLen {
                    let markRange = NSRange(location: range.location, length: markLen)
                    storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: markRange)
                }
            case is Strong:
                storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
                    let font = (value as? NSFont) ?? bodyFont()
                    storage.addAttribute(.font, value: boldVariant(of: font), range: subRange)
                }
                fadeDelimiters(in: storage, range: range, delimiterLength: 2)
            case is Emphasis:
                storage.enumerateAttribute(.font, in: range) { value, subRange, _ in
                    let font = (value as? NSFont) ?? bodyFont()
                    storage.addAttribute(.font, value: italicVariant(of: font), range: subRange)
                }
                fadeDelimiters(in: storage, range: range, delimiterLength: 1)
            case is InlineCode:
                storage.addAttribute(.font, value: monoFont(), range: range)
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
                fadeDelimiters(in: storage, range: range, delimiterLength: 1)
            case is CodeBlock:
                storage.addAttribute(.font, value: monoFont(), range: range)
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
                fadeDelimiters(in: storage, range: range, delimiterLength: 3)
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

    private func fadeDelimiters(in storage: NSTextStorage, range: NSRange, delimiterLength: Int) {
        guard range.length >= delimiterLength * 2 else { return }
        let leading = NSRange(location: range.location, length: delimiterLength)
        let trailing = NSRange(location: range.location + range.length - delimiterLength, length: delimiterLength)
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: leading)
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: trailing)
    }

    private func nsRange(for markup: Markup, in source: String) -> NSRange? {
        guard let range = markup.range else { return nil }
        let nsString = source as NSString
        let start = offset(for: range.lowerBound, in: source)
        let end = offset(for: range.upperBound, in: source)
        guard start >= 0, end >= start, end <= nsString.length else { return nil }
        return NSRange(location: start, length: end - start)
    }

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
            offset += (line as NSString).length + 1
        }
        return offset
    }
}

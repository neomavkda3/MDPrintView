import Testing
import AppKit
@testable import mdview

@Suite("SyntaxHighlighter", .serialized)
@MainActor
struct SyntaxHighlighterTests {

    @Test("h1 gets larger bold font")
    func h1Bold() {
        let storage = NSTextStorage(string: "# Heading\n")
        SyntaxHighlighter().apply(to: storage)
        let attrs = storage.attributes(at: 0, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect((font?.pointSize ?? 0) > 14)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.bold) == true)
    }

    @Test("inline code gets distinct color")
    func inlineCodeColor() {
        let storage = NSTextStorage(string: "use `x` here")
        SyntaxHighlighter().apply(to: storage)
        // "x" is at index 5 (after "use `")
        let attrs = storage.attributes(at: 5, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        #expect(color == .secondaryLabelColor)
    }

    @Test("link gets blue color somewhere in its range")
    func linkColoring() {
        let storage = NSTextStorage(string: "[label](https://example.com)")
        SyntaxHighlighter().apply(to: storage)
        var found: NSColor?
        storage.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if let c = value as? NSColor, c == .linkColor { found = c }
        }
        #expect(found == .linkColor)
    }

    @Test("plain text gets default color and base font")
    func plainTextBaseStyle() {
        let storage = NSTextStorage(string: "hello world")
        SyntaxHighlighter().apply(to: storage)
        let attrs = storage.attributes(at: 0, effectiveRange: nil)
        #expect((attrs[.foregroundColor] as? NSColor) == .textColor)
        let font = attrs[.font] as? NSFont
        #expect(font?.pointSize == 14)
    }

    @Test("custom base font size scales heading sizes")
    func customBaseSize() {
        let storage = NSTextStorage(string: "# Heading\n")
        SyntaxHighlighter(baseFontSize: 18).apply(to: storage)
        let attrs = storage.attributes(at: 0, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        // h1 at base 18 = 18 + 8 = 26
        #expect((font?.pointSize ?? 0) >= 24)
    }

    @Test("system sans font family yields a non-monospaced base font")
    func customFontFamilySans() {
        let storage = NSTextStorage(string: "hello\n")
        SyntaxHighlighter(baseFontSize: 14, fontFamily: .systemSans).apply(to: storage)
        let font = storage.attributes(at: 0, effectiveRange: nil)[.font] as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.monoSpace) == false)
    }
}

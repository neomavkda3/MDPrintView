import Testing
import AppKit
@testable import mdview

@Suite("LiveFormatStyler — E1 (rich inline styling, marks visible)", .serialized)
@MainActor
struct LiveFormatStylerE1Tests {

    @Test("h1 gets a meaningfully larger font than body")
    func h1Larger() {
        let storage = NSTextStorage(string: "# Heading\nbody\n")
        LiveFormatStyler().apply(to: storage)
        let headingFont = storage.attributes(at: 0, effectiveRange: nil)[.font] as? NSFont
        let bodyFont = storage.attributes(at: 10, effectiveRange: nil)[.font] as? NSFont
        let headingSize = headingFont?.pointSize ?? 0
        let bodySize = bodyFont?.pointSize ?? 0
        #expect(headingSize >= bodySize + 4)
    }

    @Test("bold span gets bold font trait")
    func boldTrait() {
        let storage = NSTextStorage(string: "say **bold** word")
        LiveFormatStyler().apply(to: storage)
        // "bold" begins at index 6
        let attrs = storage.attributes(at: 6, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.bold) == true)
    }

    @Test("italic span gets italic font trait")
    func italicTrait() {
        let storage = NSTextStorage(string: "say *em* word")
        LiveFormatStyler().apply(to: storage)
        // "em" begins at index 5
        let attrs = storage.attributes(at: 5, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.italic) == true)
    }

    @Test("inline code uses monospaced font")
    func inlineCodeMono() {
        let storage = NSTextStorage(string: "see `code` text")
        LiveFormatStyler().apply(to: storage)
        // "code" begins at index 5
        let attrs = storage.attributes(at: 5, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        #expect(font?.fontName.contains("Menlo") == true || font?.fontName.contains("Mono") == true)
    }

    @Test("link gets distinct color somewhere in its range")
    func linkColored() {
        let storage = NSTextStorage(string: "[label](https://example.com)")
        LiveFormatStyler().apply(to: storage)
        var found: NSColor?
        storage.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if let c = value as? NSColor, c == .linkColor { found = c }
        }
        #expect(found == .linkColor)
    }
}

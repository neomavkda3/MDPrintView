import Testing
import AppKit
@testable import MDPrintView

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

@Suite("LiveFormatStyler — E2 (faded marks)", .serialized)
@MainActor
struct LiveFormatStylerE2Tests {

    @Test("heading marker # is faded")
    func headingMarkFaded() {
        let storage = NSTextStorage(string: "# Heading\n")
        LiveFormatStyler().apply(to: storage)
        let attrs = storage.attributes(at: 0, effectiveRange: nil)
        #expect((attrs[.foregroundColor] as? NSColor) == .tertiaryLabelColor)
    }

    @Test("bold marker ** is faded on both sides")
    func boldMarksFaded() {
        let storage = NSTextStorage(string: "**bold**")
        LiveFormatStyler().apply(to: storage)
        let leadingMark = storage.attributes(at: 0, effectiveRange: nil)
        #expect((leadingMark[.foregroundColor] as? NSColor) == .tertiaryLabelColor)
        let trailingMark = storage.attributes(at: 7, effectiveRange: nil)
        #expect((trailingMark[.foregroundColor] as? NSColor) == .tertiaryLabelColor)
    }

    @Test("italic marker * is faded")
    func italicMarksFaded() {
        let storage = NSTextStorage(string: "*em*")
        LiveFormatStyler().apply(to: storage)
        let leadingMark = storage.attributes(at: 0, effectiveRange: nil)
        #expect((leadingMark[.foregroundColor] as? NSColor) == .tertiaryLabelColor)
    }
}

@Suite("LiveFormatStyler — E3 (cursor-aware fold)", .serialized)
@MainActor
struct LiveFormatStylerE3Tests {

    private func isHidden(_ color: NSColor?) -> Bool {
        guard let color else { return false }
        if color == .clear { return true }
        return color.alphaComponent == 0
    }

    @Test("bold marks are hidden when cursor outside span")
    func boldHiddenOutside() {
        let storage = NSTextStorage(string: "before **bold** after")
        LiveFormatStyler().apply(to: storage, cursorAt: 0)
        let leadingMark = storage.attributes(at: 7, effectiveRange: nil)
        #expect(isHidden(leadingMark[.foregroundColor] as? NSColor))
    }

    @Test("bold marks are revealed when cursor inside span")
    func boldRevealedInside() {
        let storage = NSTextStorage(string: "before **bold** after")
        LiveFormatStyler().apply(to: storage, cursorAt: 11) // inside "bold"
        let leadingMark = storage.attributes(at: 7, effectiveRange: nil)
        #expect(!isHidden(leadingMark[.foregroundColor] as? NSColor))
    }

    @Test("cursor at mark boundary reveals the mark")
    func cursorAtMarkBoundaryReveals() {
        let storage = NSTextStorage(string: "**bold**")
        LiveFormatStyler().apply(to: storage, cursorAt: 2) // right after the leading **
        let leadingMark = storage.attributes(at: 0, effectiveRange: nil)
        #expect(!isHidden(leadingMark[.foregroundColor] as? NSColor))
    }

    @Test("heading mark hidden when cursor far away")
    func headingMarkHiddenOutside() {
        let storage = NSTextStorage(string: "# Heading\n\nbody text here\n")
        LiveFormatStyler().apply(to: storage, cursorAt: 16) // inside body
        let mark = storage.attributes(at: 0, effectiveRange: nil)
        #expect(isHidden(mark[.foregroundColor] as? NSColor))
    }

    @Test("apply with no cursor falls back to E2 behavior (marks visible faded)")
    func noCursorFallsBackToE2() {
        let storage = NSTextStorage(string: "**bold**")
        LiveFormatStyler().apply(to: storage) // no cursorAt — same as old apply
        let mark = storage.attributes(at: 0, effectiveRange: nil)
        #expect((mark[.foregroundColor] as? NSColor) == .tertiaryLabelColor)
    }
}

import Testing
@testable import MDPrintView

@Suite("HTMLSanitizer")
struct HTMLSanitizerTests {

    @Test("allowed div with align passes through")
    func allowedDivAlign() {
        #expect(HTMLSanitizer.sanitize("<div align=\"center\">x</div>")
                == "<div align=\"center\">x</div>")
    }

    @Test("disallowed tag strips, children kept")
    func disallowedTagKeepsChildren() {
        #expect(HTMLSanitizer.sanitize("<blink>hi</blink>") == "hi")
    }

    @Test("script drops with contents")
    func scriptDropsContents() {
        #expect(HTMLSanitizer.sanitize("<script>evil()</script>after") == "after")
    }

    @Test("style tag drops with contents")
    func styleDropsContents() {
        #expect(HTMLSanitizer.sanitize("<style>*{color:red}</style>") == "")
    }

    @Test("unterminated script drops to end of input")
    func unterminatedScript() {
        #expect(HTMLSanitizer.sanitize("<script>evil(") == "")
    }

    @Test("event handler attribute dropped")
    func eventHandlerDropped() {
        #expect(HTMLSanitizer.sanitize("<div onclick=\"x()\" align=\"c\">")
                == "<div align=\"c\">")
    }

    @Test("style attribute dropped")
    func styleAttrDropped() {
        #expect(HTMLSanitizer.sanitize("<div style=\"color:red\">") == "<div>")
    }

    @Test("javascript: href dropped")
    func javascriptHrefDropped() {
        #expect(HTMLSanitizer.sanitize("<a href=\"javascript:x()\">") == "<a>")
    }

    @Test("obfuscated scheme dropped")
    func obfuscatedSchemeDropped() {
        #expect(HTMLSanitizer.sanitize("<a href=\" JaVa\tscript:x\">") == "<a>")
    }

    @Test("https href kept")
    func httpsHrefKept() {
        #expect(HTMLSanitizer.sanitize("<a href=\"https://x.y\">")
                == "<a href=\"https://x.y\">")
    }

    @Test("relative and anchor hrefs kept")
    func relativeHrefKept() {
        #expect(HTMLSanitizer.sanitize("<a href=\"#top\">") == "<a href=\"#top\">")
        #expect(HTMLSanitizer.sanitize("<a href=\"docs/x.md\">") == "<a href=\"docs/x.md\">")
    }

    @Test("comment stripped")
    func commentStripped() {
        #expect(HTMLSanitizer.sanitize("<!-- hi -->text") == "text")
    }

    @Test("lone inline open/close fragments pass through")
    func loneInlineFragments() {
        // swift-markdown delivers inline HTML as separate nodes.
        #expect(HTMLSanitizer.sanitize("<sup>") == "<sup>")
        #expect(HTMLSanitizer.sanitize("</sup>") == "</sup>")
    }

    @Test("unterminated tag fails closed to escaped text")
    func malformedFailsClosed() {
        #expect(HTMLSanitizer.sanitize("<div align=\"c") == "&lt;div align=&quot;c")
    }

    @Test("stray < that is not a tag renders as text")
    func strayLessThan() {
        // e.g. free text inside an HTML block: "a < b"
        #expect(HTMLSanitizer.sanitize("a < b") == "a &lt; b")
    }

    @Test("tag and attribute names are case-insensitive, emitted lowercase")
    func caseInsensitive() {
        #expect(HTMLSanitizer.sanitize("<DIV ALIGN=\"center\">x</DIV>")
                == "<div align=\"center\">x</div>")
    }
}

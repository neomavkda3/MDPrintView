import Testing
@testable import MDPrintView

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {

    @Test("renders a single h1 heading")
    func rendersH1() {
        let renderer = MarkdownRenderer()
        let html = renderer.renderHTML(from: "# Hello")
        #expect(html.contains("<h1"))
        #expect(html.contains(">Hello</h1>"))
    }

    @Test("renders a paragraph")
    func rendersParagraph() {
        let html = MarkdownRenderer().renderHTML(from: "hello")
        #expect(html.contains("<p>hello</p>"))
    }

    @Test("renders bullet list")
    func rendersBulletList() {
        let html = MarkdownRenderer().renderHTML(from: "- a\n- b")
        #expect(html.contains("<ul>"))
        #expect(html.contains("<li>"))
        #expect(html.contains("a"))
        #expect(html.contains("b"))
    }

    @Test("renders inline emphasis")
    func rendersEmphasis() {
        let html = MarkdownRenderer().renderHTML(from: "*em*")
        #expect(html.contains("<em>em</em>"))
    }

    @Test("renders inline strong")
    func rendersStrong() {
        let html = MarkdownRenderer().renderHTML(from: "**strong**")
        #expect(html.contains("<strong>strong</strong>"))
    }

    @Test("renders inline code")
    func rendersInlineCode() {
        let html = MarkdownRenderer().renderHTML(from: "`x`")
        #expect(html.contains("<code>x</code>"))
    }

    @Test("renders code block")
    func rendersCodeBlock() {
        let html = MarkdownRenderer().renderHTML(from: "```\nx\n```")
        #expect(html.contains("<pre>"))
        #expect(html.contains("<code>"))
        #expect(html.contains("x"))
    }

    @Test("code block with language gets class attribute")
    func rendersCodeBlockWithLanguage() {
        let html = MarkdownRenderer().renderHTML(from: "```swift\nlet x = 1\n```")
        #expect(html.contains("<code class=\"language-swift\">"))
        #expect(html.contains("let x = 1"))
    }

    @Test("mermaid code block gets language-mermaid class")
    func rendersMermaidBlock() {
        let html = MarkdownRenderer().renderHTML(from: "```mermaid\ngraph TD\n  A --> B\n```")
        #expect(html.contains("<code class=\"language-mermaid\">"))
    }

    @Test("preserves math delimiters in output (KaTeX scans this)")
    func preservesMathDelimiters() {
        let inline = MarkdownRenderer().renderHTML(from: "Some $x = 1$ math.")
        #expect(inline.contains("$x = 1$"))

        let block = MarkdownRenderer().renderHTML(from: "$$x = 1$$")
        #expect(block.contains("$$x = 1$$"))
    }

    @Test("renders link")
    func rendersLink() {
        let html = MarkdownRenderer().renderHTML(from: "[a](https://b)")
        #expect(html.contains("<a href=\"https://b\">a</a>"))
    }

    @Test("escapes < > & in plain text")
    func escapesPlainText() {
        let html = MarkdownRenderer().renderHTML(from: "a < b & c > d")
        #expect(html.contains("a &lt; b &amp; c &gt; d"))
        #expect(!html.contains("<b>") && !html.contains("> d"))
    }

    @Test("escapes HTML inside inline code")
    func escapesInlineCode() {
        let html = MarkdownRenderer().renderHTML(from: "`<body>`")
        #expect(html.contains("<code>&lt;body&gt;</code>"))
    }

    @Test("escapes HTML inside code block")
    func escapesCodeBlock() {
        let html = MarkdownRenderer().renderHTML(from: "```\n<script>x</script>\n```")
        #expect(html.contains("&lt;script&gt;x&lt;/script&gt;"))
        #expect(!html.contains("<script>x</script>"))
    }

    @Test("escapes link href; sanitized inline HTML in label renders")
    func escapesLink() {
        let html = MarkdownRenderer().renderHTML(from: "[<b>label</b>](https://x.com?a=1&b=2)")
        #expect(html.contains("href=\"https://x.com?a=1&amp;b=2\""))
        #expect(html.contains("<b>label</b>"))
    }

    @Test("renders blockquote")
    func rendersBlockquote() {
        let html = MarkdownRenderer().renderHTML(from: "> quoted\n> text")
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("</blockquote>"))
        #expect(html.contains("quoted"))
    }

    @Test("renders horizontal rule")
    func rendersThematicBreak() {
        let html = MarkdownRenderer().renderHTML(from: "before\n\n---\n\nafter")
        #expect(html.contains("<hr"))
    }

    @Test("renders ordered list")
    func rendersOrderedList() {
        let html = MarkdownRenderer().renderHTML(from: "1. first\n2. second")
        #expect(html.contains("<ol>"))
        #expect(html.contains("<li>"))
        #expect(html.contains("first"))
        #expect(html.contains("second"))
    }

    @Test("renders task list with checkboxes")
    func rendersTaskList() {
        let html = MarkdownRenderer().renderHTML(from: "- [ ] todo\n- [x] done")
        #expect(html.contains("type=\"checkbox\""))
        #expect(html.contains("checked"))
        #expect(html.contains("todo"))
        #expect(html.contains("done"))
    }

    @Test("renders simple table")
    func rendersTable() {
        let source = """
        | h1 | h2 |
        | -- | -- |
        | a  | b  |
        """
        let html = MarkdownRenderer().renderHTML(from: source)
        #expect(html.contains("<table>"))
        #expect(html.contains("<thead>"))
        #expect(html.contains("<th>h1</th>"))
        #expect(html.contains("<td>a</td>"))
    }

    @Test("sanitized block-level raw HTML renders")
    func sanitizedHTMLBlock() {
        let html = MarkdownRenderer().renderHTML(from: "<div align=\"center\">raw</div>")
        #expect(html.contains("<div align=\"center\">"))
        #expect(!html.contains("&lt;div"))
    }

    @Test("script in a document is dropped, not escaped")
    func scriptDropped() {
        let html = MarkdownRenderer().renderHTML(from: "before\n\n<script>evil()</script>\n\nafter")
        #expect(!html.contains("script"))
        #expect(!html.contains("evil"))
        #expect(html.contains("before"))
        #expect(html.contains("after"))
    }

    @Test("README-style centered header block renders with real tags")
    func centeredHeaderBlock() {
        let source = "<div align=\"center\">\n\n# Title\n\n</div>"
        let html = MarkdownRenderer().renderHTML(from: source)
        #expect(html.contains("<div align=\"center\">"))
        #expect(html.contains("<h1>Title</h1>"))
        #expect(html.contains("</div>"))
    }

    @Test("renders image")
    func rendersImage() {
        let html = MarkdownRenderer().renderHTML(from: "![alt text](https://example.com/x.png)")
        #expect(html.contains("<img src=\"https://example.com/x.png\""))
        #expect(html.contains("alt=\"alt text\""))
    }

    @Test("escapes image src and alt")
    func escapesImage() {
        let html = MarkdownRenderer().renderHTML(from: "![\"injection<>](https://x.com/?a=1&b=2)")
        // src must escape `&` in the URL
        #expect(html.contains("&amp;b=2"))
        // alt must escape `<` and `>`; swift-markdown applies smart-quote conversion
        // to the literal `"`, which then passes through unescaped in `alt=`.
        #expect(html.contains("alt=\"\u{201C}injection&lt;&gt;\""))
    }

    // MARK: - Currency vs. math regression
    //
    // Real bug, shipped and fixed once: KaTeX's single-$ inline delimiter
    // paired "$4.8B in 2025 ... $13.2B" as a math expression and stripped
    // the whitespace, rendering "4.8Bin2025...". The fix removed the
    // single-$ delimiter from the KaTeX config in PreviewWebView. These
    // tests document the renderer-side contract: dollar signs in prose
    // must pass through to HTML untouched, so the JS layer's delimiter
    // choice is the only thing standing between prose and math mode.

    @Test("currency amounts with paired dollar signs pass through verbatim")
    func currencyPreserved() {
        let html = MarkdownRenderer().renderHTML(
            from: "The market was $4.8B in 2025 and is projected to reach $13.2B by 2034."
        )
        #expect(html.contains("$4.8B in 2025"))
        #expect(html.contains("$13.2B by 2034"))
    }

    @Test("display math delimiters pass through for KaTeX")
    func displayMathPreserved() {
        let html = MarkdownRenderer().renderHTML(from: "$$e^{i\\pi} + 1 = 0$$")
        #expect(html.contains("$$"))
    }
}

@Suite("Page break rendering")
struct PageBreakRenderingTests {
    private let renderer = MarkdownRenderer()
    private let source = "# One\n\nPara one.\n\nPara two."   // 3 top-level blocks

    @Test("blockFingerprints yields one entry per top-level block")
    func fingerprints() {
        let fps = MarkdownRenderer.blockFingerprints(from: source)
        #expect(fps.count == 3)
        #expect(fps[0] == PageBreak.fingerprint(of: "# One"))
    }

    @Test("no breaks: gap divs between every boundary, none trailing")
    func gapsOnly() {
        let html = renderer.renderHTML(from: source, breaksAfter: [])
        #expect(html.contains("<div class=\"break-gap\" data-after=\"0\"></div>"))
        #expect(html.contains("<div class=\"break-gap\" data-after=\"1\"></div>"))
        #expect(!html.contains("data-after=\"2\""))   // no gap after the last block
    }

    @Test("break replaces the gap at its boundary")
    func breakDiv() {
        let html = renderer.renderHTML(from: source, breaksAfter: [1])
        #expect(html.contains("<div class=\"page-break\" data-after=\"1\">"))
        #expect(html.contains("page-break-remove"))
        #expect(!html.contains("<div class=\"break-gap\" data-after=\"1\"></div>"))
        #expect(html.contains("<div class=\"break-gap\" data-after=\"0\"></div>"))
    }

    @Test("plain renderHTML(from:) emits no gap or break markup")
    func plainUnchanged() {
        let html = renderer.renderHTML(from: source)
        #expect(!html.contains("break-gap"))
        #expect(!html.contains("page-break"))
    }

    // MARK: soft break / hard break — regression fence for the
    //        "words on adjacent lines glue together" bug reported
    //        against v0.4.3.

    @Test("single newline in a paragraph becomes whitespace, not glue")
    func softBreakBecomesWhitespace() {
        let out = MarkdownRenderer().renderHTML(from: "hello\nworld")
        // The two words must NOT be concatenated.
        #expect(!out.contains("helloworld"))
        // And they must be separated by either a newline (browser collapses
        // to a space) or an actual space character.
        #expect(out.contains("hello\nworld") || out.contains("hello world"))
    }

    @Test("hard line break (two trailing spaces) becomes <br>")
    func hardBreakBecomesBr() {
        let out = MarkdownRenderer().renderHTML(from: "line one  \nline two")
        #expect(out.contains("<br>"))
    }

    @Test("three consecutive soft-break lines all get whitespace")
    func softBreakChain() {
        let out = MarkdownRenderer().renderHTML(from: "one\ntwo\nthree")
        #expect(!out.contains("onetwo"))
        #expect(!out.contains("twothree"))
    }
}

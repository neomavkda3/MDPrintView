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

    @Test("escapes link href and label")
    func escapesLink() {
        let html = MarkdownRenderer().renderHTML(from: "[<b>label</b>](https://x.com?a=1&b=2)")
        #expect(html.contains("href=\"https://x.com?a=1&amp;b=2\""))
        #expect(html.contains("&lt;b&gt;label&lt;/b&gt;"))
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

    @Test("escapes block-level raw HTML")
    func escapesHTMLBlock() {
        let html = MarkdownRenderer().renderHTML(from: "<div>raw</div>")
        #expect(html.contains("&lt;div&gt;raw&lt;/div&gt;"))
        #expect(!html.contains("<div>raw</div>"))
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

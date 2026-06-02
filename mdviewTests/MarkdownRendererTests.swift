import Testing
@testable import mdview

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

    @Test("renders link")
    func rendersLink() {
        let html = MarkdownRenderer().renderHTML(from: "[a](https://b)")
        #expect(html.contains("<a href=\"https://b\">a</a>"))
    }
}

import Testing
import AppKit
@testable import MDPrintView

@Suite("EditorController", .serialized)
@MainActor
struct EditorControllerTests {

    private func make(_ text: String, selection: NSRange = NSRange(location: 0, length: 0)) -> (EditorController, NSTextView) {
        let tv = NSTextView()
        tv.string = text
        tv.setSelectedRange(selection)
        let controller = EditorController()
        controller.textView = tv
        return (controller, tv)
    }

    @Test("toggleBold wraps selection in **")
    func boldWrapsSelection() {
        let (c, tv) = make("hello world", selection: NSRange(location: 6, length: 5))
        c.toggleBold()
        #expect(tv.string == "hello **world**")
    }

    @Test("toggleBold inserts placeholder when no selection")
    func boldNoSelection() {
        let (c, tv) = make("hello ")
        tv.setSelectedRange(NSRange(location: 6, length: 0))
        c.toggleBold()
        #expect(tv.string == "hello **bold**")
    }

    @Test("toggleHeading prefixes line with hashes")
    func headingPrefix() {
        let (c, tv) = make("hello")
        tv.setSelectedRange(NSRange(location: 2, length: 0))
        c.toggleHeading(level: 2)
        #expect(tv.string == "## hello")
    }

    @Test("insertBullet prefixes line with dash")
    func bulletPrefix() {
        let (c, tv) = make("item")
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        c.insertBullet()
        #expect(tv.string == "- item")
    }

    @Test("insertLink wraps selection with markdown link syntax")
    func linkWraps() {
        let (c, tv) = make("click here", selection: NSRange(location: 0, length: 5))
        c.insertLink(url: "https://x.com")
        #expect(tv.string == "[click](https://x.com) here")
    }
}

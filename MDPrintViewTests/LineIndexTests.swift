import Testing
@testable import MDPrintView

@Suite("LineIndex")
struct LineIndexTests {

    @Test("empty text is one line")
    func empty() {
        let idx = LineIndex(text: "")
        #expect(idx.lineCount == 1)
        #expect(idx.lineNumber(at: 0) == 1)
    }

    @Test("single line without newline")
    func singleLine() {
        let idx = LineIndex(text: "hello")
        #expect(idx.lineCount == 1)
        #expect(idx.lineNumber(at: 4) == 1)
    }

    @Test("trailing newline adds a final empty line")
    func trailingNewline() {
        let idx = LineIndex(text: "a\n")
        #expect(idx.lineCount == 2)
        #expect(idx.lineNumber(at: 0) == 1)
        #expect(idx.lineNumber(at: 2) == 2)
    }

    @Test("offsets map to their lines")
    func midLineOffsets() {
        let idx = LineIndex(text: "ab\ncd")
        #expect(idx.lineNumber(at: 0) == 1)
        #expect(idx.lineNumber(at: 1) == 1)
        #expect(idx.lineNumber(at: 2) == 1)   // the \n itself belongs to line 1
        #expect(idx.lineNumber(at: 3) == 2)
        #expect(idx.lineNumber(at: 4) == 2)
    }

    @Test("consecutive newlines make empty lines")
    func consecutiveNewlines() {
        let idx = LineIndex(text: "a\n\nb")
        #expect(idx.lineCount == 3)
        #expect(idx.lineNumber(at: 2) == 2)   // the empty line's start
        #expect(idx.lineNumber(at: 3) == 3)   // "b"
    }

    @Test("UTF-16 offsets: emoji and CJK")
    func unicode() {
        // "🙂" is 2 UTF-16 units; "漢" is 1.
        let idx = LineIndex(text: "🙂\n漢字")
        #expect(idx.lineCount == 2)
        #expect(idx.lineNumber(at: 0) == 1)
        #expect(idx.lineNumber(at: 2) == 1)   // the \n after the emoji
        #expect(idx.lineNumber(at: 3) == 2)   // 漢
    }

    @Test("offset at end of text maps to last line")
    func endOfText() {
        let idx = LineIndex(text: "a\nb")
        #expect(idx.lineNumber(at: 3) == 2)
        // Past-the-end defensively clamps to the last line too.
        #expect(idx.lineNumber(at: 99) == 2)
    }
}

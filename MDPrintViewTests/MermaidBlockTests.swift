import Foundation
import Testing
@testable import MDPrintView

@Suite("MermaidBlock")
struct MermaidBlockTests {

    @Test("finds mermaid block containing cursor")
    func findsBlockAtCursor() throws {
        let source = "intro\n\n```mermaid\ngraph TD\n  A --> B\n```\n\nafter\n"
        let cursor = try #require(source.range(of: "graph")).lowerBound.utf16Offset(in: source)
        let block = MermaidBlock.containing(cursor: cursor, in: source)
        #expect(block != nil)
        #expect(block?.code.contains("graph TD") == true)
    }

    @Test("returns nil when cursor outside any mermaid block")
    func nilOutsideAnyBlock() throws {
        let source = "intro\n\n```mermaid\nx\n```\n\nafter\n"
        let cursor = try #require(source.range(of: "after")).lowerBound.utf16Offset(in: source)
        let block = MermaidBlock.containing(cursor: cursor, in: source)
        #expect(block == nil)
    }

    @Test("returns nil when cursor inside non-mermaid code block")
    func nilInsideOtherLanguage() throws {
        let source = "```swift\nlet x = 1\n```\n"
        let cursor = try #require(source.range(of: "let")).lowerBound.utf16Offset(in: source)
        let block = MermaidBlock.containing(cursor: cursor, in: source)
        #expect(block == nil)
    }

    @Test("reports the NSRange of the entire mermaid block including fences")
    func reportsRangeIncludingFences() throws {
        let source = "before\n```mermaid\nx\n```\nafter"
        let cursor = try #require(source.range(of: "x")).lowerBound.utf16Offset(in: source)
        let block = try #require(MermaidBlock.containing(cursor: cursor, in: source))
        let nsString = source as NSString
        let extracted = nsString.substring(with: block.fullRange)
        #expect(extracted.hasPrefix("```mermaid"))
        #expect(extracted.hasSuffix("```"))
    }
}

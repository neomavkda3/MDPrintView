import Testing
@testable import MDPrintView

@Suite("Outline")
struct OutlineTests {

    @Test("extracts flat top-level heading")
    func flatHeadings() {
        let nodes = Outline.extract(from: "# A\n## B\n## C\n")
        #expect(nodes.map(\.title) == ["A"])
        #expect(nodes.first?.children.map(\.title) == ["B", "C"])
    }

    @Test("nests deeper levels under shallower")
    func nestedHeadings() throws {
        let nodes = Outline.extract(from: "# A\n## B\n### B1\n## C\n")
        let a = try #require(nodes.first)
        #expect(a.children.map(\.title) == ["B", "C"])
        let b = try #require(a.children.first)
        #expect(b.children.map(\.title) == ["B1"])
    }

    @Test("empty input yields empty outline")
    func emptyInput() {
        #expect(Outline.extract(from: "").isEmpty)
    }

    @Test("handles multiple top-level h1 entries")
    func multipleTopLevels() {
        let nodes = Outline.extract(from: "# A\n# B\n")
        #expect(nodes.map(\.title) == ["A", "B"])
    }
}

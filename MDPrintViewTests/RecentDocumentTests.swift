import Testing
import Foundation
@testable import MDPrintView

@Suite("RecentDocument preview sanitizer")
struct RecentDocumentSanitizeTests {

    @Test("strips YAML frontmatter")
    func dropsFrontmatter() {
        let input = """
        ---
        title: My Doc
        date: 2026-06-11
        ---
        # Real Heading
        Body starts here.
        """
        let out = RecentDocument.sanitize(input)
        #expect(!out.contains("title: My Doc"))
        #expect(out.contains("Real Heading"))
        #expect(out.contains("Body starts here."))
    }

    @Test("text without frontmatter passes through")
    func noFrontmatter() {
        let out = RecentDocument.sanitize("Plain first line.\nSecond line.")
        #expect(out == "Plain first line. Second line.")
    }

    @Test("unclosed frontmatter does not eat the document")
    func unclosedFrontmatter() {
        let input = """
        ---
        title: never closed
        body text after
        """
        let out = RecentDocument.sanitize(input)
        // No closing --- means we keep the content rather than dropping it all.
        #expect(!out.isEmpty)
    }

    @Test("removes markdown emphasis + heading markers")
    func stripsMarkers() {
        let out = RecentDocument.sanitize("# Title\n**bold** and __also__ and `code`")
        #expect(!out.contains("#"))
        #expect(!out.contains("**"))
        #expect(!out.contains("__"))
        #expect(!out.contains("`"))
        #expect(out.contains("bold"))
        #expect(out.contains("code"))
    }

    @Test("collapses runs of whitespace")
    func collapsesWhitespace() {
        let out = RecentDocument.sanitize("a    b\t\tc")
        #expect(out == "a b c")
    }

    @Test("skips leading blank lines")
    func skipsLeadingBlanks() {
        let out = RecentDocument.sanitize("\n\n   \nFirst real line")
        #expect(out.hasPrefix("First real line"))
    }

    @Test("truncates at 220 characters")
    func truncates() {
        let long = String(repeating: "word ", count: 100)
        let out = RecentDocument.sanitize(long)
        #expect(out.count <= 220)
    }

    @Test("uses at most the first six lines")
    func sixLineWindow() {
        let input = (1...10).map { "line\($0)" }.joined(separator: "\n")
        let out = RecentDocument.sanitize(input)
        #expect(out.contains("line6"))
        #expect(!out.contains("line7"))
    }
}

@Suite("DateGroup bucketing")
struct DateGroupTests {
    private let cal = Calendar.current

    @Test("now is today")
    func today() {
        #expect(DateGroup.group(for: Date()) == .today)
    }

    @Test("24h ago is yesterday")
    func yesterday() {
        let d = cal.date(byAdding: .day, value: -1, to: Date())!
        #expect(DateGroup.group(for: d) == .yesterday)
    }

    @Test("3 days ago is last week")
    func lastWeek() {
        let d = cal.date(byAdding: .day, value: -3, to: Date())!
        #expect(DateGroup.group(for: d) == .lastWeek)
    }

    @Test("15 days ago is last month")
    func lastMonth() {
        let d = cal.date(byAdding: .day, value: -15, to: Date())!
        #expect(DateGroup.group(for: d) == .lastMonth)
    }

    @Test("45 days ago is older")
    func older() {
        let d = cal.date(byAdding: .day, value: -45, to: Date())!
        #expect(DateGroup.group(for: d) == .older)
    }

    @Test("distant past is older")
    func distantPast() {
        #expect(DateGroup.group(for: .distantPast) == .older)
    }

    @Test("every group has a label")
    func labels() {
        for group in DateGroup.allCases {
            #expect(!group.label.isEmpty)
        }
    }
}

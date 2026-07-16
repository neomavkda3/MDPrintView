import Testing
@testable import MDPrintView

@Suite("TextColorSwatch")
struct SwatchStripTests {

    @Test("nil hex matches System preset")
    func nilMatchesSystem() {
        let selection: String? = nil
        #expect(TextColorSwatch.matching(hex: selection) == .system)
    }

    @Test("warm ink hex matches warmInk preset")
    func warmInkMatches() {
        #expect(TextColorSwatch.matching(hex: "#5B4636") == .warmInk)
    }

    @Test("case-insensitive hex still matches")
    func caseInsensitive() {
        #expect(TextColorSwatch.matching(hex: "#5b4636") == .warmInk)
    }

    @Test("unknown hex matches nothing (→ Custom is selected)")
    func customCase() {
        #expect(TextColorSwatch.matching(hex: "#123456") == nil)
    }

    @Test("high contrast hex matches highContrast preset")
    func highContrastMatches() {
        #expect(TextColorSwatch.matching(hex: "#111111") == .highContrast)
    }
}

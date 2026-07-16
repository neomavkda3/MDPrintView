import Testing
import AppKit
@testable import MDPrintView

@Suite("HexColor")
struct HexColorTests {

    @Test("round-trip preserves the color")
    func roundTrip() {
        let original = "#5B4636"
        let color = HexColor.nsColor(from: original)
        #expect(color != nil)
        #expect(HexColor.hex(from: color!) == original)
    }

    @Test("nil hex → nil color")
    func nilInput() {
        #expect(HexColor.nsColor(from: nil) == nil)
    }

    @Test("empty string → nil")
    func emptyInput() {
        #expect(HexColor.nsColor(from: "") == nil)
    }

    @Test("missing # is accepted")
    func noHashPrefix() {
        let color = HexColor.nsColor(from: "5B4636")
        #expect(color != nil)
    }

    @Test("wrong length rejected")
    func wrongLength() {
        #expect(HexColor.nsColor(from: "#ABC") == nil)
        #expect(HexColor.nsColor(from: "#ABCDEFG") == nil)
    }

    @Test("non-hex characters rejected")
    func invalidChars() {
        #expect(HexColor.nsColor(from: "#XYZXYZ") == nil)
    }

    @Test("hex output is always uppercase 7 chars starting with #")
    func hexFormatting() {
        let hex = HexColor.hex(from: .black)
        #expect(hex.hasPrefix("#"))
        #expect(hex.count == 7)
        #expect(hex == hex.uppercased())
    }
}

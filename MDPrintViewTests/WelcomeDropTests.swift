import Testing
import Foundation
import UniformTypeIdentifiers
@testable import MDPrintView

@Suite("WelcomeDrop acceptance")
struct WelcomeDropTests {

    @Test("plain text is accepted")
    func plainText() {
        #expect(WelcomeDrop.accepts(.plainText))
    }

    @Test("the app's markdown type is accepted")
    func markdown() {
        // Regression guard on the app's UTImportedTypeDeclarations: the
        // daringfireball markdown UTI must conform to public.plain-text.
        #expect(WelcomeDrop.accepts(.markdown))
    }

    @Test("source files conform to plain-text and are accepted (matches Open panel)")
    func sourceCode() {
        #expect(WelcomeDrop.accepts(.swiftSource))
    }

    @Test("images are rejected")
    func image() {
        #expect(!WelcomeDrop.accepts(.png))
    }

    @Test("folders are rejected")
    func folder() {
        #expect(!WelcomeDrop.accepts(.folder))
    }

    @Test("opaque data (extensionless / unknown) is rejected")
    func opaqueData() {
        // Extensionless files resolve to public.data — rejected, same as the
        // Open panel, which also greys them out. No content sniffing.
        #expect(!WelcomeDrop.accepts(.data))
    }

    // MARK: Real-file URL mapping (the behavior the drop handler relies on)

    /// Make a unique temp directory; caller is responsible for cleanup.
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("a real .md file URL is accepted")
    func markdownFileURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let md = dir.appendingPathComponent("note.md")
        try "# Hi".write(to: md, atomically: true, encoding: .utf8)
        // Relies on the app's UTImportedTypeDeclarations being registered via
        // TEST_HOST. If this fails, .md no longer maps to the markdown UTI.
        #expect(WelcomeDrop.accepts(md))
    }

    @Test("a real .txt file URL is accepted")
    func txtFileURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let txt = dir.appendingPathComponent("notes.txt")
        try "hello".write(to: txt, atomically: true, encoding: .utf8)
        #expect(WelcomeDrop.accepts(txt))
    }

    @Test("a real .png file URL is rejected")
    func pngFileURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Type resolves from the .png extension, not the bytes.
        let png = dir.appendingPathComponent("image.png")
        try "not really a png".write(to: png, atomically: true, encoding: .utf8)
        #expect(!WelcomeDrop.accepts(png))
    }

    @Test("a real extensionless text file URL is rejected")
    func extensionlessFileURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // No extension → resolves to public.data (no content sniffing) → rejected,
        // same as the Open panel.
        let file = dir.appendingPathComponent("plainfile")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        #expect(!WelcomeDrop.accepts(file))
    }

    @Test("a directory URL is rejected")
    func directoryURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(!WelcomeDrop.accepts(dir))
    }
}

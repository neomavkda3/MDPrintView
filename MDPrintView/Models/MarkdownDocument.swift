import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

@Observable
final class MarkdownDocument: ReferenceFileDocument {
    typealias Snapshot = String

    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown, .plainText] }

    var text: String

    /// The content most recently read from or written to disk. Used by the
    /// external-edit reload path to distinguish three cases when the file
    /// watcher fires:
    ///   disk == lastSavedText      → our own save landing; ignore
    ///   text != lastSavedText      → unsaved in-app edits; don't clobber
    ///   otherwise                  → genuine external change; adopt it
    /// Without this, a save's atomic rename racing with fresh keystrokes
    /// could revert the editor to the just-saved (older) content.
    @ObservationIgnored var lastSavedText: String

    init(text: String = "") {
        self.text = text
        self.lastSavedText = text
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
        self.lastSavedText = string
    }

    func snapshot(contentType: UTType) throws -> String {
        // snapshot(contentType:) is documented to run on the main thread,
        // making it the safe place to record what's headed to disk.
        // (fileWrapper(snapshot:) may run on a background queue.)
        lastSavedText = text
        return text
    }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(snapshot.utf8))
    }
}

import SwiftUI

@main
struct MdviewApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            DocumentView(document: file.document)
        }
    }
}

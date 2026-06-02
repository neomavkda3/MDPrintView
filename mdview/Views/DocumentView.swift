import SwiftUI

struct DocumentView: View {
    @Bindable var document: MarkdownDocument

    var body: some View {
        TextEditor(text: $document.text)
            .font(.system(size: 14, design: .monospaced))
            .frame(minWidth: 480, minHeight: 320)
    }
}

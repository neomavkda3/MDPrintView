import SwiftUI

struct DocumentView: View {
    @Bindable var document: MarkdownDocument

    var body: some View {
        MarkdownTextView(text: $document.text)
            .frame(minWidth: 480, minHeight: 320)
    }
}

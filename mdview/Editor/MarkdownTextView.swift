import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    let controller: EditorController
    let mode: EditorMode

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, mode: mode)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false

        textView.string = text
        controller.textView = textView
        if let storage = textView.textStorage {
            context.coordinator.applyStyling(to: storage)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let modeChanged = context.coordinator.mode != mode
        context.coordinator.mode = mode
        if textView.string != text {
            textView.string = text
            if let storage = textView.textStorage {
                context.coordinator.applyStyling(to: storage)
            }
        } else if modeChanged, let storage = textView.textStorage {
            context.coordinator.applyStyling(to: storage)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let text: Binding<String>
        var mode: EditorMode
        private let sourceHighlighter = SyntaxHighlighter()
        private let liveFormatStyler = LiveFormatStyler()

        init(text: Binding<String>, mode: EditorMode) {
            self.text = text
            self.mode = mode
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            if let storage = textView.textStorage {
                applyStyling(to: storage, cursorAt: textView.selectedRange().location)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard mode == .hybrid,
                  let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }
            // Attribute-only changes don't fire selection changes, so no re-entry risk.
            liveFormatStyler.apply(to: storage, cursorAt: textView.selectedRange().location)
        }

        func applyStyling(to storage: NSTextStorage, cursorAt cursor: Int? = nil) {
            switch mode {
            case .source: sourceHighlighter.apply(to: storage)
            case .hybrid: liveFormatStyler.apply(to: storage, cursorAt: cursor)
            }
        }
    }
}

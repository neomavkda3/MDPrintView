import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    let controller: EditorController
    let mode: EditorMode
    let editorFontSize: CGFloat
    let editorFontFamily: EditorFontFamily

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, mode: mode, fontSize: editorFontSize, fontFamily: editorFontFamily)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = editorFontFamily.nsFont(size: editorFontSize)
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
        let fontSizeChanged = context.coordinator.fontSize != editorFontSize
        let fontFamilyChanged = context.coordinator.fontFamily != editorFontFamily
        context.coordinator.mode = mode
        context.coordinator.fontSize = editorFontSize
        context.coordinator.fontFamily = editorFontFamily
        if textView.string != text {
            textView.string = text
            if let storage = textView.textStorage {
                context.coordinator.applyStyling(to: storage)
            }
        } else if (modeChanged || fontSizeChanged || fontFamilyChanged), let storage = textView.textStorage {
            context.coordinator.applyStyling(to: storage)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let text: Binding<String>
        var mode: EditorMode
        var fontSize: CGFloat
        var fontFamily: EditorFontFamily

        init(text: Binding<String>, mode: EditorMode, fontSize: CGFloat, fontFamily: EditorFontFamily) {
            self.text = text
            self.mode = mode
            self.fontSize = fontSize
            self.fontFamily = fontFamily
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            if let storage = textView.textStorage {
                applyStyling(to: storage)
            }
        }

        // E3 cursor-aware fold/reveal is DEFERRED to v1.1. Spike T9 measured
        // `LiveFormatStyler.apply` at ~8s on a 50KB doc; wiring it to every
        // cursor move would freeze the editor. Hybrid mode ships as "Rich"
        // (E1+E2): rich inline styling with faded-but-visible marks.
        // See docs/plans/2026-06-05-hybrid-mode-decision.md.

        func applyStyling(to storage: NSTextStorage) {
            switch mode {
            case .source: SyntaxHighlighter(baseFontSize: fontSize, fontFamily: fontFamily).apply(to: storage)
            case .hybrid: LiveFormatStyler().apply(to: storage) // no cursorAt → E2 behavior
            }
        }
    }
}

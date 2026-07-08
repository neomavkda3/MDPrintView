import AppKit

/// Maps UTF-16 character offsets to 1-based hard-line numbers.
/// Rebuilt whole on every text change — a linear scan is cheap at
/// document sizes this app handles, and beats incremental bookkeeping.
struct LineIndex {
    /// UTF-16 offset of each line start: always contains 0; plus the offset
    /// after every "\n".
    private let lineStarts: [Int]

    init(text: String) {
        var starts = [0]
        var offset = 0
        for unit in text.utf16 {
            offset += 1
            if unit == 0x0A {   // "\n"
                starts.append(offset)
            }
        }
        lineStarts = starts
    }

    var lineCount: Int { lineStarts.count }

    /// 1-based line containing `utf16Offset`. Offsets at or past the end
    /// clamp to the last line. Binary search over line starts.
    func lineNumber(at utf16Offset: Int) -> Int {
        var lo = 0, hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= utf16Offset { lo = mid } else { hi = mid - 1 }
        }
        return lo + 1
    }
}

/// Line-number gutter for the editor. Installed as the NSScrollView's
/// vertical ruler, so it scrolls in lockstep with the text for free.
///
/// TextKit 2: numbers come from NSTextLayoutManager layout fragments. Each
/// fragment is one paragraph — for plain markdown text that means one hard
/// line — so a soft-wrapped line draws one number on its first visual row.
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private var lineIndex = LineIndex(text: "")
    private var numberFont: NSFont = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    private let padding: CGFloat = 5

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        // Wrap points move when the text view resizes; fragment frames shift.
        NotificationCenter.default.addObserver(
            self, selector: #selector(frameDidChange),
            name: NSView.frameDidChangeNotification, object: textView)
        invalidate()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func frameDidChange(_ note: Notification) {
        needsDisplay = true
    }

    /// Text changed: rebuild the line index, resize the gutter, redraw.
    func invalidate() {
        lineIndex = LineIndex(text: textView?.string ?? "")
        let digits = max(2, String(lineIndex.lineCount).count)
        let digitWidth = ("8" as NSString).size(withAttributes: [.font: numberFont]).width
        ruleThickness = ceil(CGFloat(digits) * digitWidth + 2 * padding)
        needsDisplay = true
    }

    /// Editor font size changed: scale the gutter font with it.
    func updateFontSize(_ editorFontSize: CGFloat) {
        numberFont = .monospacedDigitSystemFont(ofSize: editorFontSize * 0.8, weight: .regular)
        invalidate()
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let layoutManager = textView.textLayoutManager else { return }

        // Right-edge hairline.
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        // Converts text-view coordinates into ruler coordinates (handles the
        // current scroll offset).
        let relativePoint = convert(NSPoint.zero, from: textView)
        let inset = textView.textContainerInset.height
        let visibleRect = textView.visibleRect

        // Start enumerating at the first fragment in view.
        let startFragment = layoutManager.textLayoutFragment(
            for: CGPoint(x: 0, y: max(0, visibleRect.minY - inset)))
        let startLocation = startFragment?.rangeInElement.location
            ?? layoutManager.documentRange.location

        var lastMaxY: CGFloat = 0
        layoutManager.enumerateTextLayoutFragments(from: startLocation,
                                                   options: [.ensuresLayout]) { fragment in
            let frame = fragment.layoutFragmentFrame
            lastMaxY = frame.maxY
            if frame.minY + inset > visibleRect.maxY { return false }

            let offset = layoutManager.offset(from: layoutManager.documentRange.location,
                                              to: fragment.rangeInElement.location)
            let line = lineIndex.lineNumber(at: offset)
            let firstRowHeight = fragment.textLineFragments.first?.typographicBounds.height
                ?? frame.height
            drawNumber(line, atY: frame.minY + inset + relativePoint.y,
                       rowHeight: firstRowHeight, attributes: attributes)
            return true
        }

        // Trailing empty line ("a\n" shows a 2 on the caret's empty row) and
        // the empty document (shows 1): TextKit has no fragment for it, so
        // place it after the last fragment using the font's line height.
        if textView.string.isEmpty || textView.string.hasSuffix("\n") {
            let rowHeight: CGFloat
            if let font = textView.font {
                rowHeight = font.ascender - font.descender + font.leading
            } else {
                rowHeight = 14
            }
            drawNumber(lineIndex.lineCount, atY: lastMaxY + inset + relativePoint.y,
                       rowHeight: rowHeight, attributes: attributes)
        }
    }

    private func drawNumber(_ line: Int, atY y: CGFloat, rowHeight: CGFloat,
                            attributes: [NSAttributedString.Key: Any]) {
        let str = "\(line)" as NSString
        let size = str.size(withAttributes: attributes)
        let point = NSPoint(x: ruleThickness - padding - size.width,
                            y: y + (rowHeight - size.height) / 2)
        str.draw(at: point, withAttributes: attributes)
    }
}

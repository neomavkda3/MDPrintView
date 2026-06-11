import AppKit

/// Adapter between SwiftUI Settings and the native `NSFontPanel`.
///
/// AppKit's font panel works by sending the `changeFont:` action up the
/// responder chain. `NSFontManager` intercepts it and forwards to its
/// `target`, which is where we hook in. We keep a singleton so the target
/// stays alive while the panel is open.
@MainActor
final class FontPickerCoordinator: NSObject {
    static let shared = FontPickerCoordinator()

    private var onPick: ((String) -> Void)?
    private var baseSize: CGFloat = 14

    private override init() { super.init() }

    /// Present the font panel pre-selecting `currentFontName` at `size`.
    /// `onPick` fires every time the user changes face/family in the
    /// panel — they can preview several picks live in the editor.
    func show(currentFontName: String, size: CGFloat, onPick: @escaping (String) -> Void) {
        self.onPick = onPick
        self.baseSize = size

        let font = NSFont(name: currentFontName, size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)

        let manager = NSFontManager.shared
        manager.target = self
        manager.setSelectedFont(font, isMultiple: false)

        NSFontPanel.shared.orderFront(nil)
    }

    @objc func changeFont(_ sender: Any?) {
        guard let manager = sender as? NSFontManager else { return }
        // Pass a same-size placeholder so the panel reports the family/face
        // change without trying to mutate our size — we keep size on our
        // own slider so the two settings don't fight each other.
        let placeholder = NSFont.systemFont(ofSize: baseSize)
        let newFont = manager.convert(placeholder)
        let name = newFont.familyName ?? newFont.fontName
        onPick?(name)
    }

    /// Restrict the font panel to family/face/collection — we have our
    /// own size slider and don't expose underline/strikethrough/colour at
    /// the editor level.
    @objc func validModesForFontPanel(_ fontPanel: NSFontPanel) -> NSFontPanel.ModeMask {
        [.face, .collection]
    }
}

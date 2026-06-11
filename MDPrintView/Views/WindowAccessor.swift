import SwiftUI
import AppKit

/// Tiny NSViewRepresentable that runs `configure` once its host view has been
/// added to a window. Used to set per-window AppKit state (tabbing mode,
/// title, etc.) from a SwiftUI hierarchy.
struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = HostingProbeView()
        view.onWindowAvailable = configure
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class HostingProbeView: NSView {
        var onWindowAvailable: ((NSWindow) -> Void)?
        private var fired = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard !fired, let window = self.window else { return }
            fired = true
            onWindowAvailable?(window)
        }
    }
}

import Foundation

@MainActor
@Observable
final class RenderState {
    var html: String = ""

    private let renderer = MarkdownRenderer()
    private var debounceTask: Task<Void, Never>?

    func schedule(_ source: String, delay: Duration = .milliseconds(40)) {
        debounceTask?.cancel()
        // [weak self]: the pending task must not keep RenderState alive
        // through the debounce window after the owning view is torn down.
        // (No deinit cancel needed — an orphaned task wakes, finds self
        // nil, and exits; deinit is nonisolated in Swift 6 and can't touch
        // the MainActor-isolated task property anyway.)
        debounceTask = Task { @MainActor [weak self, renderer] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            let result = renderer.renderHTML(from: source)
            guard !Task.isCancelled else { return }
            self.html = result
        }
    }

    func renderNow(_ source: String) {
        debounceTask?.cancel()
        html = renderer.renderHTML(from: source)
    }
}

import Foundation

@MainActor
@Observable
final class RenderState {
    var html: String = ""

    private let renderer = MarkdownRenderer()
    private var debounceTask: Task<Void, Never>?

    func schedule(_ source: String, delay: Duration = .milliseconds(80)) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [renderer] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
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

import SwiftUI
import AppKit

struct WelcomeView: View {
    @AppStorage("suppressWelcomeOnLaunch") private var suppressOnLaunch: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // App icon — pulled via NSWorkspace from the bundle path so we
            // always get the most current AppIcon (NSApp.applicationIconImage
            // can be stale during Debug rebuilds due to icon cache).
            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .interpolation(.high)
                .frame(width: 144, height: 144)

            VStack(spacing: 6) {
                Text("Welcome to mdview")
                    .font(.system(size: 28, weight: .semibold))
                Text("A native macOS markdown editor with print-quality typography")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button(action: createNewDocument) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16, weight: .medium))
                        Text("New Document")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("⌘N")
                            .font(.system(size: 12))
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("n", modifiers: .command)

                Button(action: openDocumentPanel) {
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .font(.system(size: 16, weight: .medium))
                        Text("Open Document…")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("⌘O")
                            .font(.system(size: 12))
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut("o", modifiers: .command)
            }

            if !recentURLs.isEmpty {
                Divider()
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("RECENT")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)

                    ForEach(recentURLs.prefix(5), id: \.self) { url in
                        Button { openURL(url) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    Text(url.deletingLastPathComponent().path)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 8)

            Toggle("Show this window when mdview launches", isOn: Binding(
                get: { !suppressOnLaunch },
                set: { suppressOnLaunch = !$0 }
            ))
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 560, height: recentURLs.isEmpty ? 520 : 680)
    }

    private var recentURLs: [URL] {
        NSDocumentController.shared.recentDocumentURLs
    }

    private func createNewDocument() {
        do {
            try NSDocumentController.shared.openUntitledDocumentAndDisplay(true)
            closeWelcome()
        } catch {
            print("[mdview] Failed to open untitled doc: \(error)")
        }
    }

    private func openDocumentPanel() {
        NSDocumentController.shared.beginOpenPanel { urls in
            guard let urls, !urls.isEmpty else { return }
            for url in urls {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
            }
            DispatchQueue.main.async { closeWelcome() }
        }
    }

    private func openURL(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in
            DispatchQueue.main.async { closeWelcome() }
        }
    }

    private func closeWelcome() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "mdview.welcome" }) {
            window.close()
        }
    }
}

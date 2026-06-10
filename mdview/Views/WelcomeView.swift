import SwiftUI
import AppKit

struct WelcomeView: View {
    @AppStorage("suppressWelcomeOnLaunch") private var suppressOnLaunch: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 4) {
                Text("Welcome to mdview")
                    .font(.system(size: 22, weight: .semibold))
                Text("Native macOS markdown editor with print-quality typography")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                Button(action: createNewDocument) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("New Document")
                        Spacer()
                        Text("⌘N").foregroundStyle(.secondary).monospaced()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("n", modifiers: .command)

                Button(action: openDocumentPanel) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Open Document…")
                        Spacer()
                        Text("⌘O").foregroundStyle(.secondary).monospaced()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut("o", modifiers: .command)
            }

            if !recentURLs.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)

                    ForEach(recentURLs.prefix(5), id: \.self) { url in
                        Button { openURL(url) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "doc")
                                    .foregroundStyle(.tertiary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 13))
                                    Text(url.deletingLastPathComponent().path)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 4)

            Toggle("Show this window when mdview launches", isOn: Binding(
                get: { !suppressOnLaunch },
                set: { suppressOnLaunch = !$0 }
            ))
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 440, height: recentURLs.isEmpty ? 360 : 500)
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

import SwiftUI
import AppKit

struct WelcomeView: View {
    @AppStorage("suppressWelcomeOnLaunch") private var suppressOnLaunch: Bool = false
    @Environment(\.dismissWindow) private var dismissWindow

    // Held in @State (rather than computed from NSDocumentController on
    // every body call) so we can refresh it on .onAppear — otherwise the
    // list stays frozen at whatever it was when the Window scene was
    // first created.
    @State private var recents: [RecentDocument] = []
    @State private var pinnedURLs: [URL] = []
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 18) {
            header
            actionButtons
            Divider()
            recentsSection
            footer
        }
        .padding(28)
        .frame(width: 600, height: 720)
        .onAppear(perform: refresh)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
            VStack(spacing: 4) {
                Text("Welcome to MDPrintView")
                    .font(.system(.title2, design: .default, weight: .semibold))
                Text("A native macOS markdown editor with print-quality typography")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: createNewDocument) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                    Text("New Document")
                        .fontWeight(.medium)
                    Spacer()
                    Text("⌘N")
                        .font(.caption)
                        .monospaced()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accentColor)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityIdentifier("welcome.new")

            Button(action: openDocumentPanel) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                    Text("Open…")
                        .fontWeight(.medium)
                    Spacer()
                    Text("⌘O")
                        .font(.caption)
                        .monospaced()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)
            .accessibilityIdentifier("welcome.open")
        }
    }

    @ViewBuilder
    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if !visiblePinned.isEmpty {
                        sectionHeader("PINNED")
                        ForEach(visiblePinned) { doc in
                            documentCard(doc)
                        }
                    }

                    let visibleByGroup = recentsByGroup
                    let allEmpty = visiblePinned.isEmpty
                        && visibleByGroup.allSatisfy { $0.value.isEmpty }

                    if allEmpty {
                        emptyState
                    } else {
                        ForEach(DateGroup.allCases, id: \.rawValue) { group in
                            let docs = visibleByGroup[group] ?? []
                            if !docs.isEmpty {
                                sectionHeader(group.label.uppercased())
                                ForEach(docs) { doc in
                                    documentCard(doc)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.tertiary)
            TextField("Search documents", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)
                .accessibilityLabel("Search documents")
                .accessibilityIdentifier("welcome.search")
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            if searchText.isEmpty {
                Text("Documents you open will show up here.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No documents match \"\(searchText)\".")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func documentCard(_ doc: RecentDocument) -> some View {
        let isPinned = pinnedURLs.contains(doc.url)
        return HStack(alignment: .top, spacing: 12) {
            Button { openURL(doc.url) } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, alignment: .top)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(doc.displayTitle)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(doc.relativeDate)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        if !doc.preview.isEmpty {
                            Text(doc.preview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(doc.url.deletingLastPathComponent().path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(doc.displayTitle)")
            .accessibilityHint("Modified \(doc.relativeDate)")

            // Pin button — separate from the card-open button so VoiceOver
            // treats them as distinct actions, and hit area is enlarged via
            // a 44pt-square contentShape without inflating the visual icon.
            Button { togglePin(doc.url) } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.callout)
                    .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                    .rotationEffect(.degrees(isPinned ? 0 : 45))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isPinned ? "Unpin" : "Pin to top")
            .accessibilityLabel(isPinned ? "Unpin document" : "Pin document")
            .accessibilityHint(isPinned ? "Removes from pinned section" : "Keeps this document at the top of the list")
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
    }

    private var footer: some View {
        HStack {
            Toggle("Show this window when MDPrintView launches", isOn: Binding(
                get: { !suppressOnLaunch },
                set: { suppressOnLaunch = !$0 }
            ))
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .foregroundStyle(.secondary)
            Spacer()
            if !recents.isEmpty {
                Button("Clear Recents", action: clearRecents)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear recent documents")
            }
        }
    }

    // MARK: - Derived data

    /// Pinned docs that pass the search filter, in user-pin order.
    private var visiblePinned: [RecentDocument] {
        pinnedURLs
            .compactMap { url -> RecentDocument? in
                // Prefer the in-memory recent (already has preview cached);
                // fall back to a fresh load for pinned items that have aged
                // out of the recent list.
                recents.first(where: { $0.url == url }) ?? RecentDocument.load(from: url)
            }
            .filter { $0.matches(searchText) }
    }

    /// Non-pinned recents, bucketed by DateGroup, filtered by search.
    private var recentsByGroup: [DateGroup: [RecentDocument]] {
        var buckets: [DateGroup: [RecentDocument]] = [:]
        for doc in recents where !pinnedURLs.contains(doc.url) && doc.matches(searchText) {
            buckets[DateGroup.group(for: doc.modificationDate), default: []].append(doc)
        }
        // Sort each bucket newest-first.
        for key in buckets.keys {
            buckets[key]?.sort { $0.modificationDate > $1.modificationDate }
        }
        return buckets
    }

    // MARK: - Actions

    private func refresh() {
        recents = NSDocumentController.shared.recentDocumentURLs
            .compactMap { RecentDocument.load(from: $0) }
        pinnedURLs = PinnedDocuments.shared.urls
    }

    private func togglePin(_ url: URL) {
        PinnedDocuments.shared.toggle(url)
        pinnedURLs = PinnedDocuments.shared.urls
    }

    private func createNewDocument() {
        do {
            try NSDocumentController.shared.openUntitledDocumentAndDisplay(true)
            closeWelcome()
        } catch {
            print("[MDPrintView] Failed to open untitled doc: \(error)")
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

    private func clearRecents() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        refresh()
    }

    private func closeWelcome() {
        dismissWindow(id: "welcome")
    }
}

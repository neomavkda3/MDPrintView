import SwiftUI
import AppKit

@main
struct MdviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = AppSettings()

    init() {
        // Cluster all document windows as tabs of a single mdview window
        // by default. Per-window `tabbingMode = .preferred` (set via
        // WindowAccessor inside DocumentView) overrides the user's system
        // tabbing preference so new docs land as tabs even when the system
        // pref is "Manually" or "In Full Screen".
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    var body: some Scene {
        // === Launch flow ===
        //
        // On macOS 15+, SwiftUI's `DocumentGroup` presents its own document-
        // browser scene by default on launch — what looked like the "Finder
        // file viewer" you kept seeing. We don't want that; we want a
        // welcome window.
        //
        // The native SwiftUI way: make the Welcome `Window` the default
        // launch scene with `.defaultLaunchBehavior(.presented)`, and mark
        // `DocumentGroup` as `.suppressed` so it only opens windows in
        // response to actual file opens (Cmd+O, file-double-click, etc.).
        Window("Welcome to mdview", id: "welcome") {
            WelcomeView()
                .environment(settings)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.presented)

        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            DocumentView(document: file.document)
                .environment(settings)
        }
        .defaultLaunchBehavior(.suppressed)
        .commands {
            CommandGroup(replacing: .printItem) {
                PrintMenuItem()
                ExportPDFMenuItem()
            }
            LayoutCommands(settings: settings)
        }

        Settings {
            SettingsView()
                .environment(settings)
        }
    }
}

private struct PrintMenuItem: View {
    @FocusedValue(\.printPreview) private var printAction

    var body: some View {
        Button("Print…") { printAction?() }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(printAction == nil)
    }
}

private struct ExportPDFMenuItem: View {
    @FocusedValue(\.exportPDF) private var exportAction

    var body: some View {
        Button("Export as PDF…") { exportAction?() }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(exportAction == nil)
    }
}

private struct LayoutCommands: Commands {
    let settings: AppSettings

    var body: some Commands {
        CommandMenu("View") {
            Button("Editor Only") {
                settings.defaultLayoutMode = .editorOnly
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Split Editor & Preview") {
                settings.defaultLayoutMode = .split
            }
            .keyboardShortcut("2", modifiers: [.command, .option])

            Button("Preview Only") {
                settings.defaultLayoutMode = .previewOnly
            }
            .keyboardShortcut("3", modifiers: [.command, .option])
        }
    }
}

private struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Editor") {
                HStack {
                    Text("Font size")
                    Slider(value: $settings.editorFontSize, in: 10...24, step: 1)
                    Text("\(Int(settings.editorFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
                Picker("Font family", selection: $settings.editorFontFamily) {
                    ForEach(EditorFontFamily.allCases) { Text($0.label).tag($0) }
                }
            }
            Section("Print") {
                Picker("Page size", selection: $settings.defaultPageSize) {
                    ForEach(AppSettings.PageSize.allCases) { Text($0.label).tag($0) }
                }
            }
            Section("File handling") {
                Toggle("Ask to set mdview as default for Markdown files", isOn: Binding(
                    get: { !settings.suppressDefaultAppPrompt },
                    set: { newValue in
                        settings.suppressDefaultAppPrompt = !newValue
                        if newValue {
                            // User re-enabled the prompt; clear the session
                            // dedup so the next opened doc re-prompts.
                            DefaultAppCoordinator.resetForCurrentSession()
                        }
                    }
                ))
                Toggle("Show welcome window when mdview launches", isOn: Binding(
                    get: { !settings.suppressWelcomeOnLaunch },
                    set: { settings.suppressWelcomeOnLaunch = !$0 }
                ))
            }
        }
        .padding()
        .frame(width: 460, height: 300)
    }
}

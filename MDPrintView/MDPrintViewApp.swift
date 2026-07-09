import SwiftUI
import AppKit
import Sparkle

@main
struct MDPrintViewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = AppSettings()
    // Read directly here (not via AppSettings) because scene-builder
    // modifiers run before the environment is available.
    @AppStorage("suppressWelcomeOnLaunch") private var suppressWelcomeOnLaunch = false

    /// Sparkle's standard updater. Started at init so the first background
    /// check fires shortly after launch.
    private let updaterController: SPUStandardUpdaterController

    init() {
        // Cluster all document windows as tabs of a single MDPrintView window
        // by default. Per-window `tabbingMode = .preferred` (set via
        // WindowAccessor inside DocumentView) overrides the user's system
        // tabbing preference so new docs land as tabs even when the system
        // pref is "Manually" or "In Full Screen".
        NSWindow.allowsAutomaticWindowTabbing = true

        // Sparkle reads SUFeedURL + SUPublicEDKey + SUEnableAutomaticChecks
        // from Info.plist. `startingUpdater: true` kicks off the scheduled
        // background check using SUScheduledCheckInterval (24h here).
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
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
        Window("Welcome to MDPrintView", id: "welcome") {
            WelcomeView()
                .environment(settings)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        // Honor the "Show this window when MDPrintView launches" toggle.
        // .automatic (not .suppressed) when opted out, so the window can
        // still be opened on demand via dock-menu or Window menu.
        .defaultLaunchBehavior(suppressWelcomeOnLaunch ? .automatic : .presented)

        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            DocumentView(document: file.document, fileURL: file.fileURL)
                .environment(settings)
        }
        .defaultLaunchBehavior(.suppressed)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            // SwiftUI only auto-injects New/Open into File when a
            // DocumentGroup is the FIRST scene. Ours isn't — the Welcome
            // Window scene comes first (so `.defaultLaunchBehavior(.presented)`
            // works) — so we wire New and Open explicitly through
            // NSDocumentController.
            CommandGroup(replacing: .newItem) {
                Button("New") { NSDocumentController.shared.newDocument(nil) }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open…") { NSDocumentController.shared.openDocument(nil) }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .printItem) {
                PrintMenuItem()
                ExportPDFMenuItem()
            }
            FindAndSpellCommands()
            LayoutCommands(settings: settings)
            CommandGroup(after: .help) {
                Button("What's New in MDPrintView") {
                    if let url = URL(string: "https://github.com/neomavkda3/MDPrintView/blob/main/CHANGELOG.md") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        Settings {
            SettingsView(updater: updaterController.updater)
                .environment(settings)
        }
    }
}

/// Menu item that wires `SPUUpdater.checkForUpdates()` to the "Check for
/// Updates…" item under the MDPrintView application menu. The
/// `canCheckForUpdates` binding disables the menu while Sparkle is
/// already running a check, which matches the system Mail / Safari /
/// Xcode pattern.
private struct CheckForUpdatesView: View {
    private let updater: SPUUpdater
    @State private var canCheck: Bool = true

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!canCheck)
        .onReceive(updater.publisher(for: \.canCheckForUpdates)) { canCheck = $0 }
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

/// Standard macOS Edit-menu items for Find and Spelling/Grammar that
/// SwiftUI does NOT include in `.textEditingCommands` — you have to
/// wire them yourself. All items dispatch via `NSApp.sendAction(_:to:from:)`
/// so they route through the responder chain to whichever `NSTextView`
/// (or `NSResponder`) is first responder.
///
/// Find uses the modern find bar (see `MarkdownTextView.makeNSView`),
/// which requires `textView.usesFindBar = true`. Actions are identified
/// by an `NSTextFinder.Action` raw value carried in a sender's `tag` —
/// AppKit reads that tag inside `performTextFinderAction:` to decide
/// which action to run.
private struct FindAndSpellCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Section {
                Button("Find…") { performTextFinder(.showFindInterface) }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") { performTextFinder(.nextMatch) }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") { performTextFinder(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { performTextFinder(.setSearchString) }
                    .keyboardShortcut("e", modifiers: .command)
                Button("Jump to Selection") {
                    NSApp.sendAction(#selector(NSResponder.centerSelectionInVisibleArea(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("j", modifiers: .command)
            }
            Section {
                Menu("Spelling and Grammar") {
                    Button("Show Spelling and Grammar") {
                        NSApp.sendAction(#selector(NSText.showGuessPanel(_:)), to: nil, from: nil)
                    }
                    .keyboardShortcut(":", modifiers: .command)
                    Button("Check Document Now") {
                        NSApp.sendAction(#selector(NSText.checkSpelling(_:)), to: nil, from: nil)
                    }
                    .keyboardShortcut(";", modifiers: .command)
                    Divider()
                    Button("Check Spelling While Typing") {
                        NSApp.sendAction(#selector(NSTextView.toggleContinuousSpellChecking(_:)), to: nil, from: nil)
                    }
                    Button("Check Grammar With Spelling") {
                        NSApp.sendAction(#selector(NSTextView.toggleGrammarChecking(_:)), to: nil, from: nil)
                    }
                }
            }
        }
    }

    /// AppKit routes Find actions by reading the `tag` on the sender. We
    /// forge a menu-item sender with the right tag and let the responder
    /// chain deliver it to the current NSTextView.
    private func performTextFinder(_ action: NSTextFinder.Action) {
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        NSApp.sendAction(#selector(NSTextView.performTextFinderAction(_:)), to: nil, from: sender)
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
    let updater: SPUUpdater
    /// Mirrors `updater.automaticallyDownloadsUpdates`. We keep it in local
    /// state so SwiftUI can bind a Toggle to it; onAppear seeds from the
    /// live value, onChange writes back to Sparkle.
    @State private var autoInstallUpdates: Bool = true

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("Editor") {
                HStack {
                    Text("Font size")
                    Slider(value: $settings.editorFontSize, in: 10...24, step: 1)
                    Text("\(Int(settings.editorFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
                HStack {
                    Picker("Font family", selection: $settings.editorFontFamily) {
                        ForEach(EditorFontFamily.Category.allCases) { category in
                            Section(category.rawValue) {
                                ForEach(EditorFontFamily.allCases.filter { $0.category == category }) { family in
                                    // Show the actual chosen name instead of
                                    // "Custom" so the picker reflects state.
                                    if family == .custom {
                                        Text(settings.editorCustomFontFamily.isEmpty
                                             ? "Choose…"
                                             : settings.editorCustomFontFamily)
                                            .tag(family)
                                    } else {
                                        Text(family.label).tag(family)
                                    }
                                }
                            }
                        }
                    }
                    Button("Browse…") {
                        let current = settings.editorFontFamily.nsFont(size: settings.editorFontSize)
                        FontPickerCoordinator.shared.show(
                            currentFontName: current.familyName ?? current.fontName,
                            size: settings.editorFontSize
                        ) { name in
                            settings.editorCustomFontFamily = name
                            settings.editorFontFamily = .custom
                        }
                    }
                    .controlSize(.small)
                }
            }
            Section("Print") {
                Picker("Page size", selection: $settings.defaultPageSize) {
                    ForEach(AppSettings.PageSize.allCases) { Text($0.label).tag($0) }
                }
            }
            Section("File handling") {
                Toggle("Ask to set MDPrintView as default for Markdown files", isOn: Binding(
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
                Toggle("Show welcome window when MDPrintView launches", isOn: Binding(
                    get: { !settings.suppressWelcomeOnLaunch },
                    set: { settings.suppressWelcomeOnLaunch = !$0 }
                ))
            }
            Section("Software Updates") {
                Toggle("Install updates automatically", isOn: $autoInstallUpdates)
                    .onChange(of: autoInstallUpdates) { _, newValue in
                        updater.automaticallyDownloadsUpdates = newValue
                    }
                Text("MDPrintView checks for a new version once a day and on launch. When this is on, updates are downloaded and installed on your next relaunch. When it's off, you'll see a dialog asking permission first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(width: 460, height: 460)
        .onAppear {
            autoInstallUpdates = updater.automaticallyDownloadsUpdates
        }
    }
}

import SwiftUI
import AppKit

enum EditorFontFamily: String, CaseIterable, Identifiable {
    case systemMono
    case systemSerif
    case systemSans

    var id: String { rawValue }

    var label: String {
        switch self {
        case .systemMono: return "System Mono"
        case .systemSerif: return "New York (Serif)"
        case .systemSans: return "SF Pro (Sans)"
        }
    }

    func nsFont(size: CGFloat) -> NSFont {
        switch self {
        case .systemMono:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .systemSerif:
            return NSFont(name: "NewYork", size: size) ?? NSFont.systemFont(ofSize: size)
        case .systemSans:
            return NSFont.systemFont(ofSize: size)
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored
    @AppStorage("editorFontSize") private var storedEditorFontSize: Double = 14

    var editorFontSize: Double {
        get { access(keyPath: \.editorFontSize); return storedEditorFontSize }
        set { withMutation(keyPath: \.editorFontSize) { storedEditorFontSize = newValue } }
    }

    @ObservationIgnored
    @AppStorage("editorFontFamily") private var storedEditorFontFamily: String = EditorFontFamily.systemMono.rawValue

    var editorFontFamily: EditorFontFamily {
        get {
            access(keyPath: \.editorFontFamily)
            return EditorFontFamily(rawValue: storedEditorFontFamily) ?? .systemMono
        }
        set {
            withMutation(keyPath: \.editorFontFamily) { storedEditorFontFamily = newValue.rawValue }
        }
    }

    @ObservationIgnored
    @AppStorage("defaultPageSize") private var storedPageSize: String = PageSize.letter.rawValue

    var defaultPageSize: PageSize {
        get {
            access(keyPath: \.defaultPageSize)
            return PageSize(rawValue: storedPageSize) ?? .letter
        }
        set {
            withMutation(keyPath: \.defaultPageSize) { storedPageSize = newValue.rawValue }
        }
    }

    @ObservationIgnored
    @AppStorage("defaultLayoutMode") private var storedLayoutMode: String = LayoutMode.split.rawValue

    var defaultLayoutMode: LayoutMode {
        get {
            access(keyPath: \.defaultLayoutMode)
            return LayoutMode(rawValue: storedLayoutMode) ?? .split
        }
        set {
            withMutation(keyPath: \.defaultLayoutMode) { storedLayoutMode = newValue.rawValue }
        }
    }

    @ObservationIgnored
    @AppStorage("suppressDefaultAppPrompt") private var storedSuppressDefaultAppPrompt: Bool = false

    var suppressDefaultAppPrompt: Bool {
        get { access(keyPath: \.suppressDefaultAppPrompt); return storedSuppressDefaultAppPrompt }
        set { withMutation(keyPath: \.suppressDefaultAppPrompt) { storedSuppressDefaultAppPrompt = newValue } }
    }

    @ObservationIgnored
    @AppStorage("suppressWelcomeOnLaunch") private var storedSuppressWelcomeOnLaunch: Bool = false

    var suppressWelcomeOnLaunch: Bool {
        get { access(keyPath: \.suppressWelcomeOnLaunch); return storedSuppressWelcomeOnLaunch }
        set { withMutation(keyPath: \.suppressWelcomeOnLaunch) { storedSuppressWelcomeOnLaunch = newValue } }
    }

    @ObservationIgnored
    @AppStorage("appearance") private var storedAppearance: String = Appearance.system.rawValue

    var appearance: Appearance {
        get {
            access(keyPath: \.appearance)
            return Appearance(rawValue: storedAppearance) ?? .system
        }
        set {
            withMutation(keyPath: \.appearance) { storedAppearance = newValue.rawValue }
            // Push to NSApp so AppKit-rendered surfaces (NSAlert, open panel,
            // tab bar) honor the choice — not just SwiftUI views.
            NSApp.appearance = newValue.nsAppearance
        }
    }

    /// Called once at launch from AppDelegate so the appearance is applied
    /// before any window comes on screen — otherwise the welcome flashes
    /// in system mode before flipping.
    func applyAppearanceToApp() {
        NSApp.appearance = appearance.nsAppearance
    }

    enum PageSize: String, CaseIterable, Identifiable {
        case letter
        case a4
        var id: String { rawValue }
        var label: String { self == .letter ? "US Letter" : "A4" }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: return "System"
            case .light:  return "Light"
            case .dark:   return "Dark"
            }
        }

        /// Nil → inherit system preference. Non-nil overrides NSApp.appearance.
        var nsAppearance: NSAppearance? {
            switch self {
            case .system: return nil
            case .light:  return NSAppearance(named: .aqua)
            case .dark:   return NSAppearance(named: .darkAqua)
            }
        }
    }
}

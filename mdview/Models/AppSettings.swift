import SwiftUI
import AppKit

enum EditorFontFamily: String, CaseIterable, Identifiable {
    // Monospaced
    case systemMono
    case menlo
    case monaco
    case courierNew

    // Serif
    case systemSerif
    case georgia
    case iowanOldStyle
    case palatino

    // Sans-serif
    case systemSans
    case helveticaNeue
    case avenirNext

    var id: String { rawValue }

    var label: String {
        switch self {
        case .systemMono:    return "SF Mono"
        case .menlo:         return "Menlo"
        case .monaco:        return "Monaco"
        case .courierNew:    return "Courier New"
        case .systemSerif:   return "New York"
        case .georgia:       return "Georgia"
        case .iowanOldStyle: return "Iowan Old Style"
        case .palatino:      return "Palatino"
        case .systemSans:    return "SF Pro"
        case .helveticaNeue: return "Helvetica Neue"
        case .avenirNext:    return "Avenir Next"
        }
    }

    var category: Category {
        switch self {
        case .systemMono, .menlo, .monaco, .courierNew:
            return .mono
        case .systemSerif, .georgia, .iowanOldStyle, .palatino:
            return .serif
        case .systemSans, .helveticaNeue, .avenirNext:
            return .sans
        }
    }

    func nsFont(size: CGFloat) -> NSFont {
        // Each branch falls back to a same-category system font if the
        // named family isn't installed — keeps the editor usable even if
        // a user has uninstalled an optional system font.
        switch self {
        case .systemMono:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .menlo:
            return NSFont(name: "Menlo", size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .monaco:
            return NSFont(name: "Monaco", size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .courierNew:
            return NSFont(name: "Courier New", size: size)
                ?? NSFont(name: "Courier", size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .systemSerif:
            return NSFont(name: "NewYork", size: size) ?? NSFont.systemFont(ofSize: size)
        case .georgia:
            return NSFont(name: "Georgia", size: size) ?? NSFont.systemFont(ofSize: size)
        case .iowanOldStyle:
            return NSFont(name: "Iowan Old Style", size: size)
                ?? NSFont(name: "NewYork", size: size)
                ?? NSFont.systemFont(ofSize: size)
        case .palatino:
            return NSFont(name: "Palatino", size: size)
                ?? NSFont(name: "Palatino LinoType", size: size)
                ?? NSFont.systemFont(ofSize: size)
        case .systemSans:
            return NSFont.systemFont(ofSize: size)
        case .helveticaNeue:
            return NSFont(name: "Helvetica Neue", size: size) ?? NSFont.systemFont(ofSize: size)
        case .avenirNext:
            return NSFont(name: "Avenir Next", size: size) ?? NSFont.systemFont(ofSize: size)
        }
    }

    enum Category: String, CaseIterable, Identifiable {
        case mono = "Monospaced"
        case serif = "Serif"
        case sans = "Sans-Serif"

        var id: String { rawValue }
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

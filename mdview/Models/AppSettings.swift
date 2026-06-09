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

    enum PageSize: String, CaseIterable, Identifiable {
        case letter
        case a4
        var id: String { rawValue }
        var label: String { self == .letter ? "US Letter" : "A4" }
    }
}

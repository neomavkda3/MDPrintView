import SwiftUI

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

    enum PageSize: String, CaseIterable, Identifiable {
        case letter
        case a4
        var id: String { rawValue }
        var label: String { self == .letter ? "US Letter" : "A4" }
    }
}

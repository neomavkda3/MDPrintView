import Foundation

enum LayoutMode: String, CaseIterable, Identifiable {
    case editorOnly
    case split
    case previewOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .editorOnly: return "Editor"
        case .split: return "Split"
        case .previewOnly: return "Preview"
        }
    }

    var systemImage: String {
        switch self {
        case .editorOnly: return "rectangle.lefthalf.filled"
        case .split: return "rectangle.split.2x1"
        case .previewOnly: return "rectangle.righthalf.filled"
        }
    }

    var showsEditor: Bool { self != .previewOnly }
    var showsPreview: Bool { self != .editorOnly }
}

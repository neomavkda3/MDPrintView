import Foundation

enum EditorMode: String, CaseIterable, Identifiable {
    case source
    case hybrid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .source: return "Source"
        case .hybrid: return "Hybrid"
        }
    }
}

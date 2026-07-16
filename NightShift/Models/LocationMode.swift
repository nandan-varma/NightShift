import Foundation

enum LocationMode: String, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }
}

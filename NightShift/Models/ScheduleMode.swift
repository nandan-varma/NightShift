import Foundation

enum ScheduleMode: String, CaseIterable, Identifiable {
    case auto
    case forceDay
    case forceNight
    case off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .forceDay: return "Day"
        case .forceNight: return "Night"
        case .off: return "Off"
        }
    }
}

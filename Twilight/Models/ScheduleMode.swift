import Foundation

enum ScheduleMode: String, CaseIterable, Identifiable {
    case auto
    case forceDay
    case forceNight
    case off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "Auto"
        case .forceDay: "Day"
        case .forceNight: "Night"
        case .off: "Off"
        }
    }
}

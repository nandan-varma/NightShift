import Foundation

enum SchedulePhase: Equatable {
    case day
    case night
    case transitioningToNight
    case transitioningToDay
    case off
}

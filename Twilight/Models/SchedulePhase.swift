import Foundation

enum SchedulePhase: Equatable {
    case day
    case night
    case transitioningToNight
    case transitioningToDay
    case off
}

/// What the next scheduled boundary is — used for countdown labels, which
/// differ between the solar schedule (sunrise/sunset) and a custom
/// fixed-clock schedule (warm period starts/ends).
enum TransitionKind: Equatable {
    case sunrise
    case sunset
    case warmStart
    case warmEnd
}

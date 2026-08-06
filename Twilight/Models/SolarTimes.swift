import Foundation

struct SolarTimes: Equatable {
    enum DayKind: Equatable {
        case normal(sunrise: Date, sunset: Date)
        case polarDay
        case polarNight
    }

    var dayKind: DayKind
    var referenceDate: Date

    var sunrise: Date? {
        if case let .normal(sunrise, _) = dayKind { return sunrise }
        return nil
    }

    var sunset: Date? {
        if case let .normal(_, sunset) = dayKind { return sunset }
        return nil
    }
}

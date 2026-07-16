import Foundation
import Combine

/// UserDefaults-backed store of all user-configurable preferences.
/// Each property publishes changes (for SwiftUI) and persists immediately on set.
final class SettingsStore: ObservableObject {
    private enum Key {
        static let dayColorTemperatureKelvin = "dayColorTemperatureKelvin"
        static let nightColorTemperatureKelvin = "nightColorTemperatureKelvin"
        static let transitionDurationMinutes = "transitionDurationMinutes"
        static let scheduleMode = "scheduleMode"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let locationName = "locationName"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let bedtimeRampEnabled = "bedtimeRampEnabled"
        static let bedtimeHour = "bedtimeHour"
        static let bedtimeMinute = "bedtimeMinute"
        static let bedtimeColorTemperatureKelvin = "bedtimeColorTemperatureKelvin"
    }

    private let defaults: UserDefaults

    @Published var dayColorTemperatureKelvin: Double {
        didSet { defaults.set(dayColorTemperatureKelvin, forKey: Key.dayColorTemperatureKelvin) }
    }

    @Published var nightColorTemperatureKelvin: Double {
        didSet { defaults.set(nightColorTemperatureKelvin, forKey: Key.nightColorTemperatureKelvin) }
    }

    @Published var transitionDurationMinutes: Double {
        didSet { defaults.set(transitionDurationMinutes, forKey: Key.transitionDurationMinutes) }
    }

    @Published var scheduleMode: ScheduleMode {
        didSet { defaults.set(scheduleMode.rawValue, forKey: Key.scheduleMode) }
    }

    @Published var latitude: Double {
        didSet { defaults.set(latitude, forKey: Key.latitude) }
    }

    @Published var longitude: Double {
        didSet { defaults.set(longitude, forKey: Key.longitude) }
    }

    @Published var locationName: String {
        didSet { defaults.set(locationName, forKey: Key.locationName) }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet { defaults.set(launchAtLoginEnabled, forKey: Key.launchAtLoginEnabled) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    /// Opt-in: gradually warms further over the hour before `bedtimeHour:bedtimeMinute`,
    /// down to `bedtimeColorTemperatureKelvin` — the pre-sleep window is where color
    /// temperature matters most for melatonin, and it rarely lines up with sunset.
    @Published var bedtimeRampEnabled: Bool {
        didSet { defaults.set(bedtimeRampEnabled, forKey: Key.bedtimeRampEnabled) }
    }

    @Published var bedtimeHour: Int {
        didSet { defaults.set(bedtimeHour, forKey: Key.bedtimeHour) }
    }

    @Published var bedtimeMinute: Int {
        didSet { defaults.set(bedtimeMinute, forKey: Key.bedtimeMinute) }
    }

    @Published var bedtimeColorTemperatureKelvin: Double {
        didSet { defaults.set(bedtimeColorTemperatureKelvin, forKey: Key.bedtimeColorTemperatureKelvin) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Night default (2700K) and a longer, more gradual 60-minute transition
        // are chosen to meaningfully cut blue/cyan light in the evening while
        // mimicking the ~1h span of natural dusk/dawn twilight rather than an
        // abrupt swing.
        dayColorTemperatureKelvin = defaults.object(forKey: Key.dayColorTemperatureKelvin) as? Double ?? 6500
        nightColorTemperatureKelvin = defaults.object(forKey: Key.nightColorTemperatureKelvin) as? Double ?? 2700
        transitionDurationMinutes = defaults.object(forKey: Key.transitionDurationMinutes) as? Double ?? 60
        scheduleMode = ScheduleMode(rawValue: defaults.string(forKey: Key.scheduleMode) ?? "") ?? .auto
        latitude = defaults.object(forKey: Key.latitude) as? Double ?? 0
        longitude = defaults.object(forKey: Key.longitude) as? Double ?? 0
        locationName = defaults.string(forKey: Key.locationName) ?? ""
        launchAtLoginEnabled = defaults.bool(forKey: Key.launchAtLoginEnabled)
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        bedtimeRampEnabled = defaults.bool(forKey: Key.bedtimeRampEnabled)
        bedtimeHour = defaults.object(forKey: Key.bedtimeHour) as? Int ?? 23
        bedtimeMinute = defaults.object(forKey: Key.bedtimeMinute) as? Int ?? 0
        bedtimeColorTemperatureKelvin = defaults.object(forKey: Key.bedtimeColorTemperatureKelvin) as? Double ?? 2300
    }
}

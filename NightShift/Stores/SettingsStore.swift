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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        dayColorTemperatureKelvin = defaults.object(forKey: Key.dayColorTemperatureKelvin) as? Double ?? 6500
        nightColorTemperatureKelvin = defaults.object(forKey: Key.nightColorTemperatureKelvin) as? Double ?? 3400
        transitionDurationMinutes = defaults.object(forKey: Key.transitionDurationMinutes) as? Double ?? 30
        scheduleMode = ScheduleMode(rawValue: defaults.string(forKey: Key.scheduleMode) ?? "") ?? .auto
        latitude = defaults.object(forKey: Key.latitude) as? Double ?? 0
        longitude = defaults.object(forKey: Key.longitude) as? Double ?? 0
        locationName = defaults.string(forKey: Key.locationName) ?? ""
        launchAtLoginEnabled = defaults.bool(forKey: Key.launchAtLoginEnabled)
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
    }
}

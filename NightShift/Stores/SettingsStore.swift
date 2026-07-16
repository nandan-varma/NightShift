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
        static let locationMode = "locationMode"
        static let manualLatitude = "manualLatitude"
        static let manualLongitude = "manualLongitude"
        static let manualLocationName = "manualLocationName"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let hasRequestedLocationPermission = "hasRequestedLocationPermission"
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

    @Published var locationMode: LocationMode {
        didSet { defaults.set(locationMode.rawValue, forKey: Key.locationMode) }
    }

    @Published var manualLatitude: Double {
        didSet { defaults.set(manualLatitude, forKey: Key.manualLatitude) }
    }

    @Published var manualLongitude: Double {
        didSet { defaults.set(manualLongitude, forKey: Key.manualLongitude) }
    }

    @Published var manualLocationName: String {
        didSet { defaults.set(manualLocationName, forKey: Key.manualLocationName) }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet { defaults.set(launchAtLoginEnabled, forKey: Key.launchAtLoginEnabled) }
    }

    @Published var hasRequestedLocationPermission: Bool {
        didSet { defaults.set(hasRequestedLocationPermission, forKey: Key.hasRequestedLocationPermission) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        dayColorTemperatureKelvin = defaults.object(forKey: Key.dayColorTemperatureKelvin) as? Double ?? 6500
        nightColorTemperatureKelvin = defaults.object(forKey: Key.nightColorTemperatureKelvin) as? Double ?? 3400
        transitionDurationMinutes = defaults.object(forKey: Key.transitionDurationMinutes) as? Double ?? 30
        scheduleMode = ScheduleMode(rawValue: defaults.string(forKey: Key.scheduleMode) ?? "") ?? .auto
        locationMode = LocationMode(rawValue: defaults.string(forKey: Key.locationMode) ?? "") ?? .automatic
        manualLatitude = defaults.object(forKey: Key.manualLatitude) as? Double ?? 0
        manualLongitude = defaults.object(forKey: Key.manualLongitude) as? Double ?? 0
        manualLocationName = defaults.string(forKey: Key.manualLocationName) ?? ""
        launchAtLoginEnabled = defaults.bool(forKey: Key.launchAtLoginEnabled)
        hasRequestedLocationPermission = defaults.bool(forKey: Key.hasRequestedLocationPermission)
    }
}

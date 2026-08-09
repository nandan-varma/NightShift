import Foundation
import Observation

/// UserDefaults-backed store of all user-configurable preferences.
/// Each property is Observation-tracked (for SwiftUI) and persists immediately on set.
@Observable
final class SettingsStore {
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
        static let wakeRampEnabled = "wakeRampEnabled"
        static let wakeHour = "wakeHour"
        static let wakeMinute = "wakeMinute"
        static let suspendUntil = "suspendUntil"
        static let customWarmStartHour = "customWarmStartHour"
        static let customWarmStartMinute = "customWarmStartMinute"
        static let customWarmEndHour = "customWarmEndHour"
        static let customWarmEndMinute = "customWarmEndMinute"
        static let menuBarIconName = "menuBarIconName"
        static let displayOffsets = "displayOffsets"
    }

    /// The single app-wide instance, shared by the AppDelegate, the views, and
    /// App Intents (which may launch the app in the background without the
    /// AppDelegate having been created yet).
    @MainActor static let shared = SettingsStore()

    private let defaults: UserDefaults

    var dayColorTemperatureKelvin: Double {
        didSet { defaults.set(dayColorTemperatureKelvin, forKey: Key.dayColorTemperatureKelvin) }
    }

    var nightColorTemperatureKelvin: Double {
        didSet { defaults.set(nightColorTemperatureKelvin, forKey: Key.nightColorTemperatureKelvin) }
    }

    var transitionDurationMinutes: Double {
        didSet { defaults.set(transitionDurationMinutes, forKey: Key.transitionDurationMinutes) }
    }

    /// Changing the mode explicitly cancels any active suspension — if the
    /// user reaches for a mode, they want it to take effect immediately.
    var scheduleMode: ScheduleMode {
        didSet {
            if scheduleMode != oldValue { suspendUntil = nil }
            defaults.set(scheduleMode.rawValue, forKey: Key.scheduleMode)
        }
    }

    var latitude: Double {
        didSet { defaults.set(latitude, forKey: Key.latitude) }
    }

    var longitude: Double {
        didSet { defaults.set(longitude, forKey: Key.longitude) }
    }

    var locationName: String {
        didSet { defaults.set(locationName, forKey: Key.locationName) }
    }

    var launchAtLoginEnabled: Bool {
        didSet { defaults.set(launchAtLoginEnabled, forKey: Key.launchAtLoginEnabled) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    /// Opt-in: gradually warms further over the hour before `bedtimeHour:bedtimeMinute`,
    /// down to `bedtimeColorTemperatureKelvin` — the pre-sleep window is where color
    /// temperature matters most for melatonin, and it rarely lines up with sunset.
    var bedtimeRampEnabled: Bool {
        didSet { defaults.set(bedtimeRampEnabled, forKey: Key.bedtimeRampEnabled) }
    }

    var bedtimeHour: Int {
        didSet { defaults.set(bedtimeHour, forKey: Key.bedtimeHour) }
    }

    var bedtimeMinute: Int {
        didSet { defaults.set(bedtimeMinute, forKey: Key.bedtimeMinute) }
    }

    var bedtimeColorTemperatureKelvin: Double {
        didSet { defaults.set(bedtimeColorTemperatureKelvin, forKey: Key.bedtimeColorTemperatureKelvin) }
    }

    /// Opt-in mirror of the bedtime taper: gradually brightens from the night
    /// warmth back toward `dayColorTemperatureKelvin` over the hour before
    /// `wakeHour:wakeMinute`, so the display is usable by wake-up time even
    /// when sunrise is still hours away.
    var wakeRampEnabled: Bool {
        didSet { defaults.set(wakeRampEnabled, forKey: Key.wakeRampEnabled) }
    }

    var wakeHour: Int {
        didSet { defaults.set(wakeHour, forKey: Key.wakeHour) }
    }

    var wakeMinute: Int {
        didSet { defaults.set(wakeMinute, forKey: Key.wakeMinute) }
    }

    /// Temporary suspension of scheduling: while set, the display stays neutral
    /// (as in `.off`) until `suspendUntil` passes, then scheduling resumes
    /// automatically. Set by "Suspend for 1 Hour" / "Suspend until Sunrise".
    var suspendUntil: Date? {
        didSet { defaults.set(suspendUntil, forKey: Key.suspendUntil) }
    }

    /// Fixed-clock warm window for `.custom` mode (night-shift schedules).
    /// The window may cross midnight: if the end time is earlier than the
    /// start, it wraps to the following day.
    var customWarmStartHour: Int {
        didSet { defaults.set(customWarmStartHour, forKey: Key.customWarmStartHour) }
    }

    var customWarmStartMinute: Int {
        didSet { defaults.set(customWarmStartMinute, forKey: Key.customWarmStartMinute) }
    }

    var customWarmEndHour: Int {
        didSet { defaults.set(customWarmEndHour, forKey: Key.customWarmEndHour) }
    }

    var customWarmEndMinute: Int {
        didSet { defaults.set(customWarmEndMinute, forKey: Key.customWarmEndMinute) }
    }

    /// SF Symbol used for the menu bar icon. Empty string = adaptive: the icon
    /// follows the current phase (sun / moon / haze / off).
    var menuBarIconName: String {
        didSet { defaults.set(menuBarIconName, forKey: Key.menuBarIconName) }
    }

    /// Per-display Kelvin offsets, keyed by `CGDisplayCreateUUIDFromDisplayID`
    /// UUID string. A negative offset makes that display warmer. Applied on top
    /// of the scheduled Kelvin in `DisplayGammaController`.
    var displayOffsets: [String: Double] {
        didSet { defaults.set(displayOffsets, forKey: Key.displayOffsets) }
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
        wakeRampEnabled = defaults.bool(forKey: Key.wakeRampEnabled)
        wakeHour = defaults.object(forKey: Key.wakeHour) as? Int ?? 7
        wakeMinute = defaults.object(forKey: Key.wakeMinute) as? Int ?? 0
        suspendUntil = defaults.object(forKey: Key.suspendUntil) as? Date
        customWarmStartHour = defaults.object(forKey: Key.customWarmStartHour) as? Int ?? 22
        customWarmStartMinute = defaults.object(forKey: Key.customWarmStartMinute) as? Int ?? 0
        customWarmEndHour = defaults.object(forKey: Key.customWarmEndHour) as? Int ?? 6
        customWarmEndMinute = defaults.object(forKey: Key.customWarmEndMinute) as? Int ?? 0
        menuBarIconName = defaults.string(forKey: Key.menuBarIconName) ?? ""
        displayOffsets = (defaults.dictionary(forKey: Key.displayOffsets) as? [String: Double]) ?? [:]
    }
}

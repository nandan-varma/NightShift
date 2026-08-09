import Testing
import Foundation
@testable import Twilight

@MainActor
struct FadeAndScheduledKelvinTests {
    private func makeSettings(
        day: Double = 6500,
        night: Double = 3400,
        transitionMinutes: Double = 30,
        mode: ScheduleMode = .auto
    ) -> SettingsStore {
        let suiteName = "com.nandanvarma.Twilight.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)
        store.dayColorTemperatureKelvin = day
        store.nightColorTemperatureKelvin = night
        store.transitionDurationMinutes = transitionMinutes
        store.scheduleMode = mode
        return store
    }

    private var fixedSolar: SolarTimes {
        let sunrise = Date(timeIntervalSince1970: 1_718_000_000)
        let sunset = sunrise.addingTimeInterval(12 * 3600)
        return SolarTimes(dayKind: .normal(sunrise: sunrise, sunset: sunset), referenceDate: sunrise)
    }

    // MARK: - fadedKelvin (mode-switch fade)

    @Test func fadeAtStartIsFromKelvin() {
        #expect(ScheduleEngine.fadedKelvin(from: 6500, to: 2700, progress: 0) == 6500)
    }

    @Test func fadeAtEndIsToKelvin() {
        #expect(ScheduleEngine.fadedKelvin(from: 6500, to: 2700, progress: 1) == 2700)
    }

    @Test func fadeMidpointIsHalfway() {
        // Smoothstep(0.5) == 0.5 → halfway between the two endpoints.
        #expect(abs(ScheduleEngine.fadedKelvin(from: 6500, to: 2700, progress: 0.5) - 4600) < 1)
    }

    @Test func fadeClampsOutOfRangeProgress() {
        #expect(ScheduleEngine.fadedKelvin(from: 6500, to: 2700, progress: -1) == 6500)
        #expect(ScheduleEngine.fadedKelvin(from: 6500, to: 2700, progress: 2) == 2700)
    }

    // MARK: - scheduledKelvin (used by the 24-hour preview curve)

    @Test func scheduledKelvinInAutoModeFollowsTheSolarSchedule() {
        let settings = makeSettings()
        guard case .normal(let sunrise, let sunset) = fixedSolar.dayKind else { fatalError() }
        let midday = sunrise.addingTimeInterval(sunset.timeIntervalSince(sunrise) / 2)
        let midnight = sunset.addingTimeInterval(6 * 3600)

        let middayKelvin = ScheduleEngine.scheduledKelvin(now: midday, solar: fixedSolar, settings: settings)
        let midnightKelvin = ScheduleEngine.scheduledKelvin(now: midnight, solar: fixedSolar, settings: settings)
        #expect(middayKelvin == settings.dayColorTemperatureKelvin)
        #expect(midnightKelvin == settings.nightColorTemperatureKelvin)
    }

    @Test func scheduledKelvinInForcedModesReturnsTheFixedValue() {
        let dayMode = makeSettings(mode: .forceDay)
        let dayKelvin = ScheduleEngine.scheduledKelvin(now: Date(), solar: nil, settings: dayMode)
        #expect(dayKelvin == dayMode.dayColorTemperatureKelvin)

        let nightMode = makeSettings(mode: .forceNight)
        let nightKelvin = ScheduleEngine.scheduledKelvin(now: Date(), solar: nil, settings: nightMode)
        #expect(nightKelvin == nightMode.nightColorTemperatureKelvin)

        let offMode = makeSettings(mode: .off)
        let offKelvin = ScheduleEngine.scheduledKelvin(now: Date(), solar: nil, settings: offMode)
        #expect(offKelvin == offMode.dayColorTemperatureKelvin)
    }

    @Test func scheduledKelvinInCustomModeFollowsTheWarmWindow() {
        let settings = makeSettings(mode: .custom)
        settings.customWarmStartHour = 22
        settings.customWarmStartMinute = 0
        settings.customWarmEndHour = 6
        settings.customWarmEndMinute = 0

        var midday = DateComponents()
        midday.year = 2026
        midday.month = 6
        midday.day = 15
        midday.hour = 12
        let noon = Calendar.current.date(from: midday)!

        var night = DateComponents()
        night.year = 2026
        night.month = 6
        night.day = 15
        night.hour = 3
        let threeAM = Calendar.current.date(from: night)!

        let noonKelvin = ScheduleEngine.scheduledKelvin(now: noon, solar: nil, settings: settings)
        let nightKelvin = ScheduleEngine.scheduledKelvin(now: threeAM, solar: nil, settings: settings)
        #expect(noonKelvin == settings.dayColorTemperatureKelvin)
        #expect(nightKelvin == settings.nightColorTemperatureKelvin)
    }
}

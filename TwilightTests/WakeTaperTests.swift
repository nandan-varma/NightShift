import Testing
import Foundation
@testable import Twilight

@MainActor
struct WakeTaperTests {
    private func makeSettings(
        wakeHour: Int = 7,
        wakeMinute: Int = 0,
        enabled: Bool = true,
        day: Double = 6500,
        night: Double = 3400
    ) -> SettingsStore {
        let suiteName = "com.nandanvarma.Twilight.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)
        store.wakeRampEnabled = enabled
        store.wakeHour = wakeHour
        store.wakeMinute = wakeMinute
        store.dayColorTemperatureKelvin = day
        store.nightColorTemperatureKelvin = night
        return store
    }

    private func date(_ hour: Int, _ minute: Int, day: Int = 15) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    private func solarWithSunriseAt(_ hour: Int) -> SolarTimes {
        SolarTimes(
            dayKind: .normal(sunrise: date(hour, 0), sunset: date(20, 0)),
            referenceDate: date(0, 0)
        )
    }

    @Test func disabledLeavesBaseKelvinUnchanged() {
        let settings = makeSettings(enabled: false)
        let result = ScheduleEngine.applyWakeTaper(
            baseKelvin: 2700,
            phase: .night,
            now: date(6, 30),
            settings: settings
        )
        #expect(result == 2700)
    }

    @Test func wrongPhaseLeavesBaseKelvinUnchanged() {
        let settings = makeSettings()
        let result = ScheduleEngine.applyWakeTaper(baseKelvin: 6500, phase: .day, now: date(6, 30), settings: settings)
        #expect(result == 6500)
    }

    @Test func wellBeforeRampWindowLeavesBaseKelvinUnchanged() {
        let settings = makeSettings(wakeHour: 7, wakeMinute: 0)
        let result = ScheduleEngine.applyWakeTaper(baseKelvin: 2700, phase: .night, now: date(5, 0), settings: settings)
        #expect(result == 2700)
    }

    @Test func atWakeTimeHandsControlBackToSchedule() {
        let settings = makeSettings()
        let result = ScheduleEngine.applyWakeTaper(baseKelvin: 2700, phase: .night, now: date(7, 0), settings: settings)
        #expect(result == 2700)
    }

    @Test func afterWakeTimeLeavesBaseKelvinUnchanged() {
        let settings = makeSettings()
        let result = ScheduleEngine.applyWakeTaper(baseKelvin: 2700, phase: .night, now: date(8, 0), settings: settings)
        #expect(result == 2700)
    }

    @Test func midpointOfRampIsHalfwayToDayKelvin() {
        let settings = makeSettings(day: 6500)
        let result = ScheduleEngine.applyWakeTaper(
            baseKelvin: 2700,
            phase: .night,
            now: date(6, 30),
            settings: settings
        )
        #expect(result < 6500 && result > 2700)
        // Smoothstep(0.5) == 0.5 → exactly halfway between 2700 and 6500.
        #expect(abs(result - 4600) < 1)
    }

    @Test func autoKelvinAppliesWakeTaperOnlyAtNight() {
        let settings = makeSettings(wakeHour: 7, day: 6500, night: 3400)
        let solar = solarWithSunriseAt(8) // sunrise after wake: pre-wake is still night

        let preRamp = ScheduleEngine.autoKelvin(now: date(5, 30), solar: solar, settings: settings)
        #expect(preRamp == settings.nightColorTemperatureKelvin)

        let midRamp = ScheduleEngine.autoKelvin(now: date(6, 30), solar: solar, settings: settings)
        #expect(abs(midRamp - 4950) < 1)

        // Sunrise (8:00) has passed: phase is day, no taper — solar takes over.
        let postSunrise = ScheduleEngine.autoKelvin(now: date(8, 30), solar: solar, settings: settings)
        #expect(postSunrise == settings.dayColorTemperatureKelvin)
    }

    @Test func bedtimeAndWakeTapersChainTogether() {
        let settings = makeSettings(wakeHour: 7, day: 6500, night: 3400)
        settings.bedtimeRampEnabled = true
        settings.bedtimeHour = 23
        settings.bedtimeMinute = 0
        settings.bedtimeColorTemperatureKelvin = 2300

        // 22:30, night phase: bedtime taper pulls 3400 → 2850 (halfway to 2300);
        // the wake ramp (06:00–07:00) doesn't include 22:30, so it's unchanged.
        let result = ScheduleEngine.autoKelvin(now: date(22, 30), solar: solarWithSunriseAt(8), settings: settings)
        #expect(abs(result - 2850) < 1)
    }

    @Test func nearestWakeTimeResolvesAcrossMidnightBoundary() {
        let justAfterMidnight = date(0, 30)
        let wake = ScheduleEngine.nearestWakeTime(now: justAfterMidnight, hour: 23, minute: 0)
        #expect(wake == date(23, 0, day: 14))
    }
}

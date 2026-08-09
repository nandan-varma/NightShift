import Testing
import Foundation
@testable import Twilight

@MainActor
struct CustomScheduleTests {
    private func makeSettings(
        startHour: Int = 22,
        startMinute: Int = 0,
        endHour: Int = 6,
        endMinute: Int = 0,
        transitionMinutes: Double = 30,
        day: Double = 6500,
        night: Double = 3400
    ) -> SettingsStore {
        let suiteName = "com.nandanvarma.Twilight.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)
        store.customWarmStartHour = startHour
        store.customWarmStartMinute = startMinute
        store.customWarmEndHour = endHour
        store.customWarmEndMinute = endMinute
        store.transitionDurationMinutes = transitionMinutes
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

    private func kelvin(at hour: Int, _ minute: Int, settings: SettingsStore) -> Double {
        CustomSchedule.interpolatedKelvin(now: date(hour, minute), settings: settings)
    }

    // Default window 22:00–06:00 (crosses midnight).

    @Test func middayOutsideWindowIsDayKelvin() {
        let settings = makeSettings()
        #expect(kelvin(at: 12, 0, settings: settings) == settings.dayColorTemperatureKelvin)
    }

    @Test func middleOfNightInsideWindowIsNightKelvin() {
        let settings = makeSettings()
        #expect(kelvin(at: 3, 0, settings: settings) == settings.nightColorTemperatureKelvin)
    }

    @Test func lateEveningInsideWindowIsNightKelvin() {
        let settings = makeSettings()
        #expect(kelvin(at: 23, 0, settings: settings) == settings.nightColorTemperatureKelvin)
    }

    @Test func justBeforeWindowStartIsDayKelvin() {
        let settings = makeSettings()
        #expect(kelvin(at: 21, 30, settings: settings) == settings.dayColorTemperatureKelvin)
    }

    @Test func midpointOfStartTransitionIsHalfway() {
        let settings = makeSettings()
        // Smoothstep(0.5) == 0.5, so the boundary midpoint lands halfway.
        #expect(abs(kelvin(at: 22, 0, settings: settings) - 4950) < 1)
    }

    @Test func midpointOfEndTransitionIsHalfway() {
        let settings = makeSettings()
        #expect(abs(kelvin(at: 6, 0, settings: settings) - 4950) < 1)
    }

    @Test func zeroDurationTransitionCutsHardAtBoundaries() {
        let settings = makeSettings(transitionMinutes: 0)
        #expect(kelvin(at: 21, 59, settings: settings) == settings.dayColorTemperatureKelvin)
        #expect(kelvin(at: 22, 0, settings: settings) == settings.nightColorTemperatureKelvin)
        #expect(kelvin(at: 5, 59, settings: settings) == settings.nightColorTemperatureKelvin)
        #expect(kelvin(at: 6, 0, settings: settings) == settings.dayColorTemperatureKelvin)
    }

    @Test func sameDayWindowEndsAfterStartStaysInSameDay() {
        // Window 06:00–22:00 (end after start: no cross-midnight wrap).
        let settings = makeSettings(startHour: 6, endHour: 22)
        #expect(kelvin(at: 14, 0, settings: settings) == settings.nightColorTemperatureKelvin)
        #expect(kelvin(at: 23, 0, settings: settings) == settings.dayColorTemperatureKelvin)
        #expect(kelvin(at: 4, 0, settings: settings) == settings.dayColorTemperatureKelvin)
    }

    @Test func phaseMatchesWarmWindow() {
        let settings = makeSettings()
        #expect(CustomSchedule.phase(now: date(12, 0), settings: settings) == .day)
        #expect(CustomSchedule.phase(now: date(3, 0), settings: settings) == .night)
        #expect(CustomSchedule.phase(now: date(22, 0), settings: settings) == .transitioningToNight)
        #expect(CustomSchedule.phase(now: date(6, 0), settings: settings) == .transitioningToDay)
    }

    @Test func nextTransitionPicksNextBoundary() {
        let settings = makeSettings()
        // Noon → tonight's 22:00 warm start.
        let atNoon = CustomSchedule.nextTransition(now: date(12, 0), settings: settings)
        #expect(atNoon?.isWarmStart == true)
        #expect(atNoon?.date == date(22, 0))
        // 23:00 → tomorrow's 06:00 warm end (cross-midnight wrap).
        let atNight = CustomSchedule.nextTransition(now: date(23, 0), settings: settings)
        #expect(atNight?.isWarmStart == false)
        #expect(atNight?.date == date(6, 0, day: 16))
    }
}

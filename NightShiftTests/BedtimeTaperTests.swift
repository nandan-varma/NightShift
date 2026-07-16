import Testing
import Foundation
@testable import NightShift

@MainActor
struct BedtimeTaperTests {
    private func makeSettings(bedtimeHour: Int = 23, bedtimeMinute: Int = 0, bedtimeKelvin: Double = 2300, enabled: Bool = true) -> SettingsStore {
        let suiteName = "com.nandanvarma.NightShift.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)
        store.bedtimeRampEnabled = enabled
        store.bedtimeHour = bedtimeHour
        store.bedtimeMinute = bedtimeMinute
        store.bedtimeColorTemperatureKelvin = bedtimeKelvin
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

    @Test func disabledLeavesBaseKelvinUnchangedEvenAtBedtime() {
        let settings = makeSettings(enabled: false)
        let now = date(23, 0)
        let result = ScheduleEngine.applyBedtimeTaper(baseKelvin: 2700, phase: .night, now: now, settings: settings)
        #expect(result == 2700)
    }

    @Test func wrongPhaseLeavesBaseKelvinUnchanged() {
        let settings = makeSettings()
        let now = date(23, 0)
        let result = ScheduleEngine.applyBedtimeTaper(baseKelvin: 6500, phase: .day, now: now, settings: settings)
        #expect(result == 6500)
    }

    @Test func wellBeforeRampWindowLeavesBaseKelvinUnchanged() {
        let settings = makeSettings(bedtimeHour: 23, bedtimeMinute: 0)
        let now = date(20, 0) // 3h before bedtime, ramp window is only 1h
        let result = ScheduleEngine.applyBedtimeTaper(baseKelvin: 2700, phase: .night, now: now, settings: settings)
        #expect(result == 2700)
    }

    @Test func atBedtimeMatchesBedtimeKelvin() {
        let settings = makeSettings(bedtimeHour: 23, bedtimeMinute: 0, bedtimeKelvin: 2300)
        let now = date(23, 0)
        let result = ScheduleEngine.applyBedtimeTaper(baseKelvin: 2700, phase: .night, now: now, settings: settings)
        #expect(result == 2300)
    }

    @Test func afterBedtimeStaysAtBedtimeKelvin() {
        let settings = makeSettings(bedtimeHour: 23, bedtimeMinute: 0, bedtimeKelvin: 2300)
        let now = date(23, 30)
        let result = ScheduleEngine.applyBedtimeTaper(baseKelvin: 2700, phase: .night, now: now, settings: settings)
        #expect(result == 2300)
    }

    @Test func midpointOfRampIsBetweenBaseAndBedtimeKelvin() {
        let settings = makeSettings(bedtimeHour: 23, bedtimeMinute: 0, bedtimeKelvin: 2300)
        let now = date(22, 30) // 30 min before bedtime, halfway through the 60 min ramp
        let result = ScheduleEngine.applyBedtimeTaper(baseKelvin: 2700, phase: .night, now: now, settings: settings)
        #expect(result < 2700 && result > 2300)
        // Smoothstep(0.5) == 0.5, so the midpoint should land exactly halfway.
        #expect(abs(result - 2500) < 1)
    }

    @Test func nearestBedtimeResolvesAcrossMidnightBoundary() {
        // Just after midnight, a 23:00 bedtime is ~1-2h in the past, not ~22-23h in the future.
        let justAfterMidnight = date(0, 30)
        let bedtime = ScheduleEngine.nearestBedtime(now: justAfterMidnight, hour: 23, minute: 0)
        let expected = date(23, 0, day: 14)
        #expect(bedtime == expected)
    }
}

import Testing
import Foundation
@testable import NightShift

@MainActor
struct ScheduleEngineTests {
    private func makeSettings(day: Double = 6500, night: Double = 3400, transitionMinutes: Double = 30) -> SettingsStore {
        let suiteName = "com.nandanvarma.NightShift.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)
        store.dayColorTemperatureKelvin = day
        store.nightColorTemperatureKelvin = night
        store.transitionDurationMinutes = transitionMinutes
        return store
    }

    private var fixedSolar: SolarTimes {
        let sunrise = Date(timeIntervalSince1970: 1_718_000_000)
        let sunset = sunrise.addingTimeInterval(12 * 3600)
        return SolarTimes(dayKind: .normal(sunrise: sunrise, sunset: sunset), referenceDate: sunrise)
    }

    @Test func wellBeforeSunriseWindowIsNightKelvin() {
        let settings = makeSettings(transitionMinutes: 30)
        guard case .normal(let sunrise, _) = fixedSolar.dayKind else { fatalError() }
        let now = sunrise.addingTimeInterval(-3600) // 1h before sunrise, window is only 15 min half-width
        let kelvin = ScheduleEngine.interpolatedKelvin(now: now, solar: fixedSolar, settings: settings)
        #expect(kelvin == settings.nightColorTemperatureKelvin)
    }

    @Test func middayIsDayKelvin() {
        let settings = makeSettings(transitionMinutes: 30)
        guard case .normal(let sunrise, let sunset) = fixedSolar.dayKind else { fatalError() }
        let midday = sunrise.addingTimeInterval(sunset.timeIntervalSince(sunrise) / 2)
        let kelvin = ScheduleEngine.interpolatedKelvin(now: midday, solar: fixedSolar, settings: settings)
        #expect(kelvin == settings.dayColorTemperatureKelvin)
    }

    @Test func middleOfNightIsNightKelvin() {
        let settings = makeSettings(transitionMinutes: 30)
        guard case .normal(_, let sunset) = fixedSolar.dayKind else { fatalError() }
        let midnight = sunset.addingTimeInterval(6 * 3600)
        let kelvin = ScheduleEngine.interpolatedKelvin(now: midnight, solar: fixedSolar, settings: settings)
        #expect(kelvin == settings.nightColorTemperatureKelvin)
    }

    @Test func startOfSunriseWindowMatchesNightKelvin() {
        let settings = makeSettings(transitionMinutes: 30)
        guard case .normal(let sunrise, _) = fixedSolar.dayKind else { fatalError() }
        let windowStart = sunrise.addingTimeInterval(-15 * 60)
        let kelvin = ScheduleEngine.interpolatedKelvin(now: windowStart, solar: fixedSolar, settings: settings)
        #expect(abs(kelvin - settings.nightColorTemperatureKelvin) < 0.01)
    }

    @Test func endOfSunriseWindowMatchesDayKelvin() {
        let settings = makeSettings(transitionMinutes: 30)
        guard case .normal(let sunrise, _) = fixedSolar.dayKind else { fatalError() }
        let windowEnd = sunrise.addingTimeInterval(15 * 60)
        let kelvin = ScheduleEngine.interpolatedKelvin(now: windowEnd, solar: fixedSolar, settings: settings)
        #expect(abs(kelvin - settings.dayColorTemperatureKelvin) < 0.01)
    }

    @Test func midpointOfSunriseWindowIsBetweenNightAndDay() {
        let settings = makeSettings(day: 6500, night: 3400, transitionMinutes: 30)
        guard case .normal(let sunrise, _) = fixedSolar.dayKind else { fatalError() }
        let kelvin = ScheduleEngine.interpolatedKelvin(now: sunrise, solar: fixedSolar, settings: settings)
        #expect(kelvin > 3400 && kelvin < 6500)
        // Smoothstep(0.5) == 0.5, so the midpoint should land exactly halfway.
        #expect(abs(kelvin - 4950) < 1)
    }

    @Test func zeroDurationTransitionIsAHardCutAtTheEvent() {
        let settings = makeSettings(transitionMinutes: 0)
        guard case .normal(let sunrise, _) = fixedSolar.dayKind else { fatalError() }

        let justBefore = ScheduleEngine.interpolatedKelvin(now: sunrise.addingTimeInterval(-1), solar: fixedSolar, settings: settings)
        let atOrAfter = ScheduleEngine.interpolatedKelvin(now: sunrise, solar: fixedSolar, settings: settings)

        #expect(justBefore == settings.nightColorTemperatureKelvin)
        #expect(atOrAfter == settings.dayColorTemperatureKelvin)
    }

    @Test func polarDayAlwaysResolvesToDayKelvin() {
        let settings = makeSettings()
        let solar = SolarTimes(dayKind: .polarDay, referenceDate: Date())
        let kelvin = ScheduleEngine.interpolatedKelvin(now: Date(), solar: solar, settings: settings)
        #expect(kelvin == settings.dayColorTemperatureKelvin)
    }

    @Test func polarNightAlwaysResolvesToNightKelvin() {
        let settings = makeSettings()
        let solar = SolarTimes(dayKind: .polarNight, referenceDate: Date())
        let kelvin = ScheduleEngine.interpolatedKelvin(now: Date(), solar: solar, settings: settings)
        #expect(kelvin == settings.nightColorTemperatureKelvin)
    }

    @Test func nextTransitionPicksTheClosestUpcomingEvent() {
        guard case .normal(let sunrise, let sunset) = fixedSolar.dayKind else { fatalError() }
        let beforeSunrise = sunrise.addingTimeInterval(-3600)
        #expect(ScheduleEngine.nextTransition(now: beforeSunrise, solar: fixedSolar) == sunrise)

        let afterSunrise = sunrise.addingTimeInterval(3600)
        #expect(ScheduleEngine.nextTransition(now: afterSunrise, solar: fixedSolar) == sunset)

        let afterSunset = sunset.addingTimeInterval(3600)
        #expect(ScheduleEngine.nextTransition(now: afterSunset, solar: fixedSolar) == nil)
    }
}

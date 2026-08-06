import Testing
import Foundation
@testable import Twilight

@MainActor
struct ScheduleEngineTests {
    private func makeSettings(day: Double = 6500, night: Double = 3400, transitionMinutes: Double = 30) -> SettingsStore {
        let suiteName = "com.nandanvarma.Twilight.tests.\(UUID().uuidString)"
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

    // MARK: - phase()

    @Test func phaseIsTransitioningDuringSunriseAndSunsetWindows() {
        let settings = makeSettings(transitionMinutes: 30)
        guard case .normal(let sunrise, let sunset) = fixedSolar.dayKind else { fatalError() }
        #expect(ScheduleEngine.phase(now: sunrise, solar: fixedSolar, settings: settings) == .transitioningToDay)
        #expect(ScheduleEngine.phase(now: sunset, solar: fixedSolar, settings: settings) == .transitioningToNight)
    }

    @Test func phaseIsDayAtMiddayAndNightAtMidnight() {
        let settings = makeSettings(transitionMinutes: 30)
        guard case .normal(let sunrise, let sunset) = fixedSolar.dayKind else { fatalError() }
        let midday = sunrise.addingTimeInterval(sunset.timeIntervalSince(sunrise) / 2)
        let midnight = sunset.addingTimeInterval(6 * 3600)
        #expect(ScheduleEngine.phase(now: midday, solar: fixedSolar, settings: settings) == .day)
        #expect(ScheduleEngine.phase(now: midnight, solar: fixedSolar, settings: settings) == .night)
    }

    @Test func phaseIsDayDuringPolarDayAndNightDuringPolarNight() {
        let settings = makeSettings()
        let polarDay = SolarTimes(dayKind: .polarDay, referenceDate: Date())
        let polarNight = SolarTimes(dayKind: .polarNight, referenceDate: Date())
        #expect(ScheduleEngine.phase(now: Date(), solar: polarDay, settings: settings) == .day)
        #expect(ScheduleEngine.phase(now: Date(), solar: polarNight, settings: settings) == .night)
    }

    // MARK: - solarCalculatorAnchor (regression coverage for the UTC/local day-boundary bug)

    @Test func lateEveningInNegativeUTCOffsetZoneStillResolvesTodaysSunset() throws {
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))

        // 5:30pm PDT on June 21 is already past midnight UTC (June 22) — the
        // exact instant where naively feeding `now` straight into
        // SolarCalculator (which buckets by UTC calendar day) would jump to
        // tomorrow's — still hours away — sunrise/sunset instead of today's,
        // snapping the display to full night Kelvin hours before real sunset.
        let now = try #require(pacific.date(from: DateComponents(year: 2024, month: 6, day: 21, hour: 17, minute: 30)))

        let anchor = ScheduleEngine.solarCalculatorAnchor(now: now, calendar: pacific)
        let times = SolarCalculator.sunriseSunset(for: anchor, latitude: 37.7749, longitude: -122.4194)
        let sunset = try #require(times.sunset)

        let hoursUntilSunset = sunset.timeIntervalSince(now) / 3600
        #expect(hoursUntilSunset > 0 && hoursUntilSunset < 4)
    }

    @Test func earlyMorningInPositiveUTCOffsetZoneStillResolvesTodaysSunrise() throws {
        var india = Calendar(identifier: .gregorian)
        india.timeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))

        // 2am IST is still the previous UTC calendar day (IST is UTC+5:30,
        // so UTC doesn't roll over to "today" until ~5:30am local) — the
        // mirror-image case where naively feeding `now` in would resolve
        // yesterday's already-passed sunrise instead of today's upcoming one.
        let now = try #require(india.date(from: DateComponents(year: 2024, month: 6, day: 21, hour: 2, minute: 0)))

        let anchor = ScheduleEngine.solarCalculatorAnchor(now: now, calendar: india)
        let times = SolarCalculator.sunriseSunset(for: anchor, latitude: 19.0760, longitude: 72.8777)
        let sunrise = try #require(times.sunrise)

        let hoursUntilSunrise = sunrise.timeIntervalSince(now) / 3600
        #expect(hoursUntilSunrise > 0 && hoursUntilSunrise < 6)
    }
}

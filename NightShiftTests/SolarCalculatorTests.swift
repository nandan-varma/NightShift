import Testing
import Foundation
@testable import NightShift

struct SolarCalculatorTests {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 0))!
    }

    @Test func equinoxAtEquatorMatchesTheGeometricZenithHourAngle() throws {
        // At lat=0 with declination≈0, cos(hourAngle) reduces to exactly
        // cos(zenith), so day length is exactly 2 * 90.833deg * 4min/deg —
        // about 12h6m, not a flat 12h, because the 90.833deg zenith already
        // bakes in atmospheric refraction and the sun's apparent radius.
        let times = SolarCalculator.sunriseSunset(for: date(2024, 3, 20), latitude: 0, longitude: 0)
        let sunrise = try #require(times.sunrise)
        let sunset = try #require(times.sunset)
        let dayLengthMinutes = sunset.timeIntervalSince(sunrise) / 60
        let expectedMinutes = 2 * 90.833 * 4
        #expect(abs(dayLengthMinutes - expectedMinutes) < 3)
    }

    @Test func sunriseIsBeforeSunsetAndBothOnReferenceDay() throws {
        let times = SolarCalculator.sunriseSunset(for: date(2024, 6, 21), latitude: 37.7749, longitude: -122.4194)
        let sunrise = try #require(times.sunrise)
        let sunset = try #require(times.sunset)
        #expect(sunrise < sunset)
    }

    @Test func summerSolsticeNorthernHemisphereHasLongerDayThanEquinox() throws {
        let midLatitude = 40.0
        let solsticeTimes = SolarCalculator.sunriseSunset(for: date(2024, 6, 21), latitude: midLatitude, longitude: 0)
        let equinoxTimes = SolarCalculator.sunriseSunset(for: date(2024, 3, 20), latitude: midLatitude, longitude: 0)

        let solsticeDayLength = try #require(solsticeTimes.sunset).timeIntervalSince(try #require(solsticeTimes.sunrise))
        let equinoxDayLength = try #require(equinoxTimes.sunset).timeIntervalSince(try #require(equinoxTimes.sunrise))

        #expect(solsticeDayLength > equinoxDayLength)
    }

    @Test func southernHemisphereMirrorsNorthernHemisphereAtSolstice() throws {
        // Same |latitude|, same date: one hemisphere is in summer, the other in
        // winter. Their day lengths sum to roughly 24h, but not exactly — the
        // refraction/solar-radius correction (see the equator test above) adds
        // a small amount of extra daylight at *both* latitudes, so the sum runs
        // ~20-30 minutes over 1440. The tolerance here is sized for that known bias.
        let times40N = SolarCalculator.sunriseSunset(for: date(2024, 6, 21), latitude: 40, longitude: 0)
        let times40S = SolarCalculator.sunriseSunset(for: date(2024, 6, 21), latitude: -40, longitude: 0)

        let dayLength40N = try #require(times40N.sunset).timeIntervalSince(try #require(times40N.sunrise)) / 60
        let dayLength40S = try #require(times40S.sunset).timeIntervalSince(try #require(times40S.sunrise)) / 60

        #expect(abs((dayLength40N + dayLength40S) - 1440) < 35)
    }

    @Test func highLatitudeJuneIsPolarDay() {
        let times = SolarCalculator.sunriseSunset(for: date(2024, 6, 21), latitude: 75, longitude: 0)
        #expect(times.dayKind == .polarDay)
    }

    @Test func highLatitudeDecemberIsPolarNight() {
        let times = SolarCalculator.sunriseSunset(for: date(2024, 12, 21), latitude: 75, longitude: 0)
        #expect(times.dayKind == .polarNight)
    }

    @Test func approximateReferenceSunTimesForSanFrancisco() throws {
        // Smoke test against well-known rounded almanac values for San Francisco
        // near the summer solstice (~05:48 PDT sunrise / ~20:35 PDT sunset, i.e.
        // ~12:48 UTC / ~03:35 UTC next day). Generous tolerance since these are
        // rounded reference figures, not almanac-precise ones.
        let times = SolarCalculator.sunriseSunset(for: date(2024, 6, 21), latitude: 37.7749, longitude: -122.4194)
        let sunrise = try #require(times.sunrise)
        let sunset = try #require(times.sunset)

        let expectedSunriseUTC = date(2024, 6, 21).addingTimeInterval(12 * 3600 + 48 * 60)
        let expectedSunsetUTC = date(2024, 6, 22).addingTimeInterval(3 * 3600 + 35 * 60)

        #expect(abs(sunrise.timeIntervalSince(expectedSunriseUTC)) < 600)
        #expect(abs(sunset.timeIntervalSince(expectedSunsetUTC)) < 600)
    }
}

import Foundation

/// Computes sunrise/sunset entirely offline using the NOAA solar position
/// algorithm (low-precision formulas from Meeus, "Astronomical Algorithms").
/// Accurate to roughly a minute; no network access required.
enum SolarCalculator {
    static func sunriseSunset(for date: Date, latitude: Double, longitude: Double, calendar: Calendar = .init(identifier: .gregorian)) -> SolarTimes {
        var utcCalendar = calendar
        utcCalendar.timeZone = .gmt

        let startOfDayUTC = utcCalendar.startOfDay(for: date)
        let julianDay = julianDay(for: startOfDayUTC) + 0.5 // solar calc is referenced to local noon

        let t = julianCentury(julianDay: julianDay)
        let eqTimeMinutes = equationOfTimeMinutes(t: t)
        let decl = solarDeclinationRadians(t: t)

        let latRad = latitude * .pi / 180
        let zenithRad = 90.833 * .pi / 180

        let cosHourAngle = (cos(zenithRad) / (cos(latRad) * cos(decl))) - (tan(latRad) * tan(decl))

        if cosHourAngle > 1 {
            return SolarTimes(dayKind: .polarNight, referenceDate: startOfDayUTC)
        }
        if cosHourAngle < -1 {
            return SolarTimes(dayKind: .polarDay, referenceDate: startOfDayUTC)
        }

        let hourAngleDegrees = acos(cosHourAngle) * 180 / .pi
        let solarNoonUTCMinutes = 720 - 4 * longitude - eqTimeMinutes
        let sunriseUTCMinutes = solarNoonUTCMinutes - hourAngleDegrees * 4
        let sunsetUTCMinutes = solarNoonUTCMinutes + hourAngleDegrees * 4

        let sunrise = startOfDayUTC.addingTimeInterval(sunriseUTCMinutes * 60)
        let sunset = startOfDayUTC.addingTimeInterval(sunsetUTCMinutes * 60)

        return SolarTimes(dayKind: .normal(sunrise: sunrise, sunset: sunset), referenceDate: startOfDayUTC)
    }

    // MARK: - NOAA low-precision solar position formulas

    private static func julianDay(for date: Date) -> Double {
        date.timeIntervalSince1970 / 86400 + 2440587.5
    }

    private static func julianCentury(julianDay: Double) -> Double {
        (julianDay - 2451545) / 36525
    }

    private static func geometricMeanLongitudeDegrees(t: Double) -> Double {
        var l0 = 280.46646 + t * (36000.76983 + t * 0.0003032)
        l0 = l0.truncatingRemainder(dividingBy: 360)
        return l0 < 0 ? l0 + 360 : l0
    }

    private static func geometricMeanAnomalyDegrees(t: Double) -> Double {
        357.52911 + t * (35999.05029 - 0.0001537 * t)
    }

    private static func eccentricityEarthOrbit(t: Double) -> Double {
        0.016708634 - t * (0.000042037 + 0.0000001267 * t)
    }

    private static func equationOfCenterDegrees(t: Double, meanAnomalyDegrees m: Double) -> Double {
        let mRad = m * .pi / 180
        return sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * mRad) * (0.019993 - 0.000101 * t)
            + sin(3 * mRad) * 0.000289
    }

    private static func sunApparentLongitudeDegrees(t: Double, geoMeanLongitude l0: Double, equationOfCenter c: Double) -> Double {
        let trueLongitude = l0 + c
        return trueLongitude - 0.00569 - 0.00478 * sin((125.04 - 1934.136 * t) * .pi / 180)
    }

    private static func meanObliquityOfEclipticDegrees(t: Double) -> Double {
        23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
    }

    private static func obliquityCorrectionDegrees(t: Double) -> Double {
        meanObliquityOfEclipticDegrees(t: t) + 0.00256 * cos((125.04 - 1934.136 * t) * .pi / 180)
    }

    private static func solarDeclinationRadians(t: Double) -> Double {
        let l0 = geometricMeanLongitudeDegrees(t: t)
        let m = geometricMeanAnomalyDegrees(t: t)
        let c = equationOfCenterDegrees(t: t, meanAnomalyDegrees: m)
        let apparentLongitude = sunApparentLongitudeDegrees(t: t, geoMeanLongitude: l0, equationOfCenter: c)
        let obliquityCorrection = obliquityCorrectionDegrees(t: t) * .pi / 180
        return asin(sin(obliquityCorrection) * sin(apparentLongitude * .pi / 180))
    }

    private static func equationOfTimeMinutes(t: Double) -> Double {
        let l0 = geometricMeanLongitudeDegrees(t: t) * .pi / 180
        let m = geometricMeanAnomalyDegrees(t: t) * .pi / 180
        let e = eccentricityEarthOrbit(t: t)
        let obliquityCorrection = obliquityCorrectionDegrees(t: t) * .pi / 180

        let y = pow(tan(obliquityCorrection / 2), 2)

        let eqTime = y * sin(2 * l0)
            - 2 * e * sin(m)
            + 4 * e * y * sin(m) * cos(2 * l0)
            - 0.5 * y * y * sin(4 * l0)
            - 1.25 * e * e * sin(2 * m)

        return 4 * (eqTime * 180 / .pi)
    }
}

import Testing
@testable import Twilight

struct ColorTemperatureTests {
    @Test func neutralDaylightIsApproximatelyFullGainOnAllChannels() {
        let gain = ColorTemperature.kelvinToRGBGain(6500)
        #expect(abs(gain.red - 1.0) < 0.05)
        #expect(abs(gain.green - 1.0) < 0.05)
        #expect(abs(gain.blue - 1.0) < 0.05)
    }

    @Test func blueGainDecreasesMonotonicallyAsTemperatureDrops() {
        let kelvins: [Double] = [6500, 5500, 4500, 3400, 2700]
        let blueGains = kelvins.map { ColorTemperature.kelvinToRGBGain($0).blue }
        for (previous, next) in zip(blueGains, blueGains.dropFirst()) {
            #expect(next <= previous)
        }
    }

    @Test func redGainStaysAtFullAcrossWarmRange() {
        // Red channel is unattenuated below ~6600K in the Tanner Helland approximation.
        for kelvin in stride(from: 2000.0, through: 6500.0, by: 500) {
            #expect(ColorTemperature.kelvinToRGBGain(kelvin).red == 1.0)
        }
    }

    @Test func gainsAreClampedWithinValidRangeAtExtremes() {
        let veryWarm = ColorTemperature.kelvinToRGBGain(1000)
        let veryCool = ColorTemperature.kelvinToRGBGain(40000)

        for gain in [veryWarm, veryCool] {
            #expect(gain.red >= 0 && gain.red <= 1)
            #expect(gain.green >= 0 && gain.green <= 1)
            #expect(gain.blue >= 0 && gain.blue <= 1)
        }
    }
}

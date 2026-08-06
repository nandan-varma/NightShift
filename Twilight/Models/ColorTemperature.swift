import Foundation

enum ColorTemperature {
    struct RGBGain: Equatable {
        var red: Double
        var green: Double
        var blue: Double
    }

    /// Tanner Helland's black-body radiation approximation.
    /// Converts a color temperature in Kelvin (1000...40000) to per-channel
    /// gain in 0...1, normalized so 6500K resolves to (~1, ~1, ~1).
    static func kelvinToRGBGain(_ kelvin: Double) -> RGBGain {
        let temp = kelvin.clamped(to: 1000...40000) / 100

        let red: Double
        if temp <= 66 {
            red = 255
        } else {
            red = 329.698727446 * pow(temp - 60, -0.1332047592)
        }

        let green: Double
        if temp <= 66 {
            green = 99.4708025861 * log(temp) - 161.1195681661
        } else {
            green = 288.1221695283 * pow(temp - 60, -0.0755148492)
        }

        let blue: Double
        if temp >= 66 {
            blue = 255
        } else if temp <= 19 {
            blue = 0
        } else {
            blue = 138.5177312231 * log(temp - 10) - 305.0447927307
        }

        return RGBGain(
            red: (red / 255).clamped(to: 0...1),
            green: (green / 255).clamped(to: 0...1),
            blue: (blue / 255).clamped(to: 0...1)
        )
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

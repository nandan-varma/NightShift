import SwiftUI

extension Color {
    static func fromKelvin(_ kelvin: Double) -> Color {
        let gain = ColorTemperature.kelvinToRGBGain(kelvin)
        return Color(red: gain.red, green: gain.green, blue: gain.blue)
    }
}

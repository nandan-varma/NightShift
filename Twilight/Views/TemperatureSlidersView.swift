import SwiftUI

struct TemperatureSlidersView: View {
    @Bindable var settings: SettingsStore

    private let range: ClosedRange<Double> = 2000...6500

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TemperatureRowView(title: "Day", kelvin: $settings.dayColorTemperatureKelvin, range: range)
            TemperatureRowView(title: "Night", kelvin: $settings.nightColorTemperatureKelvin, range: range)
        }
    }
}

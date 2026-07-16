import SwiftUI

struct TemperatureSlidersView: View {
    @ObservedObject var settings: SettingsStore

    private let range: ClosedRange<Double> = 2700...6500

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            temperatureRow(title: "Day", kelvin: $settings.dayColorTemperatureKelvin)
            temperatureRow(title: "Night", kelvin: $settings.nightColorTemperatureKelvin)
        }
    }

    @ViewBuilder
    private func temperatureRow(title: String, kelvin: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(kelvin.wrappedValue))K")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.fromKelvin(kelvin.wrappedValue))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(.secondary.opacity(0.3)))
                Slider(value: kelvin, in: range, step: 100)
            }
        }
    }
}

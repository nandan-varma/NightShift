import SwiftUI

struct TemperatureRowView: View {
    let title: String
    @Binding var kelvin: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(kelvin))K")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.fromKelvin(kelvin))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(.secondary.opacity(0.3)))
                Slider(value: $kelvin, in: range, step: 100)
            }
        }
    }
}

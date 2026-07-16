import SwiftUI

/// Opt-in: wind down further in the hour before bedtime, on top of the
/// regular sunset/sunrise schedule — the pre-sleep window matters most for
/// melatonin, and it rarely lines up with sunset. Off by default.
struct BedtimeSectionView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Wind Down Before Bedtime", isOn: $settings.bedtimeRampEnabled)
                .font(.subheadline)

            if settings.bedtimeRampEnabled {
                HStack {
                    Text("Bedtime")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: bedtimeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Bedtime Warmth")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(settings.bedtimeColorTemperatureKelvin))K")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.fromKelvin(settings.bedtimeColorTemperatureKelvin))
                            .frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(.secondary.opacity(0.3)))
                        Slider(value: $settings.bedtimeColorTemperatureKelvin, in: 1800...3000, step: 100)
                    }
                }

                Text("Gradually warms further over the hour before bedtime — the window that matters most for melatonin.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var bedtimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: settings.bedtimeHour, minute: settings.bedtimeMinute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.bedtimeHour = components.hour ?? 23
                settings.bedtimeMinute = components.minute ?? 0
            }
        )
    }
}

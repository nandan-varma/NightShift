import SwiftUI

/// Fixed-clock warm window for `.custom` mode (night-shift schedules): the
/// display warms from `customWarmStart` to `customWarmEnd` every day,
/// ignoring sunrise/sunset entirely. The window crosses midnight when the end
/// time is earlier than the start.
struct CustomScheduleSectionView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Schedule")
                .font(.subheadline)

            HStack {
                Text("Warm from")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: startBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .accessibilityLabel("Warm window start")
                    .datePickerStyle(.compact)
            }

            HStack {
                Text("until")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: endBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .accessibilityLabel("Warm window end")
                    .datePickerStyle(.compact)
            }

            Text("Warms on a fixed clock instead of sunrise/sunset — for night-shift")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Text("schedules. Crosses midnight if the end is earlier than the start.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: settings.customWarmStartHour,
                    minute: settings.customWarmStartMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.customWarmStartHour = components.hour ?? 22
                settings.customWarmStartMinute = components.minute ?? 0
            }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: settings.customWarmEndHour,
                    minute: settings.customWarmEndMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.customWarmEndHour = components.hour ?? 6
                settings.customWarmEndMinute = components.minute ?? 0
            }
        )
    }
}

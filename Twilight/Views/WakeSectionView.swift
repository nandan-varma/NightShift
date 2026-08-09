import SwiftUI

/// Opt-in mirror of the bedtime taper: gradually brightens from the night
/// warmth back toward day warmth over the hour before wake-up, so the display
/// is comfortable by the time the alarm goes off even when sunrise is still
/// hours away. Off by default.
struct WakeSectionView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Brighten Before Wake-up", isOn: $settings.wakeRampEnabled)
                .font(.subheadline)

            if settings.wakeRampEnabled {
                HStack {
                    Text("Wake-up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: wakeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .accessibilityLabel("Wake-up time")
                        .datePickerStyle(.compact)
                }

                Text("Gradually brightens from the night warmth to day warmth over the hour before wake-up.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var wakeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: settings.wakeHour,
                    minute: settings.wakeMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.wakeHour = components.hour ?? 7
                settings.wakeMinute = components.minute ?? 0
            }
        )
    }
}

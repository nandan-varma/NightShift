import SwiftUI

struct TransitionDurationView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Transition")
                    .font(.subheadline)
                Spacer()
                Text(durationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settings.transitionDurationMinutes, in: 0...120, step: 5)
        }
    }

    private var durationLabel: String {
        settings.transitionDurationMinutes == 0 ? "Instant" : "\(Int(settings.transitionDurationMinutes)) min"
    }
}

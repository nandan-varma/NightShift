import SwiftUI

struct OnboardingLocationStepView: View {
    let settings: SettingsStore
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "location.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Set Your Location")
                .font(.title2.bold())

            Text("Twilight needs your city (or coordinates) to calculate accurate sunrise and sunset times for your area. This stays on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            LocationSearchView(settings: settings)
                .frame(maxWidth: 320)

            Button("Continue", action: onContinue)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .disabled(settings.locationName.isEmpty)

            if settings.locationName.isEmpty {
                Text("Search for a city to continue.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

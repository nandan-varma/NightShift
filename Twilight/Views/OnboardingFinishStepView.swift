import SwiftUI

struct OnboardingFinishStepView: View {
    let settings: SettingsStore
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("You're All Set")
                .font(.title2.bold())

            Text("Twilight runs quietly in your menu bar. Click the sun or moon icon anytime to adjust temperatures, location, or scheduling.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tip: turn on Wind Down Before Bedtime in Settings for extra warmth in the hour before you sleep.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            LaunchAtLoginToggleView(settings: settings)
                .padding(.vertical, 4)

            Button("Done", action: onFinish)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
    }
}

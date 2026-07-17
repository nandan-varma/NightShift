import SwiftUI

struct OnboardingWelcomeStepView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.fromKelvin(3400), Color.fromKelvin(6500)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                Image(systemName: "sun.haze.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
            }

            Text("Welcome to NightShift")
                .font(.title2.bold())

            Text("NightShift automatically warms your display's colors after sunset and returns to normal after sunrise — easier on your eyes, with nothing to toggle by hand.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Get Started", action: onGetStarted)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
    }
}

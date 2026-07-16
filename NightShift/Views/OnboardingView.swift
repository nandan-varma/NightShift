import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: SettingsStore
    let onFinish: () -> Void

    private enum Step: Int, CaseIterable {
        case welcome, location, finish
    }

    @State private var step: Step = .welcome

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            switch step {
            case .welcome: welcomeStep
            case .location: locationStep
            case .finish: finishStep
            }

            Spacer(minLength: 0)

            stepDots
        }
        .padding(36)
        .frame(width: 440, height: 460)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
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

            Button("Get Started") {
                withAnimation { step = .location }
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
    }

    // MARK: - Location

    private var locationStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "location.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Set Your Location")
                .font(.title2.bold())

            Text("NightShift needs your city (or coordinates) to calculate accurate sunrise and sunset times for your area. This stays on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            LocationSearchView(settings: settings)
                .frame(maxWidth: 320)

            Button("Continue") {
                withAnimation { step = .finish }
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .disabled(settings.locationName.isEmpty)

            if settings.locationName.isEmpty {
                Text("Search for a city to continue.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Finish

    private var finishStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("You're All Set")
                .font(.title2.bold())

            Text("NightShift runs quietly in your menu bar. Click the sun or moon icon anytime to adjust temperatures, location, or scheduling.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            LaunchAtLoginToggleView(settings: settings)
                .padding(.vertical, 4)

            Button("Done") {
                onFinish()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
    }

    // MARK: - Progress dots

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { dot in
                Circle()
                    .fill(dot == step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

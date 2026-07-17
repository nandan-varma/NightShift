import SwiftUI

struct OnboardingView: View {
    let settings: SettingsStore
    let onFinish: () -> Void

    enum Step: Int, CaseIterable {
        case welcome, location, finish
    }

    @State private var step: Step = .welcome

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            switch step {
            case .welcome:
                OnboardingWelcomeStepView {
                    withAnimation { step = .location }
                }
            case .location:
                OnboardingLocationStepView(settings: settings) {
                    withAnimation { step = .finish }
                }
            case .finish:
                OnboardingFinishStepView(settings: settings, onFinish: onFinish)
            }

            Spacer(minLength: 0)

            OnboardingStepDotsView(currentStep: step)
        }
        .padding(36)
        .frame(width: 440, height: 460)
    }
}

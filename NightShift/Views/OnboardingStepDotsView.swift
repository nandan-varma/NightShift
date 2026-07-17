import SwiftUI

struct OnboardingStepDotsView<Step: CaseIterable & Equatable>: View where Step.AllCases: RandomAccessCollection {
    let currentStep: Step

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(Step.allCases.enumerated()), id: \.offset) { _, dot in
                Circle()
                    .fill(dot == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

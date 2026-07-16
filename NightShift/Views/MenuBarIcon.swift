import SwiftUI

struct MenuBarIcon: View {
    let phase: SchedulePhase

    var body: some View {
        Image(systemName: symbolName)
    }

    private var symbolName: String {
        switch phase {
        case .day: return "sun.max.fill"
        case .night: return "moon.fill"
        case .transitioningToNight, .transitioningToDay: return "sun.haze.fill"
        case .off: return "circle.slash"
        }
    }
}

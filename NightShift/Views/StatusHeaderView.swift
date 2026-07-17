import SwiftUI

struct StatusHeaderView: View {
    let settings: SettingsStore
    let scheduleEngine: ScheduleEngine

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 28))
                .foregroundStyle(Color.fromKelvin(scheduleEngine.currentKelvin), .secondary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                // Always reserve this line's height, even with no countdown
                // to show, so the header doesn't change size — and shift
                // every row below it — as the mode or transition state changes.
                Text(countdown ?? " ")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .opacity(countdown == nil ? 0 : 1)
            }

            Spacer()
        }
    }

    private var symbolName: String {
        switch scheduleEngine.currentPhase {
        case .day: return "sun.max.fill"
        case .night: return "moon.fill"
        case .transitioningToNight, .transitioningToDay: return "sun.haze.fill"
        case .off: return "circle.slash"
        }
    }

    private var title: String {
        switch settings.scheduleMode {
        case .off: return "Night Shift: Off"
        case .auto: return "Night Shift: Scheduled"
        case .forceDay: return "Night Shift: Day"
        case .forceNight: return "Night Shift: Night"
        }
    }

    private var subtitle: String {
        guard settings.scheduleMode != .off else { return "Display at normal color" }
        let label = scheduleEngine.currentPhase == .night ? "Warm" : "Normal"
        return "\(label) — \(Int(scheduleEngine.currentKelvin))K"
    }

    private var countdown: String? {
        guard settings.scheduleMode == .auto, let next = scheduleEngine.nextTransitionDate else { return nil }
        let interval = next.timeIntervalSinceNow
        guard interval > 0 else { return nil }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let eventLabel = scheduleEngine.currentPhase == .night || scheduleEngine.currentPhase == .transitioningToDay ? "Sunrise" : "Sunset"

        if hours > 0 {
            return "\(eventLabel) in \(hours)h \(minutes)m"
        }
        return "\(eventLabel) in \(minutes)m"
    }
}

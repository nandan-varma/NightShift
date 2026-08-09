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
                if scheduleEngine.suspendedUntil != nil {
                    HStack(spacing: 6) {
                        Text(suspensionSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Resume") { settings.suspendUntil = nil }
                            .controlSize(.small)
                            .font(.caption)
                    }
                } else {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                // Always reserve this line's height, even with no countdown
                // to show, so the header doesn't change size — and shift
                // every row below it — as the mode or transition state changes.
                Text(countdown ?? " ")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .opacity(countdown == nil ? 0 : 1)
                // Same reservation trick for the sunrise/sunset times line.
                Text(timesLine ?? " ")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .opacity(timesLine == nil ? 0 : 1)
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
        if scheduleEngine.suspendedUntil != nil { return "Twilight: Suspended" }
        switch settings.scheduleMode {
        case .off: return "Twilight: Off"
        case .auto: return "Twilight: Scheduled"
        case .forceDay: return "Twilight: Day"
        case .forceNight: return "Twilight: Night"
        case .custom: return "Twilight: Custom Schedule"
        }
    }

    private var suspensionSubtitle: String {
        guard let until = scheduleEngine.suspendedUntil else { return "" }
        return "Resumes \(until.formatted(date: .omitted, time: .shortened))"
    }

    private var subtitle: String {
        guard settings.scheduleMode != .off else { return "Display at normal color" }
        let label = scheduleEngine.currentPhase == .night ? "Warm" : "Normal"
        return "\(label) — \(Int(scheduleEngine.currentKelvin))K"
    }

    private var countdown: String? {
        guard settings.scheduleMode == .auto || settings.scheduleMode == .custom,
              let next = scheduleEngine.nextTransitionDate else { return nil }
        let interval = next.timeIntervalSinceNow
        guard interval > 0 else { return nil }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let eventLabel: String
        if settings.scheduleMode == .custom {
            eventLabel = scheduleEngine.nextTransitionKind == .warmStart ? "Warm starts" : "Warm ends"
        } else {
            eventLabel = scheduleEngine.currentPhase == .night || scheduleEngine.currentPhase == .transitioningToDay
                ? "Sunrise"
                : "Sunset"
        }

        if hours > 0 {
            return "\(eventLabel) in \(hours)h \(minutes)m"
        }
        return "\(eventLabel) in \(minutes)m"
    }

    private var timesLine: String? {
        switch settings.scheduleMode {
        case .auto:
            guard let sunrise = scheduleEngine.todaySunrise, let sunset = scheduleEngine.todaySunset else { return nil }
            return "Sunrise \(Self.timeLabel(sunrise)) · Sunset \(Self.timeLabel(sunset))"
        case .custom:
            return "Warm \(Self.timeLabel(hour: settings.customWarmStartHour, minute: settings.customWarmStartMinute))"
                + " – \(Self.timeLabel(hour: settings.customWarmEndHour, minute: settings.customWarmEndMinute))"
        default:
            return nil
        }
    }

    private static func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func timeLabel(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)?.formatted(date: .omitted, time: .shortened)
            ?? String(format: "%02d:%02d", hour, minute)
    }
}

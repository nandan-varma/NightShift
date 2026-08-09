import Foundation

/// Pure schedule math for `.custom` mode: a fixed-clock warm window
/// (`customWarmStart` → `customWarmEnd`, wrapping past midnight when the end
/// time is earlier than the start) with the same centered, smoothstep-eased
/// transition windows as the solar schedule around each boundary. Kept
/// separate from `ScheduleEngine` so the engine's instance state stays focused
/// on orchestration while this stays trivially unit-testable.
enum CustomSchedule {
    /// The warm-window Kelvin at `now`: day Kelvin outside the window, night
    /// Kelvin inside, eased across the transition windows at each boundary.
    static func interpolatedKelvin(now: Date, settings: SettingsStore, calendar: Calendar = .current) -> Double {
        // Hard cut (no transition window): warm exactly inside the window, day
        // outside. The multi-day anchor scan below relies on bounded transition
        // windows — `normalizedProgress`'s zero-width degenerate case would
        // otherwise resolve *past* boundaries as "fully transitioned".
        if settings.transitionDurationMinutes <= 0 {
            return isInsideWarmWindow(now: now, settings: settings, calendar: calendar)
                ? settings.nightColorTemperatureKelvin
                : settings.dayColorTemperatureKelvin
        }

        let halfWindow = settings.transitionDurationMinutes * 60 / 2
        var inWarmRegion = false
        let startOfDay = calendar.startOfDay(for: now)

        // Scan the warm window anchored on yesterday, today, and tomorrow so
        // cross-midnight windows resolve correctly at any hour. Transition
        // branches return immediately; the full-warm check accumulates a flag
        // so an early anchor's window doesn't shadow a later anchor's
        // transition (or vice versa).
        for dayOffset in -1...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay),
                  let start = windowStart(settings: settings, calendar: calendar, day: day),
                  let endRaw = windowEnd(settings: settings, calendar: calendar, day: day) else { continue }
            let end = endRaw > start ? endRaw : endRaw.addingTimeInterval(86400)

            if let progress = normalizedProgress(now: now, center: start, halfWindow: halfWindow) {
                return lerp(
                    from: settings.dayColorTemperatureKelvin,
                    to: settings.nightColorTemperatureKelvin,
                    progress: smoothstep(progress)
                )
            }
            if let progress = normalizedProgress(now: now, center: end, halfWindow: halfWindow) {
                return lerp(
                    from: settings.nightColorTemperatureKelvin,
                    to: settings.dayColorTemperatureKelvin,
                    progress: smoothstep(progress)
                )
            }
            if now >= start.addingTimeInterval(halfWindow) && now < end.addingTimeInterval(-halfWindow) {
                inWarmRegion = true
            }
        }

        return inWarmRegion ? settings.nightColorTemperatureKelvin : settings.dayColorTemperatureKelvin
    }

    /// `.night` inside the warm window (and its transitions), `.day` outside.
    static func phase(now: Date, settings: SettingsStore, calendar: Calendar = .current) -> SchedulePhase {
        if settings.transitionDurationMinutes <= 0 {
            return isInsideWarmWindow(now: now, settings: settings, calendar: calendar) ? .night : .day
        }

        let halfWindow = settings.transitionDurationMinutes * 60 / 2
        var inWarmRegion = false
        let startOfDay = calendar.startOfDay(for: now)

        for dayOffset in -1...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay),
                  let start = windowStart(settings: settings, calendar: calendar, day: day),
                  let endRaw = windowEnd(settings: settings, calendar: calendar, day: day) else { continue }
            let end = endRaw > start ? endRaw : endRaw.addingTimeInterval(86400)

            if normalizedProgress(now: now, center: start, halfWindow: halfWindow) != nil {
                return .transitioningToNight
            }
            if normalizedProgress(now: now, center: end, halfWindow: halfWindow) != nil {
                return .transitioningToDay
            }
            if now >= start.addingTimeInterval(halfWindow) && now < end.addingTimeInterval(-halfWindow) {
                inWarmRegion = true
            }
        }

        return inWarmRegion ? .night : .day
    }

    /// Next warm-period boundary (start or end) after `now`, with a flag for
    /// whether it opens or closes the warm window.
    static func nextTransition(
        now: Date,
        settings: SettingsStore,
        calendar: Calendar = .current
    ) -> (date: Date, isWarmStart: Bool)? {
        let startOfDay = calendar.startOfDay(for: now)
        var candidates: [(date: Date, isWarmStart: Bool)] = []

        for dayOffset in -1...2 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else { continue }
            guard let start = windowStart(settings: settings, calendar: calendar, day: day),
                  let endRaw = windowEnd(settings: settings, calendar: calendar, day: day) else { continue }
            let end = endRaw > start ? endRaw : endRaw.addingTimeInterval(86400)
            candidates.append((start, true))
            candidates.append((end, false))
        }

        return candidates.filter { $0.date > now }.min { $0.date < $1.date }
    }

    private static func isInsideWarmWindow(now: Date, settings: SettingsStore, calendar: Calendar) -> Bool {
        let startOfDay = calendar.startOfDay(for: now)
        for dayOffset in -1...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay),
                  let start = windowStart(settings: settings, calendar: calendar, day: day),
                  let endRaw = windowEnd(settings: settings, calendar: calendar, day: day) else { continue }
            let end = endRaw > start ? endRaw : endRaw.addingTimeInterval(86400)
            if now >= start && now < end { return true }
        }
        return false
    }

    private static func windowStart(settings: SettingsStore, calendar: Calendar, day: Date) -> Date? {
        calendar.date(
            bySettingHour: settings.customWarmStartHour,
            minute: settings.customWarmStartMinute,
            second: 0,
            of: day
        )
    }

    private static func windowEnd(settings: SettingsStore, calendar: Calendar, day: Date) -> Date? {
        calendar.date(
            bySettingHour: settings.customWarmEndHour,
            minute: settings.customWarmEndMinute,
            second: 0,
            of: day
        )
    }

    // MARK: - Math helpers (mirrors of ScheduleEngine's, kept private per file)

    private static func normalizedProgress(now: Date, center: Date, halfWindow: TimeInterval) -> Double? {
        guard halfWindow > 0 else { return now >= center ? 1 : nil }
        let start = center.addingTimeInterval(-halfWindow)
        let end = center.addingTimeInterval(halfWindow)
        guard now >= start, now <= end else { return nil }
        return (now.timeIntervalSince(start)) / (end.timeIntervalSince(start))
    }

    private static func smoothstep(_ progress: Double) -> Double {
        progress * progress * (3 - 2 * progress)
    }

    private static func lerp(from: Double, to: Double, progress: Double) -> Double {
        from + (to - from) * progress
    }
}

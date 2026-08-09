import Foundation
import Observation

/// Central orchestrator: ties location + solar times + settings + manual
/// override + current time into a single "desired color temperature right
/// now", applied to the displays on a periodic timer.
@MainActor
@Observable
final class ScheduleEngine {
    // MARK: - Published state

    private(set) var currentKelvin: Double = 6500
    private(set) var currentPhase: SchedulePhase = .day
    private(set) var nextTransitionDate: Date?
    private(set) var nextTransitionKind: TransitionKind?
    /// Non-nil while a temporary suspension is active (see `SettingsStore.suspendUntil`).
    private(set) var suspendedUntil: Date?
    /// Sunrise/sunset for the current local day in `.auto` mode (nil otherwise),
    /// used by the status header's times line.
    private(set) var todaySunrise: Date?
    private(set) var todaySunset: Date?

    // MARK: - Dependencies / cache

    private let settings: SettingsStore
    private let gammaController: DisplayGammaController

    private var todaySolarTimes: SolarTimes?
    private var todaySolarTimesLocalDay: Date?
    private var todaySolarTimesTimeZone: String?
    private var timer: Timer?

    // MARK: - Smooth-fade state

    /// Discrete state changes (mode toggle, suspend start/end) fade smoothly
    /// over `modeSwitchFadeDuration` instead of snapping, so the display eases
    /// between temperatures the way the sunset ramp does.
    private var fadeState: FadeState?
    private var lastStateKey: String?

    private static let tickInterval: TimeInterval = 30
    private static let kelvinChangeThreshold: Double = 5
    static let modeSwitchFadeDuration: TimeInterval = 120

    init(settings: SettingsStore, gammaController: DisplayGammaController) {
        self.settings = settings
        self.gammaController = gammaController

        observeSettingsChanges()
    }

    func start() {
        tick()
        timer?.invalidate()
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Re-applies the current state to the displays. Called after display
    /// reconfiguration or wake-from-sleep, since transfer functions can
    /// silently reset to neutral in those cases. Recomputes for `now`
    /// (rather than trusting the cached `currentKelvin`) since a long sleep
    /// can span a day/night phase change, and always force-applies rather
    /// than going through `tick()`'s "skip tiny deltas" gating — the OS just
    /// reset the transfer function out from under us, so even a desired
    /// Kelvin close to the last-known value still needs to be re-sent.
    func reapplyCurrentState(now: Date = Date()) {
        guard settings.scheduleMode != .off && !isSuspended(now: now) else {
            enterNeutralState()
            return
        }

        let effective = effectiveKelvin(now: now)
        currentKelvin = effective
        gammaController.apply(kelvin: effective, displayOffsets: settings.displayOffsets)
    }

    func tick(now: Date = Date()) {
        guard settings.scheduleMode != .off && !isSuspended(now: now) else {
            enterNeutralState()
            return
        }

        let effective = effectiveKelvin(now: now)
        if abs(effective - currentKelvin) >= Self.kelvinChangeThreshold {
            gammaController.apply(kelvin: effective, displayOffsets: settings.displayOffsets)
        }
        currentKelvin = effective
    }

    /// Resolves the Kelvin the display should show right now — the scheduled
    /// target, eased through an in-flight mode-switch fade if one is active.
    /// Updating `currentPhase`/`nextTransitionDate`/`nextTransitionKind`/
    /// `todaySunrise`/`todaySunset` as a side effect, since both `tick()` and
    /// `reapplyCurrentState()` need them kept in sync with whatever Kelvin
    /// they resolve to. Callers must guard `.off`/suspension themselves.
    private func effectiveKelvin(now: Date) -> Double {
        let target = desiredKelvin(now: now)

        let stateKey = "\(settings.scheduleMode.rawValue)|\(suspendedUntil != nil)"
        if let last = lastStateKey, last != stateKey {
            // Discrete state change (mode toggle, suspend start/end) → fade
            // from the value currently on screen instead of snapping.
            fadeState = FadeState(
                fromKelvin: currentKelvin,
                targetKelvin: target,
                startDate: now,
                duration: Self.modeSwitchFadeDuration
            )
        }
        lastStateKey = stateKey

        guard let fade = fadeState else { return target }
        let value = fade.value(at: now)
        if now >= fade.startDate.addingTimeInterval(fade.duration) {
            fadeState = nil
        }
        return value
    }

    private func desiredKelvin(now: Date) -> Double {
        switch settings.scheduleMode {
        case .off:
            return currentKelvin // unreachable: callers guard `.off` before invoking this
        case .forceDay:
            currentPhase = .day
            nextTransitionDate = nil
            nextTransitionKind = nil
            todaySunrise = nil
            todaySunset = nil
            return settings.dayColorTemperatureKelvin
        case .forceNight:
            currentPhase = .night
            nextTransitionDate = nil
            nextTransitionKind = nil
            todaySunrise = nil
            todaySunset = nil
            return settings.nightColorTemperatureKelvin
        case .auto:
            let solar = solarTimesForToday(now: now)
            currentPhase = Self.phase(now: now, solar: solar, settings: settings)
            todaySunrise = solar.sunrise
            todaySunset = solar.sunset
            let next = Self.nextTransition(now: now, solar: solar)
            nextTransitionDate = next
            nextTransitionKind = next.map { $0 == solar.sunrise ? .sunrise : .sunset }
            return Self.autoKelvin(now: now, solar: solar, settings: settings)
        case .custom:
            currentPhase = CustomSchedule.phase(now: now, settings: settings)
            todaySunrise = nil
            todaySunset = nil
            if let (date, isStart) = CustomSchedule.nextTransition(now: now, settings: settings) {
                nextTransitionDate = date
                nextTransitionKind = isStart ? .warmStart : .warmEnd
            } else {
                nextTransitionDate = nil
                nextTransitionKind = nil
            }
            return Self.customKelvin(now: now, settings: settings)
        }
    }

    private func solarTimesForToday(now: Date) -> SolarTimes {
        let calendar = Calendar.current
        let timeZone = TimeZone.current.identifier
        if let cached = todaySolarTimes, let cachedLocalDay = todaySolarTimesLocalDay,
           let cachedTimeZone = todaySolarTimesTimeZone,
           cachedTimeZone == timeZone,
           calendar.isDate(cachedLocalDay, inSameDayAs: now) {
            return cached
        }

        let anchor = Self.solarCalculatorAnchor(now: now, calendar: calendar)
        let computed = SolarCalculator.sunriseSunset(
            for: anchor,
            latitude: settings.latitude,
            longitude: settings.longitude
        )
        todaySolarTimes = computed
        todaySolarTimesLocalDay = now
        todaySolarTimesTimeZone = timeZone
        return computed
    }

    /// True while a suspension is active, clearing it when it has expired.
    private func isSuspended(now: Date) -> Bool {
        guard let until = settings.suspendUntil else {
            suspendedUntil = nil
            return false
        }
        if until <= now {
            settings.suspendUntil = nil // expired — resume normal scheduling
            suspendedUntil = nil
            return false
        }
        suspendedUntil = until
        return true
    }

    /// The next sunrise strictly after `after` — used by "Suspend until Sunrise".
    func nextSunrise(after: Date = Date()) -> Date? {
        Self.nextSunrise(after: after, latitude: settings.latitude, longitude: settings.longitude)
    }

    private func enterNeutralState() {
        currentPhase = .off
        nextTransitionDate = nil
        nextTransitionKind = nil
        todaySunrise = nil
        todaySunset = nil
        fadeState = nil
        lastStateKey = nil
        currentKelvin = settings.dayColorTemperatureKelvin
        gammaController.restoreNeutral()
    }

    /// The Date to feed into `SolarCalculator.sunriseSunset` so it resolves
    /// times for the LOCAL calendar day containing `now` — not whatever UTC
    /// calendar day the raw `now` instant happens to fall in, which drifts
    /// from the local day for any timezone away from UTC+0 (e.g. in the
    /// evening for zones west of Greenwich, `now` can already be past UTC
    /// midnight while the local day hasn't turned over yet, which would
    /// otherwise make the calculator jump to tomorrow's — still future —
    /// sunrise/sunset). Anchoring to local noon — the point in the day
    /// furthest from both the local and UTC midnight boundaries — keeps the
    /// two calendars in sync for any real-world timezone offset.
    static func solarCalculatorAnchor(now: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
    }

    /// `withObservationTracking`'s `onChange` fires only once per registration,
    /// so this re-registers itself after every change to keep observing for the
    /// lifetime of the engine — the standard pattern for reacting to an
    /// `@Observable` object outside of a SwiftUI view body.
    private func observeSettingsChanges() {
        withObservationTracking {
            // Touch every settings property `desiredKelvin` (and the gamma
            // apply path) depends on, so this closure is invalidated whenever
            // any of them changes.
            _ = settings.scheduleMode
            _ = settings.dayColorTemperatureKelvin
            _ = settings.nightColorTemperatureKelvin
            _ = settings.transitionDurationMinutes
            _ = settings.latitude
            _ = settings.longitude
            _ = settings.bedtimeRampEnabled
            _ = settings.bedtimeHour
            _ = settings.bedtimeMinute
            _ = settings.bedtimeColorTemperatureKelvin
            _ = settings.wakeRampEnabled
            _ = settings.wakeHour
            _ = settings.wakeMinute
            _ = settings.suspendUntil
            _ = settings.customWarmStartHour
            _ = settings.customWarmStartMinute
            _ = settings.customWarmEndHour
            _ = settings.customWarmEndMinute
            _ = settings.displayOffsets
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.todaySolarTimes = nil
                self.tick()
                self.observeSettingsChanges()
            }
        }
    }

    // MARK: - Pure functions (no CGDisplay/CoreLocation dependency, unit-testable)

    /// The scheduled Kelvin for any mode, used by the 24-hour preview curve.
    /// `solar` is only consulted in `.auto` mode (pass nil otherwise); it is
    /// computed once per day by the caller rather than per sample.
    static func scheduledKelvin(now: Date, solar: SolarTimes?, settings: SettingsStore) -> Double {
        switch settings.scheduleMode {
        case .auto:
            guard let solar else { return settings.dayColorTemperatureKelvin }
            return autoKelvin(now: now, solar: solar, settings: settings)
        case .custom:
            return customKelvin(now: now, settings: settings)
        case .forceDay:
            return settings.dayColorTemperatureKelvin
        case .forceNight:
            return settings.nightColorTemperatureKelvin
        case .off:
            return settings.dayColorTemperatureKelvin
        }
    }

    /// Auto mode's Kelvin for `now`, including the bedtime/wake tapers.
    static func autoKelvin(now: Date, solar: SolarTimes, settings: SettingsStore) -> Double {
        let base = interpolatedKelvin(now: now, solar: solar, settings: settings)
        return applyingTapers(
            baseKelvin: base,
            phase: phase(now: now, solar: solar, settings: settings),
            now: now,
            settings: settings
        )
    }

    /// Custom fixed-clock mode's Kelvin for `now`, including the tapers.
    static func customKelvin(now: Date, settings: SettingsStore) -> Double {
        let base = CustomSchedule.interpolatedKelvin(now: now, settings: settings)
        return applyingTapers(
            baseKelvin: base,
            phase: CustomSchedule.phase(now: now, settings: settings),
            now: now,
            settings: settings
        )
    }

    /// Computes the desired Kelvin for `.auto` mode: a smoothstep-eased
    /// interpolation between night and day Kelvin, within a transition
    /// window of `transitionDurationMinutes` centered on sunrise and sunset.
    static func interpolatedKelvin(now: Date, solar: SolarTimes, settings: SettingsStore) -> Double {
        switch solar.dayKind {
        case .polarDay:
            return settings.dayColorTemperatureKelvin
        case .polarNight:
            return settings.nightColorTemperatureKelvin
        case .normal(let sunrise, let sunset):
            let halfWindow = settings.transitionDurationMinutes * 60 / 2

            // Transition window is centered on sunrise/sunset: begins half the
            // transition duration before the event and ends half after.
            if let progress = normalizedProgress(now: now, center: sunrise, halfWindow: halfWindow) {
                return lerp(
                    from: settings.nightColorTemperatureKelvin,
                    to: settings.dayColorTemperatureKelvin,
                    progress: smoothstep(progress)
                )
            }
            if let progress = normalizedProgress(now: now, center: sunset, halfWindow: halfWindow) {
                return lerp(
                    from: settings.dayColorTemperatureKelvin,
                    to: settings.nightColorTemperatureKelvin,
                    progress: smoothstep(progress)
                )
            }

            let isDaytime = now > sunrise.addingTimeInterval(halfWindow) && now < sunset.addingTimeInterval(-halfWindow)
            return isDaytime ? settings.dayColorTemperatureKelvin : settings.nightColorTemperatureKelvin
        }
    }

    static func phase(now: Date, solar: SolarTimes, settings: SettingsStore) -> SchedulePhase {
        switch solar.dayKind {
        case .polarDay: return .day
        case .polarNight: return .night
        case .normal(let sunrise, let sunset):
            let halfWindow = settings.transitionDurationMinutes * 60 / 2
            if normalizedProgress(now: now, center: sunrise, halfWindow: halfWindow) != nil {
                return .transitioningToDay
            }
            if normalizedProgress(now: now, center: sunset, halfWindow: halfWindow) != nil {
                return .transitioningToNight
            }
            let isDaytime = now > sunrise.addingTimeInterval(halfWindow) && now < sunset.addingTimeInterval(-halfWindow)
            return isDaytime ? .day : .night
        }
    }

    static func nextTransition(now: Date, solar: SolarTimes) -> Date? {
        guard case .normal(let sunrise, let sunset) = solar.dayKind else { return nil }
        return [sunrise, sunset].filter { $0 > now }.min()
    }

    /// The next sunrise strictly after `after`, for the given location.
    static func nextSunrise(after: Date, latitude: Double, longitude: Double, calendar: Calendar = .current) -> Date? {
        let times = SolarCalculator.sunriseSunset(
            for: solarCalculatorAnchor(now: after, calendar: calendar),
            latitude: latitude,
            longitude: longitude
        )
        if let sunrise = times.sunrise, sunrise > after { return sunrise }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: after) ?? after.addingTimeInterval(86400)
        let tomorrowTimes = SolarCalculator.sunriseSunset(
            for: solarCalculatorAnchor(now: tomorrow, calendar: calendar),
            latitude: latitude,
            longitude: longitude
        )
        return tomorrowTimes.sunrise
    }

    /// Opt-in extra taper: the last `bedtimeRampMinutes` before bedtime warm
    /// further from `baseKelvin` down to `bedtimeColorTemperatureKelvin`, since
    /// the pre-sleep window matters most for melatonin and rarely lines up
    /// with sunset. Only applies once already in the flat "night" phase — it
    /// layers on top of, rather than competing with, the sunset/sunrise ramp.
    static let bedtimeRampMinutes: Double = 60

    static func applyBedtimeTaper(
        baseKelvin: Double,
        phase: SchedulePhase,
        now: Date,
        settings: SettingsStore
    ) -> Double {
        guard settings.bedtimeRampEnabled, phase == .night else { return baseKelvin }
        guard let bedtime = nearestBedtime(now: now, hour: settings.bedtimeHour, minute: settings.bedtimeMinute) else {
            return baseKelvin
        }

        let rampSeconds = bedtimeRampMinutes * 60
        let rampStart = bedtime.addingTimeInterval(-rampSeconds)

        if now >= bedtime {
            return settings.bedtimeColorTemperatureKelvin
        }
        guard now >= rampStart else { return baseKelvin }

        let progress = now.timeIntervalSince(rampStart) / rampSeconds
        return lerp(from: baseKelvin, to: settings.bedtimeColorTemperatureKelvin, progress: smoothstep(progress))
    }

    /// Mirror-image of the bedtime taper: during the hour before
    /// `wakeHour:wakeMinute`, eases from the night warmth up to
    /// `dayColorTemperatureKelvin`, so the display is comfortable by wake-up
    /// time even when sunrise is hours away. Only acts in the flat "night"
    /// phase, and past wake-up it hands control back to the base schedule.
    static let wakeRampMinutes: Double = 60

    static func applyWakeTaper(baseKelvin: Double, phase: SchedulePhase, now: Date, settings: SettingsStore) -> Double {
        guard settings.wakeRampEnabled, phase == .night else { return baseKelvin }
        guard let wake = nearestWakeTime(now: now, hour: settings.wakeHour, minute: settings.wakeMinute) else {
            return baseKelvin
        }

        let rampSeconds = wakeRampMinutes * 60
        let rampStart = wake.addingTimeInterval(-rampSeconds)

        guard now >= rampStart, now < wake else { return baseKelvin }

        let progress = now.timeIntervalSince(rampStart) / rampSeconds
        return lerp(from: baseKelvin, to: settings.dayColorTemperatureKelvin, progress: smoothstep(progress))
    }

    private static func applyingTapers(
        baseKelvin: Double,
        phase: SchedulePhase,
        now: Date,
        settings: SettingsStore
    ) -> Double {
        let afterBedtime = applyBedtimeTaper(baseKelvin: baseKelvin, phase: phase, now: now, settings: settings)
        // Applied last so the wake taper wins in the (pathological) overlap case.
        return applyWakeTaper(baseKelvin: afterBedtime, phase: phase, now: now, settings: settings)
    }

    /// The bedtime instant (today, yesterday, or tomorrow at `hour:minute`)
    /// closest to `now` — needed since a bedtime shortly after midnight can
    /// be "closer" via yesterday's or today's instance depending on `now`.
    static func nearestBedtime(now: Date, hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        guard let todayBedtime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
            return nil
        }
        let candidates = [
            todayBedtime.addingTimeInterval(-86400),
            todayBedtime,
            todayBedtime.addingTimeInterval(86400),
        ]
        return candidates.min { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) }
    }

    /// The wake-up instant closest to `now`, mirroring `nearestBedtime`.
    static func nearestWakeTime(now: Date, hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        guard let todayWake = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
            return nil
        }
        let candidates = [
            todayWake.addingTimeInterval(-86400),
            todayWake,
            todayWake.addingTimeInterval(86400),
        ]
        return candidates.min { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) }
    }

    /// Smoothly eased Kelvin between two values — used both for the
    /// mode-switch fade and for transition ramps. `progress` is clamped.
    static func fadedKelvin(from: Double, to: Double, progress: Double) -> Double {
        lerp(from: from, to: to, progress: smoothstep(progress.clamped(to: 0...1)))
    }

    /// Returns progress `0...1` through a `[center - halfWindow, center + halfWindow]`
    /// window, or `nil` if `now` falls outside it.
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

/// A mode-switch fade: eases the displayed Kelvin from `fromKelvin` to
/// `targetKelvin` over `duration`, starting at `startDate`.
private struct FadeState {
    let fromKelvin: Double
    let targetKelvin: Double
    let startDate: Date
    let duration: TimeInterval

    func value(at date: Date) -> Double {
        let progress = min(max(date.timeIntervalSince(startDate) / duration, 0), 1)
        return ScheduleEngine.fadedKelvin(from: fromKelvin, to: targetKelvin, progress: progress)
    }
}

import Foundation
import Observation

/// Central orchestrator: ties location + solar times + settings + manual
/// override + current time into a single "desired color temperature right
/// now", applied to the displays on a periodic timer.
@MainActor
@Observable
final class ScheduleEngine {
    private(set) var currentKelvin: Double = 6500
    private(set) var currentPhase: SchedulePhase = .day
    private(set) var nextTransitionDate: Date?

    private let settings: SettingsStore
    private let gammaController: DisplayGammaController

    private var todaySolarTimes: SolarTimes?
    private var todaySolarTimesLocalDay: Date?
    private var timer: Timer?

    private static let tickInterval: TimeInterval = 30
    private static let kelvinChangeThreshold: Double = 5

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
        guard settings.scheduleMode != .off else {
            currentPhase = .off
            nextTransitionDate = nil
            gammaController.restoreNeutral()
            return
        }

        currentKelvin = desiredKelvin(now: now)
        gammaController.apply(kelvin: currentKelvin)
    }

    func tick(now: Date = Date()) {
        guard settings.scheduleMode != .off else {
            currentPhase = .off
            nextTransitionDate = nil
            gammaController.restoreNeutral()
            return
        }

        let desired = desiredKelvin(now: now)
        if abs(desired - currentKelvin) >= Self.kelvinChangeThreshold {
            gammaController.apply(kelvin: desired)
        }
        currentKelvin = desired
    }

    /// Computes the desired Kelvin for `now` under the current mode, updating
    /// `currentPhase`/`nextTransitionDate` as a side effect since both
    /// `tick()` and `reapplyCurrentState()` need them kept in sync with
    /// whatever Kelvin they resolve to. Callers must guard `.off` themselves.
    private func desiredKelvin(now: Date) -> Double {
        switch settings.scheduleMode {
        case .off:
            return currentKelvin // unreachable: callers guard `.off` before invoking this
        case .forceDay:
            currentPhase = .day
            nextTransitionDate = nil
            return settings.dayColorTemperatureKelvin
        case .forceNight:
            currentPhase = .night
            nextTransitionDate = nil
            return settings.nightColorTemperatureKelvin
        case .auto:
            let solarTimes = solarTimesForToday(now: now)
            let phase = Self.phase(now: now, solar: solarTimes, settings: settings)
            let base = Self.interpolatedKelvin(now: now, solar: solarTimes, settings: settings)
            currentPhase = phase
            nextTransitionDate = Self.nextTransition(now: now, solar: solarTimes)
            return Self.applyBedtimeTaper(baseKelvin: base, phase: phase, now: now, settings: settings)
        }
    }

    private func solarTimesForToday(now: Date) -> SolarTimes {
        let calendar = Calendar.current
        if let cached = todaySolarTimes, let cachedLocalDay = todaySolarTimesLocalDay,
           calendar.isDate(cachedLocalDay, inSameDayAs: now) {
            return cached
        }

        let anchor = Self.solarCalculatorAnchor(now: now, calendar: calendar)
        let computed = SolarCalculator.sunriseSunset(for: anchor, latitude: settings.latitude, longitude: settings.longitude)
        todaySolarTimes = computed
        todaySolarTimesLocalDay = now
        return computed
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
            // Touch every settings property `desiredKelvin` depends on, so this
            // closure is invalidated whenever any of them changes.
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
            if let t = normalizedProgress(now: now, center: sunrise, halfWindow: halfWindow) {
                return lerp(from: settings.nightColorTemperatureKelvin, to: settings.dayColorTemperatureKelvin, t: smoothstep(t))
            }
            if let t = normalizedProgress(now: now, center: sunset, halfWindow: halfWindow) {
                return lerp(from: settings.dayColorTemperatureKelvin, to: settings.nightColorTemperatureKelvin, t: smoothstep(t))
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
            if normalizedProgress(now: now, center: sunrise, halfWindow: halfWindow) != nil { return .transitioningToDay }
            if normalizedProgress(now: now, center: sunset, halfWindow: halfWindow) != nil { return .transitioningToNight }
            let isDaytime = now > sunrise.addingTimeInterval(halfWindow) && now < sunset.addingTimeInterval(-halfWindow)
            return isDaytime ? .day : .night
        }
    }

    static func nextTransition(now: Date, solar: SolarTimes) -> Date? {
        guard case .normal(let sunrise, let sunset) = solar.dayKind else { return nil }
        return [sunrise, sunset].filter { $0 > now }.min()
    }

    /// Opt-in extra taper: the last `bedtimeRampMinutes` before bedtime warm
    /// further from `baseKelvin` down to `bedtimeColorTemperatureKelvin`, since
    /// the pre-sleep window matters most for melatonin and rarely lines up
    /// with sunset. Only applies once already in the flat "night" phase — it
    /// layers on top of, rather than competing with, the sunset/sunrise ramp.
    static let bedtimeRampMinutes: Double = 60

    static func applyBedtimeTaper(baseKelvin: Double, phase: SchedulePhase, now: Date, settings: SettingsStore) -> Double {
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

        let t = now.timeIntervalSince(rampStart) / rampSeconds
        return lerp(from: baseKelvin, to: settings.bedtimeColorTemperatureKelvin, t: smoothstep(t))
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

    /// Returns progress `0...1` through a `[center - halfWindow, center + halfWindow]`
    /// window, or `nil` if `now` falls outside it.
    private static func normalizedProgress(now: Date, center: Date, halfWindow: TimeInterval) -> Double? {
        guard halfWindow > 0 else { return now >= center ? 1 : nil }
        let start = center.addingTimeInterval(-halfWindow)
        let end = center.addingTimeInterval(halfWindow)
        guard now >= start, now <= end else { return nil }
        return (now.timeIntervalSince(start)) / (end.timeIntervalSince(start))
    }

    private static func smoothstep(_ t: Double) -> Double {
        t * t * (3 - 2 * t)
    }

    private static func lerp(from: Double, to: Double, t: Double) -> Double {
        from + (to - from) * t
    }
}

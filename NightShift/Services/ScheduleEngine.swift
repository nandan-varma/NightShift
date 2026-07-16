import Foundation
import Combine

/// Central orchestrator: ties location + solar times + settings + manual
/// override + current time into a single "desired color temperature right
/// now", applied to the displays on a periodic timer.
@MainActor
final class ScheduleEngine: ObservableObject {
    @Published private(set) var currentKelvin: Double = 6500
    @Published private(set) var currentPhase: SchedulePhase = .day
    @Published private(set) var nextTransitionDate: Date?

    private let settings: SettingsStore
    private let gammaController: DisplayGammaController

    private var todaySolarTimes: SolarTimes?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

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

    /// Re-applies the currently computed Kelvin value to the displays.
    /// Called after display reconfiguration or wake-from-sleep, since
    /// transfer functions can silently reset in those cases.
    func reapplyCurrentState() {
        guard settings.scheduleMode != .off else {
            gammaController.restoreNeutral()
            return
        }
        gammaController.apply(kelvin: currentKelvin)
    }

    func tick(now: Date = Date()) {
        guard settings.scheduleMode != .off else {
            currentPhase = .off
            nextTransitionDate = nil
            gammaController.restoreNeutral()
            return
        }

        let desiredKelvin: Double
        switch settings.scheduleMode {
        case .off:
            return // handled above
        case .forceDay:
            desiredKelvin = settings.dayColorTemperatureKelvin
            currentPhase = .day
            nextTransitionDate = nil
        case .forceNight:
            desiredKelvin = settings.nightColorTemperatureKelvin
            currentPhase = .night
            nextTransitionDate = nil
        case .auto:
            let solarTimes = solarTimesForToday(now: now)
            let phase = Self.phase(now: now, solar: solarTimes, settings: settings)
            let base = Self.interpolatedKelvin(now: now, solar: solarTimes, settings: settings)
            desiredKelvin = Self.applyBedtimeTaper(baseKelvin: base, phase: phase, now: now, settings: settings)
            currentPhase = phase
            nextTransitionDate = Self.nextTransition(now: now, solar: solarTimes)
        }

        if abs(desiredKelvin - currentKelvin) >= Self.kelvinChangeThreshold {
            gammaController.apply(kelvin: desiredKelvin)
        }
        currentKelvin = desiredKelvin
    }

    private func solarTimesForToday(now: Date) -> SolarTimes {
        let calendar = Calendar.current
        if let cached = todaySolarTimes, calendar.isDate(cached.referenceDate, inSameDayAs: now) {
            return cached
        }

        let computed = SolarCalculator.sunriseSunset(for: now, latitude: settings.latitude, longitude: settings.longitude)
        todaySolarTimes = computed
        return computed
    }

    private func observeSettingsChanges() {
        settings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.todaySolarTimes = nil; self?.tick() }
            }
            .store(in: &cancellables)
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

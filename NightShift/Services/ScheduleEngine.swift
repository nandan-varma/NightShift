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
    private let locationService: LocationService
    private let gammaController: DisplayGammaController

    private var todaySolarTimes: SolarTimes?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private static let tickInterval: TimeInterval = 30
    private static let kelvinChangeThreshold: Double = 5

    init(settings: SettingsStore, locationService: LocationService, gammaController: DisplayGammaController) {
        self.settings = settings
        self.locationService = locationService
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
            desiredKelvin = Self.interpolatedKelvin(now: now, solar: solarTimes, settings: settings)
            currentPhase = Self.phase(now: now, solar: solarTimes, settings: settings)
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

        let coordinate = currentCoordinate
        let computed = SolarCalculator.sunriseSunset(for: now, latitude: coordinate.latitude, longitude: coordinate.longitude)
        todaySolarTimes = computed
        return computed
    }

    private var currentCoordinate: Coordinate {
        switch settings.locationMode {
        case .automatic:
            return locationService.currentCoordinate ?? Coordinate(latitude: settings.manualLatitude, longitude: settings.manualLongitude)
        case .manual:
            return Coordinate(latitude: settings.manualLatitude, longitude: settings.manualLongitude)
        }
    }

    private func observeSettingsChanges() {
        settings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.todaySolarTimes = nil; self?.tick() }
            }
            .store(in: &cancellables)

        locationService.$currentCoordinate
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

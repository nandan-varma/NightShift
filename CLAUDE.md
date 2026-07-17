# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

NightShift is a native macOS menu bar app (SwiftUI `MenuBarExtra`, `.accessory` activation policy — no Dock icon) that warms display color temperature on a sunrise/sunset schedule, similar to f.lux/Night Shift/Shifty. Deployment target: macOS 14.0. Swift 5.0. No external dependencies (no SPM packages, no CocoaPods) — everything is built on AppKit/SwiftUI/CoreGraphics/CoreLocation/ServiceManagement.

## Build & test

There is no shared Xcode scheme checked into the repo, so builds/tests are normally done by opening `NightShift.xcodeproj` in Xcode (Cmd+B / Cmd+U). From the CLI:

```sh
xcodebuild -project NightShift.xcodeproj -scheme NightShift -destination 'platform=macOS' build
xcodebuild -project NightShift.xcodeproj -scheme NightShift -destination 'platform=macOS' test
```

To run a single test class/method with xcodebuild, add `-only-testing:NightShiftTests/ScheduleEngineTests` (or `/ScheduleEngineTests/testMethodName`).

Test targets: `NightShiftTests` (unit tests for pure logic) and `NightShiftUITests`. Unit tests exist for `ColorTemperature`, `ScheduleEngine`, `BedtimeTaper`, `SettingsStore`, and `SolarCalculator` — these are the parts of the app with real branching logic and are the ones worth covering when changing behavior.

## Architecture

**Data/control flow:** `AppDelegate` owns the three long-lived singletons — `SettingsStore`, `DisplayGammaController`, and `ScheduleEngine` — and wires them together at launch. `ScheduleEngine` is the central orchestrator: on a 30s timer (`tick()`) it combines the current time, cached solar times, and `SettingsStore` state into a target Kelvin value and pushes it to `DisplayGammaController`. It also reacts to changes on the specific `SettingsStore` properties `desiredKelvin` depends on via a self-re-registering `withObservationTracking` call (invalidating cached solar times and re-ticking), and `AppDelegate` re-invokes `reapplyCurrentState()` on display reconfiguration (debounced 0.4s, via a cancellable `Task` rather than GCD) and wake-from-sleep, since macOS silently resets per-display transfer functions in both cases.

**Layering:**
- `Models/` — plain value types with no side effects: `ScheduleMode` (auto/forceDay/forceNight/off), `SchedulePhase`, `SolarTimes` (day/night/polarDay/polarNight), `Coordinate`, `ColorTemperature` (Kelvin → RGB gain via Tanner Helland's black-body approximation).
- `Services/` — each wraps exactly one system API and is the *only* place in the app that touches it: `DisplayGammaController` (CGDisplay transfer functions), `SolarCalculator` (offline NOAA low-precision solar position formulas — no network), `GeocodingService` (`CLGeocoder`, used only once per manual location entry; the app is otherwise fully offline), `LaunchAtLoginService` (`SMAppService`).
- `Stores/SettingsStore` — the single `@Observable` / `UserDefaults`-backed source of truth for all user preferences; every property persists immediately on `didSet`.
- `Views/` — SwiftUI, composed under `MenuBarContentView`; each section (mode, temperature sliders, transition duration, bedtime, location, launch-at-login) is its own small view driven by `SettingsStore` — `@Bindable var settings: SettingsStore` where the view creates `$settings.foo` bindings, otherwise a plain `let settings: SettingsStore`.
- `Extensions/NSMenuItem+Closure.swift` — `ClosureMenuItem`, an `NSMenuItem` subclass that takes a closure instead of a target/action pair; used only by the status-item right-click menu below.

**Key invariants to preserve when touching this code:**
- `ScheduleEngine`'s pure computation functions (`interpolatedKelvin`, `phase`, `nextTransition`, `applyBedtimeTaper`, `nearestBedtime`, and the private smoothstep/lerp/progress helpers) are `static` and take all inputs as parameters specifically so they're unit-testable without CoreLocation/CGDisplay — keep new schedule logic in this same pure-function style rather than pulling live system state into it.
- The sunrise/sunset transition window is centered on the event (`transitionDurationMinutes / 2` on each side), eased with smoothstep — not a linear ramp starting at the event.
- Bedtime wind-down (`BedtimeSectionView`, `SettingsStore.bedtimeRampEnabled`) is a separate, opt-in, off-by-default taper layered on top of the sunset/sunrise schedule: once `ScheduleEngine.phase` is flat `.night`, `applyBedtimeTaper` further eases from the night Kelvin down to `bedtimeColorTemperatureKelvin` over the `bedtimeRampMinutes` (60) before the user's configured bedtime, then holds there until sunrise. `nearestBedtime` picks whichever of yesterday/today/tomorrow's bedtime instant is closest to `now`, so it resolves correctly just after midnight. This only ever makes `.auto` mode *warmer* than the base schedule — it never fires in `forceDay`/`forceNight`/`off`.
- `DisplayGammaController.restoreNeutral()` must always be reachable/called on quit, SIGINT/SIGTERM, and `.off` mode so displays never get stuck warm; `AppDelegate` wires signal handlers directly to a static reference to the shared controller for this reason. There are two independent quit affordances — `QuitButtonView` in the popover and "Quit NightShift" in the status-item right-click menu — both must call `restoreNeutral()` before `NSApp.terminate(nil)`.
- Location is manual-entry only (via `GeocodingService`/`CLGeocoder`), not continuous GPS tracking — once a coordinate is resolved it's persisted to `SettingsStore` and the app runs fully offline afterward.
- Onboarding (`OnboardingView`) gates on `settings.hasCompletedOnboarding` and requires a resolved city before it can be dismissed; it's shown as a separate `NSWindow` from `AppDelegate`, not inline in the menu bar popover. New settings features (e.g. bedtime wind-down) are intentionally *not* surfaced in onboarding beyond a one-line mention — onboarding stays a 3-step happy path (welcome → location → finish).
- `MenuBarExtra` has no public API for a distinct secondary-click menu — left and right click both just toggle the same SwiftUI window. `MenuBarIcon` works around this with `MenuBarContextMenuCatcher`, an `NSViewRepresentable` that installs a local right-mouse-down event monitor scoped to the status item's own window and pops up a standard `NSMenu` (built from `ClosureMenuItem`s) instead, without disturbing the normal left-click popover behavior.

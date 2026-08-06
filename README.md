# Twilight

A native macOS menu-bar app (f.lux / Night Shift-style) that warms display color temperature on a sunrise/sunset schedule, with an opt-in bedtime wind-down taper. Zero external dependencies — no SPM packages, no CocoaPods — everything runs on AppKit, SwiftUI, CoreGraphics, and CoreLocation.

## Architecture

Built as a `MenuBarExtra`-based app (`.accessory` activation policy, no Dock icon) with a strict layering discipline:

- Pure value types for schedule math — `ScheduleMode`, `SolarTimes`, `ColorTemperature` (Kelvin-to-RGB via Tanner Helland's black-body approximation)
- One service per system API — `DisplayGammaController` for CGDisplay transfer functions, `SolarCalculator` for offline NOAA solar-position formulas, `GeocodingService`, `LaunchAtLoginService`
- An `@Observable` settings store as the single source of truth

The schedule engine's core functions (`interpolatedKelvin`, `phase`, `nextTransition`, bedtime taper math) are kept `static` and parameterized so they're unit-testable without touching live CoreLocation or CGDisplay state.

## Correctness and reliability

The sunrise/sunset transition is a smoothstep-eased window centered on the solar event, not a linear ramp. A separate opt-in bedtime taper layers on top and only ever makes auto mode warmer — it never overrides forced day/night/off modes.

macOS silently resets display transfer functions on both external-display reconfiguration and wake-from-sleep. Twilight re-applies state on both events (debounced via a cancellable `Task`) and guarantees `restoreNeutral()` fires on quit, SIGINT/SIGTERM, and both UI quit affordances, so a display can never get stuck warm.

Solar position is computed fully offline (NOAA low-precision formulas); the only network-adjacent call is a one-time `CLGeocoder` lookup during manual location entry.

## Requirements

- macOS 14+
- Xcode 15+

## Releases

Tagged releases are packaged as signed, notarized, stapled `.dmg` files and
include a SHA-256 checksum. The release workflow uses repository secrets for a
Developer ID Application certificate and an App Store Connect API key; no
signing material is committed to the repository.

## Built with

- Swift + SwiftUI (`MenuBarExtra`) + AppKit
- CoreGraphics — display gamma / transfer function control
- CoreLocation — offline NOAA solar-position calculation
- `SMAppService` — launch at login
- Zero external dependencies

## Key decisions

- **Zero external dependencies** — a menu-bar utility running constantly in the background is exactly where a supply-chain surprise from a dependency update is least acceptable
- **Static, parameterized core functions over methods on stateful services** — keeps the schedule engine's actual logic unit-testable without mocking CoreLocation or a live display connection
- **Re-applying gamma state on both display reconfiguration and wake** — macOS resets the transfer function silently on either event; catching just one would leave the display neutral (or stuck warm) after the other

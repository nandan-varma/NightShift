import CoreGraphics
import ColorSync
import Foundation

/// The only place in the app that touches CGDisplay gamma APIs.
/// Applies a color-temperature gain to every active display by scaling each
/// channel's transfer-function max (the same lightweight technique used by
/// f.lux/Shifty/NightOwl), rather than building a full 256-entry gamma table.
final class DisplayGammaController {
    /// Applies the given Kelvin value's RGB gain to every active display,
    /// optionally nudged per display by the `displayOffsets` map (keyed by
    /// `CGDisplayCreateUUIDFromDisplayID` UUID string; negative = warmer).
    func apply(kelvin: Double, displayOffsets: [String: Double] = [:]) {
        forEachActiveDisplay { display in
            let effectiveKelvin = (kelvin + (offset(for: display, in: displayOffsets)))
                .clamped(to: 1000...10000)
            applyGain(ColorTemperature.kelvinToRGBGain(effectiveKelvin), to: display)
        }
    }

    /// Resets every active display to a neutral (1,1,1) transfer function.
    /// Used for "Off"/"Force Day", and must be called before the app quits or
    /// terminates so the user is never left with a stuck warm screen.
    func restoreNeutral() {
        forEachActiveDisplay { display in
            applyGain(ColorTemperature.RGBGain(red: 1, green: 1, blue: 1), to: display)
        }
    }

    private func offset(for display: CGDirectDisplayID, in offsets: [String: Double]) -> Double {
        guard let uuid = uuidString(for: display) else { return 0 }
        return offsets[uuid] ?? 0
    }

    private func uuidString(for display: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(display) else { return nil }
        return CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
    }

    private func applyGain(_ gain: ColorTemperature.RGBGain, to display: CGDirectDisplayID) {
        CGSetDisplayTransferByFormula(
            display,
            0.0, CGGammaValue(gain.red), 1.0,
            0.0, CGGammaValue(gain.green), 1.0,
            0.0, CGGammaValue(gain.blue), 1.0
        )
    }

    private func forEachActiveDisplay(_ body: (CGDirectDisplayID) -> Void) {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else { return }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else { return }

        for index in 0..<Int(displayCount) {
            body(displays[index])
        }
    }
}

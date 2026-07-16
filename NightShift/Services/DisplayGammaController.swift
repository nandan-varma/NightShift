import CoreGraphics
import Foundation

/// The only place in the app that touches CGDisplay gamma APIs.
/// Applies a color-temperature gain to every active display by scaling each
/// channel's transfer-function max (the same lightweight technique used by
/// f.lux/Shifty/NightOwl), rather than building a full 256-entry gamma table.
final class DisplayGammaController {
    private static let maxDisplays: UInt32 = 16

    /// Applies the given Kelvin value's RGB gain to every active display.
    func apply(kelvin: Double) {
        let gain = ColorTemperature.kelvinToRGBGain(kelvin)
        forEachActiveDisplay { display in
            CGSetDisplayTransferByFormula(
                display,
                0.0, CGGammaValue(gain.red), 1.0,
                0.0, CGGammaValue(gain.green), 1.0,
                0.0, CGGammaValue(gain.blue), 1.0
            )
        }
    }

    /// Resets every active display to a neutral (1,1,1) transfer function.
    /// Used for "Off"/"Force Day", and must be called before the app quits or
    /// terminates so the user is never left with a stuck warm screen.
    func restoreNeutral() {
        forEachActiveDisplay { display in
            CGSetDisplayTransferByFormula(display, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0)
        }
    }

    private func forEachActiveDisplay(_ body: (CGDirectDisplayID) -> Void) {
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(Self.maxDisplays))
        var displayCount: UInt32 = 0

        let result = CGGetActiveDisplayList(Self.maxDisplays, &displays, &displayCount)
        guard result == .success else { return }

        for index in 0..<Int(displayCount) {
            body(displays[index])
        }
    }
}

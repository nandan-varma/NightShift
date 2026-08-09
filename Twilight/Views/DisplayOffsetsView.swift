import SwiftUI
import CoreGraphics
import ColorSync

/// Per-display Kelvin offset sliders. Displays are enumerated at render time
/// (the popover reopens on each menu-bar click, so hot-plugged displays appear
/// naturally); offsets persist keyed by each display's stable UUID.
struct DisplayOffsetsView: View {
    @Bindable var settings: SettingsStore

    private static let offsetRange: ClosedRange<Double> = -1000...1000

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Offsets")
                .font(.subheadline)

            if displays.isEmpty {
                Text("No displays detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(displays, id: \.uuid) { display in
                    HStack(spacing: 8) {
                        Text(display.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 86, alignment: .leading)
                        Slider(value: offsetBinding(display.uuid), in: Self.offsetRange, step: 50)
                        Text(offsetLabel(display.uuid))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                    }
                }
                Text("Fine-tune warmth per display. Negative = warmer.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var displays: [DisplayInfo] {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else { return [] }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &ids, &displayCount) == .success else { return [] }

        let mainID = CGMainDisplayID()
        return ids.enumerated().map { index, id in
            let name = id == mainID ? "Built-in" : "Display \(index + 1)"
            let uuid = Self.uuidString(for: id) ?? "\(id)"
            return DisplayInfo(uuid: uuid, name: name)
        }
    }

    private func offsetBinding(_ uuid: String) -> Binding<Double> {
        Binding(
            get: { settings.displayOffsets[uuid] ?? 0 },
            set: { settings.displayOffsets[uuid] = $0 }
        )
    }

    private func offsetLabel(_ uuid: String) -> String {
        let value = settings.displayOffsets[uuid] ?? 0
        guard value != 0 else { return "0K" }
        return (value > 0 ? "+" : "−") + "\(Int(abs(value)))K"
    }

    private static func uuidString(for display: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(display) else { return nil }
        return CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
    }

    private struct DisplayInfo: Identifiable {
        let uuid: String
        let name: String
        var id: String { uuid }
    }
}

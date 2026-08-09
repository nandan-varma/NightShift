import SwiftUI

/// Choose the menu bar icon: either "Auto" (the icon follows the current
/// phase — sun by day, moon by night) or a fixed SF Symbol.
struct MenuBarIconPickerView: View {
    @Bindable var settings: SettingsStore

    private static let adaptiveSymbol = "adaptive"

    private static let options: [(symbol: String, label: String)] = [
        (adaptiveSymbol, "Auto (matches phase)"),
        ("moon.fill", "Moon"),
        ("sun.max.fill", "Sun"),
        ("moon.stars.fill", "Moon & Stars"),
        ("thermometer.medium", "Thermometer"),
        ("circle.lefthalf.filled", "Half Circle")
    ]

    var body: some View {
        HStack {
            Text("Menu Bar Icon")
                .font(.subheadline)
            Spacer()
            Menu {
                ForEach(Self.options, id: \.symbol) { option in
                    Button {
                        settings.menuBarIconName = option.symbol == Self.adaptiveSymbol ? "" : option.symbol
                    } label: {
                        Label(option.label, systemImage: symbol(for: option.symbol))
                        if currentSymbol == option.symbol {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: symbol(for: currentSymbol))
                    Text(currentLabel)
                        .font(.caption)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var currentSymbol: String {
        settings.menuBarIconName.isEmpty ? Self.adaptiveSymbol : settings.menuBarIconName
    }

    private var currentLabel: String {
        Self.options.first { $0.symbol == currentSymbol }?.label ?? "Auto"
    }

    private func symbol(for option: String) -> String {
        option == Self.adaptiveSymbol ? "sparkles" : option
    }
}

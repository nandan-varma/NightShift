import AppIntents

/// The mode options exposed to Shortcuts, mirroring `ScheduleMode`.
enum TwilightModeEnum: String, CaseIterable, AppEnum {
    case auto
    case day
    case night
    case custom
    case off

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Twilight Mode"
    static var caseDisplayRepresentations: [TwilightModeEnum: DisplayRepresentation] = [
        .auto: "Auto",
        .day: "Day",
        .night: "Night",
        .custom: "Custom",
        .off: "Off",
    ]

    var scheduleMode: ScheduleMode {
        switch self {
        case .auto: .auto
        case .day: .forceDay
        case .night: .forceNight
        case .custom: .custom
        case .off: .off
        }
    }
}

/// "Set Twilight Mode" — controls the schedule from Shortcuts, the menu-bar
/// widget, or Siri.
struct SetTwilightModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Twilight Mode"
    static var description = IntentDescription("Sets Twilight to Auto, Day, Night, Custom, or Off.")

    @Parameter(title: "Mode")
    var mode: TwilightModeEnum

    func perform() async throws -> some IntentResult {
        let scheduleMode = mode.scheduleMode
        await MainActor.run {
            SettingsStore.shared.scheduleMode = scheduleMode
        }
        return .result()
    }
}

/// "Get Twilight Status" — reports the current mode, phase, and Kelvin.
struct GetTwilightStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Twilight Status"
    static var description = IntentDescription("Reports Twilight's current mode and display temperature.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let status = await MainActor.run { () -> String in
            guard let engine = AppDelegate.shared?.scheduleEngine else {
                return SettingsStore.shared.scheduleMode.label
            }
            let phaseLabel: String
            switch engine.currentPhase {
            case .day: phaseLabel = "Day"
            case .night: phaseLabel = "Night"
            case .transitioningToNight, .transitioningToDay: phaseLabel = "Transitioning"
            case .off: phaseLabel = "Off"
            }
            return "\(phaseLabel), \(Int(engine.currentKelvin))K"
        }
        return .result(dialog: "Twilight is set to \(status)")
    }
}

/// Registers the app's Shortcuts so they appear in the Shortcuts app and can
/// be invoked with a keyboard shortcut.
struct TwilightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetTwilightModeIntent(),
            phrases: [
                "Set \(.applicationName) to \(\.$mode)",
                "Turn \(.applicationName) \(\.$mode)"
            ],
            shortTitle: "Set Mode",
            systemImageName: "moon.fill"
        )
        AppShortcut(
            intent: GetTwilightStatusIntent(),
            phrases: [
                "What's \(.applicationName) set to",
                "Get \(.applicationName) status"
            ],
            shortTitle: "Status",
            systemImageName: "info.circle"
        )
    }
}

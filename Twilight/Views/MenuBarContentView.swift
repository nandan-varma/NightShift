import SwiftUI

struct MenuBarContentView: View {
    let settings: SettingsStore
    let scheduleEngine: ScheduleEngine
    let gammaController: DisplayGammaController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusHeaderView(settings: settings, scheduleEngine: scheduleEngine)

            Divider()
            ModeControlView(settings: settings)

            Divider()
            TemperatureSlidersView(settings: settings)

            Divider()
            TransitionDurationView(settings: settings)

            Divider()
            BedtimeSectionView(settings: settings)

            Divider()
            LocationSectionView(settings: settings)

            Divider()
            LaunchAtLoginToggleView(settings: settings)

            Divider()

            HStack {
                Text("Twilight 1.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                QuitButtonView(gammaController: gammaController)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

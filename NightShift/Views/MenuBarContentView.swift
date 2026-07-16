import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var scheduleEngine: ScheduleEngine
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
            LocationSectionView(settings: settings)

            Divider()
            LaunchAtLoginToggleView(settings: settings)

            Divider()

            HStack {
                Text("NightShift 1.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                QuitButtonView(gammaController: gammaController)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

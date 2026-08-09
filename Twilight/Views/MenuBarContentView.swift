import SwiftUI

struct MenuBarContentView: View {
    let settings: SettingsStore
    let scheduleEngine: ScheduleEngine
    let gammaController: DisplayGammaController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusHeaderView(settings: settings, scheduleEngine: scheduleEngine)

            if settings.scheduleMode == .auto || settings.scheduleMode == .custom {
                ScheduleCurveView(
                    settings: settings,
                    now: Date(),
                    nextTransition: scheduleEngine.nextTransitionDate
                )
            }

            Divider()
            ModeControlView(settings: settings)

            Divider()
            TemperatureSlidersView(settings: settings)

            Divider()
            TransitionDurationView(settings: settings)

            Divider()
            BedtimeSectionView(settings: settings)
            WakeSectionView(settings: settings)

            if settings.scheduleMode == .custom {
                Divider()
                CustomScheduleSectionView(settings: settings)
            }

            Divider()
            DisplayOffsetsView(settings: settings)

            Divider()
            LocationSectionView(settings: settings)

            Divider()
            VStack(spacing: 8) {
                MenuBarIconPickerView(settings: settings)
                LaunchAtLoginToggleView(settings: settings)
            }

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

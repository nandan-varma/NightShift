import SwiftUI

struct ModeControlView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Picker("Mode", selection: $settings.scheduleMode) {
            ForEach(ScheduleMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

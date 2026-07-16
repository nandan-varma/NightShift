import SwiftUI

struct LaunchAtLoginToggleView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Toggle("Launch at Login", isOn: $settings.launchAtLoginEnabled)
            .font(.subheadline)
            .onChange(of: settings.launchAtLoginEnabled) { _, newValue in
                LaunchAtLoginService.setEnabled(newValue)
            }
            .onAppear {
                settings.launchAtLoginEnabled = LaunchAtLoginService.isEnabled
            }
    }
}

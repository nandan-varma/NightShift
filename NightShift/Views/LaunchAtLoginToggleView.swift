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
                // Deferred to the next runloop turn: writing straight to a
                // @Published property from onAppear can land mid-transaction
                // if this view mounts as part of an in-flight SwiftUI update
                // (e.g. an enclosing withAnimation step change), which trips
                // "Publishing changes from within view updates".
                DispatchQueue.main.async {
                    settings.launchAtLoginEnabled = LaunchAtLoginService.isEnabled
                }
            }
    }
}

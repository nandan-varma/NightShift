import SwiftUI

@main
struct NightShiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                settings: appDelegate.settings,
                scheduleEngine: appDelegate.scheduleEngine,
                locationService: appDelegate.locationService,
                gammaController: appDelegate.gammaController
            )
        } label: {
            MenuBarIcon(phase: appDelegate.scheduleEngine.currentPhase)
        }
        .menuBarExtraStyle(.window)
    }
}

import SwiftUI

@main
struct NightShiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                settings: appDelegate.settings,
                scheduleEngine: appDelegate.scheduleEngine,
                gammaController: appDelegate.gammaController
            )
        } label: {
            MenuBarIcon(
                phase: appDelegate.scheduleEngine.currentPhase,
                settings: appDelegate.settings,
                gammaController: appDelegate.gammaController
            )
        }
        .menuBarExtraStyle(.window)
    }
}

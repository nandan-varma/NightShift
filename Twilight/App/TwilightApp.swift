import SwiftUI

@main
struct TwilightApp: App {
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
                gammaController: appDelegate.gammaController,
                scheduleEngine: appDelegate.scheduleEngine
            )
        }
        .menuBarExtraStyle(.window)
    }
}

import AppKit
import CoreGraphics
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()
    let locationService = LocationService()
    let gammaController = DisplayGammaController()
    private(set) lazy var scheduleEngine = ScheduleEngine(settings: settings, locationService: locationService, gammaController: gammaController)

    private var reconfigDebounceWorkItem: DispatchWorkItem?
    private static var sharedGammaController: DisplayGammaController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        Self.sharedGammaController = gammaController
        signal(SIGINT) { _ in
            AppDelegate.sharedGammaController?.restoreNeutral()
            exit(0)
        }
        signal(SIGTERM) { _ in
            AppDelegate.sharedGammaController?.restoreNeutral()
            exit(0)
        }

        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        locationService.requestAuthorizationAndLocation()
        scheduleEngine.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduleEngine.stop()
        gammaController.restoreNeutral()
        CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func handleWake() {
        scheduleEngine.reapplyCurrentState()
    }

    fileprivate func handleDisplayReconfiguration() {
        reconfigDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.scheduleEngine.reapplyCurrentState()
        }
        reconfigDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }
}

/// Monitor hot-plug/mode changes reset per-display transfer functions;
/// debounce and reapply the current Kelvin value when this fires.
private func displayReconfigurationCallback(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags, userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo else { return }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
    delegate.handleDisplayReconfiguration()
}

import AppKit
import SwiftUI
import CoreGraphics
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let settings = SettingsStore()
    let gammaController = DisplayGammaController()
    private(set) lazy var scheduleEngine = ScheduleEngine(settings: settings, gammaController: gammaController)

    private var reconfigDebounceWorkItem: DispatchWorkItem?
    private static var sharedGammaController: DisplayGammaController?
    private var onboardingWindow: NSWindow?

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

        if !settings.hasCompletedOnboarding {
            showOnboardingWindow()
        }

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

    private func showOnboardingWindow() {
        let onboarding = OnboardingView(settings: settings) { [weak self] in
            self?.onboardingWindow?.close()
        }

        let window = NSWindow(contentViewController: NSHostingController(rootView: onboarding))
        window.title = "Welcome to NightShift"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        onboardingWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === onboardingWindow else { return }
        settings.hasCompletedOnboarding = true
        onboardingWindow = nil
    }
}

/// Monitor hot-plug/mode changes reset per-display transfer functions;
/// debounce and reapply the current Kelvin value when this fires.
private func displayReconfigurationCallback(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags, userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo else { return }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
    delegate.handleDisplayReconfiguration()
}

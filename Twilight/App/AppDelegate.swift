import AppKit
import SwiftUI
import CoreGraphics
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let settings = SettingsStore()
    let gammaController = DisplayGammaController()
    private(set) lazy var scheduleEngine = ScheduleEngine(settings: settings, gammaController: gammaController)

    private var reconfigDebounceTask: Task<Void, Never>?
    private var onboardingWindow: NSWindow?
    private var sigintSource: DispatchSourceSignal?
    private var sigtermSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        installSignalHandlers()

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

    /// Installs SIGINT/SIGTERM handling via GCD dispatch sources rather than a
    /// raw `signal()` handler. A raw handler runs on the signal-delivery
    /// thread inside the actual signal context, where calling into Swift/ARC
    /// code (retaining `gammaController`, invoking its method) is not
    /// async-signal-safe — if the signal lands while the main thread already
    /// holds an ARC-related lock, re-entering that same machinery can
    /// deadlock, which would skip `restoreNeutral()` and leave the display
    /// stuck warm. A dispatch source instead just observes the signal and
    /// runs its handler as an ordinary block on the main queue.
    private func installSignalHandlers() {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigint.setEventHandler { [gammaController] in
            gammaController.restoreNeutral()
            exit(0)
        }
        sigint.resume()
        sigintSource = sigint

        let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigterm.setEventHandler { [gammaController] in
            gammaController.restoreNeutral()
            exit(0)
        }
        sigterm.resume()
        sigtermSource = sigterm
    }

    @objc private func handleWake() {
        scheduleEngine.reapplyCurrentState()
    }

    fileprivate func handleDisplayReconfiguration() {
        reconfigDebounceTask?.cancel()
        reconfigDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            self?.scheduleEngine.reapplyCurrentState()
        }
    }

    private func showOnboardingWindow() {
        let onboarding = OnboardingView(settings: settings) { [weak self] in
            self?.onboardingWindow?.close()
        }

        let window = NSWindow(contentViewController: NSHostingController(rootView: onboarding))
        window.title = "Welcome to Twilight"
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
private nonisolated func displayReconfigurationCallback(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags, userInfo: UnsafeMutableRawPointer?) {
    guard let userInfo else { return }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo).takeUnretainedValue()
    Task { @MainActor in
        delegate.handleDisplayReconfiguration()
    }
}

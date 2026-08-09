import AppKit
import SwiftUI
import CoreGraphics
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// Shared instance for App Intents (which can launch the app in the
    /// background before the SwiftUI lifecycle hooks are wired up).
    private(set) static weak var shared: AppDelegate?

    /// Persisted flag: cleared at launch, set again only on a clean quit. A
    /// crash leaves it cleared, so the next launch knows to restore the
    /// display to neutral before re-applying state — otherwise a hard kill
    /// would leave the screen warm until reboot or relaunch.
    private static let terminatedCleanlyKey = "terminatedCleanly"

    let settings = SettingsStore.shared
    let gammaController = DisplayGammaController()
    private(set) lazy var scheduleEngine = ScheduleEngine(settings: settings, gammaController: gammaController)

    private var reconfigDebounceTask: Task<Void, Never>?
    private var onboardingWindow: NSWindow?
    private var sigintSource: DispatchSourceSignal?
    private var sigtermSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)

        installSignalHandlers()

        // A cleared flag means the previous session died without quitting
        // cleanly (crash / force-quit), which can leave the transfer function
        // warm on some displays — un-stick it before scheduling takes over.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.terminatedCleanlyKey) {
            gammaController.restoreNeutral()
        }
        defaults.set(false, forKey: Self.terminatedCleanlyKey)

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
        UserDefaults.standard.set(true, forKey: Self.terminatedCleanlyKey)
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

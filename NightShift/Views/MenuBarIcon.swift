import SwiftUI
import AppKit

struct MenuBarIcon: View {
    let phase: SchedulePhase
    let settings: SettingsStore
    let gammaController: DisplayGammaController

    var body: some View {
        Image(systemName: symbolName)
            .accessibilityLabel(accessibilityDescription)
            .overlay(MenuBarContextMenuCatcher(settings: settings, gammaController: gammaController))
    }

    private var symbolName: String {
        switch phase {
        case .day: "sun.max.fill"
        case .night: "moon.fill"
        case .transitioningToNight, .transitioningToDay: "sun.haze.fill"
        case .off: "circle.slash"
        }
    }

    private var accessibilityDescription: String {
        switch phase {
        case .day: "Night Shift: Day"
        case .night: "Night Shift: Night"
        case .transitioningToNight, .transitioningToDay: "Night Shift: Transitioning"
        case .off: "Night Shift: Off"
        }
    }
}

/// MenuBarExtra has no public API for a distinct secondary-click menu — left
/// and right click both just toggle the same SwiftUI window. This installs a
/// local right-mouse-down monitor scoped to this view's own window (the
/// status item's private button window) and pops up a standard AppKit menu
/// instead, without disturbing the label's normal left-click behavior.
private struct MenuBarContextMenuCatcher: NSViewRepresentable {
    let settings: SettingsStore
    let gammaController: DisplayGammaController

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.settings = settings
        context.coordinator.gammaController = gammaController
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(settings: settings, gammaController: gammaController)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var settings: SettingsStore
        var gammaController: DisplayGammaController
        private weak var view: NSView?
        private var monitor: Any?

        init(settings: SettingsStore, gammaController: DisplayGammaController) {
            self.settings = settings
            self.gammaController = gammaController
        }

        func install(on view: NSView) {
            self.view = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self else { return event }
                self.showMenu(for: event)
                return nil
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func showMenu(for event: NSEvent) {
            guard let anchorView = event.window?.contentView else { return }

            let menu = NSMenu()

            for mode in ScheduleMode.allCases {
                menu.addItem(ClosureMenuItem(
                    title: mode.label,
                    state: settings.scheduleMode == mode ? .on : .off
                ) { [weak self] in
                    Task { @MainActor in self?.settings.scheduleMode = mode }
                })
            }

            menu.addItem(.separator())

            menu.addItem(ClosureMenuItem(
                title: "Launch at Login",
                state: settings.launchAtLoginEnabled ? .on : .off
            ) { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    let requested = !self.settings.launchAtLoginEnabled
                    self.settings.launchAtLoginEnabled = LaunchAtLoginService.setEnabled(requested)
                }
            })

            menu.addItem(.separator())

            menu.addItem(ClosureMenuItem(title: "Quit NightShift") { [weak self] in
                Task { @MainActor in
                    self?.gammaController.restoreNeutral()
                    NSApp.terminate(nil)
                }
            })

            let locationInView = anchorView.convert(event.locationInWindow, from: nil)
            menu.popUp(positioning: nil, at: locationInView, in: anchorView)
        }
    }
}

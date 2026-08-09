import SwiftUI
import AppKit

struct MenuBarIcon: View {
    let phase: SchedulePhase
    let settings: SettingsStore
    let gammaController: DisplayGammaController
    let scheduleEngine: ScheduleEngine

    var body: some View {
        Image(systemName: symbolName)
            .accessibilityLabel(accessibilityDescription)
            .overlay(MenuBarContextMenuCatcher(
                settings: settings,
                gammaController: gammaController,
                scheduleEngine: scheduleEngine
            ))
    }

    private var symbolName: String {
        if !settings.menuBarIconName.isEmpty {
            return settings.menuBarIconName
        }
        switch phase {
        case .day: return "sun.max.fill"
        case .night: return "moon.fill"
        case .transitioningToNight, .transitioningToDay: return "sun.haze.fill"
        case .off: return "circle.slash"
        }
    }

    private var accessibilityDescription: String {
        switch phase {
        case .day: "Twilight: Day"
        case .night: "Twilight: Night"
        case .transitioningToNight, .transitioningToDay: "Twilight: Transitioning"
        case .off: "Twilight: Off"
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
    let scheduleEngine: ScheduleEngine

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.settings = settings
        context.coordinator.gammaController = gammaController
        context.coordinator.scheduleEngine = scheduleEngine
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(settings: settings, gammaController: gammaController, scheduleEngine: scheduleEngine)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var settings: SettingsStore
        var gammaController: DisplayGammaController
        var scheduleEngine: ScheduleEngine
        private weak var view: NSView?
        private var monitor: Any?

        init(settings: SettingsStore, gammaController: DisplayGammaController, scheduleEngine: ScheduleEngine) {
            self.settings = settings
            self.gammaController = gammaController
            self.scheduleEngine = scheduleEngine
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

            if settings.suspendUntil != nil {
                menu.addItem(ClosureMenuItem(title: "Resume") { [weak self] in
                    Task { @MainActor in self?.settings.suspendUntil = nil }
                })
            } else {
                menu.addItem(ClosureMenuItem(title: "Suspend for 1 Hour") { [weak self] in
                    Task { @MainActor in
                        self?.settings.suspendUntil = Date().addingTimeInterval(3600)
                    }
                })
                menu.addItem(ClosureMenuItem(title: "Suspend until Sunrise") { [weak self] in
                    Task { @MainActor in
                        guard let self else { return }
                        self.settings.suspendUntil = self.scheduleEngine.nextSunrise()
                    }
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

            menu.addItem(ClosureMenuItem(title: "Quit Twilight") { [weak self] in
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

import ServiceManagement

/// Wraps SMAppService.mainApp for the "Launch at Login" toggle.
enum LaunchAtLoginService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Best-effort: if registration fails (e.g. user denied in System Settings),
            // the UI will simply resync to the actual SMAppService status on next read.
        }
    }
}

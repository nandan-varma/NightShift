import os
import ServiceManagement

/// Wraps SMAppService.mainApp for the "Launch at Login" toggle.
enum LaunchAtLoginService {
    private static let logger = Logger(subsystem: "com.nandanvarma.NightShift", category: "LaunchAtLogin")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Attempts to register/unregister the app, returning whether the resulting
    /// status matches what was requested. Callers should resync any toggle UI
    /// to this return value rather than assuming the request succeeded, since
    /// registration can silently fail (e.g. the user denied it in System Settings).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
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
            let action = enabled ? "register" : "unregister"
            logger.error("Failed to \(action, privacy: .public) launch-at-login: \(error.localizedDescription, privacy: .public)")
        }
        return isEnabled
    }
}

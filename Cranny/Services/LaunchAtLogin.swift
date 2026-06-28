import ServiceManagement
import os

/// Launch-at-login via `SMAppService.mainApp` (macOS 13+). No helper bundle needed.
enum LaunchAtLogin {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.alanko.cranny",
        category: "LaunchAtLogin"
    )

    /// Live status — stays correct even if the user toggled it in System Settings.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    try? SMAppService.mainApp.unregister()   // re-registering an enabled item can throw
                }
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Failed to set launch-at-login=\(enabled): \(error.localizedDescription)")
            throw error
        }
    }
}

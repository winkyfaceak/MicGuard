import ServiceManagement

/// Login item registration for the app bundle itself.
///
/// Only works on a real `.app` bundle — running the bare SwiftPM binary will
/// report `.notFound`. Build with `make bundle` before testing this.
enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var isAvailable: Bool {
        SMAppService.mainApp.status != .notFound
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

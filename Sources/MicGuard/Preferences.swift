import Foundation

/// Small typed wrapper over UserDefaults so the model never touches raw keys.
struct Preferences {

    private enum Key {
        static let preferredUID = "preferredInputDeviceUID"
        static let isEnforcing = "isEnforcing"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Enforcement on by default — that's the whole point of the app.
        defaults.register(defaults: [Key.isEnforcing: true])
    }

    /// Stored by UID rather than AudioDeviceID: numeric IDs are recycled
    /// between reconnects, UIDs survive reboots.
    var preferredUID: String? {
        get { defaults.string(forKey: Key.preferredUID) }
        nonmutating set { defaults.set(newValue, forKey: Key.preferredUID) }
    }

    var isEnforcing: Bool {
        get { defaults.bool(forKey: Key.isEnforcing) }
        nonmutating set { defaults.set(newValue, forKey: Key.isEnforcing) }
    }
}

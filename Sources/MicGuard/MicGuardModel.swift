import CoreAudio
import MicGuardCore
import Observation
import SwiftUI

/// Owns the app's state and the reconciliation loop.
///
/// The cycle is: HAL property changes → listener fires → `refresh()` reads the
/// world → `reconcile()` writes the default input back if it drifted.
@MainActor
@Observable
final class MicGuardModel {

    private(set) var inputs: [AudioDevice] = []
    private(set) var currentUID: String?
    private(set) var preferredUID: String?
    private(set) var isEnforcing: Bool
    private(set) var lastError: String?

    private let preferences = Preferences()
    private var listeners: [AudioPropertyListener] = []

    init() {
        isEnforcing = preferences.isEnforcing
        preferredUID = preferences.preferredUID
        refresh()

        // Watch both: the mic being switched, and devices coming or going.
        // Bluetooth reconnects show up as a device-list change first.
        for selector in [
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDevices,
        ] {
            listeners.append(
                AudioPropertyListener(selector: selector) { [weak self] in
                    // The listener queue is .main, so this hop is a formality
                    // the compiler needs, not a thread change.
                    MainActor.assumeIsolated {
                        self?.refresh()
                    }
                }
            )
        }
    }

    // MARK: - Derived state

    var currentDevice: AudioDevice? {
        inputs.first { $0.uid == currentUID }
    }

    var targetDevice: AudioDevice? {
        InputSelection.target(preferredUID: preferredUID, devices: inputs)
    }

    /// Filled when enforcement is on but no target exists to enforce.
    var statusText: String {
        guard isEnforcing else { return "Not enforcing" }
        guard let targetDevice else { return "No built-in mic found" }
        return "Holding \(targetDevice.name)"
    }

    var menuBarSymbol: String {
        isEnforcing ? "mic.fill" : "mic.slash"
    }

    // MARK: - Intents

    /// Pick a device from the menu. This becomes the new preference *and*
    /// re-enables enforcement, so the choice sticks across reconnects.
    func select(_ device: AudioDevice) {
        preferredUID = device.uid
        preferences.preferredUID = device.uid
        apply(device)
        refresh()
    }

    func setEnforcing(_ enabled: Bool) {
        isEnforcing = enabled
        preferences.isEnforcing = enabled
        if enabled { reconcile() }
    }

    /// Forget the explicit preference and fall back to "whatever is built in".
    func clearPreference() {
        preferredUID = nil
        preferences.preferredUID = nil
        reconcile()
        refresh()
    }

    // MARK: - The loop

    private func refresh() {
        inputs = AudioSystem.inputDevices()
        currentUID = AudioSystem.defaultInputDeviceID().flatMap {
            AudioSystem.describe($0)?.uid
        }
        reconcile()
    }

    private func reconcile() {
        guard isEnforcing else { return }
        let target = targetDevice
        // Without this guard the write below would retrigger the listener
        // that called us, and the app would spin.
        guard InputSelection.needsCorrection(currentUID: currentUID, target: target),
              let target
        else { return }

        apply(target)
        currentUID = target.uid
    }

    private func apply(_ device: AudioDevice) {
        do {
            try AudioSystem.setDefaultInputDevice(device.id)
            lastError = nil
        } catch {
            lastError = String(describing: error)
        }
    }
}

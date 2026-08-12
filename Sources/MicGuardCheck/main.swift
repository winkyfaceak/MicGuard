import CoreAudio
import Foundation
import MicGuardCore

// A standalone checker, not a test bundle.
//
// Command Line Tools ships neither swift-testing nor XCTest, so `swift test`
// is unavailable without a full Xcode install. This executable runs the same
// assertions with plain Swift and exits non-zero on failure, which is enough
// for a pre-commit check or a CI step.
//
//   swift run MicGuardCheck           # assertions over the selection rules
//   swift run MicGuardCheck devices   # live dump of what the HAL reports

// MARK: - Minimal assertion harness

var failures = 0

// Top-level code in main.swift is main-actor isolated under Swift 6, so
// anything touching `failures` has to be too.
@MainActor
func expect(_ condition: Bool, _ label: String) {
    if condition {
        print("  ok   \(label)")
    } else {
        failures += 1
        print("  FAIL \(label)")
    }
}

// MARK: - Fixtures

func makeDevice(
    _ id: AudioDeviceID,
    _ uid: String,
    _ name: String,
    builtIn: Bool = false
) -> AudioDevice {
    AudioDevice(
        id: id,
        uid: uid,
        name: name,
        transport: builtIn ? kAudioDeviceTransportTypeBuiltIn : kAudioDeviceTransportTypeBluetooth
    )
}

let builtIn = makeDevice(1, "BuiltInMicrophoneDevice", "MacBook Pro Microphone", builtIn: true)
let headset = makeDevice(2, "AirPods-Pro-UID", "AirPods Pro")

// MARK: - Live device dump

func dumpDevices() {
    let inputs = AudioSystem.inputDevices()
    let currentUID = AudioSystem.defaultInputDeviceID().flatMap { AudioSystem.describe($0)?.uid }

    print("Input devices visible to Core Audio:\n")
    if inputs.isEmpty {
        print("  (none)")
    }
    for device in inputs {
        let marker = device.uid == currentUID ? "*" : " "
        let kind = device.isBuiltIn ? "built-in" : device.isBluetooth ? "bluetooth" : "other"
        print("  \(marker) [\(device.id)] \(device.name)")
        print("      uid: \(device.uid)  transport: \(kind)")
    }
    print("\n  * = current system default input")
}

// MARK: - Entry point

if CommandLine.arguments.dropFirst().first == "devices" {
    dumpDevices()
    exit(0)
}

print("InputSelection.target")
expect(
    InputSelection.target(preferredUID: nil, devices: [headset, builtIn]) == builtIn,
    "falls back to the built-in mic when nothing is preferred"
)
expect(
    InputSelection.target(preferredUID: headset.uid, devices: [headset, builtIn]) == headset,
    "honours an explicit preference over the built-in mic"
)
expect(
    InputSelection.target(preferredUID: headset.uid, devices: [builtIn]) == builtIn,
    "falls back when the preferred device is disconnected"
)
expect(
    InputSelection.target(preferredUID: nil, devices: [headset]) == nil,
    "leaves things alone when there is no built-in mic"
)

print("\nInputSelection.needsCorrection")
expect(
    InputSelection.needsCorrection(currentUID: builtIn.uid, target: builtIn) == false,
    "no correction when the current device already matches"
)
expect(
    InputSelection.needsCorrection(currentUID: headset.uid, target: builtIn),
    "correction when the mic has drifted to the headset"
)
expect(
    InputSelection.needsCorrection(currentUID: headset.uid, target: nil) == false,
    "never corrects toward a nil target"
)

print("")
if failures == 0 {
    print("All checks passed.")
    exit(0)
} else {
    print("\(failures) check(s) failed.")
    exit(1)
}

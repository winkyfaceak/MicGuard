# MicGuard

<img width="312" height="300" alt="Screenshot 2026-08-12 at 12 51 26 pm" src="https://github.com/user-attachments/assets/e85fe10a-0e73-4350-a4f9-c200297c83cc" />

A macOS menu bar app that holds the system input device on the built-in
microphone or a microphone of your choosing, so connecting Bluetooth headphones doesn't hijack the mic. Which doesn't
drag the headphones into low-quality HFP mode along with it.

Pick a different mic from the menu when you actually want one; that choice
becomes the new preference and survives reconnects.

## Requirements

Swift 6.x. **Full Xcode is not required** - this builds entirely with Command
Line Tools (`xcode-select --install`).

## Everyday commands

```bash
make build     # compile check while editing
make test      # run the selection-rule assertions
make devices   # dump what Core Audio currently sees
make run       # rebuild, relaunch, look for the mic icon in the menu bar
make install   # copy to /Applications and launch
make uninstall # remove from /Applications
make clean
```

`make run` is the inner loop. `make devices` is the first thing to reach for
when the wrong device gets picked — it prints every input device with its UID
and transport type, and marks the current system default.

## Layout

```
Sources/MicGuardCore/     no UI, no app lifecycle
  AudioDevice.swift            one device as the HAL describes it
  AudioSystem.swift            the HAL wrapper — read/write/enumerate
  AudioPropertyListener.swift  change notifications, unregistered on deinit
  InputSelection.swift         pure decision rules (what *should* be default)

Sources/MicGuard/         the menu bar app
  MicGuardApp.swift            @main, MenuBarExtra
  MenuView.swift               the dropdown
  MicGuardModel.swift          state + the reconciliation loop
  Preferences.swift            UserDefaults storage
  LaunchAtLogin.swift          SMAppService wrapper

Sources/MicGuardCheck/    assertions + live device dump (see Testing below)
Scripts/bundle.sh         wraps the binary into MicGuard.app
Resources/Info.plist      bundle metadata
```

The split exists so the decision rules in `InputSelection` can be checked
without audio hardware or a running GUI.

## How it works

Everything macOS knows about audio hardware is exposed as *properties* on
*audio objects*. The system is an object; so is each device. Four C functions
in the CoreAudio framework read and write them, and `AudioSystem` wraps the
pointer bookkeeping they need.

Setting the default input is one property write:

```swift
kAudioHardwarePropertyDefaultInputDevice  ←  AudioDeviceID
```

No entitlements, no microphone permission (nothing here *captures* audio, it
only changes a setting), no root.

The rest is a loop:

1. `AudioPropertyListener` watches `kAudioHardwarePropertyDefaultInputDevice`
   (something changed the mic) and `kAudioHardwarePropertyDevices` (a device
   appeared or vanished — a Bluetooth reconnect shows up here first).
2. On either signal, `refresh()` re-reads the device list and current default.
3. `reconcile()` writes the default back if it drifted.

### Two things that will bite you if you change this code

**The feedback loop.** Writing the default input fires the very listener that
triggered the write. `InputSelection.needsCorrection` is the guard that stops
it spinning — it returns `false` when the current device already matches. Take
it out and you get a pegged CPU core.

**Device IDs are not stable.** `AudioDeviceID` is reassigned on reconnect and
reboot. Anything persisted uses `kAudioDevicePropertyDeviceUID` instead, which
survives both. That's why `Preferences` stores a UID string.

## Testing

`make test` runs `Sources/MicGuardCheck`, a plain executable that asserts over
`InputSelection` and exits non-zero on failure.

It isn't a `.testTarget` on purpose: Command Line Tools ships neither
swift-testing nor XCTest, so `swift test` fails with `no such module 'Testing'`
unless full Xcode is installed. If you do install Xcode later, the assertions
in `MicGuardCheck/main.swift` map onto `@Test` functions almost line for line.

## Packaging notes

`swift build` alone produces a bare binary, which is not enough — `MenuBarExtra`
needs `LSUIElement` and a bundle identifier, and `SMAppService` needs a code
signature. `Scripts/bundle.sh` assembles `MicGuard.app`, copies `Info.plist`,
and applies an **ad-hoc signature** (`codesign --sign -`). That's fine for your
own machine; sharing it with anyone else would need a Developer ID identity,
notarization, or they'd hit Gatekeeper.

Launch at Login uses `SMAppService.mainApp`, which only works on a real bundle
in a stable location — run `make install` first, or the toggle stays disabled.

## Known limits

- **Apps can override you.** Zoom, Discord and friends remember their own input
  device independently of the system default and will grab the headset mic
  regardless. Fix that once in each app's own settings; the HAL can't reach it.
- Only the *input* default is managed. Output is left alone deliberately.

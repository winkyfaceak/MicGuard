import MicGuardCore
import SwiftUI

struct MenuView: View {

    @Bindable var model: MicGuardModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Text(model.statusText)

        Divider()

        ForEach(model.inputs) { device in
            Button {
                model.select(device)
            } label: {
                // Menus don't render checkmarks from a modifier, so the
                // selected state goes into the title itself.
                Text("\(device.uid == model.currentUID ? "✓ " : "   ")\(label(for: device))")
            }
        }

        if model.inputs.isEmpty {
            Text("No input devices").foregroundStyle(.secondary)
        }

        Divider()

        Toggle("Force preferred microphone", isOn: enforcingBinding)

        if model.preferredUID != nil {
            Button("Use Built-in Mic Instead") { model.clearPreference() }
        }

        Toggle("Launch at Login", isOn: launchAtLoginBinding)
            .disabled(!LaunchAtLogin.isAvailable)

        if let error = model.lastError {
            Divider()
            Text(error).foregroundStyle(.red)
        }

        Divider()

        Button("Quit MicGuard") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func label(for device: AudioDevice) -> String {
        if device.uid == model.preferredUID { "\(device.name) — preferred" }
        else if device.isBuiltIn { "\(device.name) (built-in)" }
        else { device.name }
    }

    private var enforcingBinding: Binding<Bool> {
        Binding(get: { model.isEnforcing }, set: { model.setEnforcing($0) })
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                try? LaunchAtLogin.set(newValue)
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        )
    }
}

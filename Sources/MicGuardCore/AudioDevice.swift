import CoreAudio

/// A snapshot of one audio device as the HAL described it.
///
/// `id` is only valid for as long as the device stays connected — it is
/// reassigned on reconnect and reboot. `uid` is the stable identifier, so that
/// is what gets persisted to disk.
public struct AudioDevice: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let transport: UInt32

    public init(id: AudioDeviceID, uid: String, name: String, transport: UInt32) {
        self.id = id
        self.uid = uid
        self.name = name
        self.transport = transport
    }

    public var isBuiltIn: Bool {
        transport == kAudioDeviceTransportTypeBuiltIn
    }

    public var isBluetooth: Bool {
        transport == kAudioDeviceTransportTypeBluetooth
            || transport == kAudioDeviceTransportTypeBluetoothLE
    }
}

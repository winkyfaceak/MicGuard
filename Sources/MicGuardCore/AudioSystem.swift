import CoreAudio
import Foundation

public enum AudioSystemError: Error, CustomStringConvertible {
    case osStatus(OSStatus, action: String)

    public var description: String {
        switch self {
        case let .osStatus(code, action):
            "\(action) failed (OSStatus \(code))"
        }
    }
}

/// A thin Swift face over the Core Audio HAL property API.
///
/// Everything macOS knows about audio hardware is exposed as properties on
/// "audio objects". The system itself is an object (`systemObject`), and so is
/// each device. You read and write properties with four C functions; this type
/// wraps the pointer bookkeeping they require.
public enum AudioSystem {

    public static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    // MARK: - Reading the default input

    /// The device macOS is currently feeding to apps that ask for "the microphone".
    public static func defaultInputDeviceID() -> AudioDeviceID? {
        var addr = address(kAudioHardwarePropertyDefaultInputDevice)
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    // MARK: - Writing the default input

    /// Point the system default input at `deviceID`.
    ///
    /// This is the single call the whole app exists to make.
    public static func setDefaultInputDevice(_ deviceID: AudioDeviceID) throws {
        var addr = address(kAudioHardwarePropertyDefaultInputDevice)
        var value = deviceID
        let status = AudioObjectSetPropertyData(
            systemObject, &addr, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &value
        )
        guard status == noErr else {
            throw AudioSystemError.osStatus(status, action: "Setting default input device")
        }
    }

    // MARK: - Enumeration

    /// Every device that can actually record — i.e. has at least one input channel.
    ///
    /// The device list includes output-only devices and aggregates, so the
    /// channel check is what keeps speakers out of a microphone menu.
    public static func inputDevices() -> [AudioDevice] {
        allDeviceIDs().compactMap { id in
            guard inputChannelCount(of: id) > 0 else { return nil }
            return describe(id)
        }
    }

    public static func describe(_ deviceID: AudioDeviceID) -> AudioDevice? {
        guard let uid = stringProperty(deviceID, kAudioDevicePropertyDeviceUID) else { return nil }
        return AudioDevice(
            id: deviceID,
            uid: uid,
            name: stringProperty(deviceID, kAudioObjectPropertyName) ?? "Unknown device",
            transport: transportType(of: deviceID)
        )
    }

    static func allDeviceIDs() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &size) == noErr,
              size > 0
        else { return [] }

        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids
    }

    /// Total input channels across the device's streams. Zero means output-only.
    static func inputChannelCount(of deviceID: AudioDeviceID) -> Int {
        var addr = address(
            kAudioDevicePropertyStreamConfiguration,
            scope: kAudioObjectPropertyScopeInput
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size) == noErr,
              size > 0
        else { return 0 }

        // AudioBufferList is variable length, so it needs raw allocation
        // rather than a plain Swift value.
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, raw) == noErr else {
            return 0
        }
        let list = UnsafeMutableAudioBufferListPointer(
            raw.assumingMemoryBound(to: AudioBufferList.self)
        )
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    static func transportType(of deviceID: AudioDeviceID) -> UInt32 {
        var addr = address(kAudioDevicePropertyTransportType)
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &transport) == noErr else {
            return 0
        }
        return transport
    }

    /// CFString-valued properties follow the Create Rule, so the returned
    /// reference is owned by us — `takeRetainedValue` is what keeps this leak free.
    static func stringProperty(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector
    ) -> String? {
        var addr = address(selector)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

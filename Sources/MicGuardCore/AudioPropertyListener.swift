import CoreAudio
import Foundation

/// Fires `handler` whenever one HAL property changes, and unregisters itself
/// when deallocated.
///
/// The two properties worth watching:
///   - `kAudioHardwarePropertyDefaultInputDevice` — something changed the mic.
///   - `kAudioHardwarePropertyDevices` — a device appeared or vanished.
///
/// Core Audio delivers callbacks on the queue you hand it, so passing
/// `.main` here is what lets the handler safely touch main-actor state.
public final class AudioPropertyListener {

    private let objectID: AudioObjectID
    private var address: AudioObjectPropertyAddress
    private var block: AudioObjectPropertyListenerBlock?

    public init(
        objectID: AudioObjectID = AudioSystem.systemObject,
        selector: AudioObjectPropertySelector,
        queue: DispatchQueue = .main,
        handler: @escaping @Sendable () -> Void
    ) {
        self.objectID = objectID
        self.address = AudioSystem.address(selector)

        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        self.block = block

        let status = AudioObjectAddPropertyListenerBlock(objectID, &address, queue, block)
        if status != noErr {
            // Non-fatal: the app still works, it just stops re-asserting
            // automatically. Better to log than to crash a menu bar utility.
            FileHandle.standardError.write(
                Data("MicGuard: failed to observe property (OSStatus \(status))\n".utf8)
            )
            self.block = nil
        }
    }

    deinit {
        guard let block else { return }
        AudioObjectRemovePropertyListenerBlock(objectID, &address, DispatchQueue.main, block)
    }
}

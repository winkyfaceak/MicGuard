/// The decision layer: given what is plugged in and what the user asked for,
/// which device *should* be the default input?
///
/// Deliberately pure — no HAL calls, no state — so the rules can be tested
/// without any audio hardware present.
public enum InputSelection {

    /// The device the app wants selected, or `nil` if it should leave things alone.
    ///
    /// Preference order:
    ///   1. The explicitly preferred device, if it is currently connected.
    ///   2. The built-in microphone, as a fallback.
    ///   3. Nothing — don't fight over a machine with no obvious right answer.
    public static func target(
        preferredUID: String?,
        devices: [AudioDevice]
    ) -> AudioDevice? {
        if let preferredUID,
           let match = devices.first(where: { $0.uid == preferredUID }) {
            return match
        }
        return devices.first(where: \.isBuiltIn)
    }

    /// Whether a correcting write is needed right now.
    ///
    /// Guarding on this is what stops the feedback loop: setting the default
    /// input fires the very listener that called us, so re-asserting an
    /// already-correct value would spin forever.
    public static func needsCorrection(
        currentUID: String?,
        target: AudioDevice?
    ) -> Bool {
        guard let target else { return false }
        return currentUID != target.uid
    }
}

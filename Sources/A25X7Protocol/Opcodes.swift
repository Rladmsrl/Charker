import Foundation

/// Discovery identity for the Anker Prime wireless charging pad, model A25X7.
///
/// The GATT layout is the same Prime / Solix family the A2687 uses: advertised
/// service `FF09`, the 128-bit service, and the write/notify characteristics.
/// Those UUIDs stay in `A2687` so the two products cannot drift apart; this
/// type only names the facts that are specific to the pad.
///
/// Evidence: SolixBLE `maggo_3in1.py` at `10879567`, which subscribes with
/// command `4200` / payload `a10121` and reads telemetry on `4300`.
public enum A25X7 {
    /// Logical command that arms the live stream. On the wire the encrypted
    /// form is `0x4200`. Resend it after every reconnect.
    public static let subscribeOpcode: UInt16 = 0x0200

    /// Unsolicited telemetry. On the wire the encrypted form is `0x4300`.
    public static let reportOpcode: UInt16 = 0x0300

    /// Pad parameter keys, in the only order the decoder accepts.
    public static let padParameterKeys: [UInt8] = [0xA2, 0xA3, 0xA4]

    /// Advertised-name fragments, already lowercased. A hint for the picker,
    /// not proof of model: an A25X7 that only advertises `FF09` is still found
    /// by the shared service match.
    public static let nameHints = ["a25x7", "maggo"]
}

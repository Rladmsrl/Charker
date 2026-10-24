import Foundation

/// Plaintext command bytes for the pad. Encryption and BLE belong to the session.
public enum A25X7Commands {
    /// Send under command `0x0200` (wire `0x4200`) after each connection.
    /// Reports come back on `0x0300`.
    ///
    /// The captured subscription is exactly these three bytes. `now` is accepted
    /// so callers can share a timestamped command shape, and it is intentionally
    /// unused: this payload has no `FE` timestamp.
    public static func subscribePayload(now: Date = Date()) throws -> Data {
        _ = now
        return Data([0xA1, 0x01, 0x21])
    }
}

import A25X7Protocol
import A2687Protocol
import Foundation

/// The one A25X7 command this port sends after the shared Prime handshake.
///
/// Plaintext is exactly `A1 01 21`. Some generic Prime paths append an `FE`
/// timestamp; the MagGo subscribe that this port follows does not. Frame
/// sealing, the P-256 ladder, and GATT stay in the A2687 session.
enum A25X7Session {
    static func subscribeMessage(at date: Date = Date()) -> OutgoingMessage {
        let payload = (try? A25X7Commands.subscribePayload(now: date)) ?? Data([0xA1, 0x01, 0x21])
        return OutgoingMessage(
            group: Frame.sessionGroup,
            opcode: A25X7.subscribeOpcode,
            plaintext: [UInt8](payload),
            encryption: .session,
            expectsResponse: false
        )
    }
}

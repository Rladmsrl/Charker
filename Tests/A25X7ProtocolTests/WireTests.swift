import Foundation
import XCTest
@testable import A25X7Protocol

/// TLV contract the pad decoder depends on.
///
/// Frame reassembly, the `FF 09` checksum, AES-GCM, and the P-256 handshake
/// are the shared Prime stack in `A2687Protocol` (see `FrameTests`,
/// `CryptoTests`, and `HandshakeTests`). This file keeps the checks that are
/// specific to the pad’s plaintext parameters.
final class A25X7WireTests: XCTestCase {
    func testStrictTLVAndTypedBytes() throws {
        let encoded = wireHex("a10121fe0404030201a2030400ff")
        let fields = try A25X7TLV.parse(encoded)
        XCTAssertEqual(fields[0xA1], Data([0x21]))
        XCTAssertEqual(fields[0xA2], Data([4, 0, 0xFF]))
        XCTAssertEqual(
            try A25X7TLV.encode([
                (0xA1, Data([0x21])),
                (0xFE, Data([4, 3, 2, 1])),
                (0xA2, Data([4, 0, 0xFF])),
            ]),
            encoded
        )
        for malformed in ["a1", "a102ff", "00a10121", "a10121a10122", "a1012100"] {
            XCTAssertThrowsError(try A25X7TLV.parse(wireHex(malformed)))
        }
        XCTAssertThrowsError(try A25X7TLV.encode([(0xA1, Data(count: 256))]))
        XCTAssertThrowsError(try A25X7TLV.encode([(0xA1, Data()), (0xA1, Data())]))
        XCTAssertEqual(try A25X7TLV.parse(Data([0xA1, 0]))[0xA1], Data())
    }

    func testCapturedReportRoundTripsThroughTLV() throws {
        let payload = wireHex(
            "a10131a20804013a0232001d01a3080401c60214008e00a4080400f40100000000a50304ffffa6050400000000fe050300000000"
        )
        let fields = try A25X7TLV.parse(payload)
        XCTAssertEqual(fields[0xA2]?.first, 0x04)
        XCTAssertEqual(try A25X7Telemetry.decode(parameters: fields).totalWatts, 4.27, accuracy: 0.000_001)
        let encoded = try A25X7TLV.encode(fields.sorted { $0.key < $1.key }.map { ($0.key, $0.value) })
        XCTAssertEqual(encoded, payload)
    }
}

private func wireHex(_ value: String) -> Data {
    let bytes = Array(value.utf8)
    return Data(stride(from: 0, to: bytes.count, by: 2).map { index in
        UInt8(String(bytes: bytes[index..<(index + 2)], encoding: .utf8)!, radix: 16)!
    })
}

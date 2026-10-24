import Foundation
import XCTest
@testable import A25X7Protocol

final class A25X7Tests: XCTestCase {
    // SolixBLE tests/test_devices.py: decrypted MagGo hardware capture.
    // Attributed to Harvey Lelliott, MIT. Not a live device key or address.
    private var captured: [UInt8: Data] {
        [
            0xA1: Data([0x31]),
            0xA2: Data([0x04, 0x01, 0x3A, 0x02, 0x32, 0x00, 0x1D, 0x01]),
            0xA3: Data([0x04, 0x01, 0xC6, 0x02, 0x14, 0x00, 0x8E, 0x00]),
            0xA4: Data([0x04, 0x00, 0xF4, 0x01, 0x00, 0x00, 0x00, 0x00]),
            0xA5: Data([0x04, 0xFF, 0xFF]),
            0xA6: Data([0x04, 0x00, 0x00, 0x00, 0x00]),
            0xFE: Data([0x03, 0x00, 0x00, 0x00, 0x00]),
        ]
    }

    func testCapturedHardwareReadings() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let telemetry = try A25X7Telemetry.decode(parameters: captured, at: date)
        XCTAssertEqual(telemetry.updatedAt, date)
        XCTAssertEqual(telemetry.pads.map(\.id), [0xA2, 0xA3, 0xA4])
        XCTAssertEqual(telemetry.pads.map(\.name), ["Pad 1", "Pad 2", "Pad 3"])
        XCTAssertEqual(telemetry.pads.map(\.status), [1, 1, 0])
        XCTAssertEqual(telemetry.pads.map(\.isCharging), [true, true, false])
        XCTAssertEqual(telemetry.pads[0].watts, 2.85, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.pads[1].watts, 1.42, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.pads[2].watts, 0)
        XCTAssertEqual(telemetry.totalWatts, 4.27, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.pads.map(\.rawVoltage), [570, 710, 500])
        XCTAssertEqual(telemetry.pads.map(\.rawCurrent), [50, 20, 0])
    }

    func testSecondCapturedReport() throws {
        var parameters = captured
        parameters[0xA3] = Data([0x04, 0x01, 0xD0, 0x02, 0x1E, 0x00, 0xD8, 0x00])
        let telemetry = try A25X7Telemetry.decode(parameters: parameters)
        XCTAssertEqual(telemetry.pads[1].watts, 2.16, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.totalWatts, 5.01, accuracy: 0.000_001)
    }

    func testCapturedTLVParserRetainsTypePrefix() throws {
        let payload = Data([
            0xA1, 0x01, 0x31,
            0xA2, 0x08, 0x04, 0x01, 0x3A, 0x02, 0x32, 0x00, 0x1D, 0x01,
            0xA3, 0x08, 0x04, 0x01, 0xC6, 0x02, 0x14, 0x00, 0x8E, 0x00,
            0xA4, 0x08, 0x04, 0x00, 0xF4, 0x01, 0x00, 0x00, 0x00, 0x00,
            0xA5, 0x03, 0x04, 0xFF, 0xFF,
            0xA6, 0x05, 0x04, 0x00, 0x00, 0x00, 0x00,
            0xFE, 0x05, 0x03, 0x00, 0x00, 0x00, 0x00,
        ])
        let parameters = try A25X7TLV.parse(payload)
        XCTAssertEqual(parameters, captured)
        XCTAssertEqual(try A25X7Telemetry.decode(parameters: parameters).totalWatts, 4.27, accuracy: 0.000_001)
    }

    func testEveryPadIsRequired() {
        for key: UInt8 in [0xA2, 0xA3, 0xA4] {
            var parameters = captured
            parameters.removeValue(forKey: key)
            XCTAssertThrowsError(try A25X7Telemetry.decode(parameters: parameters)) {
                XCTAssertEqual($0 as? A25X7DecodingError, .missingParameter(key))
            }
        }
        XCTAssertThrowsError(try A25X7Telemetry.decode(parameters: [:]))
    }

    func testRejectsEveryTruncatedPadAndOverlongValues() {
        for key: UInt8 in [0xA2, 0xA3, 0xA4] {
            for length in 0..<8 {
                var parameters = captured
                parameters[key] = Data(captured[key]!.prefix(length))
                XCTAssertThrowsError(try A25X7Telemetry.decode(parameters: parameters)) {
                    XCTAssertEqual($0 as? A25X7DecodingError, .invalidLength(parameter: key, actual: length))
                }
            }
            var parameters = captured
            var value = parameters[key]!
            value.append(0)
            parameters[key] = value
            XCTAssertThrowsError(try A25X7Telemetry.decode(parameters: parameters)) {
                XCTAssertEqual($0 as? A25X7DecodingError, .invalidLength(parameter: key, actual: 9))
            }
        }
    }

    func testRejectsStrippedPrefixAndWrongTypes() {
        var parameters = captured
        parameters[0xA2] = Data(captured[0xA2]!.dropFirst())
        XCTAssertThrowsError(try A25X7Telemetry.decode(parameters: parameters))
        for type: UInt8 in [0, 1, 2, 3, 0xFF] {
            parameters = captured
            var value = parameters[0xA2]!
            value[0] = type
            parameters[0xA2] = value
            XCTAssertThrowsError(try A25X7Telemetry.decode(parameters: parameters)) {
                XCTAssertEqual($0 as? A25X7DecodingError, .invalidType(parameter: 0xA2, actual: type))
            }
        }
    }

    func testRejectsUnestablishedStatusValues() {
        for status in UInt8(2)...UInt8.max {
            var parameters = captured
            var value = parameters[0xA3]!
            value[1] = status
            parameters[0xA3] = value
            XCTAssertThrowsError(try A25X7Telemetry.decode(parameters: parameters)) {
                XCTAssertEqual($0 as? A25X7DecodingError, .unsupportedStatus(parameter: 0xA3, actual: status))
            }
        }
    }

    func testAcceptsNonzeroDataStartIndex() throws {
        var parameters = captured
        for key: UInt8 in [0xA2, 0xA3, 0xA4] {
            let padded = Data([0xFF]) + captured[key]!
            parameters[key] = padded.dropFirst()
        }
        XCTAssertEqual(try A25X7Telemetry.decode(parameters: parameters).totalWatts, 4.27, accuracy: 0.000_001)
    }

    func testFullUInt16RangeDoesNotOverflowOrApplyUnverifiedScaling() throws {
        var parameters = captured
        for key: UInt8 in [0xA2, 0xA3, 0xA4] {
            parameters[key] = Data([0x04, 0x01, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
        }
        let telemetry = try A25X7Telemetry.decode(parameters: parameters)
        XCTAssertEqual(telemetry.totalWatts, 1_966.05, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.pads[0].watts, 655.35, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.pads[0].rawVoltage, UInt16.max)
        XCTAssertEqual(telemetry.pads[0].rawCurrent, UInt16.max)
    }

    func testSubscribeMatchesCapturedCommandWithoutTimestamp() throws {
        let expected = Data([0xA1, 0x01, 0x21])
        XCTAssertEqual(try A25X7Commands.subscribePayload(), expected)
        XCTAssertEqual(try A25X7Commands.subscribePayload(now: Date(timeIntervalSince1970: 0)), expected)
        XCTAssertEqual(try A25X7Commands.subscribePayload(now: Date(timeIntervalSince1970: 4_294_967_296)), expected)
    }
}

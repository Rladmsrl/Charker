import Foundation
import XCTest
@testable import A25X7Protocol

/// Session-side merge of partial pad reports.
///
/// The live BLE session keeps one `A25X7ReportCache` per link and only publishes
/// a snapshot once all three pads have been accepted. These tests are the
/// contract for that cache. The GCM handshake itself is covered by
/// `A2687ProtocolTests`, which is the stack the session reuses.
final class A25X7SessionTests: XCTestCase {
    private var captured: [UInt8: Data] {
        [
            0xA1: Data([0x31]),
            0xA2: Data([0x04, 0x01, 0x3A, 0x02, 0x32, 0x00, 0x1D, 0x01]),
            0xA3: Data([0x04, 0x01, 0xC6, 0x02, 0x14, 0x00, 0x8E, 0x00]),
            0xA4: Data([0x04, 0x00, 0xF4, 0x01, 0x00, 0x00, 0x00, 0x00]),
            0xA5: Data([0x04, 0xFF, 0xFF]),
        ]
    }

    func testPartialReportsStayUnpublishedUntilEveryPadArrives() throws {
        var cache = A25X7ReportCache()
        cache.merge([0xA2: captured[0xA2]!, 0xA1: captured[0xA1]!])
        XCTAssertNil(try cache.telemetry())
        cache.merge([0xA3: captured[0xA3]!])
        XCTAssertNil(try cache.telemetry())
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        cache.merge([0xA4: captured[0xA4]!, 0xA5: captured[0xA5]!])
        let telemetry = try XCTUnwrap(cache.telemetry(at: date))
        XCTAssertEqual(telemetry.updatedAt, date)
        XCTAssertEqual(telemetry.totalWatts, 4.27, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.pads.map(\.name), ["Pad 1", "Pad 2", "Pad 3"])
    }

    func testLaterReportUpdatesOnePadWithoutInventingZeros() throws {
        var cache = A25X7ReportCache()
        cache.merge(captured)
        cache.merge([0xA3: Data([0x04, 0x01, 0xD0, 0x02, 0x1E, 0x00, 0xD8, 0x00])])
        let telemetry = try XCTUnwrap(cache.telemetry())
        XCTAssertEqual(telemetry.pads[0].watts, 2.85, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.pads[1].watts, 2.16, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.pads[2].watts, 0, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.totalWatts, 5.01, accuracy: 0.000_001)
    }

    func testCorruptPadUpdateDoesNotEraseAValidReading() throws {
        var cache = A25X7ReportCache()
        cache.merge(captured)
        cache.merge([
            0xA2: Data([0x04, 0x01]),
            0xA4: Data([0x04, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
        ])
        let telemetry = try XCTUnwrap(cache.telemetry())
        XCTAssertEqual(telemetry.pads[0].watts, 2.85, accuracy: 0.000_001)
        XCTAssertEqual(telemetry.pads[2].status, 0)
        XCTAssertEqual(telemetry.totalWatts, 4.27, accuracy: 0.000_001)
    }

    func testResetDropsTheMergedReport() throws {
        var cache = A25X7ReportCache()
        cache.merge(captured)
        cache.reset()
        XCTAssertNil(try cache.telemetry())
        XCTAssertTrue(cache.parameters.isEmpty)
    }
}

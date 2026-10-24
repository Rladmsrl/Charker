import A2687Protocol
import XCTest
@testable import CharkerCore

final class A25X7SessionMessageTests: XCTestCase {
    func testSubscribeIsTheThreeByteCommandWithoutATimestamp() {
        let message = A25X7Session.subscribeMessage(at: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(message.group, Frame.sessionGroup)
        XCTAssertEqual(message.opcode, 0x0200)
        XCTAssertEqual(message.plaintext, [0xA1, 0x01, 0x21])
        XCTAssertEqual(message.encryption, .session)
        XCTAssertFalse(message.expectsResponse)
        XCTAssertFalse(message.plaintext.contains(0xFE))
    }
}

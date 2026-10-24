import Foundation

public enum A25X7TLVError: Error, Equatable, Sendable {
    case malformed
    case duplicateTag(UInt8)
    case valueTooLong
}

/// Strict TLV used by the pad’s plaintext payloads.
///
/// Values keep their type byte. Tags below `0xA1` and duplicate tags are
/// errors, matching the captured report layout. This is the parser the
/// telemetry tests feed; the live session uses the shared Prime payload
/// splitter and then `A25X7ReportCache`.
public enum A25X7TLV {
    public static func parse(_ data: Data) throws -> [UInt8: Data] {
        let bytes = [UInt8](data)
        var fields: [UInt8: Data] = [:]
        var offset = 0
        while offset < bytes.count {
            guard bytes.count - offset >= 2, bytes[offset] >= 0xA1 else {
                throw A25X7TLVError.malformed
            }
            let tag = bytes[offset]
            let length = Int(bytes[offset + 1])
            offset += 2
            guard length <= bytes.count - offset else { throw A25X7TLVError.malformed }
            guard fields[tag] == nil else { throw A25X7TLVError.duplicateTag(tag) }
            fields[tag] = Data(bytes[offset..<(offset + length)])
            offset += length
        }
        return fields
    }

    public static func encode(_ fields: [(UInt8, Data)]) throws -> Data {
        var result = Data()
        var seen = Set<UInt8>()
        for (tag, value) in fields {
            guard tag >= 0xA1 else { throw A25X7TLVError.malformed }
            guard seen.insert(tag).inserted else { throw A25X7TLVError.duplicateTag(tag) }
            guard value.count <= 255 else { throw A25X7TLVError.valueTooLong }
            result.append(contentsOf: [tag, UInt8(value.count)])
            result.append(value)
        }
        return result
    }
}

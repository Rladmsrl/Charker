import Foundation

/// Merges partial TLV reports before `A25X7Telemetry.decode`.
///
/// A single notification may carry only one pad. The cache keeps the last
/// accepted value of every key and only decodes once `A2`, `A3`, and `A4` are
/// all present. A pad value that is not the captured 8-byte, type-`04`,
/// status-0-or-1 shape is ignored, so a short or corrupt update cannot wipe
/// a pad that was already valid. Missing pads are never stored as 0 W.
public struct A25X7ReportCache: Sendable, Equatable {
    public private(set) var parameters: [UInt8: Data]

    public init(parameters: [UInt8: Data] = [:]) {
        self.parameters = parameters
    }

    public mutating func reset() {
        parameters.removeAll(keepingCapacity: true)
    }

    public mutating func merge(_ report: [UInt8: Data]) {
        for (key, value) in report {
            if A25X7.padParameterKeys.contains(key) {
                let bytes = Array(value)
                guard bytes.count == 8, bytes[0] == 0x04, bytes[1] <= 1 else { continue }
            }
            parameters[key] = Data(value)
        }
    }

    /// Nil while any pad is still missing. Any other decoding failure is thrown
    /// so a present-but-illegal value is not presented as a live reading.
    public func telemetry(at date: Date = Date()) throws -> A25X7Telemetry? {
        do {
            return try A25X7Telemetry.decode(parameters: parameters, at: date)
        } catch let error as A25X7DecodingError {
            if case .missingParameter = error { return nil }
            throw error
        }
    }
}

import Foundation

/// One wireless pad. Voltage and current fields keep the captured integers.
///
/// Their units and scale are not confirmed, so a UI must not print them as
/// volts or amps. Only `watts` and `status` are safe to show.
public struct WirelessPadReading: Identifiable, Sendable, Equatable {
    /// TLV parameter key: `0xA2`, `0xA3`, or `0xA4`.
    public var id: UInt8
    /// Stable English slot name (`Pad 1` … `Pad 3`). Not a device type.
    ///
    /// Public captures, the official parser, and a hardware note disagree about
    /// which slot is a phone, a watch, or earbuds. Callers that localize the
    /// label should say “pad 1/2/3”, not invent a device name.
    public var name: String
    public var status: UInt8
    public var watts: Double
    public var rawVoltage: UInt16
    public var rawCurrent: UInt16
    public var isCharging: Bool { status == 1 }

    public init(
        id: UInt8,
        name: String,
        status: UInt8,
        watts: Double,
        rawVoltage: UInt16,
        rawCurrent: UInt16
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.watts = watts
        self.rawVoltage = rawVoltage
        self.rawCurrent = rawCurrent
    }
}

public enum A25X7DecodingError: Error, Equatable, Sendable {
    case missingParameter(UInt8)
    case invalidLength(parameter: UInt8, actual: Int)
    case invalidType(parameter: UInt8, actual: UInt8)
    case unsupportedStatus(parameter: UInt8, actual: UInt8)
}

/// A complete three-pad snapshot. Partial reports are not decoded here.
public struct A25X7Telemetry: Sendable, Equatable {
    public var pads: [WirelessPadReading]
    public var totalWatts: Double
    public var updatedAt: Date

    public init(pads: [WirelessPadReading], totalWatts: Double, updatedAt: Date) {
        self.pads = pads
        self.totalWatts = totalWatts
        self.updatedAt = updatedAt
    }

    /// Requires all three pads. Merge partial reports in the caller’s cache first.
    ///
    /// Each value is the full TLV value, including the `0x04` type byte and
    /// excluding the key and length. Only statuses 0 (idle) and 1 (output) are
    /// accepted. A missing pad is an error, never a synthetic 0 W.
    public static func decode(
        parameters: [UInt8: Data], at: Date = Date()
    ) throws -> A25X7Telemetry {
        var pads: [WirelessPadReading] = []
        // Sum integer centiwatts first so three full-scale UInt16 readings
        // cannot overflow and so the total is not a float accumulation.
        var totalCentiwatts: UInt32 = 0
        for (offset, parameter) in A25X7.padParameterKeys.enumerated() {
            guard let value = parameters[parameter] else {
                throw A25X7DecodingError.missingParameter(parameter)
            }
            guard value.count == 8 else {
                throw A25X7DecodingError.invalidLength(parameter: parameter, actual: value.count)
            }
            // `Data` slices from a larger buffer need not start at index 0.
            let bytes = Array(value)
            guard bytes[0] == 0x04 else {
                throw A25X7DecodingError.invalidType(parameter: parameter, actual: bytes[0])
            }
            guard bytes[1] <= 1 else {
                throw A25X7DecodingError.unsupportedStatus(parameter: parameter, actual: bytes[1])
            }
            let power = littleEndianUInt16(bytes, at: 6)
            totalCentiwatts += UInt32(power)
            pads.append(WirelessPadReading(
                id: parameter,
                name: "Pad \(offset + 1)",
                status: bytes[1],
                watts: Double(power) / 100,
                rawVoltage: littleEndianUInt16(bytes, at: 2),
                rawCurrent: littleEndianUInt16(bytes, at: 4)
            ))
        }
        return A25X7Telemetry(
            pads: pads,
            totalWatts: Double(totalCentiwatts) / 100,
            updatedAt: at
        )
    }

    private static func littleEndianUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }
}

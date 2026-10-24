import Foundation

/// Hardware families supported by Charker.
///
/// This is deliberately a product-level description, not a transport enum:
/// A2687 is currently reached over BLE while A2345 is reached through Anker's
/// cloud MQTT service, but UI and history code should care about the charger in
/// front of the user rather than the wire carrying its readings.
public enum ChargerProduct: String, Codable, CaseIterable, Sendable, Equatable {
    case a2687 = "A2687"
    case a2345 = "A2345"
    case a25x7 = "A25X7"

    public var displayName: String {
        switch self {
        case .a2687: return "Anker Prime 160W"
        case .a2345: return "Anker Prime 250W"
        case .a25x7: return "Anker Prime Wireless"
        }
    }

    public var ratedWatts: Double {
        switch self {
        case .a2687: return 160
        case .a2345: return 250
        // Not a verified nameplate. Public pad captures are a few watts each.
        // 15 W is only the menu-bar rail's full-scale mark so a 3 W pad does
        // not paint the whole rail; charts promote when a sample exceeds them.
        case .a25x7: return 15
        }
    }

    public var ports: [ChargerPortID] {
        switch self {
        case .a2687, .a25x7: return [.c1, .c2, .c3]
        case .a2345: return [.c1, .c2, .c3, .c4, .a1, .a2]
        }
    }

    /// Apple Home needs a confirmed on/off command. The pad does not have one.
    public var supportsMatter: Bool {
        switch self {
        case .a2687, .a2345: return true
        case .a25x7: return false
        }
    }

    public var connectionLabel: String {
        switch self {
        case .a2687: return L10n.text("蓝牙直连", table: "Core")
        case .a2345: return L10n.text("Wi-Fi 云端", table: "Core")
        case .a25x7: return L10n.text("蓝牙直连 · 实验性", table: "Core")
        }
    }
}

/// Stable, transport-independent port identity.
///
/// Raw values are the persisted order used by nicknames, history and charts.
/// Never reorder existing cases: old three-port data occupies slots 0...2 and
/// A2345 extends that layout with C4/A1/A2 in slots 3...5.
public enum ChargerPortID: Int, Codable, CaseIterable, Sendable, Equatable, Hashable, Identifiable {
    case c1 = 0
    case c2 = 1
    case c3 = 2
    case c4 = 3
    case a1 = 4
    case a2 = 5

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .c1: return "C1"
        case .c2: return "C2"
        case .c3: return "C3"
        case .c4: return "C4"
        case .a1: return "A1"
        case .a2: return "A2"
        }
    }

    /// Name to print for this slot on `product`.
    ///
    /// A25X7 reuses the first three stable slots so energy history and the
    /// menu bar keep their indexes, but those slots are wireless pads. Public
    /// evidence disagrees about phone / watch / earbuds, so the label stays
    /// “pad 1/2/3”.
    public func readoutLabel(for product: ChargerProduct) -> String {
        guard product == .a25x7 else { return label }
        switch self {
        case .c1: return L10n.text("充电位 1", table: "Core")
        case .c2: return L10n.text("充电位 2", table: "Core")
        case .c3: return L10n.text("充电位 3", table: "Core")
        case .c4, .a1, .a2: return label
        }
    }

    public var connectorLabel: String {
        switch self {
        case .c1, .c2, .c3, .c4: return "USB-C"
        case .a1, .a2: return "USB-A"
        }
    }

    public func maximumWatts(for product: ChargerProduct) -> Double {
        switch (product, self) {
        case (.a2687, .c1), (.a2687, .c2), (.a2687, .c3): return 160
        case (.a2345, .c1): return 140
        case (.a2345, .c2), (.a2345, .c3), (.a2345, .c4): return 100
        case (.a2345, .a1), (.a2345, .a2): return 22.5
        default: return 0
        }
    }
}

/// A read-only port value shared by transport-specific presentation code.
public struct ChargerPortReading: Sendable, Equatable, Identifiable {
    public var id: ChargerPortID { port }
    public var port: ChargerPortID
    public var statusCode: UInt8
    public var voltage: Double
    public var current: Double
    public var power: Double
    public var usbVendorID: UInt16?
    public var usbProductID: UInt16?
    /// Only mainland A2345 firmware reports these three; nil means not
    /// reported, never "none".
    public var cable: PortCable?
    public var fastCharge: PortFastCharge?
    public var deviceBrand: PortDeviceBrand?
    /// A25X7 reports watts and a status byte. The two integers beside the
    /// power word do not have a confirmed unit, so voltage and current stay
    /// zero and delivery is decided from power instead of from volts × amps.
    public var infersDeliveryFromPower: Bool

    public init(
        port: ChargerPortID,
        statusCode: UInt8,
        voltage: Double,
        current: Double,
        power: Double,
        usbVendorID: UInt16? = nil,
        usbProductID: UInt16? = nil,
        cable: PortCable? = nil,
        fastCharge: PortFastCharge? = nil,
        deviceBrand: PortDeviceBrand? = nil,
        infersDeliveryFromPower: Bool = false
    ) {
        self.port = port
        self.statusCode = statusCode
        self.voltage = voltage.isFinite ? max(0, voltage) : 0
        self.current = current.isFinite ? max(0, current) : 0
        self.power = power.isFinite ? max(0, power) : 0
        self.usbVendorID = usbVendorID
        self.usbProductID = usbProductID
        self.cable = cable
        self.fastCharge = fastCharge
        self.deviceBrand = deviceBrand
        self.infersDeliveryFromPower = infersDeliveryFromPower
    }

    public var isOn: Bool { statusCode != 0 }
    public var isDelivering: Bool {
        if infersDeliveryFromPower { return isOn && power > 0 }
        return isOn && current > 0.02 && voltage > 3
    }
    public var hasReadings: Bool {
        if infersDeliveryFromPower { return isOn || power > 0 }
        return isOn && (voltage > 0 || current > 0 || power > 0)
    }
}

/// Cable rating the mainland A2345 detects on a USB-C port.
public enum PortCable: UInt8, Sendable, Equatable {
    case threeAmp = 0
    case fiveAmp = 1
    case epr = 2
    case huawei = 3
    case xiaomi = 4
}

/// Private fast-charge protocol a mainland A2345 port negotiated.
public enum PortFastCharge: UInt8, Sendable, Equatable {
    case huaweiSCP = 1
    case xiaomiHyperCharge = 2
}

/// Phone brand a mainland A2345 port recognised.
public enum PortDeviceBrand: UInt8, Sendable, Equatable {
    case huaweiHonor = 1
    case xiaomi = 2
}

/// One coherent reading from a charger, independent of BLE or MQTT framing.
public struct ChargerReading: Sendable, Equatable {
    public var product: ChargerProduct
    public var ports: [ChargerPortReading]
    public var receivedAt: Date

    public init(product: ChargerProduct, ports: [ChargerPortReading], receivedAt: Date = Date()) {
        self.product = product
        let supported = Set(product.ports)
        self.ports = ports.filter { supported.contains($0.port) }
        self.receivedAt = receivedAt
    }

    public func port(_ id: ChargerPortID) -> ChargerPortReading? {
        ports.first { $0.port == id }
    }

    public var totalPower: Double {
        ports.reduce(0) { $0 + ($1.isOn ? $1.power : 0) }
    }

    public var activePortCount: Int { ports.filter(\.isDelivering).count }

    public var orderedPortPower: [Double] {
        product.ports.map { port($0).map { $0.isOn ? $0.power : 0 } ?? 0 }
    }
}

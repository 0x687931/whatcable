import Foundation

/// USB Power Delivery 3.0 / 3.1 VDO decoders. We only parse the fields we
/// surface — refer to the USB-PD spec (Universal Serial Bus Power Delivery
/// Specification, Revision 3.1) for the full layout.
enum PDVDO {

    // MARK: ID Header VDO (always VDO[0])

    enum ProductType: Int {
        case undefined = 0
        case pdusbHub = 1
        case pdusbPeripheral = 2
        case passiveCable = 3
        case activeCable = 4
        case ama = 5            // Alternate Mode Adapter
        case vpd = 6            // VCONN-Powered Device
        case other = 7

        var label: String {
            switch self {
            case .undefined: return "Unspecified"
            case .pdusbHub: return "USB Hub"
            case .pdusbPeripheral: return "USB Peripheral"
            case .passiveCable: return "Passive cable"
            case .activeCable: return "Active cable"
            case .ama: return "Alternate Mode Adapter"
            case .vpd: return "VCONN-powered device"
            case .other: return "Other"
            }
        }
    }

    struct IDHeader {
        let usbCommHost: Bool
        let usbCommDevice: Bool
        let modalOperation: Bool
        /// UFP product type (set on cables / peripherals)
        let ufpProductType: ProductType
        /// DFP product type (set on hosts / hubs)
        let dfpProductType: ProductType
        let vendorID: Int
    }

    static func decodeIDHeader(_ vdo: UInt32) -> IDHeader {
        IDHeader(
            usbCommHost: (vdo >> 31) & 1 == 1,
            usbCommDevice: (vdo >> 30) & 1 == 1,
            modalOperation: (vdo >> 26) & 1 == 1,
            ufpProductType: ProductType(rawValue: Int((vdo >> 27) & 0b111)) ?? .undefined,
            dfpProductType: ProductType(rawValue: Int((vdo >> 23) & 0b111)) ?? .undefined,
            vendorID: Int(vdo & 0xFFFF)
        )
    }

    // MARK: Cable VDO (passive or active, VDO[3] in PD 3.0+)

    enum CableSpeed: Int {
        case usb20 = 0
        case usb32Gen1 = 1   // 5 Gbps
        case usb32Gen2 = 2   // 10 Gbps
        case usb4Gen3 = 3    // 20 Gbps (PD 3.0) / 40 Gbps (PD 3.1)
        case usb4Gen4 = 4    // 80 Gbps

        var label: String {
            switch self {
            case .usb20: return "USB 2.0 (480 Mbps)"
            case .usb32Gen1: return "USB 3.2 Gen 1 (5 Gbps)"
            case .usb32Gen2: return "USB 3.2 Gen 2 (10 Gbps)"
            case .usb4Gen3: return "USB4 Gen 3 (20 / 40 Gbps)"
            case .usb4Gen4: return "USB4 Gen 4 (80 Gbps)"
            }
        }

        var maxGbps: Double {
            switch self {
            case .usb20: return 0.48
            case .usb32Gen1: return 5
            case .usb32Gen2: return 10
            case .usb4Gen3: return 40
            case .usb4Gen4: return 80
            }
        }
    }

    enum CableCurrent: Int {
        case usbDefault = 0   // 900 mA / 1.5 A typical USB
        case threeAmp = 1
        case fiveAmp = 2

        var maxAmps: Double {
            switch self {
            case .usbDefault: return 3.0   // be charitable; Type-C default current is 3A on cables
            case .threeAmp: return 3.0
            case .fiveAmp: return 5.0
            }
        }

        var label: String {
            switch self {
            case .usbDefault: return "USB default"
            case .threeAmp: return "3 A"
            case .fiveAmp: return "5 A"
            }
        }
    }

    enum CableType: Int {
        case passive = 0
        case active = 1
        case other = 2
    }

    struct CableVDO {
        let speed: CableSpeed
        let current: CableCurrent
        /// Approx max wattage at the highest negotiated voltage (20V) the cable can carry.
        let maxWatts: Int
        let cableType: CableType
        let vbusThroughCable: Bool
        /// Encoded "Maximum VBUS Voltage" field. 0=20V, 1=30V, 2=40V, 3=50V.
        let maxVoltageEncoded: Int

        var maxVolts: Int {
            switch maxVoltageEncoded {
            case 0: return 20
            case 1: return 30
            case 2: return 40
            case 3: return 50
            default: return 20
            }
        }
    }

    static func decodeCableVDO(_ vdo: UInt32, isActive: Bool) -> CableVDO {
        let speedBits = Int(vdo & 0b111)
        let speed = CableSpeed(rawValue: speedBits) ?? .usb20
        let vbusThrough = (vdo >> 4) & 1 == 1
        let currentBits = Int((vdo >> 5) & 0b11)
        let current = CableCurrent(rawValue: currentBits) ?? .usbDefault
        let maxV = Int((vdo >> 9) & 0b11)
        let cableType: CableType = isActive ? .active : .passive

        let volts: Double
        switch maxV {
        case 1: volts = 30
        case 2: volts = 40
        case 3: volts = 50
        default: volts = 20
        }
        let amps = current.maxAmps
        let watts = min(Int((volts * amps).rounded()), 240)

        return CableVDO(
            speed: speed,
            current: current,
            maxWatts: watts,
            cableType: cableType,
            vbusThroughCable: vbusThrough,
            maxVoltageEncoded: maxV
        )
    }

    // MARK: Helpers

    /// IOKit stores VDOs as 4-byte little-endian Data blobs. Decode to UInt32.
    static func vdoFromData(_ data: Data) -> UInt32? {
        guard data.count >= 4 else { return nil }
        return data.withUnsafeBytes { buf in
            buf.loadUnaligned(as: UInt32.self).littleEndian
        }
    }
}

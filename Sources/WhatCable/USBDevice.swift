import Foundation

struct USBDevice: Identifiable, Hashable {
    let id: UInt64
    let locationID: UInt32
    let vendorID: UInt16
    let productID: UInt16
    let vendorName: String?
    let productName: String?
    let usbVersion: String?
    let speedRaw: UInt8?
    let busPowerMA: Int?
    let currentMA: Int?

    var speedLabel: String {
        // IOUSBHostDevice "Device Speed" enum values
        switch speedRaw {
        case 0: return "Low Speed (1.5 Mbps)"
        case 1: return "Full Speed (12 Mbps)"
        case 2: return "High Speed (480 Mbps)"
        case 3: return "Super Speed (5 Gbps)"
        case 4: return "Super Speed+ (10 Gbps)"
        case 5: return "Super Speed+ Gen 2x2 (20 Gbps)"
        default: return "Unknown speed"
        }
    }
}

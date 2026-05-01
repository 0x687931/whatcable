import Foundation

struct USBCPort: Identifiable, Hashable {
    let id: UInt64
    let serviceName: String          // e.g. "Port-USB-C@1"
    let className: String            // e.g. "AppleHPMInterfaceType10"
    let portDescription: String?     // "Port-USB-C@1"
    let portTypeDescription: String? // "USB-C"
    let portNumber: Int?
    let connectionActive: Bool?
    let activeCable: Bool?
    let opticalCable: Bool?
    let usbActive: Bool?
    let superSpeedActive: Bool?
    let usbModeType: Int?            // raw enum
    let usbConnectString: String?    // "None" / human label
    let transportsSupported: [String]
    let transportsActive: [String]
    let transportsProvisioned: [String]
    let plugOrientation: Int?
    let plugEventCount: Int?
    let connectionCount: Int?
    let overcurrentCount: Int?
    let pinConfiguration: [String: String]
    let powerCurrentLimits: [Int]
    let firmwareVersion: String?
    let bootFlagsHex: String?
    let rawProperties: [String: String]

    /// Match key joining port-controller, power-source, and PD identity views.
    var portKey: String? {
        guard let n = portNumber else { return nil }
        let rawType = rawProperties["PortType"].flatMap { Int($0) } ?? 0x2
        return "\(rawType)/\(n)"
    }
}

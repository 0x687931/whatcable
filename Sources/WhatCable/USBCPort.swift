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
    /// XHCI controller index derived from an `hpm<N>` ancestor when available.
    /// Used only as a fallback when devices do not expose a direct `UsbIOPort`.
    let busIndex: Int?
    let rawProperties: [String: String]

    init(
        id: UInt64,
        serviceName: String,
        className: String,
        portDescription: String?,
        portTypeDescription: String?,
        portNumber: Int?,
        connectionActive: Bool?,
        activeCable: Bool?,
        opticalCable: Bool?,
        usbActive: Bool?,
        superSpeedActive: Bool?,
        usbModeType: Int?,
        usbConnectString: String?,
        transportsSupported: [String],
        transportsActive: [String],
        transportsProvisioned: [String],
        plugOrientation: Int?,
        plugEventCount: Int?,
        connectionCount: Int?,
        overcurrentCount: Int?,
        pinConfiguration: [String: String],
        powerCurrentLimits: [Int],
        firmwareVersion: String?,
        bootFlagsHex: String?,
        busIndex: Int? = nil,
        rawProperties: [String: String]
    ) {
        self.id = id
        self.serviceName = serviceName
        self.className = className
        self.portDescription = portDescription
        self.portTypeDescription = portTypeDescription
        self.portNumber = portNumber
        self.connectionActive = connectionActive
        self.activeCable = activeCable
        self.opticalCable = opticalCable
        self.usbActive = usbActive
        self.superSpeedActive = superSpeedActive
        self.usbModeType = usbModeType
        self.usbConnectString = usbConnectString
        self.transportsSupported = transportsSupported
        self.transportsActive = transportsActive
        self.transportsProvisioned = transportsProvisioned
        self.plugOrientation = plugOrientation
        self.plugEventCount = plugEventCount
        self.connectionCount = connectionCount
        self.overcurrentCount = overcurrentCount
        self.pinConfiguration = pinConfiguration
        self.powerCurrentLimits = powerCurrentLimits
        self.firmwareVersion = firmwareVersion
        self.bootFlagsHex = bootFlagsHex
        self.busIndex = busIndex
        self.rawProperties = rawProperties
    }

    /// Match key joining port-controller, power-source, and PD identity views.
    var portKey: String? {
        guard let n = portNumber else { return nil }
        let rawType = rawProperties["PortType"].flatMap { Int($0) } ?? 0x2
        return "\(rawType)/\(n)"
    }

    func matchingDevices(from devices: [USBDevice]) -> [USBDevice] {
        let portNames = Set<String>([serviceName, portDescription].compactMap { value in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        })

        if !portNames.isEmpty {
            let directMatches = devices.filter { device in
                guard let name = device.controllerPortName else { return false }
                return portNames.contains(name)
            }
            if !directMatches.isEmpty {
                return directMatches
            }
        }

        if devices.contains(where: { $0.controllerPortName != nil }) {
            return []
        }

        guard let busIndex else { return [] }
        return devices.filter { $0.busIndex == busIndex }
    }

    static func isIntelThunderboltFallbackClass(_ className: String) -> Bool {
        switch className {
        case "AppleThunderboltPort",
             "IOThunderboltPort",
             "AppleThunderboltNHIType3",
             "IOThunderboltSwitchIntelJHL9580":
            return true
        default:
            return false
        }
    }

    static func intelThunderboltFallback(
        entryID: UInt64,
        serviceName: String,
        className: String,
        properties: [String: Any],
        ordinal: Int
    ) -> USBCPort? {
        guard isIntelThunderboltFallbackClass(className) else { return nil }

        var raw = IOKitSupport.stringProperties(from: properties)
        raw["WhatCableDetectionMode"] = "Intel Thunderbolt fallback"
        raw["WhatCableRegistryName"] = serviceName

        let portNumber = ordinal > 0 ? ordinal : nil
        let label = portNumber.map { "Intel Thunderbolt USB-C \($0)" } ?? "Intel Thunderbolt USB-C"

        return USBCPort(
            id: entryID,
            serviceName: serviceName,
            className: className,
            portDescription: label,
            portTypeDescription: "USB-C",
            portNumber: portNumber,
            connectionActive: nil,
            activeCable: nil,
            opticalCable: nil,
            usbActive: nil,
            superSpeedActive: nil,
            usbModeType: nil,
            usbConnectString: nil,
            transportsSupported: ["Thunderbolt", "USB"],
            transportsActive: [],
            transportsProvisioned: [],
            plugOrientation: nil,
            plugEventCount: nil,
            connectionCount: nil,
            overcurrentCount: nil,
            pinConfiguration: [:],
            powerCurrentLimits: [],
            firmwareVersion: nil,
            bootFlagsHex: nil,
            busIndex: nil,
            rawProperties: raw
        )
    }
}

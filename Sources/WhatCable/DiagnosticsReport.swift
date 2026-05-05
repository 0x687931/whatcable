import Darwin
import Foundation
import IOKit

enum DiagnosticsReport {
    static func make() -> String {
        var lines: [String] = []
        lines.append("WhatCable Diagnostics")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("App version: \(AppInfo.version)")
        lines.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("Hardware model: \(machineModel())")
        lines.append("")
        lines.append("Privacy: serial numbers and UUIDs are redacted. Review before sharing publicly.")
        lines.append("")
        lines.append("Physical port scan classes:")
        for cls in USBCPortWatcher.candidateClasses {
            lines.append("- \(cls)")
        }
        lines.append("")
        lines.append("Relevant IOService entries:")

        let entries = collectRelevantEntries()
        if entries.isEmpty {
            lines.append("- none found")
        } else {
            for entry in entries {
                lines.append("")
                lines.append("- \(entry.name) <class \(entry.className)> id=\(entry.entryIDHex)")
                if !entry.parentChain.isEmpty {
                    lines.append("  Parent chain:")
                    for parent in entry.parentChain {
                        lines.append("  - \(parent)")
                    }
                }
                if !entry.properties.isEmpty {
                    lines.append("  Properties:")
                    for property in entry.properties {
                        lines.append("  - \(property.key): \(property.value)")
                    }
                }
            }
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    static func fileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "WhatCable-Diagnostics-\(formatter.string(from: Date())).txt"
    }

    static func redactedPropertyValue(key: String, value: Any) -> String {
        let lowercased = key.lowercased()
        if lowercased.contains("serial") || lowercased.contains("uuid") {
            return "<redacted>"
        }
        return IOKitSupport.stringify(value)
    }

    private static let interestingPropertyKeys: Set<String> = [
        "Active",
        "AuthenticationStatusDescription",
        "AuthorizationRequired",
        "BuiltIn",
        "ConnectionActive",
        "ConnectionCount",
        "ConnectionUUID",
        "DataRateDescription",
        "Description",
        "Device Speed",
        "DriverStatusDescription",
        "FeaturesEnabled",
        "FeaturesSupported",
        "IOAccessoryUSBActive",
        "IOAccessoryUSBConnectString",
        "IOAccessoryUSBModeType",
        "IOAccessoryUSBSuperSpeedActive",
        "IOClass",
        "IONameMatch",
        "IONameMatched",
        "IOProviderClass",
        "ParentBuiltInPortNumber",
        "ParentBuiltInPortType",
        "ParentBuiltInPortTypeDescription",
        "ParentPortNumber",
        "ParentPortType",
        "ParentPortTypeDescription",
        "Plug Event Count",
        "PortDescription",
        "PortNumber",
        "PortType",
        "PortTypeDescription",
        "Product",
        "Product ID",
        "SuperSpeedSignalingDescription",
        "TransportDescription",
        "TransportTypeDescription",
        "TransportsActive",
        "TransportsProvisioned",
        "TransportsSupported",
        "USB Product Name",
        "USB Serial Number",
        "USB Vendor Name",
        "UsbIOPort",
        "UsbProtocolCompanion (1.x)",
        "UsbProtocolCompanion (2.0)",
        "UsbProtocolCompanion (3.x)",
        "UsbTransportState",
        "Vendor ID",
        "bcdUSB",
        "device_type",
        "idProduct",
        "idVendor",
        "locationID",
        "port-number",
        "port-type",
        "transports-provisioned",
        "transports-supported"
    ]

    private static func collectRelevantEntries() -> [DiagnosticEntry] {
        var iterator: io_iterator_t = 0
        let options = IOOptionBits(kIORegistryIterateRecursively)
        guard IORegistryCreateIterator(kIOMainPortDefault, kIOServicePlane, options, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var entries: [DiagnosticEntry] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            let name = registryEntryName(for: service)
            let className = objectClassName(for: service)
            let properties = IOKitSupport.properties(for: service) ?? [:]

            guard isRelevant(name: name, className: className, properties: properties) else {
                continue
            }

            let selectedProperties = properties
                .filter { interestingPropertyKeys.contains($0.key) }
                .map { key, value in
                    DiagnosticProperty(key: key, value: redactedPropertyValue(key: key, value: value))
                }
                .sorted { $0.key < $1.key }

            entries.append(DiagnosticEntry(
                name: name,
                className: className,
                entryIDHex: String(format: "0x%llx", IOKitSupport.entryID(for: service)),
                parentChain: parentChain(for: service),
                properties: selectedProperties
            ))
        }

        return entries.sorted {
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.className < $1.className
        }
    }

    private static func isRelevant(name: String, className: String, properties: [String: Any]) -> Bool {
        if name.localizedCaseInsensitiveContains("port-usb-c")
            || name.localizedCaseInsensitiveContains("port-magsafe")
            || name.hasPrefix("Port-") {
            return true
        }

        if className.hasPrefix("AppleHPMInterface")
            || className.hasPrefix("AppleTCController")
            || className.hasPrefix("IOPortTransport")
            || className == "IOPort" {
            return true
        }

        if className.hasPrefix("AppleT") && className.hasSuffix("USBXHCI") {
            return true
        }

        if properties["PortTypeDescription"] != nil
            || properties["UsbIOPort"] != nil
            || properties["TransportsSupported"] != nil
            || properties["ConnectionActive"] != nil {
            return true
        }

        return false
    }

    private static func parentChain(for service: io_service_t, maxDepth: Int = 8) -> [String] {
        var current = service
        IOObjectRetain(current)
        defer { IOObjectRelease(current) }

        var chain: [String] = []
        for _ in 0..<maxDepth {
            var parent: io_service_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS else {
                break
            }
            IOObjectRelease(current)
            current = parent
            chain.append("\(registryEntryName(for: current)) <class \(objectClassName(for: current))>")
        }
        return chain
    }

    private static func registryEntryName(for service: io_service_t) -> String {
        var nameBuf = [CChar](repeating: 0, count: 128)
        IORegistryEntryGetName(service, &nameBuf)
        let baseName = String(cString: nameBuf)

        var locBuf = [CChar](repeating: 0, count: 128)
        if IORegistryEntryGetLocationInPlane(service, kIOServicePlane, &locBuf) == KERN_SUCCESS {
            let location = String(cString: locBuf)
            if !location.isEmpty {
                return "\(baseName)@\(location)"
            }
        }
        return baseName
    }

    private static func objectClassName(for service: io_service_t) -> String {
        var classBuf = [CChar](repeating: 0, count: 128)
        IOObjectGetClass(service, &classBuf)
        return String(cString: classBuf)
    }

    private static func machineModel() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
            return "unknown"
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else {
            return "unknown"
        }
        return String(cString: buffer)
    }
}

private struct DiagnosticEntry {
    let name: String
    let className: String
    let entryIDHex: String
    let parentChain: [String]
    let properties: [DiagnosticProperty]
}

private struct DiagnosticProperty {
    let key: String
    let value: String
}
